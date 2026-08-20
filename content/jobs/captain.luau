-- The captain: one per shift, and every door on the station knows it.
return {
    id = "captain",
    name = "Captain",
    slots = 1,
    uniform = "uniform_cap",
    id_card = "id_captain",
    -- Breathing gear, on every outfit (job_boxes.dm:4-45). The bottle
    -- goes at the END of the kit: a pack row is a row a player clicks,
    -- and issuing everybody a new first item would move every other
    -- one out from under them.
    mask = "breath_mask",
    kit = { "emergency_oxygen" },
}
