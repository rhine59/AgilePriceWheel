#!/usr/bin/env python3
"""Prepare/review a specifically approved short boost-target test.

Default shows help. prepare/verify-restored are read-only Homely operations.
run/stop require --approved-live after the human approves the specific test.
No schedule setter exists here: the user adds/removes the test period in Homely.
"""
import argparse,copy,json,math,os,sys,threading,time
from datetime import datetime,timezone
from pathlib import Path
from zoneinfo import ZoneInfo
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from controller.boost_target_probe import probe,inactive
from controller.heating import ObservedHomely,SafeClient
from heating_services import Client
UTC=timezone.utc;LONDON=ZoneInfo('Europe/London')


def save_new(path,value):
    fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(fd,'w') as f:json.dump(value,f,allow_nan=False,indent=2);f.flush();os.fsync(f.fileno())


class Trace:
    def __init__(self,path):self.path=path;self.lock=threading.Lock()
    def write(self,value):
        data=json.dumps(value,allow_nan=False)+'\n'
        with self.lock:
            fd=os.open(self.path,os.O_WRONLY|os.O_CREAT|os.O_APPEND,0o600)
            with os.fdopen(fd,'a') as f:f.write(data);f.flush();os.fsync(f.fileno())


class RecordedClient(SafeClient):
    def __init__(self,client,trace):
        super().__init__(client.access_token)
        self.house_id=client.house_id;self.user_id=client.user_id;self.trace=trace
    def post(self,body):
        at=datetime.now(UTC).isoformat();started=time.monotonic()
        try:
            result=super().post(body)
        except Exception:
            self.trace.write(dict(at=at,elapsed=time.monotonic()-started,request=body,outcome='uncertain'))
            raise
        self.trace.write(dict(at=at,elapsed=time.monotonic()-started,request=body,response=result))
        return result


class Adapter:
    def __init__(self,args,installation,trace,original=None):
        if args.local_controller and args.controller_url!='http://127.0.0.1:8080':
            raise ValueError('Local mode is restricted to this container loopback API')
        self.args=args;self.installation=installation;self.trace=trace;self.original=original
        self.zone_id=installation['boost_zone_id']
        self.observer=ObservedHomely(args.homely_env_file,installation['profile'],installation['house_id'],installation['sensor_zone_id'],self.zone_id,allow_writes=False)
        client=self.observer.connect()  # Validates the configured household.
        self.observer.client=RecordedClient(client,trace)
        self.stop_lock=threading.Lock()
        self.stopper=ObservedHomely(args.homely_env_file,installation['profile'],installation['house_id'],installation['sensor_zone_id'],self.zone_id,allow_writes=False)
        self.stopper.allow_stop=True
        self.stopper.client=RecordedClient(client,trace)
        self.api=Client(args.controller_url,Path(args.key_file).read_text().strip(),demo=args.local_controller)
    def context(self):
        policy=self.api.policy();switch=self.api.automation();status=self.api.status();h=status.get('heating_control',{})
        stamp=datetime.fromisoformat(h['last_checked_at'].replace('Z','+00:00'))
        if not (h.get('manual_hold') is True and not h.get('recovery_pending') and h.get('error') is None
                and 0<=(datetime.now(UTC)-stamp).total_seconds()<=45):
            raise ValueError('A fresh settled manual hold is required')
        return dict(policy=policy,switch={k:switch[k] for k in ('revision','enabled')})
    def snapshot(self):
        return dict(settings=self.observer.call('getSettings'),schedules=self.observer.call('getAllSchedules'),boost=self.read_boost())
    def context_unchanged(self):
        if self.context()!=self.original['context']:raise ValueError('Policy or automation changed')
    def note(self,event,**fields):
        if event=='armed':
            save_new(self.args.state_file.with_name(self.args.state_file.stem+'-attempt.json'),
                     dict(at=datetime.now(UTC).isoformat(),scope='one specifically approved probe',**fields))
        self.trace.write(dict(at=datetime.now(UTC).isoformat(),event=event,**fields))
    def preflight(self):
        self.context_unchanged();current=self.snapshot();before=self.original['baseline']
        if current['settings'].get('hotWaterOnlyMode') is not True or not inactive(current['boost']):raise ValueError('Heating must be disabled with no boost')
        old=before['schedules']['schedules']['heating'];new=current['schedules']['schedules']['heating'];sid=self.installation['schedule_id']
        a=[s for s in old if s['id']==sid];b=[s for s in new if s['id']==sid]
        if len(a)!=1 or len(b)!=1:raise ValueError('Selected schedule missing')
        old_ids={r['id'] for r in a[0]['data']};added=[r for r in b[0]['data'] if r['id'] not in old_ids]
        if len(added)!=1:raise ValueError('Expected exactly one user-added period')
        row=added[0];now=datetime.now(LONDON);minute=now.hour*60+now.minute
        if not (row['weekdayId']==now.weekday() and row['temperature']==22 and row['start']<=minute<row['end']
                and row['end']-row['start']>=60 and row['end']-minute>=3):raise ValueError('A one-hour 22 C period must cover the test time with at least three minutes remaining')
        if dict(b[0],data=[r for r in b[0]['data'] if r['id'] in old_ids])!=a[0]:raise ValueError('Original entries changed')
        if [s for s in new if s['id']!=sid]!=[s for s in old if s['id']!=sid]:raise ValueError('Other schedule changed')
        for group in ('hotwater','water'):
            if before['schedules']['schedules'].get(group)!=current['schedules']['schedules'].get(group):raise ValueError('Hot-water schedule changed')
        zones=self.observer.call('getZones');matches=[z for z in zones if z.get('id')==self.installation['sensor_zone_id']]
        if len(matches)!=1:raise ValueError('Temperature zone unavailable')
        zone=matches[0];temp=zone.get('temperature');stamp=zone.get('lastUpdated')
        if (type(temp) not in (int,float) or not math.isfinite(temp) or not -30<=temp<22
                or type(stamp) not in (int,float) or not math.isfinite(stamp) or zone.get('nodeLost') is not False
                or not 0<=datetime.now(UTC).timestamp()-stamp/1000<=120):raise ValueError('Require a candidate room reading below22C and no more than120seconds old')
        self.prepared=current;self.note('preflight',room_c=temp,reading_at=stamp)
    def is_disabled(self):return self.observer.call('getSettings')['hotWaterOnlyMode']
    def read_boost(self):return self.observer.call('getHeatingBoost')
    def enable(self):self.observer.allow_writes=True;return self.observer.set_disabled(False)
    def start(self,first,last):return self.observer.start_boost(first,last)
    def cancel(self):return self.observer.cancel_boost()
    def stop_only(self):
        # Independent session; its gate cannot enable or start anything. This
        # also lets the watchdog stop while the main request is waiting.
        # This separate observer retains/re-authenticates its own stop-only
        # session even when an uncertain main write clears observer.client.
        with self.stop_lock:
            errors=[]
            for action in (lambda:self.stopper.set_disabled(True),self.stopper.cancel_boost):
                try:action()
                except Exception:errors.append(True)
            if errors:raise RuntimeError('Stop readback needs reconciliation')



