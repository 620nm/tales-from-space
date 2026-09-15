local composition = require("@helpers/composition")

-- The lab shelf is content, while closure and ranged parcel travel are
-- native mechanisms. This spec pins the shipped shells and exercises the
-- player gestures that cross that boundary.
t.world(
    [==[(
    name: "chemical containers",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "#......#",
        "########",
    ],
    structures: [(2, 1, "player_spawn")],
    items: [
        (1, 1, "water_bottle"),
        (3, 1, "spray_bottle"),
        (4, 1, "water_bottle_large"),
        (1, 2, "beaker_large"),
        (2, 2, "beaker_plastic"),
        (3, 2, "beaker_metamaterial"),
        (4, 2, "beaker_cryostasis"),
        (5, 2, "beaker_bluespace"),
        (1, 3, "water_bottle.empty"),
        (2, 3, "water_bottle_large.empty"),
    ],
)]==],
    19
)

local p = t.join()
t.tick()

local function near(got: number, want: number, what: string)
    assert(math.abs(got - want) < 1e-8, ("%s: wanted %g, got %g"):format(what, want, got))
end

local shells = {
    { x = 1, y = 2, id = "beaker_large", litres = 0.100 },
    { x = 2, y = 2, id = "beaker_plastic", litres = 0.120 },
    { x = 3, y = 2, id = "beaker_metamaterial", litres = 0.180 },
    { x = 4, y = 2, id = "beaker_cryostasis", litres = 0.050 },
    { x = 5, y = 2, id = "beaker_bluespace", litres = 0.300 },
    { x = 1, y = 1, id = "water_bottle", litres = 0.050 },
    { x = 4, y = 1, id = "water_bottle_large", litres = 0.100 },
    { x = 3, y = 1, id = "spray_bottle", litres = 0.250 },
}
for _, shell in ipairs(shells) do
    local vessel = assert(t.vessel(assert(t.target_at(p, shell.x, shell.y, shell.id))))
    assert(vessel ~= nil, shell.id .. " has an inside")
    near(vessel.volume_l, shell.litres, shell.id .. " keeps tg's shell size")
end

local small = assert(t.target_at(p, 1, 1, "water_bottle"))
local small_contents = assert(t.contents(small))
near(small_contents.water, 1.2375, "the small bottle carries 49.5 u water")
near(small_contents.fluorine, 0.0125, "the small bottle carries 0.5 u fluorine")
near(
    assert(t.contents(assert(t.target_at(p, 4, 1, "water_bottle_large")))).water,
    2.5,
    "the large bottle carries 100 u water"
)
assert(
    next(assert(t.contents(assert(t.target_at(p, 1, 3, "water_bottle.empty"))))) == nil,
    "the small empty form is empty"
)
assert(
    next(assert(t.contents(assert(t.target_at(p, 2, 3, "water_bottle_large.empty"))))) == nil,
    "the large empty form is empty"
)

t.click(p, 1, 1, assert(t.target_at(p, 1, 1, small)))
t.tick()
assert(assert(t.vessel(small)).sealed, "the filled bottle starts capped")
t.use_self(p)
t.tick()
assert(not assert(t.vessel(small)).sealed, "self-use opens the cap")
t.use_self(p)
t.tick()
assert(assert(t.vessel(small)).sealed, "a resealable bottle closes again")
assert(
    #t.ledger_rows("Unsealed") == 1 and #t.ledger_rows("Sealed") == 1,
    "both closure transitions are attributed"
)

t.drop(p)
t.tick()
local spray = assert(t.target_at(p, 3, 1, "spray_bottle"))
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, spray)))
t.tick()
assert(#t.sounds(p) == 0, "picking up the empty sprayer is silent")
composition.click_deck(p, 6, 1)
t.tick()
assert(#t.sounds(p) == 0, "an empty sprayer emits no launch sound")
assert(#t.ledger_rows("MatterSprayed") == 0, "an empty sprayer launches nothing")
-- A ranged claim costs its click window whether or not anything came
-- of it (CLICK_CD_RANGE * 2, sixteen ticks): let it pass before the
-- next one.
t.run_ticks(16)
t.move(p, "east")
t.tick()

-- A capped bottle is not a source. tg refills a sprayer only from
-- something drainable (spray.dm:52), and nothing is drawn through a
-- lid: the sprayer stays empty and the bottle keeps its water.
local reservoir = assert(t.target_at(p, 4, 1, "water_bottle_large"))
assert(assert(t.vessel(reservoir)).sealed, "the large bottle starts capped")
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, reservoir)))
t.tick()
assert(next(assert(t.contents(spray))) == nil, "a sealed source refills nothing")
near(assert(t.contents(reservoir)).water, 2.5, "and loses nothing")
assert(#t.ledger_rows("MatterMoved") == 0, "no transfer is on the record")

-- Uncap it the way a player does -- put the sprayer down, open the
-- bottle in hand, set it down beside the sprayer, step back and pick
-- the sprayer up again -- and refill from arm's length.
t.drop(p)
t.tick()
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, reservoir)))
t.tick()
t.use_self(p)
t.tick()
assert(not assert(t.vessel(reservoir)).sealed, "self-use uncaps the reservoir")
t.drop(p)
t.tick()
t.move(p, "west")
t.tick()
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, spray)))
t.tick()
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, reservoir)))
t.tick()
near(assert(t.contents(spray)).water, 1.25, "an adjacent refill takes 50 u")
near(assert(t.contents(reservoir)).water, 1.25, "out of the open bottle")
assert(#t.sounds(p) == 0, "refilling emits no launch sound")

local before = t.matter_totals()
composition.click_deck(p, 6, 1)
t.tick()
local launched = t.sounds(p)
assert(
    #launched == 1 and launched[1] == "spray",
    "an accepted launch emits its declared sound once"
)
composition.click_deck(p, 6, 1)
t.tick()
assert(#t.sounds(p) == 0, "a cooldown refusal emits no launch sound")
assert(#t.ledger_rows("MatterSprayed") == 1, "cooldown refuses a second launch")
-- Read the draw before the parcel has travelled: an open sprayer also
-- breathes with the room once an atmos pass, and that trade is not
-- what this line is about.
near(assert(t.contents(spray)).water, 1.125, "one spray draws a 5 u parcel")
t.run_ticks(20)
assert(#t.ledger_rows("MatterSprayed") == 1, "one launch is on the ledger")
local after = t.matter_totals()
near(after.moles, before.moles, "spray travel conserves matter")
assert(math.abs(after.energy_j - before.energy_j) < 1e-4, "spray travel conserves energy")
