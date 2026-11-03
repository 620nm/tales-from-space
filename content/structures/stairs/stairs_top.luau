-- The top of a flight: tg's open space over the stairs (openspace.dm:1-6,
-- stairs.dm:11), which this game climbs down rather than falls through
-- (content/compositions.luau). It draws nothing of its own.
return {
    id = "stairs_top",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.stairs_top.name",
    name = "top of the stairs",
    sprite = "stairs_n", -- turf entries never spawn; this names the flight below
    dense = false,
    turf = "component:stairs_top",
}
