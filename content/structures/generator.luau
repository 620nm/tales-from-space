-- The backup set: a diesel in a box, standing on the feeder it charges.
--
-- Bolted down and solid -- you walk around it, not through it -- and
-- everything it DOES is native, because watts per tick on a graph is
-- exactly the per-tick arithmetic the engine keeps.
return {
    id = "generator",
    name = "portable generator",
    sprite = "generator",
    fixture = "Generator",
    category = "power",
    dense = true,
    examine = {
        flavor = "A boxed generator with a pull cord. It is what the "
            .. "station falls back on when the sun goes behind something.",
    },
}
