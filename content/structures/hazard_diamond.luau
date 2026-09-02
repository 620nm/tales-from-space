-- The hazard diamond: a placard bolted beside a store, saying what is
-- in the store.
--
-- A SIGN rather than a machine (docs/construction/signs.md): no power,
-- no network, no panel. It reads the Matter Blend its placement names
-- once, while the station is being commissioned, and wears the answer
-- for the rest of the shift. So it says what was PUT in the chamber,
-- which is what a painted placard says in a real one -- an instrument
-- that tracked the room would be a gauge, and this station already has
-- those.
--
-- The layer forms are the engine's; every word and every picture is
-- ours. Three readings come off the composition's scales, and the
-- symbol list is a PRIORITY order of which the first match draws: the
-- worst thing in the chamber gets the corner, and only one thing does.
-- The words are the ones our own substances carry
-- (content/substances/*.luau, `hazard.special`).
return {
    id = "hazard_diamond",
    name = "hazard diamond",
    sprite = "nfpa_704_placard",
    mount = true,
    appearance = {
        mounted = {
            north = "nfpa_704_placard", south = "nfpa_704_placard",
            east = "nfpa_704_placard", west = "nfpa_704_placard",
        },
    },
    build = {
        on = { "wall", "reinforced_wall" },
        with = { metal = 1 },
        secs = 2.0,
        start = "You start bolting the placard to the wall.",
        done = "The placard is up.",
    },
    -- It comes down the way it went up, and the sheet comes back: a
    -- placard bolted to a wall must not spend the tile it stands on for
    -- the rest of the shift.
    transitions = {
        {
            tool = "screwdriver",
            secs = 2.0,
            gone = true,
            yields = { metal = 1 },
            start = "You start unscrewing the placard.",
            done = "The placard comes off the wall.",
        },
    },
    sign = {
        blend = {
            layers = {
                {
                    scale = "health",
                    sprites = {
                        "nfpa_704_health_0", "nfpa_704_health_1",
                        "nfpa_704_health_2", "nfpa_704_health_3",
                        "nfpa_704_health_4",
                    },
                },
                {
                    scale = "fire",
                    sprites = {
                        "nfpa_704_fire_0", "nfpa_704_fire_1",
                        "nfpa_704_fire_2", "nfpa_704_fire_3",
                        "nfpa_704_fire_4",
                    },
                },
                {
                    scale = "instability",
                    sprites = {
                        "nfpa_704_reactivity_0", "nfpa_704_reactivity_1",
                        "nfpa_704_reactivity_2", "nfpa_704_reactivity_3",
                        "nfpa_704_reactivity_4",
                    },
                },
                -- Worst first: what will kill you outright, then what
                -- will keep killing you, then what will kill the next
                -- person, then the two that only matter in quantity.
                {
                    special = {
                        { "skull", "nfpa_704_special_skull" },
                        { "radioactive", "nfpa_704_special_radioactive" },
                        { "biohazard", "nfpa_704_special_biohazard" },
                        { "water_reactive", "nfpa_704_special_water_reactive" },
                        { "asphyxiant", "nfpa_704_special_asphyxiant" },
                        { "oxidizer", "nfpa_704_special_oxidizer" },
                    },
                },
            },
        },
    },
    examine = {
        flavor = "A four-quadrant hazard placard, painted to match what "
            .. "the chamber behind it was charged with.",
    },
}
