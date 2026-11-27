import {
  classFor, dailyMax, estimatedAddedWeight, lookupStandard, makeForecast, trendValue,
  type DatedValue, type Lift, type LiftForecast, type LogItem, type WeightClassStandard,
} from './logic'
import type { AppData, Entry, Exercise, Profile } from './store'
import { infoFor, type ExerciseInfo } from './muscles'

export const toLogItems = (entries: Entry[]): LogItem[] =>
  entries.map((e) => ({ date: e.date, exercise: e.exerciseName, reps: e.reps, sets: e.sets, addedWeight: e.addedWeight, setReps: e.setReps }))

export const bestLift = (data: AppData, lift: Lift) =>
  Math.max(0, ...data.attempts.filter((a) => a.lift === lift).map((a) => a.addedWeight))

export const attemptPoints = (data: AppData, lift: Lift): DatedValue[] =>
  dailyMax(data.attempts.filter((a) => a.lift === lift).map((a) => ({ date: a.date, value: a.addedWeight })))

export function estimatePoints(data: AppData, lift: Lift): DatedValue[] {
  const points: DatedValue[] = []
  for (const e of data.entries) {
    if (e.lift !== lift || e.reps <= 1) continue
    const estimate = estimatedAddedWeight(e.addedWeight, data.profile.bodyweight, e.reps)
    if (estimate !== null) points.push({ date: e.date, value: estimate })
  }
  return dailyMax(points)
}

export const liftTarget = (profile: Profile, lift: Lift) => (lift === 'pullUp' ? profile.targetPullUp : profile.targetDip)

export function profileStandard(profile: Profile): WeightClassStandard | undefined {
  return lookupStandard(profile.federation, profile.weightClassLimit)
}

export function goalTotal(profile: Profile): number {
  const standard = profileStandard(profile)
  return standard ? standard.norms[profile.goalRank].total : profile.targetTotal || profile.targetPullUp + profile.targetDip
}

export function liftForecast(data: AppData, lift: Lift): LiftForecast {
  return makeForecast(
    bestLift(data, lift),
    liftTarget(data.profile, lift),
    dailyMax([...attemptPoints(data, lift), ...estimatePoints(data, lift)]),
    data.profile.competitionDate,
  )
}

export function trendSegment(forecast: LiftForecast, points: DatedValue[], competition: number | null): [DatedValue, DatedValue] | null {
  if (!forecast.trend || points.length === 0) return null
  const dates = points.map((p) => p.date)
  const first = Math.min(...dates)
  let last = Math.max(...dates)
  if (competition && competition > last) last = competition
  return [
    { date: first, value: trendValue(forecast.trend, first) },
    { date: last, value: trendValue(forecast.trend, last) },
  ]
}

export function currentClass(profile: Profile) {
  return classFor(profile.bodyweight, profile.federation)
}

/** Exercise name and weight of the most recent entry for each exercise, newest first. */
export function recentExercises(entries: Entry[], limit = 8): Entry[] {
  const seen = new Set<string>()
  const result: Entry[] = []
  for (let i = entries.length - 1; i >= 0 && result.length < limit; i--) {
    const e = entries[i]
    if (seen.has(e.exerciseName)) continue
    seen.add(e.exerciseName)
    result.push(e)
  }
  return result
}

export function lastEntryFor(entries: Entry[], name: string, before = Infinity): Entry | undefined {
  for (let i = entries.length - 1; i >= 0; i--) {
    if (entries[i].exerciseName === name && entries[i].date < before) return entries[i]
  }
  return undefined
}

/** Describes any exercise name: library data first, then the category of the user's own exercise. */
export function infoLookup(exercises: Exercise[]): (name: string) => ExerciseInfo | null {
  const byName = new Map(exercises.map((e) => [e.name, e]))
  const cache = new Map<string, ExerciseInfo | null>()
  return (name) => {
    if (!cache.has(name)) {
      const exercise = byName.get(name)
      cache.set(name, infoFor(name, exercise?.category, exercise?.lift))
    }
    return cache.get(name) ?? null
  }
}
