-- ╔══════════════════════════════════════════════════════════════╗
-- ║   TRAPVERSE TOOLS  FLING AND OTHER FUNCTIONS TROLLING        ║
-- ║   Features: Fly · Walk · Noclip · Inf-Jump · Tags            ║
-- ║             Click-TP · Search Player · Fling                 ║
-- ║             RESPAWN · BILIS NG TAKBO                         ║
-- ║   NEW: God Mode · Anti-AFK · ESP Boxes · Shift Sprint        ║
-- ╚══════════════════════════════════════════════════════════════╝

-- ══════════════════════════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")

-- ══════════════════════════════════════════════════════════════════
--  LOCAL PLAYER SETUP
-- ══════════════════════════════════════════════════════════════════
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse     = player:GetMouse()
local camera    = workspace.CurrentCamera

local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(char)
	character = char
	humanoid  = char:WaitForChild("Humanoid")
	rootPart  = char:WaitForChild("HumanoidRootPart")
	-- Always reset click-TP toggle to OFF on respawn (mouse connection is stale)
	if clickTpConnection then clickTpConnection:Disconnect(); clickTpConnection = nil end
	clickTpEnabled = false
	task.defer(function()
		if clickTpToggle then clickTpToggle.refresh(false) end
	end)
end)

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

-- ══════════════════════════════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════════════════════════════
local flying             = false
local flySpeed           = 50
local bodyVelocity, bodyGyro, flyConnection

local tagsEnabled        = false
local showDistance       = true
local trackedTags        = {}

local infiniteJumpEnabled = false
local noclipEnabled       = false
local walkEnabled         = false

local clickTpEnabled     = false
local clickTpConnection  = nil

local jumpPower          = 50
local runSpeed           = 16

local WALK_PRESETS = {
	{ label = "Slow",   speed = 6  },
	{ label = "Normal", speed = 16 },
	{ label = "Fast",   speed = 32 },
}
local currentWalkPreset = 2

local keys = { W=false, A=false, S=false, D=false, Space=false, Shift=false }

-- ── NEW FEATURE STATE ─────────────────────────────────────────────
local godModeEnabled     = false
local godModeConnection  = nil

local antiAfkEnabled     = false
local antiAfkThread      = nil

local espEnabled         = false
local espBoxes           = {}   -- [player] = { box=Frame, nameLbl=TextLabel }

local shiftSprintEnabled = false
local shiftSprintMult    = 2.0
local BASE_SPRINT_SPEED  = 16

-- ══════════════════════════════════════════════════════════════════
--  PALETTE  (Aesthetic Black-Grey Theme)
-- ══════════════════════════════════════════════════════════════════
local C = {
	Void        = Color3.fromRGB(5,   5,   7),
	Obsidian    = Color3.fromRGB(10,  10,  13),
	Charcoal    = Color3.fromRGB(18,  18,  22),
	Slate       = Color3.fromRGB(24,  24,  30),
	SlateHover  = Color3.fromRGB(32,  32,  40),
	Gold        = Color3.fromRGB(160, 170, 190),   -- replaced with cool grey-blue
	GoldBright  = Color3.fromRGB(210, 218, 230),   -- light silver-white
	GoldDim     = Color3.fromRGB(28,  30,  38),    -- dark blue-grey
	GoldLine    = Color3.fromRGB(40,  44,  58),    -- subtle blue-grey border
	Ivory       = Color3.fromRGB(235, 237, 242),
	Champagne   = Color3.fromRGB(160, 164, 175),
	Ash         = Color3.fromRGB( 68,  70,  80),
	Wire        = Color3.fromRGB( 32,  32,  42),
	WireGold    = Color3.fromRGB( 50,  55,  75),   -- active border (blue-grey)
	ActiveKnob  = Color3.fromRGB(150, 160, 185),
	InactiveKnob= Color3.fromRGB( 45,  46,  56),
	GreenDim    = Color3.fromRGB( 14,  44,  18),
	GreenBright = Color3.fromRGB( 72, 196,  92),
	RedDim      = Color3.fromRGB( 44,  14,  14),
	RedBright   = Color3.fromRGB(196,  72,  72),
	BlueDim     = Color3.fromRGB( 14,  26,  52),
	BlueBright  = Color3.fromRGB( 92, 148, 220),
	-- Respawn (cyan)
	CyanDim     = Color3.fromRGB( 10,  38,  48),
	CyanBright  = Color3.fromRGB( 72, 200, 220),
	CyanLine    = Color3.fromRGB( 18,  60,  72),
}

