export class PracticeEvents {
  private static statsVersion: number = 0;

  static markStatsChanged(): void {
    PracticeEvents.statsVersion++;
  }

  static currentStatsVersion(): number {
    return PracticeEvents.statsVersion;
  }
}
