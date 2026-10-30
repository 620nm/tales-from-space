-- In zero gravity a loose heavy part is something to push off: the body
-- leaves one way and the part drifts the other (tg's `Process_Spacemove`,
-- tgstation/code/modules/mob/mob_movement.dm:264-297).
local function world(object: string): number
    t.world(
        string.format(
            [==[(
                name: "zero g push off",
                tags: ["space"],
                environment: (kind: Exact(space), gravity_m_s2: Exact(0.0)),
                legend: {
                    's': (composition: (substrate: Named("space"))),
                    'f': (composition: (substrate: Named("space"), components: [(component: "station_base")])),
                },
                levels: [
                    (
                        rows: ["sssssssss", "sssssssss", "sssssssss", "sssfsssss", "sssssssss", "sssssssss", "sssssssss"],
                        structures: [(3, 3, "player_spawn"), (2, 3, %s)],
                    ),
                ],
            )]==],
            object
        ),
        0,
        "free_build"
    )
    local player = t.join()
    t.run_ticks(2)
    return player
end

for _, case in ipairs({
    { placed = '"grav_emitter"', name = "graviton emitter" },
    { placed = '"grav_supermagnet"', name = "supermagnet ring" },
    { placed = '"canister", "displaced"', name = "canister" },
}) do
    local player = world(case.placed)
    t.move(player, "east")
    t.tick()
    local x, y = t.pos(player)
    assert(x == 4 and y == 3, case.name .. ": the push-off steps the body east: " .. x .. "," .. y)
    t.run_seconds(0.5)
    x = t.pos(player)
    assert(x > 4, case.name .. ": the body keeps drifting east")
    local drawn = table.concat(t.drawn_at(player, 1, 3), ",") .. table.concat(t.drawn_at(player, 0, 3), ",")
    assert(string.find(drawn, case.name, 1, true), case.name .. ": the part drifts west, got " .. drawn)
end
