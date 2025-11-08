--!strict
--[[
    A perception-limited PvP bot for The Strongest Battlegrounds.
    Version 0.2 (Saitama TC/ECC)

    This script follows the architecture described in the accompanying design
    document.  It intentionally uses only data that a legitimate player can
    observe in game: visible character states, UI health bars, animation tags,
    and manually timed cooldowns.  No memory inspection or replicated storage
    peeking is performed; everything is inferred from in-world objects.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

--\\ CONFIG //----------------------------------------------------------------------
local Config = {}

Config.CharacterName = "The Strongest Hero"
Config.CharacterKey = "saitama"

Config.Cooldowns = {
    Shove = 10,
    ConsecutivePunches = 15,
    Uppercut = 20,
    NormalPunch = 20,
    SideDash = 2,
    ForwardDash = 5,
    BackDash = 5,
}

Config.UtilityWeights = {
    lowHealthBonus = 3.5,
    proximityBonus = 2.0,
    noEvasiveBonus = 2.5,
    wallBonus = 1.5,
    hostilityPenalty = -2.0,
    crowdPenalty = -1.0,
}

Config.Alliance = {
    handshakeWindow = 5,
    gracePeriod = 10,
    decayTime = 200,
    signalCooldown = 8,
}

Config.ActionBindings = {
    M1 = { type = "MouseButton", button = Enum.UserInputType.MouseButton1 },
    Shove = { type = "Key", key = Enum.KeyCode.R },
    ConsecutivePunches = { type = "Key", key = Enum.KeyCode.E },
    Uppercut = { type = "Key", key = Enum.KeyCode.F },
    NormalPunch = { type = "Key", key = Enum.KeyCode.G },
    Block = { type = "Key", key = Enum.KeyCode.Q },
    SideDash = { type = "Key", key = Enum.KeyCode.Z },
    ForwardDash = { type = "Key", key = Enum.KeyCode.C },
    BackDash = { type = "Key", key = Enum.KeyCode.X },
    Evasive = { type = "Key", key = Enum.KeyCode.V },
}

Config.InputRepeatDelay = 0.05
Config.MinNeutralSpacing = 8
Config.MaxNeutralSpacing = 23
Config.ComboConfirmDistance = 14
Config.FriendlyBlockWindow = 0.35
Config.MaxTargetsConsidered = 6
Config.ExtendedRagdollHeight = 8

--\\ LOGGER //-----------------------------------------------------------------------
local Logger = {}
Logger.__index = Logger

function Logger.new()
    local self = setmetatable({}, Logger)
    self.active = false
    self.sessionFolder = nil
    self.metrics = {}
    self.logFolder = nil
    self.routeFolder = nil
    self.logIndex = 0
    return self
end

function Logger:startSession()
    local rootFolder = workspace:FindFirstChild("battlegroundbotdata")
    if not rootFolder then
        rootFolder = Instance.new("Folder")
        rootFolder.Name = "battlegroundbotdata"
        rootFolder.Parent = workspace
    end

    local sessionFolder = Instance.new("Folder")
    sessionFolder.Name = os.date("%Y-%m-%d_%H-%M-%S")
    sessionFolder.Parent = rootFolder

    local metrics = Instance.new("Configuration")
    metrics.Name = "metrics"
    metrics.Parent = sessionFolder

    local metricNames = {
        "kills",
        "deaths",
        "totalDamage",
        "combosLanded",
        "combosDropped",
        "alliancesMade",
        "evasiveWasted",
    }

    for _, name in ipairs(metricNames) do
        local numberValue = Instance.new("NumberValue")
        numberValue.Name = name
        numberValue.Value = 0
        numberValue.Parent = metrics
        self.metrics[name] = numberValue
    end

    local logFolder = Instance.new("Folder")
    logFolder.Name = "logs"
    logFolder.Parent = sessionFolder

    local routeFolder = Instance.new("Folder")
    routeFolder.Name = "routes"
    routeFolder.Parent = sessionFolder

    self.sessionFolder = sessionFolder
    self.logFolder = logFolder
    self.routeFolder = routeFolder
    self.logIndex = 0
    self.active = true
end

function Logger:increment(metricName, amount)
    if not self.active then
        return
    end

    local metric = self.metrics[metricName]
    if metric then
        metric.Value += amount or 1
    end
end

function Logger:logEvent(eventName, payload)
    if not self.active then
        return
    end

    self.logIndex += 1
    local entry = Instance.new("StringValue")
    entry.Name = string.format("log_%04d", self.logIndex)
    entry.Value = HttpService:JSONEncode({
        t = tick(),
        event = eventName,
        payload = payload,
    })
    entry.Parent = self.logFolder
end

function Logger:logRoute(targetUserId, routeId)
    if not self.active then
        return
    end

    local key = string.format("%d_%d", targetUserId or 0, os.time())
    local entry = Instance.new("StringValue")
    entry.Name = key
    entry.Value = routeId
    entry.Parent = self.routeFolder
end

--\\ BLACKBOARD //------------------------------------------------------------------
local Blackboard = {}
Blackboard.__index = Blackboard

export type EnemyState = {
    player: Player,
    character: Model?,
    humanoid: Humanoid?,
    root: BasePart?,
    distance: number,
    healthRatio: number,
    maxHealth: number,
    hasEvasive: boolean,
    isRagdolled: boolean,
    isLaunched: boolean,
    isBlocking: boolean,
    lastBlockSignal: number,
    lastAttackT: number,
    hostilityScore: number,
    nearWall: boolean,
    ragdollEndT: number,
}

export type AllianceEntry = {
    userId: number,
    lastSignalT: number,
    expiryT: number,
}

export type MyState = {
    character: Model?,
    humanoid: Humanoid?,
    root: BasePart?,
    velocity: Vector3,
    blocking: boolean,
    isRagdolled: boolean,
    isAirborne: boolean,
    hasEvasive: boolean,
    evasiveLockUntil: number,
    comboConfirmed: boolean,
    lastDamageT: number,
}

export type TimerState = {
    cooldowns: { [string]: number },
    dashAvailableT: { [string]: number },
}

export type BlackboardState = {
    localPlayer: Player,
    myState: MyState,
    enemies: { EnemyState },
    alliances: { [number]: AllianceEntry },
    threatMap: { [number]: number },
    lastTarget: EnemyState?,
    timers: TimerState,
    logger: Logger,
}

function Blackboard.new(logger: Logger)
    local localPlayer = Players.LocalPlayer
    local timers: TimerState = {
        cooldowns = {},
        dashAvailableT = {},
    }

    for ability, cd in pairs(Config.Cooldowns) do
        timers.cooldowns[ability] = 0
    end

    timers.dashAvailableT.ForwardDash = 0
    timers.dashAvailableT.BackDash = 0
    timers.dashAvailableT.SideDash = 0

    local self: BlackboardState = {
        localPlayer = localPlayer,
        myState = {
            character = nil,
            humanoid = nil,
            root = nil,
            velocity = Vector3.zero,
            blocking = false,
            isRagdolled = false,
            isAirborne = false,
            hasEvasive = true,
            evasiveLockUntil = 0,
            comboConfirmed = false,
            lastDamageT = 0,
        },
        enemies = {},
        alliances = {},
        threatMap = {},
        lastTarget = nil,
        timers = timers,
        logger = logger,
    }

    return setmetatable(self, Blackboard)
end

function Blackboard:updateCooldown(abilityName: string, duration: number)
    self.timers.cooldowns[abilityName] = tick() + duration
end

function Blackboard:cooldownReady(abilityName: string): boolean
    return tick() >= (self.timers.cooldowns[abilityName] or 0)
end

function Blackboard:setDashAvailable(dashName: string, duration: number)
    self.timers.dashAvailableT[dashName] = tick() + duration
end

function Blackboard:dashReady(dashName: string): boolean
    return tick() >= (self.timers.dashAvailableT[dashName] or 0)
end

function Blackboard:isAlliance(userId: number): boolean
    local entry = self.alliances[userId]
    if not entry then
        return false
    end

    if tick() > entry.expiryT then
        self.alliances[userId] = nil
        return false
    end

    return true
end

function Blackboard:recordAllianceSignal(userId: number)
    local now = tick()
    local entry = self.alliances[userId]
    if entry then
        entry.lastSignalT = now
        entry.expiryT = now + Config.Alliance.decayTime
    else
        self.alliances[userId] = {
            userId = userId,
            lastSignalT = now,
            expiryT = now + Config.Alliance.decayTime,
        }
    end
end

function Blackboard:clearEnemies()
    table.clear(self.enemies)
end

function Blackboard:addEnemy(enemy: EnemyState)
    table.insert(self.enemies, enemy)
end

--\\ INPUT BRIDGE //----------------------------------------------------------------
local Input = {}

local function sendKey(keyCode: Enum.KeyCode, down: boolean)
    VirtualInputManager:SendKeyEvent(down, keyCode, false, game)
end

local function sendMouseButton(button: Enum.UserInputType, down: boolean)
    local x, y = unpack(UserInputService:GetMouseLocation():ToTable())
    VirtualInputManager:SendMouseButtonEvent(x, y, button, down, nil, 0)
end

function Input.press(action: string)
    local binding = Config.ActionBindings[action]
    if not binding then
        warn("No binding for action", action)
        return
    end

    if binding.type == "Key" then
        sendKey(binding.key, true)
        task.wait(Config.InputRepeatDelay)
        sendKey(binding.key, false)
    elseif binding.type == "MouseButton" then
        sendMouseButton(binding.button, true)
        task.wait(Config.InputRepeatDelay)
        sendMouseButton(binding.button, false)
    end
end

function Input.hold(action: string, duration: number)
    local binding = Config.ActionBindings[action]
    if not binding then
        warn("No binding for action", action)
        return
    end

    if binding.type == "Key" then
        sendKey(binding.key, true)
        task.wait(duration)
        sendKey(binding.key, false)
    elseif binding.type == "MouseButton" then
        sendMouseButton(binding.button, true)
        task.wait(duration)
        sendMouseButton(binding.button, false)
    end
end

--\\ ACTIONS //---------------------------------------------------------------------
local Actions = {}
Actions.__index = Actions

export type ActionStep = {
    kind: string,
    action: string?,
    duration: number?,
    metadata: { [string]: any }?,
}

local defaultMetadata = {}

function Actions.new(blackboard: BlackboardState): any
    local self = setmetatable({}, Actions)
    self.blackboard = blackboard
    self.isBusy = false
    self.queue = {}
    self.lastActionT = 0
    return self
end

function Actions:enqueueSequence(sequence: { ActionStep }, routeId: string)
    if self.isBusy then
        return false
    end

    self.isBusy = true

    task.spawn(function()
        self.blackboard.logger:logRoute(
            self.blackboard.lastTarget and self.blackboard.lastTarget.player.UserId or 0,
            routeId
        )

        for _, step in ipairs(sequence) do
            local stepKind = step.kind
            local actionName = step.action
            local duration = step.duration or 0
            local metadata = step.metadata or defaultMetadata

            if stepKind == "press" and actionName then
                Input.press(actionName)
                if Config.Cooldowns[actionName] then
                    self.blackboard:updateCooldown(actionName, Config.Cooldowns[actionName])
                end
            elseif stepKind == "hold" and actionName then
                Input.hold(actionName, duration)
                if Config.Cooldowns[actionName] then
                    self.blackboard:updateCooldown(actionName, Config.Cooldowns[actionName])
                end
            elseif stepKind == "wait" then
                task.wait(duration)
            elseif stepKind == "dash" and actionName then
                Input.press(actionName)
                self.blackboard:setDashAvailable(actionName, Config.Cooldowns[actionName] or 1)
            elseif stepKind == "aim" then
                -- Aim adjustments are perception based; we simply delay to
                -- allow camera / HRP to align, real aim handled externally.
                task.wait(duration)
            end

            task.wait(metadata.gap or 0)
        end

        self.isBusy = false
    end)

    return true
end

function Actions:tryEvasive()
    if not self.blackboard.myState.hasEvasive then
        return false
    end

    if self.blackboard.myState.evasiveLockUntil > tick() then
        return false
    end

    if not self.blackboard:cooldownReady("Evasive") then
        return false
    end

    Input.press("Evasive")
    self.blackboard.myState.hasEvasive = false
    self.blackboard.myState.evasiveLockUntil = tick() + 3
    self.blackboard:updateCooldown("Evasive", 15)
    self.blackboard.logger:logEvent("evasive", {
        reason = "panic",
        time = tick(),
    })
    return true
end

--\\ COMBO LIBRARY //----------------------------------------------------------------
local Combos = {}

local function sequence(label: string, steps: { ActionStep })
    return {
        id = label,
        steps = steps,
    }
end

Combos.TrueCombos = {
    sequence("TC_A", {
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.15 },
        { kind = "press", action = "Shove" },
        { kind = "hold", action = "M1", duration = 0.2 },
        { kind = "dash", action = "SideDash" },
        { kind = "wait", duration = 0.1 },
        { kind = "press", action = "ConsecutivePunches" },
        { kind = "wait", duration = 0.6 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.15 },
        { kind = "press", action = "NormalPunch" },
    }),
    sequence("TC_B", {
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "Shove" },
        { kind = "hold", action = "M1", duration = 0.18 },
        { kind = "dash", action = "SideDash" },
        { kind = "wait", duration = 0.15 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "NormalPunch" },
    }),
    sequence("TC_C", {
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "Shove" },
        { kind = "hold", action = "M1", duration = 0.18 },
        { kind = "dash", action = "SideDash" },
        { kind = "wait", duration = 0.18 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "Uppercut" },
    }),
    sequence("TC_D", {
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "ConsecutivePunches" },
        { kind = "wait", duration = 0.8 },
        { kind = "press", action = "Shove" },
        { kind = "hold", action = "M1", duration = 0.3 },
    }),
}

