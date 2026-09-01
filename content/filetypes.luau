-- What kinds of file this station's computers know how to hold.
--
-- The word is ours and the FORMAT is the engine's: `text` is prose a
-- crewman types and `source` is program text, and the store never
-- interprets either (docs/CONTENT-SCHEMA.md 1.10d). Two words is the
-- whole roster because two is what a crewman can make -- a note and a
-- program -- and a station that recognised a dozen extensions nothing
-- writes would be a drop-down full of promises.
--
-- `creatable` is not a lock. It decides one thing: whether a panel's
-- new-file control offers that word. Anything already on a disk is
-- copied, renamed and edited whatever it says after the dot, which is
-- what makes a disk somebody else wrote worth finding.
return {
    types = {
        -- The memo, the shift log, the note left on the drive for
        -- whoever comes on next.
        { extension = "doc", format = "text", creatable = true },
        -- Program text. Nothing on this station runs one yet; a disk
        -- of them is still the thing you carry to the machine that
        -- will (docs/DIEGETIC_SCRIPTING.md).
        { extension = "disl", format = "source", creatable = true },
    },
}
