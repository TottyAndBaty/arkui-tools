/*
 * AI code generation service for the ArkUI drag and drop tool.
 *
 *   POST /api/generate   { "prompt": "生成一个登录页面" }  -> component tree JSON
 *   GET  /               serves the browser build from ../web
 *
 * When OPENAI_API_KEY is present the prompt goes to an OpenAI compatible chat endpoint;
 * otherwise (or when the call fails) the offline rule engine answers, so the tool never
 * dead-ends on a missing key. No third party dependencies: run with plain `node server`.
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const rules = require('../shared/rules.js');

const PORT = Number(process.env.PORT || 3000);
const HOST = process.env.HOST || '0.0.0.0';
const WEB_ROOT = path.resolve(__dirname, '..', 'web');
const SHARED_ROOT = path.resolve(__dirname, '..', 'shared');

const LLM = {
  apiKey: process.env.OPENAI_API_KEY || process.env.ARKUI_LLM_API_KEY || '',
  baseUrl: (process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1').replace(/\/+$/, ''),
  model: process.env.OPENAI_MODEL || 'gpt-4o-mini'
};

const SYSTEM_PROMPT = `你是 ArkUI（鸿蒙方舟 UI 框架）开发专家。根据用户需求输出一棵组件树，只输出 JSON，不要输出解释文字或代码块。
JSON 结构：
{
  "type": "Column",
  "props": { "justifyContent": "Center", "space": "12" },
  "style": { "width": 340, "height": 0, "backgroundColor": "#00000000", "borderRadius": 0, "margin": 0, "padding": 16 },
  "children": [
    { "type": "Text", "props": { "content": "登录" }, "children": [] }
  ]
}
约束：
- type 只能是 Text、Button、Image、TextInput、Row、Column、Stack、Grid、Scroll、List、Tabs、Video、Web、Canvas。
- 只有 Row、Column、Stack、Grid、Scroll、List、Tabs 可以有 children。
- style 的数值单位是 vp；backgroundColor 使用 #RRGGBB 或 #AARRGGBB。
- 常用 props：Text.content / Button.label / Image.src / TextInput.placeholder、TextInput.type / Tabs.titles / Grid.columnsTemplate。`;

function sendJson(res, status, payload, headers) {
  const body = JSON.stringify(payload);
  res.writeHead(status, Object.assign({
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Expose-Headers': 'X-ArkUI-Source'
  }, headers || {}));
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 1e6) {
        reject(new Error('请求体过大'));
        req.destroy();
      }
    });
    req.on('end', () => resolve(raw));
    req.on('error', reject);
  });
}

/** LLMs wrap JSON in prose or fences even when told not to; keep the outermost object. */
function extractJson(content) {
  const fenced = content.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced ? fenced[1] : content;
  const start = candidate.indexOf('{');
  const end = candidate.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw new Error('模型未返回 JSON 组件树');
  }
  return JSON.parse(candidate.slice(start, end + 1));
}

async function generateWithLlm(prompt) {
  const response = await fetch(`${LLM.baseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${LLM.apiKey}`
    },
    body: JSON.stringify({
      model: LLM.model,
      temperature: 0.2,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: prompt }
      ]
    })
  });
  if (!response.ok) {
    throw new Error(`模型服务返回 ${response.status}`);
  }
  const data = await response.json();
  const content = data && data.choices && data.choices[0] && data.choices[0].message
    ? data.choices[0].message.content
    : '';
  return rules.sanitize(extractJson(content), 0);
}

function generateWithRules(prompt) {
  return rules.generate(prompt);
}

async function handleGenerate(req, res) {
  let prompt = '';
  try {
    const body = await readBody(req);
    const parsed = body ? JSON.parse(body) : {};
    prompt = typeof parsed.prompt === 'string' ? parsed.prompt.trim() : '';
  } catch (error) {
    sendJson(res, 400, { error: '请求体必须是 {"prompt": "..."} 形式的 JSON' });
    return;
  }

  if (!prompt) {
    sendJson(res, 400, { error: 'prompt 不能为空' });
    return;
  }

  if (LLM.apiKey) {
    try {
      const tree = await generateWithLlm(prompt);
      if (tree) {
        sendJson(res, 200, tree, { 'X-ArkUI-Source': 'llm' });
        console.log(`[generate] llm ok  "${prompt.slice(0, 40)}"`);
        return;
      }
      console.warn('[generate] llm returned an unusable tree, falling back to rules');
    } catch (error) {
      console.warn(`[generate] llm failed (${error.message}), falling back to rules`);
    }
  }

  sendJson(res, 200, generateWithRules(prompt), { 'X-ArkUI-Source': 'rules' });
}

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png'
};

function serveStatic(req, res, urlPath) {
  const fromShared = urlPath.startsWith('/shared/');
  const base = fromShared ? SHARED_ROOT : WEB_ROOT;
  const relative = fromShared
    ? urlPath.slice('/shared/'.length)
    : (urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, ''));
  const target = path.resolve(base, relative);
  // Reject anything that escapes the served root, e.g. /../server/index.js
  if (!target.startsWith(base + path.sep) && target !== base) {
    res.writeHead(403).end('Forbidden');
    return;
  }
  fs.readFile(target, (error, data) => {
    if (error) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }).end('Not found');
      return;
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(target)] || 'application/octet-stream' });
    res.end(data);
  });
}

const server = http.createServer(async (req, res) => {
  const urlPath = decodeURIComponent((req.url || '/').split('?')[0]);

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Expose-Headers': 'X-ArkUI-Source'
    });
    res.end();
    return;
  }

  if (req.method === 'POST' && urlPath === '/api/generate') {
    await handleGenerate(req, res);
    return;
  }

  if (req.method === 'GET' && urlPath === '/api/health') {
    sendJson(res, 200, { ok: true, mode: LLM.apiKey ? 'llm' : 'rules', model: LLM.apiKey ? LLM.model : null });
    return;
  }

  if (req.method === 'GET') {
    serveStatic(req, res, urlPath);
    return;
  }

  sendJson(res, 405, { error: '仅支持 POST /api/generate' });
});

server.listen(PORT, HOST, () => {
  console.log(`ArkUI Builder 服务已启动：http://localhost:${PORT}`);
  console.log(`AI 生成模式：${LLM.apiKey ? `大模型（${LLM.model} @ ${LLM.baseUrl}）` : '内置规则引擎（未配置 OPENAI_API_KEY）'}`);
  console.log(`鸿蒙侧服务地址：模拟器 http://10.0.2.2:${PORT}/api/generate ，真机请替换为本机局域网 IP`);
});
