-- Good Clean Fun: the rec-room shelf, and what comes off it.
--
-- `vendor_test.luau` already proves what a vending machine IS -- dense,
-- opens tg's window, dispenses on act('vend') as a player-attributed
-- action. None of that is re-proved here. What is here is the thing
-- that made this machine worth adding: every product on it is a toy
-- with behaviour, and a shelf is only worth having if what it hands you
-- WORKS when it lands on the floor. So this deals a card out of a deck
-- the machine minted, and empties a bag the machine minted, on the
-- theory that a vend which produced a hollow object would pass every
-- assertion a vending test usually makes.
--
-- The three shelves are tg's, and the twenty-one products tg stocks
-- that are absent are absent for reasons written down in
-- content/machines/games_vendor.luau rather than here.
t.world([==[(
    name: "rec room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#o..#",
        "#a.g#",
        "#####",
    ],
    spawns: [(1, 1)],
    machines: [(2, 1, "games_vendor")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
    ],
)]==], 0)

local p = t.join()
t.tick()

-- ---- the shelf --------------------------------------------------------
t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
local ui = t.ui(p)
assert(ui.document == "modules" and ui.presentation == "shelf",
    "the clean-room shelf document")
assert(ui.notice == "Roll for initiative!",
    "the content-authored slogan across the top: " .. tostring(ui.notice))

-- Every declared product is on the window, in its declared category,
-- with an atlas sprite the client can actually resolve and the stock the
-- file says. A shelf row whose art did not resolve would draw a blank
-- button, which is the failure this checks.
local WANT = {
    card_deck = { name = "Deck of Cards", category = "Cards", amount = 5 },
    captains_aid = { name = "Captain's Aid", category = "Toys", amount = 1 },
    dice_bag = { name = "Bag of Dice", category = "Other", amount = 10 },
}
local found = 0
for _, row in ipairs(ui.products) do
    local product = row.payload.product
    local want = WANT[product]
    assert(want ~= nil, "the shelf stocks nothing undeclared: " .. tostring(product))
    assert(row.label == want.name, product .. " is called " .. want.name)
    assert(row.category == want.category, product .. " is on the " .. want.category .. " shelf")
    assert(row.sprite ~= "missing", product .. " resolves to atlas art")
    assert(row.stock == want.amount,
        product .. " stocks " .. want.amount .. ", got " .. tostring(row.stock))
    found += 1
end
assert(found == 3, "three products, got " .. found)
assert(ui.products[1].category == "Cards" and ui.products[2].category == "Toys"
        and ui.products[3].category == "Other",
    "content owns the shelf-group order")

-- ---- a bag of dice, and the dice really in it -------------------------
t.ui_act(p, "vend", '{"product":"dice_bag"}')
t.tick()
assert(t.count_items("dice_bag") == 1, "a bag came out")
-- The vend drops at the MACHINE's feet, never the buyer's, so a machine
-- can never mint onto a tile it cannot see (sim/ui/vending.rs).
assert(t.item_at(2, 1, "dice_bag") ~= nil, "at the machine's feet")

t.ui_close(p)
t.tick()
t.click(p, 2, 1, t.target_at(2, 1, "dice_bag"))
t.tick()
assert(t.hands(p).held == "dice_bag", "the bag is in hand")
-- A container minted by a vending machine goes through the same one
-- spawner a map placement does, so `holds` is stocked exactly the same
-- way (sim/mint.rs). Seven dice, or the machine handed out a prop.
local ROSTER = { "d4", "d6", "d8", "d10", "d12", "d20", "d00" }
for i = 1, #ROSTER do
    t.take_held(p, 0)
    t.tick()
    t.swap_hands(p)
    assert(t.hands(p).held == ROSTER[i],
        "slot " .. i .. " is the " .. ROSTER[i] .. ", got " .. tostring(t.hands(p).held))
    t.drop(p)
    t.tick()
    t.swap_hands(p)
end
t.drop(p)
t.tick()

-- ...and one of them rolls, which is the whole point of a machine that
-- hands out dice rather than a floor that has two on it.
t.click(p, 1, 1, t.target_at(1, 1, "d20"))
t.tick()
t.use_self(p)
t.tick()
local said = table.concat(t.messages(p), "\n")
assert(said:find("You roll the d20. It lands on", 1, true),
    "a vended die rolls: " .. said)
