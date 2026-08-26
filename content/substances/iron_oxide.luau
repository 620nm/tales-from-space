-- Iron oxide: rust, and thermite's oxidiser.
--
-- tg's thermite recipe is aluminium + iron + OXYGEN
-- (pyrotechnics.dm:214-217), which read as moles is a bench holding a
-- permanent gas in an open beaker -- something a source can no longer
-- hand over, because what it deposited would leave through the same
-- mouth (D19). Real thermite has never taken loose oxygen anyway: it
-- takes an oxide, and the classic one is Fe2O3. So the oxidiser gets
-- an id of its own and a button beside iron's, and
-- reactions/thermite.luau names it.
--
-- Fe2O3: real molar mass 159.69 g/mol, real density 5.24 g/mL, molar
-- heat capacity 103.9 J/(mol*K) -- five atoms times Dulong-Petit's
-- 3R is 124, and the measured figure is a little under that, which is
-- what an oxide does. `unmodeled = "solid"` by D2: it melts at 1839 K,
-- which no bench reaches, so a curve here would answer a question
-- nobody asked (docs/CHEMISTRY.md, D2).
--
-- tg has no reagent for it; this is a DEPARTURE, taken so that a
-- recipe standing on gaseous oxygen has something a beaker can hold.
return {
    id = "iron_oxide",
    name = "iron oxide",
    molar_mass = 159.7,
    cv = 104.0,
    phase = { unmodeled = "solid" },
    density = { solid = 5.24 },
    -- Rust, which is what it is. tg's own iron is #606060
    -- (other_reagents.dm:1207); this is the oxide beside it.
    color = "#8B4513",
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel): a bench reagent, not
    -- something a room is commissioned full of.
    relevance = 0,
}
