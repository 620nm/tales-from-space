-- What a placard says about a room, and what it refuses to say about
-- an ordinary one.
--
-- Every substance on the shelf declares three 0..4 scales and at most
-- one special word (docs/chemistry/substances.md, `hazard`); the engine
-- takes the worst of each scale over whatever is thick enough to count
-- (docs/matter/hazard.md). The whole design rests on one negative: a
-- corridor full of breathable air must rate NOTHING, or a diamond on
-- every wall of the station means nothing anywhere.
--
-- That negative is bought with the thresholds in the two files it is
-- about. Oxygen is an oxidiser only past 23.5% and nitrogen an
-- asphyxiant only past 85%, and station air is 21/79 -- so it clears
-- neither, by margins a mapper could not accidentally cross.
--
-- The positive half is plasma: the one substance the station is built
-- to keep away from itself, and the one a sign has to shout about.

local function zeroes(what, summary)
    assert(summary.health == 0, what .. ": health 0")
    assert(summary.fire == 0, what .. ": fire 0")
    assert(summary.instability == 0, what .. ": instability 0")
    assert(#summary.specials == 0, what .. ": no special symbol")
end

t.world([==[(
    name: "placard",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "###",
        "#.#",
        "###",
    ],
    spawns: [(1, 1)],
)]==], 0)

t.join()
t.tick()

-- The air a station is commissioned full of (content/air/standard_air.luau).
zeroes("station air", t.hazard({ o2 = 21.0, n2 = 79.0 }))

-- And the same mixture at any amount: a placard reads a RATIO.
zeroes("a canister of it", t.hazard({ o2 = 3741.6 * 0.21, n2 = 3741.6 * 0.79 }))

-- An empty reading is not a hazard either.
zeroes("vacuum", t.hazard({}))

-- Push the oxygen past 23.5% of the same room and the diamond speaks.
local rich = t.hazard({ o2 = 30.0, n2 = 70.0 })
assert(rich.specials[1] == "oxidizer", "an oxygen-rich room is marked OX")

-- Plasma is why the sign exists.
local burning = t.hazard({ plasma = 40.0, o2 = 21.0, n2 = 39.0 })
assert(burning.fire >= 3, "a plasma-rich room rates fire " .. burning.fire)
assert(burning.health >= 3, "and it is a poison to breathe")
assert(burning.specials[1] == "skull", "plasma, being thickest, leads the symbols")

-- A trace of it does NOT stop being a fire risk: plasma's threshold is
-- the default, because a little of it in a room is still the thing that
-- burns. This is the deliberate opposite of the two air gases.
local trace = t.hazard({ plasma = 0.1, o2 = 21.0, n2 = 79.0 })
assert(trace.fire >= 3, "any plasma at all is a fire rating")
