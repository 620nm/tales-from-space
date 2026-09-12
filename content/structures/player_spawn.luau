-- An invisible, map-authored candidate for a crew body. Its location is
-- retained in the live world so the mode's round.spawn policy can choose it.
return {
    id = "player_spawn",
    name_label = "lunatic/tfs:entity.player_spawn.name",
    name = "Player Spawn",
    sprite = "marker_player_spawn",
    invisible = true,
    dense = false,
    category = "map markers",
    placement = {
        weight = { var = "lunatic/tfs:marker_weight", kind = "number", default = 1,
            min = 0, max = 1000000, step = 1, label = "lunatic/tfs:editor.player_spawn.weight" },
        jobs = { var = "lunatic/tfs:marker_jobs", kind = "text", default = "",
            label = "lunatic/tfs:editor.player_spawn.jobs" },
        roles = { var = "lunatic/tfs:marker_roles", kind = "text", default = "",
            label = "lunatic/tfs:editor.player_spawn.roles" },
    },
    script = "player_spawn",
}
