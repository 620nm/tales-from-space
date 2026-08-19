-- One playing card, which is fifty-four cards and a back.
--
-- tg's `/obj/item/toy/singlecard` (code/modules/cards/singlecard.dm).
-- There, a card is an object carrying `cardname` and a `flipped` bit,
-- and its picture is built by pasting one or the other into an icon
-- name: `"singlecard_down_[deckstyle]"` face down, and
-- `"sc_[cardname]_[deckstyle]"` face up (singlecard.dm:137-144).
--
-- HERE THE PAIR IS THE STATE. A card's appearance state is
-- `down_<face>` or `up_<face>`, so the two facts tg keeps in two vars
-- are one declared name -- and the roster below is a hundred and eight
-- of them, every one of which resolves to a cell that was baked. The
-- face-down half all resolve to the SAME cell, `card_back`, and that
-- is the whole trick: the state carries the card's identity, the
-- picture carries only what a bystander is allowed to see. A card lying
-- face down on the table IS the eight of clubs, and the wire says so to
-- nobody.
--
-- Which also means this file needs no script var at all. The deck keeps
-- one (items/card_deck.luau) because a shuffle is not a name; a card is
-- one of a hundred and eight declared names and the engine already
-- stores exactly that, bounded and ledgered, in `ItemState`.
--
-- WHAT TG HAS THAT THIS DOES NOT:
--   * The NAME on the item. tg renames the object as it turns over --
--     `name = flipped ? cardname : "card"` (singlecard.dm:119) -- so an
--     examine reads it out. There is no `ctx.set_name`, so a card here
--     is always called "card" and its face is a picture and a sentence
--     to whoever turned it. The picture is the half that reaches the
--     room, which is the half that matters.
--   * Card HANDS (`/obj/item/toy/cards/cardhand`, cardhand.dm) -- two
--     cards clicked together become a fanned overlay stack. That needs
--     an overlay STACK on an item, which is a structures-only feature
--     today (docs/luau-api.md, the deferred list under appearance
--     states). Deliberately absent rather than faked.
--   * Marked cards, blank cards written on with a pen, x-ray vision,
--     and the tarot/KOTAHI/Wiz-Off decks -- each needs a system this
--     pack has not got, or four hundred more baked cells.
--
-- The two verbs are the two seams a held item has, and they map onto
-- tg's two better than tg's own bindings do:
--   * on_use_self -- turn it over. "The only thing it can possibly act
--     on is the item in your own hand" (docs/luau-api.md), which is
--     exactly what flipping a card is. tg binds this to `attack_self`
--     too (singlecard.dm:222-228).
--   * on_use with the deck named -- put it back. tg's recycle: clicking
--     a deck with a card returns it, face down, to the bottom
--     (deck.dm:183-202). `acts_on_items` is what lets a click that
--     NAMES the deck be this card's business rather than a pickup.

-- tg's own generator, in tg's own order: two jokers, then Hearts,
-- Spades, Clubs, Diamonds, each Ace, 2..10, Jack, Queen, King
-- (`initialize_cards`, deck.dm:44-53). Fifty-four.
--
-- Character for character the same block as items/card_deck.luau's,
-- and written that way on purpose: content files here cannot `require`
-- one another, so the roster exists twice, and two copies that are
-- textually identical are two copies a diff will catch drifting. The
-- deck needs it to shuffle; this file needs it to name the faces.
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

-- The atlas spelling of a face, and the second half of every state
-- name. tg pastes the card's own name into the icon state, capitals
-- and spaces and all; this pack's names are lower case with
-- underscores, so the transformation happens once, here, and the
-- sprite manifest was generated to match.
local function slug(face)
    return (face:lower():gsub(" ", "_"))
end

