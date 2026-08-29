-- IDENTITY: chlorine, and the door that is not there any more.
--
-- THE ACCIDENT ITSELF IS vapors_test.luau, in full: a press of the
-- dispenser, a bottle tipped onto the deck, a closet that fills with
-- gas, a crewman without a mask who takes the hook's damage and one
-- with a tank who does not, and a scrubber pointed at `chlorine` that
-- takes it out of the air and puts it in the waste main. Nothing here
-- repeats any of that.
--
-- What this file adds is the two things the identity milestone needs
-- and that file does not say: that the LIQUID in the bottle and the
-- GAS in the room are the same registry row reached by state, and that
-- the books close across the whole trip.
--
-- There used to be a door. `chlorine` was a reagent you kept in a
-- beaker and `cl2` was a gas that lived in the air, and the way to get
-- from one to the other was a fictional reaction with a 420 K window
-- -- so gassing a room meant HEATING a beaker until the recipe fired,
-- and a scrubber could never be pointed at what a chemist made. There
-- is no door now. `chlorine` IS Cl2; the dispenser hands it over as
-- the liquid a pressurised bottle holds, because that is what Cl2 is
-- under 6.6 atmospheres of its own vapour at room temperature; and a
-- tile at 293 K is a hundred kelvin over its boiling point, so what
-- lands on the deck is gas before anybody looks down. A phase is
-- something a substance REACHES.
--
-- The books are the second half and they are what a translator could
-- never have passed: with two ids, the moles that left the beaker and
-- the moles that arrived in the air were two different columns, and
-- nothing could add them up. Here they are one column, and it does not
-- move.

local PRESS = 1.25

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function has_text(lines, needle)
    for _, line in ipairs(lines) do
        if string.find(line, needle, 1, true) ~= nil then
            return true
        end
    end
    return false
end

t.world([==[(
    name: "fume closet",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "######",
        "#o.a.#",
        "#....#",
        "#...g#",
        "######",
    ],
    spawns: [(2, 2)],
    items: [(2, 3, "bottle"), (3, 3, "oxygen_tank")],
    machines: [(1, 2, "chem_dispenser")],
    cables: [
        (1, 1, 1, 0, 2), (1, 1, 1, 0, 4), (1, 1, 2, 0, 2), (1, 1, 2, 0, 4),
        (2, 1, 1, 0, 2), (2, 1, 1, 0, 4), (2, 1, 1, 0, 8), (2, 1, 2, 0, 2),
        (2, 1, 2, 0, 4), (2, 1, 2, 0, 8), (3, 1, 1, 0, 2), (3, 1, 1, 0, 4),
        (3, 1, 1, 0, 8), (3, 1, 2, 0, 2), (3, 1, 2, 0, 4), (3, 1, 2, 0, 8),
        (4, 1, 1, 2, 8), (4, 1, 2, 2, 8),
        (1, 2, 1, 0, 1), (1, 2, 1, 0, 2), (1, 2, 1, 0, 4), (1, 2, 2, 0, 1),
        (1, 2, 2, 0, 2), (1, 2, 2, 0, 4), (2, 2, 1, 0, 1), (2, 2, 1, 0, 2),
        (2, 2, 1, 0, 4), (2, 2, 1, 0, 8), (2, 2, 2, 0, 1), (2, 2, 2, 0, 2),
        (2, 2, 2, 0, 4), (2, 2, 2, 0, 8), (3, 2, 1, 0, 1), (3, 2, 1, 0, 2),
        (3, 2, 1, 0, 4), (3, 2, 1, 0, 8), (3, 2, 2, 0, 1), (3, 2, 2, 0, 2),
        (3, 2, 2, 0, 4), (3, 2, 2, 0, 8), (4, 2, 1, 0, 1), (4, 2, 1, 0, 2),
        (4, 2, 1, 0, 8), (4, 2, 2, 0, 1), (4, 2, 2, 0, 2), (4, 2, 2, 0, 8),
        (1, 3, 1, 1, 4), (1, 3, 2, 1, 4), (2, 3, 1, 0, 1), (2, 3, 1, 0, 4),
        (2, 3, 1, 0, 8), (2, 3, 2, 0, 1), (2, 3, 2, 0, 4), (2, 3, 2, 0, 8),
        (3, 3, 1, 0, 1), (3, 3, 1, 0, 4), (3, 3, 1, 0, 8), (3, 3, 2, 0, 1),
        (3, 3, 2, 0, 4), (3, 3, 2, 0, 8), (4, 3, 1, 0, 1), (4, 3, 1, 0, 8),
        (4, 3, 2, 0, 1), (4, 3, 2, 0, 8),
    ],
)]==], 0)

t.set_environment({ sink_k = 293.15, insolation = 0.0 })
local chemist = t.join("engineer")
t.tick()

local dispenser = t.target_at(1, 2)
local jar = t.target_at(2, 3, "bottle")
assert(dispenser ~= nil and jar ~= nil, "the bench is set")

