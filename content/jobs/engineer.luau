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
    uniform = "uniform_eng",
    id_card = "id_engineering",
    belt = "toolbelt",
    -- Breathing gear, on every outfit (job_boxes.dm:4-45). The bottle
    -- goes at the END of the kit: a pack row is a row a player clicks,
    -- and issuing everybody a new first item would move every other
    -- one out from under them.
    mask = "breath_mask",
    kit = { "metal", "floor_tile", "emergency_oxygen" },
}
