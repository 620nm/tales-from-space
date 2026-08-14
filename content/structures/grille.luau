-- A grille, and the windows that hang in one.
--
-- tg keeps the grille and the pane as two objects sharing a tile; here
-- they are one structure wearing two pictures, because "which of these
-- did I click" is a question with no good answer and this way it never
-- gets asked. The stack is drawn bottom-first, so the mesh shows
-- THROUGH the glass -- tg's window art has no fully opaque pixel in it,
-- and that is the whole look.
--
-- Dense but not opaque: it stops you walking through and does not stop
-- you seeing through. That distinction is why those are two flags.
return {
    id = "grille",
    name = "grille",
    sprite = "grille",
    dense = true,
    opaque = false,
    -- States are adjectives because the engine composes refusals out of
    -- them: "The grille must be bolted first." reads as English only if
    -- the state is named like one.
    states = { "bolted", "unbolted", "glazed", "reinforced", "loosened" },
    -- An unfastened grille is not held to the deck, so it shoves like
    -- any other loose thing -- the same marker the girder work added.
    loose = { "unbolted" },
    state_sprites = {
        glazed = { "grille", "window" },
        -- Unscrewed but still in its frame: the pane looks the same
        -- from across the room, which is exactly the point — you
        -- cannot see that someone has started taking it apart.
        reinforced = { "grille", "rwindow" },
        loosened = { "grille", "rwindow" },
    },
    build = {
        on = { "floor", "plating" },
        with = { rod = 2 },
        secs = 1.0,
        start = "You start weaving the rods into a grille.",
        done = "The grille stands.",
    },
    transitions = {
        -- tg gates glazing on the grille being fastened down
        -- (grille.dm: "needs to be fastened to the floor first!"), and
        -- a screwdriver toggles that at no delay.
        {
            at = "bolted",
            tool = "screwdriver",
            to = "unbolted",
            done = "You unfasten the grille from the floor.",
        },
        {
            at = "unbolted",
            tool = "screwdriver",
            to = "bolted",
            done = "You fasten the grille to the floor.",
        },
        {
            at = "unbolted",
            tool = "cutters",
            secs = 1.0,
            yields = { rod = 2 },
            gone = true,
            start = "You start snipping the grille apart.",
            done = "The grille comes apart.",
        },
        {
            at = "bolted",
            with = { glass = 2 },
            secs = 2.0,
            to = "glazed",
            start = "You start fitting the pane into the grille.",
            done = "The window settles into its frame.",
        },
        {
            at = "bolted",
            with = { rglass = 2 },
            secs = 2.0,
            to = "reinforced",
            start = "You start fitting the reinforced pane.",
            done = "The reinforced window settles into its frame.",
        },
        -- Only an empty grille comes apart: the glass goes first, or
        -- the rods would come out from under a standing pane.
        {
            at = "bolted",
            tool = "cutters",
            secs = 1.0,
            yields = { rod = 2 },
            gone = true,
            start = "You start snipping the grille apart.",
            done = "The grille comes apart.",
        },
        {
            at = "glazed",
            tool = "crowbar",
            secs = 2.0,
            yields = { glass = 2 },
            to = "bolted",
            start = "You start prying the pane out.",
            done = "The pane comes free.",
        },
        -- Reinforced glass is bolted in. Unscrew it first, and anyone
        -- watching has time to object -- which is what "reinforced"
        -- buys you and why it is worth the extra sheet.
        {
            at = "reinforced",
            tool = "screwdriver",
            secs = 4.0,
            to = "loosened",
            start = "You start unscrewing the pane's bolts.",
            done = "The bolts back out.",
        },
        {
            at = "loosened",
            tool = "screwdriver",
            secs = 4.0,
            to = "reinforced",
            start = "You start screwing the bolts back down.",
            done = "The bolts bite home.",
        },
        {
            at = "loosened",
            tool = "crowbar",
            secs = 4.0,
            yields = { rglass = 2 },
            to = "bolted",
            start = "You start prying the reinforced pane out.",
            done = "The reinforced pane comes free.",
        },
    },
}
