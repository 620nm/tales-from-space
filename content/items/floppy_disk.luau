-- A 3.5-inch diskette: a sleeve of plastic with a store of named text
-- inside it, and no way to read one in your hand. It is the whole of
-- what this station has for carrying a file from one machine to
-- another -- pocket it, walk, put it in a drive.
--
-- THE NUMBERS ARE THE REAL DISK. 737,280 bytes is a double-density
-- 3.5" floppy formatted at 80 tracks, 9 sectors, two sides, 512 bytes
-- a sector; 112 is FAT12's root-directory entry limit on that format,
-- which is why a disk with room left on it can still refuse a file.
-- Neither number is tg's -- tg's disks are 16/64/256 "GQ"
-- (code/modules/modular_computers/computers/item/disks/computer_disk.dm:4,49-59)
-- and it counts no entries at all. These are the ones the fiction is
-- actually about, and the engine's own ceilings are exactly them
-- (docs/CONTENT-SCHEMA.md 1.10d), so this is the largest medium the
-- substrate can carry as well as the largest one that ever existed.
--
-- No `drive` block and no `ui`: a store is read at the terminal it is
-- fitted in. Reading one in a pocket would be a second gesture, and
-- there is nothing in a hand to read it WITH.
return {
    id = "floppy_disk",
    name = "floppy disk",
    -- tg's `/obj/item/disk` off `icons/obj/devices/floppy_disks.dmi`,
    -- `icon_state = "datadisk3"` -- the black sleeve
    -- (code/game/objects/items/floppy_disk.dm:41-45).
    sprite = "floppy_disk",
    examine = {
        flavor = "Nine centimetres of hard plastic around a disc of "
            .. "something softer. The shutter slides back under a "
            .. "thumbnail, which is the last thing anybody should be "
            .. "doing to it.",
    },
    -- Not a shortcut: tg's disk declares `inhand_icon_state = "card-id"`
    -- against the idcard hand sheets (floppy_disk.dm:46-48), which is
    -- the same cell the pack's id cards already bake
    -- (assets/sprites/30-inhand-and-worn.ron). A flat rectangle held
    -- between finger and thumb is a flat rectangle either way.
    inhand_sprite = { "held_id_l", "held_id_r" },
    files = { capacity = 737280, files = 112 },
}
