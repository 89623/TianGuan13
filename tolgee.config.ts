// NovaSector 全量汉化：Tolgee CLI 配置。
//
// 管理统一 JSON 目录：
//   strings/i18n/<locale>/<namespace>.json
//
// TGUI 文本使用 tgui 命名空间：
//   strings/i18n/<locale>/tgui.json
// 运行 / 构建前由 tools/i18n/tgui-catalog.mjs 同步到：
//   tgui/packages/tgui/i18n/<locale>.json
//
// 用法（需先 `docker compose -f modular_nova/tools/i18n/docker-compose.yml up -d` 并设置
// TOLGEE_API_KEY 环境变量）：
//   bunx @tolgee/cli push    # 上传英文源串到 Tolgee 平台
//   bunx @tolgee/cli pull    # 把校对后的 zh-Hans 写回上述目录
//   node tools/i18n/tgui-catalog.mjs sync  # pull 后同步 TGUI 前端运行时目录
//
// 这是开发期工具，运行时不依赖 Tolgee。projectId 需替换为你在 Tolgee 里创建的项目 ID。

import { defineConfig } from '@tolgee/cli';

export default defineConfig({
  apiUrl: 'http://localhost:8085',
  projectId: 1, // TODO: 替换为实际项目 ID

  push: {
    files: [
      // DM 后端与 TGUI 前端目录（按命名空间分文件）。
      {
        path: 'strings/i18n/{languageTag}/{namespace}.json',
        language: '{languageTag}',
        namespace: '{namespace}',
      },
    ],
    // 以本地为准覆盖远端的源语言键（英文为单一事实来源）。
    forceMode: 'KEEP',
  },

  pull: {
    path: '.', // 回写到与 push 相同的相对路径布局
    fileStructureTemplate: 'strings/i18n/{languageTag}/{namespace}.json',
  },
});
