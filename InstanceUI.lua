--[[
	InstanceUI — Roblox UI library
	Open: Right Shift (configurable)
	Drag: title bar + sidebar | Ghost outline while dragging
	Resize: edges + bottom-right corner
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
	Background = Color3.fromRGB(10, 12, 18),
	Sidebar = Color3.fromRGB(14, 17, 26),
	Panel = Color3.fromRGB(18, 22, 32),
	PanelBorder = Color3.fromRGB(32, 40, 58),
	Accent = Color3.fromRGB(0, 132, 255),
	AccentGlow = Color3.fromRGB(0, 160, 255),
	Text = Color3.fromRGB(235, 240, 250),
	TextMuted = Color3.fromRGB(108, 118, 140),
	TextDim = Color3.fromRGB(72, 82, 102),
	ToggleOff = Color3.fromRGB(42, 48, 62),
	ToggleOn = Color3.fromRGB(0, 132, 255),
	SliderTrack = Color3.fromRGB(36, 44, 60),
	SliderFill = Color3.fromRGB(0, 132, 255),
	Dropdown = Color3.fromRGB(22, 28, 40),
	Hover = Color3.fromRGB(28, 34, 48),
	ActiveTab = Color3.fromRGB(0, 100, 200),
	ActiveTabBg = Color3.fromRGB(0, 80, 160),
	GhostStroke = Color3.fromRGB(0, 140, 255),
	CornerRadius = 8,
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
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

function DragController:Begin(input)
	if self.Dragging then
		return
	end
	self.Dragging = true
	self.StartMouse = Vector2.new(Mouse.X, Mouse.Y)
	self.StartPos = self.Window.Position

	local size = self.Window.Size
	self.Ghost = Create("Frame", {
		Name = "InstanceUI_Ghost",
		Parent = self.Window.Parent,
		BackgroundTransparency = 1,
		Position = self.StartPos,
		Size = size,
		ZIndex = self.Window.ZIndex + 50,
		Active = false,
	})
	ApplyCorner(self.Ghost, self.Theme.CornerRadius)
	ApplyStroke(self.Ghost, self.Theme.GhostStroke, 2, 0.15)

	local fill = Create("Frame", {
		Parent = self.Ghost,
		BackgroundColor3 = self.Theme.Accent,
		BackgroundTransparency = 0.92,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		ZIndex = self.Ghost.ZIndex,
	})
	ApplyCorner(fill, self.Theme.CornerRadius)

	self.MoveConn = Connect(RunService.RenderStepped, function()
		if not self.Dragging or not self.Ghost then
			return
		end
		local delta = Vector2.new(Mouse.X, Mouse.Y) - self.StartMouse
		self.Ghost.Position = UDim2.new(
			self.StartPos.X.Scale,
			self.StartPos.X.Offset + delta.X,
			self.StartPos.Y.Scale,
			self.StartPos.Y.Offset + delta.Y
		)
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
		Tween(self.Window, TWEEN_SNAP, { Position = self.Ghost.Position }):Play()
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

-- Component builders
local function MakeToggle(parent, theme, options)
	options = options or {}
	local row = Create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 28),
	})
	local label = Create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, options.Gear and -70 or -50, 1, 0),
		Font = theme.Font,
		Text = options.Text or "Toggle",
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local track = Create("TextButton", {
		Parent = row,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(36, 18),
		BackgroundColor3 = theme.ToggleOff,
		Text = "",
		AutoButtonColor = false,
	})
	ApplyCorner(track, 9)
	local knob = Create("Frame", {
		Parent = track,
		BackgroundColor3 = Color3.fromRGB(200, 210, 225),
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(2, 2),
	})
	ApplyCorner(knob, 7)

	local state = options.Default or false
	local function refresh(animate)
		local on = state
		track.BackgroundColor3 = on and theme.ToggleOn or theme.ToggleOff
		local goal = { Position = on and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2) }
		if animate then
			Tween(knob, TWEEN_FAST, goal):Play()
		else
			knob.Position = goal.Position
		end
	end
	refresh(false)

	Connect(track.MouseButton1Click, function()
		state = not state
		refresh(true)
		if options.Callback then
			options.Callback(state)
		end
	end)

	local api = {
		Instance = row,
		Set = function(v)
			state = v
			refresh(true)
		end,
		Get = function()
			return state
		end,
		OnChanged = function(cb)
			options.Callback = cb
		end,
		Flag = options.Flag,
	}

	if options.Gear then
		Create("TextButton", {
			Parent = row,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -44, 0.5, 0),
			Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 1,
			Text = "⚙",
			TextColor3 = theme.TextMuted,
			TextSize = 14,
			Font = theme.Font,
			AutoButtonColor = false,
		})
	end

	return api
