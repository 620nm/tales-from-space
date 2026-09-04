-- The canister's control window: the first machine to wear the
-- generic settings panel, driven the way a player drives it.
--
-- canister_test.luau proves the PLUMBING (a bottle feeds a run, the
-- books balance, an empty canister repressurises nothing). This spec
-- is about the two knobs a crewman actually turns, and it asserts the
-- only thing that finally matters about a UI: that clicking it moves
-- gas, and that the ledger says who moved it.
--
-- The room below starts sealed and breathable, and the canister in it
-- is standing LOOSE on the deck (no socket under it), so its release
-- valve is pointed at the ROOM -- tg's `location.return_air()`
-- fallback. That makes the regulator legible: at the default setpoint
-- the room is already at target and nothing moves, so any gas that
-- flows later flowed because a player dialled it up.

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

-- A settled room at one atmosphere, and a full bottle beside it.
t.run_seconds(5)
local room_start = t.room_pressure(1, 1)
local can_start = t.canister_pressure(2, 2)
assert(room_start > 90.0, "the room starts breathable: " .. room_start)
assert(can_start > 4000.0, "and the canister starts full: " .. can_start)

-- ---------------------------------------------------------------
-- Clicking the bottle opens its panel. An empty hand, no tool, no
-- script: the machine-window path.
-- ---------------------------------------------------------------
t.click(p, 2, 2, t.target_at(2, 2))
t.tick()
local ui = t.ui(p)
assert(ui, "clicking a canister opens its window")
assert(ui.document == "modules" and ui.presentation == "modules",
    "the generic module document")

local valve = ui.toggles[1]
assert(valve.field == "valve", "the one switch is the release valve")
assert(valve.on == true, "which starts open")

local reg = ui.setpoints[1]
assert(reg.field == "release", "the one knob is the regulator")
assert(math.abs(reg.value - 101.325) < 0.001,
    "at tg's CAN_DEFAULT_RELEASE_PRESSURE: " .. reg.value)
-- tg's CAN_MIN/MAX_RELEASE_PRESSURE, in kPa.
assert(math.abs(reg.min - 10.1325) < 0.001, "min: " .. reg.min)
assert(math.abs(reg.max - 2533.125) < 0.001, "max: " .. reg.max)

-- The bottle is not plumbed into anything, and the panel says so
-- rather than leaving it to be inferred from a sprite.
local port = nil
for _, r in ipairs(ui.readouts) do
    if r.label == "port" then
        port = r.value
    end
end
assert(port == "loose", "an unfastened canister reads loose: " .. tostring(port))

-- ---------------------------------------------------------------
-- The knob. A room already at the setpoint costs nothing; dial the
-- regulator up and the same bottle starts pouring into the same room.
-- ---------------------------------------------------------------
t.run_seconds(10)
assert(math.abs(t.room_pressure(1, 1) - room_start) < 2.0,
    "at the default setpoint nothing moves: " .. t.room_pressure(1, 1))

t.ui_act(p, "set", '{"field":"release","value":400}')
t.tick()
assert(math.abs(t.ui(p).setpoints[1].value - 400.0) < 0.001,
    "the panel reports the new setting: " .. t.ui(p).setpoints[1].value)

t.run_seconds(60)
local room_up = t.room_pressure(1, 1)
local can_down = t.canister_pressure(2, 2)
assert(room_up > 200.0, "the room came up with the regulator: " .. room_up)
assert(can_down < can_start - 50.0,
    "and the canister is what paid: " .. can_start .. " -> " .. can_down)

-- ---------------------------------------------------------------
-- The switch. Shut the valve and the same over-pressure demand buys
-- nothing at all -- which is the whole point of a valve.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"valve"}')
t.tick()
assert(t.ui(p).toggles[1].on == false, "the panel reports the valve shut")

local held = t.canister_pressure(2, 2)
local room_held = t.room_pressure(1, 1)
-- ...and, while it is shut, wind the regulator all the way to its
-- maximum (tg's "max" word, the same one the panel's button sends). A
-- setpoint is not a tap: the largest number this machine will accept
-- still moves nothing through a closed valve.
t.ui_act(p, "set", '{"field":"release","value":"max"}')
t.run_seconds(30)
assert(math.abs(t.canister_pressure(2, 2) - held) < 1.0,
    "a shut valve moves nothing: " .. held .. " -> " .. t.canister_pressure(2, 2))
assert(math.abs(t.room_pressure(1, 1) - room_held) < 1.0,
    "and the room is untouched: " .. t.room_pressure(1, 1))

-- Open it, and now both move at once.
t.ui_act(p, "toggle", '{"field":"valve"}')
t.run_seconds(20)
assert(t.canister_pressure(2, 2) < held - 50.0,
    "reopened, the bottle empties into the room: " .. t.canister_pressure(2, 2))
assert(t.room_pressure(1, 1) > room_held + 50.0,
    "which is where the gas went: " .. t.room_pressure(1, 1))

-- ---------------------------------------------------------------
-- Both verbs are on the record, against the PLAYER. A release valve
-- is how a bottle of gas gets into a room somebody is standing in, so
-- this is the accountability the ledger exists for.
-- ---------------------------------------------------------------
assert(t.ledger_has("MachineSetpoint", "release", "Player"),
    "re-dialling the regulator is an attributed act")
assert(t.ledger_has("MachineToggled", "valve", "Player"),
    "so is throwing the valve")

-- ---------------------------------------------------------------
-- NEGATIVE: the client is hostile. The window a machine is showing IS
-- the whitelist -- a number outside the range it published is clamped
-- to the range, and a knob it does not offer is not a knob.
-- ---------------------------------------------------------------
t.ui_act(p, "set", '{"field":"release","value":-1000}')
t.tick()
assert(math.abs(t.ui(p).setpoints[1].value - 10.1325) < 0.001,
    "a client cannot dial below CAN_MIN_RELEASE_PRESSURE: " .. t.ui(p).setpoints[1].value)

t.ui_act(p, "set", '{"field":"release","value":999999}')
t.tick()
assert(math.abs(t.ui(p).setpoints[1].value - 2533.125) < 0.001,
    "nor past CAN_MAX_RELEASE_PRESSURE: " .. t.ui(p).setpoints[1].value)

-- A knob belonging to a machine this is not (the pump's rate),
-- and a verb nothing has.
local before = t.ui(p).setpoints[1].value
t.ui_act(p, "set", '{"field":"rate","value":50}')
t.ui_act(p, "detonate", "{}")
t.tick()
assert(t.ui(p).setpoints[1].value == before, "an invented knob turns nothing")

-- NEGATIVE: no window, no verbs -- the same rule the vendor follows.
local valve_before = t.ui(p).toggles[1].on
t.ui_close(p)
t.ui_act(p, "toggle", '{"field":"valve"}')
t.run_ticks(2)
t.click(p, 2, 2, t.target_at(2, 2))
t.tick()
assert(t.ui(p).toggles[1].on == valve_before,
    "a closed window cannot throw a valve")
