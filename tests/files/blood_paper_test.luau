local clock = require("@helpers/clock")
local ui_controls = require("@helpers/ui_controls")
local p: number

local function panel_data(channel: string): ui_controls.Record
    local panel = ui_controls.record(assert(t.ui(p, channel), channel .. " is open"))
    local script_panel = if panel.script then ui_controls.record(panel.script) else panel
    return ui_controls.record(script_panel.data)
end

local function committed(): { ui_controls.Record }
    return ui_controls.rows(panel_data("writing").committed or {})
end

local function fragment_text(fragment: ui_controls.Record): string
    return ui_controls.text(fragment.text)
end

local function contains(rows: { string }, wanted: string): boolean
    for _, row in ipairs(rows) do
        if row == wanted then
            return true
        end
    end
    return false
end

local function has_text(body: string, wanted: string): boolean
    return string.find(body, wanted, 1, true) ~= nil
end

local function assert_position(x: number, y: number, label: string): ()
    local actual_x, actual_y = t.pos(p)
    assert(
        actual_x == x and actual_y == y,
        label .. " (" .. tostring(actual_x) .. "," .. tostring(actual_y) .. ")"
    )
end

local function assert_seed_body(body: string, label: string): ()
    assert(
        has_text(body, "<h2>Blood Type Compatibility</h2>"),
        label .. " keeps the paper heading"
    )
    assert(
        has_text(body, ">L</td>")
            and has_text(body, ">U</td>")
            and has_text(body, "background-color: blue; color: white;\">L</td>")
            and has_text(body, "background-color: blue; color: white;\">U</td>"),
        label .. " keeps both historical row and column labels"
    )
    local compatibility_note = "Blood types not written above can only receive from the same blood type."
    local blood_note = "Certain species do not have blood."
    local compatibility_at = string.find(body, compatibility_note, 1, true)
    local blood_at = string.find(body, blood_note, 1, true)
    assert(compatibility_at ~= nil and blood_at ~= nil and compatibility_at < blood_at, label .. " keeps both trailing sentences in order")
end

local function assert_pair(rows: { ui_controls.Record }, body: string, note: string, label: string): ()
    assert(#rows == 2, label .. " keeps two ordered native text fragments")
    assert(fragment_text(rows[1]) == body, label .. " keeps the full seeded body")
    assert(fragment_text(rows[2]) == note, label .. " keeps the appended note")
end

local function control(player: number, channel: string, suffix: string): string
    local address = assert(t.ui_document(player, channel), channel .. " exposes a document address")
    return "doc/" .. address.document .. "/" .. address.generation .. suffix
end

t.world(
    [==[ (
    name: "blood paper desk",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: ["#######", "#Gao..#", "#.....#", "#.....#", "#######"],
            structures: [
                (4, 2, "player_spawn"),
                (0, 0, "apc"), (1, 0, "apc"), (2, 0, "apc"), (3, 0, "apc"), (4, 0, "apc"), (5, 0, "apc"), (6, 0, "apc"),
                (0, 1, "apc"), (1, 1, "apc"), (2, 1, "apc"), (5, 1, "apc"), (6, 1, "apc"),
                (0, 2, "apc"), (1, 2, "apc"), (2, 2, "apc"), (3, 2, "apc"), (4, 2, "apc"), (6, 2, "apc"),
                (0, 3, "apc"), (1, 3, "apc"), (2, 3, "apc"), (3, 3, "apc"), (4, 3, "apc"), (5, 3, "apc"), (6, 3, "apc"),
                (0, 4, "apc"), (1, 4, "apc"), (2, 4, "apc"), (3, 4, "apc"), (4, 4, "apc"), (5, 4, "apc"), (6, 4, "apc"),
                (5, 2, "locker"),
            ],
            machines: [(4, 1, "photocopier")],
            items: [
                (4, 2, "paper.blood_types"), (3, 2, "four_color_pen"), (2, 3, "paper_bin"),
            ],
            networks: [
                (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
            ],
        ),
    ],
)]==],
    0
)

p = t.join()
t.run_ticks(3)

-- Open one real bin slot before testing a nonblank sheet against it.
t.move(p, "west")
t.run_ticks(6)
t.move(p, "south")
t.run_ticks(6)
local bin = assert(t.target_at(p, 2, 3, "paper_bin"), "the stocked paper bin is reachable")
t.use_item(p, bin, "alt_primary")
t.run_ticks(1)
if t.hands(p).held ~= "paper_bin" then
    t.swap_hands(p)
    t.run_ticks(1)
