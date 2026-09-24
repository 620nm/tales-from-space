-- The sky roll's shared fixture: the standard-gravity map, the station's
-- roster, and the seed sweep `atmos/environment/space_environment_*_test.luau`
-- split between them so the runner works the seeds in parallel.
local space_environment = {}

space_environment.STANDARD_GRAVITY = 9.80665

space_environment.MAP = [==[(
    name: "somewhere",
    // This is the pre-environment fixture: retain the walking assumptions
    // of the older test while the real map contract grows new choices.
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
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
space_environment.ROSTER = {
    dead_space = 0.0,
    microgravity = 0.0,
    orbit = 1361.0,
    sunward = 2700.0,
} :: { [string]: number }

-- Boot MAP under seeds `first`..`last`; every roll lands on the roster at
-- standard gravity. Returns how many distinct skies the range landed on.
function space_environment.roll_seeds(first: number, last: number): number
    local seen: { [string]: boolean } = {}
    local distinct = 0
    for seed = first, last do
        t.world(space_environment.MAP, seed)
        local id = t.environment().id
        assert(space_environment.ROSTER[id] ~= nil, "every seed lands on the roster: " .. id)
        assert(
            assert(t.environment().profile).gravity_m_s2 == space_environment.STANDARD_GRAVITY,
            "the fixture filters zero gravity"
        )
        if not seen[id] then
            seen[id] = true
            distinct = distinct + 1
        end
    end
    return distinct
end

return space_environment
