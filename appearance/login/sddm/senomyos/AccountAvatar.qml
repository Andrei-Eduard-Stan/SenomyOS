import QtQuick
Item {
    id:root
    property url source
    property url fallbackSource:"assets/avatar.png"
    Image {anchors.fill:parent;source:root.fallbackSource;sourceSize:Qt.size(256,256);fillMode:Image.PreserveAspectFit;visible:selected.status!==Image.Ready}
    Image {id:selected;anchors.fill:parent;source:root.source;sourceSize:Qt.size(256,256);fillMode:Image.PreserveAspectFit;asynchronous:true;visible:status===Image.Ready}
}
