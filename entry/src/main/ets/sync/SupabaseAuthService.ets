import { AppSession } from '../model/AppSession'
import { getSupabaseConfig, SupabaseRuntimeConfig } from './SupabaseConfig'
import { HarmonyHeaders, HarmonyHttpClient } from './HarmonyHttpClient'

class SendOtpRequest {
  email: string = ''
  create_user: boolean = true
}

class VerifyOtpRequest {
  email: string = ''
  token: string = ''
  type: string = ''
}

class RefreshTokenRequest {
  refresh_token: string = ''
}

class SupabaseUserDto {
  id: string = ''
  email: string = ''
}

class SupabaseAuthResponseDto {
  access_token: string = ''
  refresh_token: string = ''
  expires_in: number = 0
  expires_at: number = 0
  user: SupabaseUserDto = new SupabaseUserDto()
}

export class SupabaseAuthService {
  private httpClient: HarmonyHttpClient = new HarmonyHttpClient()

  private getConfig(): SupabaseRuntimeConfig {
    return getSupabaseConfig()
  }

  isConfigured(): boolean {
    const config = this.getConfig()
    return config.enabled && config.projectUrl.length > 0 && config.anonKey.length > 0
  }

  async sendEmailOtp(email: string): Promise<void> {
    const config = this.getRequiredConfig()
    const payload = new SendOtpRequest()
    payload.email = email
    payload.create_user = true
    await this.httpClient.postJson(
      `${config.projectUrl}/auth/v1/otp`,
      this.createJsonHeaders(config, config.anonKey),
      JSON.stringify(payload)
    )
  }

  async verifyEmailOtp(email: string, token: string): Promise<AppSession> {
    const config = this.getRequiredConfig()
    const payload = new VerifyOtpRequest()
    payload.email = email
    payload.token = token
    payload.type = 'email'
    const responseText = await this.httpClient.postJson(
      `${config.projectUrl}/auth/v1/verify`,
      this.createJsonHeaders(config, config.anonKey),
      JSON.stringify(payload)
    )
    const response = this.parseAuthResponse(responseText)
    return this.mapSession(response, email)
  }

  async refreshSession(refreshToken: string): Promise<AppSession> {
    const config = this.getRequiredConfig()
    const responseText = await this.httpClient.postForm(
      `${config.projectUrl}/auth/v1/token?grant_type=refresh_token`,
      this.createFormHeaders(config, config.anonKey),
      this.createRefreshBody(refreshToken)
    )
    const response = this.parseAuthResponse(responseText)
    return this.mapSession(response, '')
  }

  async logout(accessToken: string): Promise<void> {
    const config = this.getRequiredConfig()
    await this.httpClient.postJson(
      `${config.projectUrl}/auth/v1/logout`,
      this.createBasicHeaders(config, accessToken),
      ''
    )
  }

  private getRequiredConfig(): SupabaseRuntimeConfig {
    const config = this.getConfig()
    if (!config.enabled || config.projectUrl.length === 0 || config.anonKey.length === 0) {
      throw new Error('Supabase auth is not configured')
    }
    return config
  }

  private createBasicHeaders(config: SupabaseRuntimeConfig, bearerToken: string): HarmonyHeaders {
    const headers = new HarmonyHeaders()
    headers.apikey = config.anonKey
    headers.Authorization = `Bearer ${bearerToken}`
    return headers
  }

  private createJsonHeaders(config: SupabaseRuntimeConfig, bearerToken: string): HarmonyHeaders {
    const headers = new HarmonyHeaders()
    headers.apikey = config.anonKey
    headers.Authorization = `Bearer ${bearerToken}`
    headers.contentType = 'application/json'
    return headers
  }

  private createFormHeaders(config: SupabaseRuntimeConfig, bearerToken: string): HarmonyHeaders {
    const headers = new HarmonyHeaders()
    headers.apikey = config.anonKey
    headers.Authorization = `Bearer ${bearerToken}`
    headers.contentType = 'application/x-www-form-urlencoded;charset=UTF-8'
    return headers
  }

  private createRefreshBody(refreshToken: string): string {
    const payload = new RefreshTokenRequest()
    payload.refresh_token = refreshToken
    return `refresh_token=${encodeURIComponent(payload.refresh_token)}`
  }

  private parseAuthResponse(responseText: string): SupabaseAuthResponseDto {
    return JSON.parse(responseText) as SupabaseAuthResponseDto
  }

  private mapSession(data: SupabaseAuthResponseDto, fallbackEmail: string): AppSession {
    const user = data.user
    const expiresIn = data.expires_in > 0 ? data.expires_in : 3600
    const expiresAt = data.expires_at > 0 ? data.expires_at : 0
    const calculatedExpiresAt = expiresAt > 0
      ? expiresAt * 1000
      : Date.now() + expiresIn * 1000
    const session: AppSession = {
      id: 1,
      email: this.readUserEmail(user, fallbackEmail),
      accessToken: this.readString(data.access_token) ?? '',
      refreshToken: this.readString(data.refresh_token) ?? '',
      userId: this.readUserId(user),
      expiresAt: calculatedExpiresAt
    }
    return session
  }

  private readUserId(user: SupabaseUserDto | null): string {
    if (user === null || user === undefined || user.id === undefined) {
      return ''
    }
    return user.id
  }

  private readUserEmail(user: SupabaseUserDto | null, fallbackEmail: string): string {
    if (user !== null && user !== undefined && user.email !== undefined) {
      return user.email
    }
    return fallbackEmail
  }

  private readString(value: Object | undefined): string | null {
    if (value === null || value === undefined) {
      return null
    }
    return String(value)
  }

}
