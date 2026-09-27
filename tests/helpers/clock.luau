-- Rate-aware duration arithmetic for specs: the booted round's tick
-- rate, never a literal 20. The conversion rounds UP, so a wait is
-- never shorter than the duration it covers; observation steps stay
-- the caller's own `+ N`.
local clock = {}

-- Ticks covering `seconds` under the booted round's rate.
function clock.deadline_ticks(seconds: number): number
    return math.ceil(seconds * t.tick_hz())
end

return clock
