local assembly = require("@lib/assembly")

-- Five sheets box up into a frame that waits for an identity
-- (tg's machine_frame.dm).
return {
    id = "machine_frame",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.machine_frame.name",
    name = "machine frame",
    sprite = "frame",
    dense = true,
    states = { "empty", "wired", "boarded" },
    build = {
        sound = "smash",
        on = { "component:station_base" },
        with = { metal = 5 },
        secs = 8.0,
        start = "You start assembling a machine frame.",
        done = "The frame is boxed up.",
    },
    transitions = assembly.board_frame({
        metal = 5,
        cut_start = "You start cutting the frame apart.",
        cut_done = "The frame comes apart.",
        closed = "The machine hums to life.",
    }),
}
