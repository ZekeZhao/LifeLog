import { relationalStore } from '@kit.ArkData'
import { TABLE_APP_SESSION } from '../common/Constants'
import { AppSession } from '../model/AppSession'
import { getDbStore } from './DbHelper'

export class AppSessionDao {
  private context: Context

  constructor(context: Context) {
    this.context = context
  }

  async save(session: AppSession): Promise<void> {
    const store = await getDbStore(this.context)
    const sql =
      `INSERT OR REPLACE INTO ${TABLE_APP_SESSION} (id, email, access_token, refresh_token, user_id, expires_at) VALUES (?, ?, ?, ?, ?, ?)`
    await store.executeSql(sql, [
      1,
      session.email,
      session.accessToken,
      session.refreshToken,
      session.userId,
      session.expiresAt
    ])
  }

  async get(): Promise<AppSession | null> {
    const store = await getDbStore(this.context)
    const predicates = new relationalStore.RdbPredicates(TABLE_APP_SESSION)
    predicates.equalTo('id', 1)
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

  async clear(): Promise<void> {
    const store = await getDbStore(this.context)
    const predicates = new relationalStore.RdbPredicates(TABLE_APP_SESSION)
    predicates.equalTo('id', 1)
    await store.delete(predicates)
  }

  private mapRow(resultSet: relationalStore.ResultSet): AppSession {
    const idIdx = resultSet.getColumnIndex('id')
    const emailIdx = resultSet.getColumnIndex('email')
    const accessTokenIdx = resultSet.getColumnIndex('access_token')
    const refreshTokenIdx = resultSet.getColumnIndex('refresh_token')
    const userIdIdx = resultSet.getColumnIndex('user_id')
    const expiresAtIdx = resultSet.getColumnIndex('expires_at')

    const session: AppSession = {
      id: resultSet.getLong(idIdx),
      email: resultSet.getString(emailIdx),
      accessToken: resultSet.getString(accessTokenIdx),
      refreshToken: resultSet.getString(refreshTokenIdx),
      userId: resultSet.getString(userIdIdx),
      expiresAt: resultSet.getLong(expiresAtIdx)
    }
    return session
  }
}
