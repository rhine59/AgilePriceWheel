"""Private, idempotent controller-action history with London calendar weeks."""
from datetime import date,datetime,time,timedelta,timezone
from contextlib import closing
import json,math,os,sqlite3
from pathlib import Path
from zoneinfo import ZoneInfo
UTC=timezone.utc;LONDON=ZoneInfo('Europe/London');RETENTION_DAYS=366
class HistoryUnavailable(RuntimeError):pass

def aware(value):
    value=datetime.fromisoformat(value.replace('Z','+00:00')) if isinstance(value,str) else value
    if value.tzinfo is None or value.utcoffset() is None:raise ValueError('Timezone required')
    return value.astimezone(UTC)
def iso(value):return aware(value).isoformat(timespec='milliseconds').replace('+00:00','Z')
def monday(day):return day-timedelta(days=day.weekday())
def week_bounds(week,now):
    current=monday(aware(now).astimezone(LONDON).date())
    if week is None:day=current
    else:
        try:day=date.fromisoformat(week)
        except (ValueError,TypeError):raise ValueError('Use a Monday date as YYYY-MM-DD') from None
        if str(day)!=week or day.weekday()!=0:raise ValueError('Use a Monday date as YYYY-MM-DD')
    oldest=monday((aware(now)-timedelta(days=RETENTION_DAYS)).astimezone(LONDON).date())
    if not oldest<=day<=current:raise ValueError('Week is outside retained history')
    end=day+timedelta(days=7)
    return day,end,datetime.combine(day,time.min,LONDON).astimezone(UTC),datetime.combine(end,time.min,LONDON).astimezone(UTC)

