-- BLOOD IDENTITY: tg's eight human blood types, riding blood.
--
-- The kind (`riders/blood_identity.luau`) carries one field, `type`, a
-- ref into the `blood_types` roster. This lib is the one answer beside
-- it: the weights, the compatibility, the one writer and the one meet
-- dispatcher. DNA and contagion slide in beside it without a rewrite
-- (docs/TODO.md, "Blood identity rider").
--
-- tg: /datum/blood_type/human and its eight children
-- (code/modules/mob/living/blood_types.dm:175-240); assignment by
-- random_human_blood_type's weights (code/__HELPERS/mobs.dm:10-22).
local blood_identity = {}

blood_identity.KIND = "blood_identity"

-- Roster order is tg's weights order (mobs.dm:14-21): o-, o+, a-, a+,
-- b-, b+, ab-, ab+. A rider field holds the 0-based position; these
-- Lua arrays are 1-based, so every crossing subtracts one.
blood_identity.IDS = {
    "o_minus",
    "o_plus",
    "a_minus",
    "a_plus",
    "b_minus",
    "b_plus",
    "ab_minus",
    "ab_plus",
}
blood_identity.NAMES = {
    "O-",
    "O+",
    "A-",
    "A+",
    "B-",
    "B+",
    "AB-",
    "AB+",
}
-- mobs.dm:14-21, verbatim. Total 98.
local WEIGHTS = { 4, 36, 3, 28, 1, 20, 1, 5 }
local TOTAL_WEIGHT = 0
for _, w in ipairs(WEIGHTS) do
    TOTAL_WEIGHT += w
end

-- Compatible DONORS per receiver, as 0-based roster indices: the types
-- safe to use with people who have this one (blood_types.dm:13).
-- A-: A-, O- (:175-181); A+: A-, A+, O-, O+ (:182-190);
-- B-: B-, O- (:191-196); B+: B-, B+, O-, O+ (:198-205);
-- AB-: A-, B-, AB-, O- (:207-214);
-- AB+: every type (:216-227); O-: O- (:229-233); O+: O-, O+ (:235-240).
local COMPATIBLE: { { number } } = {
    { 0 }, -- O-
    { 0, 1 }, -- O+
    { 2, 0 }, -- A-
    { 2, 3, 0, 1 }, -- A+
    { 4, 0 }, -- B-
    { 4, 5, 0, 1 }, -- B+
    { 2, 4, 6, 0 }, -- AB-
    { 2, 3, 4, 5, 0, 1, 6, 7 }, -- AB+
}

-- blood.dm:408: an incompatible transfusion adds toxin at half the
-- transfused volume. carbon/life.dm:498 says the same for donor blood
-- that reaches the bloodstream as a substance.
local TOXIN_HALF = 0.5

-- BODYTEMP_NORMAL (code/__DEFINES/atmospherics/atmos_mob_interaction.dm:53),
-- the figure the bloodstream holder is declared at; the reaction's
-- toxin lands at body temperature.
local BLOOD_TEMP_K = 310.15

export type TransfusionNote = {
    target: Handle,
    donor: number?,
    receiver: number?,
}

-- Injections in flight, oldest first. A `matter.inject.done` carries
-- only moles -- no ends -- so the stroke files its note beside the
-- command and the completion settles the oldest one. Completions fire
-- in issue order, and every stroke pushes exactly one note, so the
-- oldest note is always this completion's. An empty book settles to
-- nothing, the way `lib/consume_followups.luau` settles an unknown
-- item to nil.
local pending: { TransfusionNote } = {}

-- True when `donor` blood is safe in a `receiver` body, both 0-based
-- roster indices (blood_types.dm:13, blood.dm:406).
function blood_identity.compatible(receiver: number, donor: number): boolean
    local list = COMPATIBLE[receiver + 1]
    if list == nil then
        return false
    end
    for _, candidate in ipairs(list) do
        if candidate == donor then
            return true
        end
    end
    return false
end

-- A unit draw through tg's weights, answered as a 0-based roster index.
function blood_identity.pick(u: number): number
    local x = u * TOTAL_WEIGHT
    local acc = 0
    for i, w in ipairs(WEIGHTS) do
        acc += w
        if x < acc then
            return i - 1
        end
    end
    return #WEIGHTS - 1
end

