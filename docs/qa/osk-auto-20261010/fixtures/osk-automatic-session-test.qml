import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "services"
Scope {
 id:root
 Component.onCompleted:if(Quickshell.env("SENOMY_PRIVATE_OSK_TEST")!=="1")Qt.exit(2)
 InputSettings {id:settings}
 IpcHandler {
  target:"test"
  function report():string{return JSON.stringify({snapshot:settings.oskAutomatic.snapshot,mode:settings.oskAutomatic.mode,state:settings.oskController.state,owned:settings.oskController.owned,visible:settings.oskAdapter.visible,pid:settings.oskAdapter.child.processId});}
  function hide():void{settings.oskController.requestHide();}
  function manualOpen():void{settings.oskController.requestShow();}
  function mode(next:string):void{settings.oskAutomatic.setMode(next);}
 }
}
