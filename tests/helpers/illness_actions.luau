-- Player gestures shared by the rhinovirus behavior specs.
local clock = require("@helpers/clock")

local actions = {}

local function new_do_after_start(actor: number, starts_before: number): SpecLedgerRow?
    local starts = t.ledger_rows("do_after_started")
    local actor_body = t.body_id(actor)
    for index = starts_before + 1, #starts do
        local row = starts[index]
        if row.actor.kind == "script" and row.actor.triggered_by == actor_body then
            return row
        end
    end
    return nil
end

local function latest_sequence(event: string): number
    local latest = 0
    for _, row in ipairs(t.ledger_rows(event)) do
        latest = math.max(latest, row.seq)
    end
    return latest
end

local function latest_ledger_sequence(): number
    local latest = 0
    for _, row in ipairs(t.ledger_rows()) do
        latest = math.max(latest, row.seq)
    end
    return latest
end

local function effect_after_do_after(
    started: number,
    effect_seq_before: number,
    effect_event: string,
    name: string
): SpecLedgerRow
    local function result(): (string?, SpecLedgerRow?)
        for _, row in ipairs(t.ledger_rows("do_after_interrupted")) do
            if type(row.started) == "number" and row.started == started then
                return "interrupted", nil
            end
        end
        local effects = t.ledger_rows(effect_event)
        for _, provenance in ipairs(t.ledger_rows("script_provenance")) do
            if provenance.cause == started then
                for _, effect in ipairs(effects) do
                    if effect.seq > effect_seq_before and effect.cause == provenance.seq then
                        return "completed", effect
                    end
                end
            end
        end
        return nil, nil
    end

    local outcome, effect = result()
    local wait_limit = clock.deadline_ticks(3) + 2
    for _ = 1, wait_limit do
        if outcome ~= nil then
            break
        end
        t.tick()
        outcome, effect = result()
    end
    assert(outcome ~= "interrupted", name .. " do_after returned the interrupted outcome")
    assert(outcome == "completed", name .. " do_after completes within its bounded wait")
    return assert(effect, name .. " do_after completion records its matter effect")
end

function actions.take(actor: number, x: number, y: number, id: string): SpecObservedTarget
    if t.hands(actor).held ~= nil then
        t.drop(actor)
        t.tick()
    end
    local target = assert(t.target_at(actor, x, y, id), "the " .. id .. " is there")
    t.click(actor, x, y, target)
    t.run_ticks(2)
    return target
end

function actions.flip_syringe(actor: number): ()
    local sequence_before = latest_ledger_sequence()
    t.use_self(actor)
    t.run_ticks(2)
    local rows = t.ledger_rows()
    local use_self_plays: { [number]: boolean } = {}
    local provenance_rows: { [number]: boolean } = {}
    local actor_body = t.body_id(actor)
    for _, row in ipairs(rows) do
        if row.seq > sequence_before
            and row.event == "played"
            and row.actor.kind == "player"
            and row.actor.id == actor_body
            and row.claim == "use_self"
        then
            use_self_plays[row.seq] = true
        end
    end
    for _, row in ipairs(rows) do
        if row.seq > sequence_before
            and row.event == "script_provenance"
            and row.cause ~= nil
            and use_self_plays[row.cause]
        then
            provenance_rows[row.seq] = true
        end
    end
    local mode_change: SpecLedgerRow? = nil
    for _, row in ipairs(rows) do
        if row.seq > sequence_before
            and row.event == "mode_set"
            and row.cause ~= nil
            and provenance_rows[row.cause]
        then
            assert(mode_change == nil, "flip_syringe records one ModeSet outcome")
            mode_change = row
        end
    end
    assert(mode_change ~= nil, "flip_syringe records its use_self ModeSet outcome")
    assert(
        type(mode_change.mode) == "number" and (mode_change.mode == 0 or mode_change.mode == 1),
        "flip_syringe records the selected syringe mode"
    )
end

function actions.draw_from_vessel(actor: number, x: number, y: number, vessel: SpecObservedTarget): ()
    local transfers_before = #t.ledger_rows("matter_moved")
    t.click(actor, x, y, vessel)
    t.run_ticks(2)
    assert(
        #t.ledger_rows("matter_moved") > transfers_before,
        "draw_from_vessel records the syringe's matter transfer"
    )
end

local function body_needle(name: string, actor: number, patient: number): ()
    local x, y = t.pos(patient)
    local effect_event = if name == "inject_into_body" then "injected" else "matter_moved"
    local effects_before = #t.ledger_rows(effect_event)
    local effect_seq_before = latest_sequence(effect_event)
    local starts_before = #t.ledger_rows("do_after_started")
    t.click(actor, x, y, t.body_target(actor, patient))
    t.run_ticks(2)
    if actor == patient then
        local effects = t.ledger_rows(effect_event)
        assert(
            #effects > effects_before,
            name .. " records the immediate self-target syringe effect"
        )
        return
    end
    local started = assert(
        new_do_after_start(actor, starts_before),
        name .. " starts its three-second do_after"
    )
    effect_after_do_after(started.seq, effect_seq_before, effect_event, name)
end

function actions.draw_from_body(actor: number, patient: number): ()
    body_needle("draw_from_body", actor, patient)
end

function actions.inject_into_body(actor: number, patient: number): ()
    body_needle("inject_into_body", actor, patient)
end

function actions.has_illness(target: number | SpecObservedTarget, index: number): boolean
    for _, row in ipairs(t.riders(target) or {}) do
        if row.id == "contagion" then
            local raw = row.fields.illnesses
            if type(raw) == "table" then
                for _, carried in ipairs(raw :: { number }) do
                    if carried == index then
                        return true
                    end
                end
            end
        end
    end
    return false
end

return actions
