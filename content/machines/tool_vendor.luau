-- The tool vendor, standing beside the softdrinks machine because an
-- engineer who has lost a crowbar should not have to walk to the
-- Annex for another one.
--
-- tg: /obj/machinery/vending/tool ("YouTool", vending/youtool.dm) is
-- the ordinary-tool baseline. TfS folds the rest of its implemented
-- repair kit into the same free shelf: tg puts light tubes in the Robco
-- Tool Maker (vending/engineering.dm), light replacers in JaniDrobe
-- (vending/wardrobes.dm), and keeps the RPD in engineering lockers
-- (closets/secure/engineering.dm). One machine here makes every tool
-- that exists in this smaller game recoverable. tg's t-scanner,
-- flashlights, glowsticks and earmuffs remain absent because this pack
-- has no prototypes for them.
--
-- It shares `script = "vendor"` with the softdrinks machine: opening
-- a window on click and wobbling when bumped is the behaviour of a
-- vending machine, not of any particular one.
return {
    id = "tool_vendor",
    name = "YouTool vending machine",
    sprite = "tool_vendor",
    ui = { modules = { "shelf" }, opens_on_click = false },
    dense = true,
    script = "vendor",
    corded = true,
    ad = "Tools for tools.",
    categories = { "Tools", "Parts", "Media" },
    vends = {
        { item = "cable_coil", name = "Cable Coil", category = "Tools", amount = 10 },
        { item = "crowbar", name = "Crowbar", category = "Tools", amount = 5 },
        { item = "welder", name = "Welding Tool", category = "Tools", amount = 3 },
        { item = "wirecutters", name = "Wirecutters", category = "Tools", amount = 5 },
        { item = "wrench", name = "Wrench", category = "Tools", amount = 5 },
        { item = "analyzer", name = "Analyzer", category = "Tools", amount = 5 },
        { item = "screwdriver", name = "Screwdriver", category = "Tools", amount = 5 },
        { item = "multitool", name = "Multitool", category = "Tools", amount = 4 },
        { item = "rpd", name = "Rapid Pipe Dispenser", category = "Tools", amount = 2 },
        { item = "pipe_painter", name = "Pipe Painter", category = "Tools", amount = 2 },
        { item = "light_replacer", name = "Light Replacer", category = "Tools", amount = 2 },
        { item = "light_bulb", name = "Light Bulb", category = "Tools", amount = 10 },
        { item = "light_tube", name = "Light Tube", category = "Tools", amount = 10 },
        { item = "toolbelt", name = "Toolbelt", category = "Tools", amount = 2 },
        { item = "toolbox", name = "Mechanical Toolbox", category = "Tools", amount = 2 },
        { item = "box_lights", name = "Box of Replacement Lights", category = "Tools", amount = 2 },
        -- STOCK PARTS, on tg's own authority: the Robco Tool Maker
        -- stocks `micro_laser = 5` and `matter_bin = 5`
        -- (vending/engineering.dm:29-30), which is the same folding-in
        -- this file already does for tubes and replacers. The other
        -- three kinds are the same fold again: tg prints every stock
        -- part at a lathe, and until one exists the shelf is where a
        -- machine's insides come from.
        --
        -- THE PLAIN RUNG ONLY. Each of these is tier one of four
        -- (lib/stock_parts.luau); a better one is something you FIND,
        -- because a shelf that sells the top of the ladder for nothing
        -- is a ladder with no rungs.
        { item = "matter_bin", name = "Matter Bin", category = "Parts", amount = 5 },
        { item = "micro_laser", name = "Micro-Laser", category = "Parts", amount = 5 },
        { item = "capacitor", name = "Capacitor", category = "Parts", amount = 5 },
        { item = "servo", name = "Micro-Servo", category = "Parts", amount = 5 },
        { item = "scanning_module", name = "Scanning Module", category = "Parts", amount = 5 },
        -- The network card is the same fold again, and the sixth kind
        -- of stock part: nothing in tg prints one, because nothing in
        -- tg is a device network. It sits on an open shelf rather than
        -- behind a claim because an address is an identifier and never
        -- a credential (docs/DEVICES.md §1) -- there is nothing here to
        -- gate. What a card buys is a place on a network that somebody
        -- standing at a locked panel still has to let you join.
        { item = "network_card", name = "Network Card", category = "Parts", amount = 5 },
        -- The boards are NOT tg's vendor stock: circuit boards come off
        -- a departmental techfab, and this pack has no lathe of any
        -- kind. Until one exists the shelf is where the engineering
        -- boards remain obtainable. The chemistry boards belong to
        -- NanoMed Plus (machines/nanomed_plus.luau), not an engineering
        -- machine.
        {
            item = "machine_board.thermomachine",
            name = "Machine Board (Temperature Control Unit)",
            category = "Parts",
            amount = 2,
        },
        {
            item = "machine_board.access_point",
            name = "Machine Board (Access Point)",
            category = "Parts",
            amount = 2,
        },
        -- tg stocks its air alarm electronics on the engineering vendor
        -- too, ten deep (code/modules/vending/engivend.dm:17). Two here,
        -- which is what every board on this shelf comes in.
        {
            item = "machine_board.air_alarm",
            name = "Machine Board (Air Alarm)",
            category = "Parts",
            amount = 2,
        },
        {
            item = "machine_board.network_router",
            name = "Machine Board (Network Router)",
            category = "Parts",
            amount = 2,
        },
        {
            item = "machine_board.transceiver",
            name = "Machine Board (Transceiver)",
            category = "Parts",
            amount = 2,
        },
        -- The encryption keys, blank and all five words, on the same
        -- no-lathe argument as the boards above them: a shipped world
        -- must be able to key a tower it built, and a channel word is
        -- fiction rather than a credential -- what the word is worth
        -- is decided by who carries radios on it, not by who may buy
        -- the key (the network card's own argument, one shelf up).
        { item = "encryption_key", name = "Encryption Key (blank)", category = "Parts", amount = 5 },
        { item = "encryption_key.common", name = "Encryption Key (Common)", category = "Parts", amount = 3 },
        { item = "encryption_key.engineering", name = "Encryption Key (Wrench)", category = "Parts", amount = 2 },
        { item = "encryption_key.medical", name = "Encryption Key (Lifeline)", category = "Parts", amount = 2 },
        { item = "encryption_key.security", name = "Encryption Key (Watchline)", category = "Parts", amount = 2 },
        { item = "encryption_key.command", name = "Encryption Key (Charter)", category = "Parts", amount = 2 },
        {
            item = "machine_board.programming_terminal",
            name = "Machine Board (Programming Terminal)",
            category = "Parts",
            amount = 2,
        },
        -- BLANK MEDIA, which is the same fold this file already does
        -- for light tubes and stock parts: nothing in tg vends a floppy
        -- disk, because tg prints its disks at a techfab and this pack
        -- has no lathe of any kind. Until one exists the shelf is where
        -- a blank comes from, and a terminal with nothing to put in it
        -- is a terminal with 64 KiB of memory and no way to leave the
        -- room with what you wrote.
        --
        -- Its own category rather than a third row under Tools: a disk
        -- is neither a tool nor something a frame is built out of, and
        -- the derivation that would have guessed for it
        -- (README.md, "Palette categories") reads FIELDS, which is
        -- exactly the fact that a store is not a `tool` block.
        { item = "floppy_disk", name = "Floppy Disk", category = "Media", amount = 8 },
    },
}
