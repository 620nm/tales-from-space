-- The welder's deconstruction ladder, scenario 1: sealing a hull
-- breach is a guarded do_after, attributed to the script and the
-- player who held the torch. (Port of the Rust m5 seal test; the
-- repressurization tail stays native until t grows a pressure query.)
t.world([==[(
    name: "weld",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "############",
        "#..........#",
        "#..........#",
        "#..........#",
        "############",
    ],
    spawns: [(2, 1)],
    items: [(2, 2, "welder")],
)]==], 7)

local p = t.join()
t.tick()
t.click(p, 2, 2) -- grab the welder underfoot-adjacent
t.fault(1, 1, 5) -- the hull fails next door
t.run_ticks(40)  -- a couple of atmos ticks of venting
assert(t.is_breached(1, 1), "the fault breached the corner")

t.click(p, 1, 1) -- start the weld (a 4 s do_after)
t.run_seconds(4.5)
assert(not t.is_breached(1, 1), "welded shut")
assert(t.ledger_has("DoAfterStarted", "items/welder.luau"),
    "the do_after start is on the record")
assert(t.ledger_has("TurfChanged", "Plating", "Script", "items/welder.luau"),
    "the seal is attributed to the welder script")

-- Scenario 2: dropping the welder mid-weld trips the guard.
t.world([==[(
    name: "interrupt",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(2, 1)],
    items: [(3, 1, "welder")],
)]==], 7)

p = t.join()
t.tick()
t.click(p, 3, 1) -- grab the welder
t.fault(1, 1, 3)
t.run_ticks(10)
t.click(p, 1, 1) -- start the weld
t.run_ticks(10)
t.drop(p)        -- drop the torch mid-count
t.run_seconds(4.5)
assert(t.is_breached(1, 1), "no welder, no seal")
assert(t.ledger_has("DoAfterInterrupted"), "the guard caught the drop")
