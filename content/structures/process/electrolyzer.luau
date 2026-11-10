local assembly = require("@lib/assembly")

-- The electrolyzer: a shrouded 3/4ths steel cabinet with a left half-height
-- beaker bay and paired Hofmann glass columns (`assets/sprites/
-- 95-process-machines.ron:26-37`), built from a machine frame and its
-- circuitboard.
return {
    id = "electrolyzer",
    entity_class = "installed",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.electrolyzer.name",
    name = "electrolyzer",
    sprite = "electrolyzer",
    dense = true,
    examine = {
        flavor = "A steel electrolysis cabinet topped with paired glass collection columns.",
    },
    states = { "standby", "off", "working", "open_empty", "open_beaker", "open" },
    palette_states = { "standby", "off", "working", "open_empty", "open_beaker", "open" },
    state_sprites = {
        standby = "electrolyzer",
        off = "electrolyzer_off",
        working = "electrolyzer_on",
        open_empty = "electrolyzer_open_empty",
        open_beaker = "electrolyzer_open_beaker",
        open = "electrolyzer_open",
    },
    transitions = {
        {
            sound = "smash",
            at = "standby",
            tool = "screwdriver",
            to = "open",
            hint = { label = "lunatic/tfs:ui.affordance.open_panel" },
            done = "lunatic/tfs:structures.electrolyzer.panel_opened",
        },
        {
            sound = "smash",
            at = "open",
            tool = "screwdriver",
            to = "standby",
            hint = { label = "lunatic/tfs:ui.affordance.close_panel" },
            done = "lunatic/tfs:structures.electrolyzer.panel_closed",
        },
        {
            sound = "crowbar",
            at = "open",
            tool = "crowbar",
            hint = assembly.back("lunatic/tfs:ui.affordance.deconstruct"),
            secs = 4.0,
            gone = true,
            leaves = "machine_frame",
            yields = {
                ["machine_board.electrolyzer"] = 1,
                cable_coil = 6,
                glass = 1,
            },
            start = "lunatic/tfs:structures.electrolyzer.pry_start",
            done = "lunatic/tfs:structures.electrolyzer.pry_done",
        },
    },
}
