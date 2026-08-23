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
    -- What the kit arrives in, worn on the back. The engine used to
    -- mint a pack by name and slip a headset in beside the kit; both
    -- are the station's business, so both are spelled here.
    kit_container = "backpack",
    kit = { "emergency_oxygen", "headset" },
}
