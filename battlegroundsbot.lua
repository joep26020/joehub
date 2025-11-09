--!strict
-- Battlegrounds Aggro Bot — WASD chase + adaptive dash AI with offensive preference
-- Rewritten to match keep-orientation dash directives and record AI training data
-- containing distance-to-target information.

--------------------------- SERVICES & SINGLETONS -----------------------------
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local VIM         = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()

------------------------------- CONFIGURATION ---------------------------------
local CFG = {
    LoopGap        = 0.85,             -- seconds between tactical decisions
    Aggro = {
        ChaseHold     = 0.42,          -- how long to hold W when chasing
        StrafeHold    = 0.30,          -- how long to hold a strafe tap
        RepositionCD  = 0.55,          -- cooldown between aggro reposition bursts
    },
    Cooldown = { FDash = 9.5, BDash = 9.5, Side = 1.6 },
    Dash = {
        KeyQ            = Enum.KeyCode.Q,
        HoldQ           = 0.12,
        RefaceTail      = 0.50,
        OrbitTrigger    = 2.0,
        OrbitDuration   = 0.40,
        BackClose       = 4.0,
        SideOffRelock   = 3.5,
        PreEndBackFace  = 0.25,
        FDashWindow     = 0.68,
        BDashWindow     = 1.25,
    },
    HP = {
        DefensiveRatio  = 0.32,        -- go defensive if our HP ratio <= this
        PanicDelta      = -45,         -- if (myHP - enemyHP) <= this, defensive bias
    },
    RewardWeights = { dealt = 1.2, taken = 1.0, distGain = 0.35 },
    DataFile      = "bgbot_dash_ai.jsonl",
    Epsilon       = 0.18,              -- exploration chance
    SideBias      = 0.15,              -- additive bias for offensive side dash
}

------------------------------- STATE HOLDERS ---------------------------------
local char : Model? = nil
local hum  : Humanoid? = nil
local hrp  : BasePart? = nil
local cam  : Camera? = workspace.CurrentCamera

local running    = false
local busyOrient = false
local lastTarget : BasePart? = nil
local lastHumanoid : Humanoid? = nil

local lastFDash  = -1e9
local lastBDash  = -1e9
local lastSide   = -1e9
local lastAggroMove = -1e9

local trials = {
    active = nil :: {
        move: string,
        style: string,
        startT: number,
        dist0: number,
        myHP0: number,
        tgtHP0: number,
        enemyHum: Humanoid?,
        enemyHRP: BasePart?,
    }?
}

local moveStats = {
    fdash    = {count = 0, reward = 0.0, avg = 0.0},
    bdash    = {count = 0, reward = 0.0, avg = 0.0},
    sidedash = {count = 0, reward = 0.0, avg = 0.0},
}

----------------------------- GENERIC UTILITIES -------------------------------
local function now() return os.clock() end

local function ensureCharacter()
    if char and hum and hrp then return end
    char = LP.Character or LP.CharacterAdded:Wait()
    hum  = char:WaitForChild("Humanoid") :: Humanoid
    hrp  = char:WaitForChild("HumanoidRootPart") :: BasePart
    cam  = workspace.CurrentCamera
    if hum then hum.AutoRotate = false end
end

local function flat(v: Vector3) return Vector3.new(v.X, 0, v.Z) end

local function press(key: Enum.KeyCode, down: boolean)
    VIM:SendKeyEvent(down, key, false, game)
end

local function tapKey(key: Enum.KeyCode, hold: number)
    press(key, true)
    task.delay(hold, function() press(key, false) end)
end

local function holdQ(duration: number?)
    press(CFG.Dash.KeyQ, true)
    task.wait(duration or CFG.Dash.HoldQ)
    press(CFG.Dash.KeyQ, false)
end

local function alignCameraForward()
    if not (cam and hrp) then return end
    local cp = cam.CFrame.Position
    local look = flat(hrp.CFrame.LookVector)
    if look.Magnitude < 1e-3 then return end
    look = look.Unit
    cam.CFrame = CFrame.new(cp, Vector3.new(cp.X + look.X, cp.Y, cp.Z + look.Z))
end

local function faceTowards(pos: Vector3)
    if not hrp then return end
    local here = hrp.Position
    local to = flat(pos - here)
    if to.Magnitude < 1e-3 then return end
    hrp.CFrame = CFrame.lookAt(here, here + to.Unit)
    alignCameraForward()
end

