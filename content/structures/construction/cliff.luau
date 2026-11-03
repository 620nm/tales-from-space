-- The cliff substrate as a structure. tg /turf/open/cliff (cliff.dm:2-5).
-- Climbing or mining it is not ported: no transitions.
return {
    id = "cliff",
    visual_layer = "substrate",
    name_label = "lunatic/tfs:entity.cliff.name",
    name = "cliff",
    sprite = "terrain_cliff_stepped_smooth_0_4",
    turf = "substrate:cliff",
}
