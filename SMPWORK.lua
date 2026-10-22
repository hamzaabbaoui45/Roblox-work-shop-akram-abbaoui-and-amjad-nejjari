--==============================================================================
--  SMPWORK  ·  MinimaHub  ·  Xeno Executor Build
--  A compact, draggable overlay ("small screen") UI in the style of Delta.
--
--  Credits : Akram Abbaoui  &  Amjad Nejjari
--  Project : SMPWORK (a clean-room build of MinimaHub)
--  Target  : Xeno (Luau) executor
--  Needs   : Drawing API, writefile/readfile, queue_on_teleport (optional)
--
--  Hosting : publish this file to GitHub and point SELF_URL at the raw URL.
--            The loader (loader.lua) fetches and runs this exact file.
--
--  Disclaimer: educational / testing only. Modifying the game client breaks
--  the Roblox Terms of Service and can get your account banned.
--==============================================================================

--------------------------------------------------------------------------------
-- 0. SOURCE / METADATA
--------------------------------------------------------------------------------

local AUTHOR_A   = "Akram Abbaoui"
local AUTHOR_B   = "Amjad Nejjari"
local PROJECT    = "SMPWORK"
local VERSION    = "1.0.0"
local CONFIG_FILE = "SMPWORK.json"

-- Raw URL of THIS file on GitHub.
--   1. push SMPWORK.lua to your repo
--   2. replace the placeholder below with:
--        https://raw.githubusercontent.com/<user>/<repo>/main/SMPWORK.lua
--   3. put the same URL in loader.lua
-- The hub uses it for "AUTO REATTACH" (surviving a teleport) and for the
-- "CHECK FOR UPDATES" button.
local SELF_URL   = "https://raw.githubusercontent.com/YOUR_USER/SMPWORK/main/SMPWORK.lua"

--------------------------------------------------------------------------------
-- 1. SERVICES / ENVIRONMENT
--------------------------------------------------------------------------------

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Http       = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer

-- Forward declarations so the closures below can reference them.
local Page    = nil
local Cleanup = nil

local function getCamera()
    return workspace.CurrentCamera
end

-- Where do we parent our GUI? Prefer the executor's own HUD, fall back to CoreGui.
local function resolveGuiParent()
    if type(gethui) == "function" then
        local ok, gui = pcall(gethui)
        if ok and gui then return gui end
    end
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- HTTP helper: executors expose different globals.
local function httpGet(url)
    for _, name in ipairs({ "request", "http_request", "syn_request" }) do
        local fn = rawget(_G, name)
        if type(fn) == "function" then
            local ok, res = pcall(fn, url)
            if ok and type(res) == "string" and #res > 0 then return res end
        end
    end
    if type(syn) == "table" and type(syn.request) == "function" then
        local ok, res = pcall(syn.request, { Url = url, Method = "GET" })
        if ok and type(res) == "string" and #res > 0 then return res end
        if ok and type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
            return res.Body
        end
    end
    return nil
end

-- Mouse position in *viewport* space (matches Camera:WorldToViewportPoint).
local function mouseViewport()
    local m = UIS:GetMouseLocation()
    local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
    if ok and inset then return m - inset end
    return m
end

-- Mouse position in *screen* space (matches the Drawing API).
local function mouseScreen()
    return UIS:GetMouseLocation()
end

--------------------------------------------------------------------------------
-- 2. THEME
--------------------------------------------------------------------------------

local Theme = {
    bg        = Color3.fromRGB(16, 17, 22),
    bgAlt     = Color3.fromRGB(22, 24, 31),
    panel     = Color3.fromRGB(27, 29, 37),
    hover     = Color3.fromRGB(35, 38, 48),
    stroke    = Color3.fromRGB(46, 50, 62),
    text      = Color3.fromRGB(228, 231, 240),
    textDim   = Color3.fromRGB(138, 144, 160),
    accent    = Color3.fromRGB(96, 165, 250),
    accentDim = Color3.fromRGB(52, 110, 190),
    onAccent  = Color3.fromRGB(10, 12, 18),
    good      = Color3.fromRGB(74, 222, 128),
    bad       = Color3.fromRGB(248, 113, 113),
}

-- Colour presets used by the ESP colour pickers.
local PALETTE = {
    Blue   = Color3.fromRGB(96, 165, 250),
    Red    = Color3.fromRGB(248, 113, 113),
    Green  = Color3.fromRGB(74, 222, 128),
    Yellow = Color3.fromRGB(250, 204, 21),
    Purple = Color3.fromRGB(167, 139, 250),
    Orange = Color3.fromRGB(251, 146, 60),
    Cyan   = Color3.fromRGB(34, 211, 238),
    White  = Color3.fromRGB(255, 255, 255),
    Black  = Color3.fromRGB(30, 32, 40),
}

local PALETTE_ORDER = { "Blue", "Red", "Green", "Yellow", "Purple", "Cyan", "White", "Black" }

local function palette(name)
    return PALETTE[name] or PALETTE.White
end

local Font     = Enum.Font.Gotham
local FontBold = Enum.Font.GothamBold
local FontMono = Enum.Font.Code

--------------------------------------------------------------------------------
-- 3. TINY GUI HELPERS
--------------------------------------------------------------------------------

