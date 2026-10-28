#!/usr/bin/env python3
"""Run the prepared probe in a separate process inside the existing NAS container.

Uses only stdlib locally and existing container dependencies/credentials. Source
copies are temporary; the runtime process/image/policy/hold are not replaced.
prepare and verify-restored do not write heating controls. run/stop require the
specific human test approval and --approved-live. No SSH password is accepted.
"""
import argparse,json,re,shlex,subprocess,sys
from pathlib import Path,PurePosixPath

BOOTSTRAP=r'''
import json,os,pathlib,subprocess,sys,tempfile
p=json.load(sys.stdin)
with tempfile.TemporaryDirectory(prefix='supervised-target-') as folder:
    root=pathlib.Path(folder)
    allowed={'controller/boost_target_probe.py','examples/supervised_boost_target.py','examples/heating_services.py'}
    if set(p['files'])!=allowed:raise SystemExit('Unexpected source files')
    for name,content in p['files'].items():
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(content);target.chmod(0o600)
    installation=root/'installation.json';installation.write_text(json.dumps(p['installation']));installation.chmod(0o600)
    key=root/'key';key.write_text(os.environ['HEATING_API_TOKEN']);key.chmod(0o600)
    args=[sys.executable,str(root/'examples/supervised_boost_target.py'),p['command'],
        '--state-file',p['state_file'],'--installation-file',str(installation),
        '--homely-env-file',os.environ['HEATING_HOMELY_ENV_FILE'],
        '--controller-url','http://127.0.0.1:8080','--local-controller','--key-file',str(key)]
    if p['approved_live']:args.append('--approved-live')
    result=subprocess.run(args)
raise SystemExit(result.returncode)
'''


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['prepare','run','stop','verify-restored'])
    parser.add_argument('--container',default='homely-heating')
    parser.add_argument('--docker',default='/usr/local/bin/docker')
    parser.add_argument('--ssh-target',required=True)
    parser.add_argument('--ssh-port',type=int,default=22)
    parser.add_argument('--installation-file',type=Path,required=True)
    parser.add_argument('--state-file',required=True,help='New /data/supervised-target-<name>.json for prepare')
    parser.add_argument('--approved-live',action='store_true')
    args=parser.parse_args(argv)
    if args.command in ('run','stop') and not args.approved_live:parser.error('Specific human approval and --approved-live required for heating writes')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*',args.container):parser.error('Invalid container name')
    if args.ssh_target.startswith('-') or any(c.isspace() for c in args.ssh_target) or not 1<=args.ssh_port<=65535:parser.error('Invalid existing SSH destination')
    path=PurePosixPath(args.state_file)
    if path.parent!=PurePosixPath('/data') or not path.name.startswith('supervised-target-') or path.suffix!='.json':parser.error('Use a dedicated /data/supervised-target-<name>.json, not a runtime state file')
    root=Path(__file__).resolve().parents[1]
    names=['controller/boost_target_probe.py','examples/supervised_boost_target.py','examples/heating_services.py']
    payload=dict(command=args.command,state_file=str(path),approved_live=args.approved_live,
        installation=json.loads(args.installation_file.read_text()),files={n:(root/n).read_text() for n in names})
    command=shlex.join([args.docker,'exec','-i',args.container,'python','-c',BOOTSTRAP])
    result=subprocess.run(['ssh','-p',str(args.ssh_port),'-o','LogLevel=ERROR','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8',args.ssh_target,command],input=json.dumps(payload),text=True)
    return result.returncode


if __name__=='__main__':
    try:raise SystemExit(main())
    except (OSError,ValueError,KeyError):
        print('Launcher did not complete; no automatic start retry. Reconcile state before any rerun.',file=sys.stderr)
        raise SystemExit(1)
