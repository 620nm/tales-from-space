-- The given names a character may take; the list is lib/crew/names.luau's.
local crew_names = require("@lib/crew/names")

return {
    id = "given_names",
    entries = crew_names.given,
}
