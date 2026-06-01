--[[
	InstanceUI ThemeManager
	Apply and persist custom color themes for InstanceUI.
]]

local HttpService = game:GetService("HttpService")

local ThemeManager = {}
ThemeManager.Version = "1.0.0"

local Presets = {
	Default = {
		Name = "Default",
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
	},
	Midnight = {
		Name = "Midnight",
		Background = Color3.fromRGB(6, 8, 14),
		Sidebar = Color3.fromRGB(10, 12, 20),
		Panel = Color3.fromRGB(14, 18, 28),
		PanelBorder = Color3.fromRGB(24, 30, 48),
		Accent = Color3.fromRGB(88, 101, 242),
		AccentGlow = Color3.fromRGB(110, 120, 255),
		Text = Color3.fromRGB(240, 242, 255),
		TextMuted = Color3.fromRGB(120, 128, 150),
		TextDim = Color3.fromRGB(70, 78, 98),
		ToggleOff = Color3.fromRGB(38, 42, 58),
		ToggleOn = Color3.fromRGB(88, 101, 242),
		SliderTrack = Color3.fromRGB(32, 36, 52),
		SliderFill = Color3.fromRGB(88, 101, 242),
		Dropdown = Color3.fromRGB(18, 22, 34),
		Hover = Color3.fromRGB(26, 30, 44),
		ActiveTab = Color3.fromRGB(70, 82, 220),
		ActiveTabBg = Color3.fromRGB(50, 60, 180),
		GhostStroke = Color3.fromRGB(88, 101, 242),
		CornerRadius = 8,
		Font = Enum.Font.GothamMedium,
		FontBold = Enum.Font.GothamBold,
	},
	Crimson = {
		Name = "Crimson",
		Background = Color3.fromRGB(14, 10, 12),
		Sidebar = Color3.fromRGB(20, 14, 16),
		Panel = Color3.fromRGB(28, 18, 22),
		PanelBorder = Color3.fromRGB(58, 32, 40),
		Accent = Color3.fromRGB(255, 60, 90),
		AccentGlow = Color3.fromRGB(255, 90, 115),
		Text = Color3.fromRGB(250, 235, 238),
		TextMuted = Color3.fromRGB(150, 110, 118),
		TextDim = Color3.fromRGB(100, 70, 78),
		ToggleOff = Color3.fromRGB(52, 38, 42),
		ToggleOn = Color3.fromRGB(255, 60, 90),
		SliderTrack = Color3.fromRGB(48, 32, 38),
		SliderFill = Color3.fromRGB(255, 60, 90),
		Dropdown = Color3.fromRGB(32, 20, 24),
		Hover = Color3.fromRGB(42, 28, 32),
		ActiveTab = Color3.fromRGB(200, 40, 70),
		ActiveTabBg = Color3.fromRGB(140, 28, 50),
		GhostStroke = Color3.fromRGB(255, 80, 110),
		CornerRadius = 8,
		Font = Enum.Font.GothamMedium,
		FontBold = Enum.Font.GothamBold,
	},
}

local function deepCopy(t)
	local c = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			c[k] = deepCopy(v)
		else
			c[k] = v
		end
	end
	return c
end

local function colorToHex(c)
	return string.format(
		"#%02X%02X%02X",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5)
	)
end

local function hexToColor(hex)
	hex = hex:gsub("#", "")
	local r = tonumber(hex:sub(1, 2), 16) or 0
	local g = tonumber(hex:sub(3, 4), 16) or 0
	local b = tonumber(hex:sub(5, 6), 16) or 0
	return Color3.fromRGB(r, g, b)
end

function ThemeManager.New(options)
	options = options or {}
	local self = {
		Current = options.Preset or "Default",
		Custom = deepCopy(Presets.Default),
		Presets = Presets,
	}

	function self:GetTheme()
		if self.Presets[self.Current] then
			return deepCopy(self.Presets[self.Current])
		end
		return deepCopy(self.Custom)
	end

	function self:SetPreset(name)
		if self.Presets[name] then
			self.Current = name
			return true
		end
		return false
	end

	function self:GetPresetNames()
		local names = {}
		for n in pairs(self.Presets) do
			table.insert(names, n)
		end
		table.sort(names)
		return names
	end

	function self:Override(key, value)
		if self.Custom[key] ~= nil or Presets.Default[key] ~= nil then
			self.Custom[key] = value
			self.Current = "Custom"
		end
	end

	function self:SetAccent(hexOrColor3)
		local c = typeof(hexOrColor3) == "Color3" and hexOrColor3 or hexToColor(hexOrColor3)
		self:Override("Accent", c)
		self:Override("AccentGlow", Color3.new(
			math.min(c.R * 1.15, 1),
			math.min(c.G * 1.15, 1),
			math.min(c.B * 1.15, 1)
		))
		self:Override("ToggleOn", c)
		self:Override("SliderFill", c)
		self:Override("GhostStroke", c)
	end

	function self:Serialize()
		local theme = self:GetTheme()
		local data = { Preset = self.Current, Colors = {} }
		for k, v in pairs(theme) do
			if typeof(v) == "Color3" then
				data.Colors[k] = colorToHex(v)
			elseif type(v) == "number" or type(v) == "string" then
				data.Colors[k] = v
			end
		end
		return HttpService:JSONEncode(data)
	end

	function self:Deserialize(json)
		local ok, data = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		if not ok or not data then
			return false
		end
		if data.Preset and self.Presets[data.Preset] then
			self.Current = data.Preset
		end
		if data.Colors then
			for k, v in pairs(data.Colors) do
				if type(v) == "string" and v:sub(1, 1) == "#" then
					self.Custom[k] = hexToColor(v)
				else
					self.Custom[k] = v
				end
			end
			if data.Preset == nil or data.Preset == "Custom" then
				self.Current = "Custom"
			end
		end
		return true
	end

	function self:ApplyToLibrary(library)
		if not library then
			return
		end
		library.Theme = self:GetTheme()
	end

	return self
end

ThemeManager.Presets = Presets
return ThemeManager
