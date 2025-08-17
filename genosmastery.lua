--// Generated Reanimation Script with Garou replacer for Uppercut/Downslam and preloading
-- Place this as a LocalScript in StarterPlayerScripts or similar.
local FLY
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local flyingEnabled = false
local FLYING        = false
local CONTROL       = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
local SPEED         = 1
local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()

local CONTINUE_AFTER_DEATH = true

-- Hit animation IDs that should cancel any running sequence:
local HIT_IDS = {
    ["10473655645"] = true, -- hit 1
    ["10473654583"] = true, -- hit 2
    ["10473655082"] = true, -- hit 3
    ["10473653782"] = true, -- hit 4
    ["10471478869"] = true, -- backhit
}

-- Table to store all active tracks from any sequence:
local activeTracks = {}



-- Sequence‐based animation replacements (original Genos format):
local animationReplacements = {
    ["13083332742"] = {
        {
            name   = "flamewavecannon",
            chance = 100,
            steps  = {
                {
                    intendedID   = "16746824621",
                    stepName     = "bang",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = true,
                    intervals    = {{startTime=0, startSpeed=2.5, endSpeed=0.029, endTime=2}, {startTime=2.2, startSpeed=2, endSpeed=1, endTime=2.5}},
                },
            },
        },
    },
    ["12971270638"] = {  -- barragefnsher
        {
            name   = "barragefnsher",
            chance = 100,
            steps  = {
                {
                    intendedID   = "12460977270",
                    stepName     = "ultslaps",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 0.5,
                    intervals    = {{startTime = 0, startSpeed = 1.6, endSpeed = 1.5, endTime = 1}},
                },
                {
                    intendedID   = "12460977270",
                    stepName     = "next",
                    StartTPOS    = 0.1,
                    startAfter   = 0.5,
                    playUntilEnd = false,
                    duration     = 0.45,
                    intervals    = {{startTime = 0.1, startSpeed = 2.8, endSpeed = 2.8, endTime = 1.4}},
                },
                {
                    intendedID   = "140164642047188",
                    stepName     = "slap",
                    StartTPOS    = 5.5,
                    startAfter   = 0.9,
                    playUntilEnd = true,
                    intervals    = {{startTime = 4, startSpeed = 4, endSpeed = 2, endTime = "end"}},
                },
            },
        },
    },
--[[
    ["105811521074269"] = {  -- ignitionfinsher
        {
            name   = "ignitionfinsher",
            chance = 100,
            steps  = {
                {
                    intendedID   = "115484690572880",
                    stepName     = "twistthrow",
                    StartTPOS    = 0,
                    startAfter   = 0.05,
                    playUntilEnd = true,
                    intervals    = {{startTime = 0, startSpeed = 1, endSpeed = 1.8, endTime = "end"}},
                },
            },
        },
    },
]]
--[[
    ["12618292188"] = {  -- hit (TextBox)
        {
            name   = "hit",
            chance = 100,
            steps  = {
                {
                    intendedID   = "17889080495",
                    stepName     = "TextBox",
                    StartTPOS    = 2.8,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 0.7,
                    intervals    = {{startTime = 2.8, startSpeed = 4.7, endSpeed = 10, endTime = 3.15}},
                },
            },
        },
    },
]]
    ["12684390285"] = {  -- jetdive1 / jetdive2
        {
            name   = "jetdive1",
            chance = 50,
            steps  = {
                {
                    intendedID   = "101588604872680",
                    stepName     = "startdive",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 0.8,
                    intervals    = {{startTime = 0, startSpeed = 1.5, endSpeed = 1.7, endTime = 1}},
                },
                {
                    intendedID   = "102989537449083",
                    stepName     = "dive",
                    StartTPOS    = 0,
                    startAfter   = 0.8,
                    playUntilEnd = false,
                    endOnList     = { "12684185971" },
                    intervals    = {{startTime = 0, startSpeed = 1.5, endSpeed = 0, endTime = "end"}},
                },
            },
        },
        {
            name   = "jetdive2",
            chance = 50,
            steps  = {
                {
                    intendedID   = "101588604872680",
                    stepName     = "divestart2",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 0.8,
                    intervals    = {{startTime = 0, startSpeed = 1.5, endSpeed = 1.7, endTime = 1}},
                },
                {
                    intendedID   = "82365328621192",
                    stepName     = "dive2",
                    StartTPOS    = 0,
                    startAfter   = 0.8,
                    playUntilEnd = false,
                    endOnList     = { "12684185971" },
                    intervals    = {{startTime = 0, startSpeed = 1.7, endSpeed = 0, endTime = "end"}},
                },
            },
        },
    },
    ["12618271998"] = {  -- blitzshot / blitz2
        {
            name   = "blitzshot",
            chance = 0,
            steps  = {
                {
                    intendedID   = "16139108718",
                    stepName     = "tastsu",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    endOnList     = { "12618292188" },
                    intervals    = {
                        {startTime = 0,   startSpeed = 2,   endSpeed = 0.6, endTime = 0.3},
                        {startTime = 0.3, startSpeed = 0.6, endSpeed = 0.161, endTime = 1},
                    },
                },
            },
        },
        {
            name   = "blitz2",
            chance = 0,
            steps  = {
                {
                    intendedID   = "17275150809",
                    stepName     = "ultgrab",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    endOnList     = { "12618292188" },
                    intervals    = {{startTime = 0, startSpeed = 1.4, endSpeed = 0.01, endTime = 1}},
                },
            },
        },
    },

    ["12534735382"] = {  -- barrages / barragessuiryu
--[[
        {
            name   = "barrages",
            chance = 0,
            steps  = {
                {
                    intendedID   = "115484690572880",
                    stepName     = "hitter",
                    StartTPOS    = 0.5,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 0.8,
                    intervals    = {{startTime = 0.5, startSpeed = 1.5, endSpeed = 1, endTime = 2}},
                },
                {
                    intendedID   = "115484690572880",
                    stepName     = "hitter2",
                    StartTPOS    = 0.5,
                    startAfter   = 0.8,
                    playUntilEnd = false,
                    endOnList    = {
                        "10473655645", -- hit 1
                        "10473654583", -- hit 2
                        "10473655082", -- hit 3
                        "10473653782", -- hit 4
                        "10471478869"  -- backhit
                    },
                    intervals    = {{startTime = 0, startSpeed = 1.3, endSpeed = 3.3, endTime = 3.08}},
                },
            },
        },
]]
        {
            name   = "barragessuiryu",
            chance = 100,
            steps  = {
                {
                    intendedID   = "18896229321",
                    stepName     = "suiryu",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 2.2,
                    intervals    = {{startTime = 0, startSpeed = 1.7, endSpeed = 1.7, endTime = 5}},
                },
            },
        },
    },
    ["12502664044"] = {  -- burstpt1
        {
            name   = "burstpt1",
            chance = 100,
            steps  = {
                {
                    intendedID   = "105405781808472",
                    stepName     = "opener",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    endOnList     = { "12509505723" },
                    intervals    = {{startTime = 0, startSpeed = 1.9, endSpeed = 2.2, endTime = 1}},
                },
            },
        },
    },
--[[   ["12509505723"] = {  -- burstpt2
        {
            name   = "burstpt2",
            chance = 0,
            steps  = {
                {
                    intendedID   = "16310343179",
                    stepName     = "wallcombo",
                    StartTPOS    = 1.5,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 1.27,
                    intervals    = {{startTime = 1.5, startSpeed = 1.6, endSpeed = 2, endTime = 2.67}},
                },
            },
        },
    },
]]
    -- Added entries from the other script:
    ["105616370132258"] = {
        {
            name   = "ultintropunch",
            chance = 50,
            steps  = {
                {
                    intendedID   = "72451715583225",
                    stepName     = "punch",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 4,
                    intervals    = {{startTime = 0, startSpeed = 0.3, endSpeed = 0, endTime = 1.25}},
                },
            },
        },
    },
    ["12772543293"] = {
        {
            name   = "ultstart",
            chance = 50,
            steps  = {
                {
                    intendedID   = "105616370132258",
                    stepName     = "runhit",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 4,
                    intervals    = {
                        {startTime = 0,   startSpeed = 0.1, endSpeed = 1.8, endTime = 1.35},
                        {startTime = 0.7, startSpeed = 9,   endSpeed = 0.01, endTime = 0.8},
                        {startTime = 0.9, startSpeed = 0,   endSpeed = 0,    endTime = 3.91},
                    },
                },
            },
        },
    },
    ["12832505612"] = {
        {
            name   = "speedblitz",
            chance = 100,
            steps  = {
                {
                    intendedID   = "131820095363270",
                    stepName     = "TextBox",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    endOnList     = { "12830917034" },
                    intervals    = {{startTime = 0, startSpeed = 1.1, endSpeed = 1, endTime = 2.42}},
                },
            },
        },
    },
    ["13146710762"] = {
        {
            name   = "incinerate",
            chance = 100,
            steps  = {
                {
                    intendedID   = "17861840167",
                    stepName     = "arrow",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 8.2,
                    intervals    = {
                        {startTime = 0, startSpeed = 0.3, endSpeed = 0,   endTime = 1.5},
                        {startTime = 1.5, startSpeed = 0,   endSpeed = 0,   endTime = 3.2},
                    },
                },
                {
                    intendedID   = "17861840167",
                    stepName     = "bowshoot",
                    StartTPOS    = 0.5,
                    startAfter   = 8.2,
                    playUntilEnd = true,
                    intervals    = {{startTime = 0, startSpeed = 1, endSpeed = 1, endTime = 1}},
                },
            },
        },
    },
    ["13047366862"] = {
        {
            name   = "dive",
            chance = 100,
            steps  = {
                {
                    intendedID   = "18464372850",
                    stepName     = "dive",
                    StartTPOS    = 2.4,
                    startAfter   = 0,
					duration     = 1.3,
                    playUntilEnd = false,
                    endOnList     = { "13047328208" },
                    intervals    = {{startTime = 0, startSpeed = 0.7, endSpeed = 0, endTime = 3.18}},
                },
            },
        },
    },
    ["14721837245"] = {
        {
            name   = "thunderkickj",
            chance = 100,
            steps  = {
                {
                    intendedID   = "134494086123052",
                    stepName     = "swings",
                    StartTPOS    = 0,
                    startAfter   = 0,
                    playUntilEnd = false,
                    duration     = 3.28,
                    intervals    = {{startTime = 0, startSpeed = 2, endSpeed = 3.7, endTime = 7.35}},
                },
            },
        },
    },
}

