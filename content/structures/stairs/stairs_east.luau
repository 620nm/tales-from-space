-- tg /obj/structure/stairs/east (stairs.dm:43-44): a flight whose way up
-- is east. Its climb is the composition's (content/compositions.luau).
-- Building one from a stairs frame (stairs.dm:369-474) is not ported.
return {
    id = "stairs_east",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.stairs.name",
    name = "stairs",
    sprite = "stairs_e",
    dense = false,
    turf = "component:stairs_east",
}