-- ══════════════════════════════════════════════════════════════════
--  TWEEN HELPERS
-- ══════════════════════════════════════════════════════════════════
local TI_FAST = TweenInfo.new(0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TI_MED  = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function tw(obj, props, ti)
	TweenService:Create(obj, ti or TI_FAST, props):Play()
end

-- ══════════════════════════════════════════════════════════════════
--  UI UTILITY
-- ══════════════════════════════════════════════════════════════════
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = p
	return c
end

local function stroke(p, col, thick)
	local s = Instance.new("UIStroke")
	s.Color           = col   or C.Wire
	s.Thickness       = thick or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent          = p
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

local function divider(parent, order)
	local f = Instance.new("Frame")
	f.Size             = UDim2.new(1, 0, 0, 1)
	f.BackgroundColor3 = C.Wire
	f.BorderSizePixel  = 0
	f.LayoutOrder      = order or 0
	f.Parent           = parent
	return f
end

-- ══════════════════════════════════════════════════════════════════
--  SECTION HEADER  (trap_pogi_tools style: gem dot + short line)
-- ══════════════════════════════════════════════════════════════════
local function sectionHead(parent, txt, order)
	local wrap = Instance.new("Frame")
	wrap.Size                   = UDim2.new(1, 0, 0, 22)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder            = order
	wrap.Parent                 = parent

	local gem = Instance.new("Frame")
	gem.Size             = UDim2.new(0, 5, 0, 5)
	gem.Position         = UDim2.new(0, 0, 0.5, -2)
	gem.BackgroundColor3 = C.Gold
	gem.BorderSizePixel  = 0
	gem.Parent           = wrap
	corner(gem, 1)

	local line = Instance.new("Frame")
	line.Size             = UDim2.new(0, 18, 0, 1)
	line.Position         = UDim2.new(0, 8, 0.5, 0)
	line.BackgroundColor3 = C.GoldLine
	line.BorderSizePixel  = 0
	line.Parent           = wrap

	local sl = Instance.new("TextLabel")
	sl.BackgroundTransparency = 1
	sl.Size           = UDim2.new(1, -32, 1, 0)
	sl.Position       = UDim2.new(0, 30, 0, 0)
	sl.Text           = txt:upper()
	sl.TextColor3     = C.Gold
	sl.TextSize       = 9
	sl.Font           = Enum.Font.GothamBold
	sl.TextXAlignment = Enum.TextXAlignment.Left
	sl.Parent         = wrap

	return wrap
end

-- ══════════════════════════════════════════════════════════════════
--  TOGGLE ROW  (trap_pogi_tools sizing + GothamSemibold)
-- ══════════════════════════════════════════════════════════════════
local function makeToggleRow(parent, labelText, order)
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1, 0, 0, 44)
	row.BackgroundColor3 = C.Slate
	row.BorderSizePixel  = 0
	row.LayoutOrder      = order or 0
	row.Parent           = parent
	corner(row, 6)
	local rowStroke = stroke(row, C.Wire)

	local pip = Instance.new("Frame")
	pip.Size             = UDim2.new(0, 3, 0, 22)
	pip.Position         = UDim2.new(0, 0, 0.5, -11)
	pip.BackgroundColor3 = C.Ash
	pip.BorderSizePixel  = 0
	pip.Parent           = row
	corner(pip, 2)

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size           = UDim2.new(1, -90, 1, 0)
	lbl.Position       = UDim2.new(0, 18, 0, 0)
	lbl.Text           = labelText
	lbl.TextColor3     = C.Champagne
	lbl.TextSize       = 12
	lbl.Font           = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent         = row

	local statusLbl = Instance.new("TextLabel")
	statusLbl.BackgroundTransparency = 1
	statusLbl.Size           = UDim2.new(0, 28, 0, 14)
	statusLbl.Position       = UDim2.new(1, -96, 0.5, -7)
	statusLbl.Text           = "OFF"
	statusLbl.TextColor3     = C.Ash
	statusLbl.TextSize       = 9
	statusLbl.Font           = Enum.Font.GothamBold
	statusLbl.TextXAlignment = Enum.TextXAlignment.Right
	statusLbl.Parent         = row

	local track = Instance.new("Frame")
	track.Size             = UDim2.new(0, 44, 0, 23)
	track.Position         = UDim2.new(1, -56, 0.5, -11)
	track.BackgroundColor3 = C.Charcoal
	track.BorderSizePixel  = 0
	track.Parent           = row
	corner(track, 12)
	local trackStroke = stroke(track, C.Wire)

	local knob = Instance.new("Frame")
	knob.Size             = UDim2.new(0, 17, 0, 17)
	knob.Position         = UDim2.new(0, 3, 0.5, -8)
	knob.BackgroundColor3 = C.InactiveKnob
	knob.BorderSizePixel  = 0
	knob.Parent           = track
	corner(knob, 9)

	local btn = Instance.new("TextButton")
	btn.Size                   = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text                   = ""
	btn.Parent                 = row

	local function refresh(on)
		if on then
			tw(track,      { BackgroundColor3 = C.GoldDim   })
			tw(trackStroke,{ Color            = C.WireGold  })
			tw(knob,       { Position = UDim2.new(0, 24, 0.5, -8), BackgroundColor3 = C.Gold })
			tw(rowStroke,  { Color            = C.GoldLine  })
			tw(pip,        { BackgroundColor3 = C.Gold      })
			tw(lbl,        { TextColor3       = C.Ivory     })
			tw(statusLbl,  { TextColor3       = C.GoldBright})
			statusLbl.Text = "ON"
		else
			tw(track,      { BackgroundColor3 = C.Charcoal  })
			tw(trackStroke,{ Color            = C.Wire      })
			tw(knob,       { Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = C.InactiveKnob })
			tw(rowStroke,  { Color            = C.Wire      })
			tw(pip,        { BackgroundColor3 = C.Ash       })
			tw(lbl,        { TextColor3       = C.Champagne })
			tw(statusLbl,  { TextColor3       = C.Ash       })
			statusLbl.Text = "OFF"
		end
	end

	btn.MouseEnter:Connect(function()  tw(row, { BackgroundColor3 = C.SlateHover }) end)
	btn.MouseLeave:Connect(function()  tw(row, { BackgroundColor3 = C.Slate      }) end)

	return { button = btn, refresh = refresh, row = row }
end

-- ══════════════════════════════════════════════════════════════════
--  SQUARE BUTTON
-- ══════════════════════════════════════════════════════════════════
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
	corner(b, 6)
	stroke(b, C.Wire)
	b.MouseEnter:Connect(function()   tw(b, { BackgroundColor3 = C.GoldDim,  TextColor3 = C.GoldBright }) end)
	b.MouseLeave:Connect(function()   tw(b, { BackgroundColor3 = C.Charcoal, TextColor3 = C.Champagne  }) end)
	b.MouseButton1Down:Connect(function() tw(b, { BackgroundColor3 = C.Gold, TextColor3 = C.Void }) end)
	b.MouseButton1Up:Connect(function()   tw(b, { BackgroundColor3 = C.GoldDim, TextColor3 = C.GoldBright }) end)
	return b
end

-- ══════════════════════════════════════════════════════════════════
--  ACTION BUTTON  (full-width, multi-theme)
-- ══════════════════════════════════════════════════════════════════
local function makeActionBtn(parent, txt, order, theme)
	theme = theme or "gold"
	local bg, fg, brd
	if theme == "green" then
		bg = C.GreenDim; fg = C.GreenBright; brd = Color3.fromRGB(24, 68, 28)
	elseif theme == "cyan" then
		bg = C.CyanDim; fg = C.CyanBright; brd = C.CyanLine
	elseif theme == "red" then
		bg = C.RedDim; fg = C.RedBright; brd = Color3.fromRGB(65, 18, 18)
	else
		bg = C.GoldDim; fg = C.GoldBright; brd = C.GoldLine
	end

	local b = Instance.new("TextButton")
	b.Size             = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = bg
	b.Text             = txt
	b.TextColor3       = fg
	b.TextSize         = 11
	b.Font             = Enum.Font.GothamBold
	b.BorderSizePixel  = 0
	b.LayoutOrder      = order or 0
	b.Parent           = parent
	corner(b, 6)
	stroke(b, brd)

	b.MouseEnter:Connect(function()   tw(b, { BackgroundColor3 = fg, TextColor3 = C.Void }) end)
	b.MouseLeave:Connect(function()   tw(b, { BackgroundColor3 = bg, TextColor3 = fg     }) end)
	b.MouseButton1Down:Connect(function() tw(b, { BackgroundColor3 = fg, TextColor3 = C.Void }) end)
	b.MouseButton1Up:Connect(function()   tw(b, { BackgroundColor3 = bg, TextColor3 = fg     }) end)
	return b
end

