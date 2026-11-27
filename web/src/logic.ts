// Port of StreetLog/Logic (Swift) — keep both in sync.

export type Lift = 'pullUp' | 'dip'
export const LIFTS: Lift[] = ['pullUp', 'dip']

export const liftTitle: Record<Lift, string> = { pullUp: 'Подтягивания', dip: 'Брусья' }
export const liftFullTitle: Record<Lift, string> = {
  pullUp: 'Подтягивания с отягощением',
  dip: 'Отжимания на брусьях с отягощением',
}

export interface DatedValue {
  date: number
  value: number
}

const DAY = 86_400_000

export function startOfDay(ts: number): number {
  const d = new Date(ts)
  d.setHours(0, 0, 0, 0)
  return d.getTime()
}

export function addDays(ts: number, days: number): number {
  const d = new Date(ts)
  d.setDate(d.getDate() + days)
  return d.getTime()
}

export function daysBetween(from: number, to: number): number {
  return Math.round((startOfDay(to) - startOfDay(from)) / DAY)
}

/** Monday-based week start. */
export function weekStart(ts: number): number {
  const d = new Date(startOfDay(ts))
  const offset = (d.getDay() + 6) % 7
  d.setDate(d.getDate() - offset)
  return d.getTime()
}

// MARK: 1RM

export const MAX_RELIABLE_REPS = 12

export function epley(weight: number, reps: number): number {
  return reps <= 1 ? weight : weight * (1 + reps / 30)
}

export function brzycki(weight: number, reps: number): number {
  return reps <= 1 ? weight : (weight * 36) / (37 - reps)
}

/** Formulas are applied to bodyweight + added weight; the result is converted back to added weight. */
export function estimatedAddedWeight(added: number, bodyweight: number, reps: number): number | null {
  if (reps < 1 || reps > MAX_RELIABLE_REPS || bodyweight <= 0 || added < 0) return null
  if (reps === 1) return added
  const system = bodyweight + added
  return (epley(system, reps) + brzycki(system, reps)) / 2 - bodyweight
}

// MARK: Trend

export interface LinearTrend {
  slopePerDay: number
  intercept: number
  referenceDate: number
}

export function linearTrend(points: DatedValue[]): LinearTrend | null {
  if (points.length < 2) return null
  const sorted = [...points].sort((a, b) => a.date - b.date)
  const ref = sorted[0].date
  const xs = sorted.map((p) => (p.date - ref) / DAY)
  const ys = sorted.map((p) => p.value)
  const n = sorted.length
  const meanX = xs.reduce((a, b) => a + b, 0) / n
  const meanY = ys.reduce((a, b) => a + b, 0) / n
  let num = 0
  let den = 0
  xs.forEach((x, i) => {
    num += (x - meanX) * (ys[i] - meanY)
    den += (x - meanX) ** 2
  })
  if (den <= 0) return null
  const slopePerDay = num / den
  return { slopePerDay, intercept: meanY - slopePerDay * meanX, referenceDate: ref }
}

export function trendValue(trend: LinearTrend, date: number): number {
  return trend.intercept + (trend.slopePerDay * (date - trend.referenceDate)) / DAY
}

export function trendReachDate(trend: LinearTrend, target: number): number | null {
  if (trend.slopePerDay <= 0) return null
  return trend.referenceDate + ((target - trend.intercept) / trend.slopePerDay) * DAY
}

// MARK: Forecast

export type ForecastStatus = 'reached' | 'onTrack' | 'behind' | 'projected' | 'notEnoughData'

export interface LiftForecast {
  current: number
  target: number
  trend: LinearTrend | null
  reachDate: number | null
  neededPerWeek: number | null
  status: ForecastStatus
}

export function makeForecast(
  current: number,
  target: number,
  points: DatedValue[],
  competition: number | null,
  today: number = Date.now(),
): LiftForecast {
  const trend = linearTrend(points)
  let reachDate: number | null = null
  if (trend && current < target) {
    const date = trendReachDate(trend, target)
    if (date !== null) reachDate = Math.max(date, today)
  }
  let neededPerWeek: number | null = null
  if (competition !== null && competition > today && current < target) {
    const weeks = (competition - today) / (7 * DAY)
    neededPerWeek = weeks > 0 ? (target - current) / weeks : null
  }
  let status: ForecastStatus
  if (target > 0 && current >= target) status = 'reached'
  else if (!trend) status = 'notEnoughData'
  else if (competition !== null) status = reachDate !== null && reachDate <= competition ? 'onTrack' : 'behind'
  else status = reachDate === null ? 'behind' : 'projected'
  return { current, target, trend, reachDate, neededPerWeek, status }
}

