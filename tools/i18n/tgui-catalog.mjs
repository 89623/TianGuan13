#!/usr/bin/env node

import fs from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../..',
);
const ts = require(path.join(ROOT, 'tgui/node_modules/typescript'));

const LOCALES = ['en', 'zh-Hans'];
const TGUI_SOURCE_DIR = path.join(ROOT, 'tgui/packages/tgui');
const TGUI_PACKAGE_I18N_DIR = path.join(ROOT, 'tgui/packages/tgui/i18n');
const STRINGS_I18N_DIR = path.join(ROOT, 'strings/i18n');
const TGUI_NAMESPACE = 'tgui';

const TRANSLATABLE_PROPS = new Set([
  'aria-label',
  'content',
  'displayText',
  'header',
  'label',
  'message',
  'placeholder',
  'title',
  'tooltip',
]);

const OPTION_TEXT_PROPS = new Set(['displayText', 'label', 'text', 'title']);

// 偏好「feature 定义」里的 name/description（如 height_scaling.tsx 的 `name: 'Body Height'`）。
// 这些是对象字面量属性、非 JSX 文本，但 PreferencesMenu 渲染 feature.name 时经自动本地化 runtime
// 查前端目录显示。仅在 feature 定义目录下抽取，避免把任意 .tsx 里的 name/description 当文案。
const FEATURE_LABEL_PROPS = new Set(['name', 'description']);
const FEATURE_DEF_DIR = `${path.sep}PreferencesMenu${path.sep}preferences${path.sep}features${path.sep}`;

