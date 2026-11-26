import { useState } from 'react'
import { Icon } from '../icons'
import {
  FEDERATIONS, LIFTS, RANKS, achievedRank, classFor, attemptPlan, classTitle, classesFor, dayMonthYear, federationSource,
  federationTitle, fraction, kg, liftFullTitle, liftTitle, num, prepPhase, rankTitle, signedKg,
  type Federation, type Lift, type LiftForecast, type WeightClassStandard,
} from '../logic'
import { actions, useData, type Attempt } from '../store'
import {
  attemptPoints, bestLift, estimatePoints, goalTotal, liftForecast, liftTarget, profileStandard, trendSegment,
} from '../derived'
import { LiftChart } from '../charts'
import {
  BigStepper, C, Card, IconBadge, NumberField, Pill, ProgressBar, Ring, Segmented, Sheet, Switch, alpha, fromDateInput,
  liftColor, liftIcon, rankColor, toDateInput,
} from '../ui'

export function MasterScreen() {
  const data = useData()
  const { profile } = data
  const [chartLift, setChartLift] = useState<Lift>('pullUp')
  const [editing, setEditing] = useState<Attempt | 'new' | null>(null)
  const [showStandards, setShowStandards] = useState(false)
  const [showAllAttempts, setShowAllAttempts] = useState(false)

  const best = { pullUp: bestLift(data, 'pullUp'), dip: bestLift(data, 'dip') }
  const total = best.pullUp + best.dip
  const goal = goalTotal(profile)
  const standard = profileStandard(profile)
  const achieved = standard ? achievedRank(standard, total) : null
  const progress = fraction(total, goal)
  const phase = prepPhase(profile.competitionDate)
  const forecasts = { pullUp: liftForecast(data, 'pullUp'), dip: liftForecast(data, 'dip') }

  const chartAttempts = attemptPoints(data, chartLift)
  const chartEstimates = estimatePoints(data, chartLift)

  return (
    <div className="screen stack">
      <div className="screen-header">
        <h1 className="large-title">Мастер спорта</h1>
        <button className="btn-secondary" style={{ color: C.orange }} onClick={() => setEditing('new')}>
          <Icon name="plus" size={16} strokeWidth={2.6} /> Попытка
        </button>
      </div>

      <section className="hero">
        <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
          <Pill text={`Цель: ${rankTitle[profile.goalRank]}`} icon="flag" color={C.orange} />
          {standard && <Pill text={federationTitle[profile.federation]} color="#aeaeb2" />}
          <Pill text={profile.weightClass || 'своя цель'} color="#aeaeb2" />
        </div>
        <div className="row" style={{ gap: 20 }}>
          <Ring progress={progress} size={136} line={16}>
            <div>
              <div className="num" style={{ fontSize: 34, fontWeight: 800, lineHeight: 1 }}>{num(total)}</div>
              <div className="caption">{goal > 0 ? `из ${num(goal)} кг` : 'кг'}</div>
            </div>
          </Ring>
          <div className="stack" style={{ gap: 8, minWidth: 0 }}>
            <div className="subhead secondary">Сумма двоеборья</div>
            <div className="gradient-text num" style={{ fontSize: 40, fontWeight: 900, lineHeight: 1 }}>{Math.floor(progress * 100)}%</div>
            {goal > 0 ? (
              <div className="subhead" style={{ fontWeight: 700, color: total >= goal ? C.green : undefined }}>
                {total >= goal ? 'Норматив выполнен' : `Осталось ${kg(goal - total)}`}
              </div>
            ) : (
              <div className="footnote" style={{ color: C.orange }}>Выберите норматив в профиле</div>
            )}
            {achieved && <span><Pill text={`${rankTitle[achieved]} выполнен`} icon="check" color={rankColor[achieved]} /></span>}
          </div>
        </div>
        <div className="inset stack" style={{ gap: 6 }}>
          <div className="row between">
            <span className="subhead" style={{ fontWeight: 700 }}>{phase.title}</span>
            {phase.countdown && <Pill text={phase.countdown} icon="calendar" color={C.pink} />}
          </div>
          <div className="footnote">{phase.advice}</div>
        </div>
      </section>

      <div className="row" style={{ gap: 12, alignItems: 'stretch' }}>
        {LIFTS.map((lift) => <LiftTile key={lift} lift={lift} current={best[lift]} goal={liftTarget(profile, lift)} bodyweight={profile.bodyweight} />)}
      </div>

      <Card title={`Нормативы по весовым · ${federationTitle[profile.federation]}`} icon="scale">
        {classesFor(profile.federation).map((s) => (
          <WeightClassBlock key={s.limit} standard={s} total={total}
            isCurrent={profile.bodyweight > s.lowerLimit && profile.bodyweight <= s.limit}
            isGoal={profile.weightClassLimit === s.limit} />
        ))}
        <BodyweightHint bodyweight={profile.bodyweight} federation={profile.federation} />
        <button className="link" onClick={() => setShowStandards(true)}>
          Все нормативы: подтягивания, брусья, сумма <Icon name="chevronRight" size={16} />
        </button>
      </Card>

      <Card title="Динамика рекордов" icon="chart">
        <Segmented options={LIFTS.map((l) => ({ value: l, label: liftTitle[l] }))} value={chartLift} onChange={setChartLift} />
        {chartAttempts.length === 0 && chartEstimates.length === 0 ? (
          <div className="footnote" style={{ minHeight: 110, display: 'grid', placeItems: 'center', textAlign: 'center' }}>
            Добавьте попытку на 1 раз (кнопка «Попытка») или запишите в дневник подходы с отягощением — график построится автоматически.
          </div>
        ) : (
          <>
            <LiftChart points={chartAttempts} estimates={chartEstimates} color={liftColor[chartLift]}
              target={liftTarget(profile, chartLift)} competition={profile.competitionDate}
              trend={trendSegment(forecasts[chartLift], [...chartAttempts, ...chartEstimates], profile.competitionDate)} />
            <div className="row caption" style={{ gap: 14, flexWrap: 'wrap' }}>
              <Legend color={liftColor[chartLift]} text="Рекорд" />
              <Legend color={C.orange} text="Расчёт из дневника" />
              <Legend color="#8e8e93" text="Тренд" />
            </div>
          </>
        )}
      </Card>

      <Card title="Прогноз" icon="target">
        {LIFTS.map((lift, i) => (
          <div key={lift} className="stack" style={{ gap: 0 }}>
            {i > 0 && <div style={{ height: 1, background: 'var(--separator)', marginBottom: 14 }} />}
            <ForecastRow lift={lift} forecast={forecasts[lift]} />
          </div>
        ))}
        <div className="caption">Тренд — линейная регрессия по лучшим результатам дня (попытки и расчётные максимумы из дневника). Цели по движениям — раскладка норматива суммы.</div>
      </Card>

      <Card title="Подходы на помосте" icon="list">
        {LIFTS.map((lift) => {
          const plan = attemptPlan(best[lift])
          return (
            <div key={lift} className="stack" style={{ gap: 8 }}>
              <div className="subhead" style={{ fontWeight: 700, color: liftColor[lift] }}>{liftTitle[lift]}</div>
              {plan.length === 0 ? (
                <div className="footnote">Нет рекорда — добавьте попытку</div>
              ) : (
                <div className="row" style={{ gap: 8 }}>
                  {plan.map((w, idx) => (
                    <div key={idx} style={{ flex: 1, textAlign: 'center', padding: '10px 0', borderRadius: 14, background: alpha(liftColor[lift], idx === 2 ? 0.25 : 0.1) }}>
                      <div className="caption">{idx + 1}-й</div>
                      <div className="headline num">{num(w)}</div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )
        })}
        <div className="caption">1-й ≈92% от рекорда (уверенный зачёт), 2-й ≈97%, 3-й ≈101% — на рекорд. Шаг 1,25 кг.</div>
      </Card>

      <Card title="Последние попытки" icon="clock">
        {data.attempts.length === 0 ? (
          <div className="secondary">Пока пусто</div>
        ) : (
          <>
            {data.attempts.slice(-5).reverse().map((a) => <AttemptRow key={a.id} attempt={a} onClick={() => setEditing(a)} />)}
            <button className="link" onClick={() => setShowAllAttempts(true)}>
              Все попытки ({data.attempts.length}) <Icon name="chevronRight" size={16} />
            </button>
          </>
        )}
      </Card>

      <InfoCard />

      {editing && <AttemptEditor attempt={editing === 'new' ? null : editing} onClose={() => setEditing(null)} />}
      {showStandards && <StandardsSheet initial={profile.federation} total={total} pullUp={best.pullUp} dip={best.dip} onClose={() => setShowStandards(false)} />}
      {showAllAttempts && (
        <Sheet title="Все попытки" onClose={() => setShowAllAttempts(false)} left={<button onClick={() => setShowAllAttempts(false)}>Закрыть</button>}>
          <div className="card" style={{ gap: 4 }}>
            {[...data.attempts].reverse().map((a) => <AttemptRow key={a.id} attempt={a} onClick={() => setEditing(a)} />)}
          </div>
        </Sheet>
      )}
    </div>
  )
}

function Legend({ color, text }: { color: string; text: string }) {
  return <span className="row" style={{ gap: 4 }}><span style={{ width: 7, height: 7, borderRadius: '50%', background: color }} />{text}</span>
}

function LiftTile({ lift, current, goal, bodyweight }: { lift: Lift; current: number; goal: number; bodyweight: number }) {
  const color = liftColor[lift]
  return (
    <div className="card" style={{ flex: 1, gap: 10, padding: 14, borderRadius: 22, minWidth: 0 }}>
      <div className="row between">
        <IconBadge icon={liftIcon[lift]} color={color} size={36} />
        <Ring progress={fraction(current, goal)} size={30} line={5} />
      </div>
      <div className="caption">{liftTitle[lift]}</div>
      <div className="num" style={{ whiteSpace: 'nowrap' }}>
        <span style={{ fontSize: 28, fontWeight: 800 }}>+{num(current)}</span>
        <span className="secondary subhead"> кг</span>
      </div>
      <div className="caption" style={{ fontSize: 11 }}>
        <div>{goal > 0 ? `цель ${kg(goal)}` : 'цель не задана'}</div>
        {bodyweight > 0 && current > 0 && <div>{num(Math.round((current / bodyweight) * 100) / 100)}× веса тела</div>}
      </div>
    </div>
  )
}

function WeightClassBlock({ standard, total, isCurrent, isGoal }: { standard: WeightClassStandard; total: number; isCurrent: boolean; isGoal: boolean }) {
  return (
    <div className="stack" style={{
      gap: 10, padding: 14, borderRadius: 18,
      background: isGoal ? alpha(C.orange, 0.08) : 'rgba(255,255,255,0.03)',
      border: `1px solid ${isGoal ? alpha(C.orange, 0.4) : 'transparent'}`,
    }}>
      <div className="row" style={{ gap: 6 }}>
        <span className="headline">{classTitle(standard)}</span>
        {isCurrent && <Pill text="ваш вес" icon="user" color={C.green} />}
        {isGoal && <Pill text="цель" icon="flag" color={C.orange} />}
      </div>
      {RANKS.map((rank) => {
        const norm = standard.norms[rank].total
        const done = total >= norm
        return (
          <div key={rank} className="row" style={{ gap: 10 }}>
            <span className="caption" style={{ width: 44, fontWeight: 800, color: rankColor[rank] }}>{rankTitle[rank]}</span>
            <div style={{ flex: 1 }}><ProgressBar value={fraction(total, norm)} color={done ? C.green : rankColor[rank]} height={6} /></div>
            <span className="subhead num" style={{ width: 48, textAlign: 'right', fontWeight: 700 }}>{num(norm)}</span>
            <span className="caption num" style={{ width: 48, textAlign: 'right', fontWeight: 700 }}>
              {done ? <Icon name="check" size={16} style={{ color: C.green }} strokeWidth={3} /> : `−${num(norm - total)}`}
            </span>
          </div>
        )
      })}
    </div>
  )
}

function BodyweightHint({ bodyweight, federation }: { bodyweight: number; federation: Federation }) {
  const classes = classesFor(federation)
  if (bodyweight <= 0 || classes.length === 0) return null
  const lightest = classes[0]
  const heaviest = classes[classes.length - 1]
  let text: string
  if (bodyweight > heaviest.limit) {
    text = `Ваш вес ${kg(bodyweight)} — выше ${kg(heaviest.limit)}. Для тяжёлых категорий задайте свою цель в профиле.`
  } else {
    const current = classFor(bodyweight, federation) ?? lightest
    if (current.limit > lightest.limit) {
      text = `До категории ${classTitle(lightest)} нужно снизить вес на ${kg(Math.round((bodyweight - lightest.limit) * 10) / 10)} — норматив МС там на ${kg(current.norms.ms.total - lightest.norms.ms.total)} ниже.`
    } else {
      text = `При весе ${kg(bodyweight)} вы выступаете в категории ${classTitle(current)}.`
    }
  }
  return (
    <div className="row footnote" style={{ alignItems: 'flex-start', gap: 8 }}>
      <Icon name="sparkles" size={16} style={{ color: C.yellow, flex: 'none', marginTop: 1 }} />
      <span>{text}</span>
    </div>
  )
}

const statusText = (f: LiftForecast) => ({
  reached: 'Выполнено', onTrack: 'Успеваете', behind: f.target > 0 ? 'Отстаёте' : 'Нет цели', projected: 'По тренду', notEnoughData: 'Мало данных',
})[f.status]

const statusColor = (f: LiftForecast) => ({
  reached: C.green, onTrack: C.green, behind: C.orange, projected: C.blue, notEnoughData: '#8e8e93',
})[f.status]

function ForecastRow({ lift, forecast }: { lift: Lift; forecast: LiftForecast }) {
  return (
    <div className="stack" style={{ gap: 6 }}>
      <div className="row between">
        <span className="row subhead" style={{ fontWeight: 700, color: liftColor[lift], gap: 6 }}><Icon name={liftIcon[lift]} size={18} />{liftTitle[lift]}</span>
        <Pill text={statusText(forecast)} color={statusColor(forecast)} />
      </div>
      {forecast.trend && <div className="subhead">Темп: {signedKg(Math.round(forecast.trend.slopePerDay * 7 * 100) / 100)} в неделю</div>}
      {forecast.reachDate !== null && forecast.status !== 'reached' && <div className="subhead">Цель по тренду: ~{dayMonthYear(forecast.reachDate)}</div>}
      {forecast.neededPerWeek !== null && <div className="footnote">Нужно прибавлять {kg(Math.round(forecast.neededPerWeek * 100) / 100)} в неделю до старта</div>}
    </div>
  )
}

function AttemptRow({ attempt, onClick }: { attempt: Attempt; onClick: () => void }) {
  const color = liftColor[attempt.lift]
  return (
    <button className="row" style={{ width: '100%', textAlign: 'left', padding: '6px 0', gap: 12 }} onClick={onClick}>
      <IconBadge icon={attempt.isCompetition ? 'trophy' : liftIcon[attempt.lift]} color={attempt.isCompetition ? C.yellow : color} size={38} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div className="subhead" style={{ fontWeight: 700 }}>{liftTitle[attempt.lift]}</div>
        <div className="caption">{dayMonthYear(attempt.date)}{attempt.isCompetition ? ' · соревнования' : ''}{attempt.note ? ` · ${attempt.note}` : ''}</div>
      </div>
      <span className="headline num" style={{ color }}>+{kg(attempt.addedWeight)}</span>
    </button>
  )
}

function AttemptEditor({ attempt, onClose }: { attempt: Attempt | null; onClose: () => void }) {
  const data = useData()
  const [lift, setLift] = useState<Lift>(attempt?.lift ?? 'pullUp')
  const [weight, setWeight] = useState(attempt?.addedWeight ?? bestLift(data, attempt?.lift ?? 'pullUp'))
  const [bodyweight, setBodyweight] = useState(attempt?.bodyweight ?? data.profile.bodyweight)
  const [date, setDate] = useState(attempt?.date ?? Date.now())
  const [isCompetition, setIsCompetition] = useState(attempt?.isCompetition ?? false)
  const [note, setNote] = useState(attempt?.note ?? '')
  const record = bestLift(data, lift)

  const save = () => {
    const payload = { lift, addedWeight: weight, bodyweight, date, isCompetition, note: note.trim() }
    if (attempt) actions.updateAttempt(attempt.id, payload)
    else actions.addAttempt(payload)
    onClose()
  }

  return (
    <Sheet title={attempt ? 'Попытка' : 'Новая попытка'} onClose={onClose}
      right={attempt ? <button style={{ color: C.pink }} aria-label="Удалить" onClick={() => { if (confirm('Удалить попытку?')) { actions.deleteAttempt(attempt.id); onClose() } }}><Icon name="trash" size={20} /></button> : undefined}
      footer={<button className="btn-primary" onClick={save}><Icon name="check" strokeWidth={2.6} /> Сохранить</button>}>
      <Segmented options={LIFTS.map((l) => ({ value: l, label: liftTitle[l] }))} value={lift} onChange={(l) => { setLift(l); if (!attempt) setWeight(bestLift(data, l)) }} />
      <div className="footnote" style={{ textAlign: 'center' }}>{liftFullTitle[lift]} на 1 раз</div>
      <BigStepper title="Отягощение" value={weight} onChange={setWeight} step={1.25} max={300} unit="кг" quickSteps={[-2.5, 1.25, 2.5, 5]} />
      {!attempt && record > 0 && (
        <div className="footnote" style={{ textAlign: 'center', color: weight > record ? C.green : undefined }}>
          {weight > record ? `Новый рекорд! +${kg(weight - record)} к прошлому` : `Текущий рекорд: +${kg(record)}`}
        </div>
      )}
      <div className="field-group">
        <NumberField label="Вес тела" value={bodyweight} onChange={setBodyweight} />
        <div className="field">
          <label>Дата</label>
          <input type="date" value={toDateInput(date)} onChange={(e) => e.target.value && setDate(fromDateInput(e.target.value, date))} />
        </div>
        <div className="field">
          <label>На соревнованиях</label>
          <Switch on={isCompetition} onChange={setIsCompetition} />
        </div>
      </div>
      <textarea className="text-input" rows={2} placeholder="Заметка" value={note} onChange={(e) => setNote(e.target.value)} />
    </Sheet>
  )
}

function StandardsSheet({ initial, total, pullUp, dip, onClose }: { initial: Federation; total: number; pullUp: number; dip: number; onClose: () => void }) {
  const [federation, setFederation] = useState(initial)
  const cell = (norm: number, current: number) => (
    <td style={{ color: current >= norm ? C.green : undefined, fontWeight: current >= norm ? 800 : 500 }}>{num(norm)}</td>
  )
  return (
    <Sheet title="Нормативы" onClose={onClose} left={<button onClick={onClose}>Закрыть</button>}>
      <Segmented options={FEDERATIONS.map((f) => ({ value: f, label: federationTitle[f] }))} value={federation} onChange={setFederation} />
      <div className="footnote">Мужчины, классический стритлифтинг, отягощение в кг. Зелёным — то, что вы уже выполняете: подтягивания +{num(pullUp)}, брусья +{num(dip)}, сумма {num(total)}.</div>
      {classesFor(federation).map((s) => (
        <Card key={s.limit} title={classTitle(s)} icon="scale">
          <table className="norm-table">
            <thead><tr><th>Разряд</th><th>Подтяг.</th><th>Брусья</th><th>Сумма</th></tr></thead>
            <tbody>
              {RANKS.map((rank, i) => (
                <tr key={rank} className={i ? 'sep' : ''}>
                  <td style={{ color: rankColor[rank], fontWeight: 800 }}>{rankTitle[rank]}</td>
                  {cell(s.norms[rank].pullUp, pullUp)}
                  {cell(s.norms[rank].dip, dip)}
                  {cell(s.norms[rank].total, total)}
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      ))}
      <div className="caption">Источник: {federationSource[federation]}. Звание в двоеборье присваивается по сумме; нормативы в отдельных движениях — для отдельных дисциплин. Проверяйте актуальные таблицы перед стартом.</div>
    </Sheet>
  )
}

function InfoCard() {
  const items: [string, string][] = [
    ['Дисциплина', 'Двоеборье: подтягивания на перекладине и отжимания на брусьях с отягощением на один раз. Результат — вес отягощения, в зачёт идёт лучший успешный подход в каждом движении и их сумма. Обычно по три подхода в движении.'],
    ['Звания', 'Стритлифтинг не входит в ЕВСК: КМС, МС и МСМК присваивают федерации (ISF-Россия, WSF) по своим таблицам. Звание в двоеборье даётся по сумме; нормативы в подтягиваниях и брусьях — для отдельных дисциплин.'],
    ['Подтягивания — частые ошибки', 'Старт из виса на прямых руках, подбородок выше перекладины, без раскачки и рывков ногами, опускание до полного выпрямления рук по команде судьи.'],
    ['Брусья — частые ошибки', 'Старт с выпрямленных рук, опускание до положения, когда плечевой сустав ниже локтя, полное выпрямление рук наверху, без рывков ногами, фиксация по команде.'],
  ]
  return (
    <Card title="Стритлифтинг: коротко" icon="info">
      {items.map(([title, text]) => (
        <details key={title}>
          <summary>{title}</summary>
          <p className="footnote">{text}</p>
        </details>
      ))}
    </Card>
  )
}
