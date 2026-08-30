-- ChemDrobe, tg's chemistry wardrobe
-- (`/obj/machinery/vending/wardrobe/chem_wardrobe`,
-- code/modules/vending/wardrobes.dm:600-629).
--
-- TfS ports the three distinct pieces its equipment model can tell the
-- truth about: a chemist uniform, the chemistry backpack, and the belt
-- reagent bag. The headset is the same physical radio tg stocks at
-- line 620; TfS has one radio network, so there is no false departmental
-- channel encoded in a second prototype.
--
-- The alternate skirt and four alternative bags are appearance variants
-- of those same roles. Hats, gloves and shoes have no equipment slots;
-- a lab coat cannot use TfS's pressure-sealing suit slot; and the pH
-- booklet has no pH interface to document. They remain absent rather
-- than becoming decorative or mechanically dishonest rows.
return {
    id = "chemdrobe",
    name = "ChemDrobe",
    sprite = "chemdrobe",
    ui = { modules = { "shelf" }, opens_on_click = false },
    dense = true,
    script = "vendor",
    corded = true,
    -- tg's product_ads string (wardrobes.dm:604).
    ad = "Our clothes are 0.5% more resistant to acid spills! Get yours now!",
    categories = { "Uniforms", "Storage", "Communications", "Chemistry" },
    vends = {
        {
            item = "uniform_chemist",
            name = "Chemist's Jumpsuit",
            category = "Uniforms",
            amount = 2,
        },
        {
            item = "chemistry_backpack",
            name = "Chemistry Backpack",
            category = "Storage",
            amount = 2,
        },
        {
            item = "chemistry_bag",
            name = "Chemistry Bag",
            category = "Storage",
            amount = 2,
        },
        { item = "headset", name = "Headset", category = "Communications", amount = 2 },
        { item = "syringe", name = "Syringe", category = "Chemistry", amount = 12 },
        { item = "dropper", name = "Dropper", category = "Chemistry", amount = 3 },
        { item = "beaker", name = "Beaker", category = "Chemistry", amount = 5 },
        { item = "bottle", name = "Bottle", category = "Chemistry", amount = 5 },
        { item = "test_tube", name = "Test Tube", category = "Chemistry", amount = 6 },
        { item = "beaker_large", name = "Large Beaker", category = "Chemistry", amount = 5 },
        { item = "beaker_plastic", name = "X-Large Beaker", category = "Chemistry", amount = 5 },
        { item = "beaker_metamaterial", name = "Metamaterial Beaker", category = "Chemistry", amount = 5 },
        { item = "beaker_cryostasis", name = "Cryostasis Beaker", category = "Chemistry", amount = 5 },
        { item = "beaker_bluespace", name = "Bluespace Beaker", category = "Chemistry", amount = 5 },
        { item = "water_bottle", name = "Bottle of Water", category = "Chemistry", amount = 5 },
        { item = "water_bottle.empty", name = "Empty Water Bottle", category = "Chemistry", amount = 5 },
        { item = "water_bottle_large", name = "Large Bottle of Water", category = "Chemistry", amount = 5 },
        { item = "water_bottle_large.empty", name = "Empty Large Water Bottle", category = "Chemistry", amount = 5 },
        { item = "spray_bottle", name = "Spray Bottle", category = "Chemistry", amount = 5 },
    },
}
