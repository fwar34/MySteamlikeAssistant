------------------------------------------------------------------
-- MySteamlikeAssistant —— 鼠标视角助手（WoW 3.3.5a / WLK）
------------------------------------------------------------------
-- 作用：
--   接收两个特殊按键 F20 / F21（一般由手柄映射软件或安卓模拟器注入），
--   用来控制游戏的“鼠标视角”（Mouselook，等价于按住鼠标右键拖动视角）。
--
--      按 F20  -> 若当前不在鼠标视角，则开启（MouselookStart）
--      按 F21  -> 关闭鼠标视角（MouselookStop）
--
-- 原理：
--   使用 SetBindingClick 把 F20/F21 绑定到两个“隐藏按钮”的点击事件上。
--   按键触发时，客户端会调用对应按钮的 OnClick 脚本，从而执行开启/关闭逻辑。
--   这样既不需要 Bindings.xml，也不会出现在游戏“按键设置”界面里，
--   但绑定是真实生效的（用 /msa 可看到 “CLICK MSA_Btn_F20:LeftButton”）。
--
-- 相关 API（3.3.5a 客户端均已验证存在）：
--   IsMouselooking()  -> 返回当前是否处于鼠标视角
--   MouselookStart()  -> 开启鼠标视角
--   MouselookStop()   -> 关闭鼠标视角
------------------------------------------------------------------

-- 需要接收的两个按键。若某客户端不识别 F20/F21，可改成其它键（例如 F8 / F9）。
local START_KEY = "F20"
local STOP_KEY = "F21"

-- 两个隐藏按钮的全局名。
-- 注意：SetBindingClick 是“按名字”找按钮的，所以名字必须全局且唯一，不能是 local。
local BTN_START = "MSA_Btn_F20"
local BTN_STOP = "MSA_Btn_F21"

------------------------------------------------------------------
-- 业务逻辑
------------------------------------------------------------------

-- 开启鼠标视角。
-- 先判断 IsMouselooking()，避免在已经处于鼠标视角时重复调用 MouselookStart。
local function StartMouselook()
	if not IsMouselooking() then
		MouselookStart()
	end
end

-- 关闭鼠标视角。
local function StopMouselook()
	MouselookStop()
end

------------------------------------------------------------------
-- 隐藏按钮：仅用于接收按键“点击”，不参与任何界面显示
------------------------------------------------------------------

-- CreateFrame 创建的框架默认就是隐藏的，无需 Show()。
-- OnClick 就是按键触发时真正执行的入口。
local btnStart = CreateFrame("Button", BTN_START)
btnStart:SetScript("OnClick", StartMouselook)

local btnStop = CreateFrame("Button", BTN_STOP)
btnStop:SetScript("OnClick", StopMouselook)

------------------------------------------------------------------
-- 按键绑定
------------------------------------------------------------------

-- 把 F20/F21 挂到两个隐藏按钮上，并写入磁盘持久化。
-- 必须调用 SaveBindings，否则绑定只存在于内存，重载界面后会丢失。
-- GetCurrentBindingSet() 返回当前生效的按键方案编号（1 或 2）。
local function ApplyBindings()
	SetBindingClick(START_KEY, BTN_START)
	SetBindingClick(STOP_KEY, BTN_STOP)
	SaveBindings(GetCurrentBindingSet())
end

------------------------------------------------------------------
-- 聊天框输出与状态查询（诊断用）
------------------------------------------------------------------

-- 统一格式的聊天框消息，带 [MSA] 前缀和颜色。
local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[MSA]|r " .. tostring(msg))
end

-- 查询某个按键当前绑定的动作。
-- 正常生效时返回类似 "CLICK MSA_Btn_F20:LeftButton"；
-- 若返回 nil 或空字符串，说明该键未被客户端接受（未生效）。
local function BindingState(key)
	local action = GetBindingAction(key)
	if action == nil or action == "" then
		return "未生效"
	end
	return action
end

-- 输出当前状态：两个按键的绑定情况 + 当前是否在鼠标视角。
local function Status()
	Print("F20 绑定: " .. BindingState(START_KEY))
	Print("F21 绑定: " .. BindingState(STOP_KEY))
	Print("当前鼠标视角: " .. (IsMouselooking() and "开启" or "关闭"))
end

------------------------------------------------------------------
-- 斜杠命令注册
------------------------------------------------------------------
--   /msa           查看状态
--   /msa start     手动开启鼠标视角（用于验证 API 是否可用）
--   /msa stop      手动关闭鼠标视角
--   /msa rebind    重新挂载并持久化绑定
-- /bridge 是等价的别名。
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

------------------------------------------------------------------
-- 事件：登录后自动挂钩
------------------------------------------------------------------
-- 在 PLAYER_LOGIN 时挂载绑定，确保此刻按键表已加载完成，时机最稳。
-- 挂载后顺手做一次自检；若 F20 仍未生效则给出提示。
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
	ApplyBindings()
	if BindingState(START_KEY) == "未生效" then
		Print("F20 未生效，客户端可能不识别该按键。")
	end
	self:UnregisterEvent("PLAYER_LOGIN")
end)
