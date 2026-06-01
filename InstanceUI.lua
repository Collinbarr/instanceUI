--[[
	InstanceUI — Roblox UI library
	Open: Right Shift | Drag: title bar | Ghost outline | Resize: edges
	Layout: title + horizontal tabs + 2-column groupboxes (purple theme)
]]

local InstanceUI = {}
InstanceUI.Version = "1.0.0"

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse = (cloneref or function(...)
	return ...
end)(LocalPlayer:GetMouse())

local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end

local function Create(class, props)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	return inst
end

local function Tween(inst, info, goals)
	return TweenService:Create(inst, info, goals)
end

local function Connect(signal, fn)
	return signal:Connect(fn)
end

local TWEEN_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local TWEEN_SNAP = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local DefaultTheme = {
	Background = Color3.fromRGB(26, 26, 26),
	TitleBar = Color3.fromRGB(22, 22, 22),
	Sidebar = Color3.fromRGB(26, 26, 26),
	Panel = Color3.fromRGB(32, 32, 32),
	PanelBorder = Color3.fromRGB(48, 48, 48),
	Accent = Color3.fromRGB(138, 43, 226),
	AccentGlow = Color3.fromRGB(160, 70, 245),
	Text = Color3.fromRGB(240, 240, 240),
	TextMuted = Color3.fromRGB(160, 160, 160),
	TextDim = Color3.fromRGB(110, 110, 110),
	ToggleOff = Color3.fromRGB(38, 38, 38),
	ToggleOn = Color3.fromRGB(138, 43, 226),
	SliderTrack = Color3.fromRGB(42, 42, 42),
	SliderFill = Color3.fromRGB(138, 43, 226),
	Dropdown = Color3.fromRGB(28, 28, 28),
	Hover = Color3.fromRGB(40, 40, 40),
	ActiveTab = Color3.fromRGB(138, 43, 226),
	ActiveTabBg = Color3.fromRGB(138, 43, 226),
	TabDivider = Color3.fromRGB(55, 55, 55),
	GhostStroke = Color3.fromRGB(200, 200, 200),
	CornerRadius = 3,
	Font = Enum.Font.Code,
	FontBold = Enum.Font.Code,
}

