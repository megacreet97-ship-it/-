import { useMemo, useState } from 'react'
import { Icon } from '../icons'
import { dayMonth, estimatedAddedWeight, kg, liftFullTitle, type Lift } from '../logic'
import { actions, useData, type Entry } from '../store'
import { lastEntryFor, recentExercises } from '../derived'
import { EXERCISE_CATEGORIES, compareCategories } from '../exerciseLibrary'
import { BigStepper, C, IconBadge, Segmented, Sheet, Switch, alpha, liftColor, liftIcon } from '../ui'

export interface LogDraft {
  date: number
  entry?: Entry
  exerciseName?: string
}

export const atCurrentTime = (day: number) => {
  const now = new Date()
  const d = new Date(day)
  d.setHours(now.getHours(), now.getMinutes(), now.getSeconds(), 0)
  return d.getTime()
}

export function QuickLogSheet({ draft, onClose, onSaved }: { draft: LogDraft; onClose: () => void; onSaved?: (text: string) => void }) {
  const data = useData()
  const initialName = draft.entry?.exerciseName ?? draft.exerciseName ?? data.entries[data.entries.length - 1]?.exerciseName
    ?? data.exercises.find((e) => e.lift === 'pullUp')?.name ?? data.exercises[0]?.name ?? ''
  const initialSource = draft.entry ?? lastEntryFor(data.entries, initialName)

  const [exerciseName, setExerciseName] = useState(initialName)
  const [sets, setSets] = useState(initialSource?.sets ?? 3)
  const [reps, setReps] = useState(initialSource?.reps ?? 8)
  const [weight, setWeight] = useState(initialSource?.addedWeight ?? 0)
  const [note, setNote] = useState(draft.entry?.note ?? '')
  const [saveAsMax, setSaveAsMax] = useState(!draft.entry)
  const [picking, setPicking] = useState(false)

  const exercise = data.exercises.find((e) => e.name === exerciseName)
  const lift: Lift | null = exercise?.lift ?? draft.entry?.lift ?? null
  const last = lastEntryFor(data.entries, exerciseName, draft.entry?.date ?? Infinity)
  const bodyweight = data.profile.bodyweight
  const estimate = lift && reps > 1 ? estimatedAddedWeight(weight, bodyweight, reps) : null
  const tint = lift ? liftColor[lift] : C.orange

  const apply = (e: Entry) => {
    setSets(e.sets)
    setReps(e.reps)
    setWeight(e.addedWeight)
  }

  const choose = (name: string) => {
    setExerciseName(name)
    setPicking(false)
    if (!draft.entry) {
      const previous = lastEntryFor(data.entries, name)
      if (previous) apply(previous)
    }
  }

  const save = () => {
    const trimmed = note.trim()
    let date: number
    if (draft.entry) {
      date = draft.entry.date
      actions.updateEntry(draft.entry.id, { exerciseName, lift, sets, reps, addedWeight: weight, note: trimmed })
    } else {
      date = atCurrentTime(draft.date)
      actions.addEntry({ date, exerciseName, lift, sets, reps, addedWeight: weight, note: trimmed })
    }
    if (saveAsMax && reps === 1 && lift) {
      actions.addAttempt({ date, lift, addedWeight: weight, bodyweight, isCompetition: false, note: '' })
      onSaved?.(`Рекорд записан: +${kg(weight)}`)
    } else {
      onSaved?.(draft.entry ? 'Изменения сохранены' : 'Записано')
    }
    onClose()
  }

  const remove = () => {
    if (draft.entry && confirm('Удалить запись?')) {
      actions.deleteEntry(draft.entry.id)
      onClose()
    }
  }

  const duplicate = () => {
    if (!draft.entry) return
    actions.addEntry({ ...draft.entry, date: draft.entry.date + 1000 })
    onSaved?.('Скопировано')
    onClose()
  }

  return (
    <Sheet
      title={draft.entry ? 'Запись' : 'Новый подход'}
      onClose={onClose}
      right={draft.entry ? <button onClick={remove} style={{ color: C.pink }} aria-label="Удалить"><Icon name="trash" size={20} /></button> : undefined}
      footer={
        <button className="btn-primary" disabled={!exerciseName} onClick={save}>
          <Icon name="check" strokeWidth={2.6} /> {draft.entry ? 'Сохранить' : 'Записать'}
        </button>
      }
    >
      <button className="card" style={{ flexDirection: 'row', alignItems: 'center', textAlign: 'left' }} onClick={() => setPicking(true)}>
        <IconBadge icon={lift ? liftIcon[lift] : 'dumbbell'} color={tint} size={44} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div className="caption">Упражнение</div>
          <div className="headline">{exerciseName || 'Выберите упражнение'}</div>
        </div>
        <Icon name="chevronRight" size={18} className="tertiary" />
      </button>

      {last && (
        <div className="card" style={{ flexDirection: 'row', alignItems: 'center', padding: 14 }}>
          <Icon name="clock" size={20} style={{ color: tint }} />
          <div style={{ flex: 1 }}>
            <div className="caption">В прошлый раз · {dayMonth(last.date)}</div>
            <div className="subhead num" style={{ fontWeight: 700 }}>
              {last.sets} × {last.reps}{last.addedWeight > 0 ? ` · +${kg(last.addedWeight)}` : ''}
            </div>
          </div>
          <button onClick={() => apply(last)} style={{ color: tint, fontWeight: 600, fontSize: 15 }}>Подставить</button>
        </div>
      )}

      <div className="stepper-grid">
        <BigStepper title="Подходы" value={sets} onChange={setSets} min={1} max={50} />
        <BigStepper title="Повторения" value={reps} onChange={setReps} min={1} max={500} />
      </div>
      <BigStepper title="Отягощение" value={weight} onChange={setWeight} step={1.25} max={300} unit="кг" quickSteps={[-2.5, 1.25, 2.5, 5]} />

      <div className="card" style={{ flexDirection: 'row' }}>
        <div style={{ flex: 1 }}>
          <div className="caption">Всего повторений</div>
          <div className="big-number num">{sets * reps}</div>
        </div>
        {weight > 0 && (
          <div style={{ flex: 1 }}>
            <div className="caption">Тоннаж</div>
            <div className="big-number num">{kg(weight * sets * reps)}</div>
          </div>
        )}
      </div>

      {lift && (
        <div className="card" style={{ background: alpha(tint, 0.1), borderColor: alpha(tint, 0.2) }}>
          <div className="row" style={{ color: tint, fontWeight: 700, fontSize: 15 }}>
            <Icon name="trophy" size={18} /> {liftFullTitle[lift]}
          </div>
          {reps === 1 ? (
            <>
              <div className="row between">
                <span>Засчитать как рекорд на 1 раз</span>
                <Switch on={saveAsMax} onChange={setSaveAsMax} />
              </div>
              <div className="caption">Попытка попадёт во вкладку «Мастер спорта».</div>
            </>
          ) : estimate !== null ? (
            <>
              <div className="row between">
                <span>Расчётный максимум на 1 раз</span>
                <span className="headline num">+{kg(Math.round(estimate * 10) / 10)}</span>
              </div>
              <div className="caption">По формулам Эпли и Бжицки от веса тела {kg(bodyweight)} с отягощением.</div>
            </>
          ) : (
            <div className="caption">Расчёт максимума работает до 12 повторений.</div>
          )}
        </div>
      )}

      <textarea className="text-input" rows={2} placeholder="Заметка: самочувствие, техника…" value={note} onChange={(e) => setNote(e.target.value)} />

      {draft.entry && (
        <button className="btn-secondary" style={{ alignSelf: 'center' }} onClick={duplicate}>
          <Icon name="copy" size={16} /> Дублировать
        </button>
      )}

      {picking && <ExercisePicker selected={exerciseName} onPick={choose} onClose={() => setPicking(false)} />}
    </Sheet>
  )
}