t.drop(p)
t.tick()

-- ---- a deck, and a card off it ----------------------------------------
t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
t.ui_act(p, "vend", '{"product":"card_deck"}')
t.tick()
assert(t.count_items("card_deck") == 1, "a deck came out")
t.ui_close(p)
t.tick()
t.click(p, 2, 1, t.target_at(2, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == "card_deck", "the deck is in hand")

t.click(p, 1, 2)
t.tick()
local card = t.item_at(1, 2, "card")
assert(card ~= nil, "a vended deck deals a card")
assert(card.state:sub(1, 5) == "down_", "face down: " .. tostring(card.state))
assert(card.sprite == "card_back", "showing its back: " .. tostring(card.sprite))
-- The deck's shuffle is written on the record the moment it is dealt
-- from, which is the only trace a string in `ScriptVars` leaves.
local wrote = t.ledger_rows("VarSet")
assert(#wrote >= 1 and wrote[#wrote].key == "order",
    "the vended deck kept its own order")

-- ---- the Captain's Aid, which the machine is stingy with --------------
t.drop(p)
t.tick()
t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
t.ui_act(p, "vend", '{"product":"captains_aid"}')
t.tick()
assert(t.count_items("captains_aid") == 1, "the one Aid came out")
-- tg stocks exactly one (games.dm:26), and a finite shelf must actually
-- run out -- otherwise `amount` is decoration.
t.ui_act(p, "vend", '{"product":"captains_aid"}')
t.tick()
assert(t.count_items("captains_aid") == 1,
    "and the shelf is empty: a second buy mints nothing")

-- ---- nothing else is for sale here ------------------------------------
-- The negative half, and the one that matters: a payload naming a
-- prototype this machine does not stock buys nothing. The window is a
-- client claim like any other (crates/lunatic-server/AGENTS.md), and
-- the shelf list is the only thing that decides.
for _, ref in ipairs({ "cola", "d20", "card", "id_captain", "toolbox" }) do
    local before = t.count_items(ref)
    t.ui_act(p, "vend", '{"product":"' .. ref .. '"}')
    t.tick()
    assert(t.count_items(ref) == before,
        "Good Clean Fun does not deal in " .. ref)
end

-- ---- and it is plugged in on the real station -------------------------
-- The map half, which no purpose-built bench can prove: Good Clean Fun
-- stands in the Commons at (24, 16), on the same wall and the same
-- outlet as the softdrinks machine and the YouTool -- and a corded
-- appliance out of cord range is a dark box that says so instead of
-- opening (content/fixtures/vendor.luau). Unplug the Commons and the
-- shopping stops, which is the point of corded appliances; this is the
-- assertion that it was plugged in to begin with.
t.world_file("chillstation.ron", 7)
local crew = t.join()
t.run_ticks(20)

assert(t.count_items("d6") == 0 and t.count_items("d20") == 0,
    "the two loose dice are off the Commons floor")

-- Walk to it and open it. The window opening at all IS the power
-- assertion: the fixture script refuses with "dark and silent" when
-- `ctx.is_powered` says no, and that refusal would leave `t.ui` nil.
--
-- The first joiner spawns at (18, 16), five tiles west of the machine
-- along the Commons' open row, so the walk is deterministic rather
-- than a search.
local x, y = t.pos(crew)
assert(x == 18 and y == 16, "the first joiner takes the first spawn")

t.click(crew, 24, 16, t.target_at(24, 16))
t.tick()
assert(t.ui(crew) == nil, "and cannot shop from across the room")

for _ = 1, 5 do
    t.move(crew, "east")
    t.run_ticks(5)
end
x, y = t.pos(crew)
assert(x == 23 and y == 16, "standing beside it: " .. x .. "," .. y)

t.click(crew, 24, 16, t.target_at(24, 16))
t.tick()
local shelf = t.ui(crew)
assert(shelf ~= nil, "the machine has power and opens: "
    .. table.concat(t.messages(crew), " "))
assert(shelf.document == "modules" and shelf.presentation == "shelf",
    "the shelf document")
assert(shelf.notice == "Roll for initiative!",
    "and it is the right machine, not one of its two neighbours")
