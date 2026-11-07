-- TempleOS GodBits.HC:Adam/God/HolySpirit.HC:42-73 uses a replenished bit FIFO.
export type BitSource = { read: (self: BitSource, count: number) -> number }

local bits = {}

function bits.new(draw: (count: number) -> number): BitSource
	local word = 0
	local remaining = 0
	local function take(self: BitSource, count: number): number
		assert(count >= 0 and count <= 24 and count % 1 == 0, "bit count out of range")
		local value = 0
		local needed = count
		while needed > 0 do
			if remaining == 0 then
				word = draw(24) % 16777216
				remaining = 24
			end
			local used = math.min(needed, remaining)
			local shift = remaining - used
			local divisor = math.pow(2, shift)
			local part = math.floor(word / divisor) % math.pow(2, used)
			value = value * math.pow(2, used) + part
			word %= divisor
			remaining -= used
			needed -= used
		end
		return value
	end
	return { read = take }
end

return bits
