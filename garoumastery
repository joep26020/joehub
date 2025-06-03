local isPlayingMultipleTimes = false
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Global variable to track the currently playing replacement (for M1, uppercut, or downslam)
local currentM1Replacement = nil
local m1ReplacementKeys = {
    ["13532562418"] = true,
    ["13532600125"] = true,
    ["13532604085"] = true,
    ["13294471966"] = true,
}
-- Keys that require cancelling any current replacement (uppercut and downslam)
local cancelReplacementKeys = {
    ["10503381238"] = true,  -- Uppercut
    ["10470104242"] = true,  -- Downslam
}

-- Helper function to extract numeric ID from an asset ID
local function getAnimationIdFromAssetId(assetId)
    local id = assetId:match("%d+$")
    return id
end

-- Function to play the original animation multiple times with adjusted start times
local function playAnimationMultipleTimes(animator)
    if isPlayingMultipleTimes then
        return -- Prevent re-entry if already playing
    end
    isPlayingMultipleTimes = true

    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://12447247483"
    local track = animator:LoadAnimation(animation)
    
    for i = 1, 9 do
        track.TimePosition = (i == 1) and 0 or 0.91
        track:Play()
        track:AdjustSpeed(9)
        
        if track.Length then
            task.wait(track.Length / 12)  -- Adjusted wait based on speed
        else
            task.wait(1)
        end
    end

    isPlayingMultipleTimes = false
end

