-- A floor drain: a grating in the deck over a pipe run. Standing water goes
-- down it, and the run carries it wherever the run goes.
--
-- A passive vent that also takes liquid (the engine's
-- docs/atmos/liquid-mouths.md). No power and no switch: the grating levels
-- the deck against the run, so a drain on a full line gives water back.
-- It takes settled water only, so in zero gravity beads float over it. It
-- stops at the film, so a drained deck is a damp deck, and that is the mop's.
--
-- tg has no floor drain. A spill there is a `wet_floor` decal on a timer
-- (`code/game/objects/effects/decals/cleanable/misc.dm`,
-- `other_reagents.dm:138-147`), so these numbers are this pack's.
--
-- HALF A LITER A SECOND is two crew mopping: a mop lifts a quarter of a
-- liter a stroke (items/tools/mop.luau). Ten liters on one tile stand 6.7
-- over the film, gone in 13 seconds. The alcove's hundred liters over its
-- 24 tiles stand 20 over the film, gone in 40. A real flood outruns it.
--
-- `head_m` 0.01: a full run stands a centimeter over the film here, so a
-- dead-end line of one length (270 L with its port) takes that ten-liter
-- spill to within 0.24 L of the film. It is low so a short line still
-- empties a deck, and a scupper's 0.5 m wins any argument on the same run.
return {
    id = "floor_drain",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.floor_drain.name",
    name = "floor drain",
    sprite = "floor_drain",
    dense = false,
    opaque = false,
    examine = {
        flavor = "A grated hole in the deck. Whatever is spilled goes down it, eventually.",
    },
    states = { "idle", "draining" },
    state_sprites = {
        idle = "floor_drain",
        draining = "floor_drain_draining",
    },
    atmos = {
        channel = "l3",
        network = "pipe",
        device = "passive_vent",
        mouth_cap = "scrub",
        on = true,
        powered = false,
        positions = { "idle", "draining" },
        phases = { "gas", "liquid" },
        head_m = 0.01,
        rate_lps = 0.5,
    },
    build = {
        sound = "smash",
        on = { "component:station_base" },
        from_item = "floor_drain_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "lunatic/tfs:entity.floor_drain.build.start",
        done = "lunatic/tfs:entity.floor_drain.build.done",
    },
    transitions = {
        {
            sound = "smash",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { floor_drain_fitting = 1 },
            start = "lunatic/tfs:entity.floor_drain.remove.start",
            done = "lunatic/tfs:entity.floor_drain.remove.done",
        },
    },
}
