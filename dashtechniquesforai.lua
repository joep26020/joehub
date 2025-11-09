--!strict
-- Keep-Orientation Dash Modes (FDash / BDash / SideDash) + Offensive/Defensive
-- NEW FDash(OFF): Face target -> start real F-dash (W+Q) -> when ≤2 studs,
-- hold a 90° around-target orientation (CW/CCW) for 0.30s -> then re-face target.

-- ========================= SERVICES =========================
local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local RunService  = game:GetService("RunService")
local VIM         = game:GetService("VirtualInputManager")

local LP   = Players.LocalPlayer
local char = LP.Character or LP.CharacterAdded:Wait()
local hum  = char:WaitForChild("Humanoid")
local hrp  = char:WaitForChild("HumanoidRootPart")
local cam  = workspace.CurrentCamera

-- ========================== CONFIG ==========================
local KEY_Q       = Enum.KeyCode.Q
local HOLD_Q      = 0.12
local RELOCK_T    = 0.50

local CLOSE_D     = 4.0          -- common “very close” cutoff
local SIDE_OFF_RELOCK = 3.5      -- side dash relock range

local LOOP_GAP    = 1.2          -- seconds between loopOnce ticks

-- Cooldowns
local CD_FDASH    = 10.0
local CD_BDASH    = 10.0
local CD_SIDED    = 2.0

-- Backdash pre-end face timing
local PREEND_BDASH_FACE = 0.25

-- Forward dash kinematics window (approx time F-dash influences facing)
local FDASH_TIME       = 0.68

-- NEW forward dash orbit rule (when very close)
local ORBIT_TRIGGER    = 2.0      -- studs: when we first get this close, start orbit phase
local ORBIT_DURATION   = 0.4    -- seconds to keep 90° orientation before re-facing

-- Optional animation ids (if you want animator hooks)
local ANIM_FDASH  = "10479335397"
local ANIM_BDASH  = "10491993682"
local ANIM_SIDE_L = "10480796021"
local ANIM_SIDE_R = "10480793962"

-- =========================== STATE ==========================
local mode       = "fdash"       -- "fdash" | "bdash" | "sidedash"
local style      = "offensive"   -- "offensive" | "defensive"
local running    = false
local uiRoot     = nil
local busyOrient = false
local lastTarget : BasePart? = nil

local lastFDash  = -1e9
local lastBDash  = -1e9
local lastSide   = -1e9

-- ========================== HELPERS =========================
local function now() return os.clock() end

local function canUseDash(which: string)
	local t = now()
	if which == "fdash" then return (t - lastFDash) >= CD_FDASH
	elseif which == "bdash" then return (t - lastBDash) >= CD_BDASH
	else return (t - lastSide) >= CD_SIDED end
end

local function markDash(which: string)
	local t = now()
	if which == "fdash" then lastFDash = t
	elseif which == "bdash" then lastBDash = t
	else lastSide = t end
end

local function flat(v: Vector3) return Vector3.new(v.X,0,v.Z) end

local function press(k: Enum.KeyCode, down: boolean)
	VIM:SendKeyEvent(down, k, false, game)
end

local function holdQ(d: number?)
	press(KEY_Q,true); task.wait(d or HOLD_Q); press(KEY_Q,false)
end

local function nearestHRP(): (BasePart?, number?)
	if not hrp then return nil, nil end
	local me = hrp.Position
	local best : BasePart? = nil
	local bd : number? = nil
	for _,p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			local tHum = p.Character:FindFirstChildOfClass("Humanoid")
			local tHRP = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if tHum and tHum.Health > 0 and tHRP then
				local d = (tHRP.Position - me).Magnitude
				if not bd or d < bd then bd, best = d, tHRP end
			end
		end
	end
	return best, bd
end

local function alignCamToForward()
	if not cam then return end
	local cp = cam.CFrame.Position
	local f  = flat(hrp.CFrame.LookVector)
	if f.Magnitude < 1e-3 then return end
	f = f.Unit
	cam.CFrame = CFrame.new(cp, Vector3.new(cp.X+f.X, cp.Y, cp.Z+f.Z))
