"""Always-running effective-price API and gated heating supervisor."""
from __future__ import annotations
import copy
import hmac
import json
import math
import os
from pathlib import Path
import tempfile
import threading
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from zoneinfo import ZoneInfo
from urllib.parse import urlsplit,parse_qs

from homely import direct_session, fetch_agile_prices
from controller.automation import AutomationStore
from controller.history import History,HistoryUnavailable

UTC = timezone.utc
LONDON = ZoneInfo('Europe/London')
DEFAULT = dict(on_price_p=0.0, off_price_p=0.0, target_c=21.0, limit_c=22.0,
               product='', tariff='', latitude=54.0, longitude=-2.0,
               array_kwp=5.0, loss_percent=15.0, inverter_kw=5.0, load_kw=3.0)


def validate_policy(value):
    if not isinstance(value, dict) or set(value) != set(DEFAULT):
        raise ValueError('Policy must contain exactly the documented settings')
    result = dict(value)
    for key in set(DEFAULT) - {'product', 'tariff'}:
        if isinstance(value[key], bool) or not isinstance(value[key], (float, int)) or not math.isfinite(value[key]):
            raise ValueError(f'{key} must be a finite number')
    if result['off_price_p'] < result['on_price_p']:
        raise ValueError('Off price must be at least the on price')
    if not 5 <= result['target_c'] <= result['limit_c'] <= 25:
        raise ValueError('Require 5 <= target <= room limit <= 25 C')
    for key, low, high in [('latitude',-90,90),('longitude',-180,180),('array_kwp',0,1000),
                          ('loss_percent',0,100),('inverter_kw',0,1000),('load_kw',0.01,1000)]:
        if not low <= result[key] <= high:
            raise ValueError(f'{key} is out of range')
    # Empty tariff is an explicit unconfigured state, never a guessed tariff.
    product, tariff = result['product'], result['tariff']
    if not isinstance(product, str) or not isinstance(tariff, str):
        raise ValueError('Product and tariff must be text')
    if product or tariff:
        if (not product.startswith('AGILE-') or not tariff.startswith(f'E-1R-{product}-')
            or len(tariff) != len(f'E-1R-{product}-')+1
            or any(c not in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-' for c in product+tariff)):
            raise ValueError('Use matching Agile import product and single-rate tariff codes')
    return result


def effective_prices(rates, radiation, policy):
    """Same load/PV/loss/inverter formula as AgilePriceWheel Net price."""
    output=[]
    for rate in rates:
        start=rate['start'].astimezone(UTC)
        end=rate['end'].astimezone(UTC)
        price=float(rate['price'])
        ghi=float(radiation[start])  # Missing sample fails; never assume free solar.
        if not math.isfinite(price) or not math.isfinite(ghi):
            raise ValueError('Invalid price or solar forecast')
        hours=(end-start).total_seconds()/3600
        if hours != 0.5:
            raise ValueError('Expected half-hour prices')
        pv_power=policy['array_kwp'] * max(ghi,0)/1000 * (1-policy['loss_percent']/100)
        if policy['inverter_kw'] > 0:
            pv_power=min(pv_power,policy['inverter_kw'])
        pv=pv_power*hours
        load=policy['load_kw']*hours
        grid=max(load-pv,0)
        output.append(dict(start=start.isoformat(), end=end.isoformat(),
                           agile_price_p=price, effective_price_p=grid*price/load,
                           pv_kwh=pv, grid_kwh=grid))
    return output



def validate_published_prices(rates, day, tz, now):
    """Require an unbroken local-day prefix covering now; allow only a future tail.

    Octopus publication windows need not reach local midnight. An unpublished
    later interval must not invalidate a valid current price. Never fill gaps.
    """
    if now.tzinfo is None or now.utcoffset() is None:
        raise ValueError('Aware current timestamp required')
    beginning=datetime.combine(day,datetime.min.time(),tz).astimezone(UTC)
    boundary=datetime.combine(day+timedelta(days=1),datetime.min.time(),tz).astimezone(UTC)
    now=now.astimezone(UTC)
    if not beginning <= now < boundary:
        raise ValueError('Price date must be the current local day')
    ordered=sorted(rates,key=lambda r:r['start'].astimezone(UTC))
    cursor=beginning
    for rate in ordered:
        a,b=rate['start'],rate['end']
        if a.tzinfo is None or b.tzinfo is None:
            raise ValueError('Aware price timestamps required')
        a,b=a.astimezone(UTC),b.astimezone(UTC)
        if a != cursor or b-a != timedelta(minutes=30) or b > boundary:
            raise ValueError('Agile prices contain a missing, duplicate or overlapping period')
        if not math.isfinite(float(rate['price'])):
            raise ValueError('Invalid Agile price')
        cursor=b
    if cursor <= now:
        raise ValueError('Published Agile prices do not include the current period')
    return ordered


def fetch_controller_prices(product, tariff, day, tz, now=None):
    rates=fetch_agile_prices(product,tariff,day,tz,require_complete_day=False)
    return validate_published_prices(rates,day,tz,now or datetime.now(UTC))


def fetch_radiation(policy, day, rates):
    if not rates: raise ValueError('No price periods for solar forecast')
    first=min(r['start'].astimezone(UTC) for r in rates)
    last=max(r['end'].astimezone(UTC) for r in rates)-timedelta(minutes=15)
    session=direct_session()
    response=session.get('https://api.open-meteo.com/v1/forecast',params=dict(
        latitude=policy['latitude'],longitude=policy['longitude'],
        minutely_15='shortwave_radiation',timezone='UTC',timeformat='unixtime',
        start_minutely_15=first.strftime('%Y-%m-%dT%H:%M'),
        end_minutely_15=last.strftime('%Y-%m-%dT%H:%M')),timeout=30)
    response.raise_for_status()
    data=response.json()['minutely_15']
    times,values=data['time'],data['shortwave_radiation']
    if len(times)!=len(values) or len(set(times))!=len(times):
        raise ValueError('Invalid solar samples')
    samples={datetime.fromtimestamp(t,UTC):v for t,v in zip(times,values)}
    result={}
    for rate in rates:
        start=rate['start'].astimezone(UTC)
        a,b=samples[start],samples[start+timedelta(minutes=15)]
        if a is None or b is None or not math.isfinite(float(a)) or not math.isfinite(float(b)):
            raise ValueError('Missing/invalid solar forecast')
        result[start]=(max(float(a),0)+max(float(b),0))/2
    return result


class Conflict(Exception): pass


class State:
    def __init__(self, path):
        self.path=Path(path)
        self.automation=AutomationStore(self.path.with_name('automation.json'))
        self.history=History(self.path.with_name('heating-history.sqlite3'))
        self.lock=threading.Lock()
        self.control_lock=threading.RLock()
        self.control_wake=threading.Event()
        self.control=None
        self.wake=threading.Event()
        self.revision=0
        self.policy=dict(DEFAULT)
        if self.path.exists():
            record=json.loads(self.path.read_text())
            self.policy=validate_policy(record['policy'])
            self.revision=int(record['revision'])
        self.snapshot=None
        self.error='Waiting for first price and forecast refresh'
        self.demand=False
        self.error_stage=None

    def document(self):
        with self.lock:
            return dict(revision=self.revision,policy=copy.deepcopy(self.policy))

    def update(self, document):
        with self.control_lock:
            return self._update(document)

    def _update(self, document):
        if not isinstance(document,dict) or set(document)!={'revision','policy'}:
            raise ValueError('Expected revision and policy')
        policy=validate_policy(document['policy'])
        with self.lock:
            if type(document['revision']) is not int or document['revision']!=self.revision:
                raise Conflict('Policy changed. Reload it before saving.')
            record=dict(revision=self.revision+1,policy=policy)
            self.path.parent.mkdir(parents=True,exist_ok=True)
            fd,name=tempfile.mkstemp(dir=self.path.parent)
            try:
                with os.fdopen(fd,'w') as handle:
                    json.dump(record,handle,allow_nan=False)
                    handle.flush(); os.fsync(handle.fileno())
                os.replace(name,self.path)
                directory=os.open(self.path.parent,os.O_RDONLY)
                try: os.fsync(directory)
                finally: os.close(directory)
            finally:
                if os.path.exists(name): os.unlink(name)
            self.policy=policy; self.revision=record['revision']
            self.snapshot=None; self.demand=False
            self.error='Policy changed; refreshing prices and forecast'
            self.error_stage=None
        self.wake.set()
        self.control_wake.set()
        return record

    def automation_document(self):
        try:record=self.automation.load();error=None
        except (ValueError,OSError):record=dict(revision=0,enabled=False);error='Saved automation state needs an OFF request to repair it.'
        control=self.control
        can_enable=bool(error is None and control is not None and hasattr(control,'can_activate') and control.can_activate())
        status=control.status() if control is not None else {}
        return dict(record,can_enable=can_enable,shutdown_pending=bool(status.get('shutdown_pending',False) or (not record['enabled'] and record['revision']>status.get('automation_applied_revision',0))),
                    phase=status.get('phase','unavailable'),error=error)

    def history_document(self,week=None,now=None):
        result=self.history.week(week,now)
        control=self.control.status() if self.control is not None else {}
        result['pending_events']=control.get('history_pending_events',0)
        result['warning']=control.get('history_error')
        return result

    def update_automation(self,document):
        if not isinstance(document,dict) or set(document)!={'enabled'} or type(document['enabled']) is not bool:
            raise ValueError('Expected a boolean enabled field')
        if not document['enabled']:
            # Persist stop intent without waiting behind a slow Homely RPC tick.
            # The worker reconciles in-flight work; pending never means stopped.
            self.automation.save(False)
            self.control_wake.set()
            return self.automation_document()
        with self.control_lock:
            if document['enabled'] and not self.automation_document()['can_enable']:
                raise Conflict('Automatic heating has not been activated for this controller')
            self.automation.save(document['enabled'])
            self.control_wake.set()
            return self.automation_document()

    def publish(self, revision, slots, now):
        with self.lock:
            if revision!=self.revision: return
            self.snapshot=dict(updated_at=now.isoformat(),slots=slots)
            self.error=None
            self.error_stage=None

    def status(self, now=None):
        now=now or datetime.now(UTC)
        with self.lock:
            snapshot=self.snapshot
            stale=snapshot is None
            # Use numeric comparison: timestamps may have subsecond differences.
            if snapshot:
                age=(now-datetime.fromisoformat(snapshot['updated_at'])).total_seconds()
                stale=not 0 <= age <= 900
            current=None if stale else next((s for s in snapshot['slots'] if datetime.fromisoformat(s['start'])<=now<datetime.fromisoformat(s['end'])),None)
            if current is None: self.demand=False
            else:
                threshold=self.policy['off_price_p'] if self.demand else self.policy['on_price_p']
                self.demand=current['effective_price_p']<=threshold
            slots=snapshot['slots'] if snapshot else []
            day=now.astimezone(LONDON).date()
            beginning=datetime.combine(day,datetime.min.time(),LONDON).astimezone(UTC)
            boundary=datetime.combine(day+timedelta(days=1),datetime.min.time(),LONDON).astimezone(UTC)
            complete=bool(slots and datetime.fromisoformat(slots[0]['start'])==beginning
                          and datetime.fromisoformat(slots[-1]['end'])==boundary)
            result=dict(control_enabled=False, mode='plan_only', revision=self.revision,
                        price_basis='agile_plus_forecast_pv', stale=stale or current is None,
                        price_requests_heat=self.demand, current=current,
                        updated_at=snapshot['updated_at'] if snapshot else None,
                        slots=slots, error=self.error, error_stage=self.error_stage,
                        price_day_complete=complete,
                        price_coverage_end=slots[-1]['end'] if slots else None,
                        message='Live heating disabled. Price decision only; room temperature and heating state are unverified.')
        if current is not None and not complete:
            result['message']='Live heating disabled. Current published prices are usable; later prices are not yet available for the full local day.'
        if self.control is not None:
            result['heating_control']=self.control.status()
            result['control_enabled']=result['heating_control']['control_enabled']
            decision=result['heating_control'].get('slot_decision')
            if decision is not None:
                try:
                    current_decision=(decision['policy_revision']==result['revision']
                        and datetime.fromisoformat(decision['slot_start'])<=now<datetime.fromisoformat(decision['slot_end'])
                        and not result['stale'])
                except (KeyError,ValueError,TypeError):current_decision=False
                result['price_requests_heat']=bool(current_decision and decision['price_allowed'])
                result['slot_decision']=decision
            if result['control_enabled']:
                result['mode']='automatic'
                result['message']='Heating supervised by half-hour effective-price policy using existing Homely temperature settings.'
        result['automation']=self.automation_document()
        if self.control is not None and hasattr(self.control,'can_activate') and not result['automation']['enabled']:
            result['control_enabled']=False;result['mode']='plan_only';result['price_requests_heat']=False
        return result

    def refresh(self):
        record=self.document(); policy=record['policy']
        stage='configuration'
        try:
            if not policy['product']: raise ValueError('Unconfigured tariff')
            day=datetime.now(LONDON).date()
            stage='agile_prices'
            rates=fetch_controller_prices(policy['product'],policy['tariff'],day,LONDON)
            stage='solar_forecast'
            radiation=fetch_radiation(policy,day,rates)
            stage='effective_price'
            slots=effective_prices(rates,radiation,policy)
            self.publish(record['revision'],slots,datetime.now(UTC))
            self.status()  # Evaluate even with no app connected.
            self.control_wake.set()
        except Exception:
            with self.lock:
                if record['revision']==self.revision:
                    self.snapshot=None; self.demand=False
                    self.error_stage=stage
                    self.error={
                        'configuration': "No Agile tariff is saved. Choose Use this app's tariff, solar site and PV settings, then save the policy.",
                        'agile_prices': 'Could not refresh valid published Agile prices covering the current period. No heating request.',
                        'solar_forecast': 'Could not refresh all solar forecast samples needed for the published prices. No heating request.',
                        'effective_price': 'Could not calculate valid effective electricity prices. No heating request.'
                    }[stage]
            self.control_wake.set()

    def worker(self):
        while True:
            self.wake.clear()
            self.refresh()
            self.wake.wait(60)


def handler_for(state, token):
    class Handler(BaseHTTPRequestHandler):
        server_version='HeatingController'
        def log_message(self,*args): pass  # Do not log tokens, policy or coordinates.
        def reply(self,status,body):
            data=json.dumps(body,allow_nan=False).encode()
            self.send_response(status)
            self.send_header('Content-Type','application/json')
            self.send_header('Content-Length',str(len(data)))
            self.send_header('Cache-Control','no-store')
            self.end_headers(); self.wfile.write(data)
        def authorized(self):
            if not hmac.compare_digest(self.headers.get('Authorization',''),f'Bearer {token}'):
                self.reply(401,dict(error='Authentication required')); return False
            return True
        def do_GET(self):
            if not self.authorized(): return
            if self.path=='/v1/status': self.reply(200,state.status())
            elif self.path=='/v1/policy': self.reply(200,state.document())
            elif self.path=='/v1/automation': self.reply(200,state.automation_document())
            elif urlsplit(self.path).path=='/v1/history':
                try:
                    parts=urlsplit(self.path)
                    if parts.scheme or parts.netloc or parts.fragment:raise ValueError('Invalid history path')
                    query=parse_qs(parts.query,keep_blank_values=True,strict_parsing=True)
                    if set(query)-{'week'} or ('week' in query and len(query['week'])!=1):raise ValueError('Use one optional week date')
                    self.reply(200,state.history_document(query.get('week',[None])[0]))
                except ValueError as error:self.reply(400,dict(error=str(error)))
                except HistoryUnavailable:self.reply(503,dict(error='Heating history is temporarily unavailable'))
            else: self.reply(404,dict(error='Not found'))
        def do_PUT(self):
            if not self.authorized(): return
            if self.path not in ('/v1/policy','/v1/automation'): self.reply(404,dict(error='Not found')); return
            try:
                size=int(self.headers.get('Content-Length','0'))
                if not 0<size<=16384: raise ValueError('Invalid request size')
                self.connection.settimeout(10)
                document=json.loads(self.rfile.read(size))
                self.reply(200,state.update_automation(document) if self.path=='/v1/automation' else state.update(document))
            except Conflict as exc: self.reply(409,dict(error=str(exc)))
            except (ValueError,KeyError,TypeError) as exc: self.reply(400,dict(error=str(exc)))
            except Exception: self.reply(500,dict(error='Policy could not be saved'))
    return Handler


def main():
    token=os.environ.get('HEATING_API_TOKEN','')
    if len(token)<32: raise SystemExit('Set HEATING_API_TOKEN to at least 32 random characters')
    state=State(os.environ.get('HEATING_POLICY_FILE','/data/policy.json'))
    from controller.heating import build_supervisor
    state.control=build_supervisor(state,os.environ)
    state.control.claim_process()
    try:state.history.initialize()
    except HistoryUnavailable:pass  # Logging availability must not stop heating control.
    state.control.step()
    threading.Thread(target=state.control.worker,daemon=True).start()
    threading.Thread(target=state.worker,daemon=True).start()
    server=ThreadingHTTPServer(('0.0.0.0',8080),handler_for(state,token))
    server.daemon_threads=True
    server.serve_forever()


if __name__=='__main__': main()
