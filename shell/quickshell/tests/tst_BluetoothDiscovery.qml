import QtQuick
import QtTest
import "../services"

TestCase {
    name: "BluetoothDiscovery"
    QtObject { id: first; property bool enabled: true; property bool discovering: false }
    QtObject { id: second; property bool enabled: true; property bool discovering: false }
    BluetoothDiscovery { id: owner }
    function init() {
        owner.context = "";
        owner.adapter = null;
        first.enabled = true; second.enabled = true;
        first.discovering = false; second.discovering = false;
        owner.adapter = first;
    }
    function cleanup() { owner.context = ""; }
    function test_page_lifetime_and_screen_transfer() {
        compare(first.discovering, false);
        owner.context = "screen-a";
        compare(first.discovering, true);
        owner.context = "screen-b";
        compare(first.discovering, true);
        owner.context = "";
        compare(first.discovering, false);
    }
    function test_adapter_replacement_and_loss() {
        owner.context = "screen-a";
        owner.adapter = second;
        compare(first.discovering, false);
        compare(second.discovering, true);
        owner.adapter = null;
        compare(second.discovering, false);
    }
    function test_enable_while_page_open() {
        first.enabled = false;
        owner.context = "screen-a";
        compare(first.discovering, false);
        first.enabled = true;
        compare(first.discovering, true);
        first.enabled = false;
        compare(first.discovering, false);
    }
    function test_unowned_discovery_preserved() {
        first.discovering = true;
        owner.context = "screen-a";
        owner.context = "";
        compare(first.discovering, true);
        compare(owner.ownedAdapter, null);
    }
}
