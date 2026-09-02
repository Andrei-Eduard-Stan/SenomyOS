//@ pragma UseQApplication
//@ pragma ShellId senomy-v2
//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "services" as Services

ShellRoot {
    id: shell

    Services.SystemMetrics { id: metricsService }
    Services.BatteryService { id: batteryService }
    Services.AudioService { id: audioService }
    Services.NetworkService { id: networkService }
    Services.PowerService { id: powerService }

    QtObject {
        id: sharedUiState
        property string activePopup: ""
    }

    IpcHandler {
        target: "shell"

        function popup(token: string): string {
            if (token !== "" && !/^(calendar|tray):[^:]+$/.test(token))
                return "invalid popup token";
            sharedUiState.activePopup = token;
            return sharedUiState.activePopup;
        }

        function closePopups(): string {
            sharedUiState.activePopup = "";
            return "closed";
        }

        function popupState(): string {
            return sharedUiState.activePopup;
        }

        function networkState(): string {
            return JSON.stringify({
                available: networkService.available,
                networkingEnabled: networkService.networkingEnabled,
                wifiEnabled: networkService.wifiEnabled,
                wifiHardwareEnabled: networkService.wifiHardwareEnabled,
                activeConnection: networkService.activeConnection,
                ssid: networkService.ssid,
                signalPercent: networkService.signalPercent,
                connectionState: networkService.connectionStateName,
                connectivity: networkService.connectivityName,
                primaryDevice: networkService.primaryDevice
            });
        }

        function powerState(): string {
            return JSON.stringify({
                available: powerService.available,
                state: powerService.state,
                allowedActions: powerService.allowedActions
            });
        }
    }

    Variants {
        model: Quickshell.screens

        RailWindow {
            metrics: metricsService
            battery: batteryService
            audio: audioService
            network: networkService
            power: powerService
            uiState: sharedUiState
        }
    }
}
