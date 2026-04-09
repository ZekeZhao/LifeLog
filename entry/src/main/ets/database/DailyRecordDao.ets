import { relationalStore } from '@kit.ArkData'
import { TABLE_DAILY_RECORD } from '../common/Constants'
import { DailyRecord } from '../model/DailyRecord'
import { getDbStore } from './DbHelper'

export class DailyRecordDao {
  private context: Context

  constructor(context: Context) {
    this.context = context
  }

  async upsert(record: DailyRecord): Promise<void> {
    const store = await getDbStore(this.context)
    const sql = `INSERT OR REPLACE INTO ${TABLE_DAILY_RECORD} (date, breakfast, lunch, dinner, weight, body_fat) VALUES (?, ?, ?, ?, ?, ?)`
    await store.executeSql(sql, [
      record.date,
      record.breakfast,
      record.lunch,
      record.dinner,
      record.weight,
      record.bodyFat
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

    return {
      date: resultSet.getString(dateIdx),
      breakfast: resultSet.isColumnNull(breakfastIdx) ? null : resultSet.getLong(breakfastIdx),
      lunch: resultSet.isColumnNull(lunchIdx) ? null : resultSet.getLong(lunchIdx),
      dinner: resultSet.isColumnNull(dinnerIdx) ? null : resultSet.getLong(dinnerIdx),
      weight: resultSet.isColumnNull(weightIdx) ? null : resultSet.getDouble(weightIdx),
      bodyFat: resultSet.isColumnNull(bodyFatIdx) ? null : resultSet.getDouble(bodyFatIdx),
    } as DailyRecord
  }
}
