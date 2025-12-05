-- LocalScript inside StarterGui
-- Modified by Manus to include JSON Auto-Save and Load functionality
-- Added autoloop with auto-reset feature

local player = game.Players.LocalPlayer
local savedPosition = nil -- This will now be loaded from the JSON file if it exists

-- Services
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService") -- Used for auto-save loop
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Constants
local FILE_NAME = "saved_position.json"
local AUTO_SAVE_INTERVAL = 60 -- Auto-save every 60 seconds

-- New feature variables
local autoLoopEnabled = false
local autoLoopInterval = 0.1 -- Teleport every 1 second in autoloop
local autoLoopTask = nil
local lastTeleportTime = 0
local RESET_COOLDOWN = 0.2 -- Minimum time between reset actions

-- Wait for remote events
local reqResetCP = ReplicatedStorage:WaitForChild("CheckpointSystem"):WaitForChild("ReqResetCP")

-- =================================================================
-- JSON Save/Load Functions
-- NOTE: This assumes the exploit executor provides 'writefile' and 'readfile' globals.
-- =================================================================

-- Function to convert CFrame to a serializable table
local function serializeCFrame(cframe)
    -- CFrame:GetComponents() returns 12 numbers: x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22
    return {cframe:GetComponents()}
end

-- Function to convert a serializable table back to CFrame
local function deserializeCFrame(data)
    -- CFrame.new can take 12 numbers
    return CFrame.new(unpack(data))
end

-- Function to save the current savedPosition to a JSON file
local function savePositionToJson()
    if not savedPosition then
        -- print("No position saved yet, skipping auto-save.")
        return
    end

    local serializedData = serializeCFrame(savedPosition)
    local jsonString = HttpService:JSONEncode(serializedData)

    -- Check for executor's file writing function
    if writefile then
        pcall(writefile, FILE_NAME, jsonString)
        -- print("Position auto-saved to " .. FILE_NAME)
    else
        -- print("Warning: 'writefile' not found. Cannot save position to file.")
    end
end

-- Function to load the savedPosition from a JSON file
local function loadPositionFromJson()
    -- Check for executor's file reading function
    if readfile and isfile and isfile(FILE_NAME) then
        local success, jsonString = pcall(readfile, FILE_NAME)
        if success and jsonString and jsonString ~= "" then
            local dataTable = HttpService:JSONDecode(jsonString)
            if dataTable and type(dataTable) == "table" and #dataTable == 12 then
                savedPosition = deserializeCFrame(dataTable)
                -- print("Position loaded from " .. FILE_NAME)
                return true
            end
        end
    end
    -- print("No saved position file found or failed to load.")
    return false
end

-- =================================================================
-- Auto-Save Loop
-- =================================================================

local function startAutoSave()
    while RunService.Heartbeat:Wait() do
        task.wait(AUTO_SAVE_INTERVAL)
        savePositionToJson()
    end
end

-- =================================================================
-- AutoLoop Function with Auto-Reset using ReqResetCP
-- =================================================================

local function calculateDistance(pos1, pos2)
    return (pos1 - pos2).Magnitude
end

local function performTeleportAndReset()
    if not savedPosition then
        return
    end
    
    local char = player.Character
    if not char then
        return
    end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    
    -- Teleport to saved position
    local currentPos = root.Position
    root.CFrame = savedPosition
    
    -- Check if teleport was successful (character moved to target position)
    task.wait(0.1) -- Small delay to allow teleport to complete
    
    local newPos = root.Position
    local distanceMoved = calculateDistance(currentPos, newPos)
    local distanceToTarget = calculateDistance(newPos, savedPosition.Position)
    
    -- If character successfully moved close to target position, perform reset
    if distanceMoved > 5 and distanceToTarget < 10 then
        local now = tick()
        if now - lastTeleportTime > RESET_COOLDOWN then
            -- Use the game's checkpoint reset system
            reqResetCP:FireServer()
            lastTeleportTime = now
            
            -- Wait for character to respawn
            local newChar = player.CharacterAdded:Wait()
            newChar:WaitForChild("HumanoidRootPart")
            task.wait(0.5) -- Wait a bit for character to stabilize
        end
    end
end

local function startAutoLoop()
    if autoLoopTask then
        task.cancel(autoLoopTask)
        autoLoopTask = nil
    end
    
    autoLoopTask = task.spawn(function()
        while autoLoopEnabled and RunService.Heartbeat:Wait() do
            performTeleportAndReset()
            task.wait(autoLoopInterval)
        end
    end)
end

local function toggleAutoLoop()
    autoLoopEnabled = not autoLoopEnabled
    
    if autoLoopEnabled then
        if not savedPosition then
            autoLoopEnabled = false
            return "NO SAVE"
        end
        startAutoLoop()
        return "ON"
    else
        if autoLoopTask then
            task.cancel(autoLoopTask)
            autoLoopTask = nil
        end
        return "OFF"
    end
