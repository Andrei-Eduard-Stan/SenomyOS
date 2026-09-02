//@ pragma UseQApplication
//@ pragma ShellId senomy-v2-notification-test

import Quickshell
import Quickshell.Io
import "services" as Services

ShellRoot {
    Services.NotificationService { id: notifications }

    IpcHandler {
        target: "notification-test"

        function state(): string {
            return JSON.stringify({
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

        function dismissLatest(): string {
            return notifications.dismiss(notifications.latest) ? "dismissed" : "missing";
        }

        function clearAll(): string {
            notifications.clearAll();
            return "cleared";
        }
    }
}
