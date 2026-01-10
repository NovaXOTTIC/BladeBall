if game.PlaceId ~= 13772394625 then
    game.Players.LocalPlayer:Kick("You must be in Blade Ball to use this script.")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Player = Players.LocalPlayer

if _G.VyzenLoaded then
    warn("Vyzen Hub is already running!")
    return
end
_G.VyzenLoaded = true

local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success then
    warn("Failed to load Rayfield. Trying backup...")
    Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/shlexware/Rayfield/main/source'))()
end

local Window = Rayfield:CreateWindow({
   Name = "Vyzen Hub | Blade Ball",
   LoadingTitle = "Initializing Systems...",
   LoadingSubtitle = "Loading Vyzen Engine",
   ConfigurationSaving = { Enabled = true, FolderName = "VyzenHub", FileName = "BladeBallConfig" },
   Discord = {
      Enabled = true,
      Invite = "TssNQyMkVr",
      RememberJoins = true 
   },
   KeySystem = false
})

local CurrentTargetFlight = ""
local LastClickTime = 0
local LastBallPosition = Vector3.new(0, 0, 0)
local LastBallTarget = ""
local LastBallVelocity = Vector3.new(0, 0, 0)
local CanClick = true
local ParryCount = 0
local Parried = false
local DeathSlashDetection = false
local Infinity_Ball = false
local Phantom = false
local ConnectionStore = {}
local IsAutoSpamming = false
local AutoSpamLoop = nil
local AutoSpamGUI = nil

local Config = {
    AutoParry = true,
    ParryAccuracy = 95,
    AutoSpamSpeed = 0.1,
    WalkSpeed = 36,
    JumpPower = 50,
    InfiniteJump = false,
    Fly = false,
    FlySpeed = 50,
    Noclip = false,
    AntiRagdoll = true,
    SingularityDetection = true,
    InfinityDetection = true,
    DeathSlashDetection = true,
    AntiPhantom = true,
    BallESP = true,
    SafeZoneCircle = true,
    TargetTracer = true,
    FOV = 70,
    Fullbright = false,
    SpeedDivisorMultiplier = 0.85
}

local Visuals = {
    Folder = Instance.new("Folder", Workspace),
    SafeZone = nil,
    BallTracer = nil,
    TracerAttachments = {}
}
Visuals.Folder.Name = "VyzenVisuals"

local AutoParry = {}
AutoParry.Velocity_History = {}
AutoParry.Dot_Histories = {}

AutoParry.GetBall = function()
    local bestBall = nil
    local shortestDist = math.huge
    
    local ballsFolder = Workspace:WaitForChild("Balls", 5)
    if not ballsFolder then return nil end

    for _, instance in pairs(ballsFolder:GetChildren()) do
        if instance:IsA("BasePart") then
            local isRealBall = instance:GetAttribute("realBall") == true
            local notVisual = instance:GetAttribute("visualBall") ~= true
            
            if not isRealBall and instance.Name == "Ball" then
                isRealBall = true
            end
            
            if isRealBall and notVisual then
                local char = Player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local dist = (hrp.Position - instance.Position).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        bestBall = instance
                    end
                end
            end
        end
    end
    
    if bestBall then 
        bestBall.CanCollide = false
        for oldBall, _ in pairs(AutoParry.Velocity_History) do
            if oldBall ~= bestBall then
                AutoParry.Velocity_History[oldBall] = nil
                AutoParry.Dot_Histories[oldBall] = nil
            end
        end
    end
    return bestBall
end

