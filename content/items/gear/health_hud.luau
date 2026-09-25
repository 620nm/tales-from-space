local physical_profiles = require("@lib/physical_profiles")
-- The health scanner HUD: tg's /obj/item/clothing/glasses/hud/health
-- (code/modules/clothing/glasses/hud.dm:57-61), whose whole point is
-- clothing_traits = list(TRAIT_MEDICAL_HUD) -- the trait that grants
-- DATA_HUD_MEDICAL_ADVANCED (code/datums/hud.dm:30). Here the grant is
-- `reveals`: worn over the eyes, its wearer is sent the medhud display
-- (content/part_tree.luau).
--
-- No job starts in one: tg's doctor, paramedic and CMO outfits carry
-- none (code/modules/jobs/job_types/medical_doctor.dm:43-65,
-- paramedic.dm:43-72, chief_medical_officer.dm:56-87); tg stocks it in
-- the medical doctor's locker (crates_lockers/closets/secure/
-- medical.dm:39-45), which this pack does not have, so maps place it.
--
-- NOT PORTED: tg's glasses pickup/drop/equip sounds (_glasses.dm:15-17).
return {
    id = "health_hud",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.health_hud.name",
    name = "health scanner HUD",
    sprite = "health_hud",
    slot = "eyes",
    worn_sprite = "worn_health_hud",
    reveals = { "medhud" },
}
