-- The classic: no access, no duties, unlimited slots, infinite schemes.
local crew_outfits = require("@lib/crew_outfits")

return {
    id = "assistant",
    name = "Assistant",
    -- The kit is lib/crew_outfits.luau's, shared with the cadaver stock.
    outfit = crew_outfits.assistant,
}