class History:
    def __init__(self,path):self.path=Path(path)
    def initialize(self,now=None):
        now=now or datetime.now(UTC)
        try:
            self.path.parent.mkdir(parents=True,exist_ok=True)
            try:
                fd=os.open(self.path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600);os.close(fd)
            except FileExistsError:pass
            self.path.chmod(0o600)
            with closing(sqlite3.connect(self.path,timeout=0.5)) as db:
                db.execute('PRAGMA journal_mode=WAL')
                db.execute('CREATE TABLE IF NOT EXISTS metadata (name TEXT PRIMARY KEY,value TEXT NOT NULL)')
                db.execute('CREATE TABLE IF NOT EXISTS events (id TEXT PRIMARY KEY,at TEXT NOT NULL,epoch REAL NOT NULL,state TEXT NOT NULL,reason TEXT NOT NULL,price REAL,on_price REAL,off_price REAL,source TEXT NOT NULL)')
                if 'details' not in {r[1] for r in db.execute('PRAGMA table_info(events)')}:db.execute("ALTER TABLE events ADD COLUMN details TEXT NOT NULL DEFAULT '{}'")
                db.execute('CREATE INDEX IF NOT EXISTS events_epoch ON events(epoch)')
                db.execute('CREATE TABLE IF NOT EXISTS intervals (id TEXT PRIMARY KEY,at TEXT,epoch REAL,state TEXT,reason TEXT,price REAL,on_price REAL,off_price REAL,source TEXT,details TEXT NOT NULL)')
                db.execute('INSERT OR IGNORE INTO metadata VALUES (?,?)',('recording_started_at',iso(now)))
                db.commit()
        except (sqlite3.Error,OSError):raise HistoryUnavailable('Heating history is temporarily unavailable') from None
    def append(self,events,now=None):
        now=now or datetime.now(UTC);prepared=[]
        for e in events:
            if (not isinstance(e,dict) or not isinstance(e.get('id'),str) or not 1<=len(e['id'])<=160
                or e.get('state') not in ('on','off','interval') or e.get('source') not in ('automation','supervised_test')
                or not isinstance(e.get('reason'),str) or not 1<=len(e['reason'])<=80):raise ValueError('Invalid history event')
            details=e.get('details',{})
            if not isinstance(details,dict):raise ValueError('Invalid session metadata')
            sid=details.get('session_id')
            if sid is not None and (not isinstance(sid,str) or not 1<=len(sid)<=160):raise ValueError('Invalid session identity')
            interval=details.get('interval')
            if interval is not None:
                if not isinstance(interval,dict) or aware(interval['end'])<=aware(interval['start']):raise ValueError('Invalid price interval')
                for key in ('agile_price_p','effective_price_p','load_kw'):
                    value=interval.get(key)
                    if value is not None and (type(value) not in (int,float) or not math.isfinite(value)):raise ValueError('Invalid interval value')
                if interval.get('load_kw') is not None and interval['load_kw']<=0:raise ValueError('Invalid load')
            at=aware(e['at'])
            values=[e.get('price_p'),e.get('on_price_p'),e.get('off_price_p')]
            if any(v is not None and (type(v) not in (int,float) or not math.isfinite(v)) for v in values):raise ValueError('Invalid history price')
            if at>aware(now)+timedelta(seconds=5):raise ValueError('Future history event')
            prepared.append((e['id'],iso(at),at.timestamp(),e['state'],e['reason'],*values,e['source'],json.dumps(e.get('details',{}),allow_nan=False)))
        self.initialize(now)
        try:
            with closing(sqlite3.connect(self.path,timeout=0.5)) as db:
                for table,items in [('events',[r for r in prepared if r[3]!='interval']),('intervals',[r for r in prepared if r[3]=='interval'])]:
                    db.executemany('INSERT OR IGNORE INTO '+table+' (id,at,epoch,state,reason,price,on_price,off_price,source,details) VALUES (?,?,?,?,?,?,?,?,?,?)',items)
                for table in ('events','intervals'):
                    db.execute('DELETE FROM '+table+' WHERE epoch < ?',((aware(now)-timedelta(days=RETENTION_DAYS)).timestamp(),))
                db.commit()
        except (sqlite3.Error,OSError):raise HistoryUnavailable('Heating history is temporarily unavailable') from None
    def week(self,week=None,now=None):
        now=now or datetime.now(UTC);day,end,start_at,end_at=week_bounds(week,now)
        rows=[];all_rows=[];began=None;first=None
        try:
            if self.path.exists():
                with closing(sqlite3.connect(self.path.resolve().as_uri()+'?mode=ro',uri=True,timeout=0.5)) as db:
                    db.execute('BEGIN')  # One consistent snapshot for actions and cost intervals.
                    found=db.execute('SELECT value FROM metadata WHERE name=?',('recording_started_at',)).fetchone()
                    began=found[0] if found else None
                    first=db.execute('SELECT min(epoch) FROM events').fetchone()[0]
                    rows=db.execute('SELECT id,at,state,reason,price,on_price,off_price,source FROM events WHERE state IN ("on","off") AND epoch>=? AND epoch<? ORDER BY epoch DESC,rowid DESC LIMIT 2001',(max(start_at,aware(now)-timedelta(days=RETENTION_DAYS)).timestamp(),end_at.timestamp())).fetchall()
                    columns={r[1] for r in db.execute('PRAGMA table_info(events)')}
                    extra='details' if 'details' in columns else "'{}'"
                    all_rows=db.execute('SELECT id,at,state,reason,price,on_price,off_price,source,'+extra+' FROM events WHERE epoch>=? AND epoch<? ORDER BY epoch,rowid',((aware(now)-timedelta(days=RETENTION_DAYS)).timestamp(),(aware(now)+timedelta(seconds=5)).timestamp())).fetchall()
                    if db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='intervals'").fetchone():
                        all_rows.extend(db.execute('SELECT id,at,state,reason,price,on_price,off_price,source,details FROM intervals WHERE epoch>=? AND epoch<?',((aware(now)-timedelta(days=RETENTION_DAYS)).timestamp(),(aware(now)+timedelta(seconds=5)).timestamp())).fetchall())
                        all_rows.sort(key=lambda r:(aware(r[1]),0 if r[2]=='on' else 1 if r[2]=='interval' else 2))
        except (sqlite3.Error,OSError):raise HistoryUnavailable('Heating history is temporarily unavailable') from None
        current=monday(aware(now).astimezone(LONDON).date())
        earliest=aware(began) if began else aware(now)
        if first is not None:earliest=min(earliest,datetime.fromtimestamp(first,UTC))
        earliest=max(earliest,aware(now)-timedelta(days=RETENTION_DAYS))
        keys=['id','at','state','reason','price_p','on_price_p','off_price_p','source']
        try:sessions=build_sessions(all_rows,start_at,end_at)
        except (ValueError,TypeError,KeyError,AttributeError):raise HistoryUnavailable('Heating history is temporarily unavailable') from None
        return dict(week_start=str(day),week_end=str(end),current_week=str(current),oldest_week=str(monday(earliest.astimezone(LONDON).date())),timezone='Europe/London',recording_started_at=began,retention_days=RETENTION_DAYS,truncated=len(rows)>2000 or len(sessions)>2000,sessions=sessions[:2000],events=[dict(zip(keys,r)) for r in rows[:2000]])


