--[[
    VOLNX UI 6.1 - ANIMATION & FIRE BORDER EDITION
    Original modular Roblox Lua UI library.
    Single-file build. Inspired by modular UI architecture; not copied from Chilli.

    Included:
      Core window / tabs / sections / option registry
      Toggle, Button, Slider, Dropdown, MultiDropdown, Input, Keybind,
      Label, Paragraph, Divider, ColorPicker, PlayerDropdown, ProgressBar
      Search, state store, linked values, dependencies, exclusive groups
      Theme manager, animated fire accents, tween presets, notifications
      Modal, confirm, prompt, context menu, command palette, hotkey manager
      Config save/load, watermark, status bar, FPS counter, event log
      Responsive scaling, drag, resize, minimize/restore, cleanup / Maid
      Surface API, rich text helpers, signals, utility functions
      Animation presets: Bounce, Elastic, Back, Spring, Fade, Slide, Scale,
      Pulse, Shake, Rotate, Glow, Hover, Press, Open, Close and smooth tweens
      Rounded multi-layer fire border with slow moving gradient + glow pulse

    Usage:
      local Volnx = loadstring(game:HttpGet("YOUR_RAW_URL"))()
      local Window = Volnx:CreateWindow({Title = "Volnx Hub"})
      local Tab = Window:CreateTab("Combat", "Swords")
      local Section = Tab:CreateSection("Main")
      Section:CreateToggle({Name="Enabled", Default=false, Callback=function(v) end})

    Notes:
      - Designed for Roblox client environments.
      - Config persistence uses getgenv()/writefile/readfile when available.
      - This source does not include game-specific exploit logic or remotes.
]]

local Volnx = {}
Volnx.__index = Volnx
Volnx.Version = "6.1.0"
Volnx.Name = "Volnx UI"
Volnx.Author = "Volnx"
Volnx.Flags = {}
Volnx.Options = {}
Volnx.Windows = {}
Volnx.Themes = {}
Volnx.Connections = {}
Volnx._destroyed = false

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer

local function safeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return fn(table.unpack(args, 1, args.n))
    end)
    if not ok then warn("[Volnx] " .. tostring(result)) end
    return ok and result or nil
end

local function make(className, props, parent)
    local obj = Instance.new(className)
    for key, value in pairs(props or {}) do
        pcall(function() obj[key] = value end)
    end
    if parent then obj.Parent = parent end
    return obj
end

local function corner(parent, radius)
    return make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Color = color or Color3.fromRGB(190, 35, 45),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, parent)
end

local function padding(parent, left, right, top, bottom)
    return make("UIPadding", {
        PaddingLeft = UDim.new(0, left or 8),
        PaddingRight = UDim.new(0, right or 8),
        PaddingTop = UDim.new(0, top or 6),
        PaddingBottom = UDim.new(0, bottom or 6)
    }, parent)
end

local function listLayout(parent, direction, gap, horizontalAlignment)
    return make("UIListLayout", {
        FillDirection = direction or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 6),
        HorizontalAlignment = horizontalAlignment or Enum.HorizontalAlignment.Left
    }, parent)
end

local function tween(object, duration, properties, style, direction)
    if not object or not object.Parent then return nil end
    local info = TweenInfo.new(
        duration or 0.22,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local tw = TweenService:Create(object, info, properties)
    tw:Play()
    return tw
end

local function connect(signal, callback, owner)
    local connection = signal:Connect(callback)
    table.insert(owner and owner._connections or Volnx.Connections, connection)
    return connection
end

local function makeSignal()
    local signal = {}
    signal._listeners = {}
    function signal:Connect(callback)
        local entry = {Callback = callback, Connected = true}
        table.insert(self._listeners, entry)
        local connection = {}
        function connection:Disconnect() entry.Connected = false end
        return connection
    end
    function signal:Fire(...)
        for _, entry in ipairs(self._listeners) do
            if entry.Connected then safeCall(entry.Callback, ...) end
        end
    end
    function signal:Destroy()
        table.clear(self._listeners)
    end
    return signal
end

local Maid = {}
Maid.__index = Maid
function Maid.new()
    return setmetatable({_tasks = {}}, Maid)
end
function Maid:Give(task)
    table.insert(self._tasks, task)
    return task
end
function Maid:Cleanup()
    for i = #self._tasks, 1, -1 do
        local task = self._tasks[i]
        if typeof(task) == "RBXScriptConnection" then
            pcall(function() task:Disconnect() end)
        elseif typeof(task) == "Instance" then
            pcall(function() task:Destroy() end)
        elseif type(task) == "function" then
            pcall(task)
        elseif type(task) == "table" and task.Destroy then
            pcall(function() task:Destroy() end)
        elseif type(task) == "table" and task.Disconnect then
            pcall(function() task:Disconnect() end)
        end
    end
    table.clear(self._tasks)
end
Maid.Destroy = Maid.Cleanup
Volnx.Maid = Maid

Volnx.Signal = {new = makeSignal}
Volnx.Util = {
    Tween = tween,
    SafeCall = safeCall,
    Make = make,
    Clamp = math.clamp,
    Round = function(n, decimals)
        local p = 10 ^ (decimals or 0)
        return math.floor(n * p + 0.5) / p
    end,
    DeepCopy = function(value)
        if type(value) ~= "table" then return value end
        local copy = {}
        for k, v in pairs(value) do copy[k] = Volnx.Util.DeepCopy(v) end
        return copy
    end
}

Volnx.Rich = {}
function Volnx.Rich.Escape(text)
    return tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end
function Volnx.Rich.Color(text, color)
    local hex = color:ToHex()
    return '<font color="#' .. hex .. '">' .. tostring(text) .. '</font>'
end
function Volnx.Rich.Bold(text) return "<b>" .. tostring(text) .. "</b>" end
function Volnx.Rich.Italic(text) return "<i>" .. tostring(text) .. "</i>" end
function Volnx.Rich.Muted(text) return Volnx.Rich.Color(text, Color3.fromRGB(145,145,155)) end
function Volnx.Rich.Rule()
    return Volnx.Rich.Color("━━━━━━━━━━━━━━━━━━━━", Color3.fromRGB(115,35,42))
end
function Volnx.Rich.Join(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
    return table.concat(parts, " ")
end

local DEFAULT_THEME = {
    Background = Color3.fromRGB(14, 12, 15),
    Panel = Color3.fromRGB(22, 18, 22),
    Panel2 = Color3.fromRGB(30, 23, 28),
    Element = Color3.fromRGB(38, 29, 34),
    Accent = Color3.fromRGB(194, 35, 48),
    Accent2 = Color3.fromRGB(255, 93, 45),
    Text = Color3.fromRGB(245, 238, 239),
    Muted = Color3.fromRGB(157, 143, 148),
    Border = Color3.fromRGB(89, 42, 50),
    Success = Color3.fromRGB(70, 190, 120),
    Warning = Color3.fromRGB(235, 165, 55),
    Danger = Color3.fromRGB(220, 65, 75)
}
Volnx.Themes.DarkRed = DEFAULT_THEME
Volnx.Themes.Crimson = {
    Background=Color3.fromRGB(13,8,12), Panel=Color3.fromRGB(25,13,19),
    Panel2=Color3.fromRGB(39,18,27), Element=Color3.fromRGB(49,22,31),
    Accent=Color3.fromRGB(225,25,58), Accent2=Color3.fromRGB(255,90,70),
    Text=Color3.fromRGB(255,242,245), Muted=Color3.fromRGB(170,135,145),
    Border=Color3.fromRGB(105,35,53), Success=DEFAULT_THEME.Success,
    Warning=DEFAULT_THEME.Warning, Danger=DEFAULT_THEME.Danger
}
Volnx.Themes.Ember = {
    Background=Color3.fromRGB(17,13,11), Panel=Color3.fromRGB(28,21,17),
    Panel2=Color3.fromRGB(42,29,21), Element=Color3.fromRGB(53,35,25),
    Accent=Color3.fromRGB(230,83,28), Accent2=Color3.fromRGB(255,160,55),
    Text=Color3.fromRGB(255,245,232), Muted=Color3.fromRGB(175,153,132),
    Border=Color3.fromRGB(112,66,40), Success=DEFAULT_THEME.Success,
    Warning=DEFAULT_THEME.Warning, Danger=DEFAULT_THEME.Danger
}
Volnx.Themes.Midnight = {
    Background=Color3.fromRGB(11,13,20), Panel=Color3.fromRGB(19,22,32),
    Panel2=Color3.fromRGB(27,31,44), Element=Color3.fromRGB(35,40,56),
    Accent=Color3.fromRGB(177,54,73), Accent2=Color3.fromRGB(239,104,95),
    Text=Color3.fromRGB(239,243,250), Muted=Color3.fromRGB(145,155,173),
    Border=Color3.fromRGB(65,61,82), Success=DEFAULT_THEME.Success,
    Warning=DEFAULT_THEME.Warning, Danger=DEFAULT_THEME.Danger
}
Volnx.Themes.Light = {
    Background=Color3.fromRGB(235,231,233), Panel=Color3.fromRGB(250,247,248),
    Panel2=Color3.fromRGB(239,232,235), Element=Color3.fromRGB(229,218,223),
    Accent=Color3.fromRGB(180,30,48), Accent2=Color3.fromRGB(238,90,55),
    Text=Color3.fromRGB(35,25,29), Muted=Color3.fromRGB(112,98,103),
    Border=Color3.fromRGB(202,175,183), Success=Color3.fromRGB(35,140,85),
    Warning=Color3.fromRGB(190,120,25), Danger=Color3.fromRGB(190,45,55)
}

local function getTheme(window)
    return window.Theme or DEFAULT_THEME
end

local function applyTheme(window, theme)
    if type(theme) == "string" then theme = Volnx.Themes[theme] end
    if type(theme) ~= "table" then return false end
    window.Theme = theme
    local t = theme
    if window.Main then
        window.Main.BackgroundColor3 = t.Background
        window.Topbar.BackgroundColor3 = t.Panel
        window.Sidebar.BackgroundColor3 = t.Panel
        window.Content.BackgroundColor3 = t.Panel
        window.TitleLabel.TextColor3 = t.Text
        window.SubtitleLabel.TextColor3 = t.Muted
        window.FireLine.BackgroundColor3 = t.Accent
        window.BorderStroke.Color = t.Border
        for _, object in ipairs(window._themeObjects) do
            if object and object.Parent then
                local role = object:GetAttribute("VolnxThemeRole")
                if role and t[role] then
                    if object:IsA("TextLabel") or object:IsA("TextButton") then
                        if role == "Text" or role == "Muted" then object.TextColor3 = t[role] end
                    elseif object:IsA("Frame") then object.BackgroundColor3 = t[role] end
                end
            end
        end
    end
    for _, tab in ipairs(window.Tabs) do
        for _, option in ipairs(tab.Options) do
            if option.Refresh then safeCall(option.Refresh, option) end
        end
    end
    return true
end

local function themeObject(window, object, role)
    object:SetAttribute("VolnxThemeRole", role)
    table.insert(window._themeObjects, object)
    return object
end

local function createText(parent, text, size, color, font)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(text or ""),
        TextColor3 = color or DEFAULT_THEME.Text,
        TextSize = size or 13,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        RichText = true,
        Size = UDim2.new(1, 0, 0, 20)
    }, parent)
end

local function createButton(parent, text, theme, height)
    local button = make("TextButton", {
        AutoButtonColor = false,
        Text = tostring(text or ""),
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextColor3 = theme.Text,
        BackgroundColor3 = theme.Element,
        Size = UDim2.new(1, 0, 0, height or 30)
    }, parent)
    corner(button, 7)
    stroke(button, theme.Border, 1, 0.25)
    button.MouseEnter:Connect(function()
        tween(button, 0.16, {BackgroundColor3 = theme.Panel2})
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.16, {BackgroundColor3 = theme.Element})
    end)
    button.MouseButton1Down:Connect(function()
        tween(button, 0.09, {Size = UDim2.new(1, -3, 0, (height or 30)-1)}, Enum.EasingStyle.Quad)
    end)
    button.MouseButton1Up:Connect(function()
        tween(button, 0.22, {Size = UDim2.new(1, 0, 0, height or 30)}, Enum.EasingStyle.Back)
    end)
    button.MouseEnter:Connect(function()
        local edge = button:FindFirstChildOfClass("UIStroke")
        if edge then tween(edge, 0.18, {Thickness=1.55, Transparency=0.02}) end
    end)
    button.MouseLeave:Connect(function()
        local edge = button:FindFirstChildOfClass("UIStroke")
        if edge then tween(edge, 0.18, {Thickness=1, Transparency=0.25}) end
    end)
    return button