Combos.EvasiveCounterCombos = {
    sequence("ECC_A", {
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "Uppercut" },
        { kind = "wait", duration = 0.35 },
        { kind = "dash", action = "SideDash" },
        { kind = "wait", duration = 0.15 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "ConsecutivePunches" },
        { kind = "wait", duration = 0.8 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "Shove" },
        { kind = "hold", action = "M1", duration = 0.2 },
        { kind = "dash", action = "SideDash" },
        { kind = "wait", duration = 0.1 },
        { kind = "press", action = "NormalPunch" },
    }),
    sequence("ECC_B", {
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.12 },
        { kind = "press", action = "ConsecutivePunches" },
        { kind = "wait", duration = 0.75 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.1 },
        { kind = "press", action = "M1" },
        { kind = "wait", duration = 0.2 }, -- mini uppercut delay
        { kind = "press", action = "NormalPunch" },
    }),
}

function Combos.chooseRoute(enemy: EnemyState)
    if not enemy then
        return nil
    end

    if not enemy.hasEvasive then
        return Combos.EvasiveCounterCombos[1]
    end

    return Combos.TrueCombos[1]
end

function Combos.chooseFallbackRoute(enemy: EnemyState)
    if not enemy then
        return nil
    end

    if not enemy.hasEvasive then
        return Combos.EvasiveCounterCombos[2]
    end

    return Combos.TrueCombos[2]