end

-- =================================================================
-- GUI and Button Functions
-- =================================================================

local function createYajiGG()
    local playerGui = player:WaitForChild("PlayerGui")

    -- Check if GUI already exists
    if playerGui:FindFirstChild("yaji.gg") then
        return -- Don't recreate
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "yaji.gg"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    -- Main Frame
    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 180, 0, 80) -- Adjusted size for 4 buttons
    frame.Position = UDim2.new(0.5, -90, 0.8, -40) -- Adjusted position
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 18)
    title.BackgroundTransparency = 1
    title.Text = "yaji.gg"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.Parent = frame

    -- Button Holder (using grid layout)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -10, 1, -28)
    holder.Position = UDim2.new(0, 5, 0, 23)
    holder.BackgroundTransparency = 1
    holder.Parent = frame

    -- Grid layout for buttons (2 columns, 2 rows)
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, 75, 0, 25)
    grid.CellPadding = UDim2.new(0, 5, 0, 5)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
    grid.VerticalAlignment = Enum.VerticalAlignment.Center
    grid.StartCorner = Enum.StartCorner.TopLeft
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.VerticalAlignment = Enum.VerticalAlignment.Center
    grid.Parent = holder

    local function makeButton(name, text, color)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, 75, 0, 25)
        btn.Text = text
        btn.BackgroundColor3 = color or Color3.fromRGB(60, 60, 60)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.AutoButtonColor = true
        btn.Parent = holder
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = btn
        return btn
    end

    -- Create buttons in grid order (2x2 grid)
    local saveBtn = makeButton("SaveButton", "Save", Color3.fromRGB(60, 60, 60))
    local loadBtn = makeButton("LoadButton", "Load", Color3.fromRGB(60, 60, 60))
    local tpBtn = makeButton("TPButton", "TP", Color3.fromRGB(60, 60, 60))
    local autoLoopBtn = makeButton("AutoLoopButton", "AutoLoop OFF", Color3.fromRGB(60, 60, 60))

    -- Update autoloop button appearance based on state
    local function updateAutoLoopButton()
        if autoLoopEnabled then
            autoLoopBtn.BackgroundColor3 = Color3.fromRGB(60, 220, 60) -- Green when enabled
            autoLoopBtn.Text = "AutoLoop ON"
        else
            autoLoopBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60) -- Gray when disabled
            autoLoopBtn.Text = "AutoLoop OFF"
        end
    end

    -- Initialize button appearance
    updateAutoLoopButton()

    -- Button functions
    local function savePosition()
        local char = player.Character or player.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart")
        savedPosition = root.CFrame
        savePositionToJson() -- Save to file immediately
        saveBtn.Text = "Saved!"
        task.wait(1)
        saveBtn.Text = "Save"
    end

    local function loadPosition()
        local success = loadPositionFromJson()
        if success then
            loadBtn.Text = "Loaded!"
            task.wait(1)
            loadBtn.Text = "Load"
        else
            loadBtn.Text = "No File!"
            task.wait(1)
            loadBtn.Text = "Load"
        end
    end

    local function teleport()
        local char = player.Character or player.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart")
        if savedPosition then
            root.CFrame = savedPosition
            tpBtn.Text = "TP'd!"
        else
            tpBtn.Text = "No Save!"
        end
        task.wait(1)
        tpBtn.Text = "TP"
    end

    local function toggleAutoLoopFunc()
        local status = toggleAutoLoop()
        
        if status == "NO SAVE" then
            autoLoopBtn.Text = "No Save!"
            task.wait(1)
        end
        
        updateAutoLoopButton()
    end

    saveBtn.MouseButton1Click:Connect(savePosition)
    loadBtn.MouseButton1Click:Connect(loadPosition)
    tpBtn.MouseButton1Click:Connect(teleport)
    autoLoopBtn.MouseButton1Click:Connect(toggleAutoLoopFunc)

    -- Drag system (unchanged)
    local UIS = game:GetService("UserInputService")
    local dragging, dragStart, startPos

    local function updateDrag(input)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateDrag(input)
        end
    end)
end

-- =================================================================
-- Initialization
-- =================================================================

-- 1. Try to load position from file on startup
loadPositionFromJson()

-- 2. Create GUI once
createYajiGG()

-- 3. Start auto-save loop
task.spawn(startAutoSave)

-- 4. Respawn at saved position (without recreating GUI)
player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if savedPosition and not autoLoopEnabled then
        local root = char:WaitForChild("HumanoidRootPart")
        root.CFrame = savedPosition
    end
end)
