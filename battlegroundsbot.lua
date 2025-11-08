--!strict
--[[
    JoeHub Battlegrounds Bot (Perception-Limited)
    Requirements handled:
      • Runtime-capable PvP bot for The Strongest Battlegrounds.
      • Fluent-like GUI for start/stop, telemetry, and manual overrides.
      • Uses JoeHub aim CFrame helper when available, with a safe fallback.
      • Integrates with JoeHub perception data for evasive/ultimate insight when exposed.
      • Session learning system persisted to executor storage (writefile/readfile).

    This script intentionally stays within human-perceivable data: character
    positions, animation tags, public attributes, and UI-exposed state.  No
    replicated storage peeking or remote function spoofing occurs.  All actions
    are performed via VirtualInputManager in the same way a player would press
    keys.  The learning store records combo outcomes to improve routing next
    session.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- Forward declarations -------------------------------------------------------
local BotController

-- Shared Config --------------------------------------------------------------
local Config = {
    CharacterKey = "saitama",
    ComboConfirmDistance = 16,
    NeutralSpacingMin = 10,
    NeutralSpacingMax = 22,
    AimReactTime = 0.08,
    AimDamping = 0.55,
    AimStrength = 1.35,
    EvasiveCooldown = 26,
    ActionBindings = {
        M1 = { type = "MouseButton", button = Enum.UserInputType.MouseButton1 },
        Shove = { type = "Key", key = Enum.KeyCode.R },
        ConsecutivePunches = { type = "Key", key = Enum.KeyCode.E },
        Uppercut = { type = "Key", key = Enum.KeyCode.T },
        NormalPunch = { type = "Key", key = Enum.KeyCode.G },
        Block = { type = "Key", key = Enum.KeyCode.F },
        SideDash = { type = "Key", key = Enum.KeyCode.Z },
        ForwardDash = { type = "Key", key = Enum.KeyCode.C },
        BackDash = { type = "Key", key = Enum.KeyCode.X },
        Evasive = { type = "Key", key = Enum.KeyCode.V },
    },
    InputTap = 0.045,
    InputHoldShort = 0.12,
    InputHoldMedium = 0.22,
    DataFolder = "battlegroundbot",
}

-- Utility Functions ----------------------------------------------------------
local function safeMakeFolder(path)
    if not makefolder or not isfolder then
        return
    end
    if not isfolder(path) then
        pcall(makefolder, path)
    end
end

local function safeWriteFile(path, contents)
    if not writefile then
        return
    end
    local ok, err = pcall(writefile, path, contents)
    if not ok then
        warn("battlegroundbot writefile failed", err)
    end
end

local function safeAppendFile(path, contents)
    if not appendfile then
        return
    end
    local ok, err = pcall(appendfile, path, contents)
    if not ok then
        warn("battlegroundbot appendfile failed", err)
    end
end

local function safeReadFile(path)
    if not readfile or not isfile then
        return nil
    end
    if not isfile(path) then
        return nil
    end
    local ok, result = pcall(readfile, path)
    if ok then
        return result
    end
    warn("battlegroundbot readfile failed", result)
    return nil
end

local function pressBinding(name, hold)
    local binding = Config.ActionBindings[name]
    if not binding then
        return
    end

    if binding.type == "Key" then
        VirtualInputManager:SendKeyEvent(true, binding.key, false, game)
        task.wait(hold or Config.InputTap)
        VirtualInputManager:SendKeyEvent(false, binding.key, false, game)
    elseif binding.type == "MouseButton" then
        VirtualInputManager:SendMouseButtonEvent(0, 0, binding.button, true, game, 0)
        task.wait(hold or Config.InputTap)
        VirtualInputManager:SendMouseButtonEvent(0, 0, binding.button, false, game, 0)
    end
end

local function tapDirectional(keyCode: Enum.KeyCode, duration: number?)
    duration = duration or 0.2
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.delay(duration, function()
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function holdDirectional(keyCode: Enum.KeyCode, duration: number)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.wait(duration)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function setKeyState(keyCode: Enum.KeyCode, isDown: boolean)
    VirtualInputManager:SendKeyEvent(isDown, keyCode, false, game)
end

local function pressAndHold(name, duration)
    local binding = Config.ActionBindings[name]
    if not binding then
        return
    end

    if binding.type == "Key" then
        VirtualInputManager:SendKeyEvent(true, binding.key, false, game)
        task.wait(duration)
        VirtualInputManager:SendKeyEvent(false, binding.key, false, game)
    elseif binding.type == "MouseButton" then
        VirtualInputManager:SendMouseButtonEvent(0, 0, binding.button, true, game, 0)
        task.wait(duration)
        VirtualInputManager:SendMouseButtonEvent(0, 0, binding.button, false, game, 0)
    end
end

local function aimWithCFrame(rootPart: BasePart, targetPart: BasePart)
    if not (rootPart and targetPart) then
        return
    end
    local rootPos = rootPart.Position
    local targetPos = targetPart.Position
    local dir = targetPos - rootPos
    if dir.Magnitude < 0.05 then
        return
    end

    -- keep previous pitch to avoid camera snaps
    local oldLook = rootPart.CFrame.LookVector
    local oldPitch = math.asin(oldLook.Y)
    local horizTarget = Vector3.new(targetPos.X, rootPos.Y, targetPos.Z)
    local flatDir = (horizTarget - rootPos)
    if flatDir.Magnitude <= 1e-3 then
        flatDir = Vector3.new(oldLook.X, 0, oldLook.Z)
    end
    flatDir = flatDir.Unit
    local cosPitch = math.cos(oldPitch)
    local finalDir = Vector3.new(flatDir.X * cosPitch, math.sin(oldPitch), flatDir.Z * cosPitch)
    rootPart.CFrame = CFrame.lookAt(rootPos, rootPos + finalDir)
end

-- JoeHub Integrations --------------------------------------------------------
local JoeHubBridge = {}
JoeHubBridge.__index = JoeHubBridge

function JoeHubBridge.new()
    local env = rawget(getgenv(), "joehub") or rawget(getgenv(), "JoeHub")
    local self = setmetatable({}, JoeHubBridge)
    if typeof(env) == "table" then
        self.env = env
    end
    if self.env then
        self.aimFunction = self.env.AimAt or self.env.AimTarget or self.env.AimStabilizer
        self.evasiveQuery = self.env.GetEvasive or self.env.GetEvasiveState
        self.targetingFeed = self.env.GetHostilePlayers
    end
    return self
end

function JoeHubBridge:getEvasive(model: Model)
    if self.evasiveQuery then
        local ok, result = pcall(self.evasiveQuery, model)
        if ok and result ~= nil then
            return result
        end
    end
    local readyAttr = model:GetAttribute("EvasiveReady")
    if typeof(readyAttr) == "boolean" then
        return readyAttr
    end
    local cdAttr = model:GetAttribute("EvasiveCooldown")
    if typeof(cdAttr) == "number" then
        return cdAttr <= 0
    end
    return nil
end

function JoeHubBridge:aim(rootPart: BasePart, targetPart: BasePart)
    if self.aimFunction then
        local ok = pcall(self.aimFunction, rootPart, targetPart)
        if ok then
            return true
        end
    end
    return false
end

function JoeHubBridge:getTargets()
    if self.targetingFeed then
        local ok, result = pcall(self.targetingFeed)
        if ok and typeof(result) == "table" then
            return result
        end
    end
    return nil
end

-- Learning Store -------------------------------------------------------------
local LearningStore = {}
LearningStore.__index = LearningStore

function LearningStore.new()
    local self = setmetatable({}, LearningStore)
    self.folder = Config.DataFolder
    self.learningFile = string.format("%s/learning.json", self.folder)
    self.sessionsFolder = string.format("%s/sessions", self.folder)
    self.learning = {
        combos = {},
        sessions = 0,
        lastUpdate = os.time(),
    }
    self:load()
    return self
end

function LearningStore:ensure()
    safeMakeFolder(self.folder)
    safeMakeFolder(self.sessionsFolder)
end

function LearningStore:load()
    self:ensure()
    local raw = safeReadFile(self.learningFile)
    if not raw then
        return
    end
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if ok and typeof(decoded) == "table" then
        if typeof(decoded.combos) ~= "table" then
            decoded.combos = {}
        end
        self.learning = decoded
    end
end

function LearningStore:save()
    self.learning.lastUpdate = os.time()
    local encoded = HttpService:JSONEncode(self.learning)
    safeWriteFile(self.learningFile, encoded)
end

function LearningStore:startSession()
    self:ensure()
    self.learning.sessions += 1
    self:save()
    local sessionId = os.date("%Y%m%d-%H%M%S")
    local path = string.format("%s/%s.jsonl", self.sessionsFolder, sessionId)
    safeWriteFile(path, "")
    self.currentSessionPath = path
    return path
end

function LearningStore:log(eventName: string, payload: table)
    if not self.currentSessionPath then
        return
    end
    local entry = {
        t = os.clock(),
        event = eventName,
        data = payload,
    }
    safeAppendFile(self.currentSessionPath, HttpService:JSONEncode(entry) .. "\n")
end

function LearningStore:getCombo(comboId: string)
    local combos = self.learning.combos
    if not combos[comboId] then
        combos[comboId] = {
            attempts = 0,
            successes = 0,
            totalDamage = 0,
            lastSuccess = 0,
        }
    end
    return combos[comboId]
end

function LearningStore:recordAttempt(comboId: string)
    local combo = self:getCombo(comboId)
    combo.attempts += 1
    combo.lastAttempt = os.time()
    self:save()
end

function LearningStore:recordResult(comboId: string, success: boolean, damage: number)
    local combo = self:getCombo(comboId)
    if success then
        combo.successes += 1
        combo.lastSuccess = os.time()
    end
    combo.totalDamage += math.max(0, damage)
    self:save()
end

function LearningStore:reset()
    self.learning = {
        combos = {},
        sessions = 0,
        lastUpdate = os.time(),
    }
    self:save()
end

-- GUI ------------------------------------------------------------------------
local GuiController = {}
GuiController.__index = GuiController

local function createText(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, bold: boolean)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.Size = size
    label.Position = position
    label.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    label.BackgroundTransparency = 0.35
    label.TextColor3 = Color3.fromRGB(235, 235, 235)
    label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    label.TextSize = textSize
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.BorderSizePixel = 0
    label.Parent = parent
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.Parent = label
    return label
end

local function createButton(parent: Instance, name: string, text: string, size: UDim2, position: UDim2)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(48, 60, 96)
    button.TextColor3 = Color3.fromRGB(240, 240, 240)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 18
    button.Text = text
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(94, 123, 255)
    stroke.Thickness = 1.4
    stroke.Transparency = 0.35
    stroke.Parent = button
    button.Parent = parent
    return button
end

local function enableDragging(frame: Frame)
    local dragging = false
    local dragStart, startPos

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function GuiController.new()
    local self = setmetatable({}, GuiController)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BattlegroundBotUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = gethui and gethui() or game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 360, 0, 320)
    frame.Position = UDim2.new(0, 60, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(17, 18, 26)
    frame.BorderSizePixel = 0
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(76, 110, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.15
    stroke.Parent = frame
    frame.Parent = screenGui
    enableDragging(frame)

    local title = createText(frame, "Title", "JoeHub Battleground Bot", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 0), 20, true)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(205, 214, 255)

    local statusLabel = createText(frame, "Status", "Status: idle", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 46), 18, false)
    local targetLabel = createText(frame, "Target", "Target: none", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 78), 18, false)
    local comboLabel = createText(frame, "Combo", "Combo: none", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 110), 18, false)
    local evasiveLabel = createText(frame, "Evasive", "Evasive: ready", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 142), 18, false)

    local startButton = createButton(frame, "StartButton", "Start Bot", UDim2.new(0.5, -15, 0, 36), UDim2.new(0, 10, 0, 180))
    local stopButton = createButton(frame, "StopButton", "Stop Bot", UDim2.new(0.5, -15, 0, 36), UDim2.new(0.5, 5, 0, 180))
    stopButton.BackgroundColor3 = Color3.fromRGB(120, 50, 50)

    local panicButton = createButton(frame, "PanicButton", "Panic Evasive", UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 224))
    panicButton.BackgroundColor3 = Color3.fromRGB(110, 40, 40)

    local resetLearningButton = createButton(frame, "ResetLearning", "Reset Learning", UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, 264))
    resetLearningButton.BackgroundColor3 = Color3.fromRGB(48, 70, 120)

    local learningFrame = Instance.new("Frame")
    learningFrame.Name = "LearningFrame"
    learningFrame.Size = UDim2.new(0, 240, 0, 140)
    learningFrame.Position = UDim2.new(1, 10, 0, 0)
    learningFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
    learningFrame.BorderSizePixel = 0
    learningFrame.Visible = false
    local learningStroke = Instance.new("UIStroke")
    learningStroke.Color = Color3.fromRGB(76, 110, 255)
    learningStroke.Thickness = 1
    learningStroke.Transparency = 0.2
    learningStroke.Parent = learningFrame
    learningFrame.Parent = frame

    local learningTitle = createText(learningFrame, "LearningTitle", "Combo Learning", UDim2.new(1, -10, 0, 30), UDim2.new(0, 5, 0, 2), 18, true)
    learningTitle.BackgroundTransparency = 1

    local learningList = Instance.new("ScrollingFrame")
    learningList.Name = "LearningList"
    learningList.Size = UDim2.new(1, -10, 1, -36)
    learningList.Position = UDim2.new(0, 5, 0, 34)
    learningList.CanvasSize = UDim2.new(0, 0, 0, 0)
    learningList.BackgroundTransparency = 1
    learningList.BorderSizePixel = 0
    learningList.ScrollBarThickness = 4
    learningList.Parent = learningFrame

    local uiList = Instance.new("UIListLayout")
    uiList.Padding = UDim.new(0, 6)
    uiList.HorizontalAlignment = Enum.HorizontalAlignment.Left
    uiList.VerticalAlignment = Enum.VerticalAlignment.Top
    uiList.SortOrder = Enum.SortOrder.LayoutOrder
    uiList.Parent = learningList

    self.gui = screenGui
    self.frame = frame
    self.statusLabel = statusLabel
    self.targetLabel = targetLabel
    self.comboLabel = comboLabel
    self.evasiveLabel = evasiveLabel
    self.startButton = startButton
    self.stopButton = stopButton
    self.panicButton = panicButton
    self.resetLearningButton = resetLearningButton
    self.learningFrame = learningFrame
    self.learningList = learningList
    self.learningLayout = uiList

    startButton.MouseButton1Click:Connect(function()
        if BotController then
            BotController:start()
        end
    end)

    stopButton.MouseButton1Click:Connect(function()
        if BotController then
            BotController:stop()
        end
    end)

    panicButton.MouseButton1Click:Connect(function()
        if BotController then
            BotController:panicEvasive(true)
        end
    end)

    resetLearningButton.MouseButton1Click:Connect(function()
        if BotController then
            BotController:resetLearning()
        end
    end)

    return self
