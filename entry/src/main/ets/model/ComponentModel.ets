/**
 * Component tree model shared by the canvas, the property panel and the code generator.
 *
 * ArkTS forbids `any`, so the document's `Record<string, any>` props are narrowed to
 * `Record<string, string>`; every property value is edited as text and converted at
 * code-generation time.
 */

@Observed
export class ComponentStyle {
  width: number = 120;
  height: number = 40;
  backgroundColor: string = '#00000000';
  borderRadius: number = 0;
  margin: number = 6;
  padding: number = 8;
}

@Observed
export class ComponentItem {
  id: string = '';
  type: string = '';
  props: Record<string, string> = {};
  children: ComponentItem[] = [];
  style: ComponentStyle = new ComponentStyle();
}

export class PaletteEntry {
  type: string = '';
  label: string = '';
  container: boolean = false;
  textProp: string = '';

  constructor(type: string, label: string, container: boolean, textProp: string) {
    this.type = type;
    this.label = label;
    this.container = container;
    this.textProp = textProp;
  }
}

export class PaletteCategory {
  name: string = '';
  entries: PaletteEntry[] = [];

  constructor(name: string, entries: PaletteEntry[]) {
    this.name = name;
    this.entries = entries;
  }
}

export const BASIC: string = '基础组件';
export const LAYOUT: string = '布局组件';
export const MEDIA: string = '媒体组件';
export const CONTAINER: string = '容器组件';

const CONTAINER_TYPES: string[] = ['Row', 'Column', 'Stack', 'Grid', 'Scroll', 'List', 'Tabs'];

export function paletteCategories(): PaletteCategory[] {
  return [
    new PaletteCategory(BASIC, [
      new PaletteEntry('Text', '文本', false, 'content'),
      new PaletteEntry('Button', '按钮', false, 'label'),
      new PaletteEntry('Image', '图片', false, 'src'),
      new PaletteEntry('TextInput', '输入框', false, 'placeholder')
    ]),
    new PaletteCategory(LAYOUT, [
      new PaletteEntry('Row', '横向布局', true, ''),
      new PaletteEntry('Column', '纵向布局', true, ''),
      new PaletteEntry('Stack', '堆叠布局', true, ''),
      new PaletteEntry('Grid', '网格布局', true, '')
    ]),
    new PaletteCategory(MEDIA, [
      new PaletteEntry('Video', '视频', false, 'src'),
      new PaletteEntry('Web', '网页', false, 'src'),
      new PaletteEntry('Canvas', '画布', false, '')
    ]),
    new PaletteCategory(CONTAINER, [
      new PaletteEntry('Scroll', '滚动容器', true, ''),
      new PaletteEntry('List', '列表容器', true, ''),
      new PaletteEntry('Tabs', '页签容器', true, 'titles')
    ])
  ];
}

export function isContainer(type: string): boolean {
  return CONTAINER_TYPES.indexOf(type) >= 0;
}

export function paletteLabel(type: string): string {
  let result: string = type;
  for (const category of paletteCategories()) {
    for (const entry of category.entries) {
      if (entry.type === type) {
        result = entry.label;
      }
    }
  }
  return result;
}

let idSeed: number = 0;

export function nextId(): string {
  idSeed += 1;
  return `n${Date.now().toString(36)}${idSeed.toString(36)}`;
}

export function strProp(props: Record<string, string>, key: string, fallback: string): string {
  const value = props[key];
  return value === undefined || value.length === 0 ? fallback : value;
}

