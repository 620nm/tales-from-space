-- The two machines that reach out of the plumbing and into a ROOM.
--
-- Every other device in the atmospherics kit moves gas between two
-- pipes. These two move it between a pipe and the air the crew is
-- standing in, in opposite directions, and between them they are what
-- makes a station's atmosphere a LOOP: the scrubber takes the used air
-- away, the injector (and its cousin the vent) hands fresh air back.
--
-- WHAT A PRESSURE CANNOT SAY, again. A scrubber set to filter takes one
-- gas out of a room and leaves the rest, so its correctness is a
-- question about WHICH gas — exactly as the gas filter's was
-- (gas_filter_test.luau). Every scrubbing assertion below is therefore
-- in moles, read off `t.room_gas` and `t.pipe_gas` the way an analyser
-- reads them, and the books are balanced across the room/net boundary
-- rather than trusted to a direction.

local PIPE_M3 = 0.070
local PORT_M3 = 0.200

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- Moles of one gas in the run under a tile, or in the room over it.
local function pipe_of(x, y, which, layer)
    local held = t.pipe_gas(x, y, layer)
    return held and held[which] or 0.0
end

local function room_of(x, y, which)
    local held = t.room_gas(x, y)
    return held and held[which] or 0.0
end

-- Every tile of a room, summed. A room is one cell per TILE and the
-- scrubber only ever works the tile it stands on, so the rest of the
-- room refills that tile by ordinary diffusion between passes — which
-- means the books have to be taken over the whole room and not over the
-- one tile being worked.
local ROOM_TILES = {}
for x = 1, 6 do
    for y = 1, 2 do
        ROOM_TILES[#ROOM_TILES + 1] = { x, y }
    end
end

local function room_total(which)
    local sum = 0.0
    for _, tile in ipairs(ROOM_TILES) do
        sum = sum + room_of(tile[1], tile[2], which)
    end
    return sum
end

-- All the air in the room, in moles. A single tile's PRESSURE sloshes
-- for a while after anything violent happens to a room -- the gas
-- spreads tile to tile at its own pace -- so anything asserted about a
-- room filling or holding still is asserted on the conserved quantity
-- instead. Twelve tiles of one cubic metre at an atmosphere is about
-- 499 moles, which is the line "past one atmosphere" means.
local function room_air()
    return room_total("o2") + room_total("n2")
end

local ROOM_AT_ONE_ATM = 101325.0 * 12.0 / (8.314 * 293.15)

-- ---------------------------------------------------------------
-- A SCRUBBER SET TO FILTER TAKES ONE GAS AND LEAVES THE OTHER.
--
-- Standard air is two gases, 21% oxygen and 79% nitrogen, which is all
-- the instrument this needs: point a scrubber at oxygen and the room
-- should lose oxygen and keep its nitrogen, with every mole that left
-- the room turning up in the waste main.
--
-- It also opens with a real negative that costs nothing to assert. tg
-- ships a scrubber set to carbon dioxide (vent_scrubber.dm:24) because
-- that is what a crew exhales — and a room nobody has breathed in has
-- none, so a freshly bolted scrubber in a clean room runs and takes
-- NOTHING. That is correct, and it is the commonest "my scrubber is
-- broken" there is.
-- ---------------------------------------------------------------
local SCRUB_MAP = [==[(
    name: "scrubbed room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#....ag#",
        "########",
    ],
    spawns: [(5, 2)],
    // The waste main runs out under the west wall, so the room's air
    // has somewhere to go that is not the room.
    // Layer 2, because that is where a scrubber lives (tg's
    // `vent_scrubber/on/layer2`, and see the structure's own file).
    pipes: [(0, 1, 2), (1, 1, 2)],
    // Spelled out, because a placement that says nothing is a RETURN
    // GRILLE -- whole air, gently, down to a floor -- and this file is
    // about the other machine: tg's scrubber, pointed at one gas with
    // the dial wide open and nothing under it. scrubber_floor_test.luau
    // is the grille's.
    structures: [(2, 1, "air_scrubber", { "whole_air": false, "rate_lps": 200.0, "floor_kpa": 0.0 })],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==]

t.world(SCRUB_MAP, 7)

local p = t.join()
t.tick()

assert(t.structure_at(2, 1).id == "air_scrubber", "the map stood one there")
assert(t.structure_at(2, 1).state == "off", "and tg's ships off")

-- The waste main is two lengths and the scrubber's one mouth.
local WASTE_M3 = 2 * PIPE_M3 + PORT_M3

local room_o2_0 = room_total("o2")
local room_n2_0 = room_total("n2")
local waste_o2_0 = pipe_of(1, 1, "o2", 2)
local waste_n2_0 = pipe_of(1, 1, "n2", 2)
assert(room_o2_0 > 0.0 and room_n2_0 > 0.0, "the room holds standard air, which is two gases")

-- ---- switched on, set to carbon dioxide, in a room that has none ----
t.click(p, 5, 2, nil)
for _ = 1, 3 do
    walk(p, "west")
end
t.click(p, 2, 1, t.target_at(2, 1, "air_scrubber"))
t.tick()
local panel = t.ui(p)
assert(panel, "a scrubber wears a panel of its own")
assert(panel.setpoints[1].field == "rate", "with a rate on it")
near(panel.setpoints[1].value, 200.0, 0.001, "tg's volume_rate")
-- And a second dial, which tg has no equivalent of: the pressure the
-- machine works down to and stops at. Zero is tg exactly, and zero is
-- what this one was placed with.
assert(panel.setpoints[2].field == "floor", "and a floor under it")
assert(panel.setpoints[2].unit == "kPa", "which is a pressure, not a rate")
near(panel.setpoints[2].value, 0.0, 0.001, "set to tg's nothing")

local roster = {}
local direction = nil
local shape = nil
for _, sw in ipairs(panel.toggles) do
    if sw.field == "filter" then
        roster[sw.option] = sw.on
    elseif sw.field == "direction" then
        direction = sw
    elseif sw.field == "roster" then
        shape = sw
    end
end
assert(shape ~= nil, "the roster has a SHAPE switch above its buttons")
assert(shape.on == false, "and this one sieves rather than taking the lot")
assert(roster.co2 == true, "tg ships it set to carbon dioxide")
assert(roster.o2 == false, "and to nothing else")
assert(roster.n2 == false)
assert(direction ~= nil, "and it has a DIRECTION, which no other device has")
assert(direction.on == false, "opening on the safe one")
assert(
    string.find(direction.off_text, "scrub") ~= nil,
    "named by what it does, not by being 'off': " .. direction.off_text
)

t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(2, 1).state == "scrubbing", "it is running")

t.run_seconds(20)
near(room_total("o2"), room_o2_0, 0.05, "a scrubber set to CO2 in a clean room takes nothing")
near(room_total("n2"), room_n2_0, 0.05, "not a mole of it")

-- ---- point it at oxygen, and only oxygen moves ----
t.ui_act(p, "toggle", '{"field":"filter","option":"co2"}')
t.ui_act(p, "toggle", '{"field":"filter","option":"o2"}')
t.run_seconds(30)

local room_o2_1 = room_total("o2")
local room_n2_1 = room_total("n2")
assert(
    room_o2_1 < room_o2_0 - 0.5,
    "the room lost oxygen: " .. room_o2_0 .. " -> " .. room_o2_1
)
near(room_n2_1, room_n2_0, 0.05, "and kept every mole of its nitrogen")
assert(
    pipe_of(1, 1, "o2", 2) > waste_o2_0 + 0.5,
    "which turned up in the waste main: " .. waste_o2_0 .. " -> " .. pipe_of(1, 1, "o2", 2)
)
near(pipe_of(1, 1, "n2", 2), waste_n2_0, 0.05, "and no nitrogen followed it")

-- The books, across the room/net boundary. Nothing else in this map
-- moves gas, so what left one side is on the other.
near(
    room_o2_1 + pipe_of(1, 1, "o2", 2),
    room_o2_0 + waste_o2_0,
    0.05,
    "every mole of oxygen is accounted for"
)

-- ---- turned round, it takes everything ----
--
-- tg's siphon direction, and the picture changes with it because
-- standing in a room being emptied is fatal and should look it.
t.ui_act(p, "toggle", '{"field":"direction"}')
t.run_ticks(2)
assert(
    t.ledger_has("MachineToggled", "direction", "Player"),
    "and turning a scrubber round is an attributed act"
)
-- The PICTURE is a different question and it has not changed yet: the
-- third position is a warning about a room going empty, not about a
-- switch, so it waits for the air at the grille to fall under
-- `safe_pressure_kpa` (docs/ATMOS.md SS8; device_looks_test.luau owns
-- the crossing). This room is still full.
assert(t.structure_at(2, 1).state == "scrubbing", "which the corridor is not told about yet")

local n2_before_siphon = room_total("n2")
t.run_seconds(30)
assert(
    room_total("n2") < n2_before_siphon - 0.5,
    "siphoning takes the nitrogen too: " .. n2_before_siphon .. " -> " .. room_total("n2")
)
assert(
    pipe_of(1, 1, "n2", 2) > waste_n2_0 + 0.5,
    "and it is in the waste main, where the oxygen already was"
)
assert(WASTE_M3 > 0.0, "the waste main is a real net")
-- ...and by now it HAS emptied the tile it stands on, so the machine is
-- finally drawn as the dangerous thing it has been all along.
assert(
    t.structure_at(2, 1).state == "siphoning",
    "and once the air at the grille is gone the machine is drawn"
        .. " differently: " .. tostring(t.structure_at(2, 1).state)
)

-- ---------------------------------------------------------------
-- AN INJECTOR HAS NO NOTION OF ENOUGH.
--
-- The one machine in the kit with no setpoint and no ceiling. A vent
-- works a room to one atmosphere and stops; this keeps going, which is
-- the entire reason gas storage and burn chambers are built out of it.
-- So the assertion is not "the room fills" — a vent does that — it is
-- that the room goes PAST one atmosphere and keeps climbing.
--
-- The supply main is a canister on a connector port with a gas pump
-- regulating the feed at one atmosphere -- tg's own station shape,
-- because a fastened bottle IS its line (the wrench couples them into
-- one body of gas), and forty atmospheres straight into an injector
-- makes a hurricane no engineer can stand at. The pump holds the feed
-- at its setpoint off the fat reserve, which is precisely the job tg
-- gives it.
-- ---------------------------------------------------------------
t.world([==[(
    name: "injected room",
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
        "#c.....#",
        "#...a.g#",
        "########",
    ],
    spawns: [(4, 2)],
    air_presets: {
        "canister_air": (gases: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15),
    },
    structures: [
        (1, 1, "connector_port", { "dir": "east" }),
        (1, 1, "canister", { "air": "canister_air" }),
        (2, 1, "gas_pump", "running", { "dir": "east" }),
        (3, 1, "air_injector"),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local q = t.join()
t.tick()

assert(t.structure_at(3, 1).id == "air_injector", "an injector")
assert(t.structure_at(3, 1).state == "off", "off out of the crate")

local room_0 = t.room_pressure(5, 2)
assert(room_0 > 90.0 and room_0 < 110.0, "the room opens at about an atmosphere: " .. room_0)

t.click(q, 3, 1, t.target_at(3, 1, "air_injector"))
t.tick()
local inj = t.ui(q)
assert(inj.setpoints[1].field == "rate", "the injector's dial is a volume rate")
assert(inj.setpoints[1].unit == "L/s")
near(inj.setpoints[1].value, 50.0, 0.001, "tg's volume_rate = 50")
near(inj.setpoints[1].max, 200.0, 0.001, "up to MAX_TRANSFER_RATE")
-- A unary machine has ONE mouth, and the panel says so rather than
-- reading "no pipe" forever on a port it does not have.
local labels = {}
for _, r in ipairs(inj.readouts) do
    labels[r.label] = r.value
end
assert(labels["pipe"] ~= nil, "one port readout, not two")
assert(labels["output"] == nil, "there is no second mouth to report")
assert(labels["room"] ~= nil, "and the other end is a ROOM, so it reads one")

-- ---- gently first, so the switch can be tested at all ----
--
-- Left at tg's default fifty litres a second: enough to overfill a
-- room, calm enough to stand next to while it does. (The dial goes to
-- two hundred, and what THAT is like is the next paragraph.)
t.ui_act(q, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "injecting", "it is running")

-- Sixty seconds, where thirty used to do: the regulated feed tops out
-- at the pump's own 120 L/s, where the old bottle-setpoint line was
-- re-pegged to one atmosphere every pass regardless of draw.
local air_0 = room_air()
t.run_seconds(60)
local air_1 = room_air()
assert(
    air_1 > ROOM_AT_ONE_ATM * 1.05,
    "an injector does not stop at an atmosphere, which is the whole"
        .. " machine: " .. air_0 .. " -> " .. air_1 .. " mol, one atmosphere"
        .. " being " .. ROOM_AT_ONE_ATM
)

-- Switched off, it stops dead — no coasting, no setpoint to settle to.
t.ui_act(q, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "off", "and off is off")
local settled = room_air()
t.run_seconds(30)
near(room_air(), settled, 0.5, "a stopped injector injects nothing")

-- ---- and now wide open, which is a different experience ----
--
-- Two hundred litres a second into an already overfull room is a real
-- gust, and a gust drags whoever is standing in it (sim/wind.rs). So
-- the machine's own output pushes the engineer off its own panel and
-- keeps them there — reach is re-derived on every act rather than
-- trusted from when the window opened, which is why the switch above
-- was thrown while it was still calm. Asserted rather than worked
-- around: a machine you cannot walk back to while it runs is a real
-- property of a machine this strong.
t.ui_act(q, "set", '{"field":"rate","value":200}')
t.ui_act(q, "toggle", '{"field":"power"}')
t.run_ticks(2)
local before_x, before_y = t.pos(q)
t.run_seconds(30)
local after_x, after_y = t.pos(q)
assert(
    after_x ~= before_x or after_y ~= before_y,
    "the injector's own draught moved the engineer: "
        .. before_x .. "," .. before_y .. " -> " .. after_x .. "," .. after_y
)
assert(
    room_air() > settled,
    "and it is still climbing, with nothing in the machine to stop it"
)

-- ---------------------------------------------------------------
-- NEITHER OF THEM WORKS ON A DEAD GRID.
--
-- Both are fans, and tg bills both as such. Nobody ran cable into this
-- room, which is all it takes for the two of them to have no mains.
-- ---------------------------------------------------------------
t.world([==[(
    name: "dark room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(5, 2)],
    // The scrubber's waste line is layer 2, the injector's supply is
    // the default 3 -- which is exactly how the two are mapped.
    pipes: [(0, 1, 2), (1, 1, 2), (5, 1, 4), (6, 1, 4)],
    structures: [(2, 1, "air_scrubber"), (4, 1, "air_injector")],
)]==], 7)

local d = t.join()
t.tick()
t.run_seconds(3)

for _, job in ipairs({
    { x = 2, id = "air_scrubber", walk = { "west", "west", "west" } },
    { x = 4, id = "air_injector", walk = { "east", "east" } },
}) do
    for _, dir in ipairs(job.walk) do
        walk(d, dir)
    end
    t.click(d, job.x, 1, t.target_at(job.x, 1, job.id))
    t.tick()
    local ui = t.ui(d)
    local supply = nil
    for _, r in ipairs(ui.readouts) do
        if r.label == "supply" then
            supply = r.value
        end
    end
    assert(supply == "dead", job.id .. " says the mains are not behind it")
    t.ui_act(d, "toggle", '{"field":"power"}')
    t.run_ticks(2)
    assert(
        t.structure_at(job.x, 1).state == "off",
        job.id .. " is still drawn dead, which is tg's `on && is_operational`"
    )
    t.ui_close(d)
    t.tick()
end

local dark_room_o2 = room_of(3, 2, "o2")
local dark_room_kpa = t.room_pressure(3, 2)
t.run_seconds(60)
near(room_of(3, 2, "o2"), dark_room_o2, 0.05, "an unpowered scrubber takes nothing")
near(t.room_pressure(3, 2), dark_room_kpa, 0.5, "and an unpowered injector gives nothing")

-- ---------------------------------------------------------------
-- THE ROUND TRIP, both ways, for both machines.
-- ---------------------------------------------------------------
t.world([==[(
    name: "unary fittings",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#a....g#",
        "########",
    ],
    spawns: [(1, 2)],
    items: [
        (1, 2, "wrench"),
        (3, 2, "air_scrubber_fitting"),
        (4, 2, "air_injector_fitting"),
    ],
    pipes: [(1, 1, 4), (2, 1, 4)],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local s = t.join()
t.tick()
t.click(s, 1, 2, t.target_at(1, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(s).held == "wrench", "wrench in hand")

for _, job in ipairs({
    { x = 3, id = "air_scrubber" },
    { x = 4, id = "air_injector" },
}) do
    -- Stand one tile clear: you cannot raise a machine on the tile you
    -- are standing on (thermal_devices_test.luau asserts the refusal).
    walk(s, "east")
    t.click(s, job.x, 2, t.target_at(job.x, 2, job.id .. "_fitting"))
    t.run_seconds(2.5)
    local built = t.structure_at(job.x, 2)
    assert(
        built ~= nil and built.id == job.id,
        "a wrenched " .. job.id .. " fitting becomes the machine"
    )
    assert(
        t.target_at(job.x, 2, job.id .. "_fitting") == nil,
        "and the fitting is spent rather than left lying under it"
    )
end

-- ...and back. Both come up while off and hand their own fitting back.
for _, job in ipairs({
    { x = 4, id = "air_injector" },
    { x = 3, id = "air_scrubber" },
}) do
    t.click(s, job.x, 2, t.target_at(job.x, 2, job.id))
    t.run_seconds(2.5)
    assert(t.structure_at(job.x, 2) == nil, job.id .. " comes up off the deck")
    assert(
        t.count_items(job.id .. "_fitting") == 1,
        "and hands its fitting back"
    )
    walk(s, "west")
end

assert(said(s, "The air scrubber is bolted to the deck, grille upward."), "content's own words")
