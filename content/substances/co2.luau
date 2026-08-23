-- Carbon dioxide, for its LOOK only. Metadata for a BUILTIN, as
-- water.luau is; the physics are the matter registry's. The bench
-- makes this over 777 K and it goes back into the same builtin the
-- room's air is made of -- there is one matter registry and no second
-- carbon dioxide (reactions/carbon_dioxide.luau).
-- tg: /datum/reagent/carbondioxide, `color = "#B0B0B0"`
-- (other_reagents.dm:1666).
return {
    id = "co2",
    name = "carbon dioxide",
    color = "#B0B0B0",
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAPPING.md, the recipe panel). What a room full of people
    -- fills up with, and what a mapper drawing a stale chamber reaches
    -- for.
    relevance = 80,
}