end

local function MakeSlider(parent, theme, options)
	options = options or {}
	local row = Create("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
	})
	Create("TextLabel", {
		Parent = row,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -48, 0, 16),
		Font = theme.Font,
		Text = options.Text or "Slider",
		TextColor3 = theme.Text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local valueLabel = Create("TextLabel", {
		Parent = row,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(48, 16),
		BackgroundTransparency = 1,
		Font = theme.Font,
		Text = "",
		TextColor3 = theme.TextMuted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local bar = Create("TextButton", {
		Parent = row,
		Position = UDim2.new(0, 0, 0, 22),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = theme.SliderTrack,
		Text = "",
		AutoButtonColor = false,
	})
	ApplyCorner(bar, 3)
	local fill = Create("Frame", {
		Parent = bar,
		BackgroundColor3 = theme.SliderFill,
		Size = UDim2.new(0.5, 0, 1, 0),
		BorderSizePixel = 0,
	})
	ApplyCorner(fill, 3)
	local knob = Create("Frame", {
		Parent = bar,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme.AccentGlow,
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ZIndex = 2,
	})
	ApplyCorner(knob, 5)

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
		local alpha = (v - min) / (max - min)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
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

	return {
		Set = function(v)
			current = setValue(v, false)
		end,
		Get = function()
			return current
		end,
		Flag = options.Flag,
	}
end

local function MakeDropdown(parent, theme, options, multi)
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
	ApplyCorner(box, 6)
	ApplyStroke(box, theme.PanelBorder, 1, 0.5)
	local display = Create("TextLabel", {
		Parent = box,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(8, 0),
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
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		Text = "▼",
		TextColor3 = theme.TextDim,
		TextSize = 10,
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
			Sections = {},
			Elements = {},
		}

		local size = opts.Size or Vector2.new(720, 440)
		local main = Create("Frame", {
			Name = "InstanceUI_Window",
			Parent = screen,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = opts.Position or UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundColor3 = theme.Background,
			ClipsDescendants = true,
			Visible = true,
			Active = true,
		})
		ApplyCorner(main, theme.CornerRadius)
		ApplyStroke(main, theme.PanelBorder, 1, 0.55)
		win.Main = main

		local sidebar = Create("Frame", {
			Parent = main,
			Size = UDim2.new(0, 168, 1, 0),
			BackgroundColor3 = theme.Sidebar,
			BorderSizePixel = 0,
		})
		ApplyCorner(sidebar, theme.CornerRadius)
		local sideFix = Create("Frame", {
			Parent = sidebar,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 8, 0, 0),
			Size = UDim2.new(0, 16, 1, 0),
			BackgroundColor3 = theme.Sidebar,
			BorderSizePixel = 0,
		})

		local sideScroll = Create("ScrollingFrame", {
			Parent = sidebar,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -64),
			Position = UDim2.fromOffset(0, 8),
			ScrollBarThickness = 0,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			BorderSizePixel = 0,
		})
		local sideList = Create("UIListLayout", {
			Parent = sideScroll,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		})
		ApplyPadding(sideScroll, 8, 8, 8, 10)

		local profile = Create("Frame", {
			Parent = sidebar,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 48),
			BackgroundTransparency = 1,
		})
		local avatar = Create("Frame", {
			Parent = profile,
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = theme.Panel,
		})
		ApplyCorner(avatar, 6)
		if opts.AvatarImage then
			Create("ImageLabel", {
				Parent = avatar,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Image = opts.AvatarImage,
			})
		end
		Create("TextLabel", {
			Parent = profile,
			Position = UDim2.fromOffset(44, 4),
			Size = UDim2.new(1, -48, 0, 16),
			BackgroundTransparency = 1,
			Text = opts.Username or "User",
			TextColor3 = theme.Text,
			TextSize = 13,
			Font = theme.FontBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		Create("TextLabel", {
			Parent = profile,
			Position = UDim2.fromOffset(44, 22),
			Size = UDim2.new(1, -48, 0, 14),
			BackgroundTransparency = 1,
			Text = opts.Subscription or "TILL: --",
			TextColor3 = theme.Accent,
			TextSize = 11,
			Font = theme.Font,
			TextXAlignment = Enum.TextXAlignment.Left,
		})

		local content = Create("Frame", {
			Parent = main,
			Position = UDim2.fromOffset(168, 0),
			Size = UDim2.new(1, -168, 1, 0),
			BackgroundTransparency = 1,
		})

		local topbar = Create("Frame", {
			Parent = content,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
		})
		local saveBtn = Create("TextButton", {
			Parent = topbar,
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.fromOffset(72, 26),
			BackgroundColor3 = theme.Panel,
			Text = "  💾 Save",
			TextColor3 = theme.Text,
			TextSize = 12,
			Font = theme.Font,
			AutoButtonColor = false,
		})
		ApplyCorner(saveBtn, 6)
		ApplyStroke(saveBtn, theme.PanelBorder, 1, 0.5)

		local globalDrop
		local globalBox = Create("TextButton", {
			Parent = topbar,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(200, 26),
			BackgroundColor3 = theme.Panel,
			Text = "Global  ▼",
			TextColor3 = theme.TextMuted,
			TextSize = 12,
			Font = theme.Font,
			AutoButtonColor = false,
		})
		ApplyCorner(globalBox, 6)
		ApplyStroke(globalBox, theme.PanelBorder, 1, 0.5)

		local utilX = 12
		for _, icon in ipairs({ "💬", "⚙", "🔍" }) do
			Create("TextButton", {
				Parent = topbar,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -utilX, 0, 10),
				Size = UDim2.fromOffset(26, 26),
				BackgroundColor3 = theme.Panel,
				Text = icon,
				TextColor3 = theme.TextMuted,
				TextSize = 13,
				Font = theme.Font,
				AutoButtonColor = false,
			})
			utilX += 34
		end

		local tabHolder = Create("Frame", {
			Parent = content,
			Position = UDim2.fromOffset(12, 48),
			Size = UDim2.new(1, -24, 1, -56),
			BackgroundTransparency = 1,
		})

		local dragZone = Create("Frame", {
			Parent = topbar,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -200, 1, 0),
			Position = UDim2.fromOffset(90, 0),
			ZIndex = 5,
		})

		win.Drag = DragController.new(main, { sidebar, topbar, dragZone }, theme)
		win.Resize = ResizeController.new(main, theme, Vector2.new(560, 380))

		Connect(saveBtn.MouseButton1Click, function()
			if opts.OnSave then
				opts.OnSave()
			end
		end)

		function win:AddCategory(name)
			local cat = Create("TextLabel", {
				Parent = sideScroll,
				Size = UDim2.new(1, -4, 0, 18),
				BackgroundTransparency = 1,
				Text = string.upper(name),
				TextColor3 = theme.TextDim,
				TextSize = 10,
				Font = theme.FontBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			sideList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				sideScroll.CanvasSize = UDim2.fromOffset(0, sideList.AbsoluteContentSize.Y + 16)
			end)
			return cat
		end

		function win:AddTab(name, icon, category)
			local tab = {
				Name = name,
				Window = self,
				Sections = {},
				Page = nil,
				Button = nil,
			}

			local btn = Create("TextButton", {
				Parent = sideScroll,
				Size = UDim2.new(1, -4, 0, 28),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
			})
			local highlight = Create("Frame", {
				Parent = btn,
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = theme.ActiveTabBg,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 0,
			})
			ApplyCorner(highlight, 6)
			Create("TextLabel", {
				Parent = btn,
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(20, 28),
				BackgroundTransparency = 1,
				Text = icon or "•",
				TextColor3 = theme.TextMuted,
				TextSize = 14,
				Font = theme.Font,
			})
			Create("TextLabel", {
				Parent = btn,
				Position = UDim2.fromOffset(30, 0),
				Size = UDim2.new(1, -34, 1, 0),
				BackgroundTransparency = 1,
				Text = name,
				TextColor3 = theme.Text,
				TextSize = 13,
				Font = theme.Font,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local page = Create("Frame", {
				Parent = tabHolder,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Visible = false,
			})
			local grid = Create("UIGridLayout", {
				Parent = page,
				CellSize = UDim2.new(0.5, -8, 1, 0),
				CellPadding = UDim2.fromOffset(12, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirectionMaxCells = 2,
			})

			tab.Button = btn
			tab.Page = page
			tab.Highlight = highlight

			local function select()
				for _, t in ipairs(self.Tabs) do
					t.Page.Visible = false
					Tween(t.Highlight, TWEEN_FAST, { BackgroundTransparency = 1 }):Play()
				end
				tab.Page.Visible = true
				Tween(highlight, TWEEN_FAST, { BackgroundTransparency = 0.75 }):Play()
				self.ActiveTab = tab
			end

			tab.Select = select
			Connect(btn.MouseButton1Click, select)
			table.insert(self.Tabs, tab)
			if #self.Tabs == 1 then
				select()
			end

			function tab:AddSection(title, column)
				column = column or 1
				tab._sectionOrder = (tab._sectionOrder or 0) + 1
				local section = {
					Tab = tab,
					Elements = {},
					Column = column,
				}
				local panel = Create("Frame", {
					Parent = page,
					BackgroundColor3 = theme.Panel,
					LayoutOrder = tab._sectionOrder,
					Size = UDim2.fromScale(1, 1),
				})
				ApplyCorner(panel, theme.CornerRadius)
				ApplyStroke(panel, theme.PanelBorder, 1, 0.45)

				Create("TextLabel", {
					Parent = panel,
					Position = UDim2.fromOffset(12, 8),
					Size = UDim2.new(1, -16, 0, 14),
					BackgroundTransparency = 1,
					Text = string.upper(title),
					TextColor3 = theme.TextDim,
					TextSize = 10,
					Font = theme.FontBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				local body = Create("Frame", {
					Parent = panel,
					Position = UDim2.fromOffset(10, 28),
					Size = UDim2.new(1, -20, 1, -36),
					BackgroundTransparency = 1,
				})
				Create("UIListLayout", {
					Parent = body,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				})

				local library = self.Window.Library

				function section:AddToggle(text, o)
					o = o or {}
					o.Text = text
					local el = MakeToggle(body, theme, o)
					if o.Flag then
						library.Flags[o.Flag] = el
					end
					table.insert(section.Elements, el)
					return el
				end

				function section:AddSlider(text, o)
					o = o or {}
					o.Text = text
					local el = MakeSlider(body, theme, o)
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

				function section:AddButton(text, callback)
					local b = Create("TextButton", {
						Parent = body,
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundColor3 = theme.Dropdown,
						Text = text,
						TextColor3 = theme.Text,
						TextSize = 12,
						Font = theme.Font,
						AutoButtonColor = false,
					})
					ApplyCorner(b, 6)
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

		function win:Destroy()
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
