-- A boulder. tg's `/obj/structure/flora/rock` (code/game/objects/structures/flora.dm:1027-1041):
-- dense (:1032) and bolted where it lies (`anchored`, :6; `can_uproot = FALSE`, :1039),
-- and sets no `opacity`, so sight passes it. The art is greyscale; `color` tints it,
-- basalt's colour by default (substances/ground/basalt.luau), and a map may override it.
--
-- WHAT IS NOT PORTED: mining it for basalt (`harvest_verb = "mine"`, :1037,
-- `get_potential_products`, :1042-1043) and its integrity.
return {
    id = "outcrop",
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.outcrop.name",
    name = "boulder",
    sprite = "prop_rough_outcrop_2",
    dense = true,
    opaque = false,
    color = "#5E626E",
    examine = { flavor = "A craggy boulder of dark stone." },
    variants = {
        -- tg's rock styles differ only in art (flora.dm:1045-1052).
        cluster = {
            name_label = "lunatic/tfs:entity.outcrop.cluster.name",
            name = "rock cluster",
            sprite = "prop_rough_outcrop_1",
            examine = { flavor = "A cluster of weathered fieldstones." },
        },
    },
}