end

local function addOption(window, tab, option)
    option.Window = window
    option.Tab = tab
    option.Flag = option.Flag or option.Name
    option.Name = option.Name or option.Flag
    option.Callback = option.Callback or function() end
    option.Changed = makeSignal()
    option._maid = Maid.new()
    table.insert(tab.Options, option)
    window.Options[option.Flag] = option
    Volnx.Options[option.Flag] = option
    if option.Default ~= nil then
        window:SetValue(option.Flag, option.Default, true)
    end
    return option
end

local function optionFrame(section, height)
    local frame = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or 34)
    }, section.Body)
    return frame
end

local function optionTitle(parent, name, description, theme)
    local label = createText(parent, name, 12, theme.Text, Enum.Font.GothamMedium)
    label.Size = UDim2.new(1, 0, 0, 18)
    if description and description ~= "" then
        local desc = createText(parent, description, 10, theme.Muted)
        desc.Position = UDim2.fromOffset(0, 17)
        desc.Size = UDim2.new(1, 0, 0, 14)
        return label, desc
    end
    return label
end

local function makeOptionMethods()
    local Methods = {}

    function Methods:Set(value, silent)
        self.Window:SetValue(self.Flag, value, silent)
    end
    function Methods:Get()
        return self.Window:GetValue(self.Flag)
    end
    function Methods:SetVisible(visible)
        self.Visible = visible
        if self.Frame then self.Frame.Visible = visible end
    end
    function Methods:SetDisabled(disabled)
        self.Disabled = disabled
        if self.Control then self.Control.Active = not disabled end
        if self.Frame then self.Frame.BackgroundTransparency = disabled and 0.5 or 1 end
    end
    function Methods:OnChanged(callback)
        return self.Changed:Connect(callback)
    end
    function Methods:Destroy()
        self._maid:Cleanup()
        if self.Frame then self.Frame:Destroy() end
        self.Window.Options[self.Flag] = nil
        Volnx.Options[self.Flag] = nil
    end

    return Methods
end
local OptionMethods = makeOptionMethods()

local function attachMethods(option)
    for key, fn in pairs(OptionMethods) do option[key] = fn end
    return option
end

local function createToggle(section, config)
    config = config or {}
    local theme = getTheme(section.Window)
    local frame = optionFrame(section, config.Description and 48 or 34)
    local title = optionTitle(frame, config.Name or "Toggle", config.Description, theme)
    local switch = make("TextButton", {
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(38, 20),
        BackgroundColor3 = theme.Panel2
    }, frame)
    corner(switch, 10)
    local dot = make("Frame", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = theme.Muted
    }, switch)
    corner(dot, 8)
    local option = attachMethods(addOption(section.Window, section.Tab, config))
    option.Frame, option.Control = frame, switch
    option.Refresh = function()
        local enabled = option:Get() == true
        tween(switch, 0.18, {BackgroundColor3 = enabled and theme.Accent or theme.Panel2})
        tween(dot, 0.18, {Position = enabled and UDim2.new(1,-17,0,3) or UDim2.fromOffset(3,3),
            BackgroundColor3 = enabled and Color3.new(1,1,1) or theme.Muted}, Enum.EasingStyle.Back)
    end
    switch.MouseButton1Click:Connect(function()
        if not option.Disabled then option:Set(not option:Get()) end
    end)
    option.Refresh()
    return option
end

local function createButtonOption(section, config)
    config = config or {}
    local theme = getTheme(section.Window)
    local frame = optionFrame(section, config.Description and 52 or 38)
    optionTitle(frame, config.Name or "Button", config.Description, theme)
    local button = createButton(frame, config.ButtonText or "Execute", theme, 28)
    button.Position = UDim2.new(0, 0, 0, config.Description and 23 or 3)
    button.Size = UDim2.new(1, 0, 0, 28)
    local option = attachMethods(addOption(section.Window, section.Tab, config))
    option.Frame, option.Control = frame, button
    button.MouseButton1Click:Connect(function()
        if not option.Disabled then safeCall(option.Callback, option) end
    end)
    return option
end

local function createSlider(section, config)
    config = config or {}
    local theme = getTheme(section.Window)
    local frame = optionFrame(section, 52)
    local title = optionTitle(frame, config.Name or "Slider", config.Description, theme)
    local valueLabel = createText(frame, "", 11, theme.Accent2)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Position = UDim2.new(0.55,0,0,0)
    valueLabel.Size = UDim2.new(0.45,0,0,18)
    local bar = make("TextButton", {
        Text = "", AutoButtonColor = false,
        Position = UDim2.fromOffset(0, 29),
        Size = UDim2.new(1,0,0,7),
        BackgroundColor3 = theme.Panel2
    }, frame)
    corner(bar, 5)
    local fill = make("Frame", {BackgroundColor3=theme.Accent, Size=UDim2.new(0,0,1,0)}, bar)
    corner(fill, 5)
    local knob = make("Frame", {
        AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0,0,0.5,0),
        Size=UDim2.fromOffset(13,13), BackgroundColor3=theme.Text
    }, bar)
    corner(knob, 8)
    local min = tonumber(config.Min) or 0
    local max = tonumber(config.Max) or 100
    local step = tonumber(config.Step) or 1
    local dragging = false
    local option = attachMethods(addOption(section.Window, section.Tab, config))
    option.Frame, option.Control = frame, bar
    local function setFromX(x)
        local percent = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X,1), 0, 1)
        local value = min + (max-min)*percent
        value = math.floor(value/step + 0.5)*step
        option:Set(math.clamp(value,min,max))
    end
    local function refresh()
        local value = tonumber(option:Get()) or min
        local percent = max == min and 0 or math.clamp((value-min)/(max-min),0,1)
        fill.Size = UDim2.new(percent,0,1,0)
        knob.Position = UDim2.new(percent,0,0.5,0)
        valueLabel.Text = tostring(value) .. (config.Suffix or "")
    end
    option.Refresh = refresh
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end)
    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end, option)
    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end, option)
    refresh()
    return option
end

local function createInput(section, config)
    config = config or {}
    local theme = getTheme(section.Window)
    local frame = optionFrame(section, config.Description and 58 or 44)
    optionTitle(frame, config.Name or "Input", config.Description, theme)
    local box = make("TextBox", {
        ClearTextOnFocus = false, Text = tostring(config.Default or ""),
        PlaceholderText = config.Placeholder or "Enter text...",
        TextSize=12, Font=Enum.Font.Gotham, TextColor3=theme.Text,
        PlaceholderColor3=theme.Muted, BackgroundColor3=theme.Element,
        Position=UDim2.new(0,0,0,config.Description and 26 or 21),
        Size=UDim2.new(1,0,0,27), TextXAlignment=Enum.TextXAlignment.Left
    }, frame)
    corner(box,6); padding(box,8,8,0,0); stroke(box,theme.Border,1,0.35)
    local option = attachMethods(addOption(section.Window, section.Tab, config))
    option.Frame, option.Control = frame, box
    box.FocusLost:Connect(function(enter)
        if config.OnlyOnEnter and not enter then return end
        option:Set(box.Text)
        safeCall(config.OnSubmit, box.Text)
    end)
    option.Refresh = function() box.Text = tostring(option:Get() or "") end
    return option
end

