-- The crowbar pries only what the motors have let go of: a powered
-- door opens on a click like any other, a dark one takes work and then
-- stays open, because an unpowered door has nothing to close itself
-- with. (Port of the Rust m4 crowbar test.)
t.world([==[(
    name: "pry",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        '+': (turf: Floor, fixture: Some(Door)),
    },
    rows: [
        "#####",
        "#..+#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "crowbar")],
)]==], 7)

local p = t.join()
t.tick()
t.click(p, 2, 1) -- the crowbar
t.tick()
assert(t.hands(p).held == "crowbar", "in hand")
t.move(p, "east")
t.tick()

-- Powered: the crowbar hook passes, the native toggle opens it.
assert(t.door_at(3, 1).powered, "the shipped grid feeds this door")
t.click(p, 3, 1)
t.tick()
assert(t.door_at(3, 1).open, "powered doors ignore the crowbar")
t.run_ticks(65) -- DOOR_AUTOCLOSE_TICKS + change
assert(not t.door_at(3, 1).open, "autoclosed")

-- Kill the power: the same click starts a pry do_after instead.
t.outage()
t.tick()
assert(not t.door_at(3, 1).powered, "the breaker tripped")
t.click(p, 3, 1)
t.tick()
assert(not t.door_at(3, 1).open, "prying takes time")
t.run_ticks(60)
assert(t.door_at(3, 1).open, "pried open")
t.run_ticks(65)
assert(t.door_at(3, 1).open,
    "an unpowered door has no motors to autoclose with")

assert(#t.ledger_rows("PowerOutage") == 1, "the outage is on the record")
local pried = t.ledger_rows("DoorPried")
assert(#pried == 1 and pried[1].at[1] == 3 and pried[1].at[2] == 1,
    "the pry names the door it opened")
local msgs = table.concat(t.messages(p), "\n")
assert(msgs:find("gives way", 1, true), "the door gave way: " .. msgs)