export function fraction(current: number, target: number): number {
  if (target <= 0) return 0
  return Math.min(Math.max(current / target, 0), 1)
}

// MARK: Attempts

export const PLATE_STEP = 1.25

export function roundTo(value: number, step: number = PLATE_STEP): number {
  return Math.round(value / step) * step
}

export function attemptPlan(currentMax: number, step: number = PLATE_STEP): number[] {
  if (currentMax <= 0) return []
  const result: number[] = []
  for (const percent of [0.92, 0.97, 1.01]) {
    let value = roundTo(currentMax * percent, step)
    const last = result[result.length - 1]
    if (last !== undefined && value <= last) value = last + step
    result.push(value)
  }
  return result
}

// MARK: Prep phase

export interface PrepPhase {
  kind: 'noDate' | 'offSeason' | 'base' | 'strength' | 'peaking' | 'taper' | 'competitionDay' | 'past'
  days: number
  title: string
  advice: string
  countdown: string | null
}

export function prepPhase(competition: number | null, today: number = Date.now()): PrepPhase {
  if (competition === null) {
    return {
      kind: 'noDate', days: 0, title: 'Дата старта не задана', countdown: null,
      advice: 'Укажите дату соревнований в профиле — приложение рассчитает фазу подготовки и нужный темп прироста.',
    }
  }
  const days = daysBetween(today, competition)
  const weeks = Math.floor(days / 7)
  if (days < 0) return { kind: 'past', days, title: 'Старт прошёл', countdown: null, advice: 'Запишите результаты соревнований как попытки и задайте дату следующего старта.' }
  if (days === 0) return { kind: 'competitionDay', days, title: 'День соревнований', countdown: 'Сегодня!', advice: 'Удачи на помосте! Начинайте с уверенного первого подхода.' }
  if (days <= 10) return { kind: 'taper', days, title: 'Разгрузка перед стартом', countdown: `${days} дн. до старта`, advice: 'Снижайте нагрузку на 40–60%, лёгкие разминочные подходы, сон и восстановление. Новых рекордов не ищите.' }
  if (days <= 28) return { kind: 'peaking', days, title: 'Подводка (пикинг)', countdown: `${days} дн. до старта`, advice: 'Тяжёлые одиночки и двойки на 90–97%, отработка соревновательной техники и команд судьи, объём минимальный.' }
  if (days <= 56) return { kind: 'strength', days, title: 'Силовой блок', countdown: `≈ ${weeks} нед. до старта`, advice: 'Интенсивность растёт: 3–5 подходов по 2–4 повторения на 80–90%, объём постепенно снижается.' }
  if (days <= 112) return { kind: 'base', days, title: 'Базовый (объёмный) блок', countdown: `≈ ${weeks} нед. до старта`, advice: 'Объём и техника: 4–6 подходов по 4–6 повторений на 70–80% от 1ПМ, 2–3 тренировки в неделю на каждое движение.' }
  return { kind: 'offSeason', days, title: 'Межсезонье', countdown: `≈ ${weeks} нед. до старта`, advice: 'Наращивайте объём: подходы по 6–10 повторений с отягощением 60–75% от 1ПМ, подсобка на спину, трицепс и грудь.' }
}

// MARK: Diary analytics

export interface LogItem {
  date: number
  exercise: string
  reps: number
  sets: number
  addedWeight: number
  /** Reps of each set when they differ (e.g. 8, 8, 8, 3); `reps` then holds the best set. */
  setReps?: number[]
}

export const itemReps = (i: LogItem) => (i.setReps?.length ? i.setReps.reduce((a, r) => a + r, 0) : i.reps * i.sets)
export const itemTonnage = (i: LogItem) => i.addedWeight * itemReps(i)
export const totalReps = (items: LogItem[]) => items.reduce((a, i) => a + itemReps(i), 0)
export const totalSets = (items: LogItem[]) => items.reduce((a, i) => a + i.sets, 0)

export function trainingDays(items: LogItem[]): Set<number> {
  return new Set(items.map((i) => startOfDay(i.date)))
}

