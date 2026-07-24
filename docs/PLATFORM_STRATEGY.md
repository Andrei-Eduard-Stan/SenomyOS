# SenomyOS Platform and Deployment Strategy

## North star

SenomyOS should become a system a user can deploy, boot, operate, update, and
recover on supported hardware with minimal manual configuration.

The final product is more than Eww and Hyprland configuration. It includes:

- an Arch Linux base;
- package and service definitions;
- the SenomyOS shell and visual assets;
- safe data and action services;
- hardware and form-factor adaptation;
- installation and first-boot setup;
- updates, migrations, rollback, and recovery;
- a tested compatibility story.

The current T480 is the first reference machine and development environment.
It must not become an invisible hardware requirement.

## Compatibility tiers

### Tier 1 — Desktop and laptop

Initial supported class:

- x86_64 PCs with mainline Arch Linux support;
- keyboard, mouse, touchpad, or pointing stick;
- one or more monitors;
- common PipeWire and NetworkManager devices;
- optional single or dual batteries.

This is the first stable release target.

### Tier 2 — Touch and convertible

Target after the pointer/keyboard shell is stable:

- touchscreen laptops;
- convertibles;
- portrait and landscape work areas;
- on-screen keyboard integration;
- larger touch density;
- optional gestures with visible alternatives.

### Tier 3 — Mini PC, kiosk, and appliance

Target characteristics:

- no battery may be present;
- input devices may be hot-plugged;
- display and network may be the primary devices;
- a simplified first-boot path may be useful.

### Tier 4 — Tablet, ARM, and phone-sized devices

Experimental until specific hardware is tested.

The UI can be designed to scale to phone-sized work areas, but deployability
depends on:

- bootloader access;
- mainline or maintained kernels;
- GPU/display support;
- touch, orientation, and sensor support;
- suspend and power management;
- modem and telephony support where desired;
- Hyprland, Eww, and supporting packages on the architecture.

SenomyOS should publish specific tested devices rather than claim all phones or
tablets are supported.

## Layered system design

```text
Hardware
  ↓
Arch Linux base and drivers
  ↓
System services and session
  ↓
Capability detection and hardware profile
  ↓
Hyprland and SenomyOS portable defaults
  ↓
Adaptive Eww shell
  ↓
User preferences and personal state
```

Packaged defaults and user preferences must remain separate. An update should
not overwrite personal settings, and a machine profile should not fork the
whole configuration.

## Configuration hierarchy

Target precedence:

```text
portable defaults
  → architecture/form-factor profile
  → hardware-specific override
  → user preference
```

Profiles should contain only necessary differences.

Avoid embedding:

- usernames or fixed home paths;
- a specific monitor such as `eDP-1`;
- monitor index `0`;
- interface names such as `wlp3s0`;
- fixed battery names or battery counts;
- one wallpaper path;
- fixed 1920x1080 geometry;
- T480-specific device names.

## Deployment evolution

### Phase A — Portable live configuration

- remove hard-coded paths and device IDs;
- define dependencies;
- normalize data collectors;
- add graceful missing-hardware states;
- validate on the T480 and a clean test environment.

### Phase B — Repeatable bootstrap

- maintain package and service manifests;
- install SenomyOS defaults reproducibly;
- enable required user/system services;
- select a profile during first boot;
- retain logs and rollback information.

### Phase C — Packaged SenomyOS components

- package the shell, scripts, assets, and defaults;
- version configuration migrations;
- separate system defaults from user-owned state;
- add release metadata and checks.

### Phase D — Bootable installer and recovery

- build a bootable Arch-based installation/recovery image;
- automate base installation and SenomyOS selection;
- support offline recovery of the shell where practical;
- document update, rollback, and repair.

### Phase E — Hardware matrix

- test representative laptops, desktops, mini PCs, and touch devices;
- record working, partial, and unsupported capabilities;
- gate stable releases on real tests;
- keep experimental phone/ARM work isolated from stable x86_64 releases.

## Adaptive shell strategy

The shell adapts through work-area geometry and capabilities rather than
device model names.

Suggested modes:

```text
compact-pointer
comfortable-pointer
touch-landscape
touch-portrait
narrow-phone
```

Mode selection can begin with an explicit profile. Automatic detection may be
added only when it is dependable and remains user-overridable.

Adaptive behavior includes:

- target size and spacing;
- bar information priority;
- Control Centre navigation style;
- Performance Dashboard column count;
- panel anchoring and safe areas;
- text abbreviation;
- on-screen keyboard accommodation;
- orientation-specific layout.

## Touch requirements

- Primary targets are at least 44x44 logical pixels in touch mode.
- No essential information is hover-only.
- Swipe or drag interactions have visible button alternatives.
- Destructive actions are separated spatially and require confirmation.
- Scrollable areas have comfortable edge padding.
- The active element remains visually clear beneath a finger.
- The design tolerates touch devices without a physical keyboard.
- Text input surfaces account for an on-screen keyboard where possible.

## Hardware profiles

A profile describes capabilities and necessary overrides, not the entire
desktop.

Potential profile data:

```text
form factor
preferred density
touch availability
orientation support
internal display
battery behavior
special input devices
known driver limitations
safe suspend/power actions
```

Profiles must have a portable fallback. Unknown hardware should boot into a
safe generic layout with unsupported features marked unavailable.

## Testing strategy

Before claiming portability:

1. validate in a clean virtual machine;
2. test a fresh user account;
3. test missing optional commands;
4. test zero, one, and multiple batteries where possible;
5. test one and multiple monitors;
6. test disconnected networking and audio;
7. test narrow and portrait work areas;
8. test pointer-only, keyboard-only, and touch-oriented flows;
9. measure idle resource use;
10. test installation, update, rollback, and recovery.

Physical hardware remains necessary for touch, sensors, power management, GPU,
sleep, and modem validation.

## Release requirements

A release should eventually include:

- supported architectures and devices;
- package/service manifest versions;
- configuration version and migrations;
- installation instructions;
- checksums or signatures;
- known limitations;
- update and rollback steps;
- recovery instructions;
- compatibility test results.

## Non-goals for the current phase

The current revival does not immediately need to:

- replace the Arch installer;
- support every PC or phone;
- manage telephony;
- automate privileged actions from Eww;
- build an ISO before the live shell is stable.

Current work should, however, avoid architectural choices that make those
future stages unnecessarily difficult.
