local ignition_room = require("@helpers/ignition_room")

-- THE FLAME DRAWN IS THE FIRE THAT BURNS, ON WHAT IT BURNS.
--
-- Fires here are lit by a struck burner (a source that reaches
-- `ignition.expose`), and read through `t.seen_matter`, what the client
-- is told to draw:
--
-- * A fire over a standing pool draws the pool flame (`flame_pool`), an
--   emissive `flame`-phase part beside the liquid part.
-- * The same fire on vapor alone draws the open flame (`flame_open`): the
--   same phase and glow, the other look, on floor the pool never reached.
-- * When the fire's supply ends, the flame part ends with it and the
--   ledger writes `ExtinguishedAt`. The air is what runs out here; the
--   fuel stays, so a flame that outlived its fire would show.
local POOL_LOOK = "flame_pool"
local OPEN_LOOK = "flame_open"
local TILE = { x = 1, y = 1 }
local FAR_X = 4

local function flame_parts(player: number, x: number): { SpecSeenMatterPart }
    local found = {}
    for _, part in ipairs(t.seen_matter(player, x, TILE.y)) do
        if part.phase == "flame" then
            table.insert(found, part)
        end
    end
    return found
end

local function light_own_tile(player: number)
    ignition_room.take_lit_burner(player, 2, 1)
    ignition_room.touch(player, TILE.x, TILE.y)
end

-- ---------------------------------------------------------------
-- A pool burns: the pool flame, over the liquid.
-- ---------------------------------------------------------------
do
    local p = ignition_room.build({
        rows = { "####", "#..#", "####" },
        spawn = TILE,
        items = '(2, 1, "burner"),',
        spills = { { x = TILE.x, y = TILE.y, ethanol_mol = ignition_room.POOL_MOL } },
    })
    t.run_seconds(30)
    assert(flame_parts(p, TILE.x)[1] == nil, "an unlit pool draws no flame")
    light_own_tile(p)
    t.run_seconds(20)

    assert(ignition_room.ethanol_liquid_ml(TILE.x, TILE.y) > 50.0, "a pool still stands")
    local flames = flame_parts(p, TILE.x)
    assert(#flames >= 1, "the burning pool draws a flame")
    for _, flame in ipairs(flames) do
        assert(flame.look == POOL_LOOK, "over a pool it is the pool flame, got " .. flame.look)
        assert(flame.emissive, "and it glows")
    end
    local liquid_parts = 0
    for _, part in ipairs(t.seen_matter(p, TILE.x, TILE.y)) do
        if part.phase == "liquid" then
            liquid_parts += 1
        end
    end
    assert(liquid_parts > 0, "and the pool still draws under it")
end

-- ---------------------------------------------------------------
-- The fire walks off the pool: open flame on bare floor; then none.
-- ---------------------------------------------------------------
do
    local p = ignition_room.build({
        rows = { "######", "#....#", "######" },
        spawn = TILE,
        items = '(2, 1, "burner"),',
        oxygen_mol = 2.0,
        spills = { { x = TILE.x, y = TILE.y, ethanol_mol = ignition_room.POOL_MOL } },
    })
    t.run_seconds(30)
    light_own_tile(p)
    t.run_seconds(30)

    for _, part in ipairs(t.seen_matter(p, FAR_X, TILE.y)) do
        assert(part.phase ~= "liquid", "the pool never reached the far tile")
    end
    local flames = flame_parts(p, FAR_X)
    assert(#flames >= 1, "burning vapor draws a flame on the far tile")
    for _, flame in ipairs(flames) do
        assert(flame.look == OPEN_LOOK, "with no pool it is the open flame, got " .. flame.look)
        assert(flame.emissive, "and it glows")
    end
    for _, flame in ipairs(flame_parts(p, TILE.x)) do
        assert(flame.look == POOL_LOOK, "while the pool tile keeps the pool flame, got " .. flame.look)
    end
    assert(#t.ledger_rows("ExtinguishedAt") == 0, "the fire is still going")

    local out_after = ignition_room.run_until(1800, 1, function()
        return flame_parts(p, FAR_X)[1] == nil
            and ignition_room.oxygen_gas(FAR_X, TILE.y) < ignition_room.OXYGEN_FLOOR_MOL
    end)
    assert(out_after ~= nil, "the flame went when the air did")
    assert(ignition_room.ethanol_gas(FAR_X, TILE.y) >= ignition_room.FUEL_FLOOR_MOL, "though the fuel is not")
    -- The tending task drops the latch on its next visit, every 2 s.
    t.run_seconds(5)
    assert(#t.ledger_rows("ExtinguishedAt") >= 1, "the fire went out on the record")
    t.run_seconds(10)
    assert(flame_parts(p, FAR_X)[1] == nil, "and no flame comes back")
end
