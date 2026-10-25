local Catalog = require("lib/catalog")
local M = {}

local function sizeOf(component)
    local size = component.size
    return {size.width, size.height, size.widthParentPc, size.heightParentPc}
end

local function restoreSize(component, size)
    component:SetSize(size[1], size[2], size[3], size[4])
end

local function sameSize(component, size)
    if not size then return false end
    local current = sizeOf(component)
    for i=1,4 do if current[i] ~= size[i] then return false end end
    return true
end

local function setSize(component, size)
    if not sameSize(component, size) then restoreSize(component, size) end
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
                end
                if sameSize(applied.box, applied.renderedBoxSize) then restoreSize(applied.box, applied.boxSize) end
                if sameSize(applied.label, applied.renderedLabelSize) then restoreSize(applied.label, applied.labelSize) end
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
            -- Live 0.3.7 capture: label -> 902 -> 901 -> frame 899 -> viewport 896.
            -- Frame 899 is fixed-width; its inner layers inherit that width.
            local box = ui.Interfaces:GetComponent(id.Interface.TOPLEVEL_V2, 899)
            local ancestor, insideFrame, parentGrowth = label.parent, false, 1
            for _=1,8 do
                if not ancestor then break end
                if ancestor.staticID == 899 then insideFrame = true; break end
                parentGrowth = parentGrowth * ancestor.size.widthParentPc
                ancestor = ancestor.parent
            end
            if not box or box.type ~= ui.ComponentType.LAYER or not insideFrame then
                state = "native hover frame 899 invalid: found=" .. tostring(box ~= nil)
                    .. " type=" .. tostring(box and box.type) .. " expected=" .. tostring(ui.ComponentType.LAYER)
                    .. " ancestor=" .. tostring(insideFrame)
                restore(); return
            end
            if applied and (applied.label ~= label or applied.box ~= box) then restore() end
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
            if not applied or (current ~= applied.rendered and current ~= applied.original) then
                restore()
                applied = {original=original, labelSize=sizeOf(label), boxSize=sizeOf(box),
                    parentGrowth=parentGrowth}
            end
            applied.label, applied.box, applied.rendered = label, box, rendered
            local font = config.Font.FromID(label.font)
            local extraWidth = math.max(0, font:GetStringWidth(rendered, false) - font:GetStringWidth(original, false))
            label.content = rendered
            local boxSize, labelSize = applied.boxSize, applied.labelSize
            applied.renderedBoxSize = {boxSize[1] + extraWidth, boxSize[2], boxSize[3], boxSize[4]}
            setSize(box, applied.renderedBoxSize)
            -- Use sizing ratios rather than computed widths: native layout may
            -- be recalculated after Draw. A relative label already inherits growth.
            local inheritedWidth = extraWidth * applied.parentGrowth * labelSize[3]
            applied.renderedLabelSize = {math.ceil(labelSize[1] + extraWidth - inheritedWidth),
                labelSize[2], labelSize[3], labelSize[4]}
            setSize(label, applied.renderedLabelSize)
            state = "native label write readback=" .. tostring(label.content == rendered)
                .. " frameWidth=" .. tostring(box.width) .. " labelWidth=" .. tostring(label.width)
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
