-- A colour adapter: the seam between two paint jobs.
--
-- tg's `/obj/machinery/atmospherics/pipe/color_adapter`
-- (machinery/pipes/color_adapter.dm) -- "a one meter section of regular
-- pipe used to connect different colored pipes".
--
-- Paint is not decoration on this station. Two pipe ends only join when
-- their colours agree or one of them is unpainted (tg's
-- `is_connectable`, ported in crates/lunatic-server/src/pipes/paint.rs),
-- which is what makes a stripe of the wrong colour across a
-- distribution main CUT it. Very useful, until the day you actually
-- want the blue supply and the red waste line to meet and every
-- honest way of doing it means repainting one of them end to end.
--
-- This is the piece that does it. It carries tg's `PIPING_ALL_COLORS`
-- (color_adapter.dm:10): its two ends join whatever they reach,
-- whatever colour it is, and the runs on either side stay the colours
-- they were. One net, two liveries.
--
-- IT TAKES NO PAINT ITSELF (`paintable = FALSE`, color_adapter.dm:16),
-- and that is not an oversight -- a thing that joins every colour has
-- no colour to be. A painter waved at one is told so.
--
-- Seventy litres, which is one length of ordinary pipe: tg gives a pipe
-- `UNARY_PIPE_VOLUME * device_type` and this has two ends
-- (pipes.dm:27-28). It is pipe, not a machine -- no switch, no power,
-- no direction of flow. And like the layer adapter it normalises its
-- facing (`PIPING_CARDINAL_AUTONORMALIZE`), because a tube with two
-- ends has two axes and not four facings.
return {
    id = "color_adapter",
    name = "color adapter",
    sprite = "color_adapter_ns",
    dense = false,
    states = { "anchored" },
    facing_sprites = {
        anchored = {
            north = "color_adapter_ns",
            south = "color_adapter_ns",
            east = "color_adapter_ew",
            west = "color_adapter_ew",
        },
    },
    atmos = {
        device = "color_adapter",
    },
    build = {
        on = { "floor", "plating" },
        from_item = "color_adapter_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the color adapter down.",
        done = "The color adapter is bolted between the two runs.",
    },
    transitions = {
        {
            at = "anchored",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { color_adapter_fitting = 1 },
            start = "You start unfastening the color adapter.",
            done = "The color adapter comes up, and the colours part.",
        },
    },
}
