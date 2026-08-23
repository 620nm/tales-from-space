-- Oxygen, for its LOOK only: the station's own gas, seen through the
-- glass of a vessel the dispenser has just pressed it into.
--
-- Metadata for a BUILTIN, exactly as water.luau is -- the physics are
-- the matter registry's and this file cannot touch them. tg carries
-- oxygen as a reagent as well as a gas, which is why the shelf can
-- dispense it at all (docs/CHEMISTRY.md).
-- tg: /datum/reagent/oxygen, `color = COLOR_GRAY` (other_reagents.dm:
-- 983).
return {
    id = "o2",
    name = "oxygen",
    color = "#808080",
    -- What lungs are looking for. The threshold a breath is held to is
    -- the engine's (tg's `safe_oxygen_min`, 16 kPa of partial
    -- pressure); which gas clears it is this line, and this line is the
    -- only place on the station that says the crew breathes oxygen.
    breath = { breathable = true },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAPPING.md, the recipe panel). The air a station is
    -- commissioned full of, so it leads.
    relevance = 100,
}
