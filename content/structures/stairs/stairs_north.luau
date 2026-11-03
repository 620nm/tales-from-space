-- tg /obj/structure/stairs/north (stairs.dm:37-38): a flight whose way up
-- is north. Its climb is the composition's (content/compositions.luau).
-- Building one from a stairs frame (stairs.dm:369-474) is not ported.
return {
    id = "stairs_north",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.stairs.name",
    name = "stairs",
    sprite = "stairs_n",
    dense = false,
    turf = "component:stairs_north",
}
