-- The rock floor substrate as a structure. tg /turf/open/misc/asteroid
-- (asteroid.dm:5-14). Laying plating on it is not ported: no transitions.
return {
    id = "rock_floor",
    visual_layer = "substrate",
    name_label = "lunatic/tfs:entity.rock_floor.name",
    name = "rock floor",
    sprite = "rock_floor",
    turf = "substrate:rock_floor",
}
