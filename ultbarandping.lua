--[[
-- put this at startup loadstring
local cfg = {
	AntiDeathCounter    = false,
	AntiDeathCounterSpy = true,
	UltBar              = true,
	PingBar             = true,
	EvasiveBar          = true,    
	LeaderboardSpy      = true,
}

_G.Config  = cfg
Config     = cfg      
]]
local cfg = _G.Config or {}
--------------------------[[ FLAGS ]]---------------------------------
local AntiDeathCounter    = cfg.AntiDeathCounter
local AntiDeathCounterSpy = cfg.AntiDeathCounterSpy
local UltBar              = cfg.UltBar
local PingBar             = cfg.PingBar
local EvasiveBar          = cfg.EvasiveBar    
local LeaderboardSpy      = cfg.LeaderboardSpy

--------------------------[[ CONSTANTS ]]-----------------------------
local GUI_WIDTH_PX        = 105
local GUI_HEIGHT_PX       = 36
local BASE_HEIGHT         = 2.4
local DEAD_ZONE           = 20
local LIFT_PER_STUD       = 0.03
local MAX_LIFT            = 200
local FADE_NEAR           = 90
local FADE_FAR            = 100

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

--------------------------[[ SERVICES ]]-----------------------------
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TweenService    = game:GetService("TweenService")
local ReplicatedFirst = game:GetService("ReplicatedFirst") 
local Replicated      = game:GetService("ReplicatedStorage")

local LP              = Players.LocalPlayer
local Camera          = workspace.CurrentCamera

----------------[[ RESOURCES / TEMPLATE GUI ]]-----------------------
local MenacingTemplate = Replicated
	:WaitForChild("Resources")
	:WaitForChild("LegacyReplication")
	:WaitForChild("Menacing")

local MagicTemplateGui = ReplicatedFirst:WaitForChild("ScreenGui")  -- NEW
local MagicTemplate    = MagicTemplateGui:WaitForChild("MagicHealth") -- NEW


local CharacterColors = {
    Bald   = Color3.fromRGB(255, 255,   0),  
    Hunter = Color3.fromRGB( 81, 218, 255),  
    Cyborg = Color3.fromRGB(255, 45,   0),   
    Ninja  = Color3.fromRGB(223, 156, 235),  
    Batter = Color3.fromRGB(175, 175, 175),  
    Blade  = Color3.fromRGB(255, 113,  73), 
    Esper  = Color3.fromRGB(  0, 255, 105),  
    Purple = Color3.fromRGB(121, 0, 253),  
    Tech   = Color3.fromRGB(  0,   0,   0), 
    Monster   = Color3.fromRGB(  139,   0,   0), 
}


local LT_BLUE_BASE = Color3.fromRGB(135,200,255) 
local LT_BLUE_PEAK = Color3.fromRGB(175,230,255)
local CRIMSON_LOW  = Color3.fromRGB(190,  0, 25)
local CRIMSON_HIGH = Color3.fromRGB(255, 60, 60)



--------------------------[[ VAR STORES ]]---------------------------
local conns, headGuis, lastTKF = {}, {}, {}
local hiddenKills = {}

local function addConn(c) if c then table.insert(conns, c) end end

----------------------[[ SMALL HELPERS ]]----------------------------
local function comma(n)
	local s, k = tostring(n), nil
	repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
	return s
end

local function pingColor(ms)
	return (ms <= 60)  and Color3.fromRGB( 46,204,113)
	     or (ms <= 80)  and Color3.fromRGB(171,204, 46)
	     or (ms <= 100) and Color3.fromRGB(241,196, 15)
	     or (ms <= 140) and Color3.fromRGB(230,126, 34)
	     or                 Color3.fromRGB(192, 57, 43)
end

local function getStatLabel(plr, stat)
	local root = game:GetService("CoreGui"):FindFirstChild("PlayerList", true)
	local row  = root and root:FindFirstChild("p_"..plr.UserId, true)
	local g    = row  and row:FindFirstChild("GameStat_"..stat, true)
	local ov   = g    and g:FindFirstChild("OverlayFrame", true)
	return ov and ov:FindFirstChild("StatText", true)
end

local function lerp(c1,c2,t)
	return Color3.new(
		c1.R + (c2.R-c1.R)*t,
		c1.G + (c2.G-c1.G)*t,
		c1.B + (c2.B-c1.B)*t
	)
end

