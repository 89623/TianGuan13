// THIS IS A TIANGUAN UI FILE
// 界面：TianGuanCountdown —— 管理员「全局倒计时」（由「秘密」面板的按钮打开）
import { useState } from 'react';
import {
  Box,
  Button,
  Input,
  LabeledList,
  NumberInput,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  state: number;
  title: string;
  end_text: string;
  remaining: number;
  end_seconds: number;
  title_color: string;
  countdown_color: string;
  end_color: string;
  silent: boolean;
  music_catalog: MusicOption[];
  music_selection: string[];
  music_rate_manual: number;
  music_volume: number;
  music_interval: number;
  music_status: MusicStatus;
  music_state: number;
  music_remaining: number;
  music_duration: number;
  music_follow_screen: boolean;
};

/** 曲库条目：key = 点唱机上传目录里的文件名（唯一），name = 显示名 */
type MusicOption = { key: string; name: string };

/** 传输状态：每个在线玩家一行（pushed/total + 是否已推完） */
type MusicStatus = {
  players: {
    ckey: string;
    name: string;
    pushed: number;
    total: number;
    ready: boolean;
    online: boolean;
  }[];
  ready_count: number;
  online_count: number;
  total: number;
};

const STATE_TEXT = ['未进行任何设置', '倒计时中', '已暂停', '显示结束文本'];

const COLOR_PRESETS = [
  { name: '白', value: '#FFFFFF' },
  { name: '金', value: '#FFD700' },
  { name: '红', value: '#FF5555' },
  { name: '绿', value: '#55FF55' },
  { name: '青', value: '#55FFFF' },
  { name: '紫', value: '#C77DFF' },
];

const formatTime = (deciseconds: number) => {
  const total = Math.max(0, Math.floor(deciseconds / 10));
  const minutes = Math.floor(total / 60);
  const seconds = total % 60;
  return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
};

type ColorRowProps = {
  label: string;
  current: string;
  input: string;
  setInput: (value: string) => void;
  applyAction: string;
  applyParam: string;
  pickAction: string;
};

/** 一行颜色控制：输入框 + 当前色块 + 「应用」 + 「取色」（走本仓现成的 tgui_color_picker） */
const ColorRow = (props: ColorRowProps) => {
  const { act } = useBackend();
  const {
    label,
    current,
    input,
    setInput,
    applyAction,
    applyParam,
    pickAction,
  } = props;

  return (
    <Stack.Item>
      <Stack align="center">
        <Stack.Item width="6.5rem">{label}</Stack.Item>
        <Stack.Item grow>
          <Input
            fluid
            placeholder="#RRGGBB 或色名（如 gold）"
            value={input}
            onChange={setInput}
          />
        </Stack.Item>
        <Stack.Item>
          <Box
            width="1.2rem"
            height="1.2rem"
            style={{ backgroundColor: current, border: '1px solid #000' }}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="pen"
            onClick={() => act(applyAction, { [applyParam]: input })}
          >
            应用
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="eye-dropper"
            tooltip="打开取色器"
            onClick={() => act(pickAction)}
          />
        </Stack.Item>
      </Stack>
      <Stack mt={0.5}>
        <Stack.Item>预设</Stack.Item>
        {COLOR_PRESETS.map((preset) => (
          <Stack.Item key={preset.value}>
            <Button
              onClick={() => {
                setInput(preset.value);
                act(applyAction, { [applyParam]: preset.value });
              }}
            >
              {preset.name}
            </Button>
          </Stack.Item>
        ))}
      </Stack>
    </Stack.Item>
  );
};