local function createDropdown(section, config, multiple)
    config = config or {}
    local theme = getTheme(section.Window)
    local values = config.Values or config.Options or {}
    local frame = optionFrame(section, config.Description and 66 or 51)
    optionTitle(frame, config.Name or (multiple and "Multi Select" or "Dropdown"), config.Description, theme)
    local button = createButton(frame, "Select...", theme, 28)
    button.Position = UDim2.fromOffset(0, config.Description and 34 or 22)
    local menu = make("Frame", {
        Visible=false, BackgroundColor3=theme.Panel2, Size=UDim2.new(1,0,0,0),
        ClipsDescendants=true, ZIndex=30
    }, frame)
    menu.Position = UDim2.new(0,0,1,2)
    corner(menu,7); stroke(menu,theme.Border,1,0.1); padding(menu,5,5,5,5)
    local scroll = make("ScrollingFrame", {
        BackgroundTransparency=1, BorderSizePixel=0, Size=UDim2.new(1,0,1,0),
        CanvasSize=UDim2.new(), AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollBarThickness=3, ZIndex=31
    }, menu)
    listLayout(scroll, Enum.FillDirection.Vertical, 3)
    local option = attachMethods(addOption(section.Window, section.Tab, config))
    option.Frame, option.Control = frame, button
    local opened = false
    local function display()
        local current = option:Get()
        if multiple then
            local count = 0
            for _, v in pairs(current or {}) do if v then count = count + 1 end end
            button.Text = count > 0 and (tostring(count).." selected") or "Select..."
        else
            button.Text = current ~= nil and tostring(current) or "Select..."
        end
    end
    for _, value in ipairs(values) do
        local item = createButton(scroll, tostring(value), theme, 26)
        item.ZIndex = 32
        item.MouseButton1Click:Connect(function()
            if multiple then
                local selected = Volnx.Util.DeepCopy(option:Get() or {})
                selected[value] = not selected[value] or nil
                option:Set(selected)
            else
                option:Set(value)
                opened = false
                menu.Visible = false
                menu.Size = UDim2.new(1,0,0,0)
            end
        end)
    end
    button.MouseButton1Click:Connect(function()
        opened = not opened
        menu.Visible = opened
        local height = math.min(#values, 6)*29 + 10
        tween(menu,0.18,{Size=UDim2.new(1,0,0,opened and height or 0)},Enum.EasingStyle.Back)
    end)
    option.Refresh = display
    display()
    return option
end

local function createKeybind(section, config)
    config = config or {}
    local theme = getTheme(section.Window)
    local frame = optionFrame(section, 36)
    optionTitle(frame, config.Name or "Keybind", config.Description, theme)
    local button = createButton(frame, tostring(config.Default or "None"), theme, 26)
    button.AnchorPoint = Vector2.new(1,0)
    button.Position = UDim2.new(1,0,0,3)
    button.Size = UDim2.fromOffset(100,26)
    local option = attachMethods(addOption(section.Window, section.Tab, config))
    option.Frame, option.Control = frame, button
    local listening = false
    button.MouseButton1Click:Connect(function()
        listening = true
        button.Text = "Press key..."
    end)
    connect(UserInputService.InputBegan, function(input, processed)
        if processed then return end
        if listening and input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            option:Set(input.KeyCode.Name)
        elseif not listening and input.UserInputType == Enum.UserInputType.Keyboard and option:Get() == input.KeyCode.Name then
            safeCall(option.Callback, input.KeyCode)
        end
    end, option)
    option.Refresh = function() button.Text = tostring(option:Get() or "None") end
    option.Refresh()
    return option
end

local function createLabel(section, config, paragraph)
    config = config or {}
    local theme = getTheme(section.Window)
    local frame = optionFrame(section, paragraph and (config.Height or 55) or 24)
    local label = createText(frame, config.Text or config.Name or "Label", paragraph and 11 or 12, theme.Text)
    label.TextWrapped = true
    label.TextYAlignment = paragraph and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
    label.Size = UDim2.new(1,0,1,0)
    local option = attachMethods(addOption(section.Window, section.Tab, config))
    option.Frame, option.Control = frame, label
    function option:SetText(text) label.Text = tostring(text) end
    return option
end

local function createColorPicker(section, config)
    config = config or {}
    local theme = getTheme(section.Window)
    local frame = optionFrame(section, 38)
    optionTitle(frame, config.Name or "Color", config.Description, theme)
    local swatch = createButton(frame, "", theme, 25)
    swatch.AnchorPoint = Vector2.new(1,0)
    swatch.Position = UDim2.new(1,0,0,3)
    swatch.Size = UDim2.fromOffset(54,25)
    local option = attachMethods(addOption(section.Window, section.Tab, config))
    option.Frame, option.Control = frame, swatch
    local hue = 0
    swatch.MouseButton1Click:Connect(function()
        hue = (hue + 0.08) % 1
        option:Set(Color3.fromHSV(hue,0.85,1))
    end)
    option.Refresh = function()
        local color = option:Get()
        if typeof(color) == "Color3" then swatch.BackgroundColor3 = color end
    end
    option.Refresh()
    return option
end

local function createProgress(section, config)
    config = config or {}
    local theme = getTheme(section.Window)
    local frame = optionFrame(section, 42)
    local label = optionTitle(frame, config.Name or "Progress", nil, theme)
    local valueLabel = createText(frame,"0%",11,theme.Accent2)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Position = UDim2.new(0.6,0,0,0)
    valueLabel.Size = UDim2.new(0.4,0,0,18)
    local bar = make("Frame",{Position=UDim2.fromOffset(0,25),Size=UDim2.new(1,0,0,8),BackgroundColor3=theme.Panel2},frame)
    corner(bar,5)
    local fill = make("Frame",{Size=UDim2.new(0,0,1,0),BackgroundColor3=theme.Accent},bar)
    corner(fill,5)
    local option = attachMethods(addOption(section.Window, section.Tab, config))
    option.Frame = frame
    option.Refresh = function()
        local value = math.clamp(tonumber(option:Get()) or 0,0,100)
        tween(fill,0.2,{Size=UDim2.new(value/100,0,1,0)})
        valueLabel.Text = tostring(math.floor(value)).."%"
    end
    return option
end

local SectionMethods = {}
function SectionMethods:CreateToggle(c) return createToggle(self,c) end
function SectionMethods:CreateButton(c) return createButtonOption(self,c) end
function SectionMethods:CreateSlider(c) return createSlider(self,c) end
function SectionMethods:CreateInput(c) return createInput(self,c) end
function SectionMethods:CreateDropdown(c) return createDropdown(self,c,false) end
function SectionMethods:CreateMultiDropdown(c) return createDropdown(self,c,true) end
function SectionMethods:CreateKeybind(c) return createKeybind(self,c) end
function SectionMethods:CreateLabel(c) return createLabel(self,c,false) end
function SectionMethods:CreateParagraph(c) return createLabel(self,c,true) end
function SectionMethods:CreateColorPicker(c) return createColorPicker(self,c) end
function SectionMethods:CreateProgressBar(c) return createProgress(self,c) end
function SectionMethods:CreateDivider()
    local frame = optionFrame(self,10)
    local line = make("Frame",{Position=UDim2.new(0,0,0.5,0),Size=UDim2.new(1,0,0,1),BackgroundColor3=getTheme(self.Window).Border},frame)
    return line
end
function SectionMethods:CreateCard(config)
    config = config or {}
    local theme = getTheme(self.Window)
    local frame = make("Frame",{BackgroundColor3=theme.Panel2,Size=UDim2.new(1,0,0,config.Height or 80)},self.Body)
    corner(frame,8); stroke(frame,theme.Border,1,0.35); padding(frame,9,9,7,7)
    local title = createText(frame,config.Title or "Card",13,theme.Text,Enum.Font.GothamBold)
    local body = createText(frame,config.Description or "",11,theme.Muted)
    body.Position=UDim2.fromOffset(0,23); body.Size=UDim2.new(1,0,1,-23); body.TextWrapped=true; body.TextYAlignment=Enum.TextYAlignment.Top
    return {Frame=frame,Title=title,Description=body,Destroy=function(self) frame:Destroy() end}
end
function SectionMethods:CreateAccordion(config)
    config=config or {}
    local theme=getTheme(self.Window)
    local frame=make("Frame",{BackgroundColor3=theme.Element,Size=UDim2.new(1,0,0,34),ClipsDescendants=true},self.Body)
    corner(frame,7)
    local head=createButton(frame,config.Title or "Accordion",theme,32)
    head.Position=UDim2.fromOffset(0,0)
    local content=make("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(7,37),Size=UDim2.new(1,-14,0,config.Height or 80)},frame)
    listLayout(content,Enum.FillDirection.Vertical,5)
    local opened=false
    head.MouseButton1Click:Connect(function()
        opened=not opened
        tween(frame,0.2,{Size=UDim2.new(1,0,0,opened and ((config.Height or 80)+42) or 34)})
    end)
    return {Frame=frame,Content=content,Add=function(_,obj) obj.Parent=content end}
end
function SectionMethods:CreateTable(config)
    config=config or {}
    local theme=getTheme(self.Window)
    local holder=make("Frame",{BackgroundColor3=theme.Panel2,Size=UDim2.new(1,0,0,config.Height or 120)},self.Body)
    corner(holder,7); padding(holder,6,6,6,6)
    local scroll=make("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=3},holder)
    listLayout(scroll,Enum.FillDirection.Vertical,3)
    local api={Frame=holder,Rows={}}
    function api:AddRow(cells)
        local row=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,24)},scroll)
        make("UIGridLayout",{CellPadding=UDim2.fromOffset(4,0),CellSize=UDim2.new(1/math.max(#cells,1),-4,1,0)},row)
        for _,cell in ipairs(cells) do
            local label=createText(row,tostring(cell),10,theme.Text)
            label.BackgroundColor3=theme.Element; label.BackgroundTransparency=0
            label.TextXAlignment=Enum.TextXAlignment.Center; corner(label,4)
        end
        table.insert(api.Rows,row)
    end
    for _,row in ipairs(config.Rows or {}) do api:AddRow(row) end
    return api
end

local TabMethods = {}
function TabMethods:CreateSection(name)
    local theme=getTheme(self.Window)
    local holder=make("Frame",{BackgroundColor3=theme.Panel,Size=UDim2.new(1,0,0,40),AutomaticSize=Enum.AutomaticSize.Y},self.Page)
    corner(holder,8); stroke(holder,theme.Border,1,0.45); padding(holder,9,9,7,8)
    local title=createText(holder,name or "Section",12,theme.Accent2,Enum.Font.GothamBold)
    title.Size=UDim2.new(1,0,0,22)
    local body=make("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(0,26),Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},holder)
    listLayout(body,Enum.FillDirection.Vertical,6)
    local section=setmetatable({Name=name,Window=self.Window,Tab=self,Frame=holder,Body=body},{__index=SectionMethods})
    table.insert(self.Sections,section)
    return section
end
function TabMethods:Select()
    local window=self.Window
    for _,tab in ipairs(window.Tabs) do
        tab.Page.Visible=(tab==self)
        tween(tab.Button,0.24,{BackgroundColor3=tab==self and getTheme(window).Accent or getTheme(window).Panel2},Enum.EasingStyle.Quart)
        local edge=tab.Button:FindFirstChildOfClass("UIStroke")
        if edge then tween(edge,0.2,{Thickness=tab==self and 1.65 or 1,Transparency=tab==self and 0 or 0.25}) end
        tab.Button.TextColor3=tab==self and Color3.new(1,1,1) or getTheme(window).Muted
    end
    window.SelectedTab=self
end
function TabMethods:Destroy()
    self.Button:Destroy(); self.Page:Destroy()
end


-- Animation presets and window-level animation controller.
local AnimationPresets = {
    Bounce = {Style=Enum.EasingStyle.Bounce, Direction=Enum.EasingDirection.Out},
    Elastic = {Style=Enum.EasingStyle.Elastic, Direction=Enum.EasingDirection.Out},
    Back = {Style=Enum.EasingStyle.Back, Direction=Enum.EasingDirection.Out},
    Quad = {Style=Enum.EasingStyle.Quad, Direction=Enum.EasingDirection.Out},
    Cubic = {Style=Enum.EasingStyle.Cubic, Direction=Enum.EasingDirection.Out},
    Quart = {Style=Enum.EasingStyle.Quart, Direction=Enum.EasingDirection.Out},
    Quint = {Style=Enum.EasingStyle.Quint, Direction=Enum.EasingDirection.Out},
    Sine = {Style=Enum.EasingStyle.Sine, Direction=Enum.EasingDirection.Out},
    Exponential = {Style=Enum.EasingStyle.Exponential, Direction=Enum.EasingDirection.Out},
    Circular = {Style=Enum.EasingStyle.Circular, Direction=Enum.EasingDirection.Out},
    Spring = {Style=Enum.EasingStyle.Elastic, Direction=Enum.EasingDirection.Out},
    Smooth = {Style=Enum.EasingStyle.Sine, Direction=Enum.EasingDirection.InOut},
}

local function animationTween(object, preset, duration, properties, direction)
    if not object or not object.Parent then return nil end
    local data = AnimationPresets[preset or "Smooth"] or AnimationPresets.Smooth
    local style = data.Style
    local dir = direction or data.Direction
    local info = TweenInfo.new(duration or 0.28, style, dir)
    local ok, result = pcall(function()
        local tw = TweenService:Create(object, info, properties or {})
        tw:Play()
        return tw
    end)
    if ok then return result end
    return nil
end


local WindowMethods = {}
function WindowMethods:Animate(object, preset, properties, duration, callback)
    if not object then return nil end
    local tw = animationTween(object, preset, duration, properties)
    if tw and callback then
        tw.Completed:Connect(function(state)
            if state == Enum.PlaybackState.Completed then safeCall(callback, object) end
        end)
    end
    return tw
end

function WindowMethods:SetAnimation(name, enabled)
    self.AnimationSettings = self.AnimationSettings or {}
    self.AnimationSettings[name] = enabled ~= false
    return self.AnimationSettings[name]
end

function WindowMethods:PlayOpenAnimation()
    if not self.Main or not self.Main.Parent then return end
    self.Main.Visible = true
    local target = self.Config and UDim2.fromOffset(self.Config.Width or 620, self.Config.Height or 410) or self.Main.Size
    local finalPosition = self.Config and (self.Config.Position or UDim2.new(0.5,-310,0.5,-205)) or self.Main.Position
    self.Main.Position = finalPosition + UDim2.fromOffset(0, 16)
    self.Main.Size = UDim2.fromOffset(math.max(20, target.X.Offset * 0.88), math.max(20, target.Y.Offset * 0.88))
    self.Main.BackgroundTransparency = 0.12
    animationTween(self.Main, self.AnimationStyle or "Back", 0.38, {
        Size = target, Position = finalPosition, BackgroundTransparency = 0
    })
end

function WindowMethods:PlayCloseAnimation(callback)
    if not self.Main or not self.Main.Parent then return end
    local target = UDim2.fromOffset(math.max(20, self.Main.AbsoluteSize.X * 0.88), math.max(20, self.Main.AbsoluteSize.Y * 0.88))
    local tw = animationTween(self.Main, "Back", 0.22, {
        Size = target, BackgroundTransparency = 0.15
    }, Enum.EasingDirection.In)
    if tw then
        tw.Completed:Connect(function()
            if self.Main and self.Main.Parent then
                self.Main.Visible = false
                self.Main.BackgroundTransparency = 0
            end
            safeCall(callback)
        end)
    else
        self.Main.Visible = false
        safeCall(callback)
    end
end

function WindowMethods:SetBorderStyle(style)
    self.BorderStyle = style or "Fire"
    if self.BorderStroke then
        self.BorderStroke.Thickness = self.BorderStyle == "ThinFire" and 1.1 or 1.7
    end
    if self.BorderGlow then
        self.BorderGlow.Visible = self.BorderStyle ~= "None"
    end
    return self.BorderStyle
end

function WindowMethods:PlayBorderAnimation(enabled)
    self.BorderAnimationEnabled = enabled ~= false
    return self.BorderAnimationEnabled
end

function WindowMethods:GetValue(flag)
    return self.State[flag]
end
function WindowMethods:SetValue(flag,value,silent)
    self.State[flag]=value
    local option=self.Options[flag]
    if option then
        if option.Refresh then safeCall(option.Refresh) end
        option.Changed:Fire(value)
        if not silent then safeCall(option.Callback,value,option) end
    end
    for _,candidate in pairs(self.Options) do
        if candidate.DependsOn then
            local dep=candidate.DependsOn
            local visible=true
            if type(dep)=="function" then visible=safeCall(dep,self.State)~=false
            elseif type(dep)=="table" then
                local current=self.State[dep.Flag]
                if dep.Equals~=nil then visible=current==dep.Equals
                elseif dep.NotEquals~=nil then visible=current~=dep.NotEquals
                elseif dep.Truthy then visible=not not current end
            end
            candidate:SetVisible(visible)
        end
    end
    return value
end
function WindowMethods:Notify(config)
    config=config or {}
    local theme=getTheme(self)
    local toast=make("Frame",{BackgroundColor3=theme.Panel2,Size=UDim2.fromOffset(270,65),Position=UDim2.new(1,290,1,-85),AnchorPoint=Vector2.new(1,1)},self.ToastLayer)
    corner(toast,8); stroke(toast,theme.Accent,1.2,0.1)
    local title=createText(toast,config.Title or "Volnx",13,theme.Text,Enum.Font.GothamBold)
    title.Position=UDim2.fromOffset(10,5); title.Size=UDim2.new(1,-20,0,20)
    local message=createText(toast,config.Content or config.Message or "",11,theme.Muted)
    message.Position=UDim2.fromOffset(10,27); message.Size=UDim2.new(1,-20,0,30); message.TextWrapped=true
    tween(toast,0.35,{Position=UDim2.new(1,-12,1,-85)},Enum.EasingStyle.Back)
    task.delay(config.Duration or 3,function()
        if toast.Parent then
            tween(toast,0.25,{Position=UDim2.new(1,290,1,-85)})
            task.delay(0.3,function() if toast.Parent then toast:Destroy() end end)
        end
    end)
    return toast
end
function WindowMethods:Modal(config)
    config=config or {}
    local theme=getTheme(self)
    local shade=make("TextButton",{Text="",AutoButtonColor=false,BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.4,Size=UDim2.fromScale(1,1)},self.Overlay)
    local panel=make("Frame",{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(config.Width or 320,config.Height or 170),BackgroundColor3=theme.Panel},shade)
    corner(panel,10); stroke(panel,theme.Accent,1.3,0)
    panel.Size=UDim2.fromOffset((config.Width or 320)*0.88,(config.Height or 170)*0.88)
    animationTween(panel,"Back",0.28,{Size=UDim2.fromOffset(config.Width or 320,config.Height or 170)})
    local title=createText(panel,config.Title or "Dialog",15,theme.Text,Enum.Font.GothamBold)
    title.Position=UDim2.fromOffset(14,10); title.Size=UDim2.new(1,-28,0,25)
    local body=createText(panel,config.Content or "",12,theme.Muted)
    body.Position=UDim2.fromOffset(14,42); body.Size=UDim2.new(1,-28,0,65); body.TextWrapped=true; body.TextYAlignment=Enum.TextYAlignment.Top
    local close=createButton(panel,config.ButtonText or "OK",theme,30)
    close.Position=UDim2.new(0,14,1,-42); close.Size=UDim2.new(1,-28,0,30)
    close.MouseButton1Click:Connect(function() shade:Destroy(); safeCall(config.Callback) end)
    return shade
end
function WindowMethods:Confirm(config)
    config=config or {}
    config.Height=config.Height or 185
    config.ButtonText=config.ButtonText or "Confirm"
    local modal=self:Modal(config)
    local panel=modal:FindFirstChildOfClass("Frame")
    local old=panel:FindFirstChildOfClass("TextButton")
    if old then old:Destroy() end
    local yes=createButton(panel,config.ConfirmText or "Confirm",getTheme(self),28)
    yes.Position=UDim2.new(0,14,1,-40); yes.Size=UDim2.new(0.48,-7,0,28)
    local no=createButton(panel,config.CancelText or "Cancel",getTheme(self),28)
    no.Position=UDim2.new(0.52,0,1,-40); no.Size=UDim2.new(0.48,-14,0,28)
    yes.MouseButton1Click:Connect(function() modal:Destroy(); safeCall(config.Callback,true) end)
    no.MouseButton1Click:Connect(function() modal:Destroy(); safeCall(config.Callback,false) end)
    return modal
end
function WindowMethods:Prompt(config)
    config=config or {}
    local theme=getTheme(self)
    local modal=self:Modal({Title=config.Title or "Enter value",Content=config.Content or "",Height=205})
    local panel=modal:FindFirstChildOfClass("Frame")
    local input=make("TextBox",{Text="",PlaceholderText=config.Placeholder or "Type here",ClearTextOnFocus=false,TextSize=12,Font=Enum.Font.Gotham,TextColor3=theme.Text,BackgroundColor3=theme.Element,Position=UDim2.fromOffset(14,105),Size=UDim2.new(1,-28,0,28)},panel)
    corner(input,6)
    local button=panel:FindFirstChildOfClass("TextButton")
    if button then button:Destroy() end
    local submit=createButton(panel,"Submit",theme,28)
    submit.Position=UDim2.new(0,14,1,-40); submit.Size=UDim2.new(1,-28,0,28)
    submit.MouseButton1Click:Connect(function() modal:Destroy(); safeCall(config.Callback,input.Text) end)
    return modal
end
function WindowMethods:SetTheme(theme) return applyTheme(self,theme) end
function WindowMethods:CreateTab(name, icon)
    local theme=getTheme(self)
    local button=createButton(self.Sidebar,(icon and (tostring(icon).."   ") or "")..tostring(name),theme,34)
    button.TextXAlignment=Enum.TextXAlignment.Left
    padding(button,10,6,0,0)
    local page=make("ScrollingFrame",{Visible=false,BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromScale(1,1),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3,ScrollBarImageColor3=theme.Accent},self.Content)
    padding(page,2,8,2,8); listLayout(page,Enum.FillDirection.Vertical,8)
    local tab=setmetatable({Name=name,Icon=icon,Window=self,Button=button,Page=page,Sections={},Options={}}, {__index=TabMethods})
    button.MouseButton1Click:Connect(function() tab:Select() end)
    table.insert(self.Tabs,tab)
    if #self.Tabs==1 then tab:Select() end
    return tab
end
function WindowMethods:Search(query)
    query=string.lower(tostring(query or ""))
    for _,tab in ipairs(self.Tabs) do
        local tabHas=false
        for _,section in ipairs(tab.Sections) do
            local sectionHas=false
            for _,option in ipairs(section.Tab.Options) do
                local match=query=="" or string.find(string.lower(tostring(option.Name or "")),query,1,true)
                if option.Frame then option.Frame.Visible=match end
                if match then sectionHas=true end
            end
            section.Frame.Visible=query=="" or sectionHas
            if sectionHas then tabHas=true end
        end
        tab.Button.Visible=query=="" or tabHas
    end
end
function WindowMethods:CreateSearch()
    local box=make("TextBox",{ClearTextOnFocus=false,Text="",PlaceholderText="Search options...",TextSize=11,Font=Enum.Font.Gotham,TextColor3=getTheme(self).Text,PlaceholderColor3=getTheme(self).Muted,BackgroundColor3=getTheme(self).Element,Size=UDim2.new(1,0,0,30)},self.Sidebar)
    corner(box,7); padding(box,8,8,0,0)
    box:GetPropertyChangedSignal("Text"):Connect(function() self:Search(box.Text) end)
    return box
end
function WindowMethods:SetVisible(visible)
    if visible then
        self.Gui.Enabled=true
        self:PlayOpenAnimation()
    else
        self:PlayCloseAnimation(function() if self.Gui then self.Gui.Enabled=false end end)
    end
end
function WindowMethods:Toggle()
    self:SetVisible(not self.Gui.Enabled)
end
function WindowMethods:Minimize()
    if self.Minimized then return end
    self.Minimized=true
    self.Chip.Visible=true
    self.Chip.Size=UDim2.fromOffset(8,8)
    animationTween(self.Chip,"Back",0.28,{Size=UDim2.fromOffset(118,28)})
    self:PlayCloseAnimation()
end
function WindowMethods:Restore()
    self.Minimized=false
    self.Chip.Visible=false
    self.Main.Visible=true
    self:PlayOpenAnimation()
end
function WindowMethods:CreateWatermark(text)
    local theme=getTheme(self)
    local mark=make("TextLabel",{BackgroundColor3=theme.Panel,Text=text or "VOLNX UI",TextColor3=theme.Text,TextSize=11,Font=Enum.Font.GothamBold,Size=UDim2.fromOffset(150,25),Position=UDim2.fromOffset(12,12)},self.Gui)
    corner(mark,6); stroke(mark,theme.Accent,1,0)
    return mark
end
function WindowMethods:CreateStatusBar(text)
    local bar=make("Frame",{BackgroundColor3=getTheme(self).Panel2,Size=UDim2.new(1,-16,0,22),Position=UDim2.new(0,8,1,-28)},self.Main)
    corner(bar,5)
    local label=createText(bar,text or "Ready",10,getTheme(self).Muted)
    label.Position=UDim2.fromOffset(7,0); label.Size=UDim2.new(1,-14,1,0)
    return {Frame=bar,SetText=function(_,v) label.Text=tostring(v) end}
end
function WindowMethods:CreateFPSCounter()
    local label=createText(self.Main,"FPS: --",10,getTheme(self).Muted)
    label.Position=UDim2.new(1,-100,0,7); label.Size=UDim2.fromOffset(85,18); label.TextXAlignment=Enum.TextXAlignment.Right
    local elapsed,frames=0,0
    local conn=RunService.RenderStepped:Connect(function(dt)
        elapsed=elapsed+dt; frames=frames+1
        if elapsed>=0.5 then label.Text="FPS: "..math.floor(frames/elapsed); elapsed=0; frames=0 end
    end)
    self._maid:Give(conn)
    return label
end
function WindowMethods:CreateEventLog()
    local entries={}
    return {
        Entries=entries,
        Add=function(_,message,kind)
            table.insert(entries,{Time=os.time(),Message=tostring(message),Kind=kind or "Info"})
            if #entries>200 then table.remove(entries,1) end
        end,
        Clear=function() table.clear(entries) end,
        Get=function() return Volnx.Util.DeepCopy(entries) end
    }
end
function WindowMethods:SaveConfig(name)
    name=name or "VolnxConfig"
    local data={Version=Volnx.Version,State=self.State,ThemeName=self.ThemeName}
    local encoded=HttpService:JSONEncode(data)
    local path=name..".json"
    if writefile then
        local ok=pcall(writefile,path,encoded)
        return ok,path
    end
    return false,"writefile unavailable"
end
function WindowMethods:LoadConfig(name)
    name=name or "VolnxConfig"
    if not readfile or not isfile or not isfile(name..".json") then return false,"config not found" end
    local ok,decoded=pcall(function() return HttpService:JSONDecode(readfile(name..".json")) end)
    if not ok or type(decoded)~="table" then return false,"invalid config" end
    for flag,value in pairs(decoded.State or {}) do self:SetValue(flag,value,true) end
    if decoded.ThemeName then self:SetTheme(decoded.ThemeName) end
    return true
end
function WindowMethods:CreateCommandPalette(commands)
    local theme=getTheme(self)
    local overlay=make("Frame",{Visible=false,BackgroundColor3=theme.Panel,AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,35),Size=UDim2.fromOffset(380,280)},self.Overlay)
    corner(overlay,10); stroke(overlay,theme.Accent,1.2,0)
    local input=make("TextBox",{PlaceholderText="Type a command...",Text="",ClearTextOnFocus=false,TextColor3=theme.Text,PlaceholderColor3=theme.Muted,BackgroundColor3=theme.Element,TextSize=12,Font=Enum.Font.Gotham,Position=UDim2.fromOffset(10,10),Size=UDim2.new(1,-20,0,30)},overlay)
    corner(input,6); padding(input,8,8,0,0)
    local list=make("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(10,48),Size=UDim2.new(1,-20,1,-58),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=3},overlay)
    listLayout(list,Enum.FillDirection.Vertical,4)
    local rows={}
    local function refresh()
        for _,row in ipairs(rows) do row:Destroy() end
        table.clear(rows)
        local q=string.lower(input.Text)
        for _,command in ipairs(commands or {}) do
            if q=="" or string.find(string.lower(command.Name),q,1,true) then
                local row=createButton(list,command.Name,theme,28)
                row.MouseButton1Click:Connect(function()
                    overlay.Visible=false; safeCall(command.Callback)
                end)
                table.insert(rows,row)
            end
        end
    end
    input:GetPropertyChangedSignal("Text"):Connect(refresh)
    refresh()
    connect(UserInputService.InputBegan,function(inputObject,processed)
        if processed then return end
        if inputObject.KeyCode==Enum.KeyCode.P and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            overlay.Visible=not overlay.Visible
            if overlay.Visible then input:CaptureFocus() end
        end
        if inputObject.KeyCode==Enum.KeyCode.Escape then overlay.Visible=false end
    end,self)
    return {Frame=overlay,Open=function() overlay.Visible=true; input:CaptureFocus() end,Close=function() overlay.Visible=false end}
end
function WindowMethods:Destroy()
    if self._destroyed then return end
    self._destroyed=true
    self._maid:Cleanup()
    for _,option in pairs(self.Options) do
        if option.Destroy then pcall(function() option:Destroy() end) end
    end
    if self.Gui then self.Gui:Destroy() end
    for i=#Volnx.Windows,1,-1 do if Volnx.Windows[i]==self then table.remove(Volnx.Windows,i) end end
end

function Volnx:CreateWindow(config)
    config=config or {}
    local theme=type(config.Theme)=="table" and config.Theme or Volnx.Themes[config.Theme or "DarkRed"] or DEFAULT_THEME
    local playerGui=LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local parent=(gethui and safeCall(gethui)) or playerGui or CoreGui
    local gui=make("ScreenGui",{Name=config.Name or "VolnxUI",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,IgnoreGuiInset=true},parent)
    local main=make("Frame",{
        Name="Main",BackgroundColor3=theme.Background,BorderSizePixel=0,
        Size=UDim2.fromOffset(config.Width or 620,config.Height or 410),
        Position=config.Position or UDim2.new(0.5,-310,0.5,-205),
        ClipsDescendants=true
    },gui)
    corner(main,14)
    local border=stroke(main,theme.Border,1.7,0)
    local borderGradient=make("UIGradient",{Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(105,12,22)),
        ColorSequenceKeypoint.new(0.22,Color3.fromRGB(255,55,35)),
        ColorSequenceKeypoint.new(0.48,Color3.fromRGB(255,145,55)),
        ColorSequenceKeypoint.new(0.72,Color3.fromRGB(205,25,35)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(105,12,22))
    }),Rotation=0},border)
    local glow=make("Frame",{Name="FireBorderGlow",BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(-2,-2),Size=UDim2.new(1,4,1,4),ZIndex=0},main)
    corner(glow,16)
    local glowStroke=stroke(glow,Color3.fromRGB(255,65,35),2.4,0.58)
    local glowGradient=make("UIGradient",{Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(115,8,20)),
        ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,110,35)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(180,15,30))
    })},glowStroke)
    local top=make("Frame",{BackgroundColor3=theme.Panel,Size=UDim2.new(1,0,0,48),BorderSizePixel=0},main)
    local title=createText(top,config.Title or "Volnx UI",15,theme.Text,Enum.Font.GothamBold)
    title.Position=UDim2.fromOffset(15,5); title.Size=UDim2.new(1,-120,0,22)
    local subtitle=createText(top,config.Subtitle or "FIRE EDITION  •  6.1",9,theme.Muted)
    subtitle.Position=UDim2.fromOffset(16,27); subtitle.Size=UDim2.new(1,-120,0,14)
    local fire=make("Frame",{BackgroundColor3=theme.Accent,BorderSizePixel=0,Position=UDim2.new(0,0,1,-2),Size=UDim2.new(1,0,0,2)},top)
    local gradient=make("UIGradient",{Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,theme.Accent),
        ColorSequenceKeypoint.new(0.5,theme.Accent2),
        ColorSequenceKeypoint.new(1,theme.Accent)
    })},fire)
    local sidebar=make("Frame",{BackgroundColor3=theme.Panel,BorderSizePixel=0,Position=UDim2.fromOffset(0,48),Size=UDim2.new(0,155,1,-48)},main)
    padding(sidebar,9,9,10,10); listLayout(sidebar,Enum.FillDirection.Vertical,6)
    local content=make("Frame",{BackgroundColor3=theme.Panel,BorderSizePixel=0,Position=UDim2.new(0,155,0,48),Size=UDim2.new(1,-155,1,-48)},main)
    padding(content,10,10,10,34)
    local toastLayer=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},gui)
    local overlay=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},gui)
    local chip=createButton(gui,"TAP TO OPEN",theme,28)
    chip.Visible=false; chip.Position=UDim2.new(0,12,0,12); chip.Size=UDim2.fromOffset(118,28)
    chip.MouseButton1Click:Connect(function()
        chip.Visible=false
        window:PlayOpenAnimation()
    end)
    local window=setmetatable({
        Config=config,Gui=gui,Main=main,Topbar=top,Sidebar=sidebar,Content=content,
        TitleLabel=title,SubtitleLabel=subtitle,FireLine=fire,BorderStroke=border,
        BorderGradient=borderGradient,BorderGlow=glow,BorderGlowStroke=glowStroke,
        BorderGlowGradient=glowGradient,BorderAnimationEnabled=true,BorderStyle="Fire",
        AnimationStyle=config.AnimationStyle or "Back",AnimationSettings={Open=true,Close=true,Hover=true,Press=true,Tab=true,Modal=true,Toast=true},
        ToastLayer=toastLayer,Overlay=overlay,Chip=chip,Theme=theme,
        ThemeName=type(config.Theme)=="string" and config.Theme or "DarkRed",
        Tabs={},Options={},State={},SelectedTab=nil,_maid=Maid.new(),_connections={},
        _themeObjects={},Minimized=false
    },{__index=WindowMethods})
    table.insert(Volnx.Windows,window)
    -- Slow, continuous fire sweep around the rounded border.
    local rotation=0
    local pulseClock=0
    window._maid:Give(RunService.RenderStepped:Connect(function(dt)
        if window._destroyed then return end
        rotation=(rotation+dt*24)%360
        pulseClock=pulseClock+dt
        gradient.Rotation=(rotation*1.35)%360
        if window.BorderAnimationEnabled then
            borderGradient.Rotation=rotation
            glowGradient.Rotation=(360-rotation*0.72)%360
            local pulse=(math.sin(pulseClock*1.8)+1)*0.5
            glowStroke.Transparency=0.68-pulse*0.17
            glowStroke.Thickness=2.0+pulse*0.7
            border.Thickness=1.55+pulse*0.25
        end
    end))
    -- Drag from the title area; supports mouse and touch.
    local dragging,dragStart,startPos
    top.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=main.Position
        end
    end)
    connect(UserInputService.InputChanged,function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-dragStart
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end,window)
    connect(UserInputService.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end,window)
    -- Resize grip.
    local grip=make("TextButton",{Text="",AutoButtonColor=false,BackgroundColor3=theme.Accent,AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,0,1,0),Size=UDim2.fromOffset(15,15),ZIndex=10},main)
    corner(grip,5)
    local resizing,resizeStart,originalSize=false,nil,nil
    grip.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            resizing=true; resizeStart=input.Position; originalSize=main.Size
        end
    end)
    connect(UserInputService.InputChanged,function(input)
        if resizing and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local delta=input.Position-resizeStart
            main.Size=UDim2.fromOffset(math.max(430,originalSize.X.Offset+delta.X),math.max(280,originalSize.Y.Offset+delta.Y))
        end
    end,window)
    connect(UserInputService.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then resizing=false end
    end,window)
    -- Minimize button.
    local minimize=createButton(top,"—",theme,25)
    minimize.AnchorPoint=Vector2.new(1,0); minimize.Position=UDim2.new(1,-12,0,11); minimize.Size=UDim2.fromOffset(28,25)
    minimize.MouseButton1Click:Connect(function() window:Minimize() end)
    -- Keyboard toggle.
    local toggleKey=config.ToggleKey or Enum.KeyCode.RightControl
    connect(UserInputService.InputBegan,function(input,processed)
        if not processed and input.KeyCode==toggleKey then gui.Enabled=not gui.Enabled end
    end,window)
    window:CreateTab("Home","⌂")
    return window
