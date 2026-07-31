import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const PREFERENCE_NAME: string = 'arkinterview_study_preferences';
const PRACTICE_COUNT_KEY: string = 'default_practice_count';
const DEFAULT_PRACTICE_COUNT: number = 20;

export class StudyPreferenceStore {
  private static currentPracticeCount: number = DEFAULT_PRACTICE_COUNT;
  private static preference: preferences.Preferences | undefined = undefined;
  private static initTask: Promise<void> | null = null;

  static initialize(context: common.UIAbilityContext): Promise<void> {
    if (StudyPreferenceStore.initTask === null) {
      StudyPreferenceStore.initTask = StudyPreferenceStore.load(context);
    }
    return StudyPreferenceStore.initTask;
  }

  static practiceCount(): number {
    return StudyPreferenceStore.currentPracticeCount;
  }

  static async setPracticeCount(count: number): Promise<void> {
    if (!StudyPreferenceStore.isSupportedCount(count)) {
      throw new Error('unsupported default practice count');
    }
    if (StudyPreferenceStore.preference === undefined) {
      throw new Error('study preferences are not initialized');
    }
    try {
      await StudyPreferenceStore.preference.put(PRACTICE_COUNT_KEY, count);
      await StudyPreferenceStore.preference.flush();
      StudyPreferenceStore.currentPracticeCount = count;
    } catch (error) {
      throw new Error(`study preference save failed: ${String(error)}`);
    }
  }

  private static async load(context: common.UIAbilityContext): Promise<void> {
    try {
      const preference = await preferences.getPreferences(context, { name: PREFERENCE_NAME });
      StudyPreferenceStore.preference = preference;
      const value = await preference.get(PRACTICE_COUNT_KEY, DEFAULT_PRACTICE_COUNT);
      const count = typeof value === 'number' ? value : DEFAULT_PRACTICE_COUNT;
      StudyPreferenceStore.currentPracticeCount =
        StudyPreferenceStore.isSupportedCount(count) ? count : DEFAULT_PRACTICE_COUNT;
    } catch (error) {
      throw new Error(`study preferences initialization failed: ${String(error)}`);
    }
  }

  private static isSupportedCount(count: number): boolean {
    return count === 5 || count === 10 || count === 20 || count === 30;
  }
}
