-- The lab shelf is content, while closure and ranged parcel travel are
-- native mechanisms. This spec pins the shipped shells and exercises the
-- player gestures that cross that boundary.
t.world([==[(
    name: "chemical containers",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(2, 1)],
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
)]==], 19)

local p = t.join()
t.tick()

local function near(got, want, what)
    assert(math.abs(got - want) < 1e-8,
        ("%s: wanted %g, got %g"):format(what, want, got))
end

local shells = {
    { 1, 2, "beaker_large", 0.100 },
    { 2, 2, "beaker_plastic", 0.120 },
    { 3, 2, "beaker_metamaterial", 0.180 },
    { 4, 2, "beaker_cryostasis", 0.050 },
    { 5, 2, "beaker_bluespace", 0.300 },
    { 1, 1, "water_bottle", 0.050 },
    { 4, 1, "water_bottle_large", 0.100 },
    { 3, 1, "spray_bottle", 0.250 },
}
for _, row in ipairs(shells) do
    local vessel = t.vessel(t.target_at(row[1], row[2], row[3]))
    assert(vessel ~= nil, row[3] .. " has an inside")
    near(vessel.volume_l, row[4], row[3] .. " keeps tg's shell size")
end

local small = t.target_at(1, 1, "water_bottle")
local small_contents = t.contents(small)
near(small_contents.water, 1.2375, "the small bottle carries 49.5 u water")
near(small_contents.fluorine, 0.0125, "the small bottle carries 0.5 u fluorine")
near(t.contents(t.target_at(4, 1, "water_bottle_large")).water, 2.5,
    "the large bottle carries 100 u water")
assert(next(t.contents(t.target_at(1, 3, "water_bottle.empty"))) == nil,
    "the small empty form is empty")
assert(next(t.contents(t.target_at(2, 3, "water_bottle_large.empty"))) == nil,
    "the large empty form is empty")

t.click(p, 1, 1, small)
t.tick()
assert(t.vessel(small).sealed, "the filled bottle starts capped")
t.use_self(p)
t.tick()
assert(not t.vessel(small).sealed, "self-use opens the cap")
t.use_self(p)
t.tick()
assert(t.vessel(small).sealed, "a resealable bottle closes again")
assert(#t.ledger_rows("Unsealed") == 1 and #t.ledger_rows("Sealed") == 1,
    "both closure transitions are attributed")

t.drop(p)
t.tick()
local spray = t.target_at(3, 1, "spray_bottle")
t.click(p, 3, 1, spray)
t.tick()
assert(#t.sounds(p) == 0, "picking up the empty sprayer is silent")
t.click(p, 6, 1)
t.tick()
assert(#t.sounds(p) == 0, "an empty sprayer emits no launch sound")
assert(#t.ledger_rows("MatterSprayed") == 0, "an empty sprayer launches nothing")
t.move(p, "east")
t.tick()
local reservoir = t.target_at(4, 1, "water_bottle_large")
t.click(p, 4, 1, reservoir)
t.tick()
near(t.contents(spray).water, 1.25, "an adjacent refill takes 50 u")
assert(#t.sounds(p) == 0, "refilling emits no launch sound")

local before = t.matter_totals()
t.click(p, 6, 1)
t.tick()
local launched = t.sounds(p)
assert(#launched == 1 and launched[1] == "spray",
    "an accepted launch emits its declared sound once")
t.click(p, 6, 1)
t.tick()
assert(#t.sounds(p) == 0, "a cooldown refusal emits no launch sound")
assert(#t.ledger_rows("MatterSprayed") == 1, "cooldown refuses a second launch")
t.run_ticks(20)
near(t.contents(spray).water, 1.125, "one spray draws a 5 u parcel")
assert(#t.ledger_rows("MatterSprayed") == 1, "one launch is on the ledger")
local after = t.matter_totals()
near(after.moles, before.moles, "spray travel conserves matter")
assert(math.abs(after.energy_j - before.energy_j) < 1e-4,
    "spray travel conserves energy")
