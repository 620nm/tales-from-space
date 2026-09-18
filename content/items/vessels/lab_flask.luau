local vessel = require("@lib/vessel")

-- A two-litre pressure flask for gas synthesis. It keeps the bottle's
-- handling and fill art while giving the chemistry lab a shell large enough
-- for a useful syngas batch.
local content = {
    id = "lab_flask",
    visual_layer = "item",
    name_label = "lunatic/tfs:entity.lab_flask.name",
    name = "lab pressure flask",
    sprite = "bottle",
    volume_ml = 2000,
    sealed = true,
    resealable = true,
    interaction_labels = {
        self = { label = "lunatic/tfs:ui.affordance.toggle_flask_valve" },
    },
    acts_on_items = true,
    fill_sprites = {
        { 1, "bottle_fill_1" },
        { 20, "bottle_fill_20" },
        { 40, "bottle_fill_40" },
        { 60, "bottle_fill_60" },
        { 80, "bottle_fill_80" },
        { 100, "bottle_fill_100" },
    },
    -- A 2 L pressure vessel rated above the 6 MPa lab charge. The canister
    -- source is rated to 500 MPa; this flask gives a realistic lower limit
    -- while leaving the commissioned 6 MPa batch safely below it.
    failure = {
        integrity = 200,
        break_at = 0.5,
        limit_kpa = 10000,
        damage_min = 5,
        damage_max = 50,
        on_break = "leak",
        sound = "spray",
        message = "lunatic/tfs:lib.vessel.tank_leak",
    },
}

local vessel_spec: vessel.Spec = {
    id = content.id,
    noun = "lab flask",
    phases = { "liquid", "solid" },
    open_to_pour = true,
    pour = { units = 10 },
}
content.actions = vessel.actions(vessel_spec)

if sim ~= nil then
    local definition = vessel.attach(vessel_spec)
    definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        if assert(sim.matter_read(ev.subject)).sealed then
            sim.unseal(ev.subject)
        else
            sim.seal(ev.subject)
        end
        return true
    end)
end

return content
