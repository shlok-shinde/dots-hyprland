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

-- Loading is asynchronous: this block applies on the reload the plugin triggers.
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        default_theme = "dark",
        default_preset = "tahoe_clear",
        layers = { enabled = true },
    })

    -- Shell panels get glass cut to whatever shape they draw. Full-screen
    -- layers (background, overview, session, overlay) are left alone.
    for _, ns in ipairs({
        "quickshell:bar", "quickshell:verticalBar", "quickshell:dock",
        "quickshell:sidebarLeft", "quickshell:sidebarRight",
        "quickshell:notificationPopup", "quickshell:onScreenDisplay",
        "quickshell:mediaControls", "quickshell:osk", "quickshell:popup",
    }) do
        hg.layer(ns, { mask_threshold = 0.04 })
    end

    -- Magic lamp: pour the focused window into its dock icon, and back.
    hl.bind("SUPER + H", hl.dsp.exec_cmd("qs -c $qsConfig ipc call genie minimizeActive"),
        { description = "Window: Minimize into its dock icon" })
    hl.bind("SUPER + SHIFT + H", hl.dsp.exec_cmd("qs -c $qsConfig ipc call genie restoreLast"),
        { description = "Window: Restore the last minimized window" })
end

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
