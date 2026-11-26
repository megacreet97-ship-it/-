import { useMemo, useState } from 'react'
import { Icon } from '../icons'
import { addDays, num, startOfDay } from '../logic'
import {
  ALL_MUSCLES, KEY_MUSCLES, MUSCLE_GROUPS, bestForMuscle, entriesInLastDays, exerciseProgress, muscleSets, muscleTitle,
  personalRecords, volumeZone, zoneTitle, type Muscle, type VolumeZone,
} from '../muscles'
import { compareCategories } from '../exerciseLibrary'
import { useData } from '../store'
import { infoLookup } from '../derived'
import { C, Card, ProgressBar, Segmented, StatTile, alpha } from '../ui'
import { ExerciseDetail, Stars, photoUrl } from './ExerciseDetail'

type Section = 'muscles' | 'library' | 'progress'

const zoneColor: Record<VolumeZone, string> = { none: '#636366', low: C.pink, maintain: C.yellow, grow: C.green, high: C.violet }

export function ExercisesScreen() {
  const [section, setSection] = useState<Section>('muscles')
  const [muscle, setMuscle] = useState<Muscle | null>(null)
  const [detail, setDetail] = useState<string | null>(null)

  const openMuscle = (m: Muscle) => {
    setMuscle(m)
    setSection('library')
    window.scrollTo(0, 0)
  }

  return (
    <div className="screen stack">
      <div className="screen-header"><h1 className="large-title">Упражнения</h1></div>
      <Segmented<Section> options={[{ value: 'muscles', label: 'Мышцы' }, { value: 'library', label: 'Справочник' }, { value: 'progress', label: 'Прогресс' }]}
        value={section} onChange={setSection} />
      {section === 'muscles' && <MusclesSection onMuscle={openMuscle} onExercise={setDetail} />}
      {section === 'library' && <LibrarySection muscle={muscle} onMuscle={setMuscle} onExercise={setDetail} />}
      {section === 'progress' && <ProgressSection onExercise={setDetail} />}
      {detail && <ExerciseDetail key={detail} name={detail} onClose={() => setDetail(null)} onOpen={setDetail} />}
    </div>
  )
}

function MusclesSection({ onMuscle, onExercise }: { onMuscle: (m: Muscle) => void; onExercise: (name: string) => void }) {
  const data = useData()
  const [days, setDays] = useState<7 | 28>(7)
  const lookup = useMemo(() => infoLookup(data.exercises), [data.exercises])
  const sets = useMemo(() => {
    const raw = muscleSets(entriesInLastDays(data.entries, days), lookup)
    const weeks = days / 7
    return Object.fromEntries(ALL_MUSCLES.map((m) => [m, raw[m] / weeks])) as Record<Muscle, number>
  }, [data.entries, days, lookup])
  const weak = KEY_MUSCLES.filter((m) => sets[m] < 4)

  return (
    <>
      <Segmented<7 | 28> options={[{ value: 7, label: 'Эта неделя' }, { value: 28, label: 'В среднем за 4 нед' }]} value={days} onChange={setDays} />
      <div className="footnote" style={{ padding: '0 4px' }}>
        Рабочие подходы в неделю на каждую мышцу: если мышца главная в упражнении — подход целиком, если помогает — половина. Для роста обычно нужно 10–20 подходов.
      </div>
      <div className="row caption" style={{ gap: 12, flexWrap: 'wrap', padding: '0 4px' }}>
        {(['low', 'maintain', 'grow', 'high'] as VolumeZone[]).map((z) => (
          <span key={z} className="row" style={{ gap: 4 }}>
            <span style={{ width: 8, height: 8, borderRadius: '50%', background: zoneColor[z] }} />
            {zoneTitle[z]} {z === 'low' ? '<4' : z === 'maintain' ? '4–9' : z === 'grow' ? '10–20' : '>20'}
          </span>
        ))}
      </div>

      {MUSCLE_GROUPS.map((group) => (
        <Card key={group.title} title={group.title}>
          {group.muscles.map((m) => {
            const zone = volumeZone(sets[m])
            return (
              <button key={m} className="stack" style={{ gap: 6, textAlign: 'left', width: '100%' }} onClick={() => onMuscle(m)}>
                <div className="row between">
                  <span className="subhead" style={{ fontWeight: 600 }}>{muscleTitle[m]}</span>
                  <span className="row" style={{ gap: 8 }}>
                    <span className="caption" style={{ color: zoneColor[zone], fontWeight: 700 }}>{zoneTitle[zone]}</span>
                    <span className="subhead num" style={{ fontWeight: 800, minWidth: 28, textAlign: 'right' }}>{num(Math.round(sets[m] * 10) / 10)}</span>
                    <Icon name="chevronRight" size={14} className="tertiary" />
                  </span>
                </div>
                <ProgressBar value={sets[m] / 24} color={zoneColor[zone]} height={6} marker={10 / 24} />
              </button>
            )
          })}
        </Card>
      ))}

      {sets.cardio > 0 && <div className="footnote" style={{ padding: '0 4px' }}>Кардио: {num(Math.round(sets.cardio * 10) / 10)} занятий в неделю.</div>}

      {weak.length > 0 && (
        <Card title="Что добавить" icon="sparkles">
          <div className="footnote">Этим мышцам не хватает нагрузки. Лучшие упражнения для них:</div>
          {weak.map((m) => (
            <div key={m} className="stack" style={{ gap: 6 }}>
              <span className="subhead" style={{ fontWeight: 700 }}>{muscleTitle[m]}</span>
              {bestForMuscle(m, 2).map(([name, info]) => (
                <button key={name} className="row between" style={{ textAlign: 'left', gap: 8 }} onClick={() => onExercise(name)}>
                  <span className="footnote" style={{ color: 'var(--text)' }}>{name}</span>
                  <Stars rating={info.rating} size={11} />
                </button>
              ))}
            </div>
          ))}
        </Card>
      )}
    </>
  )
}