-- ══════════════════════════════════════════════════════════════════
--  PANEL FACTORY  (trap_pogi_tools style)
-- ══════════════════════════════════════════════════════════════════
local function makePanel(title, subtitle, w, h, posFunc)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name           = "TF_" .. title:gsub("%s","")
	screenGui.ResetOnSpawn   = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent         = playerGui

	local panel = Instance.new("Frame")
	panel.Name             = "Panel"
	panel.Size             = UDim2.new(0, w, 0, h)
	panel.Position         = posFunc(w, h)
	panel.BackgroundColor3 = C.Obsidian
	panel.BorderSizePixel  = 0
	panel.ClipsDescendants = true
	panel.Parent           = screenGui
	corner(panel, 10)
	stroke(panel, C.Wire, 1)

	-- top gold accent line
	local topAccent = Instance.new("Frame")
	topAccent.Size             = UDim2.new(1, 0, 0, 2)
	topAccent.BackgroundColor3 = C.Gold
	topAccent.BorderSizePixel  = 0
	topAccent.ZIndex           = 6
	topAccent.Parent           = panel

	-- header (Charcoal bg — trap_pogi style)
	local header = Instance.new("Frame")
	header.Size             = UDim2.new(1, 0, 0, 60)
	header.Position         = UDim2.new(0, 0, 0, 2)
	header.BackgroundColor3 = C.Charcoal
	header.BorderSizePixel  = 0
	header.ZIndex           = 2
	header.Parent           = panel

	-- 5 subtle diagonal lines (trap_pogi_tools style)
	for _, xs in ipairs({0, 0.25, 0.5, 0.75, 1.0}) do
		local f = Instance.new("Frame")
		f.Size                   = UDim2.new(0, 1, 0, 160)
		f.Position               = UDim2.new(xs, 0, 0, -40)
		f.BackgroundColor3       = C.Gold
		f.BackgroundTransparency = 0.90
		f.BorderSizePixel        = 0
		f.Rotation               = 28
		f.ZIndex                 = 3
		f.Parent                 = header
	end

	-- title
	local wm = Instance.new("TextLabel")
	wm.BackgroundTransparency = 1
	wm.Size           = UDim2.new(0, 180, 0, 26)
	wm.Position       = UDim2.new(0, 16, 0, 9)
	wm.Text           = "TRAPVERSE"
	wm.TextColor3     = C.Ivory
	wm.TextSize       = 18
	wm.Font           = Enum.Font.GothamBold
	wm.TextXAlignment = Enum.TextXAlignment.Left
	wm.ZIndex         = 4
	wm.Parent         = header

	local sw = Instance.new("TextLabel")
	sw.BackgroundTransparency = 1
	sw.Size           = UDim2.new(0, 180, 0, 14)
	sw.Position       = UDim2.new(0, 16, 0, 36)
	sw.Text           = subtitle
	sw.TextColor3     = C.Gold
	sw.TextSize       = 9
	sw.Font           = Enum.Font.GothamBold
	sw.TextXAlignment = Enum.TextXAlignment.Left
	sw.ZIndex         = 4
	sw.Parent         = header

	-- TF signet badge
	local signet = Instance.new("Frame")
	signet.Size             = UDim2.new(0, 34, 0, 34)
	signet.Position         = UDim2.new(1, -84, 0.5, -17)
	signet.BackgroundColor3 = C.GoldDim
	signet.BorderSizePixel  = 0
	signet.ZIndex           = 4
	signet.Parent           = header
	corner(signet, 5)
	stroke(signet, C.Gold)
	local sg = Instance.new("TextLabel")
	sg.BackgroundTransparency = 1
	sg.Size           = UDim2.new(1,0,1,0)
	sg.Text           = "TF"
	sg.TextColor3     = C.Gold
	sg.TextSize       = 12
	sg.Font           = Enum.Font.GothamBold
	sg.TextXAlignment = Enum.TextXAlignment.Center
	sg.ZIndex         = 5
	sg.Parent         = signet

	-- minimize button
	local minBtn = Instance.new("TextButton")
	minBtn.Size             = UDim2.new(0, 26, 0, 26)
	minBtn.Position         = UDim2.new(1, -40, 0.5, -13)
	minBtn.BackgroundColor3 = C.Slate
	minBtn.Text             = "−"
	minBtn.TextColor3       = C.Champagne
	minBtn.TextSize         = 16
	minBtn.Font             = Enum.Font.GothamBold
	minBtn.BorderSizePixel  = 0
	minBtn.ZIndex           = 5
	minBtn.Parent           = header
	corner(minBtn, 5)
	stroke(minBtn, C.Wire)
	minBtn.MouseEnter:Connect(function() tw(minBtn, {BackgroundColor3=C.GoldDim, TextColor3=C.Gold}) end)
	minBtn.MouseLeave:Connect(function() tw(minBtn, {BackgroundColor3=C.Slate,   TextColor3=C.Champagne}) end)

	-- gold separator line below header
	local hLine = Instance.new("Frame")
	hLine.Size             = UDim2.new(1, 0, 0, 1)
	hLine.Position         = UDim2.new(0, 0, 0, 62)
	hLine.BackgroundColor3 = C.GoldLine
	hLine.BorderSizePixel  = 0
	hLine.ZIndex           = 2
	hLine.Parent           = panel

	-- scrolling body
	local body = Instance.new("ScrollingFrame")
	body.Size                = UDim2.new(1, 0, 1, -63)
	body.Position            = UDim2.new(0, 0, 0, 63)
	body.BackgroundTransparency = 1
	body.BorderSizePixel     = 0
	body.ScrollBarThickness  = 2
	body.ScrollBarImageColor3= C.Gold
	body.CanvasSize          = UDim2.new(0, 0, 0, 0)
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent              = panel

	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Vertical
	ll.SortOrder     = Enum.SortOrder.LayoutOrder
	ll.Padding       = UDim.new(0, 6)
	ll.Parent        = body
	pad(body, 14, 16, 14, 14)

	-- minimize logic
	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			body.Visible  = false
			hLine.Visible = false
			tw(panel, { Size = UDim2.new(0, w, 0, 62) }, TI_MED)
			minBtn.Text = "+"
		else
			tw(panel, { Size = UDim2.new(0, w, 0, h) }, TI_MED)
			task.delay(0.2, function()
				body.Visible  = true
				hLine.Visible = true
			end)
			minBtn.Text = "−"
		end
	end)

	-- drag logic
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

	return { panel = panel, body = body, screenGui = screenGui }
end

-- ══════════════════════════════════════════════════════════════════
--  TEXT INPUT CARD  (trap_pogi_tools sizing)
-- ══════════════════════════════════════════════════════════════════
local function makeInputCard(parent, labelTxt, placeholderTxt, order)
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(1, 0, 0, 64)
	card.BackgroundColor3 = C.Slate
	card.BorderSizePixel  = 0
	card.LayoutOrder      = order or 0
	card.Parent           = parent
	corner(card, 6)
	stroke(card, C.Wire)

	local pip = Instance.new("Frame")
	pip.Size             = UDim2.new(0, 3, 0, 22)
	pip.Position         = UDim2.new(0, 0, 0.5, -11)
	pip.BackgroundColor3 = C.Ash
	pip.BorderSizePixel  = 0
	pip.Parent           = card
	corner(pip, 2)

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size           = UDim2.new(1, -18, 0, 16)
	lbl.Position       = UDim2.new(0, 16, 0, 6)
	lbl.Text           = labelTxt
	lbl.TextColor3     = C.Champagne
	lbl.TextSize       = 10
	lbl.Font           = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent         = card

	local box = Instance.new("TextBox")
	box.Size              = UDim2.new(1, -18, 0, 28)
	box.Position          = UDim2.new(0, 9, 0, 26)
	box.BackgroundColor3  = C.Charcoal
	box.BorderSizePixel   = 0
	box.Text              = ""
	box.PlaceholderText   = placeholderTxt or ""
	box.TextColor3        = C.Ivory
	box.PlaceholderColor3 = C.Ash
	box.TextSize          = 12
	box.Font              = Enum.Font.Gotham
	box.ClearTextOnFocus  = false
	box.Parent            = card
	corner(box, 5)
	stroke(box, C.Wire)
	pad(box, 0, 0, 8, 8)

	return card, box
end

-- ══════════════════════════════════════════════════════════════════
--  STATUS LABEL
-- ══════════════════════════════════════════════════════════════════
local function makeStatusLabel(parent, order)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size           = UDim2.new(1, 0, 0, 22)
	lbl.LayoutOrder    = order or 0
	lbl.Text           = ""
	lbl.TextColor3     = C.Champagne
	lbl.TextSize       = 10
	lbl.Font           = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextWrapped    = true
	lbl.Parent         = parent
	return lbl
end