end

--\\ PERCEPTION //------------------------------------------------------------------
local Perception = {}

local function detectBlockFromAnimator(animator: Animator?): boolean
    if not animator then
        return false
    end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if string.find(string.lower(track.Name), "block") then
            return true
        end
    end

    return false
end

local function detectRagdollFromHumanoid(humanoid: Humanoid?): (boolean, boolean)
    if not humanoid then
        return false, false
    end

    local state = humanoid:GetState()
    local ragdollStates = {
        Enum.HumanoidStateType.Ragdoll,
        Enum.HumanoidStateType.Physics,
        Enum.HumanoidStateType.FallingDown,
    }

    for _, ragdollState in ipairs(ragdollStates) do
        if state == ragdollState then
            return true, state == Enum.HumanoidStateType.FallingDown
        end
    end

    return false, false
end

function Perception.senseWorld(blackboard: BlackboardState, dt: number)
    local localPlayer = blackboard.localPlayer
    if not localPlayer then
        return
    end

    local myCharacter = localPlayer.Character
    local myHumanoid = myCharacter and myCharacter:FindFirstChildOfClass("Humanoid")
    local myRoot = myCharacter and myCharacter:FindFirstChild("HumanoidRootPart")

    blackboard.myState.character = myCharacter
    blackboard.myState.humanoid = myHumanoid
    blackboard.myState.root = myRoot
    blackboard.myState.velocity = myRoot and myRoot.Velocity or Vector3.zero

    if myHumanoid then
        blackboard.myState.blocking = detectBlockFromAnimator(myHumanoid:FindFirstChildOfClass("Animator"))
        local ragdoll, falling = detectRagdollFromHumanoid(myHumanoid)
        blackboard.myState.isRagdolled = ragdoll
        blackboard.myState.isAirborne = falling or (myRoot and math.abs(myRoot.Velocity.Y) > 6) or false
    end

    if blackboard.myState.evasiveLockUntil < tick() and not blackboard.myState.hasEvasive then
        blackboard.myState.hasEvasive = true
    end

    blackboard:clearEnemies()

    local now = tick()
    local myPosition = myRoot and myRoot.Position or Vector3.zero

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            if humanoid and rootPart and humanoid.Health > 0 then
                local distance = (rootPart.Position - myPosition).Magnitude
                local healthRatio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
                local ragdoll, falling = detectRagdollFromHumanoid(humanoid)
                local blocking = detectBlockFromAnimator(humanoid:FindFirstChildOfClass("Animator"))
                local nearWall = false

                local rayOrigin = rootPart.Position
                local rayDirection = rootPart.CFrame.LookVector * 8
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = { character, myCharacter }
                rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                local rayResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)
                if rayResult and rayResult.Instance and rayResult.Instance.CanCollide then
                    nearWall = true
                end

                local hasEvasive = true
                if blackboard.threatMap[player.UserId] then
                    hasEvasive = blackboard.threatMap[player.UserId] > now
                end

                local enemyState: EnemyState = {
                    player = player,
                    character = character,
                    humanoid = humanoid,
                    root = rootPart,
                    distance = distance,
                    healthRatio = healthRatio,
                    maxHealth = humanoid.MaxHealth,
                    hasEvasive = hasEvasive,
                    isRagdolled = ragdoll,
                    isLaunched = falling,
                    isBlocking = blocking,
                    lastBlockSignal = 0,
                    lastAttackT = 0,
                    hostilityScore = 0,
                    nearWall = nearWall,
                    ragdollEndT = ragdoll and (now + 0.5) or now,
                }

                blackboard:addEnemy(enemyState)
            end
        end
    end
