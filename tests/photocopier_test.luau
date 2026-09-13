-- Player seam for a paper copy: the script document supplies controls while
-- the native document job owns admission, timing, stock, and output.
local function control(player, channel, suffix)
    local address = assert(t.ui_document(player, channel), "document address is available")
    return "doc/" .. address.document .. "/" .. address.generation .. suffix
end

t.world([==[(
    name: "copy room",
    legend: { '.': (turf: Floor), '#': (turf: Wall), 'G': (turf: Floor, fixture: Some(Generator)), 'a': (turf: Floor, fixture: Some(Apc)), 'o': (turf: Floor, fixture: Some(Outlet)) },
    rows: ["#######", "#Gao..#", "#.....#", "#.....#", "#######"],
    structures: [(4, 2, "player_spawn")],
    machines: [(4, 1, "photocopier")],
    items: [
        (4, 2, "paper"), (3, 2, "four_color_pen"),
        (4, 3, "paper_bin"), (3, 3, "toner_cartridge"),
    ],
    cables: [(1, 1, 2), (2, 1, 3), (3, 1, 1), (4, 1, 1)],
)]==], 0)

local p = t.join()
t.run_ticks(3)
local paper = assert(t.target_at(p, 4, 2, "paper"), "a sheet is available")
t.click(p, 4, 2, paper)
t.run_ticks(5)
-- A blank sheet is read-only until a real held writer is applied.
t.ui_close(p, "writing")
local pen = assert(t.target_at(p, 3, 2, "four_color_pen"), "a writer is available")
t.click(p, 3, 2, pen)
t.run_ticks(2)
if t.hands(p).held ~= "four_color_pen" then t.swap_hands(p); t.run_ticks(1) end
assert(t.hands(p).held == "four_color_pen", "the writer is held")
t.use_self(p)
t.run_ticks(1)
t.use_on_other(p)
t.run_ticks(2)
local draft = control(p, "writing", "/paper/draft")
t.ui_edit(p, draft, "copy this")
t.ui_press(p, control(p, "writing", "/paper/commit"))
t.run_ticks(2)
local written_panel = assert(t.ui(p, "writing"), "the source writer remains open after commit")
local written_data = written_panel.script and written_panel.script.data or written_panel.data
assert(#written_data.committed == 1 and written_data.committed[1].text == "copy this",
    "the copier source contains the committed text")
