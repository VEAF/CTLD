---@diagnostic disable
-- tests/ci/functional/crate_spawn_layout_spec.lua
-- FEAT-NATIVE-CRATE-SPAWN-NEAR ticket 02 -- crates requested as a set, or produced by packing a vehicle,
-- stand in a row just clear of an aircraft whose type declares a crate spawn sector and distance (ADR 0024);
-- any other type keeps today's radial layout. Driven through the spawn entry with doubles of the aircraft and
-- of the static spawn: only positions and counts are asserted.
-- ============================================================

describe("CTLDCrateManager:spawnCratesAligned -- row beside an aircraft that declares a crate spawn plan", function()

    local cm, spawned, origRandom, origGetByName, transport, avoid
    local CX, CZ = 1000, 2000   -- aircraft position (heading 0: nose to +x, right side to +z)

    local function makeTransport(typeName, box)
        return {
            getName      = function() return "nc2_player" end,
            getTypeName  = function() return typeName end,
            isExist      = function() return true end,
            getCoalition = function() return coalition.side.BLUE end,
            getPoint     = function() return { x = CX, y = 0, z = CZ } end,
            getPosition  = function()
                return { p = { x = CX, y = 0, z = CZ }, x = { x = 1, y = 0, z = 0 },
                         y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } }
            end,
            getDesc      = function() return { box = box } end,
        }
    end

    local UH1H_BOX = { min = { x = -8.86, y = -1.63, z = -1.59 }, max = { x = 3.95, y = 1.59, z = 1.56 } }
    local C130_BOX = { min = { x = -17.6, y = -4, z = -20.5 }, max = { x = 17.6, y = 8, z = 20.5 } }

    local function descriptors(n)
        local list = {}
        for i = 1, n do list[i] = { desc = "crate " .. i, unit = "Hummer" } end
        return list
    end

    local function spawn(typeName, box, n, method)
        transport = makeTransport(typeName, box)
        spawned = {}
        Unit.getByName = function(name) if name == "nc2_player" then return transport end end
        cm:spawnCratesAligned(descriptors(n), transport, coalition.side.BLUE, "nc2_player",
            method or CTLDCrate.SPAWN_METHOD.MENU_CTLD)
        return spawned
    end

    local function lateral(p) return p.z - CZ end    -- + = right of the aircraft
    local function ahead(p)   return p.x - CX end    -- + = in front of the nose

    before_each(function()
        CTLDCrateManager._instance = nil
        CTLDPlayerManager._instance = nil
        cm = CTLDCrateManager.getInstance()
        spawned = {}
        avoid = {}
        cm.spawnCrate = function(_, _, pos) spawned[#spawned + 1] = pos; return true end
        cm._getDynamicBBoxes = function() return avoid end
        origRandom = ctld.utils.RandomReal
        ctld.utils.RandomReal = function() return 0.1 end       -- the right side, whatever the range
        origGetByName = Unit.getByName
    end)

    after_each(function()
        ctld.utils.RandomReal = origRandom
        Unit.getByName = origGetByName
        CTLDCrateManager._instance = nil
        CTLDPlayerManager._instance = nil
    end)

    describe("side sector (UH-1H: 3.0 m)", function()

        it("puts a single crate at the declared distance, abeam", function()
            local p = spawn("UH-1H", UH1H_BOX, 1)[1]
            assert.is_near(3.0, math.abs(lateral(p)), 0.01)
            assert.is_near(0, ahead(p), 0.01)
        end)

        it("puts every crate of a wave at the same lateral distance", function()
            local pos = spawn("UH-1H", UH1H_BOX, 4)
            assert.equals(4, #pos)
            for _, p in ipairs(pos) do assert.is_near(3.0, math.abs(lateral(p)), 0.01) end
        end)

        it("spaces neighbours by crate size + gap (1.31 + 0.5 = 1.81 m), centred on the aircraft", function()
            local pos = spawn("UH-1H", UH1H_BOX, 4)
            local xs = {}
            for _, p in ipairs(pos) do xs[#xs + 1] = ahead(p) end
            table.sort(xs)
            for i = 2, #xs do assert.is_near(1.81, xs[i] - xs[i - 1], 0.01) end
            assert.is_near(0, (xs[1] + xs[#xs]) / 2, 0.01)
        end)

        it("never lets two crates of a wave touch", function()
            local pos = spawn("UH-1H", UH1H_BOX, 9)
            for i = 1, #pos do
                for j = i + 1, #pos do
                    local d = math.sqrt((pos[i].x - pos[j].x) ^ 2 + (pos[i].z - pos[j].z) ^ 2)
                    assert.is_true(d >= 1.31 + 0.5 - 0.01, "crates " .. i .. " and " .. j .. " are " .. d .. " m apart")
                end
            end
        end)

        it("starts a second row one step further out when the first is full", function()
            -- the row holds floor((12.81 + 0.5) / (1.31 + 0.5)) = 7 crates along the aircraft's box
            local pos = spawn("UH-1H", UH1H_BOX, 9)
            local near, far = 0, 0
            for _, p in ipairs(pos) do
                local d = math.abs(lateral(p))
                if math.abs(d - 3.0) < 0.01 then near = near + 1
                elseif math.abs(d - (3.0 + 1.81)) < 0.01 then far = far + 1 end
            end
            assert.equals(7, near)
            assert.equals(2, far)
        end)

        it("is the same layout for the crates of a packed vehicle", function()
            local pos = spawn("UH-1H", UH1H_BOX, 4, CTLDCrate.SPAWN_METHOD.VEHICLE_PACK)
            assert.equals(4, #pos)
            for _, p in ipairs(pos) do assert.is_near(3.0, math.abs(lateral(p)), 0.01) end
        end)

        it("uses the other side when the first is inside another aircraft's volume", function()
            -- a neighbour's box centred on the right-hand spot (z = CZ + 3)
            avoid[1] = {
                unitPos = { p = { x = CX, y = 0, z = CZ + 3 }, x = { x = 1, y = 0, z = 0 },
                            y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } },
                bbox = { min = { x = -2, y = -2, z = -2 }, max = { x = 2, y = 2, z = 2 } },
            }
            local p = spawn("UH-1H", UH1H_BOX, 1)[1]
            assert.is_near(-3.0, lateral(p), 0.01)
        end)

        it("keeps the first side when both are taken", function()
            for _, dz in ipairs({ 3, -3 }) do
                avoid[#avoid + 1] = {
                    unitPos = { p = { x = CX, y = 0, z = CZ + dz }, x = { x = 1, y = 0, z = 0 },
                                y = { x = 0, y = 1, z = 0 }, z = { x = 0, y = 0, z = 1 } },
                    bbox = { min = { x = -2, y = -2, z = -2 }, max = { x = 2, y = 2, z = 2 } },
                }
            end
            local p = spawn("UH-1H", UH1H_BOX, 1)[1]
            assert.is_near(3.0, lateral(p), 0.01)
        end)

        it("picks the left side for the whole wave when the draw says so", function()
            ctld.utils.RandomReal = function() return 0.9 end
            local pos = spawn("UH-1H", UH1H_BOX, 3)
            for _, p in ipairs(pos) do assert.is_near(-3.0, lateral(p), 0.01) end
        end)

    end)

    describe("rear sector (C-130J-30: 11.3 m)", function()

        it("puts the crates in a row across the tail, 11.3 m behind the centre", function()
            local pos = spawn("C-130J-30", C130_BOX, 3)
            assert.equals(3, #pos)
            for _, p in ipairs(pos) do assert.is_near(-11.3, ahead(p), 0.01) end
            local zs = {}
            for _, p in ipairs(pos) do zs[#zs + 1] = lateral(p) end
            table.sort(zs)
            assert.is_near(1.81, zs[2] - zs[1], 0.01)
            assert.is_near(0, (zs[1] + zs[#zs]) / 2, 0.01)
        end)

    end)

    -- FIX-REVIEW-HYGIENE-B ticket 03 (issue #255): the row is computed from the crate size, so a crate model
    -- that declares none (sling, used for every crate of a slingLoad mission) keeps the radial rule.
    describe("a crate model without a size keeps the radial layout (slingLoad: true)", function()

        local origGs, models

        before_each(function()
            origGs, models = ctld.gs, nil
            ctld.gs = function(k)
                if k == "slingLoad" then return true end
                if k == "spawnableCratesModels" and models then return models end
                return origGs(k)
            end
        end)

        after_each(function() ctld.gs = origGs end)

        it("puts a wave on the radial rule even for a type that declares a plan", function()
            local pos = spawn("UH-1H", UH1H_BOX, 2)
            assert.equals(2, #pos)
            local secure = math.sqrt(8.86 * 8.86 + 1.59 * 1.59) + 5
            local d1 = math.sqrt((pos[1].x - CX) ^ 2 + (pos[1].z - CZ) ^ 2)
            local d2 = math.sqrt((pos[2].x - CX) ^ 2 + (pos[2].z - CZ) ^ 2)
            assert.is_near(secure, d1, 0.01)
            assert.is_near(secure + 5, d2, 0.01)
        end)

        it("gets the row back once the mission maker declares a size for the sling model", function()
            models = { sling = { type = "container_cargo", size = 2.0 } }
            local pos = spawn("UH-1H", UH1H_BOX, 2)
            assert.equals(2, #pos)
            for _, p in ipairs(pos) do assert.is_near(3.0, lateral(p), 0.01) end
            assert.is_near(2.0 + 0.5, math.abs(ahead(pos[2]) - ahead(pos[1])), 0.01)
        end)

    end)

    describe("an aircraft that declares no plan keeps today's radial layout", function()

        it("puts the first crate at the secure distance + 5 m and the next 5 m further out", function()
            -- SA342M declares no plan; its box is only used by the existing secure-distance rule
            local box = { min = { x = -6, y = -1, z = -1 }, max = { x = 6, y = 1, z = 1 } }
            local pos = spawn("SA342M", box, 2)
            assert.equals(2, #pos)
            local secure = math.sqrt(6 * 6 + 1 * 1) + 5
            local d1 = math.sqrt((pos[1].x - CX) ^ 2 + (pos[1].z - CZ) ^ 2)
            local d2 = math.sqrt((pos[2].x - CX) ^ 2 + (pos[2].z - CZ) ^ 2)
            assert.is_near(secure, d1, 0.01)
            assert.is_near(secure + 5, d2, 0.01)
        end)

    end)

end)
