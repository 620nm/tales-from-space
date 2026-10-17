-- A host map whose stem has uppercase letters still begins the round: the
-- bootstrap lowercases the logical id's tail to the resource-tail rule
-- (content/lib/map_boot.luau), so no boot refusal is ledgered.
t.bootstrap_world({ host_map = "Box.ron", mode = "free_build", seed = 7 })

assert(#t.ledger_rows("lunatic/tfs:map_boot_failed") == 0, "no boot refusal is ledgered")
local builder = t.join()
t.tick()
local x, y = t.pos(builder)
assert(x == 1 and y == 1, "the round began on the uppercase host map, got (" .. x .. ", " .. y .. ")")