assert(written_data.committed[1].style.color == "#FF0000", "the source keeps the pen's selected color")
t.drop(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
t.ui_close(p, "writing")
assert(t.hands(p).held == "paper", "the written source sheet is active")

local copier = assert(t.target_at(p, 4, 1, "photocopier"), "the copier is present")
t.drop(p)
t.run_ticks(1)
-- Open the provider before loading the medium; the panel remains focused
-- while the player picks up the sheet and clicks the drive.
t.click(p, 4, 1, copier)
t.run_ticks(3)
assert(t.ui(p, "copier"), "the copier opens before loading")
local floor_paper = assert(t.target_at(p, 4, 2, "paper"), "the written sheet is on the floor")
t.click(p, 4, 2, floor_paper)
t.run_ticks(1)
assert(t.hands(p).held == "paper", "the source sheet is picked up before loading")
t.click(p, 4, 1, copier)
t.run_ticks(2)
assert(t.hands(p).held == nil, "the source sheet is docked")
local panel = assert(t.ui(p, "copier"), "the copier panel refreshes after loading")
local data = panel.script and panel.script.data or panel.data
assert(data.kind == "copier" and data.count == 1 and data.mode == "bw",
    "the copier exposes one BW copy as its default")
assert(data.paper == 30 and data.toner == 30, "the copier starts with counted supplies")
assert(#data.original > 0,
    "the copier previews the written source")
assert(data.busy ~= true, "the copier is idle before the copy")
assert(panel.status == nil or panel.status >= 2, "the copier provider is actionable")
local papers_before = t.count_items("paper")

-- Loading consumes the hand-held sheet; copying is a native 80-tick job.
local copy_control = control(p, "copier", "/copy")
t.ui_press(p, copy_control)
t.run_ticks(2)
local started = t.ui(p, "copier")
local started_data = started and (started.script and started.script.data or started.data)
assert(started_data and started_data.busy == true, "the copier enters its native job")
t.run_ticks(77)
assert(t.count_items("paper") == papers_before, "no output appears before the 80-tick page")
t.run_ticks(1)
assert(t.count_items("paper") == papers_before + 1,
    "one completed copy lands on the machine tile")
data = (t.ui(p, "copier").script and t.ui(p, "copier").script.data) or t.ui(p, "copier").data
assert(data.paper == 29 and data.toner == 29,
    "one paper and one toner are charged per completed copy batch")

-- A color batch preserves the source presentation and charges once per
-- output page. The source stays docked between batches.
local count_control = control(p, "copier", "/count")
t.ui_edit(p, count_control, "2")
t.ui_press(p, count_control, "change")
local mode_control = control(p, "copier", "/mode")
t.ui_edit(p, mode_control, "color")
t.ui_press(p, mode_control, "change")
t.run_ticks(1)
data = (t.ui(p, "copier").script and t.ui(p, "copier").script.data) or t.ui(p, "copier").data
assert(data.count == 2 and data.mode == "color", "the copier accepts a two-page color batch")
local batch_before = t.count_items("paper")
t.ui_press(p, control(p, "copier", "/copy"))
t.run_ticks(160)
assert(t.count_items("paper") == batch_before + 2, "a two-page batch completes one page per 80 ticks")
t.ui_close(p, "copier")
copier = assert(t.target_at(p, 4, 1, "photocopier"), "the copier remains reachable after a color batch")
t.click(p, 4, 1, copier)
t.run_ticks(2)
data = (t.ui(p, "copier").script and t.ui(p, "copier").script.data) or t.ui(p, "copier").data
assert(data.paper == 27 and data.toner == 27 and data.busy ~= true,
    "a two-page batch charges one paper and toner per output")
local color_output = assert(t.target_at(p, 4, 1, "paper"), "a color output is readable")
t.click(p, 4, 1, color_output)
t.run_ticks(2)
local color_window = assert(t.ui(p, "writing"), "the color output opens as paper")
local color_data = color_window.script and color_window.script.data or color_window.data
assert(color_data.committed[1].style.color == "#FF0000", "color output preserves the source style")
t.ui_close(p, "writing")
t.drop(p)
t.run_ticks(1)

-- Both refill containers use the same generic resource transfer seam.
local paper_bin = assert(t.target_at(p, 4, 3, "paper_bin"), "a paper bin is available")
t.click(p, 4, 3, paper_bin)
t.run_ticks(1)
assert(t.hands(p).held == "paper_bin", "the paper bin is held")
copier = assert(t.target_at(p, 4, 1, "photocopier"), "the copier remains reachable")
t.click(p, 4, 1, copier)
t.run_ticks(2)
t.drop(p)
t.run_ticks(1)
data = (t.ui(p, "copier").script and t.ui(p, "copier").script.data) or t.ui(p, "copier").data
assert(data.paper == 30, "a paper bin restores copier stock")

local toner = assert(t.target_at(p, 3, 3, "toner_cartridge"), "a toner cartridge is available")
t.click(p, 3, 3, toner)
t.run_ticks(1)
assert(t.hands(p).held == "toner_cartridge", "the toner cartridge is held")
copier = assert(t.target_at(p, 4, 1, "photocopier"), "the copier remains reachable for toner")
t.click(p, 4, 1, copier)
t.run_ticks(2)
t.drop(p)
t.run_ticks(1)
data = (t.ui(p, "copier").script and t.ui(p, "copier").script.data) or t.ui(p, "copier").data
assert(data.toner == 30, "a toner cartridge restores copier stock")
