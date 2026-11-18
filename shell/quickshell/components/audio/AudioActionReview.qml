import QtQuick
import ".."
Column {
    id:root
    required property var audio
    width:parent.width
    spacing:8
    AudioSelectionReview {width:parent.width;actions:root.audio.selectionActions}
    AudioSelectionReview {width:parent.width;visible:root.audio.graphActions!==undefined && root.audio.graphActions!==null && root.audio.graphActions.actionState!=="idle";actions:root.audio.graphActions || root.audio.selectionActions}
}
