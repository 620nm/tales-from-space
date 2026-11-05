-- Robust. The stun baton arrives with the combat gate; until then, a
-- security officer is a toolbox with a warrant.
local crew_outfits = require("@lib/crew/outfits")

return {
    id = "security",
    name = "Security Officer",
    slots = 1,
    -- The kit is lib/crew/outfits.luau's, shared with the cadaver stock.
    outfit = crew_outfits.security,
}
