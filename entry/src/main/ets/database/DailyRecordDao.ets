import { relationalStore } from '@kit.ArkData'
import { SyncStatus, TABLE_DAILY_RECORD } from '../common/Constants'
import { DailyRecord } from '../model/DailyRecord'
import { getDbStore } from './DbHelper'

export class DailyRecordDao {
  private context: Context

  constructor(context: Context) {
    this.context = context
  }

  async upsert(record: DailyRecord): Promise<void> {
    const store = await getDbStore(this.context)
    const sql = `INSERT OR REPLACE INTO ${TABLE_DAILY_RECORD} (date, breakfast, lunch, dinner, weight, body_fat, user_id, created_at, updated_at, sync_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    await store.executeSql(sql, [
      record.date,
      record.breakfast,
      record.lunch,
      record.dinner,
      record.weight,
      record.bodyFat,
      record.userId ?? null,
      record.createdAt ?? null,
      record.updatedAt ?? null,
      record.syncStatus ?? SyncStatus.LOCAL_ONLY
    ])
  }

  async queryByDate(date: string): Promise<DailyRecord | null> {
    const store = await getDbStore(this.context)
    const predicates = new relationalStore.RdbPredicates(TABLE_DAILY_RECORD)
    predicates.equalTo('date', date)
    const resultSet = await store.query(predicates)
    try {
      if (resultSet.goToFirstRow()) {
        return this.mapRow(resultSet)
      }
      return null
    } finally {
      resultSet.close()
    }
  }

  async queryByDateRange(startDate: string, endDate: string): Promise<DailyRecord[]> {
    const store = await getDbStore(this.context)
    const predicates = new relationalStore.RdbPredicates(TABLE_DAILY_RECORD)
    predicates.between('date', startDate, endDate)
    predicates.orderByAsc('date')
    const resultSet = await store.query(predicates)
    const results: DailyRecord[] = []
    try {
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet))
      }
    } finally {
      resultSet.close()
    }
    return results
  }

  async queryByYear(year: number): Promise<DailyRecord[]> {
    const startDate = `${year}-01-01`
    const endDate = `${year}-12-31`
    return this.queryByDateRange(startDate, endDate)
  }

  async queryAll(): Promise<DailyRecord[]> {
    const store = await getDbStore(this.context)
    const predicates = new relationalStore.RdbPredicates(TABLE_DAILY_RECORD)
    predicates.orderByAsc('date')
    const resultSet = await store.query(predicates)
    const results: DailyRecord[] = []
    try {
      while (resultSet.goToNextRow()) {
        results.push(this.mapRow(resultSet))
      }
    } finally {
      resultSet.close()
    }
    return results
  }

  async queryPendingSync(): Promise<DailyRecord[]> {
    const records = await this.queryAll()
    return records.filter((record: DailyRecord) =>
      record.syncStatus === SyncStatus.LOCAL_ONLY ||
      record.syncStatus === SyncStatus.PENDING_UPLOAD ||
      record.syncStatus === SyncStatus.SYNC_FAILED
    )
  }

  async markAsSynced(date: string, userId: string | null, updatedAt: string | null): Promise<void> {
    const store = await getDbStore(this.context)
    const sql = `UPDATE ${TABLE_DAILY_RECORD} SET user_id = ?, updated_at = ?, sync_status = ? WHERE date = ?`
    await store.executeSql(sql, [userId, updatedAt, SyncStatus.SYNCED, date])
  }

  async markSyncFailed(date: string): Promise<void> {
    const store = await getDbStore(this.context)
    const sql = `UPDATE ${TABLE_DAILY_RECORD} SET sync_status = ? WHERE date = ?`
    await store.executeSql(sql, [SyncStatus.SYNC_FAILED, date])
  }

  async deleteByDate(date: string): Promise<boolean> {
    const store = await getDbStore(this.context)
    const predicates = new relationalStore.RdbPredicates(TABLE_DAILY_RECORD)
    predicates.equalTo('date', date)
    const deletedRows = await store.delete(predicates)
    return deletedRows > 0
  }

  async deleteAll(): Promise<number> {
    const store = await getDbStore(this.context)
    const predicates = new relationalStore.RdbPredicates(TABLE_DAILY_RECORD)
    const deletedRows = await store.delete(predicates)
    return deletedRows
  }

  private mapRow(resultSet: relationalStore.ResultSet): DailyRecord {
    const dateIdx = resultSet.getColumnIndex('date')
    const breakfastIdx = resultSet.getColumnIndex('breakfast')
    const lunchIdx = resultSet.getColumnIndex('lunch')
    const dinnerIdx = resultSet.getColumnIndex('dinner')
    const weightIdx = resultSet.getColumnIndex('weight')
    const bodyFatIdx = resultSet.getColumnIndex('body_fat')
    const userIdIdx = resultSet.getColumnIndex('user_id')
    const createdAtIdx = resultSet.getColumnIndex('created_at')
    const updatedAtIdx = resultSet.getColumnIndex('updated_at')
    const syncStatusIdx = resultSet.getColumnIndex('sync_status')

    return {
      date: resultSet.getString(dateIdx),
      breakfast: resultSet.isColumnNull(breakfastIdx) ? null : resultSet.getLong(breakfastIdx),
      lunch: resultSet.isColumnNull(lunchIdx) ? null : resultSet.getLong(lunchIdx),
      dinner: resultSet.isColumnNull(dinnerIdx) ? null : resultSet.getLong(dinnerIdx),
      weight: resultSet.isColumnNull(weightIdx) ? null : resultSet.getDouble(weightIdx),
      bodyFat: resultSet.isColumnNull(bodyFatIdx) ? null : resultSet.getDouble(bodyFatIdx),
      userId: userIdIdx >= 0 && !resultSet.isColumnNull(userIdIdx) ? resultSet.getString(userIdIdx) : null,
      createdAt: createdAtIdx >= 0 && !resultSet.isColumnNull(createdAtIdx) ? resultSet.getString(createdAtIdx) : null,
      updatedAt: updatedAtIdx >= 0 && !resultSet.isColumnNull(updatedAtIdx) ? resultSet.getString(updatedAtIdx) : null,
      syncStatus: syncStatusIdx >= 0 && !resultSet.isColumnNull(syncStatusIdx)
        ? resultSet.getLong(syncStatusIdx)
        : SyncStatus.LOCAL_ONLY,
    } as DailyRecord
  }
}
