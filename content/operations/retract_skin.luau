-- Hold the incision open (tg operation_generic.dm:101-139).
return {
    id = "retract_skin", name = "retract the skin",
    requires = { "skin_cut" }, sets = { "skin_open" }, clears = { "skin_cut" },
    time = 2.4,
    implements = {
        { tool = "retractor", mult = 1 },
        { tool = "screwdriver", mult = 2.25 },
        { tool = "cutters", mult = 2.85 },       -- wirecutters/rods/fork
    },
}
