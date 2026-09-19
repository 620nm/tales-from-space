-- What settled dust looks like on the deck: the engine-facing half of
-- lib/residue_kinds.luau. Kind 0 is the engine's settled-fragment
-- number; the ladder and the layer below are this pack's answer for
-- it. A single blast dusts, a second one on the same tile cakes, and
-- a tile swept clean draws nothing at all.
local residue_kinds = require("@lib/residue_kinds")

return {
    visual_layer = "residue",
    kinds = {
        [residue_kinds.dust_kind] = { tiers = residue_kinds.tiers },
    },
}
