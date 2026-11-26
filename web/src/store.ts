import { useSyncExternalStore } from 'react'
import {
  addDays, lookupStandard, roundTo, splitTotal, startOfDay, type Federation, type Lift, type SportRank,
} from './logic'
import { EXERCISE_LIBRARY, LIBRARY_VERSION } from './exerciseLibrary'
import type { BodyLog, Goal } from './body'

export interface Exercise {
  id: string
  name: string
  category: string
  lift: Lift | null
  createdAt: number
}

export interface Entry {
  id: string
  date: number
  exerciseName: string
  lift: Lift | null
  reps: number
  sets: number
  addedWeight: number
  note: string
  /** Reps of each set when they differ; `sets` is its length and `reps` the best set. */
  setReps?: number[]
}

export interface Attempt {
  id: string
  date: number
  lift: Lift
  addedWeight: number
  bodyweight: number
  isCompetition: boolean
  note: string
}

export interface Profile {
  name: string
  bodyweight: number
  weightClass: string
  targetPullUp: number
  targetDip: number
  targetTotal: number
  competitionDate: number | null
  competitionName: string
  federation: Federation
  /** Upper limit of a class from STANDARDS; 0 means custom targets. */
  weightClassLimit: number
  goalRank: SportRank
  /** Unset for new users until they pick one; see `effectiveGoal`. */
  goal?: Goal
  targetWeight?: number
  targetWaist?: number
  weeklyWorkouts?: number
}

export interface AppData {
  version: 1
  exercises: Exercise[]
  entries: Entry[]
  attempts: Attempt[]
  profile: Profile
  /** Version of EXERCISE_LIBRARY already merged into exercises. */
  libraryVersion?: number
  bodyLogs?: BodyLog[]
}

/** Users from before goals existed and anyone with streetlifting data keep the МС screen. */
export function effectiveGoal(data: AppData): Goal | null {
  if (data.profile.goal) return data.profile.goal
  return data.attempts.length > 0 || data.entries.some((e) => e.lift) ? 'ms' : null
}

const withLatestBodyweight = (d: AppData, bodyLogs: BodyLog[]): AppData => {
  const sorted = [...bodyLogs].sort((a, b) => a.date - b.date)
  const latest = sorted[sorted.length - 1]
  return { ...d, bodyLogs: sorted, profile: latest ? { ...d.profile, bodyweight: latest.weight } : d.profile }
}

const STORAGE_KEY = 'streetlog.v1'

