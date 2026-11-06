


# ArkUI 拖放工具项目文档 (project.md)

## 一、项目概述

本项目旨在构建一个基于 **ArkUI（方舟UI框架）** 的拖放工具，用于可视化搭建鸿蒙应用界面。用户可通过拖拽组件、实时预览、配置属性等方式，快速生成 ArkUI 页面代码，提升开发效率。

本工具结合 AI 驱动能力，支持通过自然语言描述生成组件布局，辅助开发者快速完成界面搭建。

---

## 二、技术选型

| 层级 | 技术选型 | 说明 |
|------|---------|------|
| 开发框架 | ArkUI（声明式UI） | 基于 TypeScript 语法，支持组件化开发 |
| 开发工具 | DevEco Studio | 鸿蒙官方 IDE，支持预览、调试、模拟器 |
| 语言 | TypeScript / ArkTS | 强类型语言，适合大型应用开发 |
| 状态管理 | V1/V2 状态管理 | @State、@Prop、@Link 等装饰器 |
| 拖放实现 | PanGesture + Drop | 手势识别 + 拖放事件 |
| AI 辅助 | 大模型 API | 自然语言生成组件布局代码 |
| 构建工具 | hvigor | 鸿蒙官方构建工具 |

---

## 三、核心功能设计

### 1. 组件面板
- 左侧展示可拖拽组件库，分类包括：
  - 基础组件：Text、Button、Image、TextInput
  - 布局组件：Row、Column、Stack、Grid
  - 媒体组件：Video、Web、Canvas
  - 容器组件：Scroll、List、Tabs

### 2. 拖放画布
- 中间区域为可视化画布，支持：
  - 从组件面板拖入组件到画布
  - 画布内组件自由移动、缩放
  - 组件层级调整（上移/下移/置顶/置底）
  - 组件删除、复制、粘贴

### 3. 属性配置面板
- 右侧展示选中组件的可配置属性：
  - 通用属性：宽、高、边距、背景色、圆角
  - 特有属性：Text 内容、Button 点击事件、Image 资源等
  - 事件绑定：onClick、onAppear 等

### 4. 代码生成与预览
- 实时生成 ArkUI 代码（.ets 文件）
- 内置模拟器预览，实时查看运行效果
- 支持代码导出，可直接在 DevEco Studio 中运行

### 5. AI 辅助生成（结合前文思路）
- 输入自然语言描述，如“生成一个登录页面，包含用户名、密码输入框和登录按钮”
- 调用大模型 API，生成组件树结构和布局代码
- 自动渲染到画布中，用户可继续手动调整

---

## 四、系统架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                    前端界面（ArkUI）                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐  │
│  │ 组件面板  │→│ 拖放画布  │→│ 属性配置  │  │代码预览│  │
│  └──────────┘  └──────────┘  └──────────┘  └────────┘  │
└──────────────────────┬──────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              核心逻辑层（ArkTS）                          │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ 组件树管理 │ 拖放引擎 │ 属性绑定 │ 代码生成器 │  │  │
│  └─────────────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              服务端（Node.js）                            │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  AI 代码生成服务（调用大模型 API）              │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 五、核心模块实现方案

### 1. 拖放引擎实现

```typescript
// 拖放核心逻辑
@Entry
@Component
struct DragDropPage {
  @State componentList: ComponentItem[] = []
  @State dragIndex: number = -1

  // 开始拖拽
  onDragStart(index: number) {
    this.dragIndex = index
  }

  // 拖拽进入目标区域
  onDrop(targetIndex: number) {
    if (this.dragIndex >= 0) {
      // 交换位置
      const temp = this.componentList[this.dragIndex]
      this.componentList[this.dragIndex] = this.componentList[targetIndex]
      this.componentList[targetIndex] = temp
      this.dragIndex = -1
    }
  }

  build() {
    Column() {
      // 组件面板
      ComponentPanel({ onDragStart: (index) => this.onDragStart(index) })
      
      // 画布区域
      CanvasArea({
        componentList: this.componentList,
        onDrop: (index) => this.onDrop(index)
      })
    }
  }
}
```

### 2. 组件树数据结构

