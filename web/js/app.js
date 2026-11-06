/*
 * Browser build of the ArkUI drag and drop tool.
 * Shares the component registry, the offline rule engine and the code generator with the
 * Node service (../shared) and mirrors the HarmonyOS app under entry/src/main/ets.
 */
(function () {
  const R = window.ArkUIRegistry;
  const Rules = window.ArkUIRules;
  const Gen = window.ArkUICodeGenerator;

  const DND_MIME = 'application/x-arkui-node';

  const els = {
    palette: document.getElementById('palette'),
    canvas: document.getElementById('canvas'),
    emptyTip: document.getElementById('empty-tip'),
    summary: document.getElementById('tree-summary'),
    propertyForm: document.getElementById('property-form'),
    propertyEmpty: document.getElementById('property-empty'),
    codeView: document.getElementById('code-view'),
    aiForm: document.getElementById('ai-form'),
    aiPrompt: document.getElementById('ai-prompt'),
    aiRun: document.getElementById('ai-run'),
    aiSource: document.getElementById('ai-source'),
    svcToggle: document.getElementById('svc-toggle'),
    svcEndpoint: document.getElementById('svc-endpoint'),
    toast: null
  };

  let tree = [];
  let selectedId = '';
  let clipboard = null;
  let dragPayload = null;

  /* ---------- tree helpers ---------- */

  function locate(id, list, parent) {
    const items = list || tree;
    for (let i = 0; i < items.length; i++) {
      if (items[i].id === id) {
        return { list: items, index: i, parent: parent || null, node: items[i] };
      }
      const found = locate(id, items[i].children, items[i]);
      if (found) {
        return found;
      }
    }
    return null;
  }

  function findById(id) {
    const found = locate(id);
    return found ? found.node : null;
  }

  function contains(id, otherId) {
    const found = locate(id);
    if (!found) {
      return false;
    }
    return !!locate(otherId, found.node.children, found.node);
  }

  function countAll(list) {
    let total = 0;
    (list || tree).forEach((node) => {
      total += 1 + countAll(node.children);
    });
    return total;
  }

  /** Same placement rules as applyDrop() in the ArkTS model layer. */
  function applyDrop(payload, targetId) {
    let list = tree;
    let before = null;

    if (targetId) {
      const hit = findById(targetId);
      if (hit) {
        if (R.isContainer(hit.type)) {
          list = hit.children;
        } else {
          const found = locate(targetId);
          list = found.list;
          before = found.index;
        }
      }
    }

    let moving;
    if (payload.kind === 'palette') {
      moving = R.createNode(payload.type);
    } else {
      if (payload.id === targetId || contains(payload.id, targetId)) {
        return;
      }
      const found = locate(payload.id);
      if (!found) {
        return;
      }
      moving = found.node;
      found.list.splice(found.index, 1);
      if (before !== null && found.list === list && found.index < before) {
        before -= 1;
      }
    }

    if (before === null) {
      list.push(moving);
    } else {
      list.splice(before, 0, moving);
    }
    selectedId = moving.id;
    renderAll();
  }

  function moveZOrder(direction) {
    const found = locate(selectedId);
    if (!found) {
      return;
    }
    const items = found.list;
    const from = found.index;
    let to = from;
    if (direction === 'up') {
      to = Math.max(0, from - 1);
    } else if (direction === 'down') {
      to = Math.min(items.length - 1, from + 1);
    } else if (direction === 'top') {
      to = 0;
    } else if (direction === 'bottom') {
      to = items.length - 1;
    }
    if (to === from) {
      return;
    }
    items.splice(to, 0, items.splice(from, 1)[0]);
    renderAll();
  }

  function selectedNode() {
    return selectedId ? findById(selectedId) : null;
  }

  function insertAfter(anchorId, nodeToInsert) {
    const found = locate(anchorId);
    if (!found) {
      tree.push(nodeToInsert);
      return;
    }
    found.list.splice(found.index + 1, 0, nodeToInsert);
  }

  /* ---------- palette ---------- */

  function renderPalette() {
    els.palette.innerHTML = '';
    R.CATEGORIES.forEach((category) => {
      const title = document.createElement('div');
      title.className = 'palette-cat';
      title.textContent = category.name;
      els.palette.appendChild(title);

      const grid = document.createElement('div');
      grid.className = 'palette-grid';
      category.entries.forEach((entry) => {
        const item = document.createElement('div');
        item.className = 'palette-item';
        item.draggable = true;
        item.tabIndex = 0;
        item.setAttribute('role', 'button');
        item.setAttribute('aria-label', `添加 ${entry.label} ${entry.type}`);
        item.innerHTML = `<span class="name">${entry.label}</span><span class="kind">${entry.type}</span>`;
        item.addEventListener('dragstart', (event) => {
          dragPayload = { kind: 'palette', type: entry.type };
          event.dataTransfer.setData(DND_MIME, 'palette');
          event.dataTransfer.effectAllowed = 'copy';
        });
        item.addEventListener('dragend', () => {
          dragPayload = null;
          clearDropMarks();
        });
        item.addEventListener('click', () => {
          applyDrop({ kind: 'palette', type: entry.type }, null);
        });
        item.addEventListener('keydown', (event) => {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            applyDrop({ kind: 'palette', type: entry.type }, null);
          }
        });
        grid.appendChild(item);
      });
      els.palette.appendChild(grid);
    });
  }

  /* ---------- canvas ---------- */

  function styleBox(element, node) {
    const style = node.style || {};
    if (style.width > 0) {
      element.style.width = `${style.width}px`;
    }
    if (style.height > 0) {
      element.style.height = `${style.height}px`;
    }
    element.style.margin = `${style.margin || 0}px`;
    element.style.padding = `${style.padding || 0}px`;
    element.style.borderRadius = `${style.borderRadius || 0}px`;
    if (style.backgroundColor && style.backgroundColor !== '#00000000') {
      element.style.background = argbToCss(style.backgroundColor);
    }
  }

  function argbToCss(value) {
    if (/^#[0-9a-fA-F]{8}$/.test(value)) {
      const alpha = parseInt(value.slice(1, 3), 16) / 255;
      return `rgba(${parseInt(value.slice(3, 5), 16)}, ${parseInt(value.slice(5, 7), 16)}, ${parseInt(value.slice(7, 9), 16)}, ${alpha.toFixed(2)})`;
    }
    return value;
  }

  function leafElement(node) {
    const props = node.props || {};
    let inner;
    switch (node.type) {
      case 'Text':
        inner = document.createElement('div');
        inner.className = 'ui-text';
        inner.textContent = props.content || '文本';
        inner.style.fontSize = `${parseInt(props.fontSize, 10) || 16}px`;
        inner.style.color = argbToCss(props.color || '#182431');
        inner.style.fontWeight = /^(Bold|Bolder)$/.test(props.fontWeight) ? '700' : '400';
        break;
      case 'Button':
        inner = document.createElement('div');
        inner.className = 'ui-button';
        inner.textContent = props.label || '按钮';
        inner.style.fontSize = `${parseInt(props.fontSize, 10) || 16}px`;
        inner.style.background = argbToCss(props.bgColor || '#0A59F7');
        break;
      case 'Image':
        inner = document.createElement('div');
        inner.className = 'ui-image';
        inner.textContent = props.src || 'startIcon';
        break;
      case 'TextInput':
        inner = document.createElement('input');
        inner.className = 'ui-input';
        inner.type = props.type === 'password' ? 'password' : 'text';
        inner.placeholder = props.placeholder || '请输入内容';
        inner.value = props.text || '';
        inner.tabIndex = -1;
        break;
      case 'Tabs': {
        inner = document.createElement('div');
        inner.style.width = '100%';
        const strip = document.createElement('div');
        strip.className = 'tab-strip';
        const titles = (props.titles || '').split(',');
        node.children.forEach((child, i) => {
          const label = document.createElement('span');
          label.textContent = titles[i] || `页签${i + 1}`;
          strip.appendChild(label);
        });
        inner.appendChild(strip);
        if (node.children.length) {
          inner.appendChild(buildElement(node.children[0]));
        }
        break;
      }
      default:
        inner = document.createElement('div');
        inner.className = 'ui-placeholder';
        inner.innerHTML = `<span>${node.type}</span><small>${(props.src || '').slice(0, 42)}</small>`;
        break;
    }
    return inner;
  }

  function containerClass(type) {
    switch (type) {
      case 'Row':
        return 'container-body horizontal';
      case 'Grid':
        return 'container-body grid';
      case 'Stack':
        return 'container-body stack';
      case 'List':
        return 'container-body list';
      case 'Scroll':
        return 'container-body scroll';
      default:
        return 'container-body vertical';
    }
  }

  function buildElement(node) {
    const element = document.createElement('div');
    element.className = 'node';
    element.dataset.id = node.id;
    element.dataset.drop = 'node';
    element.setAttribute('role', 'group');
    element.setAttribute('aria-label', `${node.type} 组件，点击选中`);
    if (node.id === selectedId) {
      element.classList.add('selected');
    }

    const tag = document.createElement('span');
    tag.className = 'node-tag';
    tag.textContent = node.type;
    element.appendChild(tag);

    if (R.isContainer(node.type)) {
      const body = document.createElement('div');
      body.className = containerClass(node.type);
      if (node.type === 'Grid') {
        const template = (node.props.columnsTemplate || '1fr 1fr').trim().split(/\s+/);
        body.style.gridTemplateColumns = template.join(' ');
      }
      if (node.type === 'Row') {
        body.style.justifyContent = cssJustify(node.props.justifyContent);
      }
      if (!node.children.length) {
        const tip = document.createElement('div');
        tip.className = 'drop-here';
        tip.textContent = '拖组件到这里';
        body.appendChild(tip);
      } else if (node.type !== 'Tabs') {
        node.children.forEach((child) => body.appendChild(buildElement(child)));
      }
      if (node.type === 'Tabs') {
        element.appendChild(leafElement(node));
      } else {
        element.appendChild(body);
      }
    } else {
      element.appendChild(leafElement(node));
    }

    element.draggable = true;
    element.addEventListener('dragstart', (event) => {
      event.stopPropagation();
      dragPayload = { kind: 'node', id: node.id, type: node.type };
      event.dataTransfer.setData(DND_MIME, 'node');
      event.dataTransfer.effectAllowed = 'move';
      element.classList.add('dragging');
    });
    element.addEventListener('dragend', () => {
      dragPayload = null;
      element.classList.remove('dragging');
      clearDropMarks();
    });
    element.addEventListener('click', (event) => {
      event.stopPropagation();
      selectedId = node.id;
      renderAll();
    });
    return element;
  }

  function cssJustify(value) {
    if (value === 'Center') {
      return 'center';
    }
    if (value === 'End') {
      return 'flex-end';
    }
    if (value === 'SpaceBetween') {
      return 'space-between';
    }
    if (value === 'SpaceAround') {
      return 'space-around';
    }
    return 'flex-start';
  }

  function renderCanvas() {
    els.canvas.innerHTML = '';
    if (!tree.length) {
      const tip = document.createElement('p');
      tip.className = 'empty-tip';
      tip.textContent = '从左侧拖入组件开始搭建页面';
      els.canvas.appendChild(tip);
    } else {
      tree.forEach((node) => els.canvas.appendChild(buildElement(node)));
    }
    const roots = tree.length;
    const selected = selectedNode();
    els.summary.textContent = roots
      ? `${roots} 个根组件 / ${countAll(tree)} 个节点 · ${selected ? `已选中 ${selected.type}` : '未选中'}`
      : '画布为空';
  }

  function clearDropMarks() {
    els.canvas.querySelectorAll('.drop-in, .drop-side').forEach((el) => {
      el.classList.remove('drop-in', 'drop-side');
    });
    els.canvas.classList.remove('drag-over');
  }

  function dropTargetFor(event) {
    const nodeEl = event.target.closest ? event.target.closest('.node') : null;
    if (nodeEl) {
      return { id: nodeEl.dataset.id, element: nodeEl };
    }
    return { id: '', element: els.canvas };
  }

  function bindCanvasDnd() {
    els.canvas.addEventListener('dragover', (event) => {
      if (!dragPayload) {
        return;
      }
      event.preventDefault();
      event.dataTransfer.dropEffect = dragPayload.kind === 'palette' ? 'copy' : 'move';
      const target = dropTargetFor(event);
      clearDropMarks();
      if (target.element === els.canvas) {
        els.canvas.classList.add('drag-over');
        return;
      }
      const node = findById(target.id);
      if (!node) {
        return;
      }
      if (R.isContainer(node.type)) {
        target.element.classList.add('drop-in');
      } else {
        target.element.classList.add('drop-side');
      }
    });

    els.canvas.addEventListener('dragleave', (event) => {
      if (event.target === els.canvas) {
        els.canvas.classList.remove('drag-over');
      }
    });

    els.canvas.addEventListener('drop', (event) => {
      event.preventDefault();
      const payload = dragPayload;
      clearDropMarks();
      dragPayload = null;
      if (!payload) {
        return;
      }
      applyDrop(payload, dropTargetFor(event).id || null);
    });

    els.canvas.addEventListener('click', (event) => {
      if (event.target === els.canvas) {
        selectedId = '';
        renderAll();
      }
    });
  }

  /* ---------- property panel ---------- */

  function renderProperty() {
    const node = selectedNode();
    if (!node) {
      els.propertyForm.classList.add('hidden');
      els.propertyEmpty.classList.remove('hidden');
      return;
    }
    els.propertyEmpty.classList.add('hidden');
    els.propertyForm.classList.remove('hidden');
    els.propertyForm.innerHTML = '';

    const meta = document.createElement('div');
    meta.className = 'node-meta';
    meta.textContent = `${R.labelFor(node.type)} · ${node.type} · ${node.id}`;
    els.propertyForm.appendChild(meta);

    els.propertyForm.appendChild(group('通用属性', styleRows(node)));
    const typed = propRows(node);
    if (typed.length) {
      els.propertyForm.appendChild(group('组件属性', typed));
    }
    els.propertyForm.appendChild(group('事件绑定', eventRows(node)));
  }

  function group(title, rows) {
    const wrapper = document.createElement('div');
    wrapper.className = 'prop-group';
    const heading = document.createElement('h3');
    heading.textContent = title;
    wrapper.appendChild(heading);
    rows.forEach((row) => wrapper.appendChild(row));
    return wrapper;
  }

  function textField(label, value, onInput) {
    const row = document.createElement('div');
    row.className = 'prop-row';
    const name = document.createElement('label');
    name.textContent = label;
    const input = document.createElement('input');
    input.type = 'text';
    input.value = value === undefined || value === null ? '' : String(value);
    input.addEventListener('input', () => {
      onInput(input.value);
    });
    row.appendChild(name);
    row.appendChild(input);
    return row;
  }

  function numberField(label, value, onInput) {
    const row = textField(label, value, (raw) => {
      const parsed = parseFloat(raw);
      onInput(Number.isNaN(parsed) ? 0 : parsed);
    });
    row.querySelector('input').type = 'number';
    return row;
  }

  function chipField(label, value, options, onPick) {
    const row = document.createElement('div');
    row.className = 'prop-row';
    const name = document.createElement('label');
    name.textContent = label;
    row.appendChild(name);
    const chips = document.createElement('div');
    chips.className = 'chips';
    options.forEach((option) => {
      const chip = document.createElement('span');
      chip.className = `chip${String(value) === option ? ' on' : ''}`;
      chip.textContent = option;
      chip.addEventListener('click', () => {
        onPick(option);
        renderAll();
      });
      chips.appendChild(chip);
    });
    row.appendChild(chips);
    return row;
  }

  function styleRows(node) {
    const style = node.style;
    const repaint = () => {
      renderCanvas();
      renderCode();
    };
    return [
      numberField('宽', style.width, (value) => {
        style.width = value;
        repaint();
      }),
      numberField('高', style.height, (value) => {
        style.height = value;
        repaint();
      }),
      numberField('外边距', style.margin, (value) => {
        style.margin = value;
        repaint();
      }),
      numberField('内边距', style.padding, (value) => {
        style.padding = value;
        repaint();
      }),
      numberField('圆角', style.borderRadius, (value) => {
        style.borderRadius = value;
        repaint();
      }),
      textField('背景色', style.backgroundColor, (value) => {
        style.backgroundColor = value;
        repaint();
      })
    ];
  }

  function propRows(node) {
    const schema = R.PROP_SCHEMA[node.type] || [];
    const repaint = () => {
      renderCanvas();
      renderCode();
    };
    return schema
      .filter((field) => field.kind !== 'event')
      .map((field) => {
        if (field.kind === 'enum') {
          return chipField(field.label, node.props[field.key] || '', field.options, (option) => {
            node.props[field.key] = option;
            repaint();
          });
        }
        if (field.kind === 'number') {
          return numberField(field.label, node.props[field.key] || '', (value) => {
            node.props[field.key] = String(value);
            repaint();
          });
        }
        return textField(field.label, node.props[field.key] || '', (value) => {
          node.props[field.key] = value;
          repaint();
        });
      });
  }

  function eventRows(node) {
    const repaint = () => renderCode();
    const rows = [];
    const supportsClick = ['Button', 'Image', 'Text', 'TextInput'].indexOf(node.type) >= 0;
    if (supportsClick) {
      rows.push(textField('onClick', node.props.onClick || '', (value) => {
        node.props.onClick = value;
        repaint();
      }));
    }
    rows.push(textField('onAppear', node.props.onAppear || '', (value) => {
      node.props.onAppear = value;
      repaint();
    }));
    rows.push(hintRow('填写 ArkTS 语句，例如 console.info(\'clicked\')'));
    return rows;
  }

  function hintRow(text) {
    const row = document.createElement('div');
    row.className = 'prop-row';
    const label = document.createElement('label');
    label.textContent = '';
    const value = document.createElement('span');
    value.textContent = text;
    value.style.cssText = 'font-size:10px;color:var(--text-dim)';
    row.appendChild(label);
    row.appendChild(value);
    return row;
  }

  /* ---------- code ---------- */

  function renderCode() {
    els.codeView.textContent = Gen.generate(tree);
  }

  /* ---------- toolbar / actions ---------- */

  function runAction(action) {
    const node = selectedNode();
    if (action === 'clear') {
      tree = [];
      selectedId = '';
      renderAll();
      return;
    }
    if (!node) {
      toast('请先在画布中选中一个组件');
      return;
    }
    if (action === 'delete') {
      const found = locate(node.id);
      found.list.splice(found.index, 1);
      selectedId = '';
    } else if (action === 'duplicate') {
      const copy = deepClone(node);
      insertAfter(node.id, copy);
      selectedId = copy.id;
    } else if (action === 'copy') {
      clipboard = deepClone(node);
      toast('已复制组件');
      return;
    } else if (action === 'paste') {
      if (!clipboard) {
        toast('剪贴板为空');
        return;
      }
      const pasted = deepClone(clipboard);
      insertAfter(node.id, pasted);
      selectedId = pasted.id;
    } else {
      moveZOrder(action);
      return;
    }
    renderAll();
  }

  function deepClone(node) {
    const copy = R.createNode(node.type, { props: node.props, style: node.style });
    copy.props = JSON.parse(JSON.stringify(node.props));
    copy.style = JSON.parse(JSON.stringify(node.style));
    node.children.forEach((child) => copy.children.push(deepClone(child)));
    return copy;
  }

  /* ---------- AI ---------- */

  async function callService(promptText, endpoint) {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt: promptText })
    });
    if (!response.ok) {
      throw new Error(`服务返回 ${response.status}`);
    }
    const source = response.headers.get('X-ArkUI-Source') || 'service';
    return { tree: await response.json(), source: source };
  }

  function markSource(text, cls) {
    els.aiSource.textContent = text;
    els.aiSource.className = `badge ${cls}`;
  }

  async function generate(promptText) {
    const trimmed = promptText.trim();
    if (!trimmed) {
      toast('请先描述想要的页面');
      return;
    }
    els.aiRun.disabled = true;
    markSource('生成中…', '');
    let result = null;

    if (els.svcToggle.checked) {
      try {
        result = await callService(trimmed, els.svcEndpoint.value.trim());
        markSource(result.source === 'llm' ? '大模型生成' : '服务端规则生成', result.source === 'llm' ? 'llm' : 'rules');
      } catch (error) {
        result = { tree: Rules.generate(trimmed), source: 'local-rules' };
        markSource(`服务不可用，本地生成（${error.message}）`, 'error');
      }
    } else {
      result = { tree: Rules.generate(trimmed), source: 'local-rules' };
      markSource('本地规则生成', 'rules');
    }

    const clean = Rules.sanitize(result.tree, 0);
    tree = clean ? [clean] : [];
    selectedId = tree.length ? tree[0].id : '';
    renderAll();
    els.aiRun.disabled = false;
  }

  /* ---------- import / export ---------- */

  function download(name, content, mime) {
    const blob = new Blob([content], { type: mime });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = name;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  function importJson() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json,application/json';
    input.addEventListener('change', () => {
      const file = input.files && input.files[0];
      if (!file) {
        return;
      }
      const reader = new FileReader();
      reader.onload = () => {
        try {
          const clean = Rules.sanitize(JSON.parse(String(reader.result)), 0);
          tree = clean ? [clean] : [];
          selectedId = '';
          renderAll();
          toast('组件树已导入');
        } catch (error) {
          toast(`导入失败：${error.message}`);
        }
      };
      reader.readAsText(file, 'utf-8');
    });
    input.click();
  }

  async function copyCode() {
    try {
      await navigator.clipboard.writeText(els.codeView.textContent);
      toast('代码已复制');
    } catch (error) {
      const helper = document.createElement('textarea');
      helper.value = els.codeView.textContent;
      document.body.appendChild(helper);
      helper.select();
      const ok = document.execCommand('copy');
      helper.remove();
      toast(ok ? '代码已复制' : '复制失败，请手动选择代码');
    }
  }

  /* ---------- misc ---------- */

  function toast(message) {
    if (!els.toast) {
      els.toast = document.createElement('div');
      els.toast.className = 'toast';
      document.body.appendChild(els.toast);
    }
    els.toast.textContent = message;
    els.toast.classList.add('show');
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => els.toast.classList.remove('show'), 2200);
  }

  function renderAll() {
    renderCanvas();
    renderProperty();
    renderCode();
  }

  function bindUi() {
    document.querySelectorAll('.tools button').forEach((button) => {
      button.addEventListener('click', () => runAction(button.dataset.action));
    });

    document.querySelectorAll('.tab').forEach((tab) => {
      tab.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach((el) => el.classList.remove('active'));
        tab.classList.add('active');
        document.getElementById('tab-property').classList.toggle('hidden', tab.dataset.tab !== 'property');
        document.getElementById('tab-code').classList.toggle('hidden', tab.dataset.tab !== 'code');
      });
    });

    els.aiForm.addEventListener('submit', (event) => {
      event.preventDefault();
      generate(els.aiPrompt.value);
    });
    document.getElementById('btn-import').addEventListener('click', importJson);
    document.getElementById('btn-export-json').addEventListener('click', () => {
      download('arkui-tree.json', JSON.stringify(tree.length === 1 ? tree[0] : tree, null, 2), 'application/json');
    });
    document.getElementById('btn-export-ets').addEventListener('click', () => {
      download('GeneratedPage.ets', Gen.generate(tree), 'text/plain;charset=utf-8');
    });
    document.getElementById('btn-copy-code').addEventListener('click', copyCode);

    document.addEventListener('keydown', (event) => {
      if (event.target.tagName === 'INPUT' || event.target.tagName === 'TEXTAREA') {
        return;
      }
      const meta = event.ctrlKey || event.metaKey;
      if (event.key === 'Delete' && selectedId) {
        runAction('delete');
      } else if (meta && event.key.toLowerCase() === 'c') {
        runAction('copy');
      } else if (meta && event.key.toLowerCase() === 'v') {
        runAction('paste');
      } else if (meta && event.key.toLowerCase() === 'd') {
        runAction('duplicate');
      }
    });

    // Deployment defaults: same-origin service on http(s), local dev service on file://.
    if (window.location.protocol.indexOf('http') === 0) {
      els.svcEndpoint.value = `${window.location.origin}/api/generate`;
    }
    if (typeof window.ARKUI_ENDPOINT === 'string' && window.ARKUI_ENDPOINT.length > 0) {
      els.svcEndpoint.value = window.ARKUI_ENDPOINT;
    }

    // Remember the endpoint between reloads; file:// storage is origin-less but still works.
    try {
      const saved = localStorage.getItem('arkui.endpoint');
      if (saved) {
        els.svcEndpoint.value = saved;
      }
      els.svcEndpoint.addEventListener('change', () => {
        localStorage.setItem('arkui.endpoint', els.svcEndpoint.value);
      });
    } catch (error) {
      // file:// without storage access: the default endpoint still applies.
    }
  }

  renderPalette();
  bindCanvasDnd();
  bindUi();
  renderAll();
})();
