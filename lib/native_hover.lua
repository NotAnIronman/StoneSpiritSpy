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

    local function restore()
        if applied then
            pcall(function()
                if applied.label.content == applied.rendered then
                    applied.label.content = applied.original
                    restoreSize(applied.label, applied.labelSize)
                    restoreSize(applied.box, applied.boxSize)
                end
            end)
            applied = nil
        end
    end

    function self:clear()
        name, suffix = nil, nil
        restore()
    end

    function self:setTarget(rockName, countSuffix)
        if not rockName then self:clear(); return end
        name, suffix = Catalog.normalise(rockName), countSuffix
    end

    function self:draw()
        if not name then return end
        local ok, err = pcall(function()
            -- Native TEXT_TOOLTIP layout, checked against cache 2736/build 950.1:
            -- component 15 is its text; component 1 is the existing tooltip box.
            local interfaceID = id.Interface.TEXT_TOOLTIP
            local label = ui.Interfaces:GetComponent(interfaceID, 15)
            local box = ui.Interfaces:GetComponent(interfaceID, 1)
            if not label or not box or label.type ~= ui.ComponentType.LABEL or not label.visibleGlobal then
                restore(); return
            end
            local current = label.content
            local original = applied and current == applied.rendered and applied.original or current
            local plain = Catalog.normalise(original)
            local first, last = plain:find(name, 1, true)
            if not first or (first > 1 and plain:sub(first - 1, first - 1):match("[%w]"))
                or plain:sub(last + 1, last + 1):match("[%w]") then
                restore(); return
            end

            local rendered = original .. suffix
            if applied and current == applied.rendered and rendered == applied.rendered then return end
            if not applied or (current ~= applied.rendered and current ~= applied.original) then
                restore()
                applied = {original=original, labelSize=sizeOf(label), boxSize=sizeOf(box),
                    labelWidth=label.width, labelHeight=label.height, boxWidth=box.width, boxHeight=box.height}
            end
            applied.label, applied.box, applied.rendered = label, box, rendered
            local font = config.Font.FromID(label.font)
            local extraWidth = math.max(0, font:GetStringWidth(rendered, false) - font:GetStringWidth(original, false))
            label.content = rendered
            label:SetSize(applied.labelWidth + extraWidth, applied.labelHeight)
            box:SetSize(applied.boxWidth + extraWidth, applied.boxHeight)
        end)
        if not ok then
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
