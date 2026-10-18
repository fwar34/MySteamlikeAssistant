------------------------------------------------------------------
-- MySteamlikeAssistant —— 鼠标视角助手（WoW 3.3.5a / WLK）
------------------------------------------------------------------
-- 作用：
--   接收两个特殊按键 F11 / F12（一般由手柄映射软件或安卓模拟器注入），
--   用来控制游戏的“鼠标视角”（Mouselook，等价于按住鼠标右键拖动视角）。
--
--      按 F11  -> 若当前不在鼠标视角，则开启（MouselookStart）
--      按 F12  -> 关闭鼠标视角（MouselookStop）
--
--   另外提供一个「移动自动锁视角」功能（默认关闭，可用 /msa wasd 开关）：
--   当玩家用 W/A/S/D 方向键开始移动时，若当前不在鼠标视角，则自动开启，
--   让相机跟随角色移动。实现方式见下方“移动自动锁视角”一节。
--
-- 原理：
--   使用 SetBindingClick 把 F11/F12 绑定到两个“隐藏按钮”的点击事件上。
--   按键触发时，客户端会调用对应按钮的 OnClick 脚本，从而执行开启/关闭逻辑。
--   这样既不需要 Bindings.xml，也不会出现在游戏“按键设置”界面里，
--   但绑定是真实生效的（用 /msa 可看到 “CLICK MSA_Btn_F20:LeftButton”）。
--
-- 相关 API（3.3.5a 客户端均已验证存在）：
--   IsMouselooking()  -> 返回当前是否处于鼠标视角
--   MouselookStart()  -> 开启鼠标视角
--   MouselookStop()   -> 关闭鼠标视角
------------------------------------------------------------------

-- 需要接收的两个按键。当前先用 F11 / F12，如需更换直接改这里即可。
local START_KEY = "F11"
local STOP_KEY = "F12"

-- 两个隐藏按钮的全局名（仅作内部标识，与具体按键无关）。
-- 注意：SetBindingClick 是“按名字”找按钮的，所以名字必须全局且唯一，不能是 local。
local BTN_START = "MSA_Btn_F20"
local BTN_STOP = "MSA_Btn_F21"

-- 「移动自动锁视角」开关：开启后，用 W/A/S/D 方向键开始移动时，
-- 若当前不在鼠标视角，则自动开启。用 /msa wasd 切换。**默认关闭**。
-- 注意：这是本次运行内的临时开关，重载界面后会恢复为默认值。
local wasdAutoLock = false

-- WASD 本次“已锁定”标记：一旦通过方向键锁上视角，就把后续按键直接短路，
-- 不再每次按键都调用 IsMouselooking() 判断，避免无谓的重复检查。
-- 以下情况会重置该标记，以便下次移动能重新判断并锁定：
--   * 按 F12 / 输入 /msa stop 停止视角；
--   * 按下或松开鼠标右键（手动转向 / 看视角）；
--   * 低频兜底检测发现客户端已自行退出鼠标视角（见下方“视角状态兜底检测”）。
-- 该标记统一通过 SetWASDLocked() 读写，以便顺带开关兜底检测。
local wasdLocked = false

------------------------------------------------------------------
-- 聊天框输出与调试日志
------------------------------------------------------------------

-- 调试日志开关：用 /msa debug 切换，默认关闭，避免正常游玩时刷屏。
-- 打开后，每次收到开始/停止键都会在聊天框打印一行，用来确认按键到底有没有送达。
local debugEnabled = false

-- 统一格式的聊天框消息，带 [MSA] 前缀和颜色。
local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[MSA]|r " .. tostring(msg))
end

-- 仅在调试开关打开时输出。
local function Debug(msg)
	if debugEnabled then
		Print(msg)
	end
end

------------------------------------------------------------------
-- 视角状态兜底检测（自愈）
------------------------------------------------------------------
-- 为什么需要它：wasdLocked 为 true 时，方向键钩子会直接短路（不再判断视角状态）。
-- 但客户端还有很多“非右键”的停视角路径，插件完全看不到，例如：
--   * 打开会捕获鼠标的界面（背包 / 角色 / 地图 / Esc 菜单 / 回车打字）；
--   * 切出游戏窗口后再切回；
--   * 触摸或点击到界面元素。
-- 这些情况下客户端已经退出鼠标视角，而 wasdLocked 仍是 true，于是之后
-- 按 W/A/S/D 全被短路，视角再也锁不回来 —— 外部表现就是“相机不转，
-- 但光标可见、划过界面还会弹提示框”。
-- 解决办法：只在 wasdLocked 为 true 期间挂一个低频（0.5 秒）检测，
-- 一旦发现已不在鼠标视角，就重置标记，让下一次方向键移动重新自动锁定。
-- 按方向键本身仍然只判断一次，不受影响。
local LOCK_CHECK_INTERVAL = 0.5

