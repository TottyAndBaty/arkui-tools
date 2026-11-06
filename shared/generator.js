/*
 * Component tree -> ArkTS (.ets) page.
 * Behavioural twin of entry/src/main/ets/utils/CodeGenerator.ets: same nesting, same
 * attribute order, so code copied out of the browser tool matches what the HarmonyOS app
 * previews and exports.
 */
(function (root, factory) {
  const registry = typeof module !== 'undefined' && module.exports
    ? require('./registry.js')
    : root.ArkUIRegistry;
  const api = factory(registry);
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  } else {
    root.ArkUICodeGenerator = api;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function (registry) {
  function text(props, key, fallback) {
    const value = props ? props[key] : undefined;
    return value === undefined || value === null || String(value).length === 0 ? fallback : String(value);
  }

  function number(props, key, fallback) {
    const value = props ? props[key] : undefined;
    if (value === undefined || value === null || String(value).length === 0) {
      return fallback;
    }
    const parsed = parseInt(String(value), 10);
    return Number.isNaN(parsed) ? fallback : parsed;
  }

  function pad(level) {
    return '  '.repeat(Math.max(0, level));
  }

  function escape(value) {
    return String(value).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\n/g, ' ');
  }

  function imageSource(src) {
    if (!src) {
      return "$r('app.media.startIcon')";
    }
    if (src.indexOf('http://') === 0 || src.indexOf('https://') === 0 || src.indexOf('/') === 0) {
      return `'${escape(src)}'`;
    }
    return `$r('app.media.${escape(src)}')`;
  }

  function headOf(node, state) {
    const props = node.props || {};
    switch (node.type) {
      case 'Text':
        return `Text('${escape(text(props, 'content', '文本'))}')`;
      case 'Button':
        return `Button('${escape(text(props, 'label', '按钮'))}')`;
      case 'Image':
        return `Image(${imageSource(text(props, 'src', ''))})`;
      case 'TextInput':
        return `TextInput({ placeholder: '${escape(text(props, 'placeholder', ''))}', text: '${escape(text(props, 'text', ''))}' })`;
      case 'Row':
        return 'Row()';
      case 'Column':
        return 'Column()';
      case 'Stack':
        return 'Stack()';
      case 'Grid': {
        const template = text(props, 'columnsTemplate', '');
        return template ? `Grid().columnsTemplate('${escape(template)}')` : 'Grid()';
      }
      case 'List':
        return 'List()';
      case 'Scroll':
        return 'Scroll()';
      case 'Tabs': {
        const bar = text(props, 'barPosition', 'Start') === 'End' ? 'End' : 'Start';
        const vertical = text(props, 'vertical', 'false') === 'true';
        return `Tabs({ barPosition: BarPosition.${bar}, vertical: ${vertical} })`;
      }
      case 'Video': {
        const auto = text(props, 'autoPlay', 'false') === 'true';
        return `Video({ src: '${escape(text(props, 'src', ''))}', autoPlay: ${auto} })`;
      }
      case 'Web': {
        const id = state.webCount;
        state.webCount += 1;
        state.needsWebview = true;
        return `Web({ src: '${escape(text(props, 'src', 'https://developer.huawei.com'))}', controller: this.webController${id} })`;
      }
      case 'Canvas': {
        const id = state.canvasCount;
        state.canvasCount += 1;
        return `Canvas(this.ctx${id})`;
      }
      default:
        return `${node.type}()`;
    }
  }

  function styleChain(node, level) {
    const props = node.props || {};
    const style = node.style || {};
    // Attributes sit one column deeper than the component head.
    const prefix = pad(level + 1);
    const attrs = [];

    if (style.width > 0) {
      attrs.push(`.width(${style.width})`);
    }
    if (style.height > 0) {
      attrs.push(`.height(${style.height})`);
    }

    switch (node.type) {
      case 'Row':
      case 'Column': {
        const justify = text(props, 'justifyContent', '');
        const align = text(props, 'alignItems', '');
        if (justify) {
          attrs.push(`.justifyContent(FlexAlign.${justify})`);
        }
        if (align) {
          attrs.push(`.alignItems(VerticalAlign.${align})`);
        }
        const space = text(props, 'space', '');
        if (space) {
          attrs.push(`.space(${space})`);
        }
        break;
      }
      case 'Text':
        attrs.push(`.fontSize(${number(props, 'fontSize', 16)})`);
        attrs.push(`.fontColor('${escape(text(props, 'color', '#182431'))}')`);
        attrs.push(`.fontWeight(FontWeight.${text(props, 'fontWeight', 'Normal')})`);
        break;
      case 'Button':
        attrs.push(`.fontSize(${number(props, 'fontSize', 16)})`);
        attrs.push(`.backgroundColor('${escape(text(props, 'bgColor', '#0A59F7'))}')`);
        break;
      case 'Image':
        attrs.push(`.objectFit(ImageFit.${text(props, 'objectFit', 'Cover')})`);
        break;
      case 'TextInput':
        attrs.push(`.type(InputType.${text(props, 'type', 'normal') === 'password' ? 'Password' : 'Normal'})`);
        break;
      case 'Stack': {
        const align = text(props, 'alignContent', '');
        if (align) {
          attrs.push(`.alignContent(Alignment.${align})`);
        }
        break;
      }
      case 'List': {
        const space = text(props, 'space', '');
        if (space) {
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
    if (style.backgroundColor && style.backgroundColor !== '#00000000') {
      attrs.push(`.backgroundColor('${escape(style.backgroundColor)}')`);
    }
    if (style.borderRadius > 0) {
      attrs.push(`.borderRadius(${style.borderRadius})`);
    }

    const onClick = text(props, 'onClick', '');
    if (onClick) {
      attrs.push(`.onClick(() => {\n${pad(level + 2)}${onClick}\n${prefix}})`);
    }
    const onAppear = text(props, 'onAppear', '');
    if (onAppear) {
      attrs.push(`.onAppear(() => {\n${pad(level + 2)}${onAppear}\n${prefix}})`);
    }

    return attrs.length ? `\n${prefix}${attrs.join(`\n${prefix}`)}` : '';
  }

  function emitAll(children, level) {
    return (children || []).map((child) => emit(child, level)).join('\n');
  }

  // headOf mutates counters while emitting, so the active run is tracked in a module-level slot.
  let emitState = { needsWebview: false, webCount: 0, canvasCount: 0 };

  function emit(node, level) {
    const prefix = pad(level);
    return `${prefix}${headOf(node, emitState)}${emitChildren(node, level)}${styleChain(node, level)}`;
  }

  function emitChildren(node, level) {
    if (!registry.isContainer(node.type)) {
      return '';
    }
    const prefix = pad(level);
    const children = node.children || [];
    if (!children.length) {
      return ` {\n${pad(level + 1)}// 拖入子组件\n${prefix}}`;
    }
    const childLevel = level + 1;
    let parts;

    if (node.type === 'Grid') {
      parts = children.map((child) => `${pad(childLevel)}GridItem() {\n${emit(child, childLevel + 1)}\n${pad(childLevel)}}`);
    } else if (node.type === 'List') {
      parts = children.map((child) => `${pad(childLevel)}ListItem() {\n${emit(child, childLevel + 1)}\n${pad(childLevel)}}`);
    } else if (node.type === 'Tabs') {
      const titles = text(node.props, 'titles', '').split(',');
      parts = children.map((child, i) => {
        const title = titles[i] || `页签${i + 1}`;
        return `${pad(childLevel)}TabContent() {\n${emit(child, childLevel + 1)}\n${pad(childLevel)}}.tabBar('${escape(title)}')`;
      });
    } else if (node.type === 'Scroll') {
      parts = [children.length === 1
        ? emit(children[0], childLevel)
        : `${pad(childLevel)}Column() {\n${emitAll(children, childLevel + 1)}\n${pad(childLevel)}}`];
    } else {
      parts = [emitAll(children, childLevel)];
    }
    return ` {\n${parts.join('\n')}\n${prefix}}`;
  }

  function generate(roots) {
    emitState = { needsWebview: false, webCount: 0, canvasCount: 0 };
    const state = emitState;

    const list = roots || [];
    let body;
    if (!list.length) {
      body = `${pad(2)}Column() {\n${pad(3)}Text('从左侧拖入组件开始搭建页面')\n${pad(4)}.fontColor('#99191919')\n${pad(2)}}`;
    } else if (list.length === 1) {
      body = emit(list[0], 2);
    } else {
      body = `${pad(2)}Column() {\n${emitAll(list, 3)}\n${pad(2)}}`;
    }

    const members = [];
    for (let i = 0; i < state.webCount; i++) {
      members.push(`  private webController${i}: webview.WebviewController = new webview.WebviewController();`);
    }
    for (let i = 0; i < state.canvasCount; i++) {
      members.push(`  private ctx${i}: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));`);
    }

    let code = state.needsWebview ? "import { webview } from '@kit.ArkWeb';\n\n" : '';
    code += '@Entry\n@Component\nstruct GeneratedPage {\n';
    if (members.length) {
      code += `${members.join('\n')}\n\n`;
    }
    code += `  build() {\n${body}\n  }\n}\n`;
    return code;
  }

  return { generate: generate, escape: escape };
});
