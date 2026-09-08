-- Solid terrain can support a new deck without an adjacent station floor.
return {
    id = "ground",
    name_label = "lunatic/tfs:entity.ground.name",
    name = "ground",
    sprite = "ground",
    turf = "ground",
    transitions = {
        {
            with = { floor_tile = 1 },
            secs = 1.5,
            into = "turf:plating",
            start = "You start laying plating.",
            done = "The plating settles into place.",
        },
    },
}
