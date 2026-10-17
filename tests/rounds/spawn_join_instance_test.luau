-- A spawn marker on a second instance never answers for the join map. The
-- second map's marker carries 99 of the 100 weight, so an unfiltered pick
-- would almost always land a joining body on the second instance.
local JOIN = [==[(
    name: "join spawn",
    legend: { '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])) },
    levels: [
        (
            rows: ["#####", "#...#", "#####"],
            structures: [
                (1, 1, "player_spawn"),
            ],
        ),
    ],
)]==]

local SECOND = [==[(
    name: "second spawn",
    legend: { '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])) },
    levels: [
        (
            rows: ["#####", "#...#", "#####"],
            structures: [
                (3, 1, "player_spawn", { "weight": 99 }),
            ],
        ),
    ],
)]==]

t.world(JOIN, 0, "space_station", {
    key = "lunatic/tfs:join_spawn",
    second_map = {
        source = SECOND,
        key = "lunatic/tfs:second_spawn",
        plane = 1,
    },
})

for _ = 1, 4 do
    local player = t.join()
    local x, y = t.pos(player)
    assert(
        x == 1 and y == 1,
        "a join lands on the join instance's marker, got (" .. x .. ", " .. y .. ")"
    )
end
