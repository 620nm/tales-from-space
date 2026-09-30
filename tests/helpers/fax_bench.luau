-- The two-branch fax network of files/fax_test.luau and the player gestures
-- that advertise, load and send from it. Two access-point branches share one
-- router and hold the assistant's fax (4, 2) and the medic's fax (12, 2); a
-- third branch has its own root. Specs pass the floor items they need.
local ui_controls = require("@helpers/ui_controls")

local fax_bench = {}

fax_bench.SENDER_FAX = { x = 4, y = 2 }
fax_bench.RECEIVER_FAX = { x = 12, y = 2 }

local NETWORK = [==[ (
    name: "fax network",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    rows: [
        "#######################",
        "#Gao.......o.....o....#",
        "#.....................#",
        "#.....................#",
        "#######################",
    ],
    structures: [
        (3, 2, "player_spawn", { "jobs": "assistant" }),
        (13, 2, "player_spawn", { "jobs": "medic" }),
        (19, 2, "player_spawn", { "jobs": "engineer" }),
        (5, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
        (10, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
        (16, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
        (2, 1, "apc"),
    ],
    machines: [
        (4, 1, "network_router", { "network_1": "network_card" }),
        (15, 1, "network_router", { "network_1": "network_card" }),
        (4, 2, "fax", { "network_1": "network_card" }),
        (12, 2, "fax", { "network_1": "network_card" }),
        (18, 2, "fax", { "network_1": "network_card" }),
    ],
    links: [
        (4, 1, 5, 1), (4, 1, 10, 1),
        (5, 1, 4, 2), (10, 1, 12, 2),
        (15, 1, 16, 1), (16, 1, 18, 2),
    ],
    items: [ITEMS],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 9, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 10, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 11, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 12, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 13, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 14, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 15, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 16, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 17, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
) ]==]

-- Boot the network with `items` as the RON list body of the floor items,
-- e.g. `(3, 2, "paper"), (13, 2, "paper")`.
function fax_bench.world(items: string): ()
    local source = string.gsub(NETWORK, "ITEMS", function()
        return items
    end)
    t.world(source, 0)
end

function fax_bench.control(player: number, channel: string, suffix: string): string
    local address = assert(t.ui_document(player, channel), "document address is available")
    return "doc/" .. address.document .. "/" .. address.generation .. suffix
end

function fax_bench.data(player: number, channel: string): ui_controls.Record
    local panel = ui_controls.record(assert(t.ui(player, channel), "a document panel is open"))
    return ui_controls.record(panel.script and ui_controls.record(panel.script).data or panel.data)
end

function fax_bench.assert_no_script_errors(label: string): ()
    local errors = t.ledger_rows("script_error")
    local first = errors[1]
    assert(
        #errors == 0,
        label .. ": " .. tostring(first and (first.why or first.file) or "unknown script error")
    )
end

-- Name the fax at (x, y) through its panel and advertise it.
function fax_bench.advertise(player: number, x: number, y: number, name: string): ()
    local fax = assert(t.target_at(player, x, y, "fax"), "fax is present")
    t.click(player, x, y, fax)
    t.run_ticks(2)
    assert(t.ui(player, "fax"), "fax panel opened")
    t.ui_edit(player, fax_bench.control(player, "fax", "/controls/name"), name)
    t.ui_press(player, fax_bench.control(player, "fax", "/controls/name/set"))
    t.run_ticks(2)
    t.ui_press(player, fax_bench.control(player, "fax", "/controls/advertise"))
    t.run_ticks(3)
    local state = fax_bench.data(player, "fax")
    assert(state.advertised == true, "advertisement commits enabled state")
    t.ui_close(player, "fax")
end

-- Open the fax at (fax_x, fax_y), pick up the sheet lying at (sheet_x,
-- sheet_y) and dock it. The player's hands must be empty.
function fax_bench.load_sheet(
    player: number,
    fax_x: number,
    fax_y: number,
    sheet_x: number,
    sheet_y: number
): ()
    local fax = assert(t.target_at(player, fax_x, fax_y, "fax"), "fax is present")
    t.click(player, fax_x, fax_y, fax)
    t.run_ticks(2)
    assert(t.ui(player, "fax"), "the fax panel opens empty")
    local sheet = assert(t.target_at(player, sheet_x, sheet_y, "paper"), "a sheet is on the floor")
    t.click(player, sheet_x, sheet_y, sheet)
    t.run_ticks(1)
    assert(t.hands(player).held == "paper", "the sheet is picked up")
    t.click(player, fax_x, fax_y, fax)
    t.run_ticks(2)
    assert(t.hands(player).held == nil, "the fax takes the sheet")
end

-- Pick the directory row named `name` on the open panel. The directory lists
-- every advertising fax on the tree, the viewer's own included.
function fax_bench.select(player: number, name: string): ()
    local rows = ui_controls.rows(fax_bench.data(player, "fax").directory)
    for index, row in ipairs(rows) do
        if row.name == name then
            t.ui_press(
                player,
                fax_bench.control(player, "fax", "/directory/entry/" .. (index - 1) .. "/target")
            )
            t.run_ticks(1)
            return
        end
    end
    error("no directory row named " .. name)
end

-- Press the confirm control of the selection made with `select`.
function fax_bench.confirm(player: number): ()
    t.ui_press(player, fax_bench.control(player, "fax", "/confirm/send"))
end

-- Select `name` and confirm the send from the open panel.
function fax_bench.send(player: number, name: string): ()
    fax_bench.select(player, name)
    fax_bench.confirm(player)
end

-- Whether the player has heard `line` since joining.
function fax_bench.heard(player: number, line: string): boolean
    return table.concat(t.messages(player), " | "):find(line, 1, true) ~= nil
end

return fax_bench
