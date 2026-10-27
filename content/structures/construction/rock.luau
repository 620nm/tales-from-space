-- The rock composition component as a structure. tg /turf/closed/mineral
-- (minerals.dm:6-51). Mining it is not ported: no transitions.
return {
    id = "rock",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.rock.name",
    name = "rock",
    sprite = "rock-0",
    turf = "component:rock",
    -- Mineral walls join each other (minerals.dm:10-12, base state
    -- `smoothrocks` :21). SMOOTH_BORDER has no engine equivalent: the
    -- map edge is not a neighbour.
    smooth = {
        group = "mineral_walls",
        sprites = "rock",
    },
}
