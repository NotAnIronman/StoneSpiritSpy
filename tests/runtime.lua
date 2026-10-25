local Catalog = require("lib/catalog")
local Reader = require("lib/reader")
local total = 0
local function equal(actual, expected)
    assert(actual == expected, "Expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, fn)
    fn()
    total = total + 1
    print("PASS " .. name)
end
local function field(spirit, value)
    return {id=spirit.varID, configName=spirit.varName, value=value}
end
local bag, variables, online, reads, reader
local function reset()
    bag, variables, online, reads = {}, {}, true, 0
    reader = Reader.new({
        backpackID=93,
        available=function() return online end,
        slots=function(id) reads=reads+1; return bag end,
        variableByName=function(name) return variables[name] end,
        variableByID=function(id)
            for _, cfg in pairs(variables) do if cfg.id == id then return cfg end end
        end,
    })
end
local copper = Catalog.rock("Copper rock")

test("all 17 storage bindings agree with the supplied native VarPlayer dump", function()
    equal(#Catalog.spirits, 17)
    for _, spirit in ipairs(Catalog.spirits) do
        equal(dumpVariables[spirit.varName], spirit.varID)
    end
end)

test("every supported rock resolves its own spirit", function()
    for _, spirit in ipairs(Catalog.spirits) do
        equal(Catalog.rock(spirit.name .. " rock"), spirit)
        equal(Catalog.item(spirit.id), spirit)
        equal(Catalog.rock("<col=ffff00>" .. spirit.name .. " rocks</col>"), spirit)
    end
    equal(Catalog.rock("Concentrated gold rocks").key, "gold")
    equal(Catalog.rock("Concentrated coal rocks").key, "coal")
    equal(Catalog.rock("Sandstone rock"), nil)
    equal(Catalog.rock("Gem rock"), nil)
    equal(Catalog.rock("Copper ore box"), nil)
end)

test("all ten unnoted ore boxes are detected and noted IDs are excluded", function()
    for id=44779,44797,2 do
        reset()
        bag = {{obj={id=id}, count=1}}
        equal(reader:hasBox(), true)
        bag = {{obj={id=id+1}, count=1}}
        reader:inventoryChanged({id=93})
        equal(reader:hasBox(), false)
    end
end)

test("empty backpack and zero-count box slots are not carried boxes", function()
    reset()
    equal(reader:hasBox(), false)
    bag = {{obj={id=44779}, count=0}}
    reader:inventoryChanged({id=93})
    equal(reader:hasBox(), false)
end)

test("current spirit values update without opening or hovering an ore box", function()
    reset()
    local value = field(copper, 248)
    variables[copper.varName] = value
    equal(reader:count(copper), 248)
    value.value = 247
    equal(reader:count(copper), 247)
    value.value = 0
    equal(reader:count(copper), 0)
    value.value = 2147483647
    equal(reader:count(copper), 2147483647)
end)

test("missing, unreadable and invalid values remain unavailable", function()
    reset()
    equal(reader:count(copper), nil)
    for _, value in ipairs({-1, 1.5, math.huge, "248", 2147483648}) do
        variables[copper.varName] = field(copper, value)
        equal(reader:count(copper), nil)
    end
    variables[copper.varName] = setmetatable({}, {__index=function() error("unavailable") end})
    equal(reader:count(copper), nil)
end)

test("numeric fallback verifies the exact native field name", function()
    local cfg = field(copper, 248)
    local fallback = Reader.new({
        variableByName=function() error("name unavailable") end,
        variableByID=function(id) equal(id, 11514); return cfg end,
    })
    equal(fallback:count(copper), 248)
    cfg.configName = "SOME_OTHER_VARIABLE"
    equal(fallback:count(copper), nil)
end)

test("backpack spirits and ore counts cannot inflate stored spirits", function()
    reset()
    bag = {{obj={id=44797}, count=1}, {obj={id=copper.id}, count=1000}, {obj={id=436}, count=150}}
    variables[copper.varName] = field(copper, 248)
    equal(reader:hasBox(), true)
    equal(reader:count(copper), 248)
end)

test("multiple ore boxes share one count", function()
    reset()
    bag = {{obj={id=44779}, count=1}, {obj={id=44797}, count=1}}
    variables[copper.varName] = field(copper, 248)
    equal(reader:hasBox(), true)
    equal(reader:count(copper), 248)
end)

test("all ten box tiers allow exactly their supported spirit types", function()
    local additions = {
        {"copper", "tin"}, {"iron"}, {"coal", "silver"}, {"mithril"},
        {"adamantite", "luminite", "gold"}, {"runite"}, {"orichalcite", "drakolith"},
        {"necrite", "phasmatite"}, {"banite"}, {"light_animica", "dark_animica"},
    }
    local supported = {}
    for tier, keys in ipairs(additions) do
        reset()
        bag = {{obj={id=44777 + tier * 2}, count=1}}
        for _, key in ipairs(keys) do supported[key] = true end
        for _, spirit in ipairs(Catalog.spirits) do
            equal(reader:canHold(spirit), supported[spirit.key] == true)
        end
        equal(reads, 1)
    end
end)

test("highest carried tier wins regardless of backpack slot order", function()
    for _, ids in ipairs({{44779,44797}, {44797,44779}}) do
        reset()
        bag = {{obj={id=ids[1]}, count=1}, {obj={id=ids[2]}, count=1}}
        equal(reader:canHold(Catalog.rock("Dark animica rock")), true)
    end
    bag = {{obj={id=44779}, count=1}, {obj={id=44798}, count=1}, {obj={id=44797}, count=0}}
    reader:inventoryChanged({id=93})
    equal(reader:canHold(copper), true)
    equal(reader:canHold(Catalog.rock("Iron rock")), false)
    online = false
    equal(reader:canHold(copper), false)
end)

test("box deposit, withdrawal, logout and re-login invalidate carried state", function()
    reset()
    bag = {{obj={id=44779}, count=1}}
    equal(reader:hasBox(), true)
    equal(reader:hasBox(), true)
    equal(reads, 1)
    bag = {}
    reader:inventoryChanged({id=93})
    equal(reader:hasBox(), false)
    bag = {{obj={id=44797}, count=1}}
    reader:inventoryChanged({id=93})
    equal(reader:hasBox(), true)
    online = false
    equal(reader:hasBox(), false)
    bag, online = {}, true
    equal(reader:hasBox(), false)
end)

test("labels preserve full counts and distinguish zero from unavailable", function()
    equal(Catalog.label(copper, 248), "248 Copper Stone Spirits")
    equal(Catalog.label(copper, 0), "0 Copper Stone Spirits")
    equal(Catalog.label(copper, 1), "1 Copper Stone Spirit")
    equal(Catalog.label(copper, 2147483647), "2,147,483,647 Copper Stone Spirits")
    equal(Catalog.label(copper, nil), "Copper Stone Spirits: unavailable")
end)

local handlers, logs, available, nativeBag, nativeValues, widgets, uiRoot, settingsHost, mouse, menuOpen, saved
local nativeTooltip, nativeTooltipBox
local nativePanels, uiLookups
local function boot(preferences)
    handlers, logs, available, nativeBag, nativeValues = {}, {}, true, {}, {}
    widgets, mouse, menuOpen, saved = {}, {x=200, y=200}, false, preferences or {}
    nativePanels, uiLookups = {}, 0
    Event = {}
    for _, name in ipairs({"MiniMenuReady", "InventoryAdded", "InventoryUpdated", "InventoryRemoved", "GameStateChanged",
        "MiniMenuOpened", "WindowFocusChanged", "SettingsLayerReady", "Draw"}) do
        Event[name] = {
            Subscribe=function(reference, callback) handlers[name]=callback end,
            Unsubscribe=function(reference) handlers[name]=nil end,
        }
    end
    PluginShutdown = nil
    config = {Inv={INV={id=93}}}
    config.Font = {FromID=function() return {GetStringWidth=function(_, content) return #content:gsub("<[^>]*>", "") * 7 end} end}
    PersistentDB = {
        GetBool=function(_, key) if type(saved[key]) == "boolean" then return saved[key] end end,
        SetBool=function(_, key, value) saved[key]=value; return true end,
    }
    game = {options={InterfaceScale={setting=100}}}
    id = {Font={MUSEO_SANS_15PT_REGULAR=1}, StyleSheet={BUTTON_DEFAULT=2, INPUT_DEFAULT=4},
        Interface={TEXT_TOOLTIP=1486, TOPLEVEL_V2_HOVER_TARGET=1489, MINIMENU=1322, TOPLEVEL_V2=1477},
        Component={TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP=3}}
    local function component(kind, parent)
        local control = {kind=kind, parent=parent, children={}, hooks={}, hidden=false, text={}, scrollbar={}}
        function control:SetPos(x, y) self.x, self.y=x, y end
        function control:SetSize(w, h, wp, hp)
            self.width, self.height=w+(wp or 0)*(self.parent.width or 0), h+(hp or 0)*(self.parent.height or 0)
            self.size = {width=w, height=h, widthParentPc=wp or 0, heightParentPc=hp or 0}
        end
        function control:Subscribe(hook, callback) self.hooks[hook]=callback end
        function control:Setup(visibility, filter, maxLength)
            self.visibility, self.filterMode, self.maxLength = visibility, filter, maxLength
        end
        function control:DeleteAll()
            for _, child in ipairs(self.children) do child:Destroy() end
            self.children = {}
        end
        function control:Destroy()
            self.destroyed, self.hidden = true, true
            for _, child in ipairs(self.children) do child:Destroy() end
        end
        if parent then parent.children[#parent.children+1]=control end
        widgets[#widgets+1]=control
        return control
    end
    uiRoot = component("Host")
    uiRoot.width, uiRoot.height, uiRoot.xyGlobal = 1024, 768, {x=0,y=0}
    settingsHost = component("SettingsHost")
    settingsHost.width, settingsHost.height = 420, 300
    nativeTooltipBox = component("NativeTooltipBox", uiRoot)
    nativeTooltipBox:SetSize(240, 30)
    nativeTooltip = component("NativeTooltip", nativeTooltipBox)
    nativeTooltip:SetSize(224, 22)
    nativeTooltip.type, nativeTooltip.font, nativeTooltip.visibleGlobal = 4, 1, true
    nativeTooltip.content = "Mine <col=ffff00>Copper rock</col>"
    nativePanels[1486] = {[15]=nativeTooltip, [1]=nativeTooltipBox}
    ui = {Hook={ONBUTTONPRESSED=1}, ComponentType={LABEL=4},
        TextContentVisibilityMode={VISIBLE=0}, InputFieldFilterMode={NONE=0},
        Interfaces={GetComponent=function(_, interfaceID, componentID)
        uiLookups = uiLookups + 1
        if interfaceID == 3 then return uiRoot end
        return nativePanels[interfaceID] and nativePanels[interfaceID][componentID]
    end, GetInterface=function(_, interfaceID)
        uiLookups = uiLookups + 1
        if nativePanels[interfaceID] then return {id=interfaceID} end
    end}}
    for _, kind in ipairs({"Layer", "Rectangle", "Text", "Button", "InputField"}) do
        ui[kind] = {new=function(parent) return component(kind, parent) end}
    end
    Mouse = {IsAvailable=function() return true end, GetPosition=function() return mouse end}
    MiniMenu = {IsOpen=function() return menuOpen end}
    var = {VarPlayer=setmetatable({FromID=function(id)
        for _, cfg in pairs(nativeValues) do if cfg.id == id then return cfg end end
    end}, {__index=function(_, name) return nativeValues[name] end})}
    Player = {IsAvailable=function() return available end}
    Inventory = {Find=function(id)
        equal(id, 93)
        return {isValid=true, GetSlots=function() return nativeBag end}
    end}
    MiniMenuEntryType = {LOC=3, NPC=4, OBJ=2, INTERFACE=1}
    log = function(message) logs[#logs+1]=message end
    dofile(pluginRoot .. "/main.lua")
end
local function rock(name)
    return {actionEntryType=3, subjectText=name, locData={config={name=name}},
        fullText="Mine <col=ffff00>" .. name .. "</col>", actionType=3}
end
local function hover(entries)
    handlers.MiniMenuReady({miniMenu={entries=entries}})
    local top = entries[#entries]
    nativeTooltip.visibleGlobal = top ~= nil and top.fullText ~= nil and not menuOpen
    if top and top.fullText then
        nativeTooltip.content = top.fullText
        nativeTooltip:SetSize(224, 22)
        nativeTooltipBox:SetSize(240, 30)
    end
    handlers.Draw({})
end
local function clickSetting(prefix)
    for _, child in ipairs(settingsHost.children) do child:Destroy() end
    settingsHost.children = {}
    handlers.SettingsLayerReady({component=settingsHost})
    for _, control in ipairs(widgets) do
        if control.kind == "Button" and not control.destroyed and control.label:find(prefix, 1, true) == 1 then
            control.hooks[ui.Hook.ONBUTTONPRESSED](control)
            return control
        end
    end
    error("Missing setting: " .. prefix)
end
local function nativeHasCount()
    return nativeTooltip.content:find("<col=80d8ff>", 1, true) ~= nil
end
local function expectedNative(name, count)
    return "Mine <col=ffff00>" .. name .. "</col> <col=80d8ff>(" .. count .. ")</col>"
end

test("hover edits the existing native tooltip instead of creating another box", function()
    boot({numberOnly=true})
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local originalWidgets = #widgets
    hover({rock("Copper rock")})
    equal(nativeTooltip.content, "Mine <col=ffff00>Copper rock</col> <col=80d8ff>(17)</col>")
    equal(#widgets, originalWidgets)
    equal(nativeTooltip.destroyed, nil)
    equal(nativeTooltipBox.destroyed, nil)
end)

test("Draw updates native hover text generated after MiniMenuReady", function()
    boot({numberOnly=true})
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local entry = rock("Copper rock")
    handlers.MiniMenuReady({miniMenu={entries={entry}}})
    nativeTooltip.content = entry.fullText
    equal(nativeHasCount(), false)
    handlers.Draw({})
    equal(nativeTooltip.content, expectedNative("Copper rock", "17"))
    assert(entry.overrideText:find("(17)", 1, true))
end)

test("tier matching hides unsupported counts from both native hover and menu", function()
    boot({numberOnly=true})
    nativeBag = {{obj={id=44779}, count=1}}
    for _, spirit in ipairs(Catalog.spirits) do nativeValues[spirit.varName] = field(spirit, 17) end
    local iron = rock("Iron rock")
    hover({iron})
    equal(nativeHasCount(), true)
    local button = clickSetting("Match carried ore-box tier")
    equal(button.label, "Match carried ore-box tier: On")
    equal(saved.limitToBoxTier, true)
    hover({iron})
    equal(iron.overrideText, "")
    equal(nativeHasCount(), false)
    for _, name in ipairs({"Copper rock", "Tin rock"}) do
        local entry = rock(name)
        hover({entry})
        assert(entry.overrideText:find("(17)", 1, true))
        equal(nativeTooltip.content, expectedNative(name, "17"))
    end
    clickSetting("Match carried ore-box tier")
    hover({iron})
    equal(nativeTooltip.content, expectedNative("Iron rock", "17"))
end)

test("banking the highest box lowers the native hover and menu display limit", function()
    boot({limitToBoxTier=true, numberOnly=true})
    nativeBag = {{obj={id=44779}, count=1}, {obj={id=44797}, count=1}}
    local spirit = Catalog.rock("Dark animica rock")
    nativeValues[spirit.varName] = field(spirit, 248)
    local entry = rock("Dark animica rock")
    hover({entry})
    equal(nativeTooltip.content, expectedNative("Dark animica rock", "248"))
    nativeBag = {{obj={id=44779}, count=1}}
    handlers.InventoryUpdated({inv={id=93}})
    handlers.InventoryUpdated({inv={id=95}})
    hover({entry})
    equal(entry.overrideText, "")
    equal(nativeHasCount(), false)
    nativeBag = {{obj={id=44797}, count=1}}
    handlers.InventoryUpdated({inv={id=93}})
    hover({entry})
    equal(nativeTooltip.content, expectedNative("Dark animica rock", "248"))
end)

test("tier matching survives reload", function()
    boot()
    clickSetting("Match carried ore-box tier")
    local persisted = saved
    PluginShutdown()
    boot(persisted)
    nativeBag = {{obj={id=44779}, count=1}}
    local spirit = Catalog.rock("Iron rock")
    nativeValues[spirit.varName] = field(spirit, 17)
    local entry = rock("Iron rock")
    hover({entry})
    equal(entry.overrideText, nil)
    equal(nativeHasCount(), false)
end)

test("counts update in the existing hover box and right-click menu", function()
    boot()
    nativeBag = {{obj={id=44797}, count=1}}
    local value = field(copper, 248)
    nativeValues[copper.varName] = value
    local entry = rock("Copper rock")
    hover({entry})
    equal(entry.overrideText, expectedNative("Copper rock", "248 Copper Stone Spirits"))
    equal(nativeTooltip.content, expectedNative("Copper rock", "248 Copper Stone Spirits"))
    equal(entry.actionType, 3)
    value.value = 247
    hover({entry})
    equal(nativeTooltip.content, expectedNative("Copper rock", "247 Copper Stone Spirits"))
end)

test("number only applies to the existing native hover and menu, including zero and unknown", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    equal(clickSetting("Number only").label, "Number only: On")
    equal(saved.numberOnly, true)
    local entry = rock("Copper rock")
    hover({entry})
    equal(nativeTooltip.content, expectedNative("Copper rock", "17"))
    equal(entry.overrideText, nativeTooltip.content)
    nativeValues[copper.varName].value = 0
    hover({entry})
    equal(nativeTooltip.content, expectedNative("Copper rock", "0"))
    nativeValues[copper.varName] = nil
    hover({entry})
    equal(nativeTooltip.content, expectedNative("Copper rock", "?"))
end)

test("hover toggle restores native text and size while retaining the menu count", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    hover({rock("Copper rock")})
    equal(clickSetting("Show count on hover").label, "Show count on hover: Off")
    equal(nativeTooltip.content, "Mine <col=ffff00>Copper rock</col>")
    equal(nativeTooltipBox.width, 240)
    equal(nativeTooltip.width, 224)
    equal(nativeTooltip.visibleGlobal, true)
    local entry = rock("Copper rock")
    hover({entry})
    equal(nativeHasCount(), false)
    assert(entry.overrideText:find("17 Copper Stone Spirits", 1, true))
end)

test("hover and number-only settings survive plugin reload", function()
    boot({showHoverCount=false, numberOnly=true})
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local entry = rock("Copper rock")
    hover({entry})
    equal(nativeHasCount(), false)
    assert(entry.overrideText:find("(17)", 1, true))
    clickSetting("Show count on hover")
    hover({entry})
    equal(nativeTooltip.content, expectedNative("Copper rock", "17"))
    local persisted = saved
    PluginShutdown()
    boot(persisted)
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    hover({rock("Copper rock")})
    equal(nativeTooltip.content, expectedNative("Copper rock", "17"))
end)

test("unrelated UI, right-click menus and lost focus stop native hover annotation", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local entry = rock("Copper rock")
    hover({entry})
    hover({entry, {actionEntryType=1, fullText="Bank chest"}})
    equal(nativeTooltip.content, "Bank chest")
    hover({entry})
    hover({})
    equal(nativeHasCount(), false)
    hover({entry})
    menuOpen = true
    handlers.MiniMenuOpened({})
    equal(nativeHasCount(), false)
    hover({entry})
    equal(nativeHasCount(), false)
    menuOpen = false
    hover({entry})
    handlers.WindowFocusChanged({hasFocus=false})
    equal(nativeHasCount(), false)
    hover({entry})
    equal(nativeHasCount(), false)
    handlers.WindowFocusChanged({hasFocus=true})
    hover({entry})
    equal(nativeHasCount(), true)
end)

test("repeated Draws and native text rewrites do not duplicate counts or expand the box repeatedly", function()
    boot({numberOnly=true})
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local entry = rock("Copper rock")
    hover({entry})
    local width = nativeTooltipBox.width
    assert(width > 240)
    for _=1,5 do handlers.Draw({}) end
    equal(nativeTooltipBox.width, width)
    nativeTooltip.content = entry.fullText
    handlers.Draw({})
    equal(nativeTooltip.content, expectedNative("Copper rock", "17"))
    equal(nativeTooltipBox.width, width)
    PluginShutdown()
    equal(nativeTooltipBox.width, 240)
    equal(nativeTooltip.width, 224)
    equal(nativeTooltip.content, entry.fullText)
    equal(nativeTooltip.destroyed, nil)
end)

test("native hover retains other plugin text and skips unrelated or hidden tooltip content", function()
    boot({numberOnly=true})
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local entry = rock("Copper rock")
    handlers.MiniMenuReady({miniMenu={entries={entry}}})
    nativeTooltip.content = "Mine Copper rock [other plugin]"
    handlers.Draw({})
    equal(nativeTooltip.content, "Mine Copper rock [other plugin] <col=80d8ff>(17)</col>")
    nativeTooltip.content = "Bank chest"
    handlers.Draw({})
    equal(nativeTooltip.content, "Bank chest")
    nativeTooltip.content, nativeTooltip.visibleGlobal = entry.fullText, false
    handlers.Draw({})
    equal(nativeTooltip.content, entry.fullText)
    equal(nativeTooltip.visibleGlobal, false)
end)

test("game state changes restore the native tooltip without destroying its components", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local entry = rock("Copper rock")
    hover({entry})
    handlers.GameStateChanged({})
    equal(nativeTooltip.content, entry.fullText)
    equal(nativeTooltipBox.width, 240)
    equal(nativeTooltip.destroyed, nil)
    hover({entry})
    equal(nativeHasCount(), true)
end)

test("real entrypoint reads all 17 spirits using the actual dump bindings", function()
    boot()
    nativeBag = {{obj={id=44797}, count=1}}
    for index, spirit in ipairs(Catalog.spirits) do
        nativeValues[spirit.varName] = field(spirit, index)
        local entry = rock(spirit.name .. " rock")
        hover({entry})
        assert(entry.overrideText:find(Catalog.label(spirit, index), 1, true))
    end
end)

test("real entrypoint annotates mine and examine without changing either action", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 248)
    local mine, examine = rock("Copper rock"), rock("Copper rock")
    examine.fullText, examine.actionType = "Examine Copper rock", 1002
    hover({mine, examine})
    assert(mine.overrideText:find("248 Copper Stone Spirits", 1, true))
    assert(examine.overrideText:find("248 Copper Stone Spirits", 1, true))
    equal(mine.actionType, 3)
    equal(examine.actionType, 1002)
end)

test("real entrypoint leaves unrelated menus and missing boxes unchanged", function()
    boot()
    local entry = rock("Copper rock")
    hover({entry})
    equal(entry.overrideText, nil)
    nativeBag = {{obj={id=44779}, count=1}}
    handlers.InventoryUpdated({inv={id=93}})
    local npc, item, sand = rock("Copper rock"), rock("Copper rock"), rock("Sandstone rock")
    npc.actionEntryType, item.actionEntryType = 4, 2
    hover({npc, item, sand})
    equal(npc.overrideText, nil)
    equal(item.overrideText, nil)
    equal(sand.overrideText, nil)
end)

test("real entrypoint preserves other plugin text and reports unknown storage", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    local entry = rock("Copper rock")
    entry.overrideText = "Mine Copper rock [other plugin]"
    hover({entry})
    equal(entry.overrideText, "Mine Copper rock [other plugin] <col=80d8ff>(Copper Stone Spirits: unavailable)</col>")
end)

test("real entrypoint updates after deposit and resumes on withdrawal", function()
    boot()
    nativeValues[copper.varName] = field(copper, 248)
    nativeBag = {{obj={id=44779}, count=1}}
    local entry = rock("Copper rock")
    hover({entry})
    assert(entry.overrideText)
    nativeBag = {}
    handlers.InventoryUpdated({inv={id=93}})
    hover({entry})
    equal(entry.overrideText, "")
    equal(nativeHasCount(), false)
    entry = rock("Copper rock")
    hover({entry})
    equal(entry.overrideText, nil)
    nativeBag = {{obj={id=44797}, count=1}}
    handlers.InventoryAdded({inv={id=93}})
    entry = rock("Copper rock")
    hover({entry})
    assert(entry.overrideText:find("248 Copper Stone Spirits", 1, true))
end)

test("diagnostic recorder finds an alternative rock label without modifying it", function()
    boot()
    nativeTooltip.visibleGlobal = false
    local alternative = {type=ui.ComponentType.LABEL, content="Copper rock", visibleGlobal=true,
        isRestricted=false, parent={staticID=7}}
    nativePanels[1489] = {[13]=alternative}
    local lines = {}
    local recorder = require("lib/hover_diagnostics").new(function(line) lines[#lines+1]=line end)
    recorder:draw(1, "idle")
    equal(uiLookups, 0)
    recorder:start()
    for _=1,50 do
        local before = uiLookups
        recorder:draw(0.1, "native TEXT_TOOLTIP label 15 hidden")
        assert(uiLookups - before <= 16)
    end
    if recorder:active() then recorder:draw(0.1, "native TEXT_TOOLTIP label 15 hidden") end
    equal(recorder:active(), false)
    equal(alternative.content, "Copper rock")
    local report = table.concat(lines, "\n")
    assert(report:find("TOPLEVEL_V2_HOVER_TARGET static=13", 1, true))
    assert(report:find("parentStatic=7", 1, true))
    assert(report:find("REPORT END", 1, true))
    local before = uiLookups
    recorder:draw(1, "idle")
    equal(uiLookups, before)
end)

test("settings diagnostic records actual target and options without saving a new setting", function()
    boot({showHoverCount=false})
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 17)
    local before = #widgets
    clickSetting("Record hover diagnostics")
    equal(saved.limitToBoxTier, nil)
    handlers.MiniMenuReady({miniMenu={entries={rock("Copper rock")}}})
    for _=1,21 do handlers.Draw({timeDeltaSecs=0.25}) end
    local report = table.concat(logs, "\n")
    assert(report:find("enabled=false", 1, true))
    assert(report:find("hasBox=true", 1, true))
    assert(report:find("topSubject=Copper rock", 1, true))
    assert(report:find("REPORT END", 1, true))
    local after = #widgets
    handlers.Draw({timeDeltaSecs=1})
    equal(#widgets, after)
end)

test("diagnostic scan tolerates unavailable panel names and terminates", function()
    boot()
    id.Interface.TOPLEVEL_V2_HOVER_TARGET = nil
    local lines = {}
    local recorder = require("lib/hover_diagnostics").new(function(line) lines[#lines+1]=line end)
    recorder:start()
    for _=1,600 do recorder:draw(nil, "no hover target") end
    equal(recorder:active(), false)
    assert(table.concat(lines, "\n"):find("REPORT END", 1, true))
end)

test("completed hover report is available in an enabled selectable settings field", function()
    boot()
    nativeBag = {{obj={id=44779}, count=1}}
    nativeValues[copper.varName] = field(copper, 15)
    clickSetting("Record hover diagnostics")
    hover({rock("Copper rock")})
    for _=1,21 do handlers.Draw({timeDeltaSecs=0.25}) end
    clickSetting("Show diagnostic report")
    local field
    for _, widget in ipairs(widgets) do
        if widget.kind == "InputField" and not widget.destroyed then field = widget end
    end
    assert(field, "A selectable report field must be available")
    assert(field.enabled ~= false and field.clickthrough ~= true)
    equal(field.visibility, ui.TextContentVisibilityMode.VISIBLE)
    equal(field.filterMode, ui.InputFieldFilterMode.NONE)
    assert(field.maxLength >= #field.content)
    for _, text in ipairs({"REPORT BEGIN", "REPORT END", "menus:", "states:", "panels:", "labels:", "Copper rock"}) do
        assert(field.content:find(text, 1, true), "Missing report section " .. text)
    end
    assert(field.height >= 100)
    local snapshot = field.content
    for _=1,5 do handlers.Draw({timeDeltaSecs=1}) end
    equal(field.content, snapshot)
    field.content = "An accidental edit must not alter the stored report"
    clickSetting("Show diagnostic report")
    for _, widget in ipairs(widgets) do
        if widget.kind == "InputField" and not widget.destroyed then equal(widget.content, snapshot) end
    end
end)

test("opening the report before recording explains how to create it", function()
    boot()
    clickSetting("Show diagnostic report")
    local found = false
    for _, widget in ipairs(widgets) do
        if widget.kind == "InputField" and not widget.destroyed then
            found = true
            assert(widget.content:find("No completed report yet", 1, true))
        end
    end
    equal(found, true)
end)

test("completed report stays available while a new recording is in progress", function()
    boot()
    local recorder = require("lib/hover_diagnostics").new(function() end)
    recorder:start()
    for _=1,21 do recorder:draw(0.25, "original captured state") end
    local first = recorder:report()
    assert(first:find("REPORT END", 1, true))
    recorder:start()
    equal(recorder:report(), first)
    recorder:draw(0.25, "next state")
    equal(recorder:report(), first)
end)

test("real entrypoint has no Logic callback and unsubscribes on shutdown", function()
    boot()
    equal(type(handlers.Draw), "function")
    equal(handlers.Logic, nil)
    equal(Event.PluginShutdown, nil)
    equal(type(PluginShutdown), "function")
    PluginShutdown()
    equal(next(handlers), nil)
end)

print(string.format("%d checks passed. Native hover rendering still requires in-game validation.", total))
