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
-- than becoming decorative or mechanically dishonest rows. The hidden
-- spray at lines 622-624 likewise waits for a contraband stock tier.
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
    categories = { "Uniforms", "Storage", "Communications" },
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
    },
}
