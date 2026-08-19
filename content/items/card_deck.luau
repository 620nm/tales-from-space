-- A deck of space-grade playing cards, and the first thing in this pack
-- that had to remember something the engine could not enumerate.
--
-- tg's `/obj/item/toy/cards/deck` (code/modules/cards/deck/deck.dm).
-- There, a deck holds a list of card objects and `shuffle_inplace`
-- reorders it (deck.dm:99-112). A list of objects is exactly what this
-- engine will not give content -- and should not: fifty-four entities
-- inside a thing nobody can see, minted at roundstart on every table on
-- the station, to model a fact that is one string.
--
-- SO THE DECK IS A STRING. `ctx.set_var`/`ctx.var` (docs/luau-api.md,
-- script vars) keep one key on this item: `order`, the faces still in
-- it, top first, comma separated. The engine stores it, bounds it,
-- drops it with the deck and ledgers every change, and cannot read a
-- word of it. That is the whole of what a shuffle needs, and this file
-- is the caller that named the mechanism.
--
-- The order is generated on the FIRST deal rather than at spawn,
-- because there is no on_spawn hook and because it is the honest
-- moment: an unopened deck is in no particular order until somebody
-- opens it. `ctx.random` draws from the shift-seeded RNG, so two
-- servers replaying the same shift deal the same cards.
--
-- THE TWO VERBS ARE NOT TG'S BINDINGS, and the divergence is on
-- purpose. tg draws on a bare-handed click and shuffles on alt-click
-- while the deck is WIELDED in two hands (deck.dm:146-169); this engine
-- has neither alt-click nor wielding. What it has is the two seams a
-- held item already owns, and they happen to fit better:
--   * on_use_self -- shuffle. The in-hand key, whose whole definition
--     is that "the only thing it can possibly act on is the item in
--     your own hand" (docs/luau-api.md). Squaring up a deck is that.
--   * on_use -- deal one card, face down, onto the tile you clicked.
--     tg deals into a hand or at a mob; pointing at the table is
--     better, and it is the only form this engine can express, since
--     `ctx.give` does not exist yet (it is on the deferred list, and
--     this is a caller for it).
--
-- A card comes BACK through the card's own hook, not through this file:
-- items/card.luau's `on_use` recognises a deck under the cursor and
-- writes `order` itself. That is the direction tg runs it too
-- (`deck/item_interaction`, deck.dm:192-202) and it keeps the roster of
-- faces in one file.
--
-- NOT PORTED, each because it needs something that does not exist:
-- card hands (an overlay stack on an item), the tarot/KOTAHI/Wiz-Off/
-- blank decks (four hundred more baked cells, and text on cards), the
-- card shoe, 52-card pickup on a throw (fifty-four spawns on one tile),
-- and the mood/memory events a finished game leaves behind.

