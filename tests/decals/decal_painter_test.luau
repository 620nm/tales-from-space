local composition = require("@helpers/composition")
local ui_controls = require("@helpers/ui_controls")

-- The decal painter and the decal eraser, and the one claim the whole
-- feature makes: NOBODY DRAWS A CORNER. A player paints tiles; the
-- seam between them is derived from which neighbours now match, so the
-- record on a tile never changes when the picture on it does.
--
-- That is why this spec asserts `sprites` and not just the record. The
-- record says "a blue trim line is here"; the sprites say what the deck
-- actually looks like, and the difference between them is the feature.

local word = ui_controls.word

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function heard(p, name)
    for _, s in ipairs(t.sounds(p)) do
        if s == name then
            return true
        end
    end
    return false
end

-- One step, plus the move cooldown (lunatic_core::MOVE_COOLDOWN_TICKS
-- is 4), so two calls in a row are two steps.
local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- Which dial is which row of buttons in the painter's window: the panel
-- names them positionally on the wire, in the order the prototype
-- declares them (content/items/tools/decal_painter.luau).
local DECAL, PAINT, FACING = "dial0", "dial1", "dial2"

-- Which button on a dial's row wears that word. Looked up rather than
-- counted, because the decal roster grows every time somebody imports
-- another tg family and a spec that hardcoded "decal 4 is the tiling"
-- would break on their content file.
local function pick(p: number, field: string, label: string): string
    for _, tog in ipairs(ui_controls.rows(ui_controls.state(p).toggles)) do
        if tog.field == field and tog.option ~= nil and word(tog.label) == label then
            return ui_controls.text(tog.option)
        end
    end
    error("no " .. field .. " button labelled " .. label)
end

local function set(p: number, field: string, label: string)
    ui_controls.toggle(p, field, pick(p, field, label))
    t.tick()
end

-- What one tile is painted with, and what that paint draws right now.
local function only(x: number, y: number)
    local here = t.decals_at(x, y)
    assert(#here == 1, "want exactly one decal at " .. x .. "," .. y .. ": " .. #here)
    return here[1]
end

local function drawn(x: number, y: number): string
    return table.concat(only(x, y).sprites, "+")
end

-- ---------------------------------------------------------------
-- A room with a three-by-three block of floor tiles in the middle of
-- it, plating around that, and one lattice square at the east end --
-- a grating you see the subfloor through, which is not a deck and
-- takes no paint. It stands on ground, not space: a lattice over space
-- inside the room is a hole in it, and the room would empty through
-- it in seconds and drag the crewman east.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "decals",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '_': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'l': (composition: (substrate: Some("ground"), components: [(component: "lattice")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "########",
        "#__ooo_#",
        "#__ooo_#",
        "#__oool#",
        "########",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "decal_painter"), (2, 1, "decal_eraser"), (3, 2, "crowbar")],
)]==],
    7
)

local p = t.join()
t.tick()

-- Painter in one hand, eraser in the other. Both are deck tools and
-- neither is ever aimed at the other's work: the eraser undoes the
-- painter, one marking at a time.
t.click(p, 1, 1, t.target_at(p, 1, 1, "decal_painter"))
t.run_ticks(2)
t.swap_hands(p)
t.click(p, 2, 1, t.target_at(p, 2, 1, "decal_eraser"))
t.run_ticks(2)
t.swap_hands(p)
local hands = t.hands(p)
assert(
    hands.held == "decal_painter" and hands[3 - hands.active] == "decal_eraser",
    "the painter is in hand and the eraser in the other"
)

-- ---- the window ----
--
-- tg picks decal, colour and direction out of a tgui window with a live
-- preview (decal_painter.dm:100-138). Ours is the generic dial panel,
-- three rows of buttons, and the paint row carries its real swatches.
t.use_self(p)
t.tick()
local ui = ui_controls.state(p)
assert(ui.name == "decal painter", "the in-hand key opens the painter's own window")
local captions: { [string]: string } = {}
local options: { [string]: number } = {}
local blue_swatch = nil
for _, tog in ipairs(ui_controls.rows(ui.toggles)) do
    if tog.option == nil then
        captions[ui_controls.text(tog.field)] = word(tog.label)
    else
        local field = ui_controls.text(tog.field)
        options[field] = (options[field] or 0) + 1
        if field == PAINT and word(tog.label) == "blue" then
            blue_swatch = tog.color
        end
    end
end
assert(captions[DECAL] == "Decal", "the decal dial is labelled")
assert(captions[PAINT] == "Paint" and captions[FACING] == "Facing", "and so are the other two")
assert(options[PAINT] == 12, "tg's twelve tile paints, and no thirteenth")
assert(options[FACING] == 4, "four cardinal facings for the marks that take one")
-- tilecoloring.dm:45-47, carried verbatim in lib/decal_paints.luau.
assert(blue_swatch == "#52B4E9", "the paint buttons carry tg's real hexes")

set(p, PAINT, "blue")

