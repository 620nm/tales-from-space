local ignition_room = require("@helpers/ignition_room")

-- A SPARK THAT FINDS NOTHING LEAVES NOTHING (tg LINDA_fire.dm:23-58).
--
-- A lit burner in air with nothing to burn: clicked at the deck beside
-- the player, then carried lit for ten seconds (its tile is tended once
-- a second). The lib judges the tile at that instant and declines, so
-- no latch is written, no fire is recorded, the player is not told
-- "The flame catches in the air.", and the room gains no heat. A latch
-- left behind here would light the first vapour that ever drifted in.
local IGNITE_MESSAGE = "The flame catches in the air."

local p = ignition_room.build({
    rows = { "#####", "#...#", "#####" },
    spawn = { x = 1, y = 1 },
    items = '(1, 1, "burner"),',
    spills = {},
})

assert(ignition_room.ethanol_gas(2, 1) == 0.0, "the air holds no fuel")
local before = assert(t.room_temperature(2, 1))

ignition_room.take_lit_burner(p, 1, 1)
ignition_room.touch(p, 2, 1)
t.run_seconds(10)

assert(#ignition_room.latch_rows() == 0, "no latch written")
assert(#t.ledger_rows("ColumnChanged") == 0, "no column written at all")
assert(#t.ledger_rows("IgnitionAt") == 0, "no fire recorded")
assert(not ignition_room.said(p, IGNITE_MESSAGE), "and the player is not told a flame caught")
local after = assert(t.room_temperature(2, 1))
assert(math.abs(after - before) < 0.5, ("the room gained no heat: %.2f -> %.2f K"):format(before, after))
