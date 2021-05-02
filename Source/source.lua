local toolBar = plugin:CreateToolbar("Convert2Lua")
local Selection = game:GetService("Selection")
local activateButton = toolBar:CreateButton("Activate", "Click to activate Convert2Lua", "rbxassetid://61860875")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local activated = false

local statusText
local setCursorLeave
local cursorEnter
local cursorLeave

local GuiObject_Properties = {
	Active = true;
	AnchorPoint = Vector2.new();
	AutomaticSize = Enum.AutomaticSize.None;
	BackgroundColor3 = Color3.fromRGB(255, 255, 255);
	BackgroundTransparency = 0;
	BorderColor3 = Color3.fromRGB(27, 42, 53);
	BorderMode = Enum.BorderMode.Outline;
	BorderSizePixel = 1;
	ClipsDescendants = false;
	LayoutOrder = 0;
	Rotation = 0;
	Selectable = true;
	ZIndex = 1;
	TextTransparency = 0;
	TextSize = 14;
	TextScaled = false;
	Text = "Label";
	Font = Enum.Font.SourceSans;
	MaxVisibleGraphemes = -1;
	TextColor3 = Color3.new();
	TextWrapped = false;
	--Visible will always be set to true
	--Position, Size and Name are always set (Not considered default)
}

local function objectHasProperty(object, Property)
	local success, property = pcall(function()
		return object[Property]
	end)
	return (success and property) -- If property exists it returns the property value
end

local function checkDefaultProperties(object, source)
	--Returns a dict of properties that need to be set that are not default GuiObject properties
	-- Dict is in the form of {["PropertyName"] = PropertyValue}
	local propertyDeviationFromDefault = {}
	for propertyName, propertyValue in pairs(GuiObject_Properties) do
		local prop = objectHasProperty(object, tostring(propertyName))
		if prop and prop ~= propertyValue then -- If Not the default value, add the prop name and value to table
			propertyDeviationFromDefault[propertyName] = prop
		end
	end
	
	local totalconcat = ""
	for property, value in pairs(propertyDeviationFromDefault) do
		totalconcat = totalconcat .. string.gsub([[
NN.PROPERTY = VALUE
]], "%u+", function(pattern)
				pattern, _ = string.gsub(pattern, "%s+", "")
				if pattern == "NN" then
					return object.Name
				elseif pattern == "PROPERTY" then
					return tostring(property)
				elseif pattern == "VALUE" then
					if typeof(value) == "Color3" then
						return "Color3.new("..value.R..","..value.G..","..value.B..")"
					elseif typeof(value) == "Vector2" then
						return "Vector2.new("..value.X..","..value.Y..")"
					elseif property:lower() == "text" then
						return '"'..value..'"'
					end
					return tostring(value)
				end
			end)
	end
	
	--Stringized all properties outside the defaults
	source = source .. totalconcat
	return source
	
end

local function checkType(selected)
	if selected:IsA("GuiObject") then
		return true
	else
		statusText.Text = selected.ClassName.." not supported!"
		statusText.TextColor3 = Color3.new(1, 0, 0)
		return false
	end
end

