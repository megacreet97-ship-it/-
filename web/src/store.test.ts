import { describe, expect, it } from 'vitest'
import { EXERCISE_LIBRARY, LIBRARY_VERSION } from './exerciseLibrary'
import { mergeLibrary, type AppData } from './store'

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
