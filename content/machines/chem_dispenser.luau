-- The chem dispenser: sixteen buttons and a slot for one vessel.
-- tg's `/obj/machinery/chem_dispenser` (chem_dispenser.dm).
--
-- No script, for the same reason the reaction chamber has none: a
-- vessel goes in, a button is pressed, matter arrives. That is
-- mechanism, and mechanism is the engine's (AGENTS.md's boundary
-- test). What is content is the whole of this file -- what it is
-- called, what it looks like, how big a press is, and above all THE
-- SHELF, which is a list of nouns and therefore ours.
--
-- THE SHELF is tg's own (`default_dispensable_reagents`,
-- chem_dispenser.dm:54-79, and `default_upgrade_reagents` at :81-88),
-- trimmed to what this pack has substances for and to what a source
-- can honestly hand over. Every recipe in `content/reactions/` is
-- reachable from these buttons plus a bottle and the reaction chamber:
--
--   salt          sodium + chlorine, under a lid
--   cleaner       ammonia + water, under a lid
--   lube          water + silicon
--   oil           welding fuel + carbon
--   ash           oil, at 480 K
--   lye           ash + water + carbon
--   thermite      aluminium + iron oxide
--   ammonia       nitrogen + hydrogen, off canisters, in a bottle
--   CO2           carbon + an oxygen share, at 777 K, in a bottle
--   N2O           ammonia + an oxygen share, at 525-575 K, in a bottle
--
-- THE PERMANENT GASES ARE NOT ON IT. Oxygen, nitrogen, hydrogen and
-- fluorine rest as gas at every temperature this nozzle reaches, and a
-- gas pressed over an open vessel is refused because what landed would
-- leave through the same mouth on the next exchange (D19). Rather than
-- ship buttons that only work over a bottle, they come to chemistry
-- the way they come to everything else on this station: off a
-- canister, through a connector port. tg lists all four; this is the
-- departure, and it is the one D19 names.
--
-- CHLORINE AND AMMONIA STAY, and they are why that rule is about the
-- PHASE rather than about the button. Both are gases at the nozzle's
-- 300 K, so both are refused over an open beaker -- but both CONDENSE:
-- pressed into a sealed bottle they reach their own vapour pressure
-- (about 8 atm for chlorine, 8.6 for ammonia) and the rest of the
-- press stands there as liquid, which is a reactant a bench can
-- actually use. Ammonia is tg's own upgrade-tier button
-- (chem_dispenser.dm:83).
--
-- ASH AND SALTPETRE are tg's upgrade tier too (chem_dispenser.dm:84
-- and :87), promoted to the base shelf here because this pack has no
-- upgrade parts: a machine that ships with a locked half is a machine
-- shipping mis-configured. Saltpetre has no recipe left at all -- tg's
-- is four fifths permanent gas -- so the button is the only way to it.
--
-- SALT AND IRON OXIDE are on no tg shelf and are this pack's own
-- departure, taken for pacing (D1). Salt is the bench's first product
-- and everything downstream of it would otherwise wait on a bottle of
-- liquid chlorine; iron oxide is thermite's oxidiser, which replaced
-- tg's loose oxygen leg (reactions/thermite.luau) and has to come from
-- somewhere.
--
-- What tg lists and this shelf still does not: bromine, copper,
-- iodine, lithium, mercury, phosphorus, radium, stable plasma, sulfur,
-- sulphuric acid, acetone and diethylamine. Each is one line here on
-- the day it becomes a substance file -- the same deal the pipe
-- dispenser's shelf offers.
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
        -- The nozzle's temperature, and the whole of what this machine
        -- gets to say about what comes out of it: what PHASE a press
        -- lands in is the substance's own at this temperature, off the
        -- registry (docs/CONTENT-SCHEMA.md, `chem`). Carbon arrives as
        -- a powder, water as water, and a gas has to be pressed into
        -- something with a lid on it or the machine refuses.
        mint_temperature_k = 300,
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
            -- tg's base shelf (chem_dispenser.dm:54-79), minus the
            -- permanent gases.
            { key = "carbon", name = "carbon" },
            { key = "chlorine", name = "chlorine" },
            { key = "sodium", name = "sodium" },
            { key = "potassium", name = "potassium" },
            { key = "silicon", name = "silicon" },
            { key = "aluminium", name = "aluminium" },
            { key = "iron", name = "iron" },
            { key = "water", name = "water" },
            { key = "ethanol", name = "ethanol" },
            { key = "sugar", name = "sugar" },
            { key = "welding_fuel", name = "welding fuel" },
            -- tg's upgrade tier (chem_dispenser.dm:81-88), on the base
            -- shelf here because this pack has no upgrade parts.
            { key = "ammonia", name = "ammonia" },
            { key = "ash", name = "ash" },
            { key = "saltpetre", name = "saltpetre" },
            -- On no tg shelf: this pack's own two, for pacing (D1).
            { key = "salt", name = "salt" },
            { key = "iron_oxide", name = "iron oxide" },
        },
    },
}
