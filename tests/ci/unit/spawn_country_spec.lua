---@diagnostic disable
-- FIX-SPAWN-COUNTRY-FALLBACK: an object CTLD creates goes under a country of its coalition, and a failed creation is
-- visible. In a VEAF campaign mission the blue coalition holds only CJTF Blue and the red only CJTF Red: USA and Russia,
-- the old hardcoded defaults, are in no coalition, and DCS refuses an object created under them.
-- ============================================================

local CJTF_BLUE, CJTF_RED = 80, 81

-- A mission whose coalitions hold the given countries ({ [countryId] = side }); every other country is in none.
local function missionWith(sides)
    coalition.getCountryCoalition = function(cId) return sides[cId] or coalition.side.NEUTRAL end
end

-- DCS refuses an object under a country that is in no coalition: addStaticObject / addGroup raise.
local function refuseOutsideCoalitions()
    coalition.addStaticObject = function(cId, data)
        if coalition.getCountryCoalition(cId) == coalition.side.NEUTRAL then error("country " .. cId .. " not in a coalition") end
        return { getName = function() return data.name end }
    end
end

local saved = {}
local function save(tbl, key, label) saved[#saved + 1] = { tbl, key, tbl[key], label } end

local function setupMission()
    saved = {}
    save(coalition, "getCountryCoalition")
    save(coalition, "addStaticObject")
    save(coalition, "addGroup")
    save(country.id, "CJTF_BLUE")
    save(country.id, "CJTF_RED")
    save(country.name, CJTF_BLUE)
    save(country.name, CJTF_RED)
    country.id.CJTF_BLUE, country.id.CJTF_RED = CJTF_BLUE, CJTF_RED
    country.name[CJTF_BLUE], country.name[CJTF_RED] = "CJTF_BLUE", "CJTF_RED"
end

local function restoreMission()
    for i = #saved, 1, -1 do
        local s = saved[i]
        s[1][s[2]] = s[3]
    end
end

local function liveUnit(countryId)
    return { isExist = function() return true end, getCountry = function() return countryId end }
end

-- ─────────────────────────────────────────────────────────────
describe("ctld.utils.resolveCountryId", function()

    before_each(setupMission)
    after_each(restoreMission)

    it("takes the country of a live unit first", function()
        missionWith({ [CJTF_BLUE] = coalition.side.BLUE })
        assert.equals(country.id.UKRAINE, ctld.utils.resolveCountryId(coalition.side.BLUE, liveUnit(country.id.UKRAINE)))
    end)

    it("without a unit, takes a country the coalition holds, not USA", function()
        missionWith({ [CJTF_BLUE] = coalition.side.BLUE, [CJTF_RED] = coalition.side.RED })
        assert.equals(CJTF_BLUE, ctld.utils.resolveCountryId(coalition.side.BLUE))
        assert.equals(CJTF_RED,  ctld.utils.resolveCountryId(coalition.side.RED))
    end)

    it("among several countries of the coalition, takes the lowest id", function()
        missionWith({ [CJTF_BLUE] = coalition.side.BLUE, [country.id.FRANCE] = coalition.side.BLUE })
        assert.equals(country.id.FRANCE, ctld.utils.resolveCountryId(coalition.side.BLUE))
    end)

    it("skips a unit that no longer exists", function()
        missionWith({ [CJTF_BLUE] = coalition.side.BLUE })
        local gone = { isExist = function() return false end, getCountry = function() return country.id.USA end }
        assert.equals(CJTF_BLUE, ctld.utils.resolveCountryId(coalition.side.BLUE, gone))
    end)

    it("falls back to USA for blue and Russia for red when the coalition holds no country", function()
        missionWith({})
        assert.equals(country.id.USA,    ctld.utils.resolveCountryId(coalition.side.BLUE))
        assert.equals(country.id.RUSSIA, ctld.utils.resolveCountryId(coalition.side.RED))
    end)

    it("falls back to USA / Russia when coalition.getCountryCoalition is unavailable", function()
        coalition.getCountryCoalition = nil
        assert.equals(country.id.USA,    ctld.utils.resolveCountryId(coalition.side.BLUE))
        assert.equals(country.id.RUSSIA, ctld.utils.resolveCountryId(coalition.side.RED))
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("a crate created in a mission whose coalitions hold only CJTF Blue / CJTF Red", function()

    local cm, origGetByName, origLog, logs, created

    before_each(function()
        setupMission()
        missionWith({ [CJTF_BLUE] = coalition.side.BLUE, [CJTF_RED] = coalition.side.RED })
        refuseOutsideCoalitions()
        created = {}
        local refuse = coalition.addStaticObject
        coalition.addStaticObject = function(cId, data)
            local obj = refuse(cId, data)
            created[data.name] = cId
            return obj
        end
        origGetByName = StaticObject.getByName
        StaticObject.getByName = function(name) return created[name] and { _name = name } or nil end
        origLog, logs = ctld.utils.log, {}
        ctld.utils.log = function(level, fmt, ...)
            logs[#logs + 1] = { level = level, text = select("#", ...) > 0 and string.format(fmt, ...) or fmt }
        end
        cm = CTLDCrateManager.getInstance()
        cm.crates = {}
    end)

    after_each(function()
        StaticObject.getByName = origGetByName
        ctld.utils.log = origLog
        cm.crates = {}
        restoreMission()
    end)

    local function descriptor() return cm:findDescriptorByUnitType("M1043 HMMWV Armament") end

    it("without a country goes under the coalition's country (blue)", function()
        local crate = cm:spawnCrate(descriptor(), { x = 0, y = 0, z = 0 }, coalition.side.BLUE, nil, "crate_spawn")
        assert.is_not_nil(crate)
        assert.equals(CJTF_BLUE, created[crate.crateName])
    end)

    it("without a country goes under the coalition's country (red)", function()
        local crate = cm:spawnCrate(descriptor(), { x = 0, y = 0, z = 0 }, coalition.side.RED, nil, "crate_spawn")
        assert.is_not_nil(crate)
        assert.equals(CJTF_RED, created[crate.crateName])
    end)

    it("that DCS refuses returns nil and logs a WARNING naming the DCS error and the country", function()
        local crate = cm:spawnCrate(descriptor(), { x = 0, y = 0, z = 0 }, coalition.side.BLUE, nil, "crate_spawn",
            country.id.USA)
        assert.is_nil(crate)
        local found
        for _, l in ipairs(logs) do
            if l.level == "WARNING" and l.text:find("not in a coalition", 1, true)
                and l.text:find("country=" .. country.id.USA, 1, true) then found = true end
        end
        assert.is_true(found)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("ctld.utils.dynAddStatic", function()

    before_each(setupMission)
    after_each(restoreMission)

    it("returns false and the DCS error when DCS refuses the static", function()
        missionWith({ [CJTF_BLUE] = coalition.side.BLUE })
        refuseOutsideCoalitions()
        local ok, err = ctld.utils.dynAddStatic("test", {
            name = "s1", x = 0, y = 0, type = "ammo_cargo", country = country.id.USA, mass = 100 })
        assert.is_false(ok)
        assert.is_truthy(tostring(err):find("not in a coalition", 1, true))
    end)

    it("returns the object data when DCS creates the static (control)", function()
        missionWith({ [CJTF_BLUE] = coalition.side.BLUE })
        refuseOutsideCoalitions()
        local obj = ctld.utils.dynAddStatic("test", {
            name = "s2", x = 0, y = 0, type = "ammo_cargo", country = CJTF_BLUE, mass = 100 })
        assert.equals("s2", obj.name)
    end)

end)

-- ─────────────────────────────────────────────────────────────
describe("CTLDCrateManager:_spawnUnpacked whose group DCS refuses", function()

    local pm, origOutText, messages, origLog

    before_each(function()
        setupMission()
        missionWith({ [CJTF_BLUE] = coalition.side.BLUE })
        coalition.addGroup = function(cId) error("country " .. cId .. " not in a coalition") end
        origOutText, messages = trigger.action.outTextForGroup, {}
        trigger.action.outTextForGroup = function(gid, text) messages[#messages + 1] = { gid = gid, text = text } end
        origLog = ctld.utils.log
        ctld.utils.log = function() end
        pm = CTLDPlayerManager.getInstance()
        pm._players["unpacker"] = { groupId = 4242, unitName = "unpacker" }
    end)

    after_each(function()
        pm._players["unpacker"] = nil
        trigger.action.outTextForGroup = origOutText
        ctld.utils.log = origLog
        restoreMission()
    end)

    it("returns false and tells the unpacking group", function()
        local desc = { unit = "M1043 HMMWV Armament", spawnAs = "GROUND" }
        local ok = CTLDCrateManager.getInstance():_spawnUnpacked(desc, { x = 0, y = 0, z = 0 },
            coalition.side.BLUE, country.id.USA, "unpacker")
        assert.is_false(ok)
        assert.equals(1, #messages)
        assert.equals(4242, messages[1].gid)
        assert.equals(ctld.tr("Unpack failed: the equipment could not be created."), messages[1].text)
    end)

end)
