-- Where the station is parked, and who decides it.
--
-- The engine owns the arithmetic -- a hull radiates sigma*(T^4 - Tsink^4)
-- out and absorbs S/2 in, over whatever area its decks present to the
-- sky (docs/MATTER-WORLD.md §3 step 5d). It owns none of the numbers. Which
-- skies a round may be parked under, how likely each one is and what it
-- is called are all in the game mode file, and a shift rolls one of
-- them off the seeded world RNG at boot (docs/GAMEMODES.md).
--
-- So this file asserts that rolls come off the shipped roster, the same seed
-- lands in the same place, and map preferences filter the roster.
--
-- `t.environment()` is the same table `sim.environment()` hands content,
-- so a mod asking where it is gets exactly what is checked here.

local TCMB = 2.7
local STANDARD_GRAVITY = 9.80665

local MAP = [==[(
    name: "somewhere",
    // This is the pre-environment fixture: retain the walking assumptions
    // of the older test while the real map contract grows new choices.
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "###",
        "#.#",
        "###",
    ],
    structures: [(1, 1, "player_spawn")],
)]==]

-- A new map with no saved physical preference accepts every compatible
-- profile, including microgravity.
local UNRESTRICTED_MAP = [==[(
    name: "unrestricted",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "###",
        "#.#",
        "###",
    ],
    structures: [(1, 1, "player_spawn")],
)]==]

local TERRESTRIAL_MAP = UNRESTRICTED_MAP:gsub(
    'name: "unrestricted",',
    'name: "terrestrial", tags: ["terrestrial"],'
)

local ZERO_GRAVITY_MAP = [==[(
    name: "zero gravity",
    environment: (gravity_m_s2: Exact(0.0)),
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "###",
        "#.#",
        "###",
    ],
    structures: [(1, 1, "player_spawn")],
)]==]

local MICROGRAVITY_FILTER_MAP = [==[(
    name: "microgravity filter",
    environment: (
        gravity_m_s2: Range(min: Some(0.0), max: Some(0.1)),
        background: Exact(Some("space_backdrop")),
    ),
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "###",
        "#.#",
        "###",
    ],
    structures: [(1, 1, "player_spawn")],
)]==]

-- The station's roster, verbatim from content/gamemodes/space_station.
-- Written out rather than read, because the point of the assertion is
-- that the engine reported what the FILE says.
local ROSTER = {
    dead_space = 0.0,
    microgravity = 0.0,
    orbit = 1361.0,
    sunward = 2700.0,
}

-- ---------------------------------------------------------------
-- THE DEFAULT MODE ROLLS ONE OF ITS OWN FOUR SKIES.
-- ---------------------------------------------------------------
t.world(MAP, 7)
local sky = t.environment()
assert(ROSTER[sky.id] ~= nil, "the roll is one of the roster's own: " .. sky.id)
assert(
    sky.insolation == ROSTER[sky.id],
    sky.id .. " arrives with the sunlight the mode file gave it: " .. sky.insolation
)
assert(sky.sink_k == TCMB, "and the sink is the microwave background: " .. sky.sink_k)
assert(sky.profile.gravity_m_s2 == STANDARD_GRAVITY, "the profile carries standard gravity")
assert(sky.profile.background == "space_backdrop", "the profile carries the backdrop")
assert(#sky.name > 0, "a sky has something to call it: " .. tostring(sky.name))

-- Shipped stations retain their commissioned walking contract even though
-- newly authored maps may leave gravity unconstrained.
for _, map in ipairs({
    "chillstation.ron",
    "outpost.ron",
    "cold_outpost.ron",
    "programmable_airlock.ron",
}) do
    t.world_file(map, 7)
    assert(
        t.environment().profile.gravity_m_s2 == STANDARD_GRAVITY,
        map .. " keeps standard gravity"
    )
end

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
    assert(t.environment().profile.gravity_m_s2 == STANDARD_GRAVITY, "the fixture filters zero gravity")
    if not seen[id] then
        seen[id] = true
        distinct = distinct + 1
    end
end
assert(distinct > 1, "and forty shifts are not all parked in the same place")

-- ---------------------------------------------------------------
-- AN UNRESTRICTED MAP ADMITS MICROGRAVITY IN BOTH MODES.
-- ---------------------------------------------------------------
for _, mode in ipairs({ "space_station", "free_build" }) do
    for seed = 1, 3 do
        t.world(UNRESTRICTED_MAP, seed, mode)
        local selected = t.environment()
        assert(
            selected.profile.gravity_m_s2 == STANDARD_GRAVITY or selected.profile.gravity_m_s2 == 0,
            "the unrestricted map selects a declared gravity"
        )
        assert(selected.profile.background == "space_backdrop", "the selected space backdrop is valid")
    end
end

-- An exact zero-gravity preference leaves only the microgravity profile in
-- both modes.
for _, mode in ipairs({ "space_station", "free_build" }) do
    t.world(ZERO_GRAVITY_MAP, 7, mode)
    local zero = t.environment()
    assert(zero.id == "microgravity", "an Exact(0) map selects microgravity")
    assert(zero.profile.gravity_m_s2 == 0, "the selected profile is exactly zero")
    assert(zero.profile.background == "space_backdrop", "zero gravity still has a space backdrop")
end

-- A narrow range and a named backdrop are the same physical filter: both
-- modes still have exactly one matching profile.
for _, mode in ipairs({ "space_station", "free_build" }) do
    t.world(MICROGRAVITY_FILTER_MAP, 7, mode)
    local filtered = t.environment()
    assert(filtered.id == "microgravity", "the range and backdrop select microgravity")
    assert(filtered.profile.gravity_m_s2 == 0, "the range includes only zero gravity here")
    assert(filtered.profile.background == "space_backdrop", "the exact backdrop is preserved")
end

-- ---------------------------------------------------------------
-- A MODE WITH ONE SKY GETS THAT SKY.
--
-- Free Build's terrestrial map has a single matching entry. Its space
-- roster has two choices, but a map with the terrestrial tag cannot land
-- on either one.
-- ---------------------------------------------------------------
for seed = 1, 5 do
    t.world(TERRESTRIAL_MAP, seed, "free_build")
    local sandbox = t.environment()
    assert(sandbox.id == "cold_outdoors", "the terrestrial sandbox has outdoor air: " .. sandbox.id)
    assert(sandbox.insolation == 0.0, "with no star on it: " .. sandbox.insolation)
    assert(sandbox.sink_k == 259.15, "and the cold outdoor sink: " .. sandbox.sink_k)
end