end
assert(t.hands(p).held == "paper_bin", "the player holds the stocked paper bin")
t.use_self(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper", "a real player draw opens one bin slot")
t.drop(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper_bin", "the bin remains held after setting the blank aside")
t.move(p, "west")
t.run_ticks(6)
t.drop(p)
t.run_ticks(1)
t.move(p, "east")
t.run_ticks(6)
t.move(p, "north")
t.run_ticks(6)
t.move(p, "east")
t.run_ticks(6)

local seed_target = assert(t.target_at(p, 4, 2, "paper.blood_types"), "the native blood-type paper is stocked")
t.click(p, 4, 2, seed_target)
t.run_ticks(2)
assert(t.hands(p).held == "paper.blood_types", "the player picks up the seeded native paper")
local seed_fragments = committed()
assert(#seed_fragments == 1, "UID0 opens with one native seed fragment")
local source_body = fragment_text(seed_fragments[1])
assert_seed_body(source_body, "UID0")

-- A real held pen appends through the still-open native writing document.
local pen = assert(t.target_at(p, 3, 2, "four_color_pen"), "a real pen is on the desk")
t.click(p, 3, 2, pen)
t.run_ticks(1)
if t.hands(p).held ~= "four_color_pen" then
    t.swap_hands(p)
    t.run_ticks(1)
end
assert(t.hands(p).held == "four_color_pen", "the player holds the real writer")
t.use_on_other(p)
t.run_ticks(2)
local writer_address = assert(t.ui_document(p, "writing"), "the open writer has a native address")
local appended_note = "Filed for the night shift."
t.ui_edit(p, control(p, "writing", "/paper/draft"), appended_note)
t.ui_press(p, control(p, "writing", "/paper/commit"))
t.run_ticks(2)
local same_address = assert(t.ui_document(p, "writing"), "the same writing window remains open")
assert(
    same_address.document == writer_address.document and same_address.generation == writer_address.generation,
    "the commit refreshes the same open writing window"
)
assert_pair(committed(), source_body, appended_note, "same-window append")

-- The paper bin refuses the written seed while it remains in the other hand.
t.drop(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper.blood_types", "the seeded sheet stays active after dropping the pen")
t.ui_close(p, "writing")
t.drop(p)
t.run_ticks(1)
local reopened_seed_target = assert(t.target_at(p, 4, 2, "paper.blood_types"), "the seeded paper remains on the desk")
assert(t.same_target(seed_target, reopened_seed_target), "the original seeded sheet remains on the desk")
t.click(p, 4, 2, reopened_seed_target)
t.run_ticks(2)
assert(t.hands(p).held == "paper.blood_types", "the player reacquires the seeded sheet")
assert_pair(committed(), source_body, appended_note, "reopened original paper")
t.move(p, "west")
t.run_ticks(6)
t.move(p, "south")
t.run_ticks(6)
bin = assert(t.target_at(p, 2, 3, "paper_bin"), "the paper bin is reachable")
t.use_item(p, bin, "alt_primary")
t.run_ticks(1)
if t.hands(p).held ~= "paper_bin" then
    t.swap_hands(p)
    t.run_ticks(1)
end
assert(t.hands(p).held == "paper_bin", "the player holds the bin against the seeded sheet")
t.use_on_other(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper.blood_types", "the bin rejects the nonblank seeded paper")
assert_pair(committed(), source_body, appended_note, "paper-bin refusal")
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper_bin", "the refused paper remains beside the held bin")
t.drop(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper.blood_types", "the source paper is still held")
t.ui_close(p, "writing")

-- Load the original into the powered copier and preserve its text fragments.
t.move(p, "north")
t.run_ticks(6)
t.move(p, "east")
t.run_ticks(6)
assert_position(4, 2, "the player returns to the copier desk")
t.drop(p)
t.run_ticks(1)
local copier = assert(t.target_at(p, 4, 1, "photocopier"), "the powered copier is present")
t.click(p, 4, 1, copier)
t.run_ticks(2)
assert(t.ui(p, "copier"), "the powered copier opens before the medium is loaded")
local loose_source = assert(t.target_at(p, 4, 2, "paper.blood_types"), "the seeded source sheet is on the desk")
t.click(p, 4, 2, loose_source)
t.run_ticks(1)
assert(t.hands(p).held == "paper.blood_types", "the source sheet is picked up for copying")
t.click(p, 4, 1, copier)
t.run_ticks(2)
assert(t.hands(p).held == nil, "the copier docks the source sheet")
local copier_data = panel_data("copier")
local original_fragments = ui_controls.rows(copier_data.original)
assert_pair(original_fragments, source_body, appended_note, "copier source")
assert(copier_data.mode == "bw" and copier_data.busy ~= true, "the copier is idle in its default black-and-white mode")
t.ui_press(p, control(p, "copier", "/copy"))
t.run_ticks(clock.deadline_ticks(4.0))
copier_data = panel_data("copier")
assert(copier_data.busy ~= true, "the native copy job completes")
t.ui_close(p, "copier")
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "photocopier")))
t.run_ticks(2)
local output = assert(t.target_at(p, 4, 1, "paper"), "the completed copy lands on the copier")
t.click(p, 4, 1, output)
t.run_ticks(2)
assert_pair(committed(), source_body, appended_note, "black-and-white copy")
assert_position(4, 2, "reading the copy leaves the player at the desk")
t.ui_close(p, "writing")

-- Eject the actual variant from the copier before storing it.
assert(t.hands(p).held == "paper", "the printed copy is active before source eject")
assert(t.ui(p, "copier"), "the copier panel remains available for source eject")
t.ui_press(p, control(p, "copier", "/eject"))
t.run_ticks(2)
assert(t.hands(p).held == "paper", "ejecting the source leaves the copy active")
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper.blood_types", "the eject button returns the original variant")
assert_pair(committed(), source_body, appended_note, "copier-ejected variant")
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper", "the printed copy remains after eject")
t.drop(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper.blood_types", "the ejected original stays held while setting the copy aside")
t.ui_close(p, "writing")
assert_position(4, 2, "the player stays at the desk after ejecting the original")

-- Store the original variant in a base locker, close it, reopen it, pull it clear and read it.
local locker = assert(t.target_at(p, 5, 2, "locker"), "the empty base locker is available")
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == nil, "the variant stays in the other hand while opening the locker")
assert_position(4, 2, "the empty active hand faces the locker from the desk")
t.click(p, 5, 2, locker)
t.run_ticks(1)
assert(assert(t.structure_at(5, 2)).state == "open", "the locker opens for storage")
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper.blood_types", "the original variant is active for storage")
t.click(p, 5, 2, locker)
t.run_ticks(1)
assert(
    t.hands(p).held == nil and contains(t.items_at(5, 2), "paper.blood_types"),
    "the open locker accepts the original variant"
)
t.click(p, 5, 2, locker)
t.run_ticks(1)
assert(assert(t.structure_at(5, 2)).state == "closed" and #t.items_at(5, 2) == 0, "closing conceals the stored variant")
t.click(p, 5, 2, locker)
t.run_ticks(1)
assert(assert(t.structure_at(5, 2)).state == "open", "the locker reopens with its stored variant")
t.pull(p, 5, 2, locker)
t.run_ticks(1)
assert_position(4, 2, "the player begins the pull west of the locker")
t.move(p, "west")
t.run_ticks(6)
assert_position(3, 2, "the player steps west while pulling the locker")
t.stop_pull(p)
t.run_ticks(1)
assert(
    t.same_target(assert(t.target_at(p, 4, 2, "locker")), locker),
    "the player pulls the open locker clear of its stored variant"
)
assert(contains(t.items_at(5, 2), "paper.blood_types"), "the variant is exposed after the locker moves")
t.move(p, "east")
t.run_ticks(6)
assert_position(4, 2, "the player returns to the exposed paper")
local stored_variant = assert(t.target_at(p, 5, 2, "paper.blood_types"), "the exposed variant is reachable")
t.click(p, 5, 2, stored_variant)
t.run_ticks(2)
assert(t.hands(p).held == "paper.blood_types", "the original variant is picked up after storage")
assert_pair(committed(), source_body, appended_note, "native variant storage round trip")
t.ui_close(p, "writing")

-- Return a real blank and prove it is consumed before drawing fresh stock.
t.move(p, "west")
t.run_ticks(6)
assert_position(3, 2, "the player approaches the paper bin from the locker desk")
assert(t.hands(p).held == "paper.blood_types", "the stored variant remains held before the blank control")
t.drop(p)
t.run_ticks(1)
bin = assert(t.target_at(p, 3, 3, "paper_bin"), "the dropped bin is reachable after storage")
t.use_item(p, bin, "alt_primary")
t.run_ticks(1)
if t.hands(p).held ~= "paper_bin" then
    t.swap_hands(p)
    t.run_ticks(1)
end
assert(t.hands(p).held == "paper_bin", "the bin is ready for its blank-sheet control")
t.use_self(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper", "an ordinary blank sheet is drawn for return")
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper_bin", "the bin is held against the ordinary blank")
t.use_on_other(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == nil, "the accepted blank is consumed from the other hand")
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper_bin", "the bin remains held after accepting the blank")
t.use_self(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == "paper", "returned blank stock can be drawn again")
