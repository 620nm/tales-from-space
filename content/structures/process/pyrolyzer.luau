local assembly = require("@lib/assembly")

-- The pyrolyzer (methane cracker): a domed thermal retort drum and control
-- column with an H2 top riser and a lower carbon drawer, wired as a
-- frame-built structure across its four baked states (assets/sprites/
-- 95-process-machines.ron:18-21).
return {
    id = "pyrolyzer",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.pyrolyzer.name",
    name = "pyrolyzer",
    sprite = "pyrolyzer",
    dense = true,
    examine = {
        flavor = "A domed thermal retort drum with a top riser and a lower carbon drawer.",
    },
    states = { "standby", "off", "working", "open" },
    palette_states = { "standby", "off", "working", "open" },
    state_sprites = {
        standby = "pyrolyzer",
        off = "pyrolyzer_off",
        working = "pyrolyzer_on",
        open = "pyrolyzer_open",
    },
    transitions = {
        {
            sound = "smash",
            at = "standby",
            tool = "screwdriver",
            to = "open",
            hint = { label = "lunatic/tfs:ui.affordance.open_panel" },
            done = "lunatic/tfs:structures.pyrolyzer.panel_opened",
        },
        {
            sound = "smash",
            at = "open",
            tool = "screwdriver",
            to = "standby",
            hint = { label = "lunatic/tfs:ui.affordance.close_panel" },
            done = "lunatic/tfs:structures.pyrolyzer.panel_closed",
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
                ["machine_board.pyrolyzer"] = 1,
                cable_coil = 6,
                glass = 1,
            },
            start = "lunatic/tfs:structures.pyrolyzer.pry_start",
            done = "lunatic/tfs:structures.pyrolyzer.pry_done",
        },
    },
}
