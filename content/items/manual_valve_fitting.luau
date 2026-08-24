-- A manual valve, in your hands rather than in the run.
--
-- tg's `/obj/item/pipe/binary` carrying `pipe_type = .../binary/valve`
-- (construction.dm:15 on the valve, construction.dm:212 on the name):
-- every atmospherics machine in the game is placed this way. You never
-- put a machine down; you put a fitting down, wrench it, and
-- `/obj/item/pipe/wrench_act` (construction.dm:268-312) deletes the
-- fitting and stands the machine up in its place. Taking one apart runs
-- the trade backwards, which is the valve's own `yields`.
--
-- No hooks, no tool class, no stack: this file is a NOUN. What a wrench
-- does to it is written down in structures/manual_valve.luau, where the
-- target is the expert.
return {
    id = "manual_valve_fitting",
    name = "manual valve fitting",
    sprite = "manual_valve_loose",
    category = "fittings",
    -- tg's `inhand_icon_state = "buildpipe"` for the whole
    -- /obj/item/pipe family (construction.dm:20) -- one length of pipe
    -- over the shoulder, whichever fitting it is going to become.
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    -- The main this one will stand on, 1..=5, and it is the ENGINE's
    -- dial rather than this file's: `modes` mints it, the dispenser
    -- sets it before it hands the part over (tg's `set_piping_layer`
    -- off the RPD, RPD.dm:569), and `attach_pipe_device` reads it when
    -- the machine stands up. Every `/obj/item/pipe` in tg carries one.
    -- Starting on the distribution run, tg's PIPING_LAYER_DEFAULT
    -- (__DEFINES/atmospherics/atmos_piping.dm:80).
    modes = 5,
    mode = 2,
}
