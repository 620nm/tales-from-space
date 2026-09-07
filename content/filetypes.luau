-- File extensions are pack vocabulary; text/source are native storage formats.
-- PEM text carries no authority; ATMO records are interpreted by the pack UI.
return {
    types = {
        { extension = "md", format = "text", creatable = true },
        { extension = "disl", format = "source", creatable = true },
        { extension = "atmo", format = "text", creatable = true },
        { extension = "pem", format = "text", creatable = true },
    },
}
