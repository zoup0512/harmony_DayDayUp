// EntryAbility —— 应用上下文初始化 + 载入 Index。
// UIAbilityContext 是整个服务的根：文件、缓存、Preferences、resourceManager 都从它派生。
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AppEnv } from '../services/Files';
import { ProgressStore } from '../stores/ProgressStore';
import { AudioPlayer } from '../services/Audio';
import { StreakReminders, ReminderContext } from '../services/Feedback';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      AppEnv.context = this.context;
    } catch (e) {
      // context 必须可用；启动失败会在页面呈现加载错误
      console.error(`[EntryAbility] context init failed ${JSON.stringify(e)}`);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index');
  }

  onForeground(): void {
    // 回前台：回心 / 跨日 / 联赛结算 / 提醒全部按当前时刻重算
    try {
      const store = ProgressStore.shared;
      store.refreshForNow();
    } catch (e) {
      // 进度尚未载入（首启竞态）—— Index 会再调用
    }
  }

  onBackground(): void {
    // 进后台：音频立刻停，不让声音在后台继续放
    try {
      AudioPlayer.shared.stop();
    } catch (e) {
      // 忽略
    }
  }
}
