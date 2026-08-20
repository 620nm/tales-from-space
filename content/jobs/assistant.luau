-- The classic: no access, no duties, unlimited slots, infinite schemes.
return {
    id = "assistant",
    name = "Assistant",
    uniform = "uniform_grey",
    id_card = "id_assistant",
    -- Apparatus on the face and a pocket bottle in the pack, on this
    -- job and on every other one in this directory: tg gives EVERY
    -- outfit the survival box (code/game/objects/items/storage/boxes/
    -- job_boxes.dm:4-45), and a station where only some of the crew can
    -- breathe through a breach has a job that is a death sentence.
    mask = "breath_mask",
    kit = { "emergency_oxygen" },
}
