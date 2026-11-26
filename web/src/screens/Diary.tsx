import { useEffect, useMemo, useRef, useState } from 'react'
import { Icon } from '../icons'
import { addDays, kg, longDay, num, startOfDay, weekdayShort, dayMonth } from '../logic'
import { actions, useData, type Entry } from '../store'
import { recentExercises } from '../derived'
import { C, IconBadge, alpha, liftColor, liftIcon, useToast } from '../ui'
import { QuickLogSheet, atCurrentTime, type LogDraft } from './QuickLog'

const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)

export function DiaryScreen() {
  const data = useData()
  const today = startOfDay(Date.now())
  const [selected, setSelected] = useState(today)
  const [draft, setDraft] = useState<LogDraft | null>(null)
  const [toast, showToast] = useToast()

  const dayEntries = useMemo(() => data.entries.filter((e) => startOfDay(e.date) === selected), [data.entries, selected])
  const recent = useMemo(() => recentExercises(data.entries), [data.entries])
  const daysWithEntries = useMemo(() => new Set(data.entries.map((e) => startOfDay(e.date))), [data.entries])
  const previousDay = useMemo(() => {
    const before = [...daysWithEntries].filter((d) => d < selected).sort((a, b) => b - a)
    return before[0] ?? null
  }, [daysWithEntries, selected])

  const sets = dayEntries.reduce((a, e) => a + e.sets, 0)
  const reps = dayEntries.reduce((a, e) => a + e.sets * e.reps, 0)
  const tonnage = dayEntries.reduce((a, e) => a + e.sets * e.reps * e.addedWeight, 0)

  const repeatDay = (day: number) => {
    const source = data.entries.filter((e) => startOfDay(e.date) === day)
    source.forEach((e, i) => actions.addEntry({ ...e, date: atCurrentTime(selected) + i * 1000, note: '' }))
    showToast(`Добавлено упражнений: ${source.length}`)
  }

  const addSet = (entry: Entry) => {
    actions.updateEntry(entry.id, { sets: entry.sets + 1 })
    showToast(`${entry.exerciseName}: ${entry.sets + 1} подх.`)
  }

  return (
    <div className="screen stack with-fab">
      <div className="screen-header">
        <div>
          <div className="caption" style={{ fontSize: 13, fontWeight: 600 }}>{capitalize(longDay(selected))}</div>
          <h1 className="large-title">Дневник</h1>
        </div>
        {selected !== today && (
          <button className="btn-secondary" onClick={() => setSelected(today)} style={{ color: C.orange }}>Сегодня</button>
        )}
      </div>

      <DayStrip selected={selected} today={today} marked={daysWithEntries} onSelect={setSelected} />

      <div className="card summary" style={{ padding: '18px 0' }}>
        <SummaryItem value={String(dayEntries.length)} label="упражнений" />
        <SummaryItem value={String(sets)} label="подходов" />
        <SummaryItem value={String(reps)} label="повторений" />
        {tonnage > 0 && <SummaryItem value={tonnage >= 1000 ? `${num(Math.round(tonnage / 100) / 10)}т` : num(tonnage)} label="тоннаж, кг" />}
      </div>

      {recent.length > 0 && (
        <>
          <div className="section-title">Быстро добавить</div>
          <div className="h-scroll">
            {recent.map((e) => (
              <button key={e.exerciseName} className="quick-chip" onClick={() => setDraft({ date: selected, exerciseName: e.exerciseName })}>
                <div className="row" style={{ justifyContent: 'space-between' }}>
                  <IconBadge icon={e.lift ? liftIcon[e.lift] : 'dumbbell'} color={e.lift ? liftColor[e.lift] : C.orange} size={30} />
                  <Icon name="plus" size={18} style={{ color: C.orange }} />
                </div>
                <div className="name">{e.exerciseName}</div>
                <div className="caption num">{e.sets} × {e.reps}{e.addedWeight > 0 ? ` · +${num(e.addedWeight)}` : ''}</div>
              </button>
            ))}
          </div>
        </>
      )}

      <div className="section-title">
        {selected === today ? 'Сегодня' : dayMonth(selected)}
        {dayEntries.length > 0 && <small>{dayEntries.length} упр.</small>}
      </div>

      {dayEntries.length === 0 ? (
        <div className="card" style={{ alignItems: 'center', textAlign: 'center', padding: '28px 16px' }}>
          <IconBadge icon="calendar" color={C.orange} size={56} />
          <div className="headline">Нет записей за этот день</div>
          <div className="footnote">Нажмите «Добавить упражнение» внизу или выберите упражнение из быстрых.</div>
          {previousDay !== null && (
            <button className="btn-secondary" style={{ color: C.orange }} onClick={() => repeatDay(previousDay)}>
              <Icon name="repeat" size={16} /> Повторить тренировку от {dayMonth(previousDay)}
            </button>
          )}
        </div>
      ) : (
        <div className="stack" style={{ gap: 10 }}>
          {dayEntries.map((e) => (
            <EntryCard key={e.id} entry={e} onOpen={() => setDraft({ date: selected, entry: e })} onAddSet={() => addSet(e)} />
          ))}
        </div>
      )}

      <div className="floating-action">
        <button className="btn-primary" onClick={() => setDraft({ date: selected })}>
          <Icon name="plus" strokeWidth={2.6} /> Добавить упражнение
        </button>
      </div>

      {draft && <QuickLogSheet draft={draft} onClose={() => setDraft(null)} onSaved={showToast} />}
      {toast}
    </div>
  )
}

