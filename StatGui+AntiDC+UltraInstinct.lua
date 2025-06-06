local AntiDeathCounter    = true
local AntiDeathCounterSpy = true
local UltBar              = true
local PingBar             = true
local EvasiveBar          = true
local LeaderboardSpy      = true
local followKey           = Enum.KeyCode.X
local SPEED               = 600
local BEHIND_DIST         = 3.3
local ANIM_INTERVAL       = 0.2

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Replicated      = game:GetService("ReplicatedStorage")
local UserInputService= game:GetService("UserInputService")

local LP       = Players.LocalPlayer
local Camera   = workspace.CurrentCamera

local Library = loadstring(game:HttpGetAsync("https://github.com/ActualMasterOogway/Fluent-Renewed/releases/latest/download/Fluent.luau"))()
local SaveManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/SaveManager.luau"))()
local InterfaceManager = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/ActualMasterOogway/Fluent-Renewed/master/Addons/InterfaceManager.luau"))()

local Window = Library:CreateWindow{
    Title = "StatGui+AntiDC+UltraInstinct",
    SubTitle = "by Azacks",
    TabWidth = 80,
    Size = UDim2.fromOffset(400, 455),
    Resize = true,
    MinSize = Vector2.new(310, 200),
    Acrylic = false,
    Theme = "Vynixu",
    MinimizeKey = Enum.KeyCode.RightControl
}

local Tabs = {
    Main = Window:CreateTab{ Title = "Main", Icon = "phosphor-circuitry" },
    Settings = Window:CreateTab{ Title = "Settings", Icon = "settings" }
}

local conns = {}
local headGuis = {}
local lastTKF = {}
local hiddenKills = {}

local function addConn(c) if c then table.insert(conns, c) end end

local function comma(n)
    local s,k = tostring(n), nil
    repeat s,k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k==0
    return s
end

local function pingColor(ms)
    return (ms<=60) and Color3.fromRGB(46,204,113)
         or (ms<=80) and Color3.fromRGB(171,204,46)
         or (ms<=100) and Color3.fromRGB(241,196,15)
         or (ms<=140) and Color3.fromRGB(230,126,34)
         or Color3.fromRGB(192,57,43)
end

local function getStatLabel(plr, stat)
    local root = game:GetService("CoreGui"):FindFirstChild("PlayerList", true)
    local row = root and root:FindFirstChild("p_"..plr.UserId, true)
    local g = row and row:FindFirstChild("GameStat_"..stat, true)
    local ov = g and g:FindFirstChild("OverlayFrame", true)
    return ov and ov:FindFirstChild("StatText", true)
end

local function lerp(c1,c2,t)
    return Color3.new(
        c1.R + (c2.R-c1.R)*t,
        c1.G + (c2.G-c1.G)*t,
        c1.B + (c2.B-c1.B)*t
    )
end

local FADE_NEAR = 90
local FADE_FAR  = 100

local function fadeFactor(d)
    if d<=FADE_NEAR then return 0 end
    if d>=FADE_FAR then return 1 end
    return (d-FADE_NEAR)/(FADE_FAR-FADE_NEAR)
end

local function clearReveal(plr)
    local kl = getStatLabel(plr,"Kills")
    local tl = getStatLabel(plr,"Total Kills")
    if kl and plr:FindFirstChild("Kills") then
        kl.Text = comma(plr.Kills.Value)
    end
    if tl and plr:FindFirstChild("Total Kills") then
        tl.Text = comma(plr["Total Kills"].Value)
    end
end

local function reveal(plr)
    if not LeaderboardSpy then return end
    if plr:GetAttribute("S_HideKills")~=true then return end
    local kl = getStatLabel(plr,"Kills")
    local tl = getStatLabel(plr,"Total Kills")
    local kv = plr:FindFirstChild("Kills")
    local tv = plr:FindFirstChild("Total Kills")
    if kl and kv then kl.Text = "🔍 "..comma(kv.Value) end
    if tl and tv then tl.Text = "🔍 "..comma(tv.Value) end
end

