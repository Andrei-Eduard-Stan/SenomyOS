import QtQuick
import QtTest
import "../config/SessionPolicyPreferences.js" as Preferences

TestCase {
    name: "SessionPolicyPreferences"

    function rejected(call) {
        let failed=false;
        try { call(); } catch(e) { failed=true; }
        return failed;
    }

    function test_timeout_validation() {
        const value=Preferences.validate(7,15,"lock");
        compare(value.lockSeconds,420);
        compare(value.displayOffSeconds,900);
        verify(rejected(()=>Preferences.validate(0,10,"lock")));
        verify(rejected(()=>Preferences.validate(5,5,"lock")));
        verify(rejected(()=>Preferences.validate(5.5,10,"lock")));
        verify(rejected(()=>Preferences.validate(5,121,"lock")));
        verify(rejected(()=>Preferences.validate(5,10,"suspend")));
    }

    function test_response_states() {
        const value=Preferences.parseResponse(JSON.stringify({ok:true,available:false,configured:true,
            lockSeconds:420,displayOffSeconds:900,suspendEnabled:false,
            lockBeforeSleep:true,lidAvailable:true,lidAction:"none",activationRequired:true}));
        compare(value.lockSeconds,420);
        compare(value.displayOffSeconds,900);
        verify(value.configured);
        verify(!value.available);
        verify(value.activationRequired);
        verify(value.lidAvailable);
        compare(value.lidAction,"none");
        verify(rejected(()=>Preferences.parseResponse(JSON.stringify({ok:false,error:"fixture failure"}))));
        verify(rejected(()=>Preferences.parseResponse("not json")));
    }
}
