import { CANVAS_KEY, ComponentItem, PaletteCategory, PaletteEntry, applyDrop, paletteCategories } from '../model/ComponentModel';
import { DragDropEngine } from '../components/DragDropEngine';

@Component
export struct ComponentPanel {
  @Link tree: ComponentItem[];
  @Link selectedId: string;
  private categories: PaletteCategory[] = paletteCategories();

  private place(type: string, targetKey: string): void {
    DragDropEngine.bindTree(this.tree);
    this.selectedId = applyDrop(this.tree, 'palette', type, '', targetKey);
  }

  @Builder
  tile(type: string, label: string) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor('#182431')
      Text(type)
        .fontSize(9)
        .fontColor('#99182431')
        .margin({ top: 2 })
    }
    .width(78)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .border({ width: 1, color: '#33000000' })
    .onClick(() => {
      // Tap appends to the end of the canvas, which is the fastest path on a phone.
      this.place(type, CANVAS_KEY);
    })
    .gesture(
      GestureGroup(
        GestureMode.Sequence,
        LongPressGesture({ duration: 250 }),
        PanGesture({ direction: PanDirection.All })
          .onActionStart((event: GestureEvent) => {
            const finger = event.fingerList[0];
            DragDropEngine.startPaletteDrag(type, finger.globalX, finger.globalY);
          })
          .onActionUpdate((event: GestureEvent) => {
            const finger = event.fingerList[0];
            DragDropEngine.move(finger.globalX, finger.globalY, label);
          })
          .onActionEnd((event: GestureEvent) => {
            const finger = event.fingerList[0];
            const target = DragDropEngine.finish(finger.globalX, finger.globalY);
            if (target !== undefined) {
              this.place(type, target.key);
            }
          })
      )
    )
  }

  build() {
    Column() {
      Text('组件面板')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 2 })
      Text('长按拖拽到画布，或单击追加')
        .fontSize(10)
        .fontColor('#99182431')
        .margin({ bottom: 8 })

      Scroll() {
        Column() {
          ForEach(this.categories, (category: PaletteCategory) => {
            Column() {
              Text(category.name)
                .fontSize(12)
                .fontColor('#0A59F7')
                .alignSelf(ItemAlign.Start)
                .margin({ top: 8, bottom: 6 })
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                ForEach(category.entries, (entry: PaletteEntry) => {
                  this.tile(entry.type, entry.label)
                }, (entry: PaletteEntry) => entry.type)
              }
            }
            .width('100%')
          }, (category: PaletteCategory) => category.name)
        }
        .padding({ right: 4 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#EEF1F5')
    .alignItems(HorizontalAlign.Start)
  }
}