end

function Perception.updateThreatMap(blackboard: BlackboardState, dt: number)
    for _, enemy in ipairs(blackboard.enemies) do
        local userId = enemy.player.UserId
        local record = blackboard.threatMap[userId]
        if not record then
            blackboard.threatMap[userId] = tick() + 8
        end

        local isFriend = blackboard:isAlliance(userId)
        if isFriend then
            enemy.hostilityScore = -1
        else
            enemy.hostilityScore = 1
        end

        if enemy.isBlocking then
            enemy.lastBlockSignal = tick()
        end
    end
end

--\\ DECISION TREE //----------------------------------------------------------------
local Decisions = {}

function Decisions.selectTarget(blackboard: BlackboardState)
    local bestEnemy: EnemyState? = nil
    local bestScore = -math.huge
    local myRoot = blackboard.myState.root
    if not myRoot then
        return nil
    end

    local enemyCount = 0
    for _, enemy in ipairs(blackboard.enemies) do
        if enemyCount >= Config.MaxTargetsConsidered then
            break
        end
        enemyCount += 1

        local score = 0
        score += (1 - enemy.healthRatio) * Config.UtilityWeights.lowHealthBonus
        score += (1 - math.clamp(enemy.distance / 50, 0, 1)) * Config.UtilityWeights.proximityBonus
        if not enemy.hasEvasive then
            score += Config.UtilityWeights.noEvasiveBonus
        end
        if enemy.nearWall then
            score += Config.UtilityWeights.wallBonus
        end

        if blackboard:isAlliance(enemy.player.UserId) then
            score += Config.UtilityWeights.hostilityPenalty * 2
        end

        local neighbors = 0
        for _, other in ipairs(blackboard.enemies) do
            if other ~= enemy and (other.distance - enemy.distance) < 8 then
                neighbors += 1
            end
        end
        score += neighbors * Config.UtilityWeights.crowdPenalty

        if score > bestScore then
            bestScore = score
            bestEnemy = enemy
        end
    end

    blackboard.lastTarget = bestEnemy
    return bestEnemy
