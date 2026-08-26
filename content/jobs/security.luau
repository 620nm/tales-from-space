-- Robust. The stun baton arrives with the combat gate; until then, a
-- security officer is a toolbox with a warrant.
return {
    id = "security",
    name = "Security Officer",
    slots = 1,
    -- Breathing gear, on every outfit (job_boxes.dm:4-45). The bottle
    -- goes at the END of the kit: a pack row is a row a player clicks,
    -- and issuing everybody a new first item would move every other
    -- one out from under them.
    -- What the kit arrives in, worn on the back. The engine used to
    -- mint a pack by name and slip a headset in beside the kit; both
    -- are the station's business, so both are spelled here.
    outfit = {
        { slot = "uniform", item = "uniform_sec" },
        { slot = "id", item = "id_security" },
        { slot = "mask", item = "breath_mask" },
        { slot = "back", item = "backpack", contents = {
            "toolbox", "emergency_tank.oxygen", "headset",
        } },
    },
}
