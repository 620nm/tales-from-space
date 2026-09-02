-- The atmos emergency-kit case, end to end: a room whose own authored
-- mixture is already above plasma's ignition point catches fire; a
-- player picks up the resin projector and sprays that room; the native
-- reaction pass stops firing and writes ExtinguishedAt. No hook is
-- involved in ignition or extinguishing -- the item writes the column,
-- the two TfS fire rules read it, and the engine records the edge.
t.world([==[(
    name: "resin fire bench",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "###",
        "#.#",
        "###",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "atmos_resin_projector")],
    blends: {
        "burning_mix": (
            rows: [("plasma", 10.0), ("o2", 14.0)],
            temperature_k: 700.0,
            amount: per_tile,
        ),
    },
    painted: [(1, 1, "burning_mix")],
)]==], 0)

local p = t.join()
t.tick()

local projector = t.target_at(1, 1, "atmos_resin_projector")
assert(projector ~= nil, "the emergency projector is on the deck")
t.click(p, 1, 1, projector)
t.tick()
assert(t.hands(p).held == "atmos_resin_projector", "the player picked the projector up")

-- Two atmos passes are enough for the hot, fuelled mixture to burn.
t.run_seconds(1)
local ignitions = t.ledger_rows("IgnitionAt")
assert(#ignitions == 1, ("the room caught fire once, got %d ignitions"):format(#ignitions))
assert(ignitions[1].at[1] == 1 and ignitions[1].at[2] == 1, "the fire is in this room")

-- A ground click on the room is the projector's authored gesture.
t.click(p, 1, 1)
t.tick()
assert(t.hands(p).held == "atmos_resin_projector", "a spent charge leaves the device")

local changed = t.ledger_rows("ColumnChanged")
assert(#changed == 1, ("one resin column write landed, got %d"):format(#changed))
assert(changed[1].column == "atmos_resin", "the row names the pack's column")
assert(changed[1].from == 0 and changed[1].to == 1, "fresh resin replaced zero with one")
assert(changed[1].actor.kind == "script", "the item file owns the write")

-- The next native matter pass sees the column, fires neither plasma
-- branch, and crosses the ledger-only extinguish edge.
t.run_seconds(1)
local extinguished = t.ledger_rows("ExtinguishedAt")
assert(#extinguished == 1, ("one fire went out, got %d rows"):format(#extinguished))
assert(
    extinguished[1].at[1] == 1 and extinguished[1].at[2] == 1,
    "ExtinguishedAt names the sprayed tile"
)

-- This is suppression, not a fire that merely ran out of ingredients
-- or cooled below its gate. The room remains hot and fuelled after the
-- edge, yet the persistent column prevents a new ignition.
local gas = t.room_gas(1, 1)
assert(gas.plasma > 0.01 and gas.o2 > 0.01, "the room still has both fire reactants")
assert(t.room_temperature(1, 1) > 373.15, "the room is still above the ignition floor")
t.run_seconds(5)
assert(#t.ledger_rows("IgnitionAt") == 1, "fresh resin stops the fire from restarting")
