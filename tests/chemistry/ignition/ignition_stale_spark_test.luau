local ignition_room = require("@helpers/ignition_room")

-- A SPARK THAT LIGHTS NOTHING IS GONE.
--
-- Ethanol under the rule's 250 K floor: the pool takes the latch, because
-- it could burn, but no fire starts. The latch must not wait there for the
-- room to warm up: a few seconds with no fire clears it.
local p = ignition_room.build({
    rows = { "####", "#..#", "####" },
    spawn = { x = 1, y = 1 },
    items = '(2, 1, "burner"),',
    spills = {
        { x = 1, y = 1, ethanol_mol = ignition_room.POOL_MOL, temperature_k = 240 },
        { x = 2, y = 1, ethanol_mol = ignition_room.POOL_MOL, temperature_k = 240 },
    },
})

ignition_room.take_lit_burner(p, 2, 1)
ignition_room.touch(p, 2, 1)
assert(#ignition_room.latch_edges(true) == 1, "the flame latched the pool")
t.use_self(p)
t.tick()

t.run_seconds(10)
assert(#t.ledger_rows("IgnitionAt") == 0, "nothing burned under the floor")
assert(ignition_room.count(ignition_room.latched_tiles()) == 0, "and the latch did not stay")
