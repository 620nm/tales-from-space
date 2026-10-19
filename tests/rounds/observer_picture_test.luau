-- A dead player who comes back is pictured as the ghost this pack ships.
--
-- The engine draws the observer a dead mind reconnects as only when the
-- pack names its picture: `mod.toml [view] observer = { sprite = "ghost" }`
-- (the engine's `docs/sim/view-radius.md` section 3). Without the line
-- the observer has no picture and no session is ever sent it.
local MAP = [==[(
    name: "observer bay",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [(1, 1, "player_spawn"), (2, 1, "player_spawn"), (3, 1, "player_spawn")],
        ),
    ],
)]==]

local COUNTDOWN = 120

t.world(MAP, 7, "space_station")
local profile = string.format("%064x", 77)
local first = t.connect(profile)
assert(t.prepare(first, { name = "Ada Lovelace", ranked_jobs = { "engineer" }, fallback = false }))
assert(t.ready(first))
t.preparation_steps(COUNTDOWN * t.tick_hz())
assert(t.round_status().phase == "playing", "the cohort is admitted")
assert(assert(t.body(first)).animate, "the crewman starts alive")

-- Dead in the pack's terms, then gone: the mind that returns finds its body
-- dead and comes back as an observer.
t.set_health(first, { oxy = 500 })
t.run_ticks(4)
assert(not assert(t.body(first)).animate, "the crewman is dead")
t.disconnect(first)
t.run_ticks(4)
local returned = t.connect(profile)
t.run_ticks(6)

local seen = t.seen(returned)
assert(seen.kind ~= "unseen", "the observer is streamed to its own session")
assert(#seen.layers == 1, "and wears one picture: " .. #seen.layers)
assert(seen.layers[1].sprite == "ghost", "the picture is the pack's ghost: " .. seen.layers[1].sprite)
