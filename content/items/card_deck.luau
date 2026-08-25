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
-- SO THE DECK IS A STRING. `sim.set_var`/`sim.var` (docs/LUAU-API.md,
-- script vars) keep one key on this item: `order`, the faces still in
-- it, top first, comma separated. The engine stores it, bounds it,
-- drops it with the deck and ledgers every change, and cannot read a
-- word of it. That is the whole of what a shuffle needs, and this file
-- is the caller that named the mechanism.
--
-- The order is generated on the FIRST deal rather than at spawn,
-- because there is no on_spawn hook and because it is the honest
-- moment: an unopened deck is in no particular order until somebody
-- opens it. `sim.random` draws from the shift-seeded RNG, so two
-- servers replaying the same shift deal the same cards.
--
-- THE TWO VERBS ARE NOT TG'S BINDINGS, and the divergence is on
-- purpose. tg draws on a bare-handed click and shuffles on alt-click
-- while the deck is WIELDED in two hands (deck.dm:146-169); this engine
-- has neither alt-click nor wielding. What it has is the two seams a
-- held item already owns, and they happen to fit better:
--   * interaction.use@self -- shuffle. The in-hand key, whose whole definition
--     is that "the only thing it can possibly act on is the item in
--     your own hand" (docs/LUAU-API.md). Squaring up a deck is that.
--   * interaction.use -- deal one card, face down, onto the tile you clicked.
--     tg deals into a hand or at a mob; pointing at the table is
--     better, and it is the only form this engine can express, since
--     `sim.give` does not exist yet (it is on the deferred list, and
--     this is a caller for it). Pointed AT A TABLE it is tg exactly --
--     `deck_act` draws a card and lays it on the table
--     (tables_racks.dm:375-384) -- so the deck deals rather than being
--     put down. Putting the deck itself down is the drop verb, which
--     is how everything else leaves a hand.
--
-- A card comes back BOTH ways round, because tg does:
--   * card in hand, deck under the cursor -- items/card.luau's
--     `interaction.use` recognises the deck and writes `order` itself, which is
--     tg's `deck/item_interaction` (deck.dm:192-202);
--   * DECK in hand, card under the cursor -- this file's `interaction.use`
--     below, which is tg's `singlecard/item_interaction`: an unwielded
--     deck used on a card recycles the card rather than dealing onto
--     it (singlecard.dm:150-158). There is no wielding here, so the
--     deck always takes it back.
-- The second direction is what makes the gesture work with the card in
-- one hand and the deck in the other, whichever way round the player
-- happens to be holding them (sim/offhand.rs).
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