end

local function faceToward(pos: Vector3)
	local here = hrp.Position
	local to   = flat(pos - here); if to.Magnitude<1e-3 then return end
	hrp.CFrame = CFrame.lookAt(here, here + to.Unit)
	alignCamToForward()
end

local function faceAwayFrom(pos: Vector3)
	local here = hrp.Position
	local to   = flat(pos - here); if to.Magnitude<1e-3 then return end
	hrp.CFrame = CFrame.lookAt(here, here + (-to.Unit))
	alignCamToForward()
end

local function facePerp(toUnit: Vector3, cw: boolean)
	local perp = cw and Vector3.new(toUnit.Z,0,-toUnit.X) or Vector3.new(-toUnit.Z,0,toUnit.X)
	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + perp.Unit)
	alignCamToForward()
end

-- Positive if ME is behind target along target's LookVector
local function behindAmount(mePos: Vector3, tPos: Vector3, tLookFlat: Vector3): number
	local toMe = flat(mePos - tPos)
	if toMe.Magnitude < 1e-3 then return 0 end
	return toMe:Dot(tLookFlat.Unit) * -1
end

-- ================ ALWAYS-ON AIM-LOCK (when idle) ================
local idleLockConn = RunService.Heartbeat:Connect(function()
	if not running or busyOrient then return end
	if not (hum and hrp and hum.Health>0) then return end
	local tgt = nearestHRP()
	if tgt then
		lastTarget = tgt
		faceToward(tgt.Position)
	elseif lastTarget then
		faceToward(lastTarget.Position)
	end
end)

-- Repeat facing for a while (or until earlyBreak returns true)
local function keepFacingFor(timeout: number, faceFn: ()->(), earlyBreak: (()->boolean)?)
	local t0 = now()
	while now() - t0 < timeout do
		if not running or not hum or hum.Health<=0 then break end
		if earlyBreak and earlyBreak() then break end
		faceFn()
		RunService.Heartbeat:Wait()
	end
end

-- Backdash watcher: keep facing, and allow a callback shortly before dash end
local function keepFacingUntilBackdashEnd(faceFn: ()->(), beforeEndFaceFn: (()->())?)
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local active, started = false, false
	local track, startT, length = nil, 0.0, 0.0
	local con
	if animator then
		con = animator.AnimationPlayed:Connect(function(tr)
			local id = tostring(tr.Animation and tr.Animation.AnimationId or ""):match("(%d+)$") or ""
			if id == ANIM_BDASH then
				active, started = true, true
				track  = tr
				startT = now()
				length = (tr.Length and tr.Length>0) and tr.Length or 0.0
				tr.Stopped:Connect(function() active = false end)
			end
		end)
	end
	local hardStart = now()
	local hardDur   = 1.25
	while running and hum and hum.Health>0 and (active or (not started and now()<hardStart+hardDur)) do
		if beforeEndFaceFn then
			if active and length>0 then
				if (length - (now()-startT)) <= PREEND_BDASH_FACE then beforeEndFaceFn() end
			elseif not started then
				if (hardStart+hardDur - now()) <= PREEND_BDASH_FACE then beforeEndFaceFn() end
			end
		end
		faceFn()
		RunService.Heartbeat:Wait()
	end
	if con then pcall(function() con:Disconnect() end) end
end

