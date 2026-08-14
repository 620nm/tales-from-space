-- A wall knows what a torch does to it. Ten seconds is tg's
-- slicing_duration (walls.dm), copied deliberately: feel parity is the
-- point, not an improvement.
--
-- A sliced wall is its parts again -- plating underfoot, two sheets
-- loose, and the girder left standing. The girder half is not written
-- here because a turf product cannot also raise an entity; until that
-- gap closes the interpreter owes it.
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
            yields = { metal = 2 },
            start = "You start slicing the wall apart.",
            done = "The wall comes apart.",
        },
    },
}
