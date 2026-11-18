import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Provider intent and observed D-Bus ownership are separate states.
Scope {
    id: root

    // A commitment is a distinct pinned system category, projected directly
    // from PowerService. It never enters timeout, clear-all or history storage.
    property var sessionService: null
    readonly property var commitment: sessionService && sessionService.hasSchedule ? sessionService.schedule : null
    signal openSessionRequested()
    readonly property bool serverRequested: String(Quickshell.env("SENOMY_NOTIFICATION_OWNER") || "") === "quickshell"
    property var ownership: ({available:false,owned:false,owner_pid:0,state:"unavailable",message:"Checking desktop notification ownership…"})
    readonly property bool serverEnabled: serverRequested && ownership.owned === true
    readonly property string ownershipMessage: ownership.message
    Process {
        id:ownershipObserver
        running:root.serverRequested
        command:["python3",Quickshell.shellDir+"/scripts/notification-owner.py",String(Quickshell.processId)]
        stdout:SplitParser {onRead:data=>{try{root.ownership=JSON.parse(data);}catch(_){root.ownership={available:false,owned:false,owner_pid:0,state:"unavailable",message:"Invalid notification ownership response."};}}}
        onExited:(code,status)=>{if(root.serverRequested)root.ownership={available:false,owned:false,owner_pid:0,state:"unavailable",message:"Desktop notification ownership observer is unavailable."};}
    }
    readonly property var server: serverLoader.item
    readonly property var activeNotifications: server ? server.trackedNotifications.values : []
    readonly property string storePath: String(Quickshell.env("SENOMY_NOTIFICATION_STORE") || "")
    property string clearContext: ""
    readonly property bool clearAvailable: serverEnabled && storePath.length > 0
    property alias clearActions: clearGuard
    property bool clearingHistory: false
    property bool clearWritePending: false
    NotificationClearActions { id: clearGuard; provider: root; context: root.clearContext }
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
        if (!storePath || clearingHistory)
            return;
        const records = history.slice(0, 120).map(serializable);
        store.setText(JSON.stringify({schemaVersion: 1, dnd: dnd, history: records}));
    }

    function recordFor(notification, receivedAt) {
        return {
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
            receivedAt: receivedAt,
            unread: !notification.transient,
            closeReason: "",
            object: notification
        };
    }

    function receive(notification) {
        notification.tracked = true;
        const record = recordFor(notification, Date.now());
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

    function synchronize(notification) {
        // Quickshell applies a replacement ID by mutating the current tracked
        // object. Consolidate its property-change burst into one new record.
        const record = recordFor(notification, Date.now());
        latest = record;
        const next = history.filter(existing => existing.id !== record.id);
        if (!record.transient)
            next.unshift(record);
        history = next.slice(0, 120);
        persist();
        if (!dnd)
            toastGeneration += 1;
    }

    function recordClosed(notification, reason) {
        const reasonName = NotificationCloseReason.toString(reason);
        history = history.map(record => {
            // Replacement generations reuse an ID. Object identity prevents
            // an old generation's close event from marking its replacement.
            if (record.object !== notification)
                return record;
            const updated = serializable(record);
            updated.unread = record.unread;
            updated.closeReason = reasonName;
            return updated;
        });
        if (latest && latest.object === notification) {
            const updatedLatest = serializable(latest);
            updatedLatest.closeReason = reasonName;
            latest = updatedLatest;
        }
        persist();
    }

    function recordKey(record) {
        return record ? String(record.id) + "@" + String(record.receivedAt || 0) : "";
    }
    function currentRecord(record) {
        const key = recordKey(record);
        if (!key) return null;
        return history.find(item => recordKey(item) === key)
            || (latest && recordKey(latest) === key ? latest : null);
    }
    function isLive(record) {
        const current = currentRecord(record);
        return Boolean(serverEnabled && current && current.object && activeNotifications.indexOf(current.object) >= 0);
    }
    function dismiss(record) {
        const current = currentRecord(record);
        if (!current) return false;
        const key = recordKey(current);
        if (isLive(current)) current.object.dismiss();
        history = history.filter(existing => recordKey(existing) !== key);
        persist();
        return true;
    }
    function invoke(record, action) {
        const current = currentRecord(record);
        if (!isLive(current) || !action || (current.actions || []).indexOf(action) < 0) return false;
        action.invoke();
        if (!current.resident && isLive(current)) current.object.dismiss();
        return true;
    }
    // No argument means the explicit Read all action. A record reads just that
    // version; never mark offscreen messages merely because a view was opened.
    function markRead(record) {
        const key = record ? recordKey(record) : "";
        if (record && !history.some(item => recordKey(item) === key)) return false;
        let changed = false;
        const next = history.map(item => {
            if (!item.unread || (record && recordKey(item) !== key)) return item;
            changed = true;
            return Object.assign({}, item, {unread: false});
        });
        if (!changed) return false;
        history = next;
        persist();
        return true;
    }

    // Compatibility request path: this no longer deletes anything immediately.
    function clearAll(ownerContext) {
        return clearGuard.request(ownerContext || clearContext);
    }

    function clearConfirmed(historySnapshot, activeSnapshot) {
        if (clearGuard.actionState !== "running" || !clearGuard.valid()
                || historySnapshot !== history || activeSnapshot !== clearGuard.requestedActive)
            return false;
        clearingHistory = true;
        try {
            for (const notification of activeSnapshot)
                notification.dismiss();
            history = [];
            latest = null;
        } finally {
            clearingHistory = false;
        }
        error = "";
        clearWritePending = true;
        persist();
        return true;
    }

    function setDnd(value) {
        dnd = value;
        persist();
    }

    Loader {
        id: serverLoader
        active: root.serverRequested
        sourceComponent: Component {
            NotificationServer {
                keepOnReload: true
                persistenceSupported: true
                bodySupported: true
                bodyMarkupSupported: false
                bodyHyperlinksSupported: false
                bodyImagesSupported: false
                actionsSupported: true
                actionIconsSupported: false
                imageSupported: false
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
                    root.recordClosed(tracker.modelData, reason);
                }
                function onAppNameChanged() { replacementSync.restart(); }
                function onAppIconChanged() { replacementSync.restart(); }
                function onSummaryChanged() { replacementSync.restart(); }
                function onBodyChanged() { replacementSync.restart(); }
                function onUrgencyChanged() { replacementSync.restart(); }
                function onActionsChanged() { replacementSync.restart(); }
                function onResidentChanged() { replacementSync.restart(); }
                function onTransientChanged() { replacementSync.restart(); }
                function onDesktopEntryChanged() { replacementSync.restart(); }
                function onImageChanged() { replacementSync.restart(); }
            }

            Timer {
                id: replacementSync
                interval: 1
                onTriggered: root.synchronize(tracker.modelData)
            }

            Timer {
                interval: tracker.modelData.expireTimeout > 0
                    ? Math.max(1000, tracker.modelData.expireTimeout) : 5000
                running: tracker.modelData.urgency !== NotificationUrgency.Critical
                    && !tracker.modelData.resident
                    && tracker.modelData.expireTimeout !== 0
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
        onSaved: {
            if (root.clearWritePending) {
                root.clearWritePending = false;
                clearGuard.saved();
            }
        }
        onSaveFailed: error => {
            root.error = "Notification history could not be saved";
            if (root.clearWritePending) {
                root.clearWritePending = false;
                clearGuard.fail("Notifications were cleared in memory, but saving failed. Retained history may return after restart.");
            }
        }
    }
}
