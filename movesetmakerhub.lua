--// LocalScript (Client-Side) placed in StarterPlayerScripts
--------------------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------------------
local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local TweenService       = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService  = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local sequenceUIList = {}      -- UI handles go in here
local animationReplacements = {}
local configNameBox
local buildReplacementTable
local connections = {}



-- A folder/filename to store your moveset files:
-- You can change this to whatever “subfolder/filename” you like.
local CONFIG_FOLDER = "MyMoveSets"      -- e.g. "MyMoveSets"
local CONFIG_FILE   = CONFIG_FOLDER .. "/latestMoveset.json"

local function readLastConfigMeta()
    if not (isfile and isfile(CONFIG_FILE)) then
        return nil
    end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok then
        return nil
    end
    local okDecode, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if okDecode and typeof(decoded) == "table" then
        return decoded
    end
    return nil
end

local function rememberLastConfigName(name)
    if not name or name == "" then
        return
    end
    local payloadOk, payload = pcall(function()
        return HttpService:JSONEncode({ last = name, savedAt = os.time() })
    end)
    if payloadOk then
        writefile(CONFIG_FILE, payload)
    end
end

local function forgetLastConfigName(name)
    if not name or name == "" then
        return
    end
    local data = readLastConfigMeta()
    if data and data.last == name and isfile and isfile(CONFIG_FILE) then
        delfile(CONFIG_FILE)
    end
end

local function getStoredConfigName()
    local data = readLastConfigMeta()
    if not (data and data.last) then
        return nil
    end
    local path = CONFIG_FOLDER .. "/" .. data.last .. ".json"
    if isfile and isfile(path) then
        return data.last
    end
    return nil
end

local function safeNumber(str, def)    return tonumber(str) or def end
local function isEndToken(str)        return tostring(str):lower()=="end" end

-- For copying text to clipboard (Studio-only or certain browsers)
local Clipboard = setclipboard or function() end

-------------------------------------------------------------------- CONFIG ---
local MAX_GRAPH_SPEED   = 10         -- hard cap for Y-axis (user can still type >10)
local DEFAULT_STIME     = 0
local DEFAULT_ETIME     = 1
local DEFAULT_SSPEED    = 1
local DEFAULT_ESPEED    = 1
-------------------------------------------------------------------------------
local GRAPH_SCALE = MAX_GRAPH_SPEED   -- stays 10 – fixed axis

--------------------------------------------------------------------------------
-- LOCAL PLAYER
--------------------------------------------------------------------------------
local player = Players.LocalPlayer
_G.AllGraphs = _G.AllGraphs or {}

if not isfolder(CONFIG_FOLDER) then
    makefolder(CONFIG_FOLDER)
end

--------------------------------------------------------------------------------
-- CHARACTER -> NAME & COLOR MAPPINGS
--------------------------------------------------------------------------------
local Characters = {
    ["Purple"]  = { Name = "Suiryu",       Color = Color3.fromRGB(128, 0, 128) },
    ["Cyborg"]  = { Name = "Genos",        Color = Color3.fromRGB(255, 69, 0) },
    ["Hunter"]  = { Name = "Garou",        Color = Color3.fromRGB(173, 216, 230) },
    ["Bald"]    = { Name = "Saitama",      Color = Color3.fromRGB(200, 200, 0) },
    ["Esper"]   = { Name = "Tatsumaki",    Color = Color3.fromRGB(57, 255, 20) },
    ["Ninja"]   = { Name = "Sonic",        Color = Color3.fromRGB(216, 191, 216) },
    ["Blade"]   = { Name = "Atomic",       Color = Color3.fromRGB(255, 165, 0) },
    ["Batter"]  = { Name = "MetalBat",     Color = Color3.fromRGB(192, 192, 192) },
    ["KJ"]      = { Name = "KJ",           Color = Color3.fromRGB(138, 3, 3) },
    ["Tech"]    = { Name = "ChildEmperor", Color = Color3.fromRGB(0, 0, 0) },
    ["Monster"] = { Name = "Monster",      Color = Color3.fromRGB(174, 0, 0) },
}
local WEAKEST_DUMMY_COLOR = Color3.fromRGB(139, 69, 19) -- Brown
local FALLBACK_COLOR      = Color3.fromRGB(128, 128, 128)
local FALLBACK_NAME       = "Unknown"

local DOT_SIZE = 20
local HALF_DOT = DOT_SIZE * 3

--------------------------------------------------------------------------------
-- DATA & STATE
--------------------------------------------------------------------------------
-- Our local blacklist: anims that won't show in the log / or can be hidden
-- We'll store a set of IDs so we can add more easily
local animationBlacklist = {
    ["7815618175"] = true, -- run
    ["7807831448"] = true, -- walk
    ["125750702"] = true, -- falljump
    ["180436148"] = true, -- fall
    ["14516273501"] = true, -- stand still
    ["10473655645"] = true, -- hit 1
    ["10473654583"] = true, -- hit 2
    ["10473655082"] = true, -- hit 3
    ["10473653782"] = true, -- hit 4? end(10473655645,10471478869)
    ["180436334"] = true, -- climb
    ["10480793962"] = true, -- rdash
    ["10480796021"] = true, -- ldash
    ["10491993682"] = true, -- backdash
    ["10471478869"] = true, -- backhit (saitama normpunch notblock far away victim)
    ["10479335397"] = true, -- fdash
}
local spawnInterval
local addStep
local loadConfigIntoUI
-- Logs to prevent repeated listings
local logs = {}

-- For hooking humanoid AnimationPlayed
local connectedHumanoids = {}

-- Current target filter in the logger
local currentTargetChoice = "All"
local loggingEnabled = true

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------
local function getAnimationIdFromAssetId(assetId)
    if not assetId then return nil end
    local id = assetId:match("%d+$")
    return id
end

local function getAnimationName(animId)
    local success, result = pcall(function()
        local info = MarketplaceService:GetProductInfo(animId)
        return info.Name or "Unknown"
    end)
    if success then
        return result
    end
    return "Unknown"
end

local function getCharacterAttribute(liveFolderChild)
    if not liveFolderChild then return nil end
    return liveFolderChild:GetAttribute("Character")
end

local function isUltedActive(liveFolderChild)
    if liveFolderChild and liveFolderChild:GetAttribute("Ulted") then
        return true
    end
    return false
end

local startTimeLabel = Instance.new("TextLabel")
local startTimeBox = Instance.new("TextBox")

--------------------------------------------------------------------------------
-- LOGGING ANIMATION PLAY
--------------------------------------------------------------------------------
local function onAnimationPlayedForLogging(animationTrack, liveFolderChild)
	local playerKey = tostring(liveFolderChild:GetAttribute("PlayerId") or liveFolderChild.Name)
    if not loggingEnabled then return end
    if not animationTrack or not animationTrack.Animation then return end
    local assetId = animationTrack.Animation.AnimationId
    local animId = getAnimationIdFromAssetId(assetId)
    if not animId then return end

    if animationBlacklist[animId] then return end



    local attr = getCharacterAttribute(liveFolderChild) or ""
    local cData = Characters[attr]
    local color, displayName

    if liveFolderChild.Name == "Weakest Dummy" then
        color = WEAKEST_DUMMY_COLOR
        displayName = "Weakest Dummy"
    elseif cData then
        color = cData.Color
        displayName = cData.Name
    else
        color = FALLBACK_COLOR
        displayName = FALLBACK_NAME
    end

    local ulted = isUltedActive(liveFolderChild)

    -- Insert into the Log
    if _G.AddToLog then
        _G.AddToLog(animId, getAnimationName(animId), displayName, color, ulted, playerKey, liveFolderChild)
    end
end

--------------------------------------------------------------------------------
-- CONNECTING / DISCONNECTING HUMANOIDS
--------------------------------------------------------------------------------
local function disconnectAll()
    for hum, conn in pairs(connectedHumanoids) do
        if conn then
            conn:Disconnect()
        end
    end
    connectedHumanoids = {}
end

local function connectHumanoid(humanoid, liveFolderChild)
    if not humanoid then return end
    if connectedHumanoids[humanoid] then
        return
    end
    local conn = humanoid.AnimationPlayed:Connect(function(track)
        onAnimationPlayedForLogging(track, liveFolderChild)
    end)
    connectedHumanoids[humanoid] = conn
end

local function getLiveChildrenTargets()
    local live = workspace:FindFirstChild("Live")
    if not live then return {} end
    local results = {}
    for _, child in ipairs(live:GetChildren()) do
        local hum = child:FindFirstChildOfClass("Humanoid")
        if hum then
            table.insert(results, { Obj = child, Name = child.Name, Attr = getCharacterAttribute(child) or "" })
        end
    end
    return results
end

local function reconnectLogging()
    disconnectAll()
    local live = workspace:FindFirstChild("Live")
    if not live then return end

    if currentTargetChoice == "All" then
        for _, child in ipairs(live:GetChildren()) do
            local hum = child:FindFirstChildOfClass("Humanoid")
            if hum then
                connectHumanoid(hum, child)
            end
        end
    else
        -- *** was using attr – change to pKey ***
        for _, child in ipairs(live:GetChildren()) do
            local hum = child:FindFirstChildOfClass("Humanoid")
            if hum then
                local pKey = tostring(child:GetAttribute("PlayerId") or child.Name)
                if pKey == currentTargetChoice then
                    connectHumanoid(hum, child)
                    -- no break if you want to support alt-forms on same player
                end
            end
        end
    end
end


local function onLiveChildAdded(child)
    if currentTargetChoice == "All" then
        local hum = child:FindFirstChildOfClass("Humanoid")
        if hum then
            connectHumanoid(hum, child)
        end
    else
        -- only hook if it belongs to the currently-filtered player
        local pKey = tostring(child:GetAttribute("PlayerId") or child.Name)
        if pKey == currentTargetChoice then
            local hum = child:FindFirstChildOfClass("Humanoid")
            if hum then
                connectHumanoid(hum, child)
            end
        end
    end
end

  
local function rebuildRuntimeTable()
	animationReplacements = {}           -- wipe
	for _, seqData in ipairs(sequenceUIList) do
		if seqData.UnwantedIdBox then 
			local uid = (seqData.UnwantedIdBox.Text:match("%d+")) 
			if uid and uid ~= "" then
				animationReplacements[uid] = animationReplacements[uid] or {}
				local seqObj = {
					name   = seqData.NameBox.Text,
					chance = tonumber(seqData.ChanceBox.Text) or 100,
					steps  = {}
				}
				for _, st in ipairs(seqData.Steps) do
					local durTxt = st.Duration.Text
					local endOnList = {}           -- will hold IDs if they typed "end(id1,id2,...)"
					local numericDur = tonumber(durTxt)
					local isSimpleEnd = false

					-- 1) check for "end(id1,id2,...)"
					local rawList = tostring(durTxt):match("^end%(([%d,]+)%)$")
					if rawList then
						-- split out every numeric ID inside
						for id in rawList:gmatch("%d+") do
							table.insert(endOnList, id)
						end
					else
						-- no parentheses version → maybe the literal string "end"
						isSimpleEnd = (tostring(durTxt):lower() == "end")
					end

					local step = {
						intendedID    = st.AnimationId.Text,
						stepName      = st.StepName.Text,
						startAfter    = tonumber(st.StartAfter.Text) or 0,
						StartTPOS   = tonumber(st.StartTime.Text),

						-- if they wrote exactly "end", we'll stop when the animation itself ends:
						playUntilEnd  = isSimpleEnd,

						-- if they wrote "end(id1,id2,...)", stop when any of those IDs fires:
						endOnList     = endOnList,

						-- if they typed a number (e.g. "3.5"), we'll stop after 3.5 seconds:
						duration      = numericDur,

						intervals     = {}
					}
					for _, iv in ipairs(st.IntervalsData) do
						local eVal = iv.EndTime.Text
						local isEnd = (type(eVal) == "string" and eVal:lower() == "end")
						table.insert(step.intervals, {
							startTime  = tonumber(iv.StartTime.Text)  or 0,
							startSpeed = tonumber(iv.StartSpeed.Text) or 1,
							endSpeed   = tonumber(iv.EndSpeed.Text)   or 1,
							endTime    = isEnd and "end" or tonumber(eVal) or 1
						})
					end
					table.insert(seqObj.steps, step)
				end
				table.insert(animationReplacements[uid], seqObj)
			end
		end
	end
end

local function saveCurrentConfig(configName)
    -- 1) Build an array, pulling data out of sequenceUIList exactly as loadConfigIntoUI expects:
    local dataToSave = {}
    for _, seqData in ipairs(sequenceUIList) do
        local entry = {
            name   = seqData.NameBox.Text or "",
            uid    = seqData.UnwantedIdBox.Text:match("%d+") or "",
            chance = tonumber(seqData.ChanceBox.Text) or 100,
            steps  = {},
        }
        for _, stepObj in ipairs(seqData.Steps or {}) do
			local durTxt = stepObj.Duration.Text or ""
			local rawList = durTxt:match("^end%(([%d,]+)%)$")    -- capture “end(id1,id2,…)” case
			local isSimpleEnd = (durTxt:lower() == "end")

			local singleStep = {
				intendedID   = stepObj.AnimationId.Text or "",
				stepName     = stepObj.StepName.Text or "",
				startAfter   = tonumber(stepObj.StartAfter.Text) or 0,
			    StartTPOS    = tonumber(stepObj.StartTime.Text) or 0,

				-- if they typed “end”, or “end(id1,id2,…)”, record appropriately:
				playUntilEnd = isSimpleEnd,
				endOnList    = {},       -- will fill below if rawList exists
				duration     = tonumber(durTxt),  -- only numeric if not end/endList
				intervals    = {},
			}

			if rawList then
				-- split out the IDs inside the parentheses
				for id in rawList:gmatch("%d+") do
					table.insert(singleStep.endOnList, id)
				end
				singleStep.playUntilEnd = false   -- “end(id1,…)” should not set playUntilEnd
				singleStep.duration = nil         -- we don’t store numeric in that case
			end

			for _, iv in ipairs(stepObj.IntervalsData) do
				local rawE = iv.EndTime.Text or ""
				local isIvEnd = (rawE:lower() == "end")
				table.insert(singleStep.intervals, {
					startTime  = tonumber(iv.StartTime.Text)  or 0,
					startSpeed = tonumber(iv.StartSpeed.Text) or 1,
					endSpeed   = tonumber(iv.EndSpeed.Text)   or 1,
					endTime    = isIvEnd and "end" or (tonumber(rawE) or 1),
				})
			end

			table.insert(entry.steps, singleStep)

        end
        table.insert(dataToSave, entry)
    end

    -- 2) JSON‐encode that array
    local jsonString = HttpService:JSONEncode(dataToSave)
    local configPath = CONFIG_FOLDER .. "/" .. tostring(configName) .. ".json"
    writefile(configPath, jsonString)
    rememberLastConfigName(tostring(configName))
end

local addSequence

local function safeDisconnect(conn)
    if conn and conn.Disconnect then
        pcall(function() conn:Disconnect() end)
    end
end


local scrollFrame
local configPanel
-- (predeclare)
local createConfigButton, listSavedConfigs