-- Garou‐style replacer table for Uppercut/Downslam:
local garouReplacements = {
    ["10503381238"] = {  -- Uppercut
        {
            intendedID   = "140164642047188",
            playbackSpeed = 0.7,
            startTime    = 0,
            duration     = 0.8,
            playUntilEnd = false,
            chance       = 33,
        },
        {
            intendedID   = "136370737633649",
            playbackSpeed = 1,
            startTime    = 1.2,
            duration     = 0.7,
            playUntilEnd = false,
            chance       = 33,
        },
        {
            intendedID   = "18179181663",
            playbackSpeed = 1.6,
            startTime    = 0,
            duration     = 0.7,
            playUntilEnd = false,
            chance       = 34,
        },
    },
    ["10470104242"] = {  -- Downslam
        {
            intendedID   = "18464356233",
            playbackSpeed = 2.45,
            startTime    = 0.4,
            duration     = 0.85,
            playUntilEnd = false,
            chance       = 20,
        },
        {
            intendedID   = "17859055671",
            playbackSpeed = 2.2,
            startTime    = 0,
            duration     = nil,
            playUntilEnd = true,
            chance       = 20,
        },
        {
            intendedID   = "17858878027",
            playbackSpeed = 2.2,
            startTime    = 0,
            duration     = nil,
            playUntilEnd = true,
            chance       = 20,
        },
        {
            intendedID   = "17858997926",
            playbackSpeed = 2.2,
            startTime    = 0.1,
            duration     = nil,
            playUntilEnd = true,
            chance       = 20,
        },
        {
            intendedID   = "17859015788",
            playbackSpeed = 2.6,
            startTime    = 0,
            duration     = nil,
            playUntilEnd = true,
            chance       = 20,
        },
    },
}

