local ui_controls = require("@helpers/ui_controls")
local atmos_cell = require("@helpers/atmos_cell")

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

t.world(
    [==[(
    name: "canister bay",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'c': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    blends: {
        "canister_air": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15, amount: per_m3),
    },
    levels: [
        (
            structures: [
                (2, 1, "player_spawn"),
                (2, 2, "canister", { "blend": "canister_air", "open": true }),
            ],
            rows: [
                "#####",
                "#...#",
                "#.c.#",
                "#...#",
                "#####",
            ],
        ),
    ],
)]==],
    7
)

local p = t.join()
t.tick()

-- A settled room at one atmosphere, and a full bottle beside it.
t.run_seconds(5)
local room_start = assert(t.room_pressure(1, 1))
local can_start = assert(t.canister_pressure(2, 2))
assert(room_start > 90.0, "the room starts breathable: " .. room_start)
assert(can_start > 4000.0, "and the canister starts full: " .. can_start)

-- ---------------------------------------------------------------
-- Clicking the bottle opens its panel. An empty hand, no tool, no
-- script: the machine-window path.
-- ---------------------------------------------------------------
t.click(p, 2, 2, t.target_at(p, 2, 2))
t.tick()
local ui = ui_controls.record(assert(t.ui(p)))
assert(ui, "clicking a canister opens its window")
assert(ui.document == "modules" and ui.presentation == "modules", "the generic module document")

local valve = ui_controls.rows(ui.toggles)[1]
assert(valve.field == "valve", "the one switch is the release valve")
assert(valve.on == true, "which starts open")

local reg = ui_controls.rows(ui.setpoints)[1]
assert(reg.field == "release", "the one knob is the regulator")
assert(
    math.abs(ui_controls.number(reg.value) - 101.325) < 0.001,
    "at tg's CAN_DEFAULT_RELEASE_PRESSURE: " .. ui_controls.number(reg.value)
)
-- tg's CAN_MIN/MAX_RELEASE_PRESSURE, in kPa.
assert(
    math.abs(ui_controls.number(reg.min) - 10.1325) < 0.001,
    "min: " .. ui_controls.number(reg.min)
)
assert(
    math.abs(ui_controls.number(reg.max) - 2533.125) < 0.001,
    "max: " .. ui_controls.number(reg.max)
)

-- The bottle is not plumbed into anything, and the panel says so
-- rather than leaving it to be inferred from a sprite.
-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local word = ui_controls.word

local port = nil
for _, r in ipairs(ui_controls.rows(ui.readouts)) do
    if word(r.label) == "canister.port" then
        port = word(r.value)
    end
end
assert(port == "canister.port.loose", "an unfastened canister reads loose: " .. tostring(port))

-- ---------------------------------------------------------------
-- The knob. A room already at the setpoint costs nothing; dial the
-- regulator up and the same bottle starts pouring into the same room.
-- ---------------------------------------------------------------
t.run_seconds(10)
assert(
    math.abs(assert(t.room_pressure(1, 1)) - room_start) < 2.0,
    "at the default setpoint nothing moves: " .. assert(t.room_pressure(1, 1))
)

ui_controls.set(p, "release", 400)
t.tick()
assert(
    math.abs(ui_controls.number(ui_controls.rows(ui_controls.state(p).setpoints)[1].value) - 400.0)
        < 0.001,
    "the panel reports the new setting: "
        .. ui_controls.number(ui_controls.rows(ui_controls.state(p).setpoints)[1].value)
)

-- Three seconds, not until the room reaches 400: a 2 m3 bottle brings a
-- room of nine 3 m3 cells to the setpoint in about 30 s and is left near
-- 523 kPa, which would leave "max" below almost nothing to pour. Measured
-- after the 3 s: the room at 228.6 kPa (on 1 m3 cells too) and the bottle
-- at 2569.4.
t.run_seconds(3)
local room_up = assert(t.room_pressure(1, 1))
local can_down = assert(t.canister_pressure(2, 2))
assert(room_up > 200.0, "the room came up with the regulator: " .. room_up)
assert(
    can_down < can_start - 50.0,
    "and the canister is what paid: " .. can_start .. " -> " .. can_down
)

-- ---------------------------------------------------------------
-- The switch. Shut the valve and the same over-pressure demand buys
-- nothing at all -- which is the whole point of a valve.
-- ---------------------------------------------------------------
ui_controls.toggle(p, "valve")
t.tick()
assert(
    ui_controls.rows(ui_controls.state(p).toggles)[1].on == false,
    "the panel reports the valve shut"
)

