--[[
    Fallen Survival Noclip
    Bypass + walk-through-walls noclip (no flying)
    Toggle: V key
    Sprint: hold LeftShift while noclipping
    Stays grounded — just phases through geometry
]]

-------------------------------------------------
-- 1. BYPASS (AssetContainer anti-cheat hooks)
-------------------------------------------------
if not LPH_OBFUSCATED then
    LPH_NO_UPVALUES = function(...)
        return setfenv(function(...)
            return __forwarded(...)
        end, setmetatable({ __forwarded = ... }, { __index = getfenv((...)) }))
    end
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end
task.wait(1)

if not getgenv().BypassLoaded then
    for _, Value in next, getgc(false) do
        if type(Value) == "function" and not isexecutorclosure(Value) then
            local Info = getinfo(Value)
            if Info.short_src and string.find(Info.short_src, "AssetContainer") and Info.numparams == 1 then
                local V2 = getprotos(Value)
                if #V2 > 0 then
                    for _, V2Value in next, getprotos(Value, true) do
                        local V3 = getconstants(V2Value)
                        local V4 = getupvalues(V2Value)
                        if #V3 ~= 23 and (#V3 ~= 9 or #V4 ~= 3) then
                            local OldFunc = nil
                            OldFunc = hookfunction(V2Value, LPH_NO_UPVALUES(function(...)
                                local Args = {...}
                                if #Args > 0 then
                                    local First = Args[1]
                                    if typeof(First) == "Instance" then return end
                                    if type(First) == "string" and First == "" then return end
                                    if type(First) == "table" then return end
                                    if type(First) == "function" then return end
                                end
                                return OldFunc(...)
                            end))
                        elseif #V3 == 9 and #V4 == 3 then
                            hookfunction(V2Value, LPH_NO_UPVALUES(function()
                                return
                            end))
                        elseif #V3 == 23 then
                            local OldFunc23 = nil
                            OldFunc23 = hookfunction(V2Value, LPH_NO_UPVALUES(function(...)
                                local Args = {...}
                                if #Args > 0 and type(Args[1]) == "table" then
                                    local Cleaned = {}
                                    for k, v in next, Args[1] do
                                        if type(v) ~= "table" then
                                            Cleaned[k] = v
                                        end
                                    end
                                    return OldFunc23(Cleaned, select(2, ...))
                                end
                                return OldFunc23(...)
                            end))
                        end
                    end
                end
            end
        end
    end
    getgenv().BypassLoaded = true
end

-------------------------------------------------
-- 2. SERVICES
-------------------------------------------------
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer      = Players.LocalPlayer
local Character        = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid         = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Camera           = workspace.CurrentCamera

-------------------------------------------------
-- 3. CONFIG
-------------------------------------------------
local TOGGLE_KEY  = Enum.KeyCode.V
local SPRINT_KEY  = Enum.KeyCode.LeftShift
local WALK_SPEED  = 16    -- normal Roblox walk speed
local SPRINT_SPEED = 32   -- sprint while noclipping

-------------------------------------------------
-- 4. STATE
-------------------------------------------------
local noclipEnabled  = false
local steppedConn    = nil
local collisionParts = {}

-------------------------------------------------
-- 5. COLLISION TOGGLE
-------------------------------------------------
local function setCollision(char, canCollide)
    collisionParts = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if not canCollide then
                table.insert(collisionParts, { Part = part, Original = part.CanCollide })
            end
            part.CanCollide = canCollide
        end
    end
end

local function restoreCollision()
    for _, data in ipairs(collisionParts) do
        if data.Part and data.Part.Parent then
            data.Part.CanCollide = data.Original
        end
    end
    collisionParts = {}
end

-------------------------------------------------
-- 6. NOCLIP LOOP (ground-based, no flying)
--    Every frame: disable CanCollide on all
--    character parts so you walk straight through
--    walls, terrain, everything. Gravity still
--    applies — you stay on the ground.
-------------------------------------------------
local function onStepped()
    if not noclipEnabled then return end
    if not Character or not Character.Parent then return end

    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end

    -- Sprint support while noclipping
    if Humanoid and Humanoid.Parent then
        if UserInputService:IsKeyDown(SPRINT_KEY) then
            Humanoid.WalkSpeed = SPRINT_SPEED
        else
            Humanoid.WalkSpeed = WALK_SPEED
        end
    end
end

-------------------------------------------------
-- 7. ENABLE / DISABLE
-------------------------------------------------
local originalWalkSpeed = WALK_SPEED

local function enableNoclip()
    if noclipEnabled then return end
    noclipEnabled = true

    Character = LocalPlayer.Character
    if not Character then return end
    Humanoid = Character:FindFirstChildOfClass("Humanoid")
    HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not Humanoid or not HumanoidRootPart then return end

    originalWalkSpeed = Humanoid.WalkSpeed

    -- Disable collision on all parts
    setCollision(Character, false)

    -- Connect stepped to keep collision off every frame
    steppedConn = RunService.Stepped:Connect(onStepped)
end

local function disableNoclip()
    if not noclipEnabled then return end
    noclipEnabled = false

    if steppedConn then
        steppedConn:Disconnect()
        steppedConn = nil
    end

    restoreCollision()

    if Humanoid and Humanoid.Parent then
        Humanoid.WalkSpeed = originalWalkSpeed
    end
end

-------------------------------------------------
-- 8. TOGGLE KEYBIND
-------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == TOGGLE_KEY then
        if noclipEnabled then
            disableNoclip()
        else
            enableNoclip()
        end
    end
end)

-------------------------------------------------
-- 9. CHARACTER RESPAWN HANDLER
-------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function(newChar)
    local wasEnabled = noclipEnabled
    if noclipEnabled then
        disableNoclip()
    end

    Character = newChar
    Humanoid = newChar:WaitForChild("Humanoid")
    HumanoidRootPart = newChar:WaitForChild("HumanoidRootPart")
    Camera = workspace.CurrentCamera

    Humanoid.Died:Connect(function()
        if noclipEnabled then
            disableNoclip()
        end
    end)

    if wasEnabled then
        task.wait(0.5)
        enableNoclip()
    end
end)

-- Hook current character death
if Humanoid then
    Humanoid.Died:Connect(function()
        if noclipEnabled then
            disableNoclip()
        end
    end)
end