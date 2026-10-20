---@diagnostic disable
-- FIX-I18N-TRANSLATE-ALIAS: every text written as a literal in src/ through ctld.tr, or through its alias ctld.i18n_translate, is a key of
-- the English dictionary. The dictionary generator, the i18n-guard job and the pre-push hook all scan the source for these calls; this spec
-- holds the same invariant from the Lua side, so a key written through a name the scan does not know cannot go unnoticed.
-- ============================================================

local _root = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]unit[\\/]")
if not _root then _root = "" end  -- relative path: cwd is repo root
local SRC = _root .. "src"

local function listSources()
    local windows = package.config:sub(1, 1) == "\\"
    local cmd = windows and ('dir /s /b "' .. SRC:gsub("/", "\\") .. '\\*.lua" 2>nul')
                         or ('find "' .. SRC .. '" -name "*.lua" 2>/dev/null')
    local files = {}
    local p = io.popen(cmd)
    for line in p:lines() do
        local name = line:match("([^\\/]+)$")
        -- the dictionaries and the translation module itself only hold or define keys, they do not use them
        if name and not name:match("^CTLD_i18n") then files[#files + 1] = line end
    end
    p:close()
    return files
end

-- Literals passed as the first argument of ctld.tr( or ctld.i18n_translate(, as the generator reads them.
local function literalKeys(content)
    local keys = {}
    for _, name in ipairs({ "ctld%.tr", "ctld%.i18n_translate" }) do
        local from = 1
        while true do
            local _, e = content:find(name .. "%s*%(%s*\"", from)
            if not e then break end
            local i = e + 1
            while i <= #content do
                local c = content:sub(i, i)
                if c == "\\" then i = i + 2
                elseif c == '"' then break
                else i = i + 1 end
            end
            keys[#keys + 1] = content:sub(e + 1, i - 1)
            from = i + 1
        end
    end
    return keys
end

describe("the literal keys used in src/", function()

    it("are all keys of the English dictionary", function()
        local missing, seen, count = {}, {}, 0
        for _, path in ipairs(listSources()) do
            local f = io.open(path, "rb")
            local content = f:read("*a")
            f:close()
            for _, raw in ipairs(literalKeys(content)) do
                local chunk = loadstring('return "' .. raw .. '"')
                local key = chunk and chunk() or raw
                count = count + 1
                if ctld.i18n["en"][key] == nil and not seen[key] then
                    seen[key] = true
                    missing[#missing + 1] = key .. "   (" .. path:match("([^\\/]+)$") .. ")"
                end
            end
        end
        assert.is_true(count > 100, "the scan found only " .. count .. " literal keys: it is not looking at src/")
        table.sort(missing)
        assert.same({}, missing)
    end)
end)
