import { DailyRecord, getTodayDateString } from '../model/DailyRecord'
import { ValidationRanges } from '../common/Constants'
import { getDailyRecordRepository, DailyRecordRepository } from '../repository/DailyRecordRepository'

export class ValidationResult {
  valid: boolean
  message: string

  constructor(valid: boolean, message: string = '') {
    this.valid = valid
    this.message = message
  }
}

// Get yesterday's date string
function getYesterdayDateString(): string {
  const now = new Date()
  now.setDate(now.getDate() - 1)
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

@ObservedV2
export class TodayViewModel {
  // Today's data: body measurements
  @Trace weightText: string = ''
  @Trace bodyFatText: string = ''
  @Trace isExistingRecord: boolean = false
  @Trace isSaving: boolean = false
  @Trace showSaveSuccess: boolean = false

  // Yesterday's data: meals
  @Trace yesterdayBreakfast: number | null = null
  @Trace yesterdayLunch: number | null = null
  @Trace yesterdayDinner: number | null = null

  repository: DailyRecordRepository
  private todayDate: string = getTodayDateString()
  private yesterdayDate: string = getYesterdayDateString()

  // 数据保存后的回调
  onDataSaved: (() => void) | null = null

  constructor(context: Context) {
    this.repository = getDailyRecordRepository(context)
  }

  async loadToday(): Promise<void> {
    this.todayDate = getTodayDateString()
    this.yesterdayDate = getYesterdayDateString()

    // Load today's body data
    const todayRecord = await this.repository.queryByDate(this.todayDate)
    if (todayRecord !== null) {
      this.weightText = todayRecord.weight !== null ? todayRecord.weight.toString() : ''
      this.bodyFatText = todayRecord.bodyFat !== null ? todayRecord.bodyFat.toString() : ''
      this.isExistingRecord = true
    } else {
      this.weightText = ''
      this.bodyFatText = ''
      this.isExistingRecord = false
    }

    // Load yesterday's meal data
    const yesterdayRecord = await this.repository.queryByDate(this.yesterdayDate)
    if (yesterdayRecord !== null) {
      this.yesterdayBreakfast = yesterdayRecord.breakfast
      this.yesterdayLunch = yesterdayRecord.lunch
      this.yesterdayDinner = yesterdayRecord.dinner
    } else {
      this.yesterdayBreakfast = null
      this.yesterdayLunch = null
      this.yesterdayDinner = null
    }
  }

  validateInputs(): ValidationResult {
    const weight = this.weightText.length > 0 ? parseFloat(this.weightText) : null
    const bodyFat = this.bodyFatText.length > 0 ? parseFloat(this.bodyFatText) : null

    if (weight !== null) {
      if (isNaN(weight)) {
        return new ValidationResult(false, '体重格式不正确')
      }
      if (weight < ValidationRanges.WEIGHT_MIN || weight > ValidationRanges.WEIGHT_MAX) {
        return new ValidationResult(false, `体重应在 ${ValidationRanges.WEIGHT_MIN}-${ValidationRanges.WEIGHT_MAX}kg 之间`)
      }
    }

    if (bodyFat !== null) {
      if (isNaN(bodyFat)) {
        return new ValidationResult(false, '体脂率格式不正确')
      }
      if (bodyFat < ValidationRanges.BODY_FAT_MIN || bodyFat > ValidationRanges.BODY_FAT_MAX) {
        return new ValidationResult(false, `体脂率应在 ${ValidationRanges.BODY_FAT_MIN}-${ValidationRanges.BODY_FAT_MAX}% 之间`)
      }
    }

    return new ValidationResult(true)
  }

  async save(): Promise<boolean> {
    this.isSaving = true
    try {
      const weight = this.weightText.length > 0 ? parseFloat(this.weightText) : null
      const bodyFat = this.bodyFatText.length > 0 ? parseFloat(this.bodyFatText) : null

      const validation: ValidationResult = this.validateInputs()
      if (!validation.valid) {
        this.isSaving = false
        return false
      }

      // Save today's body data
      const todayRecord: DailyRecord = {
        date: this.todayDate,
        breakfast: null,
        lunch: null,
        dinner: null,
        weight: weight,
        bodyFat: bodyFat,
      }
      await this.repository.save(todayRecord)

      // Save yesterday's meal data
      const yesterdayRecord: DailyRecord = {
        date: this.yesterdayDate,
        breakfast: this.yesterdayBreakfast,
        lunch: this.yesterdayLunch,
        dinner: this.yesterdayDinner,
        weight: null,
        bodyFat: null,
      }
      await this.repository.save(yesterdayRecord)

      this.isExistingRecord = true
      this.showSaveSuccess = true
      this.isSaving = false
      // 触发回调通知数据已保存
      if (this.onDataSaved) {
        this.onDataSaved()
      }
      return true
    } catch (e) {
      this.isSaving = false
      return false
    }
  }

  getTodayDisplay(): string {
    const parts = this.todayDate.split('-')
    return `${parts[0]} 年 ${parseInt(parts[1])} 月 ${parseInt(parts[2])} 日`
  }

  getWeekdayDisplay(): string {
    const days = ['日', '一', '二', '三', '四', '五', '六']
    const d = new Date(this.todayDate)
    return `星期${days[d.getDay()]}`
  }

  getYesterdayDisplay(): string {
    const parts = this.yesterdayDate.split('-')
    return `${parts[0]} 年 ${parseInt(parts[1])} 月 ${parseInt(parts[2])} 日`
  }

  async syncWithCloud(): Promise<void> {
    await this.repository.syncWithCloud()
    await this.loadToday()
  }
}
