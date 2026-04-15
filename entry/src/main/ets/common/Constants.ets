export class AppColors {
  static readonly BG: string = '#FAF9F6'
  static readonly CARD: string = '#FFFFFF'
  static readonly TEXT_PRIMARY: string = '#3D3029'
  static readonly TEXT_SECONDARY: string = '#8C7B6F'
  static readonly ACCENT: string = '#C47A3A'
  static readonly ACCENT_LIGHT: string = '#F5E6D3'
  static readonly INPUT_BORDER: string = '#D9D2C9'
  static readonly DIVIDER: string = '#EBE7E2'
  static readonly HEATMAP_GREEN: string = '#2D6A4F'
  static readonly HEATMAP_RED: string = '#D35233'
  static readonly HEATMAP_EMPTY: string = '#E8E4DF'
}

export class AppDimens {
  static readonly RADIUS_SM: number = 8
  static readonly RADIUS_MD: number = 12
  static readonly RADIUS_LG: number = 16
  static readonly PADDING_PAGE: number = 20
  static readonly PADDING_CARD: number = 16
  static readonly SHADOW_RADIUS: number = 8
  static readonly SHADOW_OFFSET_Y: number = 2
  static readonly SHADOW_COLOR: string = '#0A000000'
}

// Meal level enum for better readability
export enum MealLevel {
  LIGHT = 0,   // 清淡
  NORMAL = 1,  // 正常
  INDULGENT = 2 // 放纵
}

export const MEAL_LABELS: string[] = ['清淡', '正常', '放纵']

// Input validation ranges
export class ValidationRanges {
  static readonly WEIGHT_MIN: number = 20
  static readonly WEIGHT_MAX: number = 300
  static readonly BODY_FAT_MIN: number = 1
  static readonly BODY_FAT_MAX: number = 60
}

export enum SyncStatus {
  LOCAL_ONLY = 0,
  PENDING_UPLOAD = 1,
  SYNCED = 2,
  SYNC_FAILED = 3
}

export const DB_NAME = 'lifelog.db'
export const TABLE_DAILY_RECORD = 'daily_record'
export const TABLE_APP_SESSION = 'app_session'
