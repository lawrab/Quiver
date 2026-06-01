-- Loads a module file into the current environment after stubs are in place.
-- WoW addon files assign into _G implicitly; this just dofile()s them in order.

local function load_module(path)
    local ok, err = pcall(dofile, path)
    if not ok then
        error("Failed to load " .. path .. ": " .. tostring(err), 2)
    end
end

return {
    -- Load stubs first, then the modules under test
    setup = function(modules)
        dofile("tests/wow_stubs.lua")
        for _, path in ipairs(modules) do
            load_module(path)
        end
    end,
}
