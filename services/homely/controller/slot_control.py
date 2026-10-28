"""Price-only native boost driver. Starts require activation, proof and app ON.
Explicit authenticated app OFF has separate, strictly scoped stop-only permission.

Homely supplies no conditional-write token. Read-before-write comparisons reduce,
but cannot eliminate, races with its app. Unexpected changes cause a durable hold.
"""
from __future__ import annotations
import copy
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import tempfile
import time
import uuid
from controller.history import iso

from controller.heating import Supervisor, ControlUnavailable
from controller.slot_policy import SlotPolicy, timestamp
UTC=timezone.utc


def installation_identity(observer):
    values=[observer.profile,observer.house_id,observer.boost_zone_id]
    return hashlib.sha256(json.dumps(values,separators=(',',':')).encode()).hexdigest()


class Store:
    def __init__(self,path,identity):self.path,self.identity=Path(path),identity
    def fresh(self):return dict(version=1,identity=self.identity,lease=None,hold=False,last=None,revision=None)
    def load(self):
        if not self.path.exists():return self.fresh()
        d=json.loads(self.path.read_text())
        if (not isinstance(d,dict) or d.get('version')!=1 or d.get('identity')!=self.identity
            or not {'lease','hold','last','revision'}<=d.keys() or type(d['hold']) is not bool):
            raise ValueError('Invalid control ledger')
        for key in ('automation_revision','automation_applied_revision'):
            if key in d and (type(d[key]) is not int or d[key]<0):raise ValueError('Invalid automation revision')
        if d['lease'] is not None:
            lease=d['lease']
            if not isinstance(lease,dict):raise ValueError('Invalid lease')
            if not {'stage','end_ms','slot_start','baseline','idle'}<=lease.keys():raise ValueError('Invalid lease')
            if type(lease['end_ms']) is not int or lease['stage'] not in {'enable_intent','start_intent','active','stop_intent'}:raise ValueError('Invalid lease')
        return d
    def save(self,d):
        self.path.parent.mkdir(parents=True,exist_ok=True)
        fd,name=tempfile.mkstemp(dir=self.path.parent)
        try:
            with os.fdopen(fd,'w') as f:json.dump(d,f,allow_nan=False);f.flush();os.fsync(f.fileno())
            os.replace(name,self.path)
            fd=os.open(self.path.parent,os.O_RDONLY)
            try:os.fsync(fd)
            finally:os.close(fd)
        finally:
            if os.path.exists(name):os.unlink(name)


def control_snapshot(api):
    settings=api.call('getSettings');schedules=api.call('getAllSchedules');boost=api.call('getHeatingBoost')
    if (not isinstance(settings,dict) or type(settings.get('hotWaterOnlyMode')) is not bool
        or not isinstance(schedules,dict) or not isinstance(schedules.get('schedules'),dict)
        or not isinstance(boost,list)):
        raise ControlUnavailable('Unexpected control state')
    # Exclude hot-water schedules/settings and hub metadata from manual-change
    # detection. They are neither owned nor written by the space-heating driver.
    heating_settings={k:v for k,v in settings.items() if k not in {'hotWaterOnlyMode','hasWater','hubData'} and not k.lower().startswith(('hw','dhw'))}
    heating_schedules={k:v for k,v in schedules['schedules'].items() if k not in {'hotwater','water'}}
    for row in boost:
        if not isinstance(row,dict) or type(row.get('end')) is not int or type(row.get('zoneId')) not in (int,str):
            raise ControlUnavailable('Unexpected boost state')
        if set(row)!={'zoneId','end'} and not {'start','end','zoneId','min','max','temperature'}<=row.keys():
            raise ControlUnavailable('Unknown boost response shape')
    return dict(disabled=settings['hotWaterOnlyMode'],settings=heating_settings,schedules=heating_schedules,boost=boost)


