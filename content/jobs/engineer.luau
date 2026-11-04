-- Keep the power on, patch the hull (the essence's own example).
local crew_outfits = require("@lib/crew_outfits")

return {
    id = "engineer",
    name = "Station Engineer",
    -- The kit is lib/crew_outfits.luau's, shared with the cadaver stock.
    outfit = crew_outfits.engineer,
}