function LibrarySection({ muscle, onMuscle, onExercise }: { muscle: Muscle | null; onMuscle: (m: Muscle | null) => void; onExercise: (name: string) => void }) {
  const data = useData()
  const [query, setQuery] = useState('')
  const lookup = useMemo(() => infoLookup(data.exercises), [data.exercises])
  const done = useMemo(() => {
    const count = new Map<string, number>()
    for (const e of data.entries) count.set(e.exerciseName, (count.get(e.exerciseName) ?? 0) + 1)
    return count
  }, [data.entries])

  const q = query.trim().toLowerCase()
  const rows = data.exercises
    .map((e) => ({ exercise: e, info: lookup(e.name) }))
    .filter(({ exercise, info }) => (!q || exercise.name.toLowerCase().includes(q)) && (!muscle || info?.primary.includes(muscle)))

  const row = ({ exercise, info }: (typeof rows)[number]) => (
    <button key={exercise.id} className="list-row" style={{ alignItems: 'center', gap: 12, paddingTop: 10, paddingBottom: 10 }} onClick={() => onExercise(exercise.name)}>
      {info?.photo ? <img className="ex-thumb" src={photoUrl(info.photo, 1)} alt="" loading="lazy" /> : <span className="ex-thumb" style={{ background: 'var(--elevated)' }} />}
      <div className="stack" style={{ gap: 3, flex: 1, minWidth: 0 }}>
        <span>{exercise.name}</span>
        <span className="caption">{info ? info.primary.map((m) => muscleTitle[m]).join(', ') : 'нет данных'}{done.get(exercise.name) ? ` · делали ${done.get(exercise.name)} раз` : ''}</span>
      </div>
      {info && info.rating > 0 && <Stars rating={info.rating} size={11} />}
    </button>
  )

  return (
    <>
      <div className="text-input row" style={{ padding: '10px 14px' }}>
        <Icon name="search" size={18} className="secondary" />
        <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Поиск упражнения" style={{ background: 'transparent', border: 0, outline: 'none', flex: 1, fontSize: 16 }} />
        {query && <button onClick={() => setQuery('')} aria-label="Очистить"><Icon name="close" size={16} className="secondary" /></button>}
      </div>
      <div className="h-scroll chips">
        <button className={`chip ${muscle === null ? 'active' : ''}`} onClick={() => onMuscle(null)}>Все мышцы</button>
        {ALL_MUSCLES.map((m) => (
          <button key={m} className={`chip ${muscle === m ? 'active' : ''}`} onClick={() => onMuscle(m)}>{muscleTitle[m]}</button>
        ))}
      </div>
      {muscle ? (
        <>
          <div className="section-title">Лучшие на «{muscleTitle[muscle].toLowerCase()}»<small>{rows.length}</small></div>
          <div className="field-group">
            {[...rows].sort((a, b) => (b.info?.rating ?? 0) - (a.info?.rating ?? 0) || (a.info?.primary.length ?? 0) - (b.info?.primary.length ?? 0) || (a.info?.level ?? 0) - (b.info?.level ?? 0)).map(row)}
          </div>
          <div className="caption" style={{ padding: '0 4px' }}>
            Звёзды — экспертная оценка того, насколько хорошо упражнение нагружает мышцу: большая амплитуда, нагрузка в растянутом положении, возможность прибавлять вес. Лучшее упражнение — то, которое вы делаете регулярно и с прогрессом.
          </div>
        </>
      ) : (
        [...new Set(rows.map((r) => r.exercise.category))].sort(compareCategories).map((category) => (
          <div key={category} className="stack" style={{ gap: 8 }}>
            <div className="group-label" style={{ margin: '4px 16px 0' }}>{category}</div>
            <div className="field-group">{rows.filter((r) => r.exercise.category === category).map(row)}</div>
          </div>
        ))
      )}
      {rows.length === 0 && <div className="secondary" style={{ textAlign: 'center' }}>Ничего не найдено</div>}
    </>
  )
}

