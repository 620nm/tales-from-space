-- `reactive = false` is a vessel that will not run a recipe.
--
-- The cryostasis beaker is tg's "no reactions" beaker (_cup.dm:529:
-- `reagent_flags = OPENCONTAINER | NO_REACT`), the one a chemist
-- carries two legs of a recipe around in without the recipe happening
-- on the way. The engine's half is one bit on the prototype
-- (docs/CONTENT-SCHEMA.md `reactive`); this proves the bit does what
-- it says by running the same two presses into an ordinary beaker
-- beside it. Lube is the recipe because it refuses at neither end:
-- no gate, no heat (chem_reactions_test.luau, four).
local WET = 0.15
local SAND = 0.1
local PRESS = 0.75

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function amount(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0
end

t.world([==[(
    name: "cold bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#.g.#",
        "#o..#",
        "#a..#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [
        (1, 2, "beaker_cryostasis"),
        (3, 2, "beaker"),
    ],
    machines: [(1, 1, "chem_dispenser")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
        (1, 3, 3), (2, 3, 3), (3, 3, 3),
    ],
)]==], 0)

local p = t.join()
t.tick()

local dispenser = t.target_at(1, 1)
local cold = t.target_at(1, 2, "beaker_cryostasis")
local warm = t.target_at(3, 2, "beaker")

local function take(handle, x, y)
    t.click(p, x, y, handle)
    t.tick()
end

local function press(key)
    t.ui_act(p, "toggle", '{"field":"dispense","option":"' .. key .. '"}')
    t.run_ticks(2)
end

local function dial_to(moles)
    t.ui_act(p, "set", '{"field":"amount","value":' .. moles .. '}')
    t.run_ticks(2)
end

-- Dock a vessel, press both legs into it, take it back and set it on
-- the deck: the same six gestures for both beakers.
local function charge(handle, x, y, id)
    take(handle, x, y)
    t.click(p, 1, 1, dispenser)
    t.tick()
    assert(t.hands(p).held == nil, id .. " went into the machine")
    t.click(p, 1, 1, dispenser)
    t.tick()
    dial_to(WET)
    press("water")
    dial_to(SAND)
    press("silicon")
    dial_to(PRESS)
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
    assert(t.hands(p).held == id, id .. " came back out")
    t.drop(p)
    t.tick()
end

charge(warm, 3, 2, "beaker")
charge(cold, 1, 2, "beaker_cryostasis")

t.run_seconds(300)

-- The ordinary beaker ran the recipe to its end...
near(amount(warm, "lube"), 2.0 * SAND, 1e-5, "two of lube for one of silicon")
near(amount(warm, "silicon"), 0.0, 1e-5, "and spent the silicon")
-- ...and the cryostasis beaker, standing beside it with the same two
-- legs in it, did nothing at all. The silicon is exact; the water is
-- bounded, because an open vessel breathes with the room for five
-- minutes and a run would have taken a whole SAND of it.
near(amount(cold, "lube"), 0.0, 1e-12, "no lube in a vessel that will not react")
assert(amount(cold, "water") > WET - SAND / 2,
    "the water is still standing: " .. amount(cold, "water"))
near(amount(cold, "silicon"), SAND, 1e-9, "and every mole of silicon")
