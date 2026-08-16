-- The rapid pipe dispenser: three questions, one window, and a fitting
-- that goes down and fastens in one motion.
--
-- What this spec is really about is that the RPD is a faster hand and
-- not a different rulebook. Everything it builds goes through the same
-- construction pipeline a fitting and a wrench do, so the interesting
-- assertions are the REFUSALS: the ones an engineer would meet with the
-- fitting in their hands, met identically by a device that conjures it.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

-- 0.4 s of tg's `atmos_build_speed` (RPD.dm:53), plus slack for the
-- tick the effect lands on.
local function work(p)
    t.run_ticks(12)
end

-- One step, plus the move cooldown (lunatic_core::MOVE_COOLDOWN_TICKS
-- is 4), so two calls in a row are two steps.
local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- Which dial is which row of buttons in the window: the panel names
-- them positionally on the wire (`dial0`..), and the caption on each
-- row is the dial's own label.
local MODE, RECIPE, LAYER, PAINT = "dial0", "dial1", "dial2", "dial3"

local function set(p, field, index)
    t.ui_act(p, "toggle", '{"field":"' .. field .. '","option":"' .. index .. '"}')
    t.tick()
end

-- What one dial's caption row currently reads, which is also what the
-- device is set to.
local function shows(p, field)
    for _, tog in ipairs(t.ui(p).toggles) do
        if tog.field == field and tog.option == nil then
            return tog.on_text
        end
    end
    return nil
end

-- Which button on a dial's row wears that word. Looked up rather than
-- counted on purpose: the fitting roster GROWS every time a new device
-- lands, and a spec that hardcoded "recipe 11 is the connector" would
-- break on somebody else's content file.
local function pick(p, field, label)
    for _, tog in ipairs(t.ui(p).toggles) do
        if tog.field == field and tog.option ~= nil and tog.label == label then
            return tog.option
        end
    end
    error("no " .. field .. " button labelled " .. label)
end

-- ---------------------------------------------------------------
-- A strip of open subfloor with a wall at each end. Everything an
-- atmospherics technician does happens on bare plating, because pipe
-- lives under the deck.
-- ---------------------------------------------------------------
t.world([==[(
    name: "rpd bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        'o': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#########",
        "#.......#",
        "#ooooooo#",
        "#########",
    ],
    spawns: [(1, 2)],
    items: [
        (1, 1, "wrench"),
        (1, 2, "rpd"),
        (2, 1, "manual_valve_fitting"),
        (2, 1, "manual_valve_fitting"),
    ],
)]==], 7)

local p = t.join()
t.tick()

t.click(p, 1, 2, t.target_at(1, 2, "rpd"))
t.run_ticks(2)
assert(t.hands(p).held == "rpd", "the RPD is in hand")

-- ---- the window ----
--
-- tg's `attack_self` opens the interface (RPD.dm:124-125). Ours is the
-- in-hand key, and the panel is the generic dial panel — which is the
-- point: the engine has never heard of a piping layer.
t.use_self(p)
t.tick()
local ui = t.ui(p)
assert(ui, "the in-hand key opens the RPD's window")
assert(ui.native == "settings" and ui.kind == "dials", "the generic dial panel")
assert(ui.name == "rapid pipe dispenser", "wearing the device's own name")

local captions = {}
local options = {}
local manual_presentation = nil
local green_swatch = nil
for _, tog in ipairs(ui.toggles) do
    if tog.option == nil then
        captions[tog.field] = tog.label
    else
        options[tog.field] = (options[tog.field] or 0) + 1
        if tog.field == RECIPE and tog.label == "Manual Valve" then
            manual_presentation = tog
        elseif tog.field == PAINT and tog.label == "green" then
            green_swatch = tog.color
        end
    end
end
assert(captions[MODE] == "Mode" and captions[RECIPE] == "Fitting", "every dial is labelled")
assert(captions[LAYER] == "Piping layer" and captions[PAINT] == "Paint", "all four of them")
assert(options[LAYER] == 5, "five piping layers, tg's PIPING_LAYER_MIN..MAX")
assert(options[PAINT] == 12, "and tg's twelve paints")
assert(options[RECIPE] >= 12, "the whole shelf, one button each: " .. options[RECIPE])
assert(
    manual_presentation.icon == "manual_valve_loose"
        and manual_presentation.group == "Binary Devices",
    "recipes carry content-authored atlas icons and tg-style groups"
)
assert(green_swatch == "#00FF00", "paint choices carry their real swatch colour")

