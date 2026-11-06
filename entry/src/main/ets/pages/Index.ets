import { ComponentItem, countNodes, treeFromJson } from '../model/ComponentModel';
import { DragDropEngine } from '../components/DragDropEngine';
import { AiClient } from '../utils/AiClient';
import { CanvasArea } from './CanvasArea';
import { ComponentPanel } from './ComponentPanel';
import { PropertyPanel } from './PropertyPanel';
import { CodePreview } from './CodePreview';

@Entry
@Component
struct Index {
  @State tree: ComponentItem[] = [];
  @State selectedId: string = '';
  @State draggingId: string = '';
  @State prompt: string = '生成一个登录页面，包含用户名、密码输入框和登录按钮';
  @State endpoint: string = AiClient.DEFAULT_ENDPOINT;
  @State busy: boolean = false;
  @State isWide: boolean = false;
  @State showSettings: boolean = false;
  @StorageProp('dragActive') dragActive: boolean = false;
  @StorageProp('dragX') dragX: number = 0;
  @StorageProp('dragY') dragY: number = 0;
  @StorageProp('dragLabel') dragLabel: string = '';

  aboutToAppear(): void {
    DragDropEngine.bindTree(this.tree);
  }

  private toast(message: string, duration: number = 1500): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: duration });
  }

  private runAi(): void {
    const text = this.prompt.trim();
    if (text.length === 0) {
      this.toast('请先描述想要的页面', 1200);
      return;
    }
    this.busy = true;
    AiClient.generate(this.endpoint, text)
      .then((json: string) => {
        const roots = treeFromJson(json);
        if (roots.length === 0) {
          this.toast('未解析出组件结构');
          return;
        }
        this.tree = roots;
        DragDropEngine.bindTree(this.tree);
        this.selectedId = roots[0].id;
        this.toast(`已生成 ${countNodes(roots)} 个节点`);
      })
      .catch((error: Error) => {
        this.toast(`生成失败：${error.message}`, 2000);
      })
      .finally(() => {
        this.busy = false;
      });
  }

  @Builder
  aiBar() {
    Column() {
      Row({ space: 8 }) {
        Text('AI 辅助生成')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
        TextInput({ text: this.prompt, placeholder: '用自然语言描述页面结构' })
          .fontSize(12)
          .height(34)
          .layoutWeight(1)
          .onChange((value: string) => {
            this.prompt = value;
          })
        Button(this.busy ? '生成中…' : '生成')
          .fontSize(13)
          .height(34)
          .enabled(!this.busy)
          .onClick(() => {
            this.runAi();
          })
        Button('服务设置')
          .fontSize(12)
          .height(34)
          .backgroundColor('#F2F3F5')
          .fontColor('#182431')
          .onClick(() => {
            this.showSettings = !this.showSettings;
          })
      }
      .width('100%')

      if (this.showSettings) {
        Row({ space: 8 }) {
          Text('服务地址')
            .fontSize(12)
            .fontColor('#99182431')
          TextInput({ text: this.endpoint })
            .fontSize(11)
            .height(30)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.endpoint = value;
            })
        }
        .width('100%')
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  dragGhost() {
    if (this.dragActive) {
      Text(this.dragLabel)
        .fontSize(12)
        .fontColor('#FFFFFF')
        .backgroundColor('#CC0A59F7')
        .borderRadius(6)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .position({ x: this.dragX + 12, y: this.dragY + 12 })
        .zIndex(1000)
        .hitTestBehavior(HitTestMode.Transparent)
    }
  }

  @Builder
  wideLayout() {
    Row() {
      ComponentPanel({ tree: this.tree, selectedId: this.selectedId })
        .width(210)
        .height('100%')
      CanvasArea({ tree: this.tree, selectedId: this.selectedId, draggingId: this.draggingId })
        .layoutWeight(1)
        .height('100%')
        .margin({ left: 8, right: 8 })
      Column() {
        PropertyPanel({ tree: this.tree, selectedId: this.selectedId })
          .layoutWeight(1)
          .width('100%')
        Divider().margin({ top: 6, bottom: 6 })
        CodePreview({ tree: this.tree })
          .height('45%')
          .width('100%')
      }
      .width(300)
      .height('100%')
    }
    .width('100%')
    .layoutWeight(1)
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  compactLayout() {
    Tabs({ barPosition: BarPosition.Start }) {
      TabContent() {
        ComponentPanel({ tree: this.tree, selectedId: this.selectedId })
      }
      .tabBar('组件')

      TabContent() {
        CanvasArea({ tree: this.tree, selectedId: this.selectedId, draggingId: this.draggingId })
      }
      .tabBar('画布')

      TabContent() {
        PropertyPanel({ tree: this.tree, selectedId: this.selectedId })
      }
      .tabBar('属性')

      TabContent() {
        CodePreview({ tree: this.tree })
      }
      .tabBar('代码')
    }
    .vertical(false)
    .barMode(BarMode.Fixed)
    .layoutWeight(1)
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.aiBar()
        if (this.isWide) {
          this.wideLayout()
        } else {
          this.compactLayout()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F7FA')

      this.dragGhost()
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.isWide = Number(newValue.width) > 720;
    })
  }
}