-- Animation replacement configurations
local animationReplacements = {
    -- NORMAL MOVES

    -- 1. flowingwater
    ["12273188754"] = {
        {
            intendedID = "134494086123052",
            playbackSpeed = 3.5,
            startTime = 1.5,
            duration = nil,
            playUntilEnd = true,
            chance = 34,
        },
        {
            intendedID = "17799224866",
            playbackSpeed = 1.2,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 33,
        },
        {
            intendedID = "76530443909428",
            playbackSpeed = 2.4,
            startTime = 0.2,
            duration = 2,
            playUntilEnd = false,
            chance = 0,
        },
        {
            intendedID = "105811521074269",
            playbackSpeed = 1.15,
            startTime = 0,
            duration = nil, -- 'end' implies duration is nil
            playUntilEnd = true,
            chance = 33,
        },
    },

    -- 1a. flowingfinisher variants
    ["14374357351"] = {
        {
            intendedID = "14809836765",
            playbackSpeed = 1.33,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 20,
        },
        {
            intendedID = "18440406788",
            playbackSpeed = 2,
            startTime = 2.6,
            duration = 3,
            playUntilEnd = false,
            chance = 40,
        },
        {
            intendedID = "18896229321",
            playbackSpeed = 2.5,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 40,
        },
    },

    -- 2. lethal moves
    ["12296113986"] = {
        {
            intendedID = "18182425133",
            playbackSpeed = 1.85,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 40,
        },
        {
            intendedID = "76530443909428",
            playbackSpeed = 2.5,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 15,
        },
        {
            intendedID = "105811521074269",
            playbackSpeed = 1.05,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 30,
        },
        {
            intendedID = "71060716968719",
            playbackSpeed = 0.73,
            startTime = 0,
            duration = 1.8,
            playUntilEnd = false,
            chance = 0,
        },
        {
            intendedID = "96865367566704",
            playbackSpeed = 1.6,
            startTime = 1,
            duration = 2.4,
            playUntilEnd = false,
            chance = 15,
        },
    },

    -- 2b. lethalfinisher variant2
    ["14798608838"] = {
        {
            intendedID = "18896229321",
            playbackSpeed = 1.25,
            startTime = 4.1,
            duration = 1.45,
            playUntilEnd = false,
            chance = 50,
        },
        {
            intendedID = "17859015788 ",
            playbackSpeed = 1,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 50,
        },
    },

    -- 3. huntergrasp
    ["12309835105"] = {
        {
            intendedID = "81827172076105",
            playbackSpeed = 2.5,
            startTime = 0,
            duration = 1,
            playUntilEnd = false,
            chance = 35,
        },
        {
            intendedID = "13501296372",
            playbackSpeed = 1,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 35,
        },
        {
            intendedID = "77727115892579",
            playbackSpeed = 6,
            startTime = 25.3,
            duration = 2,
            playUntilEnd = true,
            chance = 0,
        },
        {
            intendedID = "94395585475029",
            playbackSpeed = 0.93,
            startTime = 0,
            duration = 1,
            playUntilEnd = true,
            chance = 30,
        },
    },

    -- 3a. huntergraspfinisher 
    ["12447247483"] = {
        {
            intendedID = "93546004428904",
            specialSequence = "huntergraspfinisher_variant1",
            chance = 10,
        },
        {
            intendedID = "18464362124",
            playbackSpeed = 2,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 10,
        },
        {
            specialSequence = "hunterfinisher_variant",
            chance = 80,
        },
    },

    -- 4. counterprey
    ["12351854556"] = {
        {
            intendedID = "78521642007560",
            playbackSpeed = 0.9,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 34,
        },
        {
            intendedID = "106778226674700",
            playbackSpeed = 2,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 33,
        },
        {
            intendedID = "131177495882827",
            playbackSpeed = 1.1,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 33,
        },
    },

    -- ULTIMATE MOVES

    -- 0. garouultintro
    ["12342141464"] = {
        {
            intendedID = "95000469063288",
            playbackSpeed = 1.7,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 33,
        },
        {
            intendedID = "113876851900426",
            playbackSpeed = 1.25,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 33,
        },
        {
            intendedID = "16719183472",
            playbackSpeed = 0.65,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 34,
        },
    },

    -- 1. waterpunches
    ["12460977270"] = {
        {
            intendedID = "13560306510",
            specialSequence = "waterpunches_sequence",
            chance = 100,
        },
    },

    -- 2. finalhunt variants
    ["12467789963"] = {
        {
            intendedID = "137561511768861",
            playbackSpeed = 1.25,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 90,
        },
        {
            intendedID = "18231574269",
            playbackSpeed = 1,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 10,
        },
    },

    -- 3. waterslap
    ["14057231976"] = {
        {
            specialSequence = "waterslap_sequence",
            chance = 100,
        },
    },

    -- 5. spawninanim (new)
    ["15957376722"] = {
        {
            intendedID = "119325239112989",
            playbackSpeed = 1,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 100,
        },
    },

    -- 6. wall combo (new, 2 in 1)
    ["16310343179"] = {
        {
            intendedID = "76530443909428",
            specialSequence = "wallcombo_sequence",
            chance = 100,
        },
    },

    -- NEW UPPERCUT Animation Replacements
    ["10503381238"] = {
        {
            intendedID = "140164642047188",
            playbackSpeed = .7,
            startTime = 0,
            duration = 0.8,
            playUntilEnd = false,
            chance = 33,
        },
        {
            intendedID = "136370737633649",
            playbackSpeed = 1,
            startTime = 1.2,
            duration = 0.7,
            playUntilEnd = false,
            chance = 33,
        },
        {
            intendedID = "18179181663",
            playbackSpeed = 1.6,
            startTime = 0,
            duration = 0.7,
            playUntilEnd = false,
            chance = 34,
        },
    },

    -- NEW DOWNSLAM Animation Replacements
    ["10470104242"] = {
        {
            intendedID = "18464356233",
            playbackSpeed = 2.45,
            startTime = 0.4,
            duration = 0.85,
            playUntilEnd = false,
            chance = 20,
        },
        {
            intendedID = "17859055671",
            playbackSpeed = 2.2,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 20,
        },
        {
            intendedID = "17858878027",
            playbackSpeed = 2.2,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 20,
        },
        {
            intendedID = "17858997926",
            playbackSpeed = 2.2,
            startTime = 0.1,
            duration = nil,
            playUntilEnd = true,
            chance = 20,
        },
        {
            intendedID = "17859015788",
            playbackSpeed = 2.6,
            startTime = 0,
            duration = nil,
            playUntilEnd = true,
            chance = 20,
        },
    },

    -- NEW M1 Animation Replacements (Modified for longer duration and dynamic speed)
    ["13532562418"] = {
        {
            intendedID = "13491635433",
            playbackSpeed = 1.35, -- start fast
            startTime = 0,
            duration = 0.7,
            playUntilEnd = false,
            chance = 50,
        },
        {
            intendedID = "17889458563",
            playbackSpeed = 1.35,
            startTime = 0,
            duration = 0.7,
            playUntilEnd = false,
            chance = 50,
        },
    },
    ["13532600125"] = {
        {
            intendedID = "100059874351664",
            playbackSpeed = 1.35,
            startTime = 0,
            duration = 0.7,
            playUntilEnd = false,
            chance = 100,
        },
    },
    ["13532604085"] = {
        {
            intendedID = "18169291044",
            playbackSpeed = 1.35,
            startTime = 0,
            duration = 0.7,
            playUntilEnd = false,
            chance = 100,
        },
    },
    ["13294471966"] = {
        {
            intendedID = "17325537719",
            playbackSpeed = 1.35,
            startTime = 0,
            duration = 1,
            playUntilEnd = false,
            chance = 40,
        },
        {
            intendedID = "17838006839",
            playbackSpeed = 1.35,
            startTime = 0.45,
            duration = 1,
            playUntilEnd = false,
            chance = 30,
        },
        {
            intendedID = "13146710762",
            playbackSpeed = 2.4,
            startTime = 0.2,
            duration = 0.8,
            playUntilEnd = false,
            chance = 30,
        },
    },
}

-- Function to replace unwanted animation with intended animation
local function replaceAnimation(params, animator)
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

