# MySteamlikeAssistant（鼠标视角助手）

魔兽世界 **3.3.5a（WLK）** 插件。把由手柄映射软件 / 安卓模拟器注入的两个特殊按键 **F11 / F12**
转换为「鼠标视角」操作，效果**等同于按住鼠标右键拖动视角**；
并在使用 W/A/S/D 方向键移动时可选地自动锁定鼠标视角（默认关闭）。

- **按 F11**：若当前不在鼠标视角，则**开启**鼠标视角（`MouselookStart`）
- **按 F12**：**关闭**鼠标视角（`MouselookStop`）
- **按 W/A/S/D 移动**：若当前不在鼠标视角，则**自动开启**（可用开关控制，见下）

典型用途：安卓手柄 → 模拟器（如 Winlator）/ 键盘映射软件 → 注入 `F11` / `F12` → 本插件接收 → 控制游戏视角。

---

## 一、功能特性

| 功能 | 说明 |
| --- | --- |
| F11 开启视角 | 内部先用 `IsMouselooking()` 判断，已在视角中则不会重复开启 |
| F12 关闭视角 | 直接调用 `MouselookStop()` |
| 移动自动锁视角 | 用 W/A/S/D 方向键开始移动时，若不在视角中则自动开启；带独立开关（**默认关闭**） |
| 登录自动挂钩 | 在 `PLAYER_LOGIN` 时自动绑定并持久化，重载 / 重登后依然有效 |
| 状态自检 | 命令 `/msa` 可查看按键绑定是否生效、当前视角状态、各开关状态 |
| 不污染按键面板 | 采用「隐藏按钮 + `SetBindingClick`」，不会出现在游戏「按键设置」界面中 |

---

## 二、目录结构

```
MySteamlikeAssistant/
├── MySteamlikeAssistant.toc    # 插件描述文件（元信息 + 要加载的文件清单）
├── MySteamlikeAssistant.lua    # 插件全部逻辑（绑定、视角控制、斜杠命令）
└── README.md                   # 本文档
```

> 本插件**不需要** `Bindings.xml`。按键绑定在运行时由 `SetBindingClick` 完成。

---

## 三、安装

