-- What atmospherics machinery LOOKS like while it is working, as a
-- player standing in the room sees it.
--
-- The other specs in this directory ask what the gas did. This one asks
-- what the room told you, which for a valve is a different question with
-- a different answer for about a second and a half.
--
-- tg draws a worked valve in two independent motions, and the whole
-- point of this file is that they are independent
-- (components/binary_devices/valve.dm):
--
--   * `interact()` flicks the turn the instant your click lands
--     (valve.dm:67 -> `update_icon_nopipes(TRUE)`, valve.dm:24-29),
--   * and sets a ONE SECOND timer that will actually move the gas
--     (valve.dm:70 -> `finish_interact` -> `set_open`).
--
-- The art runs 1.4 seconds (`mvalve_01`, five frames of `2,2,2,2,6`).
-- So there is a stretch in the middle where the valve is open, the gas
-- is already crossing, and the wheel is still visibly moving. That is
-- not a bug to be tidied up: `flick()` is cosmetic and the timer is the
-- mechanism, and the engine copies tg's numbers rather than reconciling
-- them.
--
-- Every sprite name asserted below comes from a TfS content file --
-- `structures/manual_valve.luau`'s `moving_sprites`. The engine has
-- never heard of any of them, which is the property this spec is really
-- guarding.

-- ---------------------------------------------------------------
-- A VALVE YOU CAN SEE TURNING.
--
-- One main, one valve, one crewman standing under it.
-- ---------------------------------------------------------------
t.world([==[(
    name: "a valve to watch",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "#######",
        "#.....#",
        "#..a.g#",
        "#######",
    ],
    spawns: [(3, 2)],
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4)],
    structures: [(3, 1, "manual_valve")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

local valve = t.structure_at(3, 1)
assert(valve.id == "manual_valve", "the map stood a valve on the main")
assert(valve.state == "shut", "and tg's valve ships shut")
assert(
    valve.sprite == "valve_shut_ew",
    "wearing the east-west picture, because it lies across an east-west run: "
        .. tostring(valve.sprite)
)

-- Click it. The wheel starts moving IMMEDIATELY -- before anything has
-- happened to the gas, which is the half of tg's behaviour that makes an
-- atmospherics valve feel like a commitment rather than a toggle.
t.click(p, 3, 1, t.target_at(3, 1, "manual_valve"))
t.run_ticks(1)

local turning = t.structure_at(3, 1)
assert(
    turning.sprite == "valve_opening_ew",
    "the wheel is turning on the click: " .. tostring(turning.sprite)
)
assert(turning.state == "shut", "and the gas has not moved yet")

-- One second in: tg's timer fires, the valve is open, the two runs are
-- one body of gas. The picture is STILL the turn -- four tenths of a
-- second of animation left to play over a machine that has already
-- changed. A repaint that wrote the resting picture here would cut the
-- wheel off mid-swing.
t.run_seconds(1.0)
local mid = t.structure_at(3, 1)
assert(mid.state == "open", "a second is a second, and then it is open")
assert(
    mid.sprite == "valve_opening_ew",
    "and the wheel is still turning after the gas is through: "
        .. tostring(mid.sprite)
)

-- The rest of the art plays out and the valve comes to rest.
t.run_seconds(0.6)
local rest = t.structure_at(3, 1)
assert(rest.state == "open")
assert(
    rest.sprite == "valve_open_ew",
    "and settles on the position it travelled to: " .. tostring(rest.sprite)
)

-- ---------------------------------------------------------------
-- SHUTTING IT PLAYS THE OTHER PICTURE.
--
-- tg ships `mvalve_01` and `mvalve_10` as two different animations, and
-- so does the content file: a valve closing does not look like a valve
-- opening played backwards, it looks like its own art.
-- ---------------------------------------------------------------
t.click(p, 3, 1, t.target_at(3, 1, "manual_valve"))
t.run_ticks(1)
assert(
    t.structure_at(3, 1).sprite == "valve_closing_ew",
    "the other direction is its own picture: "
        .. tostring(t.structure_at(3, 1).sprite)
)

-- And a second click during the turn is nothing at all -- not a cancel,
-- not a queue, not a second turn. tg refuses every interaction while
-- `switching` is set (valve.dm:65-66).
t.click(p, 3, 1, t.target_at(3, 1, "manual_valve"))
t.run_seconds(2.0)
local shut = t.structure_at(3, 1)
assert(shut.state == "shut", "it shut once, and stayed shut")
assert(
    shut.sprite == "valve_shut_ew",
    "resting again: " .. tostring(shut.sprite)
)

-- ---------------------------------------------------------------
-- A RUNNING PUMP IS A LOOP, AND A LOOP IS NOT AN EVENT.
--
-- tg's `pump_on-1` is five frames that cycle forever. Nothing about it
-- is server state: the sprite NAME changes when the machine is switched
-- on and never again, and the frames are the client's business. So the
-- assertion is that the pump wears its running picture and simply keeps
-- wearing it -- if a loop ever started needing an anchor, this is where
-- it would show up as the name drifting.
-- ---------------------------------------------------------------
t.world([==[(
    name: "a pump to watch",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "#######",
        "#.....#",
        "#..a.g#",
        "#######",
    ],
    spawns: [(3, 2)],
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4)],
    structures: [(3, 1, "gas_pump")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3),
    ],
)]==], 7)

local q = t.join()
t.tick()

local pump = t.structure_at(3, 1)
assert(pump.id == "gas_pump", "the map stood a pump on the main")
assert(pump.state == "off", "and tg's pump ships off")
assert(
    pump.sprite == "pump_off_ew",
    "dark: " .. tostring(pump.sprite)
)

-- The pump wears a panel rather than a wheel, so a hand on it opens the
-- window instead of switching it (tg's `interact()` on a pump is
-- `ui_interact`, pump.dm:68) and the switch is thrown there.
t.click(q, 3, 1, t.target_at(3, 1, "gas_pump"))
t.tick()
assert(t.ui(q), "a pump answers an empty hand with a panel")
t.ui_act(q, "toggle", '{"field":"power"}')
t.run_ticks(2)

local running = t.structure_at(3, 1)
assert(running.state == "running", "the switch throws")
assert(
    running.sprite == "pump_on_ew",
    "and the pump wears its running body: " .. tostring(running.sprite)
)

-- Twenty seconds later it is wearing exactly the same name. The five
-- frames are the client's clock, not the sim's.
t.run_seconds(20)
assert(
    t.structure_at(3, 1).sprite == "pump_on_ew",
    "a loop needs no anchor and never changes its name"
)
