-- This pack ships no root map, so a server started with no map has nothing
-- to instantiate: the handler ledgers that and the round never begins. The
-- spec boot raises rather than waiting forever (content/lib/map_boot.luau).
local booted, why = pcall(function()
    t.bootstrap_world({ mode = "free_build", seed = 7, max_seconds = 2 })
end)
assert(not booted, "a bootstrap with no host map must not begin a round")
assert(
    string.find(tostring(why), "no join install", 1, true) ~= nil,
    "the failure says no join install settled, got " .. tostring(why)
)
local rows = t.ledger_rows("lunatic/tfs:map_boot_failed")
assert(#rows >= 1, "the missing host map is ledgered, got " .. #rows)
