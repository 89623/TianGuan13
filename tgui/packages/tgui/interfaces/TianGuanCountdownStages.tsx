// THIS IS A TIANGUAN UI FILE
// 倒计时 · 标题阶段编辑器（由全局倒计时面板的「编辑标题阶段」按钮打开）
//
// 「阶段」= 倒计时开始后到第 N 分钟（精确到秒）时，把**上方那行标题**换成指定文本。
// 可以设任意多条（= 变几次）；还没到第一条阶段之前显示静态标题。
// 时间按「分 + 秒」输入（读作"开始后第几分钟"），每条还可以单独指定标题颜色。
// 只作用于标题那一行 —— 倒计时数字与结束文本不受影响。
// 单独一个窗口的原因：阶段是「时间点 + 文本 + 颜色」的列表，塞进主面板既挤又容易误触。

import { useBackend } from '../backend';
import {
  Box,
  Button,
  ColorBox,
  Input,
  NumberInput,
  Section,
  Stack,
} from 'tgui-core/components';
import { Window } from '../layouts';

/** 一条阶段：开始后第 at 秒起显示 text（color 为空则用全局标题色） */
type Stage = { at: number; text: string; color: string | null };

type Data = {
  base_title: string;
  total_seconds: number;
  state: number;
  elapsed: number;
  current: string;
  stages: Stage[];
};

/** 秒 ⇒ M:SS */
const fmt = (sec: number) => {
  const safe = Math.max(Math.round(sec), 0);
  return `${Math.floor(safe / 60)}:${String(safe % 60).padStart(2, '0')}`;
};

export const TianGuanCountdownStages = () => {
  const { act, data } = useBackend<Data>();
  const { base_title, total_seconds, state, elapsed, current, stages } = data;
  return (
    <Window title="倒计时 · 标题阶段" width={720} height={560}>
      <Window.Content scrollable>
        <Section title="说明">
          <Box color="label">
            「阶段」= 倒计时开始后到第 N 分钟时，把上方标题换成指定文本；可以设任意多条。
            没到第一条阶段之前显示静态标题。只影响标题那一行，倒计时数字与结束文本不受影响。
            「新增阶段」会自动接着上一条 +1 分钟，所以连点几次就是 1 分、2 分、3 分…各变一次。
          </Box>
          <Box mt={0.5}>
            静态标题：
            <Box inline bold>
              {base_title || '（空）'}
            </Box>
            {' · 总时长 '}
            {fmt(total_seconds)}
            {state === 1 ? ` · 已过 ${fmt(elapsed)}` : ''}
          </Box>
          <Box mt={0.5}>
            当前实际显示：
            <Box inline bold color="good">
              {current || '（不显示标题）'}
            </Box>
          </Box>
        </Section>

        <Section
          title={`阶段（${stages.length} 条）`}
          buttons={
            <Button
              icon="plus"
              color="good"
              tooltip="默认接在上一条之后 1 分钟"
              onClick={() => act('add_stage')}
            >
              新增阶段
            </Button>
          }
        >
          {stages.length === 0 && (
            <Box color="label">（还没有阶段：一直显示静态标题）</Box>
          )}
          {stages.map((stage, index) => (
            <Stack key={index} align="center" mb={0.5}>
              <Stack.Item width="2.2rem" color="label">
                #{index + 1}
              </Stack.Item>
              <Stack.Item width="3.2rem">开始后</Stack.Item>
              <Stack.Item width="6rem">
                <NumberInput
                  fluid
                  minValue={0}
                  maxValue={600}
                  step={1}
                  unit="分"
                  value={Math.floor(stage.at / 60)}
                  onChange={(value) =>
                    act('set_stage', {
                      index: index + 1,
                      at: Math.max(Math.round(value), 0) * 60 + (stage.at % 60),
                    })
                  }
                />
              </Stack.Item>
              <Stack.Item width="6rem">
                <NumberInput
                  fluid
                  minValue={0}
                  maxValue={59}
                  step={1}
                  unit="秒"
                  value={stage.at % 60}
                  onChange={(value) =>
                    act('set_stage', {
                      index: index + 1,
                      at:
                        Math.floor(stage.at / 60) * 60 +
                        Math.max(Math.min(Math.round(value), 59), 0),
                    })
                  }
                />
              </Stack.Item>
              <Stack.Item grow>
                <Input
                  fluid
                  value={stage.text}
                  placeholder="这一阶段起显示的标题"
                  onChange={(value) =>
                    act('set_stage', { index: index + 1, text: value })
                  }
                />
              </Stack.Item>
              <Stack.Item>
                <Stack align="center">
                  <Stack.Item>
                    <ColorBox color={stage.color || undefined} mr={0.5} />
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="eye-dropper"
                      tooltip="给这条阶段单独取色（留空则用全局标题色）"
                      onClick={() =>
                        act('pick_stage_color', { index: index + 1 })
                      }
                    />
                  </Stack.Item>
                </Stack>
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="bad"
                  icon="trash"
                  tooltip="删除这条阶段"
                  onClick={() => act('remove_stage', { index: index + 1 })}
                />
              </Stack.Item>
            </Stack>
          ))}
          {stages.length > 0 && (
            <Box mt={1}>
              <Button
                color="bad"
                icon="eraser"
                onClick={() => act('clear_stages')}
              >
                清空全部阶段
              </Button>
            </Box>
          )}
        </Section>

        <Section title="时间轴预览">
          <Box color="label">
            {fmt(0)}：{base_title || '（空标题）'}
            {stages.map(
              (stage) =>
                ` → ${fmt(stage.at)}：${stage.text || '（空）'}${
                  stage.color ? ` [${stage.color}]` : ''
                }`,
            )}
          </Box>
        </Section>
      </Window.Content>
    </Window>
  );
};
