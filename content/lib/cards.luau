-- THE DECK, as a fact rather than as two copies of a fact.
--
-- A card and a deck of cards each need the same four things: the roster
-- of fifty-four faces in tg's order, how a face is spelled in the atlas,
-- how many cards a comma-separated order holds, and how thick a deck of
-- that many looks. Both files used to carry all four, character for
-- character, with a comment in each apologising for it and naming the
-- shared-module seam that would fix it. This is that seam
-- (docs/SCRIPTING.md 1.6), and these are its first callers.
local cards = {}

-- tg's own generator, in tg's own order: two jokers, then Hearts,
-- Spades, Clubs, Diamonds, each Ace, 2..10, Jack, Queen, King
-- (`initialize_cards`, deck.dm:44-53). Fifty-four.
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
cards.FACES = FACES

-- The atlas spelling of a face, and the second half of every state
-- name. tg pastes the card's own name into the icon state, capitals and
-- spaces and all; this pack's names are lower case with underscores, so
-- the transformation happens once, here, and the sprite manifest
-- (tfs/assets/sprites/80-toys.ron) was generated to match.
function cards.slug(face)
    return (face:lower():gsub(" ", "_"))
end

-- THE PAIR IS THE STATE. A card's appearance state is `down_<face>` or
-- `up_<face>`, so the two facts tg keeps in two vars (`cardname` and
-- `flipped`, singlecard.dm:137-144) are one declared name -- and the
-- roster below is a hundred and eight of them, every one of which
-- resolves to a cell that was baked. The face-down half all resolve to
-- the SAME cell, `card_back`, and that is the whole trick: the state
-- carries the card's identity, the picture carries only what a
-- bystander is allowed to see.
local states, state_sprites = {}, {}
for _, face in ipairs(FACES) do
    local key = cards.slug(face)
    -- Face down first, so a card whose state was somehow never set
    -- lands on a back rather than on a face -- the safe half of the
    -- pair, since items/card.luau picks the mint explicitly anyway.
    states[#states + 1] = "down_" .. key
    states[#states + 1] = "up_" .. key
    state_sprites["down_" .. key] = "card_back"
    state_sprites["up_" .. key] = "card_" .. key
end
cards.states = states
cards.state_sprites = state_sprites

-- The English name of a slug, for the sentence a player reads when they
-- turn one over. Built from the roster rather than by un-slugging, so
-- the two can never disagree.
local NAMES = {}
for _, face in ipairs(FACES) do
    NAMES[cards.slug(face)] = face
end
cards.NAMES = NAMES

-- The face a state names, and which way up it is. Every state is one of
-- the two prefixes by construction, so a nil here would mean the engine
-- handed back a state nothing declared -- which it cannot.
function cards.read(state)
    local up, key = state:match("^(%a+)_(.+)$")
    return up == "up", key
end

-- How many cards a comma-separated order holds. Empty is nought; every
-- other string is its commas plus one.
function cards.count(order)
    if order == "" then
        return 0
    end
    return select(2, order:gsub(",", "")) + 1
end

-- How thick a deck of `n` looks. tg switches on the same three
-- thresholds in `update_icon_state` (deck.dm:171-181).
--
-- It answers a CELL rather than a state name: a deck's look is a
-- replicated script var its prototype hangs `sprite` on, so what goes
-- into the var is the picture every viewer draws.
function cards.picture(n)
    if n >= 27 then
        return "card_deck_full"
    elseif n >= 11 then
        return "card_deck_half"
    elseif n >= 1 then
        return "card_deck_low"
    end
    return "card_deck_empty"
end

return cards
