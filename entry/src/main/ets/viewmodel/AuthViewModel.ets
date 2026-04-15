import { AppSession } from '../model/AppSession'
import { AppSessionDao } from '../database/AppSessionDao'
import { SupabaseAuthService } from '../sync/SupabaseAuthService'
import { clearSupabaseSession, setSupabaseSession } from '../sync/SupabaseConfig'

@ObservedV2
export class AuthViewModel {
  @Trace emailText: string = ''
  @Trace otpText: string = ''
  @Trace otpRequested: boolean = false
  @Trace isLoading: boolean = false
  @Trace isLoggedIn: boolean = false
  @Trace currentEmail: string = ''
  @Trace errorMessage: string = ''
  @Trace statusText: string = '未登录'

  private sessionDao: AppSessionDao
  private authService: SupabaseAuthService
  private currentSession: AppSession | null = null

  constructor(context: Context) {
    this.sessionDao = new AppSessionDao(context)
    this.authService = new SupabaseAuthService()
  }

  isConfigured(): boolean {
    return this.authService.isConfigured()
  }

  getActionLabel(): string {
    return this.isLoggedIn ? '云同步已连接' : '登录同步'
  }

  async restoreSession(): Promise<boolean> {
    this.errorMessage = ''
    if (!this.authService.isConfigured()) {
      this.statusText = '未配置 Supabase'
      return false
    }

    const storedSession = await this.sessionDao.get()
    if (storedSession === null) {
      this.statusText = '未登录'
      return false
    }

    this.isLoading = true
    try {
      let nextSession = storedSession
      if (this.shouldRefresh(storedSession)) {
        nextSession = await this.authService.refreshSession(storedSession.refreshToken)
        await this.sessionDao.save(nextSession)
      }
      this.applySession(nextSession)
      this.isLoading = false
      return true
    } catch (_err) {
      await this.sessionDao.clear()
      clearSupabaseSession()
      this.resetSessionState()
      this.errorMessage = '登录状态已失效，请重新获取验证码'
      this.isLoading = false
      return false
    }
  }

  async requestOtp(): Promise<boolean> {
    const email = this.emailText.trim()
    if (!this.isConfigured()) {
      this.errorMessage = '请先填写 Supabase 配置'
      return false
    }
    if (!this.isValidEmail(email)) {
      this.errorMessage = '请输入正确的邮箱地址'
      return false
    }
    this.isLoading = true
    this.errorMessage = ''
    try {
      await this.authService.sendEmailOtp(email)
      this.emailText = email
      this.otpRequested = true
      this.statusText = '验证码已发送'
      this.isLoading = false
      return true
    } catch (err) {
      this.errorMessage = this.extractErrorMessage(err)
      this.isLoading = false
      return false
    }
  }

  async verifyOtp(): Promise<boolean> {
    const email = this.emailText.trim()
    const otp = this.otpText.trim()
    if (!this.isValidEmail(email)) {
      this.errorMessage = '请输入正确的邮箱地址'
      return false
    }
    if (otp.length < 6) {
      this.errorMessage = '请输入 6 位验证码'
      return false
    }

    this.isLoading = true
    this.errorMessage = ''
    try {
      const session = await this.authService.verifyEmailOtp(email, otp)
      await this.sessionDao.save(session)
      this.applySession(session)
      this.otpText = ''
      this.otpRequested = false
      this.isLoading = false
      return true
    } catch (err) {
      this.errorMessage = this.extractErrorMessage(err)
      this.isLoading = false
      return false
    }
  }

  async signOut(): Promise<void> {
    this.isLoading = true
    try {
      if (this.currentSession !== null) {
        await this.authService.logout(this.currentSession.accessToken)
      }
    } catch (_err) {
      // Clear local session even if the remote logout request fails.
    }
    await this.sessionDao.clear()
    clearSupabaseSession()
    this.resetSessionState()
    this.isLoading = false
  }

  private applySession(session: AppSession): void {
    this.currentSession = session
    this.isLoggedIn = true
    this.currentEmail = session.email
    this.emailText = session.email
    this.statusText = '已登录'
    setSupabaseSession(session.accessToken, session.userId)
  }

  private resetSessionState(): void {
    this.currentSession = null
    this.isLoggedIn = false
    this.currentEmail = ''
    this.statusText = '未登录'
    this.otpRequested = false
    this.otpText = ''
  }

  private shouldRefresh(session: AppSession): boolean {
    return session.expiresAt <= Date.now() + 60 * 1000
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  }

  private extractErrorMessage(err: Object): string {
    if (err instanceof Error) {
      return err.message
    }
    return '请求失败，请稍后重试'
  }
}
