local ignition_room = require("@helpers/ignition_room")

-- A FIRE WALKS TO FUEL, WAITS FOR LATE FUEL, AND LETS GO WHEN IT DIES.
--
-- Four sealed tiles in a row, each low on oxygen (a mole a tile, so the
-- fire can use the air up in a few minutes). A spill sits on the second
-- tile and a struck burner clicks it alight; the player then snuffs the
-- burner so the room has no other source.
--
-- * The neighbours light: the fire spreads tile to tile (lib spread).
-- * The far tile holds no vapour when the fire starts; it lights only
--   after the vapour arrives, and only behind its neighbour.
-- * When the oxygen is gone the latch clears on every tile within three
--   seconds. The fuel is still there.
-- * Fresh air then brings back everything the rule asks for but the
--   latch, and the room stays unlit: a fire needs a new cause.
local ROW = { 1, 2, 3, 4 }
local SPILL_X = 2

local p = ignition_room.build({
    rows = { "######", "#....#", "######" },
    spawn = { x = 1, y = 1 },
    items = '(2, 1, "burner"),',
    oxygen_mol = 1.0,
    spills = { { x = SPILL_X, y = 1, ethanol_mol = ignition_room.POOL_MOL } },
})

assert(
    ignition_room.ethanol_gas(4, 1) < ignition_room.FUEL_FLOOR_MOL,
    "the far tile holds no vapour when the fire starts"
)
ignition_room.take_lit_burner(p, 2, 1)
ignition_room.touch(p, SPILL_X, 1)
assert(#ignition_room.latch_edges(true) >= 1, "the click lit the spill tile")

-- Spread, and late vapour: all four tiles latch, the far one last.
local all_lit = ignition_room.run_until(180, 1, function()
    return ignition_room.count(ignition_room.latched_tiles()) == #ROW
end)
assert(all_lit ~= nil, "the fire reached every tile: " .. ignition_room.count(ignition_room.latched_tiles()))
local order: { [string]: number } = {}
for _, row in ipairs(ignition_room.latch_edges(true)) do
    local tile = ignition_room.tile_of(row)
    local tile_key = ignition_room.tile_key(tile.x, tile.y)
    if order[tile_key] == nil then
        order[tile_key] = (row :: any).seq
    end
end
assert(order["3:1"] < order["4:1"], "the far tile caught behind its neighbour")

-- The burner is the only other source; take it away.
t.use_self(p)
t.tick()
t.run_seconds(2)

-- The oxygen runs out; the latch follows it down.
local function air_is_gone(): boolean
    for _, x in ipairs(ROW) do
        if ignition_room.oxygen_gas(x, 1) >= ignition_room.OXYGEN_FLOOR_MOL then
            return false
        end
    end
    return true
end
local burned_for = ignition_room.run_until(900, 0.5, air_is_gone)
assert(burned_for ~= nil, "the fire used the oxygen up")
t.run_seconds(3)
local still = ignition_room.latched_tiles()
assert(ignition_room.count(still) == 0, "every latch cleared within 3 s of the air going")
for _, x in ipairs(ROW) do
    assert(ignition_room.ethanol_gas(x, 1) >= ignition_room.FUEL_FLOOR_MOL, "fuel remains on tile " .. x)
end

-- New air, old fuel, no latch: the room stays unlit.
for _, x in ipairs(ROW) do
    assert(t.foul_room(x, 1, "o2", ignition_room.AIR_O2), "fresh air goes in")
end
t.run_seconds(1)
for _, x in ipairs(ROW) do
    assert(ignition_room.oxygen_gas(x, 1) >= ignition_room.OXYGEN_FLOOR_MOL, "air is back on tile " .. x)
    assert(ignition_room.ethanol_gas(x, 1) >= ignition_room.FUEL_FLOOR_MOL, "and so is fuel on tile " .. x)
end
local lit_edges = #ignition_room.latch_edges(true)
local ignitions = #t.ledger_rows("IgnitionAt")
t.run_seconds(60)
assert(#ignition_room.latch_edges(true) == lit_edges, "no source, no new latch")
assert(#t.ledger_rows("IgnitionAt") == ignitions, "and no new fire")
