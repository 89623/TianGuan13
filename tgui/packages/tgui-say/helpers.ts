import type { Channel } from './ChannelIterator';
import { RADIO_PREFIXES, WindowSize } from './constants';

/**
 * Once byond signals this via keystroke, it
 * ensures window size, visibility, and focus.
 */
export function windowOpen(channel: Channel, scale: boolean): void {
  setWindowVisibility(true, scale);
  Byond.sendMessage('open', { channel });
}

/**
 * Resets the state of the window and hides it from user view.
 * Sending "close" logs it server side.
 */
export function windowClose(scale: boolean): void {
  setWindowVisibility(false, scale);
  Byond.winset('map', {
    focus: true,
  });
  Byond.sendMessage('close');
}

/**
 * Modifies the window size.
 */
export function windowSet(size = WindowSize.Small, scale: boolean): void {
  const pixelRatio = scale ? window.devicePixelRatio : 1;

  const sizeStr = `${WindowSize.Width * pixelRatio}x${size * pixelRatio}`;

  Byond.winset(null, {
    'tgui_say.size': sizeStr,
    'tgui_say.browser.size': sizeStr,
  });
}

/** Helper function to set window size and visibility */
function setWindowVisibility(visible: boolean, scale: boolean): void {
  const pixelRatio = scale ? window.devicePixelRatio : 1;

  const sizeStr = `${WindowSize.Width * pixelRatio}x${WindowSize.Small * pixelRatio}`;

  Byond.winset(null, {
    'tgui_say.is-visible': visible,
    'tgui_say.size': sizeStr,
    'tgui_say.browser.size': sizeStr,
  });
}

//TIANGUAN EDIT CHANGE - UAR 频道：原为 /^[:.]\w\s/（只认「冒号+1 字符+空白」）⇒ 两字符前缀 :ua 永远不匹配
const CHANNEL_REGEX = /^[:.]\w{1,2}\s/;

/** Tests for a channel prefix, returning it or none */
export function getPrefix(
  value: string,
): keyof typeof RADIO_PREFIXES | undefined {
  if (!value || value.length < 3 || !CHANNEL_REGEX.test(value)) {
    return;
  }

  //TIANGUAN EDIT ADDITION START - UAR 频道：先试两字符前缀（:ua ），命中优先；再退回单字符（:u = 补给）
  const twoChar = value
    .slice(0, 4)
    ?.toLowerCase()
    ?.replace('.', ':') as keyof typeof RADIO_PREFIXES;

  if (RADIO_PREFIXES[twoChar]) {
    return twoChar;
  }
  //TIANGUAN EDIT ADDITION END

  const adjusted = value
    .slice(0, 3)
    ?.toLowerCase()
    ?.replace('.', ':') as keyof typeof RADIO_PREFIXES;

  if (!RADIO_PREFIXES[adjusted]) {
    return;
  }

  return adjusted;
}