local function performConversion(Object)
	ChangeHistoryService:SetWaypoint("Conversion to script form")
	-- To be able to undo this action, just in case.
	local source = ""
	local storedNames = {}
	if not checkType(Object) then return end -- Check if its a GuiObject
	local function main(obj, optionalParent)
		source = source .. string.gsub(
			[[
			
local NN = Instance.new("CN")
NN.Name = "NN"
NN.Visible = true
NN.Position = OP
NN.Size = OS

]], "%u+", function(pattern)
				local a, _ = pattern:gsub("%s+", "")
				if a == "NN" then
					return obj.Name
				elseif a == "CN" then
					return obj.ClassName
				elseif a == "OP" then
					return "UDim2.new("..obj.Position.X.Scale..","..obj.Position.X.Offset..","..obj.Position.Y.Scale..","..obj.Position.Y.Offset..")"
				elseif a == "OS" then
					return "UDim2.new("..obj.Size.X.Scale..","..obj.Size.X.Offset..","..obj.Size.Y.Scale..","..obj.Size.Y.Offset..")"
				end
			end
		)
		source = checkDefaultProperties(obj, source)
		source = source .. string.gsub([[
NN.Parent = PP
]], "%u+", function(pattern)
				pattern = string.gsub(pattern, "%s+", "")
				if pattern == "PP" then
					for _, name in ipairs(storedNames) do
						if name == obj.Parent.Name and name ~= obj.Name then
							return name
						end
					end
					return "game." ..obj.Parent:GetFullName()
				elseif pattern == "NN" then
					storedNames[#storedNames + 1] = obj.Name
					return obj.Name
				end
		end)
	
		return source
	end
	local no = 0
	local function Convert(obj)
		
		source = main(obj)
		
		for _, gui in ipairs(obj:GetChildren()) do
			if (#(gui:GetChildren()) > 0) then
				Convert(gui)
			else
				source = main(gui) -- where problem is lmao
			end
		end
		
		
	end
	
	Convert(Object)
	
	local newScript =  game.StarterGui:FindFirstChild(Object.Name) or Instance.new("LocalScript")
	newScript.Name = Object.Name
	newScript.Source = source
	newScript.Parent = game.StarterGui
end

local function convertUI()
	local selected = Selection:Get()
	local lastSelected = selected[#selected]
	if lastSelected then
		performConversion(lastSelected)
	end
end

local function setCursor(cursorId)
	plugin:GetMouse().Icon = cursorId
end

local function setCursorEnter(button)
	cursorEnter = button.MouseEnter:Connect(function()
		setCursor("rbxasset://SystemCursors/PointingHand")
		cursorEnter:Disconnect()
		setCursorLeave(button)
	end)
end

setCursorLeave = function(button)
	cursorLeave = button.MouseLeave:Connect(function()
		setCursor("rbxasset://SystemCursors/Arrow")
		cursorLeave:Disconnect()
		setCursorEnter(button)
	end)
end

local function syncGuiColors(objects)
	local function setColors()
		for _, guiObject in pairs(objects) do
			-- Sync background color
			guiObject.BackgroundColor3 = settings().Studio.Theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
		end
	end
	-- Run 'setColors()' function to initially sync colors
	setColors()
	-- Connect 'ThemeChanged' event to the 'setColors()' function
	settings().Studio.ThemeChanged:Connect(setColors)
end


local function CreateWidget(Name : string)
	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Float, -- Dock state
		true,   -- Widget will be initially enabled
		false,  -- Don't override the previous enabled state
		195,    -- Default width of the floating window
		103,    -- Default height of the floating window
		195,    -- Minimum width of the floating window
		103     -- Minimum height of the floating window
	)
	local widget = plugin:CreateDockWidgetPluginGui(Name, widgetInfo)
	widget.Title = Name
	return widget
end

local function ScaleToOffset(Scale)
	local ViewPortSize = workspace.Camera.ViewportSize
	return ({ViewPortSize.X * Scale[1],ViewPortSize.Y * Scale[2]})
end


local function OffsetToScale(Offset)
	local ViewPortSize = workspace.Camera.ViewportSize
	return ({Offset[1] / ViewPortSize.X, Offset[2] / ViewPortSize.Y})
end

local function precreateWidget()
	
	local widget = CreateWidget("Convert")

	return widget
end

local function makeUI(widget)
	local Credits = Instance.new("TextLabel")
	Credits.Name = "Credits"
	Credits.Visible = true
	Credits.Position = UDim2.new(0,0,0.73786419630051,0)
	Credits.Size = UDim2.new(0,195,0,27)

	Credits.TextWrapped = true
	Credits.BackgroundTransparency = 1
	Credits.BorderColor3 = Color3.new(0.10588236153126,0.16470588743687,0.20784315466881)
	Credits.Text = "By keeptheluck! Please note this version is unrevised."
	Credits.TextScaled = true
	Credits.Parent = widget

	local Monitor = Instance.new("ImageButton")
	Monitor.Name = "Monitor"
	Monitor.Visible = true
	Monitor.Position = UDim2.new(0.086999997496605,0,0.40000000596046,0)
	Monitor.Size = UDim2.new(0,86,0,27)
	Monitor.Image = "rbxasset://textures/TerrainTools/button_default.png"
	Monitor.HoverImage = "rbxasset://textures/TerrainTools/button_hover.png"
	Monitor.AutoButtonColor = false

	Monitor.BorderColor3 = Color3.new(0.10588236153126,0.16470588743687,0.20784315466881)
	Monitor.BackgroundTransparency = 1
	Monitor.Parent = widget

	local Track = Instance.new("TextLabel")
	Track.Name = "Track"
	Track.Visible = true
	Track.Position = UDim2.new(0,0,0,0)
	Track.Size = UDim2.new(1,0,-0.85185205936432,50)

	Track.TextWrapped = true
	Track.BackgroundTransparency = 1
	Track.BorderColor3 = Color3.new(0.10588236153126,0.16470588743687,0.20784315466881)
	Track.Text = "Track changes"
	Track.TextSize = 15
	Track.Parent = Monitor

	local Convert = Instance.new("ImageButton")
	Convert.Name = "Convert"
	Convert.Visible = true
	Convert.Position = UDim2.new(0.087179489433765,0,0.10679611563683,0)
	Convert.Size = UDim2.new(0,86,0,27)
	Convert.Image = "rbxasset://textures/TerrainTools/button_default.png"
	Convert.HoverImage = "rbxasset://textures/TerrainTools/button_hover.png"
	Convert.AutoButtonColor = false

	Convert.BorderColor3 = Color3.new(0.10588236153126,0.16470588743687,0.20784315466881)
	Convert.BackgroundTransparency = 1
	Convert.Parent = widget

	local ConvertText = Instance.new("TextLabel")
	ConvertText.Name = "ConvertText"
	ConvertText.Visible = true
	ConvertText.Position = UDim2.new(0,0,0,0)
	ConvertText.Size = UDim2.new(1,0,-0.85185205936432,50)

	ConvertText.TextWrapped = true
	ConvertText.BackgroundTransparency = 1
	ConvertText.BorderColor3 = Color3.new(0.10588236153126,0.16470588743687,0.20784315466881)
	ConvertText.Text = "Convert"
	ConvertText.TextSize = 15
	ConvertText.Parent = Convert

	local Status = Instance.new("TextLabel")
	Status.Name = "Status"
	Status.Visible = true
	Status.Position = UDim2.new(0.5794872045517,0,0.10679611563683,0)
	Status.Size = UDim2.new(0,73,0,57)

	Status.TextWrapped = true
	Status.BackgroundTransparency = 1
	Status.TextColor3 = Color3.new(1,0,0)
	Status.BorderColor3 = Color3.new(0.10588236153126,0.16470588743687,0.20784315466881)
	Status.Text = "No Instance selected"
	Status.BackgroundColor3 = Color3.new(1,0,0)
	Status.Parent = widget
	
	return Convert, Monitor, Status
end

local widget = precreateWidget()
local convert, monitor, status = makeUI(widget)
statusText = status

--syncGuiColors({convert})
setCursorEnter(convert)
setCursorLeave(convert)


convert.MouseButton1Click:Connect(convertUI)

local function Activated()
	 widget.Enabled = not widget.Enabled
end

activateButton.Click:Connect(Activated)

Selection.SelectionChanged:Connect(function()
	if not widget.Enabled then return end
	
	local selecteds = Selection:Get()
	local last = selecteds[1]
	if (last ~= nil and checkType(last)) or (last and last.ClassName == "LocalScript") then
		status.Text = last.ClassName .. " detected!"
		status.TextColor3 = Color3.new(0, 1, 0)
	end
end)

local function onSourceChanged(uI, scr)
	if uI then
		uI:Destroy()
	end
	print("Source change detected! This is still in development!")
	loadstring(scr.Source)()
end

local detecting = false
local signal

monitor.MouseButton1Down:Connect(function()
	if not widget.Enabled then return end
	
	if detecting then
		if signal then
			signal:Disconnect()
			
			monitor.Image = "rbxasset://textures/TerrainTools/button_default.png"
			monitor.HoverImage = "rbxasset://textures/TerrainTools/button_hover.png"
			monitor.AutoButtonColor = true
			
			detecting = false
			return
		end
	end
	local selecteds = Selection:Get()
	local last = selecteds[1]
	
	if last == nil then return end
	
	monitor.AutoButtonColor = false
	
	if last:IsA("LocalScript") then
		statusText.Text = "Tracking LocalScript!"
		statusText.TextColor3 = Color3.new(1, 0, 0)
		
		monitor.HoverImage = ""
		monitor.Image = "rbxasset://textures/TerrainTools/button_pressed.png"
		detecting = true
		
		signal = last:GetPropertyChangedSignal("Source"):Connect(function()
			local ScreenUI = game.StarterGui:FindFirstChildWhichIsA("ScreenGui")
			local ParentUI = ScreenUI and ScreenUI:FindFirstChild(last.Name, true)
			onSourceChanged(ParentUI, last)
		end)
	else
		detecting = false
		if signal then
			signal:Disconnect()
		end
		statusText.Text = "Select the localscript and click Convert!"
	end
end)