```typescript
interface ComponentItem {
  id: string
  type: string          // 组件类型：Text/Button/Column等
  props: Record<string, any>  // 属性配置
  children: ComponentItem[]  // 子组件
  style: {
    width: number
    height: number
    backgroundColor: string
    borderRadius: number
    margin: number
    padding: number
  }
}
```

### 3. 代码生成器

```typescript
class CodeGenerator {
  generateCode(componentTree: ComponentItem): string {
    // 递归遍历组件树，生成 ArkTS 代码
    let code = `@Entry\n@Component\nstruct GeneratedPage {\n`
    code += this.generateComponent(componentTree, 1)
    code += `}\n`
    return code
  }

  private generateComponent(item: ComponentItem, indent: number): string {
    // 根据组件类型生成对应代码
    // 处理属性、事件、子组件递归
  }
}
```

### 4. AI 辅助生成服务

```typescript
// 后端服务：接收自然语言描述，返回组件树
app.post('/api/generate', async (req, res) => {
  const { prompt } = req.body
  
  // 构造系统提示词
  const systemPrompt = `
    你是一个 ArkUI 开发专家，请根据用户需求生成组件树结构。
    输出格式为 JSON：
    {
      "type": "Column",
      "props": {},
      "children": [
        { "type": "Text", "props": { "content": "登录" } }
      ]
    }
  `
  
  // 调用大模型 API
  const response = await callLLM(systemPrompt, prompt)
  res.json(JSON.parse(response))
})
```

---

## 六、开发计划

| 阶段 | 任务内容 | 预计工时 |
|------|---------|---------|
| 第一阶段 | 环境搭建、项目初始化、基础框架搭建 | 2天 |
| 第二阶段 | 组件面板 + 拖放引擎实现 | 3天 |
| 第三阶段 | 画布渲染 + 组件树管理 | 3天 |
| 第四阶段 | 属性配置面板 + 事件绑定 | 2天 |
| 第五阶段 | 代码生成器 + 预览功能 | 3天 |
| 第六阶段 | AI 辅助生成功能集成 | 3天 |
| 第七阶段 | 测试优化、导出功能 | 2天 |

---

## 七、项目目录结构

```
arkui-drag-drop-tool/
├── AppScope/
│   └── app.json5
├── entry/
│   └── src/
│       ├── main/
│       │   ├── ets/
│       │   │   ├── entryability/
│       │   │   ├── pages/
│       │   │   │   ├── Index.ets          // 主页面
│       │   │   │   ├── CanvasArea.ets     // 画布区域
│       │   │   │   ├── ComponentPanel.ets  // 组件面板
│       │   │   │   └── PropertyPanel.ets  // 属性配置
│       │   │   ├── components/
│       │   │   │   ├── ComponentItem.ets   // 组件项
│       │   │   │   └── DragDropEngine.ets // 拖放引擎
│       │   │   ├── model/
│       │   │   │   └── ComponentModel.ets  // 数据模型
│       │   │   └── utils/
│       │   │       └── CodeGenerator.ets  // 代码生成器
│       │   └── resources/
│       ├── test/
│       └── ohosTest/
├── server/
│   ├── index.js              // AI 生成服务
│   └── package.json
├── build-profile.json5
├── hvigorfile.ts
└── oh-package.json5
```

---

## 八、核心亮点

1. **可视化拖拽**：所见即所得，拖拽组件即可生成页面
2. **实时代码预览**：左侧拖拽，右侧实时生成 ArkTS 代码
3. **AI 辅助生成**：输入自然语言描述，自动生成组件布局
4. **代码导出**：一键导出 .ets 文件，可直接在 DevEco Studio 中运行
5. **组件丰富**：支持基础组件、布局组件、媒体组件等常用组件

---

## 九、后续扩展方向

- 支持更多复杂组件（图表、地图等）
- 主题定制功能（一键换肤）
- 团队协作（多人同时编辑）
- 模板市场（分享优秀页面模板）
- 一键发布到鸿蒙应用市场

---

本项目文档结合了前文讨论的 AI 驱动应用生成思路，将自然语言生成能力融入 ArkUI 拖放工具中，实现更高效的开发体验。已完成文档生成

**内容由AI生成**

