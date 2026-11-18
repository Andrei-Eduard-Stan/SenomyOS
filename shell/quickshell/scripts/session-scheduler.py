#!/usr/bin/env python3
"""One authoritative, reviewed session commitment; inert-testable OS boundary.

A transient systemd user worker supervises CLOCK_BOOTTIME deadlines and detects
resume/unavailable gaps. Absolute instructions persist; countdowns never leave
the login runtime. Every mutation and dispatch claim shares one file lock.
"""
import contextlib
from datetime import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import tempfile
import time
from zoneinfo import ZoneInfo

ACTIONS={'lock':'Lock','suspend':'Sleep','logout':'Log out','reboot':'Restart','poweroff':'Shut down'}
ACTIVE=('scheduled','running')
MAX_DELAY=7*86400
LATE_GRACE=3
class Problem(ValueError):
    def __init__(self,message,fields=None):super().__init__(message);self.fields=fields or {}

class Runtime:
    def __init__(self):
        runtime=os.environ.get('XDG_RUNTIME_DIR','')
        if not runtime or not Path(runtime).is_absolute():raise Problem('The login runtime directory is unavailable.')
        self.root=Path(runtime)/'senomyos'
        self.persistent_root=Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/'senomyos/session'
        self.tool=Path(__file__).resolve().parents[3]/'scripts/senomy-session-action'
    def now(self):return time.time()
    def boottime(self):return time.clock_gettime(time.CLOCK_BOOTTIME)
    def monotonic(self):return time.monotonic()
    def sleep(self):time.sleep(1)
    def run(self,args,timeout=8,env=None):
        try:return subprocess.run(args,capture_output=True,text=True,timeout=timeout,env=env)
        except (OSError,subprocess.TimeoutExpired) as error:raise Problem('The session operation could not be verified. Reopen Session to check its state.') from error
    def zone(self):
        local=Path('/etc/localtime')
        try:return ZoneInfo(str(local.resolve().relative_to('/usr/share/zoneinfo')))
        except (ValueError,KeyError):
            with local.open('rb') as source:return ZoneInfo.from_file(source)
    def zone_id(self):return hashlib.sha256(Path('/etc/localtime').read_bytes()).hexdigest()
    def identity(self,expected=None):
        session=os.environ.get('XDG_SESSION_ID','')
        if expected:session=expected['session']
        if not session:
            session=self.run(['/usr/bin/loginctl','show-user',str(os.getuid()),'-p','Display','--value']).stdout.strip()
        if not re.fullmatch(r'[A-Za-z0-9_-]{1,128}',session):raise Problem('An active desktop login could not be identified.')
        result=self.run(['/usr/bin/loginctl','show-session',session,'-p','User','-p','State','-p','Class'])
        values=dict(line.split('=',1) for line in result.stdout.splitlines() if '=' in line)
        if result.returncode or values.get('User')!=str(os.getuid()) or values.get('State') not in ('active','online') or values.get('Class')!='user':raise Problem('This desktop login has ended or is unavailable.')
        signature=os.environ.get('HYPRLAND_INSTANCE_SIGNATURE','')
        if not signature or len(signature)>200 or '/' in signature:raise Problem('The desktop session connection is unavailable.')
        if not (Path(os.environ['XDG_RUNTIME_DIR'])/'hypr'/signature/'.socket.sock').is_socket():raise Problem('The desktop session connection is no longer available.')
        identity=dict(session=session,boot=Path('/proc/sys/kernel/random/boot_id').read_text().strip(),signature=signature)
        if expected and identity!=expected:raise Problem('This schedule belongs to an earlier desktop login.')
        return identity
    def available(self,action,identity):
        env=dict(os.environ,XDG_SESSION_ID=identity['session'])
        result=self.run([str(self.tool),'check',action],env=env)
        if result.returncode:raise Problem(ACTIONS[action]+' is unavailable in this login.',{'action':ACTIONS[action]+' is unavailable in this login.'})
        capability={'poweroff':'CanPowerOff','reboot':'CanReboot','suspend':'CanSuspend'}.get(action)
        if capability:
            query=self.run(['/usr/bin/busctl','--system','--json=short','call','org.freedesktop.login1','/org/freedesktop/login1','org.freedesktop.login1.Manager',capability])
            try:answer=json.loads(query.stdout)['data'][0]
            except (ValueError,KeyError,IndexError):raise Problem('System action permissions are unavailable.') from None
            if query.returncode or answer not in ('yes','challenge'):raise Problem(ACTIONS[action]+' is not supported or permitted.',{'action':ACTIONS[action]+' is not supported or permitted.'})
            return answer=='challenge'
        return False
    def timer_available(self):
        if not Path('/usr/bin/systemd-run').is_file():return False
        return self.run(['/usr/bin/systemctl','--user','is-active','graphical-session.target']).returncode==0
    def arm(self,record):
        # A supervised worker (only while pending) can distinguish elapsed time
        # across suspend from continuous availability. Calendar timer catch-up
        # alone cannot provide the required never-execute-after-downtime rule.
        command=['/usr/bin/systemd-run','--user','--quiet','--collect','--expand-environment=no','--unit='+record['unit'],'--description=Senomy '+record['label']+' commitment','--property=PartOf=graphical-session.target','--property=Type=exec','--property=UMask=0077']
        forwarded={'XDG_SESSION_ID':record['identity']['session'],'HYPRLAND_INSTANCE_SIGNATURE':record['identity']['signature'],'XDG_RUNTIME_DIR':os.environ['XDG_RUNTIME_DIR'],'XDG_STATE_HOME':str(self.persistent_root.parents[1]),'WAYLAND_DISPLAY':os.environ.get('WAYLAND_DISPLAY','')}
        for key,value in forwarded.items():
            if value:command.append('--setenv='+key+'='+value)
        command += ['/usr/bin/python3',str(Path(__file__).resolve()),'watch',record['id']]
        if self.run(command).returncode:raise Problem('The schedule worker could not be started. The previous instruction was retained.')
        if not self.timer_active(record):raise Problem('The schedule worker did not become active. Reopen Session to check its state.')
    def timer_active(self,record):
        return self.run(['/usr/bin/systemctl','--user','is-active',record['unit']+'.service']).returncode==0
    def stop(self,record):
        # Never stop the current dispatch. The caller holds the claim lock.
        if self.run(['/usr/bin/systemctl','--user','stop',record['unit']+'.service']).returncode:raise Problem('The schedule worker could not be stopped. Retry cancellation.')
    def notify_failure(self,label,message):
        if not Path('/usr/bin/notify-send').is_file():return
        try:self.run(['/usr/bin/notify-send','--app-name=SenomyOS','--icon=system-shutdown',label+' schedule',message],timeout=3)
        except Problem:pass
    def execute(self,action,identity):
        self.identity(identity);self.available(action,identity)
        result=self.run([str(self.tool),'run',action,'--confirm',action],timeout=20,env=dict(os.environ,XDG_SESSION_ID=identity['session']))
        if result.returncode:raise Problem(ACTIONS[action]+' was refused or failed. No force or inhibitor bypass was used.')

