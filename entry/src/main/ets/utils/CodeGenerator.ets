import { ComponentItem, isContainer } from '../model/ComponentModel';

/**
 * Turns the component tree into a standalone .ets page that DevEco Studio can compile.
 * The generated page keeps the same nesting, styles and inline event handlers the user
 * configured on the canvas.
 */
export class CodeGenerator {
  private needsWebview: boolean = false;
  private webCount: number = 0;
  private canvasCount: number = 0;

  generate(roots: ComponentItem[]): string {
    this.needsWebview = false;
    this.webCount = 0;
    this.canvasCount = 0;

    let body: string;
    if (roots.length === 0) {
      body = `${this.pad(2)}Column() {\n${this.pad(3)}Text('从左侧拖入组件开始搭建页面')\n${this.pad(4)}.fontColor('#99191919')\n${this.pad(2)}}`;
    } else if (roots.length === 1) {
      body = this.emit(roots[0], 2);
    } else {
      body = `${this.pad(2)}Column() {\n${this.emitAll(roots, 3)}\n${this.pad(2)}}`;
    }

    const members: string[] = [];
    for (let i = 0; i < this.webCount; i++) {
      members.push(`  private webController${i}: webview.WebviewController = new webview.WebviewController();`);
    }
    for (let i = 0; i < this.canvasCount; i++) {
      members.push(`  private ctx${i}: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));`);
    }

    let code = '';
    if (this.needsWebview) {
      code += 'import { webview } from \'@kit.ArkWeb\';\n\n';
    }
    code += '@Entry\n@Component\nstruct GeneratedPage {\n';
    if (members.length > 0) {
      code += `${members.join('\n')}\n\n`;
    }
    code += `  build() {\n${body}\n  }\n}\n`;
    return code;
  }

  private emit(node: ComponentItem, level: number): string {
    const pad = this.pad(level);
    return `${pad}${this.headOf(node)}${this.emitChildren(node, level)}${this.styleChain(node, level)}`;
  }

  private emitChildren(node: ComponentItem, level: number): string {
    if (!isContainer(node.type)) {
      return '';
    }
    const pad = this.pad(level);
    const childLevel = level + 1;

    if (node.children.length === 0) {
      return ` {\n${this.pad(childLevel)}// 拖入子组件\n${pad}}`;
    }

    const parts: string[] = [];
    if (node.type === 'Grid') {
      for (const child of node.children) {
        parts.push(`${this.pad(childLevel)}GridItem() {\n${this.emit(child, childLevel + 1)}\n${this.pad(childLevel)}}`);
      }
    } else if (node.type === 'List') {
      for (const child of node.children) {
        parts.push(`${this.pad(childLevel)}ListItem() {\n${this.emit(child, childLevel + 1)}\n${this.pad(childLevel)}}`);
      }
    } else if (node.type === 'Tabs') {
      const titles = this.tabTitles(node);
      for (let i = 0; i < node.children.length; i++) {
        const title = i < titles.length ? titles[i] : `页签${i + 1}`;
        parts.push(`${this.pad(childLevel)}TabContent() {\n${this.emit(node.children[i], childLevel + 1)}\n${this.pad(childLevel)}}.tabBar('${this.escape(title)}')`);
      }
    } else if (node.type === 'Scroll') {
      // Scroll accepts exactly one child, so multiple nodes are wrapped in a Column.
      parts.push(node.children.length === 1
        ? this.emit(node.children[0], childLevel)
        : `${this.pad(childLevel)}Column() {\n${this.emitAll(node.children, childLevel + 1)}\n${this.pad(childLevel)}}`);
    } else {
      parts.push(this.emitAll(node.children, childLevel));
    }
    return ` {\n${parts.join('\n')}\n${pad}}`;
  }

  private emitAll(children: ComponentItem[], level: number): string {
    const parts: string[] = [];
    for (const child of children) {
      parts.push(this.emit(child, level));
    }
    return parts.join('\n');
  }

  private headOf(node: ComponentItem): string {
    const props = node.props;
    switch (node.type) {
      case 'Text':
        return `Text('${this.escape(this.text(props, 'content', '文本'))}')`;
      case 'Button':
        return `Button('${this.escape(this.text(props, 'label', '按钮'))}')`;
      case 'Image':
        return `Image(${this.imageSource(this.text(props, 'src', ''))})`;
      case 'TextInput':
        return `TextInput({ placeholder: '${this.escape(this.text(props, 'placeholder', ''))}', text: '${this.escape(this.text(props, 'text', ''))}' })`;
      case 'Row':
        return 'Row()';
      case 'Column':
        return 'Column()';
      case 'Stack':
        return 'Stack()';
      case 'Grid': {
        const template = this.text(props, 'columnsTemplate', '');
        return template.length > 0 ? `Grid().columnsTemplate('${this.escape(template)}')` : 'Grid()';
      }
      case 'List':
        return 'List()';
      case 'Scroll':
        return 'Scroll()';
      case 'Tabs': {
        const bar = this.text(props, 'barPosition', 'Start') === 'End' ? 'End' : 'Start';
        const vertical = this.text(props, 'vertical', 'false') === 'true';
        return `Tabs({ barPosition: BarPosition.${bar}, vertical: ${vertical} })`;
      }
      case 'Video': {
        const auto = this.text(props, 'autoPlay', 'false') === 'true';
        return `Video({ src: '${this.escape(this.text(props, 'src', ''))}', autoPlay: ${auto} })`;
      }
      case 'Web': {
        this.needsWebview = true;
        const id = this.webCount;
        this.webCount += 1;
        return `Web({ src: '${this.escape(this.text(props, 'src', 'https://developer.huawei.com'))}', controller: this.webController${id} })`;
      }
      case 'Canvas': {
        const id = this.canvasCount;
        this.canvasCount += 1;
        return `Canvas(this.ctx${id})`;
      }
      default:
        return `${node.type}()`;
    }
  }

