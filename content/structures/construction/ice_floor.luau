-- The ice floor substrate as a structure. tg /turf/open/misc/ice takes
-- metal floor tiles as plating like any misc turf (misc.dm:33-35).
return {
    id = "ice_floor",
    visual_layer = "substrate",
    name_label = "lunatic/tfs:entity.ice_floor.name",
    name = "ice",
    sprite = "ice_floor-0",
    turf = "substrate:ice_floor",
    transitions = {
        {
            sound = "smash",
            with = { floor_tile = 1 },
            secs = 1.5,
            into = "add_component:station_base",
            start = "You start laying plating.",
            done = "The plating settles into place.",
        },
    },
}
