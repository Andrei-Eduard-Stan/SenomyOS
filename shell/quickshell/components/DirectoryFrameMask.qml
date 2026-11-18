import QtQuick
import QtQml.Models
import Quickshell

// The invisible source items inherit the frame's actual reveal transform.
Region {
    id: root
    required property Item frameItem
    required property var rectangles
    property Instantiator pieces: Instantiator {
        model: root.rectangles
        delegate: Region {
            id: piece
            required property var modelData
            property Item geometryItem: Item {
                objectName: "directory-mask-piece"
                parent: root.frameItem
                x: piece.modelData.x; y: piece.modelData.y
                width: piece.modelData.width; height: piece.modelData.height
            }
            item: geometryItem
        }
        onObjectAdded: (index, object) => { root.regions.push(object); root.changed(); }
        onObjectRemoved: (index, object) => { const at=root.regions.indexOf(object); if(at>=0)root.regions.splice(at,1); root.changed(); }
    }
}
