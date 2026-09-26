// THIS IS A TIANGUAN UI FILE
import {
  Box,
  Button,
  Collapsible,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type GuidePageNode = {
  kind: 'page';
  id: string;
  label: string;
};

type GuideCategoryNode = {
  kind: 'category';
  id: string;
  label: string;
  count: number;
  children: GuideNode[];
};

type GuideNode = GuidePageNode | GuideCategoryNode;

type GuideBrowserData = {
  guide_tree: GuideNode[];
  selected_id: string;
  selected_title: string | null;
  page_url: string | null;
  guide_available: boolean;
  selected_mode: string | null;
  supports_iframe: boolean;
};

type GuideTreeProps = {
  nodes: GuideNode[];
  selectedId: string;
  onSelect: (id: string) => void;
};

const GuideTree = ({ nodes, selectedId, onSelect }: GuideTreeProps) => (
  <>
    {nodes.map((node) => {
      if (node.kind === 'category') {
        return (
          <Collapsible
            key={node.id}
            title={`${node.label}（${node.count}）`}
            child_mt={0}
            childStyles={{ padding: '0.25em 0 0.25em 0.5em' }}
          >
            <GuideTree
              nodes={node.children}
              selectedId={selectedId}
              onSelect={onSelect}
            />
          </Collapsible>
        );
      }

      return (
        <Button
          key={node.id}
          fluid
          selected={node.id === selectedId}
          textAlign="left"
          onClick={() => onSelect(node.id)}
        >
          {node.label}
        </Button>
      );
    })}
  </>
);

/** 指南浏览器：左侧目录来自 config/tianguan/guide_browser.json，右侧是选中条目的详情与打开按钮。
 *
 * 为什么右侧不是"内嵌网页"：目标站点（天关 wiki = Miraheze）对页面发了 X-Frame-Options，
 * BYOND 516 的内置浏览器（WebView2）会照章拒绝渲染 iframe。所以打开方式走 open 字段：
 * 默认在游戏内浏览器（browse()）顶层打开——那里不受该限制。只有当站点允许被内嵌时
 * （条目写 open: "frame"）右侧才直接内嵌。 */
export const GuideBrowser = () => {
  const { act, data } = useBackend<GuideBrowserData>();
  const {
    guide_tree,
    selected_id,
    selected_title,
    page_url,
    guide_available,
    selected_mode,
    supports_iframe,
  } = data;

  const frame_mode = selected_mode === 'frame';
  const to_browser = selected_mode === 'browser';
  // 只有 frame 模式 + 客户端支持内嵌 + 拿到 url 时，右侧才是网页本体
  const embed =
    !!guide_available && frame_mode && supports_iframe && !!page_url;

  return (
    <Window width={1120} height={760} title="指南浏览器">
      <Window.Content>
        <Stack fill>
          <Stack.Item width="360px">
            <Section fill scrollable title="指南目录">
              <GuideTree
                nodes={guide_tree}
                selectedId={selected_id}
                onSelect={(id) => act('select_page', { id })}
              />
            </Section>
          </Stack.Item>
          <Stack.Divider />
          <Stack.Item grow minWidth="0">
            <Section
              fill
              title={selected_title || '指南详情'}
              buttons={
                <Button
                  icon="external-link-alt"
                  disabled={!guide_available || !selected_title}
                  onClick={() => act('open_external')}
                >
                  在系统浏览器打开
                </Button>
              }
            >
              {!guide_available && (
                <NoticeBox danger>
                  指南目录未加载，请管理员检查天关指南配置。
                </NoticeBox>
              )}
              {!!guide_available && !embed && (
                <Stack vertical>
                  <Stack.Item>
                    <Button
                      fluid
                      icon={to_browser ? 'external-link-alt' : 'book-open'}
                      onClick={() => act('open_page')}
                    >
                      {to_browser ? '在系统浏览器打开' : '在游戏内打开'}
                    </Button>
                  </Stack.Item>
                  {!!page_url && (
                    <Stack.Item mt={1}>
                      <Box
                        color="label"
                        fontSize="0.85em"
                        style={{ wordBreak: 'break-all' }}
                      >
                        {page_url}
                      </Box>
                    </Stack.Item>
                  )}
                </Stack>
              )}
              {embed && (
                <iframe
                  key={page_url}
                  src={page_url}
                  title={selected_title || ''}
                  style={{ border: 0, height: '100%', width: '100%' }}
                />
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
