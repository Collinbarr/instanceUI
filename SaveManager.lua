--[[
	InstanceUI SaveManager
	Save / load UI flags and window position to executor filesystem or HttpService queue.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local SaveManager = {}
SaveManager.Version = "1.0.0"

local function getWriteFile()
	returnwritefile or writefile
end

local function getReadFile()
	return readfile
end

local function getIsFile()
	return isfile
end

local function getMakeFolder()
	return makefolder
end

local function hasFilesystem()
	return getWriteFile() and getReadFile() and getIsFile()
end

function SaveManager.New(options)
	options = options or {}
	local self = {
		Folder = options.Folder or "InstanceUI",
		ConfigName = options.ConfigName or "default",
		Library = nil,
		Window = nil,
		ThemeManager = nil,
		Ignore = options.Ignore or {},
	}

	local function path(name)
		return self.Folder .. "/" .. name .. ".json"
	end

	local function ensureFolder()
		if not hasFilesystem() then
			return false
		end
		if getMakeFolder() and not getIsFile()(self.Folder) then
			pcall(function()
				getMakeFolder()(self.Folder)
			end)
		end
		return true
	end

	function self:SetLibrary(library)
		self.Library = library
	end

	function self:SetWindow(window)
		self.Window = window
	end

	function self:SetThemeManager(tm)
		self.ThemeManager = tm
	end

	function self:IgnoreFlag(flag)
		self.Ignore[flag] = true
	end

	function self:Collect()
		local data = {
			Flags = {},
			Window = {},
			Theme = nil,
		}

		if self.Library and self.Library.Flags then
			for flag, element in pairs(self.Library.Flags) do
				if not self.Ignore[flag] and element.Get then
					local ok, value = pcall(function()
						return element:Get()
					end)
					if ok then
						if typeof(value) == "Color3" then
							data.Flags[flag] = {
								__type = "Color3",
								R = value.R,
								G = value.G,
								B = value.B,
							}
						elseif typeof(value) == "EnumItem" then
							data.Flags[flag] = tostring(value)
						else
							data.Flags[flag] = value
						end
					end
				end
			end
		end

		if self.Window and self.Window.Main then
			local m = self.Window.Main
			data.Window = {
				Position = { m.Position.X.Scale, m.Position.X.Offset, m.Position.Y.Scale, m.Position.Y.Offset },
				Size = { m.Size.X.Offset, m.Size.Y.Offset },
			}
		end

		if self.ThemeManager and self.ThemeManager.Serialize then
			data.Theme = self.ThemeManager:Serialize()
		end

		return data
	end

	function self:Apply(data)
		if not data then
			return false
		end

		if data.Theme and self.ThemeManager then
			pcall(function()
				self.ThemeManager:Deserialize(data.Theme)
				self.ThemeManager:ApplyToLibrary(self.Library)
			end)
		end

		if data.Window and self.Window and self.Window.Main then
			local m = self.Window.Main
			if data.Window.Position then
				local p = data.Window.Position
				m.Position = UDim2.new(p[1], p[2], p[3], p[4])
			end
			if data.Window.Size then
				local s = data.Window.Size
				m.Size = UDim2.fromOffset(s[1], s[2])
			end
		end

		if data.Flags and self.Library and self.Library.Flags then
			for flag, value in pairs(data.Flags) do
				local el = self.Library.Flags[flag]
				if el and el.Set then
					if type(value) == "table" and value.__type == "Color3" then
						value = Color3.new(value.R, value.G, value.B)
					end
					pcall(function()
						el:Set(value)
					end)
				end
			end
		end

		return true
	end

	function self:Save(name)
		name = name or self.ConfigName
		local data = self:Collect()
		local json = HttpService:JSONEncode(data)

		if hasFilesystem() and ensureFolder() then
			getWriteFile()(path(name), json)
			return true, json
		end

		-- Fallback: store in player attribute (small configs only)
		pcall(function()
			LocalPlayer:SetAttribute("InstanceUI_" .. name, json:sub(1, 199000))
		end)
		return false, json
	end

	function self:Load(name)
		name = name or self.ConfigName
		local json

		if hasFilesystem() and getIsFile()(path(name)) then
			json = getReadFile()(path(name))
		else
			json = LocalPlayer:GetAttribute("InstanceUI_" .. name)
		end

		if not json or json == "" then
			return false
		end

		local ok, data = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		if not ok then
			return false
		end
		return self:Apply(data)
	end

	function self:Delete(name)
		name = name or self.ConfigName
		if hasFilesystem() and getIsFile()(path(name)) then
			if delfile then
				delfile(path(name))
			end
			return true
		end
		LocalPlayer:SetAttribute("InstanceUI_" .. name, nil)
		return false
	end

	function self:ListConfigs()
		if not hasFilesystem() then
			return { self.ConfigName }
		end
		local list = {}
		if listfiles then
			pcall(function()
				for _, file in ipairs(listfiles(self.Folder)) do
					if file:match("%.json$") then
						table.insert(list, file:match("([^/\\]+)%.json$"))
					end
				end
			end)
		end
		if #list == 0 then
			table.insert(list, self.ConfigName)
		end
		return list
	end

	function self:BindSaveButton(buttonOrCallback)
		if type(buttonOrCallback) == "function" then
			return buttonOrCallback(function()
				self:Save()
			end)
		end
	end

	function self:AutoSave(interval)
		interval = interval or 60
		task.spawn(function()
			while self.Library and self.Library.ScreenGui and self.Library.ScreenGui.Parent do
				task.wait(interval)
				self:Save()
			end
		end)
	end

	return self
end

return SaveManager
