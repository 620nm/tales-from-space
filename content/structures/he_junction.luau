-- A junction: the seam between a heat-exchange run and ordinary pipe.
--
-- tg's `/obj/machinery/atmospherics/pipe/heat_exchanging/junction`
-- (heat_exchange/junction.dm) -- "a one meter junction that connects
-- regular and heat-exchanging pipe".
--
-- Heat-exchanging pipe joins only heat-exchanging pipe (tg's
-- `HE_type_check`, he_pipes.dm:18-21), which is what makes a cooling
-- loop a closed circuit rather than a branch of the distribution main.
-- This is the piece that opens it: two mouths, one net across itself,
-- and the runs on either side stay the kinds they were. It is the
-- colour adapter's trick applied to the other half of a length's
-- identity, and it is the same engine primitive doing it.
--
-- IT CONDUCTS NOTHING. tg gives it `WALL_HEAT_TRANSFER_COEFFICIENT`,
-- which is 0.0 (__DEFINES/atmospherics/atmos_core.dm:119), behind a
-- 300 K deadband -- a heat-exchange fitting that is deliberately inert,
-- so the seam is a seam and not a radiator. Here it is a device rather
-- than a length, and a device holds gas without trading heat with the
-- deck at all, which lands in the same place.
--
-- ONE DEVIATION, and it is the engine's: a device mouth takes any run
-- it reaches (../lunatic/docs/ATMOS.md, "Devices are omni"), so this
-- accepts either kind at either end where tg refuses ordinary pipe on
-- its heat-exchange side. Turning it around therefore changes nothing,
-- which is why it normalises its facing onto one axis and wears two
-- pictures rather than four.
--
-- Seventy litres, one length of ordinary pipe: tg gives a pipe
-- `UNARY_PIPE_VOLUME * device_type` and this has two ends
-- (pipes.dm:27-28).
return {
    id = "he_junction",
    name = "junction",
    sprite = "he_junction_ns",
    dense = false,
    states = { "anchored" },
    facing_sprites = {
        anchored = {
            north = "he_junction_ns",
            south = "he_junction_ns",
            east = "he_junction_ew",
            west = "he_junction_ew",
        },
    },
    atmos = {
        device = "color_adapter",
    },
    build = {
        on = { "floor", "plating" },
        from_item = "he_junction_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the junction down.",
        done = "The junction is bolted between the two runs.",
    },
    transitions = {
        {
            at = "anchored",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { he_junction_fitting = 1 },
            start = "You start unfastening the junction.",
            done = "The junction comes up, and the two runs part.",
        },
    },
}
