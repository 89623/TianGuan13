import { Button, Section } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

export const Holodeck = (props) => {
  const { act, data } = useBackend();
  const { can_toggle_safety, emagged, program } = data;
  const default_programs = data.default_programs || [];
  const emag_programs = data.emag_programs || [];
  // NOVA EDIT - I18N - strip the "Holodeck - " prefix by its " - " separator instead of a fixed
  // offset; substring(11) was calibrated for the English prefix and cut the translated name
  // ("全息甲板 - X") at the wrong place / to empty, making most programs look like they vanished.
  const stripProgramPrefix = (name) => name.replace(/^.+? - /, '');
  return (
    <Window width={400} height={500}>
      <Window.Content scrollable>
        <Section
          title="Default Programs"
          buttons={
            <Button
              icon={emagged ? 'unlock' : 'lock'}
              content="Safeties"
              color="bad"
              disabled={!can_toggle_safety}
              selected={!emagged}
              onClick={() => act('safety')}
            />
          }
        >
          {default_programs.map((def_program) => (
            <Button
              fluid
              key={def_program.id}
              content={stripProgramPrefix(def_program.name)}
              textAlign="center"
              selected={def_program.id === program}
              onClick={() =>
                act('load_program', {
                  id: def_program.id,
                })
              }
            />
          ))}
        </Section>
        {!!emagged && (
          <Section title="Dangerous Programs">
            {emag_programs.map((emag_program) => (
              <Button
                fluid
                key={emag_program.id}
                content={stripProgramPrefix(emag_program.name)}
                color="bad"
                textAlign="center"
                selected={emag_program.id === program}
                onClick={() =>
                  act('load_program', {
                    id: emag_program.id,
                  })
                }
              />
            ))}
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
