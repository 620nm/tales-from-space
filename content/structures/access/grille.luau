-- A grille, and the clear windows that hang in one.
--
-- One structure wears the mesh and pane bottom-first so the mesh shows
-- through translucent window art and remains unreachable until the pane is
-- removed. Dense but not opaque: blocks movement without blocking sight.
-- Timings follow tg (2 s to fit, 14 s plain or 30 s across five tools for
-- reinforced disassembly). Lead-glass panes swap into `lead_glass_grille`
-- and `reinforced_lead_glass_grille` (`gone = true, leaves = ...`).
return {
    id = "grille",
    -- Large and loose, so it draws over items (large_object in content/compositions.luau).
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.grille.name",
    name = "grille",
    sprite = "grille",
    dense = true,
    motion_response = {
        mass = 50.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.45,
        public_contacts = true,
    },
    opaque = false,
    -- Adjective state names compose grammatical refusals ("The grille must be bolted first.").
    states = { "bolted", "unbolted", "glazed", "unsealed", "reinforced", "heated", "unscrewed", "popped", "cut" },
    -- Commissioned states only; disassembly rungs stay off the editor palette (docs/MAPPING.md).
    palette_states = { "bolted", "glazed", "reinforced" },
    loose = { "unbolted" },
    -- Glass stops air across all glazed and partial-disassembly states (tg window.dm:405).
    airtight = { "glazed", "unsealed", "reinforced", "heated", "unscrewed", "popped", "cut" },
    state_sprites = {
        glazed = { "grille", "window" },
        unsealed = { "grille", "window" },
        -- Every reinforced rung draws identically so partial disassembly is not visible from afar.
        reinforced = { "grille", "rwindow" },
        heated = { "grille", "rwindow" },
        unscrewed = { "grille", "rwindow" },
        popped = { "grille", "rwindow" },
        cut = { "grille", "rwindow" },
    },
    build = {
        sound = "smash",
        on = { "component:station_base" },
        with = { rod = 2 },
        secs = 1.0,
        start = "You start weaving the rods into a grille.",
        done = "The grille stands.",
    },
    transitions = {
        -- tg gates glazing on a fastened grille (grille.dm); screwdriver toggles with no delay.
        {
            sound = "smash",
            at = "bolted",
            tool = "screwdriver",
            to = "unbolted",
            done = "You unfasten the grille from the floor.",
        },
        {
            sound = "smash",
            at = "unbolted",
            tool = "screwdriver",
            to = "bolted",
            done = "You fasten the grille to the floor.",
        },
        {
            sound = "smash",
            at = "unbolted",
            tool = "cutters",
            secs = 1.0,
            yields = { rod = 2 },
            gone = true,
            start = "You start snipping the grille apart.",
            done = "The grille comes apart.",
        },
        {
            sound = "smash",
            at = "bolted",
            tool = "cutters",
            secs = 1.0,
            yields = { rod = 2 },
            gone = true,
            start = "You start snipping the grille apart.",
            done = "The grille comes apart.",
        },

        -- ---- lead glass: swaps to dedicated shielded window structures ----
        {
            sound = "smash",
            at = "bolted",
            with = { lead_glass = 2 },
            secs = 2.0,
            gone = true,
            leaves = "lead_glass_grille",
            start = "You start fitting the lead glass to the grille.",
            done = "The lead glass settles into the grille.",
        },
        {
            sound = "smash",
            at = "bolted",
            with = { reinforced_lead_glass = 2 },
            secs = 2.0,
            hint = {
                id = "fit_reinforced_lead_glass",
                label = "lunatic/tfs:ui.affordance.fit_reinforced_lead_glass",
                suggest = true,
            },
            gone = true,
            leaves = "reinforced_lead_glass_grille",
            start = "You start bolting the reinforced lead glass to the grille.",
            done = "The reinforced lead glass bolts into the grille.",
        },

        -- ---- plain glass: two seconds in, fourteen out ----
        {
            sound = "smash",
            at = "bolted",
            with = { glass = 2 },
            secs = 2.0,
            to = "glazed",
            start = "You start fitting the pane into the grille.",
            done = "The window settles into its frame.",
        },
        {
            sound = "smash",
            at = "glazed",
            tool = "screwdriver",
            secs = 4.0,
            to = "unsealed",
            start = "You start unscrewing the pane from its frame.",
            done = "The pane sits loose in the frame.",
        },
        {
            sound = "smash",
            at = "unsealed",
            tool = "screwdriver",
            secs = 4.0,
            to = "glazed",
            start = "You start screwing the pane back down.",
            done = "The pane is secure again.",
        },
        {
            sound = "smash",
            at = "unsealed",
            tool = "crowbar",
            secs = 10.0,
            yields = { glass = 2 },
            to = "bolted",
            start = "You start levering the pane out of the frame.",
            done = "The pane comes free.",
        },

        -- ---- reinforced: tg's five-tool ladder (window.dm *_act_secondary) ----
        {
            sound = "smash",
            at = "bolted",
            with = { rglass = 2 },
            secs = 2.0,
            hint = {
                id = "rebuild_reinforced_glass",
                label = "lunatic/tfs:ui.affordance.rebuild_reinforced_glass",
                suggest = true,
            },
            to = "reinforced",
            start = "You start fitting the reinforced pane.",
            done = "The reinforced window settles into its frame.",
        },
        {
            sound = "smash",
            at = "reinforced",
            tool = "welder",
            secs = 15.0,
            fuel = 0.45,
            hint = {
                id = "heat_reinforced_glass",
                label = "lunatic/tfs:ui.affordance.heat_reinforced_glass",
            },
            to = "heated",
            start = "You start heating the security screws.",
            done = "The security screws glow white hot.",
        },
        {
            sound = "smash",
            at = "heated",
            tool = "screwdriver",
            secs = 5.0,
            hint = {
                id = "remove_reinforced_glass_screws",
                label = "lunatic/tfs:ui.affordance.remove_reinforced_glass_screws",
            },
            to = "unscrewed",
            start = "You dig into the heated screws.",
            done = "The screws come out, and a gap opens around the pane.",
        },
        {
            sound = "smash",
            at = "unscrewed",
            tool = "crowbar",
            secs = 4.0,
            hint = {
                id = "pry_reinforced_glass",
                label = "lunatic/tfs:ui.affordance.pry_reinforced_glass",
            },
            to = "popped",
            start = "You wedge the crowbar into the gap and pry.",
            done = "The panel pops out, exposing thin metal bars.",
        },
        {
            sound = "smash",
            at = "popped",
            tool = "cutters",
            secs = 2.0,
            hint = {
                id = "cut_reinforced_glass_bars",
                label = "lunatic/tfs:ui.affordance.cut_reinforced_glass_bars",
            },
            to = "cut",
            start = "You start cutting the exposed bars.",
            done = "The panel falls away, exposing the frame bolts.",
        },
        {
            sound = "smash",
            at = "cut",
            tool = "wrench",
            secs = 4.0,
            hint = {
                id = "unbolt_reinforced_glass",
                label = "lunatic/tfs:ui.affordance.unbolt_reinforced_glass",
            },
            yields = { rglass = 2 },
            to = "bolted",
            start = "You start unfastening the frame bolts.",
            done = "The bolts back out and the pane comes loose.",
        },

        -- Reversible intermediate rungs; salvage remains conserved.
        {
            sound = "smash",
            at = "heated",
            tool = "welder",
            secs = 15.0,
            fuel = 0.45,
            hint = {
                id = "repair_reinforced_glass",
                label = "lunatic/tfs:ui.affordance.repair_reinforced_glass",
            },
            to = "reinforced",
            start = "You start securing the heated security screws.",
            done = "The reinforced window is secure again.",
        },
        {
            sound = "smash",
            at = "unscrewed",
            tool = "screwdriver",
            secs = 5.0,
            hint = {
                id = "replace_reinforced_glass_screws",
                label = "lunatic/tfs:ui.affordance.replace_reinforced_glass_screws",
            },
            to = "heated",
            start = "You start replacing the security screws.",
            done = "The screws hold the pane in place again.",
        },
        {
            sound = "smash",
            at = "popped",
            tool = "crowbar",
            secs = 4.0,
            hint = {
                id = "reseat_reinforced_glass",
                label = "lunatic/tfs:ui.affordance.reseat_reinforced_glass",
            },
            to = "unscrewed",
            start = "You start levering the panel back into the frame.",
            done = "The panel sits in the frame again.",
        },
        {
            sound = "smash",
            at = "cut",
            tool = "welder",
            secs = 2.0,
            fuel = 0.3,
            hint = {
                id = "weld_reinforced_glass_bars",
                label = "lunatic/tfs:ui.affordance.weld_reinforced_glass_bars",
            },
            to = "popped",
            start = "You start welding the security bars back together.",
            done = "The security bars hold the panel again.",
        },
    },
}
