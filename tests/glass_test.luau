-- Windows, both directions. Putting glass in is quick; getting it out
-- is not, and getting REINFORCED glass out is a five-tool job -- tg's
-- asymmetry, kept on purpose. Every step here is a click a person
-- could make, from a tile they could stand on.
--
-- The room is deliberately 3x3 with the builder in the middle, so all
-- eight neighbours are within REACH and nobody has to walk.
local ROOM = [==[(
    name: "glazing",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [
        (1, 1, "rod"),
        (3, 1, "glass"),
        (1, 3, "screwdriver"),
        (3, 3, "crowbar"),
    ],
)]==]

-- Empty the active hand, then take what is on that tile. A click while
-- holding a material BUILDS and one while holding a tool USES, so the
-- hand has to be empty first.
local function take(p, x, y)
    t.drop(p)
    t.run_ticks(2)
    t.click(p, x, y)
    t.run_ticks(2)
end

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

t.world(ROOM, 7)
local p = t.join()
t.tick()

-- Two rods weave a grille, fastened to the deck as tg's is.
t.click(p, 1, 1)
t.run_ticks(2)
t.click(p, 2, 1)
t.run_seconds(1.5)
assert(t.ledger_has("StructureStep", "grille", "built"), "the grille stands")

-- Two seconds to fit a pane.
take(p, 3, 1)
t.click(p, 2, 1)
t.run_seconds(2.5)
assert(t.ledger_has("StructureStep", "grille", "glazed"), "the pane went in")

-- Load both hands, so the pane can be worked without putting a tool
-- down between rungs (a dropped tool lands underfoot, not back where
-- it came from).
take(p, 1, 3) -- screwdriver, active hand
t.swap_hands(p)
t.run_ticks(2)
take(p, 3, 3) -- crowbar, other hand
t.run_ticks(2)

-- Fourteen seconds to get it back out, and a crowbar alone will not do
-- it: the pane is screwed to its frame first. The refusal names BOTH
-- rungs a crowbar works on rather than whichever the file lists first
-- -- as two whole sentences, never one joined with "or"
-- (docs/localization.md).
local _ = t.messages(p)
t.click(p, 2, 1)
t.run_ticks(4)
local unsealed, unscrewed = false, false
for _, m in ipairs(t.messages(p)) do
    if m == "The grille must be unsealed first." then
        unsealed = true
    elseif m == "The grille must be unscrewed first." then
        unscrewed = true
    end
end
assert(
    unsealed and unscrewed,
    "a crowbar on a sealed pane is told both rungs it needs"
)

t.swap_hands(p) -- screwdriver
t.run_ticks(2)
t.click(p, 2, 1)
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "grille", "unsealed"), "unscrewed")

t.swap_hands(p) -- crowbar
t.run_ticks(2)
t.click(p, 2, 1)
t.run_seconds(10.5)
assert(t.ledger_has("StructureStep", "grille", "bolted"), "the pane came out")
assert(t.count_items("glass") > 0, "and the sheets came back")

-- An unfastened grille takes no glass, exactly as tg refuses it.
t.swap_hands(p) -- screwdriver
t.run_ticks(2)
t.click(p, 2, 1)
t.run_ticks(4)
assert(t.ledger_has("StructureStep", "grille", "unbolted"), "it came loose")

-- ---------------------------------------------------------------
-- Reinforced: five tools and thirty seconds, against two to fit it.
-- Each tool is used exactly once, in order, so a plain drop suffices.
-- ---------------------------------------------------------------
t.world([==[(
    name: "reinforced",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [
        (1, 1, "rod"),
        (3, 1, "rglass"),
        (1, 2, "welder"),
        (3, 2, "screwdriver"),
        (1, 3, "crowbar"),
        (2, 3, "wirecutters"),
        (3, 3, "wrench"),
    ],
)]==], 7)

p = t.join()
t.tick()
t.click(p, 1, 1)
t.run_ticks(2)
t.click(p, 2, 1)
t.run_seconds(1.5)

take(p, 3, 1) -- reinforced sheets
t.click(p, 2, 1)
t.run_seconds(2.5)
assert(t.ledger_has("StructureStep", "grille", "reinforced"), "bolted in")

-- Every rung, in order: welder 15 s, screwdriver 5 s, crowbar 4 s,
-- cutters 2 s, wrench 4 s. Thirty seconds, against two to put it in --
-- which is the entire reason to spend the extra sheet.
take(p, 1, 2) -- welder: heat the security screws
t.click(p, 2, 1)
t.run_seconds(15.5)
assert(t.ledger_has("StructureStep", "grille", "heated"), "screws glowing")

take(p, 3, 2) -- screwdriver
t.click(p, 2, 1)
t.run_seconds(5.5)
assert(t.ledger_has("StructureStep", "grille", "unscrewed"), "screws out")

take(p, 1, 3) -- crowbar
t.click(p, 2, 1)
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "grille", "popped"), "panel popped")

take(p, 2, 3) -- wirecutters
t.click(p, 2, 1)
t.run_seconds(2.5)
assert(t.ledger_has("StructureStep", "grille", "cut"), "bars cut")

take(p, 3, 3) -- wrench
t.click(p, 2, 1)
t.run_seconds(4.5)
assert(t.count_items("rglass") > 0, "the reinforced sheets came back")
assert(t.ledger_has("StructureStep", "grille", "bolted"), "an empty grille remains")
