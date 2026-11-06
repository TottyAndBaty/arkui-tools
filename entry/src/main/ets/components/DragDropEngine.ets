import { isContainer, locate, CANVAS_KEY, ComponentItem } from '../model/ComponentModel';

export class DropTarget {
  key: string = '';
  kind: string = '';   // 'palette' | 'node'
  type: string = '';
  id: string = '';

  constructor(key: string, kind: string, type: string, id: string) {
    this.key = key;
    this.kind = kind;
    this.type = type;
    this.id = id;
  }
}

class RectInfo {
  x: number = 0;
  y: number = 0;
  w: number = 0;
  h: number = 0;

  constructor(x: number, y: number, w: number, h: number) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
  }

  contains(px: number, py: number): boolean {
    return px >= this.x && px <= this.x + this.w && py >= this.y && py <= this.y + this.h;
  }

  area(): number {
    return this.w * this.h;
  }
}

/**
 * Gesture based drag and drop. The panel and every canvas node start a drag on
 * long press and follow the finger with a pan gesture; placement is resolved on
 * release by hit-testing the recorded global frames instead of relying on the
 * system drag data pipeline.
 */
export class DragDropEngine {
  private static frames: Map<string, RectInfo> = new Map();
  private static treeRef: ComponentItem[] = [];
  private static kind: string = '';
  private static dragType: string = '';
  private static dragId: string = '';
  private static dragging: boolean = false;

  static bindTree(tree: ComponentItem[]): void {
    DragDropEngine.treeRef = tree;
  }

  static registerFrame(key: string, x: number, y: number, w: number, h: number): void {
    DragDropEngine.frames.set(key, new RectInfo(x, y, w, h));
  }

  static unregisterFrame(key: string): void {
    DragDropEngine.frames.delete(key);
  }

  static resetFrames(): void {
    DragDropEngine.frames.clear();
  }

  static startPaletteDrag(type: string, x: number, y: number): void {
    DragDropEngine.begin('palette', type, '');
    DragDropEngine.move(x, y, type);
  }

  static startNodeDrag(id: string, type: string, x: number, y: number): void {
    DragDropEngine.begin('node', type, id);
    DragDropEngine.move(x, y, type);
  }

  private static begin(kind: string, type: string, id: string): void {
    DragDropEngine.kind = kind;
    DragDropEngine.dragType = type;
    DragDropEngine.dragId = id;
    DragDropEngine.dragging = true;
    AppStorage.setOrCreate('dragActive', true);
  }

  static move(x: number, y: number, label: string): void {
    if (!DragDropEngine.dragging) {
      return;
    }
    AppStorage.setOrCreate('dragX', x);
    AppStorage.setOrCreate('dragY', y);
    AppStorage.setOrCreate('dragLabel', label);
    const hit = DragDropEngine.hitTest(x, y);
    AppStorage.setOrCreate('dragHint', DragDropEngine.hintFor(hit));
  }

  /** Returns the drop target resolved from the last pointer position, or undefined when cancelled. */
  static finish(x: number, y: number): DropTarget | undefined {
    if (!DragDropEngine.dragging) {
      return undefined;
    }
    DragDropEngine.dragging = false;
    AppStorage.setOrCreate('dragActive', false);
    AppStorage.setOrCreate('dragHint', '');
    const key = DragDropEngine.hitTest(x, y);
    if (key.length === 0) {
      return undefined;
    }
    return new DropTarget(key, DragDropEngine.kind, DragDropEngine.dragType, DragDropEngine.dragId);
  }

  static cancel(): void {
    DragDropEngine.dragging = false;
    AppStorage.setOrCreate('dragActive', false);
    AppStorage.setOrCreate('dragHint', '');
  }

  static hitTest(x: number, y: number): string {
    let best: string = '';
    let bestArea: number = Number.MAX_VALUE;
    const entries = Array.from(DragDropEngine.frames.entries());
    for (const entry of entries) {
      const rect = entry[1];
      if (!rect.contains(x, y)) {
        continue;
      }
      if (entry[0] === DragDropEngine.dragId) {
        continue;
      }
      if (rect.area() < bestArea) {
        best = entry[0];
        bestArea = rect.area();
      }
    }
    return best;
  }

  /**
   * Containers only accept children, so a hit on a leaf resolves to the leaf
   * position (insert next to it) and a hit inside a container resolves to append.
   */
  private static hintFor(key: string): string {
    if (key === CANVAS_KEY) {
      return '放到画布末尾';
    }
    const node = locate(DragDropEngine.treeRef, key);
    const item = node === undefined ? undefined : node.node;
    if (item === undefined) {
      return '放到画布末尾';
    }
    return isContainer(item.type) ? `放入 ${item.type} 内部` : `插入 ${item.type} 旁边`;
  }
}
