"""Supervised, explicitly authorised boost-target experiment; not a worker.

No network or write transport here. An injected adapter supplies the existing
captured enable/start/cancel/disable commands. It never writes a schedule.
"""
import math
import threading
import time
from datetime import datetime,timezone
UTC=timezone.utc


def inactive(rows):
    return isinstance(rows,list) and all(isinstance(row,dict) and 'start' in row for row in rows)


def probe(adapter, *, authorised=False, maximum_seconds=60, clock=None,
          monotonic=None, timer_factory=None):
    if authorised is not True:
        raise ValueError('Specific supervised live-test approval is required')
    if type(maximum_seconds) not in (int,float) or not math.isfinite(maximum_seconds) or not 1<=maximum_seconds<=60:
        raise ValueError('Supervised stop timer must be 1..60 seconds')
    clock=clock or (lambda:datetime.now(UTC));monotonic=monotonic or time.monotonic
    timer_factory=timer_factory or threading.Timer
    # All preflight failures happen before arming any heating write.
    adapter.preflight()
    if adapter.is_disabled() is not True or not inactive(adapter.read_boost()):
        raise ValueError('Start only with heating disabled and no timed boost')
    result=dict(returned_target_c=None,returned_min_c=None,returned_max_c=None,
        requested_target_c=22,returned_target_matches_22=False,boost_readback_verified=False,
        stop_confirmed=False,watchdog_fired=False,error=None,
        physical_temperature_ceiling_verified=False,schedule_restoration_pending=True,trace_error=False)
    def note(event,**fields):
        try:adapter.note(event,**fields)
        except Exception:result['trace_error']=True

    expired=threading.Event();start=monotonic();deadline=start+maximum_seconds

    def stopped():
        try:return adapter.is_disabled() is True and inactive(adapter.read_boost())
        except Exception:return False

    def watchdog():
        expired.set();result['watchdog_fired']=True
        try:adapter.stop_only()
        except Exception:pass

    def ready():
        if expired.is_set() or monotonic()>=deadline:
            raise TimeoutError('Supervised stop deadline reached')
        adapter.context_unchanged()
        if expired.is_set() or monotonic()>=deadline:
            raise TimeoutError('Supervised stop deadline reached')

    timer=timer_factory(maximum_seconds,watchdog)
    adapter.note('armed',maximum_seconds=maximum_seconds)
    timer.start()
    # No sleep/dwell. Stop as soon as the response and owned-boost readback exist.
    try:
        ready();adapter.note('enable_intent');adapter.enable()
        ready()
        if adapter.is_disabled():raise ValueError('Enable not confirmed')
        rows=adapter.read_boost()
        if not inactive(rows):
            # Enabling can generate a boost. Preflight had none; cancel that
            # selected-zone test effect before the explicit bounded request.
            if len(rows)!=1 or str(rows[0].get('zoneId'))!=str(adapter.zone_id):
                raise ValueError('Unexpected boost after enable')
            adapter.cancel()
            if not inactive(adapter.read_boost()):raise ValueError('Generated boost not cancelled')
        ready();now=clock()
        if now.utcoffset() is None:raise ValueError('Timezone required')
        end=datetime.fromtimestamp((int(now.timestamp())//1800+1)*1800,UTC)
        if (end-now).total_seconds()<30:raise ValueError('Too close to slot end; do not start')
        adapter.note('boost_intent',start=now.isoformat(),end=end.isoformat())
        response=adapter.start(now,end)
        ready()
        if not isinstance(response,dict) or response.get('boostActive') is not True:
            raise ValueError('Unexpected boost response')
        first,last=int(now.timestamp()*1000),int(end.timestamp()*1000)
        if (response.get('start')!=first or response.get('end')!=last
                or str(response.get('zoneId'))!=str(adapter.zone_id)):
            raise ValueError('Boost response does not match request')
        rows=adapter.read_boost()
        if (len(rows)!=1 or set(rows[0])!={'zoneId','end'}
                or str(rows[0]['zoneId'])!=str(adapter.zone_id) or rows[0]['end']!=last
                or adapter.is_disabled() is not False):
            raise ValueError('Active boost readback not verified')
        for source,target in [('temperature','returned_target_c'),('min','returned_min_c'),('max','returned_max_c')]:
            value=response.get(source)
            if type(value) not in (int,float) or not math.isfinite(value):raise ValueError('Invalid returned target')
            result[target]=value
        result['boost_readback_verified']=True
        result['returned_target_matches_22']=result['returned_target_c']==22
        adapter.note('observed',returned_target_c=result['returned_target_c'])
    except BaseException as error:
        result['error']='Probe did not finish: '+type(error).__name__
    finally:
        note('stop_intent')
        try:adapter.stop_only()
        except Exception:result['error']=result['error'] or 'Stop requires independent reconciliation'
        result['stop_confirmed']=stopped()
        if result['stop_confirmed']:
            timer.cancel()
        else:
            # Leave the stop-only fallback armed. It cannot enable/start or
            # modify a schedule. A cloud outage can still delay physical off.
            note('stop_unconfirmed')
        result['elapsed_seconds']=round(monotonic()-start,3)
        note('finished',result=result)
    return result
