local Chapter1Integration = {}

function Chapter1Integration.apply(Game)
    local originalDrawNativeTitleHeader = Game.drawNativeTitleHeader

    function Game:drawNativeTitleHeader(panelX, panelY, panelWidth, compact)
        if not self.assets or not self.assets:has("chapter_logo") then
            return originalDrawNativeTitleHeader(self, panelX, panelY, panelWidth, compact)
        end

        local asset = self.assets:get("chapter_logo")
        local image = asset.image
        local imageWidth, imageHeight = image:getDimensions()
        local titleY = panelY + math.floor((compact and 20 or 34) * self.nativeScale)
        local maxWidth = panelWidth * 0.82
        local maxHeight = math.floor((compact and 92 or 138) * self.nativeScale)
        local scale = math.min(maxWidth / imageWidth, maxHeight / imageHeight)

        -- Integer enlargement keeps the original logo sharp. Downscaling is only
        -- used when the selected window is genuinely smaller than the sprite.
        if scale >= 1 then
            scale = math.max(1, math.floor(scale))
        end

        local drawWidth = imageWidth * scale
        local drawHeight = imageHeight * scale
        local drawX = panelX + (panelWidth - drawWidth) / 2

        image:setFilter("nearest", "nearest")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(image, math.floor(drawX + 0.5), titleY, 0, scale, scale)

        love.graphics.setFont(self.nativeFonts.tiny)
        love.graphics.setColor(0.76, 0.57, 0.94, 1)
        local subtitleY = titleY + drawHeight + math.floor(8 * self.nativeScale)
        love.graphics.printf("CHAPTER 1 ENGINE PROTOTYPE", panelX, subtitleY, panelWidth, "center")

        return subtitleY + self.nativeFonts.tiny:getHeight()
    end
end

return Chapter1Integration