-- Out of the crate it is set the way tg ships one: plain pipe, the
-- distribution layer, green (RPD.dm:51,61).
assert(shows(p, MODE) == "Build", "build mode")
assert(shows(p, RECIPE) == "Pipe", "plain pipe")
assert(shows(p, LAYER) == "3", "PIPING_LAYER_DEFAULT")
assert(shows(p, PAINT) == "green", "and tg's green")

-- Exact item and ground are different clicks. tg enables BUILD and
-- DESTROY together, with loose pipe breakdown first, so Build mode
-- consumes the fitting the client named instead of dispensing over it.
local _ = t.messages(p)
t.click(p, 2, 1, t.target_at(2, 1, "manual_valve_fitting"))
work(p)
assert(t.count_items("manual_valve_fitting") == 1, "build mode consumed exactly one named fitting")
assert(t.pipe(2, 1) == 0, "and does not reinterpret the item click as turf")
assert(
    said(p, "You break down the manual valve fitting."),
    "the tg-ordered breakdown branch ran before construction"
)

-- The precedence is typed, not permission to erase arbitrary clutter.
local _ = t.messages(p)
t.click(p, 1, 1, t.target_at(1, 1, "wrench"))
work(p)
assert(t.count_items("wrench") == 1, "build mode protects an ordinary item")
assert(t.pipe(1, 1) == 0, "an ordinary item click is not retargeted to turf")
assert(said(p, "That loose item is not atmospherics construction."), "the refusal names the type")

-- ---- pipe: the layer and the paint are real ----
--
-- Layer 3 is bit 4, layer 2 is bit 2, layer 4 is bit 8 (the piping
-- layers are a bitmask under the deck). Three runs crossing one tile
-- without joining is the whole reason layers exist.
walk(p, "north")
assert(t.pipe(2, 1) == 0, "nothing laid yet")
t.click(p, 2, 1)
work(p)
assert(t.pipe(2, 1) == 4, "one length on the distribution layer: " .. t.pipe(2, 1))

set(p, LAYER, pick(p, LAYER, "2"))
set(p, PAINT, pick(p, PAINT, "red"))
assert(shows(p, LAYER) == "2" and shows(p, PAINT) == "red", "the dials moved")
t.click(p, 2, 1)
work(p)
assert(t.pipe(2, 1) == 6, "a second run crosses the first: " .. t.pipe(2, 1))

set(p, LAYER, pick(p, LAYER, "4"))
set(p, PAINT, pick(p, PAINT, "blue"))
t.click(p, 2, 1)
work(p)
assert(t.pipe(2, 1) == 14, "and a third: " .. t.pipe(2, 1))

