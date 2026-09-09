-- tg storage/boxes/science_boxes.dm:27-34 supplies eight floppy disks.
-- The pack supplies them unpackaged; ordinary storage owns all handling.
return {
    id = "disk_box",
    name_label = "lunatic/tfs:entity.disk_box.name",
    name = "box of disks",
    sprite = "disk_box",
    inhand_sprite = { "held_disk_box_l", "held_disk_box_r" },
    storage = 8,
    holds = {
        "floppy_disk", "floppy_disk", "floppy_disk", "floppy_disk",
        "floppy_disk", "floppy_disk", "floppy_disk", "floppy_disk",
    },
}
