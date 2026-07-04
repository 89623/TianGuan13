## 紧急穿梭机中央指挥停靠点

模块 ID：TIANGUAN_EMERGENCY_SHUTTLE_CC

### 说明：

让普通撤离结束时的紧急穿梭机优先停靠到基础 CC 地图恢复翼处的大型撤离船停靠点，避免 Nova Interlink 额外加载的同名 `emergency_away` 停靠点影响最终停靠位置。

### 核心文件 / Proc 改动：

- 无

### 模块化覆盖：

- `modular_tianguan/modules/emergency_shuttle_cc/code/emergency_shuttle_cc.dm` 增加 `/datum/controller/subsystem/shuttle/proc/tianguan_get_cc_emergency_away_dock()`，并覆盖 `/obj/docking_port/mobile/emergency/dock_id()`；普通撤离目标为 `emergency_away` 时，只选择更新后基础 CC 地图里的大型 dock：`port_destinations = emergency_away`、`area_type = /area/space`、尺寸 50x50、`dwidth = 25`、方向 EAST，避免选到 Nova Interlink 的同名 dock。

### Defines：

- `TIANGUAN_EMERGENCY_AWAY_DOCK`
- `TIANGUAN_CC_RECOVERY_WING_DOCK_DIR`

### 本模块目录外的依赖文件：

- `tgstation.dme` 需要包含本模块代码文件。

### 致谢：

- 无
