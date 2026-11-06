import {
  ComponentItem,
  ComponentStyle,
  PropField,
  findNode,
  paletteLabel,
  propSchema,
  strProp
} from '../model/ComponentModel';

@Component
export struct PropertyPanel {
  @Link tree: ComponentItem[];
  @Link selectedId: string;

  private node(): ComponentItem | undefined {
    return this.selectedId.length === 0 ? undefined : findNode(this.tree, this.selectedId);
  }

  private writeProp(key: string, value: string): void {
    const node = this.node();
    if (node !== undefined) {
      node.props[key] = value;
    }
  }

  /** ComponentStyle is observed one level deep, so edits replace the whole style object. */
  private writeStyle(field: string, value: string): void {
    const node = this.node();
    if (node === undefined) {
      return;
    }
    const next = new ComponentStyle();
    next.width = node.style.width;
    next.height = node.style.height;
    next.backgroundColor = node.style.backgroundColor;
    next.borderRadius = node.style.borderRadius;
    next.margin = node.style.margin;
    next.padding = node.style.padding;
    const numeric = Number.parseFloat(value);
    const number = Number.isNaN(numeric) ? 0 : numeric;
    if (field === 'backgroundColor') {
      next.backgroundColor = value;
    } else if (field === 'width') {
      next.width = number;
    } else if (field === 'height') {
      next.height = number;
    } else if (field === 'margin') {
      next.margin = number;
    } else if (field === 'padding') {
      next.padding = number;
    } else {
      next.borderRadius = number;
    }
    node.style = next;
  }

  @Builder
  sectionTitle(title: string) {
    Text(title)
      .fontSize(12)
      .fontColor('#0A59F7')
      .alignSelf(ItemAlign.Start)
      .margin({ top: 14, bottom: 6 })
  }

  @Builder
  numberField(label: string, value: number, field: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('#182431')
        .width(64)
      TextInput({ text: value.toString() })
        .type(InputType.Number)
        .fontSize(12)
        .height(30)
        .layoutWeight(1)
        .onChange((text: string) => {
          this.writeStyle(field, text);
        })
    }
    .width('100%')
    .margin({ bottom: 6 })
  }

  @Builder
  textField(label: string, value: string, key: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('#182431')
        .width(64)
      TextInput({ text: value })
        .fontSize(12)
        .height(30)
        .layoutWeight(1)
        .onChange((text: string) => {
          this.writeProp(key, text);
        })
    }
    .width('100%')
    .margin({ bottom: 6 })
  }

  @Builder
  enumField(label: string, value: string, field: PropField) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor('#182431')
        .alignSelf(ItemAlign.Start)
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(field.options, (option: string) => {
          Text(option)
            .fontSize(11)
            .fontColor(value === option ? '#FFFFFF' : '#182431')
            .backgroundColor(value === option ? '#0A59F7' : '#F2F3F5')
            .borderRadius(6)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .margin({ right: 6, top: 4 })
            .onClick(() => {
              this.writeProp(field.key, option);
            })
        }, (option: string) => option)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 6 })
  }

  @Builder
  colorField(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('#182431')
        .width(64)
      TextInput({ text: value })
        .fontSize(12)
        .height(30)
        .layoutWeight(1)
        .onChange((text: string) => {
          this.writeStyle('backgroundColor', text);
        })
    }
    .width('100%')
    .margin({ bottom: 6 })
  }

  @Builder
  fieldOf(field: PropField) {
    if (field.kind === 'enum') {
      this.enumField(field.label, strProp(this.propsOfSelected(), field.key, ''), field)
    } else {
      this.textField(field.label, strProp(this.propsOfSelected(), field.key, ''), field.key)
    }
  }

  build() {
    Column() {
      Text('属性配置')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 6 })

      Scroll() {
        if (this.selectedId.length === 0) {
          Text('选中画布中的组件后在这里配置属性')
            .fontSize(12)
            .fontColor('#99182431')
            .margin({ top: 30 })
        } else {
          this.panelBody()
        }
      }
      .layoutWeight(1)
      .align(Alignment.TopStart)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  panelBody() {
    Column() {
      // The node is resolved once per build so every builder below reads the same instance.
      Text(`${paletteLabel(this.typeOfSelected())} · ${this.typeOfSelected()}`)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)

      this.sectionTitle('通用属性')
      this.numberField('宽', this.styleOfSelected().width, 'width')
      this.numberField('高', this.styleOfSelected().height, 'height')
      this.numberField('外边距', this.styleOfSelected().margin, 'margin')
      this.numberField('内边距', this.styleOfSelected().padding, 'padding')
      this.numberField('圆角', this.styleOfSelected().borderRadius, 'borderRadius')
      this.colorField('背景色', this.styleOfSelected().backgroundColor)

      this.sectionTitle('组件属性')
      ForEach(propSchema(this.typeOfSelected()), (field: PropField) => {
        this.fieldOf(field)
      }, (field: PropField) => field.key)

      this.sectionTitle('事件绑定')
      this.textField('onAppear', strProp(this.propsOfSelected(), 'onAppear', ''), 'onAppear')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  private typeOfSelected(): string {
    const node = this.node();
    return node === undefined ? '' : node.type;
  }

  private styleOfSelected(): ComponentStyle {
    const node = this.node();
    return node === undefined ? new ComponentStyle() : node.style;
  }

  private propsOfSelected(): Record<string, string> {
    const node = this.node();
    return node === undefined ? {} : node.props;
  }
}
