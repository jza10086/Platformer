# 美术资产来源与改动记录

本次环境与道具美术更新采用 **Kenney Platformer Kit 4.1** 的统一低模风格。玩家 Cube、敌人、地图坐标、碰撞体、相机和游戏规则保持原有实现。工程已包含运行需要的模型和纹理，无需联网下载。

## 1. Kenney Platformer Kit

- 作者 / 发布者：**Kenney**（https://kenney.nl）
- 官方资产页：https://kenney.nl/assets/platformer-kit
- 本次版本：**4.1**，包内许可证标记的创建时间为 `02-04-2026 11:29`。
- 下载日期：**2026-10-14（UTC）**。
- 官方下载地址：https://kenney.nl/media/pages/assets/platformer-kit/1585cf62b4-1775122253/kenney_platformer-kit.zip
- 许可证：**Creative Commons Zero 1.0 Universal（CC0 1.0）**。
- 许可证说明：https://creativecommons.org/publicdomain/zero/1.0/
- 原包 `License.txt` 原样保留于 [`assets/kenney/platformer-kit/License.txt`](assets/kenney/platformer-kit/License.txt)。CC0 允许个人、教育及商业使用；这里自愿注明作者。
- 官方 ZIP：4,640,135 bytes；SHA-256：`899605d237367688c6b42e41fff2206c0fb8d626163158294556353f7baa7c1b`。
- 工程只包含实际需要的模型、派生来源和纹理，没有带入整包的角色模型、FBX、OBJ、HTML、URL 快捷方式或压缩包。

### 选用文件与用途

模型均位于 `assets/kenney/platformer-kit/Models/`。原始 GLB 与原始纹理未改写；每个文件的 SHA-256、上游路径、用途及来源范围见 [`assets/kenney/platformer-kit/manifest.json`](assets/kenney/platformer-kit/manifest.json)。

| 原文件 | 工程中的用途 | 视觉适配 |
| --- | --- | --- |
| `block-grass.glb` | 地上地面第一排草地块 | 按完整模型 AABB（含草沿）归一到一格，缩为 0.982×0.982×0.982；不越过坑边界 |
| `brick.glb` | 地面下排、悬空砖、阶梯、城堡墙、地下砖 | 同一格尺寸；地上砖的蓝灰砂浆改为深土色以免误看成天空漏缝，砖面保留原色；地下采用蓝灰色运行时调色 |
| `crate-item.glb` | 未使用问号块、已用尽奖励块 | 归一到同一格；未使用时叠加原创 `?` 标识；使用后切换低饱和暗色 |
| `pipe.glb` | 地上六根水管与地下横向出口 | 蓝紫色调改为绿色；仅伸长管体，口沿世界高度固定约 0.5714；地下出口整体旋转 90° |
| `coin-gold.glb` | 顶砖弹出金币、地下房可收集金币 | 保留正面朝向 +Z；按原拾取视觉尺寸适配 |
| `star.glb` | 无敌星星奖励 | 适配 0.72×0.72×0.30 视觉边界，保留原有旋转及物理行为 |
| `mushrooms.glb` | 单朵奖励蘑菇的原始来源 | 保留原文件；从簇模型提取最高一朵的帽与柄，见派生文件说明 |
| `tree.glb`、`tree-pine-small.glb` | 远景阔叶树和松树 | 保持直立；降低饱和度、提高背景色混合，放在玩家平面后方，底部按相机投影落到前景地面高度 |
| `hedge.glb` | 背景矮篱 | 横向适配，使用原始纹理 |
| `flowers.glb`、`rocks.glb` | 背景花与石块 | 只作装饰，不增加碰撞体 |
| `door-open.glb` | 终点城堡拱门 | 配合同包砖模型组装，保留原有城堡位置与通关路线 |
| `flag.glb` | 可降下旗面的原始来源 | 保留原文件；提取旗布，沿用原有旗杆与降旗流程 |
| `Textures/colormap.png` | 所有上述模型共享的颜色图集 | 512×512 原图；砖缝、管道、地下、用尽块、生命蘑菇及远景使用独立运行时调色副本 |

### 派生文件与可复现处理

- `Models/mushroom-single.glb`：仅提取 `mushrooms.glb` 中最高一朵蘑菇的两个连通几何部分（帽与柄），未重新绘制；出生、移动、拾取、成长与加命逻辑保持原样。普通奖励使用原红色，加命奖励仅将帽的暖色调改为绿色。
- `Models/flag-cloth.glb`：仅提取 `flag.glb` 中旗布的连通几何部分，使降旗时旗杆不跟随移动。
- 生成工具：[`tools/derive_platformer_assets.py`](tools/derive_platformer_assets.py)。在仓库根目录执行 `python3 tools/derive_platformer_assets.py` 可从保留的源 GLB 字节级重建这两个派生文件。工具只读取模型数据，不执行下载包内代码。
- 运行时适配器：[`scripts/world11_assets.gd`](scripts/world11_assets.gd)。从源 mesh 的实际 AABB 居中、归一，再设置明确视觉尺寸；保留 UV 和原图集。适配器仅创建 MeshInstance3D，不创建或修改任何碰撞体。
- 已用方块在原位置更新 mesh/material；隐藏方块仍按原条件显示；撞碎、顶起、金币弹出和奖励状态均由原逻辑驱动。
- 地面仍由 402 个独立等尺寸视觉格子构成；不会合成一整片地形或用装饰跨过三个真实缺口。
- 模型资产与派生物继续按 CC0 使用；工程 MIT 许可不改变这些上游资产的许可。

## 2. 保留的原创部分

- Cube 玩家及全部敌人造型保持不变，本轮不处理人物。
- 远山轮廓、方云、旗杆、城堡门洞遮暗平面、少量窗洞、地面接缝后方的深土色衬底、碎片粒子、`?` 标识、UI 与合成音效仍由项目程序生成。单包没有适合本关横版视图的云、远山和独立旗杆，因此保留少量原创几何作为配套。
- 城堡墙和拱门已使用上表 Kenney 模型，不是新增混用另一套城堡包。
- 旧关 `scenes/main.tscn` 的美术与行为不在本轮更改范围内。

## 3. 既有字体

- **Noto Sans CJK**，上游：https://github.com/notofonts/noto-cjk 。
- 许可证：SIL Open Font License 1.1；原文见 [`third_party/Noto-LICENSE.txt`](third_party/Noto-LICENSE.txt)。
- 文件：`assets/fonts/NotoSansCJK.ttc`；用途：中文 UI。本轮没有替换、修改或重新下载该字体。

## 4. 布局参考与版权边界

World 1-1 的布局参考见 [README 的布局参考](README.md#布局参考)。地图参考和游戏资产是两件事：本工程没有引入 Nintendo 的 ROM、商业游戏模型、原版贴图、人物精灵、音乐或其他版权资产；本次新引入的环境与道具模型来自上述 Kenney CC0 官方资产包。
