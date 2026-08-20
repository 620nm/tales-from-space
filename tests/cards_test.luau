-- A deck of cards: the first thing in this pack that remembers
-- something across invocations.
--
-- The claim under test is not "clicking a deck produces a card". It is
-- that a deck is a DECK -- fifty-four distinct cards, dealt without
-- repeats, in an order fixed by a shuffle nobody can see, out of a
-- string the engine stores and cannot read (`ctx.set_var`/`ctx.var`,
-- docs/luau-api.md). Every earlier per-instance fact in this pack is a
-- number the prototype enumerated; this one is not, and the way to
-- prove the difference is to deal the whole deck and count.
--
-- And the SECRET half, which is the part a spec has to be careful
-- about: a card lying face down is a particular card, and the picture
-- must say nothing about which. `t.layers` is what the client was
-- actually told to draw, so it is the only assertion that can tell a
-- card that is face down from a card that is merely called face down.
--
-- Seed 0 pins the shuffle, so the sequence below is a fact rather than
-- a range; the assertions are still relations (no repeats, fifty-four
-- of them, the face on the floor is the face that was named) so that a
-- change to how many numbers the engine draws before these moves the
-- ORDER without breaking the meaning.
t.world([==[(
    name: "rec room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "card_deck"), (3, 1, "card_deck")],
)]==], 0)

local p = t.join()
t.tick()

-- ---- out of the box, full -------------------------------------------
local boxed = t.item_at(2, 1, "card_deck")
assert(boxed ~= nil, "the deck is on the table")
assert(boxed.state == "full", "an untouched deck is full: " .. tostring(boxed.state))
assert(boxed.sprite == "card_deck_full", "and looks it: " .. tostring(boxed.sprite))