listSavedConfigs = function()
    -- 1) Clear “old” entries from configPanel (everything except title, nameBox, saveButton):
    for i = #configPanel:GetChildren(), 1, -1 do
        local child = configPanel:GetChildren()[i]
        if not child:IsA("UIListLayout")
           and not (child:IsA("TextLabel")    and child.Text == "Saved Configs")
           and not (child:IsA("TextBox")      and child.PlaceholderText == "Enter config name")
           and not (child:IsA("TextButton")   and child.Text == "Save Config")
                   and child.Name ~= "ToggleConfigBtn" then
            child:Destroy()
        end
    end

    -- 2) Now enumerate all *.json files:
    local i = 0
    local pointerPath = CONFIG_FILE:gsub("\\", "/")
    for _, fileName in ipairs(listfiles(CONFIG_FOLDER)) do
        local normalized = fileName:gsub("\\", "/")
        if normalized ~= pointerPath and fileName:match("%.json$") then
            i = i + 1
            local configName = fileName:match("([^/]+)%.json$")
            createConfigButton(configName, i)
        end
    end
end

createConfigButton = function(configName, idx)
    local entryFrame = Instance.new("Frame")
    entryFrame.Size        = UDim2.new(1, -10, 0, 30)
    entryFrame.LayoutOrder = idx        -- 📌 use the index we passed in
    entryFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    entryFrame.BorderSizePixel   = 1
    entryFrame.Parent            = configPanel

    -- Name Label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size           = UDim2.new(0.4, 0, 1,  0)
    nameLabel.Position       = UDim2.new(0, 5, 0, 0)
    nameLabel.Text           = configName
    nameLabel.TextColor3     = Color3.new(1, 1, 1)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font           = Enum.Font.SourceSansBold
    nameLabel.TextSize       = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent         = entryFrame

    -- “Load” button
    local loadBtn = Instance.new("TextButton")
    loadBtn.Size            = UDim2.new(0.2, 0, 0.8, 0)
    loadBtn.Position        = UDim2.new(0.4, 5, 0.1, 0)
    loadBtn.Text            = "Load"
    loadBtn.Font            = Enum.Font.SourceSans
    loadBtn.TextSize        = 14
    loadBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    loadBtn.TextColor3      = Color3.new(1, 1, 1)
    loadBtn.Parent          = entryFrame
    loadBtn.ZIndex          = 2

    -- “Overwrite” button
    local overBtn = Instance.new("TextButton")
    overBtn.Size            = UDim2.new(0.2, 0, 0.8, 0)
    overBtn.Position        = UDim2.new(0.6, 5, 0.1, 0)
    overBtn.Text            = "Overwrite"
    overBtn.Font            = Enum.Font.SourceSans
    overBtn.TextSize        = 14
    overBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
    overBtn.TextColor3      = Color3.new(1, 1, 1)
    overBtn.Parent          = entryFrame
    overBtn.ZIndex          = 2

    -- “Delete” button
    local delBtn = Instance.new("TextButton")
    delBtn.Size            = UDim2.new(0.2, 0, 0.8, 0)
    delBtn.Position        = UDim2.new(0.8, 5, 0.1, 0)
    delBtn.Text            = "Delete"
    delBtn.Font            = Enum.Font.SourceSans
    delBtn.TextSize        = 14
    delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    delBtn.TextColor3      = Color3.new(1, 1, 1)
    delBtn.Parent          = entryFrame
    delBtn.ZIndex          = 2

    -- Callbacks:
    loadBtn.MouseButton1Click:Connect(function()
        loadConfigIntoUI(sequenceUIList, configName, scrollFrame)
    end)
    overBtn.MouseButton1Click:Connect(function()
        saveCurrentConfig(configName)
        listSavedConfigs()
    end)
    delBtn.MouseButton1Click:Connect(function()
        local path = CONFIG_FOLDER .. "/" .. configName .. ".json"
        if isfile(path) then
            delfile(path)
        end
        forgetLastConfigName(configName)
        listSavedConfigs()
    end)
end

local function autoloadLatestConfig()
    local latest = getStoredConfigName()
    if not latest then
        return
    end
    task.defer(function()
        loadConfigIntoUI(sequenceUIList, latest, scrollFrame)
    end)
end






