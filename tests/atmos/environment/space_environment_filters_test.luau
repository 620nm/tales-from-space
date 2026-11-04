-- Map preferences filter the sky roster (the roll itself is
-- `space_environment_test.luau`): a map's saved physical preference and
-- needs narrow which of a mode's skies a shift may be parked under.
local space_environment = require("@helpers/space_environment")

local STANDARD_GRAVITY = space_environment.STANDARD_GRAVITY

-- A new map with no saved physical preference accepts every compatible
-- profile, including microgravity.
local UNRESTRICTED_MAP = [==[(
    name: "unrestricted",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "###",
                "#.#",
                "###",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==]

local TERRESTRIAL_MAP = UNRESTRICTED_MAP:gsub(
    'name: "unrestricted",',
    'name: "terrestrial", needs: ["gravity"], environment: (surface_temperature_k: Exact(259.15)),'
)

local ZERO_GRAVITY_MAP = [==[(
    name: "zero gravity",
    environment: (gravity_m_s2: Exact(0.0)),
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "###",
                "#.#",
                "###",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==]

local MICROGRAVITY_FILTER_MAP = [==[(
    name: "microgravity filter",
    environment: (
        gravity_m_s2: Range(min: Some(0.0), max: Some(0.1)),
        background: Exact(Some("space_backdrop")),
    ),
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "###",
                "#.#",
                "###",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==]

-- ---------------------------------------------------------------
-- AN UNRESTRICTED MAP ADMITS MICROGRAVITY IN BOTH MODES.
-- ---------------------------------------------------------------
for _, mode in ipairs({ "space_station", "free_build" }) do
    for seed = 1, 3 do
        t.world(UNRESTRICTED_MAP, seed, mode)
        local selected = t.environment()
        local selected_profile = assert(selected.profile)
        assert(
            selected_profile.gravity_m_s2 == STANDARD_GRAVITY or selected_profile.gravity_m_s2 == 0,
            "the unrestricted map selects a declared gravity"
        )
        assert(
            selected_profile.background == "space_backdrop",
            "the selected space backdrop is valid"
        )
    end
end

-- An exact zero-gravity preference leaves only the two weightless skies
-- (`dead_space` and `microgravity`) in both modes.
for _, mode in ipairs({ "space_station", "free_build" }) do
    t.world(ZERO_GRAVITY_MAP, 7, mode)
    local zero = t.environment()
    local zero_profile = assert(zero.profile)
    assert(
        zero.id == "microgravity" or zero.id == "dead_space",
        "an Exact(0) map selects a weightless sky: " .. zero.id
    )
    assert(zero_profile.gravity_m_s2 == 0, "the selected profile is exactly zero")
    assert(zero_profile.background == "space_backdrop", "zero gravity still has a space backdrop")
end

-- A narrow range and a named backdrop are the same physical filter: both
-- modes leave only the two weightless skies.
for _, mode in ipairs({ "space_station", "free_build" }) do
    t.world(MICROGRAVITY_FILTER_MAP, 7, mode)
    local filtered = t.environment()
    local filtered_profile = assert(filtered.profile)
    assert(
        filtered.id == "microgravity" or filtered.id == "dead_space",
        "the range and backdrop select a weightless sky: " .. filtered.id
    )
    assert(filtered_profile.gravity_m_s2 == 0, "the range includes only zero gravity here")
    assert(filtered_profile.background == "space_backdrop", "the exact backdrop is preserved")
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