-- ══════════════════════════════════════════════════════════════════
--  VALUE CARD  (label + badge + −/+ buttons)
-- ══════════════════════════════════════════════════════════════════
local function makeValueCard(parent, labelTxt, defaultVal, order)
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(1, 0, 0, 44)
	card.BackgroundColor3 = C.Slate
	card.BorderSizePixel  = 0
	card.LayoutOrder      = order or 0
	card.Parent           = parent
	corner(card, 6)
	stroke(card, C.Wire)

	local pip = Instance.new("Frame")
	pip.Size             = UDim2.new(0, 3, 0, 22)
	pip.Position         = UDim2.new(0, 0, 0.5, -11)
	pip.BackgroundColor3 = C.Ash
	pip.BorderSizePixel  = 0
	pip.Parent           = card
	corner(pip, 2)

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size           = UDim2.new(0, 90, 1, 0)
	lbl.Position       = UDim2.new(0, 16, 0, 0)
	lbl.Text           = labelTxt
	lbl.TextColor3     = C.Champagne
	lbl.TextSize       = 12
	lbl.Font           = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent         = card

	local badge = Instance.new("Frame")
	badge.Size             = UDim2.new(0, 50, 0, 26)
	badge.Position         = UDim2.new(0.5, -25, 0.5, -13)
	badge.BackgroundColor3 = C.GoldDim
	badge.BorderSizePixel  = 0
	badge.Parent           = card
	corner(badge, 5)
	stroke(badge, C.GoldLine)

	local val = Instance.new("TextLabel")
	val.BackgroundTransparency = 1
	val.Size           = UDim2.new(1, 0, 1, 0)
	val.Text           = tostring(defaultVal)
	val.TextColor3     = C.GoldBright
	val.TextSize       = 14
	val.Font           = Enum.Font.GothamBold
	val.TextXAlignment = Enum.TextXAlignment.Center
	val.Parent         = badge

	local minusBtn = makeSquareBtn(card, "−")
	minusBtn.Position = UDim2.new(1, -80, 0.5, -15)
	local plusBtn  = makeSquareBtn(card, "+")
	plusBtn.Position  = UDim2.new(1, -44, 0.5, -15)

	return { card=card, val=val, minusBtn=minusBtn, plusBtn=plusBtn }
end

-- ══════════════════════════════════════════════════════════════════
--  BUILD PANEL 1 — FLYER
-- ══════════════════════════════════════════════════════════════════
local PW, PH = 308, 530
local p1 = makePanel("Flyer", "F L Y E R", PW, PH, function(w, h)
	return UDim2.new(0.5, -w - 8, 0.5, -h/2)
end)
local body1 = p1.body

-- ─── MOVEMENT ────────────────────────────────────────────────────
sectionHead(body1, "Movement", 10)
local flyToggle  = makeToggleRow(body1, "Fly Mode", 20)
local speedVC    = makeValueCard(body1, "Fly Speed", flySpeed, 30)

divider(body1, 33)

local walkToggle = makeToggleRow(body1, "Walk Speed", 36)

local wpCard = Instance.new("Frame")
wpCard.Size             = UDim2.new(1, 0, 0, 50)
wpCard.BackgroundColor3 = C.Slate
wpCard.BorderSizePixel  = 0
wpCard.LayoutOrder      = 37
wpCard.Parent           = body1
corner(wpCard, 6)
stroke(wpCard, C.Wire)

local wpPip = Instance.new("Frame")
wpPip.Size             = UDim2.new(0, 3, 0, 22)
wpPip.Position         = UDim2.new(0, 0, 0.5, -11)
wpPip.BackgroundColor3 = C.Ash
wpPip.BorderSizePixel  = 0
wpPip.Parent           = wpCard
corner(wpPip, 2)

local wpLbl = Instance.new("TextLabel")
wpLbl.BackgroundTransparency = 1
wpLbl.Size           = UDim2.new(1, -18, 0, 15)
wpLbl.Position       = UDim2.new(0, 16, 0, 5)
wpLbl.Text           = "Walk Preset"
wpLbl.TextColor3     = C.Champagne
wpLbl.TextSize       = 10
wpLbl.Font           = Enum.Font.GothamSemibold
wpLbl.TextXAlignment = Enum.TextXAlignment.Left
wpLbl.Parent         = wpCard

local presetRow = Instance.new("Frame")
presetRow.Size                   = UDim2.new(1, -18, 0, 22)
presetRow.Position               = UDim2.new(0, 9, 0, 23)
presetRow.BackgroundTransparency = 1
presetRow.Parent                 = wpCard

local prl = Instance.new("UIListLayout")
prl.FillDirection = Enum.FillDirection.Horizontal
prl.SortOrder     = Enum.SortOrder.LayoutOrder
prl.Padding       = UDim.new(0, 4)
prl.Parent        = presetRow

local presetBtns = {}
local function setWalkPreset(idx)
	currentWalkPreset = idx
	runSpeed = WALK_PRESETS[idx].speed
	for i, b in ipairs(presetBtns) do
		if i == idx then tw(b, {BackgroundColor3=C.Gold, TextColor3=C.Void})
		else              tw(b, {BackgroundColor3=C.Charcoal, TextColor3=C.Champagne}) end
	end
	if walkEnabled then
		updateCharacterReferences()
		if humanoid then humanoid.WalkSpeed = runSpeed end
	end
end

for i, preset in ipairs(WALK_PRESETS) do
	local b = Instance.new("TextButton")
	b.Size             = UDim2.new(0, 84, 1, 0)
	b.BackgroundColor3 = i == currentWalkPreset and C.Gold or C.Charcoal
	b.Text             = preset.label .. " (" .. preset.speed .. ")"
	b.TextColor3       = i == currentWalkPreset and C.Void or C.Champagne
	b.TextSize         = 10
	b.Font             = Enum.Font.GothamSemibold
	b.BorderSizePixel  = 0
	b.LayoutOrder      = i
	b.Parent           = presetRow
	corner(b, 5)
	stroke(b, C.Wire)
	presetBtns[i] = b
	b.MouseButton1Click:Connect(function() setWalkPreset(i) end)
	b.MouseEnter:Connect(function()
		if currentWalkPreset ~= i then tw(b, {BackgroundColor3=C.GoldDim, TextColor3=C.GoldBright}) end
	end)
	b.MouseLeave:Connect(function()
		if currentWalkPreset ~= i then tw(b, {BackgroundColor3=C.Charcoal, TextColor3=C.Champagne}) end
	end)
end

local jumpVC = makeValueCard(body1, "Jump Power", jumpPower, 38)

-- ─── BILIS NG TAKBO  (custom run speed input) ─────────────────────
divider(body1, 39)
sectionHead(body1, "Run Speed", 40)

local bilisCard = Instance.new("Frame")
bilisCard.Size             = UDim2.new(1, 0, 0, 64)
bilisCard.BackgroundColor3 = C.Slate
bilisCard.BorderSizePixel  = 0
bilisCard.LayoutOrder      = 41
bilisCard.Parent           = body1
corner(bilisCard, 6)
local bilisStroke = stroke(bilisCard, C.Wire)

local bilisPip = Instance.new("Frame")
bilisPip.Size             = UDim2.new(0, 3, 0, 22)
bilisPip.Position         = UDim2.new(0, 0, 0.5, -11)
bilisPip.BackgroundColor3 = C.Ash
bilisPip.BorderSizePixel  = 0
bilisPip.Parent           = bilisCard
corner(bilisPip, 2)

local bilisTopRow = Instance.new("Frame")
bilisTopRow.Size                   = UDim2.new(1, -18, 0, 18)
bilisTopRow.Position               = UDim2.new(0, 9, 0, 5)
bilisTopRow.BackgroundTransparency = 1
bilisTopRow.Parent                 = bilisCard

