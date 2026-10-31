-- The one click every die answers: roll it in hand.
local dice = {}

-- A fresh action list per die; the `interaction.use` self handler it describes
-- rolls, sounds and tells the roller.
function dice.actions()
    return {
        {
            id = "roll",
            gesture = "self",
            route = "self_use",
            label = "lunatic/tfs:ui.affordance.roll",
        },
    }
end

return dice
