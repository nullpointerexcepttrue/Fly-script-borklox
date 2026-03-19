-- ╔════════════════════════════════════════════╗
-- ║       TRAPVERSE FLYER                      ║
-- ║       Harvey Specter Edition               ║
-- ║       LocalScript — StarterPlayerScripts   ║
-- ╚════════════════════════════════════════════╝

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(char)
	character = char
	humanoid  = char:WaitForChild("Humanoid")
	rootPart  = char:WaitForChild("HumanoidRootPart")
end)

-- ─── STATE ────────────────────────────────────────────────────────────────────
local flying             = false
local flySpeed           = 50
local bodyVelocity, bodyGyro, flyConnection

local tagsEnabled        = false
local showDistance       = true
local trackedTags        = {}

local infiniteJumpEnabled = false
local noclipEnabled       = false

local keys = { W=false, A=false, S=false, D=false, Space=false, Shift=false }

local function updateCharacterReferences()
	if not character or not character.Parent then
		character = player.Character or player.CharacterAdded:Wait()
	end
	if not humanoid or not humanoid.Parent then
		humanoid = character:WaitForChild("Humanoid")
	end
	if not rootPart or not rootPart.Parent then
		rootPart = character:WaitForChild("HumanoidRootPart")
	end
end

-- ─── PALETTE — Harvey Specter / Old Money ─────────────────────────────────────
--  Obsidian blacks, aged gold, cold champagne whites, silk charcoal
local C = {
	-- Backgrounds
	Void        = Color3.fromRGB(6,   6,   7),    -- near-true black
	Obsidian    = Color3.fromRGB(11,  11,  13),   -- panel base
	Charcoal    = Color3.fromRGB(18,  18,  21),   -- surface
	Slate       = Color3.fromRGB(26,  26,  31),   -- raised elements
	SlateHover  = Color3.fromRGB(32,  32,  38),   -- hover state

	-- Gold
	Gold        = Color3.fromRGB(196, 160,  90),  -- primary accent — aged gold
	GoldBright  = Color3.fromRGB(222, 186, 116),  -- highlight
	GoldDim     = Color3.fromRGB( 68,  52,  22),  -- active track fill
	GoldLine    = Color3.fromRGB( 80,  62,  24),  -- subtle gold border

	-- Typography
	Ivory       = Color3.fromRGB(240, 236, 225),  -- primary text
	Champagne   = Color3.fromRGB(185, 178, 160),  -- secondary text
	Ash         = Color3.fromRGB( 80,  78,  72),  -- muted / disabled

	-- Borders
	Wire        = Color3.fromRGB( 36,  36,  42),  -- default border
	WireGold    = Color3.fromRGB( 90,  70,  28),  -- active border

	-- Status
	ActiveKnob  = Color3.fromRGB(210, 175, 100),
	InactiveKnob= Color3.fromRGB( 55,  54,  50),
}

-- ─── TWEEN SHORTHAND ──────────────────────────────────────────────────────────
local TI_FAST   = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TI_MED    = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function tw(obj, props, ti)
	TweenService:Create(obj, ti or TI_FAST, props):Play()
end

-- ─── UI UTILITY FUNCTIONS ─────────────────────────────────────────────────────
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = p
	return c
end

local function stroke(p, col, thick)
	local s = Instance.new("UIStroke")
	s.Color             = col   or C.Wire
	s.Thickness         = thick or 1
	s.ApplyStrokeMode   = Enum.ApplyStrokeMode.Border
	s.Parent            = p
	return s
end

local function pad(p, t, b, l, r)
	local u = Instance.new("UIPadding")
	u.PaddingTop    = UDim.new(0, t or 0)
	u.PaddingBottom = UDim.new(0, b or 0)
	u.PaddingLeft   = UDim.new(0, l or 0)
	u.PaddingRight  = UDim.new(0, r or 0)
	u.Parent        = p
end

