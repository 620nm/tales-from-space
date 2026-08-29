-- NanoMed Plus, tg's medbay equipment shelf
-- (`/obj/machinery/vending/medical`,
-- code/modules/vending/medical.dm:1-43).
--
-- The four products TfS and tg share keep tg's exact stock counts:
-- twelve syringes, three droppers, two sutures and four tubes of bone
-- gel (medical.dm:8-18). The remaining Surgery rows are the rest of
-- TfS's `surgical = true` roster. tg obtains those tools from surgical
-- storage rather than this machine, but a small station with no medical
-- fabricator needs one honest recovery shelf; this is the same fold the
-- YouTool makes for every implemented engineering tool.
--
-- Chemistry is here rather than in ChemDrobe: ChemDrobe is explicitly
-- a clothing vendor (vending/wardrobes.dm:600-621). These are the five
-- bench tools TfS implements, and this shelf makes the lab's finite
-- round-start glassware replaceable. The two boards are the same
-- departmental-techfab substitution used by the YouTool; their machine
-- files are content and the vendor mechanism remains generic.
--
-- tg's premium and contraband lists (medical.dm:26-38) are absent. TfS
-- has neither money nor a hacked-stock tier, so exposing either as an
-- ordinary free row would discard the lock rather than port it.
return {
    id = "nanomed_plus",
    name = "NanoMed Plus",
    sprite = "nanomed_plus",
    ui = { modules = { "shelf" }, opens_on_click = false },
    dense = true,
    script = "vendor",
    corded = true,
    -- First of tg's product_ads (medical.dm:7).
    ad = "Go save some lives!",
    categories = { "Medical", "Surgery", "Chemistry", "Parts" },
    vends = {
        { item = "syringe", name = "Syringe", category = "Medical", amount = 12 },

        { item = "scalpel", name = "Scalpel", category = "Surgery", amount = 2 },
        { item = "hemostat", name = "Hemostat", category = "Surgery", amount = 2 },
        { item = "retractor", name = "Retractor", category = "Surgery", amount = 2 },
        { item = "cautery", name = "Cautery", category = "Surgery", amount = 2 },
        { item = "circular_saw", name = "Circular Saw", category = "Surgery", amount = 2 },
        { item = "surgical_drill", name = "Surgical Drill", category = "Surgery", amount = 2 },
        { item = "bone_gel", name = "Bone Gel", category = "Surgery", amount = 4 },
        { item = "suture", name = "Suture", category = "Surgery", amount = 2 },
        { item = "surgical_kit", name = "Surgical Kit", category = "Surgery", amount = 2 },

        { item = "dropper", name = "Dropper", category = "Chemistry", amount = 3 },
        { item = "beaker", name = "Beaker", category = "Chemistry", amount = 5 },
        { item = "bottle", name = "Bottle", category = "Chemistry", amount = 5 },
        { item = "test_tube", name = "Test Tube", category = "Chemistry", amount = 6 },
        { item = "burner", name = "Burner", category = "Chemistry", amount = 2 },

        {
            item = "machine_board.chem_heater",
            name = "Machine Board (Reaction Chamber)",
            category = "Parts",
            amount = 2,
        },
        {
            item = "machine_board.chem_dispenser",
            name = "Machine Board (Chem Dispenser)",
            category = "Parts",
            amount = 2,
        },
    },
}
