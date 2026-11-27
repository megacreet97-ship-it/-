import { describe, expect, it } from 'vitest'
import { bestForMuscle, exerciseProgress, infoFor, muscleSets, personalRecords, volumeZone } from './muscles'

const DAY = 86_400_000
const today = new Date(2026, 10, 26, 18).getTime()
const entry = (daysAgo: number, exerciseName: string, sets: number, reps: number, addedWeight = 0) =>
  ({ date: today - daysAgo * DAY, exerciseName, sets, reps, addedWeight })

describe('muscles', () => {
  it('describes library and custom exercises', () => {
    expect(infoFor('Выпады с гантелями')?.primary).toEqual(['quads', 'glutes'])
    expect(infoFor('Мой жим', 'Грудь')?.primary).toEqual(['chest'])
    expect(infoFor('Что-то', undefined, 'pullUp')?.primary).toContain('lats')
    expect(infoFor('Неизвестное')).toBeNull()
  })

  it('counts primary sets fully and secondary sets by half', () => {
    const sets = muscleSets([entry(1, 'Отжимания на брусьях', 4, 10), entry(2, 'Бег (мин)', 1, 20), entry(2, 'Планка (сек)', 3, 60)], (n) => infoFor(n))
    expect(sets.chest).toBe(4)
    expect(sets.frontDelts).toBe(2)
    expect(sets.cardio).toBe(1)
    expect(sets.abs).toBe(3)
    expect(volumeZone(sets.chest)).toBe('maintain')
    expect(volumeZone(12)).toBe('grow')
  })

  it('ranks the best exercises for a muscle', () => {
    const best = bestForMuscle('sideDelts', 3)
    expect(best[0][1].rating).toBe(5)
    expect(best.every(([, i]) => i.primary.includes('sideDelts'))).toBe(true)
  })

  it('compares the last 4 weeks with the 4 before', () => {
    const progress = exerciseProgress([
      entry(40, 'Подтягивания', 3, 8), entry(10, 'Подтягивания', 3, 10),
      entry(45, 'Жим лёжа', 3, 5, 50), entry(5, 'Жим лёжа', 3, 5, 55),
      entry(3, 'Новое', 3, 5),
    ], today)
    expect(progress.map((p) => p.name)).toEqual(['Подтягивания', 'Жим лёжа'])
    expect(progress[0].change).toBeCloseTo(0.25)
    expect(progress[1].weighted).toBe(true)
  })

  it('counts personal records', () => {
    const entries = [entry(20, 'Подтягивания', 3, 8), entry(10, 'Подтягивания', 3, 9), entry(5, 'Подтягивания', 3, 7), entry(2, 'Подтягивания', 3, 10)]
    expect(personalRecords(entries, today - 30 * DAY)).toBe(2)
    expect(personalRecords(entries, today - 3 * DAY)).toBe(1)
  })
})
