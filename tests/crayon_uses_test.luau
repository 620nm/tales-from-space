local ui_controls = require("@helpers/ui_controls")

-- A crayon's thirty successful commits consume thirty uses. The thirty-first
-- refusal leaves the committed projection unchanged.
t.world([==[(
    name: "crayon uses",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#####", "#...#", "#...#", "#####"],
    structures: [(2, 1, "player_spawn")],
    items: [(2, 1, "paper"), (3, 1, "crayon_red")],
)]==], 0)

local p = t.join()
t.tick()
local function prefix()
    local address = assert(t.ui_document(p, "writing"), "writing window address")
    return "doc/" .. address.document .. "/" .. address.generation .. "/paper"
end
local function commit(text: string): {ui_controls.Record}?
    local id = prefix()
    t.ui_edit(p, id .. "/draft", text)
    t.ui_press(p, id .. "/commit")
    t.tick()
    local window = t.ui(p, "writing")
    if window == nil then return nil end
    local data = ui_controls.record(ui_controls.record(ui_controls.record(window).script).data)
    return ui_controls.rows(assert(data.committed))
end

local position = t.pos(p)
local crayon = assert(t.target_at(p, 2, 1), "the spent crayon remains at " .. tostring(position) .. "; tile=" .. table.concat(t.items_at(2, 1), ","))
t.click(p, 2, 1, crayon)
t.tick()
t.click(p, 3, 1, assert(t.target_at(p, 3, 1)))
t.tick()
if t.hands(p).held ~= "crayon_red" then t.swap_hands(p); t.tick() end
assert(t.hands(p).held == "crayon_red", "the red crayon is active")
t.use_on_other(p)
t.tick()

for index = 1, 30 do
    local committed = commit("mark " .. index)
    if committed == nil then
        assert(index == 30, "the crayon ran out before thirty successful commits")
        break
    end
    assert(#committed == index, "commit " .. index .. " is retained")
    assert(ui_controls.record(committed[index].style).font_family == "kalam-bold"
        and ui_controls.record(committed[index].style).weight == 700
        and ui_controls.record(committed[index].style).color == "#DA0000",
        "commit " .. index .. " keeps crayon style")
    if index < 30 then
        t.use_on_other(p)
        t.tick()
    end
end

-- A depleted writer closes its bound window when the inventory snapshot
-- reaches zero. Try the empty writer while it is still paired with the
-- sheet, then reopen the sheet read-only and prove no thirty-first fragment.
t.use_on_other(p)
t.tick()
t.drop(p)
t.tick()
t.swap_hands(p)
t.tick()
t.move(p, "east")
t.tick()
t.drop(p)
t.tick()
t.move(p, "west")
t.tick()
local sheet = assert(t.target_at(p, 3, 1), "the written sheet remains")
t.click(p, 3, 1, sheet)
t.tick()
assert(t.hands(p).held == "paper", "the sheet can be reopened after depletion")
local after = ui_controls.record(ui_controls.record(ui_controls.record(assert(t.ui(p, "writing"))).script).data)
assert(#ui_controls.rows(assert(after.committed)) == 30, "an empty crayon does not append another fragment")
