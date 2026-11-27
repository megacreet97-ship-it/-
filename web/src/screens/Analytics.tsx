import { useMemo, useState } from 'react'
import { Icon } from '../icons'
import {
  addDays, currentStreak, exerciseTotals, itemReps, itemTonnage, kg, longestStreak, num,
  startOfDay, totalReps, totalSets, trainingDays, weeklySum, type ExerciseTotal,
} from '../logic'
import { useData } from '../store'
import { toLogItems } from '../derived'
import { BarChart } from '../charts'
import { C, Card, IconBadge, ProgressBar, Segmented, StatTile, liftColor, liftIcon } from '../ui'
import { ExerciseDetail } from './ExerciseDetail'

type Period = 28 | 90 | 365 | 0

export function AnalyticsScreen() {
  const data = useData()
  const [period, setPeriod] = useState<Period>(28)
  const [detail, setDetail] = useState<string | null>(null)

  const allItems = useMemo(() => toLogItems(data.entries), [data.entries])
  const items = useMemo(() => {
    if (period === 0) return allItems
    const from = addDays(startOfDay(Date.now()), -period + 1)
    return allItems.filter((i) => i.date >= from)
  }, [allItems, period])

  const allDays = useMemo(() => trainingDays(allItems), [allItems])
  const days = trainingDays(items)
  const totals = exerciseTotals(items)
  const maxReps = Math.max(1, ...totals.map((t) => t.totalReps))
  const weeklyReps = weeklySum(items, itemReps)
  const weeklyTonnage = weeklySum(items, itemTonnage)
  const hasTonnage = weeklyTonnage.some((w) => w.value > 0)
  const weeks = period === 0 ? Math.max(1, weeklyReps.length) : period / 7

  return (
    <div className="screen stack">
      <div className="screen-header"><h1 className="large-title">Аналитика</h1></div>
      <Segmented<Period> options={[{ value: 28, label: '4 нед' }, { value: 90, label: '3 мес' }, { value: 365, label: 'Год' }, { value: 0, label: 'Всё' }]} value={period} onChange={setPeriod} />

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <StatTile title="Тренировки" value={String(days.size)} caption={`≈ ${num(Math.round((days.size / weeks) * 10) / 10)} в неделю`} icon="calendar" color={C.orange} />
        <StatTile title="Серия" value={`${currentStreak(allDays)} дн.`} caption={`рекорд ${longestStreak(allDays)} дн.`} icon="flame" color={C.pink} />
        <StatTile title="Подходы" value={num(totalSets(items))} icon="list" color={C.blue} />
        <StatTile title="Повторения" value={num(totalReps(items))} icon="bolt" color={C.violet} />
      </div>

      <Card title="Повторения по неделям" icon="chart">
        <BarChart data={weeklyReps} color={C.orange} />
      </Card>

      {hasTonnage && (
        <Card title="Тоннаж с отягощением, кг" icon="dumbbell">
          <BarChart data={weeklyTonnage} color={C.violet} format={(v) => (v >= 1000 ? `${num(Math.round(v / 100) / 10)}т` : num(Math.round(v)))} />
        </Card>
      )}

      <Card title="Упражнения" icon="list">
        {totals.length === 0 ? (
          <div className="secondary">Нет записей за период</div>
        ) : totals.map((t) => (
          <ExerciseRow key={t.name} total={t} max={maxReps} onClick={() => setDetail(t.name)}
            lift={data.exercises.find((e) => e.name === t.name)?.lift ?? null} />
        ))}
      </Card>

      {detail && <ExerciseDetail key={detail} name={detail} onClose={() => setDetail(null)} onOpen={setDetail} />}
    </div>
  )
}

function ExerciseRow({ total, max, lift, onClick }: { total: ExerciseTotal; max: number; lift: 'pullUp' | 'dip' | null; onClick: () => void }) {
  const color = lift ? liftColor[lift] : C.orange
  return (
    <button className="row" style={{ width: '100%', textAlign: 'left', gap: 12 }} onClick={onClick}>
      <IconBadge icon={lift ? liftIcon[lift] : 'dumbbell'} color={color} size={38} />
      <div className="stack" style={{ flex: 1, gap: 6, minWidth: 0 }}>
        <div className="row between">
          <span className="subhead" style={{ fontWeight: 700, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{total.name}</span>
          <span className="subhead num" style={{ fontWeight: 800 }}>{num(total.totalReps)}</span>
        </div>
        <ProgressBar value={total.totalReps / max} color={color} height={6} />
        <div className="caption">{total.sessions} трен. · {total.totalSets} подх.{total.maxWeight > 0 ? ` · макс +${kg(total.maxWeight)}` : ''}</div>
      </div>
      <Icon name="chevronRight" size={16} className="tertiary" />
    </button>
  )
}
