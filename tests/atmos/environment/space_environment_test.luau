-- Where the station is parked, and who decides it.
--
-- The engine owns the arithmetic -- a hull radiates sigma*(T^4 - Tsink^4)
-- out and absorbs S/2 in, over whatever area its decks present to the
-- sky (docs/MATTER-WORLD.md §3 step 5d). It owns none of the numbers. Which
-- skies a round may be parked under, how likely each one is and what it
-- is called are all in the game mode file, and a shift rolls one of
-- them off the seeded world RNG at boot (docs/GAMEMODES.md).
--
-- So this file asserts that rolls come off the shipped roster and the same
-- seed lands in the same place; `space_environment_seeds_*_test.luau` sweep
-- forty seeds, and `space_environment_filters_test.luau` asserts that map
-- preferences filter the roster.
--
-- `t.environment()` is the same table `sim.environment()` hands content,
-- so a mod asking where it is gets exactly what is checked here.
local space_environment = require("@helpers/space_environment")

local TCMB = 2.7
local STANDARD_GRAVITY = space_environment.STANDARD_GRAVITY
local MAP = space_environment.MAP
local ROSTER = space_environment.ROSTER

-- ---------------------------------------------------------------
-- THE DEFAULT MODE ROLLS ONE OF ITS OWN FOUR SKIES.
-- ---------------------------------------------------------------
t.world(MAP, 7)
local sky = t.environment()
local sky_profile = assert(sky.profile)
assert(ROSTER[sky.id] ~= nil, "the roll is one of the roster's own: " .. sky.id)
assert(
    sky.insolation == ROSTER[sky.id],
    sky.id .. " arrives with the sunlight the mode file gave it: " .. sky.insolation
)
assert(sky.sink_k == TCMB, "and the sink is the microwave background: " .. sky.sink_k)
assert(sky_profile.gravity_m_s2 == STANDARD_GRAVITY, "the profile carries standard gravity")
assert(sky_profile.background == "space_backdrop", "the profile carries the backdrop")
assert(#sky.name > 0, "a sky has something to call it: " .. tostring(sky.name))

-- Each focused fixture that pins standard gravity walks under it; a map
-- that says nothing about gravity stays unconstrained and is not listed.
-- The list is exactly those fixtures (tools/map-fixture-coverage.mjs).
for _, map in ipairs({
    "cold_outpost.ron",
    "flooded_alcove.ron",
    "plant_loop.ron",
    "programmable_airlock.ron",
    "tank_row.ron",
}) do
    t.world_file(map, 7)
    assert(
        assert(t.environment().profile).gravity_m_s2 == STANDARD_GRAVITY,
        map .. " keeps standard gravity"
    )
end

-- ---------------------------------------------------------------
-- ONE SEED, ONE SKY -- AND DIFFERENT SEEDS REALLY DO DIFFER.
--
-- This half is the replay road: everything about a shift follows from
-- its seed, weather included. The other half, in
-- `space_environment_seeds_*_test.luau`, is what stops that from being
-- satisfied by a constant -- a roll that ignored the roster and always
-- answered "dead space" would pass this assertion forever.
-- ---------------------------------------------------------------
t.world(MAP, 7)
assert(t.environment().id == sky.id, "the same seed is parked in the same place")
assert(t.environment().insolation == sky.insolation, "with the same star, or none")
