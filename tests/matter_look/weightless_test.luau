local matter_look = require("@helpers/matter_look")

-- A tile without gravity draws the look's weightless ladder.
--
-- The same liter of water and the same canister of chlorine are painted into
-- two otherwise identical rooms, one under gravity and one weightless. Under
-- gravity the water is the joined puddle shell; weightless it is the
-- pack's floating pictures, which never join. The chlorine look declares no
-- weightless ladder, so gravity does not change how it is drawn.

t.set_breathing(false)

local WATER_TILE, GAS_TILE = 3, 7

local function room(gravity: number): number
    return matter_look.room({
        { x = WATER_TILE, y = 3, rows = matter_look.water(1000) },
        { x = GAS_TILE, y = 3, rows = '("chlorine", 100.0)' },
    }, gravity)
end

-- The gas is drawn the same way with or without gravity.
local function assert_gas_ordinary(player: number, why: string)
    local cloud = matter_look.parts(player, GAS_TILE, 3, "cloud")
    assert(#cloud > 0, "the canister draws " .. why)
    for _, part in ipairs(cloud) do
        assert(not part.weightless and part.blocks ~= nil, "a gas has no weightless ladder " .. why)
    end
end

local grounded = room(9.80665)
local water = matter_look.parts(grounded, WATER_TILE, 3, "puddle")
assert(#water > 0, "a liter of water draws under gravity")
local shells = 0
for _, part in ipairs(water) do
    assert(not part.weightless, "gravity draws the ordinary ladder, rung " .. part.rung)
    if part.blocks ~= nil then
        shells += 1
    end
end
assert(shells > 0, "and its top rung is the joined shell")
assert_gas_ordinary(grounded, "under gravity")

local floating = room(0)
local drifting = matter_look.parts(floating, WATER_TILE, 3, "puddle")
assert(#drifting > 0, "the same liter still draws without gravity")
for _, part in ipairs(drifting) do
    assert(part.weightless, "no gravity draws the weightless ladder, rung " .. part.rung)
    assert(part.sprite ~= nil and part.blocks == nil and part.joins == nil, "and its rungs are loose pictures")
end
assert_gas_ordinary(floating, "without gravity")
