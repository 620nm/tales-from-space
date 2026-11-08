local assembly = require("@lib/assembly")
local reflection_chamber = require("@lib/process/reflection_chamber")

return {
    id = "reflection_chamber",
    name_label = "lunatic/tfs:entity.reflection_chamber.name",
    name = "reflection chamber",
    sprite = "reflection_chamber",
    visual_layer = "fixture",
    script = "reflection_chamber",
    ui = {
        modules = { "tank", "actions" },
        actions = {
            { key = "toggle_power", label = "lunatic/tfs:action.reflection_chamber.toggle_power" },
        },
    },
    dense = true,
    facings = { "east" },
    examine = {
        flavor = "A tall cold-steel neutron reflector housing with opposing distribution flanges.",
    },
    states = {
        "standby",
        "subcritical",
        "critical",
        "overheated",
        "supercritical",
        "open",
        "broken",
        "destroyed",
    },
    scripted_states = {
        "standby",
        "subcritical",
        "critical",
        "overheated",
        "supercritical",
    },
    -- A map places a chamber already engaged without choosing a thermal
    -- band as a variant; the band stays a live condition of its charge.
    placement = {
        engaged = {
            var = reflection_chamber.ENABLED_VAR,
            kind = "flag",
            default = false,
            label = "lunatic/tfs:editor.reflection_chamber.engaged",
        },
    },
    passable = { "broken", "destroyed" },
    state_sprites = {
        standby = "reflection_chamber",
        subcritical = {
            "reflection_chamber",
            "reflection_chamber_core_subcritical",
            "reflection_chamber_rad_green",
            "reflection_chamber_dial_low",
            "reflection_chamber_slag_clean",
            "reflection_chamber_press_low",
        },
        critical = {
            "reflection_chamber",
            "reflection_chamber_core_critical",
            "reflection_chamber_rad_green",
            "reflection_chamber_dial_nominal",
            "reflection_chamber_slag_clean",
            "reflection_chamber_press_nominal",
        },
        overheated = {
            "reflection_chamber",
            "reflection_chamber_pipe_overheated",
            "reflection_chamber_core_critical",
            "reflection_chamber_rad_yellow",
            "reflection_chamber_dial_high",
            "reflection_chamber_slag_light",
            "reflection_chamber_press_high",
        },
        supercritical = {
            "reflection_chamber",
            "reflection_chamber_pipe_supercritical",
            "reflection_chamber_core_supercritical",
            "reflection_chamber_rad_red",
            "reflection_chamber_dial_max",
            "reflection_chamber_slag_choked",
            "reflection_chamber_press_danger",
        },
        -- The deconstruction rung: the board is in and the panel is off,
        -- so the housing wears its open-panel stripes.
        open = { "reflection_chamber", "reflection_chamber_panel_open" },
        broken = "reflection_chamber_broken",
        destroyed = "reflection_chamber_destroyed",
    },
    atmos = {
        network = "pipe",
        channel = "l3",
        port_channels = { "l3", "l3" },
        device = "tank",
        port_layout = "axis",
        fixed_body = true,
        joined_stubs = true,
        mouth_cap = "chamber",
        volume_l = 1000.0,
        rated_kpa = 4500.0,
    },
    failure = {
        integrity = 200,
        break_at = 0.4,
        limit_kpa = 5000,
        jitter = 0.0,
        damage_min = 15,
        damage_max = 100,
        on_break = "dump",
        broken_state = "broken",
        sound = "spray",
        message = "lunatic/tfs:structures.reflection_chamber.rupture",
    },
    transitions = {
        {
            at = "standby",
            to = "open",
            tool = "screwdriver",
            sound = "smash",
            hint = { label = "lunatic/tfs:ui.affordance.open_panel" },
            done = "lunatic/tfs:structures.reflection_chamber.panel_opened",
        },
        {
            at = "open",
            to = "standby",
            tool = "screwdriver",
            sound = "smash",
            hint = { label = "lunatic/tfs:ui.affordance.close_panel" },
            done = "lunatic/tfs:structures.reflection_chamber.panel_closed",
        },
        {
            at = "subcritical",
            tool = "screwdriver",
            hint = { label = "lunatic/tfs:ui.affordance.open_panel" },
            refuse = {
                {
                    when = true,
                    label = "lunatic/tfs:structures.reflection_chamber.active_refusal",
                },
            },
        },
        {
            at = "critical",
            tool = "screwdriver",
            hint = { label = "lunatic/tfs:ui.affordance.open_panel" },
            refuse = {
                {
                    when = true,
                    label = "lunatic/tfs:structures.reflection_chamber.active_refusal",
                },
            },
        },
        {
            at = "overheated",
            tool = "screwdriver",
            hint = { label = "lunatic/tfs:ui.affordance.open_panel" },
            refuse = {
                {
                    when = true,
                    label = "lunatic/tfs:structures.reflection_chamber.active_refusal",
                },
            },
        },
        {
            at = "supercritical",
            tool = "screwdriver",
            hint = { label = "lunatic/tfs:ui.affordance.open_panel" },
            refuse = {
                {
                    when = true,
                    label = "lunatic/tfs:structures.reflection_chamber.active_refusal",
                },
            },
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
                ["machine_board.reflection_chamber"] = 1,
                cable_coil = 6,
                metal = 5,
            },
            start = "lunatic/tfs:structures.reflection_chamber.pry_start",
            done = "lunatic/tfs:structures.reflection_chamber.pry_done",
        },
    },
}
