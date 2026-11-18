import QtQuick

Item {
    id: root
    property bool revealed: false
    property bool reducedMotion: false
    property real phase: 0
    opacity: revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 110 } }
    NumberAnimation on phase {
        from: 0; to: 3; duration: 900; loops: Animation.Infinite
        running: root.revealed && root.visible && !root.reducedMotion
    }
    onRevealedChanged: if (!revealed) phase = 0
    Column {
        anchors.centerIn: parent
        spacing: 3
        Repeater {
            model: 3
            Canvas {
                required property int index
                width: 12; height: 7
                opacity: root.reducedMotion ? 0.85 : Math.floor(root.phase) === 2 - index ? 1 : 0.18
                Behavior on opacity { NumberAnimation { duration: root.reducedMotion ? 0 : 100 } }
                onPaint: {
                    const c = getContext("2d");
                    c.reset(); c.strokeStyle = "white"; c.lineWidth = 2;
                    c.lineCap = "round"; c.lineJoin = "round";
                    c.beginPath(); c.moveTo(1, 6); c.lineTo(6, 1); c.lineTo(11, 6); c.stroke();
                }
            }
        }
    }
}
