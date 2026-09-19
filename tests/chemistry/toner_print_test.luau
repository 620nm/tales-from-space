local ui_controls = require("@helpers/ui_controls")

local function amount(handle, key: string): number
    return (assert(t.contents(handle))[key]) or 0
end

local function control(player: number, channel: string, suffix: string): string
    local address = assert(t.ui_document(player, channel), "document address is available")
    return "doc/" .. address.document .. "/" .. address.generation .. suffix
end

local function script_data(panel: ui_controls.Record): ui_controls.Record
    local script = panel.script
    return ui_controls.record(if script then ui_controls.record(script).data else panel.data)
end

-- One small powered lab takes the actual toner reaction through its player
-- seams, then carries the cartridge to a copier in the same room.
t.world(
    [==[(
    name: "toner print bench",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    rows: [
        "############",
        "#Gao.......#",
        "#..........#",
        "#..........#",
        "############",
    ],
    structures: [(8, 2, "player_spawn"), (2, 1, "apc")],
    machines: [(4, 1, "chem_packager"), (5, 1, "chem_heater"), (9, 1, "photocopier")],
    items: [
        (5, 2, "beaker", { "blend": "toner_batch" }),
        (8, 2, "paper"), (7, 2, "four_color_pen"),
    ],
    blends: {
        "toner_batch": (rows: [
            ("polymer_resin:solid", 0.1),
            ("carbon:solid", 0.025),
            ("wax:solid", 0.025),
        ], temperature_k: 293.15, amount: total),
    },
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 9, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 9, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    0
)

local p = t.join()
t.run_ticks(3)

local function walk(direction: "east" | "north" | "south" | "west", count: number)
    for _ = 1, count do
        t.move(p, direction)
        t.run_ticks(5)
    end
end

-- Make a readable source sheet so the copier's print job has player-authored
-- content to carry through the native document path.
local paper = assert(t.target_at(p, 8, 2, "paper"), "the source paper is available")
t.click(p, 8, 2, paper)
t.run_ticks(5)
t.ui_close(p, "writing")
local pen = assert(t.target_at(p, 7, 2, "four_color_pen"), "a writer is available")
t.click(p, 7, 2, pen)
t.run_ticks(2)
if t.hands(p).held ~= "four_color_pen" then
    t.swap_hands(p)
    t.run_ticks(1)
end
assert(t.hands(p).held == "four_color_pen", "the writer is held")
t.use_self(p)
t.run_ticks(1)
t.use_on_other(p)
t.run_ticks(2)
local draft = control(p, "writing", "/paper/draft")
t.ui_edit(p, draft, "toner print")
t.ui_press(p, control(p, "writing", "/paper/commit"))
t.run_ticks(2)
t.drop(p)
t.run_ticks(1)
t.swap_hands(p)
t.run_ticks(1)
t.ui_close(p, "writing")
assert(t.hands(p).held == "paper", "the written source sheet is active")
t.drop(p)
t.run_ticks(1)

-- The 0.15 mol blend fits the beaker and mixes at 330 K. The toner recipe's
-- base rate is 0.25, so a 120-second powered run is enough for this batch.
walk("west", 3)
local vessel = assert(t.target_at(p, 5, 2, "beaker"), "the toner beaker is available")
t.click(p, 5, 2, vessel)
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "the toner beaker is held")
local heater = assert(t.target_at(p, 5, 1, "chem_heater"), "the reaction chamber is visible")
t.click(p, 5, 1, heater)
t.run_ticks(2)
assert(t.hands(p).held == nil, "the beaker docks in the reaction chamber")
t.click(p, 5, 1, heater)
t.run_ticks(2)
ui_controls.set(p, "temperature", 330)
ui_controls.toggle(p, "power")
t.run_seconds(120)
ui_controls.toggle(p, "power")
local toner = amount(vessel, "toner")
assert(math.abs(toner - 0.025) < 1e-4, "the heated resin, carbon and wax make 0.025 mol toner: " .. toner)
assert(amount(vessel, "polymer_resin") < 1e-6, "the toner reaction spends the resin binder")
assert(amount(vessel, "carbon") < 1e-6, "the toner reaction spends the pigment")
assert(amount(vessel, "wax") < 1e-6, "the toner reaction spends the flow aid")

ui_controls.toggle(p, "eject")
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "the reacted beaker is returned")

-- Dock the reacted batch in the packager and make the existing 30-charge
-- cartridge item. The extraction consumes exactly one 0.025 mol batch.
local packager = assert(t.target_at(p, 4, 1, "chem_packager"), "the chem packager is visible")
t.click(p, 4, 1, packager)
t.run_ticks(2)
assert(t.hands(p).held == nil, "the reacted beaker docks in the packager")
t.click(p, 4, 1, packager)
t.run_ticks(2)
ui_controls.toggle(p, "action", "make_toner_cartridge")
t.run_ticks(2)
assert(t.count_items("toner_cartridge") == 1, "the toner reaction becomes one cartridge")
assert(amount(vessel, "toner") < 1e-6, "packaging consumes the 0.025 mol toner batch")

-- Prepare the copier with the written source and spend one initial toner
-- charge. This leaves room below capacity for the cartridge's real refill.
ui_controls.toggle(p, "eject")
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "the packager returns the empty beaker")
t.drop(p)
t.run_ticks(1)
walk("east", 4)
local copier = assert(t.target_at(p, 9, 1, "photocopier"), "the copier is visible")
t.click(p, 9, 1, copier)
t.run_ticks(3)
walk("west", 1)
paper = assert(t.target_at(p, 8, 2, "paper"), "the written source remains on the floor")
t.click(p, 8, 2, paper)
t.run_ticks(1)
assert(t.hands(p).held == "paper", "the written source is picked up")
walk("east", 1)
t.click(p, 9, 1, copier)
t.run_ticks(2)
assert(t.hands(p).held == nil, "the written source is loaded")
local copier_data = script_data(ui_controls.state(p, "copier"))
assert(#ui_controls.rows(copier_data.original) > 0, "the copier can read the written source")
assert(copier_data.toner == 30, "the copier starts with thirty toner charges")

local papers_before = t.count_items("paper")
t.ui_press(p, control(p, "copier", "/copy"))
t.run_ticks(2)
local started = script_data(ui_controls.state(p, "copier"))
assert(started.busy == true, "the copier starts the print job")
t.run_ticks(77)
assert(t.count_items("paper") == papers_before, "the page is not printed before the job completes")
t.run_ticks(1)
assert(t.count_items("paper") == papers_before + 1, "one printed page lands on the copier")
copier_data = script_data(ui_controls.state(p, "copier"))
assert(copier_data.paper == 29 and copier_data.toner == 29, "the initial page spends one paper and toner")

-- The output is a real paper document carrying the authored source text.
local output = assert(t.target_at(p, 9, 1, "paper"), "the first output is readable")
t.click(p, 9, 1, output)
t.run_ticks(2)
local output_data = script_data(ui_controls.record(assert(t.ui(p, "writing"), "the output opens for reading")))
local output_fragments = ui_controls.rows(output_data.committed)
assert(
    #output_fragments == 1 and output_fragments[1].text == "toner print",
    "the printed page preserves the authored text"
)
t.ui_close(p, "writing")
t.drop(p)
t.run_ticks(1)
t.click(p, 9, 1, copier)
t.run_ticks(3)

-- Now carry the newly made cartridge to the copier. The machine is at 29,
-- so accepting its 30-charge source proves the refill is an actual transfer.
walk("west", 4)
local cartridge = assert(t.target_at(p, 4, 1, "toner_cartridge"), "the cartridge is on the packager tray")
t.click(p, 4, 1, cartridge)
t.run_ticks(2)
assert(t.hands(p).held == "toner_cartridge", "the new cartridge is held")
walk("east", 4)
t.drop(p)
t.run_ticks(1)
t.click(p, 9, 1, copier)
t.run_ticks(3)
cartridge = assert(t.target_at(p, 9, 2, "toner_cartridge"), "the cartridge is ready beside the copier")
t.click(p, 9, 2, cartridge)
t.run_ticks(1)
t.click(p, 9, 1, copier)
t.run_ticks(2)
assert(t.hands(p).held == "toner_cartridge", "the cartridge remains a refill source")
t.drop(p)
t.run_ticks(1)
copier_data = script_data(ui_controls.state(p, "copier"))
assert(copier_data.toner == 30, "the produced cartridge refills the depleted copier")

-- The source stays docked between jobs; print again after the refill.
local pages_before_refilled_print = t.count_items("paper")
t.ui_press(p, control(p, "copier", "/copy"))
t.run_ticks(2)
local refilled_started = script_data(ui_controls.state(p, "copier"))
assert(refilled_started.busy == true, "the copier starts a post-refill print job")
t.run_ticks(77)
assert(
    t.count_items("paper") == pages_before_refilled_print,
    "the refilled page is not printed before the job completes"
)
t.run_ticks(1)
assert(
    t.count_items("paper") == pages_before_refilled_print + 1,
    "one post-refill page lands on the copier"
)
copier_data = script_data(ui_controls.state(p, "copier"))
assert(copier_data.paper == 28 and copier_data.toner == 29, "the post-refill page spends one paper and toner")
