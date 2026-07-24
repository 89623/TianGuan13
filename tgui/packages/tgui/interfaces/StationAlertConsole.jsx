import { sortBy } from 'es-toolkit';
import { Button, Section, Stack } from 'tgui-core/components';

import { useBackend } from '../backend';
// NOVA EDIT ADDITION - i18n: 类目标题是 `${category.name} Alarms` 模板串（服务端类目名 + 字面
// "Alarms" 客户端拼接），jsx-runtime 自动本地化只处理静态文本、不碰动态串。用 translateCurrent
// 拿拼好的英文整串（"Fire Alarms" 等）当键查目录（英文键→中文），缺翻译时回落英文。
import { translateCurrent } from '../i18n';
import { Window } from '../layouts';

export const StationAlertConsole = (props) => {
  const { data } = useBackend();
  const { cameraView } = data;
  return (
    <Window width={cameraView ? 390 : 345} height={587}>
      <Window.Content scrollable>
        <StationAlertConsoleContent />
      </Window.Content>
    </Window>
  );
};

export const StationAlertConsoleContent = (props) => {
  const { act, data } = useBackend();
  const { cameraView } = data;

  const sortingKey = {
    Fire: 0,
    Atmosphere: 1,
    Power: 2,
    Burglar: 3,
    Motion: 4,
    Camera: 5,
  };

  const sortedAlarms = sortBy(data.alarms || [], [
    (alarm) => sortingKey[alarm.name],
  ]);

  return (
    <>
      {sortedAlarms.map((category) => (
        <Section
          key={category.name}
          title={translateCurrent(`${category.name} Alarms`)}
        >
          <ul>
            {category.alerts.length === 0 && (
              <li className="color-good">Systems nominal</li>
            )}
            {category.alerts.map((alert) => (
              <Stack key={alert.name} height="30px" align="baseline">
                <Stack.Item grow>
                  <li className="color-average">
                    {alert.name}{' '}
                    {cameraView && alert.sources > 1
                      ? ` (${alert.sources} sources)`
                      : ''}
                  </li>
                </Stack.Item>
                {!!cameraView && (
                  <Stack.Item>
                    <Button
                      textAlign="center"
                      width="100px"
                      icon={alert.cameras ? 'video' : ''}
                      disabled={!alert.cameras}
                      content={
                        alert.cameras === 1
                          ? `${alert.cameras} Camera`
                          : alert.cameras > 1
                            ? `${alert.cameras} Cameras`
                            : 'No Camera'
                      }
                      onClick={() =>
                        act('select_camera', {
                          alert: alert.ref,
                        })
                      }
                    />
                  </Stack.Item>
                )}
              </Stack>
            ))}
          </ul>
        </Section>
      ))}
    </>
  );
};
