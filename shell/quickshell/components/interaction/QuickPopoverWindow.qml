import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Hyprland
import ".."
import "../../config" as Config
import "InteractionChildren.js" as Children

// All quick controls share one lifetime policy. Content owns no close timers.
PopupWindow {
    id: root
    required property var anchorItem
    property var coordinator: null
    property var targetScreen: null
    property string popupToken: ""
    property bool requestedOpen: false
    property bool cardShown: false
    property int openDuration: Config.Motion.compactMs
    readonly property real presentationProgress: motion.progress
    property string openingPrimary: ""
    readonly property bool mayRetract: !coordinator || ((!coordinator.activePopup || coordinator.activePopup === popupToken)
        && !coordinator.capturePaused && coordinator.activePrimary === openingPrimary)
    readonly property bool presentationAllowed: anchorTracker.ready && (requestedOpen || mayRetract)
    SurfaceMotion {
        id: motion
        shown: root.cardShown
        allowed: root.presentationAllowed
        openMs: root.openDuration
        onClosed: if (!root.requestedOpen) root.anchorPrepared = false
    }
    // Retraction is presentation only: no pointer input or focus grab survives it.
    mask: Region { x: 0; y: 0; width: root.requestedOpen ? root.width : 0; height: root.requestedOpen ? root.height : 0 }
    Binding { target: root.contentItem; property: "enabled"; value: root.requestedOpen }
    property var focusTarget: null
    // Every popup acquires native keyboard focus before admitting Rails.
    // A multi-surface focus grab may otherwise choose a Rail as its first surface.
    property bool keyboardPriority: true
    // Search content must not reveal or start providers before Wayland has
    // configured the new native popup and queued its first frame.
    property bool waitForFirstFrame: true
    property bool anchorPrepared: false
    property int pendingRevealGeneration: -1
    property int pendingRevealLease: -1
    property int lease: -1
    property int localGeneration: 0
    readonly property bool nativeVisible: !!contentItem.Window.window && contentItem.Window.window.visible
        && (typeof root.backingWindowVisible === "undefined" || root.backingWindowVisible)
    readonly property bool focusGrabActive: !!focusGrabLoader.item && focusGrabLoader.item.active
    readonly property string lifecycle: !requestedOpen ? (motion.retained ? "closing" : "closed") : !anchorPrepared || !cardShown ? "preparing" : motion.phase
    readonly property bool ownsEscape: requestedOpen && contentItem.Window.window && contentItem.Window.window.active
    FrameObserver {targetItem:root.contentItem;key:root.popupToken.split(":")[0] || "popup";requested:root.requestedOpen}
    signal dismissRequested()
    // Fresh mappings prepare request-dependent content before native allocation.
    // In-flight reversals retain the current editor and geometry.
    signal preparing()
    visible: (requestedOpen || motion.retained) && presentationAllowed && anchorPrepared
    grabFocus: false
    // Native xdg-positioner constraints operate in output logical coordinates.
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Resize
    function refreshAnchor() {if(requestedOpen && anchorTracker.ready)anchor.updateAnchor();}
    PopupAnchorTracker {
        id: anchorTracker
        item: root.anchorItem
        active: root.requestedOpen
        onMoved: root.handleAnchorMovement()
    }
    function currentOpening(generation, openingLease) {
        return generation === localGeneration && requestedOpen && openingLease === lease
            && (!coordinator || coordinator.popupGeneration === openingLease);
    }
    function handleAnchorMovement() {
        if (!requestedOpen) return;
        if (anchorPrepared && !anchorTracker.ready) { invalidateAnchor(); return; }
        // Coalesce a layout pass; never let a callback for an old lease move
        // or reveal its replacement. No fixed geometry delay is required.
        Qt.callLater(refreshPlacement);
    }
    function refreshPlacement() {
        if (!currentOpening(localGeneration, lease)) return;
        if (!anchorPrepared) prepareOpening(localGeneration, lease);
        else refreshAnchor();
    }
    function invalidateAnchor() {
        if (!requestedOpen || (coordinator && coordinator.popupGeneration !== lease)) return;
        ++localGeneration;
        anchorPrepared = false;
        cardShown = false;
        if (coordinator) {
            if (typeof coordinator.modalCancelRequested === "function") coordinator.modalCancelRequested();
            coordinator.closePopups(popupToken, lease, true);
        } else dismissRequested();
    }
    function restoreVisibilityBinding() {
        if (!nativeVisible) visible = false;
        visible = Qt.binding(() => (root.requestedOpen || motion.retained) && root.presentationAllowed && root.anchorPrepared);
    }
    function repairPresentation() {
        Children.dismiss(contentItem);
        anchorPrepared = false;
        cardShown = false;
        restoreVisibilityBinding();
        reconcile();
    }
    Connections {
        target: root.coordinator
        ignoreUnknownSignals: true
        function onRecoveryRequested() { root.repairPresentation(); }
    }
    Connections {
        target: root
        ignoreUnknownSignals: true
        function onClosed() {
            const generation=root.localGeneration, openingLease=root.lease;
            Children.dismiss(root.contentItem);
            // Finish the native close transaction before reconciling the derived
            // request and the native proxy's retained visibility intent.
            Qt.callLater(function() {
                if (root.currentOpening(generation,openingLease)) {
                    if (root.coordinator && root.coordinator.modalActive) root.repairPresentation();
                    else root.dismiss();
                }
                root.restoreVisibilityBinding();
            });
        }
    }
    function dismiss() {
        if (coordinator) return coordinator.closePopups(popupToken, lease);
        dismissRequested(); return true;
    }
    function handleEscape() {
        if (coordinator && coordinator.modalActive) coordinator.modalCancelRequested();
        else dismiss();
    }
    function reveal(generation, openingLease) {
        if (!currentOpening(generation, openingLease) || !anchorTracker.ready) return;
        pendingRevealGeneration = -1;
        pendingRevealLease = -1;
        cardShown = true;
        if (focusTarget) focusTarget.forceActiveFocus(Qt.PopupFocusReason);
    }
    Connections {
        target: root.waitForFirstFrame && root.requestedOpen ? root.contentItem.Window.window : null
        function onFrameSwapped() {
            const generation = root.pendingRevealGeneration;
            const openingLease = root.pendingRevealLease;
            if (generation < 0) return;
            Qt.callLater(function() { root.reveal(generation, openingLease); });
        }
    }
    function prepareOpening(generation, openingLease) {
        if (!currentOpening(generation, openingLease) || anchorPrepared || !anchorTracker.ready) return;
        // All popups prepare the complete anchor transform before mapping.
        refreshAnchor();
        anchorPrepared = true;
        // Mapping must precede focus within this window. This queued callback
        // has no authority over another opening, even if the token is reused.
        Qt.callLater(function() {
            if (!root.currentOpening(generation, openingLease) || !anchorTracker.ready) return;
            if (root.waitForFirstFrame) {
                root.pendingRevealGeneration = generation;
                root.pendingRevealLease = openingLease;
                const window = root.contentItem.Window.window;
                if (window) window.update();
            } else root.reveal(generation, openingLease);
        });
    }
    function reconcile() {
        const generation = ++localGeneration;
        pendingRevealGeneration = -1;
        pendingRevealLease = -1;
        if (!requestedOpen) {
            Children.dismiss(contentItem);
            cardShown = false;
            if (!motion.retained) anchorPrepared = false;
            return;
        }
        openingPrimary = coordinator ? coordinator.activePrimary : "";
        lease = coordinator ? coordinator.popupGeneration : generation;
        if (!anchorItem) {
            Qt.callLater(function() {
                if (root.currentOpening(generation, root.lease) && !root.anchorItem) root.invalidateAnchor();
            });
            return;
        }
        // A same-token reopen reverses an in-flight exit without remapping.
        if (anchorPrepared && nativeVisible && anchorTracker.ready) {
            reveal(generation, lease);
            return;
        }
        cardShown = false;
        anchorPrepared = false;
        // A real item may be instantiated before its parent native window.
        // The tracker resumes preparation on readiness, rather than throwing
        // or leaving a permanently invisible requested popup.
        preparing();
        Qt.callLater(refreshPlacement);
    }
    onRequestedOpenChanged: reconcile()
    onAnchorItemChanged: if (requestedOpen) {
        if (!anchorItem) invalidateAnchor(); else handleAnchorMovement();
    }
    Component.onCompleted: reconcile()
    Component.onDestruction: ++localGeneration
    Loader {
        id: focusGrabLoader
        // One native grab object per opening. A clear from a destroyed grab
        // cannot be mistaken for dismissal of a later opening of the same token.
        active: root.requestedOpen && root.cardShown
        sourceComponent: Component {
            HyprlandFocusGrab {
                id: grab
                property int heldLease: -1
                property int heldGeneration: -1
                property bool focusAcquired: false
                windows: root.keyboardPriority && !focusAcquired ? [root]
                    : [root].concat(root.coordinator ? root.coordinator.railWindows : [])
                property Connections focusObserver: Connections {
                    target: root
                    function onOwnsEscapeChanged() {
                        if (root.ownsEscape) grab.focusAcquired = true;
                    }
                }
                Component.onCompleted: {
                    heldLease = root.lease;
                    heldGeneration = root.localGeneration;
                    active = true;
                    // active acknowledges the local protocol request, not native
                    // keyboard ownership. Window.active is the readiness signal.
                    if (root.ownsEscape) focusAcquired = true;
                }
                onCleared: {
                    if (!root.requestedOpen || heldLease !== root.lease || heldGeneration !== root.localGeneration) return;
                    if (root.coordinator) {
                        const dismissed = root.coordinator.closePopups(root.popupToken, heldLease);
                        if (!dismissed && root.coordinator.modalActive) {
                            const expected = heldLease;
                            const expectedGeneration = heldGeneration;
                            Qt.callLater(function(){
                                if(root && root.requestedOpen && root.lease === expected && root.localGeneration === expectedGeneration && root.coordinator.popupGeneration === expected && root.coordinator.modalActive && grab) grab.active=true;
                            });
                        }
                    }
                    else root.dismissRequested();
                }
            }
        }
    }
}
