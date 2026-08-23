-- Tritium, for its RANK only. Metadata for a BUILTIN, exactly as
-- o2.luau is: the physics -- the molar mass, the specific heat, the
-- visibility threshold -- live in the engine's matter registry because
-- atmos needs them long before content does, and the registry skips a
-- content substance whose key it already knows (invariant I9,
-- docs/CHEMISTRY.md). Nothing here registers physics and nothing here
-- could override any.
--
-- It earns a file because a mapper reaches for it: the station ships a
-- tank of it standing in the annex, and a chamber authored to hold it
-- is a thing somebody will want to draw.
return {
    id = "tritium",
    name = "tritium",
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAPPING.md, the recipe panel). Under the air a station is
    -- made of, over every reagent that only ever lives in a beaker.
    relevance = 40,
}
