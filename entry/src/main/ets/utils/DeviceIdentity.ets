import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { util } from '@kit.ArkTS';

const PREFERENCE_NAME: string = 'arkinterview_identity';
const DEVICE_ID_KEY: string = 'anonymous_device_id';
const DEVICE_ID_PREFIX: string = 'ark-';

export class DeviceIdentity {
  private static currentId: string = '';
  private static initTask: Promise<void> | null = null;

  static initialize(context: common.UIAbilityContext): Promise<void> {
    if (DeviceIdentity.initTask === null) {
      DeviceIdentity.initTask = DeviceIdentity.load(context);
    }
    return DeviceIdentity.initTask;
  }

  static getId(): string {
    if (DeviceIdentity.currentId.length === 0) {
      DeviceIdentity.currentId = DeviceIdentity.createId();
    }
    return DeviceIdentity.currentId;
  }

  private static async load(context: common.UIAbilityContext): Promise<void> {
    try {
      const preference = await preferences.getPreferences(context, { name: PREFERENCE_NAME });
      const value = await preference.get(DEVICE_ID_KEY, '');
      const storedId = typeof value === 'string' ? value.trim() : '';
      if (DeviceIdentity.isValid(storedId)) {
        DeviceIdentity.currentId = storedId;
        return;
      }

      const generatedId = DeviceIdentity.createId();
      DeviceIdentity.currentId = generatedId;
      await preference.put(DEVICE_ID_KEY, generatedId);
      await preference.flush();
    } catch (error) {
      throw new Error(`anonymous identity initialization failed: ${String(error)}`);
    }
  }

  private static createId(): string {
    return `${DEVICE_ID_PREFIX}${util.generateRandomUUID(false)}`;
  }

  private static isValid(value: string): boolean {
    return value.startsWith(DEVICE_ID_PREFIX) && value.length === 40;
  }
}
