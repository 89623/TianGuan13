// THIS IS A TIANGUAN UI FILE
// 模块：admin_sound_board —— 全局音效面板 · 传输详情（由主面板的「查看传输详情」按钮打开）
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
  left: boolean;
};

type Data = {
  interval: number;
  status: {
    players: PlayerRow[];
    ready_count: number;
    online_count: number;
    total: number;
    queue_left: number;
  };
};

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
      <Box bold color={!player.online ? 'bad' : player.ready ? 'good' : undefined}>
        {player.name}
        {player.online ? '' : '（离线）'}
      </Box>
      <ProgressBar value={ratio} mt={0.3}>
        {player.pushed}/{player.total}
      </ProgressBar>
    </Box>
  );
};

export const TianGuanSoundBoardTransfer = () => {
  const { data } = useBackend<Data>();
  const { interval, status } = data;
  return (
    <Window title="全局音效 · 传输详情" width={760} height={620}>
      <Window.Content scrollable>
        <Section title="总览">
          <Box>
            音频 {status.total} 首 · 在线 {status.online_count} 人 · 已登记{' '}
            {status.players.length} 人 · 已就绪 {status.ready_count} 人
          </Box>
          <Box mt={0.5}>
            每份间隔 {Number(interval).toFixed(1)} 秒 · 队列剩余 {status.queue_left} 份
          </Box>
          <Box mt={0.5} color="label">
            一份 = 一个在线玩家的一份音频。进度是**服务端已推送**的量；
            新加入的玩家会每秒自动补传。
          </Box>
        </Section>

        <Section title="玩家">
          {status.players.length === 0 ? (
            <Box color="label">（还没有需要传输的音频）</Box>
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