AutoParry.IsCurved = function(ball)
    if not ball then return false, false end
    local Zoomies = ball:FindFirstChild('zoomies')
    if not Zoomies then return false, false end
    
    local Velocity = Zoomies.VectorVelocity
    local Speed = Velocity.Magnitude
    if Speed < 50 then return false, false end
    
    if not AutoParry.Velocity_History[ball] then AutoParry.Velocity_History[ball] = {} end
    if not AutoParry.Dot_Histories[ball] then AutoParry.Dot_Histories[ball] = {} end

    if #AutoParry.Velocity_History[ball] < 2 or #AutoParry.Dot_Histories[ball] < 2 then
        return false, false
    end
    
    local char = Player.Character
    if not char or not char.PrimaryPart then return false, false end

    local Ball_Direction = Velocity.Unit
    local Direction = (char.PrimaryPart.Position - ball.Position).Unit
    local Dot = Direction:Dot(Ball_Direction)
    
    local baseDotThreshold = 0.2
    if Speed > 600 then baseDotThreshold = 0.0
    elseif Speed > 400 then baseDotThreshold = 0.1
    elseif Speed > 200 then baseDotThreshold = 0.15 end
    
    local backwardsCurveDetected = false
    local backwardsAngleThreshold = 60
    if Speed > 600 then backwardsAngleThreshold = 45
    elseif Speed > 400 then backwardsAngleThreshold = 52 end
    
    local playerPos = char.PrimaryPart.Position
    local ballPos = ball.Position
    local horizDirection = Vector3.new(playerPos.X - ballPos.X, 0, playerPos.Z - ballPos.Z)
    
    if horizDirection.Magnitude > 0.1 then 
        horizDirection = horizDirection.Unit
        local awayFromPlayer = -horizDirection
        local horizBallDir = Vector3.new(Ball_Direction.X, 0, Ball_Direction.Z)
        
        if horizBallDir.Magnitude > 0.1 then
            horizBallDir = horizBallDir.Unit
            local backwardsAngle = math.deg(math.acos(math.clamp(awayFromPlayer:Dot(horizBallDir), -1, 1)))
            if backwardsAngle < backwardsAngleThreshold and (playerPos - ballPos).Magnitude > 25 then
                backwardsCurveDetected = true
            end
        end
    end
    
    local curved = Dot < baseDotThreshold or backwardsCurveDetected
    return curved, backwardsCurveDetected
end

