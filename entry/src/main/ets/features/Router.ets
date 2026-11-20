// 导航：AppRoute 的鸿蒙版。所有跳转走 Router，以便同步一份可观察的路由栈（决定是否隐藏 Tab 栏）。
import { LessonRunResult } from '../models/Types';
import { Files } from '../services/Files';

export type RouteName = 'bookList' | 'bookDetail' | 'lesson' | 'lessonResult' | 'review' | 'reviewRunner' |
  'achievements' | 'stories' | 'storyReader' | 'reading' | 'passageReader' | 'shop' | 'profile' | 'settings' |
  'guide' | 'jumpTest';

export class AppRoute {
  name: RouteName;
  bookId: string = '';
  lessonId: string = '';
  itemId: string = '';
  unitNumber: number = 0;
  grade: number = 0;
  result: LessonRunResult | null = null;

  constructor(name: RouteName) {
    this.name = name;
  }

  static lesson(bookId: string, lessonId: string): AppRoute {
    const r = new AppRoute('lesson');
    r.bookId = bookId;
    r.lessonId = lessonId;
    return r;
  }

  static book(name: RouteName, bookId: string): AppRoute {
    const r = new AppRoute(name);
    r.bookId = bookId;
    return r;
  }

  static item(name: RouteName, bookId: string, itemId: string): AppRoute {
    const r = new AppRoute(name);
    r.bookId = bookId;
    r.itemId = itemId;
    return r;
  }

  static unit(name: RouteName, bookId: string, unitNumber: number): AppRoute {
    const r = new AppRoute(name);
    r.bookId = bookId;
    r.unitNumber = unitNumber;
    return r;
  }

  static resultOf(result: LessonRunResult): AppRoute {
    const r = new AppRoute('lessonResult');
    r.result = result;
    return r;
  }

  get immersive(): boolean {
    switch (this.name) {
      case 'lesson':
      case 'lessonResult':
      case 'reviewRunner':
      case 'storyReader':
      case 'passageReader':
      case 'reading':
      case 'guide':
      case 'jumpTest':
        return true;
      default:
        return false;
    }
  }
}

@ObservedV2
export class Router {
  static readonly shared: Router = new Router();

  // 路由栈即数组——Index 用 ForEach 自绘全屏页（Navigation 组件在本机内容区不渲染，弃用）。
  // @Trace 跨组件字段在这台机器上实测不派发，靠显式监听 + @Local 镜像驱动重绘。
  @Trace routes: AppRoute[] = [];
  private listeners: Array<() => void> = [];

  onChange(cb: () => void): void {
    this.listeners.push(cb);
  }

  private emit(): void {
    this.listeners.forEach((cb: () => void) => cb());
  }

  push(route: AppRoute): void {
    this.routes = this.routes.concat([route]);
    this.emit();
  }

  pop(): void {
    if (this.routes.length === 0) {
      return;
    }
    this.routes = this.routes.slice(0, this.routes.length - 1);
    this.emit();
  }

  /** 替换栈顶（例如课程结束 → 结算页）。 */
  replaceTop(route: AppRoute): void {
    this.routes = this.routes.slice(0, Math.max(0, this.routes.length - 1)).concat([route]);
    this.emit();
  }

  clear(): void {
    this.routes = [];
    this.emit();
  }

  /** 清空后再推一个页面。 */
  reset(route: AppRoute): void {
    this.clear();
    this.push(route);
  }

  get top(): AppRoute | null {
    return this.routes.length > 0 ? this.routes[this.routes.length - 1] : null;
  }

  get hideTabBar(): boolean {
    const t = this.top;
    return t !== null && t.immersive;
  }
}