--------------------------------------------------------------------------------
-- GUI CREATION
--------------------------------------------------------------------------------
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.ResetOnSpawn = false
    screenGui.Name = "AnimationManagerGUI"
    screenGui.Parent = player:WaitForChild("PlayerGui")
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    ----------------------------------------------------------------
    -- MAIN FRAME
    ----------------------------------------------------------------
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 1100, 0, 900)
    mainFrame.Position = UDim2.new(0.5, -550, 0.5, -450)
    mainFrame.BackgroundColor3 = Color3.fromRGB(50,50,50)
    mainFrame.BorderSizePixel = 2
    mainFrame.Parent = screenGui
    mainFrame.Active = true
    mainFrame.ZIndex = 1


    configPanel = Instance.new("Frame")
    configPanel.Size = UDim2.new(0, 200, 1, 0)  -- Left Panel
	configPanel.Position = UDim2.new(0, -200, 0, 0)
	configPanel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	configPanel.BorderSizePixel = 0
	configPanel.Parent = mainFrame  -- Parent it to the main frame
	configPanel.ZIndex = 5

    local isConfigMinimized = false
    local fullConfigSize     = configPanel.Size
    local fullConfigPos      = configPanel.Position

    -- collapse/expand button (30×30) in top‐right corner of configPanel
    local toggleConfigBtn = Instance.new("TextButton")
    toggleConfigBtn.Size = UDim2.new(0, 30, 0, 30)
    toggleConfigBtn.Position = UDim2.new(1, 0, 0, 2)  -- a couple px inset from top‐right
    toggleConfigBtn.Text = "⇔"
	toggleConfigBtn.Name = "ToggleConfigBtn"
    toggleConfigBtn.Font = Enum.Font.SourceSansBold
    toggleConfigBtn.TextSize = 18
    toggleConfigBtn.BackgroundColor3 = Color3.fromRGB(80,80,80)
    toggleConfigBtn.TextColor3 = Color3.new(1,1,1)
    toggleConfigBtn.ZIndex = 999999
    toggleConfigBtn.Parent = configPanel

    toggleConfigBtn.MouseButton1Click:Connect(function()
        if isConfigMinimized then
            -- expand back to original size/position, show all children
            configPanel:TweenSize(fullConfigSize, "Out", "Quad", 0.2, true)
            configPanel.Position = fullConfigPos
            for _, child in ipairs(configPanel:GetChildren()) do
                if child ~= toggleConfigBtn and not child:IsA("UIListLayout") then
                    child.Visible = true
                end
            end
            isConfigMinimized = false
            toggleConfigBtn.Text = "⇔"
        else
            -- store original, then shrink to 30×30 and hide everything except toggle button
            fullConfigSize = configPanel.Size
            fullConfigPos  = configPanel.Position

            configPanel:TweenSize(UDim2.new(0, 30, 0, 30), "Out", "Quad", 0.2, true)
            configPanel.Position = UDim2.new(1, 0, 0, 2)
            for _, child in ipairs(configPanel:GetChildren()) do
                if child ~= toggleConfigBtn and not child:IsA("UIListLayout") then
                    child.Visible = false
                end
            end
            isConfigMinimized = true
            toggleConfigBtn.Text = "⇔"
        end
    end)

	local configLayout = Instance.new("UIListLayout")
	configLayout.SortOrder = Enum.SortOrder.LayoutOrder
	configLayout.Padding   = UDim.new(0, 5)
	configLayout.Parent    = configPanel

	-- Title for Config Panel
	local configTitle = Instance.new("TextLabel")
	configTitle.Size = UDim2.new(1, 0, 0, 30)
	configTitle.Text = "Saved Configs"
	configTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	configTitle.BackgroundTransparency = 1
	configTitle.Font = Enum.Font.SourceSansBold
	configTitle.TextSize = 18
	configTitle.Parent = configPanel

	-- TextBox to enter Config name
    local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(1, -20, 0, 30)
	nameBox.Position = UDim2.new(0, 10, 0, 50)
	nameBox.PlaceholderText = "Enter config name"
	nameBox.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameBox.Parent = configPanel
        configNameBox = nameBox

	-- Save Config Button
	local saveButton = Instance.new("TextButton")
	saveButton.Size = UDim2.new(1, -20, 0, 30)
	saveButton.Position = UDim2.new(0, 10, 0, 90)
	saveButton.Text = "Save Config"
	saveButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	saveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	saveButton.Parent = configPanel
	saveButton.ZIndex = 999

	saveButton.MouseButton1Click:Connect(function()
		local configName = nameBox.Text
		if configName ~= "" then
			saveCurrentConfig(configName)
			listSavedConfigs()
		end
	end)






    ----------------------------------------------------------------
    -- TOP BAR & WINDOW DRAG
    ----------------------------------------------------------------
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 40)
    topBar.BackgroundColor3 = Color3.fromRGB(70,70,70)
    topBar.Parent = mainFrame
    topBar.ZIndex = 10  -- keep on top

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Text = "Animation Replacement Manager"
    title.Position = UDim2.new(0, 0, 0, 0)
    title.TextColor3 = Color3.new(1,1,1)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 20
    title.Parent = topBar

    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -45, 0, 0)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.new(1,0,0)
    closeButton.BackgroundColor3 = Color3.fromRGB(200,50,50)
    closeButton.BorderSizePixel = 0
    closeButton.Parent = topBar
    closeButton.ZIndex = 11
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Entire UI Minimize/Maximize
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Size = UDim2.new(0, 40, 0, 40)
    minimizeButton.Position = UDim2.new(1, -90, 0, 0)
    minimizeButton.Text = "[-]"
    minimizeButton.TextColor3 = Color3.new(1,1,1)
    minimizeButton.BackgroundColor3 = Color3.fromRGB(100,100,100)
    minimizeButton.BorderSizePixel = 0
    minimizeButton.Parent = topBar
    minimizeButton.ZIndex = toggleConfigBtn.ZIndex + 1

	-- ▼▼ NEW: Live-Replace Toggle
	local liveToggle = Instance.new("TextButton")
	liveToggle.Size = UDim2.new(0, 40, 0, 40)
	liveToggle.Position = UDim2.new(1, -135, 0, 0)  -- 45px left of minimizeButton
	liveToggle.Text = "ON"
	liveToggle.Name = "LiveToggle"
	liveToggle.Font = Enum.Font.SourceSansBold
	liveToggle.TextSize = 18
	liveToggle.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	liveToggle.TextColor3 = Color3.new(1, 1, 1)
	liveToggle.Parent = topBar
	liveToggle.ZIndex = minimizeButton.ZIndex

	local liveEnabled = true
	liveToggle.MouseButton1Click:Connect(function()
		liveEnabled = not liveEnabled
		if liveEnabled then
			liveToggle.Text = "ON"
			liveToggle.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
		else
			liveToggle.Text = "OFF"
			liveToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		end
	end)

    local draggingWindow = false
    local dragOffset = Vector2.new()

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingWindow = true
            dragOffset = UserInputService:GetMouseLocation() - mainFrame.AbsolutePosition
        end
    end)

    topBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingWindow = false
        end
    end)

    RunService.RenderStepped:Connect(function()
        if draggingWindow then
            local mousePos = UserInputService:GetMouseLocation()
            local newPos = mousePos - dragOffset
            mainFrame.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
        end
    end)

    local isMinimized = false
    minimizeButton.MouseButton1Click:Connect(function()
        if isMinimized then
            minimizeButton.Text = "[-]"
            minimizeButton.Position = UDim2.new(1, -90, 0, 0)
            minimizeButton.Size = UDim2.new(0, 40, 0, 40)
            TweenService:Create(mainFrame, TweenInfo.new(0.3), {
                Size=UDim2.new(0,1100,0,900)
            }):Play()
            isMinimized = false
        else
            minimizeButton.Text = "[+]"
            minimizeButton.Size = UDim2.new(1, 0, 0, 40)
            minimizeButton.Position = UDim2.new(0, 0, 0, 0)
            TweenService:Create(mainFrame, TweenInfo.new(0.3), {
                Size=UDim2.new(0,1100,0,40)
            }):Play()
            isMinimized = true
        end
    end)

    ----------------------------------------------------------------
    -- LEFT FRAME (Sequence Editor), MIDDLE FRAME (Logger), RIGHT FRAME (Blacklist)
    ----------------------------------------------------------------
    local leftFrame = Instance.new("Frame")
    leftFrame.Name = "LeftFrame"
    leftFrame.BackgroundColor3 = Color3.fromRGB(40,40,40)
    leftFrame.BorderSizePixel = 2
    leftFrame.Position = UDim2.new(0, 0, 0, 40)
    leftFrame.Size = UDim2.new(0,650,1,-40)
    leftFrame.Parent = mainFrame
    leftFrame.ZIndex = 1

    local loggerFrame = Instance.new("Frame")
    loggerFrame.Name = "LoggerFrame"
    loggerFrame.BackgroundColor3 = Color3.fromRGB(40,40,40)
    loggerFrame.BorderSizePixel = 2
    loggerFrame.Position = UDim2.new(0,650,0,40)
    loggerFrame.Size = UDim2.new(0,300,1,-40)
    loggerFrame.Parent = mainFrame
    loggerFrame.ZIndex = 1

    local blacklistFrame = Instance.new("Frame")
    blacklistFrame.Name = "BlacklistFrame"
    blacklistFrame.BackgroundColor3 = Color3.fromRGB(40,40,40)
    blacklistFrame.BorderSizePixel = 2
    blacklistFrame.Position = UDim2.new(0,950,0,40)
    blacklistFrame.Size = UDim2.new(0,150,1,-40)
    blacklistFrame.Parent = mainFrame
    blacklistFrame.ZIndex = 1

    -- auto-resize helper
    local function resizeColumns()
		local total = mainFrame.Size.X.Offset  -- account for configPanel’s width
		local leftW   = math.floor(total * 0.59)
		local loggerW = math.floor(total * 0.27)
		local blackW  = total - leftW - loggerW
	

        leftFrame.Size          = UDim2.new(0, leftW, 1, -40)
        loggerFrame.Position    = UDim2.new(0, leftW, 0, 40)
        loggerFrame.Size        = UDim2.new(0, loggerW, 1, -40)
        blacklistFrame.Position = UDim2.new(0, leftW + loggerW, 0, 40)
        blacklistFrame.Size     = UDim2.new(0, blackW, 1, -40)
    end
    mainFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeColumns)

    ----------------------------------------------------------------
    -- RESIZER BETWEEN LEFT & LOGGER
    ----------------------------------------------------------------
    local leftLoggerResizer = Instance.new("Frame")
    leftLoggerResizer.Size = UDim2.new(0,5,1,0)
    leftLoggerResizer.Position = UDim2.new(1,0,0,0)
    leftLoggerResizer.AnchorPoint = Vector2.new(1,0)
    leftLoggerResizer.BackgroundColor3 = Color3.fromRGB(80,80,80)
    leftLoggerResizer.BorderSizePixel = 0
    leftLoggerResizer.Parent = leftFrame
    leftLoggerResizer.Active = true
    leftLoggerResizer.ZIndex = 2

    local leftLoggerLabel = Instance.new("TextLabel")
    leftLoggerLabel.Size = UDim2.new(1,0,0,30)
    leftLoggerLabel.Position = UDim2.new(0,0,0.5,-15)
    leftLoggerLabel.BackgroundTransparency = 1
    leftLoggerLabel.TextColor3 = Color3.new(1,1,1)
    leftLoggerLabel.Text = "<=>"
    leftLoggerLabel.TextScaled = true
    leftLoggerLabel.Parent = leftLoggerResizer

    local resizingLeftLogger = false
    local leftLoggerStartSize
    local leftLoggerDragStartX

    leftLoggerResizer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizingLeftLogger = true
            leftLoggerStartSize = leftFrame.Size
            leftLoggerDragStartX = UserInputService:GetMouseLocation().X
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizingLeftLogger = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if resizingLeftLogger and input.UserInputType == Enum.UserInputType.MouseMovement then
            local totalWidth = mainFrame.Size.X.Offset
            local currentX   = UserInputService:GetMouseLocation().X
            local deltaX     = currentX - leftLoggerDragStartX
            local newLeftW   = math.clamp(leftLoggerStartSize.X.Offset + deltaX, 200, totalWidth - 300)

            leftFrame.Size = UDim2.new(0, newLeftW, 1, -40)
            resizeColumns()
        end
    end)

    ----------------------------------------------------------------
    -- RESIZER BETWEEN LOGGER & BLACKLIST
    ----------------------------------------------------------------
    local loggerBlacklistResizer = Instance.new("Frame")
    loggerBlacklistResizer.Size = UDim2.new(0,5,1,0)
    loggerBlacklistResizer.Position = UDim2.new(1,0,0,0)
    loggerBlacklistResizer.AnchorPoint = Vector2.new(1,0)
    loggerBlacklistResizer.BackgroundColor3 = Color3.fromRGB(80,80,80)
    loggerBlacklistResizer.BorderSizePixel = 0
    loggerBlacklistResizer.Parent = loggerFrame
    loggerBlacklistResizer.Active = true
    loggerBlacklistResizer.ZIndex = 2

    local loggerBlackLabel = Instance.new("TextLabel")
    loggerBlackLabel.Size = UDim2.new(1,0,0,30)
    loggerBlackLabel.Position = UDim2.new(0,0,0.5,-15)
    loggerBlackLabel.BackgroundTransparency = 1
    loggerBlackLabel.TextColor3 = Color3.new(1,1,1)
    loggerBlackLabel.Text = "<=>"
    loggerBlackLabel.TextScaled = true
    loggerBlackLabel.Parent = loggerBlacklistResizer

    local resizingLoggerBlack = false
    local loggerBlackStartLoggerSize
    local loggerBlackDragStartX

    loggerBlacklistResizer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizingLoggerBlack = true
            loggerBlackStartLoggerSize = loggerFrame.Size
            loggerBlackDragStartX = UserInputService:GetMouseLocation().X
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizingLoggerBlack = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if resizingLoggerBlack and input.UserInputType == Enum.UserInputType.MouseMovement then
            local totalWidth = mainFrame.Size.X.Offset
            local currentX   = UserInputService:GetMouseLocation().X
            local deltaX     = currentX - loggerBlackDragStartX
            local newLoggerW = math.clamp(loggerBlackStartLoggerSize.X.Offset + deltaX,
                                        200, totalWidth - leftFrame.Size.X.Offset - 100)

            loggerFrame.Size = UDim2.new(0, newLoggerW, 1, -40)
            resizeColumns()
        end
    end)

    ----------------------------------------------------------------
    -- RESIZER ON THE RIGHT EDGE OF THE BLACKLIST
    ----------------------------------------------------------------
    local blacklistRightResizer = Instance.new("Frame")
    blacklistRightResizer.Size = UDim2.new(0,5,1,0)
    blacklistRightResizer.Position = UDim2.new(1,0,0,0)
    blacklistRightResizer.AnchorPoint = Vector2.new(1,0)
    blacklistRightResizer.BackgroundColor3 = Color3.fromRGB(80,80,80)
    blacklistRightResizer.BorderSizePixel = 0
    blacklistRightResizer.Parent = blacklistFrame
    blacklistRightResizer.Active = true
    blacklistRightResizer.ZIndex = 2

    local blackRightLabel = Instance.new("TextLabel")
    blackRightLabel.Size = UDim2.new(1,0,0,30)
    blackRightLabel.Position = UDim2.new(0,0,0.5,-15)
    blackRightLabel.BackgroundTransparency = 1
    blackRightLabel.TextColor3 = Color3.new(1,1,1)
    blackRightLabel.Text = "<=>"
    blackRightLabel.TextScaled = true
    blackRightLabel.Parent = blacklistRightResizer

    local resizingBlacklistRight = false
    local blackRightStartWidth
    local blackRightDragStartX

    blacklistRightResizer.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizingBlacklistRight = true
            blackRightStartWidth = blacklistFrame.Size
            blackRightDragStartX = UserInputService:GetMouseLocation().X
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizingBlacklistRight = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizingBlacklistRight and input.UserInputType == Enum.UserInputType.MouseMovement then
            local currentX = UserInputService:GetMouseLocation().X
            local deltaX = currentX - blackRightDragStartX
            local newWidth = math.clamp(blackRightStartWidth.X.Offset + deltaX, 100, 1200)
            blacklistFrame.Size = UDim2.new(0,newWidth,1,-40)
            mainFrame.Size = UDim2.new(0, leftFrame.Size.X.Offset + loggerFrame.Size.X.Offset + newWidth, 0, 900)
            resizeColumns()
        end
    end)

    ----------------------------------------------------------------
    -- SEQUENCE EDITOR CONTENT (LEFT)
    ----------------------------------------------------------------

    scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -10)
    scrollFrame.Position = UDim2.new(0, 5, 0, 5)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 12
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0,0,0,0)
    scrollFrame.Parent = leftFrame
    scrollFrame.ZIndex = 1
	local extra = Instance.new("UIPadding")
	extra.Parent = scrollFrame
	extra.PaddingBottom = UDim.new(0, 1500)

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0,10)
    layout.Parent = scrollFrame

    ----------------------------------------------------------------
    -- LOGGER CONTENT (MIDDLE)
    ----------------------------------------------------------------
    local loggerTitleBar = Instance.new("Frame")
    loggerTitleBar.Size = UDim2.new(1, 0, 0, 30)
    loggerTitleBar.BackgroundColor3 = Color3.fromRGB(70,70,70)
    loggerTitleBar.Parent = loggerFrame
    loggerTitleBar.ZIndex = 1

    local loggerLabel = Instance.new("TextLabel")
    loggerLabel.Size = UDim2.new(1, -5, 1, 0)
    loggerLabel.Position = UDim2.new(0, 5, 0, 0)
    loggerLabel.Text = "Animation Log"
    loggerLabel.Font = Enum.Font.SourceSansBold
    loggerLabel.TextSize = 16
    loggerLabel.TextColor3 = Color3.new(1,1,1)
    loggerLabel.BackgroundTransparency = 1
    loggerLabel.Parent = loggerTitleBar
    loggerLabel.ZIndex = 2

    local loggerContent = Instance.new("Frame")
    loggerContent.Size = UDim2.new(1,0,1,-30)
    loggerContent.Position = UDim2.new(0,0,0,30)
    loggerContent.BackgroundTransparency = 1
    loggerContent.Parent = loggerFrame
    loggerContent.ZIndex = 1

    local loggerScrollFrame = Instance.new("ScrollingFrame")
    loggerScrollFrame.Size = UDim2.new(1, -20, 1, -40)
    loggerScrollFrame.Position = UDim2.new(0, 10, 0, 10)
    loggerScrollFrame.BackgroundTransparency = 1
    loggerScrollFrame.BorderSizePixel = 0
    loggerScrollFrame.ScrollBarThickness = 8
    loggerScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    loggerScrollFrame.CanvasSize = UDim2.new(0,0,0,0)
    loggerScrollFrame.Parent = loggerContent
    loggerScrollFrame.ZIndex = 1

    ------------------------------------------------------------
    -- STOP / START LOGGING BUTTON
    ------------------------------------------------------------
    local stopBtn = Instance.new("TextButton")
    stopBtn.Size  = UDim2.new(1,-20,0,30)
    stopBtn.Position = UDim2.new(0,10,1,30)
    stopBtn.Text  = "STOP"
    stopBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
    stopBtn.TextColor3 = Color3.new(1,1,1)
    stopBtn.Parent = loggerFrame
    stopBtn.ZIndex = 2

    stopBtn.MouseButton1Click:Connect(function()
        loggingEnabled = not loggingEnabled
        stopBtn.Text   = loggingEnabled and "STOP" or "START"
        stopBtn.BackgroundColor3 = loggingEnabled
            and Color3.fromRGB(200,50,50) or Color3.fromRGB(50,200,50)
        filterLogs()
    end)

    ------------------------------------------------------------
    -- CLEAR LOG BUTTON
    ------------------------------------------------------------
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size  = UDim2.new(1,-20,0,30)
    clearBtn.Position = UDim2.new(0,10,1,0)
    clearBtn.Text  = "CLEAR"
    clearBtn.BackgroundColor3 = Color3.fromRGB(50,50,200)
    clearBtn.TextColor3 = Color3.new(1,1,1)
    clearBtn.Parent = loggerFrame
    clearBtn.ZIndex = 2

    clearBtn.MouseButton1Click:Connect(function()
        -- Clear all log entries
        for _, child in ipairs(loggerScrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        logs = {}
    end)

    local loggerLayout = Instance.new("UIListLayout")
    loggerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    loggerLayout.Parent = loggerScrollFrame

    -- Dropdown for "All" or specific targets (color-coded)
    local targetDropdown = Instance.new("TextButton")
    targetDropdown.Size = UDim2.new(0, 200, 0, 30)
    targetDropdown.Position = UDim2.new(0, 10, 0, 0)
    targetDropdown.Text = "All"
    targetDropdown.BackgroundColor3 = Color3.fromRGB(100,100,100)
    targetDropdown.TextColor3 = Color3.new(1,1,1)
    targetDropdown.Parent = loggerTitleBar
    targetDropdown.ZIndex = 2

    local dropdownFrame = Instance.new("Frame")
    dropdownFrame.Size = UDim2.new(0,200,0,0)
    dropdownFrame.Position = UDim2.new(0,10,0,30)
    dropdownFrame.BackgroundColor3 = Color3.fromRGB(60,60,60)
    dropdownFrame.BorderSizePixel = 2
    dropdownFrame.Visible = false
    dropdownFrame.Parent = loggerFrame
    dropdownFrame.ZIndex = 2

    local dropLayout = Instance.new("UIListLayout")
    dropLayout.SortOrder = Enum.SortOrder.LayoutOrder
    dropLayout.Parent = dropdownFrame

    local function makeChoiceButton(text, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 20)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 14
        b.Text = text
        b.Parent = dropdownFrame
        return b
    end

    local function refreshDropdown()
        for _, child in ipairs(dropdownFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        -- "All"
        local bAll = makeChoiceButton("All", Color3.fromRGB(100,100,100))
        bAll.MouseButton1Click:Connect(function()
            dropdownFrame.Visible = false
            targetDropdown.Text = "All"
            currentTargetChoice = "All"
            reconnectLogging()
            filterLogs()
        end)

		local listed = {}
		for _, itm in ipairs(getLiveChildrenTargets()) do
			local pKey = tostring(itm.Obj:GetAttribute("PlayerId") or itm.Name)
			if not listed[pKey] then
				listed[pKey] = true

				--------------------------------------------------------
				-- figure out the character that player is using NOW
				--------------------------------------------------------
				local attr      = itm.Attr                      -- “Cyborg”, “Hunter”, …
				local cData     = Characters[attr]
				local charName  = (cData and cData.Name)  or FALLBACK_NAME
				local btnColour
				if itm.Name == "Weakest Dummy" then
					btnColour = WEAKEST_DUMMY_COLOR
				elseif cData then
					btnColour = cData.Color
				else
					btnColour = FALLBACK_COLOR
				end

				--------------------------------------------------------
				-- build label:  PlayerName (Character)
				--------------------------------------------------------
				local labelText = string.format("%s  (%s)", pKey, charName)

				local btn = makeChoiceButton(labelText, btnColour)
				btn.MouseButton1Click:Connect(function()
					dropdownFrame.Visible = false
					currentTargetChoice   = pKey          -- we filter by player key
					targetDropdown.Text   = labelText
					reconnectLogging()
					filterLogs()
				end)
			end
		end


        -- auto-resize
        local count = 0
        for _, c in ipairs(dropdownFrame:GetChildren()) do
            if c:IsA("TextButton") then
                count += 1
            end
        end
        dropdownFrame.Size = UDim2.new(0,200,0,20*count)
    end

    targetDropdown.MouseButton1Click:Connect(function()
        if dropdownFrame.Visible then
            dropdownFrame.Visible = false
        else
            refreshDropdown()
            dropdownFrame.Visible = true
        end
    end)

    ----------------------------------------------------------------
    -- BLACKLIST CONTENT (RIGHT)
    ----------------------------------------------------------------
    local blacklistLabel = Instance.new("TextLabel")
    blacklistLabel.Size = UDim2.new(1, -5, 0, 30)
    blacklistLabel.Position = UDim2.new(0,5,0,0)
    blacklistLabel.Text = "Blacklist"
    blacklistLabel.Font = Enum.Font.SourceSansBold
    blacklistLabel.TextSize = 16
    blacklistLabel.TextColor3 = Color3.new(1,1,1)
    blacklistLabel.BackgroundTransparency = 1
    blacklistLabel.Parent = blacklistFrame
    blacklistLabel.ZIndex = 1

    local blacklistScrollFrame = Instance.new("ScrollingFrame")
    blacklistScrollFrame.Size = UDim2.new(1, -10, 1, -40)
    blacklistScrollFrame.Position = UDim2.new(0,5,0,30)
    blacklistScrollFrame.BackgroundTransparency = 1
    blacklistScrollFrame.ScrollBarThickness = 8
    blacklistScrollFrame.CanvasSize = UDim2.new(0,0,0,0)
    blacklistScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    blacklistScrollFrame.Parent = blacklistFrame
    blacklistScrollFrame.ZIndex = 1

    local blacklistLayout = Instance.new("UIListLayout")
    blacklistLayout.SortOrder = Enum.SortOrder.LayoutOrder
    blacklistLayout.Parent = blacklistScrollFrame

    local function showBlacklistItem(animId, animName, charName)
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, -10, 0, 30)
        itemFrame.BackgroundColor3 = Color3.fromRGB(80,80,80)
        itemFrame.BorderSizePixel = 1
        itemFrame.LayoutOrder = 0
        itemFrame.Parent = blacklistScrollFrame
        itemFrame.ZIndex = 1

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -40, 1, 0)
        label.Position = UDim2.new(0,5,0,0)
        label.Text = "ID: "..animId.." | "..(animName or "?")
        label.TextColor3 = Color3.new(1,1,1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.SourceSans
        label.TextSize = 14
        label.TextWrapped = true
        label.Parent = itemFrame

        local plusButton = Instance.new("TextButton")
        plusButton.Size = UDim2.new(0,30,0,30)
        plusButton.Position = UDim2.new(1,-35,0,0)
        plusButton.Text = "+"
        plusButton.TextColor3 = Color3.new(1,1,1)
        plusButton.BackgroundColor3 = Color3.fromRGB(50,200,50)
        plusButton.Parent = itemFrame
        plusButton.ZIndex = 2

        plusButton.MouseButton1Click:Connect(function()
            animationBlacklist[animId] = nil
            itemFrame:Destroy()
        end)
    end

    local function addToBlacklist(animId, animName, charName)
        animationBlacklist[animId] = true
        showBlacklistItem(animId, animName, charName)
    end

    for defaultId, _ in pairs(animationBlacklist) do
       -- skip remote lookup; display ID immediately
        addToBlacklist(defaultId, defaultId, "")
    end

    ----------------------------------------------------------------
    -- GLOBAL: ADD TO LOG
    ----------------------------------------------------------------
	_G.AddToLog = function(animId, animName, charName, color, ulted, playerKey, charRef)
		logs[animId] = logs[animId] or {}
		if logs[animId][playerKey] or animationBlacklist[animId] then return end
		logs[animId][playerKey] = true     
		local attrId = getCharacterAttribute(charRef) or ""

        local logFrame = Instance.new("Frame")
        logFrame.Size = UDim2.new(1, -10, 0, 50)
        logFrame.BackgroundColor3 = Color3.fromRGB(80,80,80)
        logFrame.BorderSizePixel = 1
        logFrame.LayoutOrder = 0
        logFrame.Parent = loggerScrollFrame
        logFrame.ZIndex = 1
        logFrame:SetAttribute("TargetPlayer", playerKey)

        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(0, 140, 1, 0)
        infoLabel.Position = UDim2.new(0, -14, 0, 0)
        infoLabel.BackgroundTransparency = 1
        infoLabel.Font = Enum.Font.SourceSans
        infoLabel.TextSize = 12
        infoLabel.TextColor3 = Color3.new(1,1,1)
        infoLabel.Text = "Id: "..animId.."\n"..animName
        infoLabel.TextWrapped = true
        infoLabel.Parent = logFrame
        infoLabel.ZIndex = 1

        local playButton = Instance.new("TextButton")
        playButton.Size = UDim2.new(0, 100, 0, 25)
        playButton.Position = UDim2.new(0, 105, 0, 5)
        playButton.Text = "Play ["..charName.."]"
        playButton.BackgroundColor3 = color
        playButton.TextColor3 = Color3.new(1,1,1)
        playButton.Parent = logFrame
        playButton.ZIndex = 1

        if ulted and charName ~= "Weakest Dummy" then
            local ultLabel = Instance.new("TextLabel")
            ultLabel.Size = UDim2.new(0, 20, 0, 20)
            ultLabel.Position = UDim2.new(0, 0, 0, 5)
            ultLabel.BackgroundTransparency = 1
            ultLabel.Font = Enum.Font.SourceSansBold
            ultLabel.TextSize = 16
            ultLabel.TextColor3 = Color3.new(1,0,0)
            ultLabel.Text = "✓"
            ultLabel.Parent = logFrame
            ultLabel.ZIndex = 9
        end

        local copyButton = Instance.new("TextButton")
        copyButton.Size = UDim2.new(0,40,0,25)
        copyButton.Position = UDim2.new(1, -70, 0, 5)
        copyButton.Text = "Copy"
        copyButton.BackgroundColor3 = Color3.fromRGB(200,200,50)
        copyButton.TextColor3 = Color3.new(0,0,0)
        copyButton.Parent = logFrame
        copyButton.ZIndex = 1

        local minusButton = Instance.new("TextButton")
        minusButton.Size = UDim2.new(0,30,0,25)
        minusButton.Position = UDim2.new(1, -30, 0, 5)
        minusButton.Text = "[-]"
        minusButton.BackgroundColor3 = Color3.fromRGB(200,50,50)
        minusButton.TextColor3 = Color3.new(1,1,1)
        minusButton.Parent = logFrame
        minusButton.ZIndex = 1

        playButton.MouseButton1Click:Connect(function()
            local myChar = player.Character
            if myChar then
                local hum = myChar:FindFirstChildOfClass("Humanoid")
                if hum then
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if animator then
                        -- Stop old tracks
                        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                            track:Stop()
                        end
                        local newAnim = Instance.new("Animation")
                        newAnim.AnimationId = "rbxassetid://"..animId
						local track = animator:LoadAnimation(newAnim)
						track.Looped = false
						track:Play()
                    end
                end
            end
        end)

        copyButton.MouseButton1Click:Connect(function()
            Clipboard(animId)
        end)

        minusButton.MouseButton1Click:Connect(function()
            addToBlacklist(animId, animName, charName)
            logs[animId][playerKey] = nil
            logFrame:Destroy()
        end)
        filterLogs()  
    end

	function filterLogs()
		for _, child in ipairs(loggerScrollFrame:GetChildren()) do
			if child:IsA("Frame") then
				local pKey = child:GetAttribute("TargetPlayer")
				child.Visible = (currentTargetChoice == "All") or (pKey == currentTargetChoice)
			end
		end
	end

    ----------------------------------------------------------------
    -- PLAY A SEQUENCE (all steps in order)
    ----------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- PLAY A SEQUENCE (all steps fire at exactly `step.startAfter` seconds)
	--   • Each step is scheduled independently relative to the moment `playSequence` is called.
	--   • If two steps “overlap,” they run concurrently.
	--   • `step.startTime` is still the time‐offset *within* the animation.
	--   • `step.playUntilEnd` or `step.duration` stops that track after the correct amount of time.
	--------------------------------------------------------------------------------

	local function playSequence(sequence, animator)
		local cancel = false
		local tracks = {}
		local allEndIds = {}
		for _, step in ipairs(sequence.steps or {}) do
			if step.endOnList then
				for _, id in ipairs(step.endOnList) do
					allEndIds[tostring(id)] = true
				end
			end
		end

		local stopConn
		stopConn = animator.AnimationPlayed:Connect(function(otherTrack)
			if not otherTrack.Animation then return end
			local otherID = otherTrack.Animation.AnimationId:match("%d+$")
			if otherID and allEndIds[otherID] then
				cancel = true
				for _, t in ipairs(tracks) do
					if t.IsPlaying then
						t:Stop()
					end
				end
				stopConn:Disconnect()
			end
		end)

		for _, step in ipairs(sequence.steps or {}) do
			coroutine.wrap(function()
				if cancel then return end

				if step.startAfter and step.startAfter > 0 then
					local elapsed = 0
					while elapsed < step.startAfter do
						if cancel then return end
						local dt = RunService.Heartbeat:Wait()
						elapsed = elapsed + dt
					end
				end
				if cancel then return end

				local newAnim = Instance.new("Animation")
				newAnim.AnimationId = "rbxassetid://" .. step.intendedID
				local track = animator:LoadAnimation(newAnim)
				track.Looped = false
				
				track:Play()
				track.TimePosition = tonumber(step.StartTPOS) or 0

				if step.StartTPOS and step.StartTPOS > 0 and step.intervals and #step.intervals > 0 then
					track:AdjustSpeed(step.intervals[1].startSpeed or 1) 
				elseif step.intervals and #step.intervals > 0 then
					track:AdjustSpeed(step.intervals[1].startSpeed or 1)
				end
				table.insert(tracks, track)

				if step.intervals and #step.intervals > 0 then
					coroutine.wrap(function()
						for _, iv in ipairs(step.intervals) do
							local st   = iv.startTime   or 0
							local sspd = iv.startSpeed  or 1
							local espd = iv.endSpeed    or sspd
							local eT   = iv.endTime
							if type(eT) == "string" and eT:lower() == "end" then
								eT = (track.Length and track.Length > 0) and track.Length or (st + 1)
							end
							eT = tonumber(eT) or (st + 1)

							while not cancel and track.IsPlaying and track.TimePosition < st do
								RunService.Heartbeat:Wait()
							end
							while not cancel and track.IsPlaying and track.TimePosition < eT do
								local frac = math.clamp((track.TimePosition - st) / (eT - st), 0, 1)
								track:AdjustSpeed(sspd + (espd - sspd) * frac)
								RunService.Heartbeat:Wait()
							end
							if cancel then return end
							if track.IsPlaying then
								track:AdjustSpeed(1)
							end
						end
					end)()
				end

				if step.duration and step.duration > 0 then
					task.delay(step.duration, function()
						if track and track.IsPlaying then
							track:Stop()
						end
					end)
					while not cancel and track and track.IsPlaying do
						RunService.Heartbeat:Wait()
					end
				end
			end)()
		end
	end

    ----------------------------------------------------------------
    -- MAIN ON ANIMATION PLAYED: play replacements
    ----------------------------------------------------------------
	local function onAnimationPlayed(animationTrack, animator)
		if not animationTrack.Animation then return end
		if not liveEnabled then return end 
		local unwantedID = animationTrack.Animation.AnimationId:match("%d+$")
		if not unwantedID then return end

		local sequences = animationReplacements[unwantedID]
		if not sequences then return end

		animationTrack:AdjustSpeed(0)
		animationTrack:Stop()

		-- weighted pick
		local totalChance = 0
		for _, seq in ipairs(sequences) do
			totalChance = totalChance + (seq.chance or 0)
		end
		if totalChance == 0 then
			totalChance = #sequences
			for _, seq in ipairs(sequences) do
				seq.chance = 1
			end
		end

		local pick = math.random(1, totalChance)
		local cum = 0
		local selected
		for _, seq in ipairs(sequences) do
			cum = cum + (seq.chance or 0)
			if pick <= cum then
				selected = seq
				break
			end
		end
		if selected then
			playSequence(selected, animator, unwantedID, animationTrack.Stopped)
		end
	end

    ----------------------------------------------------------------
    -- SEQUENCE EDITOR GUI
    ----------------------------------------------------------------
    local function updateStepsOrder(seqData)
        for i, st in ipairs(seqData.Steps) do
            st.StepFrame.LayoutOrder = i
            st.StepHeader.Text = "Stp "..i
        end
    end
    addStep = function(seqData, stepsContainer)
        local stepData = {
            AnimationId   = nil,
            StepName      = nil,
            StartTime     = nil,
            Duration      = nil,
            IntervalsData = {}
        }

        table.insert(seqData.Steps, stepData)
		stepData.__connections = {}
		local function hook(box)
			table.insert(stepData.__connections, box.FocusLost:Connect(rebuildRuntimeTable))
			table.insert(stepData.__connections, box:GetPropertyChangedSignal("Text"):Connect(rebuildRuntimeTable))
		end
        local stepFrame = Instance.new("Frame")
        stepFrame.Size = UDim2.new(1,0,0,0)
        stepFrame.AutomaticSize = Enum.AutomaticSize.Y
        stepFrame.BackgroundColor3 = Color3.fromRGB(70,70,70)
        stepFrame.BorderSizePixel = 2
        stepFrame.Parent = stepsContainer
        stepData.StepFrame = stepFrame
        stepFrame.ZIndex = 1

        local whiteSep = Instance.new("Frame")
        whiteSep.Size = UDim2.new(1,0,0,2)
        whiteSep.Position = UDim2.new(0,0,1,5)
        whiteSep.BackgroundColor3 = Color3.new(1,1,1)
        whiteSep.AnchorPoint = Vector2.new(0.5,0)
        whiteSep.Parent = stepFrame

        local stepHeader = Instance.new("TextLabel")
        stepHeader.Size = UDim2.new(1, -150, 0, 25)
        stepHeader.Text = "Stp "..(#seqData.Steps)
        stepHeader.TextColor3 = Color3.new(1,1,1)
        stepHeader.BackgroundColor3 = Color3.fromRGB(90,90,90)
        stepHeader.Font = Enum.Font.SourceSansBold
        stepHeader.TextSize = 14
        stepHeader.Parent = stepFrame
        stepData.StepHeader = stepHeader
        stepHeader.ZIndex = 1

        local removeStep = Instance.new("TextButton")
        removeStep.Size = UDim2.new(0,80,0,25)
        removeStep.Position = UDim2.new(1,-90,0,0)
        removeStep.Text = "Rem"
        removeStep.BackgroundColor3 = Color3.fromRGB(200,50,50)
        removeStep.TextColor3 = Color3.new(1,1,1)
        removeStep.Font = Enum.Font.SourceSansBold
        removeStep.TextSize = 14
        removeStep.Parent = stepFrame
        removeStep.ZIndex = 1

        removeStep.MouseButton1Click:Connect(function()
            local idx = table.find(seqData.Steps, stepData)
            if idx then
                table.remove(seqData.Steps, idx)
            end
						
			for _, c in ipairs(stepData.__connections or {}) do
				safeDisconnect(c)
			end
            stepFrame:Destroy()
            updateStepsOrder(seqData)
			rebuildRuntimeTable()
        end)

        local stepNameLabel = Instance.new("TextLabel")
        stepNameLabel.Size = UDim2.new(0,80,0,25)
        stepNameLabel.Position = UDim2.new(0,10,0,30)
        stepNameLabel.Text = "Name:"
        stepNameLabel.TextColor3 = Color3.new(1,1,1)
        stepNameLabel.BackgroundTransparency = 1
        stepNameLabel.Font = Enum.Font.SourceSans
        stepNameLabel.TextSize = 14
        stepNameLabel.Parent = stepFrame
        stepNameLabel.ZIndex = 1

        local stepNameBox = Instance.new("TextBox")
        stepNameBox.Size = UDim2.new(0,160,0,25)
        stepNameBox.Position = UDim2.new(0,100,0,30)
        stepNameBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
        stepNameBox.TextColor3 = Color3.new(1,1,1)
        stepNameBox.PlaceholderText = "StepName"
        stepNameBox.Parent = stepFrame
        stepNameBox.ZIndex = 1
        stepData.StepName = stepNameBox
		hook(stepNameBox) 
        local animIdLabel = Instance.new("TextLabel")
        animIdLabel.Size = UDim2.new(0,80,0,25)
        animIdLabel.Position = UDim2.new(0,10,0,60)
        animIdLabel.Text = "Anim ID:"
        animIdLabel.TextColor3 = Color3.new(1,1,1)
        animIdLabel.BackgroundTransparency = 1
        animIdLabel.Font = Enum.Font.SourceSans
        animIdLabel.TextSize = 14
        animIdLabel.Parent = stepFrame
        animIdLabel.ZIndex = 1

		local KSP = game:GetService("KeyframeSequenceProvider")

        local animIdBox = Instance.new("TextBox")
        animIdBox.Size = UDim2.new(0,160,0,25)
        animIdBox.Position = UDim2.new(0,100,0,60)
        animIdBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
        animIdBox.TextColor3 = Color3.new(1,1,1)
        animIdBox.PlaceholderText = "Anim ID"
        animIdBox.Parent = stepFrame
        animIdBox.ZIndex = 1
        stepData.AnimationId = animIdBox
		hook(animIdBox) 

		local lenLabel = Instance.new("TextLabel")
		lenLabel.Size            = UDim2.new(0, 60, 0, 25)
		lenLabel.Position        = UDim2.new(0, 270, 0, 60)
		lenLabel.BackgroundColor3= Color3.fromRGB(30,120,30)
		lenLabel.TextColor3      = Color3.new(1,1,1)
		lenLabel.Font            = Enum.Font.SourceSans
		lenLabel.TextSize        = 14
		lenLabel.Text            = ""        -- filled on lookup
		lenLabel.Parent          = stepFrame
		stepData.LenLabel = lenLabel

        -- “Start” (time into the animation)
        local startTimeLabel = Instance.new("TextLabel")
        startTimeLabel.Size = UDim2.new(0,80,0,25)
        startTimeLabel.Position = UDim2.new(0,10,0,90)
        startTimeLabel.Text = "StartTPOS:"
        startTimeLabel.TextColor3 = Color3.new(1,1,1)
        startTimeLabel.BackgroundTransparency = 1
        startTimeLabel.Font = Enum.Font.SourceSans
        startTimeLabel.TextSize = 14
        startTimeLabel.Parent = stepFrame

        local startTimeBox = Instance.new("TextBox")
        startTimeBox.Size = UDim2.new(0,160,0,25)
        startTimeBox.Position = UDim2.new(0,100,0,90)
        startTimeBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
        startTimeBox.TextColor3 = Color3.new(1,1,1)
        startTimeBox.PlaceholderText = "0"
        startTimeBox.Parent = stepFrame
        stepData.StartTime = startTimeBox
        hook(startTimeBox)

        -- ↪ “StartAfter” (wait after unwanted ID fires), placed to the right of “Start:”
        local startAfterLabel = Instance.new("TextLabel")
        startAfterLabel.Size = UDim2.new(0,80,0,25)
        --    ^ keep Y = 90 so it lines up with “Start:”
        startAfterLabel.Position = UDim2.new(0,280,0,90)
        startAfterLabel.Text = "StartAfter:"
        startAfterLabel.TextColor3 = Color3.new(1,1,1)
        startAfterLabel.BackgroundTransparency = 1
        startAfterLabel.Font = Enum.Font.SourceSans
        startAfterLabel.TextSize = 14
        startAfterLabel.Parent = stepFrame

        local startAfterBox = Instance.new("TextBox")
        startAfterBox.Size = UDim2.new(0,60,0,25)
        --    ^ narrower so it doesn’t push Duration too far
        startAfterBox.Position = UDim2.new(0,370,0,90)
        startAfterBox.PlaceholderText = "0"
        startAfterBox.Text = "0"
        startAfterBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
        startAfterBox.TextColor3 = Color3.new(1,1,1)
        startAfterBox.Parent = stepFrame
        stepData.StartAfter = startAfterBox
        hook(startAfterBox)

        -- “Duration” stays at its original Y (120), since we didn’t push anything down
        local durationLabel = Instance.new("TextLabel")
        durationLabel.Size = UDim2.new(0,80,0,25)
        durationLabel.Position = UDim2.new(0,10,0,120)
        durationLabel.Text = "Dur:"
        durationLabel.TextColor3 = Color3.new(1,1,1)
        durationLabel.BackgroundTransparency = 1
        durationLabel.Font = Enum.Font.SourceSans
        durationLabel.TextSize = 14
        durationLabel.Parent = stepFrame

        local durationBox = Instance.new("TextBox")
        durationBox.Size = UDim2.new(0,160,0,25)
        durationBox.Position = UDim2.new(0,100,0,120)
        durationBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
        durationBox.TextColor3 = Color3.new(1,1,1)
        durationBox.PlaceholderText = "'X' or 'end'"
        durationBox.Parent = stepFrame
        stepData.Duration = durationBox
        hook(durationBox)


		animIdBox.FocusLost:Connect(function(enter)
			if not enter then return end
			local id = animIdBox.Text:match("%d+")
			if not id then return end

			-- wrap the call in a function so pcall can catch errors
			local ok, seq = pcall(function()
				return KSP:GetKeyframeSequenceAsync("rbxassetid://"..id)
			end)

			if ok and seq then
				local kfs = seq:GetKeyframes()
				local len = (#kfs > 0) and kfs[#kfs].Time or nil
				if len then
					lenLabel.Text = string.format("%.2f", len)
				end
			end
			rebuildRuntimeTable()
		end)

        local graphFrame = Instance.new("Frame")
        graphFrame.Name = "GraphFrame"
        graphFrame.Size = UDim2.new(1,-20,0,100)
        graphFrame.Position = UDim2.new(0,10,0,160)
        graphFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
        graphFrame.BorderSizePixel = 1
        graphFrame.Parent = stepFrame
        graphFrame.ZIndex = 1
        stepData.GraphFrame = graphFrame

        local intervalsContainer = Instance.new("Frame")
        intervalsContainer.Name = "IntervalsContainer"
        intervalsContainer.Size = UDim2.new(1,-20,0,100)
        intervalsContainer.Position = UDim2.new(0,10,0,270)
        intervalsContainer.BackgroundTransparency = 1
        intervalsContainer.ClipsDescendants = false
        intervalsContainer.AutomaticSize = Enum.AutomaticSize.Y
        intervalsContainer.Parent = stepFrame
        intervalsContainer.ZIndex = 1
		

        local intervalsLayout = Instance.new("UIListLayout")
        intervalsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        intervalsLayout.Padding = UDim.new(0,5)
        intervalsLayout.Parent = intervalsContainer
		stepData.IntervalsContainer = intervalsContainer
        ----------------------------------------------------------------
        -- INTERVALS (speed graph)
        ----------------------------------------------------------------
        local updateGraph  
	
        local dragging, dragIv, dragKind       -- dragKind = "Start" | "End" | "Bar"
        local grabOffset   -- distance from the mouse to the interval’s start (seconds)
        local barLength    -- cached width of the interval (seconds)
        local function round1(x)
            return math.floor(x*10+0.5)/10
        end

     
        local function addInterval()
            local ivData = {StartTime=nil, StartSpeed=nil, EndSpeed=nil, EndTime=nil}
            table.insert(stepData.IntervalsData, ivData)
	


            local ivFrame = Instance.new("Frame")
            ivFrame.Size = UDim2.new(1,0,0,60)
            ivFrame.BackgroundColor3 = Color3.fromRGB(80,80,80)
            ivFrame.BorderSizePixel = 1
            ivFrame.LayoutOrder = #stepData.IntervalsData
            ivFrame.Parent = intervalsContainer
            ivFrame.ZIndex = 1
            ivData.IntervalFrame = ivFrame

            ------------------------------------------------------------
            -- labels / textboxes
            ------------------------------------------------------------
            local stLabel = Instance.new("TextLabel")
            stLabel.Size = UDim2.new(0,80,0,20)
            stLabel.Position = UDim2.new(0,-15,0,5)
            stLabel.Text = "St Time:"
            stLabel.TextColor3 = Color3.new(1,1,1)
            stLabel.BackgroundTransparency = 1
            stLabel.Font = Enum.Font.SourceSans
            stLabel.TextSize = 14
            stLabel.Parent = ivFrame
            stLabel.ZIndex = 1

            local stBox = Instance.new("TextBox")
            stBox.Size = UDim2.new(0,40,0,25)
            stBox.Position = UDim2.new(0,50,0,5)
            stBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
            stBox.TextColor3 = Color3.new(1,1,1)
            stBox.PlaceholderText = "0"
            stBox.Text = ""
            stBox.Parent = ivFrame
            stBox.ZIndex = 1

            -- Start-speed label / box
            local ssLabel = Instance.new("TextLabel")
            ssLabel.Size = UDim2.new(0,60,0,20)
            ssLabel.Position = UDim2.new(0,90,0,5)
            ssLabel.Text = "St Speed:"
            ssLabel.TextColor3 = Color3.new(1,1,1)
            ssLabel.BackgroundTransparency = 1
            ssLabel.Font = Enum.Font.SourceSans
            ssLabel.TextSize = 14
            ssLabel.Parent = ivFrame
            ssLabel.ZIndex = 1

            local ssBox = Instance.new("TextBox")
            ssBox.Size = UDim2.new(0,30,0,25)
            ssBox.Position = UDim2.new(0,150,0,5)
            ssBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
            ssBox.TextColor3 = Color3.new(1,1,1)
            ssBox.PlaceholderText = "1"
            ssBox.Text = ""
            ssBox.Parent = ivFrame
            ssBox.ZIndex = 1

            -- End-speed label / box
            local esLabel = ssLabel:Clone()
            esLabel.Text = "End Speed:"
            esLabel.Position = UDim2.new(0,185,0,5)
            esLabel.Parent = ivFrame
            esLabel.ZIndex = 1

            local esBox = ssBox:Clone()
            esBox.Position = UDim2.new(0,250,0,5)
            esBox.Parent = ivFrame
            esBox.ZIndex = 1

            local eLabel = Instance.new("TextLabel")
            eLabel.Size = UDim2.new(0,60,0,20)
            eLabel.Position = UDim2.new(0,280,0,5)
            eLabel.Text = "End Time:"
            eLabel.TextColor3 = Color3.new(1,1,1)
            eLabel.BackgroundTransparency = 1
            eLabel.Font = Enum.Font.SourceSans
            eLabel.TextSize = 14
            eLabel.Parent = ivFrame
            eLabel.ZIndex = 1

            local eBox = Instance.new("TextBox")
            eBox.Size = UDim2.new(0,30,0,25)
            eBox.Position = UDim2.new(0,340,0,5)
            eBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
            eBox.TextColor3 = Color3.new(1,1,1)
            eBox.PlaceholderText = "1/end"
            eBox.Text = ""
            eBox.Parent = ivFrame
            eBox.ZIndex = 1

			stBox.Text = tostring(DEFAULT_STIME)
			ssBox.Text = tostring(DEFAULT_SSPEED)
			esBox.Text = tostring(DEFAULT_ESPEED)
			eBox.Text  = tostring(DEFAULT_ETIME)
            ------------------------------------------------------------
            -- remove button
            ------------------------------------------------------------
            local removeInterval = Instance.new("TextButton")
            removeInterval.Size = UDim2.new(0,50,0,25)
            removeInterval.Position = UDim2.new(1,-60,0,5)
            removeInterval.Text = "Rmv"
            removeInterval.BackgroundColor3 = Color3.fromRGB(200,50,50)
            removeInterval.TextColor3 = Color3.new(1,1,1)
            removeInterval.Parent = ivFrame
            removeInterval.ZIndex = 1

            removeInterval.MouseButton1Click:Connect(function()
                local idx = table.find(stepData.IntervalsData, ivData)
                if idx then
                    table.remove(stepData.IntervalsData, idx)
                end
                ivFrame:Destroy()
                for i, x in ipairs(stepData.IntervalsData) do
                    x.IntervalFrame.LayoutOrder = i
                end
                updateGraph()
				rebuildRuntimeTable()
            end)

			stBox:GetPropertyChangedSignal("Text"):Connect(function()
				updateGraph()
				rebuildRuntimeTable()      -- <-- add this line
			end)
			ssBox:GetPropertyChangedSignal("Text"):Connect(function()
				updateGraph()
				rebuildRuntimeTable()
			end)
			esBox:GetPropertyChangedSignal("Text"):Connect(function()
				updateGraph()
				rebuildRuntimeTable()
			end)
			eBox:GetPropertyChangedSignal("Text"):Connect(function()
				updateGraph()
				rebuildRuntimeTable()
			end)

            ivData.StartTime     = stBox
            ivData.StartSpeed    = ssBox
            ivData.EndSpeed      = esBox
            ivData.EndTime       = eBox
            ivData.Color = Color3.fromRGB(math.random(50,255), math.random(50,255), math.random(50,255))   -- random colour
        end

        local function clearGraph()
            for _,c in ipairs(graphFrame:GetChildren()) do
                if c.Name ~= "DotTemplate" then c:Destroy() end
            end
        end

        local function bindDraggable(frame, kind, iv)
            frame.Active = true
			frame.InputBegan:Connect(function(inp)
				if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

				dragging, dragIv, dragKind = true, iv, kind         -- kind == "Bar"

				local function readDur()
					if tostring(durationBox.Text):lower()=="end" then
						return tonumber(lenLabel.Text) or 1   -- falls back to 1
					end
					return tonumber(durationBox.Text) or 1
				end
				local dur = readDur()

				-- current start
				local s = tonumber(iv.StartTime.Text) or 0

							
				local txtEnd = tostring(iv.EndTime.Text or "")
				local e      = isEndToken(txtEnd) and dur or tonumber(txtEnd) or (s + 0.1)

				-- always leave a sliver so bars draw
				barLength = math.clamp(e - s, 0.1, dur)

				----------------------------------------------------------------
				-- work out mouse offset for smooth drag
				----------------------------------------------------------------
				local gx  = graphFrame.AbsolutePosition.X
				local gw  = graphFrame.AbsoluteSize.X
				local mouseX  = UserInputService:GetMouseLocation().X
				local hitTime = math.clamp((mouseX - gx) / gw * dur, 0, dur)

				grabOffset = math.clamp(hitTime - s, 0, barLength)   -- full bar, not ½
			end)
        end

        local function makeDot(px, py, iv, which, col)
            local dot = Instance.new("Frame")
            dot.Size = UDim2.new(0, DOT_SIZE, 0, DOT_SIZE)
            dot.AnchorPoint = Vector2.new(0.5,0.5)
            dot.Position = UDim2.new(0,px,0,py)
            dot.BackgroundColor3 = col
            dot.BorderSizePixel = 0
            dot.Parent = graphFrame
            dot.ZIndex = 4
            dot.Name = which

            dot.Active = true
            dot.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging, dragIv, dragKind = true, iv, which
                end
            end)

            -- Speed label above dot
            local speedLabel = Instance.new("TextLabel")
            speedLabel.Size = UDim2.new(0,40,0,14)
            speedLabel.AnchorPoint = Vector2.new(0.5,1)
            speedLabel.Position = UDim2.new(0,px,0,py - 10)
            speedLabel.BackgroundTransparency = 1
            speedLabel.TextColor3 = Color3.new(1,1,1)
            speedLabel.Font = Enum.Font.SourceSans
            speedLabel.TextSize = 12
            speedLabel.Text = (which == "Start") and tostring(iv.StartSpeed.Text) or tostring(iv.EndSpeed.Text)
            speedLabel.Parent = graphFrame
            speedLabel.ZIndex = 3
			speedLabel:GetPropertyChangedSignal("Text"):Connect(updateGraph)
        end

        updateGraph = function()
            clearGraph()

            local ivs = stepData.IntervalsData
            if #ivs == 0 then return end
			local function readDur()
				if tostring(durationBox.Text):lower()=="end" then
					return tonumber(lenLabel.Text) or 1
				end
				return tonumber(durationBox.Text) or 1
			end
			local dur = readDur()
            
			local graphMaxSpeed = MAX_GRAPH_SPEED

			

			for _,iv in ipairs(ivs) do
				graphMaxSpeed = math.max(
					graphMaxSpeed,
					tonumber(iv.StartSpeed.Text) or 1,
					tonumber(iv.EndSpeed.Text) or 1
				)
			end

            local gw, gh = graphFrame.AbsoluteSize.X, graphFrame.AbsoluteSize.Y

            for _,iv in ipairs(ivs) do
                local col  = iv.Color
                local st   = math.clamp(tonumber(iv.StartTime.Text) or 0 , 0, dur)
				local txtEnd = tostring(iv.EndTime.Text or "")
				local en     = isEndToken(txtEnd) and dur or tonumber(txtEnd) or (st + 0.1)
				pcall(function()
					en = math.clamp(en, st + 0.1, dur)
				end)
				local isEnd     = (txtEnd:lower() == "end")
				local isNumeric = tonumber(txtEnd)
				local eBoxIsBeingEdited = iv.EndTime:IsFocused()  
				if txtEnd == "" and not eBoxIsBeingEdited then
					iv.EndTime.Text = (en == dur) and "end" or ("%0.1f"):format(en)
				end

                local ss   = tonumber(iv.StartSpeed.Text) or 1
                local es   = tonumber(iv.EndSpeed.Text) or ss

                local x1 = (st/dur)*gw
                local x2 = (en/dur)*gw
				local y1 = gh - (ss / graphMaxSpeed) * gh
				local y2 = gh - (es / graphMaxSpeed) * gh
                -- Bar
                local dx, dy = x2 - x1, y2 - y1
                local length = math.sqrt(dx*dx + dy*dy)
                local angle  = math.deg(math.atan2(dy, dx))

                local bar = Instance.new("Frame")
                bar.AnchorPoint      = Vector2.new(0.5, 0.5)
                bar.Size             = UDim2.new(0, length, 0, 6)
				Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 3)
                bar.Position         = UDim2.new(0, (x1 + x2) / 2, 0, (y1 + y2) / 2)
                bar.BackgroundColor3 = col
                bar.BorderSizePixel  = 0
                bar.Rotation         = angle
                bar.Parent           = graphFrame
                bar.ZIndex           = 1
                bindDraggable(bar, "Bar", iv)

                local hit = Instance.new("Frame")
                hit.Size  = UDim2.new(1,0,0,14)
                hit.Position = UDim2.new(0,0,0,-6)
                hit.BackgroundTransparency = 1
                hit.Parent = bar
                hit.ZIndex = 1
                bindDraggable(hit, "Bar", iv)

                -- Start dot
                makeDot(x1, y1, iv, "Start", col)

                -- End dot
                makeDot(x2, y2, iv, "End", col)
            end

            table.sort(ivs, function(a,b)
                return (tonumber(a.StartTime.Text) or 0) < (tonumber(b.StartTime.Text) or 0)
            end)

            for i = 2, #ivs do
                local a, b = ivs[i-1], ivs[i]
				local function parseTime(txt, default)
					if type(txt) == "string" and txt:lower() == "end" then
						return dur          -- full length
					end
					return tonumber(txt) or default
				end

				local aEnd  = parseTime(a.EndTime.Text, dur)
				local bStart= parseTime(b.StartTime.Text, 0)
				local ax = (aEnd   / dur) * gw
				local ay = gh - ((tonumber(a.EndSpeed.Text)   or 1) / graphMaxSpeed) * gh
				local bx = (bStart / dur) * gw
				local by = gh - ((tonumber(b.StartSpeed.Text) or 1) / graphMaxSpeed) * gh
                local d  = Instance.new("Frame")
                d.AnchorPoint   = Vector2.new(0,0.5)
                d.Size          = UDim2.new(0,(bx-ax),0,2)
                d.Position      = UDim2.new(0,ax,0,ay)
                d.Rotation      = math.deg(math.atan2(by-ay,bx-ax))
                d.BorderSizePixel = 0
                d.BackgroundColor3 = Color3.new(0.7,0.7,0.7)
                d.Parent        = graphFrame
                d.ZIndex        = 0
            end
			rebuildRuntimeTable()
        end

		stepData.GraphUpdater = updateGraph
		if not table.find(_G.AllGraphs, updateGraph) then
			table.insert(_G.AllGraphs, updateGraph)
		end

        ----------------------------------------------------------------
        -- default first interval + “Add Interval” button
        ----------------------------------------------------------------
        addInterval()
        updateGraph()
        graphFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGraph)

        local addIntervalButton = Instance.new("TextButton")
        addIntervalButton.Size = UDim2.new(0,100,0,25)
        addIntervalButton.Position = UDim2.new(0,10,0,0)
        addIntervalButton.Text = "Add"
        addIntervalButton.BackgroundColor3 = Color3.fromRGB(50,200,50)
        addIntervalButton.TextColor3 = Color3.new(1,1,1)
        addIntervalButton.Parent = intervalsContainer
        addIntervalButton.ZIndex = 1

		addIntervalButton.MouseButton1Click:Connect(function()
			addInterval()
			updateGraph()
			rebuildRuntimeTable()
		end)

        UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging, dragIv, dragKind = nil,nil,nil
            end
        end)

		local function currentMaxSpeed()
			local m = MAX_GRAPH_SPEED
			for _, iv in ipairs(stepData.IntervalsData) do
				m = math.max(m,
					tonumber(iv.StartSpeed.Text) or 1,
					tonumber(iv.EndSpeed.Text)   or 1
				)
			end
			return m
		end

        UserInputService.InputChanged:Connect(function(inp)
            if not dragging or inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			local rawMouse = UserInputService:GetMouseLocation()
			local relX = rawMouse.X - graphFrame.AbsolutePosition.X
			local relY = rawMouse.Y - graphFrame.AbsolutePosition.Y - 57
			local gw,gh = graphFrame.AbsoluteSize.X, graphFrame.AbsoluteSize.Y

			local function readDur()
				if tostring(durationBox.Text):lower() == "end" then
					return tonumber(lenLabel.Text) or 1
				end
				return tonumber(durationBox.Text) or 1
			end
			local dur = readDur()

			local timeRaw = math.clamp(relX / gw * dur, 0, dur)
            local time = round1(relX / gw * dur)

			local rawSpd = round1(math.max(0, (gh - relY) / gh) * GRAPH_SCALE)
			local spd = math.clamp(rawSpd, 0, MAX_GRAPH_SPEED)

			if dragKind == "Start" then
				dragIv.StartSpeed.Text = tostring(spd)
				local eLimit = isEndToken(dragIv.EndTime.Text) and dur or
							safeNumber(dragIv.EndTime.Text, dur)
				dragIv.StartTime.Text = tostring(math.min(time, eLimit - 0.1))
			elseif dragKind == "End" then
				dragIv.EndSpeed.Text = tostring(spd)
				local sLimit = safeNumber(dragIv.StartTime.Text, 0)
				dragIv.EndTime.Text = tostring(math.max(time, sLimit + 0.1))
            elseif dragKind == "Bar" then
				local newStart = math.clamp(timeRaw - grabOffset, 0, dur - barLength)
				dragIv.StartTime.Text = ("%0.1f"):format(newStart)
				dragIv.EndTime.Text   = ("%0.1f"):format(newStart + barLength)
                local deltaSpd = round1(-inp.Delta.Y / gh * GRAPH_SCALE)
                dragIv.StartSpeed.Text = tostring( math.max(0, (tonumber(dragIv.StartSpeed.Text) or 1) + deltaSpd) )
                dragIv.EndSpeed.Text   = tostring( math.max(0, (tonumber(dragIv.EndSpeed.Text)   or 1) + deltaSpd) )
            end
            updateGraph()
        end)
		rebuildRuntimeTable()
    end
    spawnInterval = function(stepData, ivValues)
		ivValues = ivValues or {}

		-- 1) Create the new ivData table and append to stepData.IntervalsData
		local ivData = {
			StartTime   = nil,
			StartSpeed  = nil,
			EndSpeed    = nil,
			EndTime     = nil,
			Color       = Color3.fromRGB(math.random(50,255), math.random(50,255), math.random(50,255)),
			IntervalFrame = nil,
			RemoveButton  = nil,
		}
		table.insert(stepData.IntervalsData, ivData)

		-- 2) Create the Frame that will hold this interval’s UI
		local intervalsContainer = stepData.IntervalsContainer
		local ivFrame = Instance.new("Frame")
		ivFrame.Size = UDim2.new(1,0,0,60)
		ivFrame.BackgroundColor3 = Color3.fromRGB(80,80,80)
		ivFrame.BorderSizePixel = 1
		ivFrame.LayoutOrder = #stepData.IntervalsData
		ivFrame.Parent = intervalsContainer
		ivFrame.ZIndex = 1
		ivData.IntervalFrame = ivFrame

		-- 3) “St Time” label + TextBox
		local stLabel = Instance.new("TextLabel")
		stLabel.Size = UDim2.new(0,80,0,20)
		stLabel.Position = UDim2.new(0,-15,0,5)
		stLabel.Text = "St Time:"
		stLabel.TextColor3 = Color3.new(1,1,1)
		stLabel.BackgroundTransparency = 1
		stLabel.Font = Enum.Font.SourceSans
		stLabel.TextSize = 14
		stLabel.Parent = ivFrame

		local stBox = Instance.new("TextBox")
		stBox.Size = UDim2.new(0,40,0,25)
		stBox.Position = UDim2.new(0,50,0,5)
		stBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
		stBox.TextColor3 = Color3.new(1,1,1)
		stBox.PlaceholderText = "0"
		stBox.Text = tostring(ivValues.startTime or DEFAULT_STIME)
		stBox.Parent = ivFrame
		ivData.StartTime = stBox

		-- 4) “St Speed” label + TextBox
		local ssLabel = Instance.new("TextLabel")
		ssLabel.Size = UDim2.new(0,60,0,20)
		ssLabel.Position = UDim2.new(0,90,0,5)
		ssLabel.Text = "St Speed:"
		ssLabel.TextColor3 = Color3.new(1,1,1)
		ssLabel.BackgroundTransparency = 1
		ssLabel.Font = Enum.Font.SourceSans
		ssLabel.TextSize = 14
		ssLabel.Parent = ivFrame

		local ssBox = Instance.new("TextBox")
		ssBox.Size = UDim2.new(0,30,0,25)
		ssBox.Position = UDim2.new(0,150,0,5)
		ssBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
		ssBox.TextColor3 = Color3.new(1,1,1)
		ssBox.PlaceholderText = "1"
		ssBox.Text = tostring(ivValues.startSpeed or DEFAULT_SSPEED)
		ssBox.Parent = ivFrame
		ivData.StartSpeed = ssBox

		-- 5) “End Speed” label + TextBox (clone of ssLabel/ssBox)
		local esLabel = ssLabel:Clone()
		esLabel.Text = "End Speed:"
		esLabel.Position = UDim2.new(0,185,0,5)
		esLabel.Parent = ivFrame

		local esBox = ssBox:Clone()
		esBox.Position = UDim2.new(0,250,0,5)
		esBox.Text = tostring(ivValues.endSpeed or DEFAULT_ESPEED)
		esBox.Parent = ivFrame
		ivData.EndSpeed = esBox

		-- 6) “End Time” label + TextBox
		local eLabel = Instance.new("TextLabel")
		eLabel.Size = UDim2.new(0,60,0,20)
		eLabel.Position = UDim2.new(0,280,0,5)
		eLabel.Text = "End Time:"
		eLabel.TextColor3 = Color3.new(1,1,1)
		eLabel.BackgroundTransparency = 1
		eLabel.Font = Enum.Font.SourceSans
		eLabel.TextSize = 14
		eLabel.Parent = ivFrame

		local eBox = Instance.new("TextBox")
		eBox.Size = UDim2.new(0,30,0,25)
		eBox.Position = UDim2.new(0,340,0,5)
		eBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
		eBox.TextColor3 = Color3.new(1,1,1)
		eBox.PlaceholderText = "1/end"
		local endTimeVal = ivValues.endTime or DEFAULT_ETIME
		if type(endTimeVal)=="number" then
			eBox.Text = tostring(endTimeVal)
		elseif type(endTimeVal)=="string" and endTimeVal:lower()=="end" then
			eBox.Text = "end"
		else
			eBox.Text = tostring(DEFAULT_ETIME)
		end
		eBox.Parent = ivFrame
		ivData.EndTime = eBox

		-- 7) “Remove Interval” button
		local removeInterval = Instance.new("TextButton")
		removeInterval.Size = UDim2.new(0,50,0,25)
		removeInterval.Position = UDim2.new(1,-60,0,5)
		removeInterval.Text = "Rmv"
		removeInterval.BackgroundColor3 = Color3.fromRGB(200,50,50)
		removeInterval.TextColor3 = Color3.new(1,1,1)
		removeInterval.Parent = ivFrame
		ivData.RemoveButton = removeInterval

		removeInterval.MouseButton1Click:Connect(function()
			local idx = table.find(stepData.IntervalsData, ivData)
			if idx then
				table.remove(stepData.IntervalsData, idx)
			end
			ivFrame:Destroy()
			for i, x in ipairs(stepData.IntervalsData) do
				x.IntervalFrame.LayoutOrder = i
			end
			if stepData.GraphUpdater then
				stepData.GraphUpdater()
			end
	
			rebuildRuntimeTable()
		end)

		local function remember(conn)
			stepData.__connections = stepData.__connections or {}
			table.insert(stepData.__connections, conn)
		end
		-- 8) Hook “Text changed” on each TextBox to redraw the graph + rebuild table
		remember(stBox:GetPropertyChangedSignal("Text"):Connect(function() 
			if stepData.GraphUpdater then 
				stepData.GraphUpdater() 
			end 
			rebuildRuntimeTable() 
		end))
		remember(ssBox:GetPropertyChangedSignal("Text"):Connect(function() 
			if stepData.GraphUpdater then 
				stepData.GraphUpdater() 
			end 
			rebuildRuntimeTable() 
		end))
		remember(esBox:GetPropertyChangedSignal("Text"):Connect(function() 
			if stepData.GraphUpdater then 
				stepData.GraphUpdater() 
			end 
			rebuildRuntimeTable() 
		end))
		remember(eBox:GetPropertyChangedSignal("Text"):Connect(function() 
			if stepData.GraphUpdater then 
				stepData.GraphUpdater() 
			end 
			rebuildRuntimeTable() 
		end))

		-- 9) Save references into ivData
		ivData.StartTime   = stBox
		ivData.StartSpeed  = ssBox
		ivData.EndSpeed    = esBox
		ivData.EndTime     = eBox

		return ivData
	end


    addSequence = function()
        local seqData = {
            NameBox       = nil,
            UnwantedIdBox = nil,
            ChanceBox     = nil,
            Steps         = {}
        }
        table.insert(sequenceUIList, seqData)

        local sequenceFrame = Instance.new("Frame")
        sequenceFrame.Size = UDim2.new(1, -10, 0, 0)
        sequenceFrame.AutomaticSize = Enum.AutomaticSize.Y
        sequenceFrame.BackgroundColor3 = Color3.fromRGB(60,60,60)
        sequenceFrame.BorderSizePixel = 2
        sequenceFrame.LayoutOrder = #sequenceUIList
        sequenceFrame.Parent = scrollFrame
        sequenceFrame.ZIndex = 1
        seqData.sequenceFrame = sequenceFrame

		local sep = Instance.new("Frame")
		sep.Size = UDim2.new(1,0,0,4)  -- made the height 4 instead of 2
		sep.Position = UDim2.new(0,0,0,-5)
		sep.BackgroundColor3 = Color3.fromRGB(
			math.random(0,255),
			math.random(0,255),
			math.random(0,255)
		)
		sep.AnchorPoint = Vector2.new(0.5,1)
		sep.Parent = sequenceFrame
        sep.ZIndex = 5

        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 40)
        header.BackgroundColor3 = Color3.fromRGB(80,80,80)
        header.Parent = sequenceFrame
        header.ZIndex = 1

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0,50,1,0)
        nameLabel.Position = UDim2.new(0,0,0,0)
        nameLabel.Text = "Name:"
        nameLabel.TextColor3 = Color3.new(1,1,1)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.SourceSansBold
        nameLabel.TextSize = 16
        nameLabel.Parent = header
        nameLabel.ZIndex = 1

        local nameBox = Instance.new("TextBox")
        nameBox.Size = UDim2.new(0,80,0,25)
        nameBox.Position = UDim2.new(0,50,0,7)
        nameBox.PlaceholderText = "Seq"
        nameBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
        nameBox.TextColor3 = Color3.new(1,1,1)
        nameBox.Text = ""
        nameBox.Parent = header
        nameBox.ZIndex = 1
        seqData.NameBox = nameBox

        local unwantedIdLabel = Instance.new("TextLabel")
        unwantedIdLabel.Size = UDim2.new(0,60,1,0)
        unwantedIdLabel.Position = UDim2.new(0,117,0,0)
        unwantedIdLabel.Text = "UID:"
        unwantedIdLabel.TextColor3 = Color3.new(1,1,1)
        unwantedIdLabel.BackgroundTransparency = 1
        unwantedIdLabel.Font = Enum.Font.SourceSansBold
        unwantedIdLabel.TextSize = 16
        unwantedIdLabel.Parent = header
        unwantedIdLabel.ZIndex = 1

        local unwantedIdBox = Instance.new("TextBox")
        unwantedIdBox.Size = UDim2.new(0,80,0,25)
        unwantedIdBox.Position = UDim2.new(0,162,0,7)
        unwantedIdBox.PlaceholderText = "Unwanted"
        unwantedIdBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
        unwantedIdBox.TextColor3 = Color3.new(1,1,1)
        unwantedIdBox.Text = ""
        unwantedIdBox.Parent = header
        unwantedIdBox.ZIndex = 1
        seqData.UnwantedIdBox = unwantedIdBox

        local chanceLabel = Instance.new("TextLabel")
        chanceLabel.Size = UDim2.new(0,60,1,0)
        chanceLabel.Position = UDim2.new(0,240,0,0)
        chanceLabel.Text = "Chance:"
        chanceLabel.TextColor3 = Color3.new(1,1,1)
        chanceLabel.BackgroundTransparency = 1
        chanceLabel.Font = Enum.Font.SourceSansBold
        chanceLabel.TextSize = 16
        chanceLabel.Parent = header
        chanceLabel.ZIndex = 1

        local chanceBox = Instance.new("TextBox")
        chanceBox.Size = UDim2.new(0,50,0,25)
        chanceBox.Position = UDim2.new(0,300,0,7)
        chanceBox.PlaceholderText = "100"
        chanceBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
        chanceBox.TextColor3 = Color3.new(1,1,1)
        chanceBox.Text = ""
        chanceBox.Parent = header
        chanceBox.ZIndex = 1
        seqData.ChanceBox = chanceBox

        local playSeqButton = Instance.new("TextButton")
        playSeqButton.Size = UDim2.new(0,80,0,25)
        playSeqButton.Position = UDim2.new(0,370,0,7)
        playSeqButton.Text = "Play"
        playSeqButton.BackgroundColor3 = Color3.fromRGB(255,165,0)
        playSeqButton.TextColor3 = Color3.new(1,1,1)
        playSeqButton.Font = Enum.Font.SourceSansBold
        playSeqButton.TextSize = 14
        playSeqButton.Parent = header
        playSeqButton.ZIndex = 1
	

		for _, box in ipairs({ nameBox, unwantedIdBox, chanceBox }) do
			box:GetPropertyChangedSignal("Text"):Connect(rebuildRuntimeTable)
		end


		playSeqButton.MouseButton1Click:Connect(function()
			local char = player.Character
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum then return end
			local animator = hum:FindFirstChildOfClass("Animator")
			if not animator then return end

			local testSequence = {
				name   = seqData.NameBox.Text,
				chance = tonumber(seqData.ChanceBox.Text) or 100,
				steps  = {},
			}

			for _, stepObj in ipairs(seqData.Steps) do
				local sID   = stepObj.AnimationId.Text
				local sName = stepObj.StepName.Text
				local stt   = tonumber(stepObj.StartTime.Text) or 0
				local rawDur= stepObj.Duration.Text
				local isEnd = (type(rawDur)=="string" and rawDur:lower()=="end")
				local numericDur = tonumber(rawDur)

				local intervalsPack = {}
				for _, iv in ipairs(stepObj.IntervalsData) do
					local iStart    = tonumber(iv.StartTime.Text) or 0
					local iSpdStart = tonumber(iv.StartSpeed.Text) or 1
					local iSpdEnd   = tonumber(iv.EndSpeed.Text) or 1
					local rawEnd    = iv.EndTime.Text
					local iEnd
					if type(rawEnd)=="string" and rawEnd:lower()=="end" then
						iEnd = "end"
					else
						iEnd = tonumber(rawEnd) or 1
					end
					table.insert(intervalsPack, {
						startTime  = iStart,
						startSpeed = iSpdStart,
						endSpeed   = iSpdEnd,
						endTime    = iEnd,
					})
				end

				table.insert(testSequence.steps, {
					intendedID   = sID,
					stepName     = sName,
					StartTPOS    = stt,
					playUntilEnd = isEnd,
					duration     = numericDur,
					intervals    = intervalsPack,
					startAfter   = tonumber(stepObj.StartAfter.Text) or 0,   -- ← NEW
				})
			end

			-- Stop any old tracks on the player's Animator:
			for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
				t:Stop()
			end

			-- Now call our new playSequence exactly once:
			playSequence(testSequence, animator, "")
		end)


        local removeSeqButton = Instance.new("TextButton")
        removeSeqButton.Size = UDim2.new(0,60,0,25)
        removeSeqButton.Position = UDim2.new(1,-70,0,7)
        removeSeqButton.Text = "Rem"
        removeSeqButton.BackgroundColor3 = Color3.fromRGB(200,50,50)
        removeSeqButton.TextColor3 = Color3.new(1,1,1)
        removeSeqButton.Font = Enum.Font.SourceSansBold
        removeSeqButton.TextSize = 14
        removeSeqButton.Parent = header
        removeSeqButton.ZIndex = 1

        local addStepButton = Instance.new("TextButton")
        addStepButton.Size = UDim2.new(0,60,0,25)
        addStepButton.Position = UDim2.new(1,-140,0,7)
        addStepButton.Text = "Add"
        addStepButton.BackgroundColor3 = Color3.fromRGB(50,200,50)
        addStepButton.TextColor3 = Color3.new(1,1,1)
        addStepButton.Font = Enum.Font.SourceSansBold
        addStepButton.TextSize = 14
        addStepButton.Parent = header
        addStepButton.ZIndex = 1

        local stepsContainer = Instance.new("Frame")
        stepsContainer.Name = "StepsContainer"
        stepsContainer.Size = UDim2.new(1, -20, 1, -50)
        stepsContainer.Position = UDim2.new(0,10,0,50)
        stepsContainer.BackgroundTransparency = 1
        stepsContainer.AutomaticSize = Enum.AutomaticSize.Y
        stepsContainer.Parent = sequenceFrame
        stepsContainer.ZIndex = 1

        local stepsLayout = Instance.new("UIListLayout")
        stepsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        stepsLayout.Padding = UDim.new(0,10)
        stepsLayout.Parent = stepsContainer

		seqData.StepsContainer = stepsContainer

        addStepButton.MouseButton1Click:Connect(function()
            addStep(seqData, stepsContainer)
        end)

		removeSeqButton.MouseButton1Click:Connect(function()
			local idx = table.find(sequenceUIList, seqData)  -- use sequenceUIList, not animationReplacements
			if idx then
				table.remove(sequenceUIList, idx)
			end
			for _, st in ipairs(seqData.Steps) do
				local gi = table.find(_G.AllGraphs, st.GraphUpdater)
				if gi then table.remove(_G.AllGraphs, gi) end
				for _, c in ipairs(st.__connections or {}) do
					safeDisconnect(c)
				end
			end
			sequenceFrame:Destroy()
			-- Reorder remaining sequences
			for i, s in ipairs(sequenceUIList) do
				s.sequenceFrame.LayoutOrder = i
			end
			rebuildRuntimeTable()
		end)


        -- Start with one step
        addStep(seqData, stepsContainer)
		rebuildRuntimeTable()
		nameBox.FocusLost:Connect(rebuildRuntimeTable)
		unwantedIdBox.FocusLost:Connect(rebuildRuntimeTable)
		chanceBox.FocusLost:Connect(rebuildRuntimeTable)
    end

    local addSeqButton = Instance.new("TextButton")
    addSeqButton.Size = UDim2.new(0,200,0,40)
    addSeqButton.Position = UDim2.new(0,10,1,0)
    addSeqButton.Text = "Add Seq"
    addSeqButton.BackgroundColor3 = Color3.fromRGB(50, 50, 200)
    addSeqButton.TextColor3 = Color3.new(1,1,1)
    addSeqButton.Font = Enum.Font.SourceSansBold
    addSeqButton.TextSize = 18
    addSeqButton.Parent = leftFrame
    addSeqButton.ZIndex = 1

    addSeqButton.MouseButton1Click:Connect(function()
        addSequence()
    end)

	----------------------------------------------------------------
	-- QUICK-LENGTH WIDGET  (place right under addSeqButton)
	----------------------------------------------------------------
	local lengthBox   = Instance.new("TextBox")
	lengthBox.Size    = UDim2.new(0,160,0,40)
	lengthBox.Position= UDim2.new(0,220,1,0)   -- 10px to the right of “Add Seq”
	lengthBox.PlaceholderText = "Anim ID"
	lengthBox.BackgroundColor3 = Color3.fromRGB(100,100,100)
	lengthBox.TextColor3       = Color3.new(1,1,1)
	lengthBox.Text             = ""
	lengthBox.Parent           = leftFrame
	lengthBox.ZIndex           = 1

	local resultLabel   = Instance.new("TextLabel")
	resultLabel.Size    = UDim2.new(0,120,0,40)
	resultLabel.Position= UDim2.new(0,390,1,0)  -- sits right of the input
	resultLabel.BackgroundColor3 = Color3.fromRGB(50,150,50)
	resultLabel.TextColor3       = Color3.new(1,1,1)
	resultLabel.Text             = ""
	resultLabel.Visible          = false
	resultLabel.Parent           = leftFrame
	resultLabel.ZIndex           = 1

	-- helper that fetches the last keyframe’s Time
	local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
	local function fetchLength(id)
		local ok, seq = pcall(function()
			return KeyframeSequenceProvider:GetKeyframeSequenceAsync("rbxassetid://"..id)
		end)
		if not ok then return nil end
		local kfs = seq:GetKeyframes()
		return (#kfs > 0) and kfs[#kfs].Time or nil
	end




	-- when user presses Enter or clicks away
	lengthBox.FocusLost:Connect(function(enterPressed)
		if not enterPressed then return end
		local animId = lengthBox.Text:match("%d+")
		if not animId then return end

		resultLabel.Visible = true
		resultLabel.Text    = "…"
		task.defer(function()                      -- non-blocking
			local len = fetchLength(animId)
			if len then
				resultLabel.Text = string.format("%.2fs", len)
			else
				resultLabel.Text = "n/a"
			end
		end)
	end)


    ----------------------------------------------------------------
    -- COPY SCRIPT BUTTON
    ----------------------------------------------------------------
    local copyButton = Instance.new("TextButton")
    copyButton.Size = UDim2.new(0,120,0,40)
    copyButton.Position = UDim2.new(1, -130, 1, 0)
    copyButton.Text = "Copy"
    copyButton.BackgroundColor3 = Color3.fromRGB(200,200,50)
    copyButton.TextColor3 = Color3.new(0,0,0)
    copyButton.Font = Enum.Font.SourceSansBold
    copyButton.TextSize = 18
    copyButton.Parent = leftFrame
    copyButton.ZIndex = 1

	buildReplacementTable = function()
		-- Make sure the runtime table is up to date
		rebuildRuntimeTable()

		-- 1) Group all seqData by unwantedID
		local groupedByUID = {}
		for _, seqData in ipairs(sequenceUIList) do
			local rawUID = seqData.UnwantedIdBox.Text:match("%d+") or ""
			if rawUID ~= "" then
				groupedByUID[rawUID] = groupedByUID[rawUID] or {}
				table.insert(groupedByUID[rawUID], seqData)
			end
		end

		-- 2) Emit a single Lua‐literal for animationReplacements,
		--    where each key is a UID, and its value is an array of sequence objects.
		local lines = {}
		table.insert(lines, "local animationReplacements = {")
		
		for unwantedId, seqList in pairs(groupedByUID) do
			table.insert(lines, string.format("    [\"%s\"] = {", unwantedId))

			for _, seqData in ipairs(seqList) do
				local seqName   = seqData.NameBox.Text or ""
				local chanceVal = tonumber(seqData.ChanceBox.Text) or 100

				table.insert(lines, "        {")
				table.insert(lines, string.format("            name   = %q,", seqName))
				table.insert(lines, string.format("            chance = %d,", chanceVal))
				table.insert(lines, "            steps  = {")

				-- Iterate each step in this seqData
				for _, stepObj in ipairs(seqData.Steps) do
					local stepAnimId  = stepObj.AnimationId.Text or ""
					local stepName    = stepObj.StepName.Text or ""
					local stepStart = tonumber(stepObj.StartTime.Text) or 0
					local stepStartAfter = tonumber(stepObj.StartAfter.Text) or 0
					local rawDurText  = stepObj.Duration.Text or ""
					local isPlayUntil = (rawDurText:lower() == "end")
					local stepDurNum  = tonumber(rawDurText)
					local endOn = {}                  -- <- NEW
					local rawList  = rawDurText:match("^end%(([%d,]+)%)$")
					local playUntil = (rawDurText:lower() == "end")
					if rawList then                                    -- “end(id1,id2,…)”
						for id in rawList:gmatch("%d+") do
							table.insert(endOn,id)
						end
						playUntil = false
					end

					-- Build a small array of interval‐tables
					local intervalsLines = {}
					for _, iv in ipairs(stepObj.IntervalsData) do
						local iStart    = tonumber(iv.StartTime.Text) or 0
						local iSpdStart = tonumber(iv.StartSpeed.Text) or 1
						local iSpdEnd   = tonumber(iv.EndSpeed.Text) or 1
						local rawEnd = tostring(iv.EndTime.Text or ""):lower()
						local iEndIsEnd = (rawEnd:lower() == "end")
						local iEndVal   = iEndIsEnd and "\"end\"" or (tonumber(rawEnd) or 1)

						table.insert(intervalsLines,
							string.format("{startTime=%s, startSpeed=%s, endSpeed=%s, endTime=%s}",
										iStart, iSpdStart, iSpdEnd, iEndVal)
						)
					end

					local intervalsBlock = "{" .. table.concat(intervalsLines, ", ") .. "}"

					table.insert(lines,"                {")
					table.insert(lines,("                    intendedID   = %q,"):format(stepAnimId))
					table.insert(lines,("                    stepName     = %q,"):format(stepName))
					table.insert(lines, ("                    StartTPOS    = %s,"):format(stepStart))
					table.insert(lines,("                    startAfter   = %s,"):format(stepStartAfter))
					table.insert(lines,("                    playUntilEnd = %s,"):format(tostring(playUntil)))
					--  NEW  ➜ only emit endOnList when it is not empty
					if #endOn > 0 then
						table.insert(lines,
							("                    endOnList     = {%s},")
							:format(table.concat(endOn,",")))
					end

					if stepDurNum then
						table.insert(lines,("                    duration     = %s,"):format(stepDurNum))
					end

					table.insert(lines,("                    intervals    = %s,"):format(intervalsBlock))
					table.insert(lines,"                },")
				end

				table.insert(lines, "            },")   -- end of steps array
				table.insert(lines, "        },")       -- end of this sequence entry
			end

			table.insert(lines, "    },")               -- end of unwantedId’s table
		end

		table.insert(lines, "}")
		return table.concat(lines, "\n")
	end



    copyButton.MouseButton1Click:Connect(function()
		rebuildRuntimeTable()
        local function showPopup(cb)
            local sg = Instance.new("ScreenGui")
            sg.Parent = player:WaitForChild("PlayerGui")
            sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0,400,0,250)
            frame.Position = UDim2.new(0.5,-200,0.5,-125)
            frame.BackgroundColor3 = Color3.fromRGB(50,50,50)
            frame.Parent = sg
            frame.Active = true
            frame.Draggable = true
            frame.ZIndex = 100

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1,-20,0,60)
            lbl.Position = UDim2.new(0,10,0,10)
            lbl.TextWrapped = true
            lbl.Text = "Copy reanimation script (based on current sequences)?"
            lbl.TextColor3 = Color3.new(1,1,1)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.SourceSansBold
            lbl.TextSize = 18
            lbl.Parent = frame
            lbl.ZIndex = 101

            local cBtn = Instance.new("TextButton")
            cBtn.Size = UDim2.new(0,180,0,40)
            cBtn.Position = UDim2.new(0.5,-190,1,-50)
            cBtn.Text = "Copy"
            cBtn.BackgroundColor3 = Color3.fromRGB(50,200,50)
            cBtn.TextColor3 = Color3.new(1,1,1)
            cBtn.Font = Enum.Font.SourceSansBold
            cBtn.TextSize = 18
            cBtn.Parent = frame
            cBtn.ZIndex = 101

            local xBtn = Instance.new("TextButton")
            xBtn.Size = UDim2.new(0,180,0,40)
            xBtn.Position = UDim2.new(0.5,10,1,-50)
            xBtn.Text = "Cancel"
            xBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
            xBtn.TextColor3 = Color3.new(1,1,1)
            xBtn.Font = Enum.Font.SourceSansBold
            xBtn.TextSize = 18
            xBtn.Parent = frame
            xBtn.ZIndex = 101
			-- ▼▼ NEW: toggle to decide if script should keep working after respawn
			local afterDeathFlag = false
			local keepChk = Instance.new("TextButton")
			keepChk.Size = UDim2.new(0,340,0,30)
			keepChk.Position = UDim2.new(0.5,-170,0,80)
			keepChk.Text = "[  ] keep replacing animations after you respawn"
			keepChk.TextColor3 = Color3.new(1,1,1)
			keepChk.BackgroundTransparency = 1
			keepChk.Parent = frame
			keepChk.ZIndex = 101
			keepChk.MouseButton1Click:Connect(function()
				afterDeathFlag = not afterDeathFlag
				keepChk.Text = afterDeathFlag
					and "[✓] keep replacing animations after you respawn"
					or  "[  ] keep replacing animations after you respawn"
			end)

            cBtn.MouseButton1Click:Connect(function()
                sg:Destroy()
                cb(true,  afterDeathFlag)
            end)
            xBtn.MouseButton1Click:Connect(function()
                sg:Destroy()
                cb(false)
            end)
        end

        showPopup(function(confirmCopy, afterDeathFlag)
            if not confirmCopy then return end

            local replacementsCode = buildReplacementTable()
            local header = string.format([[
--// Generated Reanimation Script
-- Place this as a LocalScript in StarterPlayerScripts or similar.

local Players = game:GetService("Players")
local CONTINUE_AFTER_DEATH = %s
local RunService = game:GetService("RunService")

-- We listen only for external animations; no internal multi-play logic.

]], tostring(afterDeathFlag))

local finalScript = header
    .. "\n"
    .. "-- This table is auto-generated from your UI:\n"
    .. replacementsCode
    .. [[
--------------------------------------------------------------------------------
-- PLAY A SEQUENCE (all steps fire at exactly `step.startAfter` seconds)
--   • Each step is scheduled independently relative to the moment `playSequence` is called.
--   • If two steps “overlap,” they run concurrently.
--   • `step.startTime` is still the time‐offset *within* the animation.
--   • `step.playUntilEnd` or `step.duration` stops that track after the correct amount of time.
--------------------------------------------------------------------------------

local function playSequence(sequence, animator, unwantedID, stoppedEvent)
    local cancel = false
    local tracks = {}
    local allEndIds = {}
    for _, step in ipairs(sequence.steps or {}) do
        if step.endOnList then
            for _, id in ipairs(step.endOnList) do
                allEndIds[tostring(id)] = true
            end
        end
    end

    local stopConn
    stopConn = animator.AnimationPlayed:Connect(function(otherTrack)
        if not otherTrack.Animation then return end
        local otherID = otherTrack.Animation.AnimationId:match("%d+$")
        if otherID and allEndIds[otherID] then
            cancel = true
            for _, t in ipairs(tracks) do
                if t.IsPlaying then t:Stop() end
            end
            stopConn:Disconnect()
        end
    end)

    for _, step in ipairs(sequence.steps or {}) do
        coroutine.wrap(function()
            if cancel then return end

            if step.startAfter and step.startAfter > 0 then
                local elapsed = 0
                while elapsed < step.startAfter do
                    if cancel then return end
                    local dt = RunService.Heartbeat:Wait()
                    elapsed = elapsed + dt
                end
            end
            if cancel then return end

            local newAnim = Instance.new("Animation")
            newAnim.AnimationId = "rbxassetid://" .. step.intendedID
            local track = animator:LoadAnimation(newAnim)
            track.Looped = false
            
            track:Play()
			track.TimePosition = tonumber(step.StartTPOS) or 0
			if step.StartTPOS and step.StartTPOS > 0 and step.intervals and #step.intervals > 0 then
				track:AdjustSpeed(step.intervals[1].startSpeed or 1) 
			elseif step.intervals and #step.intervals > 0 then
				track:AdjustSpeed(step.intervals[1].startSpeed or 1)
			end
            table.insert(tracks, track)

            if step.intervals and #step.intervals > 0 then
                coroutine.wrap(function()
                    for _, iv in ipairs(step.intervals) do
                        local st   = iv.startTime   or 0
                        local sspd = iv.startSpeed  or 1
                        local espd = iv.endSpeed    or sspd
                        local eT   = iv.endTime
                        if type(eT) == "string" and eT:lower() == "end" then
                            eT = (track.Length and track.Length > 0) and track.Length or (st + 1)
                        end
                        eT = tonumber(eT) or (st + 1)

                        while not cancel and track.IsPlaying and track.TimePosition < st do
                            RunService.Heartbeat:Wait()
                        end
                        while not cancel and track.IsPlaying and track.TimePosition < eT do
                            local frac = math.clamp((track.TimePosition - st) / (eT - st), 0, 1)
                            track:AdjustSpeed(sspd + (espd - sspd) * frac)
                            RunService.Heartbeat:Wait()
                        end
                        if cancel then return end
                        if track.IsPlaying then
                            track:AdjustSpeed(1)
                        end
                    end
                end)()
            end

            if step.duration and step.duration > 0 then
                task.delay(step.duration, function()
                    if track and track.IsPlaying then track:Stop() end
                end)
                while not cancel and track and track.IsPlaying do
                    RunService.Heartbeat:Wait()
                end
            end
        end)()
    end
end

local function onAnimationPlayed(animationTrack, animator)
    if not animationTrack.Animation then return end
    local unwantedID = animationTrack.Animation.AnimationId:match("%d+$")
    if not unwantedID then return end

    local sequences = animationReplacements[unwantedID]
    if not sequences then return end

    animationTrack:AdjustSpeed(0)
    animationTrack:Stop()

    -- weighted pick
    local totalChance = 0
    for _, seq in ipairs(sequences) do
        totalChance = totalChance + (seq.chance or 0)
    end
    if totalChance == 0 then
        totalChance = #sequences
        for _, seq in ipairs(sequences) do
            seq.chance = 1
        end
    end

    local pick = math.random(1, totalChance)
    local cum = 0
    local selected
    for _, seq in ipairs(sequences) do
        cum = cum + (seq.chance or 0)
        if pick <= cum then
            selected = seq
            break
        end
    end
    if selected then
        playSequence(selected, animator, unwantedID, animationTrack.Stopped)
    end
end

-- hook to local player:
local function onCharacterAdded(char)
    local hum = char:WaitForChild("Humanoid")
    local animator = hum:WaitForChild("Animator")
    animator.AnimationPlayed:Connect(function(track)
        onAnimationPlayed(track, animator)
    end)
    if not CONTINUE_AFTER_DEATH then
        hum.Died:Connect(function()
            -- disconnect all after death if flag is false
            for _, conn in ipairs(animator:GetConnections()) do
                conn:Disconnect()
            end
        end)
    end
end

if CONTINUE_AFTER_DEATH then
    player.CharacterAdded:Connect(onCharacterAdded)
end
if player.Character then
    onCharacterAdded(player.Character)
end
]]
			
            Clipboard(finalScript)
        end)
    end)

    ----------------------------------------------------------------
    -- RESIZE BOTTOM-RIGHT CORNER: ENTIRE UI
    ----------------------------------------------------------------
    local resizeButton = Instance.new("TextButton")
    resizeButton.Size = UDim2.new(0,120,0,50)
    resizeButton.Position = UDim2.new(1, -130, 1, -60)
    resizeButton.Text = "[ Resize ]"
    resizeButton.TextColor3 = Color3.new(1,1,1)
    resizeButton.BackgroundColor3 = Color3.fromRGB(70,70,70)
    resizeButton.BorderSizePixel = 3
    resizeButton.ZIndex = 10
    resizeButton.Parent = mainFrame

    local resizing = false
    local resizeStart
    local initialSize

    resizeButton.MouseButton1Down:Connect(function()
        resizing     = true
        resizeStart  = UserInputService:GetMouseLocation()
        initialSize  = mainFrame.Size
    end)

    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = UserInputService:GetMouseLocation() - resizeStart
            mainFrame.Size = UDim2.new(0, initialSize.X.Offset + delta.X,
                                    0, initialSize.Y.Offset + delta.Y)
            resizeColumns()
            for _,fn in ipairs(_G.AllGraphs or {}) do
                fn()
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
        end
    end)

    ----------------------------------------------------------------
    -- INIT
    ----------------------------------------------------------------
    local liveFolder = workspace:FindFirstChild("Live")
    if liveFolder then
        liveFolder.ChildAdded:Connect(onLiveChildAdded)
    end
    reconnectLogging()
	-- put this outside of any “if” so it always runs
	local function hookLocalPlayerReplacement()
		-- whenever the LocalPlayer’s character spawns, hook its Animator
		player.CharacterAdded:Connect(function(char)
			local hum = char:WaitForChild("Humanoid", 5)
			if not hum then return end
			local animator = hum:WaitForChild("Animator", 5)
			if not animator then return end

			animator.AnimationPlayed:Connect(function(track)
				onAnimationPlayed(track, animator)
			end)
		end)

		-- if character already exists (e.g. on initial load), hook it now
		if player.Character then
			local hum0 = player.Character:FindFirstChildOfClass("Humanoid")
			local animator0 = hum0 and hum0:FindFirstChildOfClass("Animator")
			if hum0 and animator0 then
				animator0.AnimationPlayed:Connect(function(track)
					onAnimationPlayed(track, animator0)
				end)
			end
		end
	end

        hookLocalPlayerReplacement()
        listSavedConfigs()
        autoloadLatestConfig()
