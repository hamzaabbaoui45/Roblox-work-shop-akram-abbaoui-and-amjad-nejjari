-- debug: inspect the toast label state after clicking a config button
dofile("mock.lua")
local ok, err = pcall(dofile, "SMPWORK_dbg.lua")
print("loaded:", ok, err)

local function walk(inst, out)
    out = out or {}
    for _, child in ipairs(inst.__children or {}) do
        out[#out + 1] = child
        walk(child, out)
    end
    return out
end

local gui = nil
for _, inst in ipairs(MOCK_CORE.__children) do
    if inst.__class == "ScreenGui" then gui = inst end
end

local all = walk(gui)
for _, inst in ipairs(all) do
    if inst.__class == "TextLabel" and inst.__props.ZIndex == 20 then
        print("found toast: class=" .. inst.__class .. " text=[" .. tostring(inst.__props.Text) ..
            "] visible=" .. tostring(inst.__props.Visible) ..
            " parent=" .. tostring(inst.__props.Parent and inst.__props.Parent.__props.Name))
    end
end

-- click CHECK FOR UPDATES
for _, inst in ipairs(all) do
    if inst.__class == "TextButton" and inst.__props.Text == "CHECK FOR UPDATES" then
        print("clicking CHECK FOR UPDATES")
        inst.MouseButton1Click:Fire()
        print("after click, visible=" .. tostring(inst.__props.Visible))
        for _, t in ipairs(all) do
            if t.__class == "TextLabel" and t.__props.ZIndex == 20 then
                print("  toast now: text=[" .. tostring(t.__props.Text) .. "] visible=" .. tostring(t.__props.Visible))
            end
        end
    end
end
