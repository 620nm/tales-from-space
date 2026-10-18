-- The station's blood ledger, split between what bodies carry and what
-- has been spilled. Blood is a substance: `t.matter_totals()` counts the
-- moles circulating in every bloodstream, and the harmony handler's
-- top-up (content/lib/blood_harmony.luau) is a `minted` row owned by the
-- body. A spec asking about WOUNDS reads through this module instead.
local blood_books = {}

-- Moles of `blood` lying outside the given bodies' bloodstreams: on the
-- deck, in a container, in a pool.
function blood_books.spilled(bodies: { number }): number
    local circulating = 0
    for _, body in ipairs(bodies) do
        circulating += t.blood(body).blood or 0
    end
    return math.max((t.matter_totals().substances["blood"] or 0) - circulating, 0)
end

-- A `minted` row owned by a tile, "(x, y)", rather than by a body.
local function tile_owned(row: SpecLedgerRow): boolean
    return tostring(row.owner):match("^%(%-?%d+, %-?%d+%)$") ~= nil
end

-- The `minted` rows minus the body's own blood top-ups: every row left
-- is ash, a spilled wound, or another mint a spec cares about.
function blood_books.minted(): { SpecLedgerRow }
    local rows = {}
    for _, row in ipairs(t.ledger_rows("minted")) do
        if row.substance ~= "blood" or tile_owned(row) then
            table.insert(rows, row)
        end
    end
    return rows
end

return blood_books
