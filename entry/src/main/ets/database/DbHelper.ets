import { relationalStore } from '@kit.ArkData'
import { DB_NAME, TABLE_APP_SESSION, TABLE_DAILY_RECORD } from '../common/Constants'

const SQL_CREATE_TABLE = `CREATE TABLE IF NOT EXISTS ${TABLE_DAILY_RECORD} (
  date TEXT PRIMARY KEY,
  breakfast INTEGER,
  lunch INTEGER,
  dinner INTEGER,
  weight REAL,
  body_fat REAL,
  user_id TEXT,
  created_at TEXT,
  updated_at TEXT,
  sync_status INTEGER DEFAULT 0
)`

const SQL_CREATE_SESSION_TABLE = `CREATE TABLE IF NOT EXISTS ${TABLE_APP_SESSION} (
  id INTEGER PRIMARY KEY,
  email TEXT NOT NULL,
  access_token TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  user_id TEXT NOT NULL,
  expires_at INTEGER NOT NULL
)`

const SQL_MIGRATIONS: string[] = [
  `ALTER TABLE ${TABLE_DAILY_RECORD} ADD COLUMN user_id TEXT`,
  `ALTER TABLE ${TABLE_DAILY_RECORD} ADD COLUMN created_at TEXT`,
  `ALTER TABLE ${TABLE_DAILY_RECORD} ADD COLUMN updated_at TEXT`,
  `ALTER TABLE ${TABLE_DAILY_RECORD} ADD COLUMN sync_status INTEGER DEFAULT 0`
]

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
  await rdbStore.executeSql(SQL_CREATE_SESSION_TABLE)
  for (const migration of SQL_MIGRATIONS) {
    try {
      await rdbStore.executeSql(migration)
    } catch (_err) {
      // Ignore duplicate-column migrations on upgraded installs.
    }
  }
  return rdbStore
}
