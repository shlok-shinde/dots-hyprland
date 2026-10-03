-- Nothing Liquid: liquid glass and the magic lamp, from the hyprglass fork
-- (branch nothing-liquid). Optional: without the plugin this file does nothing
-- and the shell keeps its own look.
--
-- The plugin is looked up at $NOTHING_LIQUID_PLUGIN, else
-- ~/.local/lib/nothing-liquid/hyprglass.so

local plugin = os.getenv("NOTHING_LIQUID_PLUGIN") or (HOME .. "/.local/lib/nothing-liquid/hyprglass.so")
if not hl.plugin.hyprglass and is_file_exists(plugin) then
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
