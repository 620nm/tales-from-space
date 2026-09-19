local ui_controls = require("@helpers/ui_controls")

-- A department transceiver arrives keyed: the variant's own
-- `encryption_1` seats the key at spawn, and a placement that names
-- the socket itself wins over the variant
-- (docs/CONTENT-SCHEMA.md §1.1a: placement beats variant beats
-- prototype; docs/MAP-PROPERTIES.md, the property sheet -- a socket
-- row takes a tier word or the full item id of a part of that
-- socket's kind).

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local word = ui_controls.word

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function part_row(ui: unknown, label: string): ui_controls.Record?
    for _, r in ipairs(ui_controls.rows(ui_controls.record(ui).readouts)) do
        if r.section and word(r.section) == "parts.parts" and word(r.label) == label then
            return r
        end
    end
    return nil
end

-- The bench: two Lifeline-variant towers on live cord, one of them
-- with its key socket overridden by the placement.
t.world(
    [==[(
    name: "variant bench",
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
        "#..........#",
        "#Gao....o..#",
        "############",
    ],
    structures: [(5, 1, "player_spawn"), (2, 2, "apc")],
    machines: [
        (6, 1, "transceiver.medical"),
        (9, 1, "transceiver.medical", { "encryption_1": "encryption_key.engineering" }),
    ],
    networks: [
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
)]==],
    0
)

local p = t.join()
t.run_ticks(20)

-- ---------------------------------------------------------------
-- 1. THE VARIANT'S KEY IS SEATED AT BOOT. The panel's parts roster
--    names the Lifeline key by its own name -- the fitted item is
--    encryption_key.medical, not a plain rung -- and the status
--    sentence says the word (fixtures/transceiver.luau).
-- ---------------------------------------------------------------
local _ = t.messages(p)
t.click(p, 6, 1, t.target_at(p, 6, 1))
t.tick()
-- RELAYED, because the APC feeding this tower is a hub and every
-- device it powers is hardwired under it (docs/devices/joining.md).
assert(
    said(p, "The transceiver is on the air, carrying Lifeline, relayed through its network."),
    "the variant boots keyed, got: " .. table.concat(t.messages(p), " | ")
)
local panel = t.ui(p)
assert(panel ~= nil, "the tower wears a panel")
assert(part_row(panel, "encryption key (Lifeline)") ~= nil, "the parts roster names the seated key")
assert(part_row(panel, "network card") ~= nil, "beside the derived network socket's plain rung")
t.ui_close(p)
t.tick()

-- Walk around the dense tower, along the cord row, to stand beside
-- the overridden one at (8, 1).
local route: { "north" | "east" | "south" | "west" } = { "south", "east", "east", "east", "north" }
for _, dir in ipairs(route) do
    t.move(p, dir)
    t.run_ticks(6)
end
local px, py = t.pos(p)
assert(px == 8 and py == 1, "standing beside the second tower: " .. px .. "," .. py)

-- ---------------------------------------------------------------
-- 2. THE PLACEMENT BEATS THE VARIANT. Same variant id on the map,
--    but its row named engineering's key, so Wrench is what boots.
-- ---------------------------------------------------------------
local _ = t.messages(p)
t.click(p, 9, 1, t.target_at(p, 9, 1))
t.tick()
assert(
    said(p, "The transceiver is on the air, carrying Wrench, relayed through its network."),
    "the placement's socket row wins, got: " .. table.concat(t.messages(p), " | ")
)
panel = t.ui(p)
assert(part_row(panel, "encryption key (Wrench)") ~= nil, "the parts roster shows the override")
assert(
    part_row(panel, "encryption key (Lifeline)") == nil,
    "and no Lifeline key was seated beside it"
)
t.ui_close(p)
t.tick()

-- ---------------------------------------------------------------
-- 3. THE LIGHTS GO OUT, and the sentence says so: a dead cord is the
--    first thing status_line checks (lib/radio.luau), before any talk
--    of keys -- the same fact that natively drops the machine back to
--    its dark base picture (docs/CONTENT-SCHEMA.md par.1.3).
-- ---------------------------------------------------------------
t.outage()
t.run_ticks(60)
local _ = t.messages(p)
t.click(p, 9, 1, t.target_at(p, 9, 1))
t.tick()
assert(
    said(p, "The transceiver is dark. Check what is feeding it."),
    "a tower on a dead cord says so, got: " .. table.concat(t.messages(p), " | ")
)
