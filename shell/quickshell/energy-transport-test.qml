import QtQuick
import Quickshell
import "services"
Scope {
    id: suite
    property int stage: 0
    EnergyService { id: energy; helper: Quickshell.shellDir + "/tests/fixtures/energy-provider-fake.py" }
    EnergyService { id: missing; enabled: false; interpreter: "/nonexistent-senomy-qa-python" }
    Timer { interval:20; repeat:true; running:true; onTriggered: {
        try {
            if (suite.stage === 0 && energy.available) {
                energy.active=true;
                if (energy.submit("power-saver", "stale-token")) throw new Error("Stale review submitted");
                if (!energy.submit("power-saver", "token")) throw new Error("Inert request refused");
                if (energy.submit("balanced", "token")) throw new Error("Concurrent request accepted");
                suite.stage=1;
            } else if (suite.stage === 1 && energy.actionFailed) {
                if (!energy.actionError.includes("verifiable")) throw new Error("Missing honest transport failure");
                energy.active=false;energy.active=true;
                missing.adopt({schemaVersion:1,ok:true,backend:{available:true,active:"balanced",profiles:["power-saver"],token:"missing-token",identity:"inert"}});
                if (!missing.submit("power-saver", "missing-token")) throw new Error("Missing-start request not exercised");
                suite.stage=2;
            } else if (suite.stage === 2 && missing.actionFailed) {
                if (missing.busy || !missing.actionError.includes("could not start")) throw new Error("Missing dependency left a request pending");
                console.log("PASS: native watcher, stale token, single-flight, invalid-result failure, page reopen and missing-interpreter completion");
                Qt.quit();
            }
        } catch(e) {console.error("FAIL: "+e.stack);Qt.exit(1);}
    }}
    Timer {interval:6000;running:true;onTriggered:{console.error("FAIL: transport timed out");Qt.exit(1);}}
}