local function label(parent, text, size, color, font, xAlign, yAlign)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size             = UDim2.new(1, 0, 1, 0)
	l.Text             = text
	l.TextColor3       = color  or C.Ivory
	l.TextSize         = size   or 13
	l.Font             = font   or Enum.Font.Gotham
	l.TextXAlignment   = xAlign or Enum.TextXAlignment.Left
	l.TextYAlignment   = yAlign or Enum.TextYAlignment.Center
	l.TextTruncate     = Enum.TextTruncate.AtEnd
	l.Parent           = parent
	return l
end

local function divider(parent, order)
	local f = Instance.new("Frame")
	f.Size             = UDim2.new(1, 0, 0, 1)
	f.BackgroundColor3 = C.Wire
	f.BorderSizePixel  = 0
	f.LayoutOrder      = order or 0
	f.Parent           = parent
	return f
end

-- Gold monogram diamond ornament (decorative TextLabel)
local function ornament(parent, txt, size, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size       = UDim2.new(0, size*2, 0, size*2)
	l.Text       = txt
	l.TextColor3 = color or C.Gold
	l.TextSize   = size
	l.Font       = Enum.Font.GothamBold
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent     = parent
	return l
end

-- ─── TOGGLE ROW ───────────────────────────────────────────────────────────────
local function makeToggleRow(parent, labelText, order)
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1, 0, 0, 44)
	row.BackgroundColor3 = C.Slate
	row.BorderSizePixel  = 0
	row.LayoutOrder      = order or 0
	row.Parent           = parent
	corner(row, 5)
	local rowStroke = stroke(row, C.Wire)

	-- Left gold pip
	local pip = Instance.new("Frame")
	pip.Size             = UDim2.new(0, 2, 0, 20)
	pip.Position         = UDim2.new(0, 0, 0.5, -10)
	pip.BackgroundColor3 = C.Ash
	pip.BorderSizePixel  = 0
	pip.Parent           = row
	corner(pip, 1)

	-- Label
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size           = UDim2.new(1, -80, 1, 0)
	lbl.Position       = UDim2.new(0, 18, 0, 0)
	lbl.Text           = labelText
	lbl.TextColor3     = C.Champagne
	lbl.TextSize       = 12
	lbl.Font           = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent         = row

	-- Pill track
	local track = Instance.new("Frame")
	track.Size             = UDim2.new(0, 42, 0, 22)
	track.Position         = UDim2.new(1, -56, 0.5, -11)
	track.BackgroundColor3 = C.Charcoal
	track.BorderSizePixel  = 0
	track.Parent           = row
	corner(track, 11)
	local trackStroke = stroke(track, C.Wire)

	local knob = Instance.new("Frame")
	knob.Size             = UDim2.new(0, 16, 0, 16)
	knob.Position         = UDim2.new(0, 3, 0.5, -8)
	knob.BackgroundColor3 = C.InactiveKnob
	knob.BorderSizePixel  = 0
	knob.Parent           = track
	corner(knob, 8)

	-- Click capture
	local btn = Instance.new("TextButton")
	btn.Size                = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                = ""
	btn.Parent              = row

	-- Status word
	local statusLbl = Instance.new("TextLabel")
	statusLbl.BackgroundTransparency = 1
	statusLbl.Size           = UDim2.new(0, 32, 0, 14)
	statusLbl.Position       = UDim2.new(1, -100, 0.5, -7)
	statusLbl.Text           = "OFF"
	statusLbl.TextColor3     = C.Ash
	statusLbl.TextSize       = 9
	statusLbl.Font           = Enum.Font.GothamBold
	statusLbl.TextXAlignment = Enum.TextXAlignment.Right
	statusLbl.Parent         = row

	local function refresh(on)
		if on then
			tw(track,      { BackgroundColor3 = C.GoldDim  })
			tw(trackStroke,{ Color            = C.WireGold })
			tw(knob,       { Position         = UDim2.new(0, 23, 0.5, -8),
			                 BackgroundColor3 = C.Gold })
			tw(rowStroke,  { Color            = C.GoldLine })
			tw(pip,        { BackgroundColor3 = C.Gold     })
			tw(lbl,        { TextColor3       = C.Ivory    })
			tw(statusLbl,  { TextColor3       = C.GoldBright })
			statusLbl.Text = "ON"
		else
			tw(track,      { BackgroundColor3 = C.Charcoal })
			tw(trackStroke,{ Color            = C.Wire     })
			tw(knob,       { Position         = UDim2.new(0, 3, 0.5, -8),
			                 BackgroundColor3 = C.InactiveKnob })
			tw(rowStroke,  { Color            = C.Wire     })
			tw(pip,        { BackgroundColor3 = C.Ash      })
			tw(lbl,        { TextColor3       = C.Champagne})
			tw(statusLbl,  { TextColor3       = C.Ash      })
			statusLbl.Text = "OFF"
		end
	end

	btn.MouseEnter:Connect(function()
		tw(row, { BackgroundColor3 = C.SlateHover })
	end)
	btn.MouseLeave:Connect(function()
		tw(row, { BackgroundColor3 = C.Slate })
	end)

	return { button = btn, refresh = refresh, row = row }
