-- Station permission words on a leaf. `station` is one realm; engineering,
-- medical, security and command are its permissions, and the captain mask
-- holds all four. `station.captain` needs every one of them; `any:station.captain`
-- needs one. Each body walks a row of leaves it must test, so one world serves it.
local access_bench = require("@helpers/access_bench")

local function word(access: string): string
    return "{ \"access\": \"" .. access .. "\" }"
end

-- ---- a worn captain card opens the engineering leaf, each single-permission
-- leaf, and the every-permission leaf, one after another down the corridor.
access_bench.world(
    "captain chain",
    access_bench.spawn("captain", 3)
        .. ", "
        .. access_bench.leaf(5, "airlock.engineering")
        .. ", "
        .. access_bench.leaf(7, "airlock", word("station.medical"))
        .. ", "
        .. access_bench.leaf(9, "airlock", word("station.security"))
        .. ", "
        .. access_bench.leaf(11, "airlock", word("station.command"))
        .. ", "
        .. access_bench.leaf(13, "airlock", word("station.captain")),
    ""
)
local captain = t.join("captain")
t.run_seconds(1.0)
assert(t.worn(captain).id == "id_captain", "the captain wears the captain ID")
for _, door_x in ipairs({ 5, 7, 9, 11, 13 }) do
    access_bench.bump(captain, door_x)
    assert(
        assert(t.door_at(door_x, 1)).open,
        "the worn captain card opens the leaf at column " .. door_x
    )
    access_bench.pass_through(captain, door_x)
end

-- ---- an engineer holds one permission: any-of the captain mask admits it,
-- and the every-permission leaf behind it refuses it.
access_bench.world(
    "engineer chain",
    access_bench.spawn("engineer", 3)
        .. ", "
        .. access_bench.leaf(5, "airlock", word("any:station.captain"))
        .. ", "
        .. access_bench.leaf(7, "airlock", word("station.captain")),
    ""
)
local engineer = t.join("engineer")
t.run_seconds(1.0)
access_bench.bump(engineer, 5)
assert(assert(t.door_at(5, 1)).open, "one engineering permission passes any-of station.captain")
access_bench.pass_through(engineer, 5)
access_bench.bump(engineer, 7)
assert(
    not assert(t.door_at(7, 1)).open,
    "an engineer's one permission is short of every-permission station.captain"
)

-- ---- any-of from both sides of one leaf: an assistant holds no permission and
-- is refused; a medic holds one and passes.
access_bench.world(
    "any of captain",
    access_bench.spawn("assistant", 3)
        .. ", "
        .. access_bench.spawn("medic", 6)
        .. ", "
        .. access_bench.leaf(5, "airlock", word("any:station.captain")),
    ""
)
local assistant = t.join("assistant")
local medic = t.join("medic")
t.run_seconds(1.0)
access_bench.bump(assistant, 5)
assert(
    not assert(t.door_at(5, 1)).open,
    "an assistant holds no permission; any-of captain refuses it"
)
access_bench.bump(medic, 5)
assert(assert(t.door_at(5, 1)).open, "a medic's one permission passes any-of captain")

-- ---- an undeclared word is refused at load, and the refusal names it.
local UNDECLARED = access_bench.source(
    "undeclared word",
    access_bench.spawn("captain", 3)
        .. ", "
        .. access_bench.leaf(5, "airlock", word("station.nope")),
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
