/*
 * Offline natural language -> component tree.
 * Used as the fallback path by both the Node service (no API key configured) and the
 * browser tool (service unreachable), so the AI button always produces an editable tree.
 */
(function (root, factory) {
  const registry = typeof module !== 'undefined' && module.exports
    ? require('./registry.js')
    : root.ArkUIRegistry;
  const api = factory(registry);
  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  } else {
    root.ArkUIRules = api;
  }
})(typeof globalThis !== 'undefined' ? globalThis : this, function (registry) {
  function node(type, props, children, style) {
    return registry.createNode(type, { props: props, children: children, style: style });
  }

  function heading(text) {
    return node('Text', { content: text, fontSize: '22', fontWeight: 'Bold' }, [], { width: 240, height: 32 });
  }

  function input(placeholder, type) {
    return node('TextInput', { placeholder: placeholder, type: type || 'normal' }, [], { width: 260, height: 40 });
  }

  function button(label) {
    return node('Button', { label: label }, [], { width: 260, height: 40, borderRadius: 20 });
  }

  function repeatedCount(text, fallback) {
    const digits = text.match(/(\d+)\s*(?:个|条|项|行|张)/);
    if (digits) {
      return Math.min(12, Math.max(1, parseInt(digits[1], 10)));
    }
    const english = text.match(/(\d+)\s*(?:items?|rows?|cards?|tiles?)/);
    if (english) {
      return Math.min(12, Math.max(1, parseInt(english[1], 10)));
    }
    return fallback;
  }

  function page(children) {
    return node(
      'Column',
      { justifyContent: 'Start', alignItems: 'Top', space: '12' },
      children,
      { width: 340, height: 0, backgroundColor: '#00000000', borderRadius: 0, margin: 0, padding: 16 }
    );
  }

  const TEMPLATES = [
    {
      id: 'login',
      match: /(登录|登陆|login|sign\s*in)/i,
      build: () => page([
        heading('登录'),
        input('请输入用户名'),
        input('请输入密码', 'password'),
        button('登录')
      ])
    },
    {
      id: 'register',
      match: /(注册|register|sign\s*up)/i,
      build: () => page([
        heading('注册'),
        input('请输入手机号', 'number'),
        input('请输入验证码', 'number'),
        input('请设置密码', 'password'),
        button('注册')
      ])
    },
    {
      id: 'search',
      match: /(搜索|search)/i,
      build: () => node('Column', { space: '12' }, [
        node('Row', { space: '8' }, [
          input('搜索内容', 'normal'),
          button('搜索')
        ]),
        node('List', {}, [
          node('Text', { content: '搜索历史一' }),
          node('Text', { content: '搜索历史二' })
        ])
      ])
    },
    {
      id: 'form',
      match: /(表单|反馈|反馈页|留言|联系|提交|form|feedback|contact|submit)/i,
      build: () => page([
        heading('信息填写'),
        input('姓名'),
        input('联系方式', 'number'),
        input('备注内容'),
        button('提交')
      ])
    },
    {
      id: 'tabs',
      match: /(页签|标签页|tabs?|底部导航|导航栏|首页|个人中心|my\s*page)/i,
      build: () => node('Tabs', { titles: '首页,发现,我的' }, [
        node('Column', { space: '10' }, [heading('首页'), node('Text', { content: '首页内容占位' })]),
        node('Column', { space: '10' }, [heading('发现'), node('Text', { content: '推荐列表占位' })]),
        node('Column', { space: '10' }, [heading('我的'), button('退出登录')])
      ], { width: 320, height: 260 })
    },
    {
      id: 'list',
      match: /(列表|list|消息|待办|todo)/i,
      build: (text) => {
        const count = repeatedCount(text, 4);
        const items = [];
        for (let i = 1; i <= count; i++) {
          items.push(node('Text', { content: `列表项 ${i}` }, [], { width: 280, height: 32 }));
        }
        return page([heading('列表'), node('List', { space: '8' }, items, { width: 300, height: 60 * count })]);
      }
    },
    {
      id: 'grid',
      match: /(网格|宫格|九宫格|六宫格|grid|商品|分类)/i,
      build: (text) => {
        const count = repeatedCount(text, 6);
        const items = [];
        for (let i = 1; i <= count; i++) {
          items.push(node('Column', { space: '6' }, [
            node('Image', { src: 'startIcon' }, [], { width: 72, height: 72, borderRadius: 8 }),
            node('Text', { content: `分类 ${i}`, fontSize: '13' })
          ]));
        }
        return page([heading('网格'), node('Grid', { columnsTemplate: '1fr 1fr 1fr' }, items, { width: 300, height: 200 })]);
      }
    },
    {
      id: 'card',
      match: /(卡片|card|资讯|文章|详情|profile)/i,
      build: () => page([
        node('Column', { space: '8' }, [
          node('Image', { src: 'startIcon' }, [], { width: 300, height: 140, borderRadius: 10 }),
          node('Text', { content: '卡片标题', fontSize: '18', fontWeight: 'Bold' }, [], { width: 280, height: 26 }),
          node('Text', { content: '这里是卡片的描述内容，可在属性面板中修改。', fontSize: '13', color: '#66182431' }, [], { width: 280, height: 44 }),
          button('查看详情')
        ], { width: 320, height: 0, backgroundColor: '#FFFFFFFF', borderRadius: 14, padding: 14 })
      ])
    },
    {
      id: 'video',
      match: /(视频|播放器|video)/i,
      build: () => page([
        heading('视频播放'),
        node('Video', { src: '', autoPlay: 'false' }, [], { width: 320, height: 180, borderRadius: 8 })
      ])
    },
    {
      id: 'web',
      match: /(网页|浏览器|webview|web\s*page)/i,
      build: () => page([
        heading('网页'),
        node('Web', { src: 'https://developer.huawei.com' }, [], { width: 320, height: 320 })
      ])
    }
  ];

  /** Anything the templates above did not consume still gets a visible block. */
  function extras(text, usedTemplate) {
    const out = [];
    if (/(标题|title)/i.test(text) && usedTemplate !== 'login') {
      out.push(heading('标题'));
    }
    if (/(按钮|button|提交|确定)/i.test(text) && usedTemplate !== 'login' && usedTemplate !== 'register') {
      out.push(button('按钮'));
    }
    if (/(输入框|输入|input)/i.test(text) && usedTemplate !== 'login' && usedTemplate !== 'form') {
      out.push(input('请输入内容'));
    }
    return out;
  }

  function generate(prompt) {
    const text = prompt || '';
    let template;
    for (const candidate of TEMPLATES) {
      if (candidate.match.test(text)) {
        template = candidate;
        break;
      }
    }
    const tree = template ? template.build(text) : page([
      heading('新页面'),
      node('Text', { content: text.length > 0 ? text.slice(0, 40) : '未识别到具体页面结构，可在画布中手动调整。' }, [], { width: 300, height: 60 })
    ]);
    if (template) {
      const tail = extras(text, template.id);
      for (const extra of tail) {
        if (tree.children.length < 8) {
          tree.children.push(extra);
        }
      }
    }
    return tree;
  }

  function clampStyle(raw) {
    const base = registry.DEFAULT_STYLE;
    const style = {};
    const numbers = ['width', 'height', 'borderRadius', 'margin', 'padding'];
    numbers.forEach((key) => {
      if (raw && typeof raw[key] === 'number' && isFinite(raw[key])) {
        style[key] = Math.max(-200, Math.min(4096, Math.round(raw[key])));
      } else if (base[key] !== undefined) {
        style[key] = base[key];
      }
    });
    if (raw && typeof raw.backgroundColor === 'string' && /^#[0-9a-fA-F]{6,8}$/.test(raw.backgroundColor)) {
      style.backgroundColor = raw.backgroundColor;
    }
    return style;
  }

  /** Clamp an untrusted tree (LLM output) to the component registry the canvas can render. */
  function sanitize(value, depth) {
    const level = depth || 0;
    if (level > 12 || value === null || typeof value !== 'object') {
      return null;
    }
    const type = registry.knownType(value.type) ? value.type : 'Column';
    const props = {};
    if (value.props && typeof value.props === 'object') {
      Object.keys(value.props).forEach((key) => {
        const raw = value.props[key];
        if (typeof raw === 'string' || typeof raw === 'number' || typeof raw === 'boolean') {
          props[key] = String(raw);
        }
      });
    }
    const children = [];
    if (Array.isArray(value.children) && registry.isContainer(type)) {
      value.children.slice(0, 40).forEach((child) => {
        const clean = sanitize(child, level + 1);
        if (clean) {
          children.push(clean);
        }
      });
    }
    return registry.createNode(type, { props: props, children: children, style: clampStyle(value.style) });
  }

  return { generate: generate, sanitize: sanitize, TEMPLATES: TEMPLATES };
});
