-- tg storage/boxes/science_boxes.dm:27-34 supplies eight floppy disks,
-- one of each sleeve colour. The pack supplies them unpackaged, in a
-- rainbow; ordinary storage owns all handling.
return {
    id = "disk_box",
    name_label = "lunatic/tfs:entity.disk_box.name",
    name = "box of disks",
    sprite = "disk_box",
    inhand_sprite = { "held_disk_box_l", "held_disk_box_r" },
    storage = 8,
    holds = {
        "floppy_disk.red", "floppy_disk.yellow", "floppy_disk.green",
        "floppy_disk.light_blue", "floppy_disk.dark_blue",
        "floppy_disk.purple", "floppy_disk.grey", "floppy_disk",
    },
}