local ROOM = {}
for x = 1, 4 do
    for y = 1, 3 do
        ROOM[#ROOM + 1] = { x, y }
    end
end

local function room(key)
    local n = 0.0
    for _, tile in ipairs(ROOM) do
        local gases = t.room_gas(tile[1], tile[2])
        n = n + ((gases and gases[key]) or 0.0)
    end
    return n
end

-- ---------------------------------------------------------------
-- THE MASK GOES ON FIRST, and it is the books that need it rather
-- than the crewman.
--
-- `chlorine` authors `inhale = 0.9` (substances/chlorine.luau), so a
-- pair of unprotected lungs in this closet KEEPS nine tenths of every
-- breath and the liver spends it -- and matter a body metabolizes is
-- matter that leaves the world (sim/annihilate.rs). That is correct
-- physics and it is also a hole in any conservation sum taken across
-- it. A tank's contents carry no `inhale`, so a crewman on internals
-- keeps nothing of what is in the room (sim/breathing.rs,
-- `absorb_breath`) -- which is tg parity, and here it is also what
-- makes the closing sum below mean something.
-- ---------------------------------------------------------------
assert(t.worn(chemist).mask == "breath_mask", "the shift starts with apparatus on")
t.click(chemist, 3, 3, t.target_at(3, 3, "oxygen_tank"))
t.run_ticks(2)
assert(t.hands(chemist).held == "oxygen_tank", "the tank is in hand")
t.use_self(chemist)
t.run_ticks(2)
assert(t.vitals(chemist) ~= nil and t.vitals(chemist).tank ~= nil, "the valve is open")
-- The bottle goes in the OTHER hand: an open valve is a tank still
-- held, and letting go of it shuts it (internals_test.luau).
t.swap_hands(chemist)
t.run_ticks(2)

-- ---------------------------------------------------------------
-- ONE: A BOTTLE OF LIQUID CHLORINE.
-- ---------------------------------------------------------------
t.click(chemist, 2, 3, jar)
t.run_ticks(2)
assert(t.hands(chemist).held == "bottle", "and the bottle in the working one")
t.click(chemist, 1, 2, dispenser)
t.tick()
t.click(chemist, 1, 2, dispenser)
t.tick()
t.ui_act(chemist, "set", '{"field":"amount","value":' .. PRESS .. '}')
t.run_ticks(2)
t.ui_act(chemist, "toggle", '{"field":"dispense","option":"chlorine"}')
-- The press lands in one pass; the sweep takes a few more to walk the
-- superheat down onto the saturation line.
t.run_seconds(10)
t.ui_act(chemist, "toggle", '{"field":"eject"}')
t.run_ticks(2)
assert(t.hands(chemist).held == "bottle", "the vessel comes back out")

local inside = t.vessel(jar)
near(inside.contents.chlorine.liquid + (inside.contents.chlorine.gas or 0.0), PRESS, 1e-9,
    "the whole press landed, because there is a lid")
assert(inside.contents.chlorine.liquid > 0.5 * PRESS,
    "and most of it is standing as LIQUID: " .. inside.contents.chlorine.liquid .. " mol")
assert(inside.pressure_kpa > 400.0,
    "under several atmospheres of its own vapour: " .. inside.pressure_kpa .. " kPa")

-- The examine pane names it out of the registry (sim/examine.rs,
-- `matter_lines`), and there is one name because there is one row.
local look = t.examine_held(chemist)
assert(look ~= nil, "a crewman can look at what is in their hand")
assert(has_text(look.lines, "chlorine"), "and it is chlorine: " .. table.concat(look.lines, " / "))

-- ---------------------------------------------------------------
-- TWO: TIP IT OUT, AND IT IS GAS.
--
-- No recipe, no window, no heat. The tip takes the condensed phases
-- onto the deck (items/bottle.luau) and the deck is a hundred kelvin
-- over chlorine's 239.1 K boiling point, so the phase step turns it
-- over where it lands.
-- ---------------------------------------------------------------
near(room("chlorine"), 0.0, 1e-12, "the closet is clean to start with")
local booked = t.matter_totals()
near(booked.substances.chlorine, PRESS, 1e-9,
    "and the books hold exactly the press: " .. booked.substances.chlorine .. " mol")

t.click(chemist, 3, 2)
t.run_seconds(20)

local loose = room("chlorine")
assert(loose > 0.5 * PRESS, "it boiled off into the room: " .. loose .. " mol")
near(t.contents(jar).chlorine or 0.0, PRESS - loose, 1e-6,
    "and what is left in the bottle is the saturated vapour it kept")

-- ---------------------------------------------------------------
-- THREE: THE BOOKS CLOSE.
--
-- One column, across a mint, a lid, a condensation, a transfer, a
-- flash and twelve tiles of room. Two ids could not have been added
-- up at all.
-- ---------------------------------------------------------------
t.run_seconds(60)
local closed = t.matter_totals()
near(closed.substances.chlorine, PRESS, 1e-9,
    "not one mole of it was made or lost: " .. closed.substances.chlorine)
near(closed.moles, booked.moles, 1e-9, "nor of anything else in the closet")
