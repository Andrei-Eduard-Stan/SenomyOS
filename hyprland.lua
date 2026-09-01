-- SenomyOS Hyprland configuration.
-- This Lua source supersedes hyprland.conf before Hyprland 0.57 removes the
-- legacy .conf format. Keep it portable: user paths come from the environment
-- and the monitor rule lets Hyprland discover the connected outputs. Display
-- scale is an explicit profile value: PPI-based automatic scaling made a
-- 1920x1080 panel resolve to only 1280x720 logical pixels on the reference
-- laptop and enlarged every application unexpectedly.

local home = os.getenv("HOME") or ""

local function selected_display_scale()
    local configHome = os.getenv("XDG_CONFIG_HOME")
    if configHome == nil or configHome == "" then
        configHome = home .. "/.config"
    end

    local profilePath = os.getenv("SENOMY_PROFILE")
    if profilePath == nil or profilePath == "" then
        profilePath = configHome .. "/senomyos/profile.json"
    end

    local profile = io.open(profilePath, "r")
    if profile == nil then
        return 1.0
    end

    local content = profile:read("*a") or ""
    profile:close()
    local display = content:match('"display"%s*:%s*{(.-)}') or ""
    local candidate = tonumber(display:match('"scale"%s*:%s*([0-9.]+)'))
    local allowed = { [1.0] = true, [1.25] = true, [1.5] = true, [1.75] = true, [2.0] = true }
    return allowed[candidate] and candidate or 1.0
end

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = selected_display_scale(),
})

local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "/usr/bin/env sh -c '$HOME/.local/bin/senomy-file-workspace'"
local menu = "/usr/bin/env sh -c '$HOME/.local/bin/senomy-command-lens'"

if os.getenv("SENOMY_NESTED_QA") ~= "1" then
    hl.on("hyprland.start", function()
        hl.exec_cmd("systemctl --user import-environment XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY DISPLAY && systemctl --user reset-failed workspaces.service && systemctl --user restart workspaces.service")
        hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
        hl.exec_cmd(home .. "/.config/eww/scripts/start-eww.sh")
        hl.exec_cmd(home .. "/.local/bin/senomy-wallpaper")
    end)
end

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = { top = 20, right = 20, bottom = 6, left = 20 },
        border_size = 1,
        col = {
            active_border = {
                colors = { "rgba(f4f5f8cc)", "rgba(9a72e8ee)" },
                angle = 55,
            },
            inactive_border = "rgba(777c8966)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding = 18,
        rounding_power = 2.4,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 14,
            render_power = 3,
            color = 0xa6000000,
        },
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        new_status = "master",
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
    input = {
        kb_layout = "gb,us",
        kb_variant = ",",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- The Rail owns a distinct layer namespace so compositor blur applies only to
-- its translucent glass pixels instead of every GTK layer-shell surface.
hl.layer_rule({
    name = "senomy-rail-glass",
    match = { namespace = "^senomy-rail$" },
    blur = true,
    ignore_alpha = 0.06,
    xray = false,
})

hl.layer_rule({
    name = "senomy-surface-glass",
    match = { namespace = "^senomy-(control|performance|insights|flyout|companion)$" },
    blur = true,
    ignore_alpha = 0.08,
    xray = false,
})

hl.layer_rule({
    name = "senomy-launcher-glass",
    match = { namespace = "^rofi$" },
    blur = true,
    ignore_alpha = 0.08,
    xray = false,
})

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("/usr/bin/env sh -c '$HOME/.local/bin/senomy-lock'"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), { locked = true })
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("/usr/bin/env sh -c '$HOME/.local/bin/senomy-fullscreen'"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + X", hl.dsp.layout("togglesplit"))

for direction, key in pairs({ left = "left", right = "right", up = "up", down = "down" }) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = direction }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = direction }))
end

for workspace = 1, 10 do
    local key = workspace % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = workspace }))
end

hl.bind("Print", hl.dsp.exec_cmd("/usr/bin/env sh -c '$HOME/.config/eww/scripts/screenshot-action.sh capture'"))
hl.bind("Escape", hl.dsp.exec_cmd("/usr/bin/env sh -c '$HOME/.config/eww/scripts/surface-state.sh dismiss'"), { non_consuming = true })
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("/usr/bin/env sh -c '$HOME/.local/bin/senomy-fullscreen immersive'"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "senomy-thunar-client-frame",
    match = { class = "^(thunar|Thunar)$" },
    rounding = 20,
    rounding_power = 2.0,
    border_size = 1,
})

hl.window_rule({
    name = "float-flameshot-launcher",
    match = { class = "^flameshot$", initial_title = "^Capture Launcher$" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "fullscreen-flameshot-capture",
    match = { class = "^flameshot$", initial_title = "^flameshot$" },
    float = true,
    fullscreen = true,
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})
