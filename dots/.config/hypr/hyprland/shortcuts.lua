-- Nothing Liquid: the shortcuts and default apps chosen in the shell's Settings
-- (Shortcuts, Default apps). quickshell/ii/services/ShortcutSettings.qml writes
--   $XDG_STATE_HOME/quickshell/user/generated/shortcuts.lua:
--   return { apps = { browser = "firefox", ... }, keys = { ["SUPER + W"] = "SUPER + B", ... } }
-- apps replace the app variables of variables.lua (and custom/variables.lua);
-- keys move a default shortcut to other keys ("" turns it off). Every default
-- shortcut, with its description, is written back to keybinds.json there for the
-- Settings page. custom/keybinds.lua is not touched: what's bound there stays.

local M = {}

local stateDir = (os.getenv("XDG_STATE_HOME") or (HOME .. "/.local/state")) .. "/quickshell/user/generated"

local function loadSaved()
    local path = stateDir .. "/shortcuts.lua"
    if not is_file_exists(path) then return {} end
    local ok, saved = pcall(dofile, path)
    return (ok and type(saved) == "table") and saved or {}
end
local saved = loadSaved()

local MODIFIERS = { SUPER = "SUPER", WIN = "SUPER", MOD4 = "SUPER", META = "SUPER", CTRL = "CTRL", CONTROL = "CTRL",
                    SHIFT = "SHIFT", ALT = "ALT", MOD1 = "ALT" }
local ORDER = { "SUPER", "CTRL", "SHIFT", "ALT" }

-- The same keys written another way ("ctrl+super + t", "SUPER + CTRL + T") give the same id
function M.normalize(combo)
    local mods, key = {}, ""
    for raw in tostring(combo):gmatch("[^+]+") do
        local part = raw:match("^%s*(.-)%s*$")
        local mod = MODIFIERS[part:upper()]
        if mod then mods[mod] = true elseif part ~= "" then key = part:lower() end
    end
    local out = {}
    for _, mod in ipairs(ORDER) do if mods[mod] then out[#out + 1] = mod end end
    out[#out + 1] = key
    return table.concat(out, " + ")
end

-- After the app variables are set, before the keybinds use them
function M.applyApps()
    for name, command in pairs(saved.apps or {}) do
        if type(name) == "string" and type(command) == "string" and command ~= "" then
            _G[name] = command
        end
    end
end

local function jsonString(s)
    return '"' .. tostring(s):gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" end
        return string.format("\\u%04x", c:byte())
    end) .. '"'
end

local originalBind
local seen = {}

-- Around the default keybinds: each one goes to the keys chosen for it
function M.begin()
    local moved = {}
    for from, to in pairs(saved.keys or {}) do
        if type(from) == "string" and type(to) == "string" then moved[M.normalize(from)] = to end
    end
    originalBind = hl.bind
    seen = {}
    hl.bind = function(keys, action, opts)
        local to = moved[M.normalize(keys)]
        seen[#seen + 1] = { keys = keys, description = type(opts) == "table" and opts.description or nil }
        if to == "" then return end
        return originalBind(to or keys, action, opts)
    end
end

function M.finish()
    if originalBind then hl.bind = originalBind end

    -- Where the Settings page waits for new keys: no shortcut runs meanwhile. (A
    -- submap needs a bind to exist: a way out, should the page not take it back.)
    hl.define_submap("nl_capture", function()
        hl.bind("CTRL + SUPER + SHIFT + ALT + Escape", hl.dsp.submap("reset"))
    end)

    local entries = {}
    for _, bind in ipairs(seen) do
        entries[#entries + 1] = "{\"keys\": " .. jsonString(bind.keys) ..
            (bind.description and (", \"description\": " .. jsonString(bind.description)) or "") .. "}"
    end
    local file = io.open(stateDir .. "/keybinds.json", "w")
    if file then
        file:write("[\n" .. table.concat(entries, ",\n") .. "\n]\n")
        file:close()
    end
end

return M
