import QtQuick
import QtTest
import "../services"

TestCase {
    name: "SelectionActions"
    QtObject { id: backend }
    QtObject { id: replacementBackend }
    QtObject { id: firstNode; property string name: "First endpoint" }
    QtObject { id: nextNode; property string name: "Next endpoint" }
    QtObject { id: foreignNode }
    QtObject {
        id: provider
        property var selectionBackend: null
        property bool available: true
        property string allowedKind: "output"
        property var options: []
        property var current: null
        property int writes: 0
        property bool reject: false
        property bool throwOnApply: false
        function selectionAvailable(kind) { return available && kind === allowedKind; }
        function selectionOptions(kind) { return selectionAvailable(kind) ? options : []; }
        function selectionCurrent(kind) { return current; }
        function selectionLabel(kind, value) { return kind + ": " + (typeof value === "number" ? value : value ? value.name : "none"); }
        function selectionImpact(kind) { return "Fixture impact"; }
        function applySelection(kind, target) {
            if (throwOnApply) throw new Error("fixture rejection");
            if (reject) return false;
            writes++;
            return true;
        }
    }
    SelectionActions { id: guard; provider: provider }
    property var targetValue: null
    function init() {
        guard.actionState = "idle";
        guard.release();
        guard.context = "screen-a";
        provider.available = true;
        provider.selectionBackend = backend;
        provider.writes = 0;
        provider.reject = false;
        provider.throwOnApply = false;
    }
    function rows() { return [{tag:"output",kind:"output"},{tag:"input",kind:"input"},{tag:"profile",kind:"profile"}]; }
    function setup(kind) {
        provider.allowedKind = kind;
        provider.current = kind === "profile" ? 1 : firstNode;
        targetValue = kind === "profile" ? 0 : nextNode;
        provider.options = [provider.current, targetValue];
    }
    function test_request_cancel_data() { return rows(); }
    function test_request_cancel(row) {
        setup(row.kind);
        verify(guard.request(row.kind, targetValue));
        compare(provider.writes, 0);
        verify(guard.cancel());
        verify(!guard.confirm());
        compare(provider.writes, 0);
    }
    function test_confirm_observed_once_data() { return rows(); }
    function test_confirm_observed_once(row) {
        setup(row.kind);
        verify(guard.request(row.kind, targetValue));
        verify(guard.confirm());
        compare(provider.writes, 1);
        verify(!guard.confirm());
        verify(!guard.request(row.kind, targetValue));
        guard.observe();
        compare(guard.actionState, "running");
        provider.current = targetValue;
        guard.observe();
        compare(guard.actionState, "succeeded");
    }
    function test_stale_current_data() { return rows(); }
    function test_stale_current(row) {
        setup(row.kind);
        verify(guard.request(row.kind, targetValue));
        provider.current = targetValue;
        verify(!guard.confirm());
        compare(provider.writes, 0);
    }
    function test_target_removed_data() { return rows(); }
    function test_target_removed(row) {
        setup(row.kind);
        verify(guard.request(row.kind, targetValue));
        provider.options = [provider.current];
        verify(!guard.confirm());
        compare(provider.writes, 0);
    }
    function test_backend_replaced_data() { return rows(); }
    function test_backend_replaced(row) {
        setup(row.kind);
        verify(guard.request(row.kind, targetValue));
        provider.selectionBackend = replacementBackend;
        verify(!guard.confirm());
        compare(provider.writes, 0);
    }
    function test_context_change_data() { return rows(); }
    function test_context_change(row) {
        setup(row.kind);
        verify(guard.request(row.kind, targetValue));
        guard.context = "screen-b";
        compare(guard.actionState, "idle");
        verify(!guard.confirm());
        verify(guard.request(row.kind, targetValue));
        guard.context = "";
        verify(!guard.confirm());
        verify(!guard.request(row.kind, targetValue));
        compare(provider.writes, 0);
    }
    function test_timeout_and_provider_loss_data() { return rows(); }
    function test_timeout_and_provider_loss(row) {
        setup(row.kind);
        verify(guard.request(row.kind, targetValue));
        verify(guard.confirm());
        guard.deadline = 0;
        guard.observe();
        compare(guard.actionState, "failed");
        verify(guard.request(row.kind, targetValue));
        verify(guard.confirm());
        provider.available = false;
        guard.observe();
        compare(guard.actionState, "failed");
    }
    function test_invalid_noop_reject_throw_data() { return rows(); }
    function test_invalid_noop_reject_throw(row) {
        setup(row.kind);
        verify(!guard.request("arbitrary", targetValue));
        verify(!guard.request(row.kind, foreignNode));
        verify(!guard.request(row.kind, provider.current));
        provider.reject = true;
        verify(guard.request(row.kind, targetValue));
        verify(!guard.confirm());
        provider.reject = false;
        provider.throwOnApply = true;
        verify(guard.request(row.kind, targetValue));
        verify(!guard.confirm());
        compare(provider.writes, 0);
    }
    function test_running_survives_dismissal_data() { return rows(); }
    function test_running_survives_dismissal(row) {
        setup(row.kind);
        verify(guard.request(row.kind, targetValue));
        verify(guard.confirm());
        guard.context = "";
        compare(guard.actionState, "running");
        provider.current = targetValue;
        guard.observe();
        compare(guard.actionState, "succeeded");
    }
}
