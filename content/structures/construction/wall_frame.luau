local assembly = require("@lib/assembly")

-- Two sheets bent into a box and screwed to a wall: the thing every
-- wall-mounted device on this station is before it is anything in
-- particular.
--
-- It is `machine_frame` for the wall, the same `assembly.board_frame`
-- ladder. What differs is the one thing that makes a mount a mount: `build.on` names what it HANGS ON rather than
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
-- tg hands its own hull back as the item it was (apc_tool_act.dm:384);
-- there is no frame ITEM here -- the sheets are the recipe -- so what the
-- torch gives back is the sheets.
return {
    id = "wall_frame",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.wall_frame.name",
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
            north = "wall_frame_n",
            south = "wall_frame_s",
            east = "wall_frame_e",
            west = "wall_frame_w",
        },
        wired = {
            north = "wall_frame_wired_n",
            south = "wall_frame_wired_s",
            east = "wall_frame_wired_e",
            west = "wall_frame_wired_w",
        },
        boarded = {
            north = "wall_frame_boarded_n",
            south = "wall_frame_boarded_s",
            east = "wall_frame_boarded_e",
            west = "wall_frame_boarded_w",
        },
    },
    build = {
        sound = "smash",
        on = { "component:wall", "component:reinforced_wall" },
        with = { metal = 2 },
        secs = 4.0,
        start = "You start bolting a frame to the wall.",
        done = "The frame is screwed to the wall.",
    },
    examine = {
        flavor = "An empty box bolted to the wall, waiting for somebody to "
            .. "decide what it is.",
    },
    transitions = assembly.board_frame({
        metal = 2,
        cut_start = "You start cutting the frame off the wall.",
        cut_done = "The frame comes off the wall.",
        closed = "The panel closes over it.",
    }),
}