end

-- ─── SMALL SQUARE BUTTON ──────────────────────────────────────────────────────
local function makeSquareBtn(parent, txt)
	local b = Instance.new("TextButton")
	b.Size             = UDim2.new(0, 30, 0, 30)
	b.BackgroundColor3 = C.Charcoal
	b.Text             = txt
	b.TextColor3       = C.Champagne
	b.TextSize         = 16
	b.Font             = Enum.Font.GothamBold
	b.BorderSizePixel  = 0
	b.Parent           = parent
	corner(b, 4)
	stroke(b, C.Wire)

	b.MouseEnter:Connect(function()
		tw(b, { BackgroundColor3 = C.GoldDim, TextColor3 = C.GoldBright })
	end)
	b.MouseLeave:Connect(function()
		tw(b, { BackgroundColor3 = C.Charcoal, TextColor3 = C.Champagne })
	end)
	b.MouseButton1Down:Connect(function()
		tw(b, { BackgroundColor3 = C.Gold, TextColor3 = C.Void })
	end)
	b.MouseButton1Up:Connect(function()
		tw(b, { BackgroundColor3 = C.GoldDim, TextColor3 = C.GoldBright })
	end)
	return b
end

-- ══════════════════════════════════════════════════════════════════════════════
--  ROOT GUI
-- ══════════════════════════════════════════════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name          = "TrapverseFlyer"
screenGui.ResetOnSpawn  = false
screenGui.ZIndexBehavior= Enum.ZIndexBehavior.Sibling
screenGui.Parent        = playerGui

local PW, PH = 310, 420

local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.new(0, PW, 0, PH)
panel.Position         = UDim2.new(0.5, -PW/2, 0.5, -PH/2)
panel.BackgroundColor3 = C.Obsidian
panel.BorderSizePixel  = 0
panel.ClipsDescendants = true
panel.Parent           = screenGui
corner(panel, 8)
stroke(panel, C.Wire)

-- ── Thin gold top accent line ─────────────────────────────────────────────────
local topLine = Instance.new("Frame")
topLine.Size             = UDim2.new(1, 0, 0, 1)
topLine.BackgroundColor3 = C.Gold
topLine.BorderSizePixel  = 0
topLine.ZIndex           = 6
topLine.Parent           = panel

-- ── HEADER BAND ───────────────────────────────────────────────────────────────
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 62)
header.Position         = UDim2.new(0, 0, 0, 1)
header.BackgroundColor3 = C.Charcoal
header.BorderSizePixel  = 0
header.ZIndex           = 2
header.Parent           = panel

