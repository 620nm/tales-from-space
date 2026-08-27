-- The chem dispenser: twenty-three buttons and a slot for one vessel.
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
--   acetone       oil + welding fuel
--   ammonia       nitrogen + hydrogen, off canisters, in a bottle
--   CO2           carbon + an oxygen share, at 777 K, in a bottle
--   N2O           ammonia + an oxygen share, at 525-575 K, in a bottle
--   diethylamine  ammonia + ethanol, under a lid
--   phenol        water + chlorine + oil, under a lid
--
-- ...and the medicine trunk that stands on top of them:
--
--   salglu        water + salt + sugar
--   multiver      ash + salt, at 400 K
--   libital       phenol + saltpetre, at 700 K
--   aiuri         ammonia + sulphuric acid, under a lid, kept warm
--   epinephrine   phenol + acetone + diethylamine + chlorine
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
-- and :87), promoted to the base shelf here. tg gates that half of the
-- shelf behind a servo above tier three (chem_dispenser.dm:467-471),
-- and this machine now HAS a servo socket -- but a shelf is a ROSTER,
-- and `parts.scale` moves numbers rather than rosters, so a per-tier
-- shelf is not something this machine can say. It is not a thing worth
-- inventing a mechanism for either: a machine that ships with a locked
-- half is a machine shipping mis-configured, and this one ships whole.
-- Saltpetre has no recipe left at all -- tg's is four fifths permanent
-- gas -- so the button is the only way to it.
--
-- SALT AND IRON OXIDE are on no tg shelf and are this pack's own
-- departure, taken for pacing (D1). Salt is the bench's first product
-- and everything downstream of it would otherwise wait on a bottle of
-- liquid chlorine; iron oxide is thermite's oxidiser, which replaced
-- tg's loose oxygen leg (reactions/thermite.luau) and has to come from
-- somewhere.
--
-- MOST OF THE REST OF TG'S BASE SHELF is here now: bromine, copper,
-- lithium, mercury, phosphorus, sulfur and sulphuric acid, each one
-- line, the same deal the pipe dispenser's shelf offers. Only the acid
-- is a leg of anything yet (aiuri); the other six are on the shelf
-- because the shelf is tg's and a button that waits for its recipe
-- costs nothing.
--
-- WHAT TG LISTS AND THIS SHELF STILL DOES NOT: iodine and radium have
-- substance files and no buttons, because a tap that pours a
-- radioactive metal into an open beaker is not a thing a chemistry
-- bench should offer and nothing here names iodine -- both come in a
-- bottle. Stable plasma is tg's twin of the atmos gas and there is one
-- id per molecule here (D3), so it does not exist. Acetone,
-- diethylamine and oil are on tg's UPGRADE tier and stay off this
-- shelf on purpose, unlike ammonia, ash and saltpetre above: all three
-- have recipes, and a bench where the first medicine is two presses
-- and a stir is a bench with nothing to learn in it.
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
    ui = { modules = { "mint_dock", "parts" } },
    examine = {
        flavor = "A shelf of taps over a single dock. Every button on it "
            .. "is somewhere a shift's chemistry could start.",
    },
    dense = true,
    corded = true,
    -- AND BACK APART. tg gives every machine the same two rungs
    -- generically: a screwdriver opens the maintenance panel
    -- (`default_deconstruction_screwdriver`, _machinery.dm:1049) and a
    -- crowbar takes it apart behind the open panel
    -- (`default_deconstruction_crowbar`, :912). Both are instant there,
    -- so neither names a `secs` here.
    --
    -- What is left standing is the assembly it was screwed together
    -- from, in the state that holds a board and its parts -- so the
    -- board and everything in the sockets come back out of the frame's
    -- own crowbar, at the tiers that are actually fitted
    -- (docs/CONSTRUCTION.md, "machine teardown").
    teardown = {
        open = "screwdriver",
        remove = "crowbar",
        into = "machine_frame",
        state = "boarded",
    },
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
            -- The rest of tg's base shelf, the day this pack got
            -- substance files for them (chem_dispenser.dm:54-79). None
            -- of them is a leg of anything here yet except the acid,
            -- which is half of aiuri; the other six are the buttons a
            -- recipe will find already fitted.
            { key = "bromine", name = "bromine" },
            { key = "copper", name = "copper" },
            { key = "lithium", name = "lithium" },
            { key = "mercury", name = "mercury" },
            { key = "phosphorus", name = "phosphorus" },
            { key = "sulfur", name = "sulfur" },
            { key = "sulfuric_acid", name = "sulphuric acid" },
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
    -- WHAT THIS MACHINE IS MADE OF, off tg's board verbatim: two matter
    -- bins, a capacitor and a servo (machine_circuitboards.dm:756-760).
    -- The cell tg also asks for has no twin here and the board's file
    -- says why (items/chem_dispenser_board.luau).
    --
    -- WHAT TG SCALES AND THIS MACHINE CANNOT. tg's `RefreshParts`
    -- (chem_dispenser.dm:455-474) moves three things, and two of them
    -- are about a power economy this pack does not have: the capacitor
    -- multiplies `recharge_amount` and the bins take a quarter of a
    -- kilowatt off `power_cost` each, both of which are the cell's
    -- numbers. The third is the servo's shelf gate, which is a roster
    -- rather than a knob (see ASH AND SALTPETRE above).
    --
    -- SO THE SOCKETS ARE MAPPED ONTO WHAT EXISTS: the dial. Bins are
    -- capacity in tg wherever they are read, so here they are the
    -- ceiling on a single press -- a machine with better bins can fill
    -- a bigger vessel in one go. The servo is precision, so here it is
    -- the NOTCH -- a better servo divides the step and lets a chemist
    -- ask for a third of a unit. That is this pack's own reading of
    -- tg's parts rather than tg's own arithmetic, and it is the
    -- departure: the capacitor is a build requirement with nothing to
    -- move until a cell exists, which is why it has no `scale` row.
    parts = {
        slots = { "bin", "bin", "capacitor", "servo" },
        scale = {
            -- Never under the beaker brim the file ships with (bins only
            -- ever improve it), never past four beakers in one press.
            mint_max = { by = "bin", law = "multiply", clamp = { 1.25, 5.0 } },
            -- tg's smallest press is one unit (0.025 mol) at the top of
            -- the clamp; a fifth of one at the bottom, so no ladder can
            -- turn the dial into a slider.
            mint_step = { by = "servo", law = "divide", clamp = { 0.005, 0.025 } },
        },
    },
    variants = {
        -- tg's `/fullupgrade` board, which stocks its frame with tier
        -- fours (machine_circuitboards.dm:765-773). tg asks for two of
        -- each; this machine has the socket count its plain board has,
        -- so the variant fills the sockets it HAS rather than growing
        -- new ones. No lathe prints the board here, so an upgraded
        -- dispenser is a thing a map places.
        fullupgrade = {
            name = "chem dispenser (upgraded)",
            props = {
                bin_1 = "4",
                bin_2 = "4",
                capacitor_1 = "4",
                servo_1 = "4",
            },
        },
    },
}