local states, state_sprites = {}, {}
for _, face in ipairs(FACES) do
    local key = slug(face)
    -- Face down first, so a card whose state was somehow never set
    -- lands on a back rather than on a face -- the safe half of the
    -- pair, since `state` below picks the mint explicitly anyway.
    states[#states + 1] = "down_" .. key
    states[#states + 1] = "up_" .. key
    state_sprites["down_" .. key] = "card_back"
    state_sprites["up_" .. key] = "card_" .. key
end

-- The face a state names, and which way up it is. Every state is one
-- of the two prefixes by construction, so a nil here would mean the
-- engine handed back a state this file never declared -- which it
-- cannot.
local function read(state)
    local up, key = state:match("^(%a+)_(.+)$")
    return up == "up", key
end

-- The English name of a slug, for the sentence. Built from the roster
-- rather than by un-slugging, so the two can never disagree.
local NAMES = {}
for _, face in ipairs(FACES) do
    NAMES[slug(face)] = face
end

-- How many cards a comma-separated order holds. Empty is nought; every
-- other string is its commas plus one.
local function count(order)
    if order == "" then
        return 0
    end
    return select(2, order:gsub(",", "")) + 1
end

-- How thick a deck of `n` looks. tg switches on the same three
-- thresholds in `update_icon_state` (deck.dm:171-181).
--
-- A SECOND COPY of items/card_deck.luau's own `thickness`, and the
-- duplication is deliberate rather than overlooked: content files here
-- cannot `require` one another, and the alternative -- letting a deck
-- keep a stale picture until the next time somebody deals from it --
-- is a lie on the table rather than a repetition in a file. If a
-- shared-module seam ever lands, these two are its first caller.
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

return {
    id = "card",
    name = "card",
    -- The resting picture is the back: an item's base `sprite` is the
    -- fallback for a state that named no cell of its own, and here
    -- every state names one, so this is only what a card would look
    -- like if it somehow had no state at all. A back is the right
    -- answer to that question.
    sprite = "card_back",
    -- tg's `/obj/item/toy/singlecard` defaults to
    -- `icon_state = "sc_Ace of Spades_nanotrasen"` (singlecard.dm:5).
    -- Face DOWN, though: tg's `flipped` defaults false, and a card that
    -- arrived face up would be a card that had already been read.
    state = "down_ace_of_spades",
    states = states,
    state_sprites = state_sprites,
    -- A click that names the deck is this card's business rather than a
    -- pickup of whatever is under the cursor (docs/luau-api.md). A hook
    -- that declines still falls through to the pickup, so a card
    -- clicked at anything else is picked up as usual.
    acts_on_items = true,
    -- tg's single card sits five 32nds left of centre
    -- (code/modules/cards/singlecard.dm:8) -- a permanent anchor for
    -- the type rather than a jitter, so a card dealt onto a table keeps
    -- reading as a card wherever the scatter puts it.
    base_offset = { x = -5 },
    -- tg's `/obj/item/toy` gives cards no throwforce; a thrown one is
    -- litter. `throw_range`/`throw_speed` are tg's defaults, unstated.
    on_use_self = function(ctx, self, user)
        local face_up, key = read(ctx.state(self))
        if face_up then
            ctx.set_state(self, "down_" .. key)
            ctx.sound("card_flip", ctx.pos(user))
            ctx.system_msg(user, "You turn the card face down.")
        else
            ctx.set_state(self, "up_" .. key)
            ctx.sound("card_flip", ctx.pos(user))
            ctx.system_msg(user, "You turn the card over. It is the " .. NAMES[key] .. ".")
        end
    end,
    on_use = function(ctx, self, user, x, y, choice, target)
        -- Only a deck takes a card back. Anything else -- the deck of
        -- somebody's lunch, the floor, a crewman -- is not this hook's
        -- business, and returning without an effect lets the click fall
        -- through to whatever it would ordinarily have been.
        if target == nil or target.kind ~= "item" then
            return "pass"
        end
        local deck = target.entity
        if ctx.item_id(deck) ~= "card_deck" then
            return "pass"
        end

        -- The deck's own bookkeeping, read and written from here. A
        -- card knows which card it is; the deck knows how many it has
        -- and in what order; and neither has to carry the other's list.
        local order = ctx.var(deck, "order")
        -- tg refuses an insert past `card_limit` and returns null rather
        -- than growing the list (`insert`, cards.dm:76-77). Two cases
        -- reach that here and both must be caught: a deck nobody has
        -- dealt from is still whole (`nil`, meaning all fifty-four), and
        -- a deck dealt from ONCE will otherwise take returns forever --
        -- deal from one deck, feed the card to another, and the second
        -- grows past a full deck. Which matters more than tidiness: the
        -- order is a script var with a length cap, so an unbounded deck
        -- eventually meets a refused write while `ctx.consume` below has
        -- already eaten the card. Cards would quietly stop existing.
        if order == nil or count(order) >= #FACES then
            ctx.system_msg(user, "The deck is already full.")
            return
        end
        local _, key = read(ctx.state(self))
        -- On the BOTTOM, which is tg's own `insert` -- it appends, and
        -- a returned card is the last one you will see again
        -- (cards.dm:74-111). Face down is tg's too: the deck forces it
        -- on the way in (deck.dm:183-190), and it is the reason a card
        -- somebody peeked at is not readable through the side of the
        -- deck.
        local restored = order == "" and key or (key .. "," .. order)
        ctx.set_var(deck, "order", restored)
        ctx.set_state(deck, thickness(count(restored)))
        ctx.sound("card_flip", x, y)
        ctx.system_msg(user, "You slide the card into the deck.")
        -- The card itself is gone: it is in the deck now, and the deck
        -- is a string. `ctx.consume` does the hand slots, the despawn
        -- and the ledger row, so this hook can never leave a hand
        -- holding a dead entity.
        ctx.consume(self)
    end,
}
