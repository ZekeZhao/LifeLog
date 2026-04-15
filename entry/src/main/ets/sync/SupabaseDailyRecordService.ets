import { DailyRecord, getCurrentTimestampString } from '../model/DailyRecord'
import { getSupabaseConfig, SupabaseRuntimeConfig } from './SupabaseConfig'
import { HarmonyHeaders, HarmonyHttpClient } from './HarmonyHttpClient'

class SupabaseRecordPayload {
  user_id: string = ''
  date: string = ''
  breakfast: number | null = null
  lunch: number | null = null
  dinner: number | null = null
  weight: number | null = null
  body_fat: number | null = null
  created_at: string = ''
  updated_at: string = ''
}

class SupabaseRecordDto {
  user_id: string = ''
  date: string = ''
  breakfast: number | null = null
  lunch: number | null = null
  dinner: number | null = null
  weight: number | null = null
  body_fat: number | null = null
  created_at: string = ''
  updated_at: string = ''
}

export class SupabaseDailyRecordService {
  private httpClient: HarmonyHttpClient = new HarmonyHttpClient()

  private getConfig(): SupabaseRuntimeConfig {
    return getSupabaseConfig()
  }

  isConfigured(): boolean {
    const config = this.getConfig()
    return config.enabled &&
      config.projectUrl.length > 0 &&
      config.anonKey.length > 0 &&
      config.accessToken.length > 0 &&
      config.userId.length > 0
  }

  getUserId(): string | null {
    const config = this.getConfig()
    return config.userId.length > 0 ? config.userId : null
  }

  async fetchRecords(): Promise<DailyRecord[]> {
    if (!this.isConfigured()) {
      return []
    }
    const config = this.getConfig()
    const url =
      `${config.projectUrl}/rest/v1/${config.tableName}?select=*&user_id=eq.${encodeURIComponent(config.userId)}&order=date.asc`
    const responseText = await this.httpClient.get(url, this.createHeaders(config))
    const response = this.parseRecordList(responseText)
    return response.map((item: SupabaseRecordDto) => this.mapRemoteRecord(item))
  }

  async upsertRecord(record: DailyRecord): Promise<DailyRecord> {
    if (!this.isConfigured()) {
      throw new Error('Supabase is not configured')
    }
    const config = this.getConfig()
    const payload = new SupabaseRecordPayload()
    payload.user_id = config.userId
    payload.date = record.date
    payload.breakfast = record.breakfast
    payload.lunch = record.lunch
    payload.dinner = record.dinner
    payload.weight = record.weight
    payload.body_fat = record.bodyFat
    payload.created_at = record.createdAt ?? getCurrentTimestampString()
    payload.updated_at = record.updatedAt ?? getCurrentTimestampString()
    const url = `${config.projectUrl}/rest/v1/${config.tableName}?on_conflict=user_id,date`
    const responseText = await this.httpClient.postJson(url, this.createJsonHeaders(config), JSON.stringify([payload]))
    const response = this.parseRecordList(responseText)
    if (response.length === 0) {
      const fallbackDto = this.createDtoFromPayload(payload)
      return this.mapRemoteRecord(fallbackDto)
    }
    return this.mapRemoteRecord(response[0])
  }

  private createHeaders(config: SupabaseRuntimeConfig): HarmonyHeaders {
    const headers = new HarmonyHeaders()
    headers.apikey = config.anonKey
    headers.Authorization = `Bearer ${config.accessToken}`
    return headers
  }

  private createJsonHeaders(config: SupabaseRuntimeConfig): HarmonyHeaders {
    const headers = new HarmonyHeaders()
    headers.apikey = config.anonKey
    headers.Authorization = `Bearer ${config.accessToken}`
    headers.contentType = 'application/json'
    headers.prefer = 'resolution=merge-duplicates,return=representation'
    return headers
  }

  private parseRecordList(responseText: string): SupabaseRecordDto[] {
    const data: Object = JSON.parse(responseText) as Object
    if (!Array.isArray(data)) {
      return []
    }
    return data as SupabaseRecordDto[]
  }

  private createDtoFromPayload(payload: SupabaseRecordPayload): SupabaseRecordDto {
    const dto = new SupabaseRecordDto()
    dto.user_id = payload.user_id
    dto.date = payload.date
    dto.breakfast = payload.breakfast
    dto.lunch = payload.lunch
    dto.dinner = payload.dinner
    dto.weight = payload.weight
    dto.body_fat = payload.body_fat
    dto.created_at = payload.created_at
    dto.updated_at = payload.updated_at
    return dto
  }

  private mapRemoteRecord(row: SupabaseRecordDto): DailyRecord {
    const record: DailyRecord = {
      date: row.date,
      breakfast: row.breakfast,
      lunch: row.lunch,
      dinner: row.dinner,
      weight: row.weight,
      bodyFat: row.body_fat,
      userId: this.readString(row.user_id),
      createdAt: this.readString(row.created_at),
      updatedAt: this.readString(row.updated_at)
    }
    return record
  }

  private readString(value: Object | undefined): string | null {
    if (value === null || value === undefined) {
      return null
    }
    return String(value)
  }
}
