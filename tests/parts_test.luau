-- STOCK PARTS, from the outside: what a machine is built out of moves
-- what it does, and a crewman can read both off its panel.
--
-- Three claims, and every one of them is something a player could
-- cause. A MAP says which rung is in which socket and the machine runs
-- accordingly; a BUILDER puts whatever was in the bag into a frame and
-- the finished machine is worth exactly that; and a preconfigured
-- variant reaches further than the plain one.
--
-- The reaction chamber is the machine under test for the first two,
-- because its whole spec sheet is one socket: tg's `RefreshParts` sets
-- `heater_coefficient = 0.1` and multiplies by the micro-laser it finds
-- (chem_heater.dm:86-90), so a better laser is visible as nothing but a
-- beaker getting warm faster. The temperature control unit carries the
-- third, because both ends of its dial are its lasers
-- (thermomachine.dm:94-96) and a window states them outright.

local function rows_in(ui, section)
    local out = {}
    for _, r in ipairs(ui.readouts) do
        if r.section == section then
            table.insert(out, r)
        end
    end
    return out
end

local function row(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r
        end
    end
    return nil
end

-- The bench: mains down the west end, two chambers a map stood up, a
-- build site at the east end with a socket of its own -- a cord only
-- reaches so far -- and two temperature control units beyond it.
t.world([==[(
    name: "parts bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "############",
        "#o..a#g#...#",
        "#......o...#",
        "############",
    ],
    spawns: [(8, 2)],
    machines: [
        (2, 1, "chem_heater"),
        (3, 1, "chem_heater", { "laser_1": "4" }),
    ],
    structures: [
        (9, 1, "thermomachine", "off"),
        (10, 1, "thermomachine.fullupgrade", "off"),
    ],
    items: [
        (2, 2, "beaker.libital"),
        (3, 2, "beaker.libital"),
        (8, 2, "beaker.libital"),
        (8, 2, "metal"),
        (8, 2, "cable_coil"),
        (8, 2, "chem_heater_board"),
        (8, 2, "glass"),
        (8, 2, "micro_laser.tier3"),
        (8, 2, "screwdriver"),
    ],
    cables: [
        (1, 1, 1, 0, 2), (1, 1, 1, 0, 4), (1, 1, 2, 0, 2), (1, 1, 2, 0, 4),
        (2, 1, 1, 0, 2), (2, 1, 1, 0, 4), (2, 1, 1, 0, 8), (2, 1, 2, 0, 2),
        (2, 1, 2, 0, 4), (2, 1, 2, 0, 8), (3, 1, 1, 0, 2), (3, 1, 1, 0, 4),
        (3, 1, 1, 0, 8), (3, 1, 2, 0, 2), (3, 1, 2, 0, 4), (3, 1, 2, 0, 8),
        (4, 1, 1, 0, 2), (4, 1, 1, 0, 4), (4, 1, 1, 0, 8), (4, 1, 2, 0, 2),
        (4, 1, 2, 0, 4), (4, 1, 2, 0, 8), (5, 1, 1, 0, 2), (5, 1, 1, 0, 4),
        (5, 1, 1, 0, 8), (5, 1, 2, 0, 2), (5, 1, 2, 0, 4), (5, 1, 2, 0, 8),
        (6, 1, 1, 0, 2), (6, 1, 1, 0, 8), (6, 1, 2, 0, 2), (6, 1, 2, 0, 8),
        (1, 2, 1, 1, 4), (1, 2, 2, 1, 4), (2, 2, 1, 0, 1), (2, 2, 1, 0, 4),
        (2, 2, 1, 0, 8), (2, 2, 2, 0, 1), (2, 2, 2, 0, 4), (2, 2, 2, 0, 8),
        (3, 2, 1, 0, 1), (3, 2, 1, 0, 4), (3, 2, 1, 0, 8), (3, 2, 2, 0, 1),
        (3, 2, 2, 0, 4), (3, 2, 2, 0, 8), (4, 2, 1, 0, 1), (4, 2, 1, 0, 4),
        (4, 2, 1, 0, 8), (4, 2, 2, 0, 1), (4, 2, 2, 0, 4), (4, 2, 2, 0, 8),
        (5, 2, 1, 0, 1), (5, 2, 1, 0, 4), (5, 2, 1, 0, 8), (5, 2, 2, 0, 1),
        (5, 2, 2, 0, 4), (5, 2, 2, 0, 8), (6, 2, 1, 0, 1), (6, 2, 1, 0, 4),
        (6, 2, 1, 0, 8), (6, 2, 2, 0, 1), (6, 2, 2, 0, 4), (6, 2, 2, 0, 8),
        (7, 2, 1, 0, 4), (7, 2, 1, 0, 8), (7, 2, 2, 0, 4), (7, 2, 2, 0, 8),
        (8, 2, 1, 0, 1), (8, 2, 1, 0, 4), (8, 2, 1, 0, 8), (8, 2, 2, 0, 1),
        (8, 2, 2, 0, 4), (8, 2, 2, 0, 8), (9, 2, 1, 4, 8), (9, 2, 2, 4, 8),
        (10, 2, 1, 0, 8), (10, 2, 2, 0, 8),
        (8, 1, 1, 0, 2), (8, 1, 2, 0, 2),
    ],
)]==], 0)

