import { DailyRecordDao } from '../database/DailyRecordDao'
import { DailyRecord } from '../model/DailyRecord'
import { AppColors, MealLevel } from '../common/Constants'

export type TrendPeriod = 'week' | 'month' | 'year'

export interface TrendDataPoint {
  date: string
  displayDate: string
  weight: number | null
  bodyFat: number | null
}

export interface TrendStats {
  totalDays: number
  healthyDays: number
  healthyRate: number // 0-100%
  avgWeight: number | null
  weightChange: number | null // last - first
  firstWeight: number | null
  lastWeight: number | null
}

export interface DateRange {
  startDate: string
  endDate: string
}

export interface ChartDataPoint {
  x: number
  y: number
  point: TrendDataPoint
}

export interface ChartBounds {
  minWeight: number
  maxWeight: number
}

@ObservedV2
export class TrendViewModel {
  @Trace period: TrendPeriod = 'week'
  @Trace dataPoints: TrendDataPoint[] = []
  @Trace stats: TrendStats = this.createEmptyStats()
  @Trace anchorDate: Date = new Date() // 当前查看时间段的锚点日期

  private createEmptyStats(): TrendStats {
    return {
      totalDays: 0,
      healthyDays: 0,
      healthyRate: 0,
      avgWeight: null,
      weightChange: null,
      firstWeight: null,
      lastWeight: null
    }
  }
  @Trace isLoading: boolean = false
  @Trace selectedPoint: TrendDataPoint | null = null
  @Trace showPointDetail: boolean = false

  private dao: DailyRecordDao

  constructor(context: Context) {
    this.dao = new DailyRecordDao(context)
  }

  async loadTrend(period: TrendPeriod): Promise<void> {
    this.period = period
    await this.loadTrendWithAnchor()
  }

  private getDateRange(period: TrendPeriod): DateRange {
    const anchor = new Date(this.anchorDate)
    let startDate: string
    let endDate: string

    switch (period) {
      case 'week':
        // 以 anchorDate 为结束，往前推7天
        endDate = this.formatDate(anchor)
        const weekAgo = new Date(anchor)
        weekAgo.setDate(weekAgo.getDate() - 6)
        startDate = this.formatDate(weekAgo)
        break
      case 'month':
        // 以 anchorDate 为结束，往前推30天
        endDate = this.formatDate(anchor)
        const monthAgo = new Date(anchor)
        monthAgo.setDate(monthAgo.getDate() - 29)
        startDate = this.formatDate(monthAgo)
        break
      case 'year':
        // 以 anchorDate 所在月份为结束，往前推12个月
        endDate = this.formatDate(anchor)
        const yearAgo = new Date(anchor)
        yearAgo.setFullYear(yearAgo.getFullYear() - 1)
        yearAgo.setDate(yearAgo.getDate() + 1)
        startDate = this.formatDate(yearAgo)
        break
      default:
        startDate = endDate = this.formatDate(anchor)
    }

    const result: DateRange = { startDate: startDate, endDate: endDate }
    return result
  }

  // 切换到上一时间段
  async goToPrevious(): Promise<void> {
    const newAnchor = new Date(this.anchorDate)
    switch (this.period) {
      case 'week':
        newAnchor.setDate(newAnchor.getDate() - 7)
        break
      case 'month':
        newAnchor.setDate(newAnchor.getDate() - 30)
        break
      case 'year':
        newAnchor.setFullYear(newAnchor.getFullYear() - 1)
        break
    }
    this.anchorDate = newAnchor
    await this.loadTrendWithAnchor()
  }

  // 切换到下一时间段
  async goToNext(): Promise<void> {
    const now = new Date()
    const newAnchor = new Date(this.anchorDate)

    switch (this.period) {
      case 'week':
        newAnchor.setDate(newAnchor.getDate() + 7)
        break
      case 'month':
        newAnchor.setDate(newAnchor.getDate() + 30)
        break
      case 'year':
        newAnchor.setFullYear(newAnchor.getFullYear() + 1)
        break
    }

    // 不允许超过今天
    if (newAnchor > now) {
      this.anchorDate = new Date()
    } else {
      this.anchorDate = newAnchor
    }
    await this.loadTrendWithAnchor()
  }

  // 回到今天
  async goToToday(): Promise<void> {
    this.anchorDate = new Date()
    await this.loadTrendWithAnchor()
  }

  // 数据加载完成回调
  onDataLoaded: (() => void) | null = null

