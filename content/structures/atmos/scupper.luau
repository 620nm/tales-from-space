-- A scupper: a one-way outlet on a wall, where a drain line ends.
--
-- A passive vent hung on a wall (the engine's docs/atmos/liquid-mouths.md).
-- It stands on the floor tile beside its wall, trades with that tile, and
-- discharges what is in the run until the two stand level. `one_way` means
-- nothing comes back up it, so a line ending here cannot flood a deck
-- upstream from the far side. It may discharge into zero gravity: water may
-- enter a room in either state, as beads.
--
-- tg has no scupper; these numbers are this pack's.
--
-- TWO LITRES A SECOND keeps pace with four floor drains on one line.
-- `head_m` 0.5 is the outfall half a metre under the gratings that feed it:
-- fifty times a floor drain's, so a line ending here stands near empty and
-- each drain upstream reaches its film.
--
-- Hung by hand from the fitting, as a button is. The dispenser gives the
-- fitting; the RPD lays nothing that hangs on a wall.
return {
    id = "scupper",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.scupper.name",
    name = "scupper",
    sprite = "scupper",
    mount = true,
    examine = {
        flavor = "An outlet in the wall with a flap over it. Water comes out. Nothing goes back in.",
    },
    states = { "idle", "draining" },
    facing_sprites = {
        idle = {
            north = "scupper_n",
            south = "scupper_s",
            east = "scupper_e",
            west = "scupper_w",
        },
        draining = {
            north = "scupper_draining_n",
            south = "scupper_draining_s",
            east = "scupper_draining_e",
            west = "scupper_draining_w",
        },
    },
    atmos = {
        channel = "l3",
        network = "pipe",
        device = "passive_vent",
        mouth_cap = "vent",
        on = true,
        powered = false,
        positions = { "idle", "draining" },
        phases = { "gas", "liquid" },
        head_m = 0.5,
        one_way = true,
        rate_lps = 2.0,
    },
    build = {
        sound = "smash",
        on = { "component:wall", "component:reinforced_wall" },
        with = { scupper_fitting = 1 },
        secs = 2.0,
        start = "lunatic/tfs:entity.scupper.build.start",
        done = "lunatic/tfs:entity.scupper.build.done",
    },
    transitions = {
        {
            sound = "smash",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { scupper_fitting = 1 },
            start = "lunatic/tfs:entity.scupper.remove.start",
            done = "lunatic/tfs:entity.scupper.remove.done",
        },
    },
}
