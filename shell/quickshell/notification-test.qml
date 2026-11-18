//@ pragma UseQApplication
//@ pragma ShellId senomy-v2-notification-test

import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    Services.NotificationService { id: notifications; clearContext: "notifications:fixture" }

    property var heldRecord: null
    property var heldAction: null
    IpcHandler {
        target: "notification-test"

        function state(): string {
            return JSON.stringify({
                clearState: notifications.clearActions.actionState,
                clearMessage: notifications.clearActions.message,
                serverEnabled: notifications.serverEnabled,
                activeCount: notifications.activeCount,
                unreadCount: notifications.unreadCount,
                dnd: notifications.dnd,
                toastGeneration: notifications.toastGeneration,
                history: notifications.history.map(record => ({
                    id: record.id,
                    appName: record.appName,
                    summary: record.summary,
                    body: record.body,
                    unread: record.unread,
                    recordKey: notifications.recordKey(record),
                    urgency: record.urgency,
                    resident: record.resident,
                    transient: record.transient,
                    closeReason: record.closeReason || "",
                    actionCount: record.actions ? record.actions.length : 0
                })),
                latest: notifications.latest ? {
                    id: notifications.latest.id,
                    summary: notifications.latest.summary,
                    transient: notifications.latest.transient,
                    actionCount: notifications.latest.actions ? notifications.latest.actions.length : 0
                } : null,
                error: notifications.error
            });
        }

        function setDnd(enabled: bool): string {
            notifications.setDnd(enabled);
            return notifications.dnd ? "true" : "false";
        }

        function invokeLatest(identifier: string): string {
            if (!notifications.latest || !notifications.latest.actions)
                return "missing";
            const action = notifications.latest.actions.find(candidate => candidate.identifier === identifier);
            return notifications.invoke(notifications.latest, action) ? "invoked" : "missing";
        }

        function holdLatestAction(): string {
            heldRecord = notifications.latest;
            heldAction = heldRecord && heldRecord.actions ? heldRecord.actions[0] : null;
            return heldAction ? "held" : "missing";
        }
        function invokeHeld(): string { return notifications.invoke(heldRecord, heldAction) ? "invoked" : "missing"; }
        function readLatest(): string {
            return notifications.markRead(notifications.latest) ? "read" : "unchanged";
        }
        function readAll(): string { return notifications.markRead() ? "read" : "unchanged"; }

        function dismissLatest(): string {
            return notifications.dismiss(notifications.latest) ? "dismissed" : "missing";
        }

        function requestClear(): string {
            return notifications.clearAll("notifications:fixture") ? "pending" : "rejected";
        }
        function cancelClear(): string {
            return notifications.clearActions.cancel() ? "cancelled" : "rejected";
        }
        function confirmClear(): string {
            return notifications.clearActions.confirm("notifications:fixture") ? "confirmed" : "rejected";
        }
    }
}
