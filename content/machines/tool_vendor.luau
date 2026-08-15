-- The tool vendor, standing beside the softdrinks machine because an
-- engineer who has lost a crowbar should not have to walk to the
-- Annex for another one.
--
-- tg: /obj/machinery/vending/tool ("YouTool", vending/youtool.dm),
-- whose stock this reproduces as far as the pack has prototypes for
-- it. tg also lists a t-scanner, flashlights, glowsticks and earmuffs;
-- those are not things yet, so they are not on the shelf. Nothing
-- native has to change when they are — one line here, which is exactly
-- what the gas analyzer cost the day it became a thing.
--
-- It shares `script = "vendor"` with the softdrinks machine: opening
-- a window on click and wobbling when bumped is the behaviour of a
-- vending machine, not of any particular one.
return {
    id = "tool_vendor",
    name = "YouTool vending machine",
    sprite = "tool_vendor",
    dense = true,
    script = "vendor",
    corded = true,
    ad = "Tools for tools.",
    categories = { Tools = "screwdriver" },
    vends = {
        { item = "cable_coil", name = "Cable Coil", category = "Tools", amount = 10 },
        { item = "crowbar", name = "Crowbar", category = "Tools", amount = 5 },
        { item = "welder", name = "Welding Tool", category = "Tools", amount = 3 },
        { item = "wirecutters", name = "Wirecutters", category = "Tools", amount = 5 },
        { item = "wrench", name = "Wrench", category = "Tools", amount = 5 },
        { item = "analyzer", name = "Gas Analyzer", category = "Tools", amount = 5 },
        { item = "screwdriver", name = "Screwdriver", category = "Tools", amount = 5 },
        { item = "multitool", name = "Multitool", category = "Tools", amount = 4 },
        { item = "toolbelt", name = "Toolbelt", category = "Tools", amount = 2 },
    },
}
