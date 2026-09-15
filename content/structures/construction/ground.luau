-- Solid terrain can support a new deck without an adjacent station floor.
return {
    id = "ground",
    visual_layer = "substrate",
    name_label = "lunatic/tfs:entity.ground.name",
    name = "ground",
    sprite = "ground",
    turf = "substrate:ground",
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
