local composition = require("@helpers/composition")

-- An open vessel dipped into standing water comes up with tg's scoop of
-- whatever the water holds (code/datums/elements/reagent_scoopable_atom.dm:34,
-- `rand(5, 10)` units). A lake pays for it out of its own water; the sea
-- is a tile its ideal walks back (the engine's docs/matter-world/ideal.md).
--
-- Columns 0-1 are lake, 2 sand, 3-5 sea; the player stands on the sand.
t.world(
    [==[(
    name: "scoop",
    tags: ["terrestrial", "warm_outdoors"],
    environment: (kind: Exact(terrestrial)),
    legend: {
        'a': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'l': (outdoors: true, composition: (substrate: Named("ground"), material: Named("lake_water"), components: [])),
        'w': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sea_water"), components: [])),
    },
    levels: [
        (
            rows: [
                "llawww",
                "llawww",
                "llawww",
            ],
            structures: [(2, 1, "player_spawn")],
            items: [(2, 1, "beaker"), (2, 1, "water_bottle")],
        ),
    ],
)]==],
    0,
    "free_build"
)
t.set_breathing(false)

local U = 0.025 -- mol per tg unit (docs/CHEMISTRY.md 4)

local p = t.join()
t.tick()
local beaker = assert(t.target_at(p, 2, 1, "beaker"))
t.click(p, 2, 1, beaker)
t.tick()
assert(t.hands(p).held == "beaker", "the beaker is in hand")
t.messages(p)

local function water(): number
    return (assert(t.contents(beaker)).water or 0)
end

local function scoop_at(x: number): number
    local before = water()
    composition.click_deck(p, x, 1)
    t.tick()
    local lines = t.messages(p)
    assert(lines[#lines] == "You scoop water up in the beaker.", "the scoop is reported: " .. tostring(lines[#lines]))
    local dose = water() - before
    assert(dose >= 5 * U - 1e-6 and dose <= 10 * U + 1e-6, ("a scoop is 5-10 u, got %g mol"):format(dose))
    return dose
end

-- THE LAKE: no water was made to fill the beaker. The tolerance is a
-- hundredth of the dose, so a refill would show.
local before = t.matter_totals().substances.water
local dose = scoop_at(1)
local after = t.matter_totals().substances.water
assert(math.abs(after - before) < 0.01 * dose, ("the lake paid for the scoop: %.6f -> %.6f mol"):format(before, after))

-- THE SEA: the beaker gains the sea's water and nothing else.
local held = assert(t.contents(beaker))
scoop_at(3)
for key, moles in pairs(assert(t.contents(beaker))) do
    assert(key == "water" or moles <= (held[key] or 0) + 1e-9, "the sea holds only water, the beaker gained " .. key)
end

-- A FULL beaker takes no more: scoops trim to the brim, then refuse.
local refused = nil
for _ = 1, 80 do
    composition.click_deck(p, 1, 1)
    t.tick()
    local lines = t.messages(p)
    if lines[#lines] == "The beaker will hold no more." then
        refused = water()
        break
    end
end
assert(refused ~= nil, "a full beaker refuses the scoop")
composition.click_deck(p, 1, 1)
t.tick()
assert(math.abs(water() - refused) < 1e-9, "the refused scoop moved nothing")

-- A SEALED bottle is refused before it dips.
t.drop(p)
t.tick()
local bottle = assert(t.target_at(p, 2, 1, "water_bottle"))
t.click(p, 2, 1, bottle)
t.tick()
assert(t.hands(p).held == "water_bottle", "the bottle is in hand")
local sealed = assert(t.contents(bottle)).water or 0
t.messages(p)
composition.click_deck(p, 1, 1)
t.tick()
local lines = t.messages(p)
assert(lines[#lines] == "Open the bottle before scooping with it.", "the sealed bottle refuses: " .. tostring(lines[#lines]))
assert(math.abs((assert(t.contents(bottle)).water or 0) - sealed) < 1e-9, "the sealed bottle took nothing")
