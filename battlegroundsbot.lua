--!strict
--[[
    JoeHub Battlegrounds Bot - Adaptive Combat Controller

    Rewritten to resolve merge conflicts by replacing the entire file.
    Implements aggressive pursuit, combo execution, adaptive blocking,
    and evasive movement that learns from enemy animations.  Uses
    workspace.Live attributes to prioritise the last hitter and respects
    humanoid FallingDown state by suspending aim-lock behaviour.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

export type EnemyStats = {
    aggression: number,
    block: number,
    mobility: number,
    lastAttackTime: number?,
    lastBlockTime: number?,
    lastDashTime: number?,
    recentDamageTime: number?,
    character: Model?,
    humanoid: Humanoid?,
    connections: { RBXScriptConnection },
}

local Config = {
    ComboConfirmDistance = 16,
    NeutralSpacingMin = 10,
    NeutralSpacingMax = 22,
    TargetRefreshRate = 0.25,
    BlockReactionRange = 18,
    BlockReactionWindow = 0.65,
    CounterWindow = 0.8,
    DashCooldown = 1.0,
    StrafeInterval = 0.75,
    StrafeHold = 0.18,
    MovePulseCooldown = 0.25,
    InputTap = 0.045,
    InputHoldShort = 0.14,
    InputHoldMedium = 0.22,
    BehaviourDecay = 0.45,
    TargetMaxDistance = 120,
    LastHitterBonus = 25,
    AggressionWeight = 2.4,
    BlockWeight = 1.7,
    MobilityWeight = 1.2,
    BlockPunishDelay = 0.6,
    DataFolder = "battlegroundbot",
    DirectionBindings = {
        Forward = Enum.KeyCode.W,
        Backward = Enum.KeyCode.S,
        Left = Enum.KeyCode.A,
        Right = Enum.KeyCode.D,
    },
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
}

local function makeSeededRandom()
    local seed = tick() * 1000
    return Random.new(math.floor(seed % 1e9))
end

local rng = makeSeededRandom()

local function safeMakeFolder(path: string)
    if not makefolder or not isfolder then
        return
    end
    if not isfolder(path) then
        pcall(makefolder, path)
    end
end

local function pressBinding(name: string, hold: number?)
    local binding = Config.ActionBindings[name]
    if not binding then
        return
    end

    local holdTime = hold or Config.InputTap
    if binding.type == "Key" then
        VirtualInputManager:SendKeyEvent(true, binding.key, false, game)
        task.wait(holdTime)
        VirtualInputManager:SendKeyEvent(false, binding.key, false, game)
    elseif binding.type == "MouseButton" then
        VirtualInputManager:SendMouseButtonEvent(0, 0, binding.button, true, game, 0)
        task.wait(holdTime)
        VirtualInputManager:SendMouseButtonEvent(0, 0, binding.button, false, game, 0)
    end
end

local function pressKeyPulse(keyCode: Enum.KeyCode, hold: number)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    task.delay(hold, function()
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function normalize(v: Vector3): Vector3
    if v.Magnitude < 1e-3 then
        return Vector3.zero
    end
    return v.Unit
end

local ComboLibrary = {
    {
        id = "dash_pressure",
        evaluate = function(stats: EnemyStats)
            return 1 + (stats.aggression + stats.mobility * 0.4)
        end,
        steps = {
            { kind = "Dash", direction = "Forward" },
            { kind = "Action", name = "M1" },
            { kind = "Action", name = "M1" },
            { kind = "Action", name = "Uppercut", hold = Config.InputHoldShort },
            { kind = "Action", name = "M1" },
        },
    },
    {
        id = "guard_breaker",
        evaluate = function(stats: EnemyStats)
            return 1 + (stats.block * 1.2) + math.max(0, 1 - stats.aggression * 0.2)
        end,
        steps = {
            { kind = "Move", direction = "Left", duration = 0.2 },
            { kind = "Block", duration = 0.25 },
            { kind = "Action", name = "Shove" },
            { kind = "Action", name = "NormalPunch", hold = Config.InputHoldMedium },
            { kind = "Action", name = "M1" },
        },
    },
    {
        id = "side_mix",
        evaluate = function(stats: EnemyStats)
            return 1 + math.max(0.6, 1 - stats.block * 0.5) + stats.mobility * 0.3
        end,
        steps = {
            { kind = "Dash", direction = "Side" },
            { kind = "Action", name = "M1" },
            { kind = "Block", duration = 0.18 },
            { kind = "Action", name = "M1" },
            { kind = "Action", name = "Uppercut" },
        },
    },
    {
        id = "whiff_punish",
        evaluate = function(stats: EnemyStats)
            return 1 + stats.aggression * 0.8 + stats.mobility * 0.6
        end,
        steps = {
            { kind = "Wait", duration = 0.08 },
            { kind = "Dash", direction = "Forward" },
            { kind = "Action", name = "M1" },
            { kind = "Action", name = "ConsecutivePunches", hold = Config.InputHoldMedium },
            { kind = "Dash", direction = "Back" },
        },
    },
}

local BotController = {}
BotController.__index = BotController

function BotController.new()
    local self = setmetatable({}, BotController)
    self.character = nil
    self.rootPart = nil
    self.humanoid = nil
    self.lastHealth = nil
    self.blockHeld = false
    self.blockForced = false
    self.blockReactiveWanted = false
    self.movementCooldowns = {}
    self.nextStrafeTime = 0
    self.nextStrafeSide = "Left"
    self.nextDashTime = 0
    self.comboThread = nil
    self.comboActive = false
    self.lastComboTime = 0
    self.targetPlayer = nil
    self.targetHumanoid = nil
    self.targetRoot = nil
    self.targetRefreshClock = 0
    self.enemyStats = {}
    self.wasHitTime = 0
    self.lastHitterName = nil
    self.liveFolder = workspace:FindFirstChild("Live")
    self.connections = {}
    self:bootstrap()
    return self
end

function BotController:bootstrap()
    safeMakeFolder(Config.DataFolder)

    self:bindCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
    table.insert(self.connections, LocalPlayer.CharacterAdded:Connect(function(char)
        self:bindCharacter(char)
    end))

    table.insert(self.connections, RunService.RenderStepped:Connect(function(dt)
        self:update(dt)
    end))

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            self:ensureEnemyTracked(player)
        end
    end
    table.insert(self.connections, Players.PlayerAdded:Connect(function(player)
        if player ~= LocalPlayer then
            self:ensureEnemyTracked(player)
        end
    end))
    table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
        local stats = self.enemyStats[player]
        if stats then
            self:cleanupEnemy(player)
        end
    end))
end

function BotController:bindCharacter(character: Model)
    self.character = character
    self.humanoid = character:WaitForChild("Humanoid") :: Humanoid
    self.rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
    self.lastHealth = self.humanoid.Health

    for _, conn in ipairs(self.characterConnections or {}) do
        conn:Disconnect()
    end
    self.characterConnections = {}

    table.insert(self.characterConnections, self.humanoid.Died:Connect(function()
        self.comboActive = false
        self.comboThread = nil
        self:SetBlockForced(false)
    end))

    table.insert(self.characterConnections, self.humanoid.HealthChanged:Connect(function(newHealth)
        if self.lastHealth and newHealth < self.lastHealth then
            self.wasHitTime = tick()
            local lastHitter = self:getLastHitterName()
            if lastHitter then
                self.lastHitterName = lastHitter
                local stats = self:getEnemyStatsByName(lastHitter)
                if stats then
                    stats.recentDamageTime = tick()
                    stats.aggression = stats.aggression + 0.6
                end
            end
        end
        self.lastHealth = newHealth
    end))
end

function BotController:getLastHitterName(): string?
    if not self.liveFolder then
        self.liveFolder = workspace:FindFirstChild("Live")
    end
    if not self.liveFolder then
        return nil
    end
    local selfModel = self.liveFolder:FindFirstChild(LocalPlayer.Name)
    if not selfModel then
        return nil
    end
    local attr = selfModel:GetAttribute("last hit")
    if typeof(attr) == "string" and attr ~= "" then
        return attr
    end
    return nil
end

function BotController:getEnemyStatsByName(name: string): EnemyStats?
    for player, stats in pairs(self.enemyStats) do
        if player.Name == name then
            return stats
        end
    end
    return nil
end

function BotController:ensureEnemyTracked(player: Player)
    if self.enemyStats[player] then
        return
    end

    local stats: EnemyStats = {
        aggression = 0,
        block = 0,
        mobility = 0,
        lastAttackTime = nil,
        lastBlockTime = nil,
        lastDashTime = nil,
        recentDamageTime = nil,
        character = nil,
        humanoid = nil,
        connections = {},
    }
    self.enemyStats[player] = stats

    local function onCharacter(char: Model)
        self:hookEnemyCharacter(player, stats, char)
    end

    if player.Character then
        onCharacter(player.Character)
    end

    table.insert(stats.connections, player.CharacterAdded:Connect(onCharacter))
    table.insert(stats.connections, player.CharacterRemoving:Connect(function()
        stats.character = nil
        stats.humanoid = nil
    end))
end

function BotController:cleanupEnemy(player: Player)
    local stats = self.enemyStats[player]
    if not stats then
        return
    end
    for _, conn in ipairs(stats.connections) do
        conn:Disconnect()
    end
    if stats.character then
        self:disconnectEnemyCharacter(stats)
    end
    self.enemyStats[player] = nil
end

function BotController:disconnectEnemyCharacter(stats: EnemyStats)
    if stats.character and stats.character:IsDescendantOf(workspace) then
        -- nothing special currently
    end
    for _, conn in ipairs(stats.connections) do
        if conn.Connected then
            -- keep player-level connections intact
        end
    end
end

function BotController:hookEnemyCharacter(player: Player, stats: EnemyStats, character: Model)
    stats.character = character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    stats.humanoid = humanoid
    stats.lastAttackTime = nil
    stats.lastBlockTime = nil
    stats.lastDashTime = nil

    if not humanoid then
        return
    end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    local function categoriseAnimation(track: AnimationTrack)
        local name = string.lower(track.Name or "")
        if track.Animation then
            local animName = (track.Animation.Name or ""):lower()
            if animName ~= "" then
                name = animName
            else
                local animId = track.Animation.AnimationId
                if animId then
                    name = name .. " " .. animId:lower()
                end
            end
        end

        local now = tick()
        if string.find(name, "punch") or string.find(name, "attack") or string.find(name, "m1") or string.find(name, "combo") then
            stats.lastAttackTime = now
            stats.aggression = stats.aggression + 1
        elseif string.find(name, "block") or string.find(name, "guard") then
            stats.lastBlockTime = now
            stats.block = stats.block + 1
        elseif string.find(name, "dash") or string.find(name, "evade") or string.find(name, "step") then
            stats.lastDashTime = now
            stats.mobility = stats.mobility + 1
        end
    end

    table.insert(stats.connections, animator.AnimationPlayed:Connect(function(track)
        categoriseAnimation(track)
    end))

    table.insert(stats.connections, humanoid.Died:Connect(function()
        stats.character = nil
        stats.humanoid = nil
    end))
end

function BotController:update(dt: number)
    if not self.humanoid or self.humanoid.Health <= 0 then
        return
    end

    self:decayEnemyStats(dt)
    self:updateLastHitter()
    self:updateTarget(dt)

    if not self.targetRoot or not self.targetHumanoid or self.targetHumanoid.Health <= 0 then
        self.blockReactiveWanted = false
        self:applyBlockState()
        return
    end

    self:faceTarget(self.targetRoot)
    local distance = (self.targetRoot.Position - self.rootPart.Position).Magnitude

    if not self.comboActive then
        self:maintainSpacing(distance)
        self:reactiveDefense(distance)
        if distance <= Config.ComboConfirmDistance then
            self:attemptCombo(distance)
        end
    end
end

function BotController:updateLastHitter()
    local hitter = self:getLastHitterName()
    if hitter then
        self.lastHitterName = hitter
    end
end

function BotController:decayEnemyStats(dt: number)
    local decay = Config.BehaviourDecay * dt
    for _, stats in pairs(self.enemyStats) do
        stats.aggression = math.max(0, stats.aggression - decay)
        stats.block = math.max(0, stats.block - decay * 0.8)
        stats.mobility = math.max(0, stats.mobility - decay * 0.6)
    end
end

function BotController:updateTarget(dt: number)
    self.targetRefreshClock -= dt
    if self.targetRefreshClock > 0 then
        return
    end
    self.targetRefreshClock = Config.TargetRefreshRate

    local bestPlayer: Player? = nil
    local bestHumanoid: Humanoid? = nil
    local bestRoot: BasePart? = nil
    local bestScore = -math.huge
    local now = tick()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local stats = self.enemyStats[player]
            if not stats then
                self:ensureEnemyTracked(player)
                stats = self.enemyStats[player]
            end
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if humanoid and humanoid.Health > 0 and root then
                local distance = (root.Position - self.rootPart.Position).Magnitude
                if distance <= Config.TargetMaxDistance then
                    local score = Config.TargetMaxDistance - distance
                    if player.Name == self.lastHitterName then
                        score = score + Config.LastHitterBonus
                    end
                    if stats then
                        score = score + stats.aggression * Config.AggressionWeight
                        score = score - stats.block * Config.BlockWeight
                        score = score + stats.mobility * Config.MobilityWeight
                        if stats.recentDamageTime and now - stats.recentDamageTime < 3 then
                            score = score + 8
                        end
                    end
                    if score > bestScore then
                        bestScore = score
                        bestPlayer = player
                        bestHumanoid = humanoid
                        bestRoot = root
                    end
                end
            end
        end
    end

    self.targetPlayer = bestPlayer
    self.targetHumanoid = bestHumanoid
    self.targetRoot = bestRoot
end

function BotController:faceTarget(targetRoot: BasePart)
    if not self.rootPart then
        return
    end
    if self.humanoid:GetState() == Enum.HumanoidStateType.FallingDown then
        return
    end
    local myPos = self.rootPart.Position
    local targetPos = targetRoot.Position
    local lookVector = normalize(Vector3.new(targetPos.X, myPos.Y, targetPos.Z) - myPos)
    if lookVector == Vector3.zero then
        return
    end
    local newCFrame = CFrame.lookAt(myPos, myPos + lookVector)
    self.rootPart.CFrame = newCFrame
end

function BotController:maintainSpacing(distance: number)
    local now = tick()
    if distance > Config.NeutralSpacingMax then
        self:pulseMovement("Forward", Config.InputHoldShort)
        if distance > Config.NeutralSpacingMax + 8 then
            self:dash("Forward")
        end
    elseif distance < Config.NeutralSpacingMin then
        self:pulseMovement("Backward", Config.InputHoldShort)
        if distance < Config.NeutralSpacingMin * 0.6 then
            self:dash("Back")
        end
    else
        if now >= self.nextStrafeTime then
            self:pulseMovement(self.nextStrafeSide, Config.StrafeHold)
            self.nextStrafeSide = (self.nextStrafeSide == "Left") and "Right" or "Left"
            self.nextStrafeTime = now + Config.StrafeInterval
        end
    end
end

function BotController:pulseMovement(direction: string, duration: number)
    local keyCode = Config.DirectionBindings[direction]
    if not keyCode then
        return
    end

    local now = tick()
    local cooldown = self.movementCooldowns[keyCode]
    if cooldown and cooldown > now then
        return
    end
    self.movementCooldowns[keyCode] = now + Config.MovePulseCooldown
    pressKeyPulse(keyCode, duration)
end

function BotController:dash(direction: string)
    local now = tick()
    if now < self.nextDashTime then
        return
    end
    if direction == "Forward" then
        pressBinding("ForwardDash")
    elseif direction == "Back" then
        pressBinding("BackDash")
    elseif direction == "Side" then
        local lateral = rng:NextNumber() > 0.5 and Enum.KeyCode.A or Enum.KeyCode.D
        pressBinding("SideDash")
        pressKeyPulse(lateral, Config.InputHoldShort)
    elseif direction == "Escape" then
        pressBinding("Evasive")
    end
    self.nextDashTime = now + Config.DashCooldown
end

function BotController:reactiveDefense(distance: number)
    if self.blockForced then
        return
    end

    local stats = self.targetPlayer and self.enemyStats[self.targetPlayer]
    local now = tick()
    local attackThreat = false
    local heavyThreat = false

    if stats then
        if stats.lastAttackTime and now - stats.lastAttackTime < Config.BlockReactionWindow then
            attackThreat = true
        end
        if stats.recentDamageTime and now - stats.recentDamageTime < Config.CounterWindow then
            heavyThreat = true
        end
    end
    if now - self.wasHitTime < Config.CounterWindow * 0.8 then
        attackThreat = true
    end

    local shouldBlock = (attackThreat or heavyThreat) and distance < Config.BlockReactionRange
    self.blockReactiveWanted = shouldBlock
    self:applyBlockState()

    if shouldBlock and stats and stats.mobility > 1.5 and stats.lastDashTime and now - stats.lastDashTime < 0.6 then
        self:dash("Side")
    end
end

function BotController:applyBlockState()
    local binding = Config.ActionBindings.Block
    if not binding or binding.type ~= "Key" then
        return
    end
    local desired = self.blockForced or self.blockReactiveWanted
    if desired == self.blockHeld then
        return
    end
    self.blockHeld = desired
    VirtualInputManager:SendKeyEvent(desired, binding.key, false, game)
end

function BotController:SetBlockForced(enabled: boolean)
    self.blockForced = enabled
    self:applyBlockState()
end

function BotController:forceBlock(duration: number)
    if duration <= 0 then
        return
    end
    self:SetBlockForced(true)
    task.wait(duration)
    self:SetBlockForced(false)
end

function BotController:attemptCombo(distance: number)
    if self.comboActive then
        return
    end
    local now = tick()
    if now - self.lastComboTime < 1.2 then
        return
    end

    local stats = self.targetPlayer and self.enemyStats[self.targetPlayer]
    if stats and stats.lastBlockTime and now - stats.lastBlockTime < Config.BlockPunishDelay then
        return
    end

    local bestCombo = nil
    local bestScore = -math.huge
    for _, combo in ipairs(ComboLibrary) do
        local weight = 1
        if stats then
            weight = combo.evaluate(stats)
        end
        weight = weight + rng:NextNumber() * 0.5
        if weight > bestScore then
            bestScore = weight
            bestCombo = combo
        end
    end

    if bestCombo then
        self.comboActive = true
        self.comboThread = task.spawn(function()
            self:runCombo(bestCombo)
        end)
        self.lastComboTime = now
    end
end

function BotController:runCombo(combo)
    local targetRoot = self.targetRoot
    for _, step in ipairs(combo.steps) do
        if not self.targetRoot or not self.targetHumanoid or self.targetHumanoid.Health <= 0 then
            break
        end
        self:executeStep(step)
    end
    self.comboActive = false
    self.comboThread = nil
    self.blockReactiveWanted = false
    self:applyBlockState()
end

function BotController:executeStep(step)
    if step.kind == "Action" then
        pressBinding(step.name, step.hold)
    elseif step.kind == "Dash" then
        self:dash(step.direction)
        task.wait(0.05)
    elseif step.kind == "Move" then
        self:pulseMovement(step.direction, step.duration or Config.InputHoldShort)
        task.wait(step.duration or Config.InputHoldShort)
    elseif step.kind == "Block" then
        self:forceBlock(step.duration or Config.InputHoldShort)
    elseif step.kind == "Wait" then
        task.wait(step.duration or 0.1)
    end
end

local bot = BotController.new()

return bot
