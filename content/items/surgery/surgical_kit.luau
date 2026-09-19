local physical_profiles = require("@lib/physical_profiles")
-- The medic's roll of surgical tools (tg's surgical tray/belt). A belt
-- container, filled at spawn. Reuses the toolbelt picture for now.
return {
    id = "surgical_kit",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.surgical_kit.name",
    name = "surgical kit",
    sprite = "toolbelt",
    slot = "belt",
    storage = 8,
    show_contents = false,
    holds = {
        "scalpel",
        "hemostat",
        "retractor",
        "cautery",
        "circular_saw",
        "surgical_drill",
        "bone_gel",
        "suture",
    },
}
