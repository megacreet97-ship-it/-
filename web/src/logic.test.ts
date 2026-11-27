import { describe, expect, it } from 'vitest'
import {
  achievedRank, addDays, attemptPlan, classFor, classesFor, currentStreak, dailyProgress, estimatedAddedWeight,
  exerciseTotals, kg, linearTrend, longestStreak, lookupStandard, makeForecast, prepPhase, signedKg, splitTotal,
  STANDARDS, startOfDay, totalReps, trainingDays, trendReachDate, weeklySum, itemReps, itemTonnage, setsLabel,
  normalizeSets, type LogItem,
} from './logic'

const base = startOfDay(new Date(2026, 0, 1).getTime())
const day = (n: number) => addDays(base, n)

describe('logic', () => {
  it('estimates 1RM on system weight', () => {
    expect(estimatedAddedWeight(40, 80, 1)).toBe(40)
    expect(estimatedAddedWeight(20, 80, 5)).toBeCloseTo(34.58, 2)
    expect(estimatedAddedWeight(20, 80, 20)).toBeNull()
    expect(estimatedAddedWeight(20, 0, 3)).toBeNull()
  })

  it('fits a linear trend', () => {
    const points = [0, 1, 2, 3, 4].map((w) => ({ date: day(w * 7), value: 40 + w * 1.25 }))
    const trend = linearTrend(points)!
    expect(trend.slopePerDay * 7).toBeCloseTo(1.25)
    expect(Math.round((trendReachDate(trend, 50)! - day(56)) / 86_400_000)).toBe(0)
    expect(linearTrend([points[0]])).toBeNull()
  })

  it('classifies forecasts', () => {
    const points = [0, 1, 2, 3, 4].map((w) => ({ date: day(w * 7), value: 40 + w }))
    const today = day(28)
    expect(makeForecast(44, 48, points, day(70), today).status).toBe('onTrack')
    expect(makeForecast(44, 48, points, day(70), today).neededPerWeek).toBeCloseTo(4 / 6)
    expect(makeForecast(44, 60, points, day(42), today).status).toBe('behind')
    expect(makeForecast(50, 48, points, null, today).status).toBe('reached')
    expect(makeForecast(40, 48, [], null, today).status).toBe('notEnoughData')
    expect(makeForecast(44, 48, points, null, today).status).toBe('projected')
  })

  it('plans increasing rounded attempts', () => {
    expect(attemptPlan(50)).toEqual([46.25, 48.75, 50])
    expect(attemptPlan(5)).toEqual([5, 6.25, 7.5])
    expect(attemptPlan(0)).toEqual([])
  })

  it('derives prep phase', () => {
    expect(prepPhase(null, base).kind).toBe('noDate')
    expect(prepPhase(day(0), base).kind).toBe('competitionDay')
    expect(prepPhase(day(7), base).kind).toBe('taper')
    expect(prepPhase(day(20), base).kind).toBe('peaking')
    expect(prepPhase(day(42), base).kind).toBe('strength')
    expect(prepPhase(day(84), base).kind).toBe('base')
    expect(prepPhase(day(200), base).kind).toBe('offSeason')
    expect(prepPhase(day(-1), base).kind).toBe('past')
  })

  it('computes diary analytics', () => {
    const items: LogItem[] = [
      { date: day(0), exercise: 'A', reps: 10, sets: 3, addedWeight: 0 },
      { date: day(1), exercise: 'A', reps: 8, sets: 4, addedWeight: 0 },
      { date: day(1), exercise: 'B', reps: 5, sets: 5, addedWeight: 20 },
      { date: day(2), exercise: 'B', reps: 3, sets: 5, addedWeight: 25 },
      { date: day(5), exercise: 'A', reps: 12, sets: 2, addedWeight: 0 },
    ]
    expect(totalReps(items)).toBe(126)
    const days = trainingDays(items)
    expect(days.size).toBe(4)
    expect(longestStreak(days)).toBe(3)
    expect(currentStreak(days, day(2))).toBe(3)
    expect(currentStreak(days, day(3))).toBe(3)
    expect(currentStreak(days, day(4))).toBe(0)
    const totals = exerciseTotals(items)
    expect(totals[0].name).toBe('A')
    expect(totals[0].totalReps).toBe(86)
    expect(totals[1].maxWeight).toBe(25)
    expect(dailyProgress(items, 'B').map((p) => p.value)).toEqual([20, 25])
    expect(dailyProgress(items, 'A').map((p) => p.value)).toEqual([30, 32, 24])
    expect(weeklySum(items, itemReps).reduce((a, p) => a + p.value, 0)).toBe(126)
  })

  it('matches the Swift standards table', () => {
    expect(lookupStandard('isf', 67.5)!.norms.ms.total).toBe(152.5)
    expect(lookupStandard('isf', 75)!.norms.ms.total).toBe(165)
    expect(lookupStandard('wsf', 67.5)!.norms.ms.total).toBe(140)
    expect(lookupStandard('wsf', 75)!.norms.ms.total).toBe(152.5)
    expect(classesFor('isf').map((s) => s.limit)).toEqual([67.5, 75])
    for (const s of STANDARDS) {
      expect(s.norms.kms.total).toBeLessThan(s.norms.ms.total)
      expect(s.norms.ms.total).toBeLessThan(s.norms.msmk.total)
      const split = splitTotal(s.norms.ms)
      expect(split.pullUp + split.dip).toBeCloseTo(s.norms.ms.total)
    }
    expect(splitTotal(lookupStandard('isf', 67.5)!.norms.ms).pullUp).toBe(61.25)
    const isf = lookupStandard('isf', 67.5)!
    expect(achievedRank(isf, 134)).toBeNull()
    expect(achievedRank(isf, 135)).toBe('kms')
    expect(achievedRank(isf, 200)).toBe('msmk')
    expect(classFor(67.5, 'isf')!.limit).toBe(67.5)
    expect(classFor(67.6, 'isf')!.limit).toBe(75)
    expect(classFor(80, 'isf')).toBeUndefined()
  })

  it('formats numbers the Russian way', () => {
    expect(kg(50)).toBe('50 кг')
    expect(kg(47.5)).toBe('47,5 кг')
    expect(kg(46.25)).toBe('46,25 кг')
    expect(signedKg(-2.5)).toBe('−2,5 кг')
  })
})

describe('per-set reps', () => {
  it('counts each set separately', () => {
    const item = { date: 0, exercise: 'x', reps: 8, sets: 4, addedWeight: 10, setReps: [8, 8, 8, 3] }
    expect(itemReps(item)).toBe(27)
    expect(itemTonnage(item)).toBe(270)
    expect(setsLabel(item)).toBe('8, 8, 8, 3')
    expect(setsLabel({ reps: 8, sets: 4 })).toBe('4 × 8')
  })

  it('normalizes equal sets back to sets × reps', () => {
    expect(normalizeSets([8, 8, 8])).toEqual({ sets: 3, reps: 8 })
    expect(normalizeSets([8, 8, 8, 3])).toEqual({ sets: 4, reps: 8, setReps: [8, 8, 8, 3] })
    expect(normalizeSets([0, 5])).toEqual({ sets: 1, reps: 5 })
  })
})
