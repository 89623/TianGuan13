// THIS IS A TIANGUAN UI FILE - 天关模块 GuideBrowser 的偏好条目
//
// 这条对应 DM 侧 modular_tianguan/modules/guide_browser/code/guide_prefs.dm 里的
// /datum/preference/toggle/tianguan_guide_button：**导出的常量名必须与它的 savefile_key 一致**
// （界面按 savefile_key 从服务端数据里取值），所以这里是 `tianguanguidebutton`。
// ⚠ 常量名（= savefile_key）是**数据键**，不要跟着显示名一起改 —— 改了等于把玩家已经勾过的状态丢掉。
//
// 位置：游戏内 ESC → 设置（游戏偏好设置）→ 「指南浏览器」分区。
// 勾上 = 回合开始时不自动发放左上角的「指南浏览器」按钮（也就是"回合开始时自动关掉它"）；
// 默认不勾 = 每回合照常显示。中途想临时要回来：OOC 栏 →「打开指南按钮」（本局有效，不改这里的勾选）。
//
// 本文件是**新增**的：PreferencesMenu/preferences/features 目录用 require.context 自动加载，
// 所以不需要在任何上游文件里登记（零共享文件改动）。文案直接写中文 —— 纯中文不会被 i18n
// 提取器抽成 key（避免往 strings/i18n/ 里塞条目）。
import { CheckboxInput, type FeatureToggle } from '../base';

export const tianguanguidebutton: FeatureToggle = {
  name: '回合开始时自动关闭指南按钮',
  category: '指南浏览器',
  description:
    '回合开始时不自动显示左上角的「指南浏览器」按钮。勾/取消不会当场改变按钮，下个回合开始（或重新进服）时生效；当前回合的显示/隐藏请用 OOC 栏的指令。',
  component: CheckboxInput,
};