end

function GuiController:setStatus(text: string)
    if self.statusLabel then
        self.statusLabel.Text = text
    end
end

function GuiController:setTarget(text: string)
    if self.targetLabel then
        self.targetLabel.Text = text
    end
end

function GuiController:setCombo(text: string)
    if self.comboLabel then
        self.comboLabel.Text = text
    end
end

function GuiController:setEvasive(text: string)
    if self.evasiveLabel then
        self.evasiveLabel.Text = text
    end
end

function GuiController:showLearning(show: boolean)
    if self.learningFrame then
        self.learningFrame.Visible = show
    end
end

function GuiController:updateLearningList(learning: table)
    if not self.learningList then
        return
    end
    local layout: UIListLayout? = self.learningLayout
    for _, child in ipairs(self.learningList:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    for comboId, info in pairs(learning.combos or {}) do
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -6, 0, 32)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(210, 220, 255)
        label.Font = Enum.Font.Gotham
        label.TextSize = 16
        local successRate = 0
        if info.attempts > 0 then
            successRate = (info.successes / info.attempts) * 100
        end
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Text = string.format("%s | %d/%d | %.1f%% | dmg %.0f", comboId, info.successes or 0, info.attempts or 0, successRate, info.totalDamage or 0)
        label.Parent = self.learningList
    end
    if layout then
        self.learningList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end
