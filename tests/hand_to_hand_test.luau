-- One hand acting on the other: a card and the deck it came out of,
-- held at the same time.
--
-- tg needs no special case for this at all -- reach there is
-- location-agnostic (`DirectAccess()` is self + loc + the mob's whole
-- inventory, code/_onclick/click.dm:227-233), so the card in your off
-- hand is as clickable as the one on the deck and the ordinary attack
-- chain runs against it. Here a held item has no tile, so the gesture
-- is its own message (`t.use_on_other`, the HUD's occupied-off-hand
-- slot click) and the engine synthesises the same target a floor click
-- would have named. The claim under test is exactly that: THE CONTENT
-- DOES NOT KNOW THE DIFFERENCE. Not one line of items/card.luau was
-- touched to make the first half of this file pass.
--
-- Both directions matter, and both are tg's:
--   * card in hand, deck in the other -- `deck/item_interaction`
--     (deck.dm:192-202), which is items/card.luau's `interaction.use`;
--   * deck in hand, card in the other -- `singlecard/item_interaction`
--     (singlecard.dm:150-158), which is items/card_deck.luau's.
-- A player should never have to work out which of the two they are
-- holding, so the two produce the same result.
--
-- Seed 0 pins the shuffle; nothing here asserts WHICH card, only that
-- the deck's count and its picture follow the cards.
t.world([==[(
    name: "card room",
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

-- What the OTHER hand holds. `t.hands` reports both slots plus which
-- one is active, and which physical slot a pickup lands in depends on
-- how many swaps came before it -- so every assertion below names the
-- hand by its ROLE, exactly as the gesture does.
local function idle(hands)
    return hands[3 - hands.active]
end

-- ---- the deck in one hand, a card in the other ------------------------
t.click(p, 2, 1, t.target_at(2, 1, "card_deck"))
t.tick()
assert(t.hands(p).held == "card_deck", "the deck is in hand")

t.click(p, 1, 2)
t.tick()
assert(t.item_at(1, 2, "card") ~= nil, "and it dealt one card onto the floor")

-- The off hand is filled the only way a player can fill it: swap, then
-- pick up. Which leaves the card active and the deck idle.
t.swap_hands(p)
t.tick()
t.click(p, 1, 2, t.target_at(1, 2, "card"))
t.tick()
local hands = t.hands(p)
assert(hands.held == "card", "the card is in the active hand: " .. tostring(hands.held))
assert(idle(hands) == "card_deck", "and the deck is in the other one")

-- ---- card onto deck ---------------------------------------------------
-- items/card.luau's `interaction.use`, unmodified, reached through the new
-- channel: it asks for `target.kind == "item"` and a deck at
-- `target.entity`, and gets both.
t.use_on_other(p)
t.tick()
hands = t.hands(p)
assert(hands.held == nil, "the card left the hand: " .. tostring(hands.held))
assert(idle(hands) == "card_deck", "the deck did not")
assert(t.item_at(1, 2, "card") == nil and t.item_at(1, 1, "card") == nil,
    "and the card is nowhere on the floor either: it went into the deck")
local said = table.concat(t.messages(p), "\n")
assert(said:find("You slide the card into the deck.", 1, true),
    "and the player was told: " .. said)

-- ---- deck onto card ---------------------------------------------------
-- The same act, the hands the other way round -- tg's own second
-- direction, and this pack's `card_deck.luau` answering it. Deal one
-- out, take it into the off hand, and push the deck at it.
t.swap_hands(p)
t.tick()
assert(t.hands(p).held == "card_deck", "the deck is active again")
t.click(p, 1, 2)
t.tick()
assert(t.item_at(1, 2, "card") ~= nil, "one card back on the floor")

t.swap_hands(p)
t.tick()
t.click(p, 1, 2, t.target_at(1, 2, "card"))
t.tick()
t.swap_hands(p)
t.tick()
hands = t.hands(p)
assert(hands.held == "card_deck", "the DECK is the active hand this time")
assert(idle(hands) == "card", "and the card is the one being acted on")

t.use_on_other(p)
t.tick()
hands = t.hands(p)
assert(hands.held == "card_deck", "the deck stays in hand")
assert(idle(hands) == nil, "the card is gone from the other hand: " .. tostring(idle(hands)))
assert(t.item_at(1, 2, "card") == nil, "and it did not fall on the floor")
said = table.concat(t.messages(p), "\n")
assert(said:find("You slide the card into the deck.", 1, true),
    "one act, one sentence, whichever hand held which: " .. said)

-- ---- and the deck's PICTURE follows ------------------------------------
-- A deck in a hand has no tile to be repainted at; its only view is the
-- inventory panel, which is what `t.hud` reads. Deal it down to ten --
-- tg's own thresholds put 11..26 at half and 1..10 at low
-- (deck.dm:171-181) -- and the eleventh card back must move it up a
-- step, through the hand-to-hand channel.
for _ = 1, 44 do
    t.click(p, 2, 2)
    t.tick()
end
assert(#t.items_at(2, 2) == 44, "forty-four cards dealt onto one tile")
assert(t.hud(p)[t.hands(p).active] == "card_deck_low",
    "ten left is a thin deck: " .. tostring(t.hud(p)[t.hands(p).active]))

t.swap_hands(p)
t.tick()
t.click(p, 2, 2, t.target_at(2, 2, "card"))
t.tick()
t.swap_hands(p)
t.tick()
t.use_on_other(p)
t.tick()
assert(idle(t.hands(p)) == nil, "the eleventh card went back in")
assert(t.hud(p)[t.hands(p).active] == "card_deck_half",
    "and eleven is a half deck again: " .. tostring(t.hud(p)[t.hands(p).active]))

-- ---- a full deck still refuses ----------------------------------------
-- The refusal both hooks keep, reached from the deck's side: an
-- untouched deck is already whole, so it has nowhere to put a
-- fifty-fifth card. tg says "stacked too high" here
-- (singlecard.dm:156); this pack says it the way items/card.luau
-- already says it, because it is one refusal and a player should not
-- have to notice which hand produced the sentence.
--
-- The second deck on the table is the one nobody has dealt from.
t.drop(p)
t.tick()
t.move(p, "east")
t.run_ticks(5)
local px, py = t.pos(p)
assert(px == 2 and py == 1, "standing within reach of the second deck")

t.click(p, 2, 2, t.target_at(2, 2, "card"))
t.tick()
assert(t.hands(p).held == "card", "a card off the pile")
t.swap_hands(p)
t.tick()
t.click(p, 3, 1, t.target_at(3, 1, "card_deck"))
t.tick()
hands = t.hands(p)
assert(hands.held == "card_deck", "the untouched deck is in the active hand")

t.use_on_other(p)
t.tick()
hands = t.hands(p)
assert(hands.held == "card_deck", "the deck is still held")
assert(idle(hands) == "card", "and the card was NOT eaten: " .. tostring(idle(hands)))
said = table.concat(t.messages(p), "\n")
assert(said:find("The deck is already full.", 1, true), "and it said why: " .. said)
