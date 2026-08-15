-- A layer adapter: the one piece of pipe that breaks the layer rule.
--
-- tg's `/obj/machinery/atmospherics/pipe/layer_manifold`
-- (machinery/pipes/layermanifold.dm) -- "a special pipe to bridge pipe
-- layers with".
--
-- Five piping layers run under every tile of this station and they
-- never meet. That is the whole reason a supply main and a scrubber
-- line can cross a corridor together, and it is enforced everywhere:
-- the flood fill is per layer, a device binds to its own layer and is
-- deaf to the rest. This is the exception, and it is a big one -- an
-- adapter finds the run at BOTH of its ends on EVERY layer and welds
-- every one of them into a SINGLE pipenet
-- (`find_all_connections`/`pipeline_expansion`,
-- layermanifold.dm:90-114).
--
-- So: ten runs, one body of gas, equalised instantly. Put one between a
-- five-layer trunk and a single-layer spur and you have joined the lot.
-- Put one in by mistake and you have joined the lot, which is the same
-- sentence and is why it wants placing deliberately.
--
-- IT IS NOT A PUMP. There is no switch, no power draw and no direction
-- of flow -- it is 200 L of pipe with an unusual number of ends
-- (layermanifold.dm:11). Gas crosses it because it is all one net now,
-- exactly as it crosses an open manual valve.
--
-- TWO PLACEMENT RULES, both tg's, both enforced by the engine because
-- neither can be got right by hand:
--   * `PIPING_DEFAULT_LAYER_ONLY` -- it has no layer of its own to be
--     on, so it is always the default one (`set_piping_layer` ignores
--     its argument, layermanifold.dm:110-111);
--   * `PIPING_CARDINAL_AUTONORMALIZE` -- a thing with two ends and no
--     front has two axes rather than four facings, so south folds onto
--     north and west onto east.
return {
    id = "layer_adapter",
    name = "layer adapter",
    sprite = "layer_adapter_ns",
    dense = false,
    states = { "anchored" },
    facing_sprites = {
        -- Two pictures for two axes, which is all a normalised facing
        -- can ask for.
        anchored = {
            north = "layer_adapter_ns",
            south = "layer_adapter_ns",
            east = "layer_adapter_ew",
            west = "layer_adapter_ew",
        },
    },
    atmos = {
        device = "layer_adapter",
    },
    build = {
        on = { "floor", "plating" },
        from_item = "layer_adapter_fitting",
        tool = "wrench",
        secs = 2.0,
        start = "You start fastening the layer adapter down.",
        done = "The layer adapter is bolted across all five layers.",
    },
    transitions = {
        {
            -- `can_unwrench` on the pipe base, unguarded: an adapter has
            -- no position to be in. Pulling it up splits the ten runs
            -- back into whatever they were, and the gas divides by
            -- volume on the way -- which is the engine's ordinary
            -- conserving rebuild, not a special case for this machine.
            at = "anchored",
            tool = "wrench",
            secs = 2.0,
            gone = true,
            yields = { layer_adapter_fitting = 1 },
            start = "You start unfastening the layer adapter.",
            done = "The layer adapter comes up, and the layers part.",
        },
    },
}
