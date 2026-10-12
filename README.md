# MySteamlikeAssistant（鼠标视角助手）

魔兽世界 **3.3.5a（WLK）** 插件。把由手柄映射软件 / 安卓模拟器注入的两个特殊按键 **F20 / F21**
转换为「鼠标视角」操作，效果**等同于按住鼠标右键拖动视角**。

- **按 F20**：若当前不在鼠标视角，则**开启**鼠标视角（`MouselookStart`）
- **按 F21**：**关闭**鼠标视角（`MouselookStop`）

典型用途：安卓手柄 → 模拟器（如 Winlator）/ 键盘映射软件 → 注入 `F20` / `F21` → 本插件接收 → 控制游戏视角。

---

## 一、功能特性

| 功能 | 说明 |
| --- | --- |
| F20 开启视角 | 内部先用 `IsMouselooking()` 判断，已在视角中则不会重复开启 |
| F21 关闭视角 | 直接调用 `MouselookStop()` |
| 登录自动挂钩 | 在 `PLAYER_LOGIN` 时自动绑定并持久化，重载 / 重登后依然有效 |
| 状态自检 | 命令 `/msa` 可查看按键绑定是否生效、当前视角状态 |
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
4. 进入游戏，输入 `/msa`。若能看到 `[MSA] F20 绑定: ...` 即安装成功。

---

## 四、使用方法

正常游玩时无需任何操作，直接使用手柄映射出来的按键即可：

| 按键 | 行为 |
| --- | --- |
| `F20` | 开启鼠标视角（移动鼠标转动视角） |
| `F21` | 关闭鼠标视角 |

建议把「按下视角键 → 发送 `F20`」「松开视角键 → 发送 `F21`」映射到同一个手柄按键上，
即可获得「按住看视角、松开停止」的手感。

---

## 五、斜杠命令

| 命令 | 作用 |
| --- | --- |
| `/msa` | 查看状态：两个按键的绑定情况 + 当前是否处于鼠标视角 |
| `/msa start` | 手动开启鼠标视角（用于验证 API 是否可用） |
| `/msa stop` | 手动关闭鼠标视角 |
| `/msa rebind` | 重新挂载绑定并持久化（绑定被重置后可用它恢复） |
| `/bridge` | 与 `/msa` 完全等价的别名 |

`/msa` 的典型输出：

```
[MSA] F20 绑定: CLICK MSA_Btn_F20:LeftButton
[MSA] F21 绑定: CLICK MSA_Btn_F21:LeftButton
[MSA] 当前鼠标视角: 关闭
```

- 出现 `CLICK MSA_Btn_F20:LeftButton` 表示**绑定已生效**（客户端认识 F20）。
- 出现 `未生效` 表示该按键未被客户端接受，需要换键（见「七、自定义」）。

---

## 六、工作原理

1. **键位从哪来**：手柄软件 / 模拟器把某个手柄按键「翻译」成键盘上的 `F20`、`F21`，
   再由 Windows 送到游戏客户端。
2. **插件如何接到按键**：WoW 里能可靠接收“任意按键”的机制是**按键绑定**。
   插件用 `SetBindingClick("F20", "MSA_Btn_F20")` 把 F20 绑定为「点击名为 `MSA_Btn_F20` 的按钮」。
3. **按键触发流程**：
   ```
   按下 F20  →  客户端执行“点击 MSA_Btn_F20”  →  触发按钮 OnClick
             →  StartMouselook()  →  if not IsMouselooking() then MouselookStart() end
   ```
   F21 同理，`OnClick` 里直接调用 `MouselookStop()`。
4. **为什么用隐藏按钮**：`SetBindingClick` 走的是“点击按钮”这条路径，不需要 `Bindings.xml`，
   也不会在「按键设置」界面里留下条目，干净且不冲突。
5. **为什么要在 `PLAYER_LOGIN` 挂钩**：此时按键表已加载完成，`SetBindingClick` + `SaveBindings`
   才能正确落盘，保证下次登录依然有效。

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

---

## 七、自定义

### 更换接收的按键

编辑 `MySteamlikeAssistant.lua` 顶部两行即可：

```lua
local START_KEY = "F20"   -- 改成你需要的键，例如 "F8"
local STOP_KEY  = "F21"   -- 改成你需要的键，例如 "F9"
```

改完后 `/reload` 或重新登录生效。可用 `/msa` 确认是否变为 `CLICK ...`。

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

**Q2：`/msa` 里 `F20 绑定:` 显示 `未生效`？**
说明该客户端不识别 F20 这个键。按「七、自定义」换成客户端支持的键即可。
（注：本项目在目标 3.3.5a 客户端上实测 F20 / F21 **可被识别**，显示为 `CLICK MSA_Btn_F20:LeftButton`。）

**Q3：`/msa start` / `/msa stop` 有效，但按 F20 / F21 没反应？**
说明按键没有送达客户端，问题在**手柄映射 / 模拟器一侧**，不是插件。
可用 `F20` 之外的普通键（如 `F8`）先验证映射链路是否正常。

**Q4：视角能开但不能关？**
确认松开手柄按键时确实发送的是 `F21`；必要时用 `/msa` 观察状态是否在两次按键间切换。

**Q5：重载界面后绑定失效了？**
插件在 `PLAYER_LOGIN` 会自动重挂，正常情况下不会失效。若被「恢复默认」清掉，执行 `/msa rebind`。

---

## 九、已验证的关键结论

- **界面版本**：`## Interface: 30300`（对应 3.3.5a）。
- **F20 / F21 可绑定**：目标 3.3.5a 客户端**支持** F13–F24 类扩展功能键，
  `/msa` 实测返回 `CLICK MSA_Btn_F20:LeftButton` / `CLICK MSA_Btn_F21:LeftButton`。
- **视角 API 可用**：`/msa start`、`/msa stop` 实测可正常开关鼠标视角。

---

## 十、版本

- 版本：1.0.0
- 适用客户端：World of Warcraft 3.3.5a（WLK）