local function Click()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.delay(0.01, function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

local function ClickIfNotOnExcludedGUI()
    local mouse = game.Players.LocalPlayer:GetMouse()
    
    local coreGuiObjects = {}
    pcall(function()
        coreGuiObjects = game:GetService("CoreGui"):GetGuiObjectsAtPosition(mouse.X, mouse.Y)
    end)
    
    for _, obj in pairs(coreGuiObjects) do
        local parent = obj
        while parent do
            if parent.Name == "Rayfield" or parent.Name == "RayfieldMain" then
                return false
            end
            parent = parent.Parent
        end
    end
    
    local playerGuiObjects = game.Players.LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)
    
    for _, obj in pairs(playerGuiObjects) do
        local parent = obj
        while parent do
            if parent.Name == "VyzenAutoSpam" then
                return false
            end
            parent = parent.Parent
        end
    end
    
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.delay(0.01, function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
    return true
end

local function StartAutoSpam()
    if AutoSpamLoop then return end
    IsAutoSpamming = true
    
    AutoSpamLoop = task.spawn(function()
        while IsAutoSpamming do
            ClickIfNotOnExcludedGUI()
            task.wait(Config.AutoSpamSpeed)
        end
        AutoSpamLoop = nil
    end)
end

local function StopAutoSpam()
    IsAutoSpamming = false
    if AutoSpamLoop then
        task.cancel(AutoSpamLoop)
        AutoSpamLoop = nil
    end
end

local function CreateAutoSpamGUI()
    local ScreenGui = Instance.new("ScreenGui")
    local Frame = Instance.new("Frame")
    local Title = Instance.new("TextLabel")
    local CheckboxFrame = Instance.new("Frame")
    local CheckboxButton = Instance.new("TextButton")
    local Checkmark = Instance.new("TextLabel")
    local CheckboxLabel = Instance.new("TextLabel")
    local SliderFrame = Instance.new("Frame")
    local SliderBack = Instance.new("Frame")
    local SliderFill = Instance.new("Frame")
    local SliderButton = Instance.new("TextButton")
    local SliderLabel = Instance.new("TextLabel")
    local SliderValue = Instance.new("TextLabel")
    
    ScreenGui.Name = "VyzenAutoSpam"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    
    Frame.Parent = ScreenGui
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    Frame.BorderSizePixel = 0
    Frame.Position = UDim2.new(0.7, 0, 0.4, 0)
    Frame.Size = UDim2.new(0, 280, 0, 160)
    Frame.Active = true
    Frame.Draggable = true
    
    local FrameCorner = Instance.new("UICorner")
    FrameCorner.CornerRadius = UDim.new(0, 12)
    FrameCorner.Parent = Frame
    
    local FrameStroke = Instance.new("UIStroke")
    FrameStroke.Color = Color3.fromRGB(60, 60, 70)
    FrameStroke.Thickness = 2
    FrameStroke.Parent = Frame
    
    Title.Parent = Frame
    Title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    Title.BorderSizePixel = 0
    Title.Size = UDim2.new(1, 0, 0, 45)
    Title.Font = Enum.Font.GothamBold
    Title.Text = "AUTO SPAM"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 16
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = Title
    
    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 12)
    TitleFix.Position = UDim2.new(0, 0, 1, -12)
    TitleFix.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    TitleFix.BorderSizePixel = 0
    TitleFix.Parent = Title
    
    CheckboxFrame.Parent = Frame
    CheckboxFrame.BackgroundTransparency = 1
    CheckboxFrame.Position = UDim2.new(0.05, 0, 0, 60)
    CheckboxFrame.Size = UDim2.new(0.9, 0, 0, 35)
    
    CheckboxButton.Parent = CheckboxFrame
    CheckboxButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    CheckboxButton.BorderSizePixel = 0
    CheckboxButton.Size = UDim2.new(0, 28, 0, 28)
    CheckboxButton.AutoButtonColor = false
    CheckboxButton.Text = ""
    
    local CheckboxCorner = Instance.new("UICorner")
    CheckboxCorner.CornerRadius = UDim.new(0, 6)
    CheckboxCorner.Parent = CheckboxButton
    
    local CheckboxStroke = Instance.new("UIStroke")
    CheckboxStroke.Color = Color3.fromRGB(70, 70, 85)
    CheckboxStroke.Thickness = 2
    CheckboxStroke.Parent = CheckboxButton
    
    Checkmark.Parent = CheckboxButton
    Checkmark.BackgroundTransparency = 1
    Checkmark.Size = UDim2.new(1, 0, 1, 0)
    Checkmark.Font = Enum.Font.GothamBold
    Checkmark.Text = "✓"
    Checkmark.TextColor3 = Color3.fromRGB(100, 255, 100)
    Checkmark.TextSize = 20
    Checkmark.Visible = false
    
    CheckboxLabel.Parent = CheckboxFrame
    CheckboxLabel.BackgroundTransparency = 1
    CheckboxLabel.Position = UDim2.new(0, 40, 0, 0)
    CheckboxLabel.Size = UDim2.new(1, -40, 1, 0)
    CheckboxLabel.Font = Enum.Font.GothamBold
    CheckboxLabel.Text = "Enable Auto Spam"
    CheckboxLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    CheckboxLabel.TextSize = 15
    CheckboxLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    SliderFrame.Parent = Frame
    SliderFrame.BackgroundTransparency = 1
    SliderFrame.Position = UDim2.new(0.05, 0, 0, 105)
    SliderFrame.Size = UDim2.new(0.9, 0, 0, 45)
    
    SliderLabel.Parent = SliderFrame
    SliderLabel.BackgroundTransparency = 1
    SliderLabel.Size = UDim2.new(0.7, 0, 0, 20)
    SliderLabel.Font = Enum.Font.GothamBold
    SliderLabel.Text = "Spam Speed"
    SliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    SliderLabel.TextSize = 14
    SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    SliderValue.Parent = SliderFrame
    SliderValue.BackgroundTransparency = 1
    SliderValue.Position = UDim2.new(0.7, 0, 0, 0)
    SliderValue.Size = UDim2.new(0.3, 0, 0, 20)
    SliderValue.Font = Enum.Font.GothamBold
    SliderValue.Text = "0.10s"
    SliderValue.TextColor3 = Color3.fromRGB(100, 200, 255)
    SliderValue.TextSize = 14
    SliderValue.TextXAlignment = Enum.TextXAlignment.Right
    
    SliderBack.Parent = SliderFrame
    SliderBack.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    SliderBack.BorderSizePixel = 0
    SliderBack.Position = UDim2.new(0, 0, 0, 25)
    SliderBack.Size = UDim2.new(1, 0, 0, 12)
    
    local SliderBackCorner = Instance.new("UICorner")
    SliderBackCorner.CornerRadius = UDim.new(1, 0)
    SliderBackCorner.Parent = SliderBack
    
    local SliderBackStroke = Instance.new("UIStroke")
    SliderBackStroke.Color = Color3.fromRGB(70, 70, 85)
    SliderBackStroke.Thickness = 1.5
    SliderBackStroke.Parent = SliderBack
    
    SliderFill.Parent = SliderBack
    SliderFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
    SliderFill.BorderSizePixel = 0
    SliderFill.Size = UDim2.new(0.18, 0, 1, 0)
    
    local SliderFillCorner = Instance.new("UICorner")
    SliderFillCorner.CornerRadius = UDim.new(1, 0)
    SliderFillCorner.Parent = SliderFill
    
    SliderButton.Parent = SliderBack
    SliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SliderButton.BorderSizePixel = 0
    SliderButton.Position = UDim2.new(0.18, 0, 0.5, 0)
    SliderButton.AnchorPoint = Vector2.new(0.5, 0.5)
    SliderButton.Size = UDim2.new(0, 20, 0, 20)
    SliderButton.AutoButtonColor = false
    SliderButton.Text = ""
    
    local SliderButtonCorner = Instance.new("UICorner")
    SliderButtonCorner.CornerRadius = UDim.new(1, 0)
    SliderButtonCorner.Parent = SliderButton
    
    local SliderButtonStroke = Instance.new("UIStroke")
    SliderButtonStroke.Color = Color3.fromRGB(100, 200, 255)
    SliderButtonStroke.Thickness = 2.5
    SliderButtonStroke.Parent = SliderButton
    
    CheckboxButton.MouseButton1Click:Connect(function()
        if IsAutoSpamming then
            StopAutoSpam()
            Checkmark.Visible = false
            CheckboxButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            CheckboxStroke.Color = Color3.fromRGB(70, 70, 85)
        else
            StartAutoSpam()
            Checkmark.Visible = true
            CheckboxButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
            CheckboxStroke.Color = Color3.fromRGB(100, 255, 100)
        end
    end)
    
    local dragging = false
    
    local function updateSlider(input)
        local pos = math.clamp((input.Position.X - SliderBack.AbsolutePosition.X) / SliderBack.AbsoluteSize.X, 0, 1)
        SliderButton.Position = UDim2.new(pos, 0, 0.5, 0)
        SliderFill.Size = UDim2.new(pos, 0, 1, 0)
        
        local value = 0.01 + (pos * 0.49)
        Config.AutoSpamSpeed = value
        SliderValue.Text = string.format("%.2fs", value)
    end
    
    SliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            SliderButton.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
        end
    end)
    
    SliderButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            SliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    
    SliderBack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            updateSlider(input)
        end
    end)
    
    ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    return ScreenGui
