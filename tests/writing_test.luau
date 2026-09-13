-- Writing is driven through the same pointer, inventory, and script-window
-- seams as a browser. Native documents own revision, bounds, style, and use
-- charges; this spec only observes the resulting window and hands.
t.world([==[(
    name: "writing bench",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
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
    ],
)]==], 0)

local p = t.join()
t.tick()

local function pick(id, x, y)
    local target = assert(t.target_at(p, x, y), id .. " is visible; tile=" .. table.concat(t.items_at(x, y), ","))
    t.click(p, x, y, target)
    t.tick()
    assert(t.hands(p).held == id, id .. " is in the active hand; got " .. tostring(t.hands(p).held))
end

local function paper_data()
    local window = assert(t.ui(p, "writing"), "the paper window is open")
    assert(window.document == "script", "paper uses a script document")
    return assert(window.script).data, window
end

local function paper_prefix()
    local address = assert(t.ui_document(p, "writing"), "the writing address is disclosed")
    return "doc/" .. address.document .. "/" .. address.generation .. "/paper"
end

-- A held sheet is readable without a writer. Its UI is bounded and an empty
-- writer cannot mutate the append-only file.
pick("paper", 2, 1)
local data, window = paper_data()
assert(data.kind == "paper" and data.draft == "", "paper opens with an empty draft")
assert(window.script.actions[1].id == "write" and window.script.actions[1].input == 4096,
    "paper declares one bounded write action")
local prefix = paper_prefix()
assert(#(data.committed or {}) == 0, "an empty writer cannot append")

-- The pen is kept in the other hand and opened against the sheet through the
-- ordinary off-hand action. Each successful commit is a separate immutable
-- fragment, while cycling the pen changes only subsequent fragments.
local pen = t.target_at(p, 3, 1)
t.click(p, 3, 1, assert(pen))
t.tick()
if t.hands(p).held ~= "four_color_pen" then t.swap_hands(p); t.tick() end
assert(t.hands(p).held == "four_color_pen", "the pen is held beside the sheet")
t.use_on_other(p)
t.tick()
prefix = paper_prefix()
local first_text = string.rep("a", 4096)
local writer_window = assert(t.ui(p, "writing"))
assert(writer_window.status == nil or writer_window.status >= 2,
    "writer window unavailable: " .. tostring(writer_window.status))
t.ui_edit(p, prefix .. "/draft", first_text)
t.ui_press(p, prefix .. "/commit")
t.tick()

data = paper_data()
assert(#data.committed == 1 and #data.committed[1].text == 4096,
    "the first 4096-byte commit is visible on the sheet")
local first_style = data.committed[1].style
assert(first_style.font_family == "patrick-hand", "pen font is frozen on the fragment")

t.use_self(p)
t.tick()
t.use_on_other(p)
t.tick()
prefix = paper_prefix()
local second_text = string.rep("b", 4096)
t.ui_edit(p, prefix .. "/draft", second_text)
t.ui_press(p, prefix .. "/commit")
t.tick()
data = paper_data()
assert(#data.committed == 2 and #data.committed[2].text == 4096,
    "a second 4096-byte commit reaches the body boundary")
assert(data.committed[1].style.color ~= data.committed[2].style.color,
    "cycling the pen changes only the next fragment color")
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
t.drop(p)
t.tick()
t.swap_hands(p)
t.drop(p)
t.tick()
pick("paper_bin", 3, 2)
for index = 1, 30 do
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
        if id == "paper" then count = count + 1 end
    end
    return count
end
assert(papers_on_floor() == 30, "the bin materialized exactly thirty papers")
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
t.use_self(p)
t.tick()
t.swap_hands(p)
assert(t.hands(p).held == "paper", "restored bin stock draws again")