-- Subtle diagonal grid texture simulation via layered frames
-- (two faint diagonal lines crossing, purely decorative)
local function faintLine(xScale, yScale, w, h, rot)
	local f = Instance.new("Frame")
	f.Size             = UDim2.new(0, w, 0, h)
	f.Position         = UDim2.new(xScale, 0, yScale, 0)
	f.BackgroundColor3 = C.Gold
	f.BackgroundTransparency = 0.92
	f.BorderSizePixel  = 0
	f.Rotation         = rot or 0
	f.ZIndex           = 3
	f.Parent           = header
end
faintLine(0, 0, 2, 200, 30)
faintLine(0.3, 0, 2, 200, 30)
faintLine(0.6, 0, 2, 200, 30)
faintLine(0.9, 0, 2, 200, 30)

-- Wordmark — left side
local wordmark = Instance.new("TextLabel")
wordmark.BackgroundTransparency = 1
wordmark.Size           = UDim2.new(0, 190, 0, 28)
wordmark.Position       = UDim2.new(0, 16, 0, 10)
wordmark.Text           = "TRAPVERSE"
wordmark.TextColor3     = C.Ivory
wordmark.TextSize       = 19
wordmark.Font           = Enum.Font.GothamBold
wordmark.TextXAlignment = Enum.TextXAlignment.Left
wordmark.ZIndex         = 4
wordmark.Parent         = header

-- Sub-wordmark
local subWord = Instance.new("TextLabel")
subWord.BackgroundTransparency = 1
subWord.Size           = UDim2.new(0, 190, 0, 16)
subWord.Position       = UDim2.new(0, 16, 0, 34)
subWord.Text           = "F L Y E R"
subWord.TextColor3     = C.Gold
subWord.TextSize       = 10
subWord.Font           = Enum.Font.GothamBold
subWord.TextXAlignment = Enum.TextXAlignment.Left
subWord.ZIndex         = 4
subWord.Parent         = header

-- Gold monogram square — right side (like a cufflink / signet ring)
local signet = Instance.new("Frame")
signet.Size             = UDim2.new(0, 36, 0, 36)
signet.Position         = UDim2.new(1, -86, 0.5, -18)
signet.BackgroundColor3 = C.GoldDim
signet.BorderSizePixel  = 0
signet.ZIndex           = 4
signet.Parent           = header
corner(signet, 4)
stroke(signet, C.Gold)

local signetText = Instance.new("TextLabel")
signetText.BackgroundTransparency = 1
signetText.Size           = UDim2.new(1, 0, 1, 0)
signetText.Text           = "TF"
signetText.TextColor3     = C.Gold
signetText.TextSize       = 13
signetText.Font           = Enum.Font.GothamBold
signetText.TextXAlignment = Enum.TextXAlignment.Center
signetText.ZIndex         = 5
signetText.Parent         = signet

-- Minimize button
local minBtn = Instance.new("TextButton")
minBtn.Size             = UDim2.new(0, 26, 0, 26)
minBtn.Position         = UDim2.new(1, -42, 0.5, -13)
minBtn.BackgroundColor3 = C.Slate
minBtn.Text             = "−"
minBtn.TextColor3       = C.Champagne
minBtn.TextSize         = 16
minBtn.Font             = Enum.Font.GothamBold
minBtn.BorderSizePixel  = 0
minBtn.ZIndex           = 5
minBtn.Parent           = header
corner(minBtn, 4)
stroke(minBtn, C.Wire)

minBtn.MouseEnter:Connect(function()
	tw(minBtn, { BackgroundColor3 = C.GoldDim, TextColor3 = C.Gold })
end)
minBtn.MouseLeave:Connect(function()
	tw(minBtn, { BackgroundColor3 = C.Slate, TextColor3 = C.Champagne })
end)

-- Thin gold separator under header
local headerLine = Instance.new("Frame")
headerLine.Size             = UDim2.new(1, 0, 0, 1)
headerLine.Position         = UDim2.new(0, 0, 0, 63)
headerLine.BackgroundColor3 = C.GoldLine
headerLine.BorderSizePixel  = 0
headerLine.ZIndex           = 2
headerLine.Parent           = panel

