-- WHAT A SOCKET IS WORTH IS THE PACK'S ANSWER, AND THE ROOM GETS A
-- VOTE UNTIL THE PARTS ARE GOOD ENOUGH TO OUTVOTE IT.
--
-- The reaction chamber declares an environment modifier -- a fifth of
-- a percent of itself per kelvin the room stands away from twenty
-- degrees (machines/chem_heater.luau) -- and its own script takes that
-- modifier away from a chamber whose laser is rung three or better
-- (fixtures/chem_heater.luau). The engine does the arithmetic; the
-- hook only ever answers with data, at the four moments a roster is
-- settled and never per tick (docs/LUAU-API.md, `parts.refresh`).
--
-- Four chambers and two rooms, because the claim is a DIFFERENCE and
-- one machine cannot show it. Two identical benches, one at twenty
-- degrees and one at fifty-seven, each carrying a plain chamber and an
-- upgraded one. The plain pair should disagree with each other and the
-- upgraded pair should not.
--
-- WHY THE HOT ROOM IS READ EARLY. Nothing in this pack heats a room and
-- holds it there: a map may open the shift with hot air, but the deck
-- under it is a hundred times the air's heat capacity and starts
-- drinking from the first pass (docs/MATTER-WORLD.md 3). So the panels
-- are read while the room is still hot and every claim below is made
-- against the THERMOMETER rather than against the preset -- which is
-- the honest form anyway, since the modifier reads the room and not
-- the map.
local T20C = 293.15

-- The prototype's own block (machines/chem_heater.luau), spelled once
-- here so the expected number is derived rather than copied.
local IDEAL_K = 293.15
local LOSS_PER_K = 0.002
local FLOOR = 0.2

local function expected_factor(room_k)
    return math.max(FLOOR, 1.0 - LOSS_PER_K * math.abs(room_k - IDEAL_K))
end

local function rows_in(ui, section)
    local out = {}
    for _, r in ipairs(ui.readouts) do
        if r.section == section then
            table.insert(out, r)
        end
    end
    return out
end

