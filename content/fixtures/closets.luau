local closet = require("@lib/closets/closet")

local content = { id = "closets" }
if sim ~= nil then
    -- Focused specs place this helper to exercise an external removal race.
    local fixture_removal_tool = "lunatic/tfs:closet_cut_test_remover"
    sim.define("item", fixture_removal_tool, {
        name = "closet cut test remover",
        sprite = "welder",
        visual_layer = "item",
    })
    closet.attach("crate", {
        secure_variants = { ["crate.secure"] = true },
        default_access = "command",
        fixture_removal_tool = fixture_removal_tool,
    })
    closet.attach("freezer", {})
    closet.attach("locker", {})
end
return content
