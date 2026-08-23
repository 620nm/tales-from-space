return {
    id = "medic",
    name = "Medical Doctor",
    slots = 1,
    uniform = "uniform_med",
    id_card = "id_medical",
    -- Breathing gear, on every outfit (job_boxes.dm:4-45). The bottle
    -- goes at the END of the kit: a pack row is a row a player clicks,
    -- and issuing everybody a new first item would move every other
    -- one out from under them.
    mask = "breath_mask",
    -- A roll of surgical tools rides at the waist (docs/SURGERY.md §6).
    belt = "surgical_kit",
    kit = { "beaker_libital", "emergency_oxygen" },
}
