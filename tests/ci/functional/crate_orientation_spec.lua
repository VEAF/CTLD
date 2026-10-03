---@diagnostic disable
-- FIX-CRATE-ORIENTATION: a crate created for an aircraft takes the aircraft's heading, so it stands parallel to it.
-- Crates with no aircraft keep heading zero. Driven with a double of an aircraft at a known heading and of the DCS
-- static creation: only the heading handed to DCS (and stored in the crate) is asserted.
-- ============================================================

describe("crates take the heading of the aircraft that spawned or dropped them", function()

    local cm, transport, created
    local origDyn, origGetStatic, origRandom, origGs, origInAir
    local HDG = math.pi / 2          -- aircraft nose to +z (east): atan2(x.z, x.x) = pi/2
    local CX, CZ = 1000, 2000

    local function makeTransport(typeName, hasPosition)
        local t = {
            getName      = function() return "nc_player" end,
            getTypeName  = function() return typeName end,
            isExist      = function() return true end,
            getCoalition = function() return coalition.side.BLUE end,
            getCountry   = function() return country.id.USA end,
            getPoint     = function() return { x = CX, y = 0, z = CZ } end,
            getDesc      = function() return { box = { min = { x = -8, y = -1.6, z = -1.6 }, max = { x = 4, y = 1.6, z = 1.6 } } } end,
        }
        t.getPosition = function()
            if hasPosition == false then return nil end   -- DCS gave no orientation for this unit
            return { p = { x = CX, y = 0, z = CZ }, x = { x = 0, y = 0, z = 1 },
                     y = { x = 0, y = 1, z = 0 }, z = { x = -1, y = 0, z = 0 } }
        end
        return t
    end

    local function descriptors(n)
        local list = {}
        for i = 1, n do list[i] = { desc = "crate " .. i, unit = "Hummer", weight = 500 } end
        return list
    end

    before_each(function()
        CTLDCrateManager._instance = nil
        CTLDPlayerManager._instance = nil
        cm = CTLDCrateManager.getInstance()
        created = {}
        cm._getDynamicBBoxes = function() return {} end
        origDyn, origGetStatic = ctld.utils.dynAddStatic, StaticObject.getByName
        origRandom, origGs, origInAir = ctld.utils.RandomReal, ctld.gs, ctld.utils.inAir
        ctld.utils.dynAddStatic = function(_, data) created[#created + 1] = data end
        StaticObject.getByName = function(name)
            return { getName = function() return name end, isExist = function() return true end,
                     getPoint = function() return { x = 0, y = 0, z = 0 } end, destroy = function() end }
        end
        ctld.utils.RandomReal = function() return 0.1 end
        ctld.utils.inAir = function() return false end
        ctld.gs = function(k)
            if k == "capabilitiesByType" then
                return { ["UH-1H"] = { cratesEnabled = true, crateSpawnSector = "side", crateSpawnDistance = 3.0 },
                         ["Plain"] = { cratesEnabled = true } }
            end
            return origGs(k)
        end
        transport = makeTransport("UH-1H")
        Unit.getByName = function(n) if n == "nc_player" then return transport end end
    end)

    after_each(function()
        ctld.utils.dynAddStatic, StaticObject.getByName = origDyn, origGetStatic
        ctld.utils.RandomReal, ctld.gs, ctld.utils.inAir = origRandom, origGs, origInAir
        CTLDCrateManager._instance = nil
        CTLDPlayerManager._instance = nil
    end)

    it("a requested wave beside an aircraft that declares a spawn plan stands at the aircraft's heading", function()
        cm:spawnCratesAligned(descriptors(3), transport, coalition.side.BLUE, "nc_player", CTLDCrate.SPAWN_METHOD.MENU_CTLD)
        assert.equals(3, #created)
        for _, data in ipairs(created) do assert.is_near(HDG, data.heading, 0.001) end
    end)

    it("a wave for a type with no plan (radial rule) stands at the aircraft's heading", function()
        transport = makeTransport("Plain")
        cm:spawnCratesAligned(descriptors(2), transport, coalition.side.BLUE, "nc_player", CTLDCrate.SPAWN_METHOD.MENU_CTLD)
        assert.equals(2, #created)
        for _, data in ipairs(created) do assert.is_near(HDG, data.heading, 0.001) end
    end)

    it("the crates produced by packing a vehicle take the aircraft's heading too", function()
        cm:spawnCratesAligned(descriptors(2), transport, coalition.side.BLUE, "nc_player", CTLDCrate.SPAWN_METHOD.VEHICLE_PACK)
        for _, data in ipairs(created) do assert.is_near(HDG, data.heading, 0.001) end
    end)

    it("the crate record carries the heading it was created with", function()
        cm:spawnCratesAligned(descriptors(1), transport, coalition.side.BLUE, "nc_player", CTLDCrate.SPAWN_METHOD.MENU_CTLD)
        local crate = next(cm.crates) and cm.crates[next(cm.crates)]
        assert.is_near(HDG, crate.heading, 0.001)
    end)

    it("a crate dropped from the aircraft is re-created at the aircraft's heading", function()
        cm:spawnCratesAligned(descriptors(1), transport, coalition.side.BLUE, "nc_player", CTLDCrate.SPAWN_METHOD.MENU_CTLD)
        local name = next(cm.crates)
        local crate = cm.crates[name]
        crate:load(transport)
        created = {}

        cm:unloadCrate(name, { x = CX + 3, y = 0, z = CZ }, "menu_ctld")

        assert.equals(1, #created)
        assert.is_near(HDG, created[1].heading, 0.001)
        assert.is_near(HDG, crate.heading, 0.001)
    end)

    it("a crate created with no aircraft keeps heading zero", function()
        cm:spawnCrate({ desc = "crate", unit = "Hummer", weight = 500 }, { x = 1, y = 0, z = 2 }, coalition.side.BLUE, nil,
            CTLDCrate.SPAWN_METHOD.MISSION_MAKER)
        assert.equals(1, #created)
        assert.equals(0, created[1].heading)
    end)

    it("an aircraft whose heading cannot be read gives heading zero, not an error", function()
        transport = makeTransport("UH-1H", false)
        assert.has_no.errors(function()
            cm:spawnCratesAligned(descriptors(1), transport, coalition.side.BLUE, "nc_player", CTLDCrate.SPAWN_METHOD.MENU_CTLD)
        end)
        for _, data in ipairs(created) do assert.equals(0, data.heading) end
    end)

end)
