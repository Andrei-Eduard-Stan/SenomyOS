import QtQuick
import Quickshell
import Quickshell.Networking
import "services"
Scope {
 id:test
 QtObject {id:ethernet;property string name:"eth-fixture";property int type:DeviceType.Wired;property bool connected:true;property bool nmManaged:true;property int state:ConnectionState.Connected;property var networks:({values:[]})}
 QtObject {id:wifi1;property string name:"wlan-fixture-1";property int type:DeviceType.Wifi;property bool connected:true;property bool nmManaged:true;property int state:ConnectionState.Connected;property bool scannerEnabled:false;property var networks:({values:[known]})}
 QtObject {id:wifi2;property string name:"wlan-fixture-2";property int type:DeviceType.Wifi;property bool connected:false;property bool nmManaged:true;property int state:ConnectionState.Disconnected;property bool scannerEnabled:false;property var networks:({values:[unknown]})}
 QtObject {id:known;property string name:"Known";property var device:wifi1;property bool connected:true;property bool known:true;property bool stateChanging:false;property int state:ConnectionState.Connected;property int security:WifiSecurityType.WpaPsk;property real signalStrength:.7}
 QtObject {id:unknown;property string name:"Office $HOME ; λ";property var device:wifi2;property bool connected:false;property bool known:false;property bool stateChanging:false;property int state:ConnectionState.Disconnected;property int security:WifiSecurityType.WpaPsk;property real signalStrength:.6}
 QtObject {id:backend;property var devices:({values:[wifi1,wifi2,ethernet]});property int backend:NetworkBackendType.NetworkManager;property bool wifiEnabled:true;property bool wifiHardwareEnabled:true;property int connectivity:NetworkConnectivity.Full}
 NetworkService {id:network;networking:backend;actionContext:"fixture";profiles.queryEnabled:false}
 function check(ok,msg){if(!ok)throw new Error(msg);}
 Timer {interval:100;running:true;onTriggered:{try{
  network.profiles.authenticationAvailable=true;network.profiles.providerIdentity="fixture1";network.profiles.providerAvailable=true;network.profiles.status=({primaryDevice:"eth-fixture",primaryConnection:"Fixture wired",networkingEnabled:true,connectivity:"full"});
  check(network.label==="WIRED" && network.primaryDevice==="eth-fixture" && !network.connectedWifi,"primary Ethernet wins over connected secondary Wi-Fi");
  check(network.openSecurePrompt(unknown),"selected-adapter secure handoff accepted by inert launcher");network.connectionAttempt.fail("fixture finished");
  check(network.refreshNetworks()&&wifi1.scannerEnabled&&wifi2.scannerEnabled,"explicit owned scan");
  backend.devices=({values:[ethernet]});check(!network.scanning&&!wifi1.scannerEnabled&&!wifi2.scannerEnabled,"adapter removal releases only owned scan flags");
  backend.devices=({values:[wifi1,wifi2,ethernet]});check(network.actions.request("disable",null),"radio review");network.profiles.providerIdentity="fixture2";check(!network.actions.confirm()&&backend.wifiEnabled,"provider replacement refuses pending radio mutation");
  network.profiles.status=({connectivity:"portal",portalUri:"http://example.invalid/sign-in"});check(network.openPortal(),"explicit captive-browser handoff");
  console.log("PASS: actual NetworkService primary-interface selection, adapter-bound authentication, scan-owner cleanup and provider replacement; inert devices/launcher only");Qt.quit();
 }catch(e){console.error("FAIL: "+e.message+" "+e.stack);Qt.exit(1);}}}
}
