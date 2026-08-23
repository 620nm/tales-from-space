-- Take an organ out (tg operation_organ_manip.dm): it lands on the
-- patient's tile. The chest organs and the brain need the bone sawed
-- first, which the socket enforces.
return {
    id = "remove_organ", name = "remove an organ",
    organ = "remove",
    requires = { "skin_open", "organs_cut" },
    time = 1,
    implements = {
        { tool = "hemostat", mult = 1 },
        { tool = "crowbar", mult = 1.8 },
    },
}
