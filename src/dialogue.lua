local Dialogue = {}
Dialogue.__index = Dialogue

function Dialogue.new(fonts)
    return setmetatable({
        fonts = fonts,
        active = false,
        lines = {},
        index = 1,
        visibleCharacters = 0,
        characterTimer = 0,
        characterDelay = 0.025,
        onFinish = nil,
    }, Dialogue)
end

function Dialogue:start(lines, onFinish)
    assert(type(lines) == "table" and #lines > 0, "Dialogue requires at least one line")
    self.lines = lines
    self.index = 1
    self.visibleCharacters = 0
    self.characterTimer = 0
    self.onFinish = onFinish
    self.active = true
end

function Dialogue:getCurrentLine()
    return self.lines[self.index]
end

function Dialogue:update(dt)
    if not self.active then
        return
    end

    local current = self:getCurrentLine()
    local text = current.text or ""
    if self.visibleCharacters < #text then
        self.characterTimer = self.characterTimer + dt
        while self.characterTimer >= self.characterDelay and self.visibleCharacters < #text do
            self.characterTimer = self.characterTimer - self.characterDelay
            self.visibleCharacters = self.visibleCharacters + 1
        end
    end
end

function Dialogue:advance()
    if not self.active then
        return false
    end

    local current = self:getCurrentLine()
    local text = current.text or ""
    if self.visibleCharacters < #text then
        self.visibleCharacters = #text
        return true
    end

    if self.index < #self.lines then
        self.index = self.index + 1
        self.visibleCharacters = 0
        self.characterTimer = 0
        return true
    end

    self.active = false
    local callback = self.onFinish
    self.onFinish = nil
    if callback then
        callback()
    end
    return true
end

function Dialogue:keypressed(key)
    if not self.active then
        return false
    end

    if key == "z" or key == "return" or key == "space" then
        return self:advance()
    end
    return true
end

function Dialogue:draw()
    if not self.active then
        return
    end

    local current = self:getCurrentLine()
    local text = (current.text or ""):sub(1, self.visibleCharacters)

    love.graphics.setColor(0, 0, 0, 0.96)
    love.graphics.rectangle("fill", 10, 174, 300, 56)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 10, 174, 300, 56)

    if current.speaker and current.speaker ~= "" then
        love.graphics.setFont(self.fonts.small)
        love.graphics.print(current.speaker, 20, 181)
        love.graphics.setFont(self.fonts.normal)
        love.graphics.printf(text, 20, 194, 280, "left")
    else
        love.graphics.setFont(self.fonts.normal)
        love.graphics.printf(text, 20, 185, 280, "left")
    end

    if self.visibleCharacters >= #(current.text or "") then
        local pulse = math.floor(love.timer.getTime() * 4) % 2
        if pulse == 0 then
            love.graphics.polygon("fill", 296, 218, 302, 218, 299, 222)
        end
    end
end

return Dialogue
