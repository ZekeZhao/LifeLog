export interface DailyRecord {
  date: string // YYYY-MM-DD, primary key
  breakfast: number | null // 0=清淡 1=正常 2=放纵
  lunch: number | null
  dinner: number | null
  weight: number | null // kg
  bodyFat: number | null // %
  userId?: string | null
  createdAt?: string | null
  updatedAt?: string | null
  syncStatus?: number
}

export function createEmptyRecord(date: string): DailyRecord {
  return {
    date: date,
    breakfast: null,
    lunch: null,
    dinner: null,
    weight: null,
    bodyFat: null,
    userId: null,
    createdAt: null,
    updatedAt: null,
    syncStatus: 0
  } as DailyRecord
}

export function getCurrentTimestampString(): string {
  return new Date().toISOString()
}

export function getTodayDateString(): string {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}