function ProgressSection({ onExercise }: { onExercise: (name: string) => void }) {
  const data = useData()
  const progress = useMemo(() => exerciseProgress(data.entries), [data.entries])
  const today = startOfDay(Date.now())
  const records30 = personalRecords(data.entries, addDays(today, -29))
  const growing = progress.filter((p) => p.change > 0.005)
  const falling = progress.filter((p) => p.change < -0.005)
  const value = (v: number, weighted: boolean) => (weighted ? `${num(Math.round(v * 10) / 10)} кг` : `${num(Math.round(v))} раз`)

  return (
    <>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <StatTile title="Рекорды" value={String(records30)} caption="за 30 дней" icon="trophy" color={C.yellow} />
        <StatTile title="Растут" value={`${growing.length} из ${progress.length}`} caption="упражнений" icon="trendUp" color={C.green} />
      </div>
      <div className="footnote" style={{ padding: '0 4px' }}>
        Лучший результат последних 4 недель против 4 недель до них. С отягощением — расчётный максимум на 1 раз, без веса — повторения в лучшем подходе.
      </div>
      {progress.length === 0 ? (
        <Card><div className="footnote" style={{ textAlign: 'center' }}>Нужны записи хотя бы за 5 недель по одним и тем же упражнениям — тогда здесь появится сравнение.</div></Card>
      ) : (
        <Card title="По упражнениям" icon="chart">
          {progress.map((p) => {
            const color = p.change > 0.005 ? C.green : p.change < -0.005 ? C.pink : '#8e8e93'
            return (
              <button key={p.name} className="row" style={{ gap: 10, textAlign: 'left', width: '100%' }} onClick={() => onExercise(p.name)}>
                <div className="stack" style={{ flex: 1, minWidth: 0, gap: 2 }}>
                  <span className="subhead" style={{ fontWeight: 600 }}>{p.name}</span>
                  <span className="caption num">{value(p.before, p.weighted)} → {value(p.now, p.weighted)}</span>
                </div>
                <span className="pill num" style={{ background: alpha(color, 0.18), color }}>{p.change > 0 ? '+' : ''}{num(Math.round(p.change * 1000) / 10)}%</span>
              </button>
            )
          })}
        </Card>
      )}
      {falling.length > 0 && (
        <div className="caption" style={{ padding: '0 4px' }}>
          Если результат падает 2–3 недели подряд — проверьте сон и питание или сделайте разгрузочную неделю с весами на 30–40% легче.
        </div>
      )}
    </>
  )
}
