// 连胜卡片能力 —— FormExtensionAbility：桌面 2×2 卡片显示连胜火苗。
// 卡片数据由 WidgetSync（progress 每次存档时刷新）推进；点击卡片回到应用。
import { formBindingData, formInfo, FormExtensionAbility } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { WidgetSync } from '../services/WidgetSync';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string ?? '';
    if (formId.length > 0) {
      try {
        WidgetSync.addForm(this.context, formId);
      } catch (e) {
        // 卡片注册失败不影响主应用
      }
    }
    return WidgetSync.bindingData(this.context);
  }

  onRemoveForm(formId: string): void {
    try {
      WidgetSync.removeForm(this.context, formId);
    } catch (e) {
      // 忽略
    }
  }

  onUpdateForm(formId: string): void {
    try {
      WidgetSync.refreshAll(this.context);
    } catch (e) {
      // 忽略
    }
  }
}
