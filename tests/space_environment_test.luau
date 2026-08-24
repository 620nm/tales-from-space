-- Where the station is parked, and who decides it.
--
-- The engine owns the arithmetic -- a hull radiates sigma*(T^4 - Tsink^4)
-- out and absorbs S/2 in, over whatever area its decks present to the
-- sky (docs/MATTER.md §9 step 5d). It owns none of the numbers. Which
-- skies a round may be parked under, how likely each one is and what it
-- is called are all in the game mode file, and a shift rolls one of
-- them off the seeded world RNG at boot (docs/GAMEMODES.md).
--
-- So this file asserts three things and nothing else: the roll comes
-- off the shipped roster, the same seed lands in the same place, and a
-- mode with one entry on its roster gets that entry every time.
--
-- `t.environment()` is the same table `sim.environment()` hands content,
-- so a mod asking where it is gets exactly what is checked here.

local TCMB = 2.7

local MAP = [==[(
    name: "somewhere",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "###",
        "#.#",
        "###",
    ],
    spawns: [(1, 1)],
)]==]

-- The station's roster, verbatim from content/gamemodes/space_station.
-- Written out rather than read, because the point of the assertion is
-- that the engine reported what the FILE says.
local ROSTER = {
    dead_space = 0.0,
    orbit = 1361.0,
    sunward = 2700.0,
}

-- ---------------------------------------------------------------
-- THE DEFAULT MODE ROLLS ONE OF ITS OWN THREE SKIES.
-- ---------------------------------------------------------------
t.world(MAP, 7)
local sky = t.environment()
assert(ROSTER[sky.id] ~= nil, "the roll is one of the roster's own: " .. sky.id)
assert(
    sky.insolation == ROSTER[sky.id],
    sky.id .. " arrives with the sunlight the mode file gave it: " .. sky.insolation
)
assert(sky.sink_k == TCMB, "and the sink is the microwave background: " .. sky.sink_k)
assert(#sky.name > 0, "a sky has something to call it: " .. tostring(sky.name))

-- ---------------------------------------------------------------
-- ONE SEED, ONE SKY -- AND DIFFERENT SEEDS REALLY DO DIFFER.
--
-- The first half is the replay road: everything about a shift follows
-- from its seed, weather included. The second half is what stops that
-- from being satisfied by a constant -- a roll that ignored the roster
-- and always answered "dead space" would pass the first assertion
-- forever.
-- ---------------------------------------------------------------
t.world(MAP, 7)
assert(t.environment().id == sky.id, "the same seed is parked in the same place")
assert(t.environment().insolation == sky.insolation, "with the same star, or none")

local seen = {}
local distinct = 0
for seed = 1, 40 do
    t.world(MAP, seed)
    local id = t.environment().id
    assert(ROSTER[id] ~= nil, "every seed lands on the roster: " .. id)
    if not seen[id] then
        seen[id] = true
        distinct = distinct + 1
    end
end
assert(distinct > 1, "and forty shifts are not all parked in the same place")

-- ---------------------------------------------------------------
-- A MODE WITH ONE SKY GETS THAT SKY.
--
-- Free Build's roster has a single entry on purpose: a sandbox that
-- came out sunward some days and not others would make every
-- temperature reading in it a question about the weather. A one-entry
-- roster is still rolled -- there is no special case for it -- it just
-- cannot land anywhere else.
-- ---------------------------------------------------------------
for seed = 1, 5 do
    t.world(MAP, seed, "free_build")
    local sandbox = t.environment()
    assert(sandbox.id == "dead_space", "the sandbox is in dead space: " .. sandbox.id)
    assert(sandbox.insolation == 0.0, "with no star on it: " .. sandbox.insolation)
    assert(sandbox.sink_k == TCMB, "and the same cold sky: " .. sandbox.sink_k)
end
