-- Good Clean Fun: "Vends things that the Captain and Head of Personnel
-- are probably not going to appreciate you fiddling with instead of
-- your job..." — tg's `/obj/machinery/vending/games`
-- (code/modules/vending/games.dm:1-8).
--
-- It stands in the Commons because that is the room a shift walks
-- through, and it replaces the two dice somebody left on the table
-- there: a die on a table is one die, and a machine that hands out dice
-- is a rec room. The two crates beside it are the softdrinks machine
-- and the YouTool, and it shares their script — opening a window on
-- click and wobbling when bumped is the behaviour of a vending machine,
-- not of any particular one.
--
-- THREE OF TG'S SIX SHELVES, and the ruling behind the three that are
-- missing is the same one every time: a product is here when it needs
-- nothing this pack has not got.
--   * Cards -- the deck. tg stocks nine decks; eight of them are the
--     same object with a different roster of faces, and each would cost
--     between fifty and four hundred more baked atlas cells for a game
--     nobody has written rules for yet. One deck is a card game.
--   * Toys -- the Captain's Aid. tg's other two are the Intento, a
--     Simon-says machine with a remembered sequence and a per-tick
--     state machine (toys.dm:1627+), and a box of posters and pins.
--   * Other -- the bag of dice, which is the dice this machine
--     replaced, in the bag tg keeps them in.
--
-- What is NOT here, by shelf, so the next person does not have to
-- re-derive it:
--   * Art (crayons, chisel, palette, six canvases, pipe cleaners) --
--     every one of them is a drawing surface or a tool for one, and
--     there is no painting system.
--   * Fishing (eleven products) -- an entire subsystem, plus aquaria,
--     plus a minigame.
--   * Skillchips (ten) -- these are implanted in a brain and grant
--     traits; there are no organs and no traits.
--   * From Other: the camera and its film (photography), both TCG
--     card packs and the binder (a trading-card subsystem with
--     persistence), the dyespray and the razor (hair), the piano-synth
--     headphones (instruments), and the hourglass -- which is the near
--     miss, being one timer and seven pictures, and would work today on
--     `ctx.sleep` plus appearance states. It is left out because its
--     whole output is a countdown overlay floating over the object,
--     which is a rendering feature this engine does not have, and an
--     hourglass you cannot read is furniture.
--
-- NO CONTRABAND AND NO PREMIUM SHELF: content declares only the stock
-- the current game can honestly expose, because there is no currency
-- and no way to hack a machine open. tg hides the fudge die behind the
-- contraband shelf and a skateboard behind the premium shelf
-- (games.dm:104-121). Putting either on
-- the open shelf would be shipping the reward without the lock, so
-- neither is here — the fudge die in particular is a one-file port
-- waiting on a contraband tier, not on anything about dice.
--
-- Prices are likewise absent everywhere in this pack: tg charges
-- PAYCHECK_CREW for this machine's stock, but this game declares no
-- economy. The clean-room shelf exposes only live stock (docs/TGUI.md).
return {
    id = "games_vendor",
    name = "Good Clean Fun",
    sprite = "games_vendor",
    ui = { modules = { "shelf" }, opens_on_click = false },
    dense = true,
    script = "vendor",
    corded = true,
    -- tg's `product_ads`, first of the eight it rotates
    -- (games.dm:4). One line because the window shows one.
    ad = "Roll for initiative!",
    -- tg's category names (games.dm:7-99), in the order this content
    -- wants the clean-room document to show them.
    categories = { "Cards", "Toys", "Other" },
    vends = {
        -- tg stocks five of the standard deck (games.dm:11).
        { item = "card_deck", name = "Deck of Cards", category = "Cards", amount = 5 },
        -- One, as tg does: the Aid is a collector's item and the joke
        -- is that the machine is stingy with it (games.dm:26).
        { item = "captains_aid", name = "Captain's Aid", category = "Toys", amount = 1 },
        -- tg's `/obj/item/storage/dice = 10` (games.dm:96).
        { item = "dice_bag", name = "Bag of Dice", category = "Other", amount = 10 },
    },
}