export function weeklySum(items: LogItem[], value: (i: LogItem) => number): DatedValue[] {
  const buckets = new Map<number, number>()
  for (const item of items) {
    const key = weekStart(item.date)
    buckets.set(key, (buckets.get(key) ?? 0) + value(item))
  }
  return [...buckets.entries()].map(([date, v]) => ({ date, value: v })).sort((a, b) => a.date - b.date)
}

export function currentStreak(days: Set<number>, today: number = Date.now()): number {
  let cursor = startOfDay(today)
  if (!days.has(cursor)) {
    cursor = addDays(cursor, -1)
    if (!days.has(cursor)) return 0
  }
  let streak = 0
  while (days.has(cursor)) {
    streak += 1
    cursor = addDays(cursor, -1)
  }
  return streak
}

export function longestStreak(days: Set<number>): number {
  const sorted = [...days].sort((a, b) => a - b)
  let best = 0
  let current = 0
  let previous: number | null = null
  for (const day of sorted) {
    current = previous !== null && addDays(previous, 1) === day ? current + 1 : 1
    best = Math.max(best, current)
    previous = day
  }
  return best
}

export interface ExerciseTotal {
  name: string
  totalReps: number
  totalSets: number
  sessions: number
  maxWeight: number
}

export function exerciseTotals(items: LogItem[]): ExerciseTotal[] {
  const groups = new Map<string, LogItem[]>()
  for (const item of items) groups.set(item.exercise, [...(groups.get(item.exercise) ?? []), item])
  return [...groups.entries()]
    .map(([name, group]) => ({
      name,
      totalReps: totalReps(group),
      totalSets: totalSets(group),
      sessions: trainingDays(group).size,
      maxWeight: Math.max(0, ...group.map((i) => i.addedWeight)),
    }))
    .sort((a, b) => (a.totalReps === b.totalReps ? a.name.localeCompare(b.name) : b.totalReps - a.totalReps))
}

export function dailyProgress(items: LogItem[], exercise: string): DatedValue[] {
  const filtered = items.filter((i) => i.exercise === exercise)
  const weighted = filtered.some((i) => i.addedWeight > 0)
  const groups = new Map<number, LogItem[]>()
  for (const item of filtered) {
    const key = startOfDay(item.date)
    groups.set(key, [...(groups.get(key) ?? []), item])
  }
  return [...groups.entries()]
    .map(([date, group]) => ({
      date,
      value: weighted ? Math.max(...group.map((i) => i.addedWeight)) : totalReps(group),
    }))
    .sort((a, b) => a.date - b.date)
}

export function dailyMax(points: DatedValue[]): DatedValue[] {
  const groups = new Map<number, number>()
  for (const p of points) {
    const key = startOfDay(p.date)
    groups.set(key, Math.max(groups.get(key) ?? -Infinity, p.value))
  }
  return [...groups.entries()].map(([date, value]) => ({ date, value })).sort((a, b) => a.date - b.date)
}

/** "4 × 8" when all sets are equal, otherwise "8, 8, 8, 3". */
export function setsLabel(item: Pick<LogItem, 'reps' | 'sets' | 'setReps'>): string {
  const list = item.setReps
  if (list?.length && list.some((r) => r !== list[0])) return list.join(', ')
  return `${item.sets} × ${list?.length ? list[0] : item.reps}`
}

/** Normalizes per-set reps: equal sets collapse to plain sets × reps. */
export function normalizeSets(list: number[]): { sets: number; reps: number; setReps?: number[] } {
  const clean = list.filter((r) => r > 0)
  if (clean.length === 0) return { sets: 1, reps: 1 }
  const equal = clean.every((r) => r === clean[0])
  return equal ? { sets: clean.length, reps: clean[0] } : { sets: clean.length, reps: Math.max(...clean), setReps: clean }
}

// MARK: Standards

export type Federation = 'isf' | 'wsf'
export type SportRank = 'kms' | 'ms' | 'msmk'
export const FEDERATIONS: Federation[] = ['isf', 'wsf']
export const RANKS: SportRank[] = ['kms', 'ms', 'msmk']

