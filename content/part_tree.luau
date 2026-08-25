-- Tales from Space's equipment surface.  The engine indexes this roster
-- without learning any of its ids or labels.
--
-- tg models the same idea as `/datum/inventory_slot/human` declarations,
-- not a closed wire enum: code/_onclick/hud/human.dm:80-129.  The slot
-- flags those declarations reference are in code/__DEFINES/inventory.dm:27-92.
return {
    -- `breathes` and `seals` are the two capabilities a native
    -- mechanism may look for. tg splits the same facts across slot
    -- flags: MASKINTERNALS is what a supply line reaches lungs through
    -- (code/__DEFINES/obj_flags.dm:84) and STOPSPRESSUREDAMAGE is what
    -- keeps a vacuum off skin (:80). Here they are properties of the
    -- PLACE, so the engine never has to know a face from a torso.
    equipment = {
        { id = "id",      label = "ID" },
        { id = "uniform", label = "Uniform" },
        { id = "suit",    label = "Suit", seals = true },
        { id = "belt",    label = "Belt" },
        { id = "back",    label = "Back", quick_store = true },
        { id = "mask",    label = "Mask", breathes = true },
    },

    -- TfS names the derived capacities; `port` only opts one into a
    -- native per-tick/security consumer. tg separates these same consumers
    -- across movement, senses and carbon life code rather than declaring a
    -- universal body vocabulary
    -- (code/modules/mob/mob_helpers.dm:37-85;
    -- code/modules/mob/living/carbon/carbon.dm:675-692).
    capacity_roles = {
        { id = "consciousness", port = "consciousness" },
        { id = "moving",        port = "movement" },
        { id = "manipulation",  port = "manipulation" },
        { id = "sight",         port = "vision" },
        { id = "hearing",       port = "hearing" },
        { id = "speech",        port = "speech" },
        { id = "breathing",     port = "breathing" },
        { id = "blood",         port = "circulation" },
        { id = "metabolism",    port = "metabolism" },
    },

    -- Formula names are content ids. Sources are engine bookkeeping ports;
    -- tg's carbon health update sums brute, burn, toxin and oxygen loss at
    -- code/modules/mob/living/carbon/carbon.dm:424-433.
    properties = {
        { id = "health",      expr = "health_fraction" },
        { id = "damage",      expr = "damage_fraction" },
        { id = "oxy",         expr = { pool = "oxy" } },
        { id = "tox",         expr = { pool = "tox" } },
        { id = "blood",       expr = "blood_fraction" },
    },

    -- The private HUD is a pack-owned list too. Pools/properties are generic
    -- indexed reads; the two ports are actual native pressure mechanisms.
    readouts = {
        { id = "brute", label = "Brute", pool = "brute" },
        { id = "burn", label = "Burn", pool = "burn" },
        { id = "oxy", label = "Oxygen loss", pool = "oxy" },
        { id = "tox", label = "Toxin load", pool = "tox" },
        { id = "pressure", label = "Pressure", port = "ambient_pressure" },
        { id = "tank", label = "Tank", port = "supply_pressure" },
    },

    -- Pool ids and placement belong to TfS. Native ports say only which
    -- engine mechanism may add a value. tg keeps brute/burn on bodyparts
    -- (`receive_damage`, code/modules/surgery/bodyparts/_bodyparts.dm:780-803)
    -- and oxygen/toxin loss on the mob (`updatehealth`,
    -- code/modules/mob/living/carbon/carbon.dm:424-433).
    pools = {
        { id = "brute", label = "Brute", storage = "attachment", port = "impact" },
        { id = "burn",  label = "Burn", storage = "attachment", port = "heat" },
        { id = "oxy",   label = "Oxygen loss", storage = "owner", port = "oxygen_loss" },
        { id = "tox",   label = "Toxin load", storage = "owner", port = "toxin_load" },
    },
    -- get_random_valid_zone uses 80% for aimed/default melee, +10 while
    -- lying, and 65% for thrown hits (code/_onclick/item_attack.dm:321-326;
    -- code/modules/mob/living/living_defense.dm:263-264).
    aim = { aimed = 80, lying_bonus = 10, thrown = 65 },
}
