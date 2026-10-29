-- Writing is driven through the same pointer, inventory, and script-window
-- seams as a browser. Native documents own revision, bounds, style, and use
-- charges; this spec only observes the resulting window and hands.
local ui_controls = require("@helpers/ui_controls")

t.world(
    [==[(
    name: "writing bench",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#...#",
                "#####",
            ],
            structures: [(2, 1, "player_spawn")],
            items: [
                (2, 1, "paper"), (3, 1, "four_color_pen"),
                (2, 2, "crayon_box"), (3, 2, "paper_bin"),
                (1, 2, "paper_bin.empty"),
            ],
        ),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

local function pick(id: string, x: number, y: number)
    local target = assert(
        t.target_at(p, x, y, id),
        id .. " is visible; tile=" .. table.concat(t.items_at(x, y), ",")
    )
    if string.sub(id, 1, 9) == "paper_bin" then
        t.use_item(p, target, "alt_primary")
    else
        t.click(p, x, y, target)
    end
    t.tick()
    assert(t.hands(p).held == id, id .. " is in the active hand; got " .. tostring(t.hands(p).held))
end

local function paper_data()
    local window = ui_controls.record(t.ui(p, "writing"))
    assert(window.document == "script", "paper uses a script document")
    local script = ui_controls.record(window.script)
    local data = ui_controls.record(script.data)
    local committed = {}
    for _, fragment in ipairs(ui_controls.rows(data.committed or {})) do
        assert(type(fragment.text) == "string", "a committed fragment has text")
        table.insert(
            committed,
            { text = fragment.text, style = ui_controls.record(fragment.style) }
        )
    end
    return { kind = data.kind, draft = data.draft, committed = committed, writer_style = ui_controls.record(data.writer_style or {}) }, script
end

local function paper_prefix()
    local address = assert(t.ui_document(p, "writing"), "the writing address is disclosed")
    return "doc/" .. address.document .. "/" .. address.generation .. "/paper"
end

-- A held sheet is readable without a writer. Its UI is bounded and an empty
-- writer cannot mutate the append-only file.
pick("paper", 2, 1)
local data, script = paper_data()
assert(data.kind == "paper" and data.draft == "", "paper opens with an empty draft")
local write_action = ui_controls.rows(script.actions)[1]
assert(
    write_action.id == "write" and write_action.input == 4096,
    "paper declares one bounded write action"
)
local prefix = paper_prefix()
assert(#(data.committed or {}) == 0, "an empty writer cannot append")

-- The pen is kept in the other hand and opened against the sheet through the
-- ordinary off-hand action. Each successful commit is a separate immutable
-- fragment, while cycling the pen changes only subsequent fragments.
local pen = t.target_at(p, 3, 1)
t.click(p, 3, 1, assert(pen))
t.tick()
if t.hands(p).held ~= "four_color_pen" then
    t.swap_hands(p)
    t.tick()
end
assert(t.hands(p).held == "four_color_pen", "the pen is held beside the sheet")
t.use_on_other(p)
t.tick()
prefix = paper_prefix()
data = paper_data()
assert(data.writer_style.font_family == "patrick-hand" and data.writer_style.color == "#000000", "the unwritten pen text uses the selected ink")
local first_text = string.rep("a", 4096)
local writer_window = ui_controls.record(t.ui(p, "writing"))
assert(
    writer_window.status == nil
        or (type(writer_window.status) == "number" and writer_window.status >= 2),
    "writer window unavailable: " .. tostring(writer_window.status)
)
t.ui_edit(p, prefix .. "/draft", first_text)
t.ui_press(p, prefix .. "/commit")
t.tick()

data = paper_data()
assert(
    #data.committed == 1 and #data.committed[1].text == 4096,
    "the first 4096-byte commit is visible on the sheet"
)
local first_style = data.committed[1].style
assert(first_style.font_family == "patrick-hand", "pen font is frozen on the fragment")
assert(data.writer_style.color == first_style.color, "writing retains its style after commit")

t.use_self(p)
t.tick()
t.use_on_other(p)
t.tick()
prefix = paper_prefix()
local second_text = string.rep("b", 4096)
data = paper_data()
assert(data.writer_style.color == "#FF0000", "cycling the pen updates the unwritten ink")
t.ui_edit(p, prefix .. "/draft", second_text)
t.ui_press(p, prefix .. "/commit")
t.tick()
data = paper_data()
assert(
    #data.committed == 2 and #data.committed[2].text == 4096,
    "a second 4096-byte commit reaches the body boundary"
)
assert(
    data.committed[1].style.color ~= data.committed[2].style.color,
    "cycling the pen changes only the next fragment color"
)
assert(data.committed[1].text == first_text, "committed text is immutable")

-- The box is stocked with seven physical sticks. Taking its first slot uses
-- native storage, so the observed hand contains the actual crayon prototype.
t.drop(p)
t.tick()
t.swap_hands(p)
t.move(p, "west")
t.tick()
t.drop(p)
t.tick()
t.move(p, "east")
t.tick()
pick("crayon_box", 2, 2)
t.take_held(p, 0)
t.tick()
t.swap_hands(p)
assert(t.hands(p).held == "crayon_red", "the box contains a red crayon stick")

-- A paper bin is stocked with thirty counted blank-sheet units. Materializing
-- through its self action places a real paper item in the player's hand.
assert(assert(t.item_at(3, 2, "paper_bin")).sprite == "paper_bin", "default bin looks stocked")
assert(assert(t.item_at(1, 2, "paper_bin.empty")).sprite == "paper_bin_empty", "empty variant looks empty")
t.drop(p)
t.tick()
t.swap_hands(p)
t.drop(p)
t.tick()
local bin = assert(t.target_at(p, 3, 2, "paper_bin"))
local draw_hint = false
local pickup_hint = false
for _, hint in ipairs(t.action_hints(p, bin)) do
    if hint.gesture == "primary" and hint.label.key == "lunatic/tfs:action.paper_bin.draw" then draw_hint = true end
    if hint.gesture == "alt_primary" and hint.label.key == "lunatic/tfs:action.pick_up" then pickup_hint = true end
end
assert(draw_hint and pickup_hint, "the bin advertises drawing and alternative pickup")
t.click(p, 3, 2, bin)
t.tick()
assert(t.hands(p).held == "paper", "a normal floor click takes a sheet")
assert(t.item_at(3, 2, "paper_bin") ~= nil, "drawing leaves the bin on the floor")
t.drop(p)
t.tick()
pick("paper_bin", 3, 2)
local function bin_picture(id: string, state: string, sprite: string)
    t.drop(p)
    t.tick()
    local item = assert(t.item_at(2, 1, id), "the bin is visible on the floor")
    assert(item.state == state and item.sprite == sprite, "bin picture follows committed stock")
    pick(id, 2, 1)
end
for index = 2, 30 do
    t.use_self(p)
    t.tick()
    t.swap_hands(p)
    assert(t.hands(p).held == "paper", "bin draw " .. index .. " yields paper")
    t.drop(p)
    t.tick()
    t.swap_hands(p)
end
local function papers_on_floor()
    local count = 0
    for _, id in ipairs(t.items_at(2, 1)) do
        if id == "paper" then
            count = count + 1
        end
    end
    return count
end
assert(papers_on_floor() == 30, "the bin materialized exactly thirty papers")
bin_picture("paper_bin", "empty", "paper_bin_empty")
t.use_self(p)
t.tick()
assert(papers_on_floor() == 30, "the bin has no thirty-first sheet")

-- Return one untouched sheet through the off-hand action seam. The bin's
-- resource rises only after native blank-item validation and the item is
-- removed atomically; drawing again proves that the unit was retained.
t.swap_hands(p)
t.tick()
local loose = assert(t.target_at(p, 2, 1), "a blank sheet is reachable")
t.click(p, 2, 1, loose)
t.tick()
assert(t.hands(p).held == "paper", "a blank sheet is held for return")
t.swap_hands(p)
t.use_on_other(p)
t.tick()
assert(papers_on_floor() == 29, "returning a blank sheet restores bin stock")
bin_picture("paper_bin", "full", "paper_bin")
t.use_self(p)
t.tick()
t.swap_hands(p)
assert(t.hands(p).held == "paper", "restored bin stock draws again")

-- The editor's empty variant starts with no stock and shares draw/return behavior.
t.drop(p)
t.tick()
t.swap_hands(p)
t.drop(p)
t.tick()
t.click(p, 1, 2, assert(t.target_at(p, 1, 2, "paper_bin.empty")))
t.tick()
assert(t.hands(p).held == nil, "an empty bin does not fall through to pickup")
assert(t.item_at(1, 2, "paper_bin.empty") ~= nil, "the empty bin stays on the floor")
pick("paper_bin.empty", 1, 2)
t.use_self(p)
t.tick()
assert(papers_on_floor() == 30, "empty variant cannot create a sheet")
assert(t.hands(p)[1] ~= "paper" and t.hands(p)[2] ~= "paper", "empty variant leaves the other hand empty")
t.swap_hands(p)
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, "paper")))
t.tick()
t.swap_hands(p)
t.use_on_other(p)
t.tick()
assert(papers_on_floor() == 29, "empty variant accepts a blank sheet")
bin_picture("paper_bin.empty", "full", "paper_bin")
t.use_self(p)
t.tick()
bin_picture("paper_bin.empty", "empty", "paper_bin_empty")
