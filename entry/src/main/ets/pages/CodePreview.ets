import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { ComponentItem } from '../model/ComponentModel';
import { CodeGenerator } from '../utils/CodeGenerator';

@Component
export struct CodePreview {
  @Link @Watch('refresh') tree: ComponentItem[];
  private generator: CodeGenerator = new CodeGenerator();
  @State code: string = '';

  aboutToAppear(): void {
    this.refresh();
  }

  refresh(): void {
    this.code = this.generator.generate(this.tree);
  }

  private toast(message: string, duration: number = 1500): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: duration });
  }

  private copyAll(): void {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.code);
    pasteboard.getSystemPasteboard().setData(data)
      .then(() => {
        this.toast('代码已复制', 1000);
      })
      .catch((error: Error) => {
        this.toast(`复制失败：${error.message}`);
      });
  }

  private exportFile(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const path = `${context.filesDir}/GeneratedPage.ets`;
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, this.code);
      fileIo.closeSync(file);
      this.toast(`已导出 ${path}`, 2000);
    } catch (error) {
      this.toast(`导出失败：${(error as Error).message}`);
    }
  }

  build() {
    Column() {
      Row() {
        Text('代码预览')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Blank()
        Button('复制')
          .fontSize(12)
          .height(26)
          .backgroundColor('#F2F3F5')
          .fontColor('#182431')
          .onClick(() => {
            this.copyAll();
          })
        Button('导出 .ets')
          .fontSize(12)
          .height(26)
          .margin({ left: 6 })
          .onClick(() => {
            this.exportFile();
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      Scroll() {
        Text(this.code)
          .fontSize(11)
          .fontFamily('HarmonyOS Sans SC')
          .fontColor('#182431')
          .textAlign(TextAlign.Start)
          .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .padding(10)
      .backgroundColor('#0F182431')
      .borderRadius(8)
      .scrollBar(BarState.Auto)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
