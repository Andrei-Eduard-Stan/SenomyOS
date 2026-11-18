import QtQuick
import QtTest
import "../services"

TestCase {
    name: "NotificationClearActions"
    QtObject { id: activeOne }
    QtObject { id: activeTwo }
    QtObject {
        id: provider
        property bool clearAvailable: true
        property var history: []
        property var activeNotifications: []
        property int calls: 0
        property bool reject: false
        function clearConfirmed(records, active) {
            if (reject) return false;
            calls++;
            history = [];
            activeNotifications = [];
            return true;
        }
    }
    NotificationClearActions { id: guard; provider: provider }
    function init() {
        guard.actionState = "idle";
        guard.context = "notifications:fixture";
        guard.release();
        provider.clearAvailable = true;
        provider.history = [{id: 1}];
        provider.activeNotifications = [activeOne];
        provider.calls = 0;
        provider.reject = false;
    }
    function test_request_counts_cancel() {
        verify(guard.request(guard.context));
        compare(guard.retainedCount, 1);
        compare(guard.activeCount, 1);
        compare(provider.calls, 0);
        verify(guard.cancel());
        verify(!guard.confirm(guard.context));
        compare(provider.history.length, 1);
    }
    function test_confirm_once_await_save() {
        verify(guard.request(guard.context));
        verify(guard.confirm(guard.context));
        compare(provider.calls, 1);
        compare(guard.actionState, "running");
        verify(!guard.confirm(guard.context));
        verify(!guard.request(guard.context));
        guard.saved();
        compare(guard.actionState, "succeeded");
    }
    function test_new_history_rejected() {
        verify(guard.request(guard.context));
        provider.history = [{id: 2}, {id: 1}];
        verify(!guard.confirm(guard.context));
        compare(provider.calls, 0);
        compare(provider.history.length, 2);
    }
    function test_transient_active_change_rejected() {
        verify(guard.request(guard.context));
        provider.activeNotifications = [activeOne, activeTwo];
        verify(!guard.confirm(guard.context));
        compare(provider.calls, 0);
    }
    function test_same_count_replacement_rejected() {
        verify(guard.request(guard.context));
        provider.history = [{id: 1, summary: "replacement"}];
        verify(!guard.confirm(guard.context));
        compare(provider.calls, 0);
    }
    function test_context_change_and_wrong_owner() {
        verify(!guard.request("insights:fixture"));
        verify(guard.request(guard.context));
        verify(!guard.confirm("insights:fixture"));
        guard.context = "insights:fixture";
        compare(guard.actionState, "idle");
        verify(!guard.confirm(guard.context));
        compare(provider.calls, 0);
        verify(guard.request(guard.context));
        guard.context = "";
        verify(!guard.confirm("insights:fixture"));
    }
    function test_empty_unavailable_and_transient_only() {
        provider.history = [];
        provider.activeNotifications = [];
        verify(!guard.request(guard.context));
        provider.activeNotifications = [activeOne];
        verify(guard.request(guard.context));
        compare(guard.retainedCount, 0);
        provider.clearAvailable = false;
        verify(!guard.confirm(guard.context));
        compare(provider.calls, 0);
    }
    function test_save_failure_is_not_success() {
        verify(guard.request(guard.context));
        verify(guard.confirm(guard.context));
        guard.fail("fixture storage failure");
        guard.saved();
        compare(guard.actionState, "failed");
    }
    function test_rejection_and_new_notifications_after_clear() {
        provider.reject = true;
        verify(guard.request(guard.context));
        verify(!guard.confirm(guard.context));
        compare(provider.calls, 0);
        provider.reject = false;
        verify(guard.request(guard.context));
        verify(guard.confirm(guard.context));
        provider.history = [{id: 3}];
        guard.saved();
        compare(provider.history.length, 1);
        compare(guard.actionState, "succeeded");
    }
}
