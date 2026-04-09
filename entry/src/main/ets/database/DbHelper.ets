import { relationalStore } from '@kit.ArkData'
import { DB_NAME, TABLE_DAILY_RECORD } from '../common/Constants'

const SQL_CREATE_TABLE = `CREATE TABLE IF NOT EXISTS ${TABLE_DAILY_RECORD} (
  date TEXT PRIMARY KEY,
  breakfast INTEGER,
  lunch INTEGER,
  dinner INTEGER,
  weight REAL,
  body_fat REAL
)`

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1
}

let rdbStore: relationalStore.RdbStore | null = null

export async function getDbStore(context: Context): Promise<relationalStore.RdbStore> {
  if (rdbStore !== null) {
    return rdbStore
  }
  rdbStore = await relationalStore.getRdbStore(context, STORE_CONFIG)
  await rdbStore.executeSql(SQL_CREATE_TABLE)
  return rdbStore
}
