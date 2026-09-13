-- A crayon and the four-color pen can address the same sheet in sequence.
-- The committed projection is the player-visible proof of frozen style.
t.world([==[(
    name: "crayon switch",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#####", "#...#", "#...#", "#####"],
    structures: [(2, 1, "player_spawn")],
    items: [(2, 1, "paper"), (3, 1, "crayon_red"), (2, 2, "four_color_pen")],
)]==], 0)

local p = t.join()
t.tick()
local function pick(id)
    local x, y = 2, 2
    if id == "paper" then x, y = 2, 1 elseif id == "crayon_red" then x, y = 3, 1 end
    local target = assert(t.target_at(p, x, y), id .. " is visible")
    t.click(p, x, y, target)
    t.tick()
end
local function prefix()
    local address = assert(t.ui_document(p, "writing"), "writing window address")
    return "doc/" .. address.document .. "/" .. address.generation .. "/paper"
end
local function commit(text)
    local id = prefix()
    t.ui_edit(p, id .. "/draft", text)
    t.ui_press(p, id .. "/commit")
    t.tick()
    return assert(t.ui(p, "writing")).script.data
end

pick("paper")
pick("crayon_red")
if t.hands(p).held ~= "crayon_red" then t.swap_hands(p); t.tick() end
assert(t.hands(p).held == "crayon_red", "the crayon is the active implement")
t.use_on_other(p)
t.tick()
local data = commit("crayon mark")
assert(#data.committed == 1 and data.committed[1].text == "crayon mark",
    "the crayon append is committed")
assert(data.committed[1].style.font_family == "kalam-bold"
    and data.committed[1].style.weight == 700
    and data.committed[1].style.color == "#DA0000",
    "the crayon freezes its font, weight, and color")

-- Leave the crayon, bring the pen to the active hand, and use the same paper.
t.drop(p)
t.tick()
t.swap_hands(p)
pick("four_color_pen")
if t.hands(p).held ~= "four_color_pen" then t.swap_hands(p); t.tick() end
assert(t.hands(p).held == "four_color_pen", "the pen replaces the crayon")
t.use_on_other(p)
t.tick()
data = commit("pen mark")
assert(#data.committed == 2 and data.committed[1].text == "crayon mark"
    and data.committed[2].text == "pen mark", "switching tools preserves old text")
assert(data.committed[1].style.font_family == "kalam-bold"
    and data.committed[2].style.font_family == "patrick-hand"
    and data.committed[2].style.weight == 400,
    "switching tools freezes the new pen style")
