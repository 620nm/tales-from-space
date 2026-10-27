-- Realm words on a leaf. The captain card holds all four station realms, so
-- `station.captain` (all of the mask) admits only it, while
-- `any:station.captain` (any of the mask) admits a holder of one realm.
local access_bench = require("@helpers/access_bench")

local function airlock(access: string): string
    return "(5, 1, \"airlock\", { \"access\": \"" .. access .. "\" })"
end

-- ---- a worn captain card passes an engineering leaf and each single-realm leaf.
assert(
    access_bench.bump_admits("captain", "(5, 1, \"airlock.engineering\")"),
    "a worn captain card passes the engineering airlock"
)
assert(
    access_bench.bump_admits("captain", airlock("station.medical")),
    "a worn captain card passes a station.medical leaf"
)
assert(
    access_bench.bump_admits("captain", airlock("station.security")),
    "a worn captain card passes a station.security leaf"
)
assert(
    access_bench.bump_admits("captain", airlock("station.command")),
    "a worn captain card passes a station.command leaf"
)

-- ---- all of `station.captain`: an engineer's one realm is short of it.
assert(
    not access_bench.bump_admits("engineer", airlock("station.captain")),
    "an engineer is refused by a leaf that needs every realm of the captain mask"
)
assert(
    access_bench.bump_admits("captain", airlock("station.captain")),
    "the captain passes the every-realm leaf"
)

-- ---- any of `station.captain`: one realm is enough; no realm is not.
local ANY_CAPTAIN = airlock("any:station.captain")
assert(access_bench.bump_admits("engineer", ANY_CAPTAIN), "an engineer passes any-of captain")
assert(access_bench.bump_admits("medic", ANY_CAPTAIN), "a medic passes any-of captain")
assert(
    not access_bench.bump_admits("assistant", ANY_CAPTAIN),
    "an assistant, holding no realm, is refused by any-of captain"
)

-- ---- an undeclared word is refused at load, and the refusal names it.
local UNDECLARED = access_bench.source(
    "undeclared word",
    access_bench.spawn("captain", 3) .. ", " .. airlock("station.nope"),
    ""
)
local undeclared_ok, undeclared_error = pcall(function()
    t.world(UNDECLARED, 0)
end)
assert(not undeclared_ok, "a word the pack never declared does not load")
assert(
    string.find(tostring(undeclared_error), "station.nope", 1, true) ~= nil,
    "and the load refusal names it: " .. tostring(undeclared_error)
)