export const federationTitle: Record<Federation, string> = { isf: 'ISF-Россия', wsf: 'WSF' }
export const federationSource: Record<Federation, string> = {
  isf: 'Нормативы ISF-Россия, классический стритлифтинг, мужчины, действуют с 01.01.2025 (streetlifting.ru)',
  wsf: 'Нормативы WSF 2025, мужчины, дивизион с допинг-контролем (по таблице региональной федерации WSF)',
}
export const rankTitle: Record<SportRank, string> = { kms: 'КМС', ms: 'МС', msmk: 'МСМК' }

export interface LiftNorms {
  pullUp: number
  dip: number
  total: number
}

export interface WeightClassStandard {
  federation: Federation
  limit: number
  lowerLimit: number
  norms: Record<SportRank, LiftNorms>
}

export const STANDARDS: WeightClassStandard[] = [
  { federation: 'isf', limit: 67.5, lowerLimit: 60, norms: {
    kms: { pullUp: 60, dip: 85, total: 135 },
    ms: { pullUp: 67.5, dip: 100, total: 152.5 },
    msmk: { pullUp: 77.5, dip: 112.5, total: 180 },
  } },
  { federation: 'isf', limit: 75, lowerLimit: 67.5, norms: {
    kms: { pullUp: 65, dip: 90, total: 145 },
    ms: { pullUp: 72.5, dip: 105, total: 165 },
    msmk: { pullUp: 82.5, dip: 117.5, total: 190 },
  } },
  { federation: 'wsf', limit: 67.5, lowerLimit: 60, norms: {
    kms: { pullUp: 55, dip: 77.5, total: 122.5 },
    ms: { pullUp: 62.5, dip: 90, total: 140 },
    msmk: { pullUp: 72.5, dip: 107.5, total: 170 },
  } },
  { federation: 'wsf', limit: 75, lowerLimit: 67.5, norms: {
    kms: { pullUp: 60, dip: 82.5, total: 132.5 },
    ms: { pullUp: 67.5, dip: 95, total: 152.5 },
    msmk: { pullUp: 77.5, dip: 112.5, total: 180 },
  } },
]

export const classTitle = (s: WeightClassStandard) => `до ${num(s.limit)} кг`

export function classesFor(federation: Federation): WeightClassStandard[] {
  return STANDARDS.filter((s) => s.federation === federation).sort((a, b) => a.limit - b.limit)
}

export function lookupStandard(federation: Federation, limit: number): WeightClassStandard | undefined {
  return STANDARDS.find((s) => s.federation === federation && s.limit === limit)
}

export function classFor(bodyweight: number, federation: Federation): WeightClassStandard | undefined {
  return classesFor(federation).find((s) => bodyweight > s.lowerLimit && bodyweight <= s.limit)
}

export function achievedRank(standard: WeightClassStandard, total: number): SportRank | null {
  for (const rank of [...RANKS].reverse()) {
    if (total >= standard.norms[rank].total) return rank
  }
  return null
}

export function splitTotal(norms: LiftNorms, step: number = PLATE_STEP): { pullUp: number; dip: number } {
  const sum = norms.pullUp + norms.dip
  if (sum <= 0) return { pullUp: 0, dip: 0 }
  const pullUp = roundTo((norms.total * norms.pullUp) / sum, step)
  return { pullUp, dip: norms.total - pullUp }
}

// MARK: Format

export function num(value: number): string {
  const rounded = Math.round(value * 100) / 100
  return Number.isInteger(rounded)
    ? String(rounded)
    : rounded.toFixed(2).replace(/0+$/, '').replace('.', ',')
}

export const kg = (value: number) => `${num(value)} кг`
export const signedKg = (value: number) => (value >= 0 ? `+${kg(value)}` : `−${kg(-value)}`)

const monthsShort = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.']
const monthsLong = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря']
const weekdaysShort = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб']
const weekdaysLong = ['воскресенье', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота']

export const dayMonth = (ts: number) => { const d = new Date(ts); return `${d.getDate()} ${monthsShort[d.getMonth()]}` }
export const dayMonthYear = (ts: number) => { const d = new Date(ts); return `${d.getDate()} ${monthsShort[d.getMonth()]} ${String(d.getFullYear()).slice(2)}` }
export const longDay = (ts: number) => { const d = new Date(ts); return `${weekdaysLong[d.getDay()]}, ${d.getDate()} ${monthsLong[d.getMonth()]}` }
export const weekdayShort = (ts: number) => weekdaysShort[new Date(ts).getDay()]