-- Each one came out the colour the dial was on, which is the record an
-- investigator reads (paint is topology here, not decoration).
local painted = t.ledger_rows("pipe_painted")
assert(#painted == 3, "three lengths, three paint rows: " .. #painted)
assert(painted[1].layers == 4 and painted[1].color == "#00FF00", "layer 3 green")
assert(painted[2].layers == 2 and painted[2].color == "#FF0000", "layer 2 red")
assert(painted[3].layers == 8 and painted[3].color == "#0000FF", "layer 4 blue")

-- And the dial turns are on the record too, by name.
assert(t.ledger_has("DialSet", "layer"), "which layer it was set to")
assert(t.ledger_has("DialSet", "paint"), "and which paint")

-- ---- a device: dispensed and connected in ONE action ----
--
-- tg's build mode with WRENCH_MODE set, which is its default: the
-- fitting is spawned and immediately wrenched (RPD.dm:552-572). No
-- second click, no wrench in the other hand.
walk(p, "east") -- (2, 1), so the next tile along is in reach
set(p, RECIPE, pick(p, RECIPE, "Manual Valve"))
assert(shows(p, RECIPE) == "Manual Valve", "the shelf is a list of buttons")
assert(t.structure_at(3, 1) == nil, "bare deck")
t.click(p, 3, 1)
work(p)
local valve = t.structure_at(3, 1)
assert(valve and valve.id == "manual_valve", "the valve stands, in one action")
assert(#t.items_at(3, 1) == 0, "and no fitting was left lying about")
assert(t.ledger_has("StructureStep", "manual_valve", "built"), "on the record as a build")

-- ---- and the rules it obeys are the framework's, word for word ----
--
-- A connector port needs nothing under it (Josh's ruling, 2026-08-16):
-- it bolts to bare deck, and whatever it ends up joined to is a
-- question the gas loop asks the live grid every pass. The RPD is a
-- faster hand and not a different rulebook, so a port goes down here
-- exactly as one does for a technician holding the fitting and a
-- wrench (tfs/tests/fittings_test.luau) — and there is no run within
-- reach of this bench at all.
walk(p, "east")
walk(p, "east") -- (4, 1)
set(p, RECIPE, pick(p, RECIPE, "Connector"))
local _ = t.messages(p)
t.click(p, 4, 1) -- the technician's own tile: a port goes UNDER the deck
work(p)
local socket = t.structure_at(4, 1)
assert(socket and socket.id == "connector_port", "a port stands on bare deck, in one action")
assert(socket.state == "anchored", "bolted down, the only state a port has")
assert(#t.items_at(4, 1) == 0, "and no fitting was left lying about")
assert(t.pipe(4, 1) == 0, "with no run under it or beside it")
assert(
    not said(p, "There is no pipe under the floor here."),
    "the old refusal is gone from the dispenser path too"
)
assert(t.ledger_has("StructureStep", "connector_port", "built"), "on the record as a build")

-- One fitting per turf is a refusal that stayed (tg's
-- PIPING_ONE_PER_TURF): a second port cannot claim this tile.
local _ = t.messages(p)
t.click(p, 4, 1)
work(p)
assert(
    said(p, "Something is already under the floor here."),
    "one socket per tile, whoever is dispensing it"
)

-- And the same rule one layer up for components.
set(p, RECIPE, pick(p, RECIPE, "Manual Valve"))
t.click(p, 5, 1)
work(p)
assert(t.structure_at(5, 1).id == "manual_valve", "a valve goes down on bare deck")
local _ = t.messages(p)
t.click(p, 5, 1)
work(p)
assert(
    said(p, "Something is already under the floor here."),
    "and a second component cannot claim the same pipe layer"
)

-- ---- destroy mode eats loose things, and only loose things ----
--
-- tg's DESTROY_MODE deletes the `/obj/item/pipe` it was aimed at
-- (RPD.dm:324-340). An anchored machine is unwrenched, never dissolved.
set(p, MODE, 1)
assert(shows(p, MODE) == "Destroy", "destroy mode")

local _ = t.messages(p)
t.click(p, 5, 1, t.target_at(5, 1, "manual_valve"))
work(p)
assert(t.structure_at(5, 1).id == "manual_valve", "a bolted-down valve is not loose")
assert(said(p, "There is nothing loose there to break down."), "and it says so")

-- The loose fitting the map put down, on the other hand, goes.
walk(p, "west")
walk(p, "west")
walk(p, "west") -- back to (1, 1), beside it
assert(t.count_items("manual_valve_fitting") == 1, "the loose fitting is still lying there")
local _ = t.messages(p)
t.click(p, 2, 1, t.target_at(2, 1, "manual_valve_fitting"))
work(p)
assert(t.count_items("manual_valve_fitting") == 0, "destroy mode ate it")
assert(t.hands(p).held == "rpd", "and did not pocket it instead")
assert(said(p, "You break down the manual valve fitting."), "saying which thing")
assert(t.ledger_has("ItemConsumed", "manual_valve_fitting"), "on the record")

-- tg's destroy branch is typed: it accepts loose atmos construction,
-- not every ordinary item which happens to be named by the click.
local _ = t.messages(p)
t.click(p, 1, 1, t.target_at(1, 1, "wrench"))
work(p)
assert(t.count_items("wrench") == 1, "destroy mode does not eat an ordinary tool")
assert(said(p, "There is nothing loose there to break down."), "the tool earns the narrow refusal")

-- ---- copy mode: point it at a run and it takes the settings ----
--
-- tg's right-click eyedropper (RPD.dm:481-491). Ours is a mode,
-- because there is no secondary-click channel.
set(p, LAYER, pick(p, LAYER, "5")) -- deliberately wrong
set(p, PAINT, pick(p, PAINT, "omni")) -- deliberately wrong
set(p, MODE, 2)
assert(shows(p, MODE) == "Copy", "copy mode")
local _ = t.messages(p)
t.click(p, 2, 1)
-- A second, because a copy turns the dials without anyone pressing a
-- button on the panel: the window catches up on its own refresh
-- cadence (tg's SStgui `UI_STATUS_EVERY`), which is what makes a live
-- panel live.
t.run_seconds(1.5)
-- The tile carries layers 2, 3 and 4; the lowest one laid answers, and
-- that is the red one from earlier.
assert(shows(p, LAYER) == "2", "it took the layer: " .. tostring(shows(p, LAYER)))
assert(shows(p, PAINT) == "red", "and the paint: " .. tostring(shows(p, PAINT)))
assert(said(p, "Layer 2, red."), "and told the technician what it read")

-- NEGATIVE: nothing to copy is a reason, not a silence.
local _ = t.messages(p)
t.click(p, 1, 1) -- the technician's own tile, bare deck
t.run_ticks(2)
assert(said(p, "There is no pipe under the floor here."), "an empty tile earns a reason")

-- NEGATIVE, build mode: pipe is subfloor infrastructure. A run you
-- have not opened the deck over is one you cannot fit, however fast
-- your dispenser is.
set(p, MODE, pick(p, MODE, "Build"))
set(p, RECIPE, pick(p, RECIPE, "Pipe"))
local _ = t.messages(p)
t.click(p, 1, 2) -- finished floor, one tile south
work(p)
assert(t.pipe(1, 2) == 0, "nothing was laid under a tiled floor")
assert(
    said(p, "The floor is in the way. Pry the tile up first."),
    "and the technician is told to pry it up"
)

-- ---- NEGATIVE: the client is hostile ----
--
-- The window a device is showing IS the whitelist. A position past the
-- end of a roster, and a dial the device does not have, both turn
-- nothing at all.
set(p, PAINT, 99)
assert(shows(p, PAINT) == "red", "no payload can dial past the end of the roster")
t.ui_act(p, "toggle", '{"field":"dial7","option":"0"}')
t.tick()
assert(shows(p, PAINT) == "red", "nor invent a fifth dial")
t.ui_act(p, "set", '{"field":"dial2","value":4}')
t.tick()
assert(shows(p, LAYER) == "2", "nor reach a dial through a verb the panel has no controls for")

-- ...and closing the window disarms it, as for any machine. A press
-- that landed would have pushed a fresh document reading "Destroy";
-- what the client still has is the one from before it closed.
t.ui_close(p)
local before = shows(p, MODE)
t.ui_act(p, "toggle", '{"field":"dial0","option":"1"}')
t.tick()
assert(shows(p, MODE) == before, "no window, no acts")

-- ---------------------------------------------------------------
-- OCCUPANCY. An atmos component replaces raw pipe on its own layer.
-- The RPD must refuse both directions, including the fitting-shaped
-- connector that bypasses ordinary on-deck occupancy. Different layers
-- remain valid crossings.
-- ---------------------------------------------------------------
t.world([==[(
    name: "rpd occupancy",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
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
    items: [(1, 2, "rpd"), (1, 1, "wrench")],
    pipes: [(1, 2, 4), (2, 2, 4), (3, 2, 4), (1, 3, 4), (3, 3, 4)],
    structures: [
        (1, 1, "manual_valve"),
        (2, 1, "connector_port"),
        (3, 1, "manual_valve_l2"),
    ],
)]==], 7)

local o = t.join()
t.tick()
t.click(o, 1, 2, t.target_at(1, 2, "rpd"))
t.run_ticks(2)
t.use_self(o)
t.tick()

-- Raw pipe cannot be laid under either component shape.
for _, x in ipairs({ 1, 2 }) do
    local _ = t.messages(o)
    t.click(o, x, 1)
    work(o)
    assert(t.pipe(x, 1) == 0, "no hidden pipe appeared at " .. x)
    assert(
        said(o, "An atmospherics component already occupies that pipe layer."),
        "the RPD names the occupied layer at " .. x
    )
end

-- A layer-3 length may cross a layer-2 valve.
t.click(o, 3, 1)
work(o)
assert(
    t.pipe(3, 1) == 4,
    "another-layer crossing remains legal: mask " .. tostring(t.pipe(3, 1))
)

-- Connector over valve, then valve over connector: neither fitting's
-- special under-deck placement nor ordinary occupancy may erase the
-- other component.
set(o, RECIPE, pick(o, RECIPE, "Connector"))
local _ = t.messages(o)
t.click(o, 1, 1)
work(o)
assert(t.structure_at(1, 1).id == "manual_valve", "the valve survived")
assert(said(o, "Something is already under the floor here."), "connector over valve refused")

set(o, RECIPE, pick(o, RECIPE, "Manual Valve"))
local _ = t.messages(o)
t.click(o, 2, 1)
work(o)
assert(t.structure_at(2, 1).id == "connector_port", "the connector survived")
assert(said(o, "Something is already under the floor here."), "valve over connector refused")

-- Nor may a component be placed over an existing same-layer raw run.
for _, case in ipairs({
    { x = 1, y = 3, recipe = "Manual Valve" },
    { x = 3, y = 3, recipe = "Connector" },
}) do
    set(o, RECIPE, pick(o, RECIPE, case.recipe))
    local _ = t.messages(o)
    t.click(o, case.x, case.y)
    work(o)
    assert(t.structure_at(case.x, case.y) == nil, case.recipe .. " did not cover raw pipe")
    assert(said(o, "Something is already under the floor here."), "raw pipe blocks " .. case.recipe)
end

-- ---------------------------------------------------------------
-- UNARY DEVICES. Connector, scrubber and injector each have one mouth
-- aimed at an adjacent run. Their own tile is the machine centre: it
-- neither needs nor permits a raw length on the same layer.
-- ---------------------------------------------------------------
t.world([==[(
    name: "rpd unary occupancy",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#########",
        "#.......#",
        "#.......#",
        "#.......#",
        "#########",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "rpd")],
    // The positive connector reaches west from (2,1). The southern
    // three entries are deliberately on each device's own layer.
    pipes: [(1, 1, 4), (2, 3, 4), (1, 3, 4), (4, 3, 2), (6, 3, 4)],
)]==], 7)

local u = t.join()
t.tick()
t.click(u, 2, 2, t.target_at(2, 2, "rpd"))
t.run_ticks(2)
t.use_self(u)
t.tick()

set(u, RECIPE, pick(u, RECIPE, "Connector"))
t.click(u, 2, 1)
work(u)
assert(t.structure_at(2, 1).id == "connector_port", "a connector builds beside its run")
assert(t.pipe(2, 1) == 0, "the connector has no raw centre length")

walk(u, "east")
walk(u, "east") -- (4,2)
set(u, RECIPE, pick(u, RECIPE, "Air Scrubber"))
t.click(u, 4, 1)
work(u)
assert(t.structure_at(4, 1).id == "air_scrubber", "a scrubber needs no underlying raw pipe")
assert(t.pipe(4, 1) == 0, "the scrubber is a unary component, not pipe-over-pipe")

walk(u, "east")
walk(u, "east") -- (6,2)
set(u, RECIPE, pick(u, RECIPE, "Air Injector"))
t.click(u, 6, 1)
work(u)
assert(t.structure_at(6, 1).id == "air_injector", "an injector needs no underlying raw pipe")
assert(t.pipe(6, 1) == 0, "the injector centre is raw-pipe-free")

-- The reverse direction is refused without consuming the run.
for _, case in ipairs({
    { x = 6, recipe = "Air Injector", layer = 4 },
    { x = 4, recipe = "Air Scrubber", layer = 2, west = 2 },
    { x = 2, recipe = "Connector", layer = 4, west = 2 },
}) do
    if case.west then
        for _ = 1, case.west do
            walk(u, "west")
        end
    end
    set(u, RECIPE, pick(u, RECIPE, case.recipe))
    local _ = t.messages(u)
    t.click(u, case.x, 3)
    work(u)
    assert(t.structure_at(case.x, 3) == nil, case.recipe .. " did not cover its centre run")
    assert(t.pipe(case.x, 3) == case.layer, case.recipe .. " left the raw run intact")
    assert(said(u, "Something is already under the floor here."), case.recipe .. " names occupancy")
end