const COMMON_ZH = {
  Abandon: '放弃',
  Achievement: '成就',
  Achievements: '成就',
  Ability: '能力',
  Abilities: '能力',
  Admin: '管理员',
  Administrator: '管理员',
  Air: '空气',
  Airlock: '气闸',
  Alarm: '警报',
  Alarms: '警报',
  Alert: '警报',
  Alpha: '阿尔法',
  Asteroid: '小行星',
  Analyze: '分析',
  Amount: '数量',
  Anomaly: '异常体',
  Announcement: '公告',
  Announcements: '公告',
  Antagonist: '反派',
  Antagonists: '反派',
  APC: 'APC',
  Appearance: '外观',
  Application: '申请',
  Approve: '批准',
  Archive: '存档',
  Archived: '已存档',
  Area: '区域',
  Argument: '参数',
  Arguments: '参数',
  Atmos: '大气',
  Atmosphere: '大气',
  Attachment: '附件',
  Attack: '攻击',
  Auto: '自动',
  Available: '可用',
  Balance: '余额',
  Bank: '银行',
  Battery: '电池',
  Beaker: '烧杯',
  Belt: '带',
  Blood: '血液',
  Body: '身体',
  Book: '书籍',
  Books: '书籍',
  Browser: '浏览器',
  Build: '构建',
  Change: '更改',
  Cancelled: '已取消',
  Card: '卡',
  Cargo: '货运',
  Category: '分类',
  Charge: '电量',
  Character: '角色',
  Chemicals: '化学品',
  Chemistry: '化学',
  Clear: '清除',
  Click: '点击',
  Client: '客户端',
  Code: '代码',
  Color: '颜色',
  Command: '指挥',
  Component: '组件',
  Components: '组件',
  Confirmed: '已确认',
  Console: '控制台',
  Connection: '连接',
  Contents: '内容',
  Control: '控制',
  Controls: '控制',
  Controller: '控制器',
  Cooldown: '冷却',
  Core: '核心',
  Create: '创建',
  Crew: '船员',
  Crime: '罪名',
  Crimes: '罪名',
  Current: '当前',
  Custom: '自定义',
  Database: '数据库',
  Deck: '甲板',
  Default: '默认',
  Delete: '删除',
  Department: '部门',
  Description: '描述',
  Details: '详情',
  Direction: '方向',
  Disable: '禁用',
  Disabled: '已禁用',
  Disease: '疾病',
  Display: '显示',
  DNA: 'DNA',
  Door: '门',
  Download: '下载',
  Edit: '编辑',
  Effect: '效果',
  Effects: '效果',
  Eject: '弹出',
  Emergency: '紧急',
  Empty: '空',
  Enable: '启用',
  Enabled: '已启用',
  Enter: '输入',
  Engine: '引擎',
  Engineering: '工程',
  Entry: '条目',
  Equipment: '装备',
  Error: '错误',
  Event: '事件',
  Events: '事件',
  Experiment: '实验',
  Experiments: '实验',
  Fax: '传真',
  Failed: '失败',
  Filter: '筛选',
  Floor: '地板',
  Force: '强制',
  Frequency: '频率',
  General: '通用',
  Gene: '基因',
  Genetics: '遗传学',
  Goal: '目标',
  Goals: '目标',
  Health: '健康',
  Help: '帮助',
  ID: 'ID',
  Idle: '空闲',
  Info: '信息',
  Information: '信息',
  Input: '输入',
  Insert: '插入',
  Invalid: '无效',
  Item: '物品',
  Items: '物品',
  Key: '键',
  Law: '法律',
  Laws: '法律',
  Layer: '图层',
  Line: '行',
  List: '列表',
  Loadout: '配装',
  Lock: '锁定',
  Location: '位置',
  Log: '日志',
  Logs: '日志',
  Login: '登录',
  Logout: '登出',
  Machine: '机器',
  Map: '地图',
  Manual: '手册',
  Material: '材料',
  Materials: '材料',
  Medical: '医疗',
  Message: '消息',
  Messages: '消息',
  Menu: '菜单',
  Maximum: '最大',
  Minimum: '最小',
  Module: '模块',
  Modules: '模块',
  Mode: '模式',
  Modified: '已修改',
  Name: '名称',
  Network: '网络',
  Next: '下一个',
  New: '新建',
  Note: '备注',
  Notes: '备注',
  Notification: '通知',
  Notifications: '通知',
  Objective: '目标',
  Objectives: '目标',
  Normal: '正常',
  Open: '打开',
  Option: '选项',
  Options: '选项',
  Output: '输出',
  Overview: '概览',
  Panel: '面板',
  Parameter: '参数',
  Parameters: '参数',
  Pause: '暂停',
  Player: '玩家',
  Players: '玩家',
  Port: '端口',
  Power: '电力',
  Preset: '预设',
  Previous: '上一个',
  Print: '打印',
  Processing: '处理中',
  Progress: '进度',
  Quantity: '数量',
  Queue: '队列',
  Random: '随机',
  Range: '范围',
  Ready: '就绪',
  Reagent: '试剂',
  Reagents: '试剂',
  Reboot: '重启',
  Record: '记录',
  Records: '记录',
  Refinery: '精炼机',
  Refresh: '刷新',
  Reload: '重载',
  Remote: '远程',
  Remove: '移除',
  Rename: '重命名',
  Required: '需要',
  Reset: '重置',
  Restore: '恢复',
  Resume: '继续',
  Retry: '重试',
  Rule: '规则',
  Rules: '规则',
  Ruleset: '规则集',
  Rulesets: '规则集',
  Scanner: '扫描器',
  Scan: '扫描',
  Search: '搜索',
  Security: '安保',
  Select: '选择',
  Send: '发送',
  Server: '服务器',
  Settings: '设置',
  Shuttle: '穿梭机',
  Signal: '信号',
  Space: '太空',
  Status: '状态',
  Sort: '排序',
  Source: '来源',
  Start: '开始',
  Station: '空间站',
  Stop: '停止',
  Storage: '存储',
  Story: '故事',
  Stories: '故事',
  Submit: '提交',
  System: '系统',
  Tablet: '平板',
  Tablets: '平板',
  Target: '目标',
  Temperature: '温度',
  Text: '文本',
  Time: '时间',
  Tools: '工具',
  Toggle: '切换',
  Transfer: '转移',
  Turfs: '地格',
  Type: '类型',
  Types: '类型',
  Unknown: '未知',
  Update: '更新',
  Upload: '上传',
  User: '用户',
  Variable: '变量',
  Variables: '变量',
  Value: '值',
  View: '查看',
  Vote: '投票',
  Weather: '天气',
  Warning: '警告',
  Wizard: '巫师',
};

