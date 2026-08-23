-- Building a vent, which until now was the one machine in the
-- atmospherics kit nobody could build.
--
-- vents_test.luau is about the ARITHMETIC: what a vent does to a room
-- once it is bolted down. This file is about everything before that.
-- Both vents are ordinary content structures now -- a fitting you carry,
-- a wrench you turn, a row on the RPD's shelf and on the pipe
-- dispenser's -- so the interesting claim is that a vent an engineer
-- built is the SAME MACHINE a mapper draws, right down to bringing its
-- room back to one atmosphere.
--
-- The refusals matter as much as the successes, and they are the
-- scrubber's own (room_devices_test.luau, rpd_test.luau): a unary
-- component IS the length on its tile, so it neither needs nor permits
-- raw pipe under its centre, and it reaches the run beside it through
-- one mouth.

local ONE_ATM = 101.325
-- The release line the powered vent works to (vents.rs SUPPLY_BELOW).
local SUPPLIES_UNDER = ONE_ATM * 0.99
-- tg's five piping layers as a bitmask; 4 is layer 3, the distro run.
local DISTRO = 4

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

-- 0.4 s of tg's `atmos_build_speed` (RPD.dm:53), plus slack for the
-- tick the effect lands on.
local function work()
    t.run_ticks(12)
end

-- One step, plus the move cooldown, so two calls are two steps.
local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- The RPD's fitting dial, and the button on it wearing a word. Looked
-- up rather than counted, exactly as rpd_test.luau does: the shelf
-- grows, and this spec is what growing it is for.
local RECIPE = "dial1"

local function pick(p, label)
    for _, tog in ipairs(t.ui(p).toggles) do
        if tog.field == RECIPE and tog.option ~= nil and tog.label == label then
            return tog.option
        end
    end
    error("no fitting button labelled " .. label)
end

local function arm(p, label)
    t.ui_act(p, "toggle", '{"field":"' .. RECIPE .. '","option":"' .. pick(p, label) .. '"}')
    t.tick()
end

-- Everything standing in the run under a tile, in moles.
local function pipe_moles(x, y)
    local n = 0.0
    for _, amount in pairs(t.pipe_gas(x, y) or {}) do
        n = n + amount
    end
    return n
end

