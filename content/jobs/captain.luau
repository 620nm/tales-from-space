-- The captain: one per shift, and every door on the station knows it.
local crew_outfits = require("@lib/crew/outfits")

return {
    id = "captain",
    name = "Captain",
    slots = 1,
    -- The kit is lib/crew/outfits.luau's, shared with the cadaver stock.
    outfit = crew_outfits.captain,
}
