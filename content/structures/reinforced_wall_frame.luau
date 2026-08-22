-- The inside of a reinforced wall, laid open one layer at a time.
--
-- tg keeps all seven rungs on the TURF, as a `d_state` var counting
-- from INTACT to SHEATH (reinf_walls.dm:50-191). A turf entry here
-- cannot: a turf has no assembly states, so the ladder is modelled as a
-- structure standing on the plating the wall became, and the wall's own
-- table has exactly one row -- the cutters that open the grille -- which
-- leaves this frame behind. The two halves add up to tg's seven, the
-- numbers are tg's unchanged, and the repair direction still works from
-- every rung, including the first one back into solid hull.
--
-- Every step is verbatim (`use_tool` deciseconds, reinf_walls.dm):
-- screwdriver 40 either way on the support lines, welder 60 and two
-- moles of fuel to slice the cover or weld it back, crowbar 100 to pry
-- the cover off and 20 to press it back, wrench 40 either way on the
-- anchor bolts, welder 100 and two moles through the support rods and
-- 100 with NO fuel cost to weld them together again (`:181`, tg's
-- `amount = 0`), crowbar 100 to lift the outer sheath off. Prying the
-- sheath is `dismantle_wall`: one sheet of plasteel back (`sheet_type`
-- and `sheet_amount`, reinf_walls.dm:12-13) and the reinforced girder
-- left standing (`girder_type`, `:14`).
--
-- It is dense, opaque and airtight in every state, because a wall with
-- its cover off is still a wall: tg never drops density or opacity as
-- `d_state` climbs, and a crew that could breathe through a half-cut
-- r_wall would have found the fastest depressurization tool on the
-- station.
return {
    id = "reinforced_wall_frame",
    name = "reinforced wall frame",
    sprite = "reinforced_wall_1",
    dense = true,
    opaque = true,
    airtight = true,
    states = {
        "support_lines",
        "cover",
        "cut_cover",
        "anchor_bolts",
        "support_rods",
        "sheath",
    },
    -- tg's own six deconstruction pictures, `r_wall-1` through `-6`
    -- (icons/turf/walls/reinforced_states.dmi), in the order the
    -- states above climb.
    state_sprites = {
        support_lines = "reinforced_wall_1",
        cover = "reinforced_wall_2",
        cut_cover = "reinforced_wall_3",
        anchor_bolts = "reinforced_wall_4",
        support_rods = "reinforced_wall_5",
        sheath = "reinforced_wall_6",
    },
    examine = {
        flavor = "A reinforced wall opened up: support lines, a welded cover, "
            .. "and the anchored rods of its sheath beneath.",
    },
    transitions = {
        -- The way back to hull. tg repairs the grille with the same
        -- snip that cut it and no delay at all (reinf_walls.dm:72-77).
        {
            at = "support_lines",
            tool = "cutters",
            into = "turf:reinforced_wall",
            start = "You start weaving the outer grille back together.",
            done = "The grille closes, and the wall is whole.",
        },
        {
            at = "support_lines",
            tool = "screwdriver",
            secs = 4.0,
            to = "cover",
            start = "You start unsecuring the support lines.",
            done = "The support lines come unsecured.",
        },
        {
            at = "cover",
            tool = "screwdriver",
            secs = 4.0,
            to = "support_lines",
            start = "You start securing the support lines.",
            done = "The support lines are secured.",
        },
        {
            at = "cover",
            tool = "welder",
            secs = 6.0,
            fuel = 2.0,
            to = "cut_cover",
            start = "You start slicing through the metal cover.",
            done = "The cover dislodges under your hand.",
        },
        {
            at = "cut_cover",
            tool = "welder",
            secs = 6.0,
            fuel = 2.0,
            to = "cover",
            start = "You start welding the metal cover back to the frame.",
            done = "The cover is welded securely to the frame.",
        },
        {
            at = "cut_cover",
            tool = "crowbar",
            secs = 10.0,
            to = "anchor_bolts",
            start = "You start struggling to pry off the cover.",
            done = "The cover comes away.",
        },
        {
            at = "anchor_bolts",
            tool = "crowbar",
            secs = 2.0,
            to = "cut_cover",
            start = "You start prying the cover back into place.",
            done = "The cover is pried back into place.",
        },
        {
            at = "anchor_bolts",
            tool = "wrench",
            secs = 4.0,
            to = "support_rods",
            start = "You start loosening the bolts anchoring the support rods.",
            done = "The anchoring bolts come out.",
        },
        {
            at = "support_rods",
            tool = "wrench",
            secs = 4.0,
            to = "anchor_bolts",
            start = "You start tightening the bolts anchoring the support rods.",
            done = "The anchoring bolts are tight.",
        },
        {
            at = "support_rods",
            tool = "welder",
            secs = 10.0,
            fuel = 2.0,
            to = "sheath",
            start = "You start slicing through the support rods.",
            done = "The support rods part.",
        },
        -- Welding the rods back together costs no fuel in tg either:
        -- `tool_start_check(user, amount = 0)` (reinf_walls.dm:181).
        {
            at = "sheath",
            tool = "welder",
            secs = 10.0,
            fuel = 0.0,
            to = "support_rods",
            start = "You start welding the support rods back together.",
            done = "The support rods are whole again.",
        },
        {
            at = "sheath",
            tool = "crowbar",
            secs = 10.0,
            yields = { plasteel = 1 },
            gone = true,
            leaves = "reinforced_girder",
            start = "You start struggling to pry off the outer sheath.",
            done = "The sheath comes off, leaving the girder bare.",
        },
    },
}
