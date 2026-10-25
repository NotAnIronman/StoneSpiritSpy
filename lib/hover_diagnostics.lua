local Catalog = require("lib/catalog")
local M = {}
local PANEL_NAMES = {"TEXT_TOOLTIP", "TOPLEVEL_V2_HOVER_TARGET", "MINIMENU", "TOPLEVEL_V2"}
local PREFIX = "[SSS-HOVER] "

local function short(value)
    return tostring(value):gsub("[\r\n]", " "):sub(1, 180)
end

function M.new(output)
    local self = {}
    local capture
    local function remember(group, text, limit)
        if not capture.seen[group .. text] and #capture[group] < limit then
            capture.seen[group .. text] = true
            capture[group][#capture[group] + 1] = text
        end
    end

    function self:active() return capture ~= nil end

    function self:start()
        capture = {remaining=5, frames=0, calls=0, panel=1, component=-1,
            menus={}, states={}, labels={}, panels={}, seen={}}
        output(PREFIX .. "Stone Spirit Spy 0.3.2 recording for 5 seconds. Close settings and hover Copper rock.")
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

    local function scanOne()
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
        if not component or component.type ~= ui.ComponentType.LABEL then return end
        local content = component.content
        local plain = Catalog.normalise(content)
        if plain:find("copper", 1, true) or plain:find("rock", 1, true) then
            local parent = component.parent
            remember("labels", panelName .. " static=" .. staticID
                .. " visible=" .. short(component.visibleGlobal)
                .. " restricted=" .. short(component.isRestricted)
                .. " parentStatic=" .. short(parent and parent.staticID)
                .. " text=" .. short(content), 16)
        end
    end

    function self:draw(delta, hoverState)
        if not capture then return end
        capture.frames = capture.frames + 1
        remember("states", short(hoverState), 10)
        -- Only an explicit recording reads UI candidates. At most 16 lookups
        -- per Draw. Three panels cover IDs 0..255; TOPLEVEL_V2 covers 0..2047.
        for _=1,16 do
            local ok, err = pcall(scanOne)
            if not ok then remember("states", "scan error: " .. short(err), 10) end
        end
        if type(delta) == "number" and delta == delta and delta > 0 then
            capture.remaining = capture.remaining - math.min(delta, 0.25)
        end
        if capture.remaining > 0 and capture.frames < 600 then return end
        output(PREFIX .. "REPORT BEGIN frames=" .. capture.frames .. " UI lookups=" .. capture.calls)
        for _, group in ipairs({"menus", "states", "panels", "labels"}) do
            if #capture[group] == 0 then output(PREFIX .. group .. ": none captured") end
            for _, line in ipairs(capture[group]) do output(PREFIX .. group .. ": " .. line) end
        end
        output(PREFIX .. "REPORT END. Copy the SSS-HOVER lines for diagnosis.")
        capture = nil
    end

    return self
end

return M
