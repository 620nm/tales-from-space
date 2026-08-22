-- Cards meet tables: the deal lands where the dealer pointed.
--
-- tg's `deck_act` is one line long and does two things a click at a
-- table has to do in this order -- draw the top card, then hand it to
-- `table_place_act`, which puts it down at the click's own
-- `ICON_X`/`ICON_Y` (tables_racks.dm:375-384, 387-402). So a deck
-- clicked at a table DEALS rather than being put down, and the card
-- lands on the pixel and not merely on the tile.
--
-- Three separate facts are being asserted, and they are easy to
-- confuse:
--   * the deck's hook answers a click that named a structure at all
--     (it used to decline every named click, which would have put the
--     deck on the table instead of a card);
--   * the card it mints is placed rather than scattered, which is
--     `ctx.spawn_item`'s trailing offset pair suppressing the
--     prototype's own mint-time jitter;
--   * a card ALREADY in a hand goes down through the engine's surface
--     placement instead, because the card's own hook declines
--     everything that is not a deck -- one mechanism reached two ways,
--     landing on the same pixel arithmetic (`pixel = base + click`).
--
-- The card's anchor is what makes that arithmetic visible: tg's single
-- card sits five 32nds left of centre (singlecard.dm:8), so a click at
-- +9 puts a card at +4 and an implementation that forgot the anchor
-- would say +9. Every expected number below is `click - 5`.
--
-- Seed 0, as cards_test.luau uses: the deal order is the shuffle's, and
-- nothing here depends on which card comes off the top.
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
    items: [(1, 1, "card_deck")],
    // Two tables, joined, so a card can be laid on one of them without
    // being read back off a pile on the other.
    structures: [(2, 1, "table"), (2, 2, "table")],
)]==], 0)

local p = t.join()
t.tick()
t.click(p, 1, 1, t.target_at(1, 1, "card_deck"))
t.run_ticks(2)
assert(t.hands(p).held == "card_deck", "the deck is in hand")

-- ---- dealing at a table ---------------------------------------------
t.click(p, 2, 1, t.target_at(2, 1, "table"), 9, -6)
t.run_ticks(2)

local dealt = t.item_at(2, 1, "card")
assert(dealt ~= nil, "a card is on the table")
assert(dealt.state:sub(1, 5) == "down_",
    "face down, as tg deals: " .. tostring(dealt.state))
assert(dealt.offset.x == 4 and dealt.offset.y == -6,
    "on the clicked pixel, measured from the card's own anchor: "
        .. dealt.offset.x .. "," .. dealt.offset.y)

-- ...and the DECK is still in the hand. This is the whole of tg's
-- `deck_act`: a click a hook answered never reaches the engine's
-- generic placement, so pointing a deck at a table deals from it and
-- putting the deck itself down stays the drop verb.
assert(t.hands(p).held == "card_deck", "the deck did not leave the hand")
assert(t.item_at(2, 1, "card_deck") == nil, "and is not lying on the table")

-- ---- dealing at bare deck, which still scatters ----------------------
-- Deliberate divergence, and it is flagged as one in items/card_deck.luau:
-- tg has no floor placement at all, so cards on the deck are this
-- pack's own flavour and they should read as cards that fell out of a
-- hand. The click below carries a pixel and the card ignores it.
t.click(p, 1, 2, nil, 12, 12)
t.run_ticks(2)
local floored = t.item_at(1, 2, "card")
assert(floored ~= nil, "a card is on the floor tile that was clicked")
assert(not (floored.offset.x == 7 and floored.offset.y == 12),
    "not placed on the clicked pixel: " .. floored.offset.x .. "," .. floored.offset.y)
assert(math.abs(floored.offset.x + 5) <= 6 and math.abs(floored.offset.y) <= 6,
    "scattered around the anchor instead: "
        .. floored.offset.x .. "," .. floored.offset.y)

-- ---- one card, in a hand, onto the table -----------------------------
-- The other road to the same pixel. The card's `on_use` declines every
-- target that is not a deck, so the click falls through to the engine's
-- surface step (docs/LUAU-API.md, step 9) and the card is put down
-- exactly as any other held thing would be.
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 2, t.target_at(1, 2, "card"))
t.run_ticks(2)
assert(t.hands(p).held == "card", "the card off the floor is in hand")

t.click(p, 2, 2, t.target_at(2, 2, "table"), -12, 4)
t.run_ticks(2)
assert(t.hands(p).held == nil, "the card left the hand for the table")

local laid = t.item_at(2, 2, "card")
assert(laid ~= nil, "and it is lying on the tile of the table it was clicked at")
assert(laid.offset.x == -17 and laid.offset.y == 4,
    "at its own click, anchor and all: " .. laid.offset.x .. "," .. laid.offset.y)

-- The first deal has not moved: a placement puts down the thing in the
-- hand and touches nothing else on the surface.
assert(#t.items_at(2, 1) == 1, "the dealt card is still alone on the first table")
local first_again = t.item_at(2, 1, "card")
assert(first_again.offset.x == 4 and first_again.offset.y == -6,
    "and still where it was dealt: "
        .. first_again.offset.x .. "," .. first_again.offset.y)