-- The room evens out what three seconds poured onto the bottle's tile
-- before anything is held against the valve.
t.run_seconds(10)
local held = assert(t.canister_pressure(2, 2))
local room_held = assert(t.room_pressure(1, 1))
-- ...and, while it is shut, wind the regulator all the way to its
-- maximum (tg's "max" word, the same one the panel's button sends). A
-- setpoint is not a tap: the largest number this machine will accept
-- still moves nothing through a closed valve.
ui_controls.set(p, "release", "max")
t.run_seconds(30)
assert(
    math.abs(assert(t.canister_pressure(2, 2)) - held) < 1.0,
    "a shut valve moves nothing: " .. held .. " -> " .. assert(t.canister_pressure(2, 2))
)
assert(
    math.abs(assert(t.room_pressure(1, 1)) - room_held) < 1.0,
    "and the room is untouched: " .. assert(t.room_pressure(1, 1))
)

-- Open it at "max", and now both move at once: a big transfer, most of
-- the bottle into the room. Measured on the pack's 3 m3 cells: held
-- 2569.4 kPa against a 248.7 kPa room, and after 20 s 417.2 against
-- 407.8 -- a 2152.2 kPa drop for a 159.1 kPa rise. On 1 m3 cells the 3 s
-- fill leaves 3896.2 kPa in the bottle, and "max" blows the loose bottle
-- off its tile within a second (room 909.7 kPa at 20 s), so this step
-- holds on 3 m3 cells only.
ui_controls.toggle(p, "valve")
t.run_seconds(20)
local can_end = assert(t.canister_pressure(2, 2))
local room_end = assert(t.room_pressure(1, 1))
assert(
    can_end < 0.5 * held,
    "reopened, the bottle empties into the room: " .. held .. " -> " .. can_end
)
assert(room_end > room_held + 100.0, "and the room takes it: " .. room_held .. " -> " .. room_end)
-- The room gained what the bottle gave up. Both are ideal gas at one
-- temperature, so the bottle's drop over its 2 m3 is the room's rise over
-- 9 cells x CELL_VOLUME_M3. The run holds a little, so 80% is the floor
-- (measured 99.8%).
local CANISTER_M3 = 2.0
local ROOM_M3 = 9 * atmos_cell.CELL_VOLUME_M3
local bottle_drop = held - can_end
assert(
    room_end - room_held > 0.8 * bottle_drop * CANISTER_M3 / ROOM_M3,
    "which is where the gas went: "
        .. room_end
        .. " from "
        .. room_held
        .. ", bottle dropped "
        .. bottle_drop
)

-- ---------------------------------------------------------------
-- Both verbs are on the record, against the PLAYER. A release valve
-- is how a bottle of gas gets into a room somebody is standing in, so
-- this is the accountability the ledger exists for.
-- ---------------------------------------------------------------
assert(
    t.ledger_has("MachineSetpoint", "release", "Player"),
    "re-dialling the regulator is an attributed act"
)
assert(t.ledger_has("MachineToggled", "valve", "Player"), "so is throwing the valve")

-- ---------------------------------------------------------------
-- Out-of-range typed numbers clamp to the published range.
-- Controls belonging to other machines are absent from this window.
-- ---------------------------------------------------------------
ui_controls.set(p, "release", -1000)
t.tick()
assert(
    math.abs(
        ui_controls.number(ui_controls.rows(ui_controls.state(p).setpoints)[1].value) - 10.1325
    ) < 0.001,
    "a client cannot dial below CAN_MIN_RELEASE_PRESSURE: "
        .. ui_controls.number(ui_controls.rows(ui_controls.state(p).setpoints)[1].value)
)

ui_controls.set(p, "release", 999999)
t.tick()
assert(
    math.abs(
        ui_controls.number(ui_controls.rows(ui_controls.state(p).setpoints)[1].value) - 2533.125
    ) < 0.001,
    "nor past CAN_MAX_RELEASE_PRESSURE: "
        .. ui_controls.number(ui_controls.rows(ui_controls.state(p).setpoints)[1].value)
)

-- The pump's rate and an invented action have no rendered controls.
local before = ui_controls.number(ui_controls.rows(ui_controls.state(p).setpoints)[1].value)
assert(ui_controls.find(p, "/set/rate/value") == nil, "no pump dial is rendered")
assert(ui_controls.find(p, "/detonate") == nil, "no invented action is rendered")
t.tick()
assert(
    ui_controls.number(ui_controls.rows(ui_controls.state(p).setpoints)[1].value) == before,
    "an invented knob turns nothing"
)

-- NEGATIVE: no window, no verbs -- the same rule the vendor follows.
local valve_before = ui_controls.rows(ui_controls.state(p).toggles)[1].on
t.ui_close(p)
assert(ui_controls.find(p, "/toggle/valve/switch") == nil, "closing removes the valve control")
t.run_ticks(2)
t.click(p, 2, 2, t.target_at(p, 2, 2))
t.tick()
assert(
    ui_controls.rows(ui_controls.state(p).toggles)[1].on == valve_before,
    "a closed window cannot throw a valve"
)
