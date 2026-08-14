-- A grille, and the windows that hang in one.
--
-- tg keeps the grille and the pane as two objects sharing a tile; here
-- they are one structure wearing two pictures. Josh's point holds
-- either way: the glass covers the grille, so a click lands on the
-- pane and the mesh underneath is unreachable until the glass is out.
-- One structure gets there by construction instead of by leaning on
-- the hit-test, and the reachable steps come out the same. The stack
-- is drawn bottom-first, so the mesh shows THROUGH the glass -- tg's
-- window art has no fully opaque pixel in it, and that is the look.
--
-- Dense but not opaque: it stops you walking through and does not stop
-- you seeing through. That distinction is why those are two flags.
--
-- The times below are tg's, and the asymmetry is the point: two
-- seconds to fit a reinforced pane, THIRTY across five tools to get it
-- back out. A window is cheap to put up and expensive to remove, which
-- is most of what makes it worth putting up.
return {
    id = "grille",
    name = "grille",
    sprite = "grille",
    dense = true,
    opaque = false,
    -- States are adjectives because the engine composes refusals out of
    -- them: "The grille must be bolted first." reads as English only if
    -- the state is named like one.
    states = {
        "bolted",
        "unbolted",
        -- plain glass
        "glazed",
        "unsealed",
        -- reinforced glass: tg's security ladder
        "reinforced",
        "heated",
        "unscrewed",
        "popped",
        "cut",
    },
    -- An unfastened grille is not held to the deck, so it shoves like
    -- any other loose thing -- the same marker the girder work added.
    loose = { "unbolted" },
    -- Glass stops air. tg says this in window.dm:405 (`can_atmos_pass`
    -- returns false for a window that is anchored, dense and fulltile),
    -- and it is why a station can have a viewport at all: without it a
    -- window in a hull is a hole you happen to be able to see through.
    --
    -- Every glass-bearing state is listed, including the ones partway
    -- through disassembly. That is deliberate and it is tg's answer
    -- too: the pane is still standing in the frame until the step that
    -- hands it back as sheets. Half a minute of unscrewing a hull
    -- window is half a minute in which the room keeps its air -- and
    -- then does not.
    airtight = {
        "glazed",
        "unsealed",
        "reinforced",
        "heated",
        "unscrewed",
        "popped",
        "cut",
    },
    state_sprites = {
        glazed = { "grille", "window" },
        unsealed = { "grille", "window" },
        -- Every reinforced state looks identical from across the room.
        -- Deliberate: you cannot see that someone is half a minute into
        -- taking your window apart.
        reinforced = { "grille", "rwindow" },
        heated = { "grille", "rwindow" },
        unscrewed = { "grille", "rwindow" },
        popped = { "grille", "rwindow" },
        cut = { "grille", "rwindow" },
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

        -- ---- plain glass: two seconds in, fourteen out ----
        {
            at = "bolted",
            with = { glass = 2 },
            secs = 2.0,
            to = "glazed",
            start = "You start fitting the pane into the grille.",
            done = "The window settles into its frame.",
        },
        {
            at = "glazed",
            tool = "screwdriver",
            secs = 4.0,
            to = "unsealed",
            start = "You start unscrewing the pane from its frame.",
            done = "The pane sits loose in the frame.",
        },
        {
            at = "unsealed",
            tool = "screwdriver",
            secs = 4.0,
            to = "glazed",
            start = "You start screwing the pane back down.",
            done = "The pane is secure again.",
        },
        {
            at = "unsealed",
            tool = "crowbar",
            secs = 10.0,
            yields = { glass = 2 },
            to = "bolted",
            start = "You start levering the pane out of the frame.",
            done = "The pane comes free.",
        },

        -- ---- reinforced: tg's five-tool ladder ----
        -- welder 15 s, screwdriver 5 s, crowbar 4 s, cutters 2 s,
        -- wrench 4 s (window.dm's *_act_secondary chain).
        {
            at = "bolted",
            with = { rglass = 2 },
            secs = 2.0,
            to = "reinforced",
            start = "You start fitting the reinforced pane.",
            done = "The reinforced window settles into its frame.",
        },
        {
            at = "reinforced",
            tool = "welder",
            secs = 15.0,
            fuel = 3.0,
            to = "heated",
            start = "You start heating the security screws.",
            done = "The security screws glow white hot.",
        },
        {
            at = "heated",
            tool = "screwdriver",
            secs = 5.0,
            to = "unscrewed",
            start = "You dig into the heated screws.",
            done = "The screws come out, and a gap opens around the pane.",
        },
        {
            at = "unscrewed",
            tool = "crowbar",
            secs = 4.0,
            to = "popped",
            start = "You wedge the crowbar into the gap and pry.",
            done = "The panel pops out, exposing thin metal bars.",
        },
        {
            at = "popped",
            tool = "cutters",
            secs = 2.0,
            to = "cut",
            start = "You start cutting the exposed bars.",
            done = "The panel falls away, exposing the frame bolts.",
        },
        {
            at = "cut",
            tool = "wrench",
            secs = 4.0,
            yields = { rglass = 2 },
            to = "bolted",
            start = "You start unfastening the frame bolts.",
            done = "The bolts back out and the pane comes loose.",
        },
    },
}