-- 1x1 的空框架，只用来跑 OnUpdate；隐藏时不消耗任何性能。
local lockCheckFrame = CreateFrame("Frame", nil, UIParent)
lockCheckFrame:SetSize(1, 1)
local lockCheckElapsed = 0

-- 统一设置 wasdLocked：为 true 时顺带开启兜底检测，为 false 时关闭。
-- 由于检测框架只在锁定期间显示，未锁定时没有任何额外开销。
local function SetWASDLocked(locked)
	wasdLocked = locked
	lockCheckElapsed = 0
	if locked then
		lockCheckFrame:Show()
	else
		lockCheckFrame:Hide()
	end
end

lockCheckFrame:SetScript("OnUpdate", function(_, elapsed)
	lockCheckElapsed = lockCheckElapsed + elapsed
	if lockCheckElapsed < LOCK_CHECK_INTERVAL then
		return
	end
	lockCheckElapsed = 0
	if not IsMouselooking() then
		SetWASDLocked(false)
		Debug("视角已被客户端关闭（非右键途径），自动锁定标记已重置，下次移动可重新锁定")
	end
end)

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
-- 停止时清掉 WASD 的“已锁定”标记，让下次方向键移动可以重新判断并锁定。
local function StopMouselook()
	MouselookStop()
	SetWASDLocked(false)
end

------------------------------------------------------------------
-- 隐藏按钮：仅用于接收按键“点击”，不参与任何界面显示
------------------------------------------------------------------

-- CreateFrame 创建的框架默认就是隐藏的，无需 Show()。
-- OnClick 就是按键触发时真正执行的入口。
-- 这里在动作执行后顺便打一条调试日志（含触发来源与当前视角状态），方便排查输入是否送达。
-- 把触发来源（鼠标按键）一并写进日志：SetBindingClick 用的是左键，
-- 正常应显示“左键点击”，也方便确认注入的输入究竟有没有送到。
local function ClickText(button)
	if button == "LeftButton" then
		return "左键点击"
	elseif button == "RightButton" then
		return "右键点击"
	elseif button == "MiddleButton" then
		return "中键点击"
	end
	return tostring(button) .. " 点击"
end

local btnStart = CreateFrame("Button", BTN_START)
btnStart:SetScript("OnClick", function(_, button)
	StartMouselook()
	Debug("收到按键 " .. START_KEY .. "（" .. ClickText(button) .. "，鼠标视角: " .. (IsMouselooking() and "开启" or "关闭") .. "）")
end)

local btnStop = CreateFrame("Button", BTN_STOP)
btnStop:SetScript("OnClick", function(_, button)
	StopMouselook()
	Debug("收到按键 " .. STOP_KEY .. "（" .. ClickText(button) .. "，鼠标视角: " .. (IsMouselooking() and "开启" or "关闭") .. "）")
end)

------------------------------------------------------------------
-- 移动自动锁视角（W/A/S/D 方向键）
------------------------------------------------------------------
-- 思路（参考 ConsolePort 的实现）：不去重绑 W/A/S/D（那会破坏移动功能），
-- 而是用 hooksecurefunc 给游戏的“开始移动”函数挂一个后置钩子。
-- 玩家按 W/A/S/D 时，客户端会调用下列函数，钩子在原函数执行后再触发，
-- 于是我们可以在不改变移动行为的前提下，顺带把鼠标视角打开。
--
-- WoW 默认键位下，方向键对应的函数是：
--   MoveForwardStart  -> 按 W（前进）
--   MoveBackwardStart -> 按 S（后退）
--   TurnLeftStart     -> 按 A（左转）      <-- 注意：默认 A 是“转向”，不是“平移”
--   TurnRightStart    -> 按 D（右转）      <-- 默认 D 是“转向”，不是“平移”
--   StrafeLeftStart   -> 按 Q（左平移）
--   StrafeRightStart  -> 按 E（右平移）
-- （若你把 A/D 改绑成了平移，对应的仍是 Strafe 系列，所以这里一并挂钩，全覆盖。）
--
-- hooksecurefunc 保证钩子一定在原函数之后执行，且不会覆盖原函数，
-- 因此对移动本身没有任何副作用。
local MOVE_FUNCS = {
	"MoveForwardStart",
	"MoveBackwardStart",
	"TurnLeftStart",
	"TurnRightStart",
	"StrafeLeftStart",
	"StrafeRightStart",
}
for _, funcName in ipairs(MOVE_FUNCS) do
	hooksecurefunc(funcName, function()
		if not wasdAutoLock then
			return
		end
		-- 已经锁过一次：直接跳过，不再每次按键都判断视角状态。
		if wasdLocked then
			return
		end
		StartMouselook()
		SetWASDLocked(true)
		Debug("方向键移动触发自动锁视角（" .. funcName .. "）")
	end)
