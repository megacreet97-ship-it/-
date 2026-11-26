import { describe, expect, it } from 'vitest'
import { EXERCISE_LIBRARY, LIBRARY_VERSION } from './exerciseLibrary'
import { actions, effectiveGoal, mergeLibrary, update, type AppData } from './store'

const oldData = (): AppData => ({
  version: 1,
  exercises: [
    { id: 'a', name: 'Жим лёжа', category: 'Подсобка', lift: null, createdAt: 1 },
    { id: 'b', name: 'Моё упражнение', category: 'Своё', lift: null, createdAt: 2 },
  ],
  entries: [{ id: 'e', date: 1, exerciseName: 'Жим лёжа', lift: null, reps: 5, sets: 3, addedWeight: 60, note: '' }],
  attempts: [],
  profile: {
    name: '', bodyweight: 67, weightClass: '', targetPullUp: 0, targetDip: 0, targetTotal: 0, competitionDate: null,
    competitionName: '', federation: 'isf', weightClassLimit: 67.5, goalRank: 'ms',
  },
})

describe('mergeLibrary', () => {
  it('adds missing library exercises once and keeps user data', () => {
    const merged = mergeLibrary(oldData())
    const names = merged.exercises.map((e) => e.name)
    expect(merged.libraryVersion).toBe(LIBRARY_VERSION)
    expect(new Set(names).size).toBe(names.length)
    expect(names).toContain('Выпады с гантелями')
    expect(names).toContain('Махи гантелями в стороны (разводка на средние дельты)')
    expect(names).toContain('Моё упражнение')
    expect(merged.exercises.length).toBe(EXERCISE_LIBRARY.length + 1)
    expect(merged.exercises.find((e) => e.id === 'a')?.category).toBe('Грудь')
    expect(merged.entries).toHaveLength(1)
    expect(mergeLibrary(merged)).toBe(merged)
  })

  it('library names are unique', () => {
    const names = EXERCISE_LIBRARY.map(([n]) => n.toLowerCase())
    expect(new Set(names).size).toBe(names.length)
  })
})

describe('goals and copying', () => {
  it('keeps the МС screen for streetlifting users and asks new users', () => {
    const data = oldData()
    expect(effectiveGoal(data)).toBeNull()
    expect(effectiveGoal({ ...data, entries: [{ ...data.entries[0], lift: 'pullUp' }] })).toBe('ms')
    expect(effectiveGoal({ ...data, profile: { ...data.profile, goal: 'recomp' } })).toBe('recomp')
  })

  it('copies a whole day in order and updates bodyweight from measurements', () => {
    const day = new Date(2026, 10, 18).getTime()
    const at = new Date(2026, 10, 25, 19).getTime()
    let snapshot: AppData = oldData()
    update(() => ({
      ...oldData(),
      entries: [
        { id: '1', date: day + 2000, exerciseName: 'Б', lift: null, reps: 8, sets: 4, addedWeight: 0, note: 'x', setReps: [8, 8, 8, 3] },
        { id: '2', date: day + 1000, exerciseName: 'А', lift: null, reps: 5, sets: 3, addedWeight: 20, note: '' },
      ],
    }))
    expect(actions.copyDay(day, at)).toBe(2)
    update((d) => (snapshot = d))
    const copied = snapshot.entries.filter((e) => e.date >= at)
    expect(copied.map((e) => e.exerciseName)).toEqual(['А', 'Б'])
    expect(copied[1].setReps).toEqual([8, 8, 8, 3])
    expect(copied[1].note).toBe('')
    expect(new Set(snapshot.entries.map((e) => e.id)).size).toBe(4)

    actions.addBodyLog({ date: at, weight: 61.4 })
    actions.addBodyLog({ date: at - 86_400_000, weight: 62 })
    update((d) => (snapshot = d))
    expect(snapshot.profile.bodyweight).toBe(61.4)
  })
})
