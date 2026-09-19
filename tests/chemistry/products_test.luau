local ui_controls = require("@helpers/ui_controls")

-- The packager's bounded product buttons are the bridge from chemistry's
-- solid output to things a player can carry. The source blends below are
-- deliberately pre-made: reaction specs cover synthesis, this spec covers
-- the player-facing packaging and its refusal boundaries.
t.world(
    [==[(
    name: "product lab",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    rows: [
        "#############",
        "#Gao........#",
        "#...........#",
        "#...........#",
        "#############",
    ],
    structures: [(5, 1, "player_spawn"), (2, 1, "apc")],
    machines: [(4, 1, "chem_packager")],
    items: [
        (5, 2, "beaker", { "blend": "resin_batch" }),
        (6, 2, "beaker", { "blend": "contaminated_resin" }),
        (7, 2, "beaker", { "blend": "toner_batch" }),
        (8, 2, "beaker"),
        (9, 2, "beaker", { "blend": "insufficient_resin" }),
        (10, 2, "beaker", { "blend": "outage_resin" }),
    ],
    blends: {
        "resin_batch": (rows: [("polymer_resin:solid", 0.2)], temperature_k: 293.15, amount: total),
        "contaminated_resin": (rows: [("polymer_resin:solid", 0.2), ("carbon:solid", 0.1)], temperature_k: 293.15, amount: total),
        "toner_batch": (rows: [("toner:solid", 0.025)], temperature_k: 293.15, amount: total),
        "insufficient_resin": (rows: [("polymer_resin:solid", 0.05)], temperature_k: 293.15, amount: total),
        "outage_resin": (rows: [("polymer_resin:solid", 0.1)], temperature_k: 293.15, amount: total),
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

local function take(x: number, y: number, id: string)
    t.click(p, x, y, assert(t.target_at(p, x, y, id)))
    t.run_ticks(2)
end

local function dock()
    t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "chem_packager")))
    t.run_ticks(2)
    assert(t.hands(p).held == nil, "the product source docks")
    t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "chem_packager")))
    t.run_ticks(2)
end

local function action(key: string)
    ui_controls.toggle(p, "action", key)
    t.run_ticks(2)
end

local function walk(direction: "east" | "north" | "south" | "west", count: number)
    for _ = 1, count do
        t.move(p, direction)
        t.run_ticks(5)
    end
end

local function amount(handle: SpecObservedTarget, id: string): number
    return (assert(t.contents(handle))[id] or 0)
end

local resin_source = assert(t.target_at(p, 5, 2, "beaker"))
local source_before = assert(t.contents(resin_source)).polymer_resin
take(5, 2, "beaker")
dock()
action("make_resin_pellet")
assert(t.count_items("resin_pellet") == 1, "one measured resin pellet is printed")
assert((assert(t.contents(resin_source)).polymer_resin or 0) < source_before, "the pellet consumes resin")

-- The remaining tenth of a mole makes one sheet. A second press has no
-- free output because the source is empty.
action("mold_plastic_sheet")
assert(t.count_items("plastic_sheet") == 1, "one tenth of resin makes one plastic sheet")
local depleted_resin = amount(resin_source, "polymer_resin")
assert(depleted_resin < 1e-9, "the sheet consumes the remaining resin")
action("mold_plastic_sheet")
assert(t.count_items("plastic_sheet") == 1, "a depleted source prints no free plastic sheet")
assert(amount(resin_source, "polymer_resin") < 1e-9, "a repeat on an empty source stays empty")

-- A pellet is a measured solid vessel and can be poured into ordinary glass.
ui_controls.toggle(p, "eject")
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "the source is returned")
t.drop(p)
t.tick()
-- Both products share the tray. Take the top sheet first so the pellet is
-- reachable as a separate player target.
take(4, 1, "plastic_sheet")
assert(t.hands(p).held == "plastic_sheet", "the sheet can be removed from the tray")
assert(assert(t.examine_held(p)).title == "plastic sheets (1)", "the product contains one sheet")
t.drop(p)
t.tick()
local pellet = assert(t.target_at(p, 4, 1, "resin_pellet"))
take(4, 1, "resin_pellet")
assert(t.hands(p).held == "resin_pellet", "the measured pellet is held")
local pellet_before_pour = (assert(t.contents(pellet)).polymer_resin or 0)
walk("east", 3)
local pellet_receiver = assert(t.target_at(p, 8, 2, "beaker"))
take(8, 2, "beaker")
local receiver_after_pour = (assert(t.contents(pellet_receiver)).polymer_resin or 0)
assert(
    receiver_after_pour > 0.09,
    ("the pellet doses resin into the beaker (pellet=%g receiver=%g pours=%d)"):format(
        pellet_before_pour,
        receiver_after_pour,
        #t.ledger_rows("poured")
    )
)

-- A second solid contaminant refuses the resin operation without removing
-- anything or spawning a free product.
t.drop(p)
t.tick()
walk("west", 2)
walk("south", 1)
local contaminated_source = assert(t.target_at(p, 6, 2, "beaker"))
take(6, 2, "beaker")
walk("north", 1)
walk("west", 1)
dock()
local contaminated_before = assert(t.contents(contaminated_source)).polymer_resin
action("make_resin_pellet")
assert(t.count_items("resin_pellet") == 1, "contamination does not print another pellet")
assert(math.abs(amount(contaminated_source, "polymer_resin") - contaminated_before) < 1e-9, "contamination is not consumed")

-- A source below one product dose is refused without partial extraction.
ui_controls.toggle(p, "eject")
t.run_ticks(2)
t.drop(p)
t.tick()
walk("east", 4)
local insufficient_source = assert(t.target_at(p, 9, 2, "beaker"))
take(9, 2, "beaker")
walk("west", 4)
dock()
local insufficient_before = amount(insufficient_source, "polymer_resin")
action("make_resin_pellet")
assert(t.count_items("resin_pellet") == 1, "an insufficient source prints no pellet")
assert(amount(insufficient_source, "polymer_resin") == insufficient_before, "an insufficient source is not consumed")

-- The toner batch becomes the existing, printer-compatible cartridge.
ui_controls.toggle(p, "eject")
t.run_ticks(2)
t.drop(p)
t.tick()
walk("east", 2)
take(7, 2, "beaker")
walk("west", 2)
dock()
action("make_toner_cartridge")
assert(t.count_items("toner_cartridge") == 1, "toner becomes a printer cartridge")

ui_controls.toggle(p, "eject")
t.run_ticks(2)
t.drop(p)
t.tick()

-- Power loss refuses a valid batch and leaves it in the dock.
walk("east", 5)
local outage_source = assert(t.target_at(p, 10, 2, "beaker"))
take(10, 2, "beaker")
walk("west", 5)
dock()
local outage_before = amount(outage_source, "polymer_resin")
t.outage()
t.run_ticks(3)
action("mold_plastic_sheet")
assert(t.count_items("plastic_sheet") == 1, "an unpowered packager prints no sheet")
assert(amount(outage_source, "polymer_resin") == outage_before, "power loss does not consume the batch")
