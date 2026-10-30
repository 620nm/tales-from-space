-- TfS exposes the body-shaped client grammar: hands and equipment, jobs,
-- pulling and throwing, vitals, life state and respawn. Body plans alone do
-- not imply this; another pack may use the same native substrate only for
-- non-player actors and leave this declaration absent. `poke` keeps the
-- engine's poke for an empty-handed click on a crewman nothing else claims.
-- `hover` brightens whatever the pointer rests on.
-- The simulation runs at tg's own 20 Hz: TICKLAG 0.5 deciseconds
-- (tgstation/config/config.txt:268-273) mirrors an fps default of 20
-- (tgstation/code/controllers/configuration/entries/general.dm:216-247).
return {
    interactions = {
        body = true,
        poke = true,
        hover = "lift",
        -- What a construction step nobody named is called. `{item}` is what
        -- the step takes.
        verbs = {
            tools = {
                wrench = "lunatic/tfs:ui.verb.wrench",
                crowbar = "lunatic/tfs:ui.verb.crowbar",
                screwdriver = "lunatic/tfs:ui.verb.screwdriver",
                welder = "lunatic/tfs:ui.verb.welder",
                cutters = "lunatic/tfs:ui.verb.cutters",
            },
            material = "lunatic/tfs:ui.verb.material",
            part = "lunatic/tfs:ui.verb.part",
            board = "lunatic/tfs:ui.verb.board",
        },
    },
    simulation = {
        atmosphere = true,
        power = true,
        wind = true,
        tick_hz = 20,
        -- A cell is a 1 m floor tile under a 3 m deck-to-deck level: 3 m3.
        -- tg's turf is 2.5 m3 (`#define CELL_VOLUME 2500`,
        -- tgstation/code/__DEFINES/atmospherics/atmos_core.dm:152). A fall
        -- drops `height_m` per level.
        tile = { width_m = 1, depth_m = 1, height_m = 3 },
        -- The farthest sideways carry an item may answer when it falls, in
        -- tiles. A folded paper plane asks 2 per level it drops
        -- (`content/lib/paper_plane.luau`), so 8 covers a four-level fall.
        fall = { glide_max = 8 },
    },
    -- Seeing down is tg's multi-z look (the engine's
    -- docs/architecture/map-instancing/levels.md "Seeing down"): three levels
    -- below (MAX_EXPECTED_Z_DEPTH, tgstation/code/__DEFINES/layers.dm:393, counts
    -- plane offsets below the top, tgstation/code/controllers/subsystem/mapping.dm:795-819),
    -- each 0.9 darker (tgstation/code/_onclick/hud/rendering/render_plate.dm:47) and
    -- 0.965 smaller (tgstation/code/_onclick/hud/rendering/plane_master_group.dm:181),
    -- straight down.
    -- Light crosses levels one tile of distance per level: tg's falloff takes the z
    -- offset unscaled beside x and y (tgstation/code/modules/lighting/lighting_source.dm:277).
    levels = {
        view = { depth = 3, tint = 0.9, scale = 0.965, offset = { x = 0, y = 0 } },
        light = { level_distance = 1 },
    },
    -- A loose thing on a tile without gravity bobs 2 px up and 2 px down, 1 s
    -- each way (`DO_FLOATING_ANIM`, tgstation/code/__HELPERS/visual_effects.dm:8-10).
    -- tg sets it on living mobs (TRAIT_MOVE_FLOATING,
    -- tgstation/code/modules/mob/living/living.dm:1283); here every loose body,
    -- item and structure floats, and an anchored one stays put.
    weightless = {
        bob = {
            per_kind = {
                player = { rise_px = 2, rise_seconds = 1 },
                item = { rise_px = 2, rise_seconds = 1 },
                machine = { rise_px = 2, rise_seconds = 1 },
            },
        },
    },
}