t.click(p, 2, 1, t.target_at(2, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == "card_deck", "the deck is in hand")

-- ---- one card, face down, and nobody can see which --------------------
-- Dealing is a click on a TILE with the deck in hand (this pack's
-- `on_use`), which is tg's deal pointed at the table instead of at a
-- hand -- see items/card_deck.luau for why the bindings differ.
t.click(p, 1, 2)
t.tick()
local first = t.item_at(1, 2, "card")
assert(first ~= nil, "a card is on the tile that was clicked")
assert(first.state:sub(1, 5) == "down_",
    "dealt face down, as tg deals: " .. tostring(first.state))
assert(first.sprite == "card_back",
    "and the picture is the back, not the face: " .. tostring(first.sprite))

-- THE SECRET. The state says which card it is and the wire must not.
-- A card face down on the deck is the eight of clubs and the client is
-- told "card_back" -- the identity lives in the appearance state, and
-- the state is server-side. If this ever fails, every card game on the
-- station is unplayable.
-- Dealt cards do not stack on one pixel. Each is minted with its own
-- offset around the type's anchor, so a hand dealt onto a tile reads
-- as several cards rather than as one.
assert(first.offset ~= nil, "a dealt card has a sub-tile position")
assert(math.abs(first.offset.x + 5) <= 6 and math.abs(first.offset.y) <= 6,
    "and it is scattered around the -5 anchor: "
        .. first.offset.x .. "," .. first.offset.y)

local drawn = table.concat(t.layers(p, t.target_at(1, 2, "card")), " ")
assert(drawn:find("card_back", 1, true),
    "the client was sent the back: " .. drawn)
local secret = first.state:sub(6)
assert(not drawn:find(secret, 1, true),
    "and NOT the face it is hiding (" .. secret .. "): " .. drawn)

local said = table.concat(t.messages(p), "\n")
assert(said:find("You deal a card.", 1, true), "the deal reads out: " .. said)
assert(table.concat(t.sounds(p), " "):find("card_flip", 1, true), "and is heard")

-- The deck's own bookkeeping is on the record, because the engine
-- cannot summarise a string it cannot read.
local wrote = t.ledger_rows("VarSet")
assert(#wrote >= 1, "writing the deck's order is a ledger row")
assert(wrote[#wrote].key == "order",
    "naming the key: " .. tostring(wrote[#wrote].key))

-- ---- turning it over --------------------------------------------------
t.drop(p)
t.tick()
t.click(p, 1, 2, t.target_at(1, 2, "card"))
t.tick()
assert(t.hands(p).held == "card", "the card is in hand")

t.use_self(p)
t.tick()
-- The hand FIRST: a card turned face up is readable to its holder
-- immediately, and the panel is where they read it. This is a second
-- code path from the world sprite below, and it used to show the
-- prototype's picture -- a card back -- however the card was turned.
assert(t.hud(p)[1] == "card_" .. secret,
    "the hand shows the face that was turned up: " .. tostring(t.hud(p)[1]))

t.drop(p)
t.tick()
local faceup = t.item_at(1, 1, "card")
assert(faceup ~= nil, "the card is at the reader's feet")
assert(faceup.state == "up_" .. secret,
    "it is now face up, and it is the same card it always was: "
        .. tostring(faceup.state))
assert(faceup.sprite == "card_" .. secret,
    "wearing that face's cell: " .. tostring(faceup.sprite))
local shown = table.concat(t.layers(p, t.target_at(1, 1, "card")), " ")
assert(shown:find("card_" .. secret, 1, true),
    "and NOW the room can see it: " .. shown)

-- ...and back over again, which is what needed `ctx.state`: a thing
-- that toggles has to ask what it is currently showing.
t.click(p, 1, 1, t.target_at(1, 1, "card"))
t.tick()
t.use_self(p)
t.tick()
assert(t.hud(p)[1] == "card_back",
    "and turning it back down shows a back again: " .. tostring(t.hud(p)[1]))
t.drop(p)
t.tick()
local facedown = t.item_at(1, 1, "card")
assert(facedown.state == "down_" .. secret, "face down again, same card")
assert(facedown.sprite == "card_back", "back to the back")

-- ---- put it back ------------------------------------------------------
-- tg's recycle: clicking a deck while holding a card returns the card
-- to the bottom (deck.dm:192-202). Here that is the CARD's `on_use`
-- with `acts_on_items`, so a click naming the deck is the card's
-- business rather than a pickup. The deck is underfoot, where it was
-- dropped.
t.click(p, 1, 1, t.target_at(1, 1, "card"))
t.tick()
assert(t.hands(p).held == "card", "the card is in hand again")
t.click(p, 1, 1, t.target_at(1, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == nil, "the card left the hand")
assert(t.item_at(1, 1, "card") == nil and t.item_at(1, 2, "card") == nil,
    "and is not lying anywhere: it is in the deck")
local back = t.item_at(1, 1, "card_deck")
assert(back.state == "full", "a deck with all fifty-four back in it is full again")
assert(back.sprite == "card_deck_full", "and looks it: " .. tostring(back.sprite))

-- ---- deal the whole thing ---------------------------------------------
-- The assertion this whole file exists for. Fifty-four deals produce
-- fifty-four DIFFERENT cards, which is only possible if the deck
-- remembered what it had already given out -- and the memory is a
-- string in `ScriptVars`, because a shuffle is not a number the
-- prototype could have enumerated.
t.click(p, 1, 1, t.target_at(1, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == "card_deck", "the deck is in hand again")

for deal = 1, 54 do
    t.click(p, 2, 2)
    t.tick()
    assert(#t.items_at(2, 2) == deal,
        "deal " .. deal .. " put a card on the pile, got " .. #t.items_at(2, 2))
end

-- Empty, and it says so in the picture as well as in the string --
-- tg's own three thresholds (deck.dm:171-181).
t.drop(p)
t.tick()
local emptied = t.item_at(1, 1, "card_deck")
assert(emptied ~= nil, "the deck is at the dealer's feet")
assert(emptied.state == "empty", "and it is empty: " .. tostring(emptied.state))
assert(emptied.sprite == "card_deck_empty", "and looks it")

-- ---- and every one of them is a different card ------------------------
-- Read the way a player would: pick each card up off the pile, turn it
-- over, and see what it says. Fifty-four turns, fifty-four names, no
-- name twice. There is no cheaper assertion that means this -- a deck
-- that handed out the same card fifty-four times would pass every
-- other check in this file.
local seen, names = {}, {}
for card = 1, 54 do
    local on_pile = t.target_at(2, 2, "card")
    assert(on_pile ~= nil, "card " .. card .. " is still on the pile")
    t.click(p, 2, 2, on_pile)
    t.tick()
    assert(t.hands(p).held == "card", "card " .. card .. " is in hand")
    t.use_self(p)
    t.tick()
    local said = t.messages(p)
    local name = said[#said]:match("It is the (.+)%.$")
    assert(name ~= nil, "turning it over names it: " .. tostring(said[#said]))
    assert(not seen[name], "no card comes out of one deck twice: " .. name)
    seen[name] = true
    names[#names + 1] = name
    t.drop(p)
    t.tick()
end
assert(#names == 54, "fifty-four cards, all told: " .. #names)
-- tg's own roster, spot-checked at both ends: the two jokers and the
-- four aces are in a standard deck and nowhere else in it
-- (`initialize_cards`, deck.dm:44-53).
for _, must in ipairs({
    "Joker Clown", "Joker Mime",
    "Ace of Hearts", "Ace of Spades", "Ace of Clubs", "Ace of Diamonds",
    "King of Spades", "2 of Diamonds", "10 of Hearts",
}) do
    assert(seen[must], "a standard deck contains the " .. must)
end

-- ---- a deck will not swallow more than a deck -------------------------
-- Found by RUNNING it, not by the assertions above: the return hook
-- refused only a deck nobody had dealt from, so a deck dealt from ONCE
-- took cards forever. Deal from one deck, feed the card to another, and
-- the second grows past fifty-four -- and since the order is a script
-- var with a length cap, an unbounded deck eventually meets a refused
-- write with the card already consumed by `ctx.consume`. Cards would
-- quietly stop existing.
--
-- tg refuses for the tidier reason and in the same place: `insert`
-- returns null past `card_limit` rather than growing the list
-- (cards.dm:76-77).
--
-- Fifty-four cards are lying at the player's feet by now and the first
-- deck is empty, so the second deck on the table is the whole
-- experiment.
t.move(p, "east")
t.run_ticks(5)
local px, py = t.pos(p)
assert(px == 2 and py == 1, "standing between the cards and the second deck")

-- An untouched deck is whole, so it takes nothing at all.
t.click(p, 1, 1, t.target_at(1, 1, "card"))
t.tick()
assert(t.hands(p).held == "card", "a card off the floor is in hand")
t.click(p, 3, 1, t.target_at(3, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == "card", "an untouched deck refuses a fifty-fifth card")
local refused = table.concat(t.messages(p), "\n")
assert(refused:find("The deck is already full.", 1, true), "and says so: " .. refused)

-- Deal one out of it, so it is fifty-three and has room for exactly one
-- back. The SECOND return is the one that must bounce.
t.drop(p)
t.tick()
t.click(p, 3, 1, t.target_at(3, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == "card_deck", "the second deck is in hand")
t.click(p, 3, 2)
t.tick()
assert(t.item_at(3, 2, "card") ~= nil, "it dealt one, so it has room for one")
t.drop(p)
t.tick()

-- Both the deck and that first card are underfoot now: a drop lands on
-- the dropper's own tile, so putting the deck down moved it off (3, 1).
t.click(p, 2, 1, t.target_at(2, 1, "card"))
t.tick()
assert(t.hands(p).held == "card", "the card put down a moment ago is in hand")
t.click(p, 2, 1, t.target_at(2, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == nil, "the one free slot took it")

t.click(p, 3, 2, t.target_at(3, 2, "card"))
t.tick()
assert(t.hands(p).held == "card", "and one more card is in hand")
t.click(p, 2, 1, t.target_at(2, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == "card",
    "a deck already holding fifty-four refuses the next one")
refused = table.concat(t.messages(p), "\n")
assert(refused:find("The deck is already full.", 1, true),
    "rather than eating it: " .. refused)
t.drop(p)
t.tick()

-- Back where the last section expects to find the player.
t.move(p, "west")
t.run_ticks(5)
px, py = t.pos(p)
assert(px == 1 and py == 1, "back beside the empty deck")

-- ...and they came out SHUFFLED. Without this the file would pass on a
-- deck that dealt tg's roster straight down in declaration order, which
-- is fifty-four different cards and not a deck of cards. Compared both
-- ways round because the pile is read back off the top.
local roster = { "Joker Clown", "Joker Mime" }
for _, suit in ipairs({ "Hearts", "Spades", "Clubs", "Diamonds" }) do
    roster[#roster + 1] = "Ace of " .. suit
    for pip = 2, 10 do
        roster[#roster + 1] = pip .. " of " .. suit
    end
    for _, court in ipairs({ "Jack", "Queen", "King" }) do
        roster[#roster + 1] = court .. " of " .. suit
    end
end
local reversed = {}
for i = #roster, 1, -1 do
    reversed[#reversed + 1] = roster[i]
end
local dealt = table.concat(names, ",")
assert(dealt ~= table.concat(roster, ","), "the deck was shuffled, not read out")
assert(dealt ~= table.concat(reversed, ","), "and not read out backwards either")

-- ---- the fifty-fifth deal ---------------------------------------------
t.click(p, 1, 1, t.target_at(1, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == "card_deck", "the empty deck is in hand")
t.click(p, 2, 2)
t.tick()
assert(#t.items_at(2, 2) == 0, "an empty deck deals nothing")
local told = table.concat(t.messages(p), "\n")
assert(told:find("The deck is empty.", 1, true), "and says so: " .. told)

-- ...and shuffling one is refused rather than quietly restocking it.
-- The cards are on the floor; gathering them is the players' job, and a
-- deck that refilled itself would make the whole memory pointless.
t.use_self(p)
t.tick()
told = table.concat(t.messages(p), "\n")
assert(told:find("There is nothing left in the deck to shuffle.", 1, true),
    "an empty deck cannot be shuffled back into existence: " .. told)
