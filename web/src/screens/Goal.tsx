import { useMemo, useState } from 'react'
import { Icon } from '../icons'
import {
  goalPlan, goalTitle, goalVerdict, reachDate, seriesOf, smoothedLatest, targetProgress, trendLine, weeklyRate,
  type BodyLog, type Goal, type Tone,
} from '../body'
import { addDays, dayMonthYear, kg, num, startOfDay, weekStart } from '../logic'
import { KEY_MUSCLES, bestForMuscle, entriesInLastDays, muscleSets, muscleTitle, personalRecords, volumeZone } from '../muscles'
import { actions, effectiveGoal, useData } from '../store'
import { infoLookup } from '../derived'
import { LiftChart } from '../charts'
import { BigStepper, C, Card, IconBadge, Pill, ProgressBar, Ring, Segmented, Sheet, StatTile, alpha, fromDateInput, toDateInput } from '../ui'
import { MasterScreen } from './Master'
import { GoalPicker, GoalSettingsSheet, OptionalField, goalColor, goalIcon, parseOptional } from './GoalSettings'

const toneColor: Record<Tone, string> = { good: C.green, warn: C.orange, neutral: C.blue }

export const goalTabTitle = (goal: Goal | null) => (goal === 'ms' ? 'Цель МС' : goal ? 'Моя форма' : 'Цель')

export function GoalScreen({ onOpenExercises }: { onOpenExercises: () => void }) {
  const data = useData()
  const goal = effectiveGoal(data)
  if (goal === 'ms') return <MasterScreen />
  if (goal === null) {
    return (
      <div className="screen stack">
        <div className="screen-header"><h1 className="large-title">Цель</h1></div>
        <div className="footnote" style={{ padding: '0 4px' }}>Выберите, к чему идёте, — от этого зависит, что приложение покажет на этой вкладке. Цель можно поменять в любой момент.</div>
        <GoalPicker value={null} onPick={(g) => actions.updateProfile({ goal: g })} />
      </div>
    )
  }
  return <FormScreen goal={goal} onOpenExercises={onOpenExercises} />
}

const signed = (v: number, unit: string) => `${v > 0 ? '+' : v < 0 ? '−' : ''}${num(Math.abs(Math.round(v * 10) / 10))} ${unit}`

