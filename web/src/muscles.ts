import { addDays, startOfDay, type Lift } from './logic'
import { EXERCISE_INFO } from './exerciseInfo'

export type Muscle =
  | 'chest' | 'lats' | 'traps' | 'lowerBack' | 'frontDelts' | 'sideDelts' | 'rearDelts' | 'biceps' | 'triceps'
  | 'forearms' | 'abs' | 'obliques' | 'quads' | 'hamstrings' | 'glutes' | 'adductors' | 'calves' | 'cardio'

export type ExerciseKind = 'compound' | 'isolation' | 'static' | 'cardio' | 'stretch'

export interface ExerciseInfo {
  primary: Muscle[]
  secondary: Muscle[]
  kind: ExerciseKind
  equipment: string
  level: number
  /** 1–5, expert estimate of how well the exercise loads its primary muscles. */
  rating: number
  tip: string
  /** Stem of the start/end technique photos in public/exercise-photos. */
  photo?: string
}

export const muscleTitle: Record<Muscle, string> = {
  chest: 'Грудь', lats: 'Широчайшие', traps: 'Трапеции, верх спины', lowerBack: 'Поясница',
  frontDelts: 'Передние дельты', sideDelts: 'Средние дельты', rearDelts: 'Задние дельты',
  biceps: 'Бицепс', triceps: 'Трицепс', forearms: 'Предплечья, хват',
  abs: 'Пресс', obliques: 'Косые мышцы', quads: 'Квадрицепс', hamstrings: 'Бицепс бедра',
  glutes: 'Ягодицы', adductors: 'Приводящие бедра', calves: 'Икры', cardio: 'Выносливость',
}

export const MUSCLE_GROUPS: { title: string; muscles: Muscle[] }[] = [
  { title: 'Спина и грудь', muscles: ['chest', 'lats', 'traps', 'lowerBack'] },
  { title: 'Плечи', muscles: ['frontDelts', 'sideDelts', 'rearDelts'] },
  { title: 'Руки', muscles: ['biceps', 'triceps', 'forearms'] },
  { title: 'Кор', muscles: ['abs', 'obliques'] },
  { title: 'Ноги', muscles: ['quads', 'hamstrings', 'glutes', 'adductors', 'calves'] },
]

/** Muscles worth a suggestion when they get too little work; small helpers are left out. */
export const KEY_MUSCLES: Muscle[] = ['chest', 'lats', 'sideDelts', 'rearDelts', 'biceps', 'triceps', 'abs', 'quads', 'hamstrings', 'glutes', 'calves']

export const STRENGTH_MUSCLES: Muscle[] = MUSCLE_GROUPS.flatMap((g) => g.muscles)
export const ALL_MUSCLES: Muscle[] = [...STRENGTH_MUSCLES, 'cardio']

export const kindTitle: Record<ExerciseKind, string> = {
  compound: 'Базовое', isolation: 'Изолирующее', static: 'Статика', cardio: 'Кардио', stretch: 'Растяжка',
}

export const levelTitle = (level: number) => ['Новичок', 'Средний', 'Продвинутый'][Math.min(Math.max(level, 1), 3) - 1]

const CATEGORY_FALLBACK: Record<string, Pick<ExerciseInfo, 'primary' | 'secondary' | 'kind'>> = {
  'Турник': { primary: ['lats', 'biceps'], secondary: ['forearms'], kind: 'compound' },
  'Брусья': { primary: ['chest', 'triceps'], secondary: ['frontDelts'], kind: 'compound' },
  'Грудь': { primary: ['chest'], secondary: ['triceps', 'frontDelts'], kind: 'compound' },
  'Спина': { primary: ['lats'], secondary: ['traps', 'biceps'], kind: 'compound' },
  'Плечи': { primary: ['sideDelts', 'frontDelts'], secondary: ['triceps'], kind: 'compound' },
  'Бицепс': { primary: ['biceps'], secondary: ['forearms'], kind: 'isolation' },
  'Трицепс': { primary: ['triceps'], secondary: [], kind: 'isolation' },
  'Предплечья и хват': { primary: ['forearms'], secondary: [], kind: 'isolation' },
  'Ноги': { primary: ['quads', 'glutes'], secondary: ['hamstrings'], kind: 'compound' },
  'Ягодицы': { primary: ['glutes'], secondary: ['hamstrings'], kind: 'compound' },
  'Икры': { primary: ['calves'], secondary: [], kind: 'isolation' },
  'Пресс и кор': { primary: ['abs'], secondary: ['obliques'], kind: 'isolation' },
  'Кардио': { primary: ['cardio'], secondary: [], kind: 'cardio' },
  'Растяжка и мобильность': { primary: ['lowerBack'], secondary: [], kind: 'stretch' },
}