local function fadeFactor(d)
	if d <= FADE_NEAR then return 0 end
	if d >= FADE_FAR  then return 1 end
	return (d - FADE_NEAR) / (FADE_FAR - FADE_NEAR)
end

local function refreshFlags()
    AntiDeathCounter    = Config.AntiDeathCounter
    AntiDeathCounterSpy = Config.AntiDeathCounterSpy
    UltBar              = Config.UltBar
    PingBar             = Config.PingBar
    EvasiveBar          = Config.EvasiveBar
    LeaderboardSpy      = Config.LeaderboardSpy
end

local function fadeBarLayer(obj, t)
    if obj then obj.ImageTransparency = t end
end


--------------------------------------------------------------------
--                    [[ LEADERBOARD SPY ]]                        --
--------------------------------------------------------------------
local function clearReveal(plr)
	local kl = getStatLabel(plr,"Kills")
	local tl = getStatLabel(plr,"Total Kills")
	if kl and plr:FindFirstChild("Kills")        then kl.Text = comma(plr.Kills.Value) end
	if tl and plr:FindFirstChild("Total Kills")  then tl.Text = comma(plr["Total Kills"].Value) end
end

local reveal, trackTKF

if Config.LeaderboardSpy then
	reveal = function(plr)
		if plr:GetAttribute("S_HideKills") ~= true then return end
		local kl = getStatLabel(plr,"Kills")
		local tl = getStatLabel(plr,"Total Kills")
		local kv = plr:FindFirstChild("Kills")
		local tv = plr:FindFirstChild("Total Kills")
		if kl and kv then kl.Text = "🔍 "..comma(kv.Value) end
		if tl and tv then tl.Text = "🔍 "..comma(tv.Value) end
	end

	trackTKF = function(plr)
		lastTKF[plr] = plr:GetAttribute("TotalKillsFrb") or 0
		addConn(plr:GetAttributeChangedSignal("TotalKillsFrb"):Connect(function()
			local new  = plr:GetAttribute("TotalKillsFrb") or 0
			local diff = new - (lastTKF[plr] or 0)
			if diff > 0 then
				local kv = plr:FindFirstChild("Kills")
				if kv then kv.Value = kv.Value + diff end
			end
			lastTKF[plr] = new
			if plr:GetAttribute("S_HideKills") == true then reveal(plr) end
		end))
	end
else
	reveal   = function() end
	trackTKF = function() end
end

--------------------------------------------------------------------
--          [[ HEAD‑UI  (PING / ULT / EVASIVE‑CD) ]]               --
--------------------------------------------------------------------
local mkGui, updGui

