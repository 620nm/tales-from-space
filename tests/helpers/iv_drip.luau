-- Player-facing operations on the IV stand. Keep callers on the same
-- observed targets and rendered controls that a crew member can use.
local ui_controls = require("@helpers/ui_controls")
local clock = require("@helpers/clock")

local iv_drip = {}

local function stand_target(player: number, x: number, y: number): SpecObservedTarget
    local target = assert(t.target_at(player, x, y, "iv_drip"), "the IV stand is visible")
    return target
end

function iv_drip.open(player: number, x: number, y: number): ()
    t.click(player, x, y, stand_target(player, x, y))
    t.run_ticks(2)
    assert(t.ui_document(player) ~= nil, "the stand opens its module panel")
end

function iv_drip.mount(
    player: number,
    item_id: string,
    item_x: number,
    item_y: number,
    stand_x: number,
    stand_y: number
): SpecObservedTarget
    local item = assert(t.target_at(player, item_x, item_y, item_id), "the named vessel is visible")
    local vessel_name = assert(
        t.examine(player, item_x, item_y, item),
        "mount can examine the named vessel"
    ).title
    local docked_before = #t.ledger_rows("docked")
    local stand = stand_target(player, stand_x, stand_y)
    t.click(player, item_x, item_y, item)
    t.run_ticks(2)
    t.click(player, stand_x, stand_y, stand)
    t.run_ticks(2)
    local docked = t.ledger_rows("docked")
    assert(#docked == docked_before + 1, "mount records one native dock outcome")
    local receipt = assert(docked[#docked], "mount records its dock receipt")
    local actor_body = t.body_id(player)
    assert(
        receipt.actor.kind == "player"
            and receipt.actor.id == actor_body
            and receipt.item == vessel_name
            and receipt.machine == "IV drip",
        "mount receipt names this vessel and the IV drip stand"
    )
    assert(t.hands(player).held == nil, "mount leaves the vessel in the stand")
    assert(
        t.target_at(player, item_x, item_y, item_id) == nil,
        "mount removes the named vessel from its floor tile"
    )
    assert(t.vessel(item) ~= nil, "mount keeps the docked vessel observable")
    return item
end

function iv_drip.action(player: number, key: string): ()
    ui_controls.toggle(player, "action", key)
    t.run_ticks(2)
end

function iv_drip.rate(player: number, value: number): ()
    ui_controls.input(player, "rate", tostring(value))
    t.run_ticks(2)
end

function iv_drip.eject(player: number): ()
    ui_controls.toggle(player, "eject")
    t.run_ticks(2)
end

function iv_drip.drag_to_patient(
    actor: number,
    stand_x: number,
    stand_y: number,
    patient: number
): number?
    local patient_x, patient_y = t.pos(patient)
    local stand = stand_target(actor, stand_x, stand_y)
    local body = t.body_target(actor, patient)
    local started_before = #t.ledger_rows("do_after_started")
    t.messages(actor)
    t.drag(actor, stand_x, stand_y, stand, patient_x, patient_y, body)
    t.run_ticks(2)
    local started = t.ledger_rows("do_after_started")
    local actor_body = t.body_id(actor)
    local start: SpecLedgerRow? = nil
    for index = started_before + 1, #started do
        local row = started[index]
        if row.actor.kind == "script" and row.actor.triggered_by == actor_body then
            start = row
            break
        end
    end
    if start ~= nil then
        return start.seq
    end
    local refused = false
    for _, message in ipairs(t.messages(actor)) do
        if string.find(message, "Drag the stand with a docked vessel", 1, true) ~= nil then
            refused = true
            break
        end
    end
    assert(refused, "drag_to_patient reports refusal when the endpoint cannot attach")
    return nil
end

function iv_drip.attach(actor: number, stand_x: number, stand_y: number, patient: number): ()
    local started = assert(
        iv_drip.drag_to_patient(actor, stand_x, stand_y, patient),
        "attach starts the guarded IV connection"
    )
    local completed = false
    local interrupted = false
    for _ = 1, clock.deadline_ticks(1) + 2 do
        for _, row in ipairs(t.ledger_rows("do_after_interrupted")) do
            if row.started == started then
                interrupted = true
                break
            end
        end
        if interrupted then
            break
        end
        for _, row in ipairs(t.ledger_rows("script_provenance")) do
            if row.cause == started then
                completed = true
                break
            end
        end
        if completed then
            break
        end
        t.tick()
    end
    assert(not interrupted, "attach do_after completes without interruption")
    assert(completed, "attach observes the completed do_after outcome")
    local state = assert(t.structure_at(stand_x, stand_y), "attach keeps the IV stand on its tile")
    assert(
        state.state == "iv_drip_injecting" or state.state == "iv_drip_donating",
        "attach connects the IV line to the named patient"
    )
end

return iv_drip
