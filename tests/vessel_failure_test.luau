-- What the station's two big vessels do when somebody fills them past
-- what they are rated to.
--
-- The engine owns the arithmetic (one pass over every vessel that can
-- fail); the numbers are all in the two content files, and this spec
-- is the proof that the numbers reach the pass: a canister rated to
-- 500 000 kPa breaking at 40% of 300 integrity, and a reservoir rated
-- to 46 000 kPa that takes 0.1 a pass and has all shift to be noticed.
--
-- Filling one past its rating is not something a crewman can do -- the
-- station's pumps top out three orders of magnitude below it -- so the
-- charge comes from `t.charge_vessel`, a precondition setter with the
-- standing of `t.heat_pipe`. Everything asserted afterwards is what a
-- crewman sees: a pressure, a picture, a look, and the room.

-- ---------------------------------------------------------------
-- THE CANISTER. It does not leak and it does not explode: it hands
-- over everything it is holding at once and stands there split open
-- (tg's `canister_break`).
-- ---------------------------------------------------------------
t.world([==[(
    name: "canister bay",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'c': (turf: Floor),
    },
    blends: {
        "canister_air": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15, amount: per_tile),
    },
    structures: [
        (2, 2, "canister", { "blend": "canister_air", "open": true }),
    ],
    rows: [
        "#####",
        "#...#",
        "#.c.#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 1)],
)]==], 7)

local p = t.join()
t.tick()
t.run_seconds(5)

local room_start = t.room_pressure(1, 2)
assert(t.canister_pressure(2, 2) > 4000.0, "the bottle starts full")

-- Shut the valve first, through the panel, the way a crewman shuts
-- one: a loose canister with its valve open is pointed at the room and
-- would spend itself into the floor instead of straining.
t.click(p, 2, 2, t.target_at(2, 2))
t.tick()
assert(t.ui(p).toggles[1].field == "valve")
t.ui_act(p, "toggle", '{"field":"valve"}')
t.tick()
assert(t.ui(p).toggles[1].on == false, "the valve is shut")

-- Sixty times the sticker. tg's damage is the RATIO of pressure to
-- rating, clamped to 5..50 a pass, so this is the ceiling: 300
-- integrity, breaking at 40% of it, is four passes.
assert(t.charge_vessel(2, 2, "n2", 30000000.0), "a canister takes a charge")
t.run_seconds(4)

assert(#t.ledger_rows("pressure_ruptured") > 0, "the record says a vessel went")
assert(t.canister_pressure(2, 2) < 1.0,
    "and the canister is empty: " .. t.canister_pressure(2, 2))
assert(t.room_pressure(1, 2) > room_start,
    "because the room took all of it: " .. room_start .. " -> " .. t.room_pressure(1, 2))

-- It is still there, and it looks like what happened to it.
local look = t.examine(p, 2, 2, t.target_at(2, 2))
assert(look ~= nil, "a broken canister is still a thing you can look at")
assert(table.concat(look.lines, " | "):find("broken"),
    "and the look says so: " .. table.concat(look.lines, " | "))

-- ---------------------------------------------------------------
-- THE RESERVOIR. Same pass, other rule: one rating, a flat 0.1 a
-- pass past it, and 800 integrity to chew through -- so what a spec
-- can see in a few seconds is the DAMAGE starting, and the sticker
-- being what starts it.
-- ---------------------------------------------------------------
t.world([==[(
    name: "tank room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    structures: [(2, 2, "stationary_tank")],
)]==], 7)

local q = t.join()
t.tick()
t.run_seconds(2)

-- Charged to just under the sticker: a full tank is not a failing one,
-- which is the negative that makes the rest mean anything.
assert(t.charge_vessel(2, 2, "n2", 40000.0), "a reservoir takes a charge")
t.run_seconds(5)
assert(#t.ledger_rows("pressure_damaged") == 0,
    "a tank inside its rating is doing nothing at all")
local look_sound = t.examine(q, 2, 2, t.target_at(2, 2))
assert(not table.concat(look_sound.lines, " | "):find("strain"),
    "and says nothing about strain: " .. table.concat(look_sound.lines, " | "))

-- ...and past it, the same tank is visibly working.
assert(t.charge_vessel(2, 2, "n2", 20000.0), "topped up over the sticker")
assert(t.tank_pressure(2, 2) > 46000.0,
    "past tg's max_pressure: " .. t.tank_pressure(2, 2))
t.run_seconds(5)

local damage = t.ledger_rows("pressure_damaged")
assert(#damage > 0, "the record shows it taking damage")
assert(damage[1].amount ~= nil and math.abs(damage[1].amount - 0.1) < 1e-4,
    "at tg's flat 0.1 a pass: " .. tostring(damage[1].amount))
assert(t.tank_pressure(2, 2) ~= nil,
    "and it is still standing -- 800 integrity is most of a shift")
local strained = t.examine(q, 2, 2, t.target_at(2, 2))
assert(table.concat(strained.lines, " | "):find("strain"),
    "which is what a look says: " .. table.concat(strained.lines, " | "))