function FormScreen({ goal, onOpenExercises }: { goal: Goal; onOpenExercises: () => void }) {
  const data = useData()
  const { profile } = data
  const logs = useMemo(() => data.bodyLogs ?? [], [data.bodyLogs])
  const [editing, setEditing] = useState<BodyLog | 'new' | null>(null)
  const [settings, setSettings] = useState(false)
  const [showAll, setShowAll] = useState(false)
  const [chart, setChart] = useState<'weight' | 'waist'>('weight')

  const weights = useMemo(() => seriesOf(logs, (l) => l.weight), [logs])
  const waists = useMemo(() => seriesOf(logs, (l) => l.waist), [logs])
  const weight = smoothedLatest(weights)
  const waist = smoothedLatest(waists)
  const weightRate = weeklyRate(weights)
  const waistRate = weeklyRate(waists, 42)
  const verdict = goalVerdict(goal, weight, weightRate, waistRate)
  const color = goalColor[goal]

  const today = startOfDay(Date.now())
  const weekly = profile.weeklyWorkouts ?? 3
  const thisWeek = new Set(data.entries.filter((e) => e.date >= weekStart(today)).map((e) => startOfDay(e.date))).size
  const records = personalRecords(data.entries, addDays(today, -29))
  const targetWeight = profile.targetWeight ?? 0
  const startWeight = weights[0]?.value ?? 0
  const currentWeight = weight ?? profile.bodyweight
  const eta = reachDate(currentWeight, targetWeight, weightRate)

  const lookup = useMemo(() => infoLookup(data.exercises), [data.exercises])
  const sets = useMemo(() => muscleSets(entriesInLastDays(data.entries, 7), lookup), [data.entries, lookup])
  const weak = KEY_MUSCLES.filter((m) => volumeZone(sets[m]) === 'none' || volumeZone(sets[m]) === 'low').slice(0, 4)
  const growing = KEY_MUSCLES.filter((m) => sets[m] >= 10).length

  const points = chart === 'weight' ? weights : waists
  const target = chart === 'weight' ? targetWeight : profile.targetWaist ?? 0
  const recent = [...logs].sort((a, b) => b.date - a.date)

  return (
    <div className="screen stack">
      <div className="screen-header">
        <h1 className="large-title">Моя форма</h1>
        <button className="btn-secondary" style={{ color: C.orange }} onClick={() => setEditing('new')}>
          <Icon name="plus" size={16} strokeWidth={2.6} /> Замер
        </button>
      </div>

      <section className="hero">
        <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
          <button onClick={() => setSettings(true)}><Pill text={`Цель: ${goalTitle[goal]}`} icon={goalIcon[goal]} color={color} /></button>
          {targetWeight > 0 && <Pill text={`вес ${kg(targetWeight)}`} icon="flag" color="#aeaeb2" />}
          {(profile.targetWaist ?? 0) > 0 && <Pill text={`талия ${num(profile.targetWaist ?? 0)} см`} icon="ruler" color="#aeaeb2" />}
        </div>
        <div className="row" style={{ gap: 18 }}>
          <Ring progress={thisWeek / weekly} size={120} line={14}>
            <div>
              <div className="num" style={{ fontSize: 30, fontWeight: 800, lineHeight: 1 }}>{thisWeek}<span className="secondary" style={{ fontSize: 18 }}>/{weekly}</span></div>
              <div className="caption">трен. за неделю</div>
            </div>
          </Ring>
          <div className="stack" style={{ gap: 6, minWidth: 0 }}>
            <div className="headline" style={{ color: toneColor[verdict.tone], fontSize: 19 }}>{verdict.title}</div>
            <div className="footnote">{verdict.text}</div>
          </div>
        </div>
      </section>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
        <StatTile title="Вес" value={weight !== null ? num(Math.round(weight * 10) / 10) : '—'} caption={weightRate !== null ? `${signed(weightRate, 'кг')}/нед` : 'кг'} color={C.blue} />
        <StatTile title="Талия" value={waist !== null ? num(Math.round(waist * 10) / 10) : '—'} caption={waistRate !== null ? `${signed(waistRate, 'см')}/нед` : 'см'} color={C.pink} />
        <StatTile title="Рекорды" value={String(records)} caption="за 30 дней" color={C.yellow} />
      </div>

      {targetWeight > 0 && startWeight > 0 && (
        <Card title="Путь к цели" icon="flag">
          <div className="row between subhead">
            <span>Старт {kg(startWeight)}</span>
            <span style={{ fontWeight: 800 }}>Цель {kg(targetWeight)}</span>
          </div>
          <ProgressBar value={targetProgress(startWeight, currentWeight, targetWeight)} color={color} height={10} />
          <div className="footnote">
            {Math.abs(targetWeight - currentWeight) < 0.3
              ? 'Цель по весу достигнута — теперь держите вес и прибавляйте в силе.'
              : `Осталось ${kg(Math.round(Math.abs(targetWeight - currentWeight) * 10) / 10)}${eta ? ` · при текущем темпе ~${dayMonthYear(eta)}` : ''}`}
          </div>
        </Card>
      )}

      <Card title="Динамика" icon="chart">
        {waists.length > 0 && <Segmented options={[{ value: 'weight' as const, label: 'Вес' }, { value: 'waist' as const, label: 'Талия' }]} value={chart} onChange={setChart} />}
        {points.length === 0 ? (
          <div className="footnote" style={{ minHeight: 100, display: 'grid', placeItems: 'center', textAlign: 'center' }}>
            Добавьте первый замер кнопкой «Замер» — здесь появится график.
          </div>
        ) : (
          <LiftChart points={points.slice(-60)} color={chart === 'weight' ? C.blue : C.pink} target={target || undefined}
            trend={trendLine(points, chart === 'weight' ? 28 : 42)} />
        )}
        <div className="caption">Вес скачет на 1–2 кг из-за воды и еды, поэтому оценка идёт по тренду за 4 недели, а не по одному взвешиванию.</div>
      </Card>

      <Card title="Замеры" icon="ruler" trailing={logs.length > 5 ? <button className="link" onClick={() => setShowAll(true)}>Все</button> : undefined}>
        {recent.length === 0 ? <div className="secondary">Пока пусто</div> : recent.slice(0, 5).map((l) => <LogRow key={l.id} log={l} onClick={() => setEditing(l)} />)}
      </Card>

      <Card title="Мышцы за 7 дней" icon="body">
        <div className="subhead">{growing > 0 ? `В зоне роста (10+ подходов): ${growing} из ${KEY_MUSCLES.length} основных мышц.` : 'Пока ни одна мышца не получила 10+ подходов за неделю.'}</div>
        {weak.map((m) => {
          const [best] = bestForMuscle(m, 1)
          return (
            <div key={m} className="row" style={{ gap: 10, alignItems: 'flex-start' }}>
              <span className="pill" style={{ background: alpha(C.orange, 0.15), color: C.orange, flex: 'none' }}>{num(Math.round(sets[m] * 10) / 10)} подх.</span>
              <span className="footnote"><b style={{ color: 'var(--text)' }}>{muscleTitle[m]}</b>{best ? ` — попробуйте «${best[0]}»` : ''}</span>
            </div>
          )
        })}
        <button className="link" onClick={onOpenExercises}>Нагрузка на все мышцы и лучшие упражнения <Icon name="chevronRight" size={16} /></button>
      </Card>

      <Card title={`План: ${goalTitle[goal].toLowerCase()}`} icon="list">
        {goalPlan(goal, currentWeight, weekly).map((item) => (
          <div key={item.title} className="stack" style={{ gap: 2 }}>
            <span className="subhead" style={{ fontWeight: 700, color }}>{item.title}</span>
            <span className="footnote">{item.text}</span>
          </div>
        ))}
        <div className="caption">Общие рекомендации для здоровых взрослых. При болезнях, беременности или сильном лишнем весе цели лучше обсудить с врачом.</div>
      </Card>

      <button className="link" style={{ justifyContent: 'center', gap: 6 }} onClick={() => setSettings(true)}>
        <Icon name="target" size={16} /> Настроить цель
      </button>

      {editing && <BodyLogSheet log={editing === 'new' ? null : editing} defaultWeight={currentWeight} onClose={() => setEditing(null)} />}
      {settings && <GoalSettingsSheet onClose={() => setSettings(false)} />}
      {showAll && (
        <Sheet title="Все замеры" onClose={() => setShowAll(false)} left={<button onClick={() => setShowAll(false)}>Закрыть</button>}>
          <div className="card" style={{ gap: 4 }}>{recent.map((l) => <LogRow key={l.id} log={l} onClick={() => setEditing(l)} />)}</div>
        </Sheet>
      )}
    </div>
  )
}

