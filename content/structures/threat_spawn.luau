-- An invisible, map-authored candidate for a later threat encounter. The
-- marker is retained; gameplay hooks decide when and what to spawn there.
return {
    id = "threat_spawn",
    name_label = "lunatic/tfs:entity.threat_spawn.name",
    name = "Threat Spawn",
    sprite = "marker_threat_spawn",
    invisible = true,
    dense = false,
    category = "map markers",
    placement = {
        weight = { var = "lunatic/tfs:marker_weight", kind = "number", default = 1,
            min = 0, max = 1000000, step = 1, label = "lunatic/tfs:editor.threat_spawn.weight" },
    },
    script = "threat_spawn",
}
