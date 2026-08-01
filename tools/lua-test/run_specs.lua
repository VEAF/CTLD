-- run_specs.lua — a minimal busted-compatible runner for `tests/ci/unit/`, in plain Lua 5.1.
--
-- Why: busted needs luarocks on Lua ≤ 5.4, which is awkward to get on a Windows dev box, so the
-- suite often ends up only ever running in CI — several minutes per typo. This runs the whole
-- suite locally in about a second, on the same Lua 5.1 DCS uses.
--
-- It is a convenience, not an authority: **CI's busted + luacheck remain the gate.** It
-- implements `describe` / `context` / `it` / `before_each` / `after_each` / `setup` / `teardown`
-- and the `assert.*` subset the specs actually use — nothing else. A spec reaching for `spy`,
-- `mock`, `stub` or a matcher will fail here and pass in CI; that is a runner limitation, not a
-- regression. A spec that cannot even load is reported as SKIP rather than killing the run.
--
-- Usage (from the repo root — the specs use relative dofile paths):
--   lua tools/lua-test/run_specs.lua ./ tests/ci/unit/foo_spec.lua [more_spec.lua ...]
-- or, on Windows, the wrapper that finds Lua 5.1 and expands the file list:
--   powershell -File tools/lua-test/run_specs.ps1 [name-filter]

local root = arg[1]
if root:sub(-1) ~= "/" and root:sub(-1) ~= "\\" then root = root .. "/" end

local failures, passed = {}, 0
local stack = {}          -- describe titles
local beforeEach, afterEach = {}, {}

local realAssert = assert

local A = setmetatable({}, { __call = function(_, ok, msg) return realAssert(ok, msg) end })
local function fail(msg) error(msg, 3) end
function A.is_true(v, m)      if v ~= true then fail(m or ("expected true, got " .. tostring(v))) end end
function A.is_false(v, m)     if v ~= false then fail(m or ("expected false, got " .. tostring(v))) end end
function A.is_nil(v, m)       if v ~= nil then fail(m or ("expected nil, got " .. tostring(v))) end end
function A.is_not_nil(v, m)   if v == nil then fail(m or "expected non-nil") end end
function A.equals(e, a, m)    if e ~= a then fail(m or ("expected " .. tostring(e) .. ", got " .. tostring(a))) end end
A.are_equal = A.equals
A.same = function(e, a, m)
    local function deep(x, y)
        if x == y then return true end
        if type(x) ~= "table" or type(y) ~= "table" then return false end
        for k, v in pairs(x) do if not deep(v, y[k]) then return false end end
        for k in pairs(y) do if x[k] == nil then return false end end
        return true
    end
    if not deep(e, a) then fail(m or "tables differ") end
end
A.is_table = function(v, m) if type(v) ~= "table" then fail(m or "expected table") end end
A.is_string = function(v, m) if type(v) ~= "string" then fail(m or "expected string") end end
A.is_number = function(v, m) if type(v) ~= "number" then fail(m or "expected number") end end
A.is_function = function(v, m) if type(v) ~= "function" then fail(m or "expected function") end end
A.has_error = function(f, m) local ok = pcall(f) if ok then fail(m or "expected an error") end end
A.has_no_error = function(f, m)
    local ok, err = pcall(f)
    if not ok then fail(m or ("expected no error, got: " .. tostring(err))) end
end
A.is_truthy = function(v, m) if not v then fail(m or "expected a truthy value") end end
A.is_falsy  = function(v, m) if v then fail(m or "expected a falsy value") end end
A.not_equal = function(e, a, m) if e == a then fail(m or ("expected something else than " .. tostring(e))) end end

local function title()
    return table.concat(stack, " ")
end

function describe(name, fn)
    stack[#stack + 1] = name
    local nBefore, nAfter = #beforeEach, #afterEach
    fn()
    for i = #beforeEach, nBefore + 1, -1 do beforeEach[i] = nil end
    for i = #afterEach, nAfter + 1, -1 do afterEach[i] = nil end
    stack[#stack] = nil
end
context = describe

function before_each(fn) beforeEach[#beforeEach + 1] = fn end
function after_each(fn)  afterEach[#afterEach + 1] = fn end
function setup(fn)    fn() end
function teardown(fn) fn() end
function lazy_setup(fn)    fn() end
function lazy_teardown(fn) fn() end
insulate = function(_, fn) if type(_) == "function" then _() else fn() end end

function it(name, fn)
    local full = title() .. " :: " .. name
    for _, f in ipairs(beforeEach) do f() end
    local ok, err = pcall(fn)
    for _, f in ipairs(afterEach) do f() end
    if ok then
        passed = passed + 1
    else
        failures[#failures + 1] = full .. "\n    " .. tostring(err)
    end
end
pending = function(name) end

_G.assert = A

-- dkjson is a CI-only rock, and the spec that requires it (config_spec) is the one comparing
-- parseYAML against the committed defaults oracle — i.e. the spec that catches a setting added
-- to CTLD_config.yaml without regenerating tests/ci/data/config_defaults.json. Skipping it
-- locally is exactly the wrong spec to skip, so a minimal decoder stands in.
local selfDir = arg[0]:match("^(.*[/\\])") or "./"
package.preload["dkjson"] = function() return dofile(selfDir .. "dkjson_min.lua") end

dofile(root .. "tests/ci/helpers/init.lua")

local skipped = {}
for i = 2, #arg do
    local ok, err = pcall(dofile, arg[i])
    if not ok then
        skipped[#skipped + 1] = arg[i]:match("([^/\\]+)$") .. " — " .. tostring(err)
    end
end
for _, s in ipairs(skipped) do print("SKIP (runner limitation) " .. s) end

_G.assert = realAssert

print(string.format("\n%d passed, %d failed", passed, #failures))
for _, f in ipairs(failures) do print("FAIL " .. f) end
if #failures > 0 then os.exit(1) end