local bilisLbl = Instance.new("TextLabel")
bilisLbl.BackgroundTransparency = 1
bilisLbl.Size           = UDim2.new(0.72, 0, 1, 0)
bilisLbl.Text           = "BILIS NG TAKBO"
bilisLbl.TextColor3     = C.Champagne
bilisLbl.TextSize       = 10
bilisLbl.Font           = Enum.Font.GothamSemibold
bilisLbl.TextXAlignment = Enum.TextXAlignment.Left
bilisLbl.Parent         = bilisTopRow

local bilisCurrentLbl = Instance.new("TextLabel")
bilisCurrentLbl.BackgroundTransparency = 1
bilisCurrentLbl.Size           = UDim2.new(0.28, 0, 1, 0)
bilisCurrentLbl.Position       = UDim2.new(0.72, 0, 0, 0)
bilisCurrentLbl.Text           = "= " .. tostring(runSpeed)
bilisCurrentLbl.TextColor3     = C.GoldBright
bilisCurrentLbl.TextSize       = 10
bilisCurrentLbl.Font           = Enum.Font.GothamBold
bilisCurrentLbl.TextXAlignment = Enum.TextXAlignment.Right
bilisCurrentLbl.Parent         = bilisTopRow

local bilisInputRow = Instance.new("Frame")
bilisInputRow.Size                   = UDim2.new(1, -18, 0, 28)
bilisInputRow.Position               = UDim2.new(0, 9, 0, 27)
bilisInputRow.BackgroundTransparency = 1
bilisInputRow.Parent                 = bilisCard

local bilisInputLL = Instance.new("UIListLayout")
bilisInputLL.FillDirection = Enum.FillDirection.Horizontal
bilisInputLL.SortOrder     = Enum.SortOrder.LayoutOrder
bilisInputLL.Padding       = UDim.new(0, 6)
bilisInputLL.Parent        = bilisInputRow

local bilisBox = Instance.new("TextBox")
bilisBox.Size              = UDim2.new(0, 120, 1, 0)
bilisBox.BackgroundColor3  = C.Charcoal
bilisBox.BorderSizePixel   = 0
bilisBox.Text              = ""
bilisBox.PlaceholderText   = "Ilagay ang speed…"
bilisBox.TextColor3        = C.Ivory
bilisBox.PlaceholderColor3 = C.Ash
bilisBox.TextSize          = 11
bilisBox.Font              = Enum.Font.Gotham
bilisBox.ClearTextOnFocus  = false
bilisBox.LayoutOrder       = 1
bilisBox.Parent            = bilisInputRow
corner(bilisBox, 5)
stroke(bilisBox, C.Wire)
pad(bilisBox, 0, 0, 8, 8)

local bilisApplyBtn = Instance.new("TextButton")
bilisApplyBtn.Size             = UDim2.new(0, 80, 1, 0)
bilisApplyBtn.BackgroundColor3 = C.GoldDim
bilisApplyBtn.Text             = "✔  ILAPAT"
bilisApplyBtn.TextColor3       = C.GoldBright
bilisApplyBtn.TextSize         = 10
bilisApplyBtn.Font             = Enum.Font.GothamBold
bilisApplyBtn.BorderSizePixel  = 0
bilisApplyBtn.LayoutOrder      = 2
bilisApplyBtn.Parent           = bilisInputRow
corner(bilisApplyBtn, 5)
stroke(bilisApplyBtn, C.GoldLine)
bilisApplyBtn.MouseEnter:Connect(function()  tw(bilisApplyBtn, {BackgroundColor3=C.GoldBright, TextColor3=C.Void}) end)
bilisApplyBtn.MouseLeave:Connect(function()  tw(bilisApplyBtn, {BackgroundColor3=C.GoldDim, TextColor3=C.GoldBright}) end)

local function applyBilisSpeed()
	local raw = bilisBox.Text:match("^%s*(.-)%s*$")
	local n   = tonumber(raw)
	if not n then
		tw(bilisStroke, {Color=C.RedBright})
		task.delay(0.8, function() tw(bilisStroke, {Color=C.Wire}) end)
		return
	end
	n = math.clamp(n, 2, 1000)
	runSpeed = n
	bilisCurrentLbl.Text = "= " .. tostring(n)
	bilisBox.Text = ""
	tw(bilisStroke, {Color=C.GoldLine})
	tw(bilisPip, {BackgroundColor3=C.Gold})
	task.delay(0.6, function() tw(bilisStroke, {Color=C.Wire}) tw(bilisPip, {BackgroundColor3=C.Ash}) end)
	updateCharacterReferences()
	if walkEnabled and humanoid then humanoid.WalkSpeed = runSpeed end
	-- also update sprint base
	BASE_SPRINT_SPEED = n
end

bilisApplyBtn.MouseButton1Click:Connect(applyBilisSpeed)
bilisBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then applyBilisSpeed() end
end)

-- ─── UTILITIES ────────────────────────────────────────────────────
divider(body1, 44)
sectionHead(body1, "Utilities", 48)
local tagsToggle   = makeToggleRow(body1, "Player Tags",   50)
local jumpToggle   = makeToggleRow(body1, "Infinite Jump", 60)
local noclipToggle = makeToggleRow(body1, "Noclip",        70)

-- ─── NEW FEATURES ─────────────────────────────────────────────────
divider(body1, 72)
sectionHead(body1, "Advanced", 73)
local godModeToggle     = makeToggleRow(body1, "God Mode",         74)
local shiftSprintToggle = makeToggleRow(body1, "Shift Sprint",     75)
local antiAfkToggle     = makeToggleRow(body1, "Anti-AFK",         76)
local espToggle         = makeToggleRow(body1, "ESP Boxes",        77)

-- ─── RESPAWN ──────────────────────────────────────────────────────
divider(body1, 73)
sectionHead(body1, "Character", 75)

local respawnBtn = makeActionBtn(body1, "⟳   RESPAWN CHARACTER", 76, "cyan")
respawnBtn.MouseButton1Click:Connect(function()
	if flying then
		if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
		if bodyVelocity  then bodyVelocity:Destroy();    bodyVelocity  = nil end
		if bodyGyro      then bodyGyro:Destroy();        bodyGyro      = nil end
		flying = false
		flyToggle.refresh(false)
	end
	if clickTpConnection then
		clickTpConnection:Disconnect()
		clickTpConnection = nil
		clickTpEnabled = false
		clickTpToggle.refresh(false)
	end
	task.spawn(function()
		local success, err = pcall(function()
			player:LoadCharacter()
		end)
		if not success then
			-- Fallback: kill humanoid to trigger respawn
			local char = player.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then hum.Health = 0 end
			end
		end
	end)
end)

-- ─── FOOTER ───────────────────────────────────────────────────────
local footerCard = Instance.new("Frame")
footerCard.Size             = UDim2.new(1, 0, 0, 30)
footerCard.BackgroundColor3 = C.Void
footerCard.BorderSizePixel  = 0
footerCard.LayoutOrder      = 90
footerCard.Parent           = body1
corner(footerCard, 6)
stroke(footerCard, C.Wire)

local footerTxt = Instance.new("TextLabel")
footerTxt.BackgroundTransparency = 1
footerTxt.Size           = UDim2.new(1, 0, 1, 0)
footerTxt.Text           = "WASD · Space ↑ · Shift ↓  —  Harvey Specter Ed."
footerTxt.TextColor3     = C.Ash
footerTxt.TextSize       = 9
footerTxt.Font           = Enum.Font.GothamSemibold
footerTxt.TextXAlignment = Enum.TextXAlignment.Center
footerTxt.Parent         = footerCard