-- ── SCROLLABLE BODY ───────────────────────────────────────────────────────────
local body = Instance.new("ScrollingFrame")
body.Size                = UDim2.new(1, 0, 1, -64)
body.Position            = UDim2.new(0, 0, 0, 64)
body.BackgroundTransparency = 1
body.BorderSizePixel     = 0
body.ScrollBarThickness  = 2
body.ScrollBarImageColor3= C.Gold
body.CanvasSize          = UDim2.new(0, 0, 0, 0)
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.Parent              = panel

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection  = Enum.FillDirection.Vertical
listLayout.SortOrder      = Enum.SortOrder.LayoutOrder
listLayout.Padding        = UDim.new(0, 6)
listLayout.Parent         = body

pad(body, 14, 16, 14, 14)

-- ── SECTION HEADER ────────────────────────────────────────────────────────────
local function sectionHead(parent, txt, order)
	local wrap = Instance.new("Frame")
	wrap.Size             = UDim2.new(1, 0, 0, 20)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder      = order
	wrap.Parent           = parent

	local ll = Instance.new("Frame")
	ll.Size             = UDim2.new(0, 8, 0, 1)
	ll.Position         = UDim2.new(0, 0, 0.5, 0)
	ll.BackgroundColor3 = C.Gold
	ll.BorderSizePixel  = 0
	ll.Parent           = wrap

	local sl = Instance.new("TextLabel")
	sl.BackgroundTransparency = 1
	sl.Size           = UDim2.new(1, -14, 1, 0)
	sl.Position       = UDim2.new(0, 14, 0, 0)
	sl.Text           = txt:upper()
	sl.TextColor3     = C.Gold
	sl.TextSize       = 9
	sl.Font           = Enum.Font.GothamBold
	sl.TextXAlignment = Enum.TextXAlignment.Left
	sl.Parent         = wrap

	return wrap
end

-- ══════════════════════════════════════════════════════════════════════════════
--  SECTION: MOVEMENT
-- ══════════════════════════════════════════════════════════════════════════════
sectionHead(body, "Movement", 10)

local flyToggle = makeToggleRow(body, "Fly Mode", 20)

-- ── Speed Control Row ─────────────────────────────────────────────────────────
local speedCard = Instance.new("Frame")
speedCard.Size             = UDim2.new(1, 0, 0, 44)
speedCard.BackgroundColor3 = C.Slate
speedCard.BorderSizePixel  = 0
speedCard.LayoutOrder      = 30
speedCard.Parent           = body
corner(speedCard, 5)
stroke(speedCard, C.Wire)

-- Left pip
local sPip = Instance.new("Frame")
sPip.Size             = UDim2.new(0, 2, 0, 20)
sPip.Position         = UDim2.new(0, 0, 0.5, -10)
sPip.BackgroundColor3 = C.Ash
sPip.BorderSizePixel  = 0
sPip.Parent           = speedCard
corner(sPip, 1)

local speedName = Instance.new("TextLabel")
speedName.BackgroundTransparency = 1
speedName.Size           = UDim2.new(0, 80, 1, 0)
speedName.Position       = UDim2.new(0, 18, 0, 0)
speedName.Text           = "Speed"
speedName.TextColor3     = C.Champagne
speedName.TextSize       = 12
speedName.Font           = Enum.Font.GothamSemibold
speedName.TextXAlignment = Enum.TextXAlignment.Left
speedName.Parent         = speedCard

-- Value display — gold badge feel
local speedBadge = Instance.new("Frame")
speedBadge.Size             = UDim2.new(0, 44, 0, 26)
speedBadge.Position         = UDim2.new(0.5, -22, 0.5, -13)
speedBadge.BackgroundColor3 = C.GoldDim
speedBadge.BorderSizePixel  = 0
speedBadge.Parent           = speedCard
corner(speedBadge, 4)
stroke(speedBadge, C.GoldLine)

