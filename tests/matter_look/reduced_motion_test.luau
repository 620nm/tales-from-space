local matter_look = require("@helpers/matter_look")

-- Reduced motion holds every part on its first frame and keeps the regime.
--
-- The viewer asks for reduced motion through the optional last argument of
-- `t.seen_matter`. Every part comes back `held` (drawn on frame zero); the
-- regime the body would have chosen is still reported, so the picture is the
-- calm frame of the right state, not a different state. (The wind streak the
-- gas would draw is not part of the spec read, so its removal is not
-- asserted here.)

t.set_breathing(false)

local PUDDLE_TILE, GAS_TILE = 3, 7

local p = matter_look.room({
    { x = PUDDLE_TILE, y = 3, rows = matter_look.water(1000) },
    { x = GAS_TILE, y = 3, rows = '("chlorine", 100.0)' },
})
-- Long enough for the puddle's amount to change, so its body is moving.
t.run_seconds(4)

local function parts_at(x: number, reduced_motion: boolean): { SpecSeenMatterPart }
    return t.seen_matter(p, x, 3, nil, reduced_motion)
end

local moving_regimes = 0
for _, x in ipairs({ PUDDLE_TILE, GAS_TILE, GAS_TILE - 1, GAS_TILE + 1 }) do
    local live = parts_at(x, false)
    local held = parts_at(x, true)
    assert(#live > 0, "tile " .. x .. " draws")
    assert(#held == #live, "reduced motion draws the same parts at tile " .. x)
    for index, part in ipairs(live) do
        assert(not part.held, "motion is the default, tile " .. x .. " rung " .. part.rung)
        local calm = held[index]
        assert(calm.held, "reduced motion holds frame zero, tile " .. x .. " rung " .. calm.rung)
        assert(
            calm.look == part.look and calm.rung == part.rung and calm.regime == part.regime,
            "and keeps the regime in force, tile " .. x .. " rung " .. part.rung
        )
        if part.regime > 0 then
            moving_regimes += 1
        end
    end
end
assert(moving_regimes > 0, "the spill was moving, so the regime held is not just the resting one")
