import QtQuick
import "../config" as Config
Transition {
    SequentialAnimation {
        NumberAnimation {property:"opacity";from:0;to:0;duration:Math.round(Config.Motion.disclosureMs*2/3)}
        NumberAnimation {property:"opacity";from:0;to:1;duration:Math.round(Config.Motion.disclosureMs/3);easing.type:Easing.OutCubic}
    }
}
