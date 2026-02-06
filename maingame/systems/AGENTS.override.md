# systems

## 说明

`systems` 是游戏的开始界面、暂停界面、死亡后重开界面的管理模块。

## 场景与资源

`systems/syst.tscn`:

- 脚本：`systems/syst.gd`
- game：`systems/testworld.tscn`
- pause：`systems/paus.tscn`
- start：`systems/cover.tscn`
- restart：`systems/cover.tscn`（与 start 复用）

`systems/cover.tscn` / `systems/paus.tscn`:

- 根节点为 `Control`
- 按钮路径固定：
  - 开始：`Panel/Button`
  - 设置：`Panel/Button2`
  - 退出：`Panel/Button3`

`systems/testworld.tscn`:

- 包含 `Player` 节点与 `Timer`
- `Timer` 超时后触发 `Player.died`（见 `systems/testworld.gd`）

## 逻辑概览（syst.gd）

模块通过 `Mode` 状态控制界面与游戏切换：

- `START`：显示开始菜单
- `GAME`：游戏进行中
- `PAUSE`：暂停菜单
- `RESTART`：死亡后重开菜单

脚本初始化：

- `_ready` 中设置 `process_mode = ALWAYS` 并调用 `_show_start()`。
- `_show_start()` 会清理菜单、释放游戏实例并生成开始菜单。

## 按钮信号连接

`_spawn_menu()` 实例化菜单后调用 `_connect_menu_buttons()` 进行信号绑定：

- `Panel/Button` → `_on_menu_start_pressed`
- `Panel/Button2` → `_on_menu_setting_pressed`
- `Panel/Button3` → `_on_menu_exit_pressed`

连接使用 `pressed` 信号，并且在重复连接前进行 `is_connected` 检查，避免多次绑定。

## 跳转流程

开始/重开按钮（`_on_menu_start_pressed`）：

- `START` → `_start_game(false)` → 进入 `GAME`
- `PAUSE` → `_resume_game()` → 回到 `GAME`
- `RESTART` → `_start_game(true)` → 重开进入 `GAME`

暂停切换（键盘 Esc）：

- `GAME` → `_show_pause()` → 进入 `PAUSE` 并 `get_tree().paused = true`
- `PAUSE` → `_resume_game()` → 回到 `GAME` 并 `get_tree().paused = false`

玩家死亡信号：

- `_try_connect_game_signals()` 在游戏实例化后查找根下 `Player` 节点并连接 `died` 信号。
- `Player.died` 触发 `_on_player_died()` → `_show_restart()` → 进入 `RESTART`

## 现状注意点

- 游戏场景中必须存在根下的 `Player` 节点，否则 `died` 信号不会连接，死亡重开不会触发。
- `start` 与 `restart` 当前复用 `cover.tscn`，因此按钮与布局完全一致。
