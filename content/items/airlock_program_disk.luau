-- The fixed source is copied before editing; only the installed guest controls a cycle.
return {
    id = "airlock_program_disk",
    name_label = "lunatic/tfs:entity.airlock_program_disk.name",
    name = "airlock program disk", sprite = "floppy_disk",
    inhand_sprite = { "held_id_l", "held_id_r" },
    hint_tags = { "floppy" },
    files = { capacity = 737280, files = 112,
        seed = {
            { reference = "airlock_controller" },
            { reference = "airlock_instructions" },
        },
    },
}
