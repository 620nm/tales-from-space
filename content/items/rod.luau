-- Metal rods. Two of them weave a grille, which is the skeleton every
-- window hangs in.
return {
    id = "rod",
    name = "metal rods",
    sprite = "rods",
    inhand_sprite = { "held_rods_l", "held_rods_r" },
    -- Picked up as rods, dropped as metal — tg's own asymmetry, and not
    -- an oversight here: there is no iron_rod_drop file to name
    -- (rods.dm:42-43).
    pickup_sound = "rod_pickup",
    drop_sound = "metal_drop",
    stack = 50,
}
