local matter_look = require("@helpers/matter_look")

-- A substance that names a flat look stays flat.
--
-- Salt overrides the solid default (`powder`, whose second rung is a joined
-- shell) with `crystalline`, a ladder of loose pictures. The same spill of
-- ash, which keeps the default, becomes a shell at that size; salt never does,
-- at a spill-size amount or at a heap of it.

t.set_breathing(false)

-- Milliliters as moles: ash is 100 g/mol at 2.2 g/mL, salt 58.44 g/mol at
-- 2.17 g/mL (content/substances).
local function ash(ml: number): string
    return string.format('("ash", %.4f)', ml * 2.2 / 100.0)
end

local function salt(ml: number): string
    return string.format('("salt", %.4f)', ml * 2.17 / 58.44)
end

local SPILL_ML, HEAP_ML = 60, 5000

local p = matter_look.room({
    { x = 3, y = 3, rows = salt(SPILL_ML) },
    { x = 5, y = 3, rows = ash(SPILL_ML) },
    { x = 7, y = 3, rows = salt(HEAP_ML) },
})

local ash_parts = matter_look.parts(p, 5, 3, "powder")
local ash_shells = 0
for _, part in ipairs(ash_parts) do
    if part.blocks ~= nil then
        ash_shells += 1
    end
end
assert(ash_shells > 0, "the default solid look takes a shell at a spill of this size")

for _, tile in ipairs({ 3, 7 }) do
    local grains = matter_look.parts(p, tile, 3, "crystalline")
    assert(#grains > 0, "salt draws at tile " .. tile)
    for _, part in ipairs(grains) do
        assert(part.sprite ~= nil, "salt is a picture, rung " .. part.rung .. " at tile " .. tile)
        assert(part.blocks == nil and part.joins == nil, "and takes no shell, at tile " .. tile)
    end
    assert(#matter_look.parts(p, tile, 3, "powder") == 0, "the default look is not drawn under the override")
end
