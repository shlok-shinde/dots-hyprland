-- Nothing Liquid: liquid glass and the magic lamp, from the hyprglass fork
-- (branch nothing-liquid). Optional: without the plugin this file does nothing
-- and the shell keeps its own look.
--
-- The plugin is looked up at $NOTHING_LIQUID_PLUGIN, else
-- ~/.local/lib/nothing-liquid/hyprglass.so

local plugin = os.getenv("NOTHING_LIQUID_PLUGIN") or (HOME .. "/.local/lib/nothing-liquid/hyprglass.so")
-- Declarative: every parse lists the plugin. Skipping this once it is loaded
-- would read as "remove it", and the unload/reload would loop.
if is_file_exists(plugin) then
    hl.plugin.load(plugin)
end

-- Settings > Liquid glass in the shell (on/off, Clear / Tinted, edge
-- highlights) and its light or dark mode, written by
-- quickshell/ii/services/LiquidGlass.qml
local function shellSettings()
    local path = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/quickshell/user/generated/liquidglass.lua"
    if not is_file_exists(path) then return {} end
    local ok, settings = pcall(dofile, path)
    return (ok and type(settings) == "table") and settings or {}
end

-- Loading is asynchronous: this block applies on the reload the plugin triggers.
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    -- Every app window is glass, the same clear glass as the dock. It shows
    -- wherever the app draws a see-through background: kitty and foot
    -- (background_opacity / alpha), and Qt apps through the Darkly style
    -- (Dolphin's view and sidebar, toolbars, menus).
    local shell = shellSettings()
    hg.config({
        default_theme = shell.default_theme or "dark", -- the shell's light or dark mode
        default_preset = "tahoe_clear",
        enabled = shell.enabled ~= false,
        layers = { enabled = shell.enabled ~= false },
        tinted = shell.tinted or 0,
        edge_highlight = shell.edge_highlight or 1,
        lens = shell.lens or 1,
    })

    -- Shell panels get glass cut to whatever shape they draw. The background,
    -- overlay and screenshot selector are left alone.
    -- Bar, dock and the power menu's tiles: the clear glass. Panels that carry
    -- text (launcher and overview, sidebars, notifications, tray menus...) get
    -- the same glass frostier and darker, so they stay readable and stand apart
    -- from what is behind them.
    for _, ns in ipairs({ "quickshell:bar", "quickshell:verticalBar", "quickshell:dock", "quickshell:session" }) do
        hg.layer(ns, { mask_threshold = 0.04, preset = "tahoe_clear" })
    end
    for _, ns in ipairs({
        "quickshell:overview", "quickshell:cheatsheet", "quickshell:wallpaperSelector",
        "quickshell:sidebarLeft", "quickshell:sidebarRight",
        "quickshell:notificationPopup", "quickshell:onScreenDisplay",
        "quickshell:mediaControls", "quickshell:osk", "quickshell:popup", "quickshell:trayMenu",
    }) do
        hg.layer(ns, { mask_threshold = 0.04, preset = "tahoe" })
    end

    -- Magic lamp: pour the focused window into its dock icon, and back.
    hl.bind("SUPER + H", hl.dsp.exec_cmd("qs -c $qsConfig ipc call genie minimizeActive"),
        { description = "Window: Minimize into its dock icon" })
    hl.bind("SUPER + SHIFT + H", hl.dsp.exec_cmd("qs -c $qsConfig ipc call genie restoreLast"),
        { description = "Window: Restore the last minimized window" })
end

-- Floating windows sit on a big, soft shadow like Tahoe's, deeper for the
-- focused one. (Tiled windows keep no shadow, see rules.lua.)
hl.config({
    decoration = {
        shadow = {
            enabled = true,
            range = 46,
            offset = { 0, 14 },
            render_power = 3,
            color = "rgba(00000073)",
            color_inactive = "rgba(00000040)",
        },
    },
})

-- The power menu's dim is a layer of its own under the menu (the menu's own
-- surface is all glass tiles, and a scrim drawn there would become one big pane)
hl.layer_rule({ match = { namespace = "quickshell:sessionScrim" }, no_anim = true })

-- Motion: springs instead of decelerations. Panels and windows overshoot a
-- little and settle, the gel-like give of the material; nothing bounces twice.
hl.curve("liquidSpring", { type = "bezier", points = {{0.22, 1.32}, {0.34, 1.00}} })
hl.curve("liquidSettle", { type = "bezier", points = {{0.32, 1.12}, {0.30, 1.00}} })
hl.curve("liquidExit",   { type = "bezier", points = {{0.40, 0.00}, {0.80, 0.30}} })

hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3.6, bezier = "liquidSpring", style = "popin 86%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 2.2, bezier = "liquidExit",   style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4.2, bezier = "liquidSettle", style = "slide" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 3.0, bezier = "liquidSpring", style = "popin 90%" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 2.2, bezier = "liquidExit",   style = "popin 94%" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 5.0, bezier = "liquidSettle", style = "slide" })
