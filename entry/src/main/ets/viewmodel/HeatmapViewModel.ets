import { DailyRecord } from '../model/DailyRecord'
import { AppColors, MealLevel } from '../common/Constants'
import { DailyRecordRepository, getDailyRecordRepository } from '../repository/DailyRecordRepository'

export interface HeatmapCell {
  date: string
  day: number
  isCurrentMonth: boolean
  totalScore: number // 0-6
  breakfast: number | null
  lunch: number | null
  dinner: number | null
  weight: number | null
  bodyFat: number | null
  hasData: boolean
}

export interface HeatmapWeek {
  weekIndex: number
  cells: HeatmapCell[]
}

export interface MonthSummary {
  totalDays: number
  recordedDays: number
  healthyDays: number
}

@ObservedV2
export class HeatmapViewModel {
  @Trace year: number = new Date().getFullYear()
  @Trace month: number = new Date().getMonth() + 1
  @Trace weeks: HeatmapWeek[] = []
  @Trace isLoading: boolean = false
  @Trace selectedCell: HeatmapCell | null = null
  @Trace showDetailDialog: boolean = false
  @Trace showEditDialog: boolean = false
  @Trace editingRecord: HeatmapCell | null = null
  @Trace summary: MonthSummary = { totalDays: 0, recordedDays: 0, healthyDays: 0 } as MonthSummary

  private repository: DailyRecordRepository
  private recordsMap: Map<string, DailyRecord> = new Map()

  constructor(context: Context) {
    this.repository = getDailyRecordRepository(context)
  }

  getMonthTitle(): string {
    return `${this.year}年${this.month}月`
  }

  getTodayDate(): string {
    const now = new Date()
    const y = now.getFullYear()
    const m = String(now.getMonth() + 1).padStart(2, '0')
    const d = String(now.getDate()).padStart(2, '0')
    return `${y}-${m}-${d}`
  }

  async loadMonth(year: number, month: number): Promise<void> {
    this.isLoading = true
    this.year = year
    this.month = month

    const startDate = `${year}-${String(month).padStart(2, '0')}-01`
    const lastDay = new Date(year, month, 0).getDate()
    const endDate = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`

    const records = await this.repository.queryByDateRange(startDate, endDate)
    this.recordsMap.clear()
    records.forEach((r: DailyRecord) => this.recordsMap.set(r.date, r))

    this.weeks = this.buildMonthGrid(year, month)
    this.summary = this.calcSummary(records, lastDay)
    this.isLoading = false
  }

  private buildMonthGrid(year: number, month: number): HeatmapWeek[] {
    const weeks: HeatmapWeek[] = []
    const firstDay = new Date(year, month - 1, 1)
    const lastDay = new Date(year, month, 0).getDate()

    // Monday-based offset: Monday=0, Sunday=6
    const firstDayOfWeek = firstDay.getDay()
    const startOffset = firstDayOfWeek === 0 ? 6 : firstDayOfWeek - 1

    let currentDay = 1 - startOffset
    let weekIndex = 0

    while (currentDay <= lastDay) {
      const weekCells: HeatmapCell[] = []

      for (let i = 0; i < 7; i++) {
        const isCurrentMonth = currentDay >= 1 && currentDay <= lastDay

        if (isCurrentMonth) {
          const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(currentDay).padStart(2, '0')}`
          const record = this.recordsMap.get(dateStr)
          const cell: HeatmapCell = {
            date: dateStr,
            day: currentDay,
            isCurrentMonth: true,
            totalScore: this.calculateTotalScore(record),
            breakfast: record?.breakfast ?? null,
            lunch: record?.lunch ?? null,
            dinner: record?.dinner ?? null,
            weight: record?.weight ?? null,
            bodyFat: record?.bodyFat ?? null,
            hasData: record !== undefined
          }
          weekCells.push(cell)
        } else {
          const placeholderDate = new Date(year, month - 1, currentDay)
          const cell: HeatmapCell = {
            date: this.formatDate(placeholderDate),
            day: placeholderDate.getDate(),
            isCurrentMonth: false,
            totalScore: 0,
            breakfast: null,
            lunch: null,
            dinner: null,
            weight: null,
            bodyFat: null,
            hasData: false
          }
          weekCells.push(cell)
        }

        currentDay++
      }

      const week: HeatmapWeek = { weekIndex: weekIndex, cells: weekCells }
      weeks.push(week)
      weekIndex++
    }

    return weeks
  }

  private calcSummary(records: DailyRecord[], totalDays: number): MonthSummary {
    const healthyDays = records.filter((r: DailyRecord) =>
      r.breakfast === MealLevel.LIGHT &&
      r.lunch === MealLevel.LIGHT &&
      r.dinner === MealLevel.LIGHT
    ).length

    const result: MonthSummary = {
      totalDays: totalDays,
      recordedDays: records.length,
      healthyDays: healthyDays
    }
    return result
  }

  private calculateTotalScore(record: DailyRecord | undefined): number {
    if (!record) return 0
    const b = record.breakfast !== null ? record.breakfast : 0
    const l = record.lunch !== null ? record.lunch : 0
    const d = record.dinner !== null ? record.dinner : 0
    return b + l + d
  }

  getCellColor(cell: HeatmapCell): string {
    if (!cell.hasData) return AppColors.HEATMAP_EMPTY
    const ratio = cell.totalScore / 6
    return this.interpolateColor(AppColors.HEATMAP_GREEN, AppColors.HEATMAP_RED, ratio)
  }

  private interpolateColor(color1: string, color2: string, ratio: number): string {
    const hex1 = color1.replace('#', '')
    const hex2 = color2.replace('#', '')

    const r1 = parseInt(hex1.substring(0, 2), 16)
    const g1 = parseInt(hex1.substring(2, 4), 16)
    const b1 = parseInt(hex1.substring(4, 6), 16)

    const r2 = parseInt(hex2.substring(0, 2), 16)
    const g2 = parseInt(hex2.substring(2, 4), 16)
    const b2 = parseInt(hex2.substring(4, 6), 16)

    const r = Math.round(r1 + (r2 - r1) * ratio)
    const g = Math.round(g1 + (g2 - g1) * ratio)
    const b = Math.round(b1 + (b2 - b1) * ratio)

    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`
  }

  onCellClick(cell: HeatmapCell): void {
    if (cell.hasData) {
      this.selectedCell = cell
      this.showDetailDialog = true
    }
  }

  closeDetailDialog(): void {
    this.showDetailDialog = false
    this.selectedCell = null
  }

  startEdit(cell: HeatmapCell): void {
    this.editingRecord = cell
    this.showEditDialog = true
  }

  closeEditDialog(): void {
    this.showEditDialog = false
    this.editingRecord = null
  }

  goToPreviousMonth(): void {
    if (this.month === 1) {
      this.loadMonth(this.year - 1, 12)
    } else {
      this.loadMonth(this.year, this.month - 1)
    }
  }

  goToNextMonth(): void {
    if (this.month === 12) {
      this.loadMonth(this.year + 1, 1)
    } else {
      this.loadMonth(this.year, this.month + 1)
    }
  }

  goToToday(): void {
    const now = new Date()
    this.loadMonth(now.getFullYear(), now.getMonth() + 1)
  }

  getMealLabel(mealValue: number | null): string {
    if (mealValue === null) return '未记录'
    const labels: string[] = ['清淡', '正常', '放纵']
    return labels[mealValue] ?? '未记录'
  }

  private formatDate(date: Date): string {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }
}
