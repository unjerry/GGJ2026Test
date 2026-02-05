# player 模块现状（当前代码）

这份说明只基于 `player/` 目录现有内容，并补充它依赖的 `classes/StateMachin.gd`。

## 文件结构速览

- `player/player.tscn`：玩家场景，挂载 `player.gd`。
- `player/player.gd`：玩家移动与状态逻辑（核心）。
- `player/player.tres`：`AnimatedSprite2D` 用的帧资源（Cut/default）。
- `player/Dot.png`、`player/ring.png`、`player/Cut.png`：玩家贴图资源。
- `player/JumpRequestTimer`、`player/DashTimer`：场景中的计时器节点（目前只实际使用了 JumpRequestTimer）。
- `player/StateMachine`：场景里挂的是 `classes/StateMachin.gd`（通用状态机）。

## 玩家当前实现（`player.gd`）

### 状态枚举

- `IDLE`
- `RUNNING`
- `JUMP`
- `DASH`

### 每帧物理行为

- 4 个状态最终都调用同一个 `move(delta)`。
- `move(delta)` 会做三件事：
  - 读取 `move_left/move_right`，计算水平速度。
  - 按是否在地面使用不同加速度。
  - 施加重力并 `move_and_slide()`。

### 跳跃逻辑

- `_unhandled_input` 中按下 `jump` 会启动 `JumpRequestTimer`（0.1 秒输入缓冲）。
- `get_next_state` 中，若“在地面且缓冲未过期”则切到 `JUMP`。
- `transition_state` 进入 `JUMP` 时会设置 `velocity.y = JUMP_VELOCITY`，并停止缓冲计时器。
- 松开 `jump` 时有短跳处理（削减向上速度）。

### 当前代码里“已声明但未完成”的点

- `DASH` 状态已建，但无独立逻辑（和其他状态表现相同）。
- `DashTimer` 节点存在，但 `player.gd` 未使用。
- `solid` 变量目前只用于“是否处理跳跃输入”的门控，未看到受击切形态流程。
- `Dot/Cut/AnimatedSprite2D/AnimationPlayer` 在 `player.gd` 中暂无显式驱动逻辑。

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

- 目前核心是：左右移动 + 跳跃（有输入缓冲和短跳）。
- 状态机已经接好，但更像“基础骨架”；`DASH`、形态切换、受击切换动画还没在 `player.gd` 里落地完整行为。