local function ApplyCorner(parent, radius)
	Create("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius or DefaultTheme.CornerRadius) })
end

local function ApplyStroke(parent, color, thickness, transparency)
	Create("UIStroke", {
		Parent = parent,
		Color = color or DefaultTheme.PanelBorder,
		Thickness = thickness or 1,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function ApplyPadding(parent, t, r, b, l)
	Create("UIPadding", {
		Parent = parent,
		PaddingTop = UDim.new(0, t or 8),
		PaddingRight = UDim.new(0, r or 8),
		PaddingBottom = UDim.new(0, b or 8),
		PaddingLeft = UDim.new(0, l or 8),
	})
end

local function GetGuiParent()
	local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not pg then
		pg = LocalPlayer:WaitForChild("PlayerGui", 10)
	end
	return pg
end

local function Protect(instance)
	pcall(function()
		ProtectGui(instance)
	end)
end

-- Drag + ghost outline
local DragController = {}
DragController.__index = DragController

function DragController.new(window, dragTargets, theme)
	local self = setmetatable({}, DragController)
	self.Window = window
	self.Targets = dragTargets
	self.Theme = theme or DefaultTheme
	self.Dragging = false
	self.Ghost = nil
	self.StartMouse = nil
	self.StartPos = nil
	self.Connections = {}

	for _, target in ipairs(dragTargets) do
		table.insert(
			self.Connections,
			Connect(target.InputBegan, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					self:Begin(input)
				end
			end)
		)
	end

	table.insert(
		self.Connections,
		Connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and self.Dragging then
				self:End()
			end
		end)
	)

	return self
end

local function setWindowFromTopLeft(window, topLeft)
	local parent = window.Parent
	local parentAbs = parent and parent.AbsolutePosition or Vector2.zero
	local size = window.AbsoluteSize
	local anchor = window.AnchorPoint
	window.Position = UDim2.fromOffset(
		topLeft.X - parentAbs.X + size.X * anchor.X,
		topLeft.Y - parentAbs.Y + size.Y * anchor.Y
	)
end

function DragController:Begin(input)
	if self.Dragging then
		return
	end
	self.Dragging = true

	local window = self.Window
	local parent = window.Parent
	local winAbs = window.AbsolutePosition
	local winSize = window.AbsoluteSize
	local mousePos = Vector2.new(Mouse.X, Mouse.Y)

	-- Keep ghost aligned to cursor grab point (top-left math, not anchor mismatch)
	self.DragOffset = mousePos - winAbs
	self.WinSize = winSize

	self.Ghost = Create("Frame", {
		Name = "InstanceUI_Ghost",
		Parent = parent,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(winAbs.X - parent.AbsolutePosition.X, winAbs.Y - parent.AbsolutePosition.Y),
		Size = UDim2.fromOffset(winSize.X, winSize.Y),
		BackgroundTransparency = 1,
		ZIndex = window.ZIndex + 50,
		Active = false,
	})
	ApplyCorner(self.Ghost, self.Theme.CornerRadius)
	ApplyStroke(self.Ghost, self.Theme.GhostStroke, 2, 0.12)

	Create("Frame", {
		Parent = self.Ghost,
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 0.9,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	})

	window.BackgroundTransparency = 0.35

	self.MoveConn = Connect(RunService.RenderStepped, function()
		if not self.Dragging or not self.Ghost then
			return
		end
		local parentAbs = parent.AbsolutePosition
		local newTopLeft = Vector2.new(Mouse.X, Mouse.Y) - self.DragOffset
		self.Ghost.Position = UDim2.fromOffset(newTopLeft.X - parentAbs.X, newTopLeft.Y - parentAbs.Y)
	end)
end

function DragController:End()
	if not self.Dragging then
		return
	end
	self.Dragging = false
	if self.MoveConn then
		self.MoveConn:Disconnect()
		self.MoveConn = nil
	end
	if self.Ghost then
		local ghostAbs = self.Ghost.AbsolutePosition
		setWindowFromTopLeft(self.Window, ghostAbs)
		self.Window.BackgroundTransparency = 0
		self.Ghost:Destroy()
		self.Ghost = nil
	end
end

function DragController:Destroy()
	for _, c in ipairs(self.Connections) do
		c:Disconnect()
	end
	if self.MoveConn then
		self.MoveConn:Disconnect()
	end
	if self.Ghost then
		self.Ghost:Destroy()
	end
end

-- Resize from edges
local ResizeController = {}
ResizeController.__index = ResizeController

function ResizeController.new(window, theme, minSize)
	local self = setmetatable({}, ResizeController)
	self.Window = window
	self.Theme = theme or DefaultTheme
	self.Min = minSize or Vector2.new(520, 360)
	self.Handles = {}
	self.Active = false
	self.Mode = nil
	self.StartMouse = nil
	self.StartSize = nil
	self.StartPos = nil

	local parent = window.Parent
	local z = window.ZIndex + 40

	local function makeHandle(name, pos, size, mode)
		local h = Create("TextButton", {
			Name = name,
			Parent = parent,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Position = pos,
			Size = size,
			ZIndex = z,
			Active = true,
		})
		Connect(h.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:Begin(mode)
			end
		end)
		table.insert(self.Handles, h)
		return h
	end

	-- sync handle positions when window moves/resizes
	self.Sync = function()
		local p = window.AbsolutePosition
		local s = window.AbsoluteSize
		local rel = parent.AbsolutePosition
		local ox, oy = p.X - rel.X, p.Y - rel.Y

		if self.Handles[1] then
			self.Handles[1].Position = UDim2.fromOffset(ox + s.X - 6, oy + s.Y - 6)
			self.Handles[1].Size = UDim2.fromOffset(12, 12)
		end
		if self.Handles[2] then
			self.Handles[2].Position = UDim2.fromOffset(ox + s.X - 4, oy + 20)
			self.Handles[2].Size = UDim2.fromOffset(6, s.Y - 40)
		end
		if self.Handles[3] then
			self.Handles[3].Position = UDim2.fromOffset(ox + 20, oy + s.Y - 4)
			self.Handles[3].Size = UDim2.fromOffset(s.X - 40, 6)
		end
	end

	makeHandle("ResizeBR", UDim2.fromOffset(0, 0), UDim2.fromOffset(12, 12), "br")
	makeHandle("ResizeRight", UDim2.fromOffset(0, 0), UDim2.fromOffset(6, 100), "r")
	makeHandle("ResizeBottom", UDim2.fromOffset(0, 0), UDim2.fromOffset(100, 6), "b")

	self.SyncConn = Connect(RunService.RenderStepped, self.Sync)
	self.Sync()

	Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and self.Active then
			self:End()
		end
	end)

	return self
end

function ResizeController:Begin(mode)
	self.Active = true
	self.Mode = mode
	self.StartMouse = Vector2.new(Mouse.X, Mouse.Y)
	self.StartSize = Vector2.new(self.Window.AbsoluteSize.X, self.Window.AbsoluteSize.Y)
	self.StartPos = Vector2.new(self.Window.AbsolutePosition.X, self.Window.AbsolutePosition.Y)

	self.MoveConn = Connect(RunService.RenderStepped, function()
		if not self.Active then
			return
		end
		local delta = Vector2.new(Mouse.X, Mouse.Y) - self.StartMouse
		local w, h = self.StartSize.X, self.StartSize.Y

		if self.Mode == "r" or self.Mode == "br" then
			w = math.max(self.Min.X, self.StartSize.X + delta.X)
		end
		if self.Mode == "b" or self.Mode == "br" then
			h = math.max(self.Min.Y, self.StartSize.Y + delta.Y)
		end

		self.Window.Size = UDim2.fromOffset(w, h)
	end)
end

function ResizeController:End()
	self.Active = false
	self.Mode = nil
	if self.MoveConn then
		self.MoveConn:Disconnect()
		self.MoveConn = nil
	end
end

function ResizeController:Destroy()
	if self.SyncConn then
		self.SyncConn:Disconnect()
	end
	if self.MoveConn then
		self.MoveConn:Disconnect()
	end
	for _, h in ipairs(self.Handles) do
		h:Destroy()
	end
end

local MakeToggle, MakeSlider, MakeDropdown

-- Gear settings popup
local function CloseGearMenu(win)
	if win._gearMenu then
		win._gearMenu:Destroy()
		win._gearMenu = nil
	end
	if win._gearClickConn then
		win._gearClickConn:Disconnect()
		win._gearClickConn = nil
	end
end

local function BuildGearContext(body, theme, library, win)
	local ctx = {}
	function ctx:AddToggle(text, o)
		o = o or {}
		o.Text = text
		local el = MakeToggle(body, theme, o, win)
		if o.Flag then
			library.Flags[o.Flag] = el
		end
		return el
	end
	function ctx:AddSlider(text, o)
		o = o or {}
		o.Text = text
		local el = MakeSlider(body, theme, o, win)
		if o.Flag then
			library.Flags[o.Flag] = el
		end
		return el
	end
	function ctx:AddDropdown(text, o)
		o = o or {}
		o.Text = text
		local el = MakeDropdown(body, theme, o, false)
		if o.Flag then
			library.Flags[o.Flag] = el
		end
		return el
	end
	function ctx:AddLabel(text)
		Create("TextLabel", {
			Parent = body,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = theme.TextMuted,
			TextSize = 12,
			Font = theme.Font,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	return ctx
end

local function OpenGearMenu(win, theme, options, anchorBtn)
	CloseGearMenu(win)

	local title = options.Text or "Settings"
	local main = win.Main
	local menu = Create("Frame", {
		Name = "InstanceUI_GearMenu",
		Parent = main,
		Size = UDim2.fromOffset(240, 120),
		BackgroundColor3 = theme.Panel,
		ZIndex = 200,
	})
	ApplyCorner(menu, theme.CornerRadius)
	ApplyStroke(menu, theme.PanelBorder, 1, 0.3)

	local anchorAbs = anchorBtn.AbsolutePosition
	local mainAbs = main.AbsolutePosition
	menu.Position = UDim2.fromOffset(
		math.clamp(anchorAbs.X - mainAbs.X + 24, 8, main.AbsoluteSize.X - 248),
		math.clamp(anchorAbs.Y - mainAbs.Y - 8, 8, main.AbsoluteSize.Y - 120)
	)

	Create("TextLabel", {
		Parent = menu,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -40, 0, 16),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = theme.Text,
		TextSize = 13,
		Font = theme.FontBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local closeBtn = Create("TextButton", {
		Parent = menu,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Text = "x",
		TextColor3 = theme.TextMuted,
		TextSize = 14,
		Font = theme.Font,
		AutoButtonColor = false,
	})
	Connect(closeBtn.MouseButton1Click, function()
		CloseGearMenu(win)
	end)

	local body = Create("Frame", {
		Parent = menu,
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -20, 0, 80),
		BackgroundTransparency = 1,
	})
	local bodyList = Create("UIListLayout", {
		Parent = body,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	})
	ApplyPadding(body, 0, 0, 10, 0)

	local function resizeMenu()
		local h = bodyList.AbsoluteContentSize.Y + 44
		body.Size = UDim2.new(1, -20, 0, bodyList.AbsoluteContentSize.Y)
		menu.Size = UDim2.fromOffset(240, math.max(80, h))
	end
	bodyList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeMenu)

	local ctx = BuildGearContext(body, theme, win.Library, win)
	if type(options.GearSettings) == "function" then
		options.GearSettings(ctx)
	elseif type(options.GearSettings) == "table" then
		for _, item in ipairs(options.GearSettings) do
			if item.Type == "Toggle" then
				ctx:AddToggle(item.Text, item)
			elseif item.Type == "Slider" then
				ctx:AddSlider(item.Text, item)
			elseif item.Type == "Dropdown" then
				ctx:AddDropdown(item.Text, item)
			elseif item.Type == "Label" then
				ctx:AddLabel(item.Text)
			end
		end
	end
	task.defer(resizeMenu)

	win._gearMenu = menu
	win._gearClickConn = Connect(UserInputService.InputBegan, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		task.defer(function()
			if not win._gearMenu then
				return
			end
			local pos = Vector2.new(Mouse.X, Mouse.Y)
			local function inside(gui)
				if not gui or not gui:IsA("GuiObject") then
					return false
				end
				local ap, as = gui.AbsolutePosition, gui.AbsoluteSize
				return pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
			end
			if not inside(menu) and not inside(anchorBtn) then
				CloseGearMenu(win)
			end
		end)
	end)
end

local function AttachGearButton(row, theme, options, win)
	local gearBtn = Create("TextButton", {
		Parent = row,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -2, 0.5, 0),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Text = "⚙",
		TextColor3 = theme.TextMuted,
		TextSize = 14,
		Font = theme.Font,
		AutoButtonColor = false,
	})
	Connect(gearBtn.MouseButton1Click, function()
		if win._gearMenu and win._gearMenu.Parent then
			CloseGearMenu(win)
		else
			OpenGearMenu(win, theme, options, gearBtn)
		end
	end)
	return gearBtn
end

-- Component builders
MakeToggle = function(parent, theme, options, win)
	options = options or {}
	local rowH = 22
	local row = Create("TextButton", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, rowH),
		Text = "",
		AutoButtonColor = false,
	})
	local box = Create("Frame", {
		Parent = row,
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = theme.ToggleOff,
		BorderSizePixel = 0,
	})
	ApplyCorner(box, 2)
	ApplyStroke(box, theme.PanelBorder, 1, 0.2)
	local check = Create("Frame", {
		Parent = box,
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.fromOffset(2, 2),
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Visible = false,
	})
	ApplyCorner(check, 1)
	local rightPad = 18
	if options.Keybind then
		rightPad += 52
	end
	if options.Gear then
		rightPad += 22
	end
	Create("TextLabel", {
		Parent = row,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -rightPad, 1, 0),
		BackgroundTransparency = 1,
		Font = theme.Font,
		Text = options.Text or "Toggle",
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local state = options.Default or false
	local function refresh()
		local on = state
		box.BackgroundColor3 = on and theme.ToggleOn or theme.ToggleOff
		check.Visible = on
	end
	refresh()

	local function toggle()
		state = not state
		refresh()
		if options.Callback then
			options.Callback(state)
		end
	end

	Connect(row.MouseButton1Click, toggle)

	local api = {
		Instance = row,
		Set = function(v)
			state = v
			refresh()
		end,
		Get = function()
			return state
		end,
		OnChanged = function(cb)
			options.Callback = cb
		end,
		Flag = options.Flag,
	}

	if options.Keybind then
		local keyText = type(options.Keybind) == "string" and options.Keybind
			or (typeof(options.Keybind) == "EnumItem" and options.Keybind.Name)
			or "..."
		Create("TextButton", {
			Parent = row,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, options.Gear and -26 or -4, 0.5, 0),
			Size = UDim2.fromOffset(44, 18),
			BackgroundColor3 = theme.Dropdown,
			Text = keyText,
			TextColor3 = theme.TextMuted,
			TextSize = 11,
			Font = theme.Font,
			AutoButtonColor = false,
			BorderSizePixel = 1,
			BorderColor3 = theme.PanelBorder,
		})
	end

	if options.Gear and win and options.GearSettings then
		AttachGearButton(row, theme, options, win)
	end

	return api
