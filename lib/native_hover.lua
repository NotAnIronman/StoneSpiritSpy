local Catalog = require("lib/catalog")
local M = {}

local function sizeOf(component)
    local size = component.size
    return {size.width, size.height, size.widthParentPc, size.heightParentPc}
end

local function restoreSize(component, size)
    component:SetSize(size[1], size[2], size[3], size[4])
end

function M.new()
    local self = {}
    local name, suffix, applied, lastError
    local state = "no hover target"

    local function restore()
        if applied then
            pcall(function()
                if applied.label.content == applied.rendered then
                    applied.label.content = applied.original
                    restoreSize(applied.label, applied.labelSize)
                end
            end)
            applied = nil
        end
    end

    function self:clear()
        name, suffix = nil, nil
        state = "no hover target"
        restore()
    end

    function self:diagnosticState()
        return "target=" .. tostring(name) .. " | " .. state
    end

    function self:setTarget(rockName, countSuffix)
        if not rockName then self:clear(); return end
        name, suffix = Catalog.normalise(rockName), countSuffix
    end

    function self:draw()
        if not name then return end
        local ok, err = pcall(function()
            -- Client 951-1 live report: TOPLEVEL_V2 static=902/0:0 contains
            -- "Mine Copper rock". TEXT_TOOLTIP instead contains a placeholder.
            local label = ui.Interfaces:GetComponent(id.Interface.TOPLEVEL_V2, 902, 0, 0)
            if not label then state = "native TOPLEVEL_V2 label 902/0:0 missing"; restore(); return end
            if label.type ~= ui.ComponentType.LABEL then
                state = "native label has unexpected type " .. tostring(label.type); restore(); return
            end
            if not label.visibleGlobal then
                state = "native TOPLEVEL_V2 label 902/0:0 hidden"
                restore(); return
            end
            if applied and applied.label ~= label then restore() end
            local current = label.content
            local original = applied and current == applied.rendered and applied.original or current
            local plain = Catalog.normalise(original)
            local first, last = plain:find(name, 1, true)
            if not first or (first > 1 and plain:sub(first - 1, first - 1):match("[%w]"))
                or plain:sub(last + 1, last + 1):match("[%w]") then
                state = "native label text does not match target: " .. tostring(current)
                restore(); return
            end

            local rendered = original .. suffix
            if applied and current == applied.rendered and rendered == applied.rendered then
                state = "native label still contains count"; return
            end
            if not applied or applied.label ~= label or (current ~= applied.rendered and current ~= applied.original) then
                restore()
                applied = {original=original, labelSize=sizeOf(label)}
            end
            applied.label, applied.rendered = label, rendered
            local font = config.Font.FromID(label.font)
            local extraWidth = math.max(0, font:GetStringWidth(rendered, false) - font:GetStringWidth(original, false))
            label.content = rendered
            local size = applied.labelSize
            label:SetSize(size[1] + extraWidth, size[2], size[3], size[4])
            state = "native label write readback=" .. tostring(label.content == rendered)
        end)
        if not ok then
            state = "native update error: " .. tostring(err)
            restore()
            if tostring(err) ~= lastError then
                log("Stone Spirit Spy could not update the native hover box: " .. tostring(err))
                lastError = tostring(err)
            end
        else
            lastError = nil
        end
    end

    return self
end

return M
