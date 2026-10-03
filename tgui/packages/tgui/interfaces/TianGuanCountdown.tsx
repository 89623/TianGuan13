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
  } = data;

  const [inputTitle, setInputTitle] = useState(title);
  const [inputSeconds, setInputSeconds] = useState(60);
  const [inputEndText, setInputEndText] = useState(end_text);
  const [inputEndSeconds, setInputEndSeconds] = useState(end_seconds || 10);
  const [editTitle, setEditTitle] = useState('');
  const [editEndText, setEditEndText] = useState('');
  const [inputTitleColor, setInputTitleColor] = useState(title_color);
  const [inputCountdownColor, setInputCountdownColor] = useState(
    countdown_color,
  );
  const [inputEndColor, setInputEndColor] = useState(end_color);

  const active = state !== 0;

  return (
    <Window title="全局倒计时" width={440} height={640}>
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
              <NumberInput
                fluid
                step={10}
                minValue={10}
                maxValue={36000}
                unit="秒"
                value={inputSeconds}
                onChange={(value) => setInputSeconds(value)}
              />
            </Stack.Item>
            <Stack.Item>
              <Input
                fluid
                placeholder="倒计时结束后出现的文本（可留空）"
                value={inputEndText}
                onChange={setInputEndText}
              />
            </Stack.Item>
            <Stack.Item>
              <NumberInput
                fluid
                step={5}
                minValue={0}
                maxValue={3600}
                unit="秒"
                value={inputEndSeconds}
                onChange={(value) => setInputEndSeconds(value)}
              />
            </Stack.Item>
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
      </Window.Content>
    </Window>
  );
};
