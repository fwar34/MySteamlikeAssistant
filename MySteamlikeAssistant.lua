local START_KEY = "F20"
local STOP_KEY = "F21"
local BTN_START = "MSA_Btn_F20"
local BTN_STOP = "MSA_Btn_F21"

local function StartMouselook()
	if not IsMouselooking() then
		MouselookStart()
	end
end

local function StopMouselook()
	MouselookStop()
end

local btnStart = CreateFrame("Button", BTN_START)
btnStart:SetScript("OnClick", StartMouselook)

local btnStop = CreateFrame("Button", BTN_STOP)
btnStop:SetScript("OnClick", StopMouselook)

local function ApplyBindings()
	SetBindingClick(START_KEY, BTN_START)
	SetBindingClick(STOP_KEY, BTN_STOP)
	SaveBindings(GetCurrentBindingSet())
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[MSA]|r " .. tostring(msg))
end

local function BindingState(key)
	local action = GetBindingAction(key)
	if action == nil or action == "" then
		return "未生效"
	end
	return action
end

local function Status()
	Print("F20 绑定: " .. BindingState(START_KEY))
	Print("F21 绑定: " .. BindingState(STOP_KEY))
	Print("当前鼠标视角: " .. (IsMouselooking() and "开启" or "关闭"))
end

SLASH_MYSTEAMLIKEASSISTANT1 = "/msa"
SLASH_MYSTEAMLIKEASSISTANT2 = "/bridge"
SlashCmdList["MYSTEAMLIKEASSISTANT"] = function(msg)
	msg = string.lower(msg or "")
	if msg == "start" then
		StartMouselook()
	elseif msg == "stop" then
		StopMouselook()
	elseif msg == "rebind" then
		ApplyBindings()
		Status()
	else
		Status()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
	ApplyBindings()
	if BindingState(START_KEY) == "未生效" then
		Print("F20 未生效，客户端可能不识别该按键。")
	end
	self:UnregisterEvent("PLAYER_LOGIN")
end)
