-- The human body plan (docs/BIOLOGY.md §1–§2, §4).
--
-- Everything a crewman IS: six slots a blow can land on, nine sockets
-- organs fit in, five and a half litres of blood, and the eleven
-- capacities that decide what any of that lets them do. The engine
-- names none of it — it knows roles, body scalars and the formula
-- operators, and reads this file for the rest.
--
-- Numbers carry their tgstation cite. Anything without one is marked
-- NOT PORTED and is a Tales from Space choice.
local content = {
    id = "human",
    name = "human",
    -- The ONE identifying picture: what an examine icon draws, out of
    -- any world context. The world view is a coloured layer stack the
    -- `looks` block at the bottom of this table composes
    -- (docs/LOOKS.md §2), which is a different question with a
    -- different answer.
    --
    -- No `sprite_dead`: lying down is posture on the wire now, turned
    -- client-side, so there is no second whole-body picture to swap to.
    sprite = "human",
    playable = true,

    max_health = 100,          -- MAX_LIVING_HEALTH, code/__DEFINES/mobs.dm:236

    -- The lines a crewman's numbers can be on either side of. The engine
    -- latches which side and says so on `body.threshold.done`; the hook
    -- at the bottom of this file decides what any of it means, because
    -- "crit" and "dead" are Tales from Space's words and not the
    -- engine's (docs/BIOLOGY.md §3.4).
    thresholds = {
        -- HEALTH_THRESHOLD_CRIT / MAX_LIVING_HEALTH = 0.
        -- code/__DEFINES/combat.dm:88; code/__DEFINES/mobs.dm:236.
        { id = "crit", property = "health", at_most = 0 },
        -- HEALTH_THRESHOLD_DEAD / MAX_LIVING_HEALTH = -1.
        -- code/__DEFINES/combat.dm:90; code/__DEFINES/mobs.dm:236.
        { id = "dead", property = "health", at_most = -1 },
        -- The native end-conditions as one reading: a `lethal` capacity
        -- at zero, a `vital` part or organ gone or failed, blood past
        -- `dead_below`. Losing the head is dying of it.
        { id = "undone", port = "viability", at_most = 0 },
    },
    hands = 2,                 -- default_num_hands, living_defines.dm:120
    default_zone = "chest",
    knockdown = true,
    pool_coeff = { brute = 1, burn = 1, oxy = 1, tox = 1 },   -- pool_coeff, basic.dm:51

    -- Hit weights are tg's `ran_zone` table: head and chest 1, each
    -- limb 4 (code/__HELPERS/mobs.dm:36-41). Losing the head or the
    -- chest is death — the brain leaves with the head
    -- (organ_movement.dm:210-213).
    parts = {
        { id = "head",  label = "head",      doll = { 0.38, 0.00, 0.24, 0.20 }, default = "human_head",  hit_weight = 1, vital = true },
        { id = "chest", label = "chest",     doll = { 0.30, 0.20, 0.40, 0.35 }, default = "human_chest", hit_weight = 1, vital = true },
        { id = "l_arm", label = "left arm",  doll = { 0.10, 0.20, 0.20, 0.40 }, default = "human_l_arm", hit_weight = 4, hand = 1 },
        { id = "r_arm", label = "right arm", doll = { 0.70, 0.20, 0.20, 0.40 }, default = "human_r_arm", hit_weight = 4, hand = 2 },
        { id = "l_leg", label = "left leg",  doll = { 0.30, 0.55, 0.20, 0.45 }, default = "human_l_leg", hit_weight = 4 },
        { id = "r_leg", label = "right leg", doll = { 0.50, 0.55, 0.20, 0.45 }, default = "human_r_leg", hit_weight = 4 },
    },

    -- The socket carries the zone and the tags; the organ carries its
    -- own health. That split is what lets a removed organ leave a hole
    -- a capacity can see. `requires` lists the surgical states the host
    -- part must additionally hold before an organ operation may reach
    -- the socket — tg's per-organ `organ_check`
    -- (operation_organ_manip.dm:279-284).
    sockets = {
        brain    = { zone = "head",  tags = { "brain" }, mind_seat = true, requires = { "bone_sawed" } },
        eyes     = { zone = "head",  tags = { "eye" } },
        ears     = { zone = "head",  tags = { "ear" } },
        tongue   = { zone = "head",  tags = { "tongue" } },
        heart    = { zone = "chest", tags = { "heart" },   requires = { "bone_sawed" } },
        lungs    = { zone = "chest", tags = { "lung" },    requires = { "bone_sawed" } },
        liver    = { zone = "chest", tags = { "liver" },   requires = { "bone_sawed" } },
        stomach  = { zone = "chest", tags = { "stomach" }, requires = { "bone_sawed" } },
        appendix = { zone = "chest", tags = {},            requires = { "bone_sawed" } },
    },
    organs = {
        brain = "organ_brain", eyes = "organ_eyes", ears = "organ_ears",
        tongue = "organ_tongue", heart = "organ_heart", lungs = "organ_lungs",
        liver = "organ_liver", stomach = "organ_stomach", appendix = "organ_appendix",
    },

    -- The capacity graph. `awake_below`, `min_capable` and the `lerp1`
    -- weights are NOT PORTED: RimWorld's shape with Tales from Space's
    -- own constants, because tg has no capacity model to copy.
    capacities = {
        -- No role: the seat's own pulse. Losing or destroying the brain
        -- is death, and this is the only capacity allowed to say so.
        -- `awake_only = false` because it must read true while the body
        -- is under — being asleep is not the same as having no brain.
        brain = { lethal = true, awake_only = false, formula = { "tag", "brain", absent = 1 } },

        consciousness = { role = "consciousness", awake_below = 0.30,
            formula = { "product", { "cap", "brain" },
                                   { "lerp1", { "cap", "blood",     max = 1 }, 0.2 },
                                   { "lerp1", { "cap", "breathing", max = 1 }, 0.2 },
                                   -- OXYLOSS_PASSOUT_THRESHOLD, mobs.dm:14:
                                   -- a knockout, never a death.
                                   { "step", "oxy", 50 },
                                   -- BLOOD_VOLUME_BAD 224/560: tg rolls
                                   -- blackouts through this band
                                   -- (blood.dm:242-244); TfS holds the
                                   -- body under instead.
                                   { "step", "blood", 0.4, below = 0 },
                                   -- HEALTH_THRESHOLD_FULLCRIT /
                                   -- MAX_LIVING_HEALTH = -0.3
                                   -- (combat.dm:89; mobs.dm:236): tg's
                                   -- HARD_CRIT, which is out cold rather
                                   -- than merely in crit. It is a term of
                                   -- this formula and not a threshold
                                   -- because being under is a fact the
                                   -- capacities decide, not a verdict
                                   -- anybody reaches.
                                   { "step", "health", -0.3, below = 0 } } },

        moving = { role = "moving", min_capable = 0.15,
            formula = { "product", { "tag", "leg", absent = 1 },
                                   { "cap", "consciousness", max = 1 },
                                   { "lerp1", { "cap", "blood" }, 0.2 },
                                   { "lerp1", { "cap", "breathing" }, 0.2 } } },

        manipulation = { role = "manipulation",
            formula = { "product", { "tag", "arm", absent = 1 }, { "cap", "consciousness" } } },

        sight = { role = "sight",
            formula = { "product", { "tag", "eye", absent = 1 }, { "cap", "consciousness" } } },

        hearing = { role = "hearing",
            formula = { "product", { "tag", "ear", absent = 1 }, { "cap", "consciousness" } } },

        speech = { role = "speech",
            formula = { "product", { "tag", "tongue", absent = 1 },
                                   { "tag", "lung", absent = 1 },
                                   { "cap", "consciousness" } } },

        -- Lungs, and the depth past which a crewman stops using them.
        -- tg raises `losebreath` for exactly two reasons — lungs that
        -- have failed, and HARD_CRIT (carbon/life.dm:83-90) — and both
        -- are this one number now: the breathing pass misses a breath
        -- when this role reads 0, so the engine applies the fact and
        -- this file decides it.
        --
        -- NOT PORTED: tg's `losebreath += 0.25` in SOFT crit (:89-90).
        -- A quarter of a missed breath is a per-tick roll, and the
        -- boundary that made this a role reading is the same one that
        -- says a per-tick decision is not a hook's to make.
        breathing = { role = "breathing", awake_only = false,
            formula = { "product", { "tag", "lung", absent = 1 },
                                   { "step", "health", -0.3, below = 0 } } },

        -- Cardiac arrest, as data: oxy 4/s and brute 1/s spread over
        -- whatever parts are left, and the body held under for as long
        -- as it lasts (code/modules/mob/living/carbon/human/life.dm:292-295).
        blood = { role = "blood", awake_only = false,
            formula = { "tag", "heart", absent = 1 },
            when_zero = { pools = { oxy = 4, brute = 1 }, unconscious = true } },

        -- ...and liverlessness: tox 0.6/s (carbon/life.dm:746). NOT
        -- CARRIED from tg: the companion 0.5/s random organ damage
        -- (carbon/life.dm:746-747).
        metabolism = { role = "metabolism", awake_only = false,
            formula = { "tag", "liver", absent = 1 },
            when_zero = { pools = { tox = 0.6 } } },
    },

    -- The surgical states this species has (docs/SURGERY.md §6.1).
    -- Interned per plan and stored per part as a bitset; the operations
    -- that move between them are B2's.
    surgery = {
        states = { "skin_cut", "skin_open", "vessels_unclamped", "vessels_clamped",
                   "organs_cut", "bone_drilled", "bone_sawed", "cavity_open" },
        -- Per second. UNCLAMPED_VESSELS_BLEEDING / CLAMPED_VESSELS_BLEEDING,
        -- code/__DEFINES/surgery.dm (bodyparts.dm:217-219); precedence is
        -- the highest value the part holds (_bodyparts.dm:1634-1638).
        bleeds = { vessels_unclamped = 1.5, vessels_clamped = 0.2, organs_cut = 0.2 },
        clears_on_close = { "skin_cut", "skin_open", "vessels_unclamped", "vessels_clamped",
                            "organs_cut", "bone_drilled", "bone_sawed", "cavity_open" },
    },

    -- What a bystander is told about a body, in whole sentences
    -- (docs/LOCALIZATION.md §5). Read from the public layer only.
    examine = {
        lying = "They are lying on the deck.",
        bleeding = "They are bleeding.",
        missing = {
            head = "Their head is gone.",
            l_arm = "Their left arm is missing.",
            r_arm = "Their right arm is missing.",
            l_leg = "Their left leg is missing.",
            r_leg = "Their right leg is missing.",
        },
    },

    -- The three sentences the engine used to say for itself. They are
    -- content now, and a species whose members do not black out simply
    -- does not write the line.

    -- What a crewman LOOKS like: the layers a body is drawn out of and
    -- the rosters a spawn rolls over (docs/LOOKS.md). The engine picks
    -- rows and multiplies colours; every word below is this file's.
    --
    -- Ordering is load-bearing in two places, and nowhere else.
    -- `layers` below is the DRAW order, bottom-up — deliberately its
    -- own list, because the `parts` list above is the ZONE order (the
    -- hit-weight walk, the doll, the surgical index) and an artist's
    -- stacking has no business moving a mapper's anatomy. And the
    -- FIRST row of every roster
    -- is what a plain body wears, so each one leads with tg's own
    -- default: `caucasian1`, `Bald`, `Shaved`, `MALE` (human_defines.dm
    -- :20-57; species_features/basic.dm:54-197). The roll itself is
    -- uniform, so the rest of the order means nothing — tg sorts
    -- GLOB.skin_tones alphabetically at runtime for exactly that
    -- reason (mobs.dm:119).
    looks = {
        -- One greyscale cell per part slot, multiplied by the skin
        -- tone. A table is DIMORPHIC: tg builds the chest and the head
        -- as `"human_[body_zone]_[m|f]"` and the limbs without a
        -- suffix (_bodyparts.dm:1308-1310), so those two name a cell
        -- per physique and the limbs name one. An arm's cell has its
        -- hand composited in (assets/sprites/47-human-looks.ron).
        parts = {
            chest = { m = "body_chest_m", f = "body_chest_f" },
            head  = { m = "body_head_m",  f = "body_head_f" },
            l_arm = "body_l_arm",
            r_arm = "body_r_arm",
            l_leg = "body_l_leg",
            r_leg = "body_r_leg",
        },
        -- Bottom-up. The chest leads: it is the trunk everything else
        -- hangs off, exactly as tg's chest is the bodypart the others
        -- attach to (_bodyparts.dm).
        layers = { "chest", "head", "l_arm", "r_arm", "l_leg", "r_leg" },

        -- Eyes, beard and hair ride the head: lose it and all three go
        -- with it (head_hair_and_lips.dm:47-175).
        face = "head",

        -- `pick(MALE, FEMALE)` (create_mob.dm:29-30). The word is the
        -- key `parts` and the rosters below are dimorphic BY, and
        -- nothing else.
        physiques = { "m", "f" },

        -- GLOB.skin_tones (mobs.dm:119-136) with skintone2hex's own
        -- values (surgery/bodyparts/helpers.dm:288-326). The two
        -- non-human tones that proc also answers, `orange` and
        -- `green`, are not in GLOB.skin_tones and are not here.
        skin_tones = {
            { id = "caucasian1", color = "#ffe0d1" },
            { id = "albino", color = "#fff4e6" },
            { id = "caucasian2", color = "#fcccb3" },
            { id = "caucasian3", color = "#e8b59b" },
            { id = "latino", color = "#d9ae96" },
            { id = "mediterranean", color = "#c79b8b" },
            { id = "asian1", color = "#ffdeb3" },
            { id = "asian2", color = "#e3ba84" },
            { id = "arab", color = "#c4915e" },
            { id = "indian", color = "#b87840" },
            { id = "mixed1", color = "#a57a66" },
            { id = "mixed2", color = "#87563d" },
            { id = "mixed3", color = "#725547" },
            { id = "mixed4", color = "#866e63" },
            { id = "african1", color = "#754523" },
            { id = "african2", color = "#471c18" },
        },

        -- `random_hair_color()`: the 36 natural swatches, verbatim and
        -- in source order (mobs.dm:57-69). The roll gives the beard
        -- the same one (create_mob.dm:37-39), which the engine does.
        hair_colors = {
            "#111111", "#362925", "#3B3831", "#41250C", "#412922", "#544C49",
            "#583322", "#593029", "#703b30", "#714721", "#744729", "#74482a",
            "#7b746e", "#855832", "#863019", "#8c4734", "#9F550E", "#A29A96",
            "#A4381C", "#B17B41", "#C0BAB7", "#EFE5E4", "#F7F3F1", "#FFF2D6",
            "#a15537", "#a17e61", "#b38b67", "#ba673c", "#c89f73", "#d9b380",
            "#dbc9b8", "#e1621d", "#e17d17", "#e1af93", "#f1cc8f", "#fbe7a1",
        },

        -- `random_eye_color()` (mobs.dm:38-55): weighted buckets. The
        -- grey bucket is one weight of 20 spread over seven shades, so
        -- it is seven rows of a seventh of it — the same distribution
        -- written the way a table can hold it.
        --
        -- NOT PORTED: the `albino` bucket (weight 1 of 92), which is a
        -- colour tg GENERATES per roll from four hundred combinations
        -- (mobs.dm:53). A fixed table cannot hold a generator, and one
        -- representative hex would be a different number.
        eye_colors = {
            { color = "#663300", weight = 20 },   -- COLOR_BROWNER_BROWN, colors.dm:161
            { color = "#554422", weight = 20 },   -- hazel
            { color = "#666666", weight = 20 / 7 },
            { color = "#777777", weight = 20 / 7 },
            { color = "#888888", weight = 20 / 7 },
            { color = "#999999", weight = 20 / 7 },
            { color = "#aaaaaa", weight = 20 / 7 },
            { color = "#bbbbbb", weight = 20 / 7 },
            { color = "#cccccc", weight = 20 / 7 },
            { color = "#3366cc", weight = 15 },   -- blue
            { color = "#006600", weight = 15 },   -- green
            { color = "#ffcc00", weight = 1 },    -- amber
        },

        -- Two eye cells, so two eye colours are drawable
        -- (icons/mob/human/human_eyes.dmi, `_eyes.dm:305-377`). A roll
        -- gives both the same colour; anything that sets them apart
        -- has somewhere to put the difference.
        eyes = { "eye_l", "eye_r" },

        -- 42 of tgstation's 222 hairstyles: the first alphabetically in
        -- `hair.dm`, and nothing more principled than that. Every one
        -- is roll-eligible in tg — `natural_spawn` DEFAULTS to true
        -- (_sprite_accessory.dm:47-49) and only fourteen of the 222
        -- opt out — so this is a subset of ~208, not a filter of them.
        -- The rest are one line each in
        -- `assets/sprites/47-human-looks.ron` and one here, whenever
        -- somebody wants them.
        --
        -- None names a physique, because no hair datum overrides the
        -- base `gender = NEUTER` — every style is in both of tg's
        -- lists. `bald` leads and draws nothing (hair.dm:152-154). Two
        -- of the first 44, `Boddicker` and `Buzzcut`, are left out: the
        -- back of each is one flat grey the atlas lint refuses
        -- (assets/sprites/47-human-looks.ron).
        hair = {
            { id = "bald" },
            { id = "afro", sprite = "hair_afro" },
            { id = "afro2", sprite = "hair_afro2" },
            { id = "afro_over_eyes", sprite = "hair_afro_over_eyes" },
            { id = "afro_three_quarters", sprite = "hair_afro_three_quarters" },
            { id = "allthefuzz", sprite = "hair_allthefuzz" },
            { id = "ahoge", sprite = "hair_ahoge" },
            { id = "anime_protagonist", sprite = "hair_anime_protagonist" },
            { id = "balding", sprite = "hair_balding" },
            { id = "bedhead", sprite = "hair_bedhead" },
            { id = "bedhead2", sprite = "hair_bedhead2" },
            { id = "bedhead3", sprite = "hair_bedhead3" },
            { id = "bedhead4", sprite = "hair_bedhead4" },
            { id = "long_bedhead", sprite = "hair_long_bedhead" },
            { id = "shorter_long_bedhead", sprite = "hair_shorter_long_bedhead" },
            { id = "beehive", sprite = "hair_beehive" },
            { id = "beehive2", sprite = "hair_beehive2" },
            { id = "bob", sprite = "hair_bob" },
            { id = "bob2", sprite = "hair_bob2" },
            { id = "bob3", sprite = "hair_bob3" },
            { id = "bob4", sprite = "hair_bob4" },
            { id = "bobcurl", sprite = "hair_bobcurl" },
            { id = "bowlcut", sprite = "hair_bowlcut" },
            { id = "bowlcut2", sprite = "hair_bowlcut2" },
            { id = "bowlcut_over_eyes", sprite = "hair_bowlcut_over_eyes" },
            { id = "braid_floorlength", sprite = "hair_braid_floorlength" },
            { id = "braided", sprite = "hair_braided" },
            { id = "braid_front", sprite = "hair_braid_front" },
            { id = "braid_high", sprite = "hair_braid_high" },
            { id = "braid_low", sprite = "hair_braid_low" },
            { id = "braid_short", sprite = "hair_braid_short" },
            { id = "braid_tail", sprite = "hair_braid_tail" },
            { id = "bun", sprite = "hair_bun" },
            { id = "bun2", sprite = "hair_bun2" },
            { id = "bun3", sprite = "hair_bun3" },
            { id = "bun_large", sprite = "hair_bun_large" },
            { id = "manbun", sprite = "hair_manbun" },
            { id = "bun_tight", sprite = "hair_bun_tight" },
            { id = "business", sprite = "hair_business" },
            { id = "business2", sprite = "hair_business2" },
            { id = "business3", sprite = "hair_business3" },
            { id = "business4", sprite = "hair_business4" },
            { id = "chinbob", sprite = "hair_chinbob" },
        },

        -- ...and 22 of tgstation's 38 beards, the first alphabetically
        -- in `facial_hair.dm` and roll-eligible there for the same
        -- reason the hair is; the other sixteen are one line each.
        --
        -- These DO name a physique: tg's base facial datum is
        -- `gender = MALE` (facial_hair.dm:1-4), so only `Shaved` —
        -- which overrides it to NEUTER (:158-161) — can be rolled onto
        -- a body that is not `m`.
        facial_hair = {
            { id = "shaved" },
            { id = "abe", sprite = "facial_abe", gender = "m" },
            { id = "chinstrap", sprite = "facial_chinstrap", gender = "m" },
            { id = "dwarf", sprite = "facial_dwarf", gender = "m" },
            { id = "fullbeard", sprite = "facial_fullbeard", gender = "m" },
            { id = "cropped_fullbeard", sprite = "facial_cropped_fullbeard", gender = "m" },
            { id = "goatee", sprite = "facial_goatee", gender = "m" },
            { id = "hipster", sprite = "facial_hipster", gender = "m" },
            { id = "jensen", sprite = "facial_jensen", gender = "m" },
            { id = "neckbeard", sprite = "facial_neckbeard", gender = "m" },
            { id = "very_long", sprite = "facial_very_long", gender = "m" },
            { id = "muttonmus", sprite = "facial_muttonmus", gender = "m" },
            { id = "chinless", sprite = "facial_chinless", gender = "m" },
            { id = "moonshiner", sprite = "facial_moonshiner", gender = "m" },
            { id = "long", sprite = "facial_long", gender = "m" },
            { id = "volaju", sprite = "facial_volaju", gender = "m" },
            { id = "three_oclock", sprite = "facial_three_oclock", gender = "m" },
            { id = "five_oclock", sprite = "facial_five_oclock", gender = "m" },
            { id = "five_oclock_moustache", sprite = "facial_five_oclock_moustache", gender = "m" },
            { id = "seven_oclock", sprite = "facial_seven_oclock", gender = "m" },
            { id = "seven_oclock_moustache", sprite = "facial_seven_oclock_moustache", gender = "m" },
            { id = "moustache", sprite = "facial_moustache", gender = "m" },
            { id = "pencilstache", sprite = "facial_pencilstache", gender = "m" },
        },

        -- NOT SHIPPED: `underwear`, `undershirt` and `socks`. The
        -- schema carries them (docs/LOOKS.md) and tg draws them always
        -- (human_update_icons.dm:668-700); nothing in this pack has
        -- the art yet, so a crewman is bare under the jumpsuit.
    },
}