/** Library description, or a rough one built from the category for the user's own exercises. */
export function infoFor(name: string, category?: string, lift?: Lift | null): ExerciseInfo | null {
  const known = EXERCISE_INFO[name]
  if (known) return known
  const fallback = lift === 'pullUp' ? CATEGORY_FALLBACK['Турник'] : lift === 'dip' ? CATEGORY_FALLBACK['Брусья'] : category ? CATEGORY_FALLBACK[category] : undefined
  return fallback ? { ...fallback, equipment: '', level: 0, rating: 0, tip: '' } : null
}

export interface LoadEntry {
  date: number
  exerciseName: string
  sets: number
  reps: number
  setReps?: number[]
}

/** Weekly hard sets per muscle: a primary muscle gets the whole set, a secondary one half. */
export function muscleSets(entries: LoadEntry[], lookup: (name: string) => ExerciseInfo | null): Record<Muscle, number> {
  const result = Object.fromEntries(ALL_MUSCLES.map((m) => [m, 0])) as Record<Muscle, number>
  for (const e of entries) {
    const info = lookup(e.exerciseName)
    if (!info || info.kind === 'stretch') continue
    if (info.kind === 'cardio') {
      result.cardio += e.sets
      continue
    }
    for (const m of info.primary) result[m] += e.sets
    for (const m of info.secondary) result[m] += e.sets / 2
  }
  return result
}

export type VolumeZone = 'none' | 'low' | 'maintain' | 'grow' | 'high'

/** Common hypertrophy guidance: about 10–20 hard sets per muscle per week. */
export function volumeZone(sets: number): VolumeZone {
  if (sets <= 0) return 'none'
  if (sets < 4) return 'low'
  if (sets < 10) return 'maintain'
  if (sets <= 20) return 'grow'
  return 'high'
}

export const zoneTitle: Record<VolumeZone, string> = {
  none: 'Нет нагрузки', low: 'Мало', maintain: 'Поддержка', grow: 'Рост', high: 'Много',
}

export function entriesInLastDays<T extends { date: number }>(entries: T[], days: number, today = Date.now()): T[] {
  const from = addDays(startOfDay(today), -days + 1)
  return entries.filter((e) => e.date >= from)
}

/** Best exercises for a muscle: where it is a primary mover, highest rating first, easier first on ties. */
export function bestForMuscle(muscle: Muscle, limit = Infinity): [string, ExerciseInfo][] {
  return Object.entries(EXERCISE_INFO)
    .filter(([, info]) => info.primary.includes(muscle))
    .sort((a, b) => b[1].rating - a[1].rating || a[1].primary.length - b[1].primary.length || a[1].level - b[1].level)
    .slice(0, limit)
}

/** Strength score of one session: estimated 1RM with added weight, otherwise the best set's reps. */
export function sessionScore(e: LoadEntry & { addedWeight: number }): number {
  const best = e.setReps?.length ? Math.max(...e.setReps) : e.reps
  return e.addedWeight > 0 ? e.addedWeight * (1 + Math.min(best, 12) / 30) : best
}

export interface ExerciseProgress {
  name: string
  before: number
  now: number
  change: number
  weighted: boolean
}

/** Compares the best session of the last 4 weeks with the 4 weeks before them. */
export function exerciseProgress(entries: (LoadEntry & { addedWeight: number })[], today = Date.now()): ExerciseProgress[] {
  const split = addDays(startOfDay(today), -27)
  const from = addDays(split, -28)
  const byName = new Map<string, { before: number; now: number; weighted: boolean }>()
  for (const e of entries) {
    if (e.date < from) continue
    const row = byName.get(e.exerciseName) ?? { before: 0, now: 0, weighted: false }
    const score = sessionScore(e)
    if (e.date >= split) row.now = Math.max(row.now, score)
    else row.before = Math.max(row.before, score)
    row.weighted ||= e.addedWeight > 0
    byName.set(e.exerciseName, row)
  }
  return [...byName.entries()]
    .filter(([, r]) => r.before > 0 && r.now > 0)
    .map(([name, r]) => ({ name, before: r.before, now: r.now, change: r.now / r.before - 1, weighted: r.weighted }))
    .sort((a, b) => b.change - a.change)
}

/** Number of sessions that beat every earlier session of the same exercise. */
export function personalRecords(entries: (LoadEntry & { addedWeight: number })[], since: number): number {
  const best = new Map<string, number>()
  let count = 0
  for (const e of [...entries].sort((a, b) => a.date - b.date)) {
    const score = sessionScore(e)
    const previous = best.get(e.exerciseName)
    if (previous !== undefined && score > previous + 1e-9 && e.date >= since) count++
    if (previous === undefined || score > previous) best.set(e.exerciseName, score)
  }
  return count
}