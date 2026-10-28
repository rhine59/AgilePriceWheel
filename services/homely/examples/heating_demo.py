"""Offline harness for heating_services.py; no real Homely/upstream requests."""
import copy
from datetime import date, datetime, timedelta, timezone
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import sys
import tempfile
import threading
from types import SimpleNamespace
from unittest.mock import Mock, patch
from zoneinfo import ZoneInfo


def run_demo(source_dir):
    root = Path(source_dir).resolve()
    if not (root / 'controller/service.py').is_file():
        raise ValueError('--demo needs the Homely repository; set --source-dir to its root')
    sys.path.insert(0, str(root))
    from controller.service import State, handler_for, effective_prices, fetch_radiation
    from controller.heating import Supervisor, ObservedHomely, ControlUnavailable, build_supervisor
    from homely import validate_agile_day
    from heating_services import Client, APIError, show_status, exercise_live

    UTC, london = timezone.utc, ZoneInfo('Europe/London')
    now = datetime.now(UTC)
    start = now.replace(minute=now.minute // 30 * 30, second=0, microsecond=0)
    end = start + timedelta(minutes=30)
    checks = []

    def checked(name, condition=True):
        if not condition: raise RuntimeError('Demo check failed: ' + name)
        checks.append(name)
        print('PASS:', name)

    def expect_http(status, action):
        try: action()
        except APIError as exc:
            if exc.status == status: return
            raise
        raise RuntimeError('Expected HTTP ' + str(status))

    def day_rates(day):
        cursor = datetime.combine(day, datetime.min.time(), london).astimezone(UTC)
        boundary = datetime.combine(day + timedelta(days=1), datetime.min.time(), london).astimezone(UTC)
        result = []
        while cursor < boundary:
            result.append(dict(start=cursor, end=cursor + timedelta(minutes=30), price=20))
            cursor += timedelta(minutes=30)
        return validate_agile_day(result, day, london)

    class FakeHeatPump:
        """Test-only adapter; its claimed lease is NOT a Homely capability."""
        server_expiry_verified = True
        def __init__(self):
            self.state = {'mode': 'disabled', 'override': {'target': 18}}
            self.room, self.observed = 19, now
            self.fail_write = False
            self.writes = []
            self.hot_water = {'unchanged': True}
        def read(self): return copy.deepcopy(self.state)
        def temperature(self): return self.room, self.observed
        def make_boost(self, previous, target, expires, operation_id):
            return dict(mode='fake-boost', target=target, end=expires.isoformat(), owner=operation_id)
        def write(self, expected, desired, operation_id):
            if self.state != expected: raise RuntimeError('Simulated ownership conflict')
            if self.fail_write: raise TimeoutError('Simulated transport failure')
            self.state = copy.deepcopy(desired)
            self.writes.append(operation_id)

    print('OFFLINE USE CASE: free-power interval, price hold band, safe stop and restart recovery.')
    print('Upstreams, readings and equipment are fake. The HTTP API and backend calculations are real local code.')
    with tempfile.TemporaryDirectory(prefix='heating-services-demo-') as directory:
        directory = Path(directory)
        state = State(directory / 'policy.json')
        production = build_supervisor(state, {'HEATING_LIVE_ENABLED': 'true',
            'HEATING_RECOVERY_FILE': str(directory / 'blocked.json')})
        state.control = production
        checked('Production configuration cannot bypass live-write block',
                production.step(now)['phase'] == 'blocked' and production.adapter is None)
        key = 'offline-demo-key-' + 'd' * 32
        server = ThreadingHTTPServer(('127.0.0.1', 0), handler_for(state, key))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        client = Client('http://127.0.0.1:' + str(server.server_port), key, demo=True)
        try:
            baseline = client.policy()
            switch=client.automation()
            checked('Automation GET defaults OFF without activation', not switch['enabled'] and not switch['can_enable'])
            expect_http(409,lambda:client.set_automation(True))
            checked('Automation PUT cannot bypass administrative activation')
            stopped=client.set_automation(False)
            checked('Automation OFF persists a pending shutdown command', not stopped['enabled'] and stopped['shutdown_pending'])
            expect_http(401, lambda: Client(client.origin, 'wrong-' + 'x' * 32, demo=True).status())
            expect_http(404, lambda: client.request('GET', '/not-a-service'))
            expect_http(501, lambda: client.request('POST', '/v1/status', {}))
            checked('Authenticated API, 401, 404 and unsupported-method response')
            history = client.history()
            checked('Weekly history current and selected week endpoints',
                    client.history(history['week_start']) == history and history['events'] == [])
            expect_http(400, lambda: client.history('not-a-week'))
            draft = copy.deepcopy(baseline)
            draft['policy'].update(product='AGILE-EXAMPLE', tariff='E-1R-AGILE-EXAMPLE-G', off_price_p=5)
            saved = client.save(draft)
            expect_http(409, lambda: client.save(draft))
            invalid = copy.deepcopy(saved); invalid['policy']['limit_c'] = 26
            expect_http(400, lambda: client.save(invalid))
            with patch.object(state, 'update', side_effect=OSError('Simulated storage failure')):
                expect_http(500, lambda: client.save(saved))
            checked('Policy-storage failure produces the documented HTTP 500')
            checked('Full policy save, revision conflict and validation',
                    saved['revision'] == 1 and state.wake.is_set() and state.control_wake.is_set())
            restarted_state = State(state.path)
            checked('Atomic private policy persistence and startup reload',
                    restarted_state.document() == saved and state.path.stat().st_mode & 0o777 == 0o600)

            day = now.astimezone(london).date()
            rates = day_rates(day)
            times = [int((r['start'] + timedelta(minutes=n)).timestamp()) for r in rates for n in (0, 15)]
            response = Mock()
            response.json.return_value = {'minutely_15': {'time': times, 'shortwave_radiation': [600] * len(times)}}
            session = Mock(); session.get.return_value = response
            with patch('controller.service.fetch_agile_prices', return_value=rates), patch('controller.service.direct_session', return_value=session):
                state.refresh()
            current = client.status()['current']
            checked('Agile worker and real PV/effective-price calculation',
                    current is not None and abs(current['effective_price_p'] - 3) < 1e-8)
            negative = effective_prices([dict(start=start, end=end, price=-4)], {start: 0}, saved['policy'])[0]
            checked('Negative import prices remain negative with no PV', negative['effective_price_p'] == -4)
            checked('Spring/autumn DST coverage',
                    len(day_rates(date(2026, 3, 29))) == 46 and len(day_rates(date(2026, 10, 25))) == 50)
            with patch('controller.service.direct_session', return_value=session):
                response.json.return_value = {'minutely_15': {'time': times, 'shortwave_radiation': [None] * len(times)}}
                try: fetch_radiation(saved['policy'], day, rates)
                except (ValueError, KeyError): pass
                else: raise RuntimeError('Missing solar samples were accepted')
            checked('Missing solar forecast fails instead of implying free power')

            def publish(price):
                slots = copy.deepcopy(state.snapshot['slots']) if state.snapshot else [dict(
                    start=start.isoformat(), end=end.isoformat(), agile_price_p=price,
                    effective_price_p=price, pv_kwh=0, grid_kwh=1.5)]
                for slot in slots:
                    if datetime.fromisoformat(slot['start']) == start:
                        slot['effective_price_p'] = price
                state.publish(state.revision, slots, now)
                fake.observed = now

            fake = FakeHeatPump()
            previous = fake.read()
            supervisor = Supervisor(state, directory / 'recovery.json', adapter=fake,
                                    identity='offline-test-house-zone', requested=True)
            state.control = supervisor
            supervisor.claim_process()
            try:
                competitor = Supervisor(state, directory / 'recovery.json')
                try: competitor.claim_process()
                except RuntimeError: pass
                else: raise RuntimeError('Second process acquired the data directory')
                checked('Single-supervisor process exclusion')
                publish(3); checked('Hold band does not start heating', supervisor.step(now)['phase'] == 'no boost')
                publish(0); fake.server_expiry_verified = False
                checked('Missing native-expiry capability refuses even a fake start',
                        not supervisor.step(now)['control_enabled'] and not fake.writes)
                fake.server_expiry_verified = True
                checked('Free-power start in fake adapter', supervisor.step(now)['phase'] == 'boost started')
                checked('Recovery intent is private on disk', supervisor.journal.path.stat().st_mode & 0o777 == 0o600)
                publish(5); checked('Active permission holds at off-price boundary', supervisor.step(now)['phase'] == 'boost active')
                publish(5.01); checked('Above-off-price restores previous fake state',
                    supervisor.step(now)['phase'] == 'previous state restored' and fake.read() == previous)
                publish(0); supervisor.step(now); fake.room = saved['policy']['target_c']
                checked('Temperature target/limit stops fake heating', supervisor.step(now)['phase'] == 'previous state restored')
                fake.room = 19; supervisor.step(now); fake.observed = now - timedelta(seconds=121)
                checked('Stale sensor removes permission and restores', supervisor.step(now)['phase'] == 'previous state restored')
                publish(0); supervisor.step(now)
                with patch('controller.service.fetch_agile_prices', side_effect=TimeoutError): state.refresh()
                checked('Upstream API failure clears pricing and restores',
                    client.status()['stale'] and supervisor.step(now)['phase'] == 'previous state restored')
                publish(0); supervisor.step(now)
                checked('Expired price snapshot cannot sustain heating',
                    supervisor.step(now + timedelta(minutes=31))['phase'] == 'previous state restored')
                publish(0); supervisor.step(now); fake.fail_write = True; publish(6)
                checked('Failed restoration retains recovery journal', supervisor.step(now)['recovery_pending'])
                fake.fail_write = False
                restarted = Supervisor(state, supervisor.journal.path, adapter=fake,
                                       identity='offline-test-house-zone', requested=True)
                checked('Restart restores before considering another start',
                    restarted.step(now)['phase'] == 'previous state restored' and fake.read() == previous)
                state.control = restarted
                publish(0)
                original_write = fake.write
                def uncertain(*args):
                    original_write(*args)
                    raise TimeoutError('Simulated lost success response')
                fake.write = uncertain
                checked('Uncertain write is retained for reconciliation', restarted.step(now)['recovery_pending'])
                fake.write = original_write
                checked('Next check restores uncertain start first', restarted.step(now)['phase'] == 'previous state restored')
                restarted.step(now); fake.state = {'mode': 'occupant-choice'}
                checked('Manual change is preserved', restarted.step(now)['phase'] == 'external change preserved')
                again = Supervisor(state, restarted.journal.path, adapter=fake,
                                   identity='offline-test-house-zone', requested=True)
                checked('Manual hold survives restart', again.step(now)['phase'] == 'manual change hold')
                checked('Hot-water sentinel is unchanged', fake.hot_water == {'unchanged': True})
            finally:
                supervisor.process_lock.close()

            observation_config = {
                'HEATING_HOMELY_ENV_FILE': str(directory / 'unused.env'),
                'HEATING_HOMELY_PROFILE': 'Demo', 'HEATING_HOUSE_ID': 'fake-house',
                'HEATING_SENSOR_ZONE_ID': 'fake-sensor', 'HEATING_BOOST_ZONE_ID': '0',
                'HEATING_RECOVERY_FILE': str(directory / 'observed.json')}
            observed_supervisor = build_supervisor(State(directory/'observer'/'policy.json'), observation_config)
            observer = observed_supervisor.observer
            observer.client = Mock(house_id='fake-house', user_id='fake-user')
            observer.client.post.side_effect = [dict(hotWaterOnlyMode=True), [dict(
                id='fake-sensor', temperature=19.5, lastUpdated=int(now.timestamp() * 1000),
                heatingOn=False, nodeLost=False)]]
            state.control = observed_supervisor
            observed = observed_supervisor.step(now)['observation']
            checked('Optional observation is explicit and unverified for safety',
                    observed['sensor_candidate_fresh'] and not observed['sensor_contract_verified'])
            for action in (lambda: observer.set_disabled(False), observer.cancel_boost):
                try: action()
                except ControlUnavailable: pass
                else: raise RuntimeError('Production transport write gate was bypassed')
            checked('Observed mode/cancel transport is write-gated')
            # Fake transport only: demonstrate the prepared captured request shapes.
            observer.allow_writes = True
            observer.client.post.side_effect = None
            observer.client.post.return_value = {'settings': {'hotWaterOnlyMode': True}, 'schedules': {}}
            observer.set_disabled(True)
            observer.client.post.return_value = {'zoneId': '0', 'boostActive': False}
            observer.cancel_boost()
            checked('Prepared mode and cancellation payloads exercised on a mock only')
            observer.allow_writes = False
            orphan_path = directory / 'orphan.json'; orphan_path.write_text('unreadable old journal')
            orphan = Supervisor(state, orphan_path)
            checked('Orphan/corrupt recovery is retained without guessed writes',
                    orphan.step(now)['phase'] == 'recovery_required' and orphan_path.exists())
            show_status(client.status())
            restored = client.save(dict(revision=client.policy()['revision'], policy=baseline['policy']))
            checked('Original policy values restored through API', restored['policy'] == baseline['policy'])
            checked('Health-check HTTP route works independently of fresh prices',
                    client.status()['mode'] == 'plan_only')
            options = SimpleNamespace(url='https://offline.invalid', key_file=None,
                docker_container=None, write_policy=True, backup_file=str(directory / 'original-policy.json'),
                on_price=0, off_price=5, target=21, limit=22, samples=1, interval=0)
            with patch('heating_services.Client', return_value=client), patch.dict(
                    'os.environ', {'HOMELY_HEATING_TOKEN': key}):
                exercise_live(options)
            checked('Opt-in client saves a private backup and restores original values',
                    client.policy()['policy'] == baseline['policy']
                    and Path(options.backup_file).stat().st_mode & 0o777 == 0o600)

            class ConcurrentClient:
                def policy(self): return client.policy()
                def status(self): return client.status()
                def automation(self): return client.automation()
                def history(self, week=None): return client.history(week)
                def save(self, document):
                    result = client.save(document)
                    other = copy.deepcopy(result); other['policy']['off_price_p'] = 6
                    client.save(other)
                    return result
            options.backup_file = str(directory / 'concurrent-backup.json')
            preserved = False
            with patch('heating_services.Client', return_value=ConcurrentClient()), patch.dict(
                    'os.environ', {'HOMELY_HEATING_TOKEN': key}):
                try: exercise_live(options)
                except RuntimeError as exc: preserved = 'Another policy revision' in str(exc)
            checked('Opt-in restoration preserves a concurrent editor instead of overwriting',
                    preserved and client.policy()['policy']['off_price_p'] == 6)
            client.save(dict(revision=client.policy()['revision'], policy=baseline['policy']))

            class LostResponseClient:
                calls = 0
                def policy(self): return client.policy()
                def status(self): return client.status()
                def automation(self): return client.automation()
                def history(self, week=None): return client.history(week)
                def save(self, document):
                    self.calls += 1
                    client.save(document)
                    raise RuntimeError('simulated lost PUT response')
            lost = LostResponseClient(); options.backup_file = str(directory / 'uncertain-backup.json')
            uncertain = False
            with patch('heating_services.Client', return_value=lost), patch.dict(
                    'os.environ', {'HOMELY_HEATING_TOKEN': key}):
                try: exercise_live(options)
                except RuntimeError as exc: uncertain = 'simulated lost PUT' in str(exc)
            checked('Opt-in client never replays or guesses ownership of an uncertain save',
                    uncertain and lost.calls == 1 and Path(options.backup_file).exists())
            client.save(dict(revision=client.policy()['revision'], policy=baseline['policy']))

        finally:
            server.shutdown(); server.server_close(); thread.join(timeout=5)
    # Next actuator's price-only rules, separate from the legacy temperature fake.
    from controller.slot_policy import SlotPolicy
    policy = dict(on_price_p=0, off_price_p=5)
    def price_slot(at, price):
        return dict(start=at.isoformat(), end=(at+timedelta(minutes=30)).isoformat(), effective_price_p=price)
    planner = SlotPolicy()
    checked('Price-only: one boost permission at the half-hour boundary',
            planner.evaluate(start, price_slot(start, 0), policy, 1)['price_allowed'])
    checked('Price-only: forecast refresh cannot extend or restart the slot',
            planner.evaluate(start+timedelta(minutes=5), price_slot(start, 20), policy, 1)['slot_end'] == end.isoformat())
    checked('Price-only: permission holds at off threshold in following slot',
            planner.evaluate(end, price_slot(end, 5), policy, 1)['price_allowed'])
    after = end+timedelta(minutes=30)
    checked('Price-only: above-off price removes permission',
            not planner.evaluate(after, price_slot(after, 5.01), policy, 1)['price_allowed'])
    checked('Price-only: startup mid-slot waits for next boundary',
            not SlotPolicy().evaluate(start+timedelta(minutes=2), price_slot(start, 0), policy, 1)['price_allowed'])
    planner = SlotPolicy(); planner.evaluate(start, price_slot(start, 0), policy, 1)
    planner.evaluate(start+timedelta(seconds=5), None, policy, 1, stale=True)
    checked('Price-only: recovered API cannot restart within the failed slot',
            not planner.evaluate(start+timedelta(seconds=10), price_slot(start, 0), policy, 1)['price_allowed'])
    # Exercise the actual native driver + captured transport with a fake JSON API.
    from controller.slot_control import SlotSupervisor, installation_identity
    with tempfile.TemporaryDirectory(prefix='native-price-demo-') as native_directory:
        native_root = Path(native_directory)
        instant = [start]
        memory = dict(disabled=True, boost=None, writes=[])
        idle = [dict(zoneId=0, start=0, end=0, min=18, max=22, temperature=20)]
        schedules = dict(schedules=dict(heating=[], hotwater=[dict(unchanged=True)]))
        def customer(body):
            method, payload = body['method'], body.get('payload', {})
            if memory['boost'] and memory['boost']['end'] <= int(instant[0].timestamp()*1000):
                memory['boost'] = None
            if method == 'getSettings': return dict(hotWaterOnlyMode=memory['disabled'])
            if method == 'getAllSchedules': return copy.deepcopy(schedules)
            if method == 'getHeatingBoost': return [copy.deepcopy(memory['boost'])] if memory['boost'] else copy.deepcopy(idle)
            if method == 'getZones': return [dict(id='demo-sensor', temperature=20, lastUpdated=int(start.timestamp()*1000), heatingOn=not memory['disabled'], nodeLost=False)]
            memory['writes'].append(copy.deepcopy(body))
            if method == 'setSettings':
                assert set(payload) == {'hotWaterOnlyMode'}
                memory['disabled'] = payload['hotWaterOnlyMode']
                return dict(settings=dict(hotWaterOnlyMode=memory['disabled']), schedules=copy.deepcopy(schedules))
            if method == 'setHeatingBoost':
                if payload['status']:
                    memory['boost'] = dict(zoneId=0, end=payload['end'])
                    return dict(boostActive=True, zoneId='0', start=payload['start'], end=payload['end'])
                memory['boost'] = None
                return dict(boostActive=False, zoneId='0')
            raise AssertionError('Unexpected fake customer method')
        native_api = ObservedHomely('/unused', 'Demo', 'demo-house', 'demo-sensor', '0')
        native_api.client = Mock(house_id='demo-house', user_id='demo-user')
        native_api.client.post.side_effect = customer
        native_state = State(native_root/'policy.json')
        native_state.automation.save(True)
        draft = native_state.document(); draft['policy'].update(on_price_p=-5, off_price_p=-1)
        native_state.update(draft)
        proof = native_root/'native-expiry-proof.json'
        proof.write_text(json.dumps(dict(version=1, identity=installation_identity(native_api), native_expiry_records_verified=True, slot_seconds=1800)))
        def driver(active=True):
            return SlotSupervisor(native_state, native_root/'recovery.json', observer=native_api,
                requested=active, proof_path=proof, clock=lambda: instant[0])
        def native_publish(price):
            a = instant[0].replace(minute=instant[0].minute//30*30, second=0, microsecond=0)
            native_state.publish(native_state.revision, [dict(start=a.isoformat(), end=(a+timedelta(minutes=30)).isoformat(), effective_price_p=price)], instant[0])
        engine = driver(False); native_publish(-5)
        checked('Native driver: activation off forbids all writes even with proof', not engine.step()['control_enabled'] and not memory['writes'])
        engine = driver(); native_state.control = engine
        checked('Native driver: negative threshold enables and starts the bounded boost', engine.step()['phase'] == 'boost_active')
        request = next(v['payload'] for v in memory['writes'] if v['method']=='setHeatingBoost')
        checked('Native driver: exact captured payload contains no temperature', set(request)=={'status','start','end','zoneId'} and request['end']==int(end.timestamp()*1000))
        n = len(memory['writes']); instant[0] += timedelta(minutes=5); native_publish(50)
        checked('Native driver: no second write inside a slot', engine.step()['phase']=='boost_active' and len(memory['writes'])==n)
        instant[0] = end; native_publish(-1)
        checked('Native driver: native expiry followed by one hold-band renewal', engine.step()['phase']=='boost_active' and memory['boost']['end']==int((end+timedelta(minutes=30)).timestamp()*1000))
        instant[0] += timedelta(minutes=30); native_publish(0)
        checked('Native driver: above negative off threshold disables normal heating', engine.step()['phase']=='heating_off' and memory['disabled'])
        instant[0] += timedelta(minutes=30); native_publish(-5); engine.step()
        engine = driver(); native_state.control = engine
        checked('Native driver: restart reconciles before considering another start', engine.step()['phase']=='heating_off' and memory['disabled'] and memory['boost'] is None)
        memory['disabled'] = False; instant[0] += timedelta(seconds=1); native_publish(-5)
        checked('Native driver: external mode change creates a manual hold', engine.step()['phase']=='manual_change_hold' and not memory['disabled'])
        engine = driver(); native_state.control = engine
        checked('Native driver: manual hold survives restart', engine.step()['phase']=='manual_change_hold')
        checked('Native driver: hot-water schedule untouched', schedules['schedules']['hotwater']==[dict(unchanged=True)])
        checked('Native driver: signed policy values persist', State(native_root/'policy.json').document()['policy']['on_price_p']==-5)
        native_state.update_automation(dict(enabled=False)); instant[0] += timedelta(seconds=1); native_publish(-5)
        checked('Native driver: app OFF cancels policy heating and disables mode', engine.step()['phase']=='automation_off' and memory['disabled'])
        checked('Native driver: app OFF survives storage reload', not State(native_root/'policy.json').automation.load()['enabled'])
        memory['disabled']=False; n=len(memory['writes']); instant[0] += timedelta(seconds=1)
        checked('Native driver: paused automation leaves later manual heating alone', engine.step()['phase']=='automation_off' and len(memory['writes'])==n and not memory['disabled'])
        native_state.update_automation(dict(enabled=True)); instant[0] += timedelta(seconds=1); native_publish(-5)
        checked('Native driver: explicit re-enable waits for next boundary', engine.step()['phase']=='heating_off' and memory['disabled'])
        engine.store.path.write_text('corrupt ledger'); before = len(memory['writes'])
        checked('Native driver: corrupt intent is retained without guessed writes', engine.step()['phase']=='recovery_required' and engine.store.path.read_text()=='corrupt ledger' and len(memory['writes'])==before)
    print('\nOffline demo completed:', len(checks), 'checks; no cloud request or physical heating command sent.')
    print('For actual Docker health/restart/isolation, add --docker-container (and optional --ssh-target).')