-- What the lines MEAN. This is the whole of being alive in Tales from
-- Space, and it is five lines because the engine holds exactly two
-- facts about a body: whether its session may steer it, and whether its
-- own processes still run (docs/BIOLOGY.md §3.4).
--
-- Settled from the SET of crossed thresholds and not from the one edge
-- that woke the hook: a crewman healed back over the `dead` line with
-- their heart still out has cleared one and not the other, and reading
-- the set is what keeps them on the deck.
local STOP = { dead = true, undone = true }
local HOLD = { crit = true }

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("body.threshold.done", { kind = "react", route = "threshold" }, function(ev)
        local body = ev.body
        local stop, hold = false, false
        for _, id in ipairs(sim.body(body).thresholds) do
            if STOP[id] then stop = true end
            if HOLD[id] then hold = true end
        end
        sim.set_body_facts(body, {
            animate = not stop,
            controllable = not (stop or hold),
            label = stop and "Dead" or (hold and "Critical" or ""),
        })
        -- ...and then the crewman is told, once per crossing.
        if ev.edge == "dead" or ev.edge == "undone" then
            sim.message.send({ recipient = body, message = "You have died." })
        elseif ev.edge == "crit" then
            sim.message.send({ recipient = body, message = "You black out..." })
        elseif not stop and not hold then
            sim.message.send({ recipient = body, message = "You come to." })
        end
    end)
end

return content