local function trackTKF(plr)
    if not LeaderboardSpy then return end
    lastTKF[plr] = plr:GetAttribute("TotalKillsFrb") or 0
    addConn(plr:GetAttributeChangedSignal("TotalKillsFrb"):Connect(function()
        local new = plr:GetAttribute("TotalKillsFrb") or 0
        local diff = new - (lastTKF[plr] or 0)
        if diff>0 then
            local kv = plr:FindFirstChild("Kills")
            if kv then kv.Value = kv.Value + diff end
        end
        lastTKF[plr] = new
        if plr:GetAttribute("S_HideKills")==true then reveal(plr) end
    end))
end

local function finalizeTrack(plr)
    if plr:GetAttribute("S_HideKills") then
        if not hiddenKills[plr] then
            hiddenKills[plr] = true
            trackTKF(plr)
        end
        reveal(plr)
    else
        if hiddenKills[plr] then
            hiddenKills[plr] = nil
            clearReveal(plr)
        end
    end
end

for _,plr in ipairs(Players:GetPlayers()) do
    if plr~=LP then
        finalizeTrack(plr)
        addConn(plr:GetAttributeChangedSignal("S_HideKills"):Connect(function()
            finalizeTrack(plr)
        end))
    end
end

addConn(Players.PlayerAdded:Connect(function(plr)
    if plr~=LP then
        finalizeTrack(plr)
        addConn(plr:GetAttributeChangedSignal("S_HideKills"):Connect(function()
            finalizeTrack(plr)
        end))
    end
end))

local MenacingTemplate = Replicated:WaitForChild("Resources"):WaitForChild("LegacyReplication"):WaitForChild("Menacing")
local MagicTemplateGui = ReplicatedFirst:WaitForChild("ScreenGui")
local MagicTemplate    = MagicTemplateGui:WaitForChild("MagicHealth")

local CharacterColors = {
    Bald   = Color3.fromRGB(255,255,0),
    Hunter = Color3.fromRGB(81,218,255),
    Cyborg = Color3.fromRGB(255,45,0),
    Ninja  = Color3.fromRGB(223,156,235),
    Batter = Color3.fromRGB(175,175,175),
    Blade  = Color3.fromRGB(255,113,73),
    Esper  = Color3.fromRGB(0,255,105),
    Purple = Color3.fromRGB(121,0,253),
    Tech   = Color3.fromRGB(0,0,0),
    Monster= Color3.fromRGB(139,0,0),
}

local LT_BLUE_BASE = Color3.fromRGB(135,200,255)
local LT_BLUE_PEAK = Color3.fromRGB(175,230,255)
local CRIMSON_LOW  = Color3.fromRGB(190,0,25)
local CRIMSON_HIGH = Color3.fromRGB(255,60,60)

local GUI_WIDTH_PX        = 105
local GUI_HEIGHT_PX       = 36
local BASE_HEIGHT         = 2.4
local DEAD_ZONE           = 20
local LIFT_PER_STUD       = 0.03
local MAX_LIFT            = 200

local MEN_NUMBER          = 10
local MEN_RADIUS_MIN, MEN_RADIUS_MAX = 1.5, 4
local MEN_JITTER_AMT      = 0.06
local MEN_SPAWN_Y_MIN     = -0.5
local MEN_SPAWN_Y_MAX     = 2.4
local MEN_HOP_OFFSET      = 0.9
local MEN_HOP_TIME        = 0.08
local MEN_DROP_DIST       = -4
local MEN_DROP_TIME       = 0.6
local MEN_LIFE_SECONDS    = 10
local MEN_SCALE_MIN, MEN_SCALE_MAX = 0.90, 1.20

local TELEPORT_ANIMATION_ID   = "rbxassetid://11343250001"
local BASEPLATE_SIZE         = Vector3.new(2048,4,2048)
local BASEPLATE_Y_DEFAULT    = -496
local TELEPORT_HEIGHT_OFFSET = 4.25
local BACK_TELEPORT_RADIUS   = 50
local MIN_TELEPORT_DURATION  = 3