end

------------------------------------------------------------------
-- 鼠标右键：重置 WASD 自动锁定标记
------------------------------------------------------------------
-- 客户端默认把鼠标右键绑定为 TURNORACTION（手动转向 / 看视角），
-- 其处理函数就是 TurnOrActionStart（按下）和 TurnOrActionStop（松开）。
-- 这里给两者挂上钩子：只要玩家按 / 松右键，就清掉 wasdLocked，
-- 这样用右键手动看过视角后，下一次方向键移动仍能重新自动锁定。
-- hooksecurefunc 只做后置钩子，不会改变右键原有的转向/选中行为。
hooksecurefunc("TurnOrActionStart", function()
	SetWASDLocked(false)
end)
hooksecurefunc("TurnOrActionStop", function()
	SetWASDLocked(false)
end)

------------------------------------------------------------------
-- 按键绑定
------------------------------------------------------------------

-- 把 F11/F12 挂到两个隐藏按钮上，并写入磁盘持久化。
-- 必须调用 SaveBindings，否则绑定只存在于内存，重载界面后会丢失。
-- GetCurrentBindingSet() 返回当前生效的按键方案编号（1 或 2）。
local function ApplyBindings()
	SetBindingClick(START_KEY, BTN_START)
	SetBindingClick(STOP_KEY, BTN_STOP)
	SaveBindings(GetCurrentBindingSet())
end

------------------------------------------------------------------
-- 状态查询（诊断用）
------------------------------------------------------------------

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

-- 输出当前状态：两个按键的绑定情况 + 当前是否在鼠标视角 + 调试开关。
local function Status()
	Print(START_KEY .. " 绑定: " .. BindingState(START_KEY))
	Print(STOP_KEY .. " 绑定: " .. BindingState(STOP_KEY))
	Print("当前鼠标视角: " .. (IsMouselooking() and "开启" or "关闭"))
	Print("移动自动锁视角: " .. (wasdAutoLock and "开启" or "关闭"))
	Print("调试日志: " .. (debugEnabled and "开启" or "关闭"))
	Print("输入 /msa help 查看全部命令")
end

------------------------------------------------------------------
-- 设置面板（Esc → 界面 → 鼠标视角助手）
------------------------------------------------------------------
-- 3.3.5a 没有独立的“插件”标签页，插件设置是用 InterfaceOptions_AddCategory
-- 挂到“界面”设置里的一个分类，与“游戏”“声音”等并列。
-- 勾选框使用 InterfaceOptionsCheckButtonTemplate，外观与暴雪原生设置一致。
local optionsPanel = CreateFrame("Frame", "MSA_OptionsPanel", UIParent)
optionsPanel.name = "鼠标视角助手"
optionsPanel:Hide()

local optionsTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
optionsTitle:SetPoint("TOPLEFT", 16, -16)
optionsTitle:SetText("鼠标视角助手")

local optionsDesc = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
optionsDesc:SetPoint("TOPLEFT", optionsTitle, "BOTTOMLEFT", 0, -8)
optionsDesc:SetPoint("RIGHT", optionsPanel, "RIGHT", -16, 0)
optionsDesc:SetJustifyH("LEFT")
optionsDesc:SetText("接收 F11 / F12 控制鼠标视角。以下设置会自动保存，重载界面后仍然保留。")

