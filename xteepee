

-- LocalScript (place in StarterPlayerScripts)
--[[
-- set your globals
_G.FollowConfig = {
  SPEED         = 600,
  BEHIND_DIST   = 5,
  ANIM_INTERVAL = 0.2,
}
-- then load
loadstring(yourScript)()
]]

local cfg           = _G.FollowConfig
local SPEED         = cfg.SPEED
local BEHIND_DIST   = cfg.BEHIND_DIST
local ANIM_INTERVAL = cfg.ANIM_INTERVAL

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer

-- load animation once
local animation = Instance.new("Animation")
animation.AnimationId = "rbxassetid://15957361339"

-- respawned-character vars
local character, hrp, humanoid, animator, track

-- UI for destroying the script
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FollowGui"
screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

local destroyButton = Instance.new("TextButton")
destroyButton.Size = UDim2.new(0,100,0,50)
destroyButton.Position = UDim2.new(0,10,0.5,-25)
destroyButton.AnchorPoint = Vector2.new(0,0.5)
destroyButton.Text = "Destroy Script"
destroyButton.Parent = screenGui

-- state & connections
local isFollowing = false
local target
local movementConn
local animPlaying = false

-- find nearest alive player
local function getNearest()
    if not hrp then return end
    local best, minD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character then
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            local part = p.Character:FindFirstChild("HumanoidRootPart")
            if h and part and h.Health > 0 then
                local d = (part.Position - hrp.Position).Magnitude
                if d < minD then
                    minD, best = d, p
                end
            end
        end
    end
    return best
end

-- set up on respawn
local function onCharAdded(char)
    character = char
    hrp       = char:WaitForChild("HumanoidRootPart")
    humanoid  = char:WaitForChild("Humanoid")
    animator  = humanoid:WaitForChild("Animator")
    track     = animator:LoadAnimation(animation)
end

Players.LocalPlayer.CharacterAdded:Connect(onCharAdded)
if localPlayer.Character then onCharAdded(localPlayer.Character) end

-- continuously update target when not following
RunService.Heartbeat:Connect(function()
    if not isFollowing then
        target = getNearest()
    end
end)

local function startFollow()
    -- toggle OFF if already following
    if isFollowing then
        isFollowing = false
        if movementConn then
            movementConn:Disconnect()
            movementConn = nil
        end
        if track then track:Stop() end
        animPlaying = false
        return
    end

    -- validate / pick target
    if not target or not target.Character then return end
    local tHum = target.Character:FindFirstChildOfClass("Humanoid")
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not (tHum and tHRP) then return end

    isFollowing = true

    movementConn = RunService.Heartbeat:Connect(function(dt)
        if not isFollowing then return end

        -- stop following if target lost or dead
        if not target
           or not target.Character
           or not target.Character:FindFirstChild("HumanoidRootPart")
           or not target.Character:FindFirstChildOfClass("Humanoid")
           or target.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then
            startFollow()   -- cleanly toggles OFF
            return
        end

        -- fresh references each frame
        local tHRP = target.Character.HumanoidRootPart

        -- behind-offset movement
        local goalPos   = tHRP.Position - tHRP.CFrame.LookVector * BEHIND_DIST
        local direction = goalPos - hrp.Position
        local dist      = direction.Magnitude

        if dist > SPEED * dt then
            hrp.CFrame = CFrame.lookAt(hrp.Position + direction.Unit * SPEED * dt, tHRP.Position)
        else
            hrp.CFrame = CFrame.lookAt(goalPos, tHRP.Position)
        end

        -- simple step animation
        if dist > BEHIND_DIST then
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


-- press X to toggle follow
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.X then
        startFollow()
    end
end)

-- destroy script
destroyButton.MouseButton1Click:Connect(function()
    if movementConn then movementConn:Disconnect() end
    if track then track:Stop() end
    screenGui:Destroy()
    script:Destroy()
end)
