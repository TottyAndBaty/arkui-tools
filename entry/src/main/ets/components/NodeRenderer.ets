import { ComponentItem, isContainer, numProp, strProp } from '../model/ComponentModel';
import { DragDropEngine, DropTarget } from './DragDropEngine';

@Component
export struct NodeRenderer {
  @ObjectLink node: ComponentItem;
  @Link selectedId: string;
  @Link draggingId: string;
  onNodeDrop: (target: DropTarget) => void = () => {};

  build() {
    Column() {
      if (isContainer(this.node.type)) {
        this.containerBody()
      } else {
        this.leafBody()
      }
    }
    .width(this.node.style.width > 0 ? this.node.style.width : 'auto')
    .padding(this.node.style.padding)
    .margin(this.node.style.margin)
    .backgroundColor(this.node.style.backgroundColor)
    .borderRadius(this.node.style.borderRadius)
    .border({
      width: this.selectedId === this.node.id ? 2 : 1,
      color: this.selectedId === this.node.id ? '#0A59F7' : '#33000000',
      style: BorderStyle.Dashed
    })
    .onClick(() => {
      this.selectedId = this.node.id;
    })
    .gesture(
      GestureGroup(
        GestureMode.Sequence,
        LongPressGesture({ duration: 250 })
          .onAction(() => {
            this.draggingId = this.node.id;
          }),
        PanGesture({ direction: PanDirection.All })
          .onActionStart((event: GestureEvent) => {
            const finger = event.fingerList[0];
            DragDropEngine.startNodeDrag(this.node.id, this.node.type, finger.globalX, finger.globalY);
          })
          .onActionUpdate((event: GestureEvent) => {
            const finger = event.fingerList[0];
            DragDropEngine.move(finger.globalX, finger.globalY, this.node.type);
          })
          .onActionEnd((event: GestureEvent) => {
            const finger = event.fingerList[0];
            const target = DragDropEngine.finish(finger.globalX, finger.globalY);
            this.draggingId = '';
            if (target !== undefined) {
              this.onNodeDrop(target);
            }
          })
      )
    )
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const position = newValue.globalPosition;
      DragDropEngine.registerFrame(
        this.node.id,
        Number(position.x),
        Number(position.y),
        Number(newValue.width),
        Number(newValue.height)
      );
    })
  }

  @Builder
  childList(orientation: Axis) {
    if (orientation === Axis.Horizontal) {
      Row() {
        ForEach(this.node.children, (child: ComponentItem) => {
          NodeRenderer({ node: child, selectedId: this.selectedId, draggingId: this.draggingId, onNodeDrop: this.onNodeDrop })
        }, (child: ComponentItem) => child.id)
      }
      .justifyContent(this.flexAlign())
      .alignItems(VerticalAlign.Center)
    } else {
      Column() {
        ForEach(this.node.children, (child: ComponentItem) => {
          NodeRenderer({ node: child, selectedId: this.selectedId, draggingId: this.draggingId, onNodeDrop: this.onNodeDrop })
        }, (child: ComponentItem) => child.id)
      }
      .justifyContent(FlexAlign.Start)
    }
  }

  private flexAlign(): FlexAlign {
    const value = strProp(this.node.props, 'justifyContent', 'Start');
    if (value === 'Center') {
      return FlexAlign.Center;
    }
    if (value === 'End') {
      return FlexAlign.End;
    }
    return FlexAlign.Start;
  }

  @Builder
  containerBody() {
    Column() {
      Text(`${this.node.type}  ${this.node.children.length} 个子组件`)
        .fontSize(10)
        .fontColor('#99000000')
        .margin({ bottom: 4 })
      if (this.node.children.length === 0) {
        Text('拖组件到这里')
          .fontSize(11)
          .fontColor('#66000000')
      } else if (this.node.type === 'Row' || this.node.type === 'Grid') {
        this.childList(Axis.Horizontal)
      } else if (this.node.type === 'Tabs') {
        this.tabsBody()
      } else {
        this.childList(Axis.Vertical)
      }
    }
    .constraintSize({ minWidth: 80, minHeight: 56 })
  }

  @Builder
  tabsBody() {
    Column() {
      Row() {
        ForEach(this.tabTitles(), (title: string) => {
          Text(title)
            .fontSize(11)
            .fontColor('#0A59F7')
            .margin({ right: 12 })
        }, (title: string) => title)
      }
      .margin({ bottom: 6 })

      // Preview shows the first tab content only; the generator emits one TabContent per child.
      NodeRenderer({
        node: this.node.children[0],
        selectedId: this.selectedId,
        draggingId: this.draggingId,
        onNodeDrop: this.onNodeDrop
      })
    }
  }

  private tabTitles(): string[] {
    const titles = strProp(this.node.props, 'titles', '').split(',');
    const out: string[] = [];
    for (let i = 0; i < this.node.children.length; i++) {
      out.push(i < titles.length && titles[i].length > 0 ? titles[i] : `页签${i + 1}`);
    }
    return out;
  }

  @Builder
  leafBody() {
    if (this.node.type === 'Text') {
      Text(strProp(this.node.props, 'content', '文本'))
        .fontSize(numProp(this.node.props, 'fontSize', 16))
        .fontColor(strProp(this.node.props, 'color', '#182431'))
    } else if (this.node.type === 'Button') {
      Button(strProp(this.node.props, 'label', '按钮'))
        .fontSize(numProp(this.node.props, 'fontSize', 16))
        .backgroundColor(strProp(this.node.props, 'bgColor', '#0A59F7'))
        .height(this.node.style.height > 0 ? this.node.style.height : 40)
    } else if (this.node.type === 'Image') {
      Column() {
        // The canvas cannot resolve a dynamic $r() name, so the bundled icon stands in.
        Image($r('app.media.startIcon'))
          .width(this.node.style.width)
          .height(this.node.style.height)
          .objectFit(ImageFit.Cover)
          .borderRadius(this.node.style.borderRadius)
        Text(strProp(this.node.props, 'src', 'startIcon'))
          .fontSize(9)
          .fontColor('#66000000')
      }
    } else if (this.node.type === 'TextInput') {
      TextInput({ placeholder: strProp(this.node.props, 'placeholder', '请输入内容'), text: strProp(this.node.props, 'text', '') })
        .width(this.node.style.width)
        .type(strProp(this.node.props, 'type', 'normal') === 'password' ? InputType.Password : InputType.Normal)
    } else {
      this.mediaPlaceholder()
    }
  }

  @Builder
  mediaPlaceholder() {
    Column() {
      Text(this.node.type)
        .fontSize(13)
        .fontColor('#66000000')
      Text(strProp(this.node.props, 'src', ''))
        .fontSize(9)
        .fontColor('#66000000')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width(this.node.style.width)
    .height(this.node.style.height)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#11000000')
    .borderRadius(6)
  }
}
