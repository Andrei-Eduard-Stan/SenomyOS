import QtQuick
import QtTest
import "../services"
TestCase {
 id:test;name:"OskAutomatic";when:true
 QtObject {
  id:c
  property bool owned:false
  property bool startPending:false
  property int starts:0
  property int shows:0
  property int hides:0
  property int state:0
  property var capabilities:({})
  signal manualAction(bool showing)
  signal manualStop()
  function prepareAutomatic(){starts++;startPending=true;return true;}
  function showAutomatic(){if(!owned)return false;shows++;return true;}
  function hideAutomatic(){if(!owned)return false;hides++;return true;}
 }
 OskAutomaticPolicy {id:a;controller:c}
 function input(physical,active,ime=true,locked=false,epoch=1){a.consume(JSON.stringify({ok:true,mode:"auto",physicalKeyboard:physical,textActive:active,inputMethod:ime,locked:locked,focusEpoch:epoch}));}
 function init(){a.snapshot=null;a.mode="auto";a.autoShown=false;a.manualPinned=false;a.dismissed=false;a.dismissedEpoch=-1;a.stoppedByUser=false;c.owned=false;c.startPending=false;c.starts=0;c.shows=0;c.hides=0;}
 function test_laptop_never_autostarts(){input(true,true);compare(c.starts,0);compare(c.shows,0);}
 function test_no_keyboard_prearms_only_without_ime(){input(false,false);compare(c.starts,0);input(false,false,false);compare(c.starts,1);compare(c.shows,0);a.reconcile();compare(c.starts,1);}
 function test_text_focus_show_blur_hide(){c.owned=true;input(false,true);compare(c.shows,1);a.reconcile();compare(c.shows,1);input(false,false);compare(c.hides,1);}
 function test_attach_hides_automatic_only(){c.owned=true;input(false,true);input(true,true);compare(c.hides,1);input(false,true);compare(c.shows,2);}
 function test_manual_pin_survives_blur_and_hardware(){c.owned=true;c.manualAction(true);input(false,true);input(false,false);input(true,false);compare(c.hides,0);compare(c.shows,0);}
 function test_manual_hide_suppresses_same_field_until_new_focus(){c.owned=true;input(false,true);c.manualAction(false);input(false,true);compare(c.shows,1);input(false,true,true,false,2);compare(c.shows,2);}
 function test_confirmed_stop_does_not_respawn(){c.manualAction(false);c.manualStop();input(false,false,false, false,2);compare(c.starts,0);input(false,true,true,false,3);compare(c.starts,0);}
 function test_lock_and_unknown_hide_automatic(){c.owned=true;input(false,true);input(false,true,true,true);compare(c.hides,1);input(false,true);compare(c.shows,2);a.consume('{"ok":false,"mode":"auto"}');compare(c.hides,2);}
 function test_malformed_never_claims_eligible(){for(const line of ['{}','[]','bad','{"ok":true,"mode":"auto","physicalKeyboard":"false"}']){a.consume(line);verify(!a.available);compare(c.starts,0);}}
 function test_manual_mode_never_starts(){a.consume(JSON.stringify({ok:true,mode:"manual",physicalKeyboard:false,textActive:true,inputMethod:false,locked:false,focusEpoch:1}));compare(c.starts,0);}
}
