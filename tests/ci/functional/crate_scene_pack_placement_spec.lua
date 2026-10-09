---@diagnostic disable
-- FIX-REVIEW-HYGIENE-B ticket 02 (issue #253): the crates of a packed scene (a FARP) are placed by the same rule as
-- Request Equipment, Drop Crate(s) and Pack Vehicle (ADR 0024): in a row at the declared distance for a type that
-- declares a crate spawn plan, the radial rule with the anti-collision otherwise. Each crate still carries the
-- scene's warehouse snapshot, and packing broadcasts nothing to the other players.
-- Driven through the F10 "Pack <scene>" command with doubles of the aircraft and of the crate creation.
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

describe("Pack <scene> places its crates by the common rule", function()

    local SCENE, MODEL = "farp_test_1", "FARP_test_model"
    local SNAPSHOT = { liquids = { 1000 } }
    local CX, CZ = 1000, 2000   -- aircraft position (heading 0: nose to +x, right side to +z)
    local UH1H_BOX = { min = { x = -8.86, y = -1.63, z = -1.59 }, max = { x = 3.95, y = 1.59, z = 1.56 } }

    local cm, sm, transport, created, avoid, avoidSeen, broadcasts, caps
    local origGs, origGetByName, origInAir, origRandom, origGroupId, origOutTextGroup, origOutText
    local origPositions, origActive, origModels

    local function lateral(p) return p.z - CZ end    -- + = right of the aircraft
    local function ahead(p)   return p.x - CX end    -- + = in front of the nose

    local function pack()
        local playerObj = {
            unitName = "UH-1H-1", groupId = 9904, groupName = "Grp_pack", coalition = 2,
            typeName = "UH-1H", isTransport = true, canCarryVehicles = false,
        }
        CTLDPlayerManager.getInstance():buildMenu(playerObj)
        cm:refreshPackEquiptSection(playerObj, false, true)
        local menu = ctld.MenuManager:getInstance():getMenuByGroupId(9904)
        local node = menu:_getNode({ ctld.tr("CTLD"), ctld.tr("Crate Commands"), ctld.tr("Pack Equipt"),
                                     ctld.tr("Pack %1", MODEL) })
        assert.is_not_nil(node, "the Pack Equipt submenu lists no such scene")
        node.functionToCall({ unitName = "UH-1H-1", sceneName = SCENE })
    end

    before_each(function()
        resetAll()
        origGs, origGetByName, origInAir = ctld.gs, Unit.getByName, ctld.utils.inAir
        origRandom, origGroupId = ctld.utils.RandomReal, ctld.utils.getGroupId
        origOutTextGroup, origOutText = trigger.action.outTextForGroup, trigger.action.outText
        origPositions = ctld.utils.getSpawnObjectPositions

        caps = { cratesEnabled = true, crateSpawnSector = "side", crateSpawnDistance = 3.0 }
        created, avoid, avoidSeen, broadcasts = {}, {}, nil, {}

        ctld.gs = function(k)
            if k == "capabilitiesByType" then return { ["UH-1H"] = caps } end
            if k == "enableFARPRepack" then return true end
            if k == "loadCrateFromMenu" or k == "enableSmokeDrop" or k == "enabledFOBBuilding"
               or k == "enablePackingVehicles" or k == "enabledRadioBeaconDrop" or k == "reconF10Menu"
               or k == "JTAC_jtacStatusF10" or k == "JTAC_dropEnabled" or k == "enableParachuteDrop" then
                return false
            end
            if k == "ctldCrateDescriptors" then return {} end
            return origGs(k)
        end

        transport = {
            getName      = function() return "UH-1H-1" end,
            getTypeName  = function() return "UH-1H" end,
            isExist      = function() return true end,
            getCoalition = function() return coalition.side.BLUE end,
            getCountry   = function() return country.id.USA end,
            getPoint     = function() return { x = CX, y = 0, z = CZ } end,
            getPosition  = function()
                return { p = { x = CX, y = 0, z = CZ }, x = { x = 1, y = 0, z = 0 },
                         y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
            end,
            getDesc      = function() return { box = UH1H_BOX } end,
        }
        Unit.getByName = function(n) if n == "UH-1H-1" then return transport end end
        ctld.utils.inAir = function() return false end
        ctld.utils.getGroupId = function() return 9904 end
        ctld.utils.RandomReal = function() return 0.1 end        -- the right side, whatever the range
        trigger.action.outTextForGroup = function() end
        trigger.action.outText = function(text) broadcasts[#broadcasts + 1] = text end
        ctld.utils.getSpawnObjectPositions = function(unit, n, dist, spacing, axis, avoidList)
            avoidSeen = avoidList
            return origPositions(unit, n, dist, spacing, axis, avoidList)
        end

        -- The crate manager indexes the scene models when it is created: create it before the test model goes in.
        cm = CTLDCrateManager.getInstance()
        sm = CTLDSceneManager.getInstance()
        origActive, origModels = sm._active, sm._models
        sm._models = { [MODEL] = {
            crate    = { cratesRequired = 3 },
            onRepack = function(_, data) data.warehouseSnapshot = SNAPSHOT end,
        } }
        sm._active = { [SCENE] = { _name = SCENE, _modelName = MODEL, _refX = CX + 50, _refZ = CZ, _spawnedObjs = {} } }

        cm._getDynamicBBoxes = function() return avoid end
        cm.findDescriptorByUnitType = function() return { desc = "FARP crate", unit = MODEL, weight = 1000 } end
        cm.spawnCrate = function(_, _, pos)
            local crate = { position = pos, metadata = {} }
            created[#created + 1] = crate
            return crate
        end
        cm.refreshUnpackSectionForUnit = function() end
    end)

    after_each(function()
        ctld.gs, Unit.getByName, ctld.utils.inAir = origGs, origGetByName, origInAir
        ctld.utils.RandomReal, ctld.utils.getGroupId = origRandom, origGroupId
        trigger.action.outTextForGroup, trigger.action.outText = origOutTextGroup, origOutText
        ctld.utils.getSpawnObjectPositions = origPositions
        sm._active, sm._models = origActive, origModels
        resetAll()
    end)

    describe("a type that declares a crate spawn plan (UH-1H: side, 3.0 m)", function()

        it("stands the crates of the packed scene in a row at the declared distance, abeam", function()
            pack()
            assert.equals(3, #created)
            local xs = {}
            for _, c in ipairs(created) do
                assert.is_near(3.0, lateral(c.position), 0.01)
                xs[#xs + 1] = ahead(c.position)
            end
            table.sort(xs)
            assert.is_near(0, (xs[1] + xs[#xs]) / 2, 0.01)
            assert.is_nil(avoidSeen)   -- not the radial routine
        end)

        it("gives every created crate the scene's warehouse snapshot", function()
            pack()
            assert.equals(3, #created)
            for _, c in ipairs(created) do assert.equals(SNAPSHOT, c.metadata.warehouseSnapshot) end
        end)

        it("broadcasts nothing to the players of the mission", function()
            pack()
            assert.same({}, broadcasts)
        end)

    end)

    describe("a type that declares no plan keeps the radial rule", function()

        it("hands the other aircraft's volumes to the radial routine", function()
            caps = { cratesEnabled = true }
            avoid = { { unitPos = { p = { x = 5000, y = 0, z = 5000 }, x = { x = 1, y = 0, z = 0 }, y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } },
                      bbox = { min = { x = -1, y = -1, z = -1 }, max = { x = 1, y = 1, z = 1 } } } }
            pack()
            assert.equals(3, #created)
            assert.equals(avoid, avoidSeen)
            for _, c in ipairs(created) do assert.equals(SNAPSHOT, c.metadata.warehouseSnapshot) end
        end)

    end)

end)
