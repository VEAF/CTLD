-- Minimal dkjson.decode replacement (Lua 5.1) for the local mini-busted runner.
-- Only what tests/ci/unit/config_spec.lua needs: decode(text) -> table, pos, err.
-- The real dkjson is a CI dependency; this stands in so the oracle round-trip spec —
-- the one that catches a config YAML added without regenerating config_defaults.json —
-- can run locally too.

local M = {}

local function skipWs(s, i)
    local _, j = s:find("^[ \t\r\n]*", i)
    return j + 1
end

local decodeValue

local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f",
                  n = "\n", r = "\r", t = "\t" }

local function decodeString(s, i)
    local out = {}
    i = i + 1                     -- skip opening quote
    while true do
        local c = s:sub(i, i)
        if c == "" then error("unterminated string at " .. i) end
        if c == '"' then return table.concat(out), i + 1 end
        if c == "\\" then
            local e = s:sub(i + 1, i + 1)
            if e == "u" then
                local hex = s:sub(i + 2, i + 5)
                local cp  = tonumber(hex, 16) or 63
                -- Enough for the BMP characters an accented config default can hold.
                if cp < 0x80 then
                    out[#out + 1] = string.char(cp)
                elseif cp < 0x800 then
                    out[#out + 1] = string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
                else
                    out[#out + 1] = string.char(0xE0 + math.floor(cp / 0x1000),
                                                0x80 + math.floor(cp / 0x40) % 0x40,
                                                0x80 + cp % 0x40)
                end
                i = i + 6
            else
                out[#out + 1] = ESCAPES[e] or e
                i = i + 2
            end
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
end

local function decodeNumber(s, i)
    local j = s:find("[^%-%+%.eE0-9]", i) or (#s + 1)
    local n = tonumber(s:sub(i, j - 1))
    if not n then error("bad number at " .. i) end
    return n, j
end

local function decodeArray(s, i)
    local arr = {}
    i = skipWs(s, i + 1)
    if s:sub(i, i) == "]" then return arr, i + 1 end
    while true do
        local v
        v, i = decodeValue(s, i)
        arr[#arr + 1] = v
        i = skipWs(s, i)
        local c = s:sub(i, i)
        if c == "]" then return arr, i + 1 end
        if c ~= "," then error("expected , or ] at " .. i) end
        i = skipWs(s, i + 1)
    end
end

local function decodeObject(s, i)
    local obj = {}
    i = skipWs(s, i + 1)
    if s:sub(i, i) == "}" then return obj, i + 1 end
    while true do
        local k, v
        k, i = decodeString(s, skipWs(s, i))
        i = skipWs(s, i)
        if s:sub(i, i) ~= ":" then error("expected : at " .. i) end
        v, i = decodeValue(s, skipWs(s, i + 1))
        obj[k] = v
        i = skipWs(s, i)
        local c = s:sub(i, i)
        if c == "}" then return obj, i + 1 end
        if c ~= "," then error("expected , or } at " .. i) end
        i = skipWs(s, i + 1)
    end
end

decodeValue = function(s, i)
    i = skipWs(s, i)
    local c = s:sub(i, i)
    if c == "{" then return decodeObject(s, i) end
    if c == "[" then return decodeArray(s, i) end
    if c == '"' then return decodeString(s, i) end
    if s:sub(i, i + 3) == "true"  then return true,  i + 4 end
    if s:sub(i, i + 4) == "false" then return false, i + 5 end
    if s:sub(i, i + 3) == "null"  then return nil,   i + 4 end
    return decodeNumber(s, i)
end

function M.decode(text)
    local ok, value, pos = pcall(decodeValue, text, 1)
    if not ok then return nil, 1, tostring(value) end
    return value, pos
end

return M