local function faceAway(pos: Vector3)
    if not hrp then return end
    local here = hrp.Position
    local to = flat(pos - here)
    if to.Magnitude < 1e-3 then return end
    hrp.CFrame = CFrame.lookAt(here, here - to.Unit)
    alignCameraForward()
end

local function facePerpendicular(toUnit: Vector3, clockwise: boolean)
    if not hrp then return end
    local perp = clockwise and Vector3.new(toUnit.Z, 0, -toUnit.X) or Vector3.new(-toUnit.Z, 0, toUnit.X)
    hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + perp.Unit)
    alignCameraForward()
end

local function nearestEnemy()
    ensureCharacter()
    if not hrp then return nil end
    local best : BasePart? = nil
    local bestHum : Humanoid? = nil
    local bestDist = math.huge
    local origin = hrp.Position
    local live = workspace:FindFirstChild("Live")
    if live then
        for _, model in ipairs(live:GetChildren()) do
            if model:IsA("Model") and model.Name ~= LP.Name then
                local h = model:FindFirstChildOfClass("Humanoid")
                local p = model:FindFirstChild("HumanoidRootPart")
                if h and p and h.Health > 0 then
                    local d = (p.Position - origin).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = p
                        bestHum = h
                    end
                end
            end
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local h = plr.Character:FindFirstChildOfClass("Humanoid")
                local p = plr.Character:FindFirstChild("HumanoidRootPart")
                if h and p and h.Health > 0 then
                    local d = (p.Position - origin).Magnitude
                    if d < bestDist then
                        bestDist = d
                        best = p
                        bestHum = h
                    end
                end
            end
        end
    end
    if best then
        return {
            hrp = best,
            humanoid = bestHum,
            dist = bestDist,
        }
    end
    return nil
end

local function canUseDash(which: string)
    local t = now()
    if which == "fdash" then
        return (t - lastFDash) >= CFG.Cooldown.FDash
    elseif which == "bdash" then
        return (t - lastBDash) >= CFG.Cooldown.BDash
    else
        return (t - lastSide) >= CFG.Cooldown.Side
    end
end

local function markDash(which: string)
    local t = now()
    if which == "fdash" then
        lastFDash = t
    elseif which == "bdash" then
        lastBDash = t
    else
        lastSide = t
    end
end

------------------------------ TRIAL MANAGEMENT -------------------------------
local function startTrial(move: string, style: string, target)
    ensureCharacter()
    if trials.active then finishTrial() end
    if not (hum and hrp and target and target.humanoid and target.hrp) then return end
    trials.active = {
        move = move,
        style = style,
        startT = now(),
        dist0 = (target.hrp.Position - hrp.Position).Magnitude,
        myHP0 = hum.Health,
        tgtHP0 = target.humanoid.Health,
        enemyHum = target.humanoid,
        enemyHRP = target.hrp,
    }
end

local function appendData(row)
    if not (appendfile or writefile) then return end
    local json = HttpService:JSONEncode(row)
    if appendfile then
        local ok = pcall(appendfile, CFG.DataFile, json .. "\n")
        if ok then return end
    end
    if writefile then
        local existing = ""
        if readfile and isfile and isfile(CFG.DataFile) then
            local ok, res = pcall(readfile, CFG.DataFile)
            if ok then existing = res end
        end
        pcall(writefile, CFG.DataFile, (existing ~= "" and (existing .. "\n" .. json .. "\n") or (json .. "\n")))
    end
end

local function finishTrial()
    ensureCharacter()
    local t = trials.active
    trials.active = nil
    if not t then return end
    if not (hum and hrp) then return end
    local enemyHum = t.enemyHum
    local enemyHRP = t.enemyHRP
    local myHP1 = hum.Health
    local tgtHP1 = enemyHum and enemyHum.Health or 0
    local dist1 = enemyHRP and (enemyHRP.Position - hrp.Position).Magnitude or t.dist0

    local dealt = math.max(0, t.tgtHP0 - tgtHP1)
    local taken = math.max(0, t.myHP0 - myHP1)
    local distGain = math.max(0, t.dist0 - dist1)
    local reward = CFG.RewardWeights.dealt * dealt
        - CFG.RewardWeights.taken * taken
        + CFG.RewardWeights.distGain * distGain

    local stats = moveStats[t.move]
    if stats then
        stats.count += 1
        stats.reward += reward
        stats.avg = stats.reward / math.max(1, stats.count)
    end

    appendData({
        t = now(),
        move = t.move,
        style = t.style,
        dist0 = t.dist0,
        dist1 = dist1,
        myHP0 = t.myHP0,
        myHP1 = myHP1,
        tgtHP0 = t.tgtHP0,
        tgtHP1 = tgtHP1,
        reward = reward,
    })