-- create(class, props) -> instance
--   props.Parent is applied last so children are wired up before the parent
--   is attached to the tree.
local function create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" and k ~= "Children" then
            pcall(function() inst[k] = v end)
        end
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function round(inst, radius)
    create("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = inst })
end

local function stroke(inst, color, thickness)
    create("UIStroke", {
        Color = color or Theme.stroke,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = inst,
    })
end

-- Readable text colour for an arbitrary background.
local function readableOn(color)
    local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
    return lum > 0.55 and Theme.onAccent or Theme.text
end

local function toHex(c)
    return string.format("%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function fromHex(h)
    h = tostring(h):gsub("#", "")
    return Color3.fromRGB(
        tonumber(h:sub(1, 2), 16) or 255,
        tonumber(h:sub(3, 4), 16) or 255,
        tonumber(h:sub(5, 6), 16) or 255
    )
end

--------------------------------------------------------------------------------
-- 4. STATE
--------------------------------------------------------------------------------

local DEFAULTS = {
    visuals = {
        espBox            = false,
        espGlow           = false,
        espSkeleton       = false,
        espNametag        = false,
        espTracer         = false,
        wallcheck         = true,
        boxColorName      = "Blue",
        hiddenColorName   = "Red",
        skeletonColorName = "White",
        tracerColorName   = "Blue",
    },
    aim = {
        enabled  = false,
        target   = "Head",
        fov      = 150,   -- pixel radius around the mouse
        range    = 600,   -- maximum distance in studs
        smooth   = 6,
        wall     = true,
        showRing = true,
    },
    movement = {
        walkspeed    = 16,
        jumppower   = 50,
        fly          = false,
        flyspeed     = 70,
        noclip       = false,
        infiniteJump = false,
        safewalk     = false,
    },
    combat = {
        hitbox    = false,
        hitboxSz  = 8,
        spinbot   = false,
        spinSpeed = 20,
        fov       = false,
        fovValue  = 90,
    },
    utils = {
        clickTP  = false,
        reattach = true,
    },
}

-- live copy of DEFAULTS that the widgets read from / write to
local function copyTable(src)
    local out = {}
    for k, v in pairs(src) do out[k] = v end
    return out
end

local state = {
    visuals  = copyTable(DEFAULTS.visuals),
    aim      = copyTable(DEFAULTS.aim),
    movement = copyTable(DEFAULTS.movement),
    combat   = copyTable(DEFAULTS.combat),
    utils    = copyTable(DEFAULTS.utils),
}

-- path helpers ("visuals.espBox" -> value)
local function getPath(root, path)
    local node = root
    for part in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[part]
    end
    return node
end

local function setPath(root, path, value)
    local parts = {}
    for part in path:gmatch("[^%.]+") do parts[#parts + 1] = part end
    local node = root
    for i = 1, #parts - 1 do
        node[parts[i]] = node[parts[i]] or {}
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end

-- registry so loading a config can repaint every widget
local refreshers = {}
local function refresh(path)
    if refreshers[path] then refreshers[path]() end
end

--------------------------------------------------------------------------------
-- 5. PAGE + WIDGETS
--------------------------------------------------------------------------------

Page = {}
Page.__index = Page

function Page.new(container, name)
    local self = setmetatable({}, Page)
    self.name = name

    self.frame = create("ScrollingFrame", {
        Name                      = name,
        Size                      = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency    = 1,
        BorderSizePixel           = 0,
        ScrollBarThickness        = 3,
        ScrollBarImageColor3      = Theme.accent,
        ScrollBarImageTransparency = 0.6,
        AutomaticCanvasSize       = Enum.AutomaticSize.Y,
        CanvasSize                = UDim2.new(),
        ClipsDescendants           = true,
        Visible                   = false,
        Parent                    = container,
    })

    create("UIListLayout", {
        Padding   = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent    = self.frame,
    })
    create("UIPadding", {
        Left   = UDim.new(0, 9),
        Right  = UDim.new(0, 11),
        Top    = UDim.new(0, 7),
        Bottom = UDim.new(0, 8),
        Parent = self.frame,
    })

    return self
end

-- small uppercase header
function Page:section(text)
    local holder = create("Frame", {
        Size                  = UDim2.new(1, -4, 0, 18),
        BackgroundTransparency = 1,
        Parent                = self.frame,
    })
    create("TextLabel", {
        Size                  = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                  = string.upper(text),
        Font                  = FontBold,
        TextSize              = 10,
        TextColor3            = Theme.accent,
        TextXAlignment        = Enum.TextXAlignment.Left,
        Parent                = holder,
    })
    return holder
end

-- dim explanatory line
function Page:hint(text)
    create("TextLabel", {
        Size                  = UDim2.new(1, -4, 0, 16),
        AutomaticSize         = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text                  = text,
        Font                  = Font,
        TextSize              = 10,
        TextColor3            = Theme.textDim,
        TextXAlignment        = Enum.TextXAlignment.Left,
        TextYAlignment        = Enum.TextYAlignment.Top,
        TextWrapped           = true,
        Parent                = self.frame,
    })
end

-- ---- toggle -----------------------------------------------------------------
function Page:toggle(text, path, default, onChange)
    if getPath(state, path) == nil then
        setPath(state, path, default)
    end

    local row = create("Frame", {
        Size                  = UDim2.new(1, -4, 0, 22),
        BackgroundTransparency = 1,
        Parent                = self.frame,
    })

    create("TextLabel", {
        Size                  = UDim2.new(1, -44, 1, 0),
        BackgroundTransparency = 1,
        Text                  = text,
        Font                  = Font,
        TextSize              = 12,
        TextColor3            = Theme.text,
        TextXAlignment        = Enum.TextXAlignment.Left,
        Parent                = row,
    })

    local sw = create("Frame", {
        Size             = UDim2.fromOffset(32, 16),
        Position         = UDim2.new(1, -32, 0, 3),
        BackgroundColor3 = Theme.stroke,
        BorderSizePixel  = 0,
        Active           = true,
        Parent           = row,
    })
    round(sw, 8)

    local knob = create("Frame", {
        Size             = UDim2.fromOffset(12, 12),
        Position         = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Theme.textDim,
        BorderSizePixel  = 0,
        Parent           = sw,
    })
    round(knob, 6)

    local function paint(value)
        if value then
            sw.BackgroundColor3 = Theme.accentDim
            knob.BackgroundColor3 = Theme.accent
            knob.Position = UDim2.fromOffset(18, 2)
        else
            sw.BackgroundColor3 = Theme.stroke
            knob.BackgroundColor3 = Theme.textDim
            knob.Position = UDim2.fromOffset(2, 2)
        end
    end

    local function apply(value)
        setPath(state, path, value)
        paint(value)
        if onChange then onChange(value) end
    end

    local function flip()
        apply(not getPath(state, path))
    end

    -- clickable switch
    sw.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then flip() end
    end)

    -- clickable label
    local hit = create("TextButton", {
        Size                  = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        Text                  = "",
        AutoButtonColor       = false,
        Parent                = row,
    })
    hit.MouseButton1Click:Connect(flip)

    paint(getPath(state, path))
    refreshers[path] = function() paint(getPath(state, path)) end
    return row
end

-- ---- slider -----------------------------------------------------------------
function Page:slider(text, path, min, max, step, default, onChange)
    if getPath(state, path) == nil then
        setPath(state, path, default)
    end

    local row = create("Frame", {
        Size                  = UDim2.new(1, -4, 0, 38),
        BackgroundTransparency = 1,
        Parent                = self.frame,
    })

    create("TextLabel", {
        Size                  = UDim2.new(1, -60, 0, 16),
        BackgroundTransparency = 1,
        Text                  = text,
        Font                  = Font,
        TextSize              = 12,
        TextColor3            = Theme.text,
        TextXAlignment        = Enum.TextXAlignment.Left,
        Parent                = row,
    })

    local numberLabel = create("TextLabel", {
        Size                  = UDim2.fromOffset(56, 16),
        Position              = UDim2.new(1, -56, 0, 0),
        BackgroundTransparency = 1,
        Text                  = "",
        Font                  = FontMono,
        TextSize              = 11,
        TextColor3            = Theme.accent,
        TextXAlignment        = Enum.TextXAlignment.Right,
        Parent                = row,
    })

    local track = create("Frame", {
        Size             = UDim2.new(1, -4, 0, 6),
        Position         = UDim2.fromOffset(2, 26),
        BackgroundColor3 = Theme.panel,
        BorderSizePixel  = 0,
        Active           = true,
        Parent           = row,
    })
    round(track, 3)

    local fill = create("Frame", {
        Size             = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel  = 0,
        Parent           = track,
    })
    round(fill, 3)

    local knob = create("Frame", {
        Size             = UDim2.fromOffset(12, 12),
        Position         = UDim2.fromOffset(0, -3),
        BackgroundColor3 = Theme.text,
        BorderSizePixel  = 0,
        Active           = true,
        ZIndex           = 2,
        Parent           = track,
    })
    round(knob, 6)

    local function paint(value)
        local span = max - min
        local rel = span > 0 and ((value - min) / span) or 0
        rel = math.max(0, math.min(1, rel))
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0, -3)
        numberLabel.Text = tostring(value)
    end

    local function apply(value)
        if step and step > 0 then
            value = math.floor(value / step + 0.5) * step
        end
        value = math.max(min, math.min(max, value))
        setPath(state, path, value)
        paint(value)
        if onChange then onChange(value) end
    end

    local dragging = false
    local function fromX(x)
        local span = math.max(track.AbsoluteSize.X, 1)
        local rel = math.max(0, math.min(1, (x - track.AbsolutePosition.X) / span))
        apply(min + rel * (max - min))
    end

    local function beginDrag(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            fromX(input.Position.X)
        end
    end

    track.InputBegan:Connect(beginDrag)
    knob.InputBegan:Connect(beginDrag)
    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            fromX(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    paint(getPath(state, path))
    refreshers[path] = function() paint(getPath(state, path)) end
    return row
end

-- ---- button -----------------------------------------------------------------
function Page:button(text, onClick, color)
    local bg = color or Theme.accent
    local b = create("TextButton", {
        Size             = UDim2.new(1, -4, 0, 24),
        BackgroundColor3 = bg,
        BorderSizePixel  = 0,
        Text             = text,
        Font             = FontBold,
        TextSize         = 11,
        TextColor3       = readableOn(bg),
        AutoButtonColor  = false,
        Parent           = self.frame,
    })
    round(b, 6)
    b.MouseEnter:Connect(function() b.BackgroundColor3 = bg:Lerp(Color3.new(1, 1, 1), 0.12) end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = bg end)
    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(onClick)
        if not ok then
            print("[" .. PROJECT .. "] button '" .. text .. "' failed: " .. tostring(err))
        end
    end)
    return b
end

-- ---- cycling dropdown -------------------------------------------------------
function Page:cycle(text, path, options, default, onChange)
    if getPath(state, path) == nil then
        setPath(state, path, default)
    end

    local row = create("Frame", {
        Size                  = UDim2.new(1, -4, 0, 22),
        BackgroundTransparency = 1,
        Parent                = self.frame,
    })

    create("TextLabel", {
        Size                  = UDim2.new(1, -110, 1, 0),
        BackgroundTransparency = 1,
        Text                  = text,
        Font                  = Font,
        TextSize              = 12,
        TextColor3            = Theme.text,
        TextXAlignment        = Enum.TextXAlignment.Left,
        Parent                = row,
    })

    local valueLabel = create("TextButton", {
        Size             = UDim2.fromOffset(104, 18),
        Position         = UDim2.new(1, -104, 0, 2),
        BackgroundColor3 = Theme.panel,
        BorderSizePixel  = 0,
        Text             = "",
        Font             = FontMono,
        TextSize         = 11,
        TextColor3       = Theme.accent,
        AutoButtonColor  = false,
        Parent           = row,
    })
    round(valueLabel, 5)

    local function paint()
        valueLabel.Text = tostring(getPath(state, path))
    end

    valueLabel.MouseButton1Click:Connect(function()
        local current = getPath(state, path)
        local index = 1
        for i, opt in ipairs(options) do
            if opt == current then
                index = i
                break
            end
        end
        local nextValue = options[(index % #options) + 1]
        setPath(state, path, nextValue)
        paint()
        if onChange then onChange(nextValue) end
    end)

    paint()
    refreshers[path] = paint
    return row
end

--------------------------------------------------------------------------------
-- 6. WINDOW (the "small screen")
--------------------------------------------------------------------------------

local Window = {}
Window.__index = Window

local TABS = {
    { id = "visuals",  label = "Visuals" },
    { id = "aim",      label = "Aim"     },
    { id = "movement", label = "Move"    },
    { id = "combat",   label = "Combat"  },
    { id = "utils",    label = "Utils"   },
    { id = "config",   label = "Config"  },
}

function Window.new()
    local self = setmetatable({}, Window)

    self.gui = create("ScreenGui", {
        Name           = "MinimaHubScreen",
        ResetOnSpawn   = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder   = 999,
        Parent         = resolveGuiParent(),
    })

    self.frame = create("Frame", {
        Name              = "Window",
        Size              = UDim2.fromOffset(412, 300),
        Position          = UDim2.fromOffset(60, 70),
        BackgroundColor3  = Theme.bg,
        BorderSizePixel   = 0,
        Active            = true,
        Parent            = self.gui,
    })
    round(self.frame, 8)
    stroke(self.frame, Theme.stroke, 1)

    ------------------------------------------------------------------ title bar
    local title = create("Frame", {
        Name             = "Title",
        Size             = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Theme.bgAlt,
        BorderSizePixel  = 0,
        Active           = true,
        Parent           = self.frame,
    })
    round(title, 8)
    -- square off the bottom corners of the title bar
    create("Frame", {
        Size             = UDim2.new(1, 0, 0, 10),
        Position         = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = Theme.bgAlt,
        BorderSizePixel  = 0,
        ZIndex           = 1,
        Parent           = title,
    })

    -- logo chip
    local logo = create("Frame", {
        Size             = UDim2.fromOffset(16, 16),
        Position         = UDim2.fromOffset(10, 7),
        BackgroundColor3 = Theme.accent,
        BorderSizePixel  = 0,
        Parent           = title,
    })
    round(logo, 4)
    create("TextLabel", {
        Size                  = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                  = "M",
        Font                  = FontBold,
        TextSize              = 10,
        TextColor3            = Theme.onAccent,
        Parent                = logo,
    })

    create("TextLabel", {
        Size                  = UDim2.fromOffset(90, 30),
        Position              = UDim2.fromOffset(33, 0),
        BackgroundTransparency = 1,
        Text                  = "MINIMAHUB",
        Font                  = FontBold,
        TextSize              = 13,
        TextColor3            = Theme.text,
        TextXAlignment        = Enum.TextXAlignment.Left,
        Parent                = title,
    })

    create("TextLabel", {
        Size                  = UDim2.fromOffset(90, 30),
        Position              = UDim2.fromOffset(120, 0),
        BackgroundTransparency = 1,
        Text                  = PROJECT,
        Font                  = Font,
        TextSize              = 11,
        TextColor3            = Theme.textDim,
        TextXAlignment        = Enum.TextXAlignment.Left,
        Parent                = title,
    })

    -- window buttons: minimise / close
    local function titleButton(text, x)
        local b = create("TextButton", {
            Size             = UDim2.fromOffset(22, 22),
            Position         = UDim2.fromOffset(x, 4),
            BackgroundColor3 = Theme.panel,
            BorderSizePixel  = 0,
            Text             = text,
            Font             = FontBold,
            TextSize         = 13,
            TextColor3       = Theme.textDim,
            AutoButtonColor  = false,
            Parent           = title,
        })
        round(b, 5)
        b.MouseEnter:Connect(function() b.BackgroundColor3 = Theme.hover end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = Theme.panel end)
        return b
    end

    local btnMin   = titleButton("-", 352)
    local btnClose = titleButton("x", 378)
    btnClose.MouseEnter:Connect(function() btnClose.TextColor3 = Theme.bad end)
    btnClose.MouseLeave:Connect(function() btnClose.TextColor3 = Theme.textDim end)

    --------------------------------------------------------------------- body
    local body = create("Frame", {
        Name             = "Body",
        Size             = UDim2.new(1, 0, 1, -50),
        Position         = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = Theme.bg,
        BorderSizePixel  = 0,
        Parent           = self.frame,
    })
    self.body = body

    local rail = create("Frame", {
        Size             = UDim2.new(0, 84, 1, 0),
        BackgroundColor3 = Theme.bgAlt,
        BorderSizePixel  = 0,
        Parent           = body,
    })

    self.pageHost = create("Frame", {
        Size             = UDim2.new(1, -84, 1, 0),
        Position         = UDim2.fromOffset(84, 0),
        BackgroundColor3 = Theme.bg,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        Parent           = body,
    })

    ------------------------------------------------------------------- footer
    local footer = create("Frame", {
        Size             = UDim2.new(1, 0, 0, 20),
        Position         = UDim2.new(0, 0, 1, -20),
        BackgroundColor3 = Theme.bgAlt,
        BorderSizePixel  = 0,
        Parent           = self.frame,
    })
    self.footer = footer
    create("TextLabel", {
        Size                  = UDim2.new(1, -110, 1, 0),
        Position              = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        Text                  = "by " .. AUTHOR_A .. " & " .. AUTHOR_B,
        Font                  = Font,
        TextSize              = 11,
        TextColor3            = Theme.textDim,
        TextXAlignment        = Enum.TextXAlignment.Left,
        Parent                = footer,
    })
    create("TextLabel", {
        Size                  = UDim2.fromOffset(90, 20),
        Position              = UDim2.new(1, -98, 0, 0),
        BackgroundTransparency = 1,
        Text                  = "v" .. VERSION,
        Font                  = FontMono,
        TextSize              = 10,
        TextColor3            = Theme.textDim,
        TextXAlignment        = Enum.TextXAlignment.Right,
        Parent                = footer,
    })

    -------------------------------------------------------------------- toast
    -- transient message strip shown above the footer.
    -- NB: the instance field is "toastLabel" so it does not shadow the
    -- Window:toast() method below.
    self.toastLabel = create("TextLabel", {
        Size                  = UDim2.new(1, -24, 0, 24),
        Position              = UDim2.new(0, 12, 1, -50),
        BackgroundColor3      = Theme.panel,
        BackgroundTransparency = 1,
        Text                  = "",
        Font                  = Font,
        TextSize              = 11,
        TextColor3            = Theme.text,
        TextXAlignment        = Enum.TextXAlignment.Center,
        TextYAlignment        = Enum.TextYAlignment.Center,
        TextTruncate          = Enum.TextTruncate.AtEnd,
        Visible               = false,
        ZIndex                = 20,
        Parent                = self.frame,
    })
    round(self.toastLabel, 6)
    self.toastRemaining = 0

    ------------------------------------------------------------------- pages
    self.pages       = {}
    self.railButtons = {}

    for index, tab in ipairs(TABS) do
        local page = Page.new(self.pageHost, tab.id)
        self.pages[tab.id] = page

        local btn = create("TextButton", {
            Size             = UDim2.new(1, -12, 0, 26),
            Position         = UDim2.fromOffset(6, 6 + (index - 1) * 29),
            BackgroundColor3 = Theme.bgAlt,
            BorderSizePixel  = 0,
            Text             = tab.label,
            Font             = Font,
            TextSize         = 12,
            TextColor3       = Theme.textDim,
            TextXAlignment   = Enum.TextXAlignment.Left,
            AutoButtonColor  = false,
            Parent           = rail,
        })
        round(btn, 6)

        -- selection pill on the left of the active tab
        local pill = create("Frame", {
            Size             = UDim2.fromOffset(3, 14),
            Position         = UDim2.fromOffset(-3, 6),
            BackgroundColor3 = Theme.accent,
            BorderSizePixel  = 0,
            Visible          = false,
            ZIndex           = 2,
            Parent           = btn,
        })
        round(pill, 2)

        btn.MouseEnter:Connect(function()
            btn.TextColor3 = Theme.text
            btn.BackgroundColor3 = Theme.hover
        end)
        btn.MouseLeave:Connect(function()
            btn.TextColor3 = Theme.textDim
            btn.BackgroundColor3 = Theme.bgAlt
        end)
        btn.MouseButton1Click:Connect(function()
            self:select(tab.id)
        end)

        self.railButtons[tab.id] = { button = btn, pill = pill }
    end

    ------------------------------------------------------------------- drag
    self:makeDraggable(title, { btnMin, btnClose })

    ----------------------------------------------------------------- buttons
    btnMin.MouseButton1Click:Connect(function() self:toggleMinimise() end)
    btnClose.MouseButton1Click:Connect(function()
        if Cleanup then Cleanup.destroy() end
    end)

    self.minimised = false
    self.frameSize = self.frame.Size

    self:select(TABS[1].id)
    return self
end

-- Drags the window by its title bar. `exclude` lists buttons that must not
-- start a drag (otherwise clicking - / x would nudge the window around).
function Window:makeDraggable(handle, exclude)
    local dragging, offX, offY = false, 0, 0

    local function blocked(x, y)
        for _, button in ipairs(exclude or {}) do
            local p = button.AbsolutePosition
            local s = button.AbsoluteSize
            if x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y then
                return true
            end
        end
        return false
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if blocked(input.Position.X, input.Position.Y) then return end
            dragging = true
            local p = self.frame.Position
            offX = input.Position.X - p.X.Offset
            offY = input.Position.Y - p.Y.Offset
        end
    end)

    handle.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            self.frame.Position = UDim2.fromOffset(
                math.max(-self.frameSize.X.Offset + 60, input.Position.X - offX),
                math.max(0, input.Position.Y - offY)
            )
        end
    end)

    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

function Window:select(id)
    for key, page in pairs(self.pages) do
        page.frame.Visible = (key == id)
    end
    for key, entry in pairs(self.railButtons) do
        local active = (key == id)
        entry.pill.Visible = active
        entry.button.TextColor3 = active and Theme.text or Theme.textDim
        entry.button.BackgroundColor3 = active and Theme.hover or Theme.bgAlt
    end
    self.active = id
end

-- Show a short-lived message strip above the footer.
function Window:toast(text, colour, duration)
    if not self.toastLabel then return end
    self.toastLabel.Text = text
    self.toastLabel.TextColor3 = colour or Theme.text
    self.toastLabel.BackgroundTransparency = 0.15
    self.toastLabel.Visible = true
    self.toastRemaining = duration or 2.5
end

-- Collapse the window down to just the title bar.
function Window:toggleMinimise()
    self.minimised = not self.minimised
    if self.body then self.body.Visible = not self.minimised end
    if self.footer then self.footer.Visible = not self.minimised end
    self.frame.Size = self.minimised
        and UDim2.fromOffset(self.frameSize.X.Offset, 30)
        or UDim2.fromOffset(self.frameSize.X.Offset, self.frameSize.Y.Offset)
end

function Window:toggleVisible()
    self.frame.Visible = not self.frame.Visible
end

--------------------------------------------------------------------------------
-- 7. FEATURES
--------------------------------------------------------------------------------

local Connections = {}

local function connect(signal, handler)
    local c = signal:Connect(handler)
    Connections[#Connections + 1] = c
    return c
end

-- ---- character helpers ------------------------------------------------------
local function localCharacter()
    return LocalPlayer and LocalPlayer.Character
end

local function localHumanoid()
    local c = localCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function localRoot()
    local c = localCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- saved values so DESTROY can restore them
local saved = {
    walkspeed = nil,
    jumppower = nil,
    useJumpPower = nil,
    fov = nil,
    hitboxes = {},
    hitboxAlpha = {},
}

-- ---- ESP ---------------------------------------------------------------------
local espCache = {}   -- [player] = { box, glow, tag, tracer, lines = {} }

local function clearESP(player)
    local entry = espCache[player]
    if not entry then return end
    if entry.box then entry.box:Remove() end
    if entry.tag then entry.tag:Remove() end
    if entry.tracer then entry.tracer:Remove() end
    if entry.glow then entry.glow:Destroy() end
    for _, line in pairs(entry.lines or {}) do line:Remove() end
    espCache[player] = nil
end

local function clearAllESP()
    for player in pairs(espCache) do clearESP(player) end
    espCache = {}
end

local BONES_R6 = {
    { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
    { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}

local BONES_R15 = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

local function getBones(character)
    if character:FindFirstChild("UpperTorso") then return BONES_R15 end
    if character:FindFirstChild("Torso") then return BONES_R6 end
    return {}
end

-- Raycast filter: our own character + (optionally) the character we are testing.
local function losFilter(extra)
    local list = {}
    local c = localCharacter()
    if c then list[#list + 1] = c end
    if extra then list[#list + 1] = extra end
    return list
end

-- True when nothing solid sits between the camera and the target.
local function hasLineOfSight(origin, target, targetCharacter)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = losFilter(targetCharacter)
    local direction = target - origin
    if direction.Magnitude < 0.001 then return true end
    local result = workspace:Raycast(origin, direction, params)
    return result == nil
end

local function ensureESP(player)
    if espCache[player] then return espCache[player] end
    if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then return nil end

    local entry = { lines = {} }

    entry.box = Drawing.new("Circle")
    entry.box.Thickness = 1
    entry.box.Filled = false
    entry.box.Visible = false

    entry.tag = Drawing.new("Text")
    entry.tag.Visible = false
    entry.tag.Outline = true
    entry.tag.Center = true
    entry.tag.Font = FontBold
    entry.tag.Size = 12

    entry.tracer = Drawing.new("Line")
    entry.tracer.Thickness = 1
    entry.tracer.Visible = false

    espCache[player] = entry
    return entry
end

local function renderESP()
    local vis = state.visuals
    local camera = getCamera()
    if not camera then return end
    local viewport = camera.ViewportSize

    local visibleColor = palette(vis.boxColorName)
    local hiddenColor  = palette(vis.hiddenColorName)
    local boneColor    = palette(vis.skeletonColorName)
    local tracerColor  = palette(vis.tracerColorName)

    for player, entry in pairs(espCache) do
        local character = player and player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local alive = humanoid and humanoid.Health > 0

        if not alive then
            if entry.box then entry.box.Visible = false end
            if entry.tag then entry.tag.Visible = false end
            if entry.tracer then entry.tracer.Visible = false end
            if entry.glow then entry.glow.Enabled = false end
            for _, line in pairs(entry.lines) do line.Visible = false end
        else
            local root  = character:FindFirstChild("HumanoidRootPart")
            local head  = character:FindFirstChild("Head")

            if root and head and humanoid then
                local origin = camera.CFrame.Position
                local visible = hasLineOfSight(origin, head.Position, character)
                local color = (vis.wallcheck and not visible) and hiddenColor or visibleColor

                -- glow (Highlight instance)
                if vis.espGlow then
                    if not entry.glow then
                        entry.glow = create("Highlight", {
                            Name = "MinimaGlow",
                            FillTransparency = 0.55,
                            OutlineTransparency = 1,
                            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                            Parent = character,
                        })
                    end
                    entry.glow.Enabled = true
                    entry.glow.Adornee = character
                    entry.glow.FillColor = color
                    entry.glow.OutlineColor = color
                elseif entry.glow then
                    entry.glow.Enabled = false
                end

                -- box
                if vis.espBox then
                    local pos, onScreen = camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        local size = (root.Size.X + root.Size.Z) / 2
                        entry.box.Visible = true
                        entry.box.Position = Vector2.new(pos.X - size / 2, pos.Y - size / 2)
                        entry.box.Size = Vector2.new(size, size + (root.Size.Y / 2))
                        entry.box.Color = color
                        entry.box.Transparency = 0.85
                        entry.box.ZIndex = 1
                    else
                        entry.box.Visible = false
                    end
                elseif entry.box then
                    entry.box.Visible = false
                end

                -- nametag
                if vis.espNametag then
                    local pos, onScreen = camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local dist = (root.Position - origin).Magnitude
                        entry.tag.Visible = true
                        entry.tag.Position = Vector2.new(pos.X, pos.Y - 16)
                        entry.tag.Text = string.format("%s  %d  %dm",
                            player.DisplayName or player.Name,
                            math.ceil(humanoid.Health),
                            math.floor(dist))
                        entry.tag.Color = color
                        entry.tag.ZIndex = 2
                    else
                        entry.tag.Visible = false
                    end
                elseif entry.tag then
                    entry.tag.Visible = false
                end

                -- tracer
                if vis.espTracer then
                    local pos, onScreen = camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        entry.tracer.Visible = true
                        entry.tracer.From = Vector2.new(viewport.X / 2, viewport.Y)
                        entry.tracer.To = Vector2.new(pos.X, pos.Y)
                        entry.tracer.Color = tracerColor
                        entry.tracer.Transparency = 0.9
                        entry.tracer.ZIndex = 0
                    else
                        entry.tracer.Visible = false
                    end
                elseif entry.tracer then
                    entry.tracer.Visible = false
                end

                -- skeleton
                if vis.espSkeleton then
                    local bones = getBones(character)
                    for i, pair in ipairs(bones) do
                        local a = character:FindFirstChild(pair[1])
                        local b = character:FindFirstChild(pair[2])
                        local line = entry.lines[i]
                        if a and b then
                            local pa, oa = camera:WorldToViewportPoint(a.Position)
                            local pb, ob = camera:WorldToViewportPoint(b.Position)
                            if oa and ob then
                                if not line then
                                    line = Drawing.new("Line")
                                    line.Thickness = 1.4
                                    line.ZIndex = 1
                                    entry.lines[i] = line
                                end
                                line.Visible = true
                                line.From = Vector2.new(pa.X, pa.Y)
                                line.To = Vector2.new(pb.X, pb.Y)
                                line.Color = boneColor
                                line.Transparency = 0.9
                            elseif line then
                                line.Visible = false
                            end
                        elseif line then
                            line.Visible = false
                        end
                    end
                else
                    for _, line in pairs(entry.lines) do line.Visible = false end
                end
            end
        end
    end
end

-- ---- FOV ring ----------------------------------------------------------------
local fovRing = nil

local function ensureFOVRing()
    if fovRing then return fovRing end
    if type(Drawing) ~= "table" or type(Drawing.new) ~= "function" then return nil end
    fovRing = Drawing.new("Circle")
    fovRing.Thickness = 1
    fovRing.Filled = false
    fovRing.NumSides = 60
    fovRing.Visible = false
    fovRing.ZIndex = 0
    return fovRing
end

-- ---- aimbot ------------------------------------------------------------------
local function getAimTarget()
    local camera = getCamera()
    if not camera then return nil end
    local mouse = mouseViewport()
    local best, bestScore = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local part = player.Character:FindFirstChild(state.aim.target)
                    or player.Character:FindFirstChild("Head")
                if part then
                    local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local screenDist = (Vector2.new(pos.X, pos.Y) - mouse).Magnitude
                        local worldDist = (part.Position - camera.CFrame.Position).Magnitude
                        if screenDist <= state.aim.fov and worldDist <= state.aim.range then
                            if screenDist < bestScore then
                                bestScore = screenDist
                                best = {
                                    part = part,
                                    player = player,
                                    humanoid = humanoid,
                                    character = player.Character,
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function runAimbot(dt)
    if not state.aim.enabled then return end
    if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    local camera = getCamera()
    if not camera then return end
    local target = getAimTarget()
    if not target then return end

    if state.aim.wall and not hasLineOfSight(camera.CFrame.Position, target.part.Position, target.character) then
        return
    end

    local goal    = target.part.Position
    local current = camera.CFrame
    local alpha   = math.clamp(1 - math.exp(-state.aim.smooth * dt), 0, 1)
    local newPos  = current.Position:Lerp(goal, alpha)
    local dir     = goal - newPos
    if dir.Magnitude < 0.001 then dir = current.LookVector end
    camera.CFrame = CFrame.lookAt(newPos, newPos + dir.Unit, current.UpVector)
end

-- ---- movement ----------------------------------------------------------------
local function applyWalkSpeed(value)
    local hum = localHumanoid()
    if not hum then return end
    if saved.walkspeed == nil then saved.walkspeed = hum.WalkSpeed end
    hum.WalkSpeed = value
end

local function applyJumpPower(value)
    local hum = localHumanoid()
    if not hum then return end
    if saved.jumppower == nil then
        saved.jumppower = hum.JumpPower
        saved.useJumpPower = hum.UseJumpPower
    end
    hum.JumpPower = value
    hum.UseJumpPower = true
end

local function runFly(dt)
    if not state.movement.fly then return end
    local root = localRoot()
    local hum  = localHumanoid()
    local camera = getCamera()
    if not root or not hum or not camera then return end

    local dir = Vector3.new(0, 0, 0)
    if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + camera.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - camera.CFrame.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + camera.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - camera.CFrame.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end

    if dir.Magnitude > 0 then
        root.AssemblyLinearVelocity = dir.Unit * state.movement.flyspeed
        hum:ChangeState(Enum.HumanoidStateType.Physics)
    end
end

local function runNoclip()
    if not state.movement.noclip then return end
    local c = localCharacter()
    if not c then return end
    for _, part in pairs(c:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function runSafewalk()
    if not state.movement.safewalk then return end
    local root = localRoot()
    local hum  = localHumanoid()
    if not root or not hum then return end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = losFilter()

    local result = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), params)
    if result then
        local s = hum:GetState()
        if s == Enum.HumanoidStateType.Freefall or s == Enum.HumanoidStateType.FallingDown then
            local v = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
    end
end

-- ---- combat ------------------------------------------------------------------
local function applyHitbox(size)
    local c = localCharacter()
    if not c then return end
    local parts = { "Head", "HumanoidRootPart", "UpperTorso", "Torso" }
    for _, name in ipairs(parts) do
        local part = c:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            if saved.hitboxes[name] == nil then
                saved.hitboxes[name] = part.Size
                saved.hitboxAlpha[name] = part.Transparency
            end
            part.Size = Vector3.new(size, size, size)
            part.Transparency = 1
        end
    end
end

local function restoreHitbox()
    local c = localCharacter()
    for name, size in pairs(saved.hitboxes) do
        local part = c and c:FindFirstChild(name)
        if part then
            part.Size = size
            part.Transparency = saved.hitboxAlpha[name] or 0
        end
    end
    saved.hitboxes = {}
    saved.hitboxAlpha = {}
end

local function runSpinbot(dt)
    if not state.combat.spinbot then return end
    local root = localRoot()
    if not root then return end
    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(state.combat.spinSpeed * 12 * dt), 0)
end

local function applyCameraFOV(value)
    local camera = getCamera()
    if not camera then return end
    if saved.fov == nil then saved.fov = camera.FieldOfView end
    camera.FieldOfView = value
end

local function restoreCameraFOV()
    local camera = getCamera()
    if camera and saved.fov ~= nil then camera.FieldOfView = saved.fov end
    saved.fov = nil
end

-- ---- utilities ---------------------------------------------------------------
local function mouseOverUI()
    local window = Window.instance
    if not window or not window.frame or not window.frame.Visible then return false end
    local p = window.frame.AbsolutePosition
    local s = window.frame.AbsoluteSize
    local m = mouseScreen()
    return m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
end

local function clickTeleport()
    local camera = getCamera()
    local root = localRoot()
    if not camera or not root then return end
    local mouse = mouseViewport()
    local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = losFilter()

    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    if result then
        root.CFrame = CFrame.new(result.Position + ray.Direction * 4)
        root.AssemblyLinearVelocity = Vector3.zero
    end
end

local function teleportTo(placeId, serverId)
    local ok, ts = pcall(function() return game:GetService("TeleportService") end)
    if ok and ts then
        pcall(function() ts:TeleportToPlaceInstance(placeId, serverId, LocalPlayer) end)
    end
    pcall(function() game:Teleport(placeId, serverId) end)
end

local function serverHop()
    local placeId = game.PlaceId
    local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=2&limit=100"
    local body = httpGet(url)
    if not body then
        -- fall back to the in-engine service if the executor has no HTTP
        local ok, svc = pcall(function() return game:GetService("GameHttpService") end)
        if ok and svc then
            local ok2, servers = pcall(function() return svc:GetServersAsync() end)
            if ok2 and servers and servers[1] then
                teleportTo(placeId, servers[1].id)
                return
            end
        end
        return
    end

    local ok, decoded = pcall(function() return Http:JSONDecode(body) end)
    if ok and decoded and decoded.data and decoded.data[1] then
        teleportTo(placeId, decoded.data[1].id)
    end
end

-- Names we look for on disk when re-queueing ourselves after a teleport.
local SOURCE_CACHE_NAME = PROJECT .. ".src"
local LOCAL_SOURCE_NAMES = {
    SOURCE_CACHE_NAME,      -- "SMPWORK.src"  (written by cacheSelfSource)
    PROJECT .. ".lua",      -- "SMPWORK.lua"
    "SMPWORK.lua",
    "MinimaHub-Xeno.lua",
}

-- Cache our own source next to the config so reattach keeps working even
-- when the script was pasted in rather than loaded from disk.
local function cacheSelfSource()
    if type(writefile) ~= "function" then return false end
    if type(readfile) ~= "function" then return false end
    local source = nil
    for _, name in ipairs(LOCAL_SOURCE_NAMES) do
        local chunk = nil
        pcall(function() chunk = readfile(name) end)
        if type(chunk) == "string" and #chunk > 0 then
            source = chunk
            break
        end
    end
    if not source then return false end
    pcall(writefile, SOURCE_CACHE_NAME, source)
    return true
end

-- Returns true when a reattach was queued, otherwise false + a reason.
local function autoReattach()
    if type(queue_on_teleport) ~= "function" then
        return false, "executor has no queue_on_teleport"
    end

    -- 1. a copy we cached earlier
    if type(readfile) == "function" then
        for _, name in ipairs(LOCAL_SOURCE_NAMES) do
            local source = nil
            pcall(function() source = readfile(name) end)
            if type(source) == "string" and #source > 0 then
                queue_on_teleport(source)
                return true
            end
        end
    end

    -- 2. the GitHub copy of this exact script
    if SELF_URL ~= "" and not SELF_URL:find("YOUR_USER", 1, true) then
        queue_on_teleport('loadstring(game:HttpGet("' .. SELF_URL .. '"))()')
        return true
    end
    return false, "no local source and SELF_URL is not configured"
end

-- Compare the version published on GitHub with the running one.
local function checkForUpdates()
    if SELF_URL == "" or SELF_URL:find("YOUR_USER", 1, true) then
        return nil, "SELF_URL is not configured yet"
    end
    local body = httpGet(SELF_URL)
    if not body then return nil, "could not reach GitHub" end

    local remote = body:match('VERSION%s*=%s*"([^"]+)"')
    if not remote then return nil, "remote version not found" end
    if remote == VERSION then return false, "up to date" end
    return true, remote
end

--------------------------------------------------------------------------------
-- 8. CONFIG
--------------------------------------------------------------------------------

local function serialise(value)
    if type(value) == "Color3" then
        return { __c = toHex(value) }
    elseif type(value) == "table" then
        local out = {}
        for k, v in pairs(value) do out[k] = serialise(v) end
        return out
    end
    return value
end

local function deserialise(value)
    if type(value) ~= "table" then return value end
    if value.__c then return fromHex(value.__c) end
    local out = {}
    for k, v in pairs(value) do out[k] = deserialise(v) end
    return out
end

local function deepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and not v.__c and type(target[k]) == "table" then
            deepMerge(target[k], v)
        elseif target[k] ~= nil then
            target[k] = v
        end
    end
end

local function copyState()
    local out = {}
    for group, values in pairs(DEFAULTS) do
        out[group] = copyTable(values)
    end
    return out
end

local function saveConfig()
    if type(writefile) ~= "function" then return false end
    local ok, encoded = pcall(function() return Http:JSONEncode(serialise(state)) end)
    if not ok then return false end
    return pcall(writefile, CONFIG_FILE, encoded)
end

local function loadConfig()
    if type(readfile) ~= "function" then return false end
    local ok, content = pcall(readfile, CONFIG_FILE)
    if not ok or type(content) ~= "string" or #content == 0 then return false end
    local ok2, decoded = pcall(function() return Http:JSONDecode(content) end)
    if not ok2 or type(decoded) ~= "table" then return false end
    deepMerge(state, deserialise(decoded))
    for path in pairs(refreshers) do refresh(path) end
    return true
end

local function resetConfig()
    local defaults = copyState()
    deepMerge(state, defaults)
    for path in pairs(refreshers) do refresh(path) end
    applyWalkSpeed(state.movement.walkspeed)
    applyJumpPower(state.movement.jumppower)
    if state.combat.fov then applyCameraFOV(state.combat.fovValue) end
    if state.combat.hitbox then applyHitbox(state.combat.hitboxSz) else restoreHitbox() end
end

--------------------------------------------------------------------------------
-- 9. BUILD THE UI
--------------------------------------------------------------------------------

local EXTERNAL = {
    { name = "Dex Explorer",   url = "https://raw.githubusercontent.com/infyiam/dex/master/dex.lua" },
    { name = "Infinite Yield", url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source.lua" },
    -- edit these if a URL goes stale
    { name = "Shadow Hub",     url = "https://raw.githubusercontent.com/1nic/Shadow-Hub/main/README.md" },
    { name = "UNC Checker",    url = "https://raw.githubusercontent.com/unknowncheats/unknowncheats.github.io/main/unc.lua" },
}

local function buildUI()
    local window = Window.new()
    Window.instance = window

    ------------------------------------------------------------------- visuals
    local vis = window.pages.visuals
    vis:section("ESP")
    vis:toggle("Box", "visuals.espBox", false)
    vis:toggle("Glow", "visuals.espGlow", false)
    vis:toggle("Skeleton", "visuals.espSkeleton", false)
    vis:toggle("Nametag", "visuals.espNametag", false)
    vis:toggle("Tracers", "visuals.espTracer", false)
    vis:toggle("Wall check", "visuals.wallcheck", true)
    vis:hint("Wall check recolours the ESP when the target is behind geometry.")

    vis:section("Colours")
    vis:cycle("Visible", "visuals.boxColorName", PALETTE_ORDER, "Blue")
    vis:cycle("Hidden", "visuals.hiddenColorName", PALETTE_ORDER, "Red")
    vis:cycle("Skeleton", "visuals.skeletonColorName", PALETTE_ORDER, "White")
    vis:cycle("Tracers", "visuals.tracerColorName", PALETTE_ORDER, "Blue")

    ------------------------------------------------------------------------ aim
    local aim = window.pages.aim
    aim:section("Aimbot")
    aim:toggle("Enable aimbot", "aim.enabled", false)
    aim:toggle("Show FOV ring", "aim.showRing", true)
    aim:toggle("Wall check", "aim.wall", true)
    aim:cycle("Target", "aim.target", { "Head", "UpperTorso", "HumanoidRootPart" }, "Head")
    aim:slider("FOV radius", "aim.fov", 30, 600, 10, 150)
    aim:slider("Max range", "aim.range", 50, 2000, 10, 600)
    aim:slider("Smoothing", "aim.smooth", 1, 40, 1, 6)
    aim:hint("Hold RIGHT MOUSE to aim. Lower smoothing = snappier lock.")

    ------------------------------------------------------------------- movement
    local move = window.pages.movement
    move:section("Movement")
    move:slider("Walk speed", "movement.walkspeed", 0, 200, 1, 16, applyWalkSpeed)
    move:slider("Jump power", "movement.jumppower", 0, 300, 1, 50, applyJumpPower)
    move:section("Toggles")
    move:toggle("Fly", "movement.fly", false)
    move:slider("Fly speed", "movement.flyspeed", 10, 400, 5, 70)
    move:toggle("Noclip", "movement.noclip", false)
    move:toggle("Infinite jump", "movement.infiniteJump", false)
    move:toggle("Safewalk", "movement.safewalk", false)
    move:hint("Fly: WASD + Space / LeftControl. Infinite jump re-jumps while airborne.")

    -------------------------------------------------------------------- combat
    local combat = window.pages.combat
    combat:section("Combat")
    combat:toggle("Hitbox expander", "combat.hitbox", false, function(value)
        if value then
            applyHitbox(state.combat.hitboxSz)
        else
            restoreHitbox()
        end
    end)
    combat:slider("Hitbox size", "combat.hitboxSz", 1, 30, 1, 8, function(value)
        if state.combat.hitbox then applyHitbox(value) end
    end)
    combat:toggle("Spinbot", "combat.spinbot", false)
    combat:slider("Spin speed", "combat.spinSpeed", 1, 60, 1, 20)
    combat:toggle("Custom FOV", "combat.fov", false, function(value)
        if value then
            applyCameraFOV(state.combat.fovValue)
        else
            restoreCameraFOV()
        end
    end)
    combat:slider("FOV value", "combat.fovValue", 50, 120, 1, 90, function(value)
        if state.combat.fov then applyCameraFOV(value) end
    end)

    --------------------------------------------------------------------- utils
    local utils = window.pages.utils
    utils:section("Movement")
    utils:toggle("Click teleport", "utils.clickTP", false)
    utils:hint("With Click teleport on, a left click in the world teleports you there.")
    utils:section("Actions")
    utils:button("TELEPORT TO CURSOR", function()
        clickTeleport()
        window:toast("Teleported to cursor", Theme.good)
    end)
    utils:button("SERVER HOPPER", function()
        window:toast("Finding a server...", Theme.text)
        serverHop()
    end)
    utils:toggle("Auto reattach", "utils.reattach", true)
    utils:button("QUEUE REATTACH", function()
        local queued, why = autoReattach()
        if queued then
            window:toast("Reattach queued for next teleport", Theme.good)
        else
            window:toast("Reattach not queued: " .. tostring(why), Theme.bad)
        end
    end)
    utils:section("External")
    for _, item in ipairs(EXTERNAL) do
        utils:button("LOAD: " .. item.name, function()
            window:toast("Fetching " .. item.name .. "...", Theme.text)
            local src = httpGet(item.url)
            if src then
                local chunk = loadstring(src)
                if chunk then
                    chunk()
                    window:toast(item.name .. " loaded", Theme.good)
                end
            else
                window:toast("Could not reach " .. item.name, Theme.bad)
            end
        end, Theme.panel)
    end
    utils:section("Danger zone")
    utils:button("DESTROY SCRIPT", function()
        if Cleanup then Cleanup.destroy() end
    end, Theme.bad)
    utils:hint("DESTROY removes the GUI, restores hitboxes / speed / FOV and stops every loop.")

    -------------------------------------------------------------------- config
    local cfg = window.pages.config
    cfg:section("Configuration")
    cfg:button("SAVE CONFIG", function()
        if saveConfig() then
            window:toast("Config saved to " .. CONFIG_FILE, Theme.good)
        else
            window:toast("Save failed - no writefile()", Theme.bad)
        end
    end)
    cfg:button("LOAD CONFIG", function()
        if loadConfig() then
            window:toast("Config loaded", Theme.good)
        else
            window:toast("No config found", Theme.bad)
        end
    end)
    cfg:button("RESET TO DEFAULTS", function()
        resetConfig()
        window:toast("Defaults restored", Theme.text)
    end, Theme.panel)

    cfg:section("GitHub")
    cfg:button("CHECK FOR UPDATES", function()
        window:toast("Checking GitHub...", Theme.text)
        local newer, info = checkForUpdates()
        if newer == nil then
            window:toast("Update check failed: " .. tostring(info), Theme.bad)
        elseif newer then
            window:toast("Update available: v" .. tostring(info), Theme.accent)
        else
            window:toast("You are on the latest version", Theme.good)
        end
    end)
    cfg:button("RELOAD FROM GITHUB", function()
        if SELF_URL == "" or SELF_URL:find("YOUR_USER", 1, true) then
            window:toast("Set SELF_URL first", Theme.bad)
            return
        end
        window:toast("Reloading from GitHub...", Theme.text)
        local src = httpGet(SELF_URL)
        if not src then
            window:toast("Could not reach GitHub", Theme.bad)
            return
        end
        if Cleanup then Cleanup.destroy() end
        local chunk = loadstring(src)
        if chunk then
            chunk()
            window:toast("Reloaded", Theme.good)
        else
            window:toast("Bad source from GitHub", Theme.bad)
        end
    end, Theme.panel)

    cfg:section("Info")
    cfg:hint(PROJECT .. " v" .. VERSION)
    cfg:hint("Config file: " .. CONFIG_FILE)
    cfg:hint("RightControl toggles the overlay.")
    cfg:hint("Made by " .. AUTHOR_A .. " & " .. AUTHOR_B .. ".")

    return window
end

--------------------------------------------------------------------------------
-- 10. RUNTIME LOOPS
--------------------------------------------------------------------------------

local function startLoops()
    connect(Players.PlayerRemoving, function(player)
        clearESP(player)
    end)

    connect(LocalPlayer.CharacterAdded, function(character)
        character:WaitForChild("Humanoid")
        character:WaitForChild("HumanoidRootPart")
        applyWalkSpeed(state.movement.walkspeed)
        applyJumpPower(state.movement.jumppower)
        if state.combat.hitbox then applyHitbox(state.combat.hitboxSz) end
    end)

    connect(RunService.RenderStepped, function(dt)
        -- fade the toast strip back out
        local window = Window.instance
        if window and window.toastLabel and window.toastLabel.Visible then
            window.toastRemaining = window.toastRemaining - dt
            if window.toastRemaining <= 0 then
                window.toastLabel.Visible = false
            elseif window.toastRemaining < 0.5 then
                window.toastLabel.BackgroundTransparency = 0.15 + (0.5 - window.toastRemaining)
            end
        end

        -- keep the ESP cache in sync with the player list
        local anyESP = state.visuals.espBox or state.visuals.espGlow or state.visuals.espSkeleton
            or state.visuals.espNametag or state.visuals.espTracer
        if anyESP then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then ensureESP(player) end
            end
        elseif next(espCache) ~= nil then
            clearAllESP()
        end

        renderESP()
        runAimbot(dt)
        runFly(dt)
        runSpinbot(dt)

        -- FOV ring
        local ring = ensureFOVRing()
        if ring then
            local camera = getCamera()
            if state.aim.showRing and state.aim.enabled and camera then
                local m = mouseScreen()
                ring.Visible = true
                ring.Position = Vector2.new(m.X, m.Y)
                ring.Radius = state.aim.fov
                ring.Color = Theme.accent
                ring.Transparency = 0.75
            else
                ring.Visible = false
            end
        end
    end)

    -- physics loop for noclip / safewalk
    connect(RunService.Stepped, function()
        runNoclip()
        runSafewalk()
    end)

    -- infinite jump
    connect(UIS.JumpRequest, function()
        if not state.movement.infiniteJump then return end
        local hum = localHumanoid()
        if hum and hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)

    -- click teleport
    connect(UIS.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if state.utils.clickTP and not mouseOverUI() then
                clickTeleport()
            end
        end
    end)

    -- UI toggle
    connect(UIS.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.KeyCode
            and input.KeyCode == Enum.KeyCode.RightControl then
            if Window.instance then Window.instance:toggleVisible() end
        end
    end)
end

--------------------------------------------------------------------------------
-- 11. CLEANUP
--------------------------------------------------------------------------------

Cleanup = {}

function Cleanup.destroy()
    -- stop loops
    for _, c in ipairs(Connections) do
        pcall(function() c:Disconnect() end)
    end
    Connections = {}

    -- kill drawings
    clearAllESP()
    if fovRing then
        fovRing:Remove()
        fovRing = nil
    end

    -- restore the character
    restoreHitbox()
    local hum = localHumanoid()
    if hum then
        if saved.walkspeed ~= nil then hum.WalkSpeed = saved.walkspeed end
        if saved.jumppower ~= nil then hum.JumpPower = saved.jumppower end
        if saved.useJumpPower ~= nil then hum.UseJumpPower = saved.useJumpPower end
    end
    restoreCameraFOV()
    saved.walkspeed = nil
    saved.jumppower = nil
    saved.useJumpPower = nil

    -- remove the GUI
    if Window.instance and Window.instance.gui then
        pcall(function() Window.instance.gui:Destroy() end)
    end
    Window.instance = nil
end

--------------------------------------------------------------------------------
-- 12. BOOT
--------------------------------------------------------------------------------

local function boot()
    -- build the UI first so the widgets exist, then overlay the saved config
    local window = buildUI()
    startLoops()

    loadConfig()

    -- keep a copy of ourselves on disk so a teleport can re-run us
    cacheSelfSource()

    -- apply the loaded / default values once
    applyWalkSpeed(state.movement.walkspeed)
    applyJumpPower(state.movement.jumppower)
    if state.combat.fov then applyCameraFOV(state.combat.fovValue) end
    if state.combat.hitbox then applyHitbox(state.combat.hitboxSz) end
    if state.utils.reattach then autoReattach() end

    print("[" .. PROJECT .. "] " .. AUTHOR_A .. " & " .. AUTHOR_B .. " - v" .. VERSION
        .. " loaded. RightControl toggles the UI.")
    return window
end

local ok, err = pcall(boot)
if not ok then
    print("[" .. PROJECT .. "] boot failed: " .. tostring(err))
end
