local ui_controls = require("@helpers/ui_controls")

-- NanoMed Plus and ChemDrobe share the generic vending mechanism, but
-- their shelves are content contracts. This spec pins every row, proves
-- every declared product really mints, and keeps medical IDs and the two
-- machines' inventories outside hostile client payloads.
t.world(
    [==[(
    name: "medical vendors",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Apc)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#o..#",
        "#a.g#",
        "#...#",
        "#####",
    ],
    structures: [(1, 2, "player_spawn")],
    machines: [(2, 1, "nanomed_plus"), (2, 3, "chemdrobe")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    7
)

local p = t.join()
t.tick()

local NANOMED = {
    { item = "syringe", label = "Syringe", category = "Medical", stock = 12 },
    { item = "scalpel", label = "Scalpel", category = "Surgery", stock = 2 },
    { item = "hemostat", label = "Hemostat", category = "Surgery", stock = 2 },
    { item = "retractor", label = "Retractor", category = "Surgery", stock = 2 },
    { item = "cautery", label = "Cautery", category = "Surgery", stock = 2 },
    { item = "circular_saw", label = "Circular Saw", category = "Surgery", stock = 2 },
    { item = "surgical_drill", label = "Surgical Drill", category = "Surgery", stock = 2 },
    { item = "bone_gel", label = "Bone Gel", category = "Surgery", stock = 4 },
    { item = "suture", label = "Suture", category = "Surgery", stock = 2 },
    { item = "surgical_kit", label = "Surgical Kit", category = "Surgery", stock = 2 },
    { item = "dropper", label = "Dropper", category = "Chemistry", stock = 3 },
    { item = "beaker", label = "Beaker", category = "Chemistry", stock = 5 },
    { item = "bottle", label = "Bottle", category = "Chemistry", stock = 5 },
    { item = "test_tube", label = "Test Tube", category = "Chemistry", stock = 6 },
    { item = "burner", label = "Burner", category = "Chemistry", stock = 2 },
    {
        item = "machine_board.chem_heater",
        label = "Machine Board (Reaction Chamber)",
        category = "Parts",
        stock = 2,
    },
    {
        item = "machine_board.chem_dispenser",
        label = "Machine Board (Chem Dispenser)",
        category = "Parts",
        stock = 2,
    },
}

t.click(p, 2, 1, t.target_at(p, 2, 1))
t.tick()
local ui = ui_controls.record(t.ui(p))
assert(
    ui and ui.document == "modules" and ui.presentation == "shelf",
    "NanoMed opens the shared shelf document"
)
assert(
    ui_controls.record(ui.notice).text == "Go save some lives!",
    "NanoMed carries its own ad copy"
)
assert(#ui_controls.rows(ui.products) == #NANOMED, "NanoMed's complete shelf is asserted")

for i, want in ipairs(NANOMED) do
    local row = ui_controls.rows(ui.products)[i]
    local item = want.item
    assert(ui_controls.record(row.payload).product == item, "NanoMed row " .. i .. " is " .. item)
    assert(row.label == want.label, item .. " has its shelf name")
    assert(row.category == want.category, item .. " is under " .. want.category)
    assert(row.stock == want.stock, item .. " keeps its declared stock")
    assert(row.sprite ~= "missing", item .. " resolves to atlas art")
end

-- Every medical tool is a direct row. The kit remains useful as a belt,
-- but completeness does not rely on transitive contents hidden inside it.
local MEDICAL_TOOLS: { [string]: boolean } = {
    syringe = true,
    scalpel = true,
    hemostat = true,
    retractor = true,
    cautery = true,
    circular_saw = true,
    surgical_drill = true,
    bone_gel = true,
    suture = true,
    surgical_kit = true,
    dropper = true,
}
for item in pairs(MEDICAL_TOOLS) do
    local found = false
    for _, row in ipairs(ui_controls.rows(ui.products)) do
        found = found or ui_controls.record(row.payload).product == item
    end
    assert(found, item .. " is directly recoverable from NanoMed")
end

-- A row in a document is not enough: every one goes through the real
-- mint route, including glassware, stocked containers, and boards.
for _, want in ipairs(NANOMED) do
    local item = want.item
    local before = t.count_items(item)
    ui_controls.vend(p, item)
    t.tick()
    assert(t.count_items(item) == before + 1, item .. " dispensed")
    assert(t.ledger_has("ItemSpawned", item, "Player"), item .. " was attributed to the buyer")
end

-- The client names a product, but the server's shelf remains authority.
for _, item in ipairs({ "id_medical", "uniform_chemist", "cola" }) do
    local before = t.count_items(item)
    assert(not ui_controls.has_product(p, item), "excluded product has no rendered control")
    t.tick()
    assert(t.count_items(item) == before, "NanoMed refuses " .. item)
end

t.ui_close(p)
t.click(p, 2, 3, t.target_at(p, 2, 3))
t.tick()
ui = ui_controls.record(t.ui(p))

local CHEMDROBE = {
    { item = "uniform_chemist", label = "Chemist's Jumpsuit", category = "Uniforms", stock = 2 },
    { item = "chemistry_backpack", label = "Chemistry Backpack", category = "Storage", stock = 2 },
    { item = "chemistry_bag", label = "Chemistry Bag", category = "Storage", stock = 2 },
    { item = "headset", label = "Headset", category = "Communications", stock = 2 },
    { item = "syringe", label = "Syringe", category = "Chemistry", stock = 12 },
    { item = "dropper", label = "Dropper", category = "Chemistry", stock = 3 },
    { item = "beaker", label = "Beaker", category = "Chemistry", stock = 5 },
    { item = "bottle", label = "Bottle", category = "Chemistry", stock = 5 },
    { item = "test_tube", label = "Test Tube", category = "Chemistry", stock = 6 },
    { item = "beaker_large", label = "Large Beaker", category = "Chemistry", stock = 5 },
    { item = "beaker_plastic", label = "X-Large Beaker", category = "Chemistry", stock = 5 },
    {
        item = "beaker_metamaterial",
        label = "Metamaterial Beaker",
        category = "Chemistry",
        stock = 5,
    },
    { item = "beaker_cryostasis", label = "Cryostasis Beaker", category = "Chemistry", stock = 5 },
    { item = "beaker_bluespace", label = "Bluespace Beaker", category = "Chemistry", stock = 5 },
    { item = "water_bottle", label = "Bottle of Water", category = "Chemistry", stock = 5 },
    {
        item = "water_bottle.empty",
        label = "Empty Water Bottle",
        category = "Chemistry",
        stock = 5,
    },
    {
        item = "water_bottle_large",
        label = "Large Bottle of Water",
        category = "Chemistry",
        stock = 5,
    },
    {
        item = "water_bottle_large.empty",
        label = "Empty Large Water Bottle",
        category = "Chemistry",
        stock = 5,
    },
    { item = "spray_bottle", label = "Spray Bottle", category = "Chemistry", stock = 5 },
}
assert(
    ui
        and ui_controls.record(ui.notice).text
            == "Our clothes are 0.5% more resistant to acid spills! Get yours now!",
    "ChemDrobe opens with tg's ad"
)
assert(#ui_controls.rows(ui.products) == #CHEMDROBE, "ChemDrobe's implemented wardrobe is exact")
for i, want in ipairs(CHEMDROBE) do
    local row = ui_controls.rows(ui.products)[i]
    local item = want.item
    assert(
        ui_controls.record(row.payload).product == item and row.label == want.label,
        "ChemDrobe row " .. i .. " is " .. item
    )
    assert(
        row.category == want.category and row.stock == want.stock,
        item .. " keeps its category and tg stock count"
    )
    assert(row.sprite ~= "missing", item .. " resolves to atlas art")
    local before = t.count_items(item)
    ui_controls.vend(p, item)
    t.tick()
    assert(t.count_items(item) == before + 1, item .. " dispensed")
end

local pills = t.count_items("pill")
assert(not ui_controls.has_product(p, "pill"), "excluded product has no rendered control")
t.tick()
assert(t.count_items("pill") == pills, "ChemDrobe cannot be talked into excluded medicine stock")

-- The shipped station carries both machines in the Chemistry Lab and
-- their construction boards in the Workshop. The focused room above
-- proves their power behavior; these assertions pin live-map placement.
t.world_file("chillstation.ron", 7)
t.join()
t.run_ticks(20)
assert(assert(t.machine_at(23, 4)).id == "nanomed_plus", "NanoMed stands in the lab")
assert(assert(t.machine_at(24, 4)).id == "chemdrobe", "ChemDrobe stands in the lab")
assert(t.item_at(11, 7, "machine_board.nanomed_plus") ~= nil, "NanoMed has a spare board")
assert(t.item_at(12, 7, "machine_board.chemdrobe") ~= nil, "ChemDrobe has a spare board")