function translateTerm(term) {
  const titleCase = term ? `${term[0].toUpperCase()}${term.slice(1)}` : term;
  const direct = COMMON_ZH[term] ?? COMMON_ZH[titleCase];
  if (direct) {
    return direct;
  }

  const singular = term.endsWith('s') ? term.slice(0, -1) : null;
  return singular ? COMMON_ZH[singular] : null;
}

function translateNounPhrase(phrase) {
  const direct = COMMON_ZH[phrase];
  if (direct) {
    return direct;
  }

  const words = phrase.split(/[\s-]+/).filter(Boolean);
  if (!words.length) {
    return null;
  }

  const translated = [];
  for (const word of words) {
    const match = word.match(/^([^A-Za-z]*)([A-Za-z]+)([^A-Za-z]*)$/);
    if (!match) {
      return null;
    }
    const [, leading, clean, trailing] = match;
    const term = translateTerm(clean);
    if (!term) {
      return null;
    }
    translated.push(`${leading}${term}${trailing}`);
  }
  return translated.join('');
}

function phraseTranslation(source) {
  const direct = COMMON_ZH[source];
  if (direct) {
    return direct;
  }

  const colon = source.match(/^(.+):$/);
  if (colon) {
    const base = phraseTranslation(colon[1]);
    return base ? `${base}：` : null;
  }

  const question = source.match(/^(.+)\?$/);
  if (question) {
    const base = phraseTranslation(question[1]);
    return base ? `${base}？` : null;
  }

  const patterns = [
    [/^Add (.+)$/, (value) => `添加${value}`],
    [/^Adjust (.+)$/, (value) => `调整${value}`],
    [/^Apply (.+)$/, (value) => `应用${value}`],
    [/^Approve (.+)$/, (value) => `批准${value}`],
    [/^Delete (.+)$/, (value) => `删除${value}`],
    [/^Edit (.+)$/, (value) => `编辑${value}`],
    [/^Remove (.+)$/, (value) => `移除${value}`],
    [/^Reset (.+)$/, (value) => `重置${value}`],
    [/^Scan (.+)$/, (value) => `扫描${value}`],
    [/^Select (.+)$/, (value) => `选择${value}`],
    [/^Set (.+)$/, (value) => `设置${value}`],
    [/^Show (.+)$/, (value) => `显示${value}`],
    [/^Toggle (.+)$/, (value) => `切换${value}`],
    [/^View (.+)$/, (value) => `查看${value}`],
    [/^(.+) Control$/, (value) => `${value}控制`],
    [/^(.+) Controls$/, (value) => `${value}控制`],
    [/^(.+) Display$/, (value) => `${value}显示`],
    [/^(.+) Level$/, (value) => `${value}等级`],
    [/^(.+) List$/, (value) => `${value}列表`],
    [/^(.+) Log$/, (value) => `${value}日志`],
    [/^(.+) Logs$/, (value) => `${value}日志`],
    [/^(.+) Mode$/, (value) => `${value}模式`],
    [/^(.+) Name$/, (value) => `${value}名称`],
    [/^(.+) Options$/, (value) => `${value}选项`],
    [/^(.+) Panel$/, (value) => `${value}面板`],
    [/^(.+) Settings$/, (value) => `${value}设置`],
    [/^(.+) Status$/, (value) => `${value}状态`],
    [/^(.+) Type$/, (value) => `${value}类型`],
    [/^(.+) Types$/, (value) => `${value}类型`],
  ];

  for (const [regex, render] of patterns) {
    const match = source.match(regex);
    if (!match) {
      continue;
    }

    const translated = translateNounPhrase(match[1]);
    if (translated) {
      return render(translated);
    }
  }

  return translateNounPhrase(source);
}

function readJson(filePath) {
  if (!fs.existsSync(filePath)) {
    return {};
  }
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function writeJson(filePath, data) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const sorted = {};
  for (const key of Object.keys(data).sort((a, b) => a.localeCompare(b))) {
    sorted[key] = data[key];
  }
  fs.writeFileSync(filePath, `${JSON.stringify(sorted, null, '\t')}\n`);
}

function stringsCatalogPath(locale) {
  return path.join(STRINGS_I18N_DIR, locale, `${TGUI_NAMESPACE}.json`);
}