end

function GuiController:destroy()
    if self.gui then
        self.gui:Destroy()
    end
end

-- Combo Definitions ---------------------------------------------------------
export type ComboStep = {
    kind: string,
    action: string?,
    hold: number?,
    wait: number?,
    duration: number?,
    direction: Enum.KeyCode?,
}

type ComboDefinition = {
    id: string,
    name: string,
    requiresNoEvasive: boolean?,
    minimumRange: number?,
    maximumRange: number?,
    punishBlock: boolean?,
    punishDash: boolean?,
    styleBias: { [string]: number }?,
    steps: { ComboStep },
}

local ComboLibrary: { ComboDefinition } = {
    {
        id = "saitama_tc1",
        name = "TC: M1 > Shove > CP > M1 > NP",
        requiresNoEvasive = false,
        minimumRange = 0,
        maximumRange = 15,
        punishBlock = true,
        styleBias = { defensive = 1.2 },
        steps = {
            { kind = "aim" },
            { kind = "press", action = "M1", hold = Config.InputHoldShort, wait = 0.12 },
            { kind = "press", action = "Shove", wait = 0.32 },
            { kind = "press", action = "SideDash", wait = 0.08 },
            { kind = "press", action = "ConsecutivePunches", wait = 0.55 },
            { kind = "press", action = "M1", wait = 0.18 },
            { kind = "press", action = "NormalPunch" },
        },
    },
    {
        id = "saitama_tc2",
        name = "TC: M1x2 > Shove > Upper",
        requiresNoEvasive = false,
        minimumRange = 0,
        maximumRange = 13,
        punishBlock = true,
        styleBias = { aggressive = 1.1, defensive = 1.15 },
        steps = {
            { kind = "aim" },
            { kind = "press", action = "M1", hold = Config.InputHoldShort, wait = 0.12 },
            { kind = "press", action = "M1", hold = Config.InputHoldShort, wait = 0.12 },
            { kind = "press", action = "Shove", wait = 0.3 },
            { kind = "press", action = "SideDash", wait = 0.08 },
            { kind = "press", action = "Uppercut" },
        },
    },
    {
        id = "saitama_ecc1",
        name = "ECC: 3M1 > Upper > CP > NP",
        requiresNoEvasive = true,
        minimumRange = 0,
        maximumRange = 12,
        styleBias = { aggressive = 1.25 },
        steps = {
            { kind = "aim" },
            { kind = "press", action = "M1", hold = Config.InputHoldShort, wait = 0.1 },
            { kind = "press", action = "M1", hold = Config.InputHoldShort, wait = 0.1 },
            { kind = "press", action = "M1", hold = Config.InputHoldShort, wait = 0.18 },
            { kind = "press", action = "Uppercut", wait = 0.35 },
            { kind = "press", action = "SideDash", wait = 0.12 },
            { kind = "press", action = "M1", wait = 0.16 },
            { kind = "press", action = "ConsecutivePunches", wait = 0.45 },
            { kind = "press", action = "M1", wait = 0.12 },
            { kind = "press", action = "NormalPunch" },
        },
    },
    {
        id = "saitama_mix_feint",
        name = "Mix: Feint block > dash > CP > NP",
        minimumRange = 4,
        maximumRange = 18,
        punishBlock = true,
        styleBias = { defensive = 1.45 },
        steps = {
            { kind = "aim" },
            { kind = "block", duration = 0.25, wait = 0.05 },
            { kind = "press", action = "ForwardDash", wait = 0.1 },
            { kind = "press", action = "Shove", wait = 0.26 },
            { kind = "press", action = "ConsecutivePunches", wait = 0.52 },
            { kind = "press", action = "M1", wait = 0.16 },
            { kind = "press", action = "NormalPunch" },
        },
    },
    {
        id = "saitama_dashpunish",
        name = "Anti-mobility: Side catch > Upper",
        minimumRange = 3,
        maximumRange = 17,
        punishDash = true,
        styleBias = { mobile = 1.6, aggressive = 1.2 },
        steps = {
            { kind = "press", action = "SideDash", wait = 0.06 },
            { kind = "aim" },
            { kind = "press", action = "M1", hold = Config.InputHoldShort, wait = 0.12 },
            { kind = "press", action = "M1", wait = 0.12 },
            { kind = "press", action = "Uppercut", wait = 0.32 },
            { kind = "press", action = "ConsecutivePunches", wait = 0.42 },
            { kind = "press", action = "NormalPunch" },
        },
    },
    {
        id = "saitama_pressure",
        name = "Pressure: Dash in > shove loop",
        minimumRange = 2,
        maximumRange = 16,
        styleBias = { aggressive = 1.4 },
        steps = {
            { kind = "press", action = "ForwardDash", wait = 0.08 },
            { kind = "aim" },
            { kind = "press", action = "M1", hold = Config.InputHoldShort, wait = 0.12 },
            { kind = "press", action = "Shove", wait = 0.28 },
            { kind = "move", direction = Enum.KeyCode.A, duration = 0.18, wait = 0.05 },
            { kind = "press", action = "M1", wait = 0.1 },
            { kind = "press", action = "ConsecutivePunches", wait = 0.5 },
            { kind = "press", action = "Uppercut" },
        },
    },
}