  private styleChain(node: ComponentItem, level: number): string {
    // Attributes sit one column deeper than the component head.
    const pad = this.pad(level + 1);
    const style = node.style;
    const props = node.props;
    const attrs: string[] = [];

    if (style.width > 0) {
      attrs.push(`.width(${style.width})`);
    }
    if (style.height > 0) {
      attrs.push(`.height(${style.height})`);
    }

    switch (node.type) {
      case 'Row':
      case 'Column': {
        const justify = this.text(props, 'justifyContent', '');
        const align = this.text(props, 'alignItems', '');
        if (justify.length > 0) {
          attrs.push(`.justifyContent(FlexAlign.${justify})`);
        }
        if (align.length > 0) {
          attrs.push(`.alignItems(VerticalAlign.${align})`);
        }
        const space = this.text(props, 'space', '');
        if (space.length > 0) {
          attrs.push(`.space(${space})`);
        }
        break;
      }
      case 'Text': {
        attrs.push(`.fontSize(${this.number(props, 'fontSize', 16)})`);
        attrs.push(`.fontColor('${this.escape(this.text(props, 'color', '#182431'))}')`);
        attrs.push(`.fontWeight(FontWeight.${this.text(props, 'fontWeight', 'Normal')})`);
        break;
      }
      case 'Button': {
        attrs.push(`.fontSize(${this.number(props, 'fontSize', 16)})`);
        attrs.push(`.backgroundColor('${this.escape(this.text(props, 'bgColor', '#0A59F7'))}')`);
        break;
      }
      case 'Image': {
        attrs.push(`.objectFit(ImageFit.${this.text(props, 'objectFit', 'Cover')})`);
        break;
      }
      case 'TextInput': {
        const kind = this.text(props, 'type', 'normal') === 'password' ? 'Password' : 'Normal';
        attrs.push(`.type(InputType.${kind})`);
        break;
      }
      case 'Stack': {
        const align = this.text(props, 'alignContent', '');
        if (align.length > 0) {
          attrs.push(`.alignContent(Alignment.${align})`);
        }
        break;
      }
      case 'List': {
        const space = this.text(props, 'space', '');
        if (space.length > 0) {
          attrs.push(`.space(${space})`);
        }
        break;
      }
      default:
        break;
    }

    if (style.margin > 0) {
      attrs.push(`.margin(${style.margin})`);
    }
    if (style.padding > 0) {
      attrs.push(`.padding(${style.padding})`);
    }
    if (style.backgroundColor.length > 0 && style.backgroundColor !== '#00000000') {
      attrs.push(`.backgroundColor('${this.escape(style.backgroundColor)}')`);
    }
    if (style.borderRadius > 0) {
      attrs.push(`.borderRadius(${style.borderRadius})`);
    }

    const onClick = this.text(props, 'onClick', '');
    if (onClick.length > 0) {
      attrs.push(`.onClick(() => {\n${this.pad(level + 2)}${onClick}\n${pad}})`);
    }
    const onAppear = this.text(props, 'onAppear', '');
    if (onAppear.length > 0) {
      attrs.push(`.onAppear(() => {\n${this.pad(level + 2)}${onAppear}\n${pad}})`);
    }

    if (attrs.length === 0) {
      return '';
    }
    return `\n${pad}${attrs.join(`\n${pad}`)}`;
  }

  private text(props: Record<string, string>, key: string, fallback: string): string {
    const value = props[key];
    return value === undefined || value.length === 0 ? fallback : value;
  }

  private number(props: Record<string, string>, key: string, fallback: number): number {
    const raw = props[key];
    if (raw === undefined || raw.length === 0) {
      return fallback;
    }
    const parsed = Number.parseInt(raw, 10);
    return Number.isNaN(parsed) ? fallback : parsed;
  }

  private imageSource(src: string): string {
    if (src.length === 0) {
      return '$r(\'app.media.startIcon\')';
    }
    if (src.indexOf('http://') === 0 || src.indexOf('https://') === 0 || src.indexOf('/') === 0) {
      return `'${this.escape(src)}'`;
    }
    return `$r('app.media.${this.escape(src)}')`;
  }

  private tabTitles(node: ComponentItem): string[] {
    const value = node.props['titles'];
    if (value === undefined || value.length === 0) {
      return [];
    }
    return value.split(',');
  }

  private escape(value: string): string {
    let out = '';
    for (const ch of value.split('')) {
      if (ch === '\\') {
        out += '\\\\';
      } else if (ch === '\'') {
        out += '\\\'';
      } else if (ch === '\n') {
        out += ' ';
      } else {
        out += ch;
      }
    }
    return out;
  }

  private pad(level: number): string {
    let out = '';
    for (let i = 0; i < level; i++) {
      out += '  ';
    }
    return out;
  }
}