1. 把整个 `MySteamlikeAssistant` 文件夹放到：
   `...\World of Warcraft\Interface\AddOns\MySteamlikeAssistant\`
2. **完全退出客户端后重新启动**。
   - ⚠️ 重要：客户端**只在启动时扫描** `Interface\AddOns` 目录。
     如果你是在客户端运行期间才创建/添加的插件文件夹，`/reload` 或退回角色选择界面**都不会**让它出现，必须彻底关闭进程再重开。
3. 在**角色选择界面**点击「插件 / AddOns」按钮，确认 **MySteamlikeAssistant** 在列表中且已勾选启用。
   - 若显示为「不兼容 / 过期」，勾选右上角「加载过期插件」。
4. 进入游戏，输入 `/msa`。若能看到 `[MSA] F11 绑定: ...` 即安装成功。

---

## 四、使用方法

正常游玩时无需任何操作，直接使用手柄映射出来的按键即可：

| 操作 | 行为 |
| --- | --- |
| 按 `F11` | 开启鼠标视角（移动鼠标转动视角） |
| 按 `F12` | 关闭鼠标视角 |
| 按 `W/A/S/D` 移动 | 自动开启鼠标视角（前提：该功能开关为「开启」） |

建议把「按下视角键 → 发送 `F11`」「松开视角键 → 发送 `F12`」映射到同一个手柄按键上，
即可获得「按住看视角、松开停止」的手感。

「移动自动锁视角」用于让相机在移动时自动跟随（**默认关闭**，需 `/msa wasd` 开启）。
它**只负责开、不负责关**：移动开始时会自动进入鼠标视角，需要退出时按 `F12`（或用手柄映射停止键）。

---

## 五、斜杠命令

| 命令 | 作用 |
| --- | --- |
| `/msa` | 查看状态：两个按键的绑定情况 + 当前是否处于鼠标视角 + 各开关状态 |
| `/msa start` | 手动开启鼠标视角（用于验证 API 是否可用） |
| `/msa stop` | 手动关闭鼠标视角 |
| `/msa rebind` | 重新挂载绑定并持久化（绑定被重置后可用它恢复） |
| `/msa wasd` | 开 / 关「移动自动锁视角」（默认**关闭**） |
| `/msa help` | 显示全部可用命令（帮助） |
| `/msa debug` | 开 / 关调试日志：打开后每次收到 F11/F12 或触发自动锁视角都会在聊天框打印一行 |
| `/bridge` | 与 `/msa` 完全等价的别名 |

`/msa` 的典型输出：

```
[MSA] F11 绑定: CLICK MSA_Btn_F20:LeftButton
[MSA] F12 绑定: CLICK MSA_Btn_F21:LeftButton
[MSA] 当前鼠标视角: 关闭
[MSA] 移动自动锁视角: 关闭
[MSA] 调试日志: 关闭
[MSA] 输入 /msa help 查看全部命令
```

- 出现 `CLICK MSA_Btn_F20:LeftButton` 表示**绑定已生效**（客户端认识 F11）。
  `MSA_Btn_F20` 只是内部按钮名，与具体按键无关。
- 出现 `未生效` 表示该按键未被客户端接受，需要换键（见「七、自定义」）。

### 查看日志

按键本身不会常驻打印日志（否则正常游玩会刷屏）。需要排查时：

1. 输入 `/msa debug` 打开调试日志。
2. 按下 F11 / F12（或按 W/A/S/D 移动），聊天框会各打印一行，例如：

   ```
   [MSA] 收到按键 F11（鼠标视角: 开启）
   [MSA] 收到按键 F12（鼠标视角: 关闭）
   [MSA] 方向键移动触发自动锁视角（MoveForwardStart）
   ```

3. 排查完再输入一次 `/msa debug` 关闭。

日志输出去向：**游戏聊天框**（默认在「综合」标签页，可用鼠标滚轮上翻查看）。
若按了键却没有任何输出，说明按键没有送达客户端（问题在手柄 / 模拟器映射一侧）。

---

## 六、工作原理

### 1. F11 / F12 的控制链路

1. **键位从哪来**：手柄软件 / 模拟器把某个手柄按键「翻译」成键盘上的 `F11`、`F12`，
   再由 Windows 送到游戏客户端。
2. **插件如何接到按键**：WoW 里能可靠接收“任意按键”的机制是**按键绑定**。
   插件用 `SetBindingClick("F11", "MSA_Btn_F20")` 把 F11 绑定为「点击名为 `MSA_Btn_F20` 的按钮」。
3. **按键触发流程**：
   ```
   按下 F11  →  客户端执行“点击 MSA_Btn_F20”  →  触发按钮 OnClick
             →  StartMouselook()  →  if not IsMouselooking() then MouselookStart() end
   ```
   F12 同理，`OnClick` 里直接调用 `MouselookStop()`。
4. **为什么用隐藏按钮**：`SetBindingClick` 走的是“点击按钮”这条路径，不需要 `Bindings.xml`，
   也不会在「按键设置」界面里留下条目，干净且不冲突。
5. **为什么要在 `PLAYER_LOGIN` 挂钩**：此时按键表已加载完成，`SetBindingClick` + `SaveBindings`
   才能正确落盘，保证下次登录依然有效。

### 2. 「移动自动锁视角」的实现

参考 ConsolePort 的做法：**不重绑 W/A/S/D**（那会破坏移动功能），
而是用 `hooksecurefunc` 给游戏的“开始移动”函数挂一个**后置钩子**。
玩家按方向键时，客户端会调用这些函数，钩子在原函数执行完之后再触发，
于是我们能在**不改变移动行为**的前提下顺带打开鼠标视角：

| 被挂钩的函数 | 对应按键（WoW 默认键位） |
| --- | --- |
| `MoveForwardStart` | W（前进） |
| `MoveBackwardStart` | S（后退） |
| `TurnLeftStart` | A（左转） |
| `TurnRightStart` | D（右转） |
| `StrafeLeftStart` | Q（左平移） |
| `StrafeRightStart` | E（右平移） |

> 注意：WoW 默认键位里 **A/D 是“转向”（Turn），Q/E 才是“平移”（Strafe）**。
> 因此 A/D 对应的是 `TurnLeftStart` / `TurnRightStart`，必须一并挂钩，否则按 A/D 不会触发。
> 若你把 A/D 改绑成了平移，对应的仍是 Strafe 系列，所以这里两组都挂钩，做到全覆盖。

钩子内部逻辑：`if wasdAutoLock and not IsMouselooking() then MouselookStart() end`。
`wasdAutoLock` 即 `/msa wasd` 控制的开关（默认关闭）。

> `hooksecurefunc` 保证钩子一定在原函数**之后**执行，且**不覆盖**原函数，
> 所以对移动本身没有任何副作用。

### 用到的游戏 API

| API | 说明 |
| --- | --- |
| `IsMouselooking()` | 返回当前是否处于鼠标视角 |
| `MouselookStart()` | 开启鼠标视角 |
| `MouselookStop()` | 关闭鼠标视角 |
| `SetBindingClick(key, buttonName)` | 把某个键绑定为“点击某个按钮” |
| `GetBindingAction(key)` | 查询某个键当前绑定的动作 |
| `SaveBindings(set)` | 把按键绑定写入磁盘持久化 |
| `GetCurrentBindingSet()` | 返回当前生效的按键方案编号 |
| `hooksecurefunc(name, fn)` | 给全局函数挂后置钩子（不覆盖原函数） |

---

## 七、自定义

### 更换接收的按键

编辑 `MySteamlikeAssistant.lua` 顶部两行即可：

```lua
local START_KEY = "F11"   -- 改成你需要的键
local STOP_KEY  = "F12"   -- 改成你需要的键
```

改完后 `/reload` 或重新登录生效。可用 `/msa` 确认是否变为 `CLICK ...`。

> 注意：绑定会持久化写盘，**改常量不会自动解绑旧键**。
> 若旧键（如 F20/F21）仍会触发，可在游戏「按键设置」里手动清除，或忽略它。

### 移动自动锁视角

- 默认**关闭**，用 `/msa wasd` 切换。
- 该开关为**本次运行内的临时状态**，`/reload` 后会恢复默认（关闭）。
- 若想改默认值，编辑 `MySteamlikeAssistant.lua` 中的 `local wasdAutoLock = false`（改成 `true` 即默认开启）。

### 其它说明

- 绑定名称（`MSA_Btn_F20` / `MSA_Btn_F21`）是全局唯一的按钮名，一般无需改动。
- 若某次在游戏的「按键设置」里点了「恢复默认」，本插件的绑定会被清除；
  重新登录或执行 `/msa rebind` 即可恢复。

---

## 八、常见问题（FAQ）

**Q1：游戏里输入 `/msa` 没反应，提示没有该命令？**
说明插件根本没被加载。依次检查：
1. 是否在**客户端运行期间**才放入插件文件夹 —— 必须**完全重启客户端**（`/reload` 无效）。
2. 角色选择界面的「插件」列表中是否勾选了 MySteamlikeAssistant。
3. 文件夹名与 `.toc` 文件名是否完全一致（都必须是 `MySteamlikeAssistant`）。

**Q2：`/msa` 里 `F11 绑定:` 显示 `未生效`？**
说明该客户端不识别 F11 这个键。按「七、自定义」换成客户端支持的键即可。

**Q3：`/msa start` / `/msa stop` 有效，但按 F11 / F12 没反应？**
说明按键没有送达客户端，问题在**手柄映射 / 模拟器一侧**，不是插件。
可用普通键先验证映射链路是否正常。

**Q4：视角能开但不能关？**
确认松开手柄按键时确实发送的是 `F12`；必要时用 `/msa` 观察状态是否在两次按键间切换。

**Q5：重载界面后绑定失效了？**
插件在 `PLAYER_LOGIN` 会自动重挂，正常情况下不会失效。若被「恢复默认」清掉，执行 `/msa rebind`。

**Q6：想让移动时自动锁视角？**
默认是**关闭**的，输入 `/msa wasd` 开启。注意此开关 `/reload` 后会恢复默认（关闭），
如需长期默认开启，见「七、自定义」。

**Q7：怕「移动自动锁视角」破坏移动？**
不会。它只是给移动函数挂了后置钩子，**不改动** W/A/S/D 的移动绑定与行为。

---

## 九、验证结论

- **界面版本**：`## Interface: 30300`（对应 3.3.5a）。
- **F11 / F12 可绑定**：目标 3.3.5a 客户端**支持**扩展功能键，`/msa` 实测返回
  `CLICK MSA_Btn_F20:LeftButton` / `CLICK MSA_Btn_F21:LeftButton`。
- **视角 API 可用**：`/msa start`、`/msa stop` 实测可正常开关鼠标视角。
- **移动钩子可用**：`MoveForwardStart` 等函数可被 `hooksecurefunc` 挂钩（ConsolePort 亦采用同一做法）。

---

## 十、版本

- 版本：1.0.0
- 适用客户端：World of Warcraft 3.3.5a（WLK）