def inactive(snapshot):
    # Do not commandeer even an expired unknown timed record. The observed idle
    # variant has full override fields (or an empty array). Those existing
    # temperature overrides are preserved; they are not themselves a timed boost.
    return all('start' in r for r in snapshot['boost'])


def owned(snapshot,lease,zone):
    rows=snapshot['boost']
    return (len(rows)==1 and set(rows[0])=={'zoneId','end'}
            and str(rows[0]['zoneId'])==zone and rows[0]['end']==lease['end_ms'])


def same_strategy(a,b):return a['settings']==b['settings'] and a['schedules']==b['schedules']


class SlotSupervisor(Supervisor):
    def __init__(self,state,journal_path,*,observer=None,requested=False,proof_path=None,clock=None):
        super().__init__(state,journal_path,observer=observer,requested=requested)
        self.clock=clock or (lambda:datetime.now(UTC))
        self.planner=SlotPolicy()
        self.store=Store(Path(journal_path).with_suffix('.slot.json'),installation_identity(observer) if observer else 'unconfigured')
        self.proof_path=Path(proof_path) if proof_path else Path(journal_path).with_name('native-expiry-proof.json')
        self.first_tick=True

    def verified(self):
        try:
            p=json.loads(self.proof_path.read_text())
            return (p.get('version')==1 and p.get('identity')==self.store.identity
                    and p.get('native_expiry_records_verified') is True and p.get('slot_seconds')==1800)
        except (OSError,ValueError,TypeError,AttributeError):return False

    def can_activate(self):
        try:
            d=self.store.load()
            settled=d['lease'] is None or d['lease']['stage']=='active'
        except (ValueError,OSError,TypeError):return False
        return bool(self.requested and self.verified() and self.observer is not None and not self.journal.path.exists() and settled)

    def _history_event(self,d,state,reason,*,force=False,event_id=None):
        if state=='on' and d.get('history_on') is True:return
        if state=='off' and not force:return
        event_id=event_id or str(uuid.uuid4())
        context=getattr(self,'history_context',{})
        event=dict(id=event_id,at=iso(self.clock()),state=state,reason=reason,
            price_p=context.get('decision_price_p') if state=='on' else context.get('price_p'),
            on_price_p=context.get('on_price_p'),off_price_p=context.get('off_price_p'),source='automation')
        if state=='on':d['history_session_id']=event_id
        event['details']=dict(session_id=d.get('history_session_id'))
        if context.get('interval'):event['details']['interval']=context['interval']
        pending=d.setdefault('history_pending',[])
        if not isinstance(pending,list):
            d['history_invalid_pending']=pending;pending=[];d['history_pending']=pending
        if not any(isinstance(v,dict) and v.get('id')==event_id for v in pending):pending.append(event)
        d['history_on']=state=='on'
        self.store.save(d)  # Persist confirmed event before attempting the history DB.

    def _flush_history(self,d,result):
        pending=d.get('history_pending',[])
        if not isinstance(pending,list):
            result['history_pending_events']=0;result['history_error']='Saved heating history needs attention.';return
        result['history_pending_events']=len(pending);result['history_error']=None
        if not pending:return
        try:
            self.state.history.append(pending,now=self.clock())
            d['history_pending']=[];self.store.save(d)
            result['history_pending_events']=0
        except Exception:
            result['history_error']='Some confirmed heating actions are waiting to be saved to history.'

    def _stop_reason(self,d):
        lease=d.get('lease') or {};context=getattr(self,'history_context',{})
        if lease.get('policy_revision') is not None and lease['policy_revision']!=context.get('policy_revision'):return 'policy_changed'
        price=context.get('price_p');off=context.get('off_price_p')
        if price is not None and off is not None and price>off:return 'price_above_off'
        return 'data_unavailable'

    def _pause(self,d,current,revision):
        # This path is an authenticated explicit user OFF request. It is allowed
        # to stop heating even when automatic starts have not been activated.
        previous=d.get('lease') or {}
        d['lease']=dict(stage='stop_intent',end_ms=0,slot_start=None,baseline=current,idle=current,user_stop=True,disable_intent=True,mode_off_requested=previous.get('mode_off_requested',False),history_stop_id=previous.get('history_stop_id') or str(uuid.uuid4()))
        self.store.save(d)
        timed=any(set(r)=={'zoneId','end'} and str(r['zoneId'])==self.observer.boost_zone_id for r in current['boost'])
        if timed:
            try:self.observer.cancel_boost()
            except Exception:pass
        if not current['disabled']:
            d['lease']['mode_off_requested']=True;self.store.save(d)
            self.observer.set_disabled(True)
        current=control_snapshot(self.observer)
        if not current['disabled'] or any(set(r)=={'zoneId','end'} and str(r['zoneId'])==self.observer.boost_zone_id for r in current['boost']):
            raise ControlUnavailable('User shutdown requires reconciliation')
        self._history_event(d,'off','automation_off',force=d['lease'].get('mode_off_requested',False),event_id=d['lease']['history_stop_id'])
        d.update(lease=None,hold=False,last=current,automation_applied_revision=revision,history_on=False,history_session_id=None)
        self.store.save(d)
        return 'automation_off'

    def _hold(self,d,current):
        if d['lease'] is not None and d['lease']['stage']=='active':d['lease']=None
        d.update(hold=True,last=current,history_on=False,history_session_id=None);self.store.save(d)
        return 'manual_change_hold'

    def _stop(self,d,current,reason=None):
        reason=reason or self._stop_reason(d)
        lease=d['lease']
        if lease:
            # A different boost or a changed heating strategy belongs to somebody
            # else. Never restore a complete old settings/schedule snapshot.
            idle=lease['idle'] or lease['baseline']
            if lease['idle'] is None or lease.get('disable_intent'):
                # Enabling normal strategy regenerates temporary records. Recovery
                # may disable again, but never restore old temperatures/schedules.
                a=copy.deepcopy(current);b=copy.deepcopy(idle)
                a['schedules'].pop('temporary',None);b['schedules'].pop('temporary',None)
                if not same_strategy(a,b):return self._hold(d,current)
            elif not same_strategy(current,idle):return self._hold(d,current)
            if lease['idle'] is None and not inactive(current):
                # Reconcile an enable that itself produced a boost, including a
                # lost enable response. Only the selected zone is eligible.
                rows=current['boost']
                if len(rows)!=1 or str(rows[0]['zoneId'])!=self.observer.boost_zone_id:
                    return self._hold(d,current)
                lease['end_ms']=rows[0]['end'];self.store.save(d)
            if not owned(current,lease,self.observer.boost_zone_id) and not inactive(current):
                return self._hold(d,current)
            lease['stage']='stop_intent';self.store.save(d)
            if owned(current,lease,self.observer.boost_zone_id):
                try:self.observer.cancel_boost()
                except Exception:pass  # Reconcile the response before retrying.
                current=control_snapshot(self.observer)
                if not inactive(current) and not owned(current,lease,self.observer.boost_zone_id):
                    return self._hold(d,current)
                a=copy.deepcopy(current);b=copy.deepcopy(idle)
                if lease.get('disable_intent'):
                    a['schedules'].pop('temporary',None);b['schedules'].pop('temporary',None)
                if not same_strategy(a,b):return self._hold(d,current)
        elif not inactive(current):return self._hold(d,current)
        # Persist intent before mode changes, including a standalone off action.
        if not current['disabled']:
            if d['lease'] is None:
                d['lease']=dict(stage='stop_intent',end_ms=0,slot_start=None,baseline=current,idle=current)
                self.store.save(d)
            d['lease']['disable_intent']=True
            d['lease']['mode_off_requested']=True
            d['lease'].setdefault('history_stop_id',str(uuid.uuid4()))
            self.store.save(d)
            self.observer.set_disabled(True)
            current=control_snapshot(self.observer)
            if not current['disabled']:raise ControlUnavailable('Heating disable readback failed')
        if not inactive(current):
            d['last']=current;self.store.save(d)
            raise ControlUnavailable('Heating disabled but boost cancellation needs reconciliation')
        stop_lease=d.get('lease') or {}
        self._history_event(d,'off',reason,force=stop_lease.get('mode_off_requested',False),event_id=stop_lease.get('history_stop_id'))
        d.update(lease=None,last=current,history_on=False,history_session_id=None);self.store.save(d)
        return 'heating_off'

    def _cancel_held(self,d,current):
        lease=d['lease']
        if owned(current,lease,self.observer.boost_zone_id):
            self.observer.cancel_boost();current=control_snapshot(self.observer)
            if owned(current,lease,self.observer.boost_zone_id):raise ControlUnavailable('Cancel needs reconciliation')
        d.update(lease=None,last=current,history_on=False,history_session_id=None);self.store.save(d)
        return 'manual_change_hold'

    def _user_stop_if_requested(self,d,current):
        switch=self.state.automation.load()
        if not switch['enabled']:
            self.observer.allow_stop=True
            return self._pause(d,current,switch['revision'])
        return None

    def _start(self,d,current,plan):
        stopped=self._user_stop_if_requested(d,current)
        if stopped:return stopped
        if not inactive(current):return self._hold(d,current)
        now=self.clock();end=int(timestamp(plan['slot_end'])*1000)
        if not 0<=timestamp(now)-timestamp(plan['slot_start'])<=15:
            return self._stop(d,current,reason='setup_timeout') if not current['disabled'] else 'waiting_for_boundary'
        lease=dict(stage='enable_intent',end_ms=end,slot_start=plan['slot_start'],baseline=current,idle=None,policy_revision=plan['policy_revision'])
        d['lease']=lease;self.store.save(d)
        if current['disabled']:
            self.observer.set_disabled(False)
            current=control_snapshot(self.observer)
            if current['disabled']:raise ControlUnavailable('Enable outcome needs recovery')
            self._history_event(d,'on','price_policy_start')
            if not inactive(current):
                rows=current['boost']
                if len(rows)!=1 or str(rows[0]['zoneId'])!=self.observer.boost_zone_id:
                    raise ControlUnavailable('Unexpected boost after enable')
                # Replace an immediately observed enable-generated boost with
                # the explicit bounded request, never extend its unknown end.
                lease['end_ms']=rows[0]['end'];self.store.save(d)
                self.observer.cancel_boost();current=control_snapshot(self.observer)
                if not inactive(current):raise ControlUnavailable('Enable-generated boost cancellation needs recovery')
                lease['end_ms']=end;self.store.save(d)
        lease['idle']=current
        lease['stage']='start_intent';self.store.save(d)
        # A boundary attempt may need several cloud calls to enable heating and
        # reconcile its generated override. Allow at most one minute for setup;
        # retain the original slot end, never a fresh 30-minute interval.
        now=self.clock()
        if not 0<=timestamp(now)-timestamp(plan['slot_start'])<=60:
            return self._stop(d,current,reason='setup_timeout')
        stopped=self._user_stop_if_requested(d,current)
        if stopped:return stopped
        self.observer.start_boost(now,datetime.fromtimestamp(end/1000,UTC))
        readback=control_snapshot(self.observer)
        if not owned(readback,lease,self.observer.boost_zone_id) or readback['disabled']:
            raise ControlUnavailable('Boost start readback failed')
        if not same_strategy(current,readback):raise ControlUnavailable('Heating strategy changed during start')
        stopped=self._user_stop_if_requested(d,readback)
        if stopped:return stopped
        lease['stage']='active';d['last']=readback;self.store.save(d)
        self._history_event(d,'on','price_policy_start')
        return 'boost_active'

    def step(self,now=None):
        now=now or self.clock()
        result=dict(phase='disabled',strategy='slot_boost',control_enabled=False,recovery_pending=False,
                    last_checked_at=now.isoformat(),observation=None,error=None,blockers=[],slot_decision=None)
        try:
            with self.state.control_lock:
                document=self.state.document();prices=self.state.status(now)
                plan=self.planner.evaluate(now,prices['current'],document['policy'],document['revision'],stale=prices['stale'])
                result['slot_decision']=plan
                self.history_context=dict(price_p=(prices['current'] or {}).get('effective_price_p'),decision_price_p=plan.get('decision_price_p'),on_price_p=document['policy']['on_price_p'],off_price_p=document['policy']['off_price_p'],policy_revision=document['revision'],interval=dict(start=(prices['current'] or {}).get('start'),end=(prices['current'] or {}).get('end'),agile_price_p=(prices['current'] or {}).get('agile_price_p'),effective_price_p=(prices['current'] or {}).get('effective_price_p'),load_kw=document['policy']['load_kw']) if prices['current'] else None)
                try:automation=self.state.automation.load();automation_error=False
                except (ValueError,OSError):automation=dict(revision=0,enabled=False);automation_error=True
                revision=automation['revision']
                try:d=self.store.load()
                except (ValueError,OSError):
                    if automation['enabled'] or revision==0:raise
                    if self.store.path.exists():
                        fd=os.open(self.store.path.with_suffix('.invalid'),os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
                        with os.fdopen(fd,'wb') as f:f.write(self.store.path.read_bytes())
                    d=self.store.fresh()
                result['recovery_pending']=d['lease'] is not None or self.journal.path.exists()
                off_pending=not automation['enabled'] and revision>d.get('automation_applied_revision',0)
                verified=self.verified()
                result['native_expiry_verified']=verified
                enabled=bool(self.requested and verified and self.observer is not None and not self.journal.path.exists())
                result['control_enabled']=enabled and automation['enabled']
                result['automation_enabled']=automation['enabled']
                result['shutdown_pending']=bool(off_pending or (not automation['enabled'] and d['lease'] is not None))
                if self.observer is not None:
                    self.observer.allow_writes=enabled and automation['enabled']
                    self.observer.allow_stop=bool(off_pending and self.observer is not None)
                    try:result['observation']=self.observer.observe(now)
                    except Exception:result['observation_error']='Homely telemetry unavailable; temperature is not used for price policy.'
                if not automation['enabled']:
                    result['slot_decision']=self.planner.evaluate(now,None,document['policy'],document['revision'],stale=True)
                if not self.requested:result['blockers']=['Automatic heating has not been activated.']
                elif not enabled:result['blockers']=['Matching native-expiry evidence, configured Homely connection and clear recovery state are required.']
                if off_pending and self.observer is not None:
                    current=control_snapshot(self.observer)
                    result['phase']=self._pause(d,current,revision)
                    result['recovery_pending']=self.journal.path.exists();result['shutdown_pending']=False
                    self.planner.evaluate(now,None,document['policy'],document['revision'],stale=True)
                elif not enabled:
                    result['phase']='recovery_required' if result['recovery_pending'] else ('blocked' if self.requested else 'disabled')
                elif not automation['enabled']:
                    if d['lease'] is not None:
                        # A controller restart/error while paused may still owe a
                        # previously authorised stop. Only stopping is permitted.
                        self.observer.allow_stop=True
                        current=control_snapshot(self.observer)
                        result['phase']=self._pause(d,current,revision)
                        result['recovery_pending']=self.journal.path.exists();result['shutdown_pending']=False
                    else:result['phase']='automation_off'
                else:
                    current=control_snapshot(self.observer)
                    old_revision=d.get('automation_revision')
                    if old_revision is not None and old_revision!=revision:
                        d['hold']=False;d['last']=current
                        plan=self.planner.evaluate(now,None,document['policy'],document['revision'],stale=True)
                        result['slot_decision']=plan
                    d['automation_revision']=revision
                    self.store.save(d)
                    if d['revision']!=document['revision']:
                        if d['hold']:d['last']=current
                        d['hold']=False;d['revision']=document['revision'];self.store.save(d)
                    if d['hold']:
                        result['phase']=self._cancel_held(d,current) if d['lease'] is not None and d['lease'].get('cancel_only') else 'manual_change_hold'
                    elif d['lease'] is not None and (self.first_tick or d['lease']['stage']!='active'):
                        result['phase']=self._stop(d,current,reason='recovery')
                        result['slot_decision']=self.planner.evaluate(now,None,document['policy'],document['revision'],stale=True)
                    elif d['lease'] is not None:
                        lease=d['lease'];expected=lease['idle']
                        expires=timestamp(now)*1000>=lease['end_ms']
                        known=owned(current,lease,self.observer.boost_zone_id) or (expires and current['boost']==expected['boost'])
                        if current['disabled'] or not same_strategy(current,expected) or not known:
                            # Preserve occupant changes. Cancel only a still-matching
                            # owned boost; never re-enable heating or overwrite targets.
                            d['hold']=True;self.store.save(d)
                            if owned(current,lease,self.observer.boost_zone_id):
                                lease['stage']='stop_intent';lease['cancel_only']=True;self.store.save(d)
                                self.observer.cancel_boost();current=control_snapshot(self.observer)
                                d['lease']=None
                            result['phase']=self._hold(d,current)
                        elif not plan['price_allowed']:
                            result['phase']=self._stop(d,current)
                        elif expires:
                            # Native expiry does not disable normal heating. Renew
                            # once for a permitted next slot, otherwise stop above.
                            d['lease']=None;d['last']=current;self.store.save(d)
                            result['phase']=self._start(d,current,plan)
                        else:result['phase']='boost_active'
                    elif d['last'] is not None and current!=d['last']:
                        result['phase']=self._hold(d,current)
                    elif plan['price_allowed']:
                        result['phase']=self._start(d,current,plan)
                    else:result['phase']=self._stop(d,current)
                    self.first_tick=False
                    result['recovery_pending']=d['lease'] is not None and d['lease']['stage']!='active'
                    result['manual_hold']=d['hold']
        except Exception:
            result['phase']='recovery_required' if self.store.path.exists() else 'unavailable'
            result['recovery_pending']=True
            result['shutdown_pending']=True if 'off_pending' in locals() and off_pending else result.get('shutdown_pending',False)
            result['error']='Heating control check failed. Saved intent is retained; no start is replayed.'
            # Failures remove permission for the rest of this slot. A reconciled
            # subsequent tick can stop but cannot start again before a boundary.
            result['slot_decision']=self.planner.evaluate(now,None,self.state.document()['policy'],self.state.document()['revision'],stale=True)
        if 'd' in locals():
            interval_error=False
            try:
                interval=getattr(self,'history_context',{}).get('interval')
                if result['phase']=='boost_active' and d.get('history_session_id') and interval:
                    ident='interval:'+d['history_session_id']+':'+interval['start']
                    if d.get('history_interval_id')!=ident:
                        event=dict(id=ident,at=iso(self.clock()),state='interval',reason='price_interval',source='automation',details=dict(session_id=d['history_session_id'],interval=interval))
                        pending=d.setdefault('history_pending',[])
                        if isinstance(pending,list):
                            pending.append(event);d['history_interval_id']=ident;self.store.save(d)
            except Exception:interval_error=True
            self._flush_history(d,result)
            if interval_error:result['history_error']='Some session cost data could not be saved.'
            result['automation_applied_revision']=d.get('automation_applied_revision',0)
        with self.lock:self._status=copy.deepcopy(result)
        return result


    def worker(self):
        while True:
            self.state.control_wake.clear()
            self.step()
            # Wake on the boundary, rather than ten seconds after a long tick.
            remaining=1800-time.time()%1800
            self.state.control_wake.wait(min(5,remaining))