class Scheduler:
    def __init__(self,runtime):
        self.rt=runtime;self.root=runtime.root
        self.persistent=getattr(runtime,'persistent_root',self.root/'persistent')
    def boot(self):return self.rt.boottime()
    def mono(self):return self.rt.monotonic()
    @contextlib.contextmanager
    def locked(self):
        self.root.mkdir(mode=0o700,parents=True,exist_ok=True)
        self.persistent.mkdir(mode=0o700,parents=True,exist_ok=True)
        with (self.persistent/'session-schedule.lock').open('a') as lock:
            os.chmod(lock.name,0o600);fcntl.flock(lock,fcntl.LOCK_EX);yield
    def read(self,name):
        try:
            path=Path(name) if Path(name).is_absolute() else self.root/name
            if path.stat().st_size>16384:raise Problem('The saved session schedule is invalid.')
            value=json.loads(path.read_text())
            if not isinstance(value,dict):raise Problem("The saved session record is invalid.")
            return value
        except FileNotFoundError:return {}
        except (json.JSONDecodeError,UnicodeError):raise Problem('The saved session schedule is invalid.') from None
    def write(self,name,value):
        target=Path(name) if Path(name).is_absolute() else self.root/name
        fd,path=tempfile.mkstemp(prefix='.session-',dir=target.parent)
        try:
            with os.fdopen(fd,'w') as stream:json.dump(value,stream);stream.write('\n');stream.flush();os.fsync(stream.fileno())
            os.replace(path,target)
            directory=os.open(target.parent,os.O_DIRECTORY)
            try:os.fsync(directory)
            finally:os.close(directory)
        finally:
            if os.path.exists(path):os.unlink(path)
    def state(self):
        absolute=self.read(self.persistent/'absolute.json')
        if absolute:return self.with_pulse(absolute)
        temporary=self.read('session-countdown.json')
        if temporary:return self.with_pulse(temporary)
        # Compatibility: preserve a pre-redesign pending receipt in this login.
        legacy=self.read('session-schedule.json')
        return legacy if legacy and 'schemaVersion' not in legacy else {}
    def with_pulse(self,record):
        pulse=self.read('session-worker.json')
        if pulse.get('id')==record.get('id') and pulse.get('unit')==record.get('unit') and pulse.get('identity')==record.get('identity'):
            for key in ('heartbeatBoot','heartbeatMono','heartbeatWall'):record[key]=pulse[key]
        return record
    def remaining(self,record):
        if record.get('mode')=='delay' and record.get('deadlineBoot') is not None:return record['deadlineBoot']-self.boot()
        return record.get('dueEpoch',0)-self.rt.now()
    def display(self,record):
        if not record:return {}
        value={k:v for k,v in record.items() if k not in ('identity','zoneId','expires','used','heartbeatBoot','heartbeatMono','heartbeatWall')}
        remaining=max(0,self.remaining(record))
        value.update(schemaVersion=2,scheduleType='absolute' if record.get('mode')=='at' else 'countdown',remainingSeconds=remaining,progress=max(0,min(1,remaining/max(1,record.get('durationSeconds',record.get('dueEpoch',0)-record.get('createdEpoch',0))))),urgency='final' if remaining<=10 else 'critical' if remaining<=60 else 'warning' if remaining<=300 else 'approaching' if remaining<=600 else 'normal')
        return value
    def save(self,record):
        record['schemaVersion']=2
        if record.get('mode')=='at':
            self.write(self.persistent/'absolute.json',record)
            (self.root/'session-countdown.json').unlink(missing_ok=True)
        else:
            self.write('session-countdown.json',record)
            (self.persistent/'absolute.json').unlink(missing_ok=True)
        self.publish(record)
    def publish(self,record):self.write('session-schedule.json',self.display(record))
    def heartbeat(self,record):
        record.update(heartbeatBoot=self.boot(),heartbeatMono=self.mono(),heartbeatWall=self.rt.now())
    def discontinuity(self,record):
        boot_gap=self.boot()-record.get('heartbeatBoot',self.boot())
        mono_gap=self.mono()-record.get('heartbeatMono',self.mono())
        wall_gap=self.rt.now()-record.get('heartbeatWall',self.rt.now())
        return boot_gap>LATE_GRACE or boot_gap<0 or abs(boot_gap-mono_gap)>0.25 or (record.get('mode')=='at' and abs(wall_gap-boot_gap)>LATE_GRACE)
    def missed(self,record,message):
        record.update(state='missed',message=message);self.save(record)

    def status(self):
        with self.locked():
            record=self.state();reason='';capabilities={};identity=None
            try:
                identity=self.rt.identity()
                for action in ACTIONS:
                    try:self.rt.available(action,identity);capabilities[action]=True
                    except Problem:capabilities[action]=False
                timer=self.rt.timer_available()
                if not timer:reason='Scheduling needs an active systemd graphical session.'
            except Problem as error:timer=False;reason=str(error)
            if record.get('state') in ACTIVE:
                try:
                    if record['state']=='running':
                        if self.rt.now()-record.get('claimedEpoch',self.rt.now())>30:
                            record.update(state='unverified',message='Dispatch result is unverified; this instruction will never retry.');self.save(record)
                    elif record.get('mode')=='at':
                        if record['dueEpoch']<=self.rt.now() and not self.rt.timer_active(record):
                            self.missed(record,'MISSED while unavailable. Review, reschedule or execute now.')
                        elif record['dueEpoch']>self.rt.now() and identity and timer:
                            if record.get('identity')!=identity or not self.rt.timer_active(record):
                                record.update(identity=identity,unit='senomy-session-action-'+secrets.token_hex(16))
                                self.heartbeat(record);self.rt.arm(record);self.save(record)
                    else:
                        self.rt.identity(record['identity'])
                        if not self.rt.timer_active(record):raise Problem('The countdown worker was unavailable. Nothing was run.')
                except Problem as error:
                    if record.get('mode')!='at':self.missed(record,str(error))
                    else:reason=str(error);timer=False;record['statusDetail']=str(error)
            self.publish(record)
            return dict(ok=True,schedule=self.display(record),capabilities=capabilities,schedulingAvailable=timer,reason=reason)
    def prepare(self,form):
        with self.locked():
            identity=self.rt.identity();action=form.get('action');mode=form.get('mode')
            if not isinstance(action,str) or action not in ACTIONS:raise Problem('Choose a session action.',{'action':'Choose a session action.'})
            if mode not in ('now','delay','at'):raise Problem('Choose Now or Schedule.',{'mode':'Choose when to run this action.'})
            requires_auth=self.rt.available(action,identity)
            if mode!='now' and not self.rt.timer_available():raise Problem('Scheduling needs an active systemd graphical session.')
            errors={};due=0;fold=form.get('fold');now=self.rt.now()
            if mode=='delay':
                if 'seconds' in form:
                    amount=str(form['seconds']);factor=1
                else:
                    amount=str(form.get('amount',''));unit=form.get('unit')
                    factor={'minutes':60,'hours':3600}.get(unit,0) if isinstance(unit,str) else 0
                if not re.fullmatch(r'\d{1,7}',amount) or not factor or not 1<=int(amount)*factor<=MAX_DELAY:errors['seconds']='Choose a countdown from 1 second to 7 days.'
                else:due=now+int(amount)*factor
            elif mode=='at':
                date_text=str(form.get('date',''));time_text=str(form.get('time',''))
                try:
                    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}',date_text):raise ValueError()
                    datetime.fromisoformat(date_text)
                except ValueError:errors['date']='Choose a real calendar date.'
                if not re.fullmatch(r'(?:[01]\d|2[0-3]):[0-5]\d',time_text):errors['time']='Use 24-hour HH:MM, from 00:00 to 23:59.'
                if not errors:
                    try:
                        local=datetime.fromisoformat(date_text+'T'+time_text);zone=self.rt.zone();choices=[]
                        for option in (0,1):
                            candidate=local.replace(tzinfo=zone,fold=option)
                            if datetime.fromtimestamp(candidate.timestamp(),zone).replace(tzinfo=None)==local and candidate.timestamp() not in [item.timestamp() for item in choices]:choices.append(candidate)
                        if not choices:errors['time']='This time does not exist because the clocks move forward.'
                        elif len(choices)>1 and fold not in (0,1):errors['fold']='This time occurs twice. Choose the first or second occurrence.'
                        else:due=int(choices[min(int(fold or 0),len(choices)-1)].timestamp())
                    except (ValueError,OverflowError):errors['date']='This calendar date cannot be scheduled.'
                if not errors and not now+10<=due<=now+366*86400:errors['time']='Choose a time at least 10 seconds ahead, within the next year.'
            if errors:raise Problem('Check the highlighted fields.',errors)
            current=self.state()
            if current.get('state')=='running' and mode!='now':raise Problem('The scheduled action is already being dispatched.')
            identifier=secrets.token_hex(16)
            review=dict(id=identifier,action=action,label=ACTIONS[action],mode=mode,dueEpoch=due,dueLabel=datetime.fromtimestamp(due,self.rt.zone()).strftime('%a %d %b, %H:%M:%S %Z (%z)') if due else 'Now',identity=identity,zoneId=self.rt.zone_id(),expires=now+120,used=False,requiresAuth=bool(requires_auth),form=form,replaceId=current.get('id','') if current.get('state') in ('scheduled','missed','failed') and mode!='now' else '',replaces=current.get('label','')+' · '+current.get('dueLabel','') if current.get('state') in ('scheduled','missed','failed') and mode!='now' else '')
            review.update(createdEpoch=now,durationSeconds=due-now if due else 0,timezone=str(getattr(self.rt.zone(),'key',None) or datetime.fromtimestamp(due or now,self.rt.zone()).strftime('%Z %z')),executeId=form.get('executeId',''))
            if review['executeId'] and (current.get('id')!=review['executeId'] or current.get('state') not in ('scheduled','missed','failed')):raise Problem('The schedule changed. Review Execute now again.')
            self.write('session-review.json',review)
            return dict(ok=True,review=self.display(review))
    def commit(self,token):
        immediate=None
        with self.locked():
            review=self.read('session-review.json')
            if not re.fullmatch(r'[a-f0-9]{32}',str(token)) or review.get('id')!=token or review.get('used') or review.get('expires',0)<self.rt.now():raise Problem('This review has expired. Review the action again.')
            self.rt.identity(review['identity']);self.rt.available(review['action'],review['identity'])
            if review['zoneId']!=self.rt.zone_id():raise Problem('The timezone changed. Review the time again.')
            current=self.state()
            if review['mode']=='now':
                if review.get('executeId'):
                    if current.get('id')!=review['executeId'] or current.get('state') not in ('scheduled','missed','failed'):raise Problem('The schedule changed. Review Execute now again.')
                    if current['state']=='scheduled':self.rt.stop(current)
                    current.update(state='running',claimedEpoch=self.rt.now(),message='Sending reviewed request.');self.save(current)
                review['used']=True;self.write('session-review.json',review);immediate=review
            else:
                if review['mode']=='at' and not self.rt.now()+10<=review['dueEpoch']<=self.rt.now()+366*86400:raise Problem('This scheduled time is too close or has passed. Choose a new time.')
                if current.get('state')=='running':raise Problem('The previous action is already being dispatched and cannot be replaced.')
                active_id=current.get('id','') if current.get('state') in ('scheduled','missed','failed') else ''
                if active_id!=review['replaceId']:raise Problem('The existing schedule changed. Review the replacement again.')
                record=dict(review,state='scheduled',unit='senomy-session-action-'+token,message='Persistent instruction; no wake or logged-out execution.' if review['mode']=='at' else 'Temporary countdown for this login.');record.pop('used',None)
                if record['mode']=='delay':
                    record.update(createdEpoch=self.rt.now(),dueEpoch=self.rt.now()+record['durationSeconds'],deadlineBoot=self.boot()+record['durationSeconds'])
                    record['dueLabel']=datetime.fromtimestamp(record['dueEpoch'],self.rt.zone()).strftime('%a %d %b, %H:%M:%S %Z (%z)')
                if record['mode']=='at':record.update(createdEpoch=self.rt.now(),durationSeconds=record['dueEpoch']-self.rt.now())
                self.heartbeat(record)
                try:
                    self.rt.arm(record)
                    self.save(record)
                    if current.get('state')=='scheduled':
                        try:self.rt.stop(current)
                        except Problem:record['message']='Schedule replaced. The obsolete worker cannot dispatch this instruction.'
                except Exception:
                    # A worker with no authoritative identity exits itself. Never
                    # stop a potentially committed instruction after an fsync or
                    # UI-receipt failure; the caller must refresh its true state.
                    raise
                review['used']=True;self.write('session-review.json',review)
                return dict(ok=True,schedule=self.display(record),message='Schedule set.')
        try:self.rt.execute(immediate['action'],immediate['identity']);outcome='succeeded';message=immediate['label']+' request sent.'
        except Problem as error:outcome='failed';message=str(error)
        if immediate.get('executeId'):
            with self.locked():
                current=self.state()
                if current.get('id')==immediate['executeId']:current.update(state=outcome,message=message);self.save(current)
        return dict(ok=outcome=='succeeded',message=message,schedule=self.display(self.state()))
    def cancel(self,identifier):
        with self.locked():
            current=self.state()
            if current.get('id')!=identifier or current.get('state') not in ('scheduled','missed','failed'):raise Problem('This schedule changed or is already running. Refresh its state.')
            was_pending=current['state']=='scheduled'
            current.update(state='cancelled',message='Schedule cancelled. Nothing will run.');self.save(current)
            if was_pending:
                try:self.rt.stop(current)
                except Problem:pass  # The terminal receipt already prevents dispatch.
            return dict(ok=True,schedule=self.display(current),message=current['message'])
    def fire(self,identifier):
        failure=''
        with self.locked():
            current=self.state()
            if current.get('id')!=identifier or current.get('state')!='scheduled':return dict(ok=True,state='ignored')
            try:
                self.rt.identity(current['identity'])
                if not -LATE_GRACE<=self.remaining(current)<=0 or self.discontinuity(current):raise Problem('The scheduled time was missed or changed. Nothing was run.')
                self.rt.available(current['action'],current['identity'])
            except Problem as error:
                failure=str(error);current.update(state='missed',message=failure);self.save(current)
            else:
                current.update(state='running',claimedEpoch=self.rt.now(),message='Sending '+current['label'].lower()+' request.');self.save(current)
        if failure:
            self.rt.notify_failure(current['label'],failure)
            return dict(ok=False,error=failure)
        try:self.rt.execute(current['action'],current['identity']);outcome='succeeded';message=current['label']+' request sent.'
        except Problem as error:outcome='failed';message=str(error)
        with self.locked():
            latest=self.state()
            if latest.get('id')==identifier:current.update(state=outcome,message=message);self.save(current)
        if outcome=='failed':self.rt.notify_failure(current['label'],message)
        return dict(ok=outcome=='succeeded',state=outcome,message=message)

    def tick(self,identifier):
        with self.locked():
            current=self.state()
            if current.get('id')!=identifier or current.get('state')!='scheduled':return False
            try:
                if self.boot()-getattr(self,'identity_checked',-100)>5:
                    self.rt.identity(current['identity']);self.identity_checked=self.boot()
            except Problem:
                if current.get('mode')=='delay':self.missed(current,'This login ended. The temporary countdown is invalid.')
                return False
            remaining=self.remaining(current)
            if remaining<=0 and self.discontinuity(current):
                self.missed(current,'MISSED during suspension, clock change or scheduler downtime. Nothing was run.')
                return False
            self.heartbeat(current)
            # Heartbeats are runtime-only. Persisted instructions change only
            # for lifecycle/management operations, avoiding continuous disk writes.
            self.write('session-worker.json',current)
            self.publish(current)
        if remaining<=0:self.fire(identifier);return False
        return True
    def watch(self,identifier):
        # systemd Type=exec returns before this lock is acquired; commit has
        # written the authoritative instruction when the first tick proceeds.
        while self.tick(identifier):self.rt.sleep()
        return dict(ok=True,state='finished')
    def postpone(self,request):
        if not isinstance(request,dict) or request.get('seconds') not in (600,1800):raise Problem('Choose a 10 or 30 minute postponement.')
        with self.locked():
            current=self.state()
            if current.get('id')!=request.get('id') or current.get('state')!='scheduled':raise Problem('The schedule changed or is already being dispatched.')
            record=dict(current);delay=max(0,self.remaining(current))+request['seconds'];identifier=secrets.token_hex(16)
            record.update(id=identifier,unit='senomy-session-action-'+identifier,createdEpoch=self.rt.now(),dueEpoch=self.rt.now()+delay,durationSeconds=delay,message='Schedule postponed.',zoneId=self.rt.zone_id(),timezone=str(getattr(self.rt.zone(),'key',None) or datetime.fromtimestamp(self.rt.now(),self.rt.zone()).strftime('%Z %z')))
            if record['mode']=='delay':record['deadlineBoot']=self.boot()+delay
            local=datetime.fromtimestamp(record['dueEpoch'],self.rt.zone());record['dueLabel']=local.strftime('%a %d %b, %H:%M:%S %Z (%z)')
            record['form']=dict(record.get('form',{}),date=local.strftime('%Y-%m-%d'),time=local.strftime('%H:%M'),fold=local.fold,seconds=int(delay))
            self.heartbeat(record)
            try:self.rt.arm(record);self.save(record)
            except Exception:
                # Receipt identity also prevents dispatch for uncommitted workers.
                raise
            try:self.rt.stop(current)
            except Problem:pass  # Old identity is invalidated atomically above.
            return dict(ok=True,schedule=self.display(record),message='Schedule postponed.')

def main():
    try:
        if len(sys.argv)<2 or sys.argv[1] not in ('status','prepare','commit','cancel','fire','watch','postpone'):raise Problem('Unknown session operation.')
        scheduler=Scheduler(Runtime());operation=sys.argv[1]
        if operation=='status':result=scheduler.status()
        elif operation in ('prepare','postpone'):
            raw=sys.argv[2] if len(sys.argv)==3 else ''
            if len(raw)>4096:raise Problem('The schedule request is too large.')
            form=json.loads(raw)
            if not isinstance(form,dict):raise Problem('The schedule request is invalid.')
            result=getattr(scheduler,operation)(form)
        else:
            if len(sys.argv)!=3:raise Problem('A reviewed action identity is required.')
            result=getattr(scheduler,operation)(sys.argv[2])
    except (Problem,ValueError,OSError,TypeError,KeyError) as error:result=dict(ok=False,error=str(error) if isinstance(error,Problem) else 'The session operation could not be verified.',fieldErrors=getattr(error,'fields',{}))
    print(json.dumps(result,separators=(',',':')))
    return 0 if result.get('ok') else 1
if __name__=='__main__':sys.exit(main())