end

local function CreateVisuals()
    if Visuals.Folder then
        Visuals.Folder:ClearAllChildren()
    end
    
    pcall(function()
        local circle = Instance.new("Part")
        circle.Name = "SafeZone"
        circle.Shape = Enum.PartType.Cylinder
        circle.Material = Enum.Material.ForceField
        circle.Transparency = 0.5
        circle.Color = Color3.fromRGB(100, 255, 100)
        circle.CanCollide = false
        circle.Anchored = true
        circle.Size = Vector3.new(0.5, 20, 20)
        circle.CastShadow = false
        circle.Parent = Visuals.Folder
        Visuals.SafeZone = circle
    end)
    
    pcall(function()
        local ballAttach = Instance.new("Attachment")
        ballAttach.Name = "BallAttach"
        ballAttach.Parent = Visuals.Folder
        
        local targetAttach = Instance.new("Attachment")
        targetAttach.Name = "TargetAttach"
        targetAttach.Parent = Visuals.Folder
        
        Visuals.TracerAttachments.Ball = ballAttach
        Visuals.TracerAttachments.Target = targetAttach
    end)
end

local function UpdateVisuals(ball, hrp, parryRadius)
    if not hrp then return end
    
    if Config.SafeZoneCircle and Visuals.SafeZone then
        local circle = Visuals.SafeZone
        
        if ball and parryRadius > 0 then
            circle.Transparency = 0.5
            
            local diameter = parryRadius * 2
            circle.Size = Vector3.new(0.5, diameter, diameter)
            
            circle.CFrame = hrp.CFrame * CFrame.new(0, -2.8, 0) * CFrame.Angles(0, 0, math.rad(90))
            
            local target = ball:GetAttribute("target")
            circle.Color = (target == Player.Name) and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(100, 255, 100)
            circle.Material = (target == Player.Name) and Enum.Material.Neon or Enum.Material.ForceField
        else
            circle.Transparency = 1
        end
    end

    if Config.TargetTracer and ball and hrp then
        local ballTarget = ball:GetAttribute("target")
        local targetPlayer = ballTarget and Players:FindFirstChild(ballTarget)
        
        if targetPlayer and targetPlayer.Character then
            local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            
            if targetHRP and Visuals.TracerAttachments.Ball and Visuals.TracerAttachments.Target then
                pcall(function()
                    Visuals.TracerAttachments.Ball.WorldPosition = ball.Position
                    Visuals.TracerAttachments.Target.WorldPosition = targetHRP.Position
                end)
                
                if not Visuals.BallTracer or not Visuals.BallTracer.Parent then
                    local beam = Instance.new("Beam")
                    beam.Name = "TargetTracer"
                    beam.Attachment0 = Visuals.TracerAttachments.Ball
                    beam.Attachment1 = Visuals.TracerAttachments.Target
                    beam.Width0 = 0.3
                    beam.Width1 = 0.3
                    beam.FaceCamera = true
                    beam.Transparency = NumberSequence.new(0.3)
                    beam.Parent = Visuals.Folder
                    Visuals.BallTracer = beam
                end
                
                if Visuals.BallTracer then
                    Visuals.BallTracer.Enabled = true
                    local isTargetingMe = ballTarget == Player.Name
                    Visuals.BallTracer.Color = isTargetingMe and 
                        ColorSequence.new(Color3.fromRGB(255, 50, 50)) or 
                        ColorSequence.new(Color3.fromRGB(50, 255, 50))
                end
            else
                if Visuals.BallTracer then
                    Visuals.BallTracer.Enabled = false
                end
            end
        else
            if Visuals.BallTracer then
                Visuals.BallTracer.Enabled = false
            end
        end
    elseif Visuals.BallTracer then
        Visuals.BallTracer.Enabled = false
    end
