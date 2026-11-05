-- Every crew job's kit, in one place: the job files issue it (`jobs/*.luau`
-- `outfit`) and the cadaver stock dresses the station's dead in it
-- (`lib/cadaver_stock.luau`).
--
-- Breathing gear, on every outfit: tg gives EVERY outfit the survival box
-- (code/game/objects/items/storage/boxes/job_boxes.dm:4-45), and a station
-- where only some of the crew can breathe through a breach has a job that is
-- a death sentence. The bottle goes at the END of the kit: a pack row is a
-- row a player clicks, and issuing everybody a new first item would move
-- every other one out from under them. What the kit arrives in, worn on the
-- back, and the headset in it are the station's business, spelled here.

export type OutfitRow = { slot: string, item: string, contents: { string }? }

local crew_outfits = {}

crew_outfits.assistant = {
    { slot = "uniform", item = "uniform_grey" },
    { slot = "id", item = "id_assistant" },
    { slot = "mask", item = "breath_mask" },
    { slot = "back", item = "backpack", contents = { "emergency_tank.oxygen", "headset" } },
} :: { OutfitRow }

crew_outfits.captain = {
    { slot = "uniform", item = "uniform_cap" },
    { slot = "id", item = "id_captain" },
    { slot = "mask", item = "breath_mask" },
    { slot = "back", item = "backpack", contents = { "emergency_tank.oxygen", "headset" } },
} :: { OutfitRow }

-- The tools ride the BELT, as tg's engineer outfit has them
-- (station_engineer.dm:48, `belt = /obj/item/storage/belt/utility/full/engi`):
-- the toolbelt's own `holds` roster is the tool suite, and it shows what it
-- carries. The backpack keeps the bulky stock a belt has no business holding.
crew_outfits.engineer = {
    { slot = "uniform", item = "uniform_eng" },
    { slot = "id", item = "id_engineering" },
    { slot = "belt", item = "toolbelt" },
    { slot = "mask", item = "breath_mask" },
    {
        slot = "back",
        item = "backpack",
        contents = {
            "metal",
            "floor_tile",
            "emergency_tank.oxygen",
            "headset",
        },
    },
} :: { OutfitRow }

-- A roll of surgical tools rides at the waist (docs/SURGERY.md §6). The
-- analyzer is appended without moving the syringe row: tg puts a surgical
-- medkit in the doctor's left hand
-- (`code/modules/jobs/job_types/medical_doctor.dm:54`), and that kit contains
-- a health analyzer (`code/game/objects/items/storage/medkit.dm:80-94`).
crew_outfits.medic = {
    { slot = "uniform", item = "uniform_med" },
    { slot = "id", item = "id_medical" },
    { slot = "mask", item = "breath_mask" },
    { slot = "belt", item = "surgical_kit" },
    {
        slot = "back",
        item = "backpack",
        contents = {
            "beaker.libital",
            "emergency_tank.oxygen",
            "headset",
            "syringe",
            "health_analyzer",
        },
    },
} :: { OutfitRow }

crew_outfits.security = {
    { slot = "uniform", item = "uniform_sec" },
    { slot = "id", item = "id_security" },
    { slot = "mask", item = "breath_mask" },
    {
        slot = "back",
        item = "backpack",
        contents = {
            "toolbox",
            "emergency_tank.oxygen",
            "headset",
        },
    },
} :: { OutfitRow }

return crew_outfits
