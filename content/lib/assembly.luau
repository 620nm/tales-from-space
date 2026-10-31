-- Hand-built ladders: a step named into the hover card's Next or Back group,
-- and the frame every board-built machine goes through. A frame never learns
-- what it becomes: the board carries the product and its parts list.
export type FrameWords = {
    metal: number,
    cut_start: string,
    cut_done: string,
    closed: string,
}

local assembly = {}

-- A step toward the finished thing; `label` names it, else the pack's verb does.
function assembly.next(label: string?): { [string]: any }
    return { label = label, group = "lunatic/tfs:ui.look.next" }
end

-- A step back down the ladder, listed after the steps forward.
function assembly.back(label: string?): { [string]: any }
    return { label = label, group = "lunatic/tfs:ui.look.back", order = 1 }
end

-- Wired, boarded, screwed together, every rung running backwards. Only a bare
-- frame comes apart under a torch, so nobody burns a coil of cable by accident
-- (tg's machine_frame.dm). `metal` is what the torch gives back.
function assembly.board_frame(words: FrameWords): { { [string]: any } }
    return {
        {
            sound = "smash",
            at = "empty",
            with = { cable_coil = 5 },
            hint = assembly.next("lunatic/tfs:ui.affordance.wire_frame"),
            secs = 2.0,
            to = "wired",
            start = "You start wiring the frame.",
            done = "The frame is wired.",
        },
        {
            sound = "smash",
            at = "empty",
            tool = "welder",
            hint = assembly.back("lunatic/tfs:ui.affordance.dismantle_frame"),
            secs = 4.0,
            fuel = 0.3,
            yields = { metal = words.metal },
            gone = true,
            start = words.cut_start,
            done = words.cut_done,
        },
        {
            sound = "smash",
            at = "wired",
            tool = "cutters",
            hint = assembly.back(),
            secs = 2.0,
            yields = { cable_coil = 5 },
            to = "empty",
            start = "You start cutting the wiring out.",
            done = "The wiring comes free.",
        },
        -- Any item with a board table fits.
        {
            sound = "smash",
            at = "wired",
            slot = "board",
            hint = assembly.next(),
            to = "boarded",
            done = "The board clicks into place.",
        },
        -- Whatever the board asks for goes in after it, one unit at a time
        -- (tg's `req_components`, machine_frame.dm); the refusal reads the
        -- list out when something is missing or unwanted.
        {
            sound = "smash",
            at = "boarded",
            slot = "part",
            hint = assembly.next(),
            done = "It clicks into the assembly.",
        },
        -- The crowbar takes the board AND everything fitted after it: one
        -- assembly coming apart, not two steps (tg's
        -- `default_deconstruction_crowbar`).
        {
            sound = "smash",
            at = "boarded",
            tool = "crowbar",
            hint = assembly.back(),
            eject = "board",
            to = "wired",
            done = "You pry the board back out.",
        },
        {
            sound = "smash",
            at = "boarded",
            tool = "screwdriver",
            hint = assembly.next(),
            secs = 4.0,
            finish = true,
            start = "You start screwing the assembly together.",
            done = words.closed,
        },
    }
end

return assembly