  // 使用当前 anchorDate 加载数据
  private async loadTrendWithAnchor(): Promise<void> {
    this.isLoading = true

    const dateRange: DateRange = this.getDateRange(this.period)
    const records = await this.dao.queryByDateRange(dateRange.startDate, dateRange.endDate)

    // Process records into data points
    this.dataPoints = this.processRecords(records, dateRange.startDate, dateRange.endDate)

    // Calculate stats
    this.stats = this.calculateStats(records)

    this.isLoading = false

    // 触发回调通知页面数据已更新
    if (this.onDataLoaded) {
      this.onDataLoaded()
    }
  }

  // 获取当前查看范围的标题
  getRangeTitle(): string {
    const dateRange = this.getDateRange(this.period)
    const start = new Date(dateRange.startDate)
    const end = new Date(dateRange.endDate)

    const startMonth = start.getMonth() + 1
    const startDay = start.getDate()
    const endMonth = end.getMonth() + 1
    const endDay = end.getDate()

    if (this.period === 'year') {
      return `${start.getFullYear()}.${startMonth} - ${end.getFullYear()}.${endMonth}`
    }

    if (startMonth === endMonth) {
      return `${startMonth}月${startDay}日 - ${endDay}日`
    }
    return `${startMonth}月${startDay}日 - ${endMonth}月${endDay}日`
  }

  // 检查是否在最新时间段
  isAtLatest(): boolean {
    const now = new Date()
    const today = this.formatDate(now)
    const dateRange = this.getDateRange(this.period)
    return dateRange.endDate >= today
  }

  private processRecords(records: DailyRecord[], startDate: string, endDate: string): TrendDataPoint[] {
    // 年份视图按月聚合
    if (this.period === 'year') {
      return this.processYearlyRecords(records, startDate, endDate)
    }

    // Create a map for quick lookup
    const recordMap = new Map<string, DailyRecord>()
    records.forEach(r => recordMap.set(r.date, r))

    // Generate all dates in range
    const points: TrendDataPoint[] = []
    const start = new Date(startDate)
    const end = new Date(endDate)
    const current = new Date(start)

    while (current <= end) {
      const dateStr = this.formatDate(current)
      const record = recordMap.get(dateStr)

      points.push({
        date: dateStr,
        displayDate: this.formatDisplayDate(current, this.period),
        weight: record?.weight ?? null,
        bodyFat: record?.bodyFat ?? null
      })

      current.setDate(current.getDate() + 1)
    }

    return points
  }

  // 年份视图按月聚合数据
  private processYearlyRecords(records: DailyRecord[], startDate: string, endDate: string): TrendDataPoint[] {
    // 按月份分组
    const monthlyRecords = new Map<string, DailyRecord[]>()

    records.forEach(r => {
      if (r.weight !== null) {
        const date = new Date(r.date)
        const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
        if (!monthlyRecords.has(monthKey)) {
          monthlyRecords.set(monthKey, [])
        }
        monthlyRecords.get(monthKey)!.push(r)
      }
    })

    // 计算每月平均体重
    const points: TrendDataPoint[] = []
    const start = new Date(startDate)
    const end = new Date(endDate)
    const current = new Date(start.getFullYear(), start.getMonth(), 1)

    while (current <= end) {
      const monthKey = `${current.getFullYear()}-${String(current.getMonth() + 1).padStart(2, '0')}`
      const monthRecords = monthlyRecords.get(monthKey) || []

      // 计算该月平均体重
      let avgWeight: number | null = null
      let avgBodyFat: number | null = null

      if (monthRecords.length > 0) {
        const totalWeight = monthRecords.reduce((sum, r) => sum + (r.weight || 0), 0)
        const totalBodyFat = monthRecords.reduce((sum, r) => sum + (r.bodyFat || 0), 0)
        avgWeight = Math.round((totalWeight / monthRecords.length) * 10) / 10
        avgBodyFat = Math.round((totalBodyFat / monthRecords.length) * 10) / 10
      }

      points.push({
        date: this.formatDate(new Date(current.getFullYear(), current.getMonth(), 15)), // 月中作为代表日期
        displayDate: this.formatDisplayDate(current, 'year'),
        weight: avgWeight,
        bodyFat: avgBodyFat
      })

      current.setMonth(current.getMonth() + 1)
    }

    return points
  }

  private formatDisplayDate(date: Date, period: TrendPeriod): string {
    const month = date.getMonth() + 1
    const day = date.getDate()

    switch (period) {
      case 'week':
        return `${month}/${day}`
      case 'month':
        return `${month}/${day}`
      case 'year':
        return `${month}月`
      default:
        return `${month}/${day}`
    }
  }