-- 给勾选框挂上暴雪风格的鼠标提示。
local function SetOptionTooltip(btn, text)
	btn.tooltipText = text
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tooltipText, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local cbWASD = CreateFrame("CheckButton", "MSA_CB_WASD", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cbWASD:SetPoint("TOPLEFT", optionsDesc, "BOTTOMLEFT", 0, -16)
_G["MSA_CB_WASDText"]:SetText("移动自动锁视角")
SetOptionTooltip(cbWASD, "开启后，按 W/A/S/D 开始移动时若未锁定视角则自动锁定；按 F12 或鼠标右键会重置，下次移动可再次锁定。")
cbWASD:SetScript("OnClick", function(self)
	wasdAutoLock = self:GetChecked() and true or false
	if MySteamlikeAssistantDB then MySteamlikeAssistantDB.wasdAutoLock = wasdAutoLock end
	Print("移动自动锁视角已" .. (wasdAutoLock and "开启" or "关闭"))
end)

local cbDebug = CreateFrame("CheckButton", "MSA_CB_Debug", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
cbDebug:SetPoint("TOPLEFT", cbWASD, "BOTTOMLEFT", 0, -4)
_G["MSA_CB_DebugText"]:SetText("调试日志")
SetOptionTooltip(cbDebug, "开启后，每次收到 F11/F12 或方向键触发时都会在聊天框打印一行，便于确认按键是否送达。")
cbDebug:SetScript("OnClick", function(self)
	debugEnabled = self:GetChecked() and true or false
	if MySteamlikeAssistantDB then MySteamlikeAssistantDB.debugEnabled = debugEnabled end
	Print("调试日志已" .. (debugEnabled and "开启" or "关闭"))
end)

-- 只读展示：两个按键当前的绑定状态。
-- 只显示“已生效/未生效”，不显示底层动作串（如 CLICK ...:LeftButton），
-- 避免文字过长顶出面板边框；同时加右锚点，万一超长也能在面板内换行。
local bindText = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
bindText:SetPoint("TOPLEFT", cbDebug, "BOTTOMLEFT", 0, -20)
bindText:SetPoint("RIGHT", optionsPanel, "RIGHT", -16, 0)
bindText:SetJustifyH("LEFT")

-- 面板显示时同步控件状态与绑定信息（可能在别处用 /msa 命令改过）。
optionsPanel:SetScript("OnShow", function()
	cbWASD:SetChecked(wasdAutoLock)
	cbDebug:SetChecked(debugEnabled)
	local s1 = BindingState(START_KEY)
	local s2 = BindingState(STOP_KEY)
	if s1 ~= "未生效" then
		s1 = "已生效"
	end
	if s2 ~= "未生效" then
		s2 = "已生效"
	end
	bindText:SetText(START_KEY .. " 绑定: " .. s1 .. "    " .. STOP_KEY .. " 绑定: " .. s2)
end)

InterfaceOptions_AddCategory(optionsPanel)

-- 输出本插件支持的全部斜杠命令。
local function ShowHelp()
	Print("可用命令：")
	Print("  /msa            查看当前状态")
	Print("  /msa start      手动开启鼠标视角（用于验证 API 是否可用）")
	Print("  /msa stop       手动关闭鼠标视角")
	Print("  /msa rebind     重新挂载并持久化绑定")
	Print("  /msa wasd       开/关「移动自动锁视角」（默认关闭）")
	Print("  /msa debug      开/关调试日志")
	Print("  /msa help       显示本帮助")
	Print("  /bridge         与 /msa 完全等价的别名")
	Print("提示：以上设置也可在 Esc → 界面 → 鼠标视角助手中调整")
end

------------------------------------------------------------------
-- 斜杠命令注册
------------------------------------------------------------------
--   /msa           查看状态
--   /msa start     手动开启鼠标视角（用于验证 API 是否可用）
--   /msa stop      手动关闭鼠标视角
--   /msa rebind    重新挂载并持久化绑定
--   /msa wasd      开/关「移动自动锁视角」（W/A/S/D 移动时自动开视角）
--   /msa debug     开/关调试日志（收到开始/停止键时在聊天框打印）
--   /msa help      显示命令帮助
-- /bridge 是等价的别名。
SLASH_MYSTEAMLIKEASSISTANT1 = "/msa"
SLASH_MYSTEAMLIKEASSISTANT2 = "/bridge"
SlashCmdList["MYSTEAMLIKEASSISTANT"] = function(msg)
	msg = string.lower(msg or "")
	if msg == "help" then
		ShowHelp()
	elseif msg == "start" then
		StartMouselook()
	elseif msg == "stop" then
		StopMouselook()
	elseif msg == "rebind" then
		ApplyBindings()
		Status()
	elseif msg == "wasd" then
		wasdAutoLock = not wasdAutoLock
		if MySteamlikeAssistantDB then MySteamlikeAssistantDB.wasdAutoLock = wasdAutoLock end
		Print("移动自动锁视角已" .. (wasdAutoLock and "开启" or "关闭"))
	elseif msg == "debug" then
		debugEnabled = not debugEnabled
		if MySteamlikeAssistantDB then MySteamlikeAssistantDB.debugEnabled = debugEnabled end
		Print("调试日志已" .. (debugEnabled and "开启" or "关闭"))
	else
		Status()
	end
end

------------------------------------------------------------------
-- 事件：加载存档 + 登录后挂钩
------------------------------------------------------------------
-- ADDON_LOADED 时把存档读入内存：首次运行或字段缺失时补默认值。
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "MySteamlikeAssistant" then
		local d = MySteamlikeAssistantDB
		if type(d) ~= "table" then
			d = {}
			MySteamlikeAssistantDB = d
		end
		if d.wasdAutoLock == nil then d.wasdAutoLock = false end
		if d.debugEnabled == nil then d.debugEnabled = false end
		wasdAutoLock = d.wasdAutoLock
		debugEnabled = d.debugEnabled
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		-- 此刻按键表已加载完成，挂载绑定时机最稳；随后做一次自检。
		ApplyBindings()
		if BindingState(START_KEY) == "未生效" then
			Print(START_KEY .. " 未生效，客户端可能不识别该按键。")
		end
		self:UnregisterEvent("PLAYER_LOGIN")
	end
end)
