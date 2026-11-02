-- How a condensed phase of ground reads (the engine's
-- docs/content-schema/terrain.md). A tile names a ground material, a
-- blend; the profile that blend gets says what component lies under the
-- face (`bed`), which matter look is drawn as the face (`face`, in
-- matter_appearances.luau) and how much darker the substrate's own
-- picture shows at a shell's edge (`under_shade`).
--
-- 0.7 is the art's `silicate_low` over its `silicate` (#82402A over
-- #B85C3C in tools/art/terrestrial/schema_contract.py), so an edge pixel
-- reads as the ledge the art drew.
return {
    defaults = { solid = "bare_ground" },
    profiles = {
        {
            key = "bare_ground",
            phase = "solid",
            bed = "ground",
            face = "ground_shell",
            under_shade = 0.7,
        },
    },
}