local function newMagicBar(parentGui,label,yScale)
    local frame = MagicTemplate.Health:Clone()
    frame.Name = label.."Frame"
    frame.AnchorPoint = Vector2.new(0.5,0)
    frame.Position = UDim2.new(0.5,0,yScale,0)
    frame.Size = UDim2.new(0.9,0,0.25,0)
    frame.BackgroundTransparency = 1
    if frame:FindFirstChild("Ult") then frame.Ult:Destroy() end
    local lbl = frame:FindFirstChild("TextLabel")
    if lbl then
        lbl.Text = label
        local innerLbl = lbl:FindFirstChildWhichIsA("TextLabel")
        if innerLbl then innerLbl.Text = label end
    end
    frame.Parent = parentGui
    local bar = frame:FindFirstChild("Bar", true)
    local inner = bar:FindFirstChild("Bar", true)
    local glow = frame:FindFirstChild("Glow", true)
    return { root = frame, bar = bar, inner = inner, glow = glow }
end

-- 1. Replace setFill entirely with this:
local function setFill(t, alpha, colLow, colHigh, pulse)
    if t.bar then
        t.bar.Size = UDim2.new(1, 0, t.bar.Size.Y.Scale, t.bar.Size.Y.Offset)
        t.bar.ImageTransparency = 1
    end
    local col = (pulse and lerp(colLow, colHigh, pulse)) or colLow
    if t.inner then
        -- fill horizontally (X = alpha, Y stays full)
        t.inner.Size = UDim2.new(alpha, 0, 1, 0)
        t.inner.ImageColor3 = col
    end
    if t.glow then
        t.glow.ImageColor3 = col
        t.glow.ImageTransparency = 0.5 - 0.3*(pulse or 0)
        t.glow.Visible = true
    end
end

local mkGui, updGui

if PingBar or UltBar or EvasiveBar then
    mkGui = function(char)
        local head = char:FindFirstChild("Head") or char:WaitForChild("Head",2)
        if not head then return end
        if head:FindFirstChild("_StatGui") then head._StatGui:Destroy() end
        local gui = Instance.new("BillboardGui", head)
        gui.Name = "_StatGui"
        gui.Adornee = head
        gui.Size = UDim2.new(0,GUI_WIDTH_PX,0,GUI_HEIGHT_PX)
        gui.MaxDistance = 9999
        gui.AlwaysOnTop = true
        gui.StudsOffset = Vector3.new(0,BASE_HEIGHT,0)
        local ping = Instance.new("TextLabel", gui)
        ping.Name = "PingLabel"
        ping.AnchorPoint = Vector2.new(0.5,0)
        ping.Position = UDim2.new(0.5,0,0,0)
        ping.Size = UDim2.new(1,0,0.45,0)
        ping.BackgroundTransparency = 1
        ping.Font = Enum.Font.ArialBold
        ping.TextScaled = true
        local pStroke = Instance.new("UIStroke", ping)
        pStroke.Color = Color3.new(0,0,0)
        pStroke.Thickness = 1
        local evasiveBar = newMagicBar(gui,"Evasive",0.48)
        local ultBar     = newMagicBar(gui,"Ult",0.75)
        local dummy = Instance.new("Frame")
        dummy.Visible = false
        headGuis[char] = {
            gui = gui,
            ping = ping,
            pStroke = pStroke,
            evasiveBar = evasiveBar,
            ultBar = ultBar,
            back = dummy, bar = dummy, glow = dummy,
            _evasiveStart = nil
        }
    end

    updGui = function(plr, char)
        local h = headGuis[char]
        if not h then return end
        if PingBar then
            local ms = plr:GetAttribute("Ping") or 0
            h.ping.Text = ("%d ms"):format(ms)
            h.ping.TextColor3 = pingColor(ms)
            h.ping.Visible = true
            h.pStroke.Enabled = true
        else
            h.ping.Visible = false
            h.pStroke.Enabled = false
        end
        h.ultBar.root.Visible = UltBar
        if UltBar then
            local pct = math.clamp(plr:GetAttribute("Ultimate") or 0,0,100)
            local live = workspace:FindFirstChild("Live")
            local lc = live and live:FindFirstChild(char.Name)
            local ulted = lc and lc:GetAttribute("Ulted")==true
            local pulse = (math.sin(os.clock()*math.pi*16)+1)/2
            if ulted then
                setFill(h.ultBar,1,CRIMSON_LOW,CRIMSON_HIGH,pulse)
            elseif pct>=100 then
                setFill(h.ultBar,1,Color3.fromRGB(255,87,87),Color3.fromRGB(255,87,87),nil)
                h.ultBar.glow.ImageColor3 = Color3.new(1,1,1)
                local gPulse = (math.sin(os.clock()*math.pi*16)+1)/2
                h.ultBar.glow.ImageTransparency = 0.5 - 0.3*gPulse
                h.ultBar.glow.Visible = true
            else
                setFill(h.ultBar,pct/100,Color3.fromRGB(255,87,87),Color3.fromRGB(255,87,87),nil)
                h.ultBar.glow.ImageTransparency = 0.5
            end
        end
	h.evasiveBar.root.Visible = EvasiveBar
	if EvasiveBar then
	    local vars = h.evasiveBar
	    local live = workspace:FindFirstChild("Live")
	    local lc = live and live:FindFirstChild(char.Name)
	    local class = lc and lc:GetAttribute("Character")
	    local col = CharacterColors[class] or Color3.new(1,1,1)
	
	    local startTime = h._evasiveStart
	    if not startTime then
	        -- no cooldown → full bar, hide glow
	        setFill(vars, 1, col, col, nil)
	    else
	        local dt = math.min(30, tick() - startTime)
	        local alpha = dt / 30
	        local pulse = (math.sin(os.clock() * math.pi * 4) + 1) / 2
	        setFill(vars, alpha, col, col, pulse)
	        if dt >= 30 then
	            h._evasiveStart = nil
	        end
	    end
	end
        local yPing,yEvasive,yUlt = 0,0.48,0.75
        if not EvasiveBar and not UltBar then
            yPing = 0.25
        elseif not EvasiveBar and UltBar then
            yPing,yUlt = 0.3,0.7
        elseif EvasiveBar and not UltBar then
            yPing,yEvasive = 0.3,0.7
        end
        h.ping.Position = UDim2.new(0.5,0,yPing,0)
        h.evasiveBar.root.Position = UDim2.new(0.5,0,yEvasive,0)
        h.ultBar.root.Position = UDim2.new(0.5,0,yUlt,0)
    end