-- ---------------------------------------------------------------
-- ONE CLICK OF THE RPD, AND THE ROOM BREATHES AGAIN.
--
-- A sealed bay with a full canister on a socket at one end and a
-- distribution main running west under the deck. There is no vent on
-- the map at all, so the line is charged and the room it runs under
-- has no way to reach it -- which is exactly the station an
-- atmospherics technician is sent to fix.
--
-- The proof is the whole chain in one go: arm the dial, click the deck,
-- and then tear the hull open, weld it shut, and watch the machine that
-- was conjured out of a hand tool bring its own tile back to one
-- atmosphere out of the bottle and nowhere else.
-- ---------------------------------------------------------------
t.world([==[(
    name: "vent bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'c': (turf: Plating),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#.....c#",
        "#..a..g#",
        "########",
    ],
    spawns: [(3, 2)],
    items: [(3, 2, "rpd")],
    pipes: [(4, 1, 4), (5, 1, 4)],
    air_presets: {
        "canister_air": (gases: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15),
    },
    structures: [
        (6, 1, "connector_port"),
        (6, 1, "canister", { "air": "canister_air", "open": true }),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

t.click(p, 3, 2, t.target_at(3, 2, "rpd"))
t.run_ticks(2)
assert(t.hands(p).held == "rpd", "the RPD is in hand")
t.use_self(p)
t.tick()

assert(t.pipe_pressure(4, 1) > 90.0, "the mapped main opens the shift charged")
assert(t.structure_at(3, 1) == nil, "and nothing stands where the vent will go")

-- ---- the refusal comes first ----
--
-- A vent owns its centre length on its own layer, so the one place it
-- may NOT go is on top of the main it is meant to draw from. Same
-- sentence, same words, as the scrubber and the connector get.
arm(p, "Air Vent")
walk(p, "east") -- (4, 2), under the main
local _ = t.messages(p)
t.click(p, 4, 1)
work()
assert(t.structure_at(4, 1) == nil, "a vent did not cover its centre run")
assert(t.pipe(4, 1) == DISTRO, "and the raw run is intact")
assert(
    said(p, "Something is already under the floor here."),
    "the refusal names the occupancy"
)

-- ---- and then the machine ----
walk(p, "west") -- back to (3, 2)
t.click(p, 3, 1)
work()
local vent = t.structure_at(3, 1)
assert(vent ~= nil and vent.id == "vent", "one click of the RPD built a vent")
assert(t.pipe(3, 1) == 0, "a unary component is not pipe-over-pipe")
assert(t.pipe_pressure(3, 1) == nil, "its own tile carries no run at all")
assert(
    t.ledger_has("StructureStep", "vent"),
    "and raising one is an attributed act, like every other machine"
)

-- Out of the crate it is RUNNING, which is what a vent is: there is no
-- handle on it and nothing for a player to have switched.
assert(vent.state == "blowing", "a vent with power is a vent that runs")

-- Tear the deck open beside the fan. There is no breach state anywhere
-- (CLAUDE.md): a hull breach is a floor that became space.
walk(p, "east") -- out of the way of the wind
assert(t.set_turf(2, 1, "space"), "the deck opens")
t.run_seconds(20)
assert(
    t.room_pressure(3, 1) < SUPPLIES_UNDER,
    "the bay blew down past the vent's release line: " .. t.room_pressure(3, 1)
)
assert(t.set_turf(2, 1, "plating"), "and the deck goes back")
t.tick()

local spent_before = t.canister_pressure(6, 1)
t.run_seconds(40)
assert(
    t.room_pressure(3, 1) > SUPPLIES_UNDER,
    "the built vent worked its own tile back to one atmosphere: "
        .. t.room_pressure(3, 1) .. " kPa"
)
assert(
    t.room_pressure(3, 1) <= ONE_ATM + 0.5,
    "and stopped there, the way a mapped one does: " .. t.room_pressure(3, 1)
)
assert(
    t.canister_pressure(6, 1) < spent_before,
    "every mole of it came out of the bottle: "
        .. spent_before .. " -> " .. t.canister_pressure(6, 1) .. " kPa"
)

-- ---------------------------------------------------------------
-- A FITTING, A WRENCH, AND THE SAME MACHINE BACK OUT AGAIN.
--
-- The other half of tg's universal atmospherics construction, on the
-- unpowered twin: `/obj/item/pipe/wrench_act` deletes the fitting and
-- spawns the machine, and `on_deconstruction` mints the fitting back
-- onto the tile (atmosmachinery.dm:511-520). Two seconds each way.
--
-- The bind is proved the only way a passive vent can be: it is a hole,
-- so foul the room and the surplus turns up in the run behind it.
-- ---------------------------------------------------------------
t.world([==[(
    name: "passive vent bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#a.....#",
        "#.....g#",
        "########",
    ],
    spawns: [(3, 2)],
    items: [(3, 2, "wrench"), (3, 1, "passive_vent_fitting")],
    pipes: [(4, 1, 4), (5, 1, 4), (6, 1, 4)],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local q = t.join()
t.tick()

local fitting = t.target_at(3, 1, "passive_vent_fitting")
assert(fitting ~= nil, "the fitting is lying on the deck, targetable")
t.click(q, 3, 2, t.target_at(3, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(q).held == "wrench", "wrench in hand, which is the whole toolkit")

t.click(q, 3, 1, fitting)
t.run_seconds(2.5)
local hole = t.structure_at(3, 1)
assert(hole ~= nil and hole.id == "passive_vent", "the fitting became the machine")
assert(t.count_items("passive_vent_fitting") == 0, "and the fitting is spent")
assert(t.pipe(3, 1) == 0, "the passive vent owns its centre, like every unary")

-- It reaches the main beside it through one mouth, and it is a hole
-- both ways: over-pressure the tile it stands on and the surplus goes
-- down the line rather than staying in the room.
local net_before = pipe_moles(4, 1)
assert(net_before > 0.0, "the mapped run opens charged")
assert(t.foul_room(3, 1, "n2", 30.0), "thirty moles go into the vent's own tile")
t.run_seconds(20)
assert(
    pipe_moles(4, 1) > net_before + 1.0,
    "a fouled room pushes back INTO the line: "
        .. net_before .. " -> " .. pipe_moles(4, 1) .. " mol"
)

-- ---- and it comes up again ----
local _ = t.messages(q)
t.click(q, 3, 1, t.target_at(3, 1, "passive_vent"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1) == nil, "the passive vent came up off the deck")
assert(
    said(q, "The passive vent comes up off the deck."),
    "narrated in the file's own words"
)
assert(
    t.count_items("passive_vent_fitting") == 1,
    "and it is a fitting you can bolt down somewhere else"
)
assert(
    t.ledger_has("StructureStep", "passive_vent", "gone"),
    "taking one up is on the record too"
)
