-- Secure closets use an access card held in either hand or worn by the actor.
local function closet_state(): string
    local closet = assert(t.structure_at(3, 1), "the secure closet remains present")
    assert(closet.state ~= nil, "the secure closet exposes its native state")
    return closet.state
end

t.world(
    [==[ (
        name: "medical closet access",
        legend: {
            ' ': (composition: (substrate: Named("space"))),
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: ["#######", "#.....#", "#.....#", "#######"],
            structures: [
                (2, 1, "player_spawn", { "jobs": "assistant" }),
                (4, 1, "player_spawn", { "jobs": "medic" }),
                (3, 1, "crate.secure", { "access": "station.medical" }),
            ],
            items: [
                (2, 1, "backpack"),
                (2, 1, "id_medical"),
                (4, 1, "id_assistant"),
            ],
        )],
    ) ]==],
    7
)

local assistant = t.join("assistant")
local medic = t.join("medic")
t.run_ticks(2)

-- Keep the job's worn backpack for the later negative case, adding one only
-- if this loadout has no back-slot container.
if t.worn(assistant).back == nil then
    t.click(assistant, 2, 1, assert(t.target_at(assistant, 2, 1, "backpack")))
    t.run_ticks(2)
    t.equip(assistant)
    t.run_ticks(2)
end
assert(t.worn(assistant).back == "backpack", "the backpack is worn")
t.unequip(assistant, "id")
t.run_ticks(2)
assert(t.hands(assistant).held == "id_assistant", "the assistant presents their worn card")
t.click(medic, 4, 1, assert(t.target_at(medic, 4, 1, "id_assistant")))
t.run_ticks(2)
assert(t.hands(medic).held == "id_assistant", "the medic presents an assistant card")

-- A locked closet does not open to an empty hand.
t.drop(assistant)
t.run_ticks(2)
t.click_tile(assistant, 3, 1)
t.run_ticks(2)
assert(closet_state() == "closed", "an empty hand cannot open a locked medical crate")
t.click(assistant, 2, 1, assert(t.target_at(assistant, 2, 1, "id_assistant")))
t.run_ticks(2)
assert(t.hands(assistant).held == "id_assistant", "the assistant retrieves their card")

-- An assistant card cannot unlock the medical crate. The medic's worn medical
-- card authorizes the held presented card, and that action leaves it closed.
t.click(assistant, 3, 1, assert(t.target_at(assistant, 3, 1, "crate.secure")))
t.run_ticks(2)
assert(closet_state() == "closed", "the assistant card cannot open a locked medical crate")
t.click(medic, 3, 1, assert(t.target_at(medic, 3, 1, "crate.secure")))
t.run_ticks(2)
assert(closet_state() == "closed", "the worn medical card unlocks without opening")
t.drop(medic)
t.run_ticks(2)
t.click_tile(medic, 3, 1)
t.run_ticks(2)
assert(closet_state() == "open", "native empty-hand opening follows a valid unlock")
t.click_tile(medic, 3, 1)
t.run_ticks(2)

-- Any actor can lock an unlocked secure closet with an ID, including one
-- whose access level does not match the closet. The medic's next unlock and
-- native open make the preceding lock observable.
t.click(assistant, 3, 1, assert(t.target_at(assistant, 3, 1, "crate.secure")))
t.run_ticks(2)
assert(closet_state() == "closed", "the assistant locks the unlocked closet")
t.click(medic, 4, 1, assert(t.target_at(medic, 4, 1, "id_assistant")))
t.run_ticks(2)
t.click(medic, 3, 1, assert(t.target_at(medic, 3, 1, "crate.secure")))
t.run_ticks(2)
assert(closet_state() == "closed", "the medic unlocks with worn access and a held ID")
t.drop(medic)
t.run_ticks(2)
t.click_tile(medic, 3, 1)
t.run_ticks(2)
assert(closet_state() == "open", "the medic's unlock confirms the assistant locked it")
t.click_tile(medic, 3, 1)
t.run_ticks(2)

-- A medical card in the assistant's other hand authorizes the active
-- assistant card. The player opens it natively after the ID action to prove
-- the access union unlocked it, then explicitly locks it for the next case.
t.click(assistant, 3, 1, assert(t.target_at(assistant, 3, 1, "crate.secure")))
t.run_ticks(2)
assert(closet_state() == "closed", "the assistant locks it before the hand-union check")
t.swap_hands(assistant)
t.run_ticks(2)
t.click(assistant, 2, 1, assert(t.target_at(assistant, 2, 1, "id_medical")))
t.run_ticks(2)
assert(t.hands(assistant).held == "id_medical", "medical card is in the other hand")
t.swap_hands(assistant)
t.run_ticks(2)
assert(t.hands(assistant).held == "id_assistant", "assistant card is active again")
t.click(assistant, 3, 1, assert(t.target_at(assistant, 3, 1, "crate.secure")))
t.run_ticks(2)
assert(closet_state() == "closed", "the other-hand medical card authorizes unlocking")
t.drop(assistant)
t.run_ticks(2)
t.click_tile(assistant, 3, 1)
t.run_ticks(2)
assert(closet_state() == "open", "the other-hand card unlocked native opening")
t.click_tile(assistant, 3, 1)
t.run_ticks(2)
t.click(assistant, 2, 1, assert(t.target_at(assistant, 2, 1, "id_assistant")))
t.run_ticks(2)
t.click(assistant, 3, 1, assert(t.target_at(assistant, 3, 1, "crate.secure")))
t.run_ticks(2)
assert(closet_state() == "closed", "the assistant explicitly restores the locked state")

-- Move that medical card into worn storage. It must stop authorizing access;
-- the medic's next valid unlock distinguishes denial from a toggled relock.
t.swap_hands(assistant)
t.run_ticks(2)
t.interact_item(assistant, { Equipment = { slot = "back" } })
t.run_ticks(2)
assert(
    table.find(t.stored(assistant, "back"), "id_medical") ~= nil,
    "the medical ID is inside the backpack"
)
t.swap_hands(assistant)
t.run_ticks(2)
assert(t.hands(assistant).held == "id_assistant", "only the assistant ID remains in hand")
t.click(assistant, 3, 1, assert(t.target_at(assistant, 3, 1, "crate.secure")))
t.run_ticks(2)
assert(closet_state() == "closed", "a card inside the backpack grants no access")
t.click(medic, 4, 1, assert(t.target_at(medic, 4, 1, "id_assistant")))
t.run_ticks(2)
t.click(medic, 3, 1, assert(t.target_at(medic, 3, 1, "crate.secure")))
t.run_ticks(2)
assert(closet_state() == "closed", "the medic still unlocks with worn medical access")
t.drop(medic)
t.run_ticks(2)
t.click_tile(medic, 3, 1)
t.run_ticks(2)
assert(closet_state() == "open", "the rejected backpack card left the closet locked")
