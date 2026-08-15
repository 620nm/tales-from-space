-- The connector port fitting: a socket in your hands rather than in the
-- deck.
--
-- tg's `/obj/item/pipe/directional/connector`
-- (code/game/machinery/pipe/construction.dm:64-66), and it is not a
-- special case there — EVERY atmospherics device in the game is placed
-- this way. You never put a machine down; you put a fitting down and
-- wrench it, and `/obj/item/pipe/wrench_act` (construction.dm:268-312)
-- deletes the fitting and stands the machine up in its place. Taking one
-- apart runs the same trade backwards: `on_deconstruction` spawns the
-- machine's `construction_type` back onto the tile
-- (atmosmachinery.dm:511-520), which here is the port's `yields`.
--
-- The name is tg's own, composed the same way: `/obj/item/pipe/update()`
-- sets `name = "[initial(fakeA.name)] fitting"` (construction.dm:212),
-- and the machine it becomes is the "connector port". The picture is
-- likewise the machine's `pipe_state`, which for a `portables_connector`
-- is `"connector"` -- the socket drawn with no stub running down into
-- the run, because in your hands it is joined to nothing.
--
-- No hooks, no tool class, no stack: this file is a NOUN. What a wrench
-- does to it is the connector port's business, and it is written down
-- in structures/connector_port.luau where the target is the expert.
return {
    id = "connector_port_fitting",
    name = "connector port fitting",
    sprite = "connector_port_loose",
    -- tg's `inhand_icon_state = "buildpipe"` for the whole /obj/item/pipe
    -- family (construction.dm:19) -- one length of pipe over the
    -- shoulder, whichever fitting it is going to become.
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
