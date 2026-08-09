# CentCom automapper 模板

## 互联中枢（Ghost Cafe / CentCom z2）

**改互联中枢请编辑这个目录下的 `interlink_*.dmm`，不要动 `_maps/map_files/generic/CentCom_nova_z2.dmm`。**

那个底图由上游维护，已恢复成上游原样。历史上累积的全部下游改动都迁到了这里：

| 模板 | 内容 |
| --- | --- |
| `interlink_rework.dmm` | 主体改建，61×85，覆盖绝大多数改动 |
| `interlink_fans_*.dmm` | 移除自供电风扇 |
| `interlink_cafe_chem*.dmm` | 咖啡厅化学区物品替换 |
| `interlink_dna_machines.dmm` | 展示品替换为可用的 DNA 设备 |
| `interlink_painters_*.dmm` | 移除气闸喷漆器 |
| `interlink_beaker*.dmm`、`interlink_seeds.dmm`、`interlink_wood_floor.dmm` | 零散单点改动 |

配置在 `../../automapper_config.toml`。改完不用动底图，automapper 开局时会覆盖上去。

## 新增模板时的两个坑

**`required_map` 写 `"CentCom_nova_z2.dmm"`，不要写 `"builtin"`。**
`preload_templates_from_toml` 在每个 `LoadGroup` 内部调用，而 `"builtin"` 的判定看站点地图、不看当前组，会在基础 CentCom 那一组就匹配上——那时 CentCom 只有一层，`coordinates[3] = 2` 越界。**一次越界会中断整个模板循环，后续模板全部静默消失**，且不会有醒目报错。

**`coordinates` 第三项是 `levels_by_trait("CentCom")` 的索引**：1 = 基础 CentCom，2 = 互联中枢（由 `modular_nova/modules/mapping/code/interlink_helper.dm` 在 `..()` 之后加载）。

## 验证方式

模板是运行时加载的，不进 `.dmb`，**编译永远是绿的，不构成门禁**。必须真起一局，查 `runtime.log`：

```sh
grep -c 'map template interlink_' <round>/runtime.log   # 条数应等于模板数
grep -i 'bad turf\|index out of bounds' <round>/runtime.log   # 应为空
```

## 为什么会有这套东西

这张底图曾被存成**普通 DMM 而非 TGM**，于是网格区每一行都与上游不同，`mapmerge2` 完全失效，git 永远无法有意义地合并——这是它长期成为冲突重灾区的真正原因。

副作用更隐蔽：绘图者基于过期副本整份保存时，会把上游做过的类型重命名**覆盖回旧路径**。迁移时查出三处这样的死类型，其中地板那处会让 turf 建不出来、退化成 space：

- `/turf/open/floor/pod/light` → 上游已改名为 `/turf/open/floor/mineral/plastitanium/pod/light`
- `/obj/item/food/grown/poppy/geranium` → 上游给花类加父类型后变为 `/obj/item/food/grown/flower/poppy/geranium`
- `(239,224)` 处一个裸的抽象 `/area`

**用地图编辑器前请确认它按 TGM 保存**（StrongDMM 在设置里选 TGM）。另外查这类死类型要靠**运行时日志**，静态 grep 没有判别力——tg 用 `MAPPING_DIRECTIONAL_HELPERS` 之类的宏批量生成子类型，扫描器会把上百个正常类型误报成缺失。