local speedVal = Instance.new("TextLabel")
speedVal.BackgroundTransparency = 1
speedVal.Size           = UDim2.new(1, 0, 1, 0)
speedVal.Text           = "50"
speedVal.TextColor3     = C.GoldBright
speedVal.TextSize       = 14
speedVal.Font           = Enum.Font.GothamBold
speedVal.TextXAlignment = Enum.TextXAlignment.Center
speedVal.Parent         = speedBadge

local minusBtn = makeSquareBtn(speedCard, "−")
minusBtn.Position = UDim2.new(1, -82, 0.5, -15)
local plusBtn  = makeSquareBtn(speedCard, "+")
plusBtn.Position  = UDim2.new(1, -44, 0.5, -15)

-- ── DIVIDER ───────────────────────────────────────────────────────────────────
divider(body, 35)

-- ══════════════════════════════════════════════════════════════════════════════
--  SECTION: UTILITIES
-- ══════════════════════════════════════════════════════════════════════════════
sectionHead(body, "Utilities", 38)

local tagsToggle   = makeToggleRow(body, "Player Tags",     50)
local jumpToggle   = makeToggleRow(body, "Infinite Jump",   60)
local noclipToggle = makeToggleRow(body, "Noclip",          70)

-- ── FOOTER ────────────────────────────────────────────────────────────────────
local footerCard = Instance.new("Frame")
footerCard.Size             = UDim2.new(1, 0, 0, 34)
footerCard.BackgroundColor3 = C.Void
footerCard.BorderSizePixel  = 0
footerCard.LayoutOrder      = 90
footerCard.Parent           = body
corner(footerCard, 5)
stroke(footerCard, C.Wire)

-- Gold diamond ornament flanked by dots
local footerTxt = Instance.new("TextLabel")
footerTxt.BackgroundTransparency = 1
footerTxt.Size           = UDim2.new(1, 0, 1, 0)
footerTxt.Text           = "· WASD  ·  Space ↑  ·  Shift ↓ ·"
footerTxt.TextColor3     = C.Ash
footerTxt.TextSize       = 10
footerTxt.Font           = Enum.Font.GothamSemibold
footerTxt.TextXAlignment = Enum.TextXAlignment.Center
footerTxt.Parent         = footerCard

-- ══════════════════════════════════════════════════════════════════════════════
--  DRAG
-- ══════════════════════════════════════════════════════════════════════════════
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging  = true
		dragStart = input.Position
		startPos  = panel.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
header.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input == dragInput then
		local d = input.Position - dragStart
		panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  MINIMIZE
-- ══════════════════════════════════════════════════════════════════════════════
local minimized = false

minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	if minimized then
		body.Visible = false
		headerLine.Visible = false
		tw(panel, { Size = UDim2.new(0, PW, 0, 64) }, TI_MED)
	else
		tw(panel, { Size = UDim2.new(0, PW, 0, PH) }, TI_MED)
		task.delay(0.2, function()
			body.Visible      = true
			headerLine.Visible= true
		end)
	end
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  FLY LOGIC
-- ══════════════════════════════════════════════════════════════════════════════
local function stopFlying()
	flying = false
	flyToggle.refresh(false)
	if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
	if bodyVelocity  then bodyVelocity:Destroy();    bodyVelocity  = nil end
	if bodyGyro      then bodyGyro:Destroy();        bodyGyro      = nil end
	if humanoid      then humanoid.PlatformStand     = false             end
end

