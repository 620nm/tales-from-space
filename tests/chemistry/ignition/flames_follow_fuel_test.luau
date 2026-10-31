local ignition_room = require("@helpers/ignition_room")

-- THE FLAME DRAWN IS THE FIRE THAT BURNS, ON WHAT IT BURNS.
--
-- Fires here are lit by a struck burner (a source that reaches
-- `ignition.expose`), and read through `t.seen_matter`, what the client
-- is told to draw:
--
-- * A fire over a standing pool draws the pool flame (`flame_pool`), an
--   emissive `flame`-phase part stacked above the liquid part.
-- * A fire on vapour alone draws the open flame (`flame_open`): the same
--   phase and glow, the other look. A 5 mol dose is all vapour in a
--   sealed tile, so no liquid stands under it.
-- * When the fire's supply ends, the flame part ends with it and the
--   ledger writes `ExtinguishedAt`. The air is what runs out here; the
--   fuel stays, so a flame that outlived its fire would show.
local POOL_LOOK = "flame_pool"
local OPEN_LOOK = "flame_open"
local TILE = { x = 1, y = 1 }
local VAPOUR_MOL = 5.0

local function flame_parts(player: number): { SpecSeenMatterPart }
    local found = {}
    for _, part in ipairs(t.seen_matter(player, TILE.x, TILE.y)) do
        if part.phase == "flame" then
            table.insert(found, part)
        end
    end
    return found
end

local function light_own_tile(player: number)
    ignition_room.take_lit_burner(player, TILE.x, TILE.y)
    ignition_room.touch(player, TILE.x, TILE.y)
end

-- ---------------------------------------------------------------
-- A pool burns: the pool flame, over the liquid.
-- ---------------------------------------------------------------
do
    local p = ignition_room.build({
        rows = { "###", "#.#", "###" },
        spawn = TILE,
        items = '(1, 1, "burner"),',
        spills = { { x = TILE.x, y = TILE.y, ethanol_mol = ignition_room.POOL_MOL } },
    })
    t.run_seconds(30)
    assert(flame_parts(p)[1] == nil, "an unlit pool draws no flame")
    light_own_tile(p)
    t.run_seconds(20)

    assert(ignition_room.ethanol_liquid_ml(TILE.x, TILE.y) > 50.0, "a pool still stands")
    local flames = flame_parts(p)
    assert(#flames >= 1, "the burning pool draws a flame")
    for _, flame in ipairs(flames) do
        assert(flame.look == POOL_LOOK, "over a pool it is the pool flame, got " .. flame.look)
        assert(flame.emissive, "and it glows")
    end
    local liquid_at, flame_at = nil, nil
    for index, part in ipairs(t.seen_matter(p, TILE.x, TILE.y)) do
        if part.phase == "liquid" and liquid_at == nil then
            liquid_at = index
        elseif part.phase == "flame" and flame_at == nil then
            flame_at = index
        end
    end
    assert(liquid_at ~= nil and flame_at ~= nil and flame_at > liquid_at, "the flame is drawn over the liquid")
end

-- ---------------------------------------------------------------
-- Vapour burns with no pool under it: the open flame; then none.
-- ---------------------------------------------------------------
do
    local p = ignition_room.build({
        rows = { "###", "#.#", "###" },
        spawn = TILE,
        items = '(1, 1, "burner"),',
        oxygen_mol = 2.0,
        spills = { { x = TILE.x, y = TILE.y, ethanol_mol = VAPOUR_MOL } },
    })
    t.run_seconds(5)
    assert(ignition_room.ethanol_liquid_ml(TILE.x, TILE.y) < 1.0, "the dose is all vapour, no pool")
    assert(ignition_room.ethanol_gas(TILE.x, TILE.y) >= 1.0, "and the vapour is there")
    light_own_tile(p)
    t.run_seconds(20)

    local flames = flame_parts(p)
    assert(#flames >= 1, "burning vapour draws a flame")
    for _, flame in ipairs(flames) do
        assert(flame.look == OPEN_LOOK, "with no pool it is the open flame, got " .. flame.look)
        assert(flame.emissive, "and it glows")
    end
    assert(#t.ledger_rows("ExtinguishedAt") == 0, "the fire is still going")

    local out_after = ignition_room.run_until(900, 1, function()
        return flame_parts(p)[1] == nil
    end)
    assert(out_after ~= nil, "the flame went when the air did")
    assert(ignition_room.oxygen_gas(TILE.x, TILE.y) < ignition_room.OXYGEN_FLOOR_MOL, "the air is gone")
    assert(ignition_room.ethanol_gas(TILE.x, TILE.y) >= ignition_room.FUEL_FLOOR_MOL, "though the fuel is not")
    assert(#t.ledger_rows("ExtinguishedAt") >= 1, "the fire went out on the record")
    t.run_seconds(10)
    assert(flame_parts(p)[1] == nil, "and no flame comes back")
end
