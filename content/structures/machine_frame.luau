-- Five sheets box up into a frame that waits for an identity. It is
-- wired, then boarded, then screwed together -- and every one of those
-- steps runs backwards, which is the reverse path the old one-way
-- deploy never had (tg's machine_frame.dm).
--
-- The frame never learns what it is becoming: the board carries the
-- machine id and its parts list in the board's own small file, so
-- adding a machine costs zero edits here.
return {
    id = "machine_frame",
    name = "machine frame",
    sprite = "frame",
    dense = true,
    states = { "empty", "wired", "boarded" },
    build = { on = { "floor", "plating" }, with = { metal = 5 }, secs = 8.0 },
    transitions = {
        {
            at = "empty",
            with = { cable_coil = 5 },
            secs = 2.0,
            to = "wired",
            start = "You start wiring the frame.",
            done = "The frame is wired.",
        },
        -- Only a bare frame comes apart under a torch: wiring first, as
        -- tg does, so nobody burns a coil's worth of cable by accident.
        {
            at = "empty",
            tool = "welder",
            secs = 4.0,
            fuel = 2.0,
            yields = { metal = 5 },
            gone = true,
            start = "You start cutting the frame apart.",
            done = "The frame comes apart.",
        },
        {
            at = "wired",
            tool = "cutters",
            secs = 2.0,
            yields = { cable_coil = 5 },
            to = "empty",
            start = "You start cutting the wiring out.",
            done = "The wiring comes free.",
        },
        -- Any item with a board table fits; which machine it makes is
        -- the board's business, not the frame's.
        {
            at = "wired",
            slot = "board",
            to = "boarded",
            done = "The board clicks into place.",
        },
        {
            at = "boarded",
            tool = "crowbar",
            eject = "board",
            to = "wired",
            done = "You pry the board back out.",
        },
        {
            at = "boarded",
            tool = "screwdriver",
            secs = 4.0,
            finish = true,
            start = "You start screwing the assembly together.",
            done = "The machine hums to life.",
        },
    },
}
