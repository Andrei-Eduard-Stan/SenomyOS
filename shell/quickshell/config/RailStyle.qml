pragma Singleton
import QtQuick
QtObject {
    property string workspaceBorderType: Skin.mode(Skin.frame("workspace"))
    property url workspaceArtSource: Skin.resolve(Skin.frame("workspace").source || "")
    property string arrowBorderType: Skin.registry.navigation && Skin.registry.navigation.mode || "native"
    property url previousArrowArtSource: Skin.resolve(Skin.registry.navigation && Skin.registry.navigation.previous || "")
    property url nextArrowArtSource: Skin.resolve(Skin.registry.navigation && Skin.registry.navigation.next || "")
    property url avatarCircleSource: Skin.resolve(Skin.registry.persona && Skin.registry.persona.ring || "")
    property url avatarPortraitSource: Skin.resolve(Skin.registry.persona && Skin.registry.persona.portrait || "")
    property bool rotateAvatarCircle: !!(Skin.registry.persona && Skin.registry.persona.rotate)
    property int avatarRotationMs: Skin.registry.persona && Skin.registry.persona.rotationMs || 24000
}
