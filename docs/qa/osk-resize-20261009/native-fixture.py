from pathlib import Path
import os,subprocess,time,json,signal
s=Path(__file__).parent;r=Path((s/'nested-runtime-path').read_text());env=dict(os.environ,XDG_RUNTIME_DIR=str(r),WAYLAND_DISPLAY='wayland-1',HYPRLAND_INSTANCE_SIGNATURE=next((r/'hypr').iterdir()).name,SENOMY_PRIVATE_POINTER_TEST='1')
def monitor():return json.loads(subprocess.check_output(['hyprctl','-j','monitors'],env=env,text=True))[0]
def geom():return [json.loads(line) for line in (s/'native-events.log').read_text().splitlines()][-1]
def drag(x,y,ex,ey):
 m=monitor();subprocess.run([str(s/'pointer-driver'),str(m['width']),str(m['height']),str(x),str(y),str(ex),str(ey)],env=env,check=True);time.sleep(.2)
with (s/'native-run.log').open('w') as log,(s/'native-events.log').open('w') as events:
 p=subprocess.Popen([str(s/'native/wvkbd-mobintl'),'--senomy-resize','--no-popup'],env=env,stdout=events,stderr=log)
 try:
  time.sleep(.5);m=monitor();w=m['width'];h=m['height'];initial=geom();assert initial['visible'] and m['reserved'][3]==initial['height']
  drag(w//2,h-initial['height']+10,w//2,h-initial['height']-130);g=geom();assert g['height']>initial['height']+100,(initial,g);assert monitor()['reserved'][3]==g['height'];print('PASS: native top-edge resize and observed compositor reservation',g,flush=True)
  right=(w+g['width'])//2-8;y=h-g['height']//2;drag(right,y,right-80,y);g2=geom();assert g2['width']<g['width']-100,(g,g2);assert g2['height']==g['height'];print('PASS: native side-edge resize and key geometry',g2,flush=True)
  right=(w+g2['width'])//2-8;top=h-g2['height']+8;drag(right,top,right-40,top-40);g3=geom();assert g3['height']>g2['height'] and g3['width']<g2['width'];print('PASS: native corner resize',g3,flush=True)
  top=h-g3['height']+8;drag(w//2,top,w//2,10);g4=geom();assert g4['height']<=h*3//5 and monitor()['reserved'][3]==g4['height'];print('PASS: native maximum height preserves desktop work area',g4,flush=True)
  p.send_signal(signal.SIGUSR1);time.sleep(.3);assert not geom()['visible'] and monitor()['reserved'][3]==0;print('PASS: native hide releases reservation',flush=True)
  p.send_signal(signal.SIGUSR2);time.sleep(.3);assert geom()['visible'] and monitor()['reserved'][3]==geom()['height'];print('PASS: native show restores resized session geometry',flush=True)
  assert p.poll() is None
 finally:p.terminate();p.wait(timeout=3)
assert monitor()['reserved'][3]==0
print('PASS: private native provider exit releases work area; isolated nested compositor only',flush=True)