-- Function to replace Garou animations:
local function replaceGarouAnimation(params, animator)
    local intendedAnimation = Instance.new("Animation")
    intendedAnimation.AnimationId = "rbxassetid://" .. params.intendedID
    local intendedTrack = animator:LoadAnimation(intendedAnimation)
    intendedTrack:Play()
    intendedTrack:AdjustSpeed(params.playbackSpeed or 1)
    intendedTrack.TimePosition = params.startTime or 0
    if not params.playUntilEnd and params.duration then
        task.delay(params.duration, function()
            if intendedTrack.IsPlaying then
                intendedTrack:Stop()
            end
        end)
    end
    return intendedTrack
end

local function handleGarouReplacer(animationTrack, animator)
    local unwantedID = animationTrack.Animation.AnimationId:match("%d+$")
    local replacements = garouReplacements[unwantedID]
    if not replacements then return end

    animationTrack:Stop(0)

    local validRepl = {}
    for _, repl in ipairs(replacements) do
        table.insert(validRepl, repl)
    end

    local totalChance = 0
    for _, repl in ipairs(validRepl) do
        totalChance = totalChance + (repl.chance or 0)
    end
    if totalChance == 0 then
        totalChance = #validRepl
        for _, repl in ipairs(validRepl) do
            repl.chance = 1
        end
    end

    local pick = math.random(1, totalChance)
    local cum = 0
    local selected
    for _, repl in ipairs(validRepl) do
        cum = cum + (repl.chance or 0)
        if pick <= cum then
            selected = repl
            break
        end
    end

    if selected then
        replaceGarouAnimation(selected, animator)
    end
