export class FormatUtils {
  static percent(value: number): string {
    return `${Math.round(value * 100)}%`;
  }
}