else
    mkGui = function() end
    updGui = function() end
end

local function updateGuiLift()
    for char,h in pairs(headGuis) do
        local root = char.PrimaryPart 
                     or char:FindFirstChild("HumanoidRootPart") 
                     or char:FindFirstChild("Head")
        if not root then continue end

        local camPos = workspace.CurrentCamera.CFrame.Position
        local camDist = (camPos - root.Position).Magnitude
        local extra = (camDist > DEAD_ZONE)
                      and math.clamp((camDist - DEAD_ZONE) * LIFT_PER_STUD, 0, MAX_LIFT)
                      or 0
        h.gui.StudsOffset = Vector3.new(0, BASE_HEIGHT + extra, 0)

        local plr = Players:FindFirstChild(char.Name)
        if not (plr and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")) then
            continue
        end

        local playerDist = (LP.Character.HumanoidRootPart.Position - root.Position).Magnitude
        local t = fadeFactor(playerDist)

        h.ping.TextTransparency = t
        h.pStroke.Transparency = t

        if h.ultBar.inner then
            h.ultBar.inner.ImageTransparency = t
        end
        if h.evasiveBar.inner then
            h.evasiveBar.inner.ImageTransparency = t
        end

        local pct = plr:GetAttribute("Ultimate") or 0
        local live = workspace:FindFirstChild("Live")
        local lc  = live and live:FindFirstChild(char.Name)
        local ulted = lc and lc:GetAttribute("Ulted") == true

        if h.ultBar.glow then
		h.ultBar.glow.ImageTransparency = t
        end

	if h.evasiveBar.inner then
	    local alpha = 1
	    if h._evasiveStart then
	        local dt = math.min(30, tick() - h._evasiveStart)
	        alpha = dt / 30
	    end
	    -- horizontal fill
	    h.evasiveBar.inner.Size = UDim2.new(alpha, 0, 1, 0)
	end

	if h.evasiveBar.glow then
	    local innerScale = h.evasiveBar.inner.Size.X.Scale
	    local baseT = (1 - innerScale) * 0.8
	    h.evasiveBar.glow.ImageTransparency = math.max(t, baseT)
	    -- no explicit `glow.Visible = true` here
	end
    end
end

RunService.Heartbeat:Connect(updateGuiLift)

if AntiDeathCounterSpy then
    local liveFolder = workspace:WaitForChild("Live")
    local function highlightFor10sec(model)
        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(255,0,0)
        hl.FillTransparency = 0.25
        hl.OutlineColor = Color3.fromRGB(255,0,0)
        hl.OutlineTransparency = 0.5
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = model
        task.delay(10, function() if hl and hl.Parent then hl:Destroy() end end)
    end
    local function spawnDeathCounterEffects(liveChar)
        local hrp = liveChar:FindFirstChild("HumanoidRootPart") or liveChar:WaitForChild("HumanoidRootPart",2)
        if not hrp then return end
        local folder = Instance.new("Folder", hrp)
        folder.Name = "_MenacingVFX"
        local clones = {}
        for i=1,MEN_NUMBER do
            local gui = MenacingTemplate:Clone()
            gui.Parent = folder
            gui.Enabled = true
            gui.AlwaysOnTop = false
            gui.Adornee = hrp
            local s = math.random()*(MEN_SCALE_MAX-MEN_SCALE_MIN)+MEN_SCALE_MIN
            gui.Size = UDim2.new(s,0,s,0)
            local ang = math.rad((360/MEN_NUMBER)*i + math.random()*20)
            local r = math.random()*(MEN_RADIUS_MAX-MEN_RADIUS_MIN)+MEN_RADIUS_MIN
            local base = Vector3.new(math.cos(ang),0,math.sin(ang))*r
            local yOff = math.random()*(MEN_SPAWN_Y_MAX-MEN_SPAWN_Y_MIN)+MEN_SPAWN_Y_MIN
            gui.StudsOffsetWorldSpace = base + Vector3.new(0,yOff,0)
            local img = gui:FindFirstChildOfClass("ImageLabel")
            if img then img.Visible = true img.ImageTransparency = 0 img.BackgroundTransparency = 1 end
            table.insert(clones,{gui = gui, img = img})
        end
        local startTime, idx = tick(), 1
        local conn
        conn = RunService.RenderStepped:Connect(function()
            local t = tick()-startTime
            for _,c in ipairs(clones) do
                if c.gui.Parent then
                    c.gui.StudsOffsetWorldSpace += Vector3.new(
                        (math.random()-0.5)*MEN_JITTER_AMT,
                        (math.random()-0.5)*MEN_JITTER_AMT,
                        (math.random()-0.5)*MEN_JITTER_AMT
                    )
                end
            end
            if idx<=MEN_NUMBER and t>=idx then
                local c = clones[idx]
                idx = idx+1
                local g, img = c.gui, c.img
                local initial = g.StudsOffsetWorldSpace
                local upPos = initial + Vector3.new(0,MEN_HOP_OFFSET,0)
                local downPos = initial + Vector3.new(0,MEN_HOP_OFFSET+MEN_DROP_DIST,0)
                local hop = TweenService:Create(g, TweenInfo.new(MEN_HOP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {StudsOffsetWorldSpace = upPos})
                local fall = TweenService:Create(g, TweenInfo.new(MEN_DROP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {StudsOffsetWorldSpace = downPos})
                if img then
                    local fade = TweenService:Create(img, TweenInfo.new(MEN_HOP_TIME+MEN_DROP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {ImageTransparency = 1})
                    fade:Play()
                end
                hop.Completed:Connect(function() fall:Play() end)
                fall.Completed:Connect(function() g:Destroy() end)
                hop:Play()
            end
            if t>MEN_LIFE_SECONDS+MEN_HOP_TIME+MEN_DROP_TIME then
                conn:Disconnect()
                if folder and folder.Parent then folder:Destroy() end
            end
        end)
    end
    local function hookDeathCounter(liveModel)
        if liveModel.Name==LP.Name then return end
        local function fireVFX()
            highlightFor10sec(liveModel)
            spawnDeathCounterEffects(liveModel)
        end
        if liveModel:FindFirstChild("Counter") then fireVFX() end
        addConn(liveModel.ChildAdded:Connect(function(child)
            if child.Name=="Counter" then fireVFX() end
        end))
        local humanoid = liveModel:FindFirstChildOfClass("Humanoid") or liveModel:WaitForChild("Humanoid",2)
        local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator",2)
        addConn(animator.AnimationPlayed:Connect(function(track)
            if track.Animation and track.Animation.AnimationId=="rbxassetid://11343318134" then
                for _,d in ipairs(liveModel:GetDescendants()) do
                    if d:IsA("Highlight") then d:Destroy() end
                end
                local hrp = liveModel:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local vfx = hrp:FindFirstChild("_MenacingVFX")
                    if vfx then vfx:Destroy() end
                end
            end
        end))
    end
    for _,lm in ipairs(workspace:WaitForChild("Live"):GetChildren()) do
        hookDeathCounter(lm)
    end
    addConn(workspace.Live.ChildAdded:Connect(hookDeathCounter))
end
local liveFolder = workspace:WaitForChild("Live")

local function markEvasiveStart(plrName)
    for lm,h in pairs(headGuis) do
        if lm.Name == plrName then
            h._evasiveStart = tick()
            return
        end
    end
end

local function hookEvasive(lm)
    for _,d in ipairs(lm:GetDescendants()) do
        if d.Name == "RagdollCancel" then
            markEvasiveStart(lm.Name)
            break
        end
    end
    addConn(lm.DescendantAdded:Connect(function(d)
        if d.Name == "RagdollCancel" then
            markEvasiveStart(lm.Name)
        end
    end))
end

local function onLiveAdded(lm)
    if lm:GetAttribute("NPC") == true then
        return
    end
    if lm.Name == LP.Name then
        return
    end
    mkGui(lm)
    hookEvasive(lm)
    local plr = Players:FindFirstChild(lm.Name)
    if plr then
        updGui(plr, lm)
        addConn(plr:GetAttributeChangedSignal("Ping"):Connect(function()
            updGui(plr, lm)
        end))
        addConn(plr:GetAttributeChangedSignal("Ultimate"):Connect(function()
            updGui(plr, lm)
        end))
    end
end

for _, lm in ipairs(liveFolder:GetChildren()) do
    onLiveAdded(lm)
end

addConn(liveFolder.ChildAdded:Connect(onLiveAdded))

if AntiDeathCounter then
    do
        local baseplate, isTeleporting, teleportStart, originalCFrame
        local function createBaseplate(pos)
            if baseplate then baseplate:Destroy() end
            baseplate = Instance.new("Part", workspace)
            baseplate.Name = "AntiDeathBaseplate"
            baseplate.Size = BASEPLATE_SIZE
            baseplate.Anchored = true
            baseplate.CanCollide = true
            baseplate.Position = Vector3.new(pos.X, BASEPLATE_Y_DEFAULT - BASEPLATE_SIZE.Y/2, pos.Z)
        end
        local function anyPlayersNearby(pos)
            for _,pl in ipairs(Players:GetPlayers()) do
                if pl~=LP and pl.Character then
                    local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                    if hrp and (hrp.Position-pos).Magnitude<=BACK_TELEPORT_RADIUS then
                        return true
                    end
                end
            end
            return false
        end
        local function restoreCameraAndCleanup()
            workspace.CurrentCamera:Destroy()
            wait(0.1)
            repeat wait() until LP.Character and LP.Character:FindFirstChildWhichIsA("Humanoid")
            local cam = workspace.CurrentCamera
            cam.CameraSubject = LP.Character:FindFirstChildWhichIsA("Humanoid")
            cam.CameraType = Enum.CameraType.Custom
            LP.CameraMinZoomDistance = 0.5
            LP.CameraMaxZoomDistance = 400
            LP.CameraMode = Enum.CameraMode.Classic
            if LP.Character.Head then
                LP.Character.Head.Anchored = false
            end
        end
        local function onCharacter(char)
            if baseplate then baseplate:Destroy() baseplate=nil end
            isTeleporting = false
            teleportStart = nil
            originalCFrame = nil
            local hum = char:WaitForChild("Humanoid",2)
            local hrp = char:WaitForChild("HumanoidRootPart",2)
            local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator",2)
            animator.AnimationPlayed:Connect(function(track)
                if track.Animation and track.Animation.AnimationId==TELEPORT_ANIMATION_ID and not isTeleporting then
                    isTeleporting = true
                    originalCFrame = hrp.CFrame
                    createBaseplate(hrp.Position)
                    teleportStart = tick()
                    local conn
                    conn = RunService.Heartbeat:Connect(function()
                        if not hrp.Parent then conn:Disconnect() return end
                        hrp.CFrame = CFrame.new(baseplate.Position + Vector3.new(0,TELEPORT_HEIGHT_OFFSET,0))
                        if tick()-teleportStart>=MIN_TELEPORT_DURATION and not anyPlayersNearby(hrp.Position) then
                            conn:Disconnect()
                            hrp.CFrame = originalCFrame
                            restoreCameraAndCleanup()
                            if baseplate then baseplate:Destroy() baseplate=nil end
                            isTeleporting = false
                        end
                    end)
                end
            end)
        end
        LP.CharacterAdded:Connect(onCharacter)
        if LP.Character then onCharacter(LP.Character) end
    end
end

local function attachPlayer(plr)
    if plr==LP then
        addConn(plr.CharacterAdded:Connect(function(c)
            c:WaitForChild("Humanoid",4).NameDisplayDistance = 100
            c:WaitForChild("Humanoid",4).HealthDisplayDistance = 100
        end))
        if plr.Character then
            local c = plr.Character
            c:WaitForChild("Humanoid",4).NameDisplayDistance = 100
            c:WaitForChild("Humanoid",4).HealthDisplayDistance = 100
        end
        return
    end
    if LeaderboardSpy and (plr:FindFirstChild("Kills") or plr:FindFirstChild("Total Kills")) then
        if plr:GetAttribute("S_HideKills")==true then reveal(plr) end
        trackTKF(plr)
        if plr:GetAttribute("S_HideKills")==true then hiddenKills[plr] = true end
        addConn(plr:GetAttributeChangedSignal("S_HideKills"):Connect(function()
            if plr:GetAttribute("S_HideKills") then
                hiddenKills[plr] = true
                reveal(plr)
            else
                hiddenKills[plr] = nil
                clearReveal(plr)
            end
        end))
    end
    addConn(plr.AncestryChanged:Connect(function(_,parent)
        if not parent then lastTKF[plr] = nil end
    end))
end

for _,p in ipairs(Players:GetPlayers()) do attachPlayer(p) end
addConn(Players.PlayerAdded:Connect(attachPlayer))

local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://15957361339"

local character, hrp, humanoid, animator, track
local isFollowing = false
local target
local movementConn
local animPlaying = false

local function onCharAdded(char)
    character = char
    hrp = char:WaitForChild("HumanoidRootPart")
    humanoid = char:WaitForChild("Humanoid")
    animator = humanoid:WaitForChild("Animator")
    track = animator:LoadAnimation(animation)
end

Players.LocalPlayer.CharacterAdded:Connect(onCharAdded)
if LP.Character then onCharAdded(LP.Character) end

local function startFollow()
    if isFollowing then
        isFollowing = false
        if movementConn then movementConn:Disconnect() movementConn = nil end
        if track then track:Stop() end
        animPlaying = false
		if followToggle then
			followToggle:SetValue(false, true)
		end
        return
    end
    local best, minD = nil, math.huge
    if hrp then
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and p.Character then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                local part = p.Character:FindFirstChild("HumanoidRootPart")
                if h and part and h.Health>0 then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d<minD then
                        minD, best = d, p
                    end
                end
            end
        end
    end
    target = best
    if not target or not target.Character then return end
    local tHum = target.Character:FindFirstChildOfClass("Humanoid")
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not (tHum and tHRP) then return end
    isFollowing = true
    movementConn = RunService.Heartbeat:Connect(function(dt)
        if not isFollowing then return end
        if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart")
           or not target.Character:FindFirstChildOfClass("Humanoid")
           or target.Character:FindFirstChildOfClass("Humanoid").Health<=0 then
            startFollow()
            return
        end
        local tHRP2 = target.Character.HumanoidRootPart
        local goalPos = tHRP2.Position - tHRP2.CFrame.LookVector*BEHIND_DIST
        local direction = goalPos - hrp.Position
        local dist = direction.Magnitude
        if dist > SPEED*dt then
            hrp.CFrame = CFrame.lookAt(hrp.Position + direction.Unit*SPEED*dt, tHRP2.Position)
        else
            hrp.CFrame = CFrame.lookAt(goalPos, tHRP2.Position)
        end
        if dist>BEHIND_DIST then
            if not animPlaying then
                animPlaying = true
                track:Play()
                task.delay(ANIM_INTERVAL, function()
                    track:Stop()
                    animPlaying = false
                end)
            end
        elseif animPlaying then
            track:Stop()
            animPlaying = false
        end
    end)
end

local function stopFollow()
    if isFollowing then
        startFollow()
    end
end

-- Main Tab UI
local toggles = {
    { Name = "Anti Death Counter",    Value = AntiDeathCounter },
    { Name = "DC Spy", Value = AntiDeathCounterSpy },
    { Name = "Ult Bar",              Value = UltBar },
    { Name = "Ping Bar",             Value = PingBar },
    { Name = "Evasive Bar",          Value = EvasiveBar },
    { Name = "Leaderboard Spy",      Value = LeaderboardSpy }
}

for _,info in ipairs(toggles) do
    local toggle = Tabs.Main:CreateToggle(info.Name, { Title = info.Name, Default = info.Value })
    toggle:OnChanged(function(val)
        if info.Name == "Anti Death Counter"    then AntiDeathCounter    = val end
        if info.Name == "DC Spy" then AntiDeathCounterSpy = val end
        if info.Name == "Ult Bar"              then UltBar              = val end
        if info.Name == "Ping Bar"             then PingBar             = val end
        if info.Name == "Evasive Bar"          then EvasiveBar          = val end
        if info.Name == "Leaderboard Spy"      then LeaderboardSpy      = val end
    end)
end

local speedInput = Tabs.Main:CreateInput("SpeedInput", {
    Title = "Speed",
    Default = tostring(SPEED),
    Placeholder = "Numeric",
    Numeric = true,
    Finished = true
})
speedInput:OnChanged(function()
    local n = tonumber(speedInput.Value)
    if n then SPEED = n end
end)

local behindInput = Tabs.Main:CreateInput("BehindDistInput", {
    Title = "Behind Distance",
    Default = tostring(BEHIND_DIST),
    Placeholder = "Numeric",
    Numeric = true,
    Finished = true
})
behindInput:OnChanged(function()
    local n = tonumber(behindInput.Value)
    if n then BEHIND_DIST = n end
end)

local animInput = Tabs.Main:CreateInput("AnimIntervalInput", {
    Title = "Anim Interval",
    Default = tostring(ANIM_INTERVAL),
    Placeholder = "Numeric",
    Numeric = true,
    Finished = true
})
animInput:OnChanged(function()
    local n = tonumber(animInput.Value)
    if n then ANIM_INTERVAL = n end
end)

local followToggle = Tabs.Main:CreateToggle("FollowToggle", { Title = "Follow On/Off", Default = false })
followToggle:OnChanged(function(val)
    if val then
        startFollow()
    else
        stopFollow()
    end
end)

local keybind = Tabs.Main:CreateKeybind("FollowKeybind", {
    Title = "Follow Keybind",
    Mode = "Toggle",
    Default = followKey.Name,
    ChangedCallback = function(newKey)
        followKey = newKey
    end
})
keybind:OnClick(function()
    followToggle:SetValue(not followToggle.Value)
end)

SaveManager:SetLibrary(Library)
InterfaceManager:SetLibrary(Library)
InterfaceManager:SetFolder("FluentAzacksHub")
SaveManager:SetFolder("FluentAzacksHub/TSBgame")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

for _,c in ipairs(conns) do
    if c.Disconnect then
    end
end
