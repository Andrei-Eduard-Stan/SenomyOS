import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "components"
import "config" as Config
Window {
    id:fixture;width:400;height:440;visible:true;color:"#555555"
    TestCase {id:input;when:false}
    ShellSurfaceFrame {id:frame;x:20;y:20;width:360;height:400;frameKey:"notification-toast";perimeterInset:10;perimeterCorner:28;animate:false}
    function verify(ok,message){if(!ok){console.error("FAIL: "+message);Qt.exit(1);throw new Error(message);}}
    function capture(name){let done=false;frame.grabToImage(function(result){result.saveToFile(Quickshell.env("SENOMY_QA_OUT")+"/"+name+".png");done=true;});while(!done)input.wait(10);}
    Timer {interval:600;running:true;onTriggered:{
        const registry=JSON.parse(JSON.stringify(Config.Skin.registry));
        registry.backgrounds["notification-toast"]={source:"../assets/backgrounds/example.svg",scaling:"crop",imageOpacity:0.63,scrimOpacity:0.2};
        Config.Skin.registry=registry;input.wait(500);
        fixture.verify(frame.backgroundItem.imageReady,"existing background loader loads authored image");
        fixture.verify(frame.backgroundItem.spec.imageOpacity===0.63 && frame.backgroundItem.spec.scrimOpacity===0.2,"image and scrim opacity values preserved");
        fixture.capture("perimeter-background-mask");
        const empty=JSON.parse(JSON.stringify(Config.Skin.registry));empty.backgrounds["notification-toast"]={source:"",scaling:"fit",imageOpacity:0.63,scrimOpacity:0.2};Config.Skin.registry=empty;input.wait(100);
        fixture.verify(!frame.backgroundItem.imageReady,"empty source restores normal glass");fixture.capture("perimeter-default-fill");
        console.log("PASS: frame masks backgrounds within authored corner bounds and retains image/scrim settings and empty-source fallback; fixture registry only");Qt.quit();
    }}
}