export const uid = () => (crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`)

export function applyStandard(profile: Profile): Profile {
  const standard = lookupStandard(profile.federation, profile.weightClassLimit)
  if (!standard) return profile
  const norms = standard.norms[profile.goalRank]
  const split = splitTotal(norms)
  return {
    ...profile,
    weightClass: `до ${String(standard.limit).replace('.', ',')} кг`,
    targetTotal: norms.total,
    targetPullUp: split.pullUp,
    targetDip: split.dip,
  }
}

function initialData(): AppData {
  const now = Date.now()
  return {
    version: 1,
    exercises: EXERCISE_LIBRARY.map(([name, category, lift], i) => ({ id: uid(), name, category, lift, createdAt: now + i })),
    libraryVersion: LIBRARY_VERSION,
    entries: [],
    attempts: [],
    profile: applyStandard({
      name: '',
      bodyweight: 67,
      weightClass: '',
      targetPullUp: 0,
      targetDip: 0,
      targetTotal: 0,
      competitionDate: null,
      competitionName: '',
      federation: 'isf',
      weightClassLimit: 67.5,
      goalRank: 'ms',
    }),
  }
}

function isAppData(value: unknown): value is AppData {
  const v = value as AppData
  return !!v && v.version === 1 && Array.isArray(v.exercises) && Array.isArray(v.entries) &&
    Array.isArray(v.attempts) && typeof v.profile === 'object' && v.profile !== null
}

/** Adds library exercises the user doesn't have yet and moves known ones into the current categories. */
export function mergeLibrary(data: AppData): AppData {
  if ((data.libraryVersion ?? 0) >= LIBRARY_VERSION) return data
  const byName = new Map(EXERCISE_LIBRARY.map(([name, category, lift]) => [name.toLowerCase(), { name, category, lift }]))
  const existing = new Set(data.exercises.map((e) => e.name.toLowerCase()))
  const updated = data.exercises.map((e) => {
    const known = byName.get(e.name.toLowerCase())
    return known ? { ...e, category: known.category } : e
  })
  const now = Date.now()
  const added = EXERCISE_LIBRARY
    .filter(([name]) => !existing.has(name.toLowerCase()))
    .map(([name, category, lift], i) => ({ id: uid(), name, category, lift, createdAt: now + i }))
  return { ...data, exercises: [...updated, ...added], libraryVersion: LIBRARY_VERSION }
}

function load(): AppData {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      const parsed: unknown = JSON.parse(raw)
      if (isAppData(parsed)) {
        const merged = mergeLibrary(parsed)
        if (merged !== parsed) localStorage.setItem(STORAGE_KEY, JSON.stringify(merged))
        return merged
      }
    }
  } catch {
    // Corrupted storage falls back to a fresh dataset.
  }
  const data = initialData()
  const demo = typeof location !== 'undefined' ? new URLSearchParams(location.search).get('demo') : null
  if (demo === 'recomp') seedRecompDemo(data)
  else if (demo !== null) seedDemo(data)
  return data
}

let state: AppData = load()
const listeners = new Set<() => void>()

function persist() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
  } catch {
    // Storage full or unavailable (private mode): the app keeps working in memory.
  }
}

try {
  if (!localStorage.getItem(STORAGE_KEY)) persist()
} catch {
  // Storage unavailable: keep the in-memory dataset.
}

export function update(mutator: (draft: AppData) => AppData) {
  state = mutator(state)
  persist()
  listeners.forEach((l) => l())
}

export function useData(): AppData {
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },
    () => state,
  )
}

// MARK: Actions

export const actions = {
  addEntry(entry: Omit<Entry, 'id'>) {
    update((d) => ({ ...d, entries: [...d.entries, { ...entry, id: uid() }].sort((a, b) => a.date - b.date) }))
  },
  updateEntry(id: string, patch: Partial<Entry>) {
    update((d) => ({ ...d, entries: d.entries.map((e) => (e.id === id ? { ...e, ...patch } : e)) }))
  },
  deleteEntry(id: string) {
    update((d) => ({ ...d, entries: d.entries.filter((e) => e.id !== id) }))
  },
  addAttempt(attempt: Omit<Attempt, 'id'>) {
    update((d) => ({ ...d, attempts: [...d.attempts, { ...attempt, id: uid() }].sort((a, b) => a.date - b.date) }))
  },
  updateAttempt(id: string, patch: Partial<Attempt>) {
    update((d) => ({ ...d, attempts: d.attempts.map((a) => (a.id === id ? { ...a, ...patch } : a)).sort((a, b) => a.date - b.date) }))
  },
  deleteAttempt(id: string) {
    update((d) => ({ ...d, attempts: d.attempts.filter((a) => a.id !== id) }))
  },
  addExercise(name: string, category: string, lift: Lift | null) {
    update((d) => ({ ...d, exercises: [...d.exercises, { id: uid(), name, category, lift, createdAt: Date.now() }] }))
  },
  deleteExercise(id: string) {
    update((d) => ({ ...d, exercises: d.exercises.filter((e) => e.id !== id) }))
  },
  updateProfile(patch: Partial<Profile>, reapplyStandard = false) {
    update((d) => {
      const profile = { ...d.profile, ...patch }
      return { ...d, profile: reapplyStandard ? applyStandard(profile) : profile }
    })
  },
  addBodyLog(log: Omit<BodyLog, 'id'>) {
    update((d) => withLatestBodyweight(d, [...(d.bodyLogs ?? []), { ...log, id: uid() }]))
  },
  updateBodyLog(id: string, patch: Partial<BodyLog>) {
    update((d) => withLatestBodyweight(d, (d.bodyLogs ?? []).map((l) => (l.id === id ? { ...l, ...patch } : l))))
  },
  deleteBodyLog(id: string) {
    update((d) => withLatestBodyweight(d, (d.bodyLogs ?? []).filter((l) => l.id !== id)))
  },
  /** Copies every exercise of `sourceDay` to the moment `at`, keeping their order. Returns how many were copied. */
  copyDay(sourceDay: number, at: number): number {
    const source = state.entries.filter((e) => startOfDay(e.date) === sourceDay).sort((a, b) => a.date - b.date)
    update((d) => ({
      ...d,
      entries: [...d.entries, ...source.map((e, i) => ({ ...e, id: uid(), date: at + i * 1000, note: '' }))].sort((a, b) => a.date - b.date),
    }))
    return source.length
  },
  replaceAll(data: AppData) {
    update(() => mergeLibrary(data))
  },
}

export function parseBackup(text: string): AppData | null {
  try {
    const parsed: unknown = JSON.parse(text)
    return isAppData(parsed) ? parsed : null
  } catch {
    return null
  }
}

export function exportCSV(data: AppData): string {
  const esc = (s: string) => `"${s.replace(/"/g, '""')}"`
  const fmt = (ts: number) => new Date(ts).toISOString().slice(0, 16).replace('T', ' ')
  const lines = ['date;exercise;sets;reps;reps_by_set;added_kg;note']
  for (const e of data.entries) {
    lines.push([fmt(e.date), esc(e.exerciseName), e.sets, e.reps, e.setReps?.join(',') ?? '', e.addedWeight, esc(e.note)].join(';'))
  }
  lines.push('', 'date;lift;added_kg;bodyweight_kg;competition;note')
  for (const a of data.attempts) lines.push([fmt(a.date), a.lift, a.addedWeight, a.bodyweight, a.isCompetition ? 1 : 0, esc(a.note)].join(';'))
  return lines.join('\n')
}