-- Bot Controller ------------------------------------------------------------
local Bot = {}
Bot.__index = Bot

type EnemyBehavior = {
    attackScore: number,
    blockScore: number,
    dashScore: number,
    lastAttackTime: number,
    lastBlockTime: number,
    lastDashTime: number,
    hitsLanded: number,
}

type EnemyRecord = {
    model: Model,
    humanoid: Humanoid?,
    hrp: BasePart?,
    distance: number,
    hasEvasive: boolean,
    lastEvasive: number,
    threatScore: number,
    player: Player?,
    lastKnownHealth: number,
    behavior: EnemyBehavior,
    style: string?,
    connections: { RBXScriptConnection },
    listenersAttached: boolean,
}

function Bot.new()
    local self = setmetatable({}, Bot)
    self.gui = GuiController.new()
    self.learningStore = LearningStore.new()
    self.bridge = JoeHubBridge.new()
    self.enemies = {}
    self.running = false
    self.state = "idle"
    self.sessionStart = 0
    self.sessionFile = nil
    self.currentCombo = nil
    self.currentTarget = nil
    self.lastComboAttempt = 0
    self.actionThread = nil
    self.evasiveLock = 0
    self.lastDamageTaken = 0
    self.humanoid = nil
    self.rootPart = nil
    self.character = nil
    self.alive = false
    self.evasiveReady = true
    self.evasiveTimer = 0
    self.shouldPanicEvasive = false
    self.lastMoveCommand = 0
    self.lastStrafeCommand = 0
    self.lastForwardDash = 0
    self.lastBackDash = 0
    self.lastBasicAttack = 0
    self.lastAttackerName = nil
    self.liveFolder = workspace:WaitForChild("Live")
    self.liveCharacter = self.liveFolder:FindFirstChild(LocalPlayer.Name)
    self.blocking = false
    self.blockReleaseDeadline = 0
    self.counterWindow = 0
    self.lastReactiveDash = 0
    self.defensiveMode = false

    self.gui:setStatus("Status: idle")
    self.gui:setTarget("Target: none")
    self.gui:setCombo("Combo: none")
    self.gui:setEvasive("Evasive: unknown")
    self.gui:showLearning(true)
    self.gui:updateLearningList(self.learningStore.learning)

    self:connectCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())

    LocalPlayer.CharacterAdded:Connect(function(char)
        self:connectCharacter(char)
    end)

    for _, model in ipairs(self.liveFolder:GetChildren()) do
        self:addEnemy(model)
    end
    self.liveFolder.ChildAdded:Connect(function(model)
        if model.Name == LocalPlayer.Name then
            self.liveCharacter = model
        else
            self:addEnemy(model)
        end
    end)
    self.liveFolder.ChildRemoved:Connect(function(model)
        self.enemies[model] = nil
        if model == self.liveCharacter then
            self.liveCharacter = nil
        end
    end)

    self.heartbeatConn = RunService.Heartbeat:Connect(function(dt)
        self:update(dt)
    end)

    return self
