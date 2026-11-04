-- How a condensed phase of ground reads (the engine's
-- docs/content-schema/terrain.md). A tile names a ground material, a
-- blend; the profile that blend gets says which substrate component a
-- tile over a block of it carries (`floor`), which matter look is drawn as
-- the face (`face`, in matter_appearances.luau) and how much darker that
-- floor's own picture shows at a shell's edge (`under_shade`).
--
-- 0.7 is the art's `silicate_low` over its `silicate` (#82402A over
-- #B85C3C in tools/art/terrestrial/schema_contract.py), so an edge pixel
-- reads as the ledge the art drew.
--
-- The last profiles stand real matter in a bed (`fill`, `depth_m`): a bed
-- of 1.5 m of a 3 m tile is safe under a body's pressure bands. A sea does
-- not evaporate (`evaporation = 0`), or every tile of it would stay awake
-- for good, and ignores a level difference under a millimetre.
local SEABED = "#CBB68C"

return {
    defaults = { solid = "bare_ground", liquid = "deep_liquid" },
    profiles = {
        {
            key = "bare_ground",
            phase = "solid",
            floor = "ground",
            face = "ground_shell",
            under_shade = 0.7,
        },
        {
            key = "deep_liquid",
            phase = "liquid",
            floor = "ground",
            face = "ground_shell",
            face_tint = SEABED,
            fill = true,
            depth_m = 1.5,
            evaporation = 0,
            rest_head_m = 0.001,
            ideal = { half_life_s = 120 },
        },
        {
            key = "still_liquid",
            phase = "liquid",
            floor = "ground",
            face = "ground_shell",
            face_tint = SEABED,
            fill = true,
            depth_m = 1,
            rest_head_m = 0.001,
        },
        {
            key = "sheet_ice",
            phase = "solid",
            floor = "ice_floor",
            face = "ground_shell",
            face_tint = SEABED,
            fill = true,
            depth_m = 1,
            evaporation = 0,
        },
        -- A cliff: the `cliff` floor blocks a body, and the face draws
        -- the stepped escarpment, joined to the cliff beside it.
        {
            key = "cliff",
            phase = "solid",
            floor = "cliff",
            face = "cliff_shell",
            under_shade = 0.7,
        },
        -- A bed dug and left dry: whatever it reaches runs in.
        {
            key = "dry_bed",
            phase = "solid",
            floor = "ground",
            face = "ground_shell",
            under_shade = 0.7,
            depth_m = 2,
        },
    },
}
