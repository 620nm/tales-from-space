-- Gravity follows the surroundings and the installed deck; a handhold is
-- independently useful when the field supplies no gravity. Standard gravity
-- over open space rolls the station mode's lit skies, since the sunless one
-- (`dead_space`) is weightless without a running gravity battery
-- (power/grav_smes_power_test.luau).
local function world(center: string, brace: string, terrestrial: boolean, microgravity: boolean): number
    local needs = if terrestrial then '["gravity"]' else "[]"
    local kind = if terrestrial then "terrestrial" else "space"
    local gravity = if microgravity then "0.0" else "9.80665"
    t.world(
        string.format(
            [==[(
                name: "gravity movement",
                needs: %s,
                environment: (kind: Exact(%s), gravity_m_s2: Exact(%s)),
                legend: {
                    's': (composition: (substrate: Named("space"))),
                    'f': (composition: (substrate: Named("space"), components: [(component: "station_base")])),
                    'l': (composition: (substrate: Named("space"), components: [(component: "lattice")])),
                    'w': (composition: (substrate: Named("space"), components: [(component: "wall")])),
                },
                levels: [
                    (
                        rows: ["sssssssss", "sssssssss", "sssssssss", "ss%s%ssssss", "sssssssss", "sssssssss", "sssssssss"],
                        structures: [(3, 3, "player_spawn")],
                    ),
                ],
            )]==],
            needs,
            kind,
            gravity,
            brace,
            "f"
        ),
        0,
        if terrestrial or microgravity then "free_build" else "space_station"
    )
    local player = t.join()
    t.run_ticks(2)
    if center == "s" then
        assert(t.set_composition(3, 3, "bare"))
    end
    return player
end

local function position(player: number, x: number, y: number, message: string)
    local actual_x, actual_y = t.pos(player)
    assert(actual_x == x and actual_y == y, message .. ": " .. actual_x .. "," .. actual_y)
end

local stranded = world("s", "s", false, false)
t.move(stranded, "east")
t.run_seconds(0.5)
position(stranded, 3, 3, "open space refuses unsupported movement even with the station field on")

local departing = world("f", "s", false, false)
t.move(departing, "east")
t.tick()
position(departing, 4, 3, "a station deck permits stepping into space")
t.move(departing, "north")
t.run_seconds(0.5)
local flight_x, flight_y = t.pos(departing)
assert(flight_x > 4 and flight_y == 3, "released movement coasts and unsupported input cannot steer")

local grounded = world("s", "s", true, false)
t.move(grounded, "east")
t.run_seconds(0.5)
position(grounded, 4, 3, "terrestrial vacuum permits a step and supplies gravity to stop coasting")
t.move(grounded, "north")
t.tick()
position(grounded, 4, 2, "terrestrial vacuum does not require a handhold")

local floating_floor = world("f", "s", false, true)
t.move(floating_floor, "east")
t.run_seconds(0.5)
position(floating_floor, 3, 3, "a bare station floor provides no grip in explicit microgravity")

for _, brace in ipairs({ "l", "w" }) do
    local braced = world("s", brace, false, true)
    t.move(braced, "east")
    t.tick()
    position(braced, 4, 3, "a nearby lattice or wall permits push-off")
    t.run_seconds(0.5)
    local x, y = t.pos(braced)
    assert(x > 4 and y == 3, "push-off continues beyond the handhold")
end
