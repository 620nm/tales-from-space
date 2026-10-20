-- Blood identity: which of tg's eight human types a parcel of blood
-- is. Data only -- this roster never runs as a script -- so the one
-- meet dispatcher lives in `lib/blood_identity.luau` and is registered
-- from the blood substance file, the carrier it rides.
return {
    id = "blood_identity",
    carriers = { "blood" },
    fields = {
        type = { kind = "ref", roster = "blood_types" },
    },
}
