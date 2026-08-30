-- The operating computer: what the bodies laid out around it are doing.
--
-- tg: `/obj/machinery/computer/operating`
-- (code/game/machinery/computer/operating_computer.dm:4-9). Its picture
-- is the generic console frame with the crew screen and the medical
-- keyboard over it -- `icon_state = "computer"`, `icon_screen = "crew"`,
-- `icon_keyboard = "med_key"` -- which the atlas composites into one
-- cell (assets/sprites/46-surgery-tools.ron).
--
-- tg's console finds ONE operating table over `alldirs` at range 1 and
-- watches that table's patient (:96-101). The engine's `procedures` module
-- reads the four tiles the machine faces and every body standing on one
-- of them, which needs no table to exist and means a triage line on the
-- deck reads as well as a theatre does. What it draws is native state
-- throughout -- vitals, blood, the parts that are open, and what each
-- open part admits next -- so this file spends no script on it.
--
-- No disks and no techweb (tg's :66-91, surgery_disks.dm): there is no
-- research in this game, so `content/operations/` IS the catalog.
--
-- Corded because tg's is powered and a console with no mains is a dark
-- screen (tg closes the window outright on `!is_operational`, :112-114).
return {
    id = "operating_computer",
    name = "operating computer",
    sprite = "operating_computer",
    dense = true,
    corded = true,
    -- One module and one gesture: walk up to it and it opens. There is
    -- nothing else this machine does, and no hand it wants.
    ui = { modules = { "procedures" }, opens_on_click = true },
}
