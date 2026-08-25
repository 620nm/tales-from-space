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
-- are one declared name -- and the roster in `lib/cards.luau` is a
-- hundred and eight of them, every one of which resolves to a cell that
-- was baked. The face-down half all resolve to the SAME cell,
-- `card_back`, and that is the whole trick: the state carries the card's
-- identity, the picture carries only what a bystander is allowed to
-- see. A card lying face down on the table IS the eight of clubs, and
-- the wire says so to nobody.
--
-- Which also means this file needs no script var at all. The deck keeps
-- one (items/card_deck.luau) because a shuffle is not a name; a card is
-- one of a hundred and eight declared names and the engine already
-- stores exactly that, bounded and ledgered, in `ItemState`.
--
-- WHAT TG HAS THAT THIS DOES NOT:
--   * The NAME on the item. tg renames the object as it turns over --
--     `name = flipped ? cardname : "card"` (singlecard.dm:119) -- so an
--     examine reads it out. There is no `sim.set_name`, so a card here
--     is always called "card" and its face is a picture and a sentence
--     to whoever turned it. The picture is the half that reaches the
--     room, which is the half that matters.
--   * Card HANDS (`/obj/item/toy/cards/cardhand`, cardhand.dm) -- two
--     cards clicked together become a fanned overlay stack. That needs
--     an overlay STACK on an item, which is a structures-only feature
--     today (docs/LUAU-API.md §13, Gaps). Deliberately absent rather
--     than faked.
--   * Marked cards, blank cards written on with a pen, x-ray vision,
--     and the tarot/KOTAHI/Wiz-Off decks -- each needs a system this
--     pack has not got, or four hundred more baked cells.
--
-- The two verbs are the two seams a held item has, and they map onto
-- tg's two better than tg's own bindings do:
--   * interaction.use@self -- turn it over. "The only thing it can possibly act
--     on is the item in your own hand" (docs/LUAU-API.md), which is
--     exactly what flipping a card is. tg binds this to `attack_self`
--     too (singlecard.dm:222-228).
--   * interaction.use with the deck named -- put it back. tg's recycle: clicking
--     a deck with a card returns it, face down, to the bottom
--     (deck.dm:183-202). `acts_on_items` is what lets a click that
--     NAMES the deck be this card's business rather than a pickup.

-- The roster, the spelling, the state pair, the English names and the
-- deck's thickness all come out of `lib/cards.luau`, which the deck
-- reads too: one copy of each, and no comment apologising for a second
-- one (docs/SCRIPTING.md 1.6).

local content = {
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
    states = cards.states,
    state_sprites = cards.state_sprites,
    -- A click that names the deck is this card's business rather than a
    -- pickup of whatever is under the cursor (docs/LUAU-API.md). A hook
    -- that declines still falls through to the pickup, so a card
    -- clicked at anything else is picked up as usual.
    acts_on_items = true,
    -- tg's single card sits five 32nds left of centre
    -- (code/modules/cards/singlecard.dm:8) -- a permanent anchor for
    -- the type rather than a jitter, so a card dealt onto a table keeps
    -- reading as a card wherever the scatter puts it.
    base_offset = { x = -5 },
    -- ...and every card lands in its own spot around that anchor.
    -- Without this a hand dealt onto one tile is fifty-four cards
    -- stacked on the same pixel, which reads as one card.
    --
    -- Six is the number tg uses for a thing arriving on the floor out
    -- of somebody's hand (`dropItemToGround`,
    -- code/modules/mob/inventory.dm:356-357), and a dealt card is that
    -- even though the engine mints it rather than dropping it. NOT
    -- tg's ±16 card scatter: that one is 52-card pickup, a deck thrown
    -- at somebody, and it is meant to fling cards clear across the
    -- tile.
    scatter = 6,
    -- tg's `/obj/item/toy` gives cards no throwforce; a thrown one is
    -- litter. `throw_range`/`throw_speed` are tg's defaults, unstated.
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local face_up, key = cards.read(self.state)
        if face_up then
            sim.appearance.set_state({ entity = self, state = "down_" .. key })
            sim.sound.play({ asset = "lunatic/tfs:sound/card_flip", at = user.tile })
            sim.message.send({ recipient = user, message = "You turn the card face down." })
        else
            sim.appearance.set_state({ entity = self, state = "up_" .. key })
            sim.sound.play({ asset = "lunatic/tfs:sound/card_flip", at = user.tile })
            sim.message.send({ recipient = user, message = "You turn the card over. It is the " .. cards.NAMES[key] .. "." })
        end
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        -- Only a deck takes a card back. Anything else -- the deck of
        -- somebody's lunch, the floor, a crewman -- is not this hook's
        -- business, and returning without an effect lets the click fall
        -- through to whatever it would ordinarily have been.
        --
        -- A TABLE is the case that makes the decline load-bearing: the
        -- engine puts a held thing down on a surface only after every
        -- hook has declined (docs/LUAU-API.md, step 9), so a card
        -- clicked at a table lands on the table at the pixel the player
        -- pointed at, and it does so because this hook says "pass"
        -- rather than because anything here knows what a table is.
        if target == nil or target.kind ~= "item" then
            return { replaced = false }
        end
        local deck = target.entity
        if deck.prototype ~= "card_deck" then
            return { replaced = false }
        end

        -- The deck's own bookkeeping, read and written from here. A
        -- card knows which card it is; the deck knows how many it has
        -- and in what order; and neither has to carry the other's list.
        local order = deck.vars["order"]
        -- tg refuses an insert past `card_limit` and returns null rather
        -- than growing the list (`insert`, cards.dm:76-77). Two cases
        -- reach that here and both must be caught: a deck nobody has
        -- dealt from is still whole (`nil`, meaning all fifty-four), and
        -- a deck dealt from ONCE will otherwise take returns forever --
        -- deal from one deck, feed the card to another, and the second
        -- grows past a full deck. Which matters more than tidiness: the
        -- order is a script var with a length cap, so an unbounded deck
        -- eventually meets a refused write while `sim.consume` below has
        -- already eaten the card. Cards would quietly stop existing.
        if order == nil or cards.count(order) >= #cards.FACES then
            sim.message.send({ recipient = user, message = "The deck is already full." })
            return true
        end
        local _, key = cards.read(self.state)
        -- On the BOTTOM, which is tg's own `insert` -- it appends, and
        -- a returned card is the last one you will see again
        -- (cards.dm:74-111). Face down is tg's too: the deck forces it
        -- on the way in (deck.dm:183-190), and it is the reason a card
        -- somebody peeked at is not readable through the side of the
        -- deck.
        local restored = order == "" and key or (key .. "," .. order)
        deck.vars["order"] = restored
        deck.vars["picture"] = cards.picture(cards.count(restored))
        sim.sound.play({ asset = "lunatic/tfs:sound/card_flip", at = ev.at })
        sim.message.send({ recipient = user, message = "You slide the card into the deck." })
        -- The card itself is gone: it is in the deck now, and the deck
        -- is a string. `sim.entity.despawn` does the hand slots and removal
        -- and the ledger row, so this hook can never leave a hand
        -- holding a dead entity.
        sim.entity.despawn({ entity = self })
        return true
    end)
end

return content