-- ══════════════════════════════════════════════════════════════════
--  BUILD PANEL 2 — TOOLS
-- ══════════════════════════════════════════════════════════════════
local TP_W, TP_H = 308, 500
local p2 = makePanel("Tools", "T O O L S", TP_W, TP_H, function(w, h)
	return UDim2.new(0.5, 8, 0.5, -h/2)
end)
local body2 = p2.body

-- ─── TELEPORT ─────────────────────────────────────────────────────
sectionHead(body2, "Teleport", 10)
local clickTpToggle = makeToggleRow(body2, "Click to Teleport", 20)

local tpHint = Instance.new("Frame")
tpHint.Size             = UDim2.new(1, 0, 0, 30)
tpHint.BackgroundColor3 = C.Charcoal
tpHint.BorderSizePixel  = 0
tpHint.LayoutOrder      = 25
tpHint.Parent           = body2
corner(tpHint, 6)
stroke(tpHint, C.Wire)
local tpHintLbl = Instance.new("TextLabel")
tpHintLbl.BackgroundTransparency = 1
tpHintLbl.Size           = UDim2.new(1, -14, 1, 0)
tpHintLbl.Position       = UDim2.new(0, 7, 0, 0)
tpHintLbl.Text           = "⚡ Click any surface in the world to teleport"
tpHintLbl.TextColor3     = C.Ash
tpHintLbl.TextSize       = 10
tpHintLbl.Font           = Enum.Font.Gotham
tpHintLbl.TextXAlignment = Enum.TextXAlignment.Left
tpHintLbl.TextWrapped    = true
tpHintLbl.Parent         = tpHint

-- ─── SEARCH PLAYER ────────────────────────────────────────────────
divider(body2, 28)
sectionHead(body2, "Search Player", 30)

local srchInputCard, srchInput = makeInputCard(body2, "Player Username (partial ok)", "Type username…", 40)
local srchBtn    = makeActionBtn(body2, "⌕   SEARCH PLAYER", 42)
local srchStatus = makeStatusLabel(body2, 44)
local tpToBtn    = makeActionBtn(body2, "⚡   TELEPORT TO PLAYER", 46, "green")
tpToBtn.Visible  = false

local copyFromSearchBtn = makeActionBtn(body2, "✔   PLAYER FOUND", 47)
copyFromSearchBtn.Visible = false

-- ─── FLING ────────────────────────────────────────────────────────
divider(body2, 55)
sectionHead(body2, "Fling", 56)

local flingInputCard, flingInput = makeInputCard(body2, "Player to Fling (username)", "Type username…", 57)
local flingBtn = makeActionBtn(body2, "💥   FLING PLAYER", 58, "red")

flingBtn.MouseButton1Click:Connect(function()
	local query = flingInput.Text:match("^%s*(.-)%s*$"):lower()
	if query == "" then return end

	local target = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():find(query, 1, true) or p.DisplayName:lower():find(query, 1, true) then
			target = p; break
		end
	end
	if not target then return end

	local tc = target.Character
	if not tc then return end
	local tRoot = tc:FindFirstChild("HumanoidRootPart")
	if not tRoot then
		tRoot = tc:WaitForChild("HumanoidRootPart", 2)
	end
	if not tRoot then return end

	-- Random non-zero horizontal direction
	local angle = math.random() * math.pi * 2
	local hSpeed = math.random(160, 240)
	local vSpeed = math.random(200, 300)

	-- Remove any existing fling velocity first
	local existing = tRoot:FindFirstChild("_FlingBV")
	if existing then existing:Destroy() end

	local fv = Instance.new("BodyVelocity")
	fv.Name     = "_FlingBV"
	fv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	fv.Velocity = Vector3.new(
		math.cos(angle) * hSpeed,
		vSpeed,
		math.sin(angle) * hSpeed
	)
	fv.Parent = tRoot

	game:GetService("Debris"):AddItem(fv, 0.3)
end)

-- ══════════════════════════════════════════════════════════════════
--  FLY LOGIC
-- ══════════════════════════════════════════════════════════════════
local function stopFlying()
	flying = false
	flyToggle.refresh(false)
	if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
	if bodyVelocity  then bodyVelocity:Destroy();    bodyVelocity  = nil end
	if bodyGyro      then bodyGyro:Destroy();        bodyGyro      = nil end
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

	flyConnection = RunService.RenderStepped:Connect(function()
		updateCharacterReferences()
		if not flying or not rootPart or not camera then stopFlying(); return end

		local dir = Vector3.zero
		if keys.W     then dir += camera.CFrame.LookVector  end
		if keys.S     then dir -= camera.CFrame.LookVector  end
		if keys.A     then dir -= camera.CFrame.RightVector end
		if keys.D     then dir += camera.CFrame.RightVector end
		if keys.Space then dir += Vector3.new(0, 1, 0)      end
		if keys.Shift then dir -= Vector3.new(0, 1, 0)      end

		if dir.Magnitude > 0 then dir = dir.Unit end
		bodyVelocity.Velocity = dir * flySpeed
		bodyGyro.CFrame       = camera.CFrame
	end)
end

flyToggle.button.MouseButton1Click:Connect(function()
	if flying then stopFlying() else startFlying() end
end)

speedVC.plusBtn.MouseButton1Click:Connect(function()
	flySpeed = math.min(flySpeed + 10, 500)
	speedVC.val.Text = tostring(flySpeed)
end)
speedVC.minusBtn.MouseButton1Click:Connect(function()
	flySpeed = math.max(flySpeed - 10, 10)
	speedVC.val.Text = tostring(flySpeed)
end)

-- ══════════════════════════════════════════════════════════════════
--  WALK / JUMP LOGIC
-- ══════════════════════════════════════════════════════════════════
local DEFAULT_WALK = 16
local DEFAULT_JUMP = 50

local function setWalk(state)
	walkEnabled = state
	walkToggle.refresh(state)
	updateCharacterReferences()
	if state then
		if humanoid then humanoid.WalkSpeed = runSpeed end
	else
		if not flying and humanoid then humanoid.WalkSpeed = DEFAULT_WALK end
	end
end
walkToggle.button.MouseButton1Click:Connect(function() setWalk(not walkEnabled) end)

local function applyJump()
	updateCharacterReferences()
	if humanoid then humanoid.JumpPower = jumpPower end
end

jumpVC.plusBtn.MouseButton1Click:Connect(function()
	jumpPower = math.min(jumpPower + 10, 280)
	jumpVC.val.Text = tostring(jumpPower)
	applyJump()
end)
jumpVC.minusBtn.MouseButton1Click:Connect(function()
	jumpPower = math.max(jumpPower - 10, 8)
	jumpVC.val.Text = tostring(jumpPower)
	applyJump()
end)

player.CharacterAdded:Connect(function(char)
	task.wait(0.5)
	local hum = char:WaitForChild("Humanoid")
	if walkEnabled then hum.WalkSpeed = runSpeed end
	hum.JumpPower = jumpPower
end)

