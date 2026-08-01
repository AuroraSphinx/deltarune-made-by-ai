local Util = {}

function Util.clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function Util.sign(value)
    if value < 0 then
        return -1
    elseif value > 0 then
        return 1
    end
    return 0
end

function Util.length(x, y)
    return math.sqrt(x * x + y * y)
end

function Util.normalize(x, y)
    local length = Util.length(x, y)
    if length == 0 then
        return 0, 0
    end
    return x / length, y / length
end

function Util.rectsOverlap(a, b)
    return a.x < b.x + b.w
        and a.x + a.w > b.x
        and a.y < b.y + b.h
        and a.y + a.h > b.y
end

function Util.distanceSquared(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return dx * dx + dy * dy
end

function Util.shallowCopy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

return Util
