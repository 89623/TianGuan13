// THIS IS A TIANGUAN UI FILE
// 模块：admin_sound_board —— 管理员「全局音效面板」
//
// 为什么要有这个面板
// ----------------
// 原版「播放全局音效」是在**播放那一刻**给每个在线玩家各发一份音频：几十人同时拉同一个文件
// ⇒ 瞬时占满带宽 ⇒ 卡顿。这里把「上传」与「播放」之间插一个**预传输**阶段：
//   上传 → 自动开始逐份推送 → **全部就绪后播放按钮才亮** → 之后可反复播（本局一直保留）。
// 中途新加入的玩家由服务端每秒自动补传，不用管理员操心。

import { useBackend } from '../backend';
import { Box, Button, NumberInput, Section, Stack } from 'tgui-core/components';
import { Window } from '../layouts';

/** 一首音频：就绪人数 / 在线人数 + 能不能播 */
type TrackRow = {
  key: string;
  name: string;
  ready: number;
  total: number;
  can_play: boolean;
  enabled: boolean;
};

type Data = {
  volume: number;
  interval: number;
  playing_file: string | null;
  tracks: TrackRow[];
  summary: {
    players: {
      ckey: string;
      name: string;
      pushed: number;
      total: number;
      ready: boolean;
      online: boolean;
      left: boolean;
    }[];
    ready_count: number;
    online_count: number;
    total: number;
    queue_left: number;
  };
};

export const TianGuanSoundBoard = () => {
  const { act, data } = useBackend<Data>();
  const { volume, interval, playing_file, tracks, summary } = data;
  return (
    <Window title="全局音效面板" width={620} height={700}>
      <Window.Content scrollable>
        <Section title="上传">
          <Stack align="center">
            <Stack.Item>
              <Button icon="upload" onClick={() => act('upload')}>
                上传音频
              </Button>
            </Stack.Item>
            <Stack.Item color="label">
              上传的会自动开始传输；曲库里已有的点「传输」才传
            </Stack.Item>
          </Stack>
          <Stack align="center" mt={0.5}>
            <Stack.Item width="4rem">音量</Stack.Item>
            <Stack.Item width="9rem">
              <NumberInput
                value={volume}
                minValue={1}
                maxValue={100}
                step={5}
                onChange={(value) => act('set_volume', { volume: value })}
              />
            </Stack.Item>
            <Stack.Item width="8rem">每份间隔（秒）</Stack.Item>
            <Stack.Item width="9rem">
              <NumberInput
                value={interval}
                minValue={0.5}
                maxValue={60}
                step={0.5}
                onChange={(value) => act('set_interval', { interval: value })}
              />
            </Stack.Item>
          </Stack>
          <Box mt={0.5} color="label">
            一份 = 一个在线玩家的一份音频；间隔越小越快，但峰值也越高。
          </Box>
        </Section>

        <Section title={`音频（在线 ${summary.online_count} 人 · 待推 ${summary.queue_left} 份）`}>
          <Stack mb={0.5}>
            <Stack.Item>
              <Button icon="list" onClick={() => act('open_transfer')}>
                查看传输详情
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button icon="rotate" onClick={() => act('refresh')}>
                立即补传新玩家
              </Button>
            </Stack.Item>
            <Stack.Item grow textAlign="right">
              <Button
                icon="stop"
                color="bad"
                disabled={!playing_file}
                onClick={() => act('stop')}
              >
                停止播放
              </Button>
            </Stack.Item>
          </Stack>
          {tracks.length === 0 ? (
            <Box color="label">（目录里还没有音频，先上传一个）</Box>
          ) : (
            tracks.map((track) => {
              const playing = playing_file === track.key;
              return (
                <Stack key={track.key} align="center" mt={0.5}>
                  <Stack.Item grow>
                    <Box bold={playing} color={playing ? 'good' : undefined}>
                      {track.name}
                    </Box>
                  </Stack.Item>
                  <Stack.Item width="9rem" color="label">
                    {!track.enabled
                      ? '未传输'
                      : track.can_play
                        ? `已就绪 ${track.ready}/${track.total}`
                        : `传输中 ${track.ready}/${track.total}`}
                  </Stack.Item>
                  <Stack.Item>
                    {!track.enabled && (
                      <Button
                        icon="upload"
                        tooltip="让这首开始给在线玩家传输"
                        onClick={() => act('transfer', { key: track.key })}
                      >
                        传输
                      </Button>
                    )}
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="play"
                      color={track.can_play ? 'good' : undefined}
                      disabled={!track.can_play}
                      tooltip={
                        track.can_play
                          ? '所有在线玩家都已传完，可以播（可重复点）'
                          : '还在传输，传完自动变亮'
                      }
                      onClick={() => act('play', { key: track.key })}
                    >
                      {playing ? '正在播放' : '播放'}
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="trash"
                      color="bad"
                      tooltip="从服务器上删掉这个音频（会从点唱机曲库里消失，不可恢复）"
                      onClick={() => act('remove', { key: track.key })}
                    >
                      移除
                    </Button>
                  </Stack.Item>
                </Stack>
              );
            })
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
