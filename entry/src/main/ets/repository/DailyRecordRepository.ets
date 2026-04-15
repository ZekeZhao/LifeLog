import { SyncStatus } from '../common/Constants'
import { DailyRecord, getCurrentTimestampString } from '../model/DailyRecord'
import { DailyRecordDao } from '../database/DailyRecordDao'
import { SupabaseDailyRecordService } from '../sync/SupabaseDailyRecordService'

export interface SyncSummary {
  pushedCount: number
  pulledCount: number
  enabled: boolean
}

export class DailyRecordRepository {
  private dao: DailyRecordDao
  private supabaseService: SupabaseDailyRecordService

  constructor(context: Context) {
    this.dao = new DailyRecordDao(context)
    this.supabaseService = new SupabaseDailyRecordService()
  }

  async queryByDate(date: string): Promise<DailyRecord | null> {
    return await this.dao.queryByDate(date)
  }

  async queryByDateRange(startDate: string, endDate: string): Promise<DailyRecord[]> {
    return await this.dao.queryByDateRange(startDate, endDate)
  }

  async queryByYear(year: number): Promise<DailyRecord[]> {
    return await this.dao.queryByYear(year)
  }

  async save(record: DailyRecord): Promise<void> {
    const now = getCurrentTimestampString()
    const existing = await this.dao.queryByDate(record.date)
    const normalized: DailyRecord = {
      date: record.date,
      breakfast: record.breakfast,
      lunch: record.lunch,
      dinner: record.dinner,
      weight: record.weight,
      bodyFat: record.bodyFat,
      userId: existing?.userId ?? this.supabaseService.getUserId(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      syncStatus: this.supabaseService.isConfigured() ? SyncStatus.PENDING_UPLOAD : SyncStatus.LOCAL_ONLY
    }
    await this.dao.upsert(normalized)
    if (this.supabaseService.isConfigured()) {
      await this.syncWithCloud()
    }
  }

  async deleteByDate(date: string): Promise<boolean> {
    const deleted = await this.dao.deleteByDate(date)
    return deleted
  }

  async deleteAll(): Promise<number> {
    return await this.dao.deleteAll()
  }

  async queryAll(): Promise<DailyRecord[]> {
    return await this.dao.queryAll()
  }

  async syncWithCloud(): Promise<SyncSummary> {
    if (!this.supabaseService.isConfigured()) {
      return { pushedCount: 0, pulledCount: 0, enabled: false }
    }

    let pushedCount = 0
    const pendingRecords = await this.dao.queryPendingSync()
    for (const record of pendingRecords) {
      try {
        const syncedRecord = await this.supabaseService.upsertRecord(record)
        await this.dao.markAsSynced(
          syncedRecord.date,
          syncedRecord.userId ?? this.supabaseService.getUserId(),
          syncedRecord.updatedAt ?? record.updatedAt ?? getCurrentTimestampString()
        )
        pushedCount++
      } catch (_err) {
        await this.dao.markSyncFailed(record.date)
      }
    }

    let pulledCount = 0
    const remoteRecords = await this.supabaseService.fetchRecords()
    for (const remoteRecord of remoteRecords) {
      const localRecord = await this.dao.queryByDate(remoteRecord.date)
      if (this.shouldReplaceLocal(localRecord, remoteRecord)) {
        const syncedLocalRecord: DailyRecord = {
          date: remoteRecord.date,
          breakfast: remoteRecord.breakfast,
          lunch: remoteRecord.lunch,
          dinner: remoteRecord.dinner,
          weight: remoteRecord.weight,
          bodyFat: remoteRecord.bodyFat,
          userId: remoteRecord.userId,
          createdAt: remoteRecord.createdAt,
          updatedAt: remoteRecord.updatedAt,
          syncStatus: SyncStatus.SYNCED
        }
        await this.dao.upsert(syncedLocalRecord)
        pulledCount++
      }
    }

    return {
      pushedCount,
      pulledCount,
      enabled: true
    }
  }

  private shouldReplaceLocal(localRecord: DailyRecord | null, remoteRecord: DailyRecord): boolean {
    if (localRecord === null) {
      return true
    }
    if (localRecord.syncStatus === SyncStatus.PENDING_UPLOAD) {
      return false
    }
    const localUpdated = localRecord.updatedAt ?? ''
    const remoteUpdated = remoteRecord.updatedAt ?? ''
    return remoteUpdated >= localUpdated
  }
}

let repositoryInstance: DailyRecordRepository | null = null

export function getDailyRecordRepository(context: Context): DailyRecordRepository {
  if (repositoryInstance === null) {
    repositoryInstance = new DailyRecordRepository(context)
  }
  return repositoryInstance
}
