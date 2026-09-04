-- Water: the one substance on the station that is solid, liquid and gas
-- all in the same file.
--
-- It is the only member of the ported roster with a FULL phase curve,
-- and that is the whole of what makes it interesting. Everything else
-- here is `gas_only` — tg models no condensation for any of its atmos
-- gases — so water is where the engine's melting, boiling, condensing
-- and freezing actually run.
--
-- Physics:
--   * molar mass 18.015 g/mol.
--   * cv per phase, three numbers rather than one: ice 38, liquid 75.3,
--     steam 40 J/(mol·K). The gas figure is tg's own `water_vapor`
--     specific heat (gas_types.dm), which is what lets a fire's
--     humidity warm at exactly tg's rate; the other two are water's.
--   * melts at 273.15 K, boils at 373.15 K, latent heats 6 010 and
--     40 660 J/mol. The engine derives the phase reference offsets from
--     these four numbers so a transition is energy-neutral and
--     temperature is continuous across it (docs/MATTER.md §4).
--   * densities 0.917 (ice) and 1.0 (liquid) g/mL, which is what makes
--     a puddle displace air in a sealed vessel.
--
-- **tg's seventh gas, `water_vapor`, is not here: it IS this file's gas
-- row.** tg needs a separate id because its gas mixtures and its
-- reagents are two unrelated systems that cannot name the same
-- substance; here one substance carries all three phases, so a twin
-- would be a second name for one molecule — two ids to filter for, two
-- rows on an analyser, and a fire whose humidity could never rain out
-- because the thing it made had no liquid phase.
--
-- tg: /datum/reagent/water, `color = "#AAAAAA77"` (other_reagents.dm:
-- 117). The trailing 77 is BYOND's alpha byte and is DROPPED: colour
-- here is a three-byte multiply with no alpha of its own
-- (crates/lunatic-core/src/color.rs), so water tints its fill the same
-- grey tg does and simply does not thin it.
--
-- `visible.tint` is STEAM: the colour water wears in its gas phase,
-- which is what a boiled beaker gives off and what a plasma fire makes.
-- Almost white with the faintest blue in it (0.90/0.93/0.97 in the old
-- renderer): fog reads as a thinning of the room rather than a colour
-- laid over it, which is the only way a hazard overlay can sit on top
-- of a corridor without hiding what is in it. Renderers ask per phase,
-- so a puddle is never mistaken for a cloud.
return {
    id = "water",
    name = "water",
    molar_mass = 18.015,
    cv = { solid = 38.0, liquid = 75.3, gas = 40.0 },
    phase = { melt = 273.15, boil = 373.15, l_fus = 6010.0, l_vap = 40660.0 },
    density = { solid = 0.917, liquid = 1.0 },
    color = "#AAAAAA",
    -- What water LOOKS LIKE on a deck (docs/chemistry/substances.md).
    -- A splash uses the shared blobs; a litre and fifty litres are tg's
    -- own river tiles, which move (assets/sprites/93-matter.ron).
    -- `tint = "#FFFFFF"` overrides the multiply for the liquid layer
    -- only: those tiles are already blue, and multiplying water's grey
    -- through them would grey out the one picture that came coloured.
    -- Ice keeps the shared crystalline silhouette and the grey.
    appearance = {
        liquid = { profile = "flowing", tint = "#FFFFFF" },
        solid = "crystalline",
    },
    visible = { moles = 0.25, factor = 20, tint = "#E6EDF7" },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel). Authored as vapour: a humid
    -- room, which condenses out on the first atmos pass exactly as it
    -- should.
    relevance = 50,
    -- Liquid in a beaker and vapour over a burner: gas whenever a room is
    -- hot or thin enough, and nothing a station scrubs on principle.
    group = "volatile",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- NFPA 704 for water.
    hazard = { health = 0, fire = 0, instability = 0 },
}
