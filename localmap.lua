-- INSTANT PROMPT SCRIPT FOR SOLARA
local ProximityPromptService = game:GetService("ProximityPromptService")

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
    -- Instantly finish the hold
    prompt:InputHoldEnd()
    
    -- Optional: Also try firing it directly just in case
    pcall(function()
        fireproximityprompt(prompt)
    end)
end)

print("Instant Prompt Loaded!")