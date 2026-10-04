// THIS IS A TIANGUAN UI FILE
// 倒计时 · 传输详情（由全局倒计时面板的「查看传输详情」按钮打开）
//
// 为什么单独开一个界面：玩家数常有五六十人，主面板里那条窄列表根本铺不开。
// 这里用可换行的网格铺开，**每个玩家名字下面一条小进度条**，一眼能看出谁还没传完。

import { useBackend } from '../backend';
import { Box, ProgressBar, Section } from 'tgui-core/components';
import { Window } from '../layouts';

/** 一个玩家：已推送份数 / 总份数 + 是否推完 */
type PlayerRow = {
  ckey: string;
  name: string;
  pushed: number;
  total: number;
  ready: boolean;
  online: boolean;
};

type Data = {
  state: number;
  remaining: number;
  silent: boolean;
  music_interval: number;
  rate_manual: number;
  selection_count: number;
  queue_left: number;
  status: {
    players: PlayerRow[];
    ready_count: number;
    online_count: number;
    total: number;
  };
};

const STATE_TEXT = ['未设置', '倒计时中', '已暂停', '结束文本中'];

/** 单个玩家的小卡片：名字一行、下面一条进度条 */
const PlayerTile = (props: { player: PlayerRow }) => {
  const { player } = props;
  const ratio = player.total ? player.pushed / player.total : 0;
  return (
    <Box
      width="12.5rem"
      mr={0.5}
      mb={0.5}
      p={0.5}
      backgroundColor="rgba(0, 0, 0, 0.25)"
    >
      <Box
        bold
        color={!player.online ? 'bad' : player.ready ? 'good' : undefined}
      >
        {player.name}
        {player.online ? '' : '（离线）'}
      </Box>
      <ProgressBar value={ratio} mt={0.3}>
        {player.pushed}/{player.total}
      </ProgressBar>
    </Box>
  );
};

export const TianGuanCountdownTransfer = () => {
  const { data } = useBackend<Data>();
  const {
    state,
    remaining,
    silent,
    music_interval,
    rate_manual,
    selection_count,
    queue_left,
    status,
  } = data;
  return (
    <Window title="倒计时 · 传输详情" width={760} height={620}>
      <Window.Content scrollable>
        <Section title="总览">
          <Box>
            状态：{STATE_TEXT[state] ?? '未知'}
            {state === 1 ? `（剩余 ${Math.max(Math.round(remaining), 0)} 秒）` : ''}
            {silent ? ' · 纯准备模式' : ''}
          </Box>
          <Box mt={0.5}>
            已选 {selection_count} 首 · 节奏：
            {rate_manual > 0
              ? `手动 ${rate_manual} 秒/份`
              : `自动 ${music_interval.toFixed(1)} 秒/份`}
            {' · '}队列剩余 {queue_left} 份
          </Box>
          <Box mt={0.5} color="label">
            一份 = 一个玩家的一首歌（只有一首歌时就是「秒/人」）。进度是**服务端已推送**的量。
          </Box>
        </Section>

        <Section
          title={`玩家（在线 ${status.online_count} · 已登记 ${status.players.length} · 就绪 ${status.ready_count}）`}
        >
          {status.players.length === 0 ? (
            <Box color="label">（尚未开始传输）</Box>
          ) : (
            <Box style={{ display: 'flex', flexWrap: 'wrap' }}>
              {status.players.map((player) => (
                <PlayerTile key={player.ckey} player={player} />
              ))}
            </Box>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
