# tutorialUI

## 说明

这一个文件夹下主要用于实现模块化的教程系统  
教程分为很多从屏幕右下角popup的卡片  
本教程教程模块内置状态机  
玩家在教程弹出后按照教程操作  
卡片对应操作结束以后教程继续进行，知道最后一个卡片完成结束  

## 实现逻辑

### 1) 入口与职责

- 入口场景：`tutorialUI/popup.tscn`  
- 主控制脚本：`tutorialUI/script/Tut.gd`（负责教程流程）  
- 通用状态机：`tutorialUI/script/StateMa.gd`（负责“状态 + 事件 -> 转换”）  
- 流程配置：`tutorialUI/tutorial_fsm.json`（定义状态图，不把流程硬编码在脚本里）

简单理解：  
`Tut.gd` 负责“做什么”，`StateMa.gd` 负责“什么时候切换到下一步”，`tutorial_fsm.json` 负责“步骤顺序”。

### 2) 教程流程（当前实现）

当前是两张卡片：

1. `show_ad`：播放 AD 卡片出现动画  
2. `wait_ad`：等待玩家按过 `move_left` + `move_right`  
3. `hide_ad`：播放 AD 卡片隐藏动画  
4. `show_space`：播放 Space 卡片出现动画  
5. `wait_space`：等待玩家按下 `jump`  
6. `hide_space`：播放 Space 卡片隐藏动画  
7. `end`：隐藏全部卡片，发出 `tutorial_finished`

状态机初始态是 `idle`，收到 `start_tutorial` 事件后进入流程。  
此外有全局事件 `skip`，可从任意状态直接跳到 `end`。

### 3) 事件如何驱动切换

- 动画播完：`AnimationPlayer.animation_finished` -> `Tut.gd` 发 `anim_done`
- 操作完成：在 `wait_*` 状态里检测输入完成 -> 发 `action_done`
- 状态机收到事件后，按 `tutorial_fsm.json` 查表跳转到下一状态

所以你可以把它理解成：  
**动画完成推进一次，玩家按键完成再推进一次，循环直到结束。**

### 4) 关键节点约束（避免出错）

`popup.tscn` 里这些节点名必须和脚本一致：

- `AnimationPlayer`
- `panel_AD`
- `panel_Space`

动画名也必须一致：

- `AD`
- `Hide`
- `Space`
- `Hide_Space`

如果重命名节点或动画，教程会卡在某一步不前进。

### 5) 如何扩展一个新教程步骤（推荐做法）

例如要加“Dash 教程”：

1. 在 `popup.tscn` 增加对应面板和出现/隐藏动画  
2. 在 `Tut.gd` 增加 `enter/update` 方法（检测 `dash` 输入）  
3. 在 `tutorial_fsm.json` 增加新状态和转换（接在 `hide_space` 后）  
4. 保持“show -> wait -> hide”这个固定节奏，便于维护和排查

这样做的好处是：流程改动主要在 JSON，逻辑改动局部在 `Tut.gd`，diff 小且不容易破坏已有步骤。