-- The draw key for a body: its Mind's name, lowered into the resource
-- tail alphabet. Continuity state attaches to the Mind, and the rider
-- persists the outcome, so a body bled dry redraws the same type --
-- your type does not change when you bleed out. The `blood/` prefix
-- keeps the tail's first byte valid whatever the name starts with.
local function draw_key(body: Handle): string
    local mind = body.mind
    local who = (mind and mind.name) or body.name or "nameless"
    local tail = who:lower():gsub("[^a-z0-9_./-]", "_"):sub(1, 110)
    return "lunatic/tfs:blood/" .. tail
end

-- The holder's settled type, or nil when it holds no typed blood: no
-- rider, or a meeting still waiting on its answer. A pending newcomer
-- is never the answer -- the holder's type is the entry that stays.
function blood_identity.type_of(owner: Handle): number?
    local entries = sim.riders(owner)
    if entries == nil then
        return nil
    end
    for _, entry in pairs(entries) do
        if entry.id == blood_identity.KIND and entry.pending ~= true then
            local found = entry.fields and entry.fields.type
            if typeof(found) == "number" then
                return found
            end
        end
    end
    return nil
end

-- THE ONE WRITER. Run on the body's first `blood_harmony.on_life`
-- pass, and every pass after until it lands: a body with no blood has
-- nothing to carry the write, so the pass it regrows into tries again.
function blood_identity.stamp(body: Handle): ()
    if blood_identity.type_of(body) ~= nil then
        return
    end
    local state = sim.body(body)
    local blood = state and state.blood or nil
    if blood == nil or blood <= 0 then
        return
    end
    local drawn = sim.random_keyed("blood_identity.stamp", draw_key(body))
    sim.set_rider(body, blood_identity.KIND, { type = blood_identity.pick(drawn) })
end

-- THE ONE MEET DISPATCHER. Receiver wins, settled explicitly: the
-- settled entry's type is written back over the meeting, compatible
-- or not. The meet carries no moles, so an incompatible type settles
-- here and reacts at the transfer completion, which knows the dose.
-- With no settled entry the first pending one stays, the engine's own
-- default (the engine's docs/matter/rider.md, Meeting).
function blood_identity.on_meet(ev: MatterRiderMeetPayload): ()
    local entries = sim.riders(ev.holder)
    if entries == nil then
        return
    end
    local settled: number? = nil
    local first: number? = nil
    local ordered: { any } = entries :: { any }
    for _, entry in ipairs(ordered) do
        if entry.id == blood_identity.KIND then
            local found = entry.fields and entry.fields.type
            if typeof(found) == "number" then
                if first == nil then
                    first = found
                end
                if entry.pending ~= true and settled == nil then
                    settled = found
                end
            end
        end
    end
    local keep = settled or first
    if keep == nil then
        return
    end
    sim.set_rider(ev.holder, blood_identity.KIND, { type = keep })
end

-- File the note for an injection about to be issued: the body it is
-- pointed at and both ends' settled types, nil when an end is untyped.
function blood_identity.note_transfusion(target: Handle, donor: number?, receiver: number?): ()
    table.insert(pending, { target = target, donor = donor, receiver = receiver })
end

-- Answer one `matter.inject.done`: the oldest note's transfusion moved
-- `moved` moles, and an incompatible one answers with tg's toxin at
-- half the volume (blood.dm:406-410). Riderless blood on either end
-- is untyped and cannot react; a refused injection moved nothing.
function blood_identity.settle_injection(moved: number): ()
    local note = table.remove(pending, 1)
    if note == nil then
        return
    end
    if moved <= 0 then
        return
    end
    local donor, receiver = note.donor, note.receiver
    if donor == nil or receiver == nil then
        return
    end
    if blood_identity.compatible(receiver, donor) then
        return
    end
    sim.matter.deposit({
        owner = note.target,
        substance = "toxin",
        moles = moved * TOXIN_HALF,
        temp_k = BLOOD_TEMP_K,
    })
end

-- Claim the kind's definition and bind its dispatcher. Called once
-- from the blood substance file, the carrier it rides: this roster
-- never runs as a script, so the kind's behavior has to be defined
-- from a file that does.
function blood_identity.attach(): ()
    local definition =
        sim.define("behavior", "lunatic/tfs:" .. blood_identity.KIND, { prototype = blood_identity.KIND })
    definition:handle("matter.rider.meet", { kind = "react" }, blood_identity.on_meet)
end

return blood_identity
