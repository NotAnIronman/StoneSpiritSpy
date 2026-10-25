local Catalog = require("lib/catalog")
local M = {}

local function try(fn)
    local ok, value = pcall(fn)
    if ok then return value end
end

function M.new(api)
    local self = {}
    local backpackDirty, carryingBox = true, false

    function self:inventoryChanged(cfg)
        if cfg and cfg.id == api.backpackID then backpackDirty = true end
    end

    function self:reset()
        backpackDirty, carryingBox = true, false
    end

    function self:hasBox()
        if not api.available() then self:reset(); return false end
        if not backpackDirty then return carryingBox end
        carryingBox = false
        local slots = try(function() return api.slots(api.backpackID) end)
        if not slots then return false end
        for _, slot in pairs(slots) do
            if slot.obj and Catalog.boxes[slot.obj.id]
                and Catalog.isCount(slot.count) and slot.count > 0 then
                carryingBox = true
                break
            end
        end
        backpackDirty = false
        return carryingBox
    end

    function self:count(spirit)
        local cfg = try(function() return api.variableByName(spirit.varName) end)
        if not cfg then
            cfg = try(function()
                local candidate = api.variableByID(spirit.varID)
                if candidate and candidate.configName == spirit.varName then return candidate end
            end)
        end
        local value = cfg and try(function() return cfg.value end)
        if Catalog.isCount(value) then return value end
    end

    return self
end

return M
