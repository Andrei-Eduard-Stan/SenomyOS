import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The server object is instantiated only when the selector explicitly gives
// Quickshell notification ownership. SwayNC therefore remains the sole owner
// in the current Milestone 2-compatible mode.
Scope {
    id: root

    readonly property bool serverEnabled: String(Quickshell.env("SENOMY_NOTIFICATION_OWNER") || "") === "quickshell"
    readonly property var server: serverLoader.item
    readonly property var activeNotifications: server ? server.trackedNotifications.values : []
    readonly property string storePath: String(Quickshell.env("SENOMY_NOTIFICATION_STORE") || "")
    property var history: []
    property var latest: null
    property bool dnd: false
    property int toastGeneration: 0
    property string error: ""
    readonly property int unreadCount: history.filter(record => record.unread).length
    readonly property int activeCount: activeNotifications.length

    function serializable(record) {
        return {
            id: record.id,
            appName: record.appName,
            appIcon: record.appIcon,
            summary: record.summary,
            body: record.body,
            urgency: record.urgency,
            resident: record.resident,
            transient: record.transient,
            desktopEntry: record.desktopEntry,
            image: record.image,
            receivedAt: record.receivedAt,
            unread: record.unread,
            closeReason: record.closeReason || ""
        };
    }

    function persist() {
        if (!storePath)
            return;
        const records = history.slice(0, 120).map(serializable);
        store.setText(JSON.stringify({schemaVersion: 1, dnd: dnd, history: records}));
    }

    function receive(notification) {
        notification.tracked = true;
        const record = {
            id: notification.id,
            appName: notification.appName || "Unknown application",
            appIcon: notification.appIcon || "",
            summary: notification.summary || "Notification",
            body: notification.body || "",
            urgency: NotificationUrgency.toString(notification.urgency),
            resident: notification.resident,
            transient: notification.transient,
            desktopEntry: notification.desktopEntry || "",
            image: notification.image || "",
            actions: notification.actions,
            receivedAt: Date.now(),
            unread: !notification.transient,
            closeReason: "",
            object: notification
        };
        latest = record;
        if (!notification.transient) {
            const next = history.filter(existing => existing.id !== record.id);
            next.unshift(record);
            history = next.slice(0, 120);
            persist();
        }
        if (!dnd)
            toastGeneration += 1;
    }

    function recordClosed(id, reason) {
        const reasonName = NotificationCloseReason.toString(reason);
        history = history.map(record => {
            if (record.id !== id)
                return record;
            const updated = serializable(record);
            updated.unread = record.unread;
            updated.closeReason = reasonName;
            return updated;
        });
        persist();
    }

    function dismiss(record) {
        if (!record)
            return false;
        if (record.object)
            record.object.dismiss();
        history = history.filter(existing => existing.id !== record.id);
        persist();
        return true;
    }

    function invoke(record, action) {
        if (!record || !record.object || !action)
            return false;
        action.invoke();
        return true;
    }

    function markRead() {
        history = history.map(record => {
            const updated = Object.assign({}, record);
            updated.unread = false;
            return updated;
        });
        persist();
    }

    function clearAll() {
        for (const notification of activeNotifications)
            notification.dismiss();
        history = [];
        latest = null;
        persist();
    }

    function setDnd(value) {
        dnd = value;
        persist();
    }

    Loader {
        id: serverLoader
        active: root.serverEnabled
        sourceComponent: Component {
            NotificationServer {
                keepOnReload: true
                persistenceSupported: true
                bodySupported: true
                bodyMarkupSupported: false
                bodyHyperlinksSupported: false
                bodyImagesSupported: true
                actionsSupported: true
                actionIconsSupported: true
                imageSupported: true
                inlineReplySupported: false
                onNotification: notification => root.receive(notification)
            }
        }
    }

    Instantiator {
        model: root.server ? root.server.trackedNotifications : null
        delegate: Scope {
            id: tracker
            required property var modelData

            Connections {
                target: tracker.modelData
                function onClosed(reason) {
                    root.recordClosed(tracker.modelData.id, reason);
                }
            }

            Timer {
                interval: tracker.modelData.expireTimeout > 0
                    ? Math.max(1000, tracker.modelData.expireTimeout) : 5000
                running: tracker.modelData.urgency !== NotificationUrgency.Critical
                    && !tracker.modelData.resident
                onTriggered: tracker.modelData.expire()
            }
        }
    }

    FileView {
        id: store
        path: root.storePath
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(store.text());
                if (parsed.schemaVersion === 1) {
                    root.dnd = Boolean(parsed.dnd);
                    root.history = (parsed.history || []).slice(0, 120);
                }
            } catch (error) {
                root.error = "Notification history could not be loaded";
            }
        }
        onSaveFailed: error => root.error = "Notification history could not be saved"
    }
}