local function startFlying()
	updateCharacterReferences()
	if not humanoid or not rootPart then return end
	flying = true
	flyToggle.refresh(true)

	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.Parent   = rootPart

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	bodyGyro.P         = 10000
	bodyGyro.CFrame    = rootPart.CFrame
	bodyGyro.Parent    = rootPart

	humanoid.PlatformStand = true

	flyConnection = RunService.RenderStepped:Connect(function()
		updateCharacterReferences()
		if not flying or not rootPart or not camera then stopFlying(); return end

		local dir = Vector3.zero
		if keys.W     then dir += camera.CFrame.LookVector  end
		if keys.S     then dir -= camera.CFrame.LookVector  end
		if keys.A     then dir -= camera.CFrame.RightVector end
		if keys.D     then dir += camera.CFrame.RightVector end
		if keys.Space then dir += Vector3.new(0,1,0)        end
		if keys.Shift then dir -= Vector3.new(0,1,0)        end

		if dir.Magnitude > 0 then dir = dir.Unit end
		bodyVelocity.Velocity = dir * flySpeed
		bodyGyro.CFrame       = camera.CFrame
	end)
end

flyToggle.button.MouseButton1Click:Connect(function()
	if flying then stopFlying() else startFlying() end
end)

plusBtn.MouseButton1Click:Connect(function()
	flySpeed = math.min(flySpeed + 10, 200)
	speedVal.Text = tostring(flySpeed)
end)

