---@diagnostic disable
-- tests/ci/unit/retired_settings_spec.lua
-- FIX-DROPOFFZONES-PARITY ticket 02 — a v1 config's `dropOffZones` is read by nothing in src/,
-- so an AI transport that used to auto-unload there simply stops. Nothing catches it today:
-- `validate` does not report unknown keys, and a hand-written mission config never meets
-- ctld-tools. One startup NOTICE is the only signal its author gets.
-- ============================================================

describe("CTLDConfig:reportRetiredSettings", function()

    local cfg, savedSettings

    local function notices()
        local out = {}
        for _, e in ipairs(ctld.startupReport._entries) do
            if e.severity == "NOTICE" then out[#out + 1] = e end
        end
        return out
    end

    before_each(function()
        cfg = CTLDConfig.get()
        savedSettings = cfg.settings["dropOffZones"]
        cfg.settings["dropOffZones"] = nil
        ctld.startupReport._entries = {}
    end)

    after_each(function()
        cfg.settings["dropOffZones"] = savedSettings
        ctld.startupReport._entries = {}
    end)

    it("reports a snapshot carrying dropOffZones exactly once", function()
        cfg.settings["dropOffZones"] = {
            { "dropzone1", "green", 2 },
            { "dropzone2", "red",   1 },
        }

        cfg:reportRetiredSettings()

        local n = notices()
        assert.equals(1, #n)
        assert.equals("config", n[1].source)
    end)

    it("says what to do, not only what happened", function()
        cfg.settings["dropOffZones"] = { { "dropzone1", "green", 2 } }

        cfg:reportRetiredSettings()

        local msg = notices()[1].message
        assert.is_not_nil(msg:find("dropOffZones", 1, true))
        assert.is_not_nil(msg:find("aiZones", 1, true))
        assert.is_not_nil(msg:find("isDropoff", 1, true))
    end)

    it("names the key once, not once per zone", function()
        local zones = {}
        for i = 1, 10 do zones[i] = { "dropzone" .. i, "green", 2 } end
        cfg.settings["dropOffZones"] = zones

        cfg:reportRetiredSettings()

        assert.equals(1, #notices())
    end)

    it("stays silent on a snapshot that does not carry the key", function()
        cfg:reportRetiredSettings()
        assert.equals(0, #notices())
    end)

    it("stays silent on an empty table — the key is absent, not empty, when a config drops it", function()
        cfg.settings["dropOffZones"] = nil
        cfg:reportRetiredSettings()
        assert.equals(0, #notices())
    end)

    it("resolves the message through ctld.tr in both languages", function()
        local key = "dropOffZones is not read by CTLD 2 — declare each AI drop-off point as an aiZones entry with isDropoff: true"
        local saved = ctld.i18n_lang

        ctld.i18n_lang = "en"
        local en = ctld.tr(key)
        ctld.i18n_lang = "fr"
        local fr = ctld.tr(key)
        ctld.i18n_lang = saved

        assert.equals("string", type(en))
        assert.equals("string", type(fr))
        assert.is_true(#en > 0 and #fr > 0)
    end)

end)
