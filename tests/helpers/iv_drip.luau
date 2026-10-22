-- Player-facing operations on the IV stand. Keep callers on the same
-- observed targets and rendered controls that a crew member can use.
local ui_controls = require("@helpers/ui_controls")

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
    t.click(player, item_x, item_y, item)
    t.run_ticks(2)
    t.click(player, stand_x, stand_y, stand_target(player, stand_x, stand_y))
    t.run_ticks(2)
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
): ()
    local patient_x, patient_y = t.pos(patient)
    local stand = stand_target(actor, stand_x, stand_y)
    local body = t.body_target(actor, patient)
    t.drag(actor, stand_x, stand_y, stand, patient_x, patient_y, body)
    t.run_ticks(2)
end

function iv_drip.attach(actor: number, stand_x: number, stand_y: number, patient: number): ()
    iv_drip.drag_to_patient(actor, stand_x, stand_y, patient)
    t.run_seconds(1)
    t.run_ticks(2)
end

return iv_drip