if (Config.PingBar or Config.UltBar or Config.EvasiveBar) then
	-- Color palette
	local DARK_BLUE   = Color3.fromRGB(  0, 80,220)
	local CYAN_BASE   = Color3.fromRGB( 80,255,255)
	local CYAN_PEAK   = Color3.fromRGB(150,255,255)
	local RED_LOW     = Color3.fromRGB(180, 20, 20)
	local RED_HIGH    = Color3.fromRGB(255, 60, 60)
	local ORANGE_LOW  = Color3.fromRGB(255,180, 50)  -- NEW
	local ORANGE_HIGH = Color3.fromRGB(255,220,120)  -- NEW
	local BASE_RED = Color3.fromRGB(255, 87, 87)  
	local HEAD_UI_MAX_DIST = 9999

	-- utility to create cloned magic bar
	local function newMagicBar(parentGui,label,yScale)
		local frame = MagicTemplate.Health:Clone()
		frame.Name              = label.."Frame"
		frame.AnchorPoint       = Vector2.new(0.5,0)
		frame.Position          = UDim2.new(0.5,0,yScale,0)
		frame.Size              = UDim2.new(0.9,0,0.25,0)
		frame.BackgroundTransparency = 1
		if frame:FindFirstChild("Ult") then frame.Ult:Destroy() end

		local lbl = frame:FindFirstChild("TextLabel")
		if lbl then
			lbl.Text = label
			local inner = lbl:FindFirstChildWhichIsA("TextLabel")
			if inner then inner.Text = label end
		end
		frame.Parent = parentGui

		local bar  = frame:FindFirstChild("Bar",  true)
		local inner = bar:FindFirstChild("Bar",  true)   
		local glow = frame:FindFirstChild("Glow", true)
		return {root=frame, bar=bar, inner=inner, glow=glow}
	end

	--------------------------[[ MKGUI ]]--------------------------
	mkGui = function(char)
		local head = char:FindFirstChild("Head") or char:WaitForChild("Head",2)
		if not head then return end
		if head:FindFirstChild("_StatGui") then head._StatGui:Destroy() end

		local gui = Instance.new("BillboardGui",head)
		gui.Name        = "_StatGui"
		gui.Adornee     = head
		gui.Size        = UDim2.new(0,GUI_WIDTH_PX,0,GUI_HEIGHT_PX)
		gui.MaxDistance = HEAD_UI_MAX_DIST
		gui.AlwaysOnTop = true
		gui.StudsOffset = Vector3.new(0,BASE_HEIGHT,0)

		-- Ping label
		local ping = Instance.new("TextLabel",gui)
		ping.Name                     = "PingLabel"
		ping.AnchorPoint              = Vector2.new(0.5,0)
		ping.Position                 = UDim2.new(0.5,0,0,0)
		ping.Size                     = UDim2.new(1,0,0.45,0)
		ping.BackgroundTransparency   = 1
		ping.Font                     = Enum.Font.ArialBold
		ping.TextScaled               = true
		local pStroke = Instance.new("UIStroke",ping)
		pStroke.Color     = Color3.new(0,0,0)
		pStroke.Thickness = 1

		-- Bars (middle & bottom)
		local evasiveBar = newMagicBar(gui,"Evasive",0.48)
		local ultBar     = newMagicBar(gui,"Ult",    0.75)

		-- legacy dummy frames (to preserve variable names used later)
		local dummy = Instance.new("Frame")
		dummy.Visible = false

		headGuis[char] = {
			gui        = gui,
			-- ping
			ping       = ping,
			pStroke    = pStroke,
			-- bars
			evasiveBar = evasiveBar,
			ultBar     = ultBar,
			-- dummies
			back       = dummy, bar = dummy, glow = dummy,
			-- runtime vars
			_evasiveStart = nil,
		}
	end

	local function setFill(t, alpha, colLow, colHigh, pulse)
		-- outer “shell” is just a container – keep it full‑width, default colour
		if t.bar then
			local yS, yO       = t.bar.Size.Y.Scale, t.bar.Size.Y.Offset
			t.bar.Size          = UDim2.new(1, 0, yS, yO)   -- always full length
			if t.bar then t.bar.ImageTransparency = 1 end
		end

		-- work out the colour for the INNER strip
		local col = (pulse and lerp(colLow, colHigh, pulse)) or colLow

		if t.inner then
			local yS, yO = t.inner.Size.Y.Scale, t.inner.Size.Y.Offset
			t.inner.Size        = UDim2.new(alpha, 0, yS, yO)   -- % fill
			t.inner.ImageColor3 = col
		end

		if t.glow then
			t.glow.ImageColor3 = col
			local baseT, osc   = 0.5, (pulse or 0)              -- 0.5↔0.2 pulse
			t.glow.ImageTransparency = baseT - 0.3*osc
			t.glow.Visible     = true
		end
	end


	-------------------------[[ UPDGUI ]]--------------------------
	updGui = function(plr,char)
		local h = headGuis[char]
		if not h then return end

		-- PING
		if PingBar then
			local ms = plr:GetAttribute("Ping") or 0
			h.ping.Text       = ("%d ms"):format(ms)
			h.ping.TextColor3 = pingColor(ms)
			h.ping.Visible    = true
			h.pStroke.Enabled = true
		else
			h.ping.Visible    = false
			h.pStroke.Enabled = false
		end

		-- ULT
		h.ultBar.root.Visible = UltBar
		if UltBar then
			local pct   = math.clamp(plr:GetAttribute("Ultimate") or 0,0,100)
			local live  = workspace:FindFirstChild("Live")
			local lc    = live and live:FindFirstChild(char.Name)
			local ulted = lc and lc:GetAttribute("Ulted")==true
			local pulse = (math.sin(os.clock()*math.pi*4)+1)/2
			if ulted then
				setFill(h.ultBar,1,CRIMSON_LOW,CRIMSON_HIGH,pulse)           -- pulsing crimson
			elseif pct >= 100 then
				setFill(h.ultBar, 1, BASE_RED, BASE_RED, nil)                -- bar solid red
				h.ultBar.glow.ImageColor3 = Color3.new(1,1,1)                -- pure white glow
				local gPulse = (math.sin(os.clock()*math.pi*4) + 1) / 2
				h.ultBar.glow.ImageTransparency = 0.5 - 0.3 * gPulse         -- 0.5 ↔ 0.2
				h.ultBar.glow.Visible = true
			else
				setFill(h.ultBar,pct/100,BASE_RED,BASE_RED,nil)              -- red fill %
				h.ultBar.glow.ImageTransparency = 0.5
			end
		end

		-- ▬▬▬ EVASIVE‑CD BAR ▬▬▬
		h.evasiveBar.root.Visible = Config.EvasiveBar
		if Config.EvasiveBar then
			local vars   = h.evasiveBar
			local live   = workspace:FindFirstChild("Live")
			local lc     = live and live:FindFirstChild(char.Name)
			local class  = lc and lc:GetAttribute("Character")
			local col    = CharacterColors[class] or Color3.new(1,1,1)

			local start  = h._evasiveStart          -- nil → full / ready
			if not start then
				-- ability ready ⇒ full **character‑colour** bar, no pulse
				setFill(vars, 1, col, col, nil)
			else
				local dt     = math.min(30, tick() - start)
				local alpha  = dt / 30
				local pulse  = (math.sin(os.clock()*math.pi*4) + 1) / 2
				setFill(vars, alpha, col, col, pulse)
				if dt >= 30 then h._evasiveStart = nil end
			end
		end


		-- ▬▬▬ dynamic vertical layout ▬▬▬
		local yPing, yEvasive, yUlt = 0, 0.48, 0.75
		if not Config.EvasiveBar and not Config.UltBar then
			yPing = 0.25                               -- only ping visible
		elseif not Config.EvasiveBar and Config.UltBar then
			yPing, yUlt = 0.3, 0.7                    -- ping top, ult middle
		elseif Config.EvasiveBar and not Config.UltBar then
			yPing, yEvasive = 0.3, 0.7                  -- ping top, evasive bottom
		end
		h.ping.Position                 = UDim2.new(0.5,0,yPing,0)
		h.evasiveBar.root.Position      = UDim2.new(0.5,0,yEvasive,0)
		h.ultBar.root.Position          = UDim2.new(0.5,0,yUlt,0)


		local function fadeGlow(glow, t)
			glow.ImageTransparency = glow.ImageTransparency + (1 - glow.ImageTransparency)*t
		end
		-- vertical lift + fade
		local root = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
		if root then
			local camPos  = workspace.CurrentCamera.CFrame.Position
			local camDist = (camPos - root.Position).Magnitude
			local extra   = (camDist > DEAD_ZONE) and math.clamp((camDist-DEAD_ZONE)*LIFT_PER_STUD,0,MAX_LIFT) or 0
			h.gui.StudsOffset = Vector3.new(0,BASE_HEIGHT+extra,0)
			local function fadeObj(obj,t) if obj then obj.ImageTransparency = t end end
			local lpRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
			if lpRoot then
				local playerDist = (lpRoot.Position - root.Position).Magnitude
				local t = fadeFactor(playerDist)
				h.ping.TextTransparency           = t
				h.pStroke.Transparency            = t
				fadeBarLayer(h.ultBar.inner,   t)
				fadeBarLayer(h.evasiveBar.inner,t)

				if h.ultBar.glow then h.ultBar.glow.ImageTransparency =
						h.ultBar.glow.ImageTransparency + (1-h.ultBar.glow.ImageTransparency)*t end
				if h.evasiveBar.glow then h.evasiveBar.glow.ImageTransparency =
						h.evasiveBar.glow.ImageTransparency + (1-h.evasiveBar.glow.ImageTransparency)*t end
			end
		end
	end
