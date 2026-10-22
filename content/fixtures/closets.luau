local closet = require("@lib/closets/closet")

local content = { id = "closets" }
if sim ~= nil then
    closet.attach("crate", {
        secure_variants = { ["crate.secure"] = true },
        default_access = "command",
    })
    closet.attach("freezer", {})
    closet.attach("locker", {})
end
return content