  private calculateStats(records: DailyRecord[]): TrendStats {
    // Filter records with any data
    const validRecords = records.filter(r =>
      r.weight !== null || r.bodyFat !== null ||
      r.breakfast !== null || r.lunch !== null || r.dinner !== null
    )

    if (validRecords.length === 0) {
      const emptyStats: TrendStats = {
        totalDays: 0,
        healthyDays: 0,
        healthyRate: 0,
        avgWeight: null,
        weightChange: null,
        firstWeight: null,
        lastWeight: null
      }
      return emptyStats
    }

    // Count healthy days (all three meals are LIGHT)
    const healthyDays = validRecords.filter(r =>
      r.breakfast === MealLevel.LIGHT &&
      r.lunch === MealLevel.LIGHT &&
      r.dinner === MealLevel.LIGHT
    ).length

    // Calculate weight stats
    const weightRecords = validRecords.filter(r => r.weight !== null)
    let avgWeight: number | null = null
    let weightChange: number | null = null
    let firstWeight: number | null = null
    let lastWeight: number | null = null

    if (weightRecords.length > 0) {
      const weights = weightRecords.map(r => r.weight!)
      avgWeight = weights.reduce((a, b) => a + b, 0) / weights.length

      // Sort by date
      weightRecords.sort((a, b) => a.date.localeCompare(b.date))
      firstWeight = weightRecords[0].weight
      lastWeight = weightRecords[weightRecords.length - 1].weight

      if (firstWeight !== null && lastWeight !== null) {
        weightChange = lastWeight - firstWeight
      }
    }

    return {
      totalDays: validRecords.length,
      healthyDays,
      healthyRate: Math.round((healthyDays / validRecords.length) * 100),
      avgWeight,
      weightChange,
      firstWeight,
      lastWeight
    }
  }

  getPeriodLabel(): string {
    switch (this.period) {
      case 'week':
        return '近7天'
      case 'month':
        return '近30天'
      case 'year':
        return '近一年'
      default:
        return ''
    }
  }

  getPeriodOptions(): string[] {
    return ['周', '月', '年']
  }

  getPeriodIndex(): number {
    switch (this.period) {
      case 'week':
        return 0
      case 'month':
        return 1
      case 'year':
        return 2
      default:
        return 0
    }
  }

  async setPeriodByIndex(index: number): Promise<void> {
    const periods: TrendPeriod[] = ['week', 'month', 'year']
    await this.loadTrend(periods[index])
  }

  // Get weight data points for chart (only points with weight data)
  getWeightChartData(): ChartDataPoint[] {
    const validPoints = this.dataPoints.filter(p => p.weight !== null)
    if (validPoints.length < 2) return []

    const minWeight = Math.min(...validPoints.map(p => p.weight!))
    const maxWeight = Math.max(...validPoints.map(p => p.weight!))
    const weightRange = maxWeight - minWeight || 1

    const result: ChartDataPoint[] = []
    for (let i = 0; i < validPoints.length; i++) {
      const point = validPoints[i]
      const chartPoint: ChartDataPoint = {
        x: i / (validPoints.length - 1),
        y: 1 - (point.weight! - minWeight) / weightRange,
        point: point
      }
      result.push(chartPoint)
    }
    return result
  }

  getChartBounds(): ChartBounds {
    const validPoints = this.dataPoints.filter(p => p.weight !== null)
    if (validPoints.length === 0) {
      const defaultBounds: ChartBounds = { minWeight: 0, maxWeight: 100 }
      return defaultBounds
    }

    const minWeight = Math.min(...validPoints.map(p => p.weight!))
    const maxWeight = Math.max(...validPoints.map(p => p.weight!))
    const padding = (maxWeight - minWeight) * 0.1 || 5

    const bounds: ChartBounds = {
      minWeight: Math.round((minWeight - padding) * 10) / 10,
      maxWeight: Math.round((maxWeight + padding) * 10) / 10
    }
    return bounds
  }

