/** Window sizes in pixels */
export enum WindowSize {
  Small = 30,
  Medium = 50,
  Large = 70,
  Width = 231,
}

/** Line lengths for autoexpand */
export enum LineLength {
  Small = 20,
  Medium = 39,
  Large = 59,
}

/**
 * Radio prefixes.
 * Displays the name in the left button, tags a css class.
 */
export const RADIO_PREFIXES = {
  ':a ': 'Hive',
  ':b ': 'io',
  ':c ': 'Cmd',
  ':e ': 'Engi',
  ':g ': 'Cling',
  ':m ': 'Med',
  ':n ': 'Sci',
  ':o ': 'AI',
  ':p ': 'Ent',
  ':s ': 'Sec',
  ':ua ': 'UAR', // TIANGUAN EDIT ADDITION - UAR 频道：让 say 窗识别 :ua（左侧显示短标签）
  ':t ': 'Synd',
  ':u ': 'Supp',
  ':v ': 'Svc',
  ':y ': 'CCom',
  // NOVA EDIT ADDITION START
  ':w ': 'Dyne',
  ':k ': 'Tark',
  ':q ': 'Csun',
  ':1 ': 'Guild',
  ':2 ': 'SolFed',
  // NOVA EDIT ADDITION END
} as const;
