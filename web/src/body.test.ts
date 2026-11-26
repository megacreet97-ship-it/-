import { describe, expect, it } from 'vitest'
import { goalVerdict, proteinRange, reachDate, seriesOf, smoothedLatest, targetProgress, weeklyRate, type BodyLog } from './body'

const DAY = 86_400_000
const today = new Date(2026, 10, 26, 9).getTime()
const logs = (start: number, perDay: number, days = 28): BodyLog[] =>
  Array.from({ length: days / 2 }, (_, i) => ({ id: String(i), date: today - (days - 2 * i) * DAY, weight: start + perDay * (2 * i - days) }))

describe('body tracking', () => {
  it('measures the weekly rate from the trend', () => {
    const points = seriesOf(logs(70, -0.1), (l) => l.weight)
    expect(weeklyRate(points, 28, today)).toBeCloseTo(-0.7, 5)
    expect(weeklyRate(points.slice(0, 2), 28, today)).toBeNull()
  })

  it('smooths the latest weight over a week', () => {
    expect(smoothedLatest([{ date: 0, value: 60 }, { date: 8 * DAY, value: 61 }, { date: 9 * DAY, value: 62 }])).toBe(61.5)
    expect(smoothedLatest([])).toBeNull()
  })

  it('judges the pace against the goal', () => {
    expect(goalVerdict('fatLoss', 70, -0.5, null).tone).toBe('good')
    expect(goalVerdict('fatLoss', 70, -1.2, null).tone).toBe('warn')
    expect(goalVerdict('fatLoss', 70, 0.2, null).tone).toBe('warn')
    expect(goalVerdict('muscle', 70, 0.25, null).tone).toBe('good')
    expect(goalVerdict('muscle', 70, 0.6, null).tone).toBe('warn')
    expect(goalVerdict('recomp', 60, 0.05, -0.3).title).toBe('Идёт рекомпозиция')
    expect(goalVerdict('recomp', 60, 0.3, 0.2).tone).toBe('warn')
    expect(goalVerdict('recomp', 60, null, null).tone).toBe('neutral')
  })

  it('suggests protein and forecasts the target date', () => {
    expect(proteinRange(60)).toEqual([95, 130])
    expect(reachDate(70, 68, -0.5, today)).toBe(today + 4 * 7 * DAY)
    expect(reachDate(70, 68, 0.5, today)).toBeNull()
    expect(targetProgress(70, 68, 65)).toBeCloseTo(0.4)
    expect(targetProgress(60, 62, 65)).toBeCloseTo(0.4)
  })
})
