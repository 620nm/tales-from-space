-- Printing policy shared by the copier and fax. Resource debit and output
-- materialization are native jobs; these constants keep their contracts in
-- one place for handlers and specs. Durations are seconds of physical time:
-- 4 s a copy, 2 s a fax page (80/40 ticks at this pack's 20 Hz). Handlers
-- convert them with sim.ticks at the documents.start call, which is exact
-- at every integer rate; prototype-adjacent code must never assume a tick
-- count from them.
local printing = {
    paper = "paper",
    toner = "toner",
    max_copies = 10,
    copy_seconds = 4,
    fax_seconds = 2,
}

-- Native document jobs multiply each listed cost by their batch count. Keep
-- the per-output amount here so callers cannot accidentally charge count².
function printing.costs(): { { resource: string, amount: number } }
    return {
        { resource = printing.paper, amount = 1 },
        { resource = printing.toner, amount = 1 },
    }
end

return printing
