#!/usr/bin/env python3
"""Capture real SDDM QML and a non-locking projection of the emitted lock config.

Lock images are offline geometry/type/asset projections, never PAM or native
Hyprlock rendering acceptance. No display socket, host bus or mutation is used.
"""
from pathlib import Path
import argparse, json, os, re, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[1]

def lock_widgets(config, root):
    widgets = []
    manifest = json.loads((root / "deploy/manifest.json").read_text())
    bindings = {"$XDG_DATA_HOME/" + e["target"]["path"]: root / e["source"]
                for c in manifest["components"] if c["id"] == "hyprlock"
                for e in c["entries"] if e["target"]["root"] == "xdg_data"}
    for kind, body in re.findall(r"^([a-z-]+) \{\n(.*?)^\}", config, re.M | re.S):
        if kind in ("general", "auth", "animations", "background"): continue
        if kind not in ("shape", "image", "label", "input-field"):
            raise ValueError("Unsupported preview widget: " + kind)
        values = {}
        for line in body.splitlines():
            if "=" in line:
                key, value = line.strip().split("=", 1); values[key.strip()] = value.strip()
        if values.get("halign", "center") != "center" or values.get("valign", "center") != "center":
            raise ValueError("Review preview alignment for new configuration")
        if kind == "image":
            image = bindings[values["path"]].resolve()
            if not image.is_relative_to(root.resolve()) or not image.is_file(): raise ValueError("Unsafe/missing projected asset")
            values["source"] = image.as_uri()
        def color(text):
            match = re.fullmatch(r"rgba\((\d+), (\d+), (\d+), ([0-9.]+)\)", text)
            if not match: return text
            red, green, blue = map(int, match.group(1,2,3)); alpha = round(float(match[4])*255)
            return "#%02x%02x%02x%02x" % (alpha,red,green,blue)
        for key in ("color", "outer_color", "inner_color", "font_color"):
            if key in values: values[key] = color(values[key])
        values.update(kind=kind)
        widgets.append(values)
    return widgets

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("output", type=Path);p.add_argument("--lock-only",action="store_true",help="Project lock config after separate native login validation");args=p.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    env=dict(os.environ, SENOMY_QA_OUT=str(out))
    if not args.lock_only:
        result=subprocess.run(["python3",str(ROOT/"scripts/validate-login-screens.py")],env=env,capture_output=True,text=True,timeout=60)
        (out/"login-tests.log").write_text(result.stdout+result.stderr)
        if result.returncode: raise SystemExit(result.stdout+result.stderr)
    config_text=(ROOT/"appearance/lock/hyprlock.conf").read_text()
    widgets=lock_widgets(config_text,ROOT)
    background_block=re.search(r"^background \{\n(.*?)^\}",config_text,re.M|re.S).group(1)
    background={key.strip():value.strip() for key,value in (line.split("=",1) for line in background_block.splitlines() if "=" in line)}
    with tempfile.TemporaryDirectory(prefix="senomy-lock-projection-") as directory:
        case=Path(directory);runtime=case/"runtime";runtime.mkdir(mode=0o700)
        (case/"fonts.conf").write_text('<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd"><fontconfig><include>/etc/fonts/fonts.conf</include><dir>'+str(ROOT/'appearance/shared/fonts')+'</dir><cachedir>'+str(case/'font-cache')+'</cachedir></fontconfig>')
        qml = r'''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
Window {
 id:test;visible:true;width:1920;height:1080;color:"#08090b"
 property var widgets: __WIDGETS__
 TestCase {id:waiter;when:false}
 property var backdrop: __BACKDROP__
 Item {
  anchors.fill:parent;z:Number(test.backdrop.zindex || -2)
  Image {anchors.fill:parent;source:__BACKGROUND__;fillMode:Image.PreserveAspectCrop}
  // Native background brightness multiplies RGB before the configured scrim.
  Rectangle {anchors.fill:parent;color:"black";opacity:1-Math.max(0,Math.min(1,Number(test.backdrop.brightness || 1)))}
 }
 function text(value){return String(value || "").replace(/\$TIME/g,"12:34").replace(/\$USER/g,"fixture").replace(/\$LAYOUT/g,"GB");}
 Repeater {
  id:projected
  model:test.widgets
  Loader {
   id:host;required property var modelData
   property var v:modelData
   property string kind:v.kind
   z:Number(v.zindex || 0)
   width:item?(kind==="image"?Number(v.size)*item.sourceSize.width/Math.min(item.sourceSize.width,item.sourceSize.height):item.implicitWidth):0
   height:item?(kind==="image"?Number(v.size)*item.sourceSize.height/Math.min(item.sourceSize.width,item.sourceSize.height):item.implicitHeight):0
   x:(test.width-width)/2+Number((v.position || "0, 0").split(",")[0])
   y:(test.height-height)/2-Number((v.position || "0, 0").split(",")[1])
   sourceComponent:kind==="shape"?overlay:kind==="image"?picture:kind==="label"?label:field
   Component {id:overlay;Rectangle {implicitWidth:test.width;implicitHeight:test.height;color:host.v.color}}
   Component {id:picture;Image {source:host.v.source;fillMode:Image.PreserveAspectFit}}
   Component {id:label;Text {text:test.text(host.v.text);textFormat:Text.PlainText;color:host.v.color;font.family:host.v.font_family;font.pointSize:Number(host.v.font_size)}}
   Component {id:field;Rectangle {
    implicitWidth:Number(host.v.size.split(",")[0]);implicitHeight:Number(host.v.size.split(",")[1]);color:host.v.inner_color
    border.color:host.v.outer_color;border.width:Number(host.v.outline_thickness);radius:Number(host.v.rounding)
    Text {anchors.left:parent.left;anchors.leftMargin:12;anchors.verticalCenter:parent.verticalCenter;text:host.v.placeholder_text;color:host.v.font_color;font.family:host.v.font_family;font.pointSize:12}
   }}
  }
 }
 Timer {interval:250;running:true;onTriggered:{
  for(const size of [{w:1920,h:1080},{w:1366,h:768},{w:800,h:1000},{w:360,h:640}]){
   test.width=size.w;test.height=size.h;waiter.wait(100);
   for(let i=0;i<projected.count;i++){
    const widget=projected.itemAt(i);
    if(widget.x < -1 || widget.y < -1 || widget.x+widget.width > size.w+1 || widget.y+widget.height > size.h+1){console.error("FAIL: lock widget exceeds supported output");Qt.exit(1);return;}
   }
   let done=false;test.contentItem.grabToImage(result=>{result.saveToFile(__OUTPUT__+"/lock-"+size.w+"x"+size.h+".png");done=true;});while(!done)waiter.wait(10);
  }
  console.log("PASS: non-locking projection from actual generated Hyprlock config at four sizes");Qt.quit();
 }}
}
'''
        qml=qml.replace("__BACKDROP__",json.dumps(background)).replace("__WIDGETS__",json.dumps(widgets)).replace("__BACKGROUND__",json.dumps((ROOT/"appearance/login/sddm/senomyos/assets/background.png").as_uri())).replace("__OUTPUT__",json.dumps(str(out)))
        (case/"projection.qml").write_text(qml)
        env={k:v for k,v in os.environ.items() if k not in ("DISPLAY","WAYLAND_DISPLAY","HYPRLAND_INSTANCE_SIGNATURE","DBUS_SESSION_BUS_ADDRESS")}
        env.update(QT_QPA_PLATFORM="offscreen",QT_QUICK_BACKEND="software",XDG_RUNTIME_DIR=str(runtime),XDG_CONFIG_HOME=str(case/"config"),XDG_STATE_HOME=str(case/"state"),FONTCONFIG_FILE=str(case/"fonts.conf"))
        result=subprocess.run(["dbus-run-session","--","qs","--path",str(case/"projection.qml"),"--no-color"],env=env,capture_output=True,text=True,timeout=12)
        log=result.stdout+result.stderr;(out/"lock-projection.log").write_text(log)
        if result.returncode or re.search("ERROR|FAIL:|TypeError|ReferenceError",log): raise SystemExit(log)
    print("PASS: SDDM native QML / fake proxy and offline lock-config projections; no real lock/authentication")
if __name__=="__main__":main()