-- tg's own generator, in tg's own order: two jokers, then Hearts,
-- Spades, Clubs, Diamonds, each Ace, 2..10, Jack, Queen, King
-- (`initialize_cards`, deck.dm:44-53). Fifty-four.
--
-- Character for character the same block as items/card.luau's, and
-- written that way on purpose: content files here cannot `require` one
-- another, so the roster exists twice, and two copies that are
-- textually identical are two copies a diff will catch drifting.
local FACES = {}
FACES[1] = "Joker Clown"
FACES[2] = "Joker Mime"
for _, suit in ipairs({ "Hearts", "Spades", "Clubs", "Diamonds" }) do
    FACES[#FACES + 1] = "Ace of " .. suit
    for pip = 2, 10 do
        FACES[#FACES + 1] = pip .. " of " .. suit
    end
    for _, court in ipairs({ "Jack", "Queen", "King" }) do
        FACES[#FACES + 1] = court .. " of " .. suit
    end
end

-- The atlas and state spelling of a face. Identical to the one in
-- items/card.luau, and identical to how tfs/assets/sprites/80-toys.ron
-- was generated: three copies of one rule, which is two too many and is
-- what a shared-module seam would fix.
local function slug(face)
    return (face:lower():gsub(" ", "_"))
end

local function count(order)
    if order == "" then
        return 0
    end
    return select(2, order:gsub(",", "")) + 1
end

-- How thick the deck looks. tg switches on these exact three thresholds
-- (`update_icon_state`, deck.dm:171-181). items/card.luau carries the
-- same function for the same reason and says so.
local function thickness(n)
    if n >= 27 then
        return "full"
    elseif n >= 11 then
        return "half"
    elseif n >= 1 then
        return "low"
    end
    return "empty"
end

-- A fresh deck, shuffled. Fisher-Yates over the roster, drawing from
-- the shift RNG so the shuffle is a fact about the round rather than
-- about the machine that ran it.
local function shuffled(ctx)
    local order = {}
    for i, face in ipairs(FACES) do
        order[i] = slug(face)
    end
    for i = #order, 2, -1 do
        local j = ctx.random(1, i)
        order[i], order[j] = order[j], order[i]
    end
    return table.concat(order, ",")
end

-- The deck's order, generating it if this is the first time anybody has
-- touched it. `nil` from ctx.var means "nothing has been written here",
-- which for a deck means "still in the box".
local function order_of(ctx, self)
    return ctx.var(self, "order") or shuffled(ctx)
end

return {
    id = "card_deck",
    name = "deck of cards",
    sprite = "card_deck_full",
    -- Four states, and they are a QUANTITY rather than a choice: the
    -- picture of a deck is how thick it still is. Every hook that
    -- changes the count repaints, and the card's return hook does too.
    states = { "full", "half", "low", "empty" },
    state = "full",
    state_sprites = {
        ["full"] = "card_deck_full",
        ["half"] = "card_deck_half",
        ["low"] = "card_deck_low",
        ["empty"] = "card_deck_empty",
    },
    on_use_self = function(ctx, self, user)
        -- Shuffling an EMPTY deck is not magic and must not look like
        -- it: the cards are on the table, and gathering them is the
        -- players' job (each one clicked back in through card.luau).
        local order = order_of(ctx, self)
        if order == "" then
            ctx.system_msg(user, "There is nothing left in the deck to shuffle.")
            return
        end
        -- Reshuffling what is LEFT, not restoring what was dealt. The
        -- roster is only the source of a fresh deck; a deck that has
        -- been dealt from is however many faces are still in the string.
        local held = {}
        for face in order:gmatch("[^,]+") do
            held[#held + 1] = face
        end
        for i = #held, 2, -1 do
            local j = ctx.random(1, i)
            held[i], held[j] = held[j], held[i]
        end
        ctx.set_var(self, "order", table.concat(held, ","))
        ctx.sound("card_shuffle", ctx.pos(user))
        ctx.system_msg(user, "You shuffle the deck.")
    end,
    on_use = function(ctx, self, user, x, y, choice, target)
        -- A click that named something is not a deal. Falling through
        -- rather than eating it keeps a deck from being a thing that
        -- swallows every click made while holding one.
        if target ~= nil then
            return "pass"
        end
        -- Somewhere a card can lie. The engine refuses a spawn onto
        -- anything else and refuses it SILENTLY, so this hook asks
        -- first: a deal that decremented the deck and produced no card
        -- would be a deck that eats itself against a wall. Same
        -- check-twice discipline as construction, one seam smaller.
        local turf = ctx.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" then
            ctx.system_msg(user, "There is nowhere there to put a card.")
            return
        end

        local order = order_of(ctx, self)
        if order == "" then
            ctx.system_msg(user, "The deck is empty.")
            return
        end
        -- The top card is the first entry, and the rest of the string
        -- is the rest of the deck. One read, one write, no round trip:
        -- `ctx.var` is a query and `ctx.set_var` is an effect, so a
        -- hook that wrote and then read would get the old value back.
        local top, rest = order:match("^([^,]+),?(.*)$")
        ctx.set_var(self, "order", rest)
        -- Face DOWN, which is how tg deals unless the dealer says
        -- otherwise (deck.dm:146-161, and `insert` forces it on the way
        -- in). The card that lands is a particular card and nobody can
        -- see which -- the identity is the appearance state, the
        -- picture is the back.
        ctx.spawn_item("card", x, y, "down_" .. top)
        ctx.set_state(self, thickness(count(rest)))
        ctx.sound("card_flip", x, y)
        ctx.system_msg(user, "You deal a card.")
    end,
}
