-- Root-owned, deliberately minimal compositor session for password recovery.
-- No application, shell, workspace, or mouse command bindings are defined.

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

hl.env("GDK_BACKEND", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("XCURSOR_SIZE", "24")

hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        background_color = 0xff08090b,
    },
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 0,
        col = {
            active_border = "rgba(08090bff)",
            inactive_border = "rgba(08090bff)",
        },
    },
    decoration = {
        rounding = 0,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled = false,
        },
    },
    animations = {
        enabled = false,
    },
    input = {
        kb_layout = "gb",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/local/libexec/senomy-recovery-ui")
end)

hl.window_rule({
    name = "secure-recovery-surface",
    match = { class = "^senomy-recovery$" },
    fullscreen = true,
    stay_focused = true,
})
