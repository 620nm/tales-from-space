-- The bit operations a pack may call, pinned on exact results. bit32 and
-- buffer.readbits/writebits are engine stdlib members projected to packs.
-- The refusals are the engine's narrowing contract: a NaN argument throws
-- a string whose first line is "engine.math.narrowing: <lib>.<member>
-- argument <n>" (the engine's docs/luau-api/narrowing.md, Contract 2).

local function first_line(message: string): string
    local newline = string.find(message, "\n", 1, true)
    if newline == nil then
        return message
    end
    return string.sub(message, 1, newline - 1)
end

local function expect_value(actual: number, expected: number, what: string)
    assert(actual == expected, what .. " should be " .. expected .. ", got " .. actual)
end

local function expect_refusal(what: string, expected: string, ok: boolean, refusal: any)
    assert(not ok, what .. " returned a value instead of refusing")
    assert(type(refusal) == "string", what .. " refused with a non-string error")
    local line = first_line(refusal)
    assert(line == expected, what .. " refused with the wrong first line: " .. line)
end

expect_value(bit32.band(0xF0F0, 0x0FF0), 0x00F0, "bit32.band(0xF0F0, 0x0FF0)")
expect_value(bit32.bxor(0xFF00, 0x0FF0), 0xF0F0, "bit32.bxor(0xFF00, 0x0FF0)")
expect_value(bit32.lshift(1, 31), 2147483648, "bit32.lshift(1, 31)")
expect_value(bit32.lshift(0xFFFFFFFF, 4), 0xFFFFFFF0, "bit32.lshift(0xFFFFFFFF, 4)")

-- readbits numbers bits little-endian (lbuflib.cpp buffer_readbits): the
-- bytes 0xAB 0xCD load as the word 0xCDAB, then (0xCDAB >> 4) & 0xFF = 0xDA.
expect_value(
    buffer.readbits(buffer.fromstring("\xAB\xCD"), 4, 8),
    0xDA,
    "buffer.readbits over \\xAB\\xCD at bit 4, width 8"
)

local bits = buffer.create(1)
buffer.writebits(bits, 3, 5, 21)
expect_value(buffer.readbits(bits, 3, 5), 21, "buffer.readbits after writebits(3, 5, 21)")

local band_ok, band_refusal = pcall(bit32.band, 0 / 0, 1)
expect_refusal(
    "bit32.band(NaN, 1)",
    "engine.math.narrowing: bit32.band argument 1",
    band_ok,
    band_refusal
)

local read_ok, read_refusal = pcall(buffer.readbits, buffer.create(1), 0 / 0, 1)
expect_refusal(
    "buffer.readbits(buffer, NaN, 1)",
    "engine.math.narrowing: buffer.readbits argument 2",
    read_ok,
    read_refusal
)