/** Sample data, only created when the app is opened with ?demo and storage is empty. */
function seedDemo(data: AppData) {
  const today = startOfDay(Date.now())
  const at = (offset: number, minutes = 0) => addDays(today, offset) + (18 * 60 + minutes) * 60_000
  data.profile = applyStandard({ ...data.profile, name: 'Демо', bodyweight: 70.5, competitionDate: addDays(today, 45), competitionName: 'Кубок города' })
  for (let week = 0; week < 12; week++) {
    const offset = -84 + week * 7 + 5
    data.attempts.push({ id: uid(), date: at(offset), lift: 'pullUp', addedWeight: roundTo(50 + week * 0.9 + (week % 3 === 0 ? -1 : 0)), bodyweight: 70.5, isCompetition: false, note: '' })
    data.attempts.push({ id: uid(), date: at(offset), lift: 'dip', addedWeight: roundTo(72 + week * 1.2 + (week % 4 === 1 ? -1.25 : 0)), bodyweight: 70.5, isCompetition: false, note: '' })
  }
  for (let offset = -56; offset <= 0; offset++) {
    const weekday = new Date(addDays(today, offset)).getDay()
    if (![1, 3, 5].includes(weekday) && offset !== 0) continue
    const progress = (offset + 56) / 56
    data.entries.push({ id: uid(), date: at(offset), exerciseName: 'Подтягивания с отягощением', lift: 'pullUp', reps: 5, sets: 4, addedWeight: roundTo(35 + 6 * progress), note: '' })
    data.entries.push({ id: uid(), date: at(offset, 15), exerciseName: 'Отжимания на брусьях с отягощением', lift: 'dip', reps: 5, sets: 4, addedWeight: roundTo(50 + 8 * progress), note: '' })
    data.entries.push({ id: uid(), date: at(offset, 30), exerciseName: weekday === 3 ? 'Подтягивания широким хватом' : 'Отжимания от пола', lift: null, reps: weekday === 3 ? 10 : 25, sets: 3, addedWeight: 0, note: '' })
    data.entries.push({ id: uid(), date: at(offset, 45), exerciseName: 'Подъём ног в висе', lift: null, reps: 12, sets: 3, addedWeight: 0, note: '' })
  }
}

function seedRecompDemo(data: AppData) {
  const today = startOfDay(Date.now())
  const at = (offset: number, minutes = 0) => addDays(today, offset) + (8 * 60 + minutes) * 60_000
  data.profile = { ...data.profile, name: 'Аня', bodyweight: 62, goal: 'recomp', targetWeight: 60, targetWaist: 68, weeklyWorkouts: 3 }
  data.bodyLogs = []
  for (let offset = -42; offset <= 0; offset += 3) {
    const t = (offset + 42) / 42
    data.bodyLogs.push({
      id: uid(), date: at(offset), weight: Math.round((63 - 0.8 * t + Math.sin(offset) * 0.3) * 10) / 10,
      ...(offset % 7 === 0 || offset === 0 ? { waist: Math.round((74 - 3 * t) * 2) / 2 } : {}),
    })
  }
  data.profile.bodyweight = data.bodyLogs[data.bodyLogs.length - 1].weight
  const plan: [string, number, number, number][][] = [
    [['Приседания со штангой', 10, 3, 20], ['Ягодичный мост со штангой', 12, 3, 30], ['Выпады с гантелями', 10, 3, 6], ['Планка (сек)', 45, 3, 0]],
    [['Тяга верхнего блока к груди', 12, 3, 25], ['Жим гантелей сидя', 10, 3, 5], ['Махи гантелями в стороны (разводка на средние дельты)', 15, 3, 3], ['Сгибания с гантелями стоя', 12, 3, 4]],
    [['Румынская тяга с гантелями', 12, 3, 10], ['Болгарские сплит-приседания', 10, 3, 4], ['Отведение ноги назад на блоке', 15, 3, 10], ['Бег (мин)', 20, 1, 0]],
  ]
  for (let offset = -42; offset <= 0; offset++) {
    const weekday = new Date(addDays(today, offset)).getDay()
    const index = [1, 3, 5].indexOf(weekday)
    if (index === -1) continue
    const progress = (offset + 42) / 42
    plan[index].forEach(([exerciseName, reps, sets, weight], i) => {
      const addedWeight = weight > 0 ? roundTo(weight * (1 + 0.25 * progress), weight >= 10 ? 2.5 : 1) : 0
      data.entries.push({ id: uid(), date: at(offset, 600 + i * 10), exerciseName, lift: null, reps, sets, addedWeight, note: '' })
    })
  }
}