function packageCatalogPath(locale) {
  return path.join(TGUI_PACKAGE_I18N_DIR, `${locale}.json`);
}

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name === 'i18n' || entry.name === 'node_modules') {
      continue;
    }

    const entryPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(entryPath, out);
      continue;
    }

    if (
      (entry.name.endsWith('.tsx') || entry.name.endsWith('.jsx')) &&
      !entry.name.includes('.test.')
    ) {
      out.push(entryPath);
    }
  }
  return out;
}

function normalizeText(text) {
  if (typeof text !== 'string') {
    return null;
  }
  const normalized = text.replace(/\s+/g, ' ').trim();
  if (!normalized || !/[A-Za-z]/.test(normalized)) {
    return null;
  }
  if (/^[\d\s.,:;()[\]{}%+\-*/<>_=|"'`!?]+$/.test(normalized)) {
    return null;
  }
  return normalized;
}

function propertyName(name) {
  if (!name) {
    return null;
  }
  if (ts.isIdentifier(name) || ts.isStringLiteral(name)) {
    return name.text;
  }
  return null;
}

function literalText(node) {
  if (!node) {
    return null;
  }
  if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) {
    return normalizeText(node.text);
  }
  if (ts.isJsxExpression(node) && node.expression) {
    return literalText(node.expression);
  }
  return null;
}

function addText(catalog, text) {
  const normalized = normalizeText(text);
  if (normalized) {
    catalog[normalized] = normalized;
  }
}

// 「标识符耦合的 DM 显示名」——这些 name/title 在 TGUI 里既是显示又是 act() 标识符（食物类别、
// 职业、怪癖…），不能让 DM 端 P1 改数据（会破坏 act）。改为从 DM 源读进前端 tgui 目录，由 TS
// runtime 只翻**显示**（act 用原英文值，安全）；运行时 P1 会跳过出现在 tgui 目录里的串。
// runtime 无多词门槛，单词类（Meat/Cursed…）也能命中。
// 每项：[相对路径, 是否递归扫目录下 .dm, 捕获组1=可翻串的正则(必须 /g)]。
// 注意：路径钉死，上游若重命名这些目录，抽取会静默漏掉（少翻、不崩、不冲突），改路径即可。
const DM_LABEL_SOURCES = [
  // 食物类别：全局列表的引号键。
  ['code/__DEFINES/~nova_defines/_globalvars/food.dm', false, /"([^"]+)"\s*=/g],
  // 职业名/部门名：job_types 用 `title = JOB_X`（#define 常量），字面量在 jobs.dm 的 #define 里。
  ['code/__DEFINES/jobs.dm', false, /#define\s+\w+\s+"([^"]+)"/g],
  ['modular_nova/master_files/code/__DEFINES', true, /#define\s+JOB_\w+\s+"([^"]+)"/g],
  // 怪癖名：各 quirk 子类型的 `name = "..."`。
  ['code/datums/quirks', true, /^\s*name\s*=\s*"([^"]+)"/gm],
];

function dmFilesUnder(absPath, recursive, out) {
  let stat;
  try {
    stat = fs.statSync(absPath);
  } catch {
    return out;
  }
  if (!stat.isDirectory()) {
    out.push(absPath);
    return out;
  }
  for (const entry of fs.readdirSync(absPath, { withFileTypes: true })) {
    const entryPath = path.join(absPath, entry.name);
    if (entry.isDirectory()) {
      if (recursive) dmFilesUnder(entryPath, recursive, out);
    } else if (entry.name.endsWith('.dm')) {
      out.push(entryPath);
    }
  }
  return out;
}

function extractDmLabels(catalog) {
  for (const [rel, recursive, regex] of DM_LABEL_SOURCES) {
    for (const file of dmFilesUnder(path.join(ROOT, rel), recursive, [])) {
      let source;
      try {
        source = fs.readFileSync(file, 'utf8');
      } catch {
        continue;
      }
      for (const match of source.matchAll(regex)) {
        addText(catalog, match[1]);
      }
    }
  }
}

