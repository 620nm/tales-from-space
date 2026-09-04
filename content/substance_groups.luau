-- The headings a list of substances is drawn under, in the order a
-- player reads them (docs/CONTENT-SCHEMA.md, docs/CHEMISTRY.md §2).
--
-- A scrubber offers a button per gas and a filter offers the same list
-- again. Unordered, that is a wall of words a technician has to read
-- end to end to find carbon dioxide. These four headings are how the
-- station thinks about its own air: what a room is supposed to hold,
-- what a room is supposed to be rid of, what is only a gas because
-- something is hot or thin -- water is filed there and rests liquid --
-- and everything else on the shelf.
--
-- Order here IS display order, and a substance names exactly one group
-- (`group = "..."` in its own file), so the blocks never overlap. The
-- rank inside a block is each substance's own `relevance`.
--
-- `rest = true` marks the bucket everything untagged falls into. Without
-- it the untagged tail would draw under no heading at all, which is
-- honest but says nothing; with it, a reagent nobody has thought about
-- yet still lands somewhere a player can find it.
return {
    { key = "atmospheric", label = "Station atmosphere" },
    { key = "poison", label = "Atmospheric poisons" },
    { key = "volatile", label = "Volatiles" },
    { key = "other", label = "Other", rest = true },
}
