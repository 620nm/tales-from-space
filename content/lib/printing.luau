-- Printing policy shared by the copier and fax. Resource debit and output
-- materialization are native jobs; these constants keep their contracts in
-- one place for handlers and specs.
local printing = {
    paper = "paper",
    toner = "toner",
    max_copies = 10,
    copy_ticks = 80,
    fax_ticks = 40,
}

-- Native document jobs multiply each listed cost by their batch count. Keep
-- the per-output amount here so callers cannot accidentally charge count².
function printing.costs()
    return {
        { resource = printing.paper, amount = 1 },
        { resource = printing.toner, amount = 1 },
    }
end

return printing