-- ======================== SIDE DASH =========================
-- OFF: if ≤3.5 at dash start (or while inside), stay hard-locked; else perpendicular.
local function doSideDash(tHRP: BasePart, offensive: boolean)
	if not (tHRP and hrp) then return end
	busyOrient = true
	local to  = flat(tHRP.Position - hrp.Position); if to.Magnitude<1e-3 then busyOrient=false return end
	local toU = to.Unit
	local cw  = (math.random()<0.5)

	local function chooseSideKey()
		local right = flat(hrp.CFrame.RightVector).Unit
		local dot   = right.X*toU.X + right.Z*toU.Z
		if offensive then
			return (dot >= 0) and Enum.KeyCode.D or Enum.KeyCode.A -- toward
		else
			return (dot >= 0) and Enum.KeyCode.A or Enum.KeyCode.D -- away
		end
	end

	facePerp(toU, cw)
	local sideKey = chooseSideKey()
	press(sideKey,true); task.wait(0.02); press(KEY_Q,true); task.wait(HOLD_Q); press(KEY_Q,false)

	keepFacingFor(
		RELOCK_T,
		function()
			local dNow = (tHRP.Position - hrp.Position).Magnitude
			if offensive then
				if dNow <= SIDE_OFF_RELOCK then
					faceToward(tHRP.Position) -- hard lock while inside 3.5
				else
					local liveToU = flat(tHRP.Position - hrp.Position).Unit
					facePerp(liveToU, cw)
				end
			else
				local liveToU = flat(tHRP.Position - hrp.Position).Unit
				facePerp(liveToU, cw)
			end
		end
	)

	press(sideKey,false)
	faceToward(tHRP.Position)
	busyOrient = false
end

-- ======================= FORWARD DASH =======================
-- NEW OFF BEHAVIOR:
--   1) Face target and start real F-dash (W+Q).
--   2) When distance ≤ ORBIT_TRIGGER for the first time, choose CW/CCW and
--      keep perpendicular orientation (90° around) for ORBIT_DURATION.
--   3) After that, re-face the target for the remainder of the dash.
local function doForwardDash(tHRP: BasePart, offensive: boolean)
	if not (tHRP and hrp) then return end
	busyOrient = true

	local tPos0 = tHRP.Position
	local to0   = flat(tPos0 - hrp.Position); if to0.Magnitude<1e-3 then busyOrient=false return end

	-- Pre-orient and start real forward dash
	if offensive then
		faceToward(tPos0)
	else
		faceAwayFrom(tPos0)
	end
	press(Enum.KeyCode.W,true); task.wait(0.02)
	press(KEY_Q,true); task.wait(HOLD_Q); press(KEY_Q,false)

	local tStart = now()
	local orbiting = false
	local orbitCW  = (math.random() < 0.5)
	local tOrbitStart = 0.0

	while (now() - tStart) < FDASH_TIME and hum and hum.Health > 0 do
		local tPos = tHRP.Position
		local to   = flat(tPos - hrp.Position)
		if to.Magnitude < 1e-3 then break end
		local toU  = to.Unit

		if offensive then
			if not orbiting then
				-- Drive straight (facing them) until we breach the trigger
				faceToward(tPos)
				if to.Magnitude <= ORBIT_TRIGGER then
					orbiting = true
					tOrbitStart = now()
				end
			else
				-- Keep 90° orientation for ORBIT_DURATION, then re-lock on
				local elapsed = now() - tOrbitStart
				if elapsed <= ORBIT_DURATION then
					facePerp(toU, orbitCW) -- 90° around them CW/CCW
				else
					faceToward(tPos)       -- relock after orbit window
				end
			end
		else
			-- Defensive forward dash = away from target (simple)
			faceAwayFrom(tPos)
		end

		RunService.Heartbeat:Wait()
	end

	press(Enum.KeyCode.W,false)
	faceToward(tHRP.Position) -- ensure lock after finish
	busyOrient = false
end

