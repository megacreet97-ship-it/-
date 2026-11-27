import { addDays, linearTrend, startOfDay, trendValue, type DatedValue } from './logic'

export type Goal = 'ms' | 'recomp' | 'fatLoss' | 'muscle'
export const GOALS: Goal[] = ['ms', 'recomp', 'fatLoss', 'muscle']

export const goalTitle: Record<Goal, string> = {
  ms: 'Мастер спорта', recomp: 'Рекомпозиция', fatLoss: 'Похудение', muscle: 'Набор мышц',
}

export const goalSubtitle: Record<Goal, string> = {
  ms: 'Стритлифтинг: подтягивания и брусья с весом на 1 раз',
  recomp: 'Минус жир, плюс мышцы — вес почти не меняется, а фигура становится подтянутой',
  fatLoss: 'Снизить вес за счёт жира и сохранить мышцы',
  muscle: 'Больше мышц и силы с минимумом лишнего жира',
}

export interface BodyLog {
  id: string
  date: number
  weight: number
  waist?: number
  bodyFat?: number
}

const DAY = 86_400_000

export function seriesOf(logs: BodyLog[], pick: (l: BodyLog) => number | undefined): DatedValue[] {
  return logs
    .filter((l) => (pick(l) ?? 0) > 0)
    .map((l) => ({ date: l.date, value: pick(l) as number }))
    .sort((a, b) => a.date - b.date)
}

/** Mean of the values in the 7 days up to the latest one: smooths out water and food swings. */
export function smoothedLatest(points: DatedValue[]): number | null {
  if (points.length === 0) return null
  const last = points[points.length - 1].date
  const recent = points.filter((p) => p.date > last - 7 * DAY)
  return recent.reduce((a, p) => a + p.value, 0) / recent.length
}

/** Change per week from a linear trend over the last `days`; null until the data spans at least 6 days. */
export function weeklyRate(points: DatedValue[], days = 28, today = Date.now()): number | null {
  const from = addDays(startOfDay(today), -days + 1)
  const recent = points.filter((p) => p.date >= from)
  if (recent.length < 2 || recent[recent.length - 1].date - recent[0].date < 6 * DAY) return null
  const trend = linearTrend(recent)
  return trend ? trend.slopePerDay * 7 : null
}

export function trendLine(points: DatedValue[], days = 28, today = Date.now()): [DatedValue, DatedValue] | null {
  const from = addDays(startOfDay(today), -days + 1)
  const recent = points.filter((p) => p.date >= from)
  if (recent.length < 2 || recent[recent.length - 1].date - recent[0].date < 6 * DAY) return null
  const trend = linearTrend(recent)
  if (!trend) return null
  const first = recent[0].date
  const last = recent[recent.length - 1].date
  return [{ date: first, value: trendValue(trend, first) }, { date: last, value: trendValue(trend, last) }]
}

export type Tone = 'good' | 'warn' | 'neutral'

export interface Verdict {
  title: string
  text: string
  tone: Tone
}

/**
 * Reads the weight and waist trends against the goal. Rates follow common guidance:
 * fat loss 0.5–1% of bodyweight a week, lean gain 0.25–0.5%, recomposition keeps weight within ±0.25%.
 */
