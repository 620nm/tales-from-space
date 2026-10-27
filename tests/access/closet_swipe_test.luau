-- Secure closets read the actor's whole set of station permissions, the worn
-- card included. An assistant's own card swiped at the medical crate changes
-- nothing; a captain wearing a card that holds every station permission
-- unlocks it with an assistant's card.
local access_bench = require("@helpers/access_bench")

local CRATE = 5

local function crate_state(): string
    local crate = assert(t.structure_at(CRATE, 1), "the secure crate remains present")
    assert(crate.state ~= nil, "the secure crate exposes its native state")
    return crate.state
end

t.world(
    access_bench.source(
        "closet swipe bench",
        access_bench.spawn("captain", 4)
            .. ", "
            .. access_bench.spawn("assistant", 6)
            .. ", (5, 1, \"crate.secure\", { \"access\": \"station.medical\" })",
        "(4, 1, \"id_assistant\")"
    ),
    0
)
local captain = t.join("captain")
local assistant = t.join("assistant")
t.run_seconds(1.0)
assert(t.worn(captain).id == "id_captain", "the captain wears the captain ID")
assert(t.worn(assistant).id == "id_assistant", "the assistant wears the assistant ID")
local function heard(p: number): string
    return table.concat(t.messages(p), " | ")
end

local _ = t.messages(assistant)
t.click(assistant, CRATE, 1, assert(t.target_at(assistant, CRATE, 1, "crate.secure")))
t.run_ticks(2)
assert(heard(assistant):find("is locked", 1, true), "the medical crate starts locked")
assert(crate_state() == "closed", "and an empty hand cannot open it")

-- ---- the assistant swipes its own card: nothing changes.
t.unequip(assistant, "id")
t.run_ticks(2)
assert(t.hands(assistant).held == "id_assistant", "the assistant swipes its own card")
t.click(assistant, CRATE, 1, assert(t.target_at(assistant, CRATE, 1, "crate.secure")))
t.run_ticks(2)
assert(heard(assistant):find("Access denied.", 1, true), "the swipe is refused aloud")
assert(crate_state() == "closed", "an assistant card does not unlock the medical crate")

t.drop(assistant)
t.run_ticks(2)
t.click(assistant, CRATE, 1)
t.run_ticks(2)
assert(crate_state() == "closed", "the refused swipe left the crate locked")

-- ---- the captain swipes an assistant's card: the worn captain card holds
-- the medical permission, so the swipe unlocks; an empty hand then opens it.
t.click(captain, 4, 1, assert(t.target_at(captain, 4, 1, "id_assistant")))
t.run_ticks(2)
assert(t.hands(captain).held == "id_assistant", "the captain holds an assistant card")
t.click(captain, CRATE, 1, assert(t.target_at(captain, CRATE, 1, "crate.secure")))
t.run_ticks(2)
assert(crate_state() == "closed", "the swipe unlocks without opening")

t.drop(captain)
t.run_ticks(2)
t.click(captain, CRATE, 1)
t.run_ticks(2)
assert(crate_state() == "open", "the captain's swipe unlocked the crate for an empty-handed open")

-- ---- the crate's own requirement decides: a worn security card swiping an
-- assistant card is refused, a worn medic card swiping the same card unlocks.
local MEDIC_X = 4
local SECURITY_X = 6
t.world(
    access_bench.source(
        "closet swipe medic bench",
        access_bench.spawn("medic", MEDIC_X)
            .. ", "
            .. access_bench.spawn("security", SECURITY_X)
            .. ", (5, 1, \"crate.secure\", { \"access\": \"station.medical\" })",
        "(4, 1, \"id_assistant\"), (6, 1, \"id_assistant\")"
    ),
    0
)
local medic = t.join("medic")
local guard = t.join("security")
t.run_seconds(1.0)
assert(t.worn(medic).id == "id_medical", "the medic wears the medical ID")
assert(t.worn(guard).id == "id_security", "the guard wears the security ID")

t.click(guard, SECURITY_X, 1, assert(t.target_at(guard, SECURITY_X, 1, "id_assistant")))
t.run_ticks(2)
assert(t.hands(guard).held == "id_assistant", "the guard holds an assistant card")
local _ = t.messages(guard)
t.click(guard, CRATE, 1, assert(t.target_at(guard, CRATE, 1, "crate.secure")))
t.run_ticks(2)
assert(heard(guard):find("Access denied.", 1, true), "a card without medical is refused aloud")
t.drop(guard)
t.run_ticks(2)
t.click(guard, CRATE, 1)
t.run_ticks(2)
assert(crate_state() == "closed", "the guard's refused swipe left the crate locked")

t.click(medic, MEDIC_X, 1, assert(t.target_at(medic, MEDIC_X, 1, "id_assistant")))
t.run_ticks(2)
assert(t.hands(medic).held == "id_assistant", "the medic holds an assistant card")
local _ = t.messages(medic)
t.click(medic, CRATE, 1, assert(t.target_at(medic, CRATE, 1, "crate.secure")))
t.run_ticks(2)
assert(heard(medic):find("You unlock", 1, true), "the worn medical card unlocks the crate")
t.drop(medic)
t.run_ticks(2)
t.click(medic, CRATE, 1)
t.run_ticks(2)
assert(crate_state() == "open", "the medic opens the unlocked crate")
