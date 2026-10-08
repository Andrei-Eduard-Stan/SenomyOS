import QtQuick

// Shared route navigation. Selection and keyboard focus are independent until
// activation; changing a route restores focus after its old content is destroyed.
ListView {
    id: root
    property var sections: []
    property string activeSection: ""
    property bool restoreFocus: false
    signal sectionRequested(string section)

    spacing: 9
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: sections

    function available(index) {
        return index >= 0 && index < sections.length && sections[index].enabled !== false;
    }

    function focusIndex(index) {
        if (!available(index) || !restoreFocus)
            return false;
        currentIndex = index;
        positionViewAtIndex(index, ListView.Contain);
        Qt.callLater(function() {
            // Recheck after deferred creation: closing or replacing the model
            // must not revive old focus or select the wrong route.
            if (!root.restoreFocus || !root.available(index) || root.currentIndex !== index)
                return;
            const item = root.itemAtIndex(index);
            if (item)
                item.forceActiveFocus(Qt.TabFocusReason);
        });
        return true;
    }

    function focusSection() {
        return focusIndex(sections.findIndex(section => section.id === activeSection));
    }

    function moveFocus(step, edge) {
        let index = edge ? (step > 0 ? 0 : sections.length - 1) : currentIndex + step;
        while (index >= 0 && index < sections.length) {
            if (available(index))
                return focusIndex(index);
            index += step;
        }
        return false;
    }

    onActiveSectionChanged: if (restoreFocus) focusSection()
    onRestoreFocusChanged: if (restoreFocus) focusSection()
    onSectionsChanged: if (restoreFocus) focusSection()
    Component.onCompleted: if (restoreFocus) focusSection()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            moveFocus(1, false);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            moveFocus(-1, false);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            moveFocus(1, true);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            moveFocus(-1, true);
            event.accepted = true;
        }
    }

    delegate: DashboardButton {
        required property var modelData
        required property int index
        objectName: "dashboard-nav-" + modelData.id
        width: ListView.view.width
        text: modelData.label
        iconName: modelData.icon || "applications.svg"
        height: 48
        detail: modelData.detail || ""
        active: root.activeSection === modelData.id
        enabled: modelData.enabled !== false
        onActiveFocusChanged: if (activeFocus) {
            root.currentIndex = index;
            root.positionViewAtIndex(index, ListView.Contain);
        }
        onClicked: root.sectionRequested(modelData.id)
    }
}
