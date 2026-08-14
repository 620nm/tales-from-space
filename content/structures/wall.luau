-- A wall knows what a torch does to it. Ten seconds is tg's
-- slicing_duration (walls.dm), copied deliberately: feel parity is the
-- point, not an improvement.
--
-- A sliced wall is its parts again: plating underfoot, the girder left
-- standing, two sheets loose on the floor. `leaves` is the girder
-- because a girder is a structure, not a stack -- refunding it as
-- material would make it something you carry in a pocket.
return {
    id = "wall",
    name = "wall",
    sprite = "wall",
    turf = "wall",
    transitions = {
        {
            tool = "welder",
            secs = 10.0,
            fuel = 2.0,
            into = "turf:plating",
            leaves = "girder",
            yields = { metal = 2 },
            start = "You start slicing the wall apart.",
            done = "The wall comes apart.",
        },
    },
}
