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
-- 业务逻辑
------------------------------------------------------------------

-- 本地状态标记：我们认为当前是否处于鼠标视角。
-- 目的：避免在“每帧都可能被调用”的移动函数钩子里反复调用 IsMouselooking()（C API 调用较贵）。
-- 规则：
--   * 只在该标记为“未锁定”时才去判断一次并锁定，随后把标记置为 true；
--   * 标记为 true 后，钩子热路径只做一次布尔判断，不再调用任何 API；
--   * 另用低频轮询侦测视角是否被解除（例如长按右键松开），解除后还原标记，
--     以便下次移动时能再次自动锁定。
local mouselookActive = false

-- 低频轮询：只在“标记为已锁定”期间运行，每 POLL_INTERVAL 秒用一次 IsMouselooking() 侦测解除。
-- 用累计 elapsed 代替 GetTime()，避免每帧额外的 C 调用。
local POLL_INTERVAL = 0.3
local pollElapsed = 0
local poller = CreateFrame("Frame")

local function PollMouselook(self, elapsed)
	pollElapsed = pollElapsed + elapsed
	if pollElapsed < POLL_INTERVAL then
		return
	end
	pollElapsed = 0
	if not IsMouselooking() then
		-- 视角已被解除：还原标记并停止轮询，恢复零开销。
		mouselookActive = false
		self:SetScript("OnUpdate", nil)
	end
end

-- 记录为“已锁定”，并启动低频轮询以侦测解除。
local function MarkMouselookActive()
	mouselookActive = true
	pollElapsed = 0
	poller:SetScript("OnUpdate", PollMouselook)
end

-- 记录为“未锁定”，并停止轮询。
local function ClearMouselookActive()
	mouselookActive = false
	poller:SetScript("OnUpdate", nil)
end

-- 开启鼠标视角。
-- 先判断 IsMouselooking()，避免在已经处于鼠标视角时重复调用 MouselookStart。
local function StartMouselook()
	if not IsMouselooking() then
		MouselookStart()
	end
	MarkMouselookActive()
end

-- 关闭鼠标视角。
local function StopMouselook()
	MouselookStop()
	ClearMouselookActive()
end

------------------------------------------------------------------
-- 隐藏按钮：仅用于接收按键“点击”，不参与任何界面显示
------------------------------------------------------------------

-- CreateFrame 创建的框架默认就是隐藏的，无需 Show()。
-- OnClick 就是按键触发时真正执行的入口。
-- 这里在动作执行后顺便打一条调试日志（含当前视角状态），方便排查按键是否送达。
local btnStart = CreateFrame("Button", BTN_START)
btnStart:SetScript("OnClick", function()
	StartMouselook()
	Debug("收到按键 " .. START_KEY .. "（鼠标视角: " .. (IsMouselooking() and "开启" or "关闭") .. "）")
end)

local btnStop = CreateFrame("Button", BTN_STOP)
btnStop:SetScript("OnClick", function()
	StopMouselook()
	Debug("收到按键 " .. STOP_KEY .. "（鼠标视角: " .. (IsMouselooking() and "开启" or "关闭") .. "）")
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

-- 是否已经安装过移动钩子。WoW 的 hooksecurefunc **没有注销（unhook）接口**，
-- 钩子只能安装、无法真正移除。因此这里采用「懒安装」：
-- 只在该功能被打开时才安装钩子；关闭状态下不会安装。
-- 默认关闭 → 每次 /reload 后只要没开过该功能，就根本不会安装任何钩子。
-- （若“开过又关掉”，钩子仍会保留，但会在入口处快速短路，几乎零开销。）
local moveHooksInstalled = false

-- 给每个“开始移动”函数挂后置钩子。仅在需要时调用一次，重复调用直接返回。
-- ⚠️ 性能要点：TurnLeftStart / TurnRightStart 在转视角时会被客户端**每帧调用**，
--    因此这个钩子必须保持极低开销，否则移动 + 转视角时会因每帧的额外工作而卡顿。
--    所以：
--      1) 热路径只做一次布尔判断——开关关闭、或本地标记已是“已锁定”时立即 return，
--         **不调用任何 API**（含 IsMouselooking）；
--      2) 只有“开关开、且标记为未锁定”时才去判断并锁定一次；
--      3) 调试字符串仅在调试开关打开时才拼接（避免无谓地分配内存、加重 GC）。
--    视角被解除的侦测交给低频轮询 PollMouselook，见“业务逻辑”一节。
local function InstallMoveHooks()
	if moveHooksInstalled then
		return
	end
	moveHooksInstalled = true

	for _, funcName in ipairs(MOVE_FUNCS) do
		hooksecurefunc(funcName, function()
			-- 热路径：开关关闭、或本地标记已是“已锁定”时，只做一次布尔判断就返回。
			-- 这是性能关键：转视角时本函数会被每帧调用。
			if not wasdAutoLock or mouselookActive then
				return
			end

			-- 走到这里：开关开、且本地标记为“未锁定”。
			-- 先做一次真实判断，兼容“用其它方式（如长按右键）已进入视角”的情况。
			if IsMouselooking() then
				MarkMouselookActive()
				return
			end

			-- 未锁定 → 锁定一次，并记录标记。
			MouselookStart()
			MarkMouselookActive()
			if debugEnabled then
				Debug("方向键移动触发自动锁视角（" .. funcName .. "）")
			end
		end)
	end
end

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
	Print("本地视角标记: " .. (mouselookActive and "已锁定" or "未锁定"))
	Print("移动自动锁视角: " .. (wasdAutoLock and "开启" or "关闭"))
	Print("调试日志: " .. (debugEnabled and "开启" or "关闭"))
	Print("输入 /msa help 查看全部命令")
end

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
		-- 打开时才安装移动钩子（hooksecurefunc 无法注销，所以采用懒安装）。
		if wasdAutoLock then
			InstallMoveHooks()
		end
		Print("移动自动锁视角已" .. (wasdAutoLock and "开启" or "关闭"))
	elseif msg == "debug" then
		debugEnabled = not debugEnabled
		Print("调试日志已" .. (debugEnabled and "开启" or "关闭"))
	else
		Status()
	end
end

------------------------------------------------------------------
-- 事件：登录后自动挂钩
------------------------------------------------------------------
-- 在 PLAYER_LOGIN 时挂载绑定，确保此刻按键表已加载完成，时机最稳。
-- 挂载后顺手做一次自检；若开始键仍未生效则给出提示。
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
	ApplyBindings()
	-- 仅当默认值就是开启（有人把 wasdAutoLock 常量改成了 true）时才安装移动钩子；
	-- 默认关闭 → 什么都不做，保证“没开过就不挂钩”。
	if wasdAutoLock then
		InstallMoveHooks()
	end
	if BindingState(START_KEY) == "未生效" then
		Print(START_KEY .. " 未生效，客户端可能不识别该按键。")
	end
	self:UnregisterEvent("PLAYER_LOGIN")
end)
