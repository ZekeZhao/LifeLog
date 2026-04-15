export interface AppSession {
  id: number
  email: string
  accessToken: string
  refreshToken: string
  userId: string
  expiresAt: number
}
