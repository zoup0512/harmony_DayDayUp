// 应用根（MainShell）：种子安装 → 载入进度/设置 → 底部 Tab + 路由栈 + 全局结算弹层。
import { curves } from '@kit.ArkUI';
import { C, F, W, alpha } from '../design/Theme';
import { SeedInstaller } from '../services/DataLoader';
import { Files } from '../services/Files';
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
import { League } from '../domain/Seeded';

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
  @Local pushedRoutes: AppRoute[] = [];
  @Local pendingReward: DailyRewardClaim | null = null;
  @Local pendingLeague: boolean = false;
  @Local onboarded: boolean = false;

  private get tabBarHidden(): boolean {
    const n = this.pushedRoutes.length;
    return n > 0 && this.pushedRoutes[n - 1].immersive;
  }
  private tickTimer: number = -1;

  aboutToAppear(): void {
    this.router.onChange(() => {
      this.pushedRoutes = this.router.routes;
    });
    this.store.onChange(() => {
      this.pendingReward = this.store.pendingDailyReward;
      this.pendingLeague = this.store.pendingLeagueResult !== null;
      this.onboarded = this.store.hasCompletedOnboarding;
    });
    this.settings.load();
    SeedInstaller.installIfNeeded().catch(() => {
    }).finally(() => {
      this.store.load();
      this.onboarded = this.store.hasCompletedOnboarding;
      this.store.refreshForNow();
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

  /** 路由页面（自绘栈导航——Navigation 组件在本机上内容区不渲染，弃用）。 */
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
      Mascot({ mood: 'cheer', sz: 100 })
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
          Mascot({ mood: 'happy', sz: 110, still: true })
          LoadingProgress().width(36).color(C.primary)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (!this.onboarded) {
        Onboarding()
      } else {
        Column() {
          Column() {
            this.tabBody()
          }
          .layoutWeight(1)

          if (!this.tabBarHidden) {
            BottomTabBar({
              active: this.tab, onSelect: (t: AppTab) => {
                if (t !== this.tab) {
                  this.router.clear();
                  this.tab = t;
                }
              }
            })
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(C.bg)

        ForEach(this.pushedRoutes, (r: AppRoute, i: number) => {
          this.routePage(r)
        }, (r: AppRoute, i: number) => `${i}:${r.name}:${r.bookId}:${r.lessonId}:${r.itemId}`)

        if (this.pendingReward !== null && !this.rewardDismissed) {
          this.dailyReward()
        }
        if (this.pendingLeague && !this.leagueDismissed) {
          this.leagueSettle()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.bg)
  }
}