def build_sessions(rows,week_start,week_end):
    """Pair explicit IDs; legacy alternating ON/OFF pairs have no cost backfill."""
    sessions=[];by_id={};legacy=None
    for row in rows:
        ident,at,state,reason,price,on,off,source,encoded=row
        details=json.loads(encoded);sid=details.get('session_id')
        if state=='on':
            sid=sid or ident
            session=dict(id=sid,correlation='recorded_session_id' if details.get('session_id') else 'legacy_sequence',on_at=at,off_at=None,duration_seconds=None,
                on_price_p=price,off_price_p=None,off_reason=None,source=source,
                estimated_cost_gbp=None,estimated_energy_kwh=None,cost_status='end_unconfirmed',intervals=[])
            sessions.append(session);by_id[sid]=session
            legacy=session if not details.get('session_id') else None
            if details.get('interval'):session['intervals'].append(details['interval'])
        elif state=='off':
            session=by_id.get(sid) if sid else legacy
            if session is not None and session['off_at'] is None:
                session.update(off_at=at,off_price_p=price,off_reason=reason)
                if details.get('interval'):session['intervals'].append(details['interval'])
                legacy=None
        elif state=='interval' and sid in by_id:
            by_id[sid]['intervals'].append(details['interval'])
    result=[]
    for session in sessions:
        begin=aware(session['on_at']);finish=aware(session['off_at']) if session['off_at'] else None
        if not (begin<week_end and (finish is None or finish>week_start)):continue
        if finish is None and begin<week_start:
            # An unknown end is not evidence of heating in every later week.
            if not any(week_start<=aware(v['start'])<week_end for v in session['intervals']):continue
        # Deduplicate same-slot observations; persist first confirmed rate/model.
        unique={}
        for interval in session['intervals']:unique.setdefault(interval['start'],interval)
        session['intervals']=sorted(unique.values(),key=lambda v:aware(v['start']))
        if finish is not None:
            session['duration_seconds']=max(0,(finish-begin).total_seconds())
            cursor=begin;cost=energy=0.;complete=True
            for interval in session['intervals']:
                a=max(begin,aware(interval['start']));b=min(finish,aware(interval['end']))
                if b<=a:continue
                if a>cursor:complete=False
                a=max(a,cursor)
                if b<=a:continue
                load=interval.get('load_kw');rate=interval.get('effective_price_p')
                if any(type(v) not in (int,float) or not math.isfinite(v) for v in (load,rate)) or load<=0:
                    complete=False;continue
                kwh=load*(b-a).total_seconds()/3600;energy+=kwh;cost+=kwh*rate/100;cursor=b
            complete=complete and cursor>=finish and bool(session['intervals'])
            session['cost_status']='estimated' if complete else 'missing_rate_data'
            if complete:session.update(estimated_cost_gbp=round(cost,8),estimated_energy_kwh=round(energy,8))
        result.append(session)
    return list(reversed(result))