local p = t.join()
t.tick()

local function take(x, y, id)
    t.click(p, x, y, t.target_at(x, y, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function put_down()
    t.drop(p)
    t.run_ticks(2)
end

-- One step is one command and one step's worth of ticks: a spec that
-- fires five in a tick has asked for one move and thrown four away.
local function walk(dir, steps)
    for _ = 1, steps do
        t.move(p, dir)
        t.run_ticks(5)
    end
end

-- ---------------------------------------------------------------
-- ONE: A FRAME TAKES WHATEVER IS IN THE BAG.
--
-- tg's frame accepts any tier of the part its board asks for
-- (machine_frame.dm), which is what makes a machine assembled in an
-- emergency work at all. Here the bag has an ULTRA-HIGH-POWER laser in
-- it -- rung three of four -- and the finished chamber is worth exactly
-- that, neither the plain rung nor the best one.
--
-- The board names one micro-laser and one pane
-- (machine_circuitboards.dm:807-809); the socket comes off the PRODUCT
-- and the pane off the board, which is the derivation this spec walks
-- without ever saying so twice.
-- ---------------------------------------------------------------
take(8, 2, "metal")
t.build(p, "metal", "machine_frame", 8, 1)
t.run_seconds(8.5)
assert(t.structure_at(8, 1).id == "machine_frame", "five sheets box up into a frame")

put_down()
take(8, 2, "cable_coil")
t.click(p, 8, 1, t.target_at(8, 1, "machine_frame"))
t.run_seconds(2.5)
assert(t.structure_at(8, 1).state == "wired", "five lengths of cable wire it")

put_down()
take(8, 2, "chem_heater_board")
t.click(p, 8, 1, t.target_at(8, 1, "machine_frame"))
t.run_ticks(2)
assert(t.structure_at(8, 1).state == "boarded", "the board clicks into place")

-- The screwdriver reads the shortfall out, and what it names first is
-- the SOCKET, because the sockets come from the product and are asked
-- for before the board's own stack materials.
take(8, 2, "screwdriver")
local _ = t.messages(p)
t.click(p, 8, 1, t.target_at(8, 1, "machine_frame"))
t.run_seconds(4.5)
local heard = table.concat(t.messages(p), " | ")
assert(
    heard:find("It still needs 1 x micro-laser.", 1, true),
    "the refusal names the socket by its plainest part, got: " .. heard
)

put_down()
take(8, 2, "glass")
t.click(p, 8, 1, t.target_at(8, 1, "machine_frame"))
t.run_ticks(2)
put_down()

take(8, 2, "micro_laser.tier3")
t.click(p, 8, 1, t.target_at(8, 1, "machine_frame"))
t.run_ticks(2)
assert(t.hands(p).held == nil, "a rung three laser fills the socket like any other")

take(8, 2, "screwdriver")
t.click(p, 8, 1, t.target_at(8, 1, "machine_frame"))
t.run_seconds(4.5)
local built = t.target_at(8, 1)
assert(built ~= nil, "the assembly becomes the machine its board named")
put_down()

-- ---------------------------------------------------------------
-- TWO: THE PANEL SAYS WHAT IS INSIDE.
-- ---------------------------------------------------------------
local warm_beaker = t.target_at(8, 2, "beaker.libital")
take(8, 2, "beaker.libital")
t.click(p, 8, 1, built)
t.run_ticks(2)

t.run_seconds(2)
t.click(p, 8, 1, built)
t.tick()
local ui = t.ui(p)
local parts = rows_in(ui, "parts")
assert(#parts == 1, "one socket, one row: got " .. #parts)
assert(parts[1].label == "ultra-high-power micro-laser",
    "the row is the part's own name: " .. parts[1].label)
assert(parts[1].value == "tier 3 · 2.00",
    "against its rung and what it is worth: " .. parts[1].value)
assert(row(ui, "vessel").value == "beaker (libital)",
    "a machine out of a frame docks like any other: " .. tostring(row(ui, "vessel").value))
assert(row(ui, "supply").value == "fed",
    "and the frame it came out of was wired: " .. tostring(row(ui, "supply").value))
t.ui_act(p, "set", '{"field":"temperature","value":400}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
t.ui_close(p)

-- The chamber a map stocked with the BEST laser.
walk("west", 5)
local best_beaker = t.target_at(3, 2, "beaker.libital")
take(3, 2, "beaker.libital")
t.click(p, 3, 1, t.target_at(3, 1))
t.run_ticks(2)
t.click(p, 3, 1, t.target_at(3, 1))
t.tick()
parts = rows_in(t.ui(p), "parts")
assert(#parts == 1 and parts[1].label == "quad-ultra micro-laser",
    "a placement that named tier four got tier four")
assert(parts[1].value == "tier 4 · 3.00", "worth three plain lasers: " .. parts[1].value)
t.ui_act(p, "set", '{"field":"temperature","value":400}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
t.ui_close(p)

-- ...and the one nobody upgraded, which is what a placement that says
-- nothing gets: the lowest rung the pack ships.
walk("west", 1)
local plain_beaker = t.target_at(2, 2, "beaker.libital")
take(2, 2, "beaker.libital")
t.click(p, 2, 1, t.target_at(2, 1))
t.run_ticks(2)
t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
parts = rows_in(t.ui(p), "parts")
assert(#parts == 1 and parts[1].label == "micro-laser",
    "silence in a placement is the plain rung")
assert(parts[1].value == "tier 1 · 1.00", "and the neutral part: " .. parts[1].value)
assert(row(t.ui(p), "vessel").value == "beaker (libital)", "with a beaker in it")
t.ui_act(p, "set", '{"field":"temperature","value":400}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
t.ui_close(p)

-- ---------------------------------------------------------------
-- THREE: AND THE BEAKERS AGREE WITH THE PANELS.
--
-- Three chambers, three identical beakers, one dial and one stretch of
-- time. What a spec can pin about tg's rate law is the ORDER -- it
-- closes a fraction of the remaining gap every pass, so a bigger
-- coefficient is always further along and never overshoots
-- (chem_heater.dm:172) -- which is exactly the claim the sockets make.
-- ---------------------------------------------------------------
t.run_seconds(30)
local plain = t.holder_k(plain_beaker)
local middle = t.holder_k(warm_beaker)
local best = t.holder_k(best_beaker)
assert(plain < middle,
    "a rung three laser beats the plain one: " .. plain .. " vs " .. middle)
assert(middle < best,
    "and rung four beats rung three: " .. middle .. " vs " .. best)
assert(best <= 400.0 + 1e-9, "none of them crosses the dial: " .. best)

-- ---------------------------------------------------------------
-- FOUR: A VARIANT IS A MACHINE SOMEBODY ALREADY UPGRADED.
--
-- tg's `/fullupgrade` boards stock a frame with tier fours
-- (machine_circuitboards.dm:765-773). There is no lathe here to print
-- one, so the upgraded unit is a preconfiguration a map places -- and
-- what it buys is the whole of tg's `RefreshParts` arithmetic: fifteen
-- kelvin off the cold end per point of laser and a hundred and forty
-- onto the hot one (thermomachine.dm:34, :95-96).
-- ---------------------------------------------------------------
walk("east", 7)
t.click(p, 9, 1, t.target_at(9, 1))
t.tick()
ui = t.ui(p)
local dial = ui.setpoints[1]
assert(dial.field == "temperature", "a temperature control unit wears a thermostat")
assert(math.abs(dial.min - 73.15) < 1e-6,
    "two plain lasers are tg's own cold end: " .. dial.min)
assert(math.abs(dial.max - 573.15) < 1e-6,
    "and tg's own hot end: " .. dial.max)
assert(#rows_in(ui, "parts") == 4, "four sockets: two bins and two lasers")
t.ui_close(p)

walk("east", 1)
t.click(p, 10, 1, t.target_at(10, 1))
t.tick()
ui = t.ui(p)
local upgraded = ui.setpoints[1]
assert(upgraded.min < dial.min - 50.0,
    "the upgraded unit reaches far colder: " .. upgraded.min .. " vs " .. dial.min)
assert(upgraded.max > dial.max + 500.0,
    "and far hotter: " .. upgraded.max .. " vs " .. dial.max)
local four = rows_in(ui, "parts")
assert(#four == 4, "still four sockets")
for _, r in ipairs(four) do
    assert(r.value == "tier 4 · 3.00", "every one of them is a tier four: " .. r.value)
end