  // Get body fat data points for chart (only points with bodyFat data)
  getBodyFatChartData(): ChartDataPoint[] {
    const validPoints = this.dataPoints.filter(p => p.bodyFat !== null)
    if (validPoints.length < 2) return []

    const minBodyFat = Math.min(...validPoints.map(p => p.bodyFat!))
    const maxBodyFat = Math.max(...validPoints.map(p => p.bodyFat!))
    const bodyFatRange = maxBodyFat - minBodyFat || 1

    const result: ChartDataPoint[] = []
    for (let i = 0; i < validPoints.length; i++) {
      const point = validPoints[i]
      const chartPoint: ChartDataPoint = {
        x: i / (validPoints.length - 1),
        y: 1 - (point.bodyFat! - minBodyFat) / bodyFatRange,
        point: point
      }
      result.push(chartPoint)
    }
    return result
  }

  getBodyFatChartBounds(): ChartBounds {
    const validPoints = this.dataPoints.filter(p => p.bodyFat !== null)
    if (validPoints.length === 0) {
      const defaultBounds: ChartBounds = { minWeight: 5, maxWeight: 40 }
      return defaultBounds
    }

    const minBodyFat = Math.min(...validPoints.map(p => p.bodyFat!))
    const maxBodyFat = Math.max(...validPoints.map(p => p.bodyFat!))
    const padding = (maxBodyFat - minBodyFat) * 0.1 || 2

    const bounds: ChartBounds = {
      minWeight: Math.round((minBodyFat - padding) * 10) / 10,
      maxWeight: Math.round((maxBodyFat + padding) * 10) / 10
    }
    return bounds
  }

  onPointClick(point: TrendDataPoint): void {
    if (point.weight !== null) {
      this.selectedPoint = point
      this.showPointDetail = true
    }
  }

  closePointDetail(): void {
    this.showPointDetail = false
    this.selectedPoint = null
  }

  private formatDate(date: Date): string {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }

  // ========== 测试工具方法 ==========

  /**
   * 生成最近30天的随机测试数据
   * @returns 生成的记录数量
   */
  async generateTestData(): Promise<number> {
    const records: DailyRecord[] = []
    const now = new Date()
    
    // 基础体重，会在70kg上下波动
    let baseWeight = 70 + Math.random() * 10 - 5
    
    for (let i = 29; i >= 0; i--) {
      const date = new Date(now)
      date.setDate(date.getDate() - i)
      const dateStr = this.formatDate(date)
      
      // 随机生成三餐（30%概率清淡，50%正常，20%放纵）
      const randomMeal = (): number => {
        const r = Math.random()
        if (r < 0.3) return 0 // 清淡
        if (r < 0.8) return 1 // 正常
        return 2 // 放纵
      }
      
      // 体重每天波动-0.3到+0.3kg
      baseWeight += (Math.random() - 0.5) * 0.6
      baseWeight = Math.max(50, Math.min(120, baseWeight)) // 限制在50-120kg
      
      // 体脂率根据体重推算（简单模拟）
      const bodyFat = Math.max(5, Math.min(40, baseWeight * 0.25 + (Math.random() - 0.5) * 3))
      
      // 10%概率某天没有记录（模拟漏记）
      if (Math.random() < 0.1) {
        continue
      }
      
      records.push({
        date: dateStr,
        breakfast: randomMeal(),
        lunch: randomMeal(),
        dinner: randomMeal(),
        weight: Math.round(baseWeight * 10) / 10,
        bodyFat: Math.round(bodyFat * 10) / 10
      })
    }
    
    // 批量保存记录
    for (const record of records) {
      await this.dao.upsert(record)
    }
    
    // 刷新当前趋势数据
    await this.loadTrend(this.period)
    
    return records.length
  }

  /**
   * 清空所有历史数据
   * @returns 删除的记录数量
   */
  async clearAllData(): Promise<number> {
    const deletedCount = await this.dao.deleteAll()
    
    // 清空当前数据
    this.dataPoints = []
    this.stats = this.createEmptyStats()
    
    return deletedCount
  }

  /**
   * 查询指定日期的记录
   * @param date 日期字符串 YYYY-MM-DD
   * @returns 记录或null
   */
  async queryByDate(date: string): Promise<DailyRecord | null> {
    return await this.dao.queryByDate(date)
  }

  /**
   * 保存记录（新增或修改）
   * @param record 记录对象
   */
  async saveRecord(record: DailyRecord): Promise<void> {
    await this.dao.upsert(record)
    // 刷新当前趋势数据
    await this.loadTrend(this.period)
  }

  /**
   * 删除指定日期的记录
   * @param date 日期字符串
   * @returns 是否删除成功
   */
  async deleteRecord(date: string): Promise<boolean> {
    const result = await this.dao.deleteByDate(date)
    if (result) {
      await this.loadTrend(this.period)
    }
    return result
  }
}