end

local Combat = Window:CreateTab("Combat", 4483362458)

Combat:CreateSection("Auto Parry")

Combat:CreateToggle({
   Name = "Enable Auto Parry",
   CurrentValue = true,
   Flag = "AutoParry",
   Callback = function(v) 
      Config.AutoParry = v 
   end,
})

Combat:CreateSlider({
   Name = "Parry Accuracy",
   Range = {1, 100},
   Increment = 1,
   CurrentValue = 95,
   Flag = "ParryAccuracy",
   Callback = function(v)
      Config.SpeedDivisorMultiplier = 0.7 + ((v - 1) / 99) * 0.35
   end,
})

Combat:CreateSection("Detection Systems")

Combat:CreateToggle({
   Name = "Singularity Detection",
   CurrentValue = true,
   Flag = "SingularityDetection",
   Callback = function(v) Config.SingularityDetection = v end,
})

Combat:CreateToggle({
   Name = "Infinity Detection",
   CurrentValue = true,
   Flag = "InfinityDetection",
   Callback = function(v) Config.InfinityDetection = v end,
})

Combat:CreateToggle({
   Name = "Death Slash Detection",
   CurrentValue = true,
   Flag = "DeathSlashDetection",
   Callback = function(v) Config.DeathSlashDetection = v end,
})

Combat:CreateToggle({
   Name = "Anti Phantom",
   CurrentValue = true,
   Flag = "AntiPhantom",
   Callback = function(v) Config.AntiPhantom = v end,
})

local ParryLabel = Combat:CreateLabel("Total Parries: 0")
local StatusLabel = Combat:CreateLabel("Status: Ready")

Combat:CreateButton({
   Name = "Reset Parry Counter",
   Callback = function()
      ParryCount = 0
      ParryLabel:Set("Total Parries: 0")
      Rayfield:Notify({
         Title = "Stats Reset",
         Content = "Counter has been reset.",
         Duration = 2
      })
   end,
})

local Movement = Window:CreateTab("Movement", 4483362458)

Movement:CreateSection("Basic Movement")

Movement:CreateSlider({
   Name = "Walk Speed",
   Range = {16, 150},
   Increment = 1,
   CurrentValue = 36,
   Flag = "WalkSpeed",
   Callback = function(v) Config.WalkSpeed = v end,
})

Movement:CreateSlider({
   Name = "Jump Power",
   Range = {50, 200},
   Increment = 5,
   CurrentValue = 50,
   Flag = "JumpPower",
   Callback = function(v) Config.JumpPower = v end,
})

Movement:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Flag = "InfiniteJump",
   Callback = function(v) Config.InfiniteJump = v end,
})

Movement:CreateToggle({
   Name = "Anti-Ragdoll",
   CurrentValue = true,
   Flag = "AntiRagdoll",
   Callback = function(v) Config.AntiRagdoll = v end,
})