-- ══════════════════════════════════════════════════════════════════
--  PLAYER TAGS
-- ══════════════════════════════════════════════════════════════════
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
	bb.Size        = UDim2.new(0, 124, 0, 38)
	bb.StudsOffset = Vector3.new(0, 4.5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 9999
	bb.Adornee     = head
	bb.Parent      = playerGui

	local bg = Instance.new("Frame")
	bg.Size                   = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3       = C.Obsidian
	bg.BackgroundTransparency = 0.05
	bg.BorderSizePixel        = 0
	bg.Parent                 = bb
	corner(bg, 7)
	stroke(bg, C.GoldLine)

	local bar = Instance.new("Frame")
	bar.Size             = UDim2.new(0, 3, 0, 26)
	bar.Position         = UDim2.new(0, 4, 0.5, -13)
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
tagsToggle.button.MouseButton1Click:Connect(function() setTagsEnabled(not tagsEnabled) end)

-- ══════════════════════════════════════════════════════════════════
--  INFINITE JUMP
-- ══════════════════════════════════════════════════════════════════
local function setInfiniteJump(state)
	infiniteJumpEnabled = state
	jumpToggle.refresh(state)
end
jumpToggle.button.MouseButton1Click:Connect(function() setInfiniteJump(not infiniteJumpEnabled) end)

-- ══════════════════════════════════════════════════════════════════
--  NOCLIP
-- ══════════════════════════════════════════════════════════════════
local function setNoclip(state)
	noclipEnabled = state
	noclipToggle.refresh(state)
end
noclipToggle.button.MouseButton1Click:Connect(function() setNoclip(not noclipEnabled) end)

-- ══════════════════════════════════════════════════════════════════
--  CLICK TELEPORT
-- ══════════════════════════════════════════════════════════════════
local function setClickTp(state)
	clickTpEnabled = state
	clickTpToggle.refresh(state)
	if clickTpConnection then clickTpConnection:Disconnect(); clickTpConnection = nil end
	if state then
		clickTpConnection = mouse.Button1Down:Connect(function()
			if mouse.Target == nil then return end
			updateCharacterReferences()
			if not rootPart then return end
			rootPart.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
		end)
	end
end
clickTpToggle.button.MouseButton1Click:Connect(function() setClickTp(not clickTpEnabled) end)

-- ══════════════════════════════════════════════════════════════════
--  SEARCH PLAYER + TELEPORT
-- ══════════════════════════════════════════════════════════════════
local foundTargetPlayer = nil

local function setSearchResult(msg, col, showTp, showCopy)
	srchStatus.Text       = msg
	srchStatus.TextColor3 = col or C.Champagne
	tpToBtn.Visible       = showTp or false
	copyFromSearchBtn.Visible = showCopy or false
end

srchBtn.MouseButton1Click:Connect(function()
	local query = srchInput.Text:match("^%s*(.-)%s*$"):lower()
	if query == "" then
		setSearchResult("⚠ Enter a username to search.", C.Gold, false, false)
		return
	end
	foundTargetPlayer = nil
	setSearchResult("Searching…", C.Champagne, false, false)

	local found = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == query or p.DisplayName:lower() == query then
			found = p; break
		end
	end
	if not found then
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name:lower():find(query,1,true) or p.DisplayName:lower():find(query,1,true) then
				found = p; break
			end
		end
	end

	if found then
		foundTargetPlayer = found
		local disp = found.DisplayName
		if found.DisplayName ~= found.Name then
			disp = found.DisplayName .. " (@" .. found.Name .. ")"
		end
		setSearchResult("✔ Found: " .. disp, C.GreenBright, true, true)
		tpToBtn.Text = "⚡  TELEPORT TO  " .. found.DisplayName:upper()
		copyFromSearchBtn.Text = "⧉  COPY  " .. found.DisplayName:upper() .. "'S AVATAR"
	else
		setSearchResult("✗ Not in server: " .. query, C.RedBright, false, false)
	end
end)

tpToBtn.MouseButton1Click:Connect(function()
	if not foundTargetPlayer then return end
	updateCharacterReferences()
	if not rootPart then return end
	local tc = foundTargetPlayer.Character
	if not tc then setSearchResult("✗ Player has no character.", C.RedBright, false, false); return end

	-- Try to get HumanoidRootPart, wait up to 3s for it to load
	local tRoot = tc:FindFirstChild("HumanoidRootPart")
	if not tRoot then
		tRoot = tc:WaitForChild("HumanoidRootPart", 3)
	end
	if not tRoot then
		-- Last resort: try any BasePart in the character
		for _, p in ipairs(tc:GetDescendants()) do
			if p:IsA("BasePart") then tRoot = p; break end
		end
	end
	if not tRoot then setSearchResult("✗ Cannot locate player — try again in a moment.", C.RedBright, false, false); return end

	rootPart.CFrame = tRoot.CFrame * CFrame.new(3, 0, 0)
	setSearchResult("✔ Teleported to " .. foundTargetPlayer.DisplayName .. "!", C.GreenBright, true, true)
end)

-- ══════════════════════════════════════════════════════════════════
--  PLAYER EVENTS
-- ══════════════════════════════════════════════════════════════════
for _, op in ipairs(Players:GetPlayers()) do
	if op ~= player then
		op.CharacterAdded:Connect(function(c)
			task.wait(0.2)
			if tagsEnabled then createTag(op, c) end
			if espEnabled then
				local hrp = c:WaitForChild("HumanoidRootPart", 3)
				if hrp then createEspBox(op, 1) espBoxes[op].billboard.Adornee = hrp end
			end
		end)
		op.CharacterRemoving:Connect(function()
			removeTag(op)
			removeEspBox(op)
		end)
	end
end

Players.PlayerAdded:Connect(function(op)
	if op == player then return end
	op.CharacterAdded:Connect(function(c)
		task.wait(0.2)
		if tagsEnabled then createTag(op, c) end
		if espEnabled then
			local hrp = c:WaitForChild("HumanoidRootPart", 3)
			if hrp then createEspBox(op, 1) espBoxes[op].billboard.Adornee = hrp end
		end
	end)
	op.CharacterRemoving:Connect(function()
		removeTag(op)
		removeEspBox(op)
	end)
end)

Players.PlayerRemoving:Connect(function(op)
	removeTag(op)
	removeEspBox(op)
	if foundTargetPlayer == op then
		foundTargetPlayer = nil
		setSearchResult("⚠ Player left the game.", C.Gold, false, false)
	end
end)

-- ══════════════════════════════════════════════════════════════════
--  GOD MODE
-- ══════════════════════════════════════════════════════════════════
local function setGodMode(state)
	godModeEnabled = state
	godModeToggle.refresh(state)
	if godModeConnection then godModeConnection:Disconnect(); godModeConnection = nil end
	if state then
		godModeConnection = RunService.Heartbeat:Connect(function()
			updateCharacterReferences()
			if humanoid and humanoid.Parent then
				humanoid.MaxHealth = math.huge
				humanoid.Health    = math.huge
			end
		end)
	else
		updateCharacterReferences()
		if humanoid and humanoid.Parent then
			humanoid.MaxHealth = 100
			humanoid.Health    = 100
		end
	end
end
godModeToggle.button.MouseButton1Click:Connect(function() setGodMode(not godModeEnabled) end)

-- ══════════════════════════════════════════════════════════════════
--  ANTI-AFK
-- ══════════════════════════════════════════════════════════════════
local VirtualUser = game:GetService("VirtualUser")
local function setAntiAfk(state)
	antiAfkEnabled = state
	antiAfkToggle.refresh(state)
	if antiAfkThread then
		task.cancel(antiAfkThread)
		antiAfkThread = nil
	end
	if state then
		antiAfkThread = task.spawn(function()
			while antiAfkEnabled do
				task.wait(60)
				if antiAfkEnabled then
					VirtualUser:Button2Down(Vector2.new(0,0), CFrame.new())
					task.wait(0.1)
					VirtualUser:Button2Up(Vector2.new(0,0), CFrame.new())
				end
			end
		end)
	end
end
antiAfkToggle.button.MouseButton1Click:Connect(function() setAntiAfk(not antiAfkEnabled) end)

-- ══════════════════════════════════════════════════════════════════
--  ESP BOXES
-- ══════════════════════════════════════════════════════════════════
local espGui = Instance.new("ScreenGui")
espGui.Name         = "TF_ESPGui"
espGui.ResetOnSpawn = false
espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
espGui.Parent       = playerGui

local ESP_COLORS = {
	Color3.fromRGB(255, 80,  80),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(80, 255, 140),
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(200, 80, 255),
	Color3.fromRGB(255, 140, 60),
}
local function getEspColor(idx)
	return ESP_COLORS[((idx - 1) % #ESP_COLORS) + 1]
end

local function createEspBox(targetPlayer, idx)
	if targetPlayer == player then return end
	if espBoxes[targetPlayer] then return end

	local col = getEspColor(idx or 1)

	local bb = Instance.new("BillboardGui")
	bb.Name         = "ESP_" .. targetPlayer.Name
	bb.Size         = UDim2.new(0, 52, 0, 82)
	bb.StudsOffset  = Vector3.new(0, 2, 0)
	bb.AlwaysOnTop  = true
	bb.MaxDistance  = 9999
	bb.ResetOnSpawn = false
	bb.Parent       = espGui

	local outerBox = Instance.new("Frame")
	outerBox.Size                   = UDim2.new(1, 0, 1, 0)
	outerBox.BackgroundTransparency = 1
	outerBox.BorderSizePixel        = 0
	outerBox.Parent                 = bb
	stroke(outerBox, col, 2)
	corner(outerBox, 3)

	local healthBar = Instance.new("Frame")
	healthBar.Size             = UDim2.new(0, 3, 1, 0)
	healthBar.Position         = UDim2.new(0, -7, 0, 0)
	healthBar.BackgroundColor3 = Color3.fromRGB(60, 220, 90)
	healthBar.BorderSizePixel  = 0
	healthBar.Parent           = bb
	corner(healthBar, 2)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size           = UDim2.new(1, 0, 0, 14)
	nameLbl.Position       = UDim2.new(0, 0, 0, -16)
	nameLbl.Text           = targetPlayer.DisplayName
	nameLbl.TextColor3     = col
	nameLbl.TextSize       = 10
	nameLbl.Font           = Enum.Font.GothamBold
	nameLbl.TextXAlignment = Enum.TextXAlignment.Center
	nameLbl.Parent         = bb

	local distLbl2 = Instance.new("TextLabel")
	distLbl2.BackgroundTransparency = 1
	distLbl2.Size           = UDim2.new(1, 0, 0, 12)
	distLbl2.Position       = UDim2.new(0, 0, 1, 2)
	distLbl2.Text           = "0m"
	distLbl2.TextColor3     = Color3.fromRGB(180, 180, 180)
	distLbl2.TextSize       = 9
	distLbl2.Font           = Enum.Font.Gotham
	distLbl2.TextXAlignment = Enum.TextXAlignment.Center
	distLbl2.Parent         = bb

	espBoxes[targetPlayer] = {
		billboard  = bb,
		healthBar  = healthBar,
		distLbl    = distLbl2,
	}
end

local function removeEspBox(targetPlayer)
	local d = espBoxes[targetPlayer]
	if d and d.billboard then d.billboard:Destroy() end
	espBoxes[targetPlayer] = nil
end

local function setEsp(state)
	espEnabled = state
	espToggle.refresh(state)
	if not state then
		for tp in pairs(espBoxes) do removeEspBox(tp) end
	else
		local idx = 1
		for _, op in ipairs(Players:GetPlayers()) do
			if op ~= player and op.Character then
				local hrp = op.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					createEspBox(op, idx)
					espBoxes[op].billboard.Adornee = hrp
					idx += 1
				end
			end
		end
	end
end
espToggle.button.MouseButton1Click:Connect(function() setEsp(not espEnabled) end)

-- ══════════════════════════════════════════════════════════════════
--  SHIFT SPRINT
-- ══════════════════════════════════════════════════════════════════
local function setShiftSprint(state)
	shiftSprintEnabled = state
	shiftSprintToggle.refresh(state)
end
shiftSprintToggle.button.MouseButton1Click:Connect(function() setShiftSprint(not shiftSprintEnabled) end)

-- ══════════════════════════════════════════════════════════════════

RunService.RenderStepped:Connect(function()
	updateCharacterReferences()

	if noclipEnabled and character then
		for _, p in ipairs(character:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
		end
	end

	-- ── SHIFT SPRINT ─────────────────────────────────────────────
	if shiftSprintEnabled and humanoid and humanoid.Parent then
		if keys.Shift then
			humanoid.WalkSpeed = BASE_SPRINT_SPEED * shiftSprintMult
		else
			if walkEnabled then
				humanoid.WalkSpeed = runSpeed
			else
				humanoid.WalkSpeed = BASE_SPRINT_SPEED
			end
		end
	end

	-- ── PLAYER TAGS ──────────────────────────────────────────────
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
					data.distanceLabel.Text = showDistance and (math.floor(dist) .. " studs") or ""
					local _, onScreen = camera:WorldToViewportPoint(tHead.Position)
					data.billboard.Enabled = true
				end
			end
		end
	end

	-- ── ESP BOX UPDATES ──────────────────────────────────────────
	if espEnabled and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local myRoot2 = player.Character.HumanoidRootPart
		for tp, data in pairs(espBoxes) do
			local tc = tp.Character
			if not tc or not tc.Parent then
				removeEspBox(tp)
			else
				local tHRP = tc:FindFirstChild("HumanoidRootPart")
				local tHum = tc:FindFirstChildOfClass("Humanoid")
				if not tHRP or not tHum then
					removeEspBox(tp)
				else
					data.billboard.Adornee = tHRP
					local dist = math.floor((tHRP.Position - myRoot2.Position).Magnitude)
					data.distLbl.Text = dist .. "m"
					-- health bar height
					local hpRatio = math.clamp(tHum.Health / math.max(tHum.MaxHealth, 1), 0, 1)
					data.healthBar.Size = UDim2.new(0, 3, hpRatio, 0)
					local r = 1 - hpRatio
					data.healthBar.BackgroundColor3 = Color3.fromRGB(
						math.floor(r * 220 + 60),
						math.floor(hpRatio * 220 + 30),
						40
					)
				end
			end
		end
	end
end)

-- ══════════════════════════════════════════════════════════════════
--  INPUT
-- ══════════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.W     then keys.W     = true  end
	if input.KeyCode == Enum.KeyCode.A     then keys.A     = true  end
	if input.KeyCode == Enum.KeyCode.S     then keys.S     = true  end
	if input.KeyCode == Enum.KeyCode.D     then keys.D     = true  end
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
	if input.KeyCode == Enum.KeyCode.Space then keys.Space = false end
	if input.KeyCode == Enum.KeyCode.LeftShift
	or input.KeyCode == Enum.KeyCode.RightShift then
		keys.Shift = false
	end
end)
