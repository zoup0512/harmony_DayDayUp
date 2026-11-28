// 应用根（MainShell）：种子安装 → 载入进度/设置 → 底部 Tab + 路由栈 + 全局结算弹层。
import { ConfigurationConstant } from '@kit.AbilityKit';
import { C, CONTENT_MAX_W, F, W, alpha } from '../design/Theme';
import { SeedInstaller } from '../services/DataLoader';
import { AppEnv } from '../services/Files';
import { AssetDownloader } from '../services/AssetDownloader';
import { ProgressStore, DailyRewardClaim } from '../stores/ProgressStore';
import { SettingsStore } from '../stores/SettingsStore';
import { AudioPlayer, SFXEngine } from '../services/Audio';
import { Haptics } from '../services/Feedback';
import { ChunkyButton, DuoIcon, ModalCard } from '../components/Kit';
import { Mascot } from '../components/Mascot';
import { AppTab, BottomTabBar } from '../components/Widgets';
import { AppRoute, Router } from '../features/Router';
import { Onboarding } from '../features/Onboarding';
import { LearnHome, BookListPage, BookDetailPage, UnitGuidePage, JumpTestPage } from '../features/Books';
import { LessonRunner } from '../features/Lesson';
import { LessonResultPage } from '../features/LessonResult';
import { ReviewTab, ReviewRunner, LeagueTab, ShopTab } from '../features/ReviewLeagueShop';
import { StoriesPage, StoryReaderPage, PassagesPage, PassageReaderPage } from '../features/Stories';
import { ProfileTab, AchievementsPage, SettingsPage } from '../features/Profile';
import { RemedyPage } from '../features/Remedy';
import { CardAlbumPage } from '../features/Cards';
import { League } from '../domain/Seeded';
import { LearnerStore } from '../stores/LearnerStore';
import { LearnerPicker, LearnersPage, ParentOverviewPage } from '../features/Family';

@Entry
@ComponentV2
struct Index {
  @Local tab: AppTab = 'learn';
  @Local ready: boolean = false;
  /** 弹层可见性用 @Local 镜像——实测 @Trace 直读在此页不触发重建，会导致弹窗卡死关不掉。 */
  @Local rewardDismissed: boolean = false;
  @Local leagueDismissed: boolean = false;
  // @ObservedV2 单例的 @Trace 跨组件读取在这台机器上实测不派发——改显式监听 + @Local 镜像。
  router: Router = Router.shared;
  store: ProgressStore = ProgressStore.shared;
  settings: SettingsStore = SettingsStore.shared;
  @Local pendingReward: DailyRewardClaim | null = null;
  @Local pendingLeague: boolean = false;
  @Local onboarded: boolean = false;
  /** 装备的 UI 主题变化时自增，整棵界面按新配色重建（明暗切换靠 Palette 的 @Trace 就地刷新）。 */
  @Local themeRev: number = 0;
  /** 「谁在学习？」选择层（冷启动多孩子自动弹 / 首页头像手动开）。 */
  @Local picking: boolean = false;
  private learnerId: string = '';

  private get overlayOpen(): boolean {
    return this.picking || (this.pendingReward !== null && !this.rewardDismissed) ||
      (this.pendingLeague && !this.leagueDismissed);
  }
  private tickTimer: number = -1;