-- ======================== BACK DASH =========================
-- OFF: orbit when ≤4 studs; face enemy PREEND_BDASH_FACE before end.
local function doBackDash(tHRP: BasePart, offensive: boolean)
	if not (tHRP and hrp) then return end
	busyOrient = true
	local to   = flat(tHRP.Position - hrp.Position); if to.Magnitude<1e-3 then busyOrient=false return end

	if offensive then
		faceAwayFrom(tHRP.Position)
	else
		faceToward(tHRP.Position)
	end

	press(Enum.KeyCode.S,true); task.wait(0.02)
	press(KEY_Q,true); task.wait(HOLD_Q); press(KEY_Q,false)

	if offensive then
		local orbitCW = (math.random() < 0.5)
		keepFacingUntilBackdashEnd(
			function()
				local liveTo = flat(tHRP.Position - hrp.Position)
				local dNow   = liveTo.Magnitude
				if dNow > 1e-3 then
					local liveToU = liveTo.Unit
					if dNow <= CLOSE_D then
						facePerp(liveToU, orbitCW)
					else
						faceAwayFrom(tHRP.Position)
					end
				end
			end,
			function()
				-- PRE-END override: look at target so recovery faces them
				faceToward(tHRP.Position)
			end
		)
	else
		keepFacingFor(RELOCK_T, function() faceToward(tHRP.Position) end)
	end

	press(Enum.KeyCode.S,false)
	faceToward(tHRP.Position)
	busyOrient = false
end

-- ============== EVASIVE EXIT -> OFFENSIVE SIDE DASH =========
local evasiveCon : RBXScriptConnection? = nil
local function attachEvasiveHook(model: Model)
	if evasiveCon then pcall(function() evasiveCon:Disconnect() end) end
	evasiveCon = model.DescendantAdded:Connect(function(d)
		if d.Name == "RagdollCancel" then
			task.defer(function()
				if running and canUseDash("sidedash") then
					local tHRP = nearestHRP()
					if tHRP then
						markDash("sidedash")
						doSideDash(tHRP, true)
					end
				end
			end)
		end
	end)
end
attachEvasiveHook(char)

-- ===================== RESPAWN HOOKS ========================
LP.CharacterAdded:Connect(function(c)
	char = c
	hum  = c:WaitForChild("Humanoid")
	hrp  = c:WaitForChild("HumanoidRootPart")
	cam  = workspace.CurrentCamera
	hum.AutoRotate = false
	attachEvasiveHook(c)
end)
hum.AutoRotate = false

-- ======================== MAIN LOOP =========================
local function loopOnce()
	if not (running and hum and hrp and hum.Health>0) then return end
	local tHRP = nearestHRP()
	if not tHRP then return end
	lastTarget = tHRP

	faceToward(tHRP.Position) -- lock before dash

	if mode == "sidedash" then
		if canUseDash("sidedash") then
			markDash("sidedash")
			doSideDash(tHRP, style=="offensive")
		end
	elseif mode == "fdash" then
		if canUseDash("fdash") then
			markDash("fdash")
			doForwardDash(tHRP, style=="offensive")
		end
	else -- bdash
		if canUseDash("bdash") then
			markDash("bdash")
			doBackDash(tHRP, style=="offensive")
		end
	end
end

local function startLoop()
	if running then return end
	running = true
	if hum then hum.AutoRotate = false end
	task.spawn(function()
		while running do
			loopOnce()
			for _=1, math.floor(LOOP_GAP/0.1) do
				if not running then break end
				task.wait(0.1)
			end
		end
	end)
end

local function stopLoop() running = false end

local function exitScript()
	stopLoop()
	if hum then hum.AutoRotate = true end
	if idleLockConn then pcall(function() idleLockConn:Disconnect() end) end
	if evasiveCon then pcall(function() evasiveCon:Disconnect() end) end
	if uiRoot then uiRoot:Destroy() end
end