end

function Bot:destroy()
    if self.heartbeatConn then
        self.heartbeatConn:Disconnect()
        self.heartbeatConn = nil
    end
    if self.blocking then
        self:setBlocking(false)
    end
    if self.gui then
        self.gui:destroy()
    end
end

function Bot:connectCharacter(char: Model)
    self.character = char
    if not char then
        return
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not humanoid then
        return
    end
    self.humanoid = humanoid
    self.rootPart = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
    self.alive = humanoid.Health > 0
    self.evasiveReady = true
    self.evasiveTimer = 0
    self.lastDamageTaken = humanoid.Health

    humanoid.Died:Connect(function()
        self.alive = false
        self.running = false
        self.gui:setStatus("Status: dead")
        self.gui:setTarget("Target: none")
        if self.actionThread then
            self.actionThread = nil
        end
    end)

    humanoid.HealthChanged:Connect(function(health)
        if health < self.lastDamageTaken - 2 then
            self.shouldPanicEvasive = true
            self.evasiveReady = self:getEvasiveAttribute() or self.evasiveReady
        end
        self.lastDamageTaken = health
    end)

    humanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.FallingDown or newState == Enum.HumanoidStateType.Physics then
            self.shouldPanicEvasive = true
        end
    end)

    if self.bridge.env and self.bridge.env.RegisterEvasiveListener then
        pcall(self.bridge.env.RegisterEvasiveListener, function(ready)
            self.evasiveReady = ready
        end)
    end
end

function Bot:getEvasiveAttribute()
    local attr = LocalPlayer:GetAttribute("EvasiveReady")
    if typeof(attr) == "boolean" then
        return attr
    end
    local cooldown = LocalPlayer:GetAttribute("EvasiveCooldown")
    if typeof(cooldown) == "number" then
        return cooldown <= 0
    end
    return nil
end

function Bot:addEnemy(model: Model)
    if model:GetAttribute("NPC") then
        return
    end
    if model.Name == LocalPlayer.Name then
        return
    end
    local behavior: EnemyBehavior = {
        attackScore = 0,
        blockScore = 0,
        dashScore = 0,
        lastAttackTime = 0,
        lastBlockTime = 0,
        lastDashTime = 0,
        hitsLanded = 0,
    }
    local record: EnemyRecord = {
        model = model,
        humanoid = model:FindFirstChildOfClass("Humanoid"),
        hrp = model:FindFirstChild("HumanoidRootPart"),
        distance = math.huge,
        hasEvasive = true,
        lastEvasive = 0,
        threatScore = 0,
        player = Players:FindFirstChild(model.Name),
        lastKnownHealth = 100,
        behavior = behavior,
        style = "balanced",
        connections = {},
        listenersAttached = false,
    }
    if record.humanoid then
        record.lastKnownHealth = record.humanoid.Health
    end

    self:attachEnemyListeners(record)

    if record.humanoid then
        table.insert(record.connections, record.humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if record.humanoid then
                record.lastKnownHealth = record.humanoid.Health
            end
        end))
    end

    local function onDescendant(desc)
        if desc.Name == "RagdollCancel" then
            record.lastEvasive = tick()
            record.hasEvasive = false
        end
    end

    for _, desc in ipairs(model:GetDescendants()) do
        onDescendant(desc)
    end
    table.insert(record.connections, model.DescendantAdded:Connect(onDescendant))

    table.insert(record.connections, model.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            self:cleanupEnemy(record)
            self.enemies[model] = nil
        end
    end))

    self.enemies[model] = record
end

function Bot:start()
    if not self.alive then
        self.gui:setStatus("Status: waiting for spawn")
        return
    end
    if self.running then
        self.gui:setStatus("Status: running")
        return
    end

    self.running = true
    self.sessionFile = self.learningStore:startSession()
    self.sessionStart = os.clock()
    self.gui:setStatus("Status: running")
    self.gui:setCombo("Combo: none")
    self.learningStore:log("session_start", { character = Config.CharacterKey })
end

function Bot:stop()
    if not self.running then
        return
    end
    self.running = false
    if self.humanoid then
        self.humanoid.AutoRotate = true
    end
    if self.blocking then
        self:setBlocking(false)
    end
    self.gui:setStatus("Status: idle")
    self.gui:setCombo("Combo: none")
    self.learningStore:log("session_stop", { duration = os.clock() - self.sessionStart })
end

function Bot:panicEvasive(force: boolean)
    if force then
        if not self:attemptEvasive("manual") then
            self.shouldPanicEvasive = true
        end
    else
        self.shouldPanicEvasive = true
    end
end

function Bot:resetLearning()
    self.learningStore:reset()
    self.gui:updateLearningList(self.learningStore.learning)
    self.learningStore:log("learning_reset", { ts = os.time() })
end

function Bot:setBlocking(enable: boolean)
    local binding = Config.ActionBindings.Block
    if not binding or binding.type ~= "Key" then
        return
    end
    if self.blocking == enable then
        return
    end
    self.blocking = enable
    setKeyState(binding.key, enable)
    if not enable then
        self.blockReleaseDeadline = 0
    end
end