  /** 装备的 UI 主题 + 外观设置 → Palette；有变化才重建，并同步系统控件（Toggle/弹层/状态栏）的明暗。 */
  private applyPalette(): void {
    const themeId = this.store.equippedTheme;
    const theme = themeId.length > 0 && themeId !== 'theme_default' ? (this.store.equippedThemeData ?? null) : null;
    const prevTheme = C.theme;
    if (!C.apply(theme, this.settings.prefersDark)) {
      return;
    }
    if (C.theme !== prevTheme) {
      this.themeRev++;
    }
    try {
      const mode = C.dark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK :
        (this.settings.appearance === 'system' && theme === null ? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET :
        ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      AppEnv.ctx().getApplicationContext().setColorMode(mode);
    } catch (e) {
      // 仅影响系统控件配色
    }
  }

  aboutToAppear(): void {
    this.settings.onChange(() => this.applyPalette());
    this.router.setOverlayBack(() => this.closeOverlay());
    this.store.onChange(() => {
      this.pendingReward = this.store.pendingDailyReward;
      this.pendingLeague = this.store.pendingLeagueResult !== null;
      this.onboarded = this.store.hasCompletedOnboarding;
      this.applyPalette();
    });
    LearnerStore.shared.onChange(() => {
      this.picking = LearnerStore.shared.pickerOpen;
      // 换了孩子：回到学习 Tab，新孩子的登录奖励 / 联赛弹层重新可见
      if (LearnerStore.shared.activeId !== this.learnerId) {
        this.learnerId = LearnerStore.shared.activeId;
        this.tab = 'learn';
        this.rewardDismissed = false;
        this.leagueDismissed = false;
      }
    });
    this.settings.load();
    SeedInstaller.installIfNeeded().catch(() => {
    }).finally(() => {
      LearnerStore.shared.load();
      this.learnerId = LearnerStore.shared.activeId;
      this.picking = LearnerStore.shared.pickerOpen;
      this.store.load();
      this.onboarded = this.store.hasCompletedOnboarding;
      this.store.refreshForNow();
      this.applyPalette();
      this.ready = true;
      AssetDownloader.shared.refreshSiteIndexInBackground();
    });
    // 心跳：回心计时 / 跨日翻转 / 联赛结算都靠 refreshForNow
    this.tickTimer = setInterval(() => {
      this.store.refreshForNow();
      if (this.store.pendingDailyReward !== null) {
        this.rewardDismissed = false;
      }
      if (this.store.pendingLeagueResult !== null) {
        this.leagueDismissed = false;
      }
    }, 30000);
  }

  aboutToDisappear(): void {
    clearInterval(this.tickTimer);
  }

  /** 系统返回（侧滑/返回键）：弹层 → 页面拦截器 → 路由栈 → 回学习 Tab → 交给系统退出。 */
  onBackPress(): boolean {
    if (this.router.handleBack()) {
      return true;
    }
    if (this.ready && this.onboarded && this.tab !== 'learn') {
      this.tab = 'learn';
      return true;
    }
    return false;
  }

  private closeOverlay(): boolean {
    if (this.picking) {
      // 冷启动时返回 = 继续用当前孩子
      if (LearnerStore.shared.pickerAuto) {
        LearnerStore.shared.closePicker();
        this.store.refreshForNow();
      } else {
        LearnerStore.shared.closePicker();
      }
      return true;
    }
    if (this.pendingReward !== null && !this.rewardDismissed) {
      this.rewardDismissed = true;
      this.store.dismissDailyReward();
      return true;
    }
    if (this.pendingLeague && !this.leagueDismissed) {
      this.leagueDismissed = true;
      this.store.clearPendingLeagueResult();
      return true;
    }
    return false;
  }

  @Builder
  tabBody() {
    if (this.tab === 'learn') {
      LearnHome()
    } else if (this.tab === 'league') {
      LeagueTab()
    } else if (this.tab === 'review') {
      ReviewTab()
    } else if (this.tab === 'shop') {
      ShopTab()
    } else {
      ProfileTab()
    }
  }

  @Builder
  pageMap(name: string, param: Object) {
    NavDestination() {
      Stack() {
        Column() {
          this.routePage(param as AppRoute)
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: CONTENT_MAX_W })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .hideToolBar(true)
    .backgroundColor(C.bg)
    .onBackPressed(() => this.router.handleBack())
  }

  @Builder
  routePage(route: AppRoute) {
    Stack() {
      if (route.name === 'bookList') {
        BookListPage()
      } else if (route.name === 'bookDetail') {
        BookDetailPage({ route: route })
      } else if (route.name === 'lesson') {
        LessonRunner({ route: route })
      } else if (route.name === 'lessonResult') {
        LessonResultPage({ route: route })
      } else if (route.name === 'reviewRunner') {
        ReviewRunner()
      } else if (route.name === 'achievements') {
        AchievementsPage()
      } else if (route.name === 'stories') {
        StoriesPage({ route: route })
      } else if (route.name === 'storyReader') {
        StoryReaderPage({ route: route })
      } else if (route.name === 'reading') {
        PassagesPage({ route: route })
      } else if (route.name === 'passageReader') {
        PassageReaderPage({ route: route })
      } else if (route.name === 'settings') {
        SettingsPage()
      } else if (route.name === 'guide') {
        UnitGuidePage({ route: route })
      } else if (route.name === 'jumpTest') {
        JumpTestPage({ route: route })
      } else if (route.name === 'remedy') {
        RemedyPage({ route: route })
      } else if (route.name === 'cards') {
        CardAlbumPage()
      } else if (route.name === 'learners') {
        LearnersPage()
      } else if (route.name === 'parent') {
        ParentOverviewPage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }

  /** 每日登录奖励弹层（iOS daily-reward overlay）。 */
  @Builder
  dailyReward() {
    ModalCard() {
      Mascot({ mood: 'cheer', sz: 100, illustrated: true })
      Text('每日奖励').fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      Row({ space: 8 }) {
        DuoIcon({ name: 'gem', sz: 26, color: C.beetle })
        Text(`+${this.pendingReward?.gems ?? 0} 宝石`).fontSize(F.title).fontWeight(W.heavy)
          .fontColor(C.beetle)
      }
      if ((this.pendingReward?.effectiveStreak ?? 0) > 0) {
        Text(`连胜 ${this.pendingReward?.effectiveStreak} 天`).fontSize(F.caption).fontWeight(W.bold)
          .fontColor(C.fox)
      }
      ChunkyButton({ label: '收下', onTap: () => {
        this.rewardDismissed = true;
        this.store.dismissDailyReward();
        Haptics.tap();
        SFXEngine.shared.play('purchase');
      } })
    }
  }

  /** 周一联赛结算弹层（iOS league-settle overlay）。 */
  @Builder
  leagueSettle() {
    ModalCard() {
      DuoIcon({ name: 'trophy', sz: 56, color: C.bee })
      Text(this.store.pendingLeagueResult?.promoted ? '晋级！' :
        (this.store.pendingLeagueResult?.demoted ? '降级了' : '守住了位置'))
        .fontSize(F.heading).fontWeight(W.heavy).fontColor(C.ink)
      Text(`上周排名第 ${this.store.pendingLeagueResult?.rank} · ` +
        `${League.tier(this.store.pendingLeagueResult?.tierBefore ?? '').name} → ` +
        `${League.tier(this.store.pendingLeagueResult?.tierAfter ?? '').name}`)
        .fontSize(F.caption).fontWeight(W.bold).fontColor(C.inkMuted).textAlign(TextAlign.Center)
      if ((this.store.pendingLeagueResult?.gems ?? 0) > 0) {
        Row({ space: 6 }) {
          DuoIcon({ name: 'gem', sz: 18, color: C.beetle })
          Text(`+${this.store.pendingLeagueResult?.gems} 宝石`).fontSize(F.subhead).fontWeight(W.heavy)
            .fontColor(C.beetle)
        }
      }
      ChunkyButton({ label: '继续', onTap: () => {
        this.leagueDismissed = true;
        Haptics.tap();
        this.store.clearPendingLeagueResult();
      } })
    }
  }

  build() {
    // 自绘栈导航：底层 Tab 壳 + 路由页全屏覆盖（按 routes 顺序叠放，栈顶在最上）。
    Stack() {
      if (!this.ready) {
        Column({ space: 16 }) {
          Mascot({ mood: 'happy', sz: 110, still: true, illustrated: true })
          LoadingProgress().width(36).color(C.primary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (!this.onboarded) {
        Onboarding()
      } else {
        ForEach([this.themeRev], (rev: number) => {
          Navigation(this.router.stack) {
            Column() {
              Column() {
                this.tabBody()
              }
              .width('100%')
              .constraintSize({ maxWidth: CONTENT_MAX_W })
              .layoutWeight(1)

              BottomTabBar({
                active: this.tab, onSelect: (t: AppTab) => {
                  this.router.clear(false);
                  this.tab = t;
                }
              })
            }
            .width('100%')
            .height('100%')
            .backgroundColor(C.bg)
          }
          .navDestination(this.pageMap)
          .mode(NavigationMode.Stack)
          .hideTitleBar(true)
          .hideToolBar(true)
          .width('100%')
          .height('100%')
          .backgroundColor(C.bg)
          .accessibilityLevel(this.overlayOpen ? 'no-hide-descendants' : 'auto')
        }, (rev: number) => `theme-${rev}`)

        if (this.pendingReward !== null && !this.rewardDismissed && !this.picking) {
          this.dailyReward()
        }
        if (this.pendingLeague && !this.leagueDismissed && !this.picking) {
          this.leagueSettle()
        }
      }
      if (this.ready && this.picking) {
        LearnerPicker()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
