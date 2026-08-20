-- Oxygen, for its LOOK only: the station's own gas, seen through the
-- glass of a vessel the dispenser has just pressed it into.
--
-- Metadata for a BUILTIN, exactly as water.luau is -- the physics are
-- the matter registry's and this file cannot touch them. tg carries
-- oxygen as a reagent as well as a gas, which is why the shelf can
-- dispense it at all (docs/reagents.md, Effort C).
-- tg: /datum/reagent/oxygen, `color = COLOR_GRAY` (other_reagents.dm:
-- 983).
return {
    id = "o2",
    name = "oxygen",
    color = "#808080",
}