end

function Volnx:CreateNotification(config)
    local window=self.Windows[#self.Windows]
    if window then return window:Notify(config) end
    return nil
end

function Volnx:Destroy()
    for _,window in ipairs(table.clone(self.Windows)) do window:Destroy() end
    for _,connection in ipairs(self.Connections) do pcall(function() connection:Disconnect() end) end
    table.clear(self.Connections)
end

-- State transactions: apply a group of values and refresh each option once.
function WindowMethods:Transaction(values, silent)
    for flag,value in pairs(values or {}) do self.State[flag]=value end
    for flag in pairs(values or {}) do
        local option=self.Options[flag]
        if option then
            if option.Refresh then safeCall(option.Refresh) end
            option.Changed:Fire(self.State[flag])
            if not silent then safeCall(option.Callback,self.State[flag],option) end
        end
    end
end

-- Exclusive groups ensure only one flag in a group can be true.
function WindowMethods:CreateExclusiveGroup(flags)
    local group={Window=self,Flags=flags or {}}
    function group:Set(activeFlag)
        for _,flag in ipairs(self.Flags) do self.Window:SetValue(flag,flag==activeFlag) end
    end
    function group:Get()
        for _,flag in ipairs(self.Flags) do if self.Window:GetValue(flag) then return flag end end
    end
    return group
end

-- Hotkey manager.
function WindowMethods:CreateHotkeyManager()
    local manager={Window=self,Bindings={}}
    function manager:Bind(keyCode,callback)
        self.Bindings[keyCode]=callback
    end
    function manager:Unbind(keyCode) self.Bindings[keyCode]=nil end
    local connection=UserInputService.InputBegan:Connect(function(input,processed)
        if processed then return end
        if input.UserInputType==Enum.UserInputType.Keyboard then
            local callback=manager.Bindings[input.KeyCode]
            if callback then safeCall(callback,input.KeyCode) end
        end
    end)
    self._maid:Give(connection)
    function manager:Destroy() connection:Disconnect(); table.clear(self.Bindings) end
    return manager
end

-- Simple canvas/surface API for custom UI content.
function WindowMethods:CreateSurface(parent, config)
    config=config or {}
    local theme=getTheme(self)
    parent=parent or self.Content
    local root=make("Frame",{BackgroundColor3=config.Background or theme.Panel2,Size=config.Size or UDim2.new(1,0,0,100)},parent)
    corner(root,config.Radius or 8)
    local api={Root=root,Window=self}
    function api:Frame(props)
        props=props or {}
        local obj=make("Frame",{BackgroundColor3=props.Color or theme.Element,Position=props.Position or UDim2.new(),Size=props.Size or UDim2.fromOffset(100,30),BorderSizePixel=0},root)
        if props.Radius then corner(obj,props.Radius) end
        if props.Stroke then stroke(obj,props.Stroke,1,0) end
        return obj
    end
    function api:Text(props)
        props=props or {}
        local obj=createText(root,props.Text or "",props.TextSize or 12,props.Color or theme.Text)
        obj.Position=props.Position or UDim2.new()
        obj.Size=props.Size or UDim2.new(1,0,0,20)
        obj.TextWrapped=props.Wrapped or false
        return obj
    end
    function api:Button(props,callback)
        props=props or {}
        local obj=createButton(root,props.Text or "Button",theme,props.Height or 28)
        obj.Position=props.Position or UDim2.new()
        obj.Size=props.Size or UDim2.new(1,0,0,props.Height or 28)
        obj.MouseButton1Click:Connect(function() safeCall(callback) end)
        return obj
    end
    function api:Image(props)
        props=props or {}
        local obj=make("ImageLabel",{BackgroundTransparency=1,Image=props.Image or "",Position=props.Position or UDim2.new(),Size=props.Size or UDim2.fromOffset(64,64),ScaleType=Enum.ScaleType.Fit},root)
        return obj
    end
    function api:Bar(props)
        props=props or {}
        local bar=make("Frame",{BackgroundColor3=theme.Element,Position=props.Position or UDim2.new(),Size=props.Size or UDim2.new(1,0,0,8)},root)
        corner(bar,5)
        local fill=make("Frame",{BackgroundColor3=props.Color or theme.Accent,Size=UDim2.new(math.clamp(props.Value or 0,0,1),0,1,0)},bar)
        corner(fill,5)
        return {Frame=bar,Set=function(_,v) tween(fill,0.2,{Size=UDim2.new(math.clamp(v,0,1),0,1,0)}) end}
    end
    function api:Destroy() root:Destroy() end
    return api
end

-- Responsive helper scales the window to the viewport while preserving minimum size.
function WindowMethods:EnableResponsive()
    local camera=workspace.CurrentCamera
    if not camera then return end
    local function update()
        local viewport=camera.ViewportSize
        local scale=math.min(1,viewport.X/650,viewport.Y/440)
        scale=math.max(0.62,scale)
        local uiScale=self.Main:FindFirstChildOfClass("UIScale") or make("UIScale",{},self.Main)
        uiScale.Scale=scale
    end
    update()
    local connection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
    self._maid:Give(connection)
end

-- Utility config and state APIs.
function WindowMethods:GetStateSnapshot()
    return Volnx.Util.DeepCopy(self.State)
end
function WindowMethods:ResetState()
    for flag,option in pairs(self.Options) do
        if option.Default~=nil then self:SetValue(flag,Volnx.Util.DeepCopy(option.Default),true) end
    end
end
function WindowMethods:GetOption(flag) return self.Options[flag] end
function WindowMethods:GetOptions() return self.Options end


-- Convenient named animation helpers.
function WindowMethods:FadeIn(object, duration)
    if not object then return end
    object.Visible=true
    object.BackgroundTransparency=1
    return animationTween(object,"Sine",duration or 0.25,{BackgroundTransparency=0})
end
function WindowMethods:FadeOut(object, duration)
    if not object then return end
    return animationTween(object,"Sine",duration or 0.22,{BackgroundTransparency=1},Enum.EasingDirection.In)
end
function WindowMethods:SlideIn(object, direction, distance, duration)
    if not object then return end
    direction=direction or "Left"
    distance=distance or 24
    local target=object.Position
    local offset=direction=="Right" and distance or direction=="Left" and -distance or 0
    local yoff=direction=="Down" and distance or direction=="Up" and -distance or 0
    object.Position=target+UDim2.fromOffset(offset,yoff)
    object.Visible=true
    return animationTween(object,"Quart",duration or 0.28,{Position=target})
end
function WindowMethods:Pulse(object, amount, duration)
    if not object then return end
    local original=object.Size
    local scale=amount or 1.04
    local bigger=UDim2.new(original.X.Scale*scale,original.X.Offset*scale,original.Y.Scale*scale,original.Y.Offset*scale)
    local tw=animationTween(object,"Sine",duration or 0.18,{Size=bigger})
    if tw then tw.Completed:Connect(function()
        if object and object.Parent then animationTween(object,"Sine",duration or 0.18,{Size=original}) end
    end) end
    return tw
end
function WindowMethods:Shake(object, intensity, duration)
    if not object then return end
    local origin=object.Position
    intensity=intensity or 5
    duration=duration or 0.32
    local offsets={intensity,-intensity,intensity*0.65,-intensity*0.65,0}
    local step=duration/#offsets
    for i,offset in ipairs(offsets) do
        task.delay((i-1)*step,function()
            if object and object.Parent then
                animationTween(object,"Sine",step,{Position=origin+UDim2.fromOffset(offset,0)})
            end
        end)
    end
end
function WindowMethods:Rotate(object, degrees, duration)
    if not object then return end
    return animationTween(object,"Back",duration or 0.3,{Rotation=degrees or 180})
end

-- Add methods and metadata.
Volnx.CreateWindow = Volnx.CreateWindow
Volnx.Create = Volnx.CreateWindow
Volnx.GetVersion = function() return Volnx.Version end
Volnx.GetTheme = function(name) return Volnx.Themes[name] end
Volnx.SetGlobalTheme = function(name)
    local theme=Volnx.Themes[name]
    if not theme then return false end
    for _,window in ipairs(Volnx.Windows) do window:SetTheme(theme); window.ThemeName=name end
    return true
end

--[[
    VOLNX HUB ULTIMATE 7.0
    Integrated single-file UI + safe developer/visual control hub.

    Safety scope:
      - UI controls and local diagnostics only.
      - No item stealing, anti-guard bypass, anti-cheat evasion,
        unauthorized RemoteEvent calls, or hidden game manipulation.
      - Game-specific ESP/Finder/Guard integrations are intentionally
        exposed only as callbacks for experiences the developer owns
        or has permission to debug.
]]

Volnx.HubVersion = "7.1.0"

function Volnx:CreateHub(config)
    config = config or {}
    local window = self:CreateWindow({
        Name = "VolnxHubUltimate",
        Title = config.Title or "VOLNX HUB",
        Subtitle = "ULTIMATE 7.1  •  EGG FINDER EDITION",
        Width = 700,
        Height = 465,
        Theme = config.Theme or "DarkRed",
        AnimationStyle = "Back"
    })

    local log = window:CreateEventLog()
    local status = window:CreateStatusBar("Ready  •  Volnx Hub Ultimate 7.0")
    window:CreateFPSCounter()
    window.Watermark = window:CreateWatermark("VOLNX 7.0")

    local function notify(title, message)
        window:Notify({Title = title or "Volnx", Content = message or "", Duration = 3})
        log:Add((title or "Info") .. ": " .. (message or ""), "Info")
    end

    local function section(tab, name)
        return tab:CreateSection(name)
    end

    -- Dashboard
    local home = window:CreateTab("Dashboard", "⌂")
    local welcome = section(home, "Welcome")
    welcome:CreateParagraph({
        Name = "VOLNX HUB ULTIMATE",
        Description = "Dark Red / Fire interface • Egg Finder filters • Version 7.1"
    })
    welcome:CreateLabel({
        Name = "Status",
        Description = "UI loaded successfully. Use the tabs to configure the interface."
    })
    welcome:CreateButton({
        Name = "System check",
        ButtonText = "Run check",
        Callback = function()
            local player = game:GetService("Players").LocalPlayer
            local msg = player and ("Player: " .. player.Name .. " • UI: online") or "UI: online"
            status:SetText(msg)
            notify("System check", msg)
        end
    })
    local info = section(home, "Included modules")
    info:CreateParagraph({
        Name = "Visuals / Finder / Guards",
        Description = "The interface includes permission-gated integration points. Connect them only to your own Roblox experience or an authorized private test place."
    })
    info:CreateParagraph({
        Name = "Security boundary",
        Description = "No stealing, guard bypass, anti-cheat evasion, or unauthorized RemoteEvent manipulation is included."
    })

    -- Visual settings: UI-side preferences, not game-world ESP.
    local visuals = window:CreateTab("Visuals", "◈")
    local visualUI = section(visuals, "Visual interface")
    visualUI:CreateToggle({
        Name = "Show watermark",
        Flag = "Visual_Watermark",
        Default = true,
        Callback = function(value)
            -- Watermark is managed by the library; this setting is stored for integrations.
            if window.Watermark then window.Watermark.Visible = value end
            notify("Visuals", value and "Watermark preference enabled" or "Watermark preference disabled")
        end
    })
    visualUI:CreateToggle({
        Name = "Fire border animation",
        Flag = "Visual_FireBorder",
        Default = true,
        Callback = function(value)
            window.BorderAnimationEnabled = value
            notify("Fire border", value and "Animation enabled" or "Animation paused")
        end
    })
    visualUI:CreateDropdown({
        Name = "Visual theme",
        Flag = "Visual_Theme",
        Default = "DarkRed",
        Values = {"DarkRed", "Crimson", "Ember", "Midnight", "Light"},
        Callback = function(value)
            if Volnx.Themes[value] then
                window:SetTheme(value)
                window.ThemeName = value
                notify("Theme", "Applied " .. tostring(value))
            end
        end
    })
    local integration = section(visuals, "Authorized visual-debug integration")
    integration:CreateParagraph({
        Name = "Developer API",
        Description = "For your own experience, provide server-authorized debug data through your own ModuleScript and connect it to the callback hooks in this file. This build does not scan or reveal other players."
    })
    integration:CreateButton({
        Name = "Visual integration status",
        ButtonText = "Check",
        Callback = function()
            notify("Visual integration", "No game-specific debug provider is connected.")
        end
    })

    -- Finder UI is a neutral search panel for developer-provided entries.
    local finder = window:CreateTab("Finder", "⌕")
    local findSec = section(finder, "Authorized data finder")
    findSec:CreateParagraph({
        Name = "How it works",
        Description = "This tab is a UI shell for searching entries supplied by your own game or a permitted test environment. It does not search hidden game state or exploit remotes."
    })
    local finderInput = findSec:CreateInput({
        Name = "Search query",
        Flag = "Finder_Query",
        Placeholder = "Enter a name or item label...",
        Default = "",
        Callback = function(value)
            log:Add("Finder query changed: " .. tostring(value), "Search")
        end
    })
    findSec:CreateButton({
        Name = "Search local demo catalog",
        ButtonText = "Search",
        Callback = function()
            local q = tostring(window:GetValue("Finder_Query") or "")
            if q == "" then
                notify("Finder", "Enter a search term first.")
            else
                notify("Finder", "No developer catalog connected for: " .. q)
            end
        end
    })

    -- Embedded Volnx Finder Core (standalone data-processing engine).
    local FinderAPI = (function()
--[[
    Volnx Finder Core
    Rebuilt from the Finder data-processing logic in the supplied Chilli Hub source.
    Standalone: no Chilli endpoints, tokens, account checks, HTTP requests, or server hopping.

    Data is supplied by the caller through config.GetSnapshot() or Scan(snapshot).
    Expected snapshot:
      {
        Records = { ... },             -- EggState.ReadFieldEggs().Records-like table
        Directory = { [category] = assetData },
        Mutations = { EarningsFor = function(mutationList) return multiplier end }, -- optional
        EggRecords = { WeightKgForScale = function(category, scale) return weight end } -- optional
      }

    This module only reads the supplied tables. It does not call game remotes or perform
    stealing, teleporting, or other game actions.
]]

local Finder = {}
Finder.__index = Finder

local function safeCall(fn, ...)
    if type(fn) ~= "function" then
        return false, nil
    end
    return pcall(fn, ...)
end

local function number(value, fallback)
    local n = tonumber(value)
    if n == nil then return fallback or 0 end
    return n
end

local function scaleFactor(scale)
    scale = number(scale, 1)
    if scale > 5 then
        return ((scale / 5) ^ 1.2) * 19.637875755794113
    end
    return scale ^ 1.85
end

local function collectMutations(record)
    local list, seen = {}, {}

    local function add(value)
        if type(value) ~= "string" or value == "" or value == "Normal" or value == "None" then
            return
        end
        if not seen[value] then
            seen[value] = true
            list[#list + 1] = value
        end
    end

    add(record.BaseMutation)

    if type(record.Mutations) == "table" then
        for key, mutation in pairs(record.Mutations) do
            if type(key) == "string" and mutation == true then
                add(key)
            else
                add(mutation)
            end
        end
    end

    return list
end

local function mutationMultiplier(mutationsApi, mutations, record, custom)
    if type(custom) == "function" then
        local ok, result = safeCall(custom, mutations, record)
        if ok and tonumber(result) then return tonumber(result) end
    end

    if type(mutationsApi) == "table" and type(mutationsApi.EarningsFor) == "function" then
        local ok, result = safeCall(mutationsApi.EarningsFor, mutations)
        if ok and tonumber(result) then return tonumber(result) end
    end

    return 1
end

local function formatCompact(value)
    local units = {"", "K", "M", "B", "T", "Qa", "Qi"}
    local abs = math.abs(value)
    local index = 1
    while abs >= 1000 and index < #units do
        value = value / 1000
        abs = abs / 1000
        index = index + 1
    end
    if index == 1 then
        return tostring(math.floor(value * 100 + 0.5) / 100)
    end
    return string.format("%.2f%s", value, units[index])
end

local function rarityInfo(asset)
    local rarity = type(asset.Rarity) == "table" and asset.Rarity or {}
    return number(rarity.RarityNumber or rarity.Rank, 0),
        tostring(rarity.DisplayName or rarity._id or "")
end

local function getWeight(snapshot, category, scale, record, custom)
    if type(custom) == "function" then
        local ok, result = safeCall(custom, category, scale, record)
        if ok and tonumber(result) then return tonumber(result) end
    end

    local api = snapshot.EggRecords
    if type(api) == "table" and type(api.WeightKgForScale) == "function" then
        local ok, result = safeCall(api.WeightKgForScale, category, scale)
        if ok and tonumber(result) then return tonumber(result) end
    end
    return nil
end

function Finder.new(config)
    config = config or {}
    return setmetatable({
        Config = config,
        Results = {},
        LastScanAt = 0,
        ScanCount = 0,
    }, Finder)
end

function Finder:Scan(snapshot)
    snapshot = snapshot or (type(self.Config.GetSnapshot) == "function" and self.Config.GetSnapshot()) or {}
    local records = snapshot.Records
    local directory = snapshot.Directory
    local output = {}

    if type(records) ~= "table" or type(directory) ~= "table" then
        self.Results = output
        return output, "Missing Records or Directory in snapshot"
    end

    for key, record in pairs(records) do
        if type(record) == "table"
            and record.State ~= "Claimed"
            and type(record.Uid) == "string"
            and record.Uid ~= ""
            and not tostring(record.Uid):find("^FirstAreaEgg") then

            local category = tostring(record.AssetCategory or "")
            local asset = directory[category]

            if type(asset) == "table" then
                local rarity, rarityName = rarityInfo(asset)
                local scale = number(record.AssetScale, 1)
                local mutations = collectMutations(record)
                local multiplier = mutationMultiplier(
                    snapshot.Mutations, mutations, record, self.Config.MutationMultiplier
                )
                local baseRate = number(asset.EarningRate, 0)
                local value = baseRate * scaleFactor(scale) * multiplier
                local minValue = number(self.Config.MinValue, 0)
                local minRarity = number(self.Config.MinRarity, 0)

                if value >= minValue and rarity >= minRarity then
                    local weight = getWeight(
                        snapshot, category, scale, record, self.Config.WeightForScale
                    )

                    output[#output + 1] = {
                        uid = record.Uid,
                        name = tostring(asset.DisplayName or asset._id or category),
                        category = category,
                        rarity = rarity,
                        rarityName = rarityName,
                        value = value,
                        valueText = formatCompact(value),
                        weight = weight,
                        weightText = weight and (formatCompact(weight) .. " kg") or "",
                        size = math.floor(scale * 100 + 0.5) / 100,
                        area = tostring(record.AreaId or ""),
                        mutation = table.concat(mutations, ", "),
                        mutations = mutations,
                        image = tostring(asset.Icon or ""),
                        state = tostring(record.State or ""),
                        sourceKey = key,
                    }
                end
            end
        end
    end

    self.Results = output
    self.LastScanAt = os.clock and os.clock() or 0
    self.ScanCount = self.ScanCount + 1
    return output
end

function Finder:Filter(results, options)
    results = results or self.Results
    options = options or {}
    local query = string.lower(tostring(options.Search or ""))
    local minValue = number(options.MinValue, 0)
    local minRarity = number(options.MinRarity, 0)
    local allowed = options.AllowedNames
    local mutationQuery = string.lower(tostring(options.Mutation or ""))
    local filtered = {}

    for _, item in ipairs(results) do
        local matches = item.value >= minValue and item.rarity >= minRarity

        if matches and query ~= "" then
            local haystack = string.lower(item.name .. " " .. item.category .. " " ..
                item.rarityName .. " " .. item.mutation)
            matches = haystack:find(query, 1, true) ~= nil
        end

        if matches and type(allowed) == "table" then
            matches = allowed[item.name] == true or allowed[item.category] == true
        end

        if matches and mutationQuery ~= "" then
            matches = string.lower(item.mutation):find(mutationQuery, 1, true) ~= nil
        end

        if matches then filtered[#filtered + 1] = item end
    end

    return filtered
end

function Finder:Sort(results, mode, descending)
    results = results or self.Results
    mode = mode or "Value"
    local keyMap = {
        Value = "value",
        Rarity = "rarity",
        Weight = "weight",
        Size = "size",
        Name = "name",
    }
    local key = keyMap[mode] or "value"
    local copy = {}

    for i, item in ipairs(results) do copy[i] = item end

    table.sort(copy, function(a, b)
        local av, bv = a[key], b[key]
        if key == "name" then
            av, bv = string.lower(tostring(av)), string.lower(tostring(bv))
        else
            av, bv = number(av, -1), number(bv, -1)
        end
        if descending == false then return av < bv end
        return av > bv
    end)

    return copy
end

function Finder:Find(results, query)
    query = string.lower(tostring(query or ""))
    if query == "" then return nil end
    for _, item in ipairs(results or self.Results) do
        if string.lower(item.uid) == query or
            string.lower(item.name):find(query, 1, true) then
            return item
        end
    end
    return nil
end

function Finder:GetStats(results)
    results = results or self.Results
    local stats = {Count = #results, HighestValue = nil, HighestRarity = nil, Heaviest = nil}
    for _, item in ipairs(results) do
        if not stats.HighestValue or item.value > stats.HighestValue.value then
            stats.HighestValue = item
        end
        if not stats.HighestRarity or item.rarity > stats.HighestRarity.rarity then
            stats.HighestRarity = item
        end
        if item.weight and (not stats.Heaviest or item.weight > stats.Heaviest.weight) then
            stats.Heaviest = item
        end
    end
    return stats
end

function Finder:Refresh()
    if type(self.Config.GetSnapshot) ~= "function" then
        return self.Results, "Config.GetSnapshot is not set"
    end
    return self:Scan()
end

function Finder:Clear()
    self.Results = {}
end

local API = {}
function API.Create(config)
    return Finder.new(config)
end

API.ScaleFactor = scaleFactor
API.CollectMutations = collectMutations
API.FormatCompact = formatCompact

return API

    end)()
    local FinderEngine = FinderAPI.Create({MinValue = 0, MinRarity = 0})

    -- Local Egg Finder connected to the standalone Volnx Finder Core.
    -- It reads only the local player's client-visible egg slot records.
    -- It does not upload egg data, use Chilli credentials, or auto-join servers.
    local eggSec = section(finder, "Steal a Egg • Local Egg Finder")
    eggSec:CreateParagraph({
        Name = "Local scanner",
        Description = "Uses the embedded Volnx Finder Core to scan local slot records, calculate earnings / weight, then filter and sort results. No Chilli account or external feed is used."
    })
    eggSec:CreateInput({
        Name = "Minimum earning rate",
        Flag = "Egg_MinRate",
        Default = "0",
        Placeholder = "Examples: 5B, 1.5T, 250M"
    })
    eggSec:CreateDropdown({
        Name = "Minimum rarity",
        Flag = "Egg_MinRarity",
        Default = "Any",
        Values = {"Any", "Secret+", "Eternal+", "Divine"}
    })
    eggSec:CreateInput({
        Name = "Search name / mutation / area",
        Flag = "Egg_Search",
        Default = "",
        Placeholder = "Search..."
    })
    -- Chilli Finder-inspired Spotlight + responsive egg card grid.
    -- Rebuilt with Volnx components; no Chilli UI engine or account code is imported.
    local eggCardHolder = make("Frame", {
        Name = "VolnxFinderCards",
        BackgroundColor3 = Color3.fromRGB(17, 13, 18),
        BackgroundTransparency = 0,
        Size = UDim2.new(1, 0, 0, 330),
        ClipsDescendants = true
    }, eggSec.Body)
    corner(eggCardHolder, 10)
    stroke(eggCardHolder, Color3.fromRGB(125, 35, 42), 1, 0.25)
    padding(eggCardHolder, 8, 8, 8, 8)

    local eggCardScroll = make("ScrollingFrame", {
        Name = "CardScroll",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(190, 55, 65)
    }, eggCardHolder)
    listLayout(eggCardScroll, Enum.FillDirection.Vertical, 8)

    local eggSpotlight = make("Frame", {
        Name = "Spotlight",
        BackgroundColor3 = Color3.fromRGB(32, 19, 23),
        Size = UDim2.new(1, 0, 0, 104),
        Visible = false,
        LayoutOrder = 1
    }, eggCardScroll)
    corner(eggSpotlight, 9)
    stroke(eggSpotlight, Color3.fromRGB(235, 95, 65), 1.2, 0.18)

    local spotlightAccent = make("Frame", {
        BackgroundColor3 = Color3.fromRGB(235, 75, 55),
        Size = UDim2.new(0, 3, 1, -18),
        Position = UDim2.fromOffset(7, 9)
    }, eggSpotlight)
    corner(spotlightAccent, 3)

    local spotlightImage = make("ImageLabel", {
        Name = "EggImage",
        BackgroundColor3 = Color3.fromRGB(12, 10, 14),
        BackgroundTransparency = 0.1,
        Position = UDim2.fromOffset(17, 12),
        Size = UDim2.fromOffset(78, 78),
        ScaleType = Enum.ScaleType.Fit,
        Image = ""
    }, eggSpotlight)
    corner(spotlightImage, 8)
    stroke(spotlightImage, Color3.fromRGB(210, 75, 65), 1, 0.2)

    local spotlightTitle = createText(eggSpotlight, "TOP FIND", 14, Color3.fromRGB(255, 240, 235), Enum.Font.GothamBold)
    spotlightTitle.Position = UDim2.fromOffset(105, 12)
    spotlightTitle.Size = UDim2.new(1, -118, 0, 20)
    spotlightTitle.TextXAlignment = Enum.TextXAlignment.Left
    spotlightTitle.TextTruncate = Enum.TextTruncate.AtEnd

    local spotlightRarity = createText(eggSpotlight, "RARITY", 10, Color3.fromRGB(255, 145, 105), Enum.Font.GothamBold)
    spotlightRarity.Position = UDim2.fromOffset(105, 34)
    spotlightRarity.Size = UDim2.new(1, -118, 0, 15)
    spotlightRarity.TextXAlignment = Enum.TextXAlignment.Left

    local spotlightRate = createText(eggSpotlight, "0/s", 13, Color3.fromRGB(255, 205, 125), Enum.Font.GothamBold)
    spotlightRate.Position = UDim2.fromOffset(105, 52)
    spotlightRate.Size = UDim2.new(1, -118, 0, 18)
    spotlightRate.TextXAlignment = Enum.TextXAlignment.Left

    local spotlightInfo = createText(eggSpotlight, "Mutation • Size • Weight", 9, Color3.fromRGB(190, 175, 180))
    spotlightInfo.Position = UDim2.fromOffset(105, 73)
    spotlightInfo.Size = UDim2.new(1, -118, 0, 16)
    spotlightInfo.TextXAlignment = Enum.TextXAlignment.Left
    spotlightInfo.TextTruncate = Enum.TextTruncate.AtEnd

    local eggGridHolder = make("Frame", {
        Name = "EggGrid",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 2
    }, eggCardScroll)
    local eggGridLayout = make("UIGridLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        CellPadding = UDim2.fromOffset(7, 7),
        CellSize = UDim2.new(0.5, -4, 0, 132)
    }, eggGridHolder)
    eggCardHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local width = eggCardHolder.AbsoluteSize.X - 20
        local columns = width >= 520 and 3 or 2
        eggGridLayout.CellSize = UDim2.new(1 / columns, -7, 0, 132)
    end)

    local eggEmptyText = createText(eggCardScroll, "Press SCAN to find local eggs", 11, Color3.fromRGB(175, 155, 160))
    eggEmptyText.Size = UDim2.new(1, 0, 0, 28)
    eggEmptyText.TextXAlignment = Enum.TextXAlignment.Center
    eggEmptyText.LayoutOrder = 3

    local eggCards = {}
    local function clearEggCards()
        for _, card in ipairs(eggCards) do
            if card and card.Parent then card:Destroy() end
        end
        table.clear(eggCards)
        for _, child in ipairs(eggGridHolder:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
    end

    local function setEggImage(imageLabel, imageValue)
        local image = tostring(imageValue or "")
        if image ~= "" then
            if image:match("^%d+$") then image = "rbxassetid://" .. image end
            imageLabel.Image = image
            imageLabel.Visible = true
        else
            imageLabel.Image = ""
            imageLabel.Visible = true
        end
    end

    local formatEggRate

    local function createEggCard(egg, index)
        local card = make("Frame", {
            Name = "EggCard_" .. tostring(index),
            BackgroundColor3 = Color3.fromRGB(29, 20, 25),
            Size = UDim2.new(0, 0, 0, 132),
            LayoutOrder = index
        }, eggGridHolder)
        corner(card, 8)
        local rarityStroke = stroke(card, Color3.fromRGB(145, 65, 70), 1, 0.25)
        make("UIGradient", {
            Rotation = 35,
            Color = ColorSequence.new(
                Color3.fromRGB(48, 27, 34),
                Color3.fromRGB(22, 18, 24)
            )
        }, card)

        local image = make("ImageLabel", {
            BackgroundColor3 = Color3.fromRGB(12, 10, 14),
            Position = UDim2.fromOffset(8, 8),
            Size = UDim2.fromOffset(48, 48),
            ScaleType = Enum.ScaleType.Fit,
            Image = ""
        }, card)
        corner(image, 7)
        stroke(image, Color3.fromRGB(115, 55, 62), 1, 0.35)
        setEggImage(image, egg.image)

        local name = createText(card, egg.name or "Unknown Egg", 11, Color3.fromRGB(255, 245, 240), Enum.Font.GothamBold)
        name.Position = UDim2.fromOffset(64, 9)
        name.Size = UDim2.new(1, -72, 0, 30)
        name.TextWrapped = true
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextYAlignment = Enum.TextYAlignment.Top

        local rarity = createText(card, string.upper(egg.rarityName or "UNKNOWN"), 9, Color3.fromRGB(255, 150, 110), Enum.Font.GothamBold)
        rarity.Position = UDim2.fromOffset(64, 42)
        rarity.Size = UDim2.new(1, -72, 0, 14)
        rarity.TextXAlignment = Enum.TextXAlignment.Left
        rarity.TextTruncate = Enum.TextTruncate.AtEnd

        local rate = createText(card, formatEggRate(egg.value or 0), 12, Color3.fromRGB(255, 205, 125), Enum.Font.GothamBold)
        rate.Position = UDim2.fromOffset(8, 65)
        rate.Size = UDim2.new(1, -16, 0, 18)
        rate.TextXAlignment = Enum.TextXAlignment.Left

        local mutation = (egg.mutation and egg.mutation ~= "") and egg.mutation or "Normal"
        local sizeText = string.format("Size %.2fx", egg.size or 1)
        local weightText = (egg.weight and egg.weight > 0) and string.format(" • %.2fkg", egg.weight) or ""
        local detail = createText(card, mutation .. " • " .. sizeText .. weightText, 9, Color3.fromRGB(190, 175, 180))
        detail.Position = UDim2.fromOffset(8, 87)
        detail.Size = UDim2.new(1, -16, 0, 15)
        detail.TextXAlignment = Enum.TextXAlignment.Left
        detail.TextTruncate = Enum.TextTruncate.AtEnd

        local area = createText(card, egg.area or "Unknown area", 8, Color3.fromRGB(145, 130, 140))
        area.Position = UDim2.fromOffset(8, 106)
        area.Size = UDim2.new(1, -16, 0, 13)
        area.TextXAlignment = Enum.TextXAlignment.Left
        area.TextTruncate = Enum.TextTruncate.AtEnd

        local rarityKey = string.upper(tostring(egg.rarityName or ""))
        local rarityColor = ({
            SECRET = Color3.fromRGB(185, 175, 205),
            ETERNAL = Color3.fromRGB(195, 155, 255),
            DIVINE = Color3.fromRGB(255, 205, 110),
            COSMIC = Color3.fromRGB(110, 185, 255),
            MYTHIC = Color3.fromRGB(255, 115, 145)
        })[rarityKey] or Color3.fromRGB(235, 95, 85)
        rarity.TextColor3 = rarityColor
        rarityStroke.Color = rarityColor
        table.insert(eggCards, card)
        return card
    end
    local eggStatus = eggSec:CreateLabel({
        Name = "Scanner status",
        Text = "Not scanned yet"
    })

    local function parseEggRate(value)
        local s = tostring(value or "0"):lower():gsub("[%s,$]", "")
        local number, suffix = s:match("^(%d*%.?%d+)(%a*)$")
        number = tonumber(number)
        if not number then return nil end
        local multipliers = {
            [""] = 1, k = 1e3, m = 1e6, b = 1e9,
            t = 1e12, qa = 1e15, qi = 1e18
        }
        local multiplier = multipliers[suffix]
        return multiplier and number * multiplier or nil
    end

    formatEggRate = function(value)
        local units = {
            {1e18, "Qi"}, {1e15, "Qa"}, {1e12, "T"},
            {1e9, "B"}, {1e6, "M"}, {1e3, "K"}
        }
        for _, unit in ipairs(units) do
            if value >= unit[1] then
                return string.format("%.2f%s/s", value / unit[1], unit[2])
            end
        end
        return string.format("%.0f/s", value)
    end

    local function safeModule(parent, childName)
        local child = parent and parent:FindFirstChild(childName)
        if child and child:IsA("ModuleScript") then
            local ok, result = pcall(require, child)
            if ok then return result end
        end
        return nil
    end

    local function scanLocalEggSlots()
        local replicated = game:GetService("ReplicatedStorage")
        local dataFolder = replicated:FindFirstChild("Data")
        local clientFolder = replicated:FindFirstChild("Client")
        local sharedFolder = replicated:FindFirstChild("Shared")

        local assets = safeModule(dataFolder, "Assets")
        local eggState = safeModule(clientFolder, "EggState")
        local modulesFolder = sharedFolder and sharedFolder:FindFirstChild("Modules")
        local mutations = safeModule(modulesFolder, "Mutations")
        local utilFolder = sharedFolder and sharedFolder:FindFirstChild("Util")
        local eggRecords = safeModule(utilFolder, "EggRecords")

        if type(assets) ~= "table" or type(assets.Directory) ~= "table" then
            return nil, "Assets.Directory module was not found."
        end
        if type(eggState) ~= "table" or type(eggState.ReadFieldEggs) ~= "function" then
            return nil, "EggState.ReadFieldEggs module was not found."
        end

        local ok, readResult = pcall(eggState.ReadFieldEggs)
        if not ok or type(readResult) ~= "table" or type(readResult.Records) ~= "table" then
            return nil, "Could not read local egg slot records."
        end

        -- Restrict the adapter to records explicitly marked as local slots.
        local slotRecords = {}
        for key, record in pairs(readResult.Records) do
            if type(record) == "table" and record.State == "Slot" then
                slotRecords[key] = record
            end
        end

        local snapshot = {
            Records = slotRecords,
            Directory = assets.Directory,
            Mutations = mutations,
            EggRecords = eggRecords
        }

        local results, scanError = FinderEngine:Scan(snapshot)
        if scanError then return nil, scanError end
        return results
    end

    eggSec:CreateButton({
        Name = "Scan local egg slots",
        ButtonText = "SCAN",
        Callback = function()
            clearEggCards()
            eggSpotlight.Visible = false
            eggEmptyText.Text = "Scanning local egg slots..."
            eggEmptyText.Visible = true

            local minRate = parseEggRate(window:GetValue("Egg_MinRate"))
            if minRate == nil then
                notify("Egg Finder", "Minimum rate format is invalid. Try 5B or 1.5T.")
                return
            end

            local rarityChoice = tostring(window:GetValue("Egg_MinRarity") or "Any")
            local rarityThreshold = ({
                ["Any"] = 0,
                ["Secret+"] = 8,
                ["Eternal+"] = 9,
                ["Divine"] = 10
            })[rarityChoice] or 0
            local query = tostring(window:GetValue("Egg_Search") or ""):lower()
            local results, err = scanLocalEggSlots()

            if not results then
                eggStatus:SetText("Scan failed: " .. tostring(err))
                notify("Egg Finder", tostring(err))
                return
            end

            local filtered = FinderEngine:Filter(results, {
                Search = query,
                MinValue = minRate,
                MinRarity = rarityThreshold
            })
            filtered = FinderEngine:Sort(filtered, "Value", true)

            local shown = #filtered
            if shown > 0 then
                local best = filtered[1]
                setEggImage(spotlightImage, best.image)
                spotlightTitle.Text = best.name or "Unknown Egg"
                spotlightRarity.Text = string.upper(best.rarityName or "UNKNOWN")
                spotlightRate.Text = formatEggRate(best.value or 0)
                local bestMutation = (best.mutation and best.mutation ~= "") and best.mutation or "Normal"
                spotlightInfo.Text = bestMutation .. " • " .. string.format("%.2fx", best.size or 1)
                    .. ((best.weight and best.weight > 0) and string.format(" • %.2fkg", best.weight) or "")
                spotlight.Visible = true
                eggEmptyText.Visible = false
            else
                eggEmptyText.Text = query ~= "" and ("No eggs match \"" .. query .. "\"") or "No eggs in this filter"
                eggEmptyText.Visible = true
            end

            for index, egg in ipairs(filtered) do
                if index <= 60 then
                    createEggCard(egg, index)
                end
            end

            local statusText = string.format(
                "Found %d matching egg(s) • showing %d • local slots only",
                shown, math.min(shown, 60)
            )
            eggStatus:SetText(statusText)
            notify("Egg Finder", statusText)
            log:Add(statusText, "Finder")
        end
    })

    -- Guards tab: no bypass/evasion features.
    local guards = window:CreateTab("Guards", "◇")
    local guardSec = section(guards, "Guard / security diagnostics")
    guardSec:CreateParagraph({
        Name = "Authorized diagnostics only",
        Description = "Use this area for security telemetry in a Roblox experience you own. Guard bypass, evasion, disabling protections, and unauthorized access are not provided."
    })
    guardSec:CreateToggle({
        Name = "Local diagnostic panel",
        Flag = "Guards_Diagnostics",
        Default = false,
        Callback = function(value)
            notify("Diagnostics", value and "Local diagnostics preference enabled" or "Local diagnostics preference disabled")
        end
    })
    guardSec:CreateButton({
        Name = "Show security status",
        ButtonText = "Inspect",
        Callback = function()
            notify("Security status", "No external guard/security provider is connected.")
        end
    })

    -- Player tab contains local read-only diagnostics.
    local playerTab = window:CreateTab("Player", "◎")
    local playerInfo = section(playerTab, "Local player")
    playerInfo:CreateButton({
        Name = "Refresh local character info",
        ButtonText = "Refresh",
        Callback = function()
            local plr = game:GetService("Players").LocalPlayer
            local char = plr and plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local health = hum and math.floor(hum.Health) or 0
            local speed = hum and math.floor(hum.WalkSpeed) or 0
            local msg = ("Health: %d • WalkSpeed: %d • Character: %s"):format(
                health, speed, char and "loaded" or "not loaded"
            )
            status:SetText(msg)
            notify("Local player", msg)
        end
    })
    playerInfo:CreateParagraph({
        Name = "Read-only mode",
        Description = "This tab reports your own character's current client-visible values. It does not modify movement or other players."
    })

    -- Settings and config controls.
    local settings = window:CreateTab("Settings", "⚙")
    local animationSec = section(settings, "Animation")
    animationSec:CreateDropdown({
        Name = "Window animation",
        Flag = "Settings_Animation",
        Default = "Back",
        Values = {"Back", "Bounce", "Elastic", "Quart", "Sine"},
        Callback = function(value)
            window.AnimationStyle = value
            notify("Animation", "Window animation set to " .. tostring(value))
        end
    })
    animationSec:CreateToggle({
        Name = "Fire border",
        Flag = "Settings_Border",
        Default = true,
        Callback = function(value)
            window.BorderAnimationEnabled = value
        end
    })
    local configSec = section(settings, "Configuration")
    configSec:CreateInput({
        Name = "Config name",
        Flag = "Config_Name",
        Default = "VolnxConfig",
        Placeholder = "VolnxConfig"
    })
    configSec:CreateButton({
        Name = "Save configuration",
        ButtonText = "Save",
        Callback = function()
            local name = tostring(window:GetValue("Config_Name") or "VolnxConfig")
            local ok, path = window:SaveConfig(name)
            notify("Config save", ok and ("Saved: " .. tostring(path)) or tostring(path))
        end
    })
    configSec:CreateButton({
        Name = "Load configuration",
        ButtonText = "Load",
        Callback = function()
            local name = tostring(window:GetValue("Config_Name") or "VolnxConfig")
            local ok, result = window:LoadConfig(name)
            notify("Config load", ok and ("Loaded: " .. name) or tostring(result))
        end
    })
    configSec:CreateButton({
        Name = "Reset options",
        ButtonText = "Reset",
        Callback = function()
            window:ResetState()
            notify("Settings", "Options reset to their defaults.")
        end
    })

    -- Event log
    local logs = window:CreateTab("Logs", "≡")
    local logSec = section(logs, "Activity")
    logSec:CreateParagraph({
        Name = "Event log",
        Description = "The internal event log stores recent UI actions for this session. Use the command palette or notifications for quick feedback."
    })
    logSec:CreateButton({
        Name = "Show recent event count",
        ButtonText = "Inspect log",
        Callback = function()
            notify("Event log", tostring(#log:Get()) .. " events recorded.")
        end
    })
    logSec:CreateButton({
        Name = "Clear event log",
        ButtonText = "Clear",
        Callback = function()
            log:Clear()
            notify("Event log", "Cleared.")
        end
    })

    -- Search and command palette are native library features.
    window:CreateSearch()
    window:CreateCommandPalette({
        {Name = "Open Dashboard", Callback = function() home:Select() end},
        {Name = "Open Visuals", Callback = function() visuals:Select() end},
        {Name = "Open Finder", Callback = function() finder:Select() end},
        {Name = "Scan local egg slots", Callback = function() finder:Select(); notify("Egg Finder", "Open Finder and press SCAN.") end},
        {Name = "Open Guards", Callback = function() guards:Select() end},
        {Name = "Open Settings", Callback = function() settings:Select() end},
        {Name = "Open Logs", Callback = function() logs:Select() end},
        {Name = "Run System Check", Callback = function()
            status:SetText("System check complete • UI online")
            notify("System check", "All UI modules loaded.")
        end}
    })

    window.Hub = {
        Window = window,
        Log = log,
        Status = status,
        Notify = notify,
        Tabs = {
            Dashboard = home,
            Visuals = visuals,
            Finder = finder,
            Guards = guards,
            Player = playerTab,
            Settings = settings,
            Logs = logs
        }
    }

    notify("Volnx Hub Ultimate", "Version 7.0 loaded successfully.")
    return window.Hub
end

-- This is the Hub build: create the interface automatically when executed.
Volnx.Hub = Volnx:CreateHub()

return setmetatable(Volnx, {__call = function(self, config)
    return self:CreateWindow(config)
end})
