-- Nitrous oxide, for its LOOK only. Metadata for a BUILTIN, as
-- water.luau is; the physics are the matter registry's.
-- tg: /datum/reagent/nitrous_oxide, `color = COLOR_GRAY`
-- (other_reagents.dm:1682).
return {
    id = "n2o",
    name = "nitrous oxide",
    color = "#808080",
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAPPING.md, the recipe panel). A chamber a mapper fills on
    -- purpose.
    relevance = 60,
}
