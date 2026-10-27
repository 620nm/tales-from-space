-- Secure closets read the actor's whole set, the worn card included. An
-- assistant's own card swiped at the medical crate changes nothing; a captain
-- wearing a card that holds every realm unlocks it with an assistant's card.
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
assert(crate_state() == "closed", "the medical crate starts locked")

-- ---- the assistant swipes its own card: nothing changes.
t.unequip(assistant, "id")
t.run_ticks(2)
assert(t.hands(assistant).held == "id_assistant", "the assistant swipes its own card")
t.click(assistant, CRATE, 1, assert(t.target_at(assistant, CRATE, 1, "crate.secure")))
t.run_ticks(2)
assert(crate_state() == "closed", "an assistant card does not unlock the medical crate")

t.drop(assistant)
t.run_ticks(2)
t.click(assistant, CRATE, 1)
t.run_ticks(2)
assert(crate_state() == "closed", "the refused swipe left the crate locked")

-- ---- the captain swipes an assistant's card: the worn captain card holds
-- the medical realm, so the swipe unlocks; an empty hand then opens it.
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
