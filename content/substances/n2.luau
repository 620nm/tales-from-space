-- Nitrogen, for its LOOK only. Metadata for a BUILTIN, as water.luau
-- is; the physics are the matter registry's.
-- tg: /datum/reagent/nitrogen, `color = COLOR_GRAY`
-- (other_reagents.dm:1018).
return {
    id = "n2",
    name = "nitrogen",
    color = "#808080",
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAPPING.md, the recipe panel). The other four fifths of
    -- ordinary air.
    relevance = 90,
}
