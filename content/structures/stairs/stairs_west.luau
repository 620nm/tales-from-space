-- tg /obj/structure/stairs/west (stairs.dm:46-47): a flight whose way up
-- is west. Its climb is the composition's (content/compositions.luau).
-- Building one from a stairs frame (stairs.dm:369-474) is not ported.
return {
    id = "stairs_west",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.stairs.name",
    name = "stairs",
    sprite = "stairs_w",
    dense = false,
    turf = "component:stairs_west",
}
