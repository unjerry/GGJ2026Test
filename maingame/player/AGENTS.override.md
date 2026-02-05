# player 模块现状（当前代码）

这份说明只基于 `player/` 目录现有内容，并补充它依赖的 `classes/StateMachin.gd`。

## 文件结构速览

- `player/player.tscn`：玩家场景，挂载 `player.gd`。
- `player/player.gd`：玩家移动与状态逻辑（核心）。
- `player/player.tres`：`AnimatedSprite2D` 用的帧资源（Cut/default）。
- `player/Dot.png`、`player/ring.png`、`player/Cut.png`：玩家贴图资源。
- `player/JumpRequestTimer`、`player/DashTimer`：场景中的计时器节点（分别用于跳跃输入缓冲、冲刺时长）。
- `player/StateMachine`：场景里挂的是 `classes/StateMachin.gd`（通用状态机）。

## 玩家当前实现（`player.gd`）

### 状态枚举

- `IDLE`
- `RUNNING`
- `JUMP`
- `DASH`
- `HURT`

### 每帧物理行为

- `IDLE/RUNNING/JUMP` 使用 `move(delta)`：
  - 读取 `move_left/move_right`，计算水平速度。
  - 按是否在地面使用不同加速度。
  - 施加重力并 `move_and_slide()`。
- `DASH` 使用 `dash_move()`：按冲刺方向给定固定速度。
- `HURT` 使用 `hurt_move(delta)`：水平速度快速衰减 + 重力下落。

### 跳跃逻辑

- `_unhandled_input` 中，只有空心形态（`solid = false`）会处理 `jump` 输入并启动 `JumpRequestTimer`（0.1 秒输入缓冲）。
- `get_next_state` 中，若“空心 + 在地面 + 缓冲未过期”则切到 `JUMP`。
- `transition_state` 进入 `JUMP` 时会设置 `velocity.y = JUMP_VELOCITY`，并停止缓冲计时器。
- 松开 `jump` 时有短跳处理（削减向上速度）。

### 冲刺（Dash）逻辑

- 输入 `dash` 会请求进入 `DASH` 状态。
- 进入 `DASH` 会清掉跳跃缓冲并启动 `DashTimer`（0.18 秒）。
- 实心形态：只做水平冲刺（由左右输入或当前速度决定方向）。
- 空心形态：按“玩家位置 -> 鼠标位置”方向冲刺（无目标时退化为水平方向）。
- `DashTimer` 未结束前保持 `DASH`；结束后回到 `IDLE/RUNNING/JUMP`。

### 受击（Hurt）逻辑

- `hurt` 不再绑定玩家输入；改为通过 `player.hurt()` 接口触发（为未来敌人命中调用预留）。
- `HURT` 状态有 0.4 秒硬直（与 Cut 动画同长），期间执行 `hurt_move`。
- 第一次受击（实心）：
  - `solid: true -> false`（切为空心）。
  - `Dot` 贴图切到 `ring.png`。
  - 显示 `Cut` 并播放 `AnimationPlayer` 的 `Cut` 动画。
- 第二次受击（已空心）：
  - 标记死亡并 `queue_free()`。

### 攻击（Attack）逻辑

- 右键触发 `attack`（若 InputMap 未配置，会在 `player.gd` 运行时自动补上右键绑定）。
- 攻击会显示 `Cut` 并播放 `Cut` 动画，作为当前版本的攻击表现。
- 攻击不会触发 `HURT`，玩家不会因为右键而自伤。

## 状态机是如何工作的（`classes/StateMachin.gd`）

这是一个“通用状态机壳”，要求宿主节点（这里是 Player）实现 3 个方法：

- `get_next_state(current_state)`：给出下一个状态。
- `transition_state(from, to)`：进入新状态时执行一次。
- `tick_physics(state, delta)`：当前状态每帧执行。

运行流程：

1. `_ready` 后等待宿主节点就绪，然后把 `current_state` 设为 `0`（即 `IDLE`）。
2. 每次 `_physics_process(delta)`：
   - 循环调用 `get_next_state`，直到状态稳定不再变化。
   - 每次状态变化都会触发 `transition_state`（通过 `current_state` 的 setter）。
   - 最后调用一次 `tick_physics(current_state, delta)`。

## 现在可理解成的“实际玩家体验”

- 开局实心：可左右移动、水平冲刺、不能跳跃。
- 首次受击后切为空心：可跳跃（含输入缓冲/短跳）并可鼠标指向冲刺。
- 右键是攻击表现（播放 Cut 动画），不再当作自伤输入。
- 空心再次受击会死亡（当前实现为移除玩家节点）。