-- Into the middle of the tiled block, where every one of its nine
-- squares is within reach.
walk(p, "east")
walk(p, "east")
walk(p, "east")
walk(p, "south")

-- ---- **the headline**: paint tiles, get a seam ----
--
-- One painted square has no matching neighbour on any side, so all four
-- of its edges are closed and the whole thing is the box piece: a
-- rectangle of trim round one tile.
local _ = t.messages(p)
composition.click_deck(p, 3, 1)
t.run_ticks(2)
assert(said(p, "You spray a Trim line onto the deck."), "the painter says what it laid down")
assert(heard(p, "paint_spray"), "and the room hears the nozzle")
local first = only(3, 1)
assert(first.decal == "trim" and first.paint == "blue", "a blue trim line, by its authored names")
assert(first.color == nil, "a palette paint is not a raw colour")
assert(drawn(3, 1) == "decal_trim_box", "alone on its tile, a trim line draws its box")

-- Paint the square to the east of it. NOTHING WAS DONE TO (3,1) -- and
-- (3,1) changes, because its east side now has a neighbour that
-- matches. Three closed sides is a cap, keyed by the end opposite the
-- open one, so the run reads as a line that continues east.
composition.click_deck(p, 4, 1)
t.run_ticks(2)
assert(#t.decals_at(3, 1) == 1, "the record on the first tile did not move")
assert(first.instance == only(3, 1).instance, "nor was it replaced")
assert(drawn(3, 1) == "decal_trim_cap_w", "but its picture reshaped: the run opens east")
assert(drawn(4, 1) == "decal_trim_cap_e", "and the new tile opens west, back at it")

-- ---- repaint ----
--
-- Placing the same decal again rewrites its colour rather than stacking
-- a second one. And because sameness compares the resolved colour, a
-- red tile beside a blue one is not a run at all: both go back to
-- drawing their own box.
set(p, PAINT, "red")
composition.click_deck(p, 3, 1)
t.run_ticks(2)
local repainted = only(3, 1)
assert(repainted.paint == "red", "the tile is red now")
assert(repainted.instance ~= first.instance, "a repaint mints a fresh instance")
assert(drawn(3, 1) == "decal_trim_box", "and two colours are two decals, not one run")
assert(drawn(4, 1) == "decal_trim_box", "from both sides of the disagreement")

-- ---- the ledger ----
local placed = t.ledger_rows("decal_placed")
assert(#placed == 3, "three acts, three rows: " .. #placed)
local pin = ui_controls.array(placed[1].pos)
assert(pin[1] == 3 and pin[2] == 1, "the first row is pinned to the tile it painted")
assert(placed[1].decal == "trim" and placed[1].color == "blue", "and names what went down")
assert(placed[3].color == "red", "and the repaint names the colour it became")
local target = ui_controls.record(placed[1].target)
local at = ui_controls.record(target.tile)
assert(at.x == 3 and at.y == 1, "the target names the same tile")
assert(target.instance == first.instance, "and the instance that act created")
local actor = ui_controls.record(placed[1].actor)
assert(
    ui_controls.text(actor.kind) == "script" and actor.triggered_by ~= nil,
    "a painted deck is attributable to the hand that painted it"
)

-- ---- a mark, and which way it faces ----
--
-- A mark ignores the seam entirely: one sprite, aimed. tg's painter
-- opens on SOUTH (decal_painter.dm:11); this one is turned east.
set(p, DECAL, "Arrow")
set(p, FACING, "East")
composition.click_deck(p, 3, 3)
t.run_ticks(2)
local arrow = only(3, 3)
assert(arrow.facing == "e", "the facing dial aimed it")
assert(arrow.paint == nil and arrow.color == nil, "tg's arrow carries its own colour")
assert(drawn(3, 3) == "decal_mark_arrow_e", "and a mark draws exactly one piece")

-- ---- a decal is not a thing you can click ----
--
-- Which is what makes repainting over one work at all: a decorated tile
-- is still a bare deck click, so the painter always reaches the deck.
assert(t.target_at(p, 3, 1, "trim") == nil, "a decal is not pickable in play")

-- ---- four is the budget ----
--
-- The engine caps a tile at four decals, and the painter never
-- second-guesses it: one keyed sentence, and the click is spent.
set(p, DECAL, "Trim line")
composition.click_deck(p, 5, 2)
t.run_ticks(2)
set(p, DECAL, "Trim line, filled")
composition.click_deck(p, 5, 2)
t.run_ticks(2)
set(p, DECAL, "Tiling")
composition.click_deck(p, 5, 2)
t.run_ticks(2)
set(p, DECAL, "Hazard stripes")
composition.click_deck(p, 5, 2)
t.run_ticks(2)
assert(#t.decals_at(5, 2) == 4, "four markings stacked on one square")
local before = #t.ledger_rows("decal_placed")
local _ = t.messages(p)
set(p, DECAL, "Bot route")
composition.click_deck(p, 5, 2)
t.run_ticks(2)
assert(#t.decals_at(5, 2) == 4, "the fifth does not land")
assert(said(p, "There is no room left for another marking here."), "and the painter says so")
assert(#t.ledger_rows("decal_placed") == before, "a refusal writes no row")

-- ---- the eraser always erases ----
--
-- tg has no such tool: there a decal comes off only with the floor
-- under it (decal_painter.dm:3). Here it is the one thing that takes a
-- marking off a deck that still exists, newest first.
t.swap_hands(p)
assert(t.hands(p).held == "decal_eraser", "eraser in hand")
local _ = t.messages(p)
composition.click_deck(p, 3, 1)
t.run_ticks(2)
assert(#t.decals_at(3, 1) == 0, "the trim line is gone")
assert(said(p, "You scrub the marking off the deck."), "and the crewman was told")
local removed = t.ledger_rows("decal_removed")
assert(#removed == 1, "one act, one row: " .. #removed)
local scrubbed = ui_controls.array(removed[1].pos)
assert(scrubbed[1] == 3 and scrubbed[2] == 1, "pinned to the tile it cleaned")
assert(drawn(4, 1) == "decal_trim_box", "and its neighbour is alone again")

-- Nothing there is its own sentence, not silence.
local _ = t.messages(p)
composition.click_deck(p, 4, 3)
t.run_ticks(2)
assert(said(p, "There is no marking here to scrub off."), "a clean deck says so")
assert(#t.ledger_rows("decal_removed") == 1, "and writes no row")

-- ---- paint goes with the deck it was painted on ----
--
-- The whole lifetime rule, and tg's own (decal_painter.dm:3): a decal
-- is bound to the component instance under it, so prying the floor tile
-- up takes the marking with it -- and takes nothing else's.
t.swap_hands(p)
set(p, DECAL, "Tiling")
set(p, PAINT, "yellow")
composition.click_deck(p, 5, 3)
t.run_ticks(2)
assert(only(5, 3).paint == "yellow", "a yellow tiling square on the south-east corner")

t.swap_hands(p)
t.drop(p) -- the eraser, to free a hand for the crowbar
t.run_ticks(2)
t.click(p, 3, 2, t.target_at(p, 3, 2, "crowbar"))
t.run_ticks(2)
assert(t.hands(p).held == "crowbar", "crowbar in hand")

local standing = #t.decals_at(5, 2)
composition.click_deck(p, 5, 3)
t.run_ticks(4)
assert(composition.matches(5, 3, { "station_base" }), "the floor tile came up")
assert(#t.decals_at(5, 3) == 0, "and the paint on it went with it")
assert(#t.decals_at(5, 2) == standing, "while the next square keeps every one of its four")
local losses = t.ledger_rows("decal_removed")
assert(#losses == 2, "the loss is on the record too: " .. #losses)
local lost = ui_controls.array(losses[2].pos)
assert(lost[1] == 5 and lost[2] == 3, "naming the tile whose deck was taken")

-- ---- and a grating is not a deck ----
--
-- A lattice is a floor you see the subfloor through; paint has nothing
-- to sit on. The tool is still AIMED there, because a press that does
-- nothing and says nothing is the one thing it may not do: the painter
-- takes the click and spends it on a sentence.
t.swap_hands(p)
assert(t.hands(p).held == "decal_painter", "painter in hand again")
walk(p, "south")
walk(p, "east") -- onto the bared plating, beside the lattice
local offered = false
for _, action in ipairs(t.action_hints(p, composition.deck_target(6, 3))) do
    if action.id == "paint_decal" then
        offered = true
    end
end
assert(offered, "a lattice is still something the painter is aimed at")
local before_rows = #t.ledger_rows("decal_placed")
local _ = t.messages(p)
composition.click_deck(p, 6, 3)
t.run_ticks(2)
assert(#t.decals_at(6, 3) == 0, "and nothing lands on it")
assert(said(p, "This deck cannot hold a marking."), "but the crewman is told why")
assert(
    not said(p, "There is no room left for another marking here."),
    "an empty grating is not a full tile, and does not borrow its sentence"
)
assert(#t.ledger_rows("decal_placed") == before_rows, "a refusal writes no row")

-- The eraser answers the same deck the same way: nothing to scrub.
-- It was put down for the crowbar, so it is picked back up first.
t.swap_hands(p)
t.drop(p) -- the crowbar, to free the hand the eraser was put down for
t.run_ticks(2)
t.click(p, 4, 2, t.target_at(p, 4, 2, "decal_eraser"))
t.run_ticks(2)
assert(t.hands(p).held == "decal_eraser", "eraser in hand")
local erasures = #t.ledger_rows("decal_removed")
local _ = t.messages(p)
composition.click_deck(p, 6, 3)
t.run_ticks(2)
assert(said(p, "There is no marking here to scrub off."), "a grating says so too")
assert(#t.ledger_rows("decal_removed") == erasures, "and writes no row")
