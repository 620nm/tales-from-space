export type PackLabel = {
    keyed: {
        reference: { pack: string },
        args: {},
    },
}

local ui_label = {}

function ui_label.pack(key: string): PackLabel
    return {
        keyed = {
            reference = { pack = key },
            args = {},
        },
    }
end

return ui_label