function extractCatalog() {
  const catalog = {};
  extractDmLabels(catalog);
  for (const filePath of walk(TGUI_SOURCE_DIR)) {
    const source = fs.readFileSync(filePath, 'utf8');
    const sourceFile = ts.createSourceFile(
      filePath,
      source,
      ts.ScriptTarget.Latest,
      true,
      filePath.endsWith('.jsx') ? ts.ScriptKind.JSX : ts.ScriptKind.TSX,
    );

    const isFeatureDef = filePath.includes(FEATURE_DEF_DIR);

    function visit(node) {
      if (ts.isJsxText(node)) {
        addText(catalog, node.text);
      } else if (ts.isJsxAttribute(node)) {
        const name = node.name.getText(sourceFile);
        if (TRANSLATABLE_PROPS.has(name)) {
          addText(catalog, literalText(node.initializer));
        }
      } else if (ts.isPropertyAssignment(node)) {
        const name = propertyName(node.name);
        if (
          TRANSLATABLE_PROPS.has(name) ||
          OPTION_TEXT_PROPS.has(name) ||
          (isFeatureDef && FEATURE_LABEL_PROPS.has(name))
        ) {
          addText(catalog, literalText(node.initializer));
        }
      }

      ts.forEachChild(node, visit);
    }

    visit(sourceFile);
  }
  return catalog;
}

function existingTguiCatalog(locale) {
  return {
    ...readJson(packageCatalogPath(locale)),
    ...readJson(stringsCatalogPath(locale)),
  };
}

function buildReverseTranslations(locale) {
  const localeDir = path.join(STRINGS_I18N_DIR, locale);
  const enDir = path.join(STRINGS_I18N_DIR, 'en');
  const reverse = {};

  if (!fs.existsSync(localeDir)) {
    return reverse;
  }

  for (const entry of fs.readdirSync(enDir)) {
    if (!entry.endsWith('.json') || entry === `${TGUI_NAMESPACE}.json`) {
      continue;
    }
    const enCatalog = readJson(path.join(enDir, entry));
    const localeCatalog = readJson(path.join(localeDir, entry));
    for (const [key, source] of Object.entries(enCatalog)) {
      const target = localeCatalog[key];
      if (
        typeof source === 'string' &&
        typeof target === 'string' &&
        target !== source &&
        /[\u3400-\u9fff]/.test(target)
      ) {
        reverse[source] ??= target;
      }
    }
  }

  return reverse;
}

function extract() {
  const extracted = extractCatalog();
  const existingEn = existingTguiCatalog('en');
  const existingZh = existingTguiCatalog('zh-Hans');
  const reverseZh = buildReverseTranslations('zh-Hans');

  const enCatalog = {
    ...extracted,
    ...existingEn,
  };
  const zhCatalog = {};

  for (const key of Object.keys(enCatalog)) {
    const existing = existingZh[key];
    // 用户已有译文**最优先**，绝不被自动生成覆盖。否则每次 extract 都会把整句人工译文降级为
    // phraseTranslation/reverse 的词级重组（如「创建指挥报告」→「创建指挥 Report」）。
    // 只有「尚无译文」的新键才用自动生成回填。
    if (existing && existing !== key) {
      zhCatalog[key] = existing;
      continue;
    }
    zhCatalog[key] = phraseTranslation(key) ?? reverseZh[key] ?? key;
  }

  writeJson(stringsCatalogPath('en'), enCatalog);
  writeJson(stringsCatalogPath('zh-Hans'), zhCatalog);
  sync();
}

function sync() {
  const enSource = readJson(stringsCatalogPath('en'));
  for (const locale of LOCALES) {
    const sourcePath = stringsCatalogPath(locale);
    const fallbackPath = packageCatalogPath(locale);
    const source = fs.existsSync(sourcePath)
      ? readJson(sourcePath)
      : readJson(fallbackPath);
    const runtimeCatalog = {};

    for (const [key, value] of Object.entries(source)) {
      const enValue = enSource[key] ?? key;
      if (locale === 'en' ? value !== key : value !== enValue) {
        runtimeCatalog[key] = value;
      }
    }

    writeJson(fallbackPath, runtimeCatalog);
  }
}

const command = process.argv[2] ?? 'sync';
if (command === 'extract') {
  extract();
} else if (command === 'sync') {
  sync();
} else {
  console.error(`Unknown command: ${command}`);
  console.error('Usage: node tools/i18n/tgui-catalog.mjs [extract|sync]');
  process.exit(1);
}
