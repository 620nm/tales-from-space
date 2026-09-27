local clock = require("@helpers/clock")

-- The shared deadline conversion reads the booted round's rate: this
-- pack boots at 20 Hz, and the helper agrees with the harness rather
-- than with a literal.
local ARENA = [==[(
    name: "bench",
    legend: { ' ': (composition: (substrate: Some("space"))), '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])) },
    rows: [ "###", "#.#", "###" ],
    structures: [(1, 1, "player_spawn")],
)]==]

t.world(ARENA, 0)
local hz = t.tick_hz()
assert(hz == 20, "this pack boots at 20 Hz: " .. hz)
assert(clock.deadline_ticks(1.0) == hz, "one second is one rate of ticks")
assert(clock.deadline_ticks(2.0) == 2 * hz, "two seconds is two rates")
assert(clock.deadline_ticks(0.0) == 0, "zero stays zero")
assert(clock.deadline_ticks(0.001) == 1, "a sub-tick deadline still costs a tick")

-- Joining admits a body and starts the round: preparation holds the
-- gameplay clock at zero until admission completes.
t.join()

-- The boundary the callers lean on: one tick short of a second is not
-- a second yet, and the very next tick completes it.
local start = t.now()
t.run_ticks(clock.deadline_ticks(1.0) - 1)
assert(t.now() - start == hz - 1, "just before the second lands")
t.run_ticks(1)
assert(t.now() - start == hz, "the next tick completes it")

print("clock: the helper reads the booted 20 Hz rate, rounds up, and holds the boundary")
