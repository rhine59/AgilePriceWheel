"""Durable user automation switch, separate from administrative activation."""
import json,os,tempfile,threading
from pathlib import Path
class AutomationStore:
    def __init__(self,path):self.path=Path(path);self.lock=threading.Lock()
    def load(self):
        if not self.path.exists():return dict(revision=0,enabled=False)
        d=json.loads(self.path.read_text())
        if not isinstance(d,dict) or set(d)!={'revision','enabled'} or type(d['enabled']) is not bool or type(d['revision']) is not int or d['revision']<0:raise ValueError('Invalid automation state')
        return d
    def save(self,enabled):
        with self.lock:return self._save(enabled)
    def _save(self,enabled):
        if type(enabled) is not bool:raise ValueError('enabled must be a boolean')
        try:old=self.load()
        except (ValueError,OSError):
            if enabled:raise ValueError('Switch off to repair saved automation state first') from None
            old=dict(revision=0)
            if self.path.exists():
                backup=self.path.with_suffix('.invalid')
                fd=os.open(backup,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
                with os.fdopen(fd,'wb') as f:f.write(self.path.read_bytes())
        d=dict(revision=old['revision']+1,enabled=enabled)
        self.path.parent.mkdir(parents=True,exist_ok=True)
        fd,name=tempfile.mkstemp(dir=self.path.parent)
        try:
            with os.fdopen(fd,'w') as f:json.dump(d,f);f.flush();os.fsync(f.fileno())
            os.replace(name,self.path)
            fd=os.open(self.path.parent,os.O_RDONLY)
            try:os.fsync(fd)
            finally:os.close(fd)
        finally:
            if os.path.exists(name):os.unlink(name)
        return d