end

------------------------------ ORIENTATION LOOPS ------------------------------
local function keepFacing(duration: number, fn: () -> ())
    local t0 = now()
    while now() - t0 < duration do
        if not running or not hum or hum.Health <= 0 then break end
        fn()
        RunService.Heartbeat:Wait()
    end
end

local function keepFacingBackdash(faceFn: () -> (), beforeEndFaceFn: (() -> ())?)
    local t0 = now()
    local dur = CFG.Dash.BDashWindow
    while now() - t0 < dur do
        if not running or not hum or hum.Health <= 0 then break end
        if beforeEndFaceFn and (dur - (now() - t0)) <= CFG.Dash.PreEndBackFace then
            beforeEndFaceFn()
        else
            faceFn()
        end
        RunService.Heartbeat:Wait()
    end
end

------------------------------ DASH EXECUTIONS -------------------------------
local function doSideDash(target, offensive: boolean)
    ensureCharacter()
    if not (target and target.hrp and hrp) then return end
    busyOrient = true
    local to = flat(target.hrp.Position - hrp.Position)
    if to.Magnitude < 1e-3 then busyOrient = false return end
    local toUnit = to.Unit
    local clockwise = math.random() < 0.5

    facePerpendicular(toUnit, clockwise)
    local right = flat(hrp.CFrame.RightVector).Unit
    local dot = right.X * toUnit.X + right.Z * toUnit.Z
    local sideKey : Enum.KeyCode
    if offensive then
        sideKey = (dot >= 0) and Enum.KeyCode.D or Enum.KeyCode.A
    else
        sideKey = (dot >= 0) and Enum.KeyCode.A or Enum.KeyCode.D
    end

    press(sideKey, true)
    task.wait(0.02)
    holdQ(CFG.Dash.HoldQ)

    keepFacing(CFG.Dash.RefaceTail, function()
        local liveTo = flat(target.hrp.Position - hrp.Position)
        if liveTo.Magnitude < 1e-3 then return end
        local liveUnit = liveTo.Unit
        if offensive then
            if liveTo.Magnitude <= CFG.Dash.SideOffRelock then
                faceTowards(target.hrp.Position)
            else
                facePerpendicular(liveUnit, clockwise)
            end
        else
            facePerpendicular(liveUnit, clockwise)
        end
    end)

    press(sideKey, false)
    faceTowards(target.hrp.Position)
    busyOrient = false
end

local function doForwardDash(target, offensive: boolean)
    ensureCharacter()
    if not (target and target.hrp and hrp) then return end
    busyOrient = true

    local orbiting = false
    local orbitCW = math.random() < 0.5
    local orbitStart = 0.0

    if offensive then
        faceTowards(target.hrp.Position)
    else
        faceAway(target.hrp.Position)
    end

    press(Enum.KeyCode.W, true)
    task.wait(0.02)
    holdQ(CFG.Dash.HoldQ)

    local t0 = now()
    while now() - t0 < CFG.Dash.FDashWindow do
        if not running or not hum or hum.Health <= 0 then break end
        local liveTo = flat(target.hrp.Position - hrp.Position)
        if liveTo.Magnitude < 1e-3 then break end
        local liveUnit = liveTo.Unit

        if offensive then
            if not orbiting then
                faceTowards(target.hrp.Position)
                if liveTo.Magnitude <= CFG.Dash.OrbitTrigger then
                    orbiting = true
                    orbitStart = now()
                end
            else
                local elapsed = now() - orbitStart
                if elapsed <= CFG.Dash.OrbitDuration then
                    facePerpendicular(liveUnit, orbitCW)
                else
                    faceTowards(target.hrp.Position)
                end
            end
        else
            faceAway(target.hrp.Position)
        end
        RunService.Heartbeat:Wait()
    end

    press(Enum.KeyCode.W, false)
    faceTowards(target.hrp.Position)
    busyOrient = false
end

