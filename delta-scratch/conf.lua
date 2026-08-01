-- conf.lua — LÖVE boot configuration, driven by config.lua.
-- config.lua is required BEFORE love.conf() so window branding/identity are
-- correct during startup. The web build keeps t.version at 11.4 (matches the
-- love.js WASM runtime) so the "made for a newer version" screen never shows.
local configOk, config = pcall(require, "config")
if not configOk then
    config = {}
end

-- love.system is not guaranteed to be ready when love.conf() runs (on the
-- web build it isn't), so we only declare the configured version when a
-- real desktop OS is positively detected. Anything else gets 11.4, which
-- matches the love.js WASM runtime and avoids the compatibility dialog.
local DESKTOP_OSS = {
    Windows = true,
    Linux = true,
    ["OS X"] = true,
    macOS = true,
}

local function isDesktopBuild()
    local ok, osName = pcall(function()
        return love.system.getOS()
    end)
    return ok and DESKTOP_OSS[osName]
end

function love.conf(t)
    local window = config.window or {}
    local display = config.display or {}

    t.identity = config.identity or "delta-scratch-ch1"
    if isDesktopBuild() then
        t.version = config.love_version or "11.5"
    else
        t.version = "11.4"
    end
    t.console = config.console or false
    t.externalstorage = config.externalstorage or false

    t.window.title = window.title or "Deltarune made by AI"
    t.window.icon = window.icon or "icon.png"
    t.window.width = window.width or 640
    t.window.height = window.height or 480
    t.window.minwidth = window.minwidth or 320
    t.window.minheight = window.minheight or 240
    t.window.resizable = window.resizable ~= false
    t.window.vsync = window.vsync and 1 or 0
    t.window.highdpi = window.highdpi ~= false
    t.window.usedpiscale = window.usedpiscale or false

    -- Keep the build scripts' WASM heap in sync if this ever changes.
    t.modules.audio = true
end
