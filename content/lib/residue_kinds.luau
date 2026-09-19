-- The two things a blast leaves on the deck.
--
-- Dust is engine residue: spent fragments at rest as counts on tiles,
-- not things (the engine's docs/physics/residue.md). Kind 0 is the
-- engine's settled number; this pack dresses it as dust and lays one
-- blast's worth down per detonation. Ash is matter: the ash substance
-- minted onto the blast tile, riding the ordinary matter ledger and
-- the powder art. One file owns both so the grenade, the appearances
-- roster and the mop cannot disagree about what a blast left.
--
-- DUST_PER_BLAST is also the volley count (lib/blast.luau): what flies
-- is what rests. The heavy tier sits past one blast, so a single
-- detonation dusts and a second one on the same tile cakes.
local residue_kinds = {
    dust_kind = 0,
    dust_per_blast = 16,
    tiers = {
        { at = 1, sprites = { "dust" } },
        {
            at = 32,
            sprites = { "dirt_flat_0", "dirt_flat_1", "dirt_flat_2", "dirt_flat_3" },
        },
    },
    -- A quarter mole of ash is eleven millilitres of it (100 g/mol at
    -- 2.2 g/mL): over the powder profile's 1 mL tier, a visible grey
    -- dusting, and far too little to matter thermally either way.
    ash_moles = 0.25,
    -- Residue at rest is room temperature. There is no fire here to
    -- feed and none to start.
    ash_temp_k = 293.15,
}

return residue_kinds