local function doBackDash(target, offensive: boolean)
    ensureCharacter()
    if not (target and target.hrp and hrp) then return end
    busyOrient = true

    if offensive then
        faceAway(target.hrp.Position)
    else
        faceTowards(target.hrp.Position)
    end

    press(Enum.KeyCode.S, true)
    task.wait(0.02)
    holdQ(CFG.Dash.HoldQ)

    if offensive then
        local orbitCW = math.random() < 0.5
        keepFacingBackdash(function()
            local liveTo = flat(target.hrp.Position - hrp.Position)
            if liveTo.Magnitude < 1e-3 then return end
            local liveUnit = liveTo.Unit
            if liveTo.Magnitude <= CFG.Dash.BackClose then
                facePerpendicular(liveUnit, orbitCW)
            else
                faceAway(target.hrp.Position)
            end
        end, function()
            faceTowards(target.hrp.Position)
        end)
    else
        keepFacing(CFG.Dash.RefaceTail, function()
            faceTowards(target.hrp.Position)
        end)
    end

    press(Enum.KeyCode.S, false)
    faceTowards(target.hrp.Position)
    busyOrient = false
end

------------------------------ AGGRESSIVE MOVEMENT ----------------------------
local function aggroMovement(target)
    ensureCharacter()
    if not (target and target.hrp and hrp) then return end
    local t = now()
    if (t - lastAggroMove) < CFG.Aggro.RepositionCD then return end
    lastAggroMove = t

    local dist = target.dist
    if dist > 3.0 then
        tapKey(Enum.KeyCode.W, CFG.Aggro.ChaseHold)
    end
    local strafeKey = (math.random() < 0.5) and Enum.KeyCode.A or Enum.KeyCode.D
    tapKey(strafeKey, CFG.Aggro.StrafeHold)
end

------------------------------ AI DECISION HELPERS ----------------------------
local function chooseStyle(target)
    ensureCharacter()
    if not (hum and target and target.humanoid) then return "offensive" end
    local maxHealth = math.max(1, hum.MaxHealth)
    local ratio = hum.Health / maxHealth
    if ratio <= CFG.HP.DefensiveRatio then
        return "defensive"
    end
    if (hum.Health - target.humanoid.Health) <= CFG.HP.PanicDelta then
        return "defensive"
    end
    return "offensive"
end

local function moveValue(name: string)
    local stats = moveStats[name]
    if not stats then return 0 end
    return stats.avg
end

