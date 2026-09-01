//@ pragma UseQApplication
//@ pragma ShellId senomy-v2
//@ pragma IconTheme Papirus-Dark

import Quickshell
import "components"
import "services" as Services

ShellRoot {
    id: shell

    Services.SystemMetrics { id: metricsService }
    Services.BatteryService { id: batteryService }
    Services.AudioService { id: audioService }

    Variants {
        model: Quickshell.screens

        RailWindow {
            metrics: metricsService
            battery: batteryService
            audio: audioService
        }
    }
}