-- =========================== UI ============================
local function mkUI()
	local g = Instance.new("ScreenGui")
	g.Name = "DashModesUI"
	g.ResetOnSpawn = false
	g.Parent = gethui and gethui() or game:GetService("CoreGui")
	uiRoot = g

	local f = Instance.new("Frame")
	f.Size = UDim2.new(0, 640, 0, 230)
	f.Position = UDim2.new(0, 40, 0, 100)
	f.BackgroundColor3 = Color3.fromRGB(20,22,30)
	f.BorderSizePixel = 0
	f.Parent = g
	local s = Instance.new("UIStroke", f) s.Color = Color3.fromRGB(76,110,255)

	local function btn(text, x, y, w, cb, color)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, w or 110, 0, 34)
		b.Position = UDim2.new(0, x, 0, y)
		b.BackgroundColor3 = color or Color3.fromRGB(48,60,96)
		b.TextColor3 = Color3.fromRGB(240,240,240)
		b.Font = Enum.Font.GothamBold; b.TextSize = 16; b.Text = text
		b.Parent = f
		b.MouseButton1Click:Connect(cb)
		return b
	end

	-- Mode
	local bFD = btn("FDash",    10,  10, 110, function() mode="fdash";    bFD.BackgroundColor3=Color3.fromRGB(68,120,96) end)
	local bBD = btn("BDash",    130, 10, 110, function() mode="bdash";    bBD.BackgroundColor3=Color3.fromRGB(68,120,96) end)
	local bSD = btn("Side",     250, 10, 110, function() mode="sidedash"; bSD.BackgroundColor3=Color3.fromRGB(68,120,96) end)

	-- Style
	local bOff= btn("Offensive",10,  52, 110, function() style="offensive"; bOff.BackgroundColor3=Color3.fromRGB(68,120,96) end)
	local bDef= btn("Defensive",130, 52, 110, function() style="defensive"; bDef.BackgroundColor3=Color3.fromRGB(120,68,68) end)

	-- Start/Stop/Exit
	local bStart = btn("Start",  370, 10, 260, function() startLoop() end, Color3.fromRGB(60,120,60))
	local bStop  = btn("Stop",   370, 52, 260, function() stopLoop()  end, Color3.fromRGB(140,80,60))
	local bExit  = btn("Exit",   370, 94, 260, function() exitScript() end, Color3.fromRGB(100,40,40))

	-- Info
	local info = Instance.new("TextLabel")
	info.Size = UDim2.new(1, -20, 0, 90)
	info.Position = UDim2.new(0, 10, 0, 150)
	info.BackgroundTransparency = 1
	info.TextWrapped = true
	info.Text = string.format(
		"FDash(OFF): face -> W+Q -> at ≤%.1f studs orbit 90° (CW/CCW) for %.2fs -> re-face • BDash(OFF): orbit ≤%.0f + face %.2fs pre-end • Side(OFF): hard-lock ≤%.1f • CDs F/B=10s, Side=2s",
		ORBIT_TRIGGER, ORBIT_DURATION, CLOSE_D, PREEND_BDASH_FACE, SIDE_OFF_RELOCK
	)
	info.Font = Enum.Font.Gotham
	info.TextSize = 13
	info.TextColor3 = Color3.fromRGB(210,220,255)
	info.Parent = f

	-- Dragging
	local dragging, startPos, startXY
	f.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 then
			dragging = true; startXY = i.Position; startPos = f.Position
			i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
		end
	end)
	f.InputChanged:Connect(function(i)
		if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
			local d = i.Position - startXY
			f.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

mkUI()

-- ======================== HOTKEYS ===========================
UIS.InputBegan:Connect(function(i,gpe)
	if gpe then return end
	if i.KeyCode == Enum.KeyCode.O then style="offensive"
	elseif i.KeyCode == Enum.KeyCode.P then style="defensive"
	elseif i.KeyCode == Enum.KeyCode.K then mode="fdash"
	elseif i.KeyCode == Enum.KeyCode.L then mode="bdash"
	elseif i.KeyCode == Enum.KeyCode.Semicolon then mode="sidedash"
	elseif i.KeyCode == Enum.KeyCode.Equals then startLoop()
	elseif i.KeyCode == Enum.KeyCode.Minus then stopLoop()
	elseif i.KeyCode == Enum.KeyCode.BackSlash then
		-- exit
		stopLoop()
		if hum then hum.AutoRotate = true end
		if idleLockConn then pcall(function() idleLockConn:Disconnect() end) end
		if uiRoot then uiRoot:Destroy() end
	end
end)

