-- Two sheets bent into a box and screwed to a wall: the thing every
-- wall-mounted device on this station is before it is anything in
-- particular.
--
-- It is `machine_frame` for the wall, and deliberately the same ladder
-- said in the same order -- wired, then boarded, then screwed together,
-- and every rung running backwards. What differs is the one thing that
-- makes a mount a mount: `build.on` names what it HANGS ON rather than
-- what it stands on, so a player clicks the WALL with the sheets in
-- hand and the box rises on their own tile, facing it
-- (docs/CONSTRUCTION.md, "What hangs on a wall").
--
-- tg's `/obj/item/wallframe` is the same statement made as an item you
-- carry: two sheets make an "apc frame"
-- (code/game/objects/items/stacks/sheets/sheet_types.dm:131), and
-- attaching it spawns the result on `get_turf(user)` wearing
-- `get_dir(user, support)` (wall_mounted.dm:61-90). Two sheets is
-- therefore tg's number; the four seconds are ours, because tg's stack
-- recipes are instant and nothing else in this pack's construction
-- ladder is.
--
-- FIVE LENGTHS OF CABLE, which is `machine_frame`'s number and not
-- tg's: tg wires an APC hull with ten (apc_tool_act.dm:96). Ten would
-- make the smallest box on the station cost twice what a whole machine
-- frame does, and the two frames in this pack answering "how much
-- cable is a frame" differently would be a number spelled twice.
--
-- The frame never learns what it is becoming: the board carries the
-- product and its parts list, so hanging a new kind of device costs
-- zero edits here.
return {
    id = "wall_frame",
    name = "wall frame",
    sprite = "wall_frame",
    mount = true,
    states = { "empty", "wired", "boarded" },
    state_sprites = {
        wired = "wall_frame_wired",
        boarded = "wall_frame_boarded",
    },
    -- A thing that hangs is seen from whichever side its wall is on, so
    -- every state brings its own four faces. Three states and one
    -- picture each would draw a box facing out of the wall it is
    -- screwed to.
    facing_sprites = {
        empty = {
            north = "wall_frame_n", south = "wall_frame_s",
            east = "wall_frame_e", west = "wall_frame_w",
        },
        wired = {
            north = "wall_frame_wired_n", south = "wall_frame_wired_s",
            east = "wall_frame_wired_e", west = "wall_frame_wired_w",
        },
        boarded = {
            north = "wall_frame_boarded_n", south = "wall_frame_boarded_s",
            east = "wall_frame_boarded_e", west = "wall_frame_boarded_w",
        },
    },
    build = {
        on = { "wall", "reinforced_wall" },
        with = { metal = 2 },
        secs = 4.0,
        start = "You start bolting a frame to the wall.",
        done = "The frame is screwed to the wall.",
    },
    examine = {
        flavor = "An empty box bolted to the wall, waiting for somebody to "
            .. "decide what it is.",
    },
    transitions = {
        {
            at = "empty",
            with = { cable_coil = 5 },
            secs = 2.0,
            to = "wired",
            start = "You start wiring the frame.",
            done = "The frame is wired.",
        },
        -- Only a bare frame comes off under a torch: wiring first, as
        -- the machine frame does, so nobody burns a coil's worth of
        -- cable by accident. tg hands its own hull back as the item it
        -- was (apc_tool_act.dm:384); there is no frame ITEM here -- the
        -- sheets are the recipe -- so what comes back is the sheets.
        {
            at = "empty",
            tool = "welder",
            secs = 4.0,
            fuel = 2.0,
            yields = { metal = 2 },
            gone = true,
            start = "You start cutting the frame off the wall.",
            done = "The frame comes off the wall.",
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
        -- Any item with a board table fits; what it makes is the
        -- board's business and not the frame's.
        {
            at = "wired",
            slot = "board",
            to = "boarded",
            done = "The board clicks into place.",
        },
        -- ...and whatever that board asks for goes in after it, one
        -- unit at a time. The refusal reads the list out when something
        -- is missing or unwanted, so the frame still learns nothing.
        {
            at = "boarded",
            slot = "part",
            done = "It clicks into the assembly.",
        },
        -- The crowbar takes the board AND everything fitted after it:
        -- one assembly coming apart rather than two steps.
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
            done = "The panel closes over it.",
        },
    },
}
