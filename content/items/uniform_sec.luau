return {
    id = "uniform_sec",
    name = "security jumpsuit",
    sprite = "uniform_sec",
    slot = "uniform",
    -- A jumpsuit covers the torso, arms and legs (tg body_parts_covered,
    -- clothing/under/_under.dm:8); the head is bare. An operation on a
    -- covered zone needs it stripped first (docs/SURGERY.md).
    covers = { "chest", "l_arm", "r_arm", "l_leg", "r_leg" },
    worn_sprite = "worn_uniform_sec",
    -- Cloth, on every jumpsuit. tg _under.dm:15-16.
    pickup_sound = "cloth_pickup",
    drop_sound = "cloth_drop",
}
