---@diagnostic disable
-- FIX-CRATE-DROP-PLACEMENT ticket 01: Drop Crate(s) places the crates by the same rule as Request Equipment
-- (ADR 0024): in a row at the declared distance for a type that declares a crate spawn plan, with the
-- other-side anti-collision; the radial rule, now with its anti-collision, for a type that does not.
-- Driven through the F10 Drop Crate(s) callback with doubles of the aircraft; only positions are asserted.
-- ============================================================

local function resetAll()
    CTLDPlayerManager._instance  = nil
    ctld.MenuManager._instance   = nil
    EventDispatcher._instance    = nil
    CTLDDCSEventBridge._instance = nil
    CTLDZoneManager._instance    = nil
    CTLDTroopManager._instance   = nil
    CTLDVehicleSpawner._instance = nil
    CTLDCrateManager._instance   = nil
    _cmInstance                  = nil
    CTLDBeaconManager._instance  = nil
    CTLDReconManager._instance   = nil
    CTLDJTACManager._instance    = nil
end

describe("Drop Crate(s) placement (shared with Request Equipment)", function()

    local cm, transport, dropped, avoid, avoidSeen
    local origGs, origGetByName, origInAir, origRandom, origGetHeight, origGroupId, origOutText
    local origPositions, origInside
    local caps, extraDrop, models
    local CX, CZ = 1000, 2000   -- aircraft position (heading 0: nose to +x, right side to +z)
    local UH1H_BOX = { min = { x = -8.86, y = -1.63, z = -1.59 }, max = { x = 3.95, y = 1.59, z = 1.56 } }

    local function lateral(p) return p.z - CZ end    -- + = right of the aircraft
    local function ahead(p)   return p.x - CX end    -- + = in front of the nose

    local function makeTransport(typeName)
        return {
            getName      = function() return "UH-1H-1" end,
            getTypeName  = function() return typeName end,
            isExist      = function() return true end,
            getCoalition = function() return coalition.side.BLUE end,
            getPoint     = function() return { x = CX, y = 0, z = CZ } end,
            getPosition  = function()
                return { p = { x = CX, y = 0, z = CZ }, x = { x = 1, y = 0, z = 0 },
                         y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
            end,
            getDesc      = function() return { box = UH1H_BOX } end,
        }
    end

    local function addCrate(name, modelKey)
        local crate = CTLDCrate:new({
            crateName   = name,
            descriptor  = { desc = "Ammo", unit = "Ammo_Crate", weight = 500, cratesRequired = 1 },
            spawnMethod = CTLDCrate.SPAWN_METHOD.CRATE_SPAWN,
            position    = { x = 0, y = 0, z = 0 },
            coalition   = 2,
            heading     = 0,
            modelKey    = modelKey,
        })
        crate:load(transport)
        cm.crates[name] = crate
        return crate
    end

    local function buildMenu()
        CTLDCrateManager.getInstance()
        ctld.gs = function(k)
            if k == "capabilitiesByType" then return { ["UH-1H"] = caps } end
            if k == "crateDropExtraDistance" then return extraDrop end
            if k == "spawnableCratesModels" then return models end
            if k == "loadCrateFromMenu" or k == "enableSmokeDrop" or k == "enabledFOBBuilding"
               or k == "enablePackingVehicles" or k == "enabledRadioBeaconDrop" or k == "reconF10Menu"
               or k == "JTAC_jtacStatusF10" or k == "JTAC_dropEnabled" then return false end
            if k == "ctldCrateDescriptors" then return {} end
            if k == "enableParachuteDrop" then return false end
            return origGs(k)
        end
        local playerObj = {
            unitName = "UH-1H-1", groupId = 9901, groupName = "Grp_test", coalition = 2,
            typeName = "UH-1H", isTransport = true, canCarryVehicles = false,
        }
        CTLDPlayerManager.getInstance():buildMenu(playerObj)
        return ctld.MenuManager:getInstance():getMenuByGroupId(9901)
    end

    local function drop(menu)
        local node = menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Crate Commands"), ctld.tr("Drop Crate(s)") })
        node.functionToCall({ unitName = "UH-1H-1" })
    end

    before_each(function()
        resetAll()
        origGs, origGetByName, origInAir = ctld.gs, Unit.getByName, ctld.utils.inAir
        origRandom, origGetHeight = ctld.utils.RandomReal, land.getHeight
        origGroupId, origOutText = ctld.utils.getGroupId, trigger.action.outTextForGroup
        origPositions, origInside = ctld.utils.getSpawnObjectPositions, ctld.utils.positionsInsideAnyBBox

        caps      = { cratesEnabled = true, crateSpawnSector = "side", crateSpawnDistance = 3.0 }
        extraDrop = 0
        models    = nil
        dropped, avoid, avoidSeen = {}, {}, nil

        transport = makeTransport("UH-1H")
        Unit.getByName = function(n) if n == "UH-1H-1" then return transport end end
        ctld.utils.inAir = function() return false end
        ctld.utils.getGroupId = function() return 9901 end
        ctld.utils.RandomReal = function() return 0.1 end        -- the right side, whatever the range
        land.getHeight = function() return 0 end
        trigger.action.outTextForGroup = function() end
        ctld.utils.getSpawnObjectPositions = function(unit, n, dist, spacing, axis, avoidList)
            avoidSeen = avoidList
            return origPositions(unit, n, dist, spacing, axis, avoidList)
        end

        cm = CTLDCrateManager.getInstance()
        cm._getDynamicBBoxes = function() return avoid end
        cm.unloadCrate = function(_, name, pos) dropped[name] = pos end
    end)

    after_each(function()
        ctld.gs, Unit.getByName, ctld.utils.inAir = origGs, origGetByName, origInAir
        ctld.utils.RandomReal, land.getHeight = origRandom, origGetHeight
        ctld.utils.getGroupId, trigger.action.outTextForGroup = origGroupId, origOutText
        ctld.utils.getSpawnObjectPositions, ctld.utils.positionsInsideAnyBBox = origPositions, origInside
        CTLDCrateManager._instance = nil
        CTLDPlayerManager._instance = nil
    end)

    describe("a type that declares a crate spawn plan (UH-1H: side, 3.0 m)", function()

        it("puts a dropped crate at the declared distance, abeam — not on the radial rule", function()
            local menu = buildMenu()
            addCrate("c1", "dynamic")
            drop(menu)
            assert.is_near(3.0, math.abs(lateral(dropped.c1)), 0.01)
            assert.is_near(0, ahead(dropped.c1), 0.01)
        end)

        it("stands several dropped crates in a row, all at the same lateral distance, centred", function()
            local menu = buildMenu()
            for i = 1, 3 do addCrate("c" .. i, "dynamic") end
            drop(menu)
            local xs = {}
            for i = 1, 3 do
                assert.is_near(3.0, math.abs(lateral(dropped["c" .. i])), 0.01)
                xs[#xs + 1] = ahead(dropped["c" .. i])
            end
            table.sort(xs)
            assert.is_near(0, (xs[1] + xs[#xs]) / 2, 0.01)
            assert.is_near(cm:getCrateSize("dynamic") + 0.5, xs[2] - xs[1], 0.01)   -- crate size + default gap 0.5
        end)

        it("spaces each pair of neighbours by the sizes of the two crates concerned", function()
            models = { small = { size = 1.0 }, big = { size = 3.0 } }
            local menu = buildMenu()
            addCrate("a", "small")
            addCrate("b", "big")
            drop(menu)
            local d = math.abs(ahead(dropped.a) - ahead(dropped.b))
            assert.is_near(1.0 / 2 + 0.5 + 3.0 / 2, d, 0.01)
        end)

        it("moves the row to the other side when the first is inside another aircraft's volume", function()
            local menu = buildMenu()
            addCrate("c1", "dynamic")
            ctld.utils.positionsInsideAnyBBox = function(positions)
                for _, p in ipairs(positions) do if lateral(p) > 0 then return true end end
                return false
            end
            avoid = { { unitPos = {}, bbox = {} } }
            drop(menu)
            assert.is_near(-3.0, lateral(dropped.c1), 0.01)
        end)

    end)

    describe("a type that declares no plan keeps the radial rule", function()

        it("places the first crate at the secure distance + 5 m and hands the other aircraft's volumes to the radial routine", function()
            caps = { cratesEnabled = true }
            local menu = buildMenu()
            addCrate("c1", "dynamic")
            avoid = { { unitPos = { p = { x = 5000, y = 0, z = 5000 }, x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } },
                      bbox = { min = { x = -1, y = -1, z = -1 }, max = { x = 1, y = 1, z = 1 } } } }
            drop(menu)
            assert.equals(avoid, avoidSeen)
            local d = math.sqrt((dropped.c1.x - CX) ^ 2 + (dropped.c1.z - CZ) ^ 2)
            assert.is_true(d > 10, "the radial rule stands the crate well away from the hull (" .. d .. " m)")
        end)

    end)

end)
