import {
  AiNodeDto,
  CANVAS_KEY,
  ComponentItem,
  applyDrop,
  cloneNode,
  countNodes,
  findNode,
  locate,
  moveZOrder,
  nodeFromDto,
  removeNode
} from '../model/ComponentModel';
import { DragDropEngine, DropTarget } from '../components/DragDropEngine';
import { NodeRenderer } from '../components/NodeRenderer';

@Component
export struct CanvasArea {
  @Link tree: ComponentItem[];
  @Link selectedId: string;
  @Link draggingId: string;
  @StorageProp('dragActive') dragActive: boolean = false;
  @StorageProp('dragHint') dragHint: string = '';
  @StorageLink('clipboard') clipboard: string = '';

  aboutToAppear(): void {
    DragDropEngine.bindTree(this.tree);
  }

  private handleDrop(target: DropTarget): void {
    DragDropEngine.bindTree(this.tree);
    const id = applyDrop(this.tree, target.kind, target.type, target.id, target.key);
    if (id.length > 0) {
      this.selectedId = id;
    }
  }

  private selected(): ComponentItem | undefined {
    return this.selectedId.length === 0 ? undefined : findNode(this.tree, this.selectedId);
  }

  /** Place a node directly after `anchorId` inside the same parent list. */
  private insertAfter(anchorId: string, node: ComponentItem): void {
    const location = locate(this.tree, anchorId);
    if (location === undefined) {
      this.tree.push(node);
      return;
    }
    location.siblings.splice(location.index + 1, 0, node);
  }

  private mutate(action: string): void {
    const node = this.selected();
    if (action === 'clear') {
      this.tree.splice(0, this.tree.length);
      this.selectedId = '';
      return;
    }
    if (node === undefined) {
      return;
    }

    if (action === 'delete') {
      removeNode(this.tree, node.id);
      this.selectedId = '';
    } else if (action === 'duplicate') {
      const copy = cloneNode(node);
      this.insertAfter(node.id, copy);
      this.selectedId = copy.id;
    } else if (action === 'copy') {
      this.clipboard = JSON.stringify(node);
    } else if (action === 'paste') {
      this.pasteFromClipboard(node.id);
    } else {
      moveZOrder(this.tree, node.id, action);
    }
    DragDropEngine.bindTree(this.tree);
  }

  private pasteFromClipboard(anchorId: string): void {
    if (this.clipboard.length === 0) {
      return;
    }
    const dto = JSON.parse(this.clipboard) as AiNodeDto;
    const pasted = nodeFromDto(dto);
    this.insertAfter(anchorId, pasted);
    this.selectedId = pasted.id;
  }

  @Builder
  toolButton(label: string, action: string, enabled: boolean) {
    Button(label)
      .fontSize(12)
      .height(28)
      .backgroundColor('#F2F3F5')
      .fontColor(enabled ? '#182431' : '#C0C4CC')
      .onClick(() => {
        if (enabled) {
          this.mutate(action);
        }
      })
  }

  build() {
    Column() {
      Row({ space: 6 }) {
        Text('画布')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Text(`${this.tree.length} 个根组件 / ${countNodes(this.tree)} 个节点`)
          .fontSize(11)
          .fontColor('#99182431')
          .margin({ left: 6 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })

      Scroll() {
        Row({ space: 6 }) {
          this.toolButton('删除', 'delete', this.selectedId.length > 0)
          this.toolButton('复制', 'copy', this.selectedId.length > 0)
          this.toolButton('粘贴', 'paste', this.clipboard.length > 0)
          this.toolButton('克隆', 'duplicate', this.selectedId.length > 0)
          this.toolButton('上移', 'up', this.selectedId.length > 0)
          this.toolButton('下移', 'down', this.selectedId.length > 0)
          this.toolButton('置顶', 'top', this.selectedId.length > 0)
          this.toolButton('置底', 'bottom', this.selectedId.length > 0)
          this.toolButton('清空', 'clear', this.tree.length > 0)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ left: 12, right: 12, bottom: 8 })

      if (this.dragActive && this.dragHint.length > 0) {
        Text(this.dragHint)
          .fontSize(12)
          .fontColor('#0A59F7')
          .backgroundColor('#1AE3F1FF')
          .borderRadius(6)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .margin({ bottom: 6 })
      }

      Scroll() {
        Column({ space: 4 }) {
          if (this.tree.length === 0) {
            Text('从左侧组件面板长按并拖动到此处')
              .fontSize(13)
              .fontColor('#66182431')
              .margin({ top: 60 })
          }
          ForEach(this.tree, (child: ComponentItem) => {
            NodeRenderer({
              node: child,
              selectedId: this.selectedId,
              draggingId: this.draggingId,
              onNodeDrop: (target: DropTarget) => {
                this.handleDrop(target);
              }
            })
          }, (child: ComponentItem) => child.id)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding(10)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
      .backgroundColor('#F7F8FA')
      .border({ width: this.dragActive ? 2 : 1, color: this.dragActive ? '#0A59F7' : '#33000000' })
      .borderRadius(8)
      .onAreaChange((oldValue: Area, newValue: Area) => {
        const position = newValue.globalPosition;
        DragDropEngine.registerFrame(
          CANVAS_KEY,
          Number(position.x),
          Number(position.y),
          Number(newValue.width),
          Number(newValue.height)
        );
      })
    }
    .width('100%')
    .height('100%')
  }
}