end

createGUI()

-- Complete implementation of loadConfigIntoUI, assuming addSequence and addStep are defined
loadConfigIntoUI = function(sequenceUIList, configName, parentScrollFrame)
	disconnectAll() 
    -- 1) read + decode JSON
    local configPath = CONFIG_FOLDER .. "/" .. configName .. ".json"
    if not isfile(configPath) then return end
    local jsonString = readfile(configPath)
    local ok, loaded = pcall(function() return HttpService:JSONDecode(jsonString) end)
    if not ok then return end

    -- 2) clear existing UI
    for _, seqData in ipairs(sequenceUIList) do
        if seqData.sequenceFrame and seqData.sequenceFrame:IsDescendantOf(parentScrollFrame) then
			for _, st in ipairs(seqData.Steps) do
				local gi = table.find(_G.AllGraphs, st.GraphUpdater)
				if gi then table.remove(_G.AllGraphs, gi) end
				for _, c in ipairs(st.__connections or {}) do
					safeDisconnect(c)
				end
			end
            seqData.sequenceFrame:Destroy()
        end
    end

	for k in pairs(sequenceUIList) do
		sequenceUIList[k] = nil
	end
	_G.AllGraphs = {}
    animationReplacements = {}

    -- 3) rebuild each sequence
    for _, seqEntry in ipairs(loaded) do
        -- a) create the sequence block
        addSequence()
        local seqData = sequenceUIList[#sequenceUIList]
		if seqData.Steps and #seqData.Steps >= 1 then
			seqData.Steps[1].StepFrame:Destroy()
			table.remove(seqData.Steps, 1)
		end

        -- b) populate header fields
        seqData.NameBox.Text       = seqEntry.name   or ""
        seqData.UnwantedIdBox.Text = seqEntry.uid    or ""
        seqData.ChanceBox.Text     = tostring(seqEntry.chance or 100)

        -- c) for each saved step:
		for _, stepEntry in ipairs(seqEntry.steps or {}) do
			-- 1) create a brand-new step (this also auto-creates one default interval)
			addStep(seqData, seqData.StepsContainer)
			local stepData = seqData.Steps[#seqData.Steps]

			-- ✂–– immediately clear out the “default” interval that addStep() spawned:
			--    • clear data table
			stepData.IntervalsData = {}
			--    • destroy any IntervalFrame children under the UI container
			for _, child in ipairs(stepData.IntervalsContainer:GetChildren()) do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end


			stepData.StepName.Text    = stepEntry.stepName or ""
			stepData.AnimationId.Text = stepEntry.intendedID or ""
			stepData.StartAfter.Text  = tostring(stepEntry.startAfter or 0)
			stepData.StartTime.Text   = tostring(stepEntry.StartTPOS or 0)
			-- immediately fetch & show length:
			local id = stepData.AnimationId.Text:match("%d+")
			if id then
				local ok, seq = pcall(function()
					return game:GetService("KeyframeSequenceProvider")
								:GetKeyframeSequenceAsync("rbxassetid://"..id)
				end)
				if ok and seq then
					local kfs = seq:GetKeyframes()
					local len = (#kfs > 0) and kfs[#kfs].Time or nil
					if len then
						stepData.LenLabel.Text    = string.format("%.2f", len)
						stepData.Duration.Text    = string.format("%.2f", len)
					end
				end
			end


			-- if they had an endOnList, reconstruct “end(id1,id2,…)” verbatim:
			if stepEntry.endOnList and #stepEntry.endOnList > 0 then
				stepData.Duration.Text = "end(" .. table.concat(stepEntry.endOnList, ",") .. ")"
			elseif stepEntry.playUntilEnd then
				stepData.Duration.Text = "end"
			else
				stepData.Duration.Text = tostring(stepEntry.duration or "")
			end

			-- then spawn the intervals exactly as you already do…
			for _, ivEntry in ipairs(stepEntry.intervals or {}) do
				spawnInterval(stepData, {
					startTime  = ivEntry.startTime,
					startSpeed = ivEntry.startSpeed,
					endSpeed   = ivEntry.endSpeed,
					endTime    = ivEntry.endTime,
				})
			end

			if stepData.GraphUpdater then
				stepData.GraphUpdater()
			end

		end
    end

    -- 4) rebuild the runtime‐table so “animationReplacements” is up to date
    rebuildRuntimeTable()
        reconnectLogging()
    if configNameBox then
        configNameBox.Text = tostring(configName or "")
    end
end