end

function Decisions.shouldEvasive(blackboard: BlackboardState)
    if not blackboard.myState.humanoid then
        return false
    end

    if blackboard.myState.isRagdolled then
        return true
    end

    if blackboard.myState.isAirborne and blackboard.myState.humanoid.Health < 35 then
        return true
    end

    return false
end

function Decisions.haveConfirm(blackboard: BlackboardState, enemy: EnemyState)
    if not enemy or not blackboard.myState.root then
        return false
    end

    if enemy.isRagdolled then
        return true
    end

    if enemy.distance < Config.ComboConfirmDistance and enemy.isBlocking == false and enemy.isLaunched then
        return true
    end

    return false
end

function Decisions.chooseRoute(blackboard: BlackboardState, enemy: EnemyState)
    local route = Combos.chooseRoute(enemy)
    if route then
        return route
    end
    return Combos.chooseFallbackRoute(enemy)
end

function Decisions.neutralPlan(blackboard: BlackboardState, enemy: EnemyState?)
    if not enemy then
        return
    end

    if enemy.distance > Config.MaxNeutralSpacing then
        Input.press("ForwardDash")
    elseif enemy.distance < Config.MinNeutralSpacing then
        Input.press("BackDash")
    else
        Input.press("Block")
    end
end

function Decisions.updateAllianceState(blackboard: BlackboardState)
    local now = tick()
    for _, enemy in ipairs(blackboard.enemies) do
        local userId = enemy.player.UserId
        if blackboard:isAlliance(userId) then
            if now - enemy.lastBlockSignal < Config.Alliance.handshakeWindow then
                blackboard:recordAllianceSignal(userId)
            end
        else
            if now - enemy.lastBlockSignal < Config.Alliance.handshakeWindow then
                local entry = blackboard.alliances[userId]
                if not entry then
                    blackboard.alliances[userId] = {
                        userId = userId,
                        lastSignalT = now,
                        expiryT = now + Config.Alliance.gracePeriod,
                    }
                    blackboard.logger:logEvent("alliance_attempt", {
                        userId = userId,
                        time = now,
                    })
                elseif now - entry.lastSignalT < Config.Alliance.handshakeWindow then
                    entry.expiryT = now + Config.Alliance.decayTime
                    blackboard.logger:increment("alliancesMade", 1)
                    blackboard.logger:logEvent("alliance", {
                        userId = userId,
                        time = now,
                    })
                end
            end
        end
    end