function Bot:cleanupEnemy(record: EnemyRecord)
    if not record or not record.connections then
        return
    end
    for _, conn in ipairs(record.connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        elseif conn and conn.Disconnect then
            conn:Disconnect()
        end
    end
    table.clear(record.connections)
    record.listenersAttached = false
end

function Bot:registerEnemyAction(record: EnemyRecord, kind: string)
    local behavior = record and record.behavior
    if not behavior then
        return
    end
    local now = tick()
    if kind == "attack" then
        behavior.attackScore = behavior.attackScore * 0.7 + 1
        behavior.lastAttackTime = now
        behavior.hitsLanded = behavior.hitsLanded * 0.6 + 1
    elseif kind == "block" then
        behavior.blockScore = behavior.blockScore * 0.65 + 1
        behavior.lastBlockTime = now
    elseif kind == "dash" then
        behavior.dashScore = behavior.dashScore * 0.68 + 1
        behavior.lastDashTime = now
    end
end

function Bot:handleEnemyAnimation(record: EnemyRecord, track: AnimationTrack)
    if not track then
        return
    end
    local name = ""
    local animation = track.Animation
    if animation and animation.Name then
        name = string.lower(animation.Name)
    elseif track.Name then
        name = string.lower(track.Name)
    end
    if name == "" then
        return
    end
    if string.find(name, "block") or string.find(name, "guard") then
        self:registerEnemyAction(record, "block")
    end
    if string.find(name, "dash") or string.find(name, "step") or string.find(name, "evade") then
        self:registerEnemyAction(record, "dash")
    end
    if string.find(name, "punch") or string.find(name, "attack") or string.find(name, "swing") or string.find(name, "combo") then
        self:registerEnemyAction(record, "attack")
    end
end

function Bot:attachEnemyListeners(record: EnemyRecord)
    if not record or record.listenersAttached then
        return
    end
    record.listenersAttached = true
    local humanoid = record.humanoid or record.model:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        record.listenersAttached = false
        return
    end
    record.humanoid = humanoid
    local function connectAnimator(animator)
        if not animator then
            return
        end
        local animConn = animator.AnimationPlayed:Connect(function(track)
            self:handleEnemyAnimation(record, track)
        end)
        table.insert(record.connections, animConn)
    end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        connectAnimator(animator)
    end
    table.insert(record.connections, humanoid.ChildAdded:Connect(function(child)
        if child:IsA("Animator") then
            connectAnimator(child)
        end
    end))
    table.insert(record.connections, humanoid.HealthChanged:Connect(function(health)
        local last = record.lastKnownHealth or health
        local delta = last - health
        if delta > 1 then
            if record.behavior then
                record.behavior.blockScore *= 0.85
                record.behavior.attackScore *= 0.9
            end
        end
        record.lastKnownHealth = health
    end))
end

function Bot:getEnemyRecordByName(name: string): EnemyRecord?
    for _, record in pairs(self.enemies) do
        if record.model.Name == name then
            return record
        end
    end
    return nil
end

function Bot:defensiveChecks(dt: number)
    local now = tick()
    local highestThreat = 0
    local threatRecord: EnemyRecord? = nil
    for _, record in pairs(self.enemies) do
        if record.model.Parent and record.hrp then
            local distance = record.distance or math.huge
            if distance < 18 then
                local behavior = record.behavior
                local attackUrgency = 0
                local dashUrgency = 0
                if behavior then
                    attackUrgency = math.max(0, 1.4 - (now - behavior.lastAttackTime)) * (behavior.attackScore + behavior.hitsLanded * 0.5)
                    dashUrgency = math.max(0, 1.2 - (now - behavior.lastDashTime)) * (behavior.dashScore + 0.2)
                end
                local lastHitBonus = (self.lastAttackerName and record.model.Name == self.lastAttackerName) and 0.6 or 0
                local threat = attackUrgency + dashUrgency + lastHitBonus
                if threat > highestThreat then
                    highestThreat = threat
                    threatRecord = record
                end
            end
        end
    end
    local shouldBlock = highestThreat > 0.75
    if shouldBlock then
        if not self.blocking then
            self:setBlocking(true)
        end
        self.blockReleaseDeadline = os.clock() + 0.45
        self.defensiveMode = true
        if highestThreat > 1.35 and threatRecord and threatRecord.distance < 10 then
            if os.clock() - self.lastReactiveDash > 1 then
                if threatRecord.distance < 6 and os.clock() - self.lastBackDash > 1 then
                    pressBinding("BackDash")
                    self.lastBackDash = os.clock()
                else
                    pressBinding("SideDash")
                end
                self.lastReactiveDash = os.clock()
            end
        end
        return true
    else
        if self.blocking and os.clock() > self.blockReleaseDeadline then
            self:setBlocking(false)
            self.counterWindow = os.clock()
        end
        if self.blocking then
            return true
        end
        self.defensiveMode = false
        return false
    end
end

function Bot:update(dt: number)
    if not self.character or not self.humanoid or not self.rootPart then
        return
    end
    if self.humanoid.Health <= 0 then
        self.running = false
        return
    end

    self:updateEvasiveState(dt)
    self:updateEnemyData(dt)
    self:updateLastAttacker()

    if not self.running then
        return
    end

    if self.shouldPanicEvasive then
        if self:attemptEvasive("panic") then
            self.shouldPanicEvasive = false
        end
    end

    if self.actionThread then
        -- Update aim while combo executing.
        if self.currentTarget and self.currentTarget.hrp then
            self:applyAim(self.currentTarget.hrp)
        end
        return
    end

    local defending = self:defensiveChecks(dt)

    local target = self:selectTarget()
    if not target then
        self.currentTarget = nil
        self.gui:setTarget("Target: none")
        self:neutralMovement()
        return
    end

    self.currentTarget = target
    self.gui:setTarget(string.format("Target: %s (%.0f hp)", target.model.Name, target.lastKnownHealth))
    self:applyAim(target.hrp)

    if (not defending) or (self.counterWindow > 0 and os.clock() - self.counterWindow < 0.6) then
        if self:shouldStartCombo(target) then
            local combo = self:chooseCombo(target)
            if combo then
                self:executeCombo(combo, target)
                return
            end
        end
    end

    self:neutralMovement(target)
end

function Bot:updateEvasiveState(dt: number)
    local attr = self:getEvasiveAttribute()
    if attr ~= nil then
        self.evasiveReady = attr
        if attr then
            self.evasiveTimer = 0
        end
    else
        if self.evasiveTimer > 0 then
            self.evasiveTimer -= dt
            if self.evasiveTimer <= 0 then
                self.evasiveReady = true
            end
        end
    end
    local statusText = self.evasiveReady and "Evasive: ready" or string.format("Evasive: %.1fs", math.max(0, self.evasiveTimer))
    self.gui:setEvasive(statusText)
end

function Bot:updateEnemyData(dt: number)
    local myPos = self.rootPart.Position
    local now = tick()
    for model, record in pairs(self.enemies) do
        if model.Parent == nil then
            self:cleanupEnemy(record)
            self.enemies[model] = nil
        else
            record.hrp = record.hrp or model:FindFirstChild("HumanoidRootPart")
            record.humanoid = record.humanoid or model:FindFirstChildOfClass("Humanoid")
            if not record.listenersAttached and record.humanoid then
                self:attachEnemyListeners(record)
            end
            if record.hrp then
                record.distance = (record.hrp.Position - myPos).Magnitude
            else
                record.distance = math.huge
            end
            local behavior = record.behavior
            if behavior then
                local attackDecay = math.exp(-dt * 1.15)
                local blockDecay = math.exp(-dt * 0.9)
                local dashDecay = math.exp(-dt * 1)
                behavior.attackScore *= attackDecay
                behavior.blockScore *= blockDecay
                behavior.dashScore *= dashDecay
                behavior.hitsLanded *= math.exp(-dt * 0.8)
            end
            local evasiveFromBridge = self.bridge:getEvasive(model)
            if evasiveFromBridge ~= nil then
                record.hasEvasive = evasiveFromBridge and true or false
            else
                if record.lastEvasive > 0 and now - record.lastEvasive > Config.EvasiveCooldown then
                    record.hasEvasive = true
                end
            end
            if record.humanoid and record.humanoid.Health <= 0 then
                record.threatScore = -math.huge
            else
                local hp = record.humanoid and record.humanoid.Health or record.lastKnownHealth
                record.lastKnownHealth = hp
                local hpFactor = (100 - hp)
                local distanceFactor = math.clamp(40 - record.distance, -40, 40)
                local evasiveFactor = record.hasEvasive and -25 or 15
                record.threatScore = hpFactor + distanceFactor + evasiveFactor
                if self.lastAttackerName and record.model.Name == self.lastAttackerName then
                    record.threatScore += 120
                end
                if behavior then
                    local attackPressure = behavior.attackScore
                    local blockDiscipline = behavior.blockScore
                    local mobility = behavior.dashScore
                    local style = "balanced"
                    local highest = attackPressure
                    style = "aggressive"
                    if blockDiscipline > highest then
                        highest = blockDiscipline
                        style = "defensive"
                    end
                    if mobility > highest then
                        highest = mobility
                        style = "mobile"
                    end
                    if highest < 0.35 then
                        style = "balanced"
                    end
                    record.style = style
                    record.threatScore += attackPressure * 18 + blockDiscipline * 9 + mobility * 12
                end
            end
        end
    end
end

function Bot:selectTarget(): EnemyRecord?
    local best: EnemyRecord? = nil
    local bestScore = -math.huge
    for _, record in pairs(self.enemies) do
        if record.model.Parent and record.humanoid and record.humanoid.Health > 0 then
            if record.distance < 60 then
                if record.threatScore > bestScore then
                    bestScore = record.threatScore
                    best = record
                end
            end
        end
    end
    return best
end

function Bot:applyAim(targetHRP: BasePart?)
    if not targetHRP or not self.rootPart then
        return
    end
    if self.humanoid then
        local state = self.humanoid:GetState()
        if state == Enum.HumanoidStateType.FallingDown then
            self.humanoid.AutoRotate = true
            return
        end
    end
    if not self.bridge:aim(self.rootPart, targetHRP) then
        aimWithCFrame(self.rootPart, targetHRP)
    end
    if self.humanoid then
        self.humanoid.AutoRotate = false
    end
end

function Bot:shouldStartCombo(target: EnemyRecord)
    if not target or not target.hrp then
        return false
    end
    if os.clock() - self.lastComboAttempt < 1.5 then
        return false
    end
    if target.distance > Config.ComboConfirmDistance then
        return false
    end
    if self.blocking and os.clock() < self.blockReleaseDeadline then
        return false
    end
    if self.defensiveMode and (self.counterWindow == 0 or os.clock() - self.counterWindow > 0.5) then
        return false
    end
    if not self.humanoid or self.humanoid.MoveDirection.Magnitude > 0.35 then
        return false
    end
    if target.humanoid and target.humanoid.FloorMaterial == Enum.Material.Air then
        return false
    end
    return true
end

function Bot:chooseCombo(target: EnemyRecord): ComboDefinition?
    local available = {}
    for _, combo in ipairs(ComboLibrary) do
        if combo.requiresNoEvasive and target.hasEvasive then
            continue
        end
        if combo.minimumRange and target.distance < combo.minimumRange then
            continue
        end
        if combo.maximumRange and target.distance > combo.maximumRange then
            continue
        end
        local stats = self.learningStore:getCombo(combo.id)
        local attempts = stats.attempts
        local successes = stats.successes
        local successRate = (successes + 1) / (attempts + 2)
        local distanceBias = math.max(0.1, 1 - math.abs((target.distance - ((combo.minimumRange or 0) + (combo.maximumRange or 20)) / 2) / 20))
        local weight = successRate * distanceBias
        if combo.styleBias and target.style then
            weight *= combo.styleBias[target.style] or 1
        end
        local behavior = target.behavior
        if behavior then
            if combo.punishBlock and behavior.blockScore > 0.6 then
                weight *= 1.2 + math.min(0.6, behavior.blockScore)
            end
            if combo.punishDash and behavior.dashScore > 0.5 then
                weight *= 1.1 + math.min(0.5, behavior.dashScore)
            end
            if combo.requiresNoEvasive and not target.hasEvasive and behavior.attackScore > 0.8 then
                weight *= 1.15
            end
        end
        table.insert(available, { combo = combo, weight = weight })
    end
    if #available == 0 then
        return nil
    end
    table.sort(available, function(a, b)
        return a.weight > b.weight
    end)
    return available[1].combo
end

function Bot:executeCombo(combo: ComboDefinition, target: EnemyRecord)
    if self.actionThread then
        return
    end
    if self.blocking then
        self:setBlocking(false)
    end
    self.counterWindow = 0
    self.currentCombo = combo
    self.lastComboAttempt = os.clock()
    self.gui:setCombo("Combo: " .. combo.name)
    self.learningStore:recordAttempt(combo.id)
    self.learningStore:log("combo_start", { id = combo.id, target = target.model.Name })

    local startHealth = target.humanoid and target.humanoid.Health or target.lastKnownHealth
    local thread
    thread = task.spawn(function()
        local aborted = false
        for _, step in ipairs(combo.steps) do
            if not self.running then
                aborted = true
                break
            end
            if not target.model.Parent then
                aborted = true
                break
            end
            if step.kind == "aim" then
                self:applyAim(target.hrp)
                task.wait(0.05)
            elseif step.kind == "press" and step.action then
                if step.hold and step.hold > Config.InputTap then
                    pressAndHold(step.action, step.hold)
                else
                    pressBinding(step.action, step.hold)
                end
                if step.wait and step.wait > 0 then
                    task.wait(step.wait)
                else
                    task.wait(Config.InputTap)
                end
            elseif step.kind == "block" then
                local duration = step.duration or 0.3
                self:setBlocking(true)
                self.blockReleaseDeadline = os.clock() + duration
                task.wait(duration)
                if os.clock() >= self.blockReleaseDeadline then
                    self:setBlocking(false)
                end
                if step.wait and step.wait > 0 then
                    task.wait(step.wait)
                end
            elseif step.kind == "release_block" then
                self:setBlocking(false)
                if step.wait and step.wait > 0 then
                    task.wait(step.wait)
                end
            elseif step.kind == "move" and step.direction then
                holdDirectional(step.direction, step.duration or 0.2)
                if step.wait and step.wait > 0 then
                    task.wait(step.wait)
                else
                    task.wait(Config.InputTap)
                end
            elseif step.kind == "wait" then
                task.wait(step.wait or Config.InputTap)
            end
        end
        if aborted or not self.running then
            self.gui:setCombo("Combo: none")
            self.currentCombo = nil
            self.actionThread = nil
            self:setBlocking(false)
            return
        end
        task.wait(0.65)
        local endHealth = target.humanoid and target.humanoid.Health or startHealth
        local damage = math.max(0, startHealth - endHealth)
        local success = damage > 4
        self.learningStore:recordResult(combo.id, success, damage)
        self.learningStore:log("combo_result", {
            id = combo.id,
            success = success,
            damage = damage,
            target = target.model.Name,
        })
        self.gui:setCombo("Combo: none")
        self.currentCombo = nil
        self.actionThread = nil
        self:setBlocking(false)
        self.gui:updateLearningList(self.learningStore.learning)
    end)
    self.actionThread = thread
end

function Bot:neutralMovement(target: EnemyRecord?)
    if not target or not target.hrp then
        return
    end
    local distance = target.distance
    local now = os.clock()
    local behavior = target.behavior
    if behavior and behavior.blockScore > 0.8 and now - self.lastBasicAttack > 0.9 then
        if now - self.lastMoveCommand > 0.3 then
            self:setBlocking(true)
            self.blockReleaseDeadline = os.clock() + 0.2
            task.delay(0.25, function()
                if self.blocking and os.clock() > self.blockReleaseDeadline then
                    self:setBlocking(false)
                end
            end)
            self.lastMoveCommand = now
        end
    end
    if distance > Config.NeutralSpacingMax then
        if now - self.lastForwardDash > 1 then
            pressBinding("ForwardDash")
            self.lastForwardDash = now
        end
        if now - self.lastMoveCommand > 0.15 then
            tapDirectional(Enum.KeyCode.W, 0.28)
            self.lastMoveCommand = now
        end
    elseif distance < Config.NeutralSpacingMin * 0.6 then
        if behavior and behavior.attackScore > 0.8 and os.clock() - self.lastBackDash > 0.8 then
            pressBinding("BackDash")
            self.lastBackDash = os.clock()
        end
        if now - self.lastMoveCommand > 0.15 then
            tapDirectional(Enum.KeyCode.S, 0.2)
            self.lastMoveCommand = now
        end
        if now - self.lastBackDash > 0.8 then
            pressBinding("BackDash")
            self.lastBackDash = now
        end
    else
        if now - self.lastStrafeCommand > 0.9 then
            local strafeKey = math.random() < 0.5 and Enum.KeyCode.A or Enum.KeyCode.D
            tapDirectional(strafeKey, 0.18)
            if math.random() < 0.45 then
                pressBinding("SideDash")
            end
            self.lastStrafeCommand = now
        end
        local aggression = behavior and behavior.attackScore or 0
        if distance < Config.ComboConfirmDistance - 1 and now - self.lastBasicAttack > 1.1 then
            if aggression > 0.7 and os.clock() - self.lastForwardDash > 0.7 then
                pressBinding("ForwardDash")
                self.lastForwardDash = os.clock()
            end
            pressBinding("M1", Config.InputHoldShort)
            self.lastBasicAttack = now
        end
    end
end

function Bot:attemptEvasive(reason: string)
    if not self.evasiveReady then
        return false
    end
    self.evasiveReady = false
    self.evasiveTimer = Config.EvasiveCooldown
    pressBinding("Evasive", Config.InputTap)
    self.learningStore:log("evasive", { reason = reason, t = os.clock() })
    return true
end

function Bot:updateLastAttacker()
    if not self.liveCharacter then
        self.liveCharacter = self.liveFolder and self.liveFolder:FindFirstChild(LocalPlayer.Name) or nil
    end
    if not self.liveCharacter then
        return
    end
    local attacker = self.liveCharacter:GetAttribute("LastHit")
    if attacker == nil then
        attacker = self.liveCharacter:GetAttribute("lastHit")
    end
    if typeof(attacker) == "string" and attacker ~= "" then
        self.lastAttackerName = attacker
        local record = self:getEnemyRecordByName(attacker)
        if record then
            self:registerEnemyAction(record, "attack")
        end
    end
end

-- Initialization -------------------------------------------------------------
if getgenv().BattlegroundsBot and getgenv().BattlegroundsBot.destroy then
    pcall(function()
        getgenv().BattlegroundsBot:destroy()
    end)
end

local botInstance = Bot.new()
getgenv().BattlegroundsBot = botInstance
BotController = botInstance

return botInstance
