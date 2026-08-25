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
    -- The whole-body pictures. Per-part layers wait on the wire
    -- segment; these are what a crewman looks like today.
    sprite = "human",
    sprite_dead = "human_dead",
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
