import { dailyProgress, dayMonthYear, exerciseTotals, kg, num, setsLabel } from '../logic'
import { bestForMuscle, kindTitle, levelTitle, muscleTitle, type ExerciseInfo } from '../muscles'
import { useData } from '../store'
import { infoLookup, toLogItems } from '../derived'
import { BarChart } from '../charts'
import { Icon } from '../icons'
import { C, Card, Pill, Sheet, StatTile } from '../ui'

export function Stars({ rating, size = 13 }: { rating: number; size?: number }) {
  return (
    <span className="row" style={{ gap: 1, flex: 'none' }} aria-label={`Оценка ${rating} из 5`}>
      {[1, 2, 3, 4, 5].map((i) => (
        <Icon key={i} name="star" size={size} strokeWidth={1.6}
          style={{ color: i <= rating ? C.yellow : 'rgba(255,255,255,0.2)', fill: i <= rating ? C.yellow : 'none' }} />
      ))}
    </span>
  )
}

export function ExerciseDetail({ name, onClose, onOpen }: { name: string; onClose: () => void; onOpen?: (name: string) => void }) {
  const data = useData()
  const info = infoLookup(data.exercises)(name)
  const entries = data.entries.filter((e) => e.exerciseName === name)
  const items = toLogItems(entries)
  const progress = dailyProgress(items, name)
  const weighted = items.some((i) => i.addedWeight > 0)
  const total = exerciseTotals(items)[0]
  const lastEntries = entries.slice(-10).reverse()

  return (
    <Sheet title="Упражнение" onClose={onClose} left={<button onClick={onClose}>Закрыть</button>}>
      <h2 className="title2" style={{ margin: '0 4px', fontSize: 24, fontWeight: 800, lineHeight: 1.2 }}>{name}</h2>
      {info && <InfoCard info={info} name={name} onOpen={onOpen} />}
      {entries.length === 0 ? (
        <div className="footnote" style={{ textAlign: 'center', padding: '8px 0' }}>Вы ещё не записывали это упражнение — статистика появится после первой записи.</div>
      ) : (
        <>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <StatTile title="Тренировки" value={String(total?.sessions ?? 0)} color={C.orange} />
            <StatTile title="Повторения" value={num(total?.totalReps ?? 0)} color={C.violet} />
            <StatTile title="Подходы" value={num(total?.totalSets ?? 0)} color={C.blue} />
            <StatTile title="Макс. вес" value={total?.maxWeight ? `+${num(total.maxWeight)}` : '—'} color={C.green} />
          </div>
          <Card title={weighted ? 'Лучший вес за день, кг' : 'Повторений за день'} icon="chart">
            <BarChart data={progress.slice(-16)} color={C.orange} />
          </Card>
          <Card title="Последние записи" icon="clock">
            {lastEntries.map((e) => (
              <div key={e.id} className="row between">
                <span className="footnote">{dayMonthYear(e.date)}</span>
                <span className="subhead num" style={{ fontWeight: 700 }}>{setsLabel(e)}{e.addedWeight > 0 ? ` · +${kg(e.addedWeight)}` : ''}</span>
              </div>
            ))}
          </Card>
        </>
      )}
    </Sheet>
  )
}

function InfoCard({ info, name, onOpen }: { info: ExerciseInfo; name: string; onOpen?: (name: string) => void }) {
  const alternatives = info.primary[0] && info.rating > 0
    ? bestForMuscle(info.primary[0], 4).filter(([n]) => n !== name).slice(0, 3)
    : []
  return (
    <Card title="Справка" icon="info" trailing={info.rating > 0 ? <Stars rating={info.rating} /> : undefined}>
      <div className="stack" style={{ gap: 6 }}>
        <span className="caption">Основная нагрузка</span>
        <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
          {info.primary.map((m) => <Pill key={m} text={muscleTitle[m]} color={C.orange} />)}
        </div>
      </div>
      {info.secondary.length > 0 && (
        <div className="stack" style={{ gap: 6 }}>
          <span className="caption">Помогают</span>
          <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
            {info.secondary.map((m) => <Pill key={m} text={muscleTitle[m]} color="#aeaeb2" />)}
          </div>
        </div>
      )}
      <div className="row caption" style={{ gap: 12, flexWrap: 'wrap' }}>
        <span>{kindTitle[info.kind]}</span>
        {info.level > 0 && <span>{levelTitle(info.level)}</span>}
        {info.equipment && <span>{info.equipment}</span>}
      </div>
      {info.tip && <div className="footnote" style={{ color: 'var(--text)' }}>{info.tip}</div>}
      {info.rating === 0 && <div className="caption">Своё упражнение: мышцы определены по группе, оценки нет.</div>}
      {alternatives.length > 0 && (
        <div className="stack" style={{ gap: 6 }}>
          <span className="caption">Лучшие на «{muscleTitle[info.primary[0]].toLowerCase()}»</span>
          {alternatives.map(([n, i]) => (
            <button key={n} className="row between" style={{ textAlign: 'left', gap: 8 }} onClick={() => onOpen?.(n)} disabled={!onOpen}>
              <span className="subhead">{n}</span>
              <Stars rating={i.rating} size={11} />
            </button>
          ))}
        </div>
      )}
    </Card>
  )
}
