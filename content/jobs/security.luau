-- Robust. The stun baton arrives with the combat gate; until then, a
-- security officer is a toolbox with a warrant.
return {
    id = "security",
    name = "Security Officer",
    slots = 1,
    uniform = "uniform_sec",
    id_card = "id_security",
    -- Breathing gear, on every outfit (job_boxes.dm:4-45). The bottle
    -- goes at the END of the kit: a pack row is a row a player clicks,
    -- and issuing everybody a new first item would move every other
    -- one out from under them.
    mask = "breath_mask",
    kit = { "toolbox", "emergency_oxygen" },
}