export function ExercisePicker({ selected, onPick, onClose }: { selected: string; onPick: (name: string) => void; onClose: () => void }) {
  const data = useData()
  const [query, setQuery] = useState('')
  const [creating, setCreating] = useState(false)

  const [category, setCategory] = useState<string | null>(null)
  const q = query.trim().toLowerCase()

  const categories = useMemo(() => [...new Set(data.exercises.map((e) => e.category))].sort(compareCategories), [data.exercises])
  const recent = useMemo(() => recentExercises(data.entries, 6).map((e) => e.exerciseName), [data.entries])

  const groups = useMemo(() => {
    const filtered = data.exercises.filter((e) => (q ? e.name.toLowerCase().includes(q) : !category || e.category === category))
    const map = new Map<string, typeof filtered>()
    for (const e of filtered) map.set(e.category, [...(map.get(e.category) ?? []), e])
    return [...map.entries()].sort(([a], [b]) => compareCategories(a, b))
  }, [data.exercises, q, category])

  const row = (name: string, lift: Lift | null, key: string) => (
    <button key={key} className="list-row" onClick={() => onPick(name)}>
      <IconBadge icon={lift ? liftIcon[lift] : 'dumbbell'} color={lift ? liftColor[lift] : C.orange} size={30} />
      <span style={{ flex: 1 }}>{name}</span>
      {name === selected && <Icon name="check" size={18} style={{ color: C.orange }} />}
    </button>
  )

  return (
    <Sheet title="Упражнение" onClose={onClose} right={<button onClick={() => setCreating(true)} aria-label="Новое упражнение"><Icon name="plus" /></button>}>
      <div className="text-input row" style={{ padding: '10px 14px' }}>
        <Icon name="search" size={18} className="secondary" />
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder={`Поиск среди ${data.exercises.length} упражнений`} style={{ background: 'transparent', border: 0, outline: 'none', flex: 1, fontSize: 16 }} />
        {query && <button onClick={() => setQuery('')} aria-label="Очистить"><Icon name="close" size={16} className="secondary" /></button>}
      </div>
      {!q && (
        <div className="h-scroll chips">
          <button className={`chip ${category === null ? 'active' : ''}`} onClick={() => setCategory(null)}>Все</button>
          {categories.map((c) => (
            <button key={c} className={`chip ${category === c ? 'active' : ''}`} onClick={() => setCategory(c)}>{c}</button>
          ))}
        </div>
      )}
      {!q && !category && recent.length > 0 && (
        <div className="stack" style={{ gap: 8 }}>
          <div className="group-label" style={{ margin: '4px 16px 0' }}>Недавние</div>
          <div className="field-group">
            {recent.map((name) => row(name, data.exercises.find((e) => e.name === name)?.lift ?? null, `recent-${name}`))}
          </div>
        </div>
      )}
      {groups.map(([group, items]) => (
        <div key={group} className="stack" style={{ gap: 8 }}>
          <div className="group-label" style={{ margin: '4px 16px 0' }}>{group}</div>
          <div className="field-group">
            {items.map((e) => row(e.name, e.lift, e.id))}
          </div>
        </div>
      ))}
      {groups.length === 0 && (
        <button className="btn-secondary" style={{ alignSelf: 'center', color: C.orange }} onClick={() => setCreating(true)}>
          <Icon name="plus" size={16} /> Создать «{query}»
        </button>
      )}
      {creating && (
        <ExerciseForm
          initialName={query}
          onClose={() => setCreating(false)}
          onCreated={(name) => {
            setCreating(false)
            onPick(name)
          }}
        />
      )}
    </Sheet>
  )
}