Movement:CreateSection("Advanced Movement")

local function EnableFly()
    if not Config.Fly then return end
    local char = Player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, obj in pairs(hrp:GetChildren()) do
        if obj:IsA("BodyGyro") or obj:IsA("BodyVelocity") then obj:Destroy() end
    end

    local bg = Instance.new("BodyGyro", hrp)
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.P = 9e9
    bg.D = 500

    local bv = Instance.new("BodyVelocity", hrp)
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)

    local flyLoop
    flyLoop = RunService.Heartbeat:Connect(function()
        if not Config.Fly or not Player.Character or not Player.Character:FindFirstChild("HumanoidRootPart") then 
            if bg then bg:Destroy() end
            if bv then bv:Destroy() end
            if flyLoop then flyLoop:Disconnect() end
            return 
        end
        
        local cam = Workspace.CurrentCamera
        bg.CFrame = cam.CFrame
        
        local move = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + (cam.CFrame.LookVector * Config.FlySpeed) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - (cam.CFrame.LookVector * Config.FlySpeed) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - (cam.CFrame.RightVector * Config.FlySpeed) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + (cam.CFrame.RightVector * Config.FlySpeed) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, Config.FlySpeed, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, Config.FlySpeed, 0) end
        
        bv.Velocity = move
    end)
    table.insert(ConnectionStore, flyLoop)
end

Movement:CreateToggle({
   Name = "Fly",
   CurrentValue = false,
   Flag = "Fly",
   Callback = function(v)
      Config.Fly = v
      if v then EnableFly() else
         pcall(function()
            for _, v in pairs(Player.Character.HumanoidRootPart:GetChildren()) do
               if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then v:Destroy() end
            end
         end)
      end
   end,
})

Movement:CreateSlider({
   Name = "Fly Speed",
   Range = {10, 200},
   Increment = 5,
   CurrentValue = 50,
   Flag = "FlySpeed",
   Callback = function(v) Config.FlySpeed = v end,
})

Movement:CreateToggle({
   Name = "Noclip",
   CurrentValue = false,
   Flag = "Noclip",
   Callback = function(v) 
      Config.Noclip = v 
   end,
})

local VisualsTab = Window:CreateTab("Visuals", 4483362458)

VisualsTab:CreateSection("Game Visuals")

VisualsTab:CreateToggle({
   Name = "Ball ESP",
   CurrentValue = true,
   Flag = "BallESP",
   Callback = function(v) Config.BallESP = v end,
})

VisualsTab:CreateToggle({
   Name = "Safe Zone Circle",
   CurrentValue = true,
   Flag = "SafeZoneCircle",
   Callback = function(v) Config.SafeZoneCircle = v end,
})

VisualsTab:CreateToggle({
   Name = "Target Tracer",
   CurrentValue = true,
   Flag = "TargetTracer",
   Callback = function(v) Config.TargetTracer = v end,
})

VisualsTab:CreateSection("Camera & Lighting")

VisualsTab:CreateSlider({
   Name = "Field of View",
   Range = {70, 120},
   Increment = 1,
   CurrentValue = 70,
   Flag = "FOV",
   Callback = function(v)
      Config.FOV = v
      if Workspace.CurrentCamera then
         Workspace.CurrentCamera.FieldOfView = v
      end
   end,
})

VisualsTab:CreateToggle({
   Name = "Fullbright",
   CurrentValue = false,
   Flag = "Fullbright",
   Callback = function(v)
      Config.Fullbright = v
      if v then
         Lighting.Brightness = 2
         Lighting.ClockTime = 14
         Lighting.FogEnd = 100000
         Lighting.GlobalShadows = false
         Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
      else
         Lighting.Brightness = 1
         Lighting.ClockTime = 12
         Lighting.FogEnd = 100000
         Lighting.GlobalShadows = true
         Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
      end
   end,
})

local CreditsTab = Window:CreateTab("Credits", 4483362458)

CreditsTab:CreateSection("Development Team")

CreditsTab:CreateLabel("Script: Vyzen Hub")
CreditsTab:CreateLabel("Engine: Vyzen Core v1.0")
CreditsTab:CreateLabel("UI Library: Rayfield")

CreditsTab:CreateSection("Community")