end

function Decisions.tick(blackboard: BlackboardState, actions: Actions, dt: number)
    if not blackboard.myState.character then
        return
    end

    Perception.senseWorld(blackboard, dt)
    Perception.updateThreatMap(blackboard, dt)
    Decisions.updateAllianceState(blackboard)

    local enemy = Decisions.selectTarget(blackboard)
    if not enemy then
        return
    end

    if Decisions.shouldEvasive(blackboard) then
        if actions:tryEvasive() then
            blackboard.logger:logEvent("evasive_used", { reason = "defensive" })
        end
        return
    end

    if Decisions.haveConfirm(blackboard, enemy) and not actions.isBusy then
        local route = Decisions.chooseRoute(blackboard, enemy)
        if route then
            if actions:enqueueSequence(route.steps, route.id) then
                blackboard.logger:logEvent("combo_start", {
                    route = route.id,
                    target = enemy.player.UserId,
                })
            end
            return
        end
    end

    Decisions.neutralPlan(blackboard, enemy)
end

--\\ MAIN LOOP //-------------------------------------------------------------------
local logger = Logger.new()
logger:startSession()

local blackboard = Blackboard.new(logger)
local actions = Actions.new(blackboard)

local lastTick = tick()
RunService.Heartbeat:Connect(function()
    local now = tick()
    local dt = now - lastTick
    lastTick = now

    Decisions.tick(blackboard, actions, dt)
end)

return {
    Config = Config,
    Logger = Logger,
    Blackboard = Blackboard,
    Perception = Perception,
    Decisions = Decisions,
    Combos = Combos,
    Actions = Actions,
}