end

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
                allEndIds[id] = true
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
            -- if StartTPOS > 0, force the “startSpeed” right away:
            if step.StartTPOS and step.StartTPOS > 0 and step.intervals and #step.intervals > 0 then
                track:AdjustSpeed(step.intervals[1].startSpeed or 1)
            elseif step.intervals and #step.intervals > 0 then
                track:AdjustSpeed(step.intervals[1].startSpeed or 1)
            end

            -- Add to global activeTracks table:
            table.insert(activeTracks, track)
            table.insert(tracks, track)

            if step.intervals and #step.intervals > 0 then
                coroutine.wrap(function()
                    for _, iv in ipairs(step.intervals) do
                        local st   = iv.startTime or 0
                        local sspd = iv.startSpeed or 1
                        local espd = iv.endSpeed or sspd
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

--------------------------------------------------------------------------------
-- HANDLER: called whenever any animation is played on the client
--------------------------------------------------------------------------------
local function onAnimationPlayed(animationTrack, animator)
    if not animationTrack.Animation then return end
    local unwantedID = animationTrack.Animation.AnimationId:match("%d+$")
    if not unwantedID then return end
	-- Cancel run/walk when animation 17889080495 plays
	if unwantedID == "17889080495" then
		for _, t in ipairs(activeTracks) do
			local playingID = t.Animation and t.Animation.AnimationId:match("%d+$")
			if playingID == "7815618175" or playingID == "7807831448" then
				if t.IsPlaying then t:Stop() end
			end
		end
	end


    if unwantedID == "13047328208" then
        for _, t in ipairs(activeTracks) do
            local playingID = t.Animation and t.Animation.AnimationId:match("%d+$")
            if playingID == "18464372850" and t.IsPlaying then
                t:Stop()
            end
        end
    end

    -- Cancel any active sequences if a hit/backhit plays:
    if HIT_IDS[unwantedID] then
        for _, t in ipairs(activeTracks) do
            if t.IsPlaying then
                t:Stop()
            end
        end
        activeTracks = {}
        return
    end

    -- If this is Uppercut or Downslam, use Garou replacer:
    if garouReplacements[unwantedID] then
        handleGarouReplacer(animationTrack, animator)
        return
    end
--[[
    -- If the Jetdive finisher (14542032218) plays, run the fly script for 2 seconds:
    if unwantedID == "14542032218" then
		wait(.65)
        FLYING = true
        FLY()
        task.delay(2, function()
            FLYING = false
        end)
    end
]]

    -- Otherwise, handle sequence‐based replacements:
    local sequences = animationReplacements[unwantedID]
    if not sequences then return end

    animationTrack:AdjustSpeed(0)
    animationTrack:Stop()

    -- pick a sequence by weight
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

--------------------------------------------------------------------------------
-- FLY: used when Jetdive finisher plays
--------------------------------------------------------------------------------

FLY = function()
    local T = character:WaitForChild("HumanoidRootPart")
    local BG = Instance.new("BodyGyro")
    local BV = Instance.new("BodyVelocity")
    BG.P = 9e4
    BG.Parent = T
    BV.Parent = T
    BG.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    BV.maxForce = Vector3.new(9e9, 9e9, 9e9)
    BV.velocity = Vector3.new(0, 0, 0)

    task.spawn(function()
        repeat
            RunService.Heartbeat:Wait()
            local camPos = camera.CFrame.Position
            local charPos = T.Position
            local dirToCam = (camPos - charPos).unit
            local targetC0 = CFrame.new(charPos, charPos + dirToCam) * CFrame.Angles(math.rad(-90), 0, 0)

            -- Shift Lock / Normal both use same rotation math here
            BG.CFrame = targetC0
            if CONTROL.L ~= 0 or CONTROL.R ~= 0 then
                BG.CFrame = BG.CFrame * CFrame.Angles(0, math.rad(CONTROL.L * 5), 0)
            end

            -- Movement logic
            if (CONTROL.L + CONTROL.R) ~= 0 or (CONTROL.F + CONTROL.B) ~= 0 or (CONTROL.Q + CONTROL.E) ~= 0 then
                SPEED = 100
            else
                SPEED = 0
            end

            BV.velocity = (
                camera.CFrame.LookVector * (CONTROL.F + CONTROL.B)
                + ((camera.CFrame * CFrame.new(CONTROL.L + CONTROL.R,
                        (CONTROL.F + CONTROL.B + CONTROL.Q + CONTROL.E) * 0.2, 0).p)
                   - camera.CFrame.p)
            ) * SPEED

        until not FLYING

        CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
        SPEED = 0
        BG:Destroy()
        BV:Destroy()
    end)
end

-- Keybinding for movement control during fly (W, A, S, D, E, Q):
local IYMouse = player:GetMouse()
IYMouse.KeyDown:Connect(function(KEY)
    if KEY:lower() == "w" then
        CONTROL.F = 1
    elseif KEY:lower() == "s" then
        CONTROL.B = -1
    elseif KEY:lower() == "a" then
        CONTROL.L = -1
    elseif KEY:lower() == "d" then
        CONTROL.R = 1
    elseif KEY:lower() == "e" then
        CONTROL.Q = 1
    elseif KEY:lower() == "q" then
        CONTROL.E = -1
    end
end)
IYMouse.KeyUp:Connect(function(KEY)
    if KEY:lower() == "w" then
        CONTROL.F = 0
    elseif KEY:lower() == "s" then
        CONTROL.B = 0
    elseif KEY:lower() == "a" then
        CONTROL.L = 0
    elseif KEY:lower() == "d" then
        CONTROL.R = 0
    elseif KEY:lower() == "e" then
        CONTROL.Q = 0
    elseif KEY:lower() == "q" then
        CONTROL.E = 0
    end
end)

--------------------------------------------------------------------------------
-- Called when the player's character is added (or on script load if character exists)
--------------------------------------------------------------------------------
local function onCharacterAdded(char)
    character = char
    local hum = character:WaitForChild("Humanoid")
    local animator = hum:WaitForChild("Animator")


    -- Preload all animations (sequence‐based + Garou‐based) to cache them:
    local animIds = {}
    for _, sequences in pairs(animationReplacements) do
        for _, seq in ipairs(sequences) do
            for _, step in ipairs(seq.steps or {}) do
                animIds[tostring(step.intendedID)] = true
            end
        end
    end
    for _, reps in pairs(garouReplacements) do
        for _, rep in ipairs(reps) do
            animIds[tostring(rep.intendedID)] = true
        end
    end

    for id, _ in pairs(animIds) do
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. id
        local track = animator:LoadAnimation(anim)
        track:Play()
        track:AdjustSpeed(10)
        task.delay(0.1, function()
            if track.IsPlaying then
                track:Stop()
            end
        end)
    end

    -- Connect the animation played handler:
    animator.AnimationPlayed:Connect(function(track)
        onAnimationPlayed(track, animator)
    end)

    -- after: local hum = character:WaitForChild("Humanoid")
    hum.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.FallingDown then
            for _, t in ipairs(activeTracks) do
                if t.IsPlaying then t:Stop() end
            end
        elseif newState == Enum.HumanoidStateType.Landed then
            for _, t in ipairs(activeTracks) do
                local playingID = t.Animation and t.Animation.AnimationId:match("%d+$")
                if playingID == "18464372850" and t.IsPlaying then
                    t:Stop()
                end
            end
        end
    end)


    if not CONTINUE_AFTER_DEATH then
        hum.Died:Connect(function()
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
