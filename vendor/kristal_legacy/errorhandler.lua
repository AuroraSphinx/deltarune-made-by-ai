--[[
Adapted from Kristal's custom error handler (BSD-3-Clause), pinned to the same
legacy source lineage as the battle port. It keeps the standalone project's
LÖVE entry point while providing Kristal-style traceback display and copying.
]]

local function safeTraceback(message)
    if debug and debug.traceback then
        return debug.traceback("Error: " .. tostring(message), 3)
    end
    return tostring(message)
end

local function splitLines(text)
    local lines = {}
    text = tostring(text or "") .. "\n"
    for line in text:gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function wrapLines(font, text, width)
    local output = {}
    for _, line in ipairs(splitLines(text)) do
        local _, wrapped = font:getWrap(line, width)
        if #wrapped == 0 then table.insert(output, "") end
        for _, child in ipairs(wrapped) do table.insert(output, child) end
    end
    return output
end

return function(message)
    local trace = safeTraceback(message)
    print(trace)

    if not love.window or not love.graphics or not love.event then
        return
    end

    if not love.window.isOpen() then
        local ok = pcall(love.window.setMode, 960, 540, {resizable = true, minwidth = 640, minheight = 360})
        if not ok then return end
    end

    if love.mouse then
        love.mouse.setVisible(true)
        love.mouse.setGrabbed(false)
        love.mouse.setRelativeMode(false)
    end
    if love.audio then love.audio.stop() end

    local copied = 0
    local titleFont = love.graphics.newFont(24)
    local bodyFont = love.graphics.newFont(14)
    local smallFont = love.graphics.newFont(12)

    local function copyTraceback()
        if love.system then
            love.system.setClipboardText(tostring(message) .. "\n\n" .. trace)
            copied = 1.5
        end
    end

    local function draw()
        local width, height = love.graphics.getDimensions()
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 1)

        local margin = 28
        local bodyWidth = math.max(100, width - margin * 2)
        local header = "Error at " .. tostring(message)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(titleFont)
        love.graphics.printf(header, margin, 24, bodyWidth, "left")

        love.graphics.setColor(0.68, 0.68, 0.72, 1)
        love.graphics.setFont(bodyFont)
        love.graphics.print("Traceback:", margin, 72)

        local y = 98
        love.graphics.setFont(smallFont)
        for _, line in ipairs(wrapLines(smallFont, trace, bodyWidth)) do
            if y > height - 70 then
                love.graphics.print("...", margin, y)
                break
            end
            love.graphics.setColor(0.88, 0.88, 0.92, 1)
            love.graphics.print(line, margin, y)
            y = y + 15
        end

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("ESC: quit", margin, height - 42)
        love.graphics.print("CTRL+C: copy traceback", margin + 120, height - 42)
        if copied > 0 then
            love.graphics.setColor(0.3, 1, 0.45, 1)
            love.graphics.print("Copied!", margin + 330, height - 42)
        end

        love.graphics.present()
    end

    return function()
        if love.event then love.event.pump() end
        for event, a in love.event.poll() do
            if event == "quit" then return 1 end
            if event == "keypressed" then
                if a == "escape" then return 1 end
                if a == "c" and love.keyboard.isDown("lctrl", "rctrl") then copyTraceback() end
            end
        end
        if love.timer then love.timer.step() end
        copied = math.max(0, copied - (love.timer and love.timer.getDelta() or 0.016))
        if love.graphics and love.graphics.isActive() then draw() end
        if love.timer then love.timer.sleep(0.01) end
    end
end
