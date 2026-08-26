-- The captain: one per shift, and every door on the station knows it.
return {
    id = "captain",
    name = "Captain",
    slots = 1,
    -- Breathing gear, on every outfit (job_boxes.dm:4-45). The bottle
    -- goes at the END of the kit: a pack row is a row a player clicks,
    -- and issuing everybody a new first item would move every other
    -- one out from under them.
    -- What the kit arrives in, worn on the back. The engine used to
    -- mint a pack by name and slip a headset in beside the kit; both
    -- are the station's business, so both are spelled here.
    outfit = {
        { slot = "uniform", item = "uniform_cap" },
        { slot = "id", item = "id_captain" },
        { slot = "mask", item = "breath_mask" },
        { slot = "back", item = "backpack", contents = { "emergency_tank.oxygen", "headset" } },
    },
}
