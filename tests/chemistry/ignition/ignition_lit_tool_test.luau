local ignition_room = require("@helpers/ignition_room")

-- A LIT TOOL LIGHTS WHAT IT IS POINTED AT, AND WHAT IT STANDS IN.
--
-- Two worlds, two paths, one source (the bench burner):
--
-- 1. THE CLICK. An unlit burner clicked at a spill does nothing; the
--    same burner struck and clicked at it lights the tile it was
--    pointed at, before any tending, and says so.
-- 2. THE TEND. A burner struck and set down in dry air at one end of a
--    long room, with the spill at the other end, is never clicked at
--    anything. Vapour reaches its tile, the once-a-second tend finds it
--    and the room catches, the first latch being the burner's own tile.
local IGNITE_MESSAGE = "The flame catches in the air."

-- ---------------------------------------------------------------
-- 1. The click.
-- ---------------------------------------------------------------
do
    local p = ignition_room.build({
        rows = { "#######", "#.....#", "#######" },
        spawn = { x = 2, y = 1 },
        items = '(2, 1, "burner"),',
        spills = { { x = 4, y = 1, ethanol_mol = ignition_room.POOL_MOL } },
    })
    t.run_seconds(30)
    assert(ignition_room.ethanol_gas(4, 1) >= 0.5, "the target tile holds vapour")
    t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "burner")))
    t.tick()
    assert(t.hands(p).held == "burner", "the burner is in hand")

    -- Cold, it is a paperweight: no latch, no fire.
    ignition_room.touch(p, 3, 1)
    t.run_seconds(5)
    assert(#ignition_room.latch_rows() == 0, "an unlit burner lights nothing")
    assert(#t.ledger_rows("IgnitionAt") == 0, "and no fire is recorded")

    -- Struck, one click lights the tile it names, first of all.
    t.use_self(p)
    t.tick()
    assert(t.ledger_has("FuelBurnSet"), "the burner is struck")
    ignition_room.touch(p, 3, 1)
    local first = ignition_room.latch_edges(true)[1]
    assert(first ~= nil, "the click set the latch")
    local tile = ignition_room.tile_of(first)
    assert(tile.x == 3 and tile.y == 1, ("the first latch is the clicked tile, got (%d, %d)"):format(tile.x, tile.y))
    assert(ignition_room.said(p, IGNITE_MESSAGE), "and the player is told")
    t.run_seconds(5)
    assert(#t.ledger_rows("IgnitionAt") >= 1, "the clicked tile burns")
end

-- ---------------------------------------------------------------
-- 2. The tend.
-- ---------------------------------------------------------------
do
    local p = ignition_room.build({
        rows = { "###########", "#.........#", "###########" },
        spawn = { x = 1, y = 1 },
        items = '(1, 1, "burner"),',
        spills = { { x = 9, y = 1, ethanol_mol = ignition_room.POOL_MOL } },
    })
    local far_gas = ignition_room.ethanol_gas(1, 1)
    assert(far_gas < ignition_room.FUEL_FLOOR_MOL, "no vapour has reached the burner's end yet: " .. far_gas)
    ignition_room.take_lit_burner(p, 1, 1)
    t.drop(p)
    t.tick()
    assert(t.hands(p).held ~= "burner", "the burner is set down, not held")

    local lit_after = ignition_room.run_until(120, 1, function()
        return #t.ledger_rows("IgnitionAt") >= 1
    end)
    assert(lit_after ~= nil, "vapour met the standing flame and the room caught, unclicked")
    local first = ignition_room.latch_edges(true)[1]
    assert(first ~= nil, "a latch row exists")
    local tile = ignition_room.tile_of(first)
    assert(tile.x == 1 and tile.y == 1, ("the first latch is under the burner, got (%d, %d)"):format(tile.x, tile.y))
end
