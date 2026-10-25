local Catalog = require("lib/catalog")
local M = {}
local PANEL_NAMES = {"TEXT_TOOLTIP", "TOPLEVEL_V2_HOVER_TARGET", "MINIMENU", "TOPLEVEL_V2"}
local PREFIX = "[SSS-HOVER] "
local COLLECTION_TYPES = {"LAYER", "PANEL", "GRID", "PAGED_LAYER", "PAGED_CAROUSEL", "GROUP_BOX"}

local function short(value)
    return tostring(value):gsub("[\r\n]", " "):sub(1, 180)
end

local function read(object, key)
    if object == nil then return nil end
    local ok, value = pcall(function() return object[key] end)
    if ok then return value end
    return "unavailable"
end

local function address(component)
    if not component then return "nil" end
    return short(read(component, "interfaceID")) .. "/" .. short(read(component, "staticID"))
        .. "/" .. short(read(component, "categoryID")) .. ":" .. short(read(component, "dynamicID"))
end

function M.new(output)
    local self = {}
    local capture, lastReport
    local function remember(group, text, limit)
        if not capture.seen[group .. text] and #capture[group] < limit then
            capture.seen[group .. text] = true
            capture[group][#capture[group] + 1] = text
        end
    end

    function self:active() return capture ~= nil end

    function self:report()
        return lastReport or "No completed report yet. Record hover diagnostics, hover a rock for five seconds, then reopen this report."
    end

    function self:start()
        capture = {remaining=5, frames=0, calls=0, panel=1, component=-1,
            static=0, dynamic=0, collections=0, truncated=0, pending={},
            menus={}, states={}, labels={}, samples={}, panels={}, layout={}, traces=0, seen={}}
        output(PREFIX .. "Stone Spirit Spy 0.3.8 recording for 5 seconds. Close settings and hover Copper rock.")
    end

    function self:menu(entries, context)
        if not capture then return end
        local hasRock = false
        for _, entry in ipairs(entries) do
            if Catalog.rock(entry.subjectText) then hasRock = true; break end
        end
        if not hasRock then return end
        local lines = {}
        for _, key in ipairs({"enabled", "focused", "menuOpen", "hasBox", "tierFilter", "target"}) do
            lines[#lines + 1] = key .. "=" .. short(context[key])
        end
        local top = entries[#entries]
        if top then
            lines[#lines + 1] = "topType=" .. short(top.actionEntryType)
            lines[#lines + 1] = "topSubject=" .. short(top.subjectText)
            lines[#lines + 1] = "topText=" .. short(top.fullText)
            lines[#lines + 1] = "topOverride=" .. short(top.overrideText)
        end
        remember("menus", table.concat(lines, " | "), 6)
    end

    local function describeLayout(component, source)
        if not component then remember("layout", source .. " missing", 64); return end
        remember("layout", source .. " interface=" .. short(read(component, "interfaceID"))
            .. " static=" .. short(read(component, "staticID"))
            .. " category=" .. short(read(component, "categoryID")) .. " dynamic=" .. short(read(component, "dynamicID"))
            .. " type=" .. short(read(component, "type")) .. " visible=" .. short(read(component, "visibleGlobal"))
            .. " width=" .. short(read(component, "width")) .. " height=" .. short(read(component, "height")), 64)
        local size, xy = read(component, "size"), read(component, "xyGlobal")
        remember("layout", source .. " rawSize=" .. short(read(size, "width")) .. "," .. short(read(size, "height"))
            .. "," .. short(read(size, "widthParentPc")) .. "," .. short(read(size, "heightParentPc"))
            .. " xy=" .. short(read(xy, "x")) .. "," .. short(read(xy, "y"))
            .. " parent=" .. address(read(component, "parent"))
            .. " parentStatic=" .. address(read(component, "parentStatic")), 64)
    end

    local function traceLayout(component, path)
        if capture.seen["trace" .. path] or capture.traces >= 2 then return end
        capture.seen["trace" .. path] = true
        capture.traces = capture.traces + 1
        local visited = {}
        for depth=0,11 do
            local source = "trace " .. path .. " depth=" .. depth
            if not component then remember("layout", source .. " parent chain ended", 64); return end
            local key = address(component)
            if visited[key] then remember("layout", source .. " parent cycle at " .. key, 64); return end
            visited[key] = true
            describeLayout(component, source)
            component = read(component, "parent")
            if component == "unavailable" then
                remember("layout", source .. " parent unavailable", 64); return
            end
        end
        remember("layout", "trace " .. path .. " reached ancestor limit", 64)
    end

    local function inspect(component, path, depth)
        if component.type == ui.ComponentType.LABEL then
            local content = component.content
            local plain = Catalog.normalise(content)
            local parent = component.parent
            local description = path .. " category=" .. short(component.categoryID)
                .. " dynamic=" .. short(component.dynamicID)
                .. " visible=" .. short(component.visibleGlobal)
                .. " restricted=" .. short(component.isRestricted)
                .. " parentStatic=" .. short(parent and parent.staticID)
                .. " text=" .. short(content)
            if plain:find("copper", 1, true) or plain:find("rock", 1, true) then
                remember("labels", description, 32)
                if path:find("TOPLEVEL_V2 static=902/", 1, true) then traceLayout(component, path) end
            elseif path:find("TEXT_TOOLTIP", 1, true) or path:find("TOPLEVEL_V2_HOVER_TARGET", 1, true) then
                remember("samples", description, 24)
            end
            return
        end
        local collection = false
        for _, name in ipairs(COLLECTION_TYPES) do
            if ui.ComponentType[name] ~= nil and component.type == ui.ComponentType[name] then
                collection = true; break
            end
        end
        if not collection then return end
        if depth >= 8 then capture.truncated = capture.truncated + 1; return end
        capture.collections = capture.collections + 1
        local children = 0
        component:IterateDynamicComponents(function(child)
            children = children + 1
            if #capture.pending >= 512 then
                capture.truncated = capture.truncated + 1
                return true
            end
            capture.pending[#capture.pending+1] = {component=child, depth=depth+1, path=path}
            if children >= 64 then capture.truncated = capture.truncated + 1; return true end
            return false
        end)
    end

    local function scanOne()
        local pending = table.remove(capture.pending)
        if pending then
            capture.dynamic = capture.dynamic + 1
            local child = pending.component
            inspect(child, pending.path .. "/" .. short(child.categoryID) .. ":" .. short(child.dynamicID), pending.depth)
            return
        end
        local panelName = PANEL_NAMES[capture.panel]
        local resolved, panelID = pcall(function() return id.Interface[panelName] end)
        if not resolved then panelID = nil end
        capture.calls = capture.calls + 1
        if capture.component == -1 then
            local loaded = panelID and ui.Interfaces:GetInterface(panelID) ~= nil
            remember("panels", panelName .. " id=" .. short(panelID) .. " loaded=" .. tostring(loaded), 12)
            if loaded then capture.component = 0
            else capture.panel = capture.panel % #PANEL_NAMES + 1 end
            return
        end

        local staticID = capture.component
        capture.component = capture.component + 1
        local limit = panelName == "TOPLEVEL_V2" and 2047 or 255
        if capture.component > limit then
            capture.component, capture.panel = -1, capture.panel % #PANEL_NAMES + 1
        end
        local component = panelID and ui.Interfaces:GetComponent(panelID, staticID)
        capture.static = capture.static + 1
        if panelName == "TOPLEVEL_V2" and (staticID == 892 or staticID == 899 or staticID == 902) then
            local key = "candidate" .. staticID
            if not capture.seen[key] then
                capture.seen[key] = true
                describeLayout(component, "candidate TOPLEVEL_V2/" .. staticID)
            end
        end
        if component then inspect(component, panelName .. " static=" .. staticID, 0) end
    end

    function self:draw(delta, hoverState)
        if not capture then return end
        capture.frames = capture.frames + 1
        remember("states", short(hoverState), 10)
        -- Each step reads one static candidate or inspects one queued dynamic child.
        -- Child collection is bounded separately, including nested collections.
        for _=1,16 do
            local ok, err = pcall(scanOne)
            if not ok then remember("states", "scan error: " .. short(err), 10) end
        end
        if type(delta) == "number" and delta == delta and delta > 0 then
            capture.remaining = capture.remaining - math.min(delta, 0.25)
        end
        if capture.remaining > 0 and capture.frames < 600 then return end
        local lines = {PREFIX .. "REPORT BEGIN Stone Spirit Spy 0.3.8 frames=" .. capture.frames .. " UI lookups=" .. capture.calls,
            PREFIX .. "coverage: static=" .. capture.static .. " dynamic=" .. capture.dynamic
                .. " collections=" .. capture.collections .. " capped=" .. capture.truncated
                .. " pending=" .. #capture.pending}
        for _, group in ipairs({"menus", "states", "panels", "labels", "samples", "layout"}) do
            if #capture[group] == 0 then lines[#lines+1] = PREFIX .. group .. ": none captured" end
            for _, line in ipairs(capture[group]) do lines[#lines+1] = PREFIX .. group .. ": " .. line end
        end
        lines[#lines+1] = PREFIX .. "REPORT END"
        lastReport = table.concat(lines, "\n")
        for _, line in ipairs(lines) do output(line) end
        output(PREFIX .. "Open plugin settings > Show diagnostic report to select and copy the report.")
        capture = nil
    end

    return self
end

return M
