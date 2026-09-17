-- A wall-mounted air sensor: a room's own nose on the network.
--
-- It reads the air on its own tile and repeats the band onto the
-- network (fixtures/air_sensor.luau), which is how an air alarm comes
-- to draw a room it never stands in. A vent already reports its own
-- tile, but a vent is a fan on a pipe -- this is the instrument for a
-- room with no plumbing to watch, a corridor, a chamber, a doorway.
--
-- SELF-SENSING. The `sense` block names every side, so the effective
-- mask is the room minus the wall it hangs on. The `self` sample IS
-- the room: the tile it stands on, read live. Neighbours ride along
-- for context, but the station-air question is answered from home.
--
-- ENDPOINT, CLASS `sensor`. It carries its own address and joins one
-- hub. An access point takes it (its open roster takes anything the
-- roles allow); an air alarm refuses it (its roster is plumbing and
-- buttons, structures/atmos/air_alarm.luau), because a room's plumbing
-- console has no page for a bare instrument.
--
-- No `energy_network`: like the button beside it, it draws nothing.
-- The hazard pass reads it whether or not anybody is listening, and
-- the ledger row is forensic either way.
return {
    id = "air_sensor",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.air_sensor.name",
    name = "air sensor",
    sprite = "airlock_button",
    mount = true,
    script = "air_sensor",
    link = { network_interface = true, role = "endpoint", class = "sensor" },
    sense = { sides = { "north", "south", "east", "west" } },
    appearance = {
        mounted = {
            north = "airlock_button_n",
            south = "airlock_button_s",
            east = "airlock_button_e",
            west = "airlock_button_w",
        },
    },
    examine = {
        flavor = "A small grille with a lamp behind it. It tastes the air "
            .. "and tells the network what it found.",
    },
    build = {
        sound = "smash",
        on = { "component:wall", "component:reinforced_wall" },
        with = { air_sensor_fitting = 1 },
        secs = 2.0,
        start = "lunatic/tfs:entity.air_sensor.build.start",
        done = "lunatic/tfs:entity.air_sensor.build.done",
    },
    transitions = {
        {
            sound = "smash",
            tool = "screwdriver",
            secs = 2.0,
            gone = true,
            yields = { air_sensor_fitting = 1 },
            start = "lunatic/tfs:entity.air_sensor.remove.start",
            done = "lunatic/tfs:entity.air_sensor.remove.done",
        },
    },
}