export const TianGuanCountdown = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    state,
    title,
    end_text,
    end_seconds,
    remaining,
    title_color,
    countdown_color,
    end_color,
    silent,
    music_catalog,
    music_selection,
    music_rate_manual,
    music_volume,
    music_interval,
    music_status,
    music_state,
    music_remaining,
    music_duration,
    music_follow_screen,
  } = data;

  const [inputTitle, setInputTitle] = useState(title);
  const [inputSeconds, setInputSeconds] = useState(60);
  const [inputEndText, setInputEndText] = useState(end_text);
  const [inputEndSeconds, setInputEndSeconds] = useState(end_seconds || 10);
  // 初值取自后台（0 = 与明面倒计时同长），改动时会回写后台
  const [musicDuration, setMusicDuration] = useState(music_duration);
  const [editTitle, setEditTitle] = useState('');
  const [editEndText, setEditEndText] = useState('');
  const [inputTitleColor, setInputTitleColor] = useState(title_color);
  const [inputCountdownColor, setInputCountdownColor] = useState(
    countdown_color,
  );
  const [inputEndColor, setInputEndColor] = useState(end_color);

  const active = state !== 0;

  return (
    <Window title="全局倒计时" width={560} height={760}>
      <Window.Content scrollable>
        <Section title="当前状态">
          <LabeledList>
            <LabeledList.Item label="状态">
              {STATE_TEXT[state] ?? '未知'}
            </LabeledList.Item>
            <LabeledList.Item label="标题">
              {title || '（空）'}
            </LabeledList.Item>
            <LabeledList.Item label="剩余时间">
              {active ? formatTime(remaining) : '—'}
            </LabeledList.Item>
            <LabeledList.Item label="结束文本">
              {end_text || '（空）'}
            </LabeledList.Item>
            <LabeledList.Item label="结束文本时长">
              {end_seconds ? `${end_seconds} 秒` : '（空）'}
            </LabeledList.Item>
          </LabeledList>
          <Stack mt={1}>
            <Stack.Item grow>
              <Button
                fluid
                icon={state === 2 ? 'play' : 'pause'}
                disabled={!active}
                onClick={() => act('pause')}
              >
                {state === 2 ? '继续倒计时' : '暂停倒计时'}
              </Button>
            </Stack.Item>
            <Stack.Item grow>
              <Button.Confirm
                fluid
                color="bad"
                icon="stop"
                disabled={!active}
                onClick={() => act('stop')}
              >
                结束倒计时
              </Button.Confirm>
            </Stack.Item>
          </Stack>
        </Section>

        <Section title="设置并开始">
          <Stack vertical>
            <Stack.Item>
              <Input
                fluid
                placeholder="标题（可留空）"
                value={inputTitle}
                onChange={setInputTitle}
              />
            </Stack.Item>
            <Stack.Item>
              <Stack align="center">
                <Stack.Item grow color="label">
                  想让标题随倒计时变化（开始后第 N 秒换成别的文本）⇒ 用「标题阶段」
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="list-ol"
                    tooltip="阶段 = 时间点 + 文本；可设任意多条"
                    onClick={() => act('open_stages')}
                  >
                    编辑标题阶段
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Stack align="center">
                <Stack.Item grow>
                  <NumberInput
                    fluid
                    minValue={0}
                    maxValue={600}
                    step={1}
                    unit="分"
                    value={Math.floor(inputSeconds / 60)}
                    onChange={(value) =>
                      setInputSeconds(
                        Math.max(Math.round(value), 0) * 60 + (inputSeconds % 60),
                      )
                    }
                  />
                </Stack.Item>
                <Stack.Item grow>
                  <NumberInput
                    fluid
                    minValue={0}
                    maxValue={59}
                    step={1}
                    unit="秒"
                    value={inputSeconds % 60}
                    onChange={(value) =>
                      setInputSeconds(
                        Math.floor(inputSeconds / 60) * 60 +
                          Math.max(Math.min(Math.round(value), 59), 0),
                      )
                    }
                  />
                </Stack.Item>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Input
                fluid
                placeholder="倒计时结束后出现的文本（可留空）"
                value={inputEndText}
                onChange={setInputEndText}
              />
            </Stack.Item>
              <Stack align="center">
                <Stack.Item grow>
                  <NumberInput
                    fluid
                    minValue={0}
                    maxValue={60}
                    step={1}
                    unit="分"
                    value={Math.floor(inputEndSeconds / 60)}
                    onChange={(value) =>
                      setInputEndSeconds(
                        Math.max(Math.round(value), 0) * 60 +
                          (inputEndSeconds % 60),
                      )
                    }
                  />
                </Stack.Item>
                <Stack.Item grow>
                  <NumberInput
                    fluid
                    minValue={0}
                    maxValue={59}
                    step={1}
                    unit="秒"
                    value={inputEndSeconds % 60}
                    onChange={(value) =>
                      setInputEndSeconds(
                        Math.floor(inputEndSeconds / 60) * 60 +
                          Math.max(Math.min(Math.round(value), 59), 0),
                      )
                    }
                  />
                </Stack.Item>
              </Stack>
            <Stack.Item>
              <Button
                fluid
                color="good"
                icon="hourglass-start"
                onClick={() =>
                  act('start', {
                    title: inputTitle,
                    seconds: inputSeconds,
                    end_text: inputEndText,
                    end_seconds: inputEndSeconds,
                  })
                }
              >
                开始倒计时{active ? '（按当前设置重开）' : ''}
              </Button>
            </Stack.Item>
          </Stack>
        </Section>

        <Section title="颜色">
          <Stack vertical>
            <ColorRow
              label="标题颜色"
              current={title_color}
              input={inputTitleColor}
              setInput={setInputTitleColor}
              applyAction="set_title_color"
              applyParam="title_color"
              pickAction="pick_title_color"
            />
            <ColorRow
              label="倒计时颜色"
              current={countdown_color}
              input={inputCountdownColor}
              setInput={setInputCountdownColor}
              applyAction="set_countdown_color"
              applyParam="countdown_color"
              pickAction="pick_countdown_color"
            />
            <ColorRow
              label="结束文本颜色"
              current={end_color}
              input={inputEndColor}
              setInput={setInputEndColor}
              applyAction="set_end_color"
              applyParam="end_color"
              pickAction="pick_end_color"
            />
          </Stack>
        </Section>

        <Section title="运行中修改">
          <Stack vertical>
            <Stack.Item>
              <Stack>
                <Stack.Item grow>
                  <Input
                    fluid
                    placeholder="新的标题"
                    value={editTitle}
                    onChange={setEditTitle}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    disabled={!active}
                    icon="pen"
                    onClick={() => act('set_title', { title: editTitle })}
                  >
                    更改标题
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Stack>
                <Stack.Item grow>
                  <Input
                    fluid
                    placeholder="新的结束文本"
                    value={editEndText}
                    onChange={setEditEndText}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    disabled={!active}
                    icon="pen"
                    onClick={() => act('set_end_text', { end_text: editEndText })}
                  >
                    更改结束文本
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        </Section>

        <Section title="内部倒计时（放歌准备窗）">
          <Box color="label">
            它与上面的明面倒计时
            <Box inline bold>
              {' 各自独立计时 '}
            </Box>
            ：可以只启动这个（玩家屏幕上什么都不显示）、也可以两个一起跑；
            <Box inline bold>
              {' 这个归零时就播放 '}
            </Box>
            。想让「明面走一段之后才播」⇒ 把它填得比明面短即可。
          </Box>
          <Box mt={0.5}>
            <Button.Checkbox
              checked={music_follow_screen}
              onClick={() =>
                act('set_follow', { follow: !music_follow_screen })
              }
            >
              跟随明面倒计时一起启动（勾上后点上面的「开始倒计时」即可，同长、到时自动播放）
            </Button.Checkbox>
          </Box>
          {music_follow_screen && music_selection.length === 0 && (
            <Box mt={0.5} color="bad" bold>
              ⚠ 未勾选曲目 ⇒ 跟随不生效
            </Box>
          )}
          <Stack align="center" mt={0.5}>
            <Stack.Item width="4rem">时长</Stack.Item>
            <Stack.Item width="9rem">
              <Stack align="center">
                <Stack.Item width="4.5rem">
                  <NumberInput
                    fluid
                    minValue={0}
                    maxValue={60}
                    step={1}
                    unit="分"
                    value={Math.floor(musicDuration / 60)}
                    onChange={(value) => {
                      const next =
                        Math.max(Math.round(value), 0) * 60 + (musicDuration % 60);
                      setMusicDuration(next);
                      act('set_music_duration', { seconds: next });
                    }}
                  />
                </Stack.Item>
                <Stack.Item width="4.5rem">
                  <NumberInput
                    fluid
                    minValue={0}
                    maxValue={59}
                    step={1}
                    unit="秒"
                    value={musicDuration % 60}
                    onChange={(value) => {
                      const next =
                        Math.floor(musicDuration / 60) * 60 +
                        Math.max(Math.min(Math.round(value), 59), 0);
                      setMusicDuration(next);
                      act('set_music_duration', { seconds: next });
                    }}
                  />
                </Stack.Item>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Button
                color={music_state ? 'bad' : 'good'}
                icon={music_state ? 'stop' : 'play'}
                onClick={() =>
                  act(music_state ? 'stop_music' : 'start_music', {
                    music_seconds: musicDuration,
                  })
                }
              >
                {music_state ? '停止内部倒计时' : '启动内部倒计时'}
              </Button>
            </Stack.Item>
            <Stack.Item color="label">
              {music_state
                ? `进行中，剩余 ${Math.max(Math.round(music_remaining), 0)} 秒`
                : music_duration > 0
                  ? `未启动（上次设定 ${Math.floor(music_duration / 60)} 分 ${music_duration % 60} 秒）`
                  : '未启动（时长 0:00 ⇒ 与明面同长）'}
            </Stack.Item>
          </Stack>
          <Box mt={0.5} color="label">
            时长填 0:00 ⇒ 与明面倒计时同长（明面结束时正好播放）；
            填比如 1 分 0 秒 ⇒ 明面走到第 60 秒就播放（配合上面的「跟随」一次点击即可）。
          </Box>
        </Section>

        <Section title="曲目与传输（给上面的内部倒计时用）">
          <Stack vertical>
            <Stack.Item>
              <Button.Checkbox
                checked={silent}
                onClick={() => act('set_silent', { silent: !silent })}
              >
                纯准备模式（倒计时不给玩家显示，只在本面板里走）
              </Button.Checkbox>
            </Stack.Item>

            <Stack.Item>
              <Stack align="center">
                <Stack.Item grow>
                  <Box bold>曲目（来自点唱机曲库 / 管理员上传的音频）</Box>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="upload"
                    tooltip="复用「点唱机上传音乐」（文件名需 标题+节拍.ogg）"
                    onClick={() => act('upload_music')}
                  >
                    上传音频
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="rotate"
                    tooltip="上传完成后点一下，新曲目立刻出现在列表里"
                    onClick={() => act('refresh_music')}
                  >
                    刷新列表
                  </Button>
                </Stack.Item>
              </Stack>
              <Box height="9rem" overflowY="auto" mt={0.5}>
                {music_catalog.length === 0 && (
                  <Box color="bad">
                    点唱机曲库为空 —— 先用「点唱机上传音乐」上传 .ogg
                  </Box>
                )}
                {music_catalog.map((song) => {
                  const selected = music_selection.includes(song.key);
                  return (
                    <Stack key={song.key} align="center">
                      <Stack.Item grow>
                        <Button.Checkbox
                          checked={selected}
                          onClick={() => {
                            const next = selected
                              ? music_selection.filter((k) => k !== song.key)
                              : [...music_selection, song.key];
                            act('set_music', { selection: next });
                          }}
                        >
                          {song.name}
                        </Button.Checkbox>
                      </Stack.Item>
                      <Stack.Item>
                        <Button
                          icon="headphones"
                          tooltip="试听（只有你能听见）"
                          onClick={() => act('preview_music', { song: song.key })}
                        />
                      </Stack.Item>
                    </Stack>
                  );
                })}
              </Box>
            </Stack.Item>

            <Stack.Item>
              <Stack align="center">
                <Stack.Item width="7rem">音量</Stack.Item>
                <Stack.Item grow>
                  <NumberInput
                    fluid
                    minValue={1}
                    maxValue={100}
                    unit="%"
                    value={music_volume}
                    onChange={(value) =>
                      act('set_music_volume', { volume: value })
                    }
                  />
                </Stack.Item>
              </Stack>
            </Stack.Item>

            <Stack.Item>
              <Stack align="center">
                <Stack.Item width="7rem">传输节奏</Stack.Item>
                <Stack.Item grow>
                  <NumberInput
                    fluid
                    minValue={0}
                    maxValue={600}
                    step={1}
                    unit="秒/份"
                    value={music_rate_manual}
                    onChange={(value) => act('set_music_rate', { rate: value })}
                  />
                </Stack.Item>
                <Stack.Item width="17rem" color="label">
                  0 = 自动（当前 {music_interval.toFixed(1)} 秒/份；只有一首歌时 =「秒/人」）
                </Stack.Item>
              </Stack>
            </Stack.Item>

            <Stack.Item>
              <Stack align="center">
                <Stack.Item grow>
                  <Box bold>
                    传输状态（已选 {music_selection.length} 首 · 在线{' '}
                    {music_status.online_count} 人 · 就绪{' '}
                    {music_status.ready_count} 人）
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="table-list"
                    tooltip="表格版：按玩家数铺开，每人一条进度条"
                    onClick={() => act('open_transfer')}
                  >
                    查看传输详情
                  </Button>
                </Stack.Item>
              </Stack>
              <Box color="label" mt={0.5}>
                玩家多时点「查看传输详情」：那边按人数自动换行铺成表格，每个玩家名字下面一条进度条。
              </Box>
            </Stack.Item>
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};


