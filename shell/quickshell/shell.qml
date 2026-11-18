//@ pragma UseQApplication
//@ pragma ShellId senomy-v2
//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "components"
import "config" as Config
import "services" as Services
import "services/calendar" as CalendarServices
import "services/ScreenLifecycle.js" as Screens

ShellRoot {
    id: shell

    function reconcileScreens() {
        Screens.reconcile(shellState, Quickshell.screens.map(screen => screen.name));
    }

    Binding {target:Config.ReflectionLight;property:"onBattery";value:batteryService.onBattery}
    Services.SystemMetrics { id: metricsService }
    Services.BatteryService {
        id: batteryService
        onProfileFailure: message => {
            if (notificationService.serverEnabled)
                Quickshell.execDetached(["notify-send", "--app-name=SenomyOS", "--icon=battery", "--", "Power profile not verified", message]);
        }
        actionContext: shellState.activePopup.startsWith("battery:") ? shellState.activePopup : shellState.activePrimary === "control" && shellState.controlSection === "power"
            ? shellState.primaryScreen : ""
    }
    Services.AudioService {
        id: audioService
        active: (shellState.activePrimary === "control" && (shellState.controlSection === "audio" || shellState.controlPath === "devices/bluetooth")) || shellState.activePopup.startsWith("volume:")
        actionContext: shellState.activePopup.startsWith("volume:") ? shellState.activePopup
            : shellState.activePrimary === "control" && (shellState.controlSection === "audio" || shellState.controlPath === "devices/bluetooth") ? "audio:" + shellState.primaryScreen : ""
    }
    Services.NetworkService {
        id: networkService
        actionContext: shellState.activePopup.startsWith("network:") ? shellState.activePopup : shellState.activePrimary === "control" && shellState.controlSection === "network"
            ? shellState.primaryScreen+":"+shellState.controlPath : ""
    }
    Services.BluetoothService {
        id: bluetoothService
        onStateEvent:(message,failed)=>{
            if (notificationService.serverEnabled)
                Quickshell.execDetached(["notify-send","--app-name=SenomyOS","--icon=bluetooth","--",failed?"Bluetooth action failed":"Bluetooth",message]);
        }
        actionContext: shellState.activePopup.startsWith("bluetooth:") ? shellState.activePopup : !shellState.activePopup && shellState.activePrimary === "control" && shellState.controlSection === "devices" && shellState.controlPath === "devices/bluetooth"
            ? shellState.primaryScreen : ""
    }
    Services.DeviceInventory {
        id: deviceInventoryService
        active: shellState.activePrimary === "control" && shellState.controlSection === "devices"
        actionContext: active && shellState.controlPath.startsWith("devices/displays") ? shellState.primaryScreen : ""
    }
    Services.InputSettings {
        id: inputSettingsService
        active: shellState.activePrimary === "control" && shellState.controlSection === "input"
    }
    Services.SessionPolicy {
        id: sessionPolicyService
        active: shellState.activePrimary === "control"
            && (shellState.controlSection === "settings" || shellState.controlSection === "power")
    }
    Services.MediaService { id: mediaService }
    Services.NotificationService {
        id: notificationService
        sessionService: powerService
        onOpenSessionRequested: shellState.togglePopup("power",deviceInventoryService.preferredScreen)
        clearContext: shellState.activePopup.startsWith("notifications:") ? shellState.activePopup
            : shellState.activePrimary === "insights" && shellState.insightsSection === "notifications"
                ? "insights:" + shellState.primaryScreen : ""
    }
    Services.PowerService { id: powerService; active:shellState.activePopup.startsWith("power:") }
    Services.ShellState {
        id: shellState
        availableScreens: Quickshell.screens.map(screen=>screen.name)
        railWindows: rails.instances.filter(rail => rail.visible)
        confirmationSources: [accountService, networkService.actions, networkService.profiles.actions,
            audioService.selectionActions, audioService.graphActions, bluetoothService.actions,
            batteryService.selectionActions, batteryService.care, notificationService.clearActions,
            desktopSettingsService.actions, deviceInventoryService.displayActions, performanceService.managedServices.actions]
        externalModalActive: !!bluetoothService.prompt || powerService.state === "pending" || powerService.state === "running"
            || performanceService.processActionState === "pending" || performanceService.benchmarkActionState === "pending"
            || deviceInventoryService.displayActions.actionState === "revert-pending"
            || (deviceInventoryService.displayActions.actionState === "failed" && !!deviceInventoryService.displayActions.token)
        onModalCancelRequested: {
            if (bluetoothService.prompt) bluetoothService.answer(false, "");
            // Escape cancels a review, never confirms an action. Display preview
            // has explicit Keep/Revert controls and independent timed recovery.
            if (powerService.state === "pending") powerService.cancel();
            if (performanceService.processActionState === "pending") performanceService.cancelProcessAction();
            if (performanceService.benchmarkActionState === "pending") performanceService.cancelBenchmarkRequest();
            for (const source of confirmationSources)
                if (source && source.actionState === "pending" && typeof source.cancel === "function") source.cancel();
        }
    }
    Services.AccountService {
        id: accountService
        active: shellState.activePrimary === "control" && shellState.controlSection === "accounts"
        context: active ? shellState.controlMode + ":" + shellState.primaryScreen : ""
    }
    CalendarServices.CalendarService {
        id:calendarServiceOwner
        // Quick Calendar owns independent scoped queries; this range belongs to the full workspace.
        active:shellState.activePrimary === "control" && shellState.controlSection === "calendar"
        onComposeRequested:(kind,date,screenName)=>shellState.showSettings(screenName || shellState.primaryScreen || (Quickshell.screens.length?Quickshell.screens[0].name:""),"calendar/month")
        onOpenEventRequested:(source,uid,rid)=>shellState.showSettings(shellState.primaryScreen || (Quickshell.screens.length?Quickshell.screens[0].name:""),"calendar/agenda")
    }
    Services.PerformanceService {
        id: performanceService
        metrics: metricsService
        active: shellState.dashboardActive
        processPageActive: active && shellState.performanceSection === "processes"
        summaryPageActive: active && ["cpu","memory"].indexOf(shellState.performanceSection)>=0
        benchmarkPageActive: active && shellState.performanceSection === "benchmarks"
        actionContext: active ? "performance:" + shellState.performanceSection + ":" + shellState.primaryScreen : ""
    }
    Services.DesktopSettings {
        id: desktopSettingsService
        active: shellState.activePrimary === "control" && ["apps","settings"].indexOf(shellState.controlSection) >= 0
        context: active ? shellState.controlSection+":"+shellState.primaryScreen : ""
    }
    Services.InsightsService {
        id: insightsService
        active: shellState.activePrimary === "insights"
            || (shellState.dashboardActive && ["diagnostics","console","reports"].indexOf(shellState.performanceSection) >= 0)
        section: shellState.dashboardActive ? shellState.performanceSection : shellState.insightsSection
    }
    Services.SenomyState {
        id: senomyState
        performance: performanceService
        insights: insightsService
        shellState: shellState
        media: mediaService
        battery: batteryService
        network: networkService
        metrics: metricsService
        notifications: notificationService
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            Qt.callLater(shell.reconcileScreens);
        }
    }

    Timer {
        id:captureRecovery;interval:600000
        onTriggered:{shellState.capturePaused=false;shellState.captureToken="";}
    }
    IpcHandler {
        target: "shell"

        function commandLens(mode: string): string {
            if (["all","apps","files","windows","actions"].indexOf(mode)<0) return "invalid";
            const monitor=Hyprland.focusedMonitor;
            const rail=rails.instances.find(r=>r.visible && monitor && r.screen.name===monitor.name) || rails.instances.find(r=>r.visible);
            if (!rail) return "unavailable";
            return rail.openCommandLens(mode, null) ? "accepted" : "blocked";
        }
        function oskToggle(): string {
            const accepted=inputSettingsService.oskController.toggle();
            if (accepted && inputSettingsService.oskController.state !== "hide-requested") {shellState.closePrimary();shellState.closePopups();}
            return JSON.stringify({accepted:accepted,state:inputSettingsService.oskController.state,message:inputSettingsService.oskController.message});
        }

        function popup(token: string): string {
            if (token !== "" && !/^(volume|network|battery|tray|calendar|notifications|power|lens):[^:]+$/.test(token))
                return "invalid popup token";
            if (!token) shellState.closePopups();
            else if (shellState.activePopup !== token) {
                const separator = token.indexOf(":");
                shellState.togglePopup(token.slice(0, separator), token.slice(separator + 1));
            }
            return shellState.activePopup;
        }

        function captureSuspend(token: string): string {
            if (!shellState.pauseCapture(token)) return "rejected";
            captureRecovery.restart();return "paused";
        }
        function captureResume(token: string): string {
            if (!shellState.resumeCapture(token)) return "stale";
            captureRecovery.stop();return "restored";
        }
        function escapeExternal(): string {
            return shellState.dismissExternal(settingsWorkspace.ownsEscape() || rails.instances.some(rail=>rail.ownsEscape()));
        }
        function dismiss(): string {
            return shellState.escapeOverlay();
        }

        function closePopups(): string {
            return shellState.closePopups() ? "closed" : "review";
        }

        function interactionState(): string {
            return JSON.stringify({popup:shellState.activePopup,generation:shellState.popupGeneration,modal:shellState.modalActive,primary:shellState.activePrimary,mode:shellState.controlMode,route:shellState.controlPath || shellState.controlSection,history:shellState.controlHistory,historyIndex:shellState.controlHistoryIndex,rails:rails.instances.map(rail=>rail.interactionState())});
        }
        function activatePopup(kind: string, screenName: string): string {
            return shellState.togglePopup(kind,screenName) ? shellState.activePopup : "rejected";
        }
        function popupState(): string {
            return shellState.activePopup;
        }

        // Allowlisted native-window operations for launchers and verification;
        // no command text, other application's window or system device.
        function renderMetrics(action: string): string {
            if (action === "start") Config.RenderMetrics.start();
            else if (action === "stop") Config.RenderMetrics.stop();
            else if (action !== "state") return "invalid";
            return JSON.stringify(Config.RenderMetrics.snapshot());
        }
        function desktopQualityState(): string {
            return JSON.stringify({decorationClients:Config.ReflectionLight.activeClients,decorationRunning:Config.ReflectionLight.running,decorationTickMs:Config.ReflectionLight.tickMs,onBattery:Config.ReflectionLight.onBattery,reducedMotion:Config.Motion.reduced,textScale:Config.DirectoryStyle.textScale,highContrast:Config.DirectoryStyle.highContrast});
        }
        function settingsWindow(action: string): string {
            const window=settingsWorkspace.nativeSettingsWindow;
            if(action !== "state") {
                if(shellState.activePrimary !== "control" || shellState.controlMode !== "full")return "unavailable";
                if(action === "maximize") {if(!settingsWorkspace.setSettingsMaximized(true))return "unavailable";}
                else if(action === "restore") {if(!settingsWorkspace.setSettingsMaximized(false))return "unavailable";}
                else if(action === "focus")settingsWorkspace.focusWorkspace();
                else return "invalid";
            }
            return JSON.stringify({visible:window.visible,width:window.width,height:window.height,maximized:settingsWorkspace.settingsMaximized,ownedToplevel:Boolean(settingsWorkspace.settingsToplevel),processId:Quickshell.processId,usingLua:Hyprland.usingLua,geometryInitialized:settingsWorkspace.settingsGeometryInitialized});
        }
        function settings(screenName: string, section: string): string {
            return shellState.showSettings(screenName, section) ? "settings" : "rejected";
        }

        function primary(kind: string, screenName: string, section: string): string {
            if (kind === "") {
                return shellState.closePrimary() ? "closed" : "review";
            }
            return shellState.showPrimary(kind, screenName, section) ? shellState.activePrimary : "invalid";
        }

        function calendarState(): string {
            return JSON.stringify({available:calendarServiceOwner.available,eventCount:calendarServiceOwner.snapshot.eventCount||0,sourceCount:calendarServiceOwner.sources.length,reminderCount:calendarServiceOwner.reminders.length,healthError:calendarServiceOwner.snapshot.healthError||"",error:calendarServiceOwner.error});
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
                primaryDevice: networkService.primaryDevice,
                providerObserved: networkService.profiles.providerAvailable,
                profileCount: networkService.profiles.items.length,
                interfaceCount: (networkService.profiles.status.devices || []).length
            });
        }

        function audioState(): string {
            return JSON.stringify({
                available: audioService.available,
                volume: audioService.volume,
                muted: audioService.muted,
                outputName: audioService.outputName,
                outputCount: audioService.outputNodes.length,
                inputAvailable: audioService.inputAvailable,
                inputVolume: audioService.inputVolume,
                inputMuted: audioService.inputMuted,
                inputName: audioService.inputName,
                inputCount: audioService.inputNodes.length,
                detailActive: audioService.active,
                graphAvailable: audioService.graphSnapshot.available===true,
                cardCount: (audioService.graphSnapshot.cards || []).length,
                playbackCount: audioService.playbackStreams.length,
                recordingCount: audioService.recordingCount,
                selectionState: audioService.selectionActions.actionState,
                advancedActionState: audioService.graphActions.actionState,
                amplification: audioService.amplification
            });
        }

        function batteryState(): string {
            return JSON.stringify({
                available: batteryService.available,
                count: batteryService.count,
                percentage: batteryService.chargeAvailable ? batteryService.percentage : null,
                chargeState: batteryService.chargeState,
                charging: batteryService.charging,
                onBattery: batteryService.onBattery,
                timeLabel: batteryService.timeLabel,
                low: batteryService.low,
                critical: batteryService.critical,
                powerProfileAvailable: batteryService.powerProfileAvailable,
                powerProfileName: batteryService.powerProfileName,
                powerBackend: batteryService.energy.backend,
                powerObservationFresh: batteryService.energy.fresh,
                powerDiagnostics: batteryService.energy.diagnostics,
                packs: batteryService.batteries.map(device => ({
                    model: device.model,
                    percentage: device.percentage,
                    energy: device.energy,
                    energyCapacity: device.energyCapacity,
                    state: String(device.state)
                }))
            });
        }

        function powerState(): string {
            return JSON.stringify({
                available: powerService.available,
                state: powerService.state,
                allowedActions: powerService.allowedActions,
                schedulingAvailable: powerService.schedulingAvailable,
                schedule: powerService.schedule
            });
        }

        function powerRequest(action: string): string {
            return powerService.request(action) ? powerService.state : "rejected";
        }

        function powerCancel(): string {
            return powerService.cancel() ? powerService.state : "rejected";
        }

        function performanceState(): string {
            return JSON.stringify({
                active: performanceService.active,
                cpuSamples: performanceService.cpuHistory.length,
                collectorObservedAt: metricsService.observedAt,
                collectorReady: metricsService.ready,
                collectorError: metricsService.error,
                retainedSamples: metricsService.history.samples.length,
                retentionSeconds: metricsService.history.retentionSeconds,
                historyWindowSeconds: performanceService.historySeconds,
                firstSampleAt: metricsService.history.samples.length ? metricsService.history.samples[0].at : null,
                lastSampleAt: metricsService.history.lastSampleAt,
                memorySamples: performanceService.memoryHistory.length,
                rxSamples: performanceService.rxHistory.length,
                txSamples: performanceService.txHistory.length,
                detailReady: Object.keys(performanceService.details).length > 0,
                processCount: performanceService.processes.length,
                benchmarkPageActive: performanceService.benchmarkPageActive,
                error: performanceService.error
            });
        }

        function insightsState(): string {
            return JSON.stringify({
                active: insightsService.active,
                section: insightsService.section,
                loadedRoutes: Object.keys(insightsService.payloads),
                actionState: insightsService.actionState,
                error: insightsService.error
            });
        }

        function projection(): string {
            deviceInventoryService.projectionEpoch++;
            return shellState.showPrimary("control", deviceInventoryService.preferredScreen, "devices/displays") ? "projection" : "unavailable";
        }
        function displayDraftJson(): string {return JSON.stringify(deviceInventoryService.draft.exported());}
        function restoreDisplayDraft(value: string): string {try{return deviceInventoryService.draft.restore(JSON.parse(value))?"restored":"invalid";}catch(e){return "invalid";}}
        function displayState(): string {
            return JSON.stringify({
                available:!deviceInventoryService.error,
                error:deviceInventoryService.error,
                displays:deviceInventoryService.displays.map(m=>({number:m.number,name:m.name,model:m.friendlyName,width:m.width,height:m.height,refreshRate:m.refreshRate,scale:m.scale,x:m.x,y:m.y,disabled:m.disabled,mirrorOf:m.mirrorOf})),
                draftDirty:deviceInventoryService.draft.dirty,
                draftConflict:deviceInventoryService.draft.conflict,
                selected:deviceInventoryService.draft.selectedDisplay?deviceInventoryService.draft.selectedDisplay.name:"",
                workspaceMode:deviceInventoryService.policy.workspaceMode,
                projection:deviceInventoryService.snapshot.projection||{},
                workspaces:deviceInventoryService.workspaces.map(w=>({id:w.id,label:w.displayLabel,monitor:w.monitor,windows:w.windows,visible:w.indicatorVisible,persistent:w.ispersistent})),
                transaction:deviceInventoryService.displayActions.actionState,
                profiles:deviceInventoryService.profiles.length
            });
        }

        function shellStateJson(): string {
            return JSON.stringify({
                activePrimary: shellState.activePrimary,
                primaryScreen: shellState.primaryScreen,
                activePopup: shellState.activePopup,
                controlMode: shellState.controlMode,
                controlRoute: shellState.controlPath || shellState.controlSection
            });
        }

        function bluetoothInspect(deviceId: string, view: string): string {
            if (!["overview","manage","details"].includes(view)) return "invalid view";
            const device=bluetoothService.objectFor(deviceId);
            if (!device || !device.address) return "device unavailable";
            const screen=shellState.primaryScreen || deviceInventoryService.preferredScreen;
            if (!screen || !shellState.showSettings(screen,"devices/bluetooth")) return "navigation blocked";
            bluetoothService.selectDevice(device);
            const token=device.token;
            Qt.callLater(()=>{if(bluetoothService.selectedDeviceToken===token)bluetoothService.inspectorView=view;});
            return "inspecting "+view;
        }

        function bluetoothState(): string {
            return JSON.stringify({
                available: bluetoothService.available,
                enabled: bluetoothService.enabled,
                discovering: bluetoothService.discovering,
                deviceCount: bluetoothService.devices.length,
                connectedCount: bluetoothService.connectedDevices.length,
                error: bluetoothService.error, scan: bluetoothService.scan, devices: bluetoothService.devices, operations: bluetoothService.operations, pairingPromptActive: !!bluetoothService.prompt
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
                ownership: notificationService.ownership,
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

    // A single settings workspace survives mode changes and output changes.
    // Rails own only entry controls; no monitor duplicates settings pages.
    readonly property var controlRail: rails.instances.find(rail => rail.screen && rail.screen.name === shellState.primaryScreen) || null
    // Closing clears coordinator ownership before the exit fade finishes.
    // Retain presentation placement until the next Control Centre opening.
    property var controlScreen: null
    property real controlCenterX: 0
    Binding {
        target: shell; property: "controlScreen"
        when: shellState.activePrimary === "control"
        value: Quickshell.screens.find(screen => screen.name === shellState.primaryScreen) || null
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: shell; property: "controlCenterX"
        when: shellState.activePrimary === "control"
        value: shell.controlRail ? shell.controlRail.controlAnchorX : (shell.controlScreen ? shell.controlScreen.width/2 : 0)
        restoreMode: Binding.RestoreNone
    }
    Connections {target:shellState;function onSettingsRequested(){Qt.callLater(()=>settingsWorkspace.focusWorkspace());}}
    ControlCentre {
        id:settingsWorkspace
        targetScreen: shell.controlScreen
        anchorCenterX: shell.controlCenterX
        state: shellState
        metrics: metricsService
        audio: audioService
        network: networkService
        bluetooth: bluetoothService
        deviceInventory: deviceInventoryService
        inputSettings: inputSettingsService
        sessionPolicy: sessionPolicyService
        desktopSettings: desktopSettingsService
        accounts: accountService
        calendarService: calendarServiceOwner
        battery: batteryService
        media: mediaService
        notifications: notificationService
        senomy: senomyState
    }
    Variants {
        id: rails
        model: Quickshell.screens

        RailWindow {
            notificationToastEnabled: modelData.name === deviceInventoryService.preferredScreen
            metrics: metricsService
            battery: batteryService
            audio: audioService
            network: networkService
            bluetooth: bluetoothService
            deviceInventory: deviceInventoryService
            inputSettings: inputSettingsService
            sessionPolicy: sessionPolicyService
            desktopSettings: desktopSettingsService
            accounts: accountService
            calendarService:calendarServiceOwner
            media: mediaService
            notifications: notificationService
            performance: performanceService
            insights: insightsService
            senomy: senomyState
            power: powerService
            uiState: shellState
        }
    }
    // Recovery/Identify do not inherit Rail visibility or fullscreen lifetime.
    Variants {
        model:Quickshell.screens
        Scope {
            required property var modelData
            DisplayIdentifyOverlay {targetScreen:modelData;inventory:deviceInventoryService}
            DisplayRecovery {targetScreen:modelData;inventory:deviceInventoryService}
        }
    }

}