export function goalVerdict(goal: Goal, weight: number | null, weightPerWeek: number | null, waistPerWeek: number | null): Verdict {
  if (weight === null || weightPerWeek === null) {
    return { title: 'Нужно больше замеров', text: 'Взвешивайтесь 2–3 раза в неделю утром натощак — через неделю появится темп и оценка.', tone: 'neutral' }
  }
  const pct = (weightPerWeek / weight) * 100
  const waistDown = waistPerWeek !== null && waistPerWeek < -0.05
  const waistUp = waistPerWeek !== null && waistPerWeek > 0.05
  if (goal === 'fatLoss') {
    if (pct < -1) return { title: 'Слишком быстро', text: 'Больше 1% веса в неделю — растёт риск потерять мышцы. Добавьте немного калорий и держите белок.', tone: 'warn' }
    if (pct <= -0.5) return { title: 'Оптимальный темп', text: 'Вес уходит на 0,5–1% в неделю — так уходит в основном жир. Продолжайте.', tone: 'good' }
    if (pct < -0.1) return { title: 'Медленно, но верно', text: 'Вес снижается. Для темпа побыстрее уберите 100–200 ккал или добавьте шагов.', tone: 'good' }
    if (waistDown) return { title: 'Вес стоит, талия уходит', text: 'Жир уходит, а мышцы растут — это хороший знак, продолжайте.', tone: 'good' }
    return { title: pct > 0.1 ? 'Вес растёт' : 'Вес стоит', text: 'Нужен небольшой дефицит: уберите 200–300 ккал в день или добавьте 2–3 тысячи шагов.', tone: 'warn' }
  }
  if (goal === 'muscle') {
    if (pct > 0.5) return { title: 'Слишком быстро', text: 'Больше 0,5% веса в неделю — вместе с мышцами копится жир. Уберите 100–200 ккал.', tone: 'warn' }
    if (pct >= 0.2) return { title: 'Оптимальный темп', text: 'Плюс 0,25–0,5% веса в неделю — хороший темп набора мышц. Прибавляйте в рабочих весах.', tone: 'good' }
    if (pct >= -0.1) return { title: 'Вес почти не растёт', text: 'Для набора мышц добавьте 200–300 ккал в день, например перекус с белком.', tone: 'neutral' }
    return { title: 'Вес снижается', text: 'При наборе мышц вес должен понемногу расти — ешьте больше.', tone: 'warn' }
  }
  if (goal === 'recomp') {
    if (pct < -1) return { title: 'Вес уходит слишком быстро', text: 'Для рекомпозиции дефицит должен быть небольшим, иначе мышцам не из чего расти. Добавьте калорий.', tone: 'warn' }
    if (Math.abs(pct) <= 0.3 && waistDown) return { title: 'Идёт рекомпозиция', text: 'Вес стабилен, талия уменьшается — жир уходит, мышцы растут. Так и держать.', tone: 'good' }
    if (pct < -0.3 && !waistUp) return { title: 'Жир уходит', text: 'Вес плавно снижается. Если силовые растут — мышцы сохраняются, всё идёт хорошо.', tone: 'good' }
    if (waistUp || pct > 0.3) return { title: 'Талия или вес растут', text: 'Проверьте питание: при рекомпозиции калории около нормы или чуть ниже, белок каждый день.', tone: 'warn' }
    if (waistPerWeek === null) return { title: 'Вес стабилен', text: 'Для рекомпозиции важна талия: добавляйте её в замеры раз в неделю.', tone: 'neutral' }
    return { title: 'Вес и талия стабильны', text: 'Прибавляйте в весах на тренировках и держите белок — изменения придут.', tone: 'neutral' }
  }
  return { title: '', text: '', tone: 'neutral' }
}

/** Protein guidance for people who lift: 1.6–2.2 g per kg of bodyweight, rounded to 5 g. */
export function proteinRange(weight: number): [number, number] {
  return [Math.round((weight * 1.6) / 5) * 5, Math.round((weight * 2.2) / 5) * 5]
}

/** Date the target weight is reached at the current rate, if the rate points towards it. */
export function reachDate(current: number, target: number, perWeek: number | null, today = Date.now()): number | null {
  if (!perWeek || target <= 0 || Math.abs(target - current) < 0.05) return null
  const weeks = (target - current) / perWeek
  if (weeks <= 0 || weeks > 156) return null
  return today + weeks * 7 * DAY
}

export function targetProgress(start: number, current: number, target: number): number {
  if (target <= 0 || start <= 0 || start === target) return 0
  return Math.min(Math.max((current - start) / (target - start), 0), 1)
}

export interface GoalPlan {
  title: string
  text: string
}

export function goalPlan(goal: Goal, weight: number, workouts: number): GoalPlan[] {
  const [pMin, pMax] = proteinRange(weight)
  const protein = { title: 'Белок', text: `${pMin}–${pMax} г в день (1,6–2,2 г на кг веса) — главное, чтобы мышцы сохранялись и росли.` }
  const training = { title: 'Силовые', text: `${workouts} тренировки в неделю, 10–20 рабочих подходов на каждую крупную мышцу. Каждые 1–2 недели прибавляйте вес или повторения.` }
  const sleep = { title: 'Сон', text: '7–9 часов. При недосыпе хуже уходит жир и медленнее растут мышцы.' }
  if (goal === 'fatLoss') {
    return [
      { title: 'Питание', text: 'Дефицит 300–500 ккал от нормы. Без голодовок: резкий дефицит забирает мышцы.' },
      protein, training,
      { title: 'Активность', text: '8–10 тысяч шагов в день и 1–2 кардио по 20–30 минут.' },
      sleep,
    ]
  }
  if (goal === 'muscle') {
    return [
      { title: 'Питание', text: 'Профицит 200–300 ккал от нормы. Больше — лишний жир, а мышцы быстрее не растут.' },
      protein, training,
      { title: 'Прогрессия', text: 'Главный сигнал для роста — постепенный рост рабочих весов. Записывайте каждую тренировку.' },
      sleep,
    ]
  }
  return [
    { title: 'Питание', text: 'Калории около нормы или дефицит до 200–300 ккал. Вес почти не меняется — это нормально.' },
    protein, training,
    { title: 'Как следить', text: 'Смотрите на талию и рабочие веса, а не только на весы: жир уходит, мышцы прибавляются.' },
    sleep,
  ]
}
