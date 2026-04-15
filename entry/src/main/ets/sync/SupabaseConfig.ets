export interface SupabaseRuntimeConfig {
  enabled: boolean
  projectUrl: string
  anonKey: string
  accessToken: string
  userId: string
  tableName: string
}

export class SupabaseConfig {
  static readonly ENABLED: boolean = true
  static readonly PROJECT_URL: string = 'https://ssfhvzonkxkfiiefovjm.supabase.co'
  static readonly ANON_KEY: string = 'sb_publishable_BKjb1Y2qGK6RNxfG5hgATA_D7DOomg8'
  static readonly ACCESS_TOKEN: string = ''
  static readonly USER_ID: string = ''
  static readonly TABLE_NAME: string = 'daily_records'
}

let runtimeAccessToken: string = ''
let runtimeUserId: string = ''

export function setSupabaseSession(accessToken: string, userId: string): void {
  runtimeAccessToken = accessToken.trim()
  runtimeUserId = userId.trim()
}

export function clearSupabaseSession(): void {
  runtimeAccessToken = ''
  runtimeUserId = ''
}

export function getSupabaseConfig(): SupabaseRuntimeConfig {
  return {
    enabled: SupabaseConfig.ENABLED,
    projectUrl: SupabaseConfig.PROJECT_URL.trim(),
    anonKey: SupabaseConfig.ANON_KEY.trim(),
    accessToken: runtimeAccessToken.length > 0 ? runtimeAccessToken : SupabaseConfig.ACCESS_TOKEN.trim(),
    userId: runtimeUserId.length > 0 ? runtimeUserId : SupabaseConfig.USER_ID.trim(),
    tableName: SupabaseConfig.TABLE_NAME.trim().length > 0 ? SupabaseConfig.TABLE_NAME.trim() : 'daily_records'
  }
}
