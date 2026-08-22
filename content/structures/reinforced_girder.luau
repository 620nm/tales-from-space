-- A girder with a plasteel grille strutted into it (tg's
-- /obj/structure/girder/reinforced, girders.dm:179-185). It is a
-- separate entry rather than a state of the plain girder because it is
-- a separate object in tg too -- `replace_girder` swaps one for the
-- other (girders.dm:61) -- and because the two come apart down
-- different ladders.
--
-- Its own ladder is short and entirely tg's: a screwdriver unsecures
-- the struts and secures them again, four seconds each way
-- (girders.dm:76-83), and cutters take the inner grille out of the
-- unsecured frame in four more, handing the sheet back and leaving a
-- plain girder standing (`:85-90`). From there the ordinary girder's
-- own torch finishes the job, which is why there is no welder row
-- here: tg's reinforced girder does not weld apart either.
--
-- One more sheet of plasteel the other way plates it into hull. Five
-- seconds is `make_delay` on the reinforced wall itself
-- (reinf_walls.dm:16), because the wall is what the step is building.
return {
    id = "reinforced_girder",
    name = "reinforced girder",
    sprite = "girder_reinforced",
    dense = true,
    states = { "reinforced", "struts" },
    examine = {
        flavor = "A girder with a plasteel grille strutted into its frame.",
    },
    transitions = {
        {
            at = "reinforced",
            with = { plasteel = 1 },
            secs = 5.0,
            into = "turf:reinforced_wall",
            start = "You start plating the girder into a reinforced wall.",
            done = "The reinforced wall stands.",
        },
        {
            at = "reinforced",
            tool = "screwdriver",
            secs = 4.0,
            to = "struts",
            start = "You start unsecuring the support struts.",
            done = "The support struts come loose.",
        },
        {
            at = "struts",
            tool = "screwdriver",
            secs = 4.0,
            to = "reinforced",
            start = "You start securing the support struts.",
            done = "The support struts are screwed down.",
        },
        {
            at = "struts",
            tool = "cutters",
            secs = 4.0,
            yields = { plasteel = 1 },
            gone = true,
            leaves = "girder",
            start = "You start cutting out the inner grille.",
            done = "The grille comes out, leaving a plain girder.",
        },
    },
}
