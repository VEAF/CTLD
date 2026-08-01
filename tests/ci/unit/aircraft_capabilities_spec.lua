---@diagnostic disable
-- tests/ci/unit/aircraft_capabilities_spec.lua
-- FEAT-AIRCRAFT-CAPABILITIES ticket 01 — five stock DCS aircraft had no capabilitiesByType
-- entry, so their pilots lost crates, troops, beacons and smoke. The catalogue is what makes
-- an aircraft a transport (`isTransport = caps ~= nil`), so these specs pin both the entries
-- and the two decisions they encode: one soldier, and no Ka-50.
-- ============================================================

describe("capabilitiesByType — the light transports", function()

    local LIGHT = { "SA342L", "SA342M", "SA342Minigun", "SA342Mistral", "Yak-52" }

    local function caps(typeName)
        return (ctld.gs("capabilitiesByType") or {})[typeName]
    end

    it("carries an entry for every Gazelle variant and the Yak-52", function()
        for _, t in ipairs(LIGHT) do
            assert.is_not_nil(caps(t), "no capabilitiesByType entry for " .. t)
        end
    end)

    it("declares them as troop carriers that cannot take crates", function()
        for _, t in ipairs(LIGHT) do
            local c = caps(t)
            assert.is_true(c.troopsEnabled, t .. " should carry troops")
            assert.is_false(c.cratesEnabled, t .. " should not carry crates")
            assert.equals(0, c.maxCratesOnboard, t .. " crate capacity")
        end
    end)

    it("gives them v1's one-soldier limit", function()
        for _, t in ipairs(LIGHT) do
            assert.equals(1, caps(t).maxTroopsOnboard, t .. " troop limit")
        end
    end)

    it("declares no vehicle transport, no slingload and no parachute drop", function()
        for _, t in ipairs(LIGHT) do
            local c = caps(t)
            assert.is_false(c.canTransportWholeVehicle, t)
            assert.is_false(c.canSlingload, t)
            assert.is_false(c.canParachuteDrop, t)
            assert.is_false(c.useNativeDcsCargoSystem, t)
            assert.is_false(c.convertNativeLoadToCTLD, t)
            assert.equals(0, c.maxWholeVehiclesOnboard, t)
        end
    end)

    it("names no loadable vehicle — nothing to check against the datamine", function()
        for _, t in ipairs(LIGHT) do
            assert.is_nil(caps(t).loadableVehiclesRED, t)
            assert.is_nil(caps(t).loadableVehiclesBLUE, t)
        end
    end)

    it("leaves the Ka-50 out, deliberately", function()
        -- v1 gave it the global troop limit and both actions by falling through two *missing*
        -- table entries. An entry with both transport modes off would only add the beacon
        -- action: recon and JTAC status already work without one.
        assert.is_nil(caps("Ka-50"))
        assert.is_nil(caps("Ka-50_3"))
    end)

    it("makes a Gazelle a transport and the Ka-50 not one", function()
        local pm = setmetatable({}, CTLDPlayerManager)
        local function fakeUnit(typeName)
            return { getTypeName = function() return typeName end }
        end

        local isTransport = pm:_detectCapabilities(fakeUnit("SA342M"))
        assert.is_true(isTransport)

        local kaIsTransport, kaVehicles = pm:_detectCapabilities(fakeUnit("Ka-50"))
        assert.is_false(kaIsTransport)
        assert.is_false(kaVehicles)
    end)

    it("only offers a one-soldier template to a one-soldier aircraft", function()
        -- The embark menu filters templates on `tmpl.total <= limit`, so the limit is a real
        -- gate, not a label: at 1, the stock catalogue offers exactly "Single JTAC".
        local tm    = CTLDTroopManager.getInstance()
        local limit = tm:_transportLimit("SA342M")
        assert.equals(1, limit)

        local fits = {}
        for _, tmpl in ipairs(tm._templates) do
            if tmpl.total <= limit then fits[#fits + 1] = tmpl.name end
        end
        assert.equals(1, #fits)
        assert.equals("Single JTAC", fits[1])
    end)

    it("falls back to numberOfTroops for an aircraft with no entry", function()
        local tm = CTLDTroopManager.getInstance()
        assert.equals(ctld.gs("numberOfTroops"), tm:_transportLimit("Ka-50"))
    end)

end)