local function chooseMode(target, style: string)
    if not target then return "sidedash" end
    local dist = target.dist
    local bestMode = "sidedash"
    local bestScore = -math.huge

    local modes = {"sidedash", "fdash", "bdash"}
    for _, mode in ipairs(modes) do
        local score = moveValue(mode)
        if mode == "sidedash" then
            score += CFG.SideBias
            if dist <= 4.5 then score += 0.25 end
        elseif mode == "fdash" then
            if dist >= 6.0 then score += 0.30 end
        else -- bdash
            if dist <= 5.5 and style == "defensive" then score += 0.35 end
        end
        if score > bestScore then
            bestScore = score
            bestMode = mode
        end
    end

    if math.random() < CFG.Epsilon then
        bestMode = modes[math.random(1, #modes)]
    end

    if bestMode == "fdash" and not canUseDash("fdash") then
        if canUseDash("sidedash") then
            bestMode = "sidedash"
        elseif canUseDash("bdash") then
            bestMode = "bdash"
        end
    elseif bestMode == "bdash" and not canUseDash("bdash") then
        if canUseDash("sidedash") then
            bestMode = "sidedash"
        elseif canUseDash("fdash") then
            bestMode = "fdash"
        end
    elseif bestMode == "sidedash" and not canUseDash("sidedash") then
        if canUseDash("fdash") then
            bestMode = "fdash"
        elseif canUseDash("bdash") then
            bestMode = "bdash"
        end
    end

    return bestMode
end

------------------------------ MAIN LOOP & UI ---------------------------------
local idleLockConn : RBXScriptConnection? = nil

local function aimIdle()
    ensureCharacter()
    if not (hum and hrp and hum.Health > 0 and not busyOrient) then return end
    local info = nearestEnemy()
    if info and info.hrp then
        lastTarget = info.hrp
        lastHumanoid = info.humanoid
        faceTowards(info.hrp.Position)
    elseif lastTarget then
        faceTowards(lastTarget.Position)
    end
end

idleLockConn = RunService.Heartbeat:Connect(function()
    if running then return end
    aimIdle()
end)

local function loopOnce()
    ensureCharacter()
    if not (running and hum and hrp and hum.Health > 0) then return end
    local target = nearestEnemy()
    if not target then return end
    lastTarget = target.hrp
    lastHumanoid = target.humanoid

    aggroMovement(target)

    local style = chooseStyle(target)
    local mode = chooseMode(target, style)

    if mode == "sidedash" and canUseDash("sidedash") then
        markDash("sidedash")
        startTrial("sidedash", style, target)
        doSideDash(target, style == "offensive")
        task.delay(CFG.Dash.RefaceTail, finishTrial)
    elseif mode == "fdash" and canUseDash("fdash") then
        markDash("fdash")
        startTrial("fdash", style, target)
        doForwardDash(target, style == "offensive")
        task.delay(CFG.Dash.FDashWindow, finishTrial)
    elseif mode == "bdash" and canUseDash("bdash") then
        markDash("bdash")
        startTrial("bdash", style, target)
        doBackDash(target, style == "offensive")
        task.delay(CFG.Dash.BDashWindow, finishTrial)
    end
end

local function startLoop()
    ensureCharacter()
    if running then return end
    running = true
    if hum then hum.AutoRotate = false end
    task.spawn(function()
        while running do
            loopOnce()
            local tEnd = now() + CFG.LoopGap
            while running and now() < tEnd do
                task.wait(0.1)
            end
        end
    end)
end

local function stopLoop()
    running = false
    if trials.active then finishTrial() end
end

local function exitScript()
    stopLoop()
    if hum then hum.AutoRotate = true end
    if idleLockConn then pcall(function() idleLockConn:Disconnect() end) end
end

------------------------------- CHARACTER HOOKS -------------------------------
ensureCharacter()
LP.CharacterAdded:Connect(function(c)
    char = c
    hum  = c:WaitForChild("Humanoid")
    hrp  = c:WaitForChild("HumanoidRootPart")
    cam  = workspace.CurrentCamera
    if hum then hum.AutoRotate = false end
end)

------------------------------ SIMPLE TEXT UI --------------------------------
local function createUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "BattlegroundsBotUI"
    gui.ResetOnSpawn = false
    gui.Parent = gethui and gethui() or game:GetService("CoreGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 140)
    frame.Position = UDim2.new(0, 60, 0, 120)
    frame.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(76, 110, 255)
    stroke.Thickness = 1.3
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -12, 0, 24)
    title.Position = UDim2.new(0, 6, 0, 6)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(205, 214, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Battlegrounds Aggro Bot"
    title.Parent = frame

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -12, 0, 22)
    status.Position = UDim2.new(0, 6, 0, 34)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.Gotham
    status.TextSize = 13
    status.TextColor3 = Color3.fromRGB(235, 235, 235)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Text = "Status: idle"
    status.Parent = frame

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -12, 0, 44)
    info.Position = UDim2.new(0, 6, 0, 58)
    info.BackgroundTransparency = 1
    info.Font = Enum.Font.Gotham
    info.TextSize = 12
    info.TextColor3 = Color3.fromRGB(210, 220, 255)
    info.TextWrapped = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.Text = "WASD chase + adaptive dash AI. Offensive by default, defensive when hurt."
    info.Parent = frame

    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(0, 120, 0, 26)
    startBtn.Position = UDim2.new(0, 6, 0, 104)
    startBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    startBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    startBtn.Font = Enum.Font.GothamBold
    startBtn.TextSize = 14
    startBtn.Text = "Start"
    startBtn.Parent = frame
    startBtn.MouseButton1Click:Connect(function()
        startLoop()
        status.Text = "Status: running"
    end)

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0, 120, 0, 26)
    stopBtn.Position = UDim2.new(0, 148, 0, 104)
    stopBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
    stopBtn.TextColor3 = Color3.fromRGB(240, 240, 240)
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 14
    stopBtn.Text = "Stop"
    stopBtn.Parent = frame
    stopBtn.MouseButton1Click:Connect(function()
        stopLoop()
        status.Text = "Status: idle"
    end)

    local dragging = false
    local dragStart
    local frameStart
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            frameStart = frame.Position
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
            frame.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
        end
    end)

    return gui, status
end

local ui, statusLabel = createUI()

------------------------------- HOTKEY BINDINGS --------------------------------
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Equals then
        startLoop()
        if statusLabel then statusLabel.Text = "Status: running" end
    elseif input.KeyCode == Enum.KeyCode.Minus then
        stopLoop()
        if statusLabel then statusLabel.Text = "Status: idle" end
    elseif input.KeyCode == Enum.KeyCode.BackSlash then
        exitScript()
        if ui then ui:Destroy() end
    end
end)

------------------------------- CLEANUP EXPORT ---------------------------------
getgenv().BattlegroundsBot = {
    start = startLoop,
    stop = stopLoop,
    exit = exitScript,
}

