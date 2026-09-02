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
    Services.BluetoothService { id: bluetoothService }
    Services.MediaService { id: mediaService }
    Services.NotificationService { id: notificationService }
    Services.PowerService { id: powerService }
    Services.ShellState { id: shellState }
    Services.PerformanceService {
        id: performanceService
        metrics: metricsService
        active: shellState.dashboardActive
    }
    Services.InsightsService {
        id: insightsService
        active: shellState.activePrimary === "insights"
        section: shellState.insightsSection
    }
    Services.SenomyState {
        id: senomyState
        shellState: shellState
        media: mediaService
        battery: batteryService
        network: networkService
        metrics: metricsService
        notifications: notificationService
    }

    IpcHandler {
        target: "shell"

        function popup(token: string): string {
            if (token !== "" && !/^(volume|tray|calendar|notifications|power):[^:]+$/.test(token))
                return "invalid popup token";
            shellState.activePopup = token;
            return shellState.activePopup;
        }

        function closePopups(): string {
            shellState.closePopups();
            return "closed";
        }

        function popupState(): string {
            return shellState.activePopup;
        }

        function primary(kind: string, screenName: string, section: string): string {
            if (kind === "") {
                shellState.closePrimary();
                return "closed";
            }
            return shellState.showPrimary(kind, screenName, section) ? shellState.activePrimary : "invalid";
        }

        function companion(mode: string, screenName: string): string {
            return shellState.setCompanionMode(mode, screenName) ? shellState.companionMode : "invalid";
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

        function shellStateJson(): string {
            return JSON.stringify({
                activePrimary: shellState.activePrimary,
                primaryScreen: shellState.primaryScreen,
                activePopup: shellState.activePopup,
                companionMode: shellState.companionMode,
                companionScreen: shellState.companionScreen
            });
        }

        function bluetoothState(): string {
            return JSON.stringify({
                available: bluetoothService.available,
                enabled: bluetoothService.enabled,
                discovering: bluetoothService.discovering,
                deviceCount: bluetoothService.devices.length,
                connectedCount: bluetoothService.connectedDevices.length
            });
        }

        function mediaState(): string {
            return JSON.stringify({
                available: mediaService.available,
                identity: mediaService.identity,
                title: mediaService.title,
                artist: mediaService.artist,
                playing: mediaService.playing,
                playerCount: mediaService.players.length
            });
        }

        function notificationState(): string {
            return JSON.stringify({
                serverEnabled: notificationService.serverEnabled,
                activeCount: notificationService.activeCount,
                unreadCount: notificationService.unreadCount,
                dnd: notificationService.dnd,
                historyCount: notificationService.history.length
            });
        }

        function senomyStateJson(): string {
            return JSON.stringify({state: senomyState.state, message: senomyState.message});
        }
    }

    Variants {
        model: Quickshell.screens

        RailWindow {
            notificationToastEnabled: modelData === Quickshell.screens[0]
            metrics: metricsService
            battery: batteryService
            audio: audioService
            network: networkService
            bluetooth: bluetoothService
            media: mediaService
            notifications: notificationService
            performance: performanceService
            insights: insightsService
            senomy: senomyState
            power: powerService
            uiState: shellState
        }
    }
}