end

MakeSlider = function(parent, theme, options, win)
	options = options or {}
	local row = Create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
	})
	Create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, options.Gear and -52 or 0, 0, 14),
		Font = theme.Font,
		Text = options.Text or "Slider",
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local bar = Create("TextButton", {
		Parent = row,
		Position = UDim2.new(0, 0, 0, 18),
		Size = UDim2.new(1, options.Gear and -52 or 0, 0, 12),
		BackgroundColor3 = theme.SliderTrack,
		Text = "",
		AutoButtonColor = false,
	})
	ApplyCorner(bar, 2)
	local fill = Create("Frame", {
		Parent = bar,
		BackgroundColor3 = theme.SliderFill,
		Size = UDim2.new(0.5, 0, 1, 0),
		BorderSizePixel = 0,
	})
	ApplyCorner(fill, 2)
	local valueLabel = Create("TextLabel", {
		Parent = bar,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = theme.Font,
		Text = "",
		TextColor3 = theme.Text,
		TextSize = 12,
		ZIndex = 2,
	})

	local min = options.Min or 0
	local max = options.Max or 100
	local default = options.Default or min
	local suffix = options.Suffix or ""
	local rounding = options.Rounding or 0
	local dragging = false

	local function format(v)
		if options.Format then
			return options.Format(v)
		end
		if rounding > 0 then
			return string.format("%." .. rounding .. "f", v) .. suffix
		end
		return tostring(math.floor(v + 0.5)) .. suffix
	end

	local function setValue(v, fromInput)
		v = math.clamp(v, min, max)
		local alpha = (max > min) and ((v - min) / (max - min)) or 0
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		valueLabel.Text = format(v)
		if fromInput and options.Callback then
			options.Callback(v)
		end
		return v
	end

	local current = setValue(default, false)

	local function updateFromMouse()
		local rel = (Mouse.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
		rel = math.clamp(rel, 0, 1)
		current = setValue(min + (max - min) * rel, true)
	end

	Connect(bar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			updateFromMouse()
		end
	end)
	Connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
	Connect(RunService.RenderStepped, function()
		if dragging then
			updateFromMouse()
		end
	end)

	local api = {
		Set = function(v)
			current = setValue(v, false)
		end,
		Get = function()
			return current
		end,
		Flag = options.Flag,
	}

	if options.Gear and win and options.GearSettings then
		AttachGearButton(row, theme, options, win)
	end

	return api
end

MakeDropdown = function(parent, theme, options, multi)
	options = options or {}
	local row = Create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
	})
	Create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Font = theme.Font,
		Text = options.Text or "Dropdown",
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local box = Create("TextButton", {
		Parent = row,
		Position = UDim2.new(0, 0, 0, 18),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = theme.Dropdown,
		Text = "",
		AutoButtonColor = false,
	})
	ApplyCorner(box, 2)
	ApplyStroke(box, theme.PanelBorder, 1, 0.35)
	local display = Create("TextLabel", {
		Parent = box,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, multi and -28 or -18, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		Font = theme.Font,
		Text = "",
		TextColor3 = theme.TextMuted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Create("TextLabel", {
		Parent = box,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(14, 12),
		BackgroundTransparency = 1,
		Text = multi and "..." or "-",
		TextColor3 = theme.TextDim,
		TextSize = multi and 14 or 12,
		Font = theme.Font,
	})

	local list = options.Values or { "Option 1" }
	local open = false
	local menu
	local selected = multi and {} or (options.Default or list[1])
	if multi and type(selected) ~= "table" then
		selected = { selected }
	end

	local function refreshDisplay()
		if multi then
			display.Text = #selected > 0 and table.concat(selected, ", ") or "Select"
		else
			display.Text = tostring(selected)
		end
	end
	refreshDisplay()

	local function closeMenu()
		open = false
		if menu then
			menu:Destroy()
			menu = nil
		end
	end

	local function openMenu()
		closeMenu()
		open = true
		menu = Create("Frame", {
			Parent = box,
			Position = UDim2.new(0, 0, 1, 4),
			Size = UDim2.new(1, 0, 0, math.min(#list * 24 + 4, 140)),
			BackgroundColor3 = theme.Dropdown,
			ZIndex = 100,
			ClipsDescendants = true,
		})
		ApplyCorner(menu, 6)
		ApplyStroke(menu, theme.PanelBorder, 1, 0.4)
		local scroll = Create("ScrollingFrame", {
			Parent = menu,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.fromOffset(0, #list * 24),
			ScrollBarThickness = 3,
			BorderSizePixel = 0,
			ZIndex = 101,
		})
		Create("UIListLayout", { Parent = scroll, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
		ApplyPadding(scroll, 2, 2, 2, 2)

		for i, val in ipairs(list) do
			local item = Create("TextButton", {
				Parent = scroll,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundColor3 = theme.Panel,
				BackgroundTransparency = 0.2,
				Text = val,
				TextColor3 = theme.Text,
				TextSize = 12,
				Font = theme.Font,
				AutoButtonColor = false,
				LayoutOrder = i,
				ZIndex = 102,
			})
			ApplyCorner(item, 4)
			Connect(item.MouseButton1Click, function()
				if multi then
					local idx = table.find(selected, val)
					if idx then
						table.remove(selected, idx)
					else
						table.insert(selected, val)
					end
					refreshDisplay()
					if options.Callback then
						options.Callback(selected)
					end
				else
					selected = val
					refreshDisplay()
					closeMenu()
					if options.Callback then
						options.Callback(val)
					end
				end
			end)
		end
	end

	Connect(box.MouseButton1Click, function()
		if open then
			closeMenu()
		else
			openMenu()
		end
	end)

	Connect(UserInputService.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and open then
			task.defer(function()
				if menu and not box:IsDescendantOf(game) then
					return
				end
			end)
		end
	end)

	return {
		Set = function(v)
			if multi then
				selected = v
			else
				selected = v
			end
			refreshDisplay()
		end,
		Get = function()
			return selected
		end,
		Refresh = function(newList)
			list = newList
		end,
		Flag = options.Flag,
	}
end

-- Library instance
function InstanceUI.New(config)
	config = config or {}
	local theme = config.Theme or DefaultTheme
	if config.ThemeManager and config.ThemeManager.GetTheme then
		theme = config.ThemeManager:GetTheme()
	end

	local lib = {
		Theme = theme,
		Windows = {},
		Keybind = config.Keybind or Enum.KeyCode.RightShift,
		Flags = {},
		Unload = function() end,
	}

	local screen = Create("ScreenGui", {
		Name = "InstanceUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = GetGuiParent(),
	})
	Protect(screen)

	local visible = true
	local keyConn = Connect(UserInputService.InputBegan, function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == lib.Keybind then
			visible = not visible
			for _, win in ipairs(lib.Windows) do
				if win.Main then
					win.Main.Visible = visible
				end
			end
		end
	end)

	function lib:CreateWindow(opts)
		opts = opts or {}
		local win = {
			Library = self,
			Theme = self.Theme,
			Tabs = {},
			ActiveTab = nil,
		}

		local size = opts.Size or Vector2.new(620, 420)
		local main = Create("Frame", {
			Name = "InstanceUI_Window",
			Parent = screen,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = opts.Position or UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundColor3 = theme.Background,
			BorderSizePixel = 1,
			BorderColor3 = theme.PanelBorder,
			ClipsDescendants = true,
			Visible = true,
			Active = true,
		})
		ApplyCorner(main, theme.CornerRadius)
		win.Main = main

		local titleBar = Create("Frame", {
			Parent = main,
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = theme.TitleBar or theme.Background,
			BorderSizePixel = 0,
		})
		Create("UIStroke", {
			Parent = titleBar,
			Color = theme.PanelBorder,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		})
		Create("TextLabel", {
			Parent = titleBar,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -16, 1, 0),
			BackgroundTransparency = 1,
			Text = opts.Title or "InstanceUI",
			TextColor3 = theme.Text,
			TextSize = 13,
			Font = theme.Font,
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		local tabBar = Create("Frame", {
			Parent = main,
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = theme.Background,
			BorderSizePixel = 0,
		})
		Create("Frame", {
			Parent = tabBar,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = theme.PanelBorder,
			BorderSizePixel = 0,
		})
		local tabList = Create("Frame", {
			Parent = tabBar,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		})
		local tabLayout = Create("UIListLayout", {
			Parent = tabList,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		})

		local tabIndicator = Create("Frame", {
			Parent = tabBar,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -1),
			Size = UDim2.fromOffset(80, 2),
			BackgroundColor3 = theme.Accent,
			BorderSizePixel = 0,
			ZIndex = 2,
		})

		local tabHolder = Create("Frame", {
			Parent = main,
			Position = UDim2.fromOffset(8, 56),
			Size = UDim2.new(1, -16, 1, -64),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
		})

		win.Drag = DragController.new(main, { titleBar }, theme)
		win.Resize = ResizeController.new(main, theme, Vector2.new(480, 320))

		if opts.OnSave then
			Connect(titleBar.InputBegan, function() end)
		end

		function win:AddCategory(_name)
			return nil
		end

		local function moveTabIndicator(btn)
			tabIndicator.Position = UDim2.new(0, btn.AbsolutePosition.X - tabBar.AbsolutePosition.X, 1, -1)
			tabIndicator.Size = UDim2.fromOffset(btn.AbsoluteSize.X, 2)
		end

		function win:AddTab(name)
			local tab = {
				Name = name,
				Window = self,
				Sections = {},
				Page = nil,
				Button = nil,
			}

			local tabW = math.max(72, #name * 8 + 28)
			local wrap = Create("Frame", {
				Parent = tabList,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(tabW, 28),
			})
			local btn = Create("TextButton", {
				Parent = wrap,
				Size = UDim2.fromOffset(tabW, 28),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
			})
			Create("TextLabel", {
				Parent = btn,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -24, 1, 0),
				BackgroundTransparency = 1,
				Text = name,
				TextColor3 = theme.Text,
				TextSize = 13,
				Font = theme.Font,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			Create("Frame", {
				Parent = wrap,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 4),
				Size = UDim2.fromOffset(1, 20),
				BackgroundColor3 = theme.TabDivider or theme.PanelBorder,
				BorderSizePixel = 0,
			})

			local page = Create("Frame", {
				Parent = tabHolder,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = false,
			})
			local colLeft = Create("Frame", {
				Parent = page,
				Size = UDim2.new(0.5, -4, 1, 0),
				BackgroundTransparency = 1,
			})
			local colRight = Create("Frame", {
				Parent = page,
				Position = UDim2.new(0.5, 4, 0, 0),
				Size = UDim2.new(0.5, -4, 1, 0),
				BackgroundTransparency = 1,
			})
			for _, col in ipairs({ colLeft, colRight }) do
				local scroll = Create("ScrollingFrame", {
					Parent = col,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ScrollBarThickness = 2,
					ScrollBarImageColor3 = theme.Accent,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(0, 0, 0, 0),
				})
				col.Scroll = scroll
				col.Layout = Create("UIListLayout", {
					Parent = scroll,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 8),
				})
				col.Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					scroll.CanvasSize = UDim2.fromOffset(0, col.Layout.AbsoluteContentSize.Y + 8)
				end)
			end
			tab.Columns = { colLeft, colRight }

			tab.Button = btn
			tab.Page = page

			local function select()
				for _, t in ipairs(self.Tabs) do
					t.Page.Visible = false
				end
				tab.Page.Visible = true
				moveTabIndicator(btn)
				self.ActiveTab = tab
			end

			tab.Select = select
			Connect(btn.MouseButton1Click, select)
			table.insert(self.Tabs, tab)
			if #self.Tabs == 1 then
				task.defer(select)
			end

			function tab:AddSection(title, column)
				column = (column == 2) and 2 or 1
				local col = tab.Columns[column]
				local scroll = col.Scroll
				local section = { Tab = tab, Elements = {}, Column = column }

				local panel = Create("Frame", {
					Parent = scroll,
					BackgroundColor3 = theme.Panel,
					Size = UDim2.new(1, -2, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BorderSizePixel = 1,
					BorderColor3 = theme.PanelBorder,
				})
				ApplyCorner(panel, theme.CornerRadius)

				Create("TextLabel", {
					Parent = panel,
					Position = UDim2.fromOffset(8, 6),
					Size = UDim2.new(1, -16, 0, 14),
					BackgroundTransparency = 1,
					Text = title,
					TextColor3 = theme.Text,
					TextSize = 13,
					Font = theme.Font,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				Create("Frame", {
					Parent = panel,
					Position = UDim2.fromOffset(8, 22),
					Size = UDim2.new(1, -16, 0, 1),
					BackgroundColor3 = theme.Accent,
					BorderSizePixel = 0,
				})
				local body = Create("Frame", {
					Parent = panel,
					Position = UDim2.fromOffset(8, 30),
					Size = UDim2.new(1, -16, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
				})
				local bodyLayout = Create("UIListLayout", {
					Parent = body,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 3),
				})
				local function syncPanel()
					local h = bodyLayout.AbsoluteContentSize.Y
					body.Size = UDim2.new(1, -16, 0, h)
					panel.Size = UDim2.new(1, -2, 0, 38 + h)
				end
				bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(syncPanel)
				syncPanel()

				local library = self.Window.Library

				function section:AddToggle(text, o)
					o = o or {}
					o.Text = text
					local el = MakeToggle(body, theme, o, self.Window)
					if o.Flag then
						library.Flags[o.Flag] = el
					end
					table.insert(section.Elements, el)
					return el
				end

				function section:AddSlider(text, o)
					o = o or {}
					o.Text = text
					local el = MakeSlider(body, theme, o, self.Window)
					if o.Flag then
						library.Flags[o.Flag] = el
					end
					table.insert(section.Elements, el)
					return el
				end

				function section:AddDropdown(text, o)
					o = o or {}
					o.Text = text
					local el = MakeDropdown(body, theme, o, false)
					if o.Flag then
						library.Flags[o.Flag] = el
					end
					table.insert(section.Elements, el)
					return el
				end

				function section:AddMultiDropdown(text, o)
					o = o or {}
					o.Text = text
					local el = MakeDropdown(body, theme, o, true)
					if o.Flag then
						library.Flags[o.Flag] = el
					end
					table.insert(section.Elements, el)
					return el
				end

				function section:AddLabel(text)
					Create("TextLabel", {
						Parent = body,
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						Text = text,
						TextColor3 = theme.TextMuted,
						TextSize = 12,
						Font = theme.Font,
						TextXAlignment = Enum.TextXAlignment.Left,
					})
				end

				function section:AddKeybind(text, o)
					o = o or {}
					o.Text = text
					o.Keybind = o.Default or o.Keybind or "..."
					return section:AddToggle(text, o)
				end

				function section:AddButton(text, callback)
					local b = Create("TextButton", {
						Parent = body,
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundColor3 = theme.Dropdown,
						Text = text,
						TextColor3 = theme.Text,
						TextSize = 12,
						Font = theme.Font,
						AutoButtonColor = false,
						BorderSizePixel = 1,
						BorderColor3 = theme.PanelBorder,
					})
					ApplyCorner(b, 2)
					Connect(b.MouseButton1Click, function()
						if callback then
							callback()
						end
					end)
				end

				section.Panel = panel
				section.Body = body
				table.insert(tab.Sections, section)
				return section
			end

			return tab
		end

		function win:SelectTab(index)
			local t = self.Tabs[index]
			if t and t.Select then
				t.Select()
			end
		end

		function win:CloseGearMenu()
			CloseGearMenu(self)
		end

		function win:Destroy()
			CloseGearMenu(self)
			if self.Drag then
				self.Drag:Destroy()
			end
			if self.Resize then
				self.Resize:Destroy()
			end
			main:Destroy()
		end

		win.Library = self
		table.insert(self.Windows, win)
		return win
	end

	function lib:Unload()
		keyConn:Disconnect()
		for _, w in ipairs(self.Windows) do
			w:Destroy()
		end
		screen:Destroy()
	end

	lib.Unload = function()
		keyConn:Disconnect()
		for _, w in ipairs(self.Windows) do
			w:Destroy()
		end
		screen:Destroy()
	end

	lib.ScreenGui = screen
	lib.DefaultTheme = DefaultTheme

	return lib
end

function InstanceUI.GetTheme()
	return DefaultTheme
end

return InstanceUI
