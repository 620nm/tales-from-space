return {
    id = "medic",
    name = "Medical Doctor",
    slots = 1,
    -- Breathing gear, on every outfit (job_boxes.dm:4-45). The bottle
    -- goes at the END of the kit: a pack row is a row a player clicks,
    -- and issuing everybody a new first item would move every other
    -- one out from under them.
    -- A roll of surgical tools rides at the waist (docs/SURGERY.md §6).
    -- What the kit arrives in, worn on the back. The engine used to
    -- mint a pack by name and slip a headset in beside the kit; both
    -- are the station's business, so both are spelled here.
    outfit = {
        { slot = "uniform", item = "uniform_med" },
        { slot = "id", item = "id_medical" },
        { slot = "mask", item = "breath_mask" },
        { slot = "belt", item = "surgical_kit" },
        -- The syringe rides at the END for the same reason the bottle
        -- does: a pack row is a row a player clicks, and issuing
        -- everybody a new first item would move every other one out
        -- from under them. tg's medical kit carries one too
        -- (`/obj/item/storage/backpack/duffelbag/med`, and the syringe
        -- is what makes the libital beaker a DOSE rather than a drink).
        { slot = "back", item = "backpack", contents = {
            "beaker.libital", "emergency_oxygen", "headset", "syringe",
        } },
    },
}
