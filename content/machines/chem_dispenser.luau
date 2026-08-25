-- The chem dispenser: fourteen buttons and a slot for one beaker.
-- tg's `/obj/machinery/chem_dispenser` (chem_dispenser.dm).
--
-- No script, for the same reason the reaction chamber has none: a
-- vessel goes in, a button is pressed, matter arrives. That is
-- mechanism, and mechanism is the engine's (AGENTS.md's boundary
-- test). What is content is the whole of this file -- what it is
-- called, what it looks like, how big a press is, and above all THE
-- SHELF, which is a list of nouns and therefore ours.
--
-- THE SHELF is tg's own base list (`default_dispensable_reagents`,
-- chem_dispenser.dm:54-80), trimmed to what this pack has substances
-- for. Every one of the twelve recipes in `content/reactions/` is
-- reachable from these fourteen buttons plus the reaction chamber:
--
--   salt          sodium + chlorine
--   salt water    water + salt
--   ammonia       hydrogen + nitrogen
--   cleaner       ammonia + water
--   lube          water + silicon + oxygen
--   oil           welding fuel + carbon + hydrogen
--   ash           oil, at 480 K
--   lye           ash + water + carbon
--   saltpetre     potassium + nitrogen + oxygen
--   CO2           carbon + oxygen, at 777 K
--   N2O           ammonia + nitrogen + oxygen, at 525-575 K
--   thermite      aluminium + iron + oxygen
--
-- What tg lists and this shelf does not: bromine, copper, fluorine,
-- iodine, lithium, mercury, phosphorus, radium, stable plasma, sulfur
-- and sulphuric acid. Each is one line here on the day it becomes a
-- substance file -- the same deal the pipe dispenser's shelf offers.
--
-- OXYGEN AND NITROGEN ARE THE STATION'S OWN GASES. The keys `o2` and
-- `n2` are the pack's own gases, the same substances a canister holds
-- and a crewman breathes, dispensed as a liquid the way tg's reagent
-- oxygen is a reagent. One matter registry, reached from one more
-- place (docs/CHEMISTRY.md).
--
-- WHAT TG'S WINDOW HAS THAT THIS ONE CANNOT SAY: a power-cell gauge (a
-- corded appliance here draws flat off the mains, and tg's per-unit
-- cell economy is deferred), a pH bar and a reaction encyclopedia
-- (purity and pH are deferred by decision), and an adjustable amount
-- selector -- tg's `amount` is a dial over 5/10/15/20/25/30/50/100 u,
-- and one press of one size is enough machine for the bench this
-- station has.
return {
    id = "chem_dispenser",
    name = "chem dispenser",
    sprite = "chem_dispenser",
    ui = { modules = { "mint_dock" } },
    examine = {
        flavor = "A shelf of taps over a single dock. Every button on it "
            .. "is somewhere a shift's chemistry could start.",
    },
    dense = true,
    corded = true,
    chem = {
        device = "mint",
        mint_temperature_k = 300,
        mint_phase = "liquid",
        -- tg's `amount = 30` (chem_dispenser.dm:18) through the
        -- documented unit bridge of 1 u = 0.025 mol: 0.75 mol, which is
        -- three fifths of a beaker. The dial's OPENING position: the
        -- panel can turn it, and this is where it starts.
        dispense_mol = 0.75,
        -- The dial itself. One tg unit at the bottom and one tg unit a
        -- notch, because a whole unit is the smallest amount tg's own
        -- interface can ask for; a beaker's 50 u at the top, because
        -- the vessel is the honest ceiling on a single press and
        -- anything past it would be trimmed at the brim anyway.
        dispense_min = 0.025,
        dispense_max = 1.25,
        dispense_step = 0.025,
        dispenses = {
            { key = "hydrogen", name = "hydrogen" },
            { key = "carbon", name = "carbon" },
            { key = "chlorine", name = "chlorine" },
            { key = "sodium", name = "sodium" },
            { key = "potassium", name = "potassium" },
            { key = "silicon", name = "silicon" },
            { key = "aluminium", name = "aluminium" },
            { key = "iron", name = "iron" },
            { key = "o2", name = "oxygen" },
            { key = "n2", name = "nitrogen" },
            { key = "water", name = "water" },
            { key = "ethanol", name = "ethanol" },
            { key = "sugar", name = "sugar" },
            { key = "welding_fuel", name = "welding fuel" },
        },
    },
}
