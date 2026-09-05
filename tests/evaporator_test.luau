-- The evaporator: the same machine with no allow-list on its mouth, so
-- whatever boils in the glass goes down the line — and comes back off
-- it, which is the half Baystation12's own machine cannot do.
--
-- Bay's machine merges its produce INTO `air_contents` and never
-- draws from it
-- (`Baystation12/code/modules/reagents/Chemistry-Sublimator.dm:156`).
-- Here the vessel and the run are one body of matter split by volume
-- every atmos pass (../lunatic/docs/ATMOS.md §9), so both directions
-- are the same sentence and neither is a feature of its own.
--
-- `steam_generator_test.luau` is the sieved twin. What is here is the
-- unsieved machine, the ledger row a dock writes, and what a crewman
-- gets back when they take their beaker out again.

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function row(ui, label)
    for _, r in ipairs(ui.readouts) do
        if word(r.label) == label then
            return r
        end
    end
    return nil
end

local function pipe_of(x, y, which)
    local held = t.pipe_gas(x, y)
    return held and held[which] or 0.0
end

local function held_in(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0.0
end

t.world([==[(
    name: "evaporator bench",
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
        "#...ag#",
        "#######",
    ],
    spawns: [(3, 1)],
    items: [(3, 1, "beaker.ethanol")],
    pipes: [(2, 1, 4), (3, 1, 4)],
    structures: [(4, 1, "evaporator", { "pipe": "west" })],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

assert(t.structure_at(4, 1).id == "evaporator", "the map stood one there")
local machine = t.target_at(4, 1, "evaporator")

-- ---------------------------------------------------------------
-- ANYTHING THAT BOILS, NOT JUST WATER.
--
-- Ethanol is the substance the steam generator refuses, which is the
-- point of running the same gesture on this machine: the sieve is the
-- only difference between the two files.
-- ---------------------------------------------------------------
local booze = t.target_at(3, 1, "beaker.ethanol")
t.click(p, 3, 1, booze)
t.tick()
t.click(p, 4, 1, machine)
t.tick()
assert(t.hands(p).held == nil, "the beaker is in the machine")
assert(t.ledger_has("Docked", "beaker"), "and the dock is on the record")

local charged = held_in(booze, "ethanol")
assert(charged > 0.5, "with what it shipped with: " .. charged)

t.click(p, 4, 1, machine)
t.tick()
local ui = t.ui(p)
assert(row(ui, "dock.vessel").value.text == "beaker (ethanol)", "the panel names what is in it")
near(ui.setpoints[1].value, 373.15, 1e-9, "and its dial opens at water's boil")

t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
t.run_seconds(30)
local crossed = pipe_of(3, 1, "ethanol")
assert(crossed > 1e-4, "thirty seconds and nothing crossed: " .. crossed)
near(
    crossed + held_in(booze, "ethanol"),
    charged,
    1e-6,
    "and every mole of it is still on the books"
)

-- ---------------------------------------------------------------
-- AND YOU GET THE BEAKER BACK, WITH WHAT IS LEFT IN IT.
--
-- Bay has no eject button at all — it hangs a verb on the machine when
-- something is loaded (`:53`, `:76-95`). One button here, the same one
-- every dock in the bench family wears.
-- ---------------------------------------------------------------
local left = held_in(booze, "ethanol")
assert(left > 0.0, "the test is only interesting with some left: " .. left)
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
assert(t.hands(p).held == "beaker.ethanol", "the eject button hands it back")
assert(t.ledger_has("Undocked", "beaker"), "and the undock is on the record too")
near(held_in(booze, "ethanol"), left, 1e-6, "carrying exactly what was left in it")
assert(row(t.ui(p), "dock.vessel").value.id == "dock.vessel.empty", "the panel agrees the slot is bare")

-- ...and an empty dock has no reservoir behind its mouth, so the line
-- keeps what it was given and nothing else arrives.
local parked = pipe_of(3, 1, "ethanol")
t.run_seconds(20)
near(pipe_of(3, 1, "ethanol"), parked, 1e-6, "an empty machine moves nothing")