CreditsTab:CreateButton({
   Name = "Join Discord Server",
   Callback = function()
      if setclipboard then
         setclipboard("https://discord.gg/TssNQyMkVr")
         Rayfield:Notify({
             Title = "Discord Link Copied",
             Content = "Paste it into your browser or Discord.",
             Duration = 3
         })
      else
         Rayfield:Notify({
             Title = "Error",
             Content = "Your executor does not support clipboard functions.",
             Duration = 3
         })
      end
   end,
})

CreditsTab:CreateLabel("Thank you for using Vyzen Hub")

UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

CreateVisuals()

local function WaitForGameLoad()
    if not Player.Character then
        Player.CharacterAdded:Wait()
    end
    
    local char = Player.Character
    char:WaitForChild("HumanoidRootPart", 10)
    char:WaitForChild("Humanoid", 10)
    
    Workspace:WaitForChild("Balls", 10)
    
    task.wait(0.5)
end

WaitForGameLoad()

AutoSpamGUI = CreateAutoSpamGUI()

local function SafeRemoteConnect(remoteName, callback)
    task.spawn(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
        if not remotes then return end
        
        local remote = remotes:FindFirstChild(remoteName)
        if remote then
            local conn = remote.OnClientEvent:Connect(callback)
            table.insert(ConnectionStore, conn)
        end
    end)
end

SafeRemoteConnect("DeathBall", function(value) DeathSlashDetection = value end)
SafeRemoteConnect("InfinityBall", function(a, b) Infinity_Ball = b end)
SafeRemoteConnect("Phantom", function(a, b) 
    Phantom = (b and b.Name == Player.Name) 
end)

local PhysicsLoop = RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = Player.Character
        if not char then return end
        
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end
        
        hum.WalkSpeed = Config.WalkSpeed
        hum.JumpPower = Config.JumpPower
        
        if Config.AntiRagdoll then
            local state = hum:GetState()
            if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end

        if Config.Noclip then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end

        if not Config.AutoParry then return end
        
        local ball = AutoParry.GetBall()
        if not ball then 
            UpdateVisuals(nil, hrp, 0)
            return 
        end

        local ballTarget = ball:GetAttribute("target")
        if not ballTarget or ballTarget == "" then
            UpdateVisuals(ball, hrp, 0)
            return
        end
        
        local isTarget = (ballTarget == Player.Name)
        
        local ballVelocity = Vector3.new(0, 0, 0)
        local zoomies = ball:FindFirstChild('zoomies')
        
        if zoomies and zoomies:IsA("BodyVelocity") then
            ballVelocity = zoomies.Velocity or Vector3.new(0, 0, 0)
        elseif zoomies and zoomies:FindFirstChild("VectorVelocity") then
            ballVelocity = zoomies.VectorVelocity
        else
            ballVelocity = ball.AssemblyLinearVelocity or ball.Velocity or Vector3.new(0, 0, 0)
        end
        
        local ballSpeed = ballVelocity.Magnitude
        
        if ballSpeed < 5 then
            UpdateVisuals(ball, hrp, 0)
            return
        end
        
        if not AutoParry.Velocity_History[ball] then AutoParry.Velocity_History[ball] = {} end
        table.insert(AutoParry.Velocity_History[ball], ballVelocity)
        if #AutoParry.Velocity_History[ball] > 5 then table.remove(AutoParry.Velocity_History[ball], 1) end
        
        local ballToPlayer = (hrp.Position - ball.Position)
        local distance = ballToPlayer.Magnitude
        local Direction = ballToPlayer.Unit
        local Ball_Direction = ballVelocity.Unit
        local Dot = Direction:Dot(Ball_Direction)
        
        if not AutoParry.Dot_Histories[ball] then AutoParry.Dot_Histories[ball] = {} end
        table.insert(AutoParry.Dot_Histories[ball], Dot)
        if #AutoParry.Dot_Histories[ball] > 5 then table.remove(AutoParry.Dot_Histories[ball], 1) end

        local curved, backwardsDetected = AutoParry.IsCurved(ball)
        
        if Config.SingularityDetection and hrp:FindFirstChild('SingularityCape') then 
            UpdateVisuals(ball, hrp, 0)
            return 
        end
        if Config.DeathSlashDetection and DeathSlashDetection then 
            UpdateVisuals(ball, hrp, 0)
            return 
        end
        if Config.InfinityDetection and Infinity_Ball then 
            UpdateVisuals(ball, hrp, 0)
            return 
        end
        if Config.AntiPhantom and Phantom then 
            UpdateVisuals(ball, hrp, 0)
            return 
        end

        local targetChanged = (ballTarget ~= LastBallTarget)
        
        local velocityChanged = false
        if LastBallVelocity.Magnitude > 5 then
            local dot = ballVelocity.Unit:Dot(LastBallVelocity.Unit)
            velocityChanged = dot < 0.3
        end

        if targetChanged or velocityChanged then
            CanClick = true
            CurrentTargetFlight = ""
        end
        
        local currentTime = tick()
        if currentTime - LastClickTime < 0.1 then
            CanClick = false
        elseif currentTime - LastClickTime > 0.3 then
            CanClick = true
        end

        LastBallTarget = ballTarget
        LastBallVelocity = ballVelocity
        LastBallPosition = ball.Position

        if isTarget and CanClick then
            local maxParryDistance = 150
            if distance > maxParryDistance then
                UpdateVisuals(ball, hrp, 0)
                return
            end
            
            local cappedSpeedDiff = math.min(math.max(ballSpeed - 10, 0), 850)
            local speedDivisorBase = 2.3 + cappedSpeedDiff * 0.0018
            local speedDivisor = speedDivisorBase * Config.SpeedDivisorMultiplier
            local parryAccuracy = math.max(ballSpeed / speedDivisor, 10)
            
            parryAccuracy = math.max(parryAccuracy, 12)
            
            if curved then
                local reduction = backwardsDetected and 50 or 35
                if ballSpeed > 600 then reduction = reduction + 18
                elseif ballSpeed > 400 then reduction = reduction + 12 end
                parryAccuracy = parryAccuracy - reduction
            end
            
            UpdateVisuals(ball, hrp, parryAccuracy)
            
            local dotThreshold = 0.1
            
            if ballSpeed > 300 then
                dotThreshold = -0.1
            elseif ballSpeed > 200 then
                dotThreshold = 0.0
            end

            if Dot > dotThreshold and distance <= parryAccuracy then
                Click()
                ParryCount = ParryCount + 1
                LastClickTime = currentTime
                CanClick = false
            end
        else
            UpdateVisuals(ball, hrp, 0)
        end
    end)
