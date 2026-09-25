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
        { id = "id", label = "ID" },
        { id = "uniform", label = "Uniform" },
        { id = "suit", label = "Suit", seals = true },
        -- tg ITEM_SLOT_EYES: glasses, and the HUDs that ride them. Roster
        -- order is draw order: GLASSES_LAYER sits over SUIT_LAYER and under
        -- BELT_LAYER (code/__DEFINES/mobs.dm:836-840).
        { id = "eyes", label = "Eyes" },
        { id = "belt", label = "Belt" },
        { id = "back", label = "Back", quick_store = true },
        { id = "mask", label = "Mask", breathes = true },
    },

    -- TfS names the derived capacities; `port` only opts one into a
    -- native per-tick/security consumer. tg separates these same consumers
    -- across movement, senses and carbon life code rather than declaring a
    -- universal body vocabulary
    -- (code/modules/mob/mob_helpers.dm:37-85;
    -- code/modules/mob/living/carbon/carbon.dm:675-692).
    capacity_roles = {
        { id = "consciousness", port = "consciousness" },
        { id = "moving", port = "movement" },
        { id = "manipulation", port = "manipulation" },
        { id = "sight", port = "vision" },
        { id = "hearing", port = "hearing" },
        { id = "speech", port = "speech" },
        { id = "breathing", port = "breathing" },
        { id = "blood", port = "circulation" },
        { id = "metabolism", port = "metabolism" },
    },

    -- Formula names are content ids. Sources are engine bookkeeping ports;
    -- tg's carbon health update sums brute, burn, toxin and oxygen loss at
    -- code/modules/mob/living/carbon/carbon.dm:424-433.
    properties = {
        { id = "health", expr = "health_fraction" },
        { id = "damage", expr = "damage_fraction" },
        { id = "oxy", expr = { pool = "oxy" } },
        { id = "tox", expr = { pool = "tox" } },
        { id = "blood", expr = "blood_fraction" },
    },

    -- The private HUD is a pack-owned list too. Pools/properties are generic
    -- indexed reads; the ports are native atmosphere telemetry mechanisms.
    readouts = {
        { id = "brute", label = "Brute", pool = "brute" },
        { id = "burn", label = "Burn", pool = "burn" },
        { id = "oxy", label = "Oxygen loss", pool = "oxy" },
        { id = "tox", label = "Toxin load", pool = "tox" },
        { id = "pressure", label = "Pressure", port = "ambient_pressure" },
        {
            id = "temperature",
            label = "Temperature",
            suffix = "C",
            port = "ambient_temperature_c",
        },
        { id = "tank", label = "Tank", port = "supply_pressure" },
    },

    -- The medical HUD (the engine's docs/looks/status-displays.md): tg's
    -- HEALTH_HUD and STATUS_HUD images (code/__DEFINES/atom_hud.dm:7-9),
    -- full cells over the mob (code/modules/mob/mob.dm:183-197). Shown to
    -- whoever wears a medical HUD (TRAIT_MEDICAL_HUD ->
    -- DATA_HUD_MEDICAL_ADVANCED, code/datums/hud.dm:30) and to ghosts
    -- (GHOST_DATA_HUDS, code/__DEFINES/ghost.dm:63).
    status_displays = {
        {
            id = "medhud",
            property = "health",
            audience = { "revealed", "ghosts" },
            anchor = "cell",
            -- RoundHealth's bands, health/maxHealth*100 as a fraction
            -- (code/game/data_huds.dm:107-153); DM's switch takes the
            -- first matching range, so each shared edge reads the upper
            -- band. The last row is its `else` (health-100).
            style = {
                steps = {
                    { at_least = 1, sprite = "medhud_100" },
                    { at_least = 0.90625, sprite = "medhud_93_75" },
                    { at_least = 0.84375, sprite = "medhud_87_5" },
                    { at_least = 0.78125, sprite = "medhud_81_25" },
                    { at_least = 0.71875, sprite = "medhud_75" },
                    { at_least = 0.65625, sprite = "medhud_68_75" },
                    { at_least = 0.59375, sprite = "medhud_62_5" },
                    { at_least = 0.53125, sprite = "medhud_56_25" },
                    { at_least = 0.46875, sprite = "medhud_50" },
                    { at_least = 0.40625, sprite = "medhud_43_75" },
                    { at_least = 0.34375, sprite = "medhud_37_5" },
                    { at_least = 0.28125, sprite = "medhud_31_25" },
                    { at_least = 0.21875, sprite = "medhud_25" },
                    { at_least = 0.15625, sprite = "medhud_18_75" },
                    { at_least = 0.09375, sprite = "medhud_12_5" },
                    { at_least = 0.01, sprite = "medhud_6_25" },
                    { at_least = -0.5, sprite = "medhud_0" },
                    { at_least = -0.85, sprite = "medhud_m50" },
                    { at_least = -0.99, sprite = "medhud_m85" },
                    { sprite = "medhud_m100" },
                },
            },
            -- IS_DEAD_OR_FAKING reads "health-100" whatever health says
            -- (code/game/data_huds.dm:108-109): step 20. Dead is either
            -- line content/bodies/human.luau stops a body on: `dead`, or
            -- `undone` (a stopped heart), which outlasts healing.
            force = { threshold = { "dead", "undone" }, step = 20 },
            -- med_hud_set_status (code/game/data_huds.dm:179-186):
            -- huddead when dead, hudhealthy otherwise.
            icons = {
                { id = "healthy", sprite = "medhud_healthy" },
                { id = "dead", sprite = "medhud_dead", threshold = "dead" },
                { id = "undone", sprite = "medhud_dead", threshold = "undone" },
            },
            default_icon = "healthy",
        },
    },

    -- Pool ids and placement belong to TfS. Native ports say only which
    -- engine mechanism may add a value. tg keeps brute/burn on bodyparts
    -- (`receive_damage`, code/modules/surgery/bodyparts/_bodyparts.dm:780-803)
    -- and oxygen/toxin loss on the mob (`updatehealth`,
    -- code/modules/mob/living/carbon/carbon.dm:424-433).
    pools = {
        { id = "brute", label = "Brute", storage = "attachment", port = "impact" },
        { id = "burn", label = "Burn", storage = "attachment", port = "heat" },
        { id = "oxy", label = "Oxygen loss", storage = "owner", port = "oxygen_loss" },
        { id = "tox", label = "Toxin load", storage = "owner", port = "toxin_load" },
    },
    -- get_random_valid_zone uses 80% for aimed/default melee, +10 while
    -- lying, and 65% for thrown hits (code/_onclick/item_attack.dm:321-326;
    -- code/modules/mob/living/living_defense.dm:263-264).
    aim = { aimed = 80, lying_bonus = 10, thrown = 65 },
}