-- The face a card's appearance state names. Every card state is
-- `down_<slug>` or `up_<slug>` by construction (items/card.luau
-- declares them), so this reads the second half and ignores which way
-- up the card was lying: a card goes into a deck face down regardless
-- (tg's `insert` forces it, deck.dm:183-190).
local function face_of(state)
    local _, key = state:match("^(%a+)_(.+)$")
    return key
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
--
-- It answers a PICTURE rather than a state name, because the deck's
-- look is not an engine state any more: it is a replicated script var
-- the prototype below hangs `sprite` on, and what the var carries is
-- the cell every viewer draws.
local function picture(n)
    if n >= 27 then
        return "card_deck_full"
    elseif n >= 11 then
        return "card_deck_half"
    elseif n >= 1 then
        return "card_deck_low"
    end
    return "card_deck_empty"
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
        local j = math.random(1, i)
        order[i], order[j] = order[j], order[i]
    end
    return table.concat(order, ",")
end

-- The deck's order, generating it if this is the first time anybody has
-- touched it. `nil` from sim.var means "nothing has been written here",
-- which for a deck means "still in the box".
local function order_of(ctx, self)
    return self.vars["order"] or shuffled(ctx)
end

local content = {
    id = "card_deck",
    name = "deck of cards",
    -- THE PICTURE FOLLOWS THE STRING, not a roster the engine keeps.
    --
    -- How thick a deck looks is a function of `order` -- a fifty-four
    -- entry shuffle the engine stores and cannot read -- so the four
    -- thicknesses were never four states the engine had any business
    -- minting, indexing and reporting. They are one more thing this
    -- file knows and the engine does not, which is what a script var
    -- is for. `base` is the picture a viewer draws until it is told
    -- otherwise (an unopened deck is whole), `var` names the key, and
    -- `states` is every cell the key may name so the bake can check
    -- each one exists. docs/CONTENT-SCHEMA.md §1.3.
    sprite = {
        base = "card_deck_full",
        var = "lunatic/tfs:picture",
        states = { "card_deck_full", "card_deck_half", "card_deck_low", "card_deck_empty" },
    },
    -- A click that NAMES a card is the deck's business rather than a
    -- pickup of the card -- tg's `interact_with_atom` half of the
    -- chain, and the flag that lets `interaction.use` below see an item target
    -- at all (docs/LUAU-API.md). Everything that is not a card still
    -- falls through, so a deck in hand never became a thing that
    -- swallows every click made while holding one.
    acts_on_items = true,
}

if sim ~= nil then
    sim.define("script_var", "lunatic/tfs:order", { replicate = "server" })
    -- The one key that is NOT the mod's private business: a picture is
    -- for whoever is looking at it, so it replicates to every session
    -- that can see the thing and to nobody else. The engine still reads
    -- nothing out of it -- it checks the string against the roster
    -- above and hands it to the viewers.
    sim.define("script_var", "lunatic/tfs:picture", { replicate = "sight" })
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        -- Shuffling an EMPTY deck is not magic and must not look like
        -- it: the cards are on the table, and gathering them is the
        -- players' job (each one clicked back in through card.luau).
        local order = order_of(ctx, self)
        if order == "" then
            sim.message.send({ recipient = user, message = "There is nothing left in the deck to shuffle." })
            return true
        end
        -- Reshuffling what is LEFT, not restoring what was dealt. The
        -- roster is only the source of a fresh deck; a deck that has
        -- been dealt from is however many faces are still in the string.
        local held = {}
        for face in order:gmatch("[^,]+") do
            held[#held + 1] = face
        end
        for i = #held, 2, -1 do
            local j = math.random(1, i)
            held[i], held[j] = held[j], held[i]
        end
        self.vars["order"] = table.concat(held, ",")
        sim.sound.play({ asset = "lunatic/tfs:sound/card_shuffle", at = user.tile })
        sim.message.send({ recipient = user, message = "You shuffle the deck." })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        -- A click that named a loose ITEM is not a deal: that is the
        -- pickup, or a card being fed back in through items/card.luau.
        -- Falling through rather than eating it keeps a deck from being
        -- a thing that swallows every click made while holding one.
        --
        -- A click that named a STRUCTURE is a deal, and it is tg's:
        -- clicking a table with a deck in hand draws the top card and
        -- puts it on the table (`deck_act` -> `table_place_act`,
        -- deck.dm via tables_racks.dm:375-384). It deals rather than
        -- putting the deck down because a hook that answers a click
        -- keeps it -- the engine's surface placement is the LAST thing
        -- a click can mean (docs/LUAU-API.md), which is exactly tg's
        -- order. Putting the DECK itself down is the drop verb, as it
        -- is for everything else in a hand.
        -- A click that named a CARD is tg's recycle, run from the
        -- deck's side: an unwielded deck used on a card puts the card
        -- back rather than dealing onto it
        -- (`singlecard/item_interaction`, singlecard.dm:150-158). It
        -- is the same act items/card.luau performs from the card's
        -- side, and it exists so the gesture works whichever hand is
        -- holding which -- a deck in the active hand and a card in the
        -- other reaches this hook, and the reverse reaches that one.
        if target ~= nil and target.kind == "item" then
            local card = target.entity
            if card.prototype ~= "card" then
                return { replaced = false }
            end
            -- The same two refusals the card's own hook keeps, for the
            -- same reason: tg's `insert` returns null past `card_limit`
            -- rather than growing the list (cards.dm:76-77), a deck
            -- nobody has dealt from is already whole (`nil` order), and
            -- an unbounded order would eventually meet a refused write
            -- with the card already eaten.
            local order = self.vars["order"]
            if order == nil or count(order) >= #FACES then
                sim.message.send({ recipient = user, message = "The deck is already full." })
                return true
            end
            local key = face_of(card.state)
            -- The end items/card.luau writes to, so a card put back
            -- lands in the same place whichever way round the player
            -- did it. Face down is implicit: the state a dealt card
            -- wears never leaves this string, only its face does.
            local restored = order == "" and key or (key .. "," .. order)
            self.vars["order"] = restored
            self.vars["picture"] = picture(count(restored))
            sim.sound.play({ asset = "lunatic/tfs:sound/card_flip", at = ev.at })
            sim.message.send({ recipient = user, message = "You slide the card into the deck." })
            -- `sim.entity.despawn` does the hand slots, removal and the
            -- ledger row, so the card cannot survive as a dead handle
            -- in somebody's off hand.
            sim.entity.despawn({ entity = card })
            return true
        end
        if target ~= nil and target.kind ~= "machine" then
            return { replaced = false }
        end
        -- Somewhere a card can lie. The engine refuses a spawn onto
        -- anything else and refuses it SILENTLY, so this hook asks
        -- first: a deal that decremented the deck and produced no card
        -- would be a deck that eats itself against a wall. Same
        -- check-twice discipline as construction, one seam smaller.
        local turf = sim.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" then
            sim.message.send({ recipient = user, message = "There is nowhere there to put a card." })
            return true
        end

        local order = order_of(ctx, self)
        if order == "" then
            sim.message.send({ recipient = user, message = "The deck is empty." })
            return true
        end
        -- The top card is the first entry, and the rest of the string
        -- is the rest of the deck. One read, one write, no round trip:
        -- `sim.var` is a query and `sim.set_var` is an effect, so a
        -- hook that wrote and then read would get the old value back.
        local top, rest = order:match("^([^,]+),?(.*)$")
        self.vars["order"] = rest
        -- Face DOWN, which is how tg deals unless the dealer says
        -- otherwise (deck.dm:146-161, and `insert` forces it on the way
        -- in). The card that lands is a particular card and nobody can
        -- see which -- the identity is the appearance state, the
        -- picture is the back.
        --
        -- And WHERE it lands. A deal at something the player POINTED
        -- AT is placed on the pixel they pointed at -- tg reads the
        -- click's own `ICON_X`/`ICON_Y` for exactly this
        -- (`table_place_act`, tables_racks.dm:393-398) -- and naming an
        -- offset suppresses the type's mint-time scatter, so a hand
        -- dealt across a table is where the dealer put it.
        --
        -- A deal at bare deck keeps the scatter, and that is deliberate
        -- rather than an oversight: tg has no floor placement at all,
        -- so cards on the deck are this pack's own flavour, and a
        -- card that fell out of a hand should look like one.
        sim.entity.spawn({
            definition = "card",
            at = ev.at,
            initial = {
                state = "down_" .. top,
                -- Nil at bare deck: the click carried no pixel worth
                -- honouring there, and an absent offset is the ordinary
                -- scattered mint.
                offset = target ~= nil and ev.click_offset or nil,
            },
        })
        self.vars["picture"] = picture(count(rest))
        sim.sound.play({ asset = "lunatic/tfs:sound/card_flip", at = ev.at })
        sim.message.send({ recipient = user, message = "You deal a card." })
        return true
    end)
end

return content
