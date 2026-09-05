-- Pipe meters bind to one exact piping layer, even where several runs
-- cross the same tile. These are tg's three placement doors together:
-- a loose meter defaults to layer 3, using it on a raw pipe programs it
-- to that pipe's layer, and an RPD programs its generated meter before
-- immediately wrenching it down.

local L2, L4 = 2, 8

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

local function said(p, line)
    for _, message in ipairs(t.messages(p)) do
        if message == line then
            return true
        end
    end
    return false
end

local function lying_at(x, y, id)
    for _, item in ipairs(t.items_at(x, y)) do
        if item == id then
            return true
        end
    end
    return false
end

local function work()
    t.run_seconds(2.5)
end

-- A loose meter begins on PIPING_LAYER_DEFAULT and refuses a crossing
-- that has only layers 2 and 4. Clicking the exact layer-2 pipe changes
-- that one fitting, after which ordinary wrench construction binds it
-- to layer 2 and ignores layer 4 disappearing.
t.world([==[(
    name: "meter layers by hand",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(2, 1, "wrench"), (2, 1, "pipe_meter")],
    pipes: [(2, 1, 2), (2, 1, 8)],
)]==], 7)

local p = t.join()
t.tick()
t.click(p, 2, 1, t.target_at(2, 1, "wrench"))
t.run_ticks(2)

local _ = t.messages(p)
t.click(p, 2, 1, t.target_at(2, 1, "pipe_meter"))
t.run_ticks(2)
assert(said(p, "There is no pipe under the floor here."), "default layer 3 needs a layer-3 pipe")
assert(t.structure_at(2, 1) == nil and lying_at(2, 1, "pipe_meter"), "a refusal spends nothing")

t.drop(p)
t.run_ticks(2)
t.click(p, 2, 1, t.target_at(2, 1, "pipe_meter"))
t.run_ticks(2)
local _ = t.messages(p)
t.click_subfloor(p, 2, 1, "pipe", L2)
t.run_ticks(2)
assert(
    said(p, "Meter layer set to 2. Drop it before fastening."),
    "the alpha-tested pipe supplies the exact layer"
)

-- Script hooks cannot move a held item, so Lunatic uses its ordinary
-- drop key here; tg's pipe interaction performs this drop itself.
t.move(p, "north")
t.run_ticks(5)
t.drop(p)
t.run_ticks(2)
t.move(p, "south")
t.run_ticks(5)
t.click(p, 2, 2, t.target_at(2, 2, "wrench"))
t.run_ticks(2)
t.click(p, 2, 1, t.target_at(2, 1, "pipe_meter"))
work()
assert(t.structure_at(2, 1).id == "meter", "the programmed meter fastens to layer 2")

t.click_subfloor(p, 2, 1, "pipe", L4)
t.run_seconds(1.5)
t.run_seconds(1.0)
assert(t.pipe(2, 1) == L2, "only layer 4 came up")
assert(t.structure_at(2, 1).id == "meter", "another layer disappearing does not drop it")

t.click_subfloor(p, 2, 1, "pipe", L2)
t.run_seconds(1.5)
t.run_seconds(1.0)
assert(t.structure_at(2, 1) == nil, "its attached layer disappearing drops it")
assert(lying_at(2, 1, "pipe_meter"), "the meter is loose on the deck")

-- Replacing the run does not magically fasten the loose meter again.
t.drop(p)
t.run_ticks(2)
t.click(p, 2, 1, t.target_at(2, 1, "pipe"))
t.run_ticks(2)
-- Pulled pipe items preserve the exact layer they came from; layer 2
-- was the last one pulled and is the topmost fitting selected above.
t.click(p, 2, 1)
t.run_seconds(1.5)
assert(t.pipe(2, 1) == L2, "the same layer was laid again")
assert(t.structure_at(2, 1) == nil and lying_at(2, 1, "pipe_meter"), "it remains unfastened")

-- The RPD's selected layer is applied to the generated pipe_meter item
-- before the ordinary construction refusal runs. A wrong layer refuses;
-- a right layer builds; and a crossing still binds the selected one.
t.world([==[(
    name: "meter layers by RPD",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: [
        "######",
        "#....#",
        "#....#",
        "######",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "rpd"), (2, 2, "wrench")],
    pipes: [(2, 1, 2), (3, 1, 2), (3, 1, 8)],
)]==], 7)

local r = t.join()
t.tick()
t.click(r, 2, 2, t.target_at(2, 2, "rpd"))
t.run_ticks(2)
t.use_self(r)
t.tick()

local RECIPE, LAYER = "dial1", "dial2"
local function pick(field, label)
    for _, toggle in ipairs(t.ui(r).toggles) do
        if toggle.field == field and toggle.option ~= nil and word(toggle.label) == label then
            return toggle.option
        end
    end
    error("no " .. field .. " button labelled " .. label)
end

local function set(field, label)
    local option = pick(field, label)
    t.ui_act(r, "toggle", '{"field":"' .. field .. '","option":"' .. option .. '"}')
    t.tick()
end

set(RECIPE, "Meter")
set(LAYER, "4")
local _ = t.messages(r)
t.click(r, 2, 1)
t.run_seconds(1.0)
assert(t.structure_at(2, 1) == nil, "RPD layer 4 refuses a layer-2-only tile")
assert(said(r, "There is no pipe under the floor here."), "the ordinary same-layer refusal answers")

set(LAYER, "2")
t.click(r, 2, 1)
t.run_seconds(1.0)
assert(t.structure_at(2, 1).id == "meter", "RPD layer 2 fastens to the layer-2 run")

set(LAYER, "4")
t.click(r, 3, 1)
t.run_seconds(1.0)
assert(t.structure_at(3, 1).id == "meter", "RPD chooses layer 4 at a multilayer crossing")

t.drop(r)
t.run_ticks(2)
t.click(r, 2, 2, t.target_at(2, 2, "wrench"))
t.run_ticks(2)
t.click_subfloor(r, 3, 1, "pipe", L2)
t.run_seconds(2.5)
assert(t.structure_at(3, 1).id == "meter", "the RPD meter did not bind the other crossing layer")
t.click_subfloor(r, 3, 1, "pipe", L4)
t.run_seconds(2.5)
assert(t.structure_at(3, 1) == nil, "it drops when the RPD-selected layer is removed")
