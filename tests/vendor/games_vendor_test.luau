local ui_controls = require("@helpers/ui_controls")

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
t.world(
    [==[(
    name: "rec room",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#o..#",
        "#a.g#",
        "#####",
    ],
    structures: [(1, 1, "player_spawn"), (1, 2, "apc")],
    machines: [(2, 1, "games_vendor")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

-- ---- the shelf --------------------------------------------------------
t.click(p, 2, 1, t.target_at(p, 2, 1))
t.tick()
local ui = ui_controls.state(p)
assert(ui.document == "modules" and ui.presentation == "shelf", "the clean-room shelf document")
assert(
    ui_controls.record(ui.notice).text == "Roll for initiative!",
    "the content-authored slogan across the top: " .. tostring(ui_controls.record(ui.notice).text)
)

-- Every declared product is on the window, in its declared category,
-- with an atlas sprite the client can actually resolve and the stock the
-- file says. A shelf row whose art did not resolve would draw a blank
-- button, which is the failure this checks.
local WANT: { [string]: { name: string, category: string, amount: number } } = {
    card_deck = { name = "Deck of Cards", category = "Cards", amount = 5 },
    captains_aid = { name = "Captain's Aid", category = "Toys", amount = 1 },
    dice_bag = { name = "Bag of Dice", category = "Other", amount = 10 },
}
local found = 0
local products = ui_controls.rows(ui.products)
for _, row in ipairs(products) do
    local product = ui_controls.text(ui_controls.record(row.payload).product)
    local want = WANT[product]
    assert(want ~= nil, "the shelf stocks nothing undeclared: " .. tostring(product))
    assert(row.label == want.name, product .. " is called " .. want.name)
    assert(row.category == want.category, product .. " is on the " .. want.category .. " shelf")
    assert(row.sprite ~= "missing", product .. " resolves to atlas art")
    assert(
        row.stock == want.amount,
        product .. " stocks " .. want.amount .. ", got " .. tostring(row.stock)
    )
    found += 1
end
assert(found == 3, "three products, got " .. found)
assert(
    products[1].category == "Cards"
        and products[2].category == "Toys"
        and products[3].category == "Other",
    "content owns the shelf-group order"
)

-- ---- a bag of dice, and the dice really in it -------------------------
ui_controls.vend(p, "dice_bag")
t.tick()
assert(t.count_items("dice_bag") == 1, "a bag came out")
-- The vend drops at the MACHINE's feet, never the buyer's, so a machine
-- can never mint onto a tile it cannot see (sim/ui/vending.rs).
assert(t.item_at(2, 1, "dice_bag") ~= nil, "at the machine's feet")

t.ui_close(p)
t.tick()
t.click(p, 2, 1, t.target_at(p, 2, 1, "dice_bag"))
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
    assert(
        t.hands(p).held == ROSTER[i],
        "slot " .. i .. " is the " .. ROSTER[i] .. ", got " .. tostring(t.hands(p).held)
    )
    t.drop(p)
    t.tick()
    t.swap_hands(p)
end
t.drop(p)
t.tick()

-- ...and one of them rolls, which is the whole point of a machine that
-- hands out dice rather than a floor that has two on it.
t.click(p, 1, 1, t.target_at(p, 1, 1, "d20"))
t.tick()
t.use_self(p)
t.tick()
local said = table.concat(t.messages(p), "\n")
assert(said:find("You roll the d20. It lands on", 1, true), "a vended die rolls: " .. said)
t.drop(p)
t.tick()

-- ---- a deck, and a card off it ----------------------------------------
t.click(p, 2, 1, t.target_at(p, 2, 1))
t.tick()
ui_controls.vend(p, "card_deck")
t.tick()
assert(t.count_items("card_deck") == 1, "a deck came out")
t.ui_close(p)
t.tick()
t.click(p, 2, 1, t.target_at(p, 2, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == "card_deck", "the deck is in hand")

t.click(p, 1, 2)
t.tick()
local card = t.item_at(1, 2, "card")
assert(card ~= nil, "a vended deck deals a card")
assert(
    assert(card.state, "the card has a face state"):sub(1, 5) == "down_",
    "face down: " .. tostring(card.state)
)
assert(card.sprite == "card_back", "showing its back: " .. tostring(card.sprite))
-- The deck's shuffle is written on the record the moment it is dealt
-- from, which is the only trace a string in `ScriptVars` leaves.
local wrote = t.ledger_rows("VarSet")
assert(
    #wrote >= 2 and wrote[#wrote - 1].key == "lunatic/tfs:order",
    "the vended deck kept its own order"
)
assert(
    wrote[#wrote].key == "lunatic/tfs:picture",
    "and repainted itself beside it: " .. tostring(wrote[#wrote].key)
)

-- ---- the Captain's Aid, which the machine is stingy with --------------
t.drop(p)
t.tick()
t.click(p, 2, 1, t.target_at(p, 2, 1))
t.tick()
ui_controls.vend(p, "captains_aid")
t.tick()
assert(t.count_items("captains_aid") == 1, "the one Aid came out")
-- tg stocks exactly one (games.dm:26), and a finite shelf must actually
-- run out -- otherwise `amount` is decoration.
local empty = ui_controls.product(p, "captains_aid")
assert(empty.disabled, "the exhausted product button is disabled")
t.tick()
assert(t.count_items("captains_aid") == 1, "and the shelf is empty: a second buy mints nothing")

-- ---- nothing else is for sale here ------------------------------------
-- The negative half, and the one that matters: a payload naming a
-- prototype this machine does not stock buys nothing. The window is a
-- client claim like any other (crates/lunatic-server/AGENTS.md), and
-- the shelf list is the only thing that decides.
for _, ref in ipairs({ "cola", "d20", "card", "id_captain", "toolbox" }) do
    local before = t.count_items(ref)
    assert(not ui_controls.has_product(p, ref), "excluded product has no rendered control")
    t.tick()
    assert(t.count_items(ref) == before, "Good Clean Fun does not deal in " .. ref)
end

-- ---- out of reach, and out of power -----------------------------------
-- Two refusals the shelf above never meets. A shop is an arm's-length
-- click: across a room the window stays shut. And a corded machine whose
-- mains are gone is a dark box that says so instead of opening
-- (fixtures/vendor.luau, the script every vendor here shares).
t.world(
    [==[(
    name: "rec room corridor",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    },
    rows: [
        "#######",
        "#o....#",
        "#....g#",
        "#######",
    ],
    structures: [(5, 1, "player_spawn"), (1, 2, "apc")],
    machines: [(2, 1, "games_vendor")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    0
)

local crew = t.join()
t.tick()
local far_x, far_y = t.pos(crew)
assert(far_x == 5 and far_y == 1, "the crewman starts three tiles down the corridor")
local shelf_target = assert(t.target_at(crew, 2, 1), "the machine is in plain view")
t.click(crew, 2, 1, shelf_target)
t.tick()
assert(t.ui(crew) == nil, "and cannot shop from across the room")

for _ = 1, 2 do
    t.move(crew, "west")
    t.run_ticks(5)
end
local near_x, near_y = t.pos(crew)
assert(near_x == 3 and near_y == 1, "standing beside it: " .. near_x .. "," .. near_y)
t.click(crew, 2, 1, t.target_at(crew, 2, 1))
t.tick()
assert(t.ui(crew) ~= nil, "beside it, with power, the shelf opens")
t.ui_close(crew)
t.tick()

t.outage()
t.run_ticks(5)
t.click(crew, 2, 1, t.target_at(crew, 2, 1))
t.tick()
assert(t.ui(crew) == nil, "with the mains gone the shelf stays shut")
local heard = table.concat(t.messages(crew), "\n")
assert(heard:find("The machine is dark and silent.", 1, true), "and the machine says why: " .. heard)
