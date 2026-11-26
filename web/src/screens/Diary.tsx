import { useEffect, useMemo, useRef, useState } from 'react'
import { Icon } from '../icons'
import { addDays, itemReps, itemTonnage, kg, longDay, num, setsLabel, startOfDay, weekdayShort, dayMonth } from '../logic'
import { actions, useData, type Entry } from '../store'
import { toLogItems } from '../derived'
import { C, IconBadge, Pill, Sheet, alpha, fromDateInput, liftColor, liftIcon, toDateInput, useToast } from '../ui'
import { RestTimerButton } from './RestTimer'
import { restTimer, useRestTimer } from '../restTimer'
import { QuickLogSheet, atCurrentTime, type LogDraft } from './QuickLog'

const capitalize = (s: string) => s.charAt(0).toUpperCase() + s.slice(1)

const lastWeekday = ['в прошлое воскресенье', 'в прошлый понедельник', 'в прошлый вторник', 'в прошлую среду', 'в прошлый четверг', 'в прошлую пятницу', 'в прошлую субботу']

export function DiaryScreen() {
  const data = useData()
  const today = startOfDay(Date.now())
  const [selected, setSelected] = useState(today)
  const [draft, setDraft] = useState<LogDraft | null>(null)
  const [toast, showToast] = useToast()
  const [copying, setCopying] = useState(false)
  const resting = useRestTimer()
  const timerUp = resting.endsAt !== null || resting.finishedAt !== null

  const dayEntries = useMemo(() => data.entries.filter((e) => startOfDay(e.date) === selected), [data.entries, selected])
  const daysWithEntries = useMemo(() => new Set(data.entries.map((e) => startOfDay(e.date))), [data.entries])
  const previousDay = useMemo(() => {
    const before = [...daysWithEntries].filter((d) => d < selected).sort((a, b) => b - a)
    return before[0] ?? null
  }, [daysWithEntries, selected])
  const sameWeekdayDay = useMemo(() => {
    const weekday = new Date(selected).getDay()
    const before = [...daysWithEntries].filter((d) => d < selected && new Date(d).getDay() === weekday).sort((a, b) => b - a)
    return before[0] ?? null
  }, [daysWithEntries, selected])

  const sets = dayEntries.reduce((a, e) => a + e.sets, 0)
  const dayItems = toLogItems(dayEntries)
  const reps = dayItems.reduce((a, i) => a + itemReps(i), 0)
  const tonnage = dayItems.reduce((a, i) => a + itemTonnage(i), 0)

  const repeatDay = (day: number) => {
    const count = actions.copyDay(day, atCurrentTime(selected))
    showToast(`Скопировано упражнений: ${count}`)
  }

  const addSet = (entry: Entry) => {
    if (entry.setReps?.length) {
      const setReps = [...entry.setReps, entry.setReps[entry.setReps.length - 1]]
      actions.updateEntry(entry.id, { setReps, sets: setReps.length })
    } else {
      actions.updateEntry(entry.id, { sets: entry.sets + 1 })
    }
    showToast(`${entry.exerciseName}: ${entry.sets + 1} подх.`)
    restTimer.autoStart()
  }

  return (
    <div className={`screen stack with-fab${timerUp ? ' resting' : ''}`}>
      <div className="screen-header">
        <div>
          <div className="caption" style={{ fontSize: 13, fontWeight: 600 }}>{capitalize(longDay(selected))}</div>
          <h1 className="large-title">Дневник</h1>
        </div>
        <div className="row" style={{ gap: 8 }}>
          {selected !== today && (
            <button className="btn-secondary" onClick={() => setSelected(today)} style={{ color: C.orange }}>Сегодня</button>
          )}
          <RestTimerButton />
        </div>
      </div>

      <DayStrip selected={selected} today={today} marked={daysWithEntries} onSelect={setSelected} />

      <div className="card summary" style={{ padding: '18px 0' }}>
        <SummaryItem value={String(dayEntries.length)} label="упражнений" />
        <SummaryItem value={String(sets)} label="подходов" />
        <SummaryItem value={String(reps)} label="повторений" />
        {tonnage > 0 && <SummaryItem value={tonnage >= 1000 ? `${num(Math.round(tonnage / 100) / 10)}т` : num(tonnage)} label="тоннаж, кг" />}
      </div>

      <div className="section-title">
        {selected === today ? 'Сегодня' : dayMonth(selected)}
        {dayEntries.length > 0 && <small>{dayEntries.length} упр.</small>}
      </div>

      {dayEntries.length === 0 ? (
        <div className="card" style={{ alignItems: 'center', textAlign: 'center', padding: '28px 16px' }}>
          <IconBadge icon="calendar" color={C.orange} size={56} />
          <div className="headline">Нет записей за этот день</div>
          <div className="footnote">Нажмите «Добавить упражнение» внизу — недавние упражнения будут сверху списка.</div>
          {sameWeekdayDay !== null && (
            <button className="btn-secondary" style={{ color: C.orange }} onClick={() => repeatDay(sameWeekdayDay)}>
              <Icon name="repeat" size={16} /> Как {lastWeekday[new Date(selected).getDay()]} · {dayMonth(sameWeekdayDay)}
            </button>
          )}
          {previousDay !== null && previousDay !== sameWeekdayDay && (
            <button className="btn-secondary" style={{ color: C.orange }} onClick={() => repeatDay(previousDay)}>
              <Icon name="repeat" size={16} /> Повторить от {dayMonth(previousDay)}
            </button>
          )}
          {daysWithEntries.size > 0 && (
            <button className="link" style={{ justifyContent: 'center', gap: 6 }} onClick={() => setCopying(true)}>
              <Icon name="copy" size={16} /> Выбрать другой день
            </button>
          )}
        </div>
      ) : (
        <div className="stack" style={{ gap: 10 }}>
          {dayEntries.map((e) => (
            <EntryCard key={e.id} entry={e} onOpen={() => setDraft({ date: selected, entry: e })} onAddSet={() => addSet(e)} />
          ))}
          {daysWithEntries.size > 1 && (
            <button className="link" style={{ justifyContent: 'center', gap: 6 }} onClick={() => setCopying(true)}>
              <Icon name="copy" size={16} /> Скопировать из другого дня
            </button>
          )}
        </div>
      )}

      <div className="floating-action">
        <button className="btn-primary" onClick={() => setDraft({ date: selected })}>
          <Icon name="plus" strokeWidth={2.6} /> Добавить упражнение
        </button>
      </div>

      {copying && (
        <CopyDaySheet entries={data.entries} target={selected} onClose={() => setCopying(false)}
          onPick={(day) => { repeatDay(day); setCopying(false) }} />
      )}
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

const monthTitle = (d: number) => capitalize(new Date(d).toLocaleDateString('ru-RU', { month: 'long' })) + ' ' + new Date(d).getFullYear()
const monthShort = (d: number) => new Date(d).toLocaleDateString('ru-RU', { month: 'short' }).replace('.', '')

function DayStrip({ selected, today, marked, onSelect }: { selected: number; today: number; marked: Set<number>; onSelect: (d: number) => void }) {
  const ref = useRef<HTMLDivElement>(null)
  const [visible, setVisible] = useState(selected)
  const first = Math.min(addDays(today, -56), addDays(selected, -14))
  const days = useMemo(() => {
    const list: number[] = []
    for (let d = first; d <= addDays(today, 7); d = addDays(d, 1)) list.push(d)
    return list
  }, [first, today])

  useEffect(() => {
    const el = ref.current?.querySelector<HTMLElement>(`[data-day="${selected}"]`)
    el?.scrollIntoView({ inline: 'center', block: 'nearest', behavior: 'smooth' })
    setVisible(selected)
  }, [selected])

  const onScroll = () => {
    const strip = ref.current
    if (!strip) return
    const center = strip.scrollLeft + strip.clientWidth / 2
    for (const pill of strip.querySelectorAll<HTMLElement>('[data-day]')) {
      if (pill.offsetLeft + pill.offsetWidth >= center) {
        setVisible(Number(pill.dataset.day))
        return
      }
    }
  }

  return (
    <div className="stack" style={{ gap: 8 }}>
      <div className="row between" style={{ padding: '0 4px' }}>
        <span className="headline">{monthTitle(visible)}</span>
        <label className="date-jump">
          <Icon name="calendar" size={16} /> Выбрать дату
          <input type="date" value={toDateInput(selected)} max={toDateInput(addDays(today, 7))} aria-label="Выбрать дату"
            onChange={(e) => e.target.value && onSelect(startOfDay(fromDateInput(e.target.value, selected)))} />
        </label>
      </div>
      <div className="day-strip" ref={ref} onScroll={onScroll}>
        {days.map((d) => (
          <div key={d} className="row" style={{ gap: 8, flex: 'none' }}>
            {new Date(d).getDate() === 1 && <span className="month-sep">{monthShort(d)}</span>}
            <button data-day={d} className={`day-pill ${d === selected ? 'selected' : ''} ${d === today ? 'today' : ''}`} onClick={() => onSelect(d)}>
              <span className="wd">{weekdayShort(d)}</span>
              <span className="dn">{new Date(d).getDate()}</span>
              <span className="dot" style={{ background: marked.has(d) ? (d === selected ? '#fff' : C.orange) : 'transparent' }} />
            </button>
          </div>
        ))}
      </div>
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
            <span style={{ fontSize: 22, fontWeight: 800 }}>{setsLabel(entry)}</span>
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

function CopyDaySheet({ entries, target, onPick, onClose }: { entries: Entry[]; target: number; onPick: (day: number) => void; onClose: () => void }) {
  const weekday = new Date(target).getDay()
  const [sameOnly, setSameOnly] = useState(false)
  const days = useMemo(() => {
    const byDay = new Map<number, Entry[]>()
    for (const e of entries) {
      const day = startOfDay(e.date)
      if (day === target) continue
      byDay.set(day, [...(byDay.get(day) ?? []), e])
    }
    return [...byDay.entries()].sort((a, b) => b[0] - a[0]).slice(0, 90)
  }, [entries, target])
  const sameCount = days.filter(([d]) => new Date(d).getDay() === weekday).length
  const shown = sameOnly ? days.filter(([d]) => new Date(d).getDay() === weekday) : days
  return (
    <Sheet title="Скопировать тренировку" onClose={onClose}>
      <div className="footnote">Упражнения выбранного дня добавятся {target === startOfDay(Date.now()) ? 'в сегодня' : `в ${dayMonth(target)}`} с теми же подходами и весами — потом их можно поменять.</div>
      {sameCount > 0 && sameCount < days.length && (
        <div className="h-scroll chips">
          <button className={`chip ${!sameOnly ? 'active' : ''}`} onClick={() => setSameOnly(false)}>Все дни</button>
          <button className={`chip ${sameOnly ? 'active' : ''}`} onClick={() => setSameOnly(true)}>Только {weekdayLong[weekday]}</button>
        </div>
      )}
      <div className="stack" style={{ gap: 10 }}>
        {shown.map(([day, list]) => {
          const sorted = [...list].sort((a, b) => a.date - b.date)
          const sets = sorted.reduce((a, e) => a + e.sets, 0)
          return (
            <button key={day} className="card" style={{ textAlign: 'left', gap: 8, padding: 14 }} onClick={() => onPick(day)}>
              <div className="row between">
                <span className="headline">{capitalize(longDay(day))}</span>
                {new Date(day).getDay() === weekday && <Pill text="тот же день недели" color={C.orange} />}
              </div>
              <div className="caption">{sorted.length} упр. · {sets} подх.</div>
              <div className="footnote" style={{ display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical', overflow: 'hidden' }}>
                {sorted.map((e) => `${e.exerciseName} ${setsLabel(e)}${e.addedWeight > 0 ? ` +${num(e.addedWeight)}` : ''}`).join(' · ')}
              </div>
            </button>
          )
        })}
      </div>
    </Sheet>
  )
}

const weekdayLong = ['воскресенья', 'понедельники', 'вторники', 'среды', 'четверги', 'пятницы', 'субботы']
