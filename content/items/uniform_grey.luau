return {
    id = "uniform_grey",
    name = "grey jumpsuit",
    sprite = "uniform_grey",
    slot = "uniform",
    -- A jumpsuit covers the torso, groin, arms and legs (tg
    -- body_parts_covered = CHEST|GROIN|LEGS|ARMS,
    -- clothing/under/_under.dm:8); the head is bare. An operation on a
    -- covered zone needs it stripped first (docs/SURGERY.md).
    covers = { "chest", "pelvis", "l_arm", "r_arm", "l_leg", "r_leg" },
    worn_sprite = "worn_uniform_grey",
    -- Cloth, on every jumpsuit. tg _under.dm:15-16.
    pickup_sound = "cloth_pickup",
    drop_sound = "cloth_drop",
}