export function numProp(props: Record<string, string>, key: string, fallback: number): number {
  const value = props[key];
  if (value === undefined || value.length === 0) {
    return fallback;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
}

function defaultStyle(type: string): ComponentStyle {
  const style = new ComponentStyle();
  if (isContainer(type)) {
    style.width = 260;
    style.height = 140;
    style.backgroundColor = '#1A007BFF';
    style.borderRadius = 8;
  } else if (type === 'Image') {
    style.width = 96;
    style.height = 96;
  } else if (type === 'Video' || type === 'Web' || type === 'Canvas') {
    style.width = 220;
    style.height = 130;
    style.backgroundColor = '#11000000';
    style.borderRadius = 6;
  } else if (type === 'TextInput') {
    style.width = 200;
  }
  return style;
}

function defaultProps(type: string): Record<string, string> {
  switch (type) {
    case 'Text':
      return { 'content': '文本', 'fontSize': '16', 'color': '#182431', 'fontWeight': 'Normal' };
    case 'Button':
      return { 'label': '按钮', 'fontSize': '16', 'bgColor': '#0A59F7', 'onClick': '' };
    case 'Image':
      return { 'src': 'startIcon', 'objectFit': 'Cover', 'onClick': '' };
    case 'TextInput':
      return { 'placeholder': '请输入内容', 'text': '', 'type': 'normal' };
    case 'Video':
      return { 'src': '', 'autoPlay': 'false' };
    case 'Web':
      return { 'src': 'https://developer.huawei.com' };
    case 'Tabs':
      return { 'titles': '页签一,页签二', 'barPosition': 'Start', 'vertical': 'false' };
    case 'Grid':
      return { 'columnsTemplate': '1fr 1fr' };
    default:
      return {};
  }
}

export function createNode(type: string): ComponentItem {
  const node = new ComponentItem();
  node.id = nextId();
  node.type = type;
  node.props = defaultProps(type);
  node.style = defaultStyle(type);
  return node;
}

export function cloneNode(source: ComponentItem): ComponentItem {
  const copy = new ComponentItem();
  copy.id = nextId();
  copy.type = source.type;
  const props: Record<string, string> = {};
  for (const key of Object.keys(source.props)) {
    props[key] = source.props[key];
  }
  copy.props = props;
  const style = new ComponentStyle();
  style.width = source.style.width;
  style.height = source.style.height;
  style.backgroundColor = source.style.backgroundColor;
  style.borderRadius = source.style.borderRadius;
  style.margin = source.style.margin;
  style.padding = source.style.padding;
  copy.style = style;
  for (const child of source.children) {
    copy.children.push(cloneNode(child));
  }
  return copy;
}

export class TreeLocation {
  parent: ComponentItem | undefined = undefined;
  siblings: ComponentItem[] = [];
  index: number = -1;

  get node(): ComponentItem | undefined {
    return this.index >= 0 && this.index < this.siblings.length ? this.siblings[this.index] : undefined;
  }
}

export function locate(list: ComponentItem[], id: string, parent?: ComponentItem): TreeLocation | undefined {
  for (let i = 0; i < list.length; i++) {
    const item = list[i];
    if (item.id === id) {
      const location = new TreeLocation();
      location.parent = parent;
      location.siblings = list;
      location.index = i;
      return location;
    }
    const nested = locate(item.children, id, item);
    if (nested !== undefined) {
      return nested;
    }
  }
  return undefined;
}

export function findNode(list: ComponentItem[], id: string): ComponentItem | undefined {
  const location = locate(list, id);
  return location === undefined ? undefined : location.node;
}

export function containsNode(list: ComponentItem[], id: string, targetId: string): boolean {
  const location = locate(list, id);
  const node = location === undefined ? undefined : location.node;
  if (node === undefined) {
    return false;
  }
  return locate(node.children, targetId) !== undefined;
}

export function removeNode(list: ComponentItem[], id: string): ComponentItem | undefined {
  const location = locate(list, id);
  if (location === undefined) {
    return undefined;
  }
  return location.siblings.splice(location.index, 1)[0];
}

/** Insert `node` before `targetId`, or append to `list` when no target is given. */
export function insertBefore(list: ComponentItem[], node: ComponentItem, targetId: string): void {
  let index = -1;
  for (let i = 0; i < list.length; i++) {
    if (list[i].id === targetId) {
      index = i;
      break;
    }
  }
  if (index >= 0) {
    list.splice(index, 0, node);
  } else {
    list.push(node);
  }
}

export function reorder(list: ComponentItem[], dragId: string, targetId: string): void {
  if (dragId === targetId || containsNode(list, dragId, targetId)) {
    return;
  }
  const target = locate(list, targetId);
  if (target === undefined) {
    return;
  }
  const moved = removeNode(list, dragId);
  if (moved === undefined) {
    return;
  }
  insertBefore(target.siblings, moved, targetId);
}

/** Drop `dragId` into container `containerId`, or next to `targetId` inside its parent. */
export function dropInto(list: ComponentItem[], dragId: string, containerId: string, targetId: string): void {
  if (dragId === containerId || dragId === targetId) {
    return;
  }
  const container = containerId.length > 0 ? findNode(list, containerId) : undefined;
  if (container !== undefined && !containsNode(list, dragId, containerId)) {
    const moved = removeNode(list, dragId);
    if (moved !== undefined) {
      container.children.push(moved);
    }
    return;
  }
  if (targetId.length > 0) {
    reorder(list, dragId, targetId);
  }
}

export function moveZOrder(list: ComponentItem[], id: string, direction: string): void {
  const location = locate(list, id);
  if (location === undefined) {
    return;
  }
  const siblings = location.siblings;
  const from = location.index;
  let to = from;
  if (direction === 'up' && from > 0) {
    to = from - 1;
  } else if (direction === 'down' && from < siblings.length - 1) {
    to = from + 1;
  } else if (direction === 'top') {
    to = 0;
  } else if (direction === 'bottom') {
    to = siblings.length - 1;
  }
  if (to === from) {
    return;
  }
  const moved = siblings.splice(from, 1)[0];
  siblings.splice(to, 0, moved);
}

export const CANVAS_KEY: string = 'canvas';

/**
 * Resolves a released drag into a tree mutation.
 * `kind` is 'palette' for a new component and 'node' for a move; `targetKey` is the
 * frame the pointer was over, either CANVAS_KEY or a node id.
 * Returns the id that should stay selected after the drop.
 */
export function applyDrop(tree: ComponentItem[], kind: string, type: string, dragId: string, targetKey: string): string {
  let list = tree;
  let targetId = '';

  if (targetKey !== CANVAS_KEY) {
    const hit = findNode(tree, targetKey);
    if (hit !== undefined) {
      if (isContainer(hit.type)) {
        list = hit.children;
      } else {
        const location = locate(tree, targetKey);
        if (location !== undefined) {
          list = location.siblings;
          targetId = targetKey;
        }
      }
    }
  }

  if (kind === 'palette') {
    const created = createNode(type);
    insertBefore(list, created, targetId);
    return created.id;
  }

  if (dragId.length === 0 || dragId === targetKey) {
    return dragId;
  }
  if (containsNode(tree, dragId, targetKey)) {
    return dragId;
  }
  const moved = removeNode(tree, dragId);
  if (moved !== undefined) {
    insertBefore(list, moved, targetId);
  }
  return dragId;
}

export class PropField {
  key: string = '';
  label: string = '';
  kind: string = 'text';   // 'text' | 'number' | 'enum' | 'event'
  options: string[] = [];

  constructor(key: string, label: string, kind: string, options: string[]) {
    this.key = key;
    this.label = label;
    this.kind = kind;
    this.options = options;
  }
}

export function propSchema(type: string): PropField[] {
  const event: PropField = new PropField('onClick', 'onClick 事件', 'event', []);
  switch (type) {
    case 'Text':
      return [
        new PropField('content', '文本内容', 'text', []),
        new PropField('fontSize', '字号', 'number', []),
        new PropField('color', '字体颜色', 'text', []),
        new PropField('fontWeight', '字重', 'enum', ['Lighter', 'Normal', 'Bold', 'Bolder'])
      ];
    case 'Button':
      return [
        new PropField('label', '按钮文字', 'text', []),
        new PropField('fontSize', '字号', 'number', []),
        new PropField('bgColor', '按钮颜色', 'text', []),
        event
      ];
    case 'Image':
      return [
        new PropField('src', '资源名或链接', 'text', []),
        new PropField('objectFit', '填充方式', 'enum', ['Cover', 'Contain', 'Fill', 'None']),
        event
      ];
    case 'TextInput':
      return [
        new PropField('placeholder', '占位文本', 'text', []),
        new PropField('text', '初始内容', 'text', []),
        new PropField('type', '输入类型', 'enum', ['normal', 'password', 'email', 'number'])
      ];
    case 'Row':
    case 'Column':
      return [
        new PropField('justifyContent', '主轴对齐', 'enum', ['Start', 'Center', 'End', 'SpaceBetween', 'SpaceAround']),
        new PropField('alignItems', '交叉轴对齐', 'enum', ['Top', 'Center', 'Bottom']),
        new PropField('space', '子组件间距', 'number', [])
      ];
    case 'Stack':
      return [new PropField('alignContent', '对齐方式', 'enum', ['TopStart', 'Center', 'BottomEnd'])];
    case 'Grid':
      return [new PropField('columnsTemplate', '列模板', 'text', [])];
    case 'List':
      return [new PropField('space', '列表间距', 'number', [])];
    case 'Scroll':
      return [];
    case 'Tabs':
      return [
        new PropField('titles', '页签标题（逗号分隔）', 'text', []),
        new PropField('barPosition', '页签位置', 'enum', ['Start', 'End']),
        new PropField('vertical', '纵向页签', 'enum', ['false', 'true'])
      ];
    case 'Video':
      return [
        new PropField('src', '视频地址', 'text', []),
        new PropField('autoPlay', '自动播放', 'enum', ['false', 'true'])
      ];
    case 'Web':
      return [new PropField('src', '网页地址', 'text', [])];
    case 'Canvas':
      return [];
    default:
      return [];
  }
}

export function countNodes(list: ComponentItem[]): number {
  let total = 0;
  for (const item of list) {
    total += 1 + countNodes(item.children);
  }
  return total;
}

/** Depth-first list of every node, used for hit testing and outline rendering. */
export function flatten(list: ComponentItem[], out: ComponentItem[]): void {
  for (const item of list) {
    out.push(item);
    flatten(item.children, out);
  }
}

export class AiStyleDto {
  width?: number;
  height?: number;
  backgroundColor?: string;
  borderRadius?: number;
  margin?: number;
  padding?: number;
}

export class AiNodeDto {
  type?: string;
  props?: Record<string, string>;
  style?: AiStyleDto;
  children?: AiNodeDto[];
}

export function nodeFromDto(dto: AiNodeDto): ComponentItem {
  const type = dto.type === undefined ? 'Column' : dto.type;
  const node = createNode(type);
  if (dto.props !== undefined) {
    for (const key of Object.keys(dto.props)) {
      node.props[key] = dto.props[key];
    }
  }
  const style = dto.style;
  if (style !== undefined) {
    const merged = new ComponentStyle();
    merged.width = node.style.width;
    merged.height = node.style.height;
    merged.backgroundColor = node.style.backgroundColor;
    merged.borderRadius = node.style.borderRadius;
    merged.margin = node.style.margin;
    merged.padding = node.style.padding;
    if (style.width !== undefined) {
      merged.width = style.width;
    }
    if (style.height !== undefined) {
      merged.height = style.height;
    }
    if (style.backgroundColor !== undefined) {
      merged.backgroundColor = style.backgroundColor;
    }
    if (style.borderRadius !== undefined) {
      merged.borderRadius = style.borderRadius;
    }
    if (style.margin !== undefined) {
      merged.margin = style.margin;
    }
    if (style.padding !== undefined) {
      merged.padding = style.padding;
    }
    node.style = merged;
  }
  if (dto.children !== undefined) {
    const children: ComponentItem[] = [];
    for (const child of dto.children) {
      children.push(nodeFromDto(child));
    }
    node.children = children;
  }
  return node;
}

export function treeFromJson(json: string): ComponentItem[] {
  const parsed = JSON.parse(json) as AiNodeDto;
  const roots: ComponentItem[] = [];
  if (parsed.type !== undefined) {
    roots.push(nodeFromDto(parsed));
  }
  if (parsed.children !== undefined) {
    for (const child of parsed.children) {
      roots.push(nodeFromDto(child));
    }
  }
  return roots;
}