def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('command',choices=['prepare','run','stop','verify-restored'])
    p.add_argument('--state-file',type=Path,required=True)
    p.add_argument('--installation-file',type=Path,required=True)
    p.add_argument('--homely-env-file',type=Path,required=True)
    p.add_argument('--controller-url',required=True)
    p.add_argument('--key-file',type=Path,required=True)
    p.add_argument('--local-controller',action='store_true',help='Inside the NAS container only: fixed http://127.0.0.1:8080 context checks; no external HTTP')
    p.add_argument('--approved-live',action='store_true')
    if argv is None and len(sys.argv)==1:p.print_help();return 0
    args=p.parse_args(argv)
    if args.command in ('run','stop') and not args.approved_live:p.error('Specific human approval plus --approved-live is required before heating writes')
    installation=json.loads(args.installation_file.read_text())
    trace=Trace(args.state_file.with_name(args.state_file.stem+'-'+datetime.now(UTC).strftime('%Y%m%dT%H%M%S%f')+'.jsonl'))
    original=None if args.command=='prepare' else json.loads(args.state_file.read_text())
    if original is not None and original['installation']!=installation:raise ValueError('Installation changed')
    if args.command=='run' and args.state_file.with_name(args.state_file.stem+'-attempt.json').exists():
        raise ValueError('This approved probe attempt was already armed; reconcile, never replay')
    a=Adapter(args,installation,trace,original)
    if args.command=='prepare':
        context=a.context();snapshot=a.snapshot()
        if snapshot['settings']['hotWaterOnlyMode'] is not True or not inactive(snapshot['boost']):raise ValueError('Baseline must have heating disabled/no boost')
        zones=a.observer.call('getZones')
        save_new(args.state_file,dict(at=datetime.now(UTC).isoformat(),installation=installation,context=context,baseline=snapshot,zones=zones))
        matches=[z for z in zones if z.get('id')==installation['sensor_zone_id']]
        candidate=None
        if len(matches)==1:
            z=matches[0];stamp=z.get('lastUpdated')
            candidate=dict(room_c=z.get('temperature'),age_seconds=round(datetime.now(UTC).timestamp()-stamp/1000,1) if type(stamp) in (int,float) else None,node_lost=z.get('nodeLost'))
        print(json.dumps(dict(private_baseline_saved=True,no_heating_controls_changed=True,candidate_room_reading=candidate)));return 0
    if args.command=='run':
        age=(datetime.now(UTC)-datetime.fromisoformat(original['at'])).total_seconds()
        if not 0<=age<=1800:raise ValueError('Prepare a fresh baseline before the approved test')
        result=probe(a,authorised=True,maximum_seconds=60)
        save_new(args.state_file.with_name(args.state_file.stem+'-result.json'),result)
        print(json.dumps(result));return 0 if result['stop_confirmed'] and result['boost_readback_verified'] and result['error'] is None and not result['trace_error'] else 1
    if args.command=='stop':
        a.stop_only();stopped=a.is_disabled() is True and inactive(a.read_boost())
        print(json.dumps(dict(stop_confirmed=stopped)));return 0 if stopped else 1
    current=a.snapshot();before=original['baseline'];a.context_unchanged()
    weekly=current['schedules']['schedules']['heating']==before['schedules']['schedules']['heating']
    water=all(current['schedules']['schedules'].get(k)==before['schedules']['schedules'].get(k) for k in ('hotwater','water'))
    water=water and all(current['settings'].get(k)==v for k,v in before['settings'].items() if k.lower().startswith(('hw','dhw')) or k=='hasWater')
    result=dict(heating_disabled=current['settings']['hotWaterOnlyMode'] is True,no_timed_boost=inactive(current['boost']),weekly_schedule_restored=weekly,hot_water_preserved=water,other_settings_preserved=all(current['settings'].get(k)==v for k,v in before['settings'].items() if k not in ('hotWaterOnlyMode','hubData')),policy_and_switch_unchanged=True)
    trace.write(dict(event='restoration_readback',result=result));print(json.dumps(result));return 0 if all(result.values()) else 1


if __name__=='__main__':
    try:raise SystemExit(main())
    except (ValueError,OSError,RuntimeError,KeyError,TypeError) as error:
        print('Test not completed: '+type(error).__name__+'. No automatic start retry; inspect the private trace and restore/verify the test period.',file=sys.stderr)
        raise SystemExit(1)
