local Util = {}

function Util.clamp(value, min, max)
	return math.min(math.max(value, min), max)
end

function Util.lerp(a, b, t)
	local v = a + (b - a) * t

	local minV = math.min(a, b)
	local maxV = math.max(a, b)
	return Util.clamp(v, minV, maxV)
end

function Util.sign(v)
	if v < 0 then
		return -1
	elseif v > 0 then
		return 1
	else
		return 0
	end
end

return Util
