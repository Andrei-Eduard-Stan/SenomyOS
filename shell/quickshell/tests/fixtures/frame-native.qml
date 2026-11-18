//@ pragma UseQApplication
//@ pragma ShellId senomy-frame-native-fixture
import QtQuick
import QtTest
import Quickshell
import "components" as UI
import "components/DirectoryFrameGeometry.js" as Geometry
import "config" as Config
ShellRoot {
 id:test
 property int checks:0
 TestCase {id:input;when:false}
 UI.DirectorySurfaceWindow {
  id:panel;targetScreen:Quickshell.screens[0];requestedOpen:true
  preferredWidth:1120;preferredHeight:650;frameKey:"dashboard";title:"ISOLATED FRAME TEST"
  Text {text:"ISOLATED FRAME GEOMETRY · NO SYSTEM ACTIONS";color:"white";font.pixelSize:16}
 }
 function check(ok,message){++checks;if(!ok)throw new Error(message);}
 function capture(name){let done=false;panel.captureItem.grabToImage(r=>done=r.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png"));for(let i=0;i<100&&!done;i++)input.wait(10);check(done,"capture "+name);}
 Timer {interval:250;running:true;onTriggered:{try{
  const registry=Config.Skin.registry;Config.Skin.registry=Object.assign({},registry,{persona:Object.assign({},registry.persona||{},{reducedMotion:true})});
  for(const width of [1700,1120,900,520,390]){
   panel.preferredWidth=width;input.wait(120);
   const frame=input.findChild(panel.captureItem,"directory-art-frame"),title=input.findChild(panel.captureItem,"authored-title-plate"),cipher=input.findChild(panel.captureItem,"authored-top-cipher");
   check(frame!==null&&panel.mask.regions.length>0&&panel.mask.regions.length<150,"native mask constructed from bounded scanline pieces");
   check(frame.children.filter(item=>item.objectName==="directory-mask-piece").length===panel.mask.regions.length,"resizing releases old mask source items");
   const titlePoint=title.mapToItem(frame,title.width/2,title.height/2),cipherPoint=cipher.mapToItem(frame,cipher.width/2,cipher.height/2);
   for(const point of [titlePoint,cipherPoint,Qt.point(3,frame.height/2),Qt.point(frame.width/2,frame.height/2)]){
    check(Geometry.contains(frame.silhouette,point.x,point.y),"lettering and body have backing");
    check(frame.inputRectangles.some(r=>point.x>=r.x&&point.x<r.x+r.width&&point.y>=r.y&&point.y<r.y+r.height),"painted content has native input coverage");
   }
   check(!Geometry.contains(frame.silhouette,2,2),"outer transparent corner stays outside the contour");
   check(!frame.inputRectangles.some(r=>2>=r.x&&2<r.x+r.width&&2>=r.y&&2<r.y+r.height),"transparent corner not in input mask");
   capture("native-frame-"+width);
  }
  Config.Skin.registry=registry;panel.requestedOpen=false;input.wait(100);
  console.log("PASS: "+checks+" native frame construction/coverage checks across five widths; actual Region and PanelWindow, inert content");Qt.quit();
 }catch(e){console.error("FAIL: "+e.message+"\n"+e.stack);Qt.exit(1);}}}
}
