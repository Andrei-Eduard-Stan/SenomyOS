import QtQuick
import "../config" as Config
Transition {NumberAnimation {properties:"x,y";duration:Math.round(Config.Motion.disclosureMs*2/3);easing.type:Easing.OutCubic}}
