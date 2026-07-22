---@diagnostic disable
-- tests/ci/unit/i18n_startup_report_spec.lua
-- busted specs for i18n audit → ctld.startupReport wiring (BUILD-DICT-AI-TRANSLATE ticket 01).
-- Tests the logic introduced in CTLD_bootstrap.lua: untranslated stubs in the active language
-- produce INFO entries in ctld.startupReport; EN lang and fully-translated dicts produce none.
-- ============================================================

-- Load non-EN dictionaries (idempotent)
local _root = debug.getinfo(1, "S").source:match("^@(.+)tests[\\/]unit[\\/]")
if not _root then _root = "" end
local SRC = _root .. "src/"
dofile(SRC .. "CTLD_i18n_fr.lua")
dofile(SRC .. "CTLD_i18n_es.lua")
dofile(SRC .. "CTLD_i18n_ko.lua")

describe("i18n audit → startupReport wiring", function()

    -- Snapshot originals
    local origGs, origI18nLang

    before_each(function()
        ctld.startupReport._entries = {}
        origGs       = ctld.gs
        origI18nLang = ctld.i18n_lang
    end)

    after_each(function()
        ctld.gs        = origGs
        ctld.i18n_lang = origI18nLang
        ctld.startupReport._entries = {}
    end)

    -- Helper: run the audit block exactly as it appears in ctld.initialize()
    local function runAudit(lang)
        -- Simulate ctld.gs returning the given lang
        ctld.gs = function(key)
            if key == "i18n_lang" then return lang end
            return origGs and origGs(key)
        end
        -- Replicate the bootstrap block
        local ok, fromSetting = pcall(function() return ctld.gs and ctld.gs("i18n_lang") end)
        local activeLang = (ok and fromSetting) or ctld.i18n_lang or "en"
        if activeLang ~= "en" then
            local result = ctld.i18n_audit(activeLang)
            if result then
                local n = #result.untranslated
                if n > 0 then
                    ctld.startupReport.add("INFO", "i18n",
                        string.format("%d untranslated key(s) in '%s' — rebuild to translate", n, activeLang))
                end
            end
        end
    end

    -- ── EN lang: no entries ───────────────────────────────────
    it("active lang 'en' → no startupReport entries", function()
        runAudit("en")
        assert.equals(0, #ctld.startupReport._entries)
    end)

    -- ── Non-EN with untranslated stubs → INFO entry ───────────
    it("active lang 'fr' with untranslated stubs → one INFO entry", function()
        -- Inject a synthetic stub: same value as EN (the stub pattern)
        local enKey  = "CTLD"   -- always exists in EN
        local enVal  = ctld.i18n["en"][enKey]
        local origFr = ctld.i18n["fr"][enKey]
        ctld.i18n["fr"][enKey] = enVal  -- simulate an untranslated stub

        runAudit("fr")

        -- Restore
        ctld.i18n["fr"][enKey] = origFr

        local entries = ctld.startupReport._entries
        assert.equals(1, #entries)
        assert.equals("INFO",  entries[1].severity)
        assert.equals("i18n",  entries[1].source)
        assert.is_true(entries[1].message:find("untranslated", 1, true) ~= nil)
        assert.is_true(entries[1].message:find("fr",           1, true) ~= nil)
    end)

    -- ── Non-EN fully translated: no entries ───────────────────
    it("active lang 'fr' fully translated → no startupReport entries", function()
        -- Force all FR values to differ from EN (i.e. remove all stubs)
        local patched = {}
        for key, enVal in pairs(ctld.i18n["en"]) do
            if key ~= "translation_version" and ctld.i18n["fr"][key] == enVal then
                ctld.i18n["fr"][key] = enVal .. "_TR"
                patched[#patched + 1] = key
            end
        end

        runAudit("fr")

        -- Restore
        for _, key in ipairs(patched) do
            ctld.i18n["fr"][key] = ctld.i18n["en"][key]
        end

        assert.equals(0, #ctld.startupReport._entries)
    end)

end)