function LogRow({ log, onClick }: { log: BodyLog; onClick: () => void }) {
  return (
    <button className="row" style={{ width: '100%', textAlign: 'left', gap: 12, padding: '4px 0' }} onClick={onClick}>
      <IconBadge icon="scale" color={C.blue} size={36} />
      <span className="footnote" style={{ flex: 1 }}>{dayMonthYear(log.date)}</span>
      {log.waist ? <span className="caption num">талия {num(log.waist)}</span> : null}
      {log.bodyFat ? <span className="caption num">жир {num(log.bodyFat)}%</span> : null}
      <span className="headline num">{kg(log.weight)}</span>
    </button>
  )
}

function BodyLogSheet({ log, defaultWeight, onClose }: { log: BodyLog | null; defaultWeight: number; onClose: () => void }) {
  const [weight, setWeight] = useState(log?.weight ?? Math.round(defaultWeight * 10) / 10)
  const [waist, setWaist] = useState(log?.waist ? num(log.waist) : '')
  const [bodyFat, setBodyFat] = useState(log?.bodyFat ? num(log.bodyFat) : '')
  const [date, setDate] = useState(log?.date ?? Date.now())

  const save = () => {
    const payload = { date, weight, waist: parseOptional(waist), bodyFat: parseOptional(bodyFat) }
    if (log) actions.updateBodyLog(log.id, payload)
    else actions.addBodyLog(payload)
    onClose()
  }

  return (
    <Sheet title={log ? 'Замер' : 'Новый замер'} onClose={onClose}
      right={log ? <button style={{ color: C.pink }} aria-label="Удалить" onClick={() => { if (confirm('Удалить замер?')) { actions.deleteBodyLog(log.id); onClose() } }}><Icon name="trash" size={20} /></button> : undefined}
      footer={<button className="btn-primary" onClick={save}><Icon name="check" strokeWidth={2.6} /> Сохранить</button>}>
      <BigStepper title="Вес тела" value={weight} onChange={setWeight} step={0.1} min={30} max={250} unit="кг" quickSteps={[-1, -0.5, 0.5, 1]} />
      <div className="footnote" style={{ textAlign: 'center' }}>Нажмите на число, чтобы вписать вес. Взвешивайтесь утром натощак.</div>
      <div className="field-group">
        <OptionalField label="Талия" value={waist} onChange={setWaist} suffix="см" />
        <OptionalField label="Процент жира" value={bodyFat} onChange={setBodyFat} suffix="%" />
        <div className="field">
          <label>Дата</label>
          <input type="date" value={toDateInput(date)} onChange={(e) => e.target.value && setDate(fromDateInput(e.target.value, date))} />
        </div>
      </div>
      <div className="caption">Талию мерьте по пупку, на выдохе, раз в неделю. Для рекомпозиции это главный показатель.</div>
    </Sheet>
  )
}