-- The one part row a chamber has: `{ label, value, tone }`, the value
-- being "tier N · E.EE" (sim/ui/settings/parts.rs).
local function socket(p, x, y)
    t.click(p, x, y, t.target_at(x, y))
    t.tick()
    local rows = rows_in(t.ui(p), "parts")
    assert(#rows == 1, "a chamber has one socket: got " .. #rows)
    t.ui_close(p)
    return rows[1]
end

local function worth(row)
    local tier, eff = row.value:match("^tier (%d+) · ([%d%.]+)$")
    assert(tier ~= nil, "the row reads as a rung and a worth: " .. row.value)
    return tonumber(tier), tonumber(eff)
end

-- Every "element" a chamber's script has written since the shift began,
-- newest last, keyed by the machine it was written about. The hook is a
-- transform and may not write; the `.done` half keeps this word, so a
-- row here IS the hook having run (fixtures/chem_heater.luau).
local function elements(machine)
    local out = {}
    for _, row in ipairs(t.ledger_rows("VarSet")) do
        if row.key == "lunatic/tfs:element" and row.entity == machine then
            table.insert(out, row.value)
        end
    end
    return out
end

-- Two sealed benches and a generator in its own closet -- the closet
-- because a running generator is a heat source and the west bench is
-- meant to be at exactly twenty degrees. Cable runs under the dividing
-- walls; a CORD does not (a cord's reach is a walk, power_pass.rs), so
-- each bench has an outlet of its own.
t.world([==[(
    name: "two benches",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "###############",
        "#o....#o....#g#",
        "#a....#.....#.#",
        "###############",
    ],
    spawns: [(3, 2), (9, 2)],
    machines: [
        (2, 1, "chem_heater"),
        (4, 1, "chem_heater", { "laser_1": "3" }),
        (8, 1, "chem_heater"),
        (10, 1, "chem_heater", { "laser_1": "3" }),
    ],
    items: [(3, 2, "part_replacer")],
    blends: {
        "sweltering": (rows: [("o2", 7.756), ("n2", 29.175)], temperature_k: 330.0, amount: per_tile),
    },
    painted: [
        (7, 1, "sweltering"), (8, 1, "sweltering"), (9, 1, "sweltering"),
        (10, 1, "sweltering"), (11, 1, "sweltering"),
        (7, 2, "sweltering"), (8, 2, "sweltering"), (9, 2, "sweltering"),
        (10, 2, "sweltering"), (11, 2, "sweltering"),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (7, 1, 3), (8, 1, 3), (9, 1, 3), (10, 1, 3), (11, 1, 3), (12, 1, 3),
        (13, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
        (7, 2, 3), (8, 2, 3), (9, 2, 3), (10, 2, 3), (11, 2, 3), (12, 2, 3),
        (13, 2, 3),
    ],
)]==], 0)

local west = t.join()
local east = t.join()
-- One atmos pass, because the environment multiplier is applied on the
-- pass and not on the tick (sim/tick.rs).
t.run_seconds(1)

local plain_cold = t.target_at(2, 1)
local upgraded_cold = t.target_at(4, 1)
local plain_hot = t.target_at(8, 1)
local upgraded_hot = t.target_at(10, 1)

-- ---------------------------------------------------------------
-- ONE: THE HOOK RAN BEFORE THE ROUND OPENED.
--
-- A map's machines are asked at boot, before the genesis row, so what
-- a mapped chamber is worth is part of the opening position rather
-- than something the first tick discovers.
-- ---------------------------------------------------------------
assert(elements(plain_cold)[1] == "exposed",
    "the plain chamber's element is out in the room")
assert(elements(upgraded_cold)[1] == "shielded",
    "and a rung three laser brings its own housing")
assert(#elements(plain_hot) == 1 and #elements(upgraded_hot) == 1,
    "each of the four was asked exactly once, at boot")

-- ---------------------------------------------------------------
-- TWO: AT TWENTY DEGREES THE MODIFIER IS NOTHING AT ALL.
--
-- Which is the point of writing it as a distance from an ideal rather
-- than as a penalty: a station kept at the temperature it was built
-- for pays nothing, and the number on the panel is the part's own.
-- ---------------------------------------------------------------
local cold_k = t.room_temperature(2, 1)
assert(math.abs(cold_k - T20C) < 0.5, "the west bench is at twenty degrees: " .. cold_k)

local row = socket(west, 2, 1)
assert(row.label == "micro-laser", "the plain part, by its own name: " .. row.label)
local tier, eff = worth(row)
assert(tier == 1 and math.abs(eff - 1.0) < 1e-9,
    "worth exactly what its file says: " .. row.value)
assert(row.tone == "idle", "a neutral part reads neutral: " .. tostring(row.tone))

row = socket(west, 4, 1)
assert(row.label == "ultra-high-power micro-laser", "the better part: " .. row.label)
tier, eff = worth(row)
assert(tier == 3 and math.abs(eff - 2.0) < 1e-9,
    "and the ladder's own 2.00 (lib/stock_parts.luau): " .. row.value)

-- ---------------------------------------------------------------
-- THREE: IN A HOT ROOM THE PLAIN CHAMBER IS WORSE, BY THE ROOM.
--
-- The engine's modifier is `max(floor, 1 - loss_per_k * |T - ideal|)`
-- applied once a tick to a machine whose prototype declared one, and
-- the panel's efficiency is the number the scaling law is actually
-- using -- so this row is the mechanism and not a second copy of it.
-- ---------------------------------------------------------------
local hot_k = t.room_temperature(8, 1)
assert(hot_k > T20C + 30.0, "the east bench opened sweltering: " .. hot_k)

row = socket(east, 8, 1)
tier, eff = worth(row)
assert(tier == 1, "the same plain part as the west bench")
assert(eff < 1.0, "and it is worth less here: " .. row.value)
assert(row.tone == "off", "which the panel says in its own three tones")
-- Slack of a hundredth, because the deck has been drinking the room's
-- heat since the first pass and the panel is a rounded printout: a
-- hundredth of efficiency is five kelvin of room, far more than the
-- couple of passes between the thermometer and the click.
assert(math.abs(eff - expected_factor(hot_k)) < 0.01,
    "and worth exactly the room's distance from ideal: "
        .. eff .. " vs " .. expected_factor(hot_k))

-- ---------------------------------------------------------------
-- FOUR: ...AND THE UPGRADED ONE IS NOT.
--
-- The hook took `environment.temperature` away, so there is no
-- modifier left to apply and the number is the part's file value to
-- the last digit -- the same 2.00 the west bench reads.
-- ---------------------------------------------------------------
row = socket(east, 10, 1)
tier, eff = worth(row)
assert(tier == 3 and math.abs(eff - 2.0) < 1e-9,
    "a shielded chamber does not care what the corridor is doing: " .. row.value)

-- ---------------------------------------------------------------
-- FIVE: ASKING AGAIN IS ASKING ONCE.
--
-- `sim.component.refresh` is the command half of the anchor, and the
-- exchanger is what calls it: tg refreshes a machine at the end of
-- every exchange whether or not a socket changed
-- (`_machinery.dm:1172`, the end of `exchange_parts`).
-- An EMPTY exchanger therefore buys a refresh and nothing else, which
-- is the cleanest way to ask a hook the same question twice.
--
-- The answer must be the same, and that is a claim about the ENGINE as
-- much as the handler: every refresh opens on the FILES rather than on
-- the last answer, so a handler that read its own output could not
-- drift a machine upward one swap at a time.
--
-- What proves the hook ran is the provenance row: a script that emits
-- anything is on the shift record under its own file, so a row naming
-- `fixtures/chem_heater.luau` at this tick, triggered by the crewman
-- who clicked, IS the chamber's handler having spoken.
-- ---------------------------------------------------------------
local function chamber_spoke()
    local n = 0
    for _, r in ipairs(t.ledger_rows("script_provenance")) do
        if r.actor.file == "fixtures/chem_heater.luau" then
            n += 1
        end
    end
    return n
end

t.click(west, 3, 2, t.target_at(3, 2, "part_replacer"))
t.run_ticks(2)
assert(t.hands(west).held == "part_replacer", "the exchanger is in hand, and empty")

local swaps_before = #t.ledger_rows("part_swapped")
local spoke_before = chamber_spoke()
local _ = t.messages(west)
t.click(west, 2, 1, t.target_at(2, 1))
t.run_ticks(2)

assert(#t.ledger_rows("part_swapped") == swaps_before, "an empty bag fits nothing")
assert(table.concat(t.messages(west), " | "):find("any better", 1, true) ~= nil,
    "and says so")
assert(chamber_spoke() == spoke_before + 1,
    "but the chamber was asked again all the same: "
        .. spoke_before .. " -> " .. chamber_spoke())

-- ...and answered what it answered before, which the record shows by
-- keeping no second row: an unchanged var is not a mutation, so the
-- one "exposed" written at boot is still the only one.
local asked = elements(plain_cold)
assert(#asked == 1 and asked[1] == "exposed",
    "the answer did not move, so neither did the record: " .. #asked)

-- The exchanger goes down first: a click with something in your hand
-- is that thing being used, and the panel is what a BARE hand opens.
t.drop(west)
t.run_ticks(2)
row = socket(west, 2, 1)
tier, eff = worth(row)
assert(tier == 1 and math.abs(eff - 1.0) < 1e-9,
    "and the panel reads exactly what it read the first time: " .. row.value)
