# M08 云间跃行　A/B　依赖 G01、G03

来源：2026-11-07 架构审查及其最后实施记录。整理日期：2026-11-14。下列待办保留原状态；实施前核对本包源码与工作区，不以历史检查代替本次验收。

[共享 G01–G03 任务](../../../protocols/godot_party_default_protocol/doc/godot_party_default_protocol_development.md) · [包说明](gp_platformer_guide.md)


包：`gp_platformer`。定位：[game.gd](../game.gd)、`scripts/world11.gd`、`scripts/world11_player.gd`、`scripts/sound.gd`。

- [ ] 移除水果分支和 IS_PLATFORM 开关，使用明确的 world/player 依赖；处理进度/排名发送返回值并清理连接。
- [ ] 普通声音接作用域组件。保留当前课程场景、出生点和运行时敌人/拾取状态，不重新生成固定地图。
- [ ] 对固定敌人类型的 `has_method("defeat")` 改为明确契约；碰撞得到的可交互对象是实际动态边界，`bump` 判断要按砖块类型/组件契约处理，不能机械删除所有检查。
- [ ] 游戏规则数据、资源外观、HUD 与输入职责沿用现有分离，仅整理不准确的通用 shapes/sound 命名和跨场景长路径。

验证：死亡重载、地下金币、顶砖与敌人、菜单/失焦输入、双端成绩、连玩两轮。

## 人工验收待办

保留自 2026-11-05 场景审查，后续记录未明确关闭的人工事项：全程跳跃手感待人工验收。