function SummaryItem({ value, label }: { value: string; label: string }) {
  return (
    <div>
      <span className="num" style={{ fontSize: 24, fontWeight: 800 }}>{value}</span>
      <span className="caption">{label}</span>
    </div>
  )
}

function DayStrip({ selected, today, marked, onSelect }: { selected: number; today: number; marked: Set<number>; onSelect: (d: number) => void }) {
  const ref = useRef<HTMLDivElement>(null)
  const days = useMemo(() => Array.from({ length: 64 }, (_, i) => addDays(today, i - 56)), [today])

  useEffect(() => {
    const el = ref.current?.querySelector<HTMLElement>(`[data-day="${selected}"]`)
    el?.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'smooth' })
  }, [selected])

  return (
    <div className="day-strip" ref={ref}>
      {days.map((d) => (
        <button key={d} data-day={d} className={`day-pill ${d === selected ? 'selected' : ''} ${d === today ? 'today' : ''}`} onClick={() => onSelect(d)}>
          <span className="wd">{weekdayShort(d)}</span>
          <span className="dn">{new Date(d).getDate()}</span>
          <span className="dot" style={{ background: marked.has(d) ? (d === selected ? '#fff' : C.orange) : 'transparent' }} />
        </button>
      ))}
    </div>
  )
}

function EntryCard({ entry, onOpen, onAddSet }: { entry: Entry; onOpen: () => void; onAddSet: () => void }) {
  const color = entry.lift ? liftColor[entry.lift] : C.orange
  return (
    <div className="entry-card">
      <button onClick={onOpen} className="row" style={{ flex: 1, minWidth: 0, gap: 14, textAlign: 'left' }}>
        <IconBadge icon={entry.lift ? liftIcon[entry.lift] : 'dumbbell'} color={color} size={44} />
        <div style={{ minWidth: 0, flex: 1 }}>
          <div className="headline" style={{ fontSize: 16, lineHeight: 1.25 }}>{entry.exerciseName}</div>
          <div className="row num" style={{ gap: 8, marginTop: 4, flexWrap: 'wrap' }}>
            <span style={{ fontSize: 22, fontWeight: 800 }}>{entry.sets} × {entry.reps}</span>
            {entry.addedWeight > 0 && <span className="pill" style={{ background: alpha(color, 0.18), color }}>+{kg(entry.addedWeight)}</span>}
          </div>
          {entry.note && <div className="caption" style={{ marginTop: 4, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{entry.note}</div>}
        </div>
      </button>
      <button className="add-set" style={{ background: alpha(color, 0.15), color }} onClick={onAddSet} aria-label="Добавить подход">
        <Icon name="plus" size={18} strokeWidth={2.6} />
        подход
      </button>
    </div>
  )
}
