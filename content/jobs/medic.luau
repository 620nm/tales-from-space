local crew_outfits = require("@lib/crew_outfits")

return {
    id = "medic",
    name = "Medical Doctor",
    slots = 1,
    -- The kit is lib/crew_outfits.luau's, shared with the cadaver stock.
    outfit = crew_outfits.medic,
}
