// THIS IS A TIANGUAN UI FILE
// 界面：TianGuanLiquidSiphon —— 轻量化液体虹吸器
import {
  Box,
  Button,
  Icon,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  on: boolean;
  has_cell: boolean;
  cell_name: string | null;
  cell_charge: number;
  cell_raw: number;
  cell_max: number;
  range_tier: number;
  rate_tier: number;
  max_range_tier: number;
  max_rate_tier: number;
  range_sides: number[];
  rates: number[];
};

export const TianGuanLiquidSiphon = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    on,
    has_cell,
    cell_name,
    cell_charge,
    cell_raw,
    cell_max,
    range_tier,
    rate_tier,
    max_range_tier,
    max_rate_tier,
    range_sides,
    rates,
  } = data;

  return (
    <Window title="轻量化液体虹吸器" width={390} height={540}>
      <Window.Content scrollable>
        <Box
          textAlign="center"
          fontSize={1.5}
          color="label"
          style={{ letterSpacing: '0.25em', marginLeft: '0.25em' }}
        >
          ——星 狐
          {/* 齿轮自转：外框限成正方并清掉父级字距，否则旋转轴心会偏离字形中心 */}
          <Box
            inline
            style={{
              display: 'inline-block',
              width: '18px',
              height: '18px',
              lineHeight: '18px',
              textAlign: 'center',
              verticalAlign: 'middle',
              letterSpacing: 'normal',
            }}
          >
            <Icon
              name="cog"
              spin={on}
              color={on ? 'good' : 'gray'}
              style={{
                // 轴心条件：字号与盒高都取【整数偶数 px】，字形墨迹正好是 1em ⇒ 轴心落在整像素上，
                // 界面缩放（如 1.25 倍）也不会把它推成半像素；否则高速旋转时会看出轻微摆动。
                display: 'inline-block',
                fontSize: '18px',
                width: '18px',
                height: '18px',
                lineHeight: '18px',
                transformOrigin: '50% 50%',
              }}
            />
          </Box>
          工 业——
        </Box>

        <Section>
          <Stack>
            <Stack.Item grow basis={0}>
              <Button
                fluid
                icon={on ? 'power-off' : 'play'}
                color={on ? 'bad' : 'good'}
                disabled={!has_cell}
                onClick={() => act('toggle')}
              >
                {on ? '停止' : '启动'}
              </Button>
            </Stack.Item>
            <Stack.Item grow basis={0}>
              <Button
                fluid
                icon="eject"
                disabled={!has_cell}
                onClick={() => act('eject_cell')}
              >
                弹出电池
              </Button>
            </Stack.Item>
          </Stack>
        </Section>

        <Section title="电池">
          {has_cell ? (
            <>
              <ProgressBar
                value={cell_charge}
                minValue={0}
                maxValue={100}
                color={
                  cell_charge > 50 ? 'good' : cell_charge > 20 ? 'average' : 'bad'
                }
              >
                {`${cell_name} — ${cell_charge}%`}
              </ProgressBar>
              <Box mt={0.5} textAlign="right" fontSize={0.9} color="label">
                {`${cell_raw} / ${cell_max}`}
              </Box>
            </>
          ) : (
            <Button fluid icon="battery-empty" disabled>
              未装电池
            </Button>
          )}
        </Section>

        <Section title="范围">
          <Stack wrap>
            {range_sides.slice(0, max_range_tier).map((sides, index) => (
              <Stack.Item key={sides}>
                <Button
                  selected={range_tier === index + 1}
                  onClick={() => act('set_range', { tier: index + 1 })}
                >
                  {sides === 1 ? '仅本格' : `${sides}×${sides}`}
                </Button>
              </Stack.Item>
            ))}
          </Stack>
        </Section>

        <Section title="速率">
          <Stack wrap>
            {rates.slice(0, max_rate_tier).map((rate, index) => (
              <Stack.Item key={rate}>
                <Button
                  selected={rate_tier === index + 1}
                  onClick={() => act('set_rate', { tier: index + 1 })}
                >
                  {`${rate}/秒`}
                </Button>
              </Stack.Item>
            ))}
          </Stack>
        </Section>

        <Section title="零件等级">
          <Stack>
            <Stack.Item grow basis={0}>
              <Box color="label" fontSize={0.9}>
                扫描模块
              </Box>
              <Box fontSize={1.3}>{`${max_range_tier} 级`}</Box>
              <Box color="label" fontSize={0.9}>
                {`范围上限 ${
                  range_sides[max_range_tier - 1] === 1
                    ? '仅本格'
                    : `${range_sides[max_range_tier - 1]}×${range_sides[max_range_tier - 1]}`
                }`}
              </Box>
            </Stack.Item>
            <Stack.Item grow basis={0}>
              <Box color="label" fontSize={0.9}>
                物质仓
              </Box>
              <Box fontSize={1.3}>{`${max_rate_tier} 级`}</Box>
              <Box color="label" fontSize={0.9}>
                {`速率上限 ${rates[max_rate_tier - 1]}/秒`}
              </Box>
            </Stack.Item>
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};
