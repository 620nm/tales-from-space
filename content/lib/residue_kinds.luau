-- The two things a blast leaves on the deck.
--
-- Shards are engine residue where pellets came DOWN: spent fragments at
-- rest as counts on tiles, not things (the engine's
-- docs/physics/residue.md). Kind 0 is the engine's settled-fragment
-- number; this pack dresses its first tier as debris shards and lays
-- one deposit per landing tile off the settle signals
-- (items/weapons/frag_grenade.luau). Cloudy is engine residue where the
-- blast WENT OFF: fallout scattered over the nine blast tiles at
-- detonate time (lib/blast.luau). Kind 1 is the engine's
-- settled-fallout number; this pack dresses its first tier as a dust
-- puff. Ash is matter: the ash substance minted onto the blast tile,
-- riding the ordinary matter ledger and the powder art. One file owns
-- all three so the grenade, the appearances roster and the mop cannot
-- disagree about what a blast left.
--
-- PELLETS_PER_VOLLEY is the volley count (lib/blast.luau) and
-- CLOUDY_PER_BLAST the blast area's share: fifteen pellets in the air,
-- fifteen fallout over the nine tiles, the ring dusted a fragment each
-- and the rest heaped on the center. The two fifteens are coincidence,
-- not conservation -- strikes spend pellets on bodies and leave no
-- shards, so what rests is what landed, not what flew. The heavy tiers
-- sit past two blasts, so one detonation dusts and only repeated
-- pounding of the same tiles cakes.
local residue_kinds = {
    shard_kind = 0,
    cloudy_kind = 1,
    pellets_per_volley = 15,
    cloudy_per_blast = 15,
    shard_tiers = {
        { at = 1, sprites = { "blast_shards" } },
        {
            at = 32,
            sprites = { "dirt_flat_0", "dirt_flat_1", "dirt_flat_2", "dirt_flat_3" },
        },
    },
    cloudy_tiers = {
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