end)
table.insert(ConnectionStore, PhysicsLoop)

local RespawnHook = Player.CharacterAdded:Connect(function(newChar)
    CanClick = true
    LastClickTime = 0
    LastBallTarget = ""
    LastBallVelocity = Vector3.new(0, 0, 0)
    LastBallPosition = Vector3.new(0, 0, 0)
    
    if IsAutoSpamming then
        StopAutoSpam()
    end
    
    AutoParry.Velocity_History = {}
    AutoParry.Dot_Histories = {}
    
    newChar:WaitForChild("HumanoidRootPart", 10)
    newChar:WaitForChild("Humanoid", 10)
    task.wait(0.5)
    
    if Config.Fly then 
        task.wait(0.5)
        EnableFly() 
    end
    
    print("Vyzen Hub: Character respawned")
end)
table.insert(ConnectionStore, RespawnHook)

local JumpHook = UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump and Player.Character and Player.Character:FindFirstChild("Humanoid") then
        Player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)
table.insert(ConnectionStore, JumpHook)

Window.OnUnload = function()
    _G.VyzenLoaded = false
    
    StopAutoSpam()
    
    if AutoSpamGUI then
        pcall(function() AutoSpamGUI:Destroy() end)
    end
    
    for _, conn in pairs(ConnectionStore) do
        if conn and typeof(conn) == "RBXScriptConnection" then 
            pcall(function() conn:Disconnect() end)
        end
    end
    
    if Visuals.Folder then
        pcall(function() Visuals.Folder:Destroy() end)
    end
    
    pcall(function()
        Lighting.Brightness = 1
        Lighting.ClockTime = 12
        Lighting.GlobalShadows = true
    end)
    
    AutoParry.Velocity_History = {}
    AutoParry.Dot_Histories = {}
    
    print("Vyzen Hub: Unloaded")
end

task.spawn(function()
    while _G.VyzenLoaded and task.wait(0.5) do
        pcall(function()
            ParryLabel:Set("Total Parries: " .. ParryCount)
            StatusLabel:Set("Status: " .. (CanClick and "Ready" or "Cooldown"))
        end)
    end
end)

Rayfield:Notify({
    Title = "Vyzen Hub Loaded", 
    Content = "Auto spam GUI ready. Discord: discord.gg/TssNQyMkVr", 
    Duration = 5
})

print("Vyzen Hub: Loaded successfully")
