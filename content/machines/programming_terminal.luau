-- The programming terminal: a console with a disk slot in the front of
-- it and just enough memory to be worth arguing over.
--
-- Almost no content. What this machine DOES -- take a disk, list what
-- is on it beside what is on itself, open one, let somebody type into
-- it, copy between the two -- is the file store and the media slot,
-- and both are mechanism (docs/CONTENT-SCHEMA.md 1.10d, docs/TGUI.md's
-- files module). What is content is the whole of this file: what it is
-- called, what it looks like, what it will read, and how much of its
-- own it can hold.
--
-- `drive = {}` with no `reads` list, deliberately. This is the general
-- terminal -- the one that opens everything the station recognises --
-- and a machine that reads only some of the roster is a machine with a
-- reason to be narrow. There is not one here yet.
--
-- WHY THE INTERNAL STORE IS SMALL. 64 KiB and sixteen entries against
-- a disk's 720 KiB and 112: the terminal is scratch space and the
-- floppy is the thing you carry. A crewman who wants to keep work
-- keeps it on a disk in a pocket, which is the whole reason a disk is
-- worth stealing. It also keeps the listing short enough to draw --
-- the panel sends every entry it can reach in one document, and two
-- maximal stores in one window is a lot of paper for one console.
return {
    id = "programming_terminal",
    name = "programming terminal",
    -- tg's R&D console, composited the way tg draws every console: the
    -- frame's own `icon_state`, the keyboard over it, the screen over
    -- that (code/game/machinery/computer/_computer.dm:67-85). The two
    -- states are the R&D console's own -- `icon_screen = "rdcomp"`,
    -- `icon_keyboard = "rd_key"`
    -- (code/modules/research/rdconsole.dm:22-24) -- which is tg's disk
    -- console: the one machine there with a floppy in the front of it
    -- (its `t_disk` and `d_disk`, rdconsole.dm:28-31).
    sprite = "programming_terminal",
    examine = {
        flavor = "A console with a slot under the screen and a hinged "
            .. "flap over it. Somebody has written a filename on the "
            .. "flap in grease pencil and then crossed it out.",
    },
    ui = { modules = { "files" }, opens_on_click = true },
    dense = true,
    corded = true,
    -- Everything the pack declares. A terminal that could not read a
    -- word somebody's disk is written in would be a terminal you carry
    -- the disk PAST.
    drive = {},
    -- Scratch space, not a filing cabinet. See the header.
    files = { capacity = 65536, files = 16 },
    -- The two generic rungs every finished machine has: a screwdriver
    -- opens the panel, a crowbar pries it apart, and what is left
    -- standing is the frame it was screwed together from, holding the
    -- board and everything in the sockets (docs/CONSTRUCTION.md).
    teardown = {
        open = "screwdriver",
        remove = "crowbar",
        into = "machine_frame",
        state = "boarded",
    },
}
