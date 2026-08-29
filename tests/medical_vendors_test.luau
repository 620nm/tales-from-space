-- NanoMed Plus and ChemDrobe share the generic vending mechanism, but
-- their shelves are content contracts. This spec pins every row, proves
-- every declared product really mints, and keeps medical IDs and the two
-- machines' inventories outside hostile client payloads.
t.world([==[(
    name: "medical vendors",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#o..#",
        "#a.g#",
        "#...#",
        "#####",
    ],
    spawns: [(1, 2)],
    machines: [(2, 1, "nanomed_plus"), (2, 3, "chemdrobe")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
        (1, 3, 3), (2, 3, 3), (3, 3, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

local NANOMED = {
    { "syringe", "Syringe", "Medical", 12 },
    { "scalpel", "Scalpel", "Surgery", 2 },
    { "hemostat", "Hemostat", "Surgery", 2 },
    { "retractor", "Retractor", "Surgery", 2 },
    { "cautery", "Cautery", "Surgery", 2 },
    { "circular_saw", "Circular Saw", "Surgery", 2 },
    { "surgical_drill", "Surgical Drill", "Surgery", 2 },
    { "bone_gel", "Bone Gel", "Surgery", 4 },
    { "suture", "Suture", "Surgery", 2 },
    { "surgical_kit", "Surgical Kit", "Surgery", 2 },
    { "dropper", "Dropper", "Chemistry", 3 },
    { "beaker", "Beaker", "Chemistry", 5 },
    { "bottle", "Bottle", "Chemistry", 5 },
    { "test_tube", "Test Tube", "Chemistry", 6 },
    { "burner", "Burner", "Chemistry", 2 },
    { "chem_heater_board", "Machine Board (Reaction Chamber)", "Parts", 2 },
    { "chem_dispenser_board", "Machine Board (Chem Dispenser)", "Parts", 2 },
}

t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
local ui = t.ui(p)
assert(ui and ui.document == "modules" and ui.presentation == "shelf",
    "NanoMed opens the shared shelf document")
assert(ui.notice == "Go save some lives!", "NanoMed carries its own ad copy")
assert(#ui.products == #NANOMED, "NanoMed's complete shelf is asserted")

for i, want in ipairs(NANOMED) do
    local row = ui.products[i]
    local item = want[1]
    assert(row.payload.product == item, "NanoMed row " .. i .. " is " .. item)
    assert(row.label == want[2], item .. " has its shelf name")
    assert(row.category == want[3], item .. " is under " .. want[3])
    assert(row.stock == want[4], item .. " keeps its declared stock")
    assert(row.sprite ~= "missing", item .. " resolves to atlas art")
end

-- Every medical tool is a direct row. The kit remains useful as a belt,
-- but completeness does not rely on transitive contents hidden inside it.
local MEDICAL_TOOLS = {
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
    for _, row in ipairs(ui.products) do
        found = found or row.payload.product == item
    end
    assert(found, item .. " is directly recoverable from NanoMed")
end

-- A row in a document is not enough: every one goes through the real
-- mint route, including glassware, stocked containers, and boards.
for _, want in ipairs(NANOMED) do
    local item = want[1]
    local before = t.count_items(item)
    t.ui_act(p, "vend", '{"product":"' .. item .. '"}')
    t.tick()
    assert(t.count_items(item) == before + 1, item .. " dispensed")
    assert(t.ledger_has("ItemSpawned", item, "Player"),
        item .. " was attributed to the buyer")
end

-- The client names a product, but the server's shelf remains authority.
for _, item in ipairs({ "id_medical", "uniform_chemist", "cola" }) do
    local before = t.count_items(item)
    t.ui_act(p, "vend", '{"product":"' .. item .. '"}')
    t.tick()
    assert(t.count_items(item) == before, "NanoMed refuses " .. item)
end

t.ui_close(p)
t.click(p, 2, 3, t.target_at(2, 3))
t.tick()
ui = t.ui(p)

local CHEMDROBE = {
    { "uniform_chemist", "Chemist's Jumpsuit", "Uniforms", 2 },
    { "chemistry_backpack", "Chemistry Backpack", "Storage", 2 },
    { "chemistry_bag", "Chemistry Bag", "Storage", 2 },
    { "headset", "Headset", "Communications", 2 },
}
assert(ui and ui.notice == "Our clothes are 0.5% more resistant to acid spills! Get yours now!",
    "ChemDrobe opens with tg's ad")
assert(#ui.products == #CHEMDROBE, "ChemDrobe's implemented wardrobe is exact")
for i, want in ipairs(CHEMDROBE) do
    local row = ui.products[i]
    local item = want[1]
    assert(row.payload.product == item and row.label == want[2],
        "ChemDrobe row " .. i .. " is " .. item)
    assert(row.category == want[3] and row.stock == want[4],
        item .. " keeps its category and tg stock count")
    assert(row.sprite ~= "missing", item .. " resolves to atlas art")
    local before = t.count_items(item)
    t.ui_act(p, "vend", '{"product":"' .. item .. '"}')
    t.tick()
    assert(t.count_items(item) == before + 1, item .. " dispensed")
end

local syringes = t.count_items("syringe")
t.ui_act(p, "vend", '{"product":"syringe"}')
t.tick()
assert(t.count_items("syringe") == syringes,
    "ChemDrobe cannot be talked into NanoMed stock")

-- The shipped station carries both machines in the Chemistry Lab and
-- their construction boards in the Workshop. The focused room above
-- proves their power behavior; these assertions pin live-map placement.
t.world_file("chillstation.ron", 7)
t.join()
t.run_ticks(20)
assert(t.target_at(23, 4) ~= nil, "NanoMed stands in the lab")
assert(t.target_at(24, 4) ~= nil, "ChemDrobe stands in the lab")
assert(t.item_at(11, 7, "nanomed_plus_board") ~= nil, "NanoMed has a spare board")
assert(t.item_at(12, 7, "chemdrobe_board") ~= nil, "ChemDrobe has a spare board")
