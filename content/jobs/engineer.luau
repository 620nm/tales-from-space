-- Keep the power on, patch the hull (the essence's own example).
--
-- The tools ride the BELT, as tg's engineer outfit has them
-- (station_engineer.dm:48, `belt = /obj/item/storage/belt/utility/
-- full/engi`) — the toolbelt's own `holds` roster is the tool suite,
-- and it shows what it carries. The backpack keeps the bulky stock a
-- belt has no business holding.
return {
    id = "engineer",
    name = "Station Engineer",
    -- Breathing gear, on every outfit (job_boxes.dm:4-45). The bottle
    -- goes at the END of the kit: a pack row is a row a player clicks,
    -- and issuing everybody a new first item would move every other
    -- one out from under them.
    -- What the kit arrives in, worn on the back. The engine used to
    -- mint a pack by name and slip a headset in beside the kit; both
    -- are the station's business, so both are spelled here.
    outfit = {
        { slot = "uniform", item = "uniform_eng" },
        { slot = "id", item = "id_engineering" },
        { slot = "belt", item = "toolbelt" },
        { slot = "mask", item = "breath_mask" },
        { slot = "back", item = "backpack", contents = {
            "metal", "floor_tile", "emergency_tank.oxygen", "headset",
        } },
    },
}