else
	mkGui  = function() end
	updGui = function() end
end

--------------------------------------------------------------------
--          [[ EVASIVE‑CANCEL TRACKING  (30 s  CD) ]]              --
--------------------------------------------------------------------
if Config.EvasiveBar then
	local liveFolder = workspace:WaitForChild("Live")

	-- helper to stamp start time on gui
	local function markEvasiveStart(plrName)
		for char,g in pairs(headGuis) do
			if char.Name == plrName then
				g._evasiveStart = tick()
			end
		end
	end

	-- watch already existing models
	for _,lm in ipairs(liveFolder:GetChildren()) do
		addConn(lm.ChildAdded:Connect(function(child)
			if child.Name == "RagdollCancel" then markEvasiveStart(lm.Name) end
		end))
	end

	-- watch future models
	addConn(liveFolder.ChildAdded:Connect(function(lm)
		addConn(lm.ChildAdded:Connect(function(child)
			if child.Name == "RagdollCancel" then markEvasiveStart(lm.Name) end
		end))
	end))
end


if Config.AntiDeathCounterSpy then
	do
		local liveFolder = workspace:WaitForChild("Live")

		local function highlightFor10sec(model)
			local hl = Instance.new("Highlight")
			hl.FillColor          = Color3.fromRGB(255, 0, 0)
			hl.FillTransparency   = 0.25
			hl.OutlineColor       = Color3.fromRGB(255, 0, 0)
			hl.OutlineTransparency = 0.5
			hl.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Parent             = model
			task.delay(10, function() if hl and hl.Parent then hl:Destroy() end end)
		end
		local function spawnDeathCounterEffects(liveChar)
			local hrp = liveChar:FindFirstChild("HumanoidRootPart") or liveChar:WaitForChild("HumanoidRootPart", 2)
			if not hrp then return end
			local folder = Instance.new("Folder", hrp)
			folder.Name = "_MenacingVFX"
			local clones = {}
			for i = 1, MEN_NUMBER do
				local gui = MenacingTemplate:Clone()
				gui.Parent                  = folder
				gui.Enabled                 = true
				gui.AlwaysOnTop             = false
				gui.Adornee                 = hrp
				local s = math.random() * (MEN_SCALE_MAX - MEN_SCALE_MIN) + MEN_SCALE_MIN
				gui.Size                    = UDim2.new(s,0,s,0)
				local ang = math.rad((360/MEN_NUMBER)*i + math.random()*20)
				local r   = math.random()*(MEN_RADIUS_MAX - MEN_RADIUS_MIN) + MEN_RADIUS_MIN
				local base = Vector3.new(math.cos(ang),0,math.sin(ang))*r
				local yOff = math.random()*(MEN_SPAWN_Y_MAX-MEN_SPAWN_Y_MIN)+MEN_SPAWN_Y_MIN
				gui.StudsOffsetWorldSpace   = base + Vector3.new(0,yOff,0)
				local img = gui:FindFirstChildOfClass("ImageLabel")
				if img then img.Visible=true img.ImageTransparency=0 img.BackgroundTransparency=1 end
				table.insert(clones, {gui=gui, img=img})
			end
			local startTime, idx = tick(), 1
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local t = tick() - startTime
				for _, c in ipairs(clones) do
					if c.gui.Parent then
						c.gui.StudsOffsetWorldSpace += Vector3.new(
							(math.random()-0.5)*MEN_JITTER_AMT,
							(math.random()-0.5)*MEN_JITTER_AMT,
							(math.random()-0.5)*MEN_JITTER_AMT
						)
					end
				end
				if idx <= MEN_NUMBER and t >= idx then
					local c = clones[idx]
					idx = idx + 1
					local g, img = c.gui, c.img
					local initial = g.StudsOffsetWorldSpace
					local upPos   = initial + Vector3.new(0, MEN_HOP_OFFSET, 0)
					local downPos = initial + Vector3.new(0, MEN_HOP_OFFSET + MEN_DROP_DIST, 0)
					local hop  = TweenService:Create(g, TweenInfo.new(MEN_HOP_TIME,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {StudsOffsetWorldSpace = upPos})
					local fall = TweenService:Create(g, TweenInfo.new(MEN_DROP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {StudsOffsetWorldSpace = downPos})
					if img then
						local fade = TweenService:Create(img, TweenInfo.new(MEN_HOP_TIME+MEN_DROP_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {ImageTransparency = 1})
						fade:Play()
					end
					hop.Completed:Connect(function() fall:Play() end)
					fall.Completed:Connect(function() g:Destroy() end)
					hop:Play()
				end
				if t > MEN_LIFE_SECONDS + MEN_HOP_TIME + MEN_DROP_TIME then
					conn:Disconnect()
					if folder and folder.Parent then folder:Destroy() end
				end
			end)
		end


		local function hookDeathCounter(liveModel)

			if liveModel.Name == LP.Name then
				return
			end
			local function fireVFX()
				highlightFor10sec(liveModel)
				spawnDeathCounterEffects(liveModel)
			end

			if liveModel:FindFirstChild("Counter") then fireVFX() end

			addConn(liveModel.ChildAdded:Connect(function(child)
				if child.Name == "Counter" then fireVFX() end
			end))


			local humanoid = liveModel:FindFirstChildOfClass("Humanoid") or liveModel:WaitForChild("Humanoid",2)
			local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator",2)
			addConn(animator.AnimationPlayed:Connect(function(track)
				if track.Animation and track.Animation.AnimationId == "rbxassetid://11343318134" then
		
					for _, d in ipairs(liveModel:GetDescendants()) do
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


		for _, lm in ipairs(liveFolder:GetChildren()) do
			hookDeathCounter(lm)
		end
		addConn(liveFolder.ChildAdded:Connect(hookDeathCounter))
	end
end



if Config.AntiDeathCounter then
	do
		local player = LP
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
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl ~= player and pl.Character then
					local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
					if hrp and (hrp.Position - pos).Magnitude <= BACK_TELEPORT_RADIUS then
						return true
					end
				end
			end
			return false
		end

		local function restoreCameraAndCleanup()
			workspace.CurrentCamera:Destroy()
			wait(0.1)
			repeat wait() until player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
			local cam = workspace.CurrentCamera
			cam.CameraSubject = player.Character:FindFirstChildWhichIsA("Humanoid")
			cam.CameraType = Enum.CameraType.Custom
			player.CameraMinZoomDistance = 0.5
			player.CameraMaxZoomDistance = 400
			player.CameraMode = Enum.CameraMode.Classic
			if player.Character.Head then
				player.Character.Head.Anchored = false
			end
		end

		local function onCharacter(char)
		if baseplate then baseplate:Destroy(); baseplate = nil end
		isTeleporting   = false
		teleportStart   = nil
		originalCFrame  = nil
			local hum = char:WaitForChild("Humanoid", 2)
			local hrp = char:WaitForChild("HumanoidRootPart", 2)
			local animator = hum:FindFirstChildOfClass("Animator") or hum:WaitForChild("Animator", 2)
			animator.AnimationPlayed:Connect(function(track)
				if track.Animation and track.Animation.AnimationId == TELEPORT_ANIMATION_ID and not isTeleporting then
					isTeleporting = true
					originalCFrame = hrp.CFrame
					createBaseplate(hrp.Position)
					teleportStart = tick()
					local conn
					conn = RunService.Heartbeat:Connect(function()
						if not hrp.Parent then conn:Disconnect() return end
						hrp.CFrame = CFrame.new(baseplate.Position + Vector3.new(0, TELEPORT_HEIGHT_OFFSET, 0))
						if tick() - teleportStart >= MIN_TELEPORT_DURATION and not anyPlayersNearby(hrp.Position) then
							conn:Disconnect()
							hrp.CFrame = originalCFrame
							restoreCameraAndCleanup()
							if baseplate then baseplate:Destroy() baseplate = nil end
							isTeleporting = false
						end
					end)
				end
			end)
		end

		player.CharacterAdded:Connect(onCharacter)
		if player.Character then onCharacter(player.Character) end
	end
end

--------------------------------------------------------------------
--                      [[ attachPlayer ]]                         --
--------------------------------------------------------------------
local function attachPlayer(plr)
	----------------------------------------------------------------
	-- ORIGINAL BODY (name‑distance tweaks, leaderboard spy, etc.)
	----------------------------------------------------------------
	if plr == LP then
		addConn(plr.CharacterAdded:Connect(function(c)
			c:WaitForChild("Humanoid",4).NameDisplayDistance   = 100
			c:WaitForChild("Humanoid",4).HealthDisplayDistance = 100
		end))
		if plr.Character then
			local c = plr.Character
			c:WaitForChild("Humanoid",4).NameDisplayDistance   = 100
			c:WaitForChild("Humanoid",4).HealthDisplayDistance = 100
		end
		return
	end

	if LeaderboardSpy and (plr:FindFirstChild("Kills") or plr:FindFirstChild("Total Kills")) then
		if plr:GetAttribute("S_HideKills") == true then reveal(plr) end
		trackTKF(plr)
		if plr:GetAttribute("S_HideKills") == true then hiddenKills[plr] = true end

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

	----------------------------------------------------------------
	--  HEAD‑GUI handling (Ping / Ult / Evasive) – NEW + legacy
	----------------------------------------------------------------
	if PingBar or UltBar or EvasiveBar then
		local function onChar(char)
			mkGui(char)
			updGui(plr,char)
		end
		if plr.Character then onChar(plr.Character) end
		addConn(plr.CharacterAdded:Connect(onChar))

		if PingBar then
			addConn(plr:GetAttributeChangedSignal("Ping"):Connect(function()
				if plr.Character then updGui(plr,plr.Character) end
			end))
		end
		if UltBar then
			addConn(plr:GetAttributeChangedSignal("Ultimate"):Connect(function()
				if plr.Character then updGui(plr,plr.Character) end
			end))
		end
		-- continuous UI refresh
		addConn(RunService.Heartbeat:Connect(function()
			if plr.Character then updGui(plr,plr.Character) end
		end))
	end

	-- cleanup on leave
	addConn(plr.AncestryChanged:Connect(function(_,parent)
		if not parent then lastTKF[plr] = nil end
	end))
end

for _,p in ipairs(Players:GetPlayers()) do attachPlayer(p) end
addConn(Players.PlayerAdded:Connect(attachPlayer))


if Config.LeaderboardSpy then
	do
		addConn(RunService.Heartbeat:Connect(function()
			for _,plr in ipairs(Players:GetPlayers()) do
				if plr ~= LP then
					local hidden = plr:GetAttribute("S_HideKills")
					if hidden then
						if not hiddenKills[plr] then
							hiddenKills[plr] = true
							trackTKF(plr)
						end
						reveal(plr)
					else
						if hiddenKills[plr] then hiddenKills[plr] = nil end
						clearReveal(plr)
					end
				end
			end
		end))
	end
end

--------------------------------------------------------------------
--               [[ IN‑GAME SETTINGS PANEL GUI ]]                  --
--------------------------------------------------------------------
do
	local UserInputService = game:GetService("UserInputService")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name           = "_StatScriptSettings"
	screenGui.ResetOnSpawn   = false
	screenGui.Parent         = LP:WaitForChild("PlayerGui")

	local HEADER_HEIGHT    = 60
	local BTN_HEIGHT       = 23
	local TOGGLE_COUNT     = 6               -- NEW count
	local TOGGLES_HEIGHT   = TOGGLE_COUNT*36 + 12 + BTN_HEIGHT
	local COLLAPSED_HEIGHT = HEADER_HEIGHT + BTN_HEIGHT
	local OPEN_HEIGHT      = HEADER_HEIGHT + BTN_HEIGHT + TOGGLES_HEIGHT

	local panel = Instance.new("Frame",screenGui)
	panel.Name             = "SettingsPanel"
	panel.Size             = UDim2.new(0,240,0,COLLAPSED_HEIGHT)
	panel.Position         = UDim2.new(0,8,0.5,-COLLAPSED_HEIGHT/2)
	panel.BackgroundColor3 = Color3.fromRGB(40,40,40)
	panel.ClipsDescendants = true
	Instance.new("UICorner",panel).CornerRadius = UDim.new(0,8)

	local dragBar = Instance.new("Frame",panel)
	dragBar.Name             = "DragBar"
	dragBar.Size             = UDim2.new(1,0,0,28)
	dragBar.Position         = UDim2.new(0,0,0,0)
	dragBar.BackgroundColor3 = Color3.fromRGB(60,60,60)
	Instance.new("UICorner",dragBar).CornerRadius = UDim.new(0,6)

	local icon = Instance.new("TextLabel",dragBar)
	icon.Size                     = UDim2.new(1,0,1,0)
	icon.BackgroundTransparency   = 1
	icon.Text                     = "≡"
	icon.Font                     = Enum.Font.SourceSansBold
	icon.TextSize                 = 20
	icon.TextColor3               = Color3.new(1,1,1)
	icon.TextScaled               = true

	-- drag logic (unchanged) --------------------------------------
	local dragging, dragStart, startPos
	dragBar.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging  = true
			dragStart = inp.Position
			startPos  = panel.Position
			inp.Changed:Connect(function()
				if inp.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = inp.Position - dragStart
			panel.Position = UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,
			                           startPos.Y.Scale,startPos.Y.Offset+delta.Y)
		end
	end)

	local title = Instance.new("TextLabel",panel)
	title.Name                   = "Title"
	title.Text                   = "Made by Azacks"
	title.Font                   = Enum.Font.SourceSansBold
	title.TextSize               = 25
	title.TextColor3             = Color3.new(1,1,1)
	title.BackgroundTransparency = 1
	title.Size                   = UDim2.new(1,0,0,16)
	title.Position               = UDim2.new(0,0,0,28)
	title.TextYAlignment         = Enum.TextYAlignment.Top

	local openBtn = Instance.new("TextButton",panel)
	openBtn.Name             = "OpenBtn"
	openBtn.Text             = "OPEN"
	openBtn.Font             = Enum.Font.SourceSansBold
	openBtn.TextSize         = 18
	openBtn.Size             = UDim2.new(1,0,0,BTN_HEIGHT)
	openBtn.Position         = UDim2.new(0,0,0,HEADER_HEIGHT)
	openBtn.BackgroundColor3 = Color3.fromRGB(46,204,113)
	openBtn.TextColor3       = Color3.new(1,1,1)
	Instance.new("UICorner",openBtn).CornerRadius = UDim.new(0,6)

	local closeBtn = Instance.new("TextButton",panel)
	closeBtn.Name             = "CloseBtn"
	closeBtn.Text             = "CLOSE"
	closeBtn.Font             = Enum.Font.SourceSansBold
	closeBtn.TextSize         = 18
	closeBtn.Size             = UDim2.new(1,0,0,BTN_HEIGHT)
	closeBtn.Position         = UDim2.new(0,0,0,HEADER_HEIGHT)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
	closeBtn.TextColor3       = Color3.new(1,1,1)
	closeBtn.Visible          = false
	Instance.new("UICorner",closeBtn).CornerRadius = UDim.new(0,6)

	local togglesFrame = Instance.new("Frame",panel)
	togglesFrame.Name                 = "Toggles"
	togglesFrame.Size                 = UDim2.new(1,0,0,TOGGLES_HEIGHT)
	togglesFrame.Position             = UDim2.new(0,0,0,HEADER_HEIGHT+BTN_HEIGHT)
	togglesFrame.BackgroundTransparency = 1
	togglesFrame.Visible              = false

	local toggleNames = {
		"AntiDeathCounter",
		"LeaderboardSpy",
		"AntiDeathCounterSpy",
		"UltBar",
		"PingBar",
		"EvasiveBar",          -- NEW
	}

	local yOff = 0
	for _,name in ipairs(toggleNames) do
		local lbl = Instance.new("TextLabel",togglesFrame)
		lbl.Text                   = name
		lbl.Font                   = Enum.Font.SourceSans
		lbl.TextSize               = 18
		lbl.TextColor3             = Color3.new(1,1,1)
		lbl.BackgroundTransparency = 1
		lbl.Size                   = UDim2.new(0.7,0,0,28)
		lbl.Position               = UDim2.new(0,12,0,yOff)

		local btn = Instance.new("TextButton",togglesFrame)
		btn.Size              = UDim2.new(0,60,0,28)
		btn.Position          = UDim2.new(1,-72,0,yOff)
		btn.Font              = Enum.Font.SourceSans
		btn.TextSize          = 18
		Instance.new("UICorner",btn).CornerRadius = UDim.new(0,6)

		local function refresh()
			btn.Text             = Config[name] and "On" or "Off"
			btn.BackgroundColor3 = Config[name] and Color3.fromRGB(46,204,113)
			                    or Color3.fromRGB(192,57,43)
		end
		btn.MouseButton1Click:Connect(function()
			Config[name] = not Config[name]
			refreshFlags()                         -- <‑‑ NEW
			for _,pl in ipairs(Players:GetPlayers()) do   -- live refresh of UIs
				if pl.Character then updGui(pl,pl.Character) end
			end
			refresh()                              -- keep button text in‑sync
		end)
		refresh()
		yOff = yOff + 36
	end

	local killBtn = Instance.new("TextButton",togglesFrame)
	killBtn.Text              = "Kill Script"
	killBtn.Font              = Enum.Font.SourceSansBold
	killBtn.TextSize          = 18
	killBtn.Size              = UDim2.new(1,-24,0,32)
	killBtn.Position          = UDim2.new(0,12,0,yOff)
	killBtn.BackgroundColor3  = Color3.fromRGB(200,50,50)
	killBtn.TextColor3        = Color3.new(1,1,1)
	Instance.new("UICorner",killBtn).CornerRadius = UDim.new(0,6)
	killBtn.MouseButton1Click:Connect(function()
		for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		for _,v in pairs(headGuis) do if v.gui then v.gui:Destroy() end end
		screenGui:Destroy()
		script:Destroy()
	end)

	local function toggleOpen(state)
		panel.Size           = state and UDim2.new(0,240,0,OPEN_HEIGHT)
		                              or UDim2.new(0,240,0,COLLAPSED_HEIGHT)
		openBtn.Visible      = not state
		closeBtn.Visible     = state
		togglesFrame.Visible = state
	end
	openBtn.MouseButton1Click:Connect(function() toggleOpen(true)  end)
	closeBtn.MouseButton1Click:Connect(function() toggleOpen(false) end)
end

--------------------------------------------------------------------
--                         [[ FIN ]]                               --
--------------------------------------------------------------------
