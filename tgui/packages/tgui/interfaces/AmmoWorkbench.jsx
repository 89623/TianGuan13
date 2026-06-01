// THIS IS A NOVA SECTOR UI FILE
import { useState } from 'react';
import {
  Box,
  Button,
  Collapsible,
  Flex,
  NoticeBox,
  NumberInput,
  ProgressBar,
  RoundGauge,
  Section,
  Stack,
  Table,
  Tabs,
  Tooltip,
} from 'tgui-core/components';
import { toTitleCase } from 'tgui-core/string';

import { useBackend, useSharedState } from '../backend';
import { useT } from '../i18n';
import { Window } from '../layouts';

export const AmmoWorkbench = (props) => {
  const [tab, setTab] = useSharedState('tab', 1);
  const t = useT();
  return (
    <Window width={600} height={600} title={t('ammo_workbench.ui.title')}>
      <Window.Content scrollable>
        <Tabs fluid textAlign="center">
          <Tabs.Tab selected={tab === 1} onClick={() => setTab(1)}>
            {t('ammo_workbench.ui.tab_ammunition')}
          </Tabs.Tab>
          <Tabs.Tab selected={tab === 2} onClick={() => setTab(2)}>
            {t('ammo_workbench.ui.tab_materials')}
          </Tabs.Tab>
        </Tabs>
        {tab === 1 && <AmmunitionsTab />}
        {tab === 2 && <MaterialsTab />}
      </Window.Content>
    </Window>
  );
};

export const AmmunitionsTab = (props) => {
  const { act, data } = useBackend();
  const t = useT();
  const {
    mag_loaded,
    system_busy,
    error,
    error_type,
    mag_name,
    turboBoost,
    current_rounds,
    max_rounds,
    efficiency,
    time,
    caliber,
    datadisk_loaded,
    datadisk_name,
    available_rounds = [],
  } = data;
  return (
    <>
      {!!error && (
        <NoticeBox textAlign="center" color={error_type}>
          {error}
        </NoticeBox>
      )}
      <Section title={t('ammo_workbench.ui.machine_settings')}>
        <Box inline mr={4}>
          {t('ammo_workbench.ui.current_efficiency')}{' '}
          <RoundGauge
            value={efficiency}
            minValue={1.6}
            maxValue={1}
            format={() => null}
          />
        </Box>
        <Box>{t('ammo_workbench.ui.time_per_round', [time])}</Box>
        <Button.Checkbox
          textAlign="right"
          checked={turboBoost}
          onClick={() => act('turboBoost')}
        >
          {t('ammo_workbench.ui.overclock')}
        </Button.Checkbox>
      </Section>
      <Section
        title={t('ammo_workbench.ui.loaded_magazine')}
        buttons={
          <>
            {!!mag_loaded && (
              <Box inline mr={2}>
                <ProgressBar
                  value={current_rounds}
                  minValue={0}
                  maxValue={max_rounds}
                />
              </Box>
            )}
            <Button
              icon="eject"
              content={t('ammo_workbench.ui.eject')}
              disabled={!mag_loaded}
              onClick={() => act('EjectMag')}
            />
          </>
        }
      >
        {!!mag_loaded && <Box>{mag_name}</Box>}
        {!!mag_loaded && (
          <Box bold textAlign="right">
            {current_rounds} / {max_rounds}
          </Box>
        )}
      </Section>
      <Section title={t('ammo_workbench.ui.available_types')}>
        {!!mag_loaded && (
          <Flex.Item grow={1} basis={0}>
            {available_rounds.map((available_round) => (
              <Box
                key={available_round.name}
                className="candystripe"
                p={1}
                pb={2}
              >
                <Stack.Item>
                  <Tooltip
                    content={available_round.mats_list}
                    position={'right'}
                  >
                    <Button
                      content={available_round.name}
                      disabled={system_busy}
                      onClick={() =>
                        act('FillMagazine', {
                          selected_type: available_round.typepath,
                        })
                      }
                    />
                  </Tooltip>
                </Stack.Item>
              </Box>
            ))}
          </Flex.Item>
        )}
      </Section>
      <Section
        title={t('ammo_workbench.ui.module_management')}
        buttons={
          <Button
            icon="eject"
            content={t('ammo_workbench.ui.eject')}
            disabled={!datadisk_loaded}
            onClick={() => act('EjectDisk')}
          />
        }
      >
        {!!datadisk_loaded && (
          <Box>{t('ammo_workbench.ui.loaded_module', [datadisk_name])}</Box>
        )}
        <Collapsible title={t('ammo_workbench.ui.owners_manual')}>
          <Section color="label">
            {t('ammo_workbench.ui.manual_p1')}
            <br />
            <br />
            {t('ammo_workbench.ui.manual_p2')}
          </Section>
        </Collapsible>
      </Section>
    </>
  );
};

export const MaterialsTab = (props) => {
  const { act, data } = useBackend();
  const t = useT();
  const { materials = [] } = data;
  return (
    <Section title={t('ammo_workbench.ui.materials')}>
      <Table>
        {materials
          .filter((material) => material.amount > 0)
          .map((material) => (
            <MaterialRow
              key={material.id}
              material={material}
              onRelease={(amount) =>
                act('Release', {
                  id: material.id,
                  sheets: amount,
                })
              }
            />
          ))}
      </Table>
    </Section>
  );
};

const MaterialRow = (props) => {
  const { material, onRelease } = props;
  const t = useT();

  const [amount, setAmount] = useState(1);

  const amountAvailable = Math.floor(material.amount);
  return (
    <Table.Row>
      <Table.Cell>{toTitleCase(material.name)}</Table.Cell>
      <Table.Cell collapsing textAlign="right">
        <Box mr={2} color="label" inline>
          {t('ammo_workbench.ui.sheets', [amountAvailable])}
        </Box>
      </Table.Cell>
      <Table.Cell collapsing>
        <NumberInput
          width="32px"
          step={1}
          stepPixelSize={5}
          minValue={1}
          maxValue={50}
          value={amount}
          onChange={(value) => setAmount(value)}
        />
        <Button
          disabled={amountAvailable < 1}
          content={t('ammo_workbench.ui.release')}
          onClick={() => onRelease(amount)}
        />
      </Table.Cell>
    </Table.Row>
  );
};