export function ExerciseForm({ initialName = '', onClose, onCreated }: { initialName?: string; onClose: () => void; onCreated?: (name: string) => void }) {
  const data = useData()
  const [name, setName] = useState(initialName)
  const [category, setCategory] = useState('Другое')
  const [lift, setLift] = useState<'none' | Lift>('none')
  const categories = [...new Set([...EXERCISE_CATEGORIES, ...data.exercises.map((e) => e.category)])]
  const clean = name.trim()
  const exists = data.exercises.some((e) => e.name.toLowerCase() === clean.toLowerCase())

  const save = () => {
    actions.addExercise(clean, category.trim() || 'Другое', lift === 'none' ? null : lift)
    onCreated?.(clean)
    onClose()
  }

  return (
    <Sheet title="Новое упражнение" onClose={onClose} right={<button disabled={!clean || exists} onClick={save} style={{ opacity: !clean || exists ? 0.4 : 1 }}>Готово</button>}>
      <input className="text-input" placeholder="Название" value={name} onChange={(e) => setName(e.target.value)} autoFocus />
      {exists && <div className="group-footer" style={{ color: C.pink }}>Такое упражнение уже есть</div>}
      <div className="group-label">Категория</div>
      <input className="text-input" list="categories" value={category} onChange={(e) => setCategory(e.target.value)} />
      <datalist id="categories">{categories.map((c) => <option key={c} value={c} />)}</datalist>
      <div className="group-label">Связь с движением стритлифтинга</div>
      <Segmented options={[{ value: 'none', label: 'Нет' }, { value: 'pullUp', label: 'Подтягивания' }, { value: 'dip', label: 'Брусья' }]} value={lift} onChange={setLift} />
      <div className="group-footer">Подходы связанного упражнения дают расчётный максимум на графике «Мастер спорта».</div>
    </Sheet>
  )
}
