local Util = {}

function Util.clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

function Util.lerp(a, b, t)
	local v = a + (b - a) * t
	return Util.clamp(v, a, b)
end

return Util
