-- Hull built out of plasteel (tg's /turf/closed/wall/r_wall,
-- reinf_walls.dm:1-20). Dense and opaque exactly as a plain wall is,
-- and five times its thermal mass -- which is the reason a burn chamber
-- is walled with it, and is the engine's business (atmos/thermal.rs).
--
-- A torch never gets through one: tg overrides `try_decon` and the
-- welder branch that slices an ordinary wall simply is not in it
-- (reinf_walls.dm:50-191). So this table has no welder row, and the
-- ONE thing that opens a reinforced wall is a pair of cutters through
-- the outer grille -- instant, because tg's INTACT rung plays a tool
-- sound and moves on without a do_after at all (`:54-59`).
--
-- What that leaves standing is the frame, and the frame is where the
-- other six rungs live: a turf cannot carry assembly states, so tg's
-- `d_state` is modelled as a structure that stands on the plating the
-- wall became (docs/CONSTRUCTION.md, "The reinforced wall's ladder").
-- Cutting the grille is therefore not a step towards demolition so much
-- as the door into it, and the frame's own first rung welds the grille
-- back and puts the wall back.
return {
    id = "reinforced_wall",
    name = "reinforced wall",
    sprite = "reinforced_wall",
    turf = "reinforced_wall",
    examine = {
        flavor = "A huge chunk of reinforced metal used to separate rooms.",
    },
    transitions = {
        {
            tool = "cutters",
            into = "turf:plating",
            leaves = "reinforced_wall_frame",
            start = "You start cutting the outer grille.",
            done = "The outer grille parts, baring the frame beneath.",
        },
    },
}
