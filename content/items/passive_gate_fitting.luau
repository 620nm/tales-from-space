-- A passive gate, in your hands.
--
-- tg's `/obj/item/pipe/directional` pointed at `.../binary/passive_gate`
-- (passive_gate.dm:17), picture from its `pipe_state`,
-- `"passivegate"` (passive_gate.dm:18).
return {
    id = "passive_gate_fitting",
    name = "passive gate fitting",
    sprite = "passive_gate_loose",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