minusBtn.MouseButton1Click:Connect(function()
	flySpeed = math.max(flySpeed - 10, 10)
	speedVal.Text = tostring(flySpeed)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  TAGS LOGIC
-- ══════════════════════════════════════════════════════════════════════════════
local function removeTag(tp)
	local d = trackedTags[tp]
	if d and d.billboard then d.billboard:Destroy() end
	trackedTags[tp] = nil
end

local function createTag(tp, tc)
	if tp == player or not tc then return end
	local head = tc:FindFirstChild("Head")
	local hrp  = tc:FindFirstChild("HumanoidRootPart")
	local hum  = tc:FindFirstChildOfClass("Humanoid")
	if not head or not hrp or not hum then return end
	removeTag(tp)

	local bb = Instance.new("BillboardGui")
	bb.Size        = UDim2.new(0, 120, 0, 34)
	bb.StudsOffset = Vector3.new(0, 4.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 220
	bb.Adornee     = head
	bb.Parent      = playerGui

	local bg = Instance.new("Frame")
	bg.Size             = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = C.Obsidian
	bg.BackgroundTransparency = 0.05
	bg.BorderSizePixel  = 0
	bg.Parent           = bb
	corner(bg, 5)
	stroke(bg, C.GoldLine)

	-- Left gold accent bar
	local bar = Instance.new("Frame")
	bar.Size             = UDim2.new(0, 3, 0, 22)
	bar.Position         = UDim2.new(0, 4, 0.5, -11)
	bar.BackgroundColor3 = C.Gold
	bar.BorderSizePixel  = 0
	bar.Parent           = bg
	corner(bar, 1)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size           = UDim2.new(1, -14, 0.55, 0)
	nameLbl.Position       = UDim2.new(0, 12, 0, 0)
	nameLbl.Text           = tp.DisplayName
	nameLbl.TextColor3     = C.Ivory
	nameLbl.TextSize       = 11
	nameLbl.Font           = Enum.Font.GothamBold
	nameLbl.TextWrapped    = true
	nameLbl.Parent         = bg

	local distLbl = Instance.new("TextLabel")
	distLbl.BackgroundTransparency = 1
	distLbl.Size           = UDim2.new(1, -14, 0.45, 0)
	distLbl.Position       = UDim2.new(0, 12, 0.55, 0)
	distLbl.Text           = "0 studs"
	distLbl.TextColor3     = C.Gold
	distLbl.TextSize       = 9
	distLbl.Font           = Enum.Font.Gotham
	distLbl.Parent         = bg

	trackedTags[tp] = { character = tc, billboard = bb, distanceLabel = distLbl }
end

local function setTagsEnabled(state)
	tagsEnabled = state
	tagsToggle.refresh(state)
	if not state then
		for tp in pairs(trackedTags) do removeTag(tp) end
	else
		for _, op in ipairs(Players:GetPlayers()) do
			if op ~= player and op.Character then createTag(op, op.Character) end
		end
	end
end

tagsToggle.button.MouseButton1Click:Connect(function()
	setTagsEnabled(not tagsEnabled)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  INFINITE JUMP
-- ══════════════════════════════════════════════════════════════════════════════
local function setInfiniteJump(state)
	infiniteJumpEnabled = state
	jumpToggle.refresh(state)
end
jumpToggle.button.MouseButton1Click:Connect(function()
	setInfiniteJump(not infiniteJumpEnabled)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  NOCLIP
-- ══════════════════════════════════════════════════════════════════════════════
local function setNoclip(state)
	noclipEnabled = state
	noclipToggle.refresh(state)
end
noclipToggle.button.MouseButton1Click:Connect(function()
	setNoclip(not noclipEnabled)
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  PLAYER EVENTS
-- ══════════════════════════════════════════════════════════════════════════════
for _, op in ipairs(Players:GetPlayers()) do
	if op ~= player then
		op.CharacterAdded:Connect(function(c)
			task.wait(0.2)
			if tagsEnabled then createTag(op, c) end
		end)
		op.CharacterRemoving:Connect(function() removeTag(op) end)
	end
end

Players.PlayerAdded:Connect(function(op)
	if op == player then return end
	op.CharacterAdded:Connect(function(c)
		task.wait(0.2)
		if tagsEnabled then createTag(op, c) end
	end)
	op.CharacterRemoving:Connect(function() removeTag(op) end)
end)

Players.PlayerRemoving:Connect(function(op) removeTag(op) end)

-- ══════════════════════════════════════════════════════════════════════════════
--  RENDER LOOP
-- ══════════════════════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
	updateCharacterReferences()

	if noclipEnabled and character then
		for _, p in ipairs(character:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
		end
	end

	if tagsEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local myRoot = player.Character.HumanoidRootPart
		for tp, data in pairs(trackedTags) do
			local tc = tp.Character
			if not tc or not tc.Parent then
				removeTag(tp)
			else
				local tHRP  = tc:FindFirstChild("HumanoidRootPart")
				local tHead = tc:FindFirstChild("Head")
				local tHum  = tc:FindFirstChildOfClass("Humanoid")
				if not tHRP or not tHead or not tHum or tHum.Health <= 0 then
					removeTag(tp)
				else
					local dist = (tHRP.Position - myRoot.Position).Magnitude
					data.distanceLabel.Text = showDistance and (math.floor(dist).." studs") or ""
					local _, onScreen = camera:WorldToViewportPoint(tHead.Position)
					data.billboard.Enabled = onScreen and dist <= 220
				end
			end
		end
	end
end)

-- ══════════════════════════════════════════════════════════════════════════════
--  INPUT
-- ══════════════════════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.W     then keys.W     = true end
	if input.KeyCode == Enum.KeyCode.A     then keys.A     = true end
	if input.KeyCode == Enum.KeyCode.S     then keys.S     = true end
	if input.KeyCode == Enum.KeyCode.D     then keys.D     = true end
	if input.KeyCode == Enum.KeyCode.Space then
		keys.Space = true
		if infiniteJumpEnabled and humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
	if input.KeyCode == Enum.KeyCode.LeftShift
	or input.KeyCode == Enum.KeyCode.RightShift then
		keys.Shift = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.W     then keys.W     = false end
	if input.KeyCode == Enum.KeyCode.A     then keys.A     = false end
	if input.KeyCode == Enum.KeyCode.S     then keys.S     = false end
	if input.KeyCode == Enum.KeyCode.D     then keys.D     = false end
	if input.KeyCode == Enum.KeyCode.Space then keys.Space  = false end
	if input.KeyCode == Enum.KeyCode.LeftShift
	or input.KeyCode == Enum.KeyCode.RightShift then
		keys.Shift = false
	end
end)