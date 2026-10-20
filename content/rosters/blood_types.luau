-- The eight human blood types, in tg's weights order
-- (code/__HELPERS/mobs.dm:14-21). The order is the roster index a
-- `blood_identity` rider's `type` field holds (content/lib/blood_identity.luau);
-- compatibility lives beside it in that lib, it is not data here.
return {
    id = "blood_types",
    entries = {
        "o_minus",
        "o_plus",
        "a_minus",
        "a_plus",
        "b_minus",
        "b_plus",
        "ab_minus",
        "ab_plus",
    },
}
