-- A cartridge carrying thirty monochrome print charges.
-- tg photocopier.dm:879-887 supplies the source item and charge gauge.
return {
    id = "toner_cartridge",
    visual_layer = "entities",
    held_visual_layer = "held",
    name_label = "lunatic/tfs:entity.toner_cartridge.name",
    name = "toner cartridge",
    sprite = "toner_cartridge",
    hint_tags = { "toner_source" },
    resources = { toner = { capacity = 30, initial = 30 } },
}
