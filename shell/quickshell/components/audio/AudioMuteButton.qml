import QtQuick

AudioButton {
    id:root
    property bool input:false
    property bool muted:false
    text:muted?(input?"Unmute mic":"Unmute"):(input?"Mute mic":"Mute")
    glyph:input?(muted?"\uf131":"\uf130"):(muted?"\uf6a9":"\uf028")
    warning:muted
    accessibleLabel:(muted?"Unmute ":"Mute ")+(input?"default microphone":"output")
    Accessible.checkable:true;Accessible.checked:muted
}