-- Event handler for animation played
local function onAnimationPlayed(animationTrack, animator)
    if isPlayingMultipleTimes then
        return -- Skip processing to prevent recursion
    end
    if not animationTrack.Animation then return end

    local unwantedID = getAnimationIdFromAssetId(animationTrack.Animation.AnimationId)
    local replacements = animationReplacements[unwantedID]
    if not replacements then return end

    -- Stop the unwanted animation
    animationTrack:Stop(0)

    -- If this is an M1, uppercut, or downslam replacement, cancel any previous replacement track
    if (m1ReplacementKeys[unwantedID] or cancelReplacementKeys[unwantedID]) and currentM1Replacement and currentM1Replacement.IsPlaying then
        currentM1Replacement:Stop(0)
        currentM1Replacement = nil
    end

    -- Handle special sequences or chance-based selection
    local replacement = nil
    local validReplacements = {}
    for _, repl in ipairs(replacements) do
        local conditionMet = true
        if repl.condition and not repl.condition() then
            conditionMet = false
        end
        if conditionMet then
            table.insert(validReplacements, repl)
        end
    end

    if #validReplacements == 0 then
        return -- No valid replacements
    end

    local totalChance = 0
    for _, repl in ipairs(validReplacements) do
        totalChance = totalChance + (repl.chance or 0)
    end

    if totalChance == 0 then
        totalChance = #validReplacements
        for _, repl in ipairs(validReplacements) do
            repl.chance = 1
        end
    end

    local randomPick = math.random(1, totalChance)
    local cumulativeChance = 0
    for _, repl in ipairs(validReplacements) do
        cumulativeChance = cumulativeChance + (repl.chance or 0)
        if randomPick <= cumulativeChance then
            replacement = repl
            break
        end
    end

    if replacement then
        print("Selected Replacement ID:", replacement.intendedID or "Special Sequence")
    end

    if replacement then
        if replacement.specialSequence then
            if replacement.specialSequence == "huntergraspfinisher_variant1" then
                print("Executing huntergraspfinisher_variant1 sequence")
                for i = 1, 2 do
                    replaceAnimation({
                        intendedID = replacement.intendedID,
                        playbackSpeed = 5,
                        startTime = 3,
                        duration = 0.5,
                        playUntilEnd = false,
                    }, animator)
                    task.wait(0.5)
                end
                replaceAnimation({
                    intendedID = "18464362124",
                    playbackSpeed = 2,
                    startTime = 2,
                    duration = 1.35,
                    playUntilEnd = false,
                }, animator)
            elseif replacement.specialSequence == "hunterfinisher_variant" then
                print("Executing hunterfinisher_variant sequence")
                playAnimationMultipleTimes(animator)
            elseif replacement.specialSequence == "waterpunches_sequence" then
                print("Executing waterpunches_sequence")
                for i = 1, 3 do
                    local track = replaceAnimation({
                        intendedID = replacement.intendedID,
                        playbackSpeed = 3,
                        startTime = 1,
                        duration = 0.5,
                        playUntilEnd = false,
                    }, animator)
                    task.wait(0.5)
                end
            elseif replacement.specialSequence == "waterslap_sequence" then
                print("Executing waterslap_sequence")
                local track1 = replaceAnimation({
                    intendedID = "17838006839",
                    playbackSpeed = 1.5,
                    startTime = 0,
                    duration = 1,
                    playUntilEnd = false,
                }, animator)
                task.wait(1)
                local track2 = replaceAnimation({
                    intendedID = "79761806706382",
                    playbackSpeed = 6.5,
                    startTime = 0,
                    duration = nil,
                    playUntilEnd = true,
                }, animator)
            elseif replacement.specialSequence == "wallcombo_sequence" then
                print("Executing wallcombo_sequence")
                replaceAnimation({
                    intendedID = "76530443909428",
                    playbackSpeed = 1.9,
                    startTime = 0,
                    duration = 2,
                    playUntilEnd = false,
                }, animator)
                task.wait(2)
                replaceAnimation({
                    intendedID = "131492147325921",
                    playbackSpeed = 1.8,
                    startTime = .7,
                    duration = nil,
                    playUntilEnd = true,
                }, animator)
            else
                print("Unknown special sequence:", replacement.specialSequence)
            end
            return
        else
            local newTrack = replaceAnimation(replacement, animator)
            -- If the replacement is for an M1, uppercut, or downslam, store it so it can be cancelled by subsequent ones
            if m1ReplacementKeys[unwantedID] or cancelReplacementKeys[unwantedID] then
                currentM1Replacement = newTrack
                -- (For M1 replacements, we adjust speed after 0.35 sec; you can add similar logic for uppercut/downslam if desired)
                if m1ReplacementKeys[unwantedID] then
                    task.delay(0.35, function()
                        if currentM1Replacement and currentM1Replacement.IsPlaying then
                            currentM1Replacement:AdjustSpeed(0.8)
                        end
                    end)
                end
            end
        end
    end
end

-- Main function when character is added
local function onCharacterAdded(character)
    local humanoid = character:WaitForChild("Humanoid")
    local animator = humanoid:WaitForChild("Animator")
    local connections = {}

    local function onHumanoidDied()
        for _, conn in ipairs(connections) do
            conn:Disconnect()
        end
        connections = {}
    end

    table.insert(connections, humanoid.Died:Connect(onHumanoidDied))
    table.insert(connections, humanoid.AnimationPlayed:Connect(function(animationTrack)
        onAnimationPlayed(animationTrack, animator)
    end))
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then
    onCharacterAdded(LocalPlayer.Character)
end
