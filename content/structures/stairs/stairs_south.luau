-- tg /obj/structure/stairs/south (stairs.dm:40-41): a flight whose way up
-- is south. Its climb is the composition's (content/compositions.luau).
-- Building one from a stairs frame (stairs.dm:369-474) is not ported.
return {
    id = "stairs_south",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.stairs.name",
    name = "stairs",
    sprite = "stairs_s",
    dense = false,
    turf = "component:stairs_south",
}
