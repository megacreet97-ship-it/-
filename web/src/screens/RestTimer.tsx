import { useEffect, useState } from 'react'
import { Icon } from '../icons'
import { REST_PRESETS, formatRest, restTimer, useRestTimer } from '../restTimer'
import { C, Sheet, Switch } from '../ui'

function useNow(active: boolean) {
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    if (!active) return
    const id = setInterval(() => setNow(Date.now()), 250)
    return () => clearInterval(id)
  }, [active])
  return now
}

/** Floating countdown shown on every tab while resting; sits higher on the diary to clear its button. */
export function RestTimerBar({ raised }: { raised: boolean }) {
  const timer = useRestTimer()
  const [settings, setSettings] = useState(false)
  const now = useNow(timer.endsAt !== null)

  return (
    <>
      {timer.endsAt !== null && (() => {
        const left = (timer.endsAt - now) / 1000
        const progress = Math.min(1, Math.max(0, 1 - left / timer.duration))
        return (
          <div className={`rest-bar ${raised ? 'raised' : ''}`} role="timer" aria-label={`Отдых ${formatRest(left)}`}>
            <div className="rest-fill" style={{ width: `${progress * 100}%` }} />
            <button className="rest-time" onClick={() => setSettings(true)}>
              <Icon name="clock" size={18} />
              <span className="caption" style={{ color: 'rgba(255,255,255,.8)' }}>Отдых</span>
              <span className="num">{formatRest(left)}</span>
            </button>
            <button className="rest-btn" onClick={() => restTimer.add(-15)} aria-label="Убавить 15 секунд">−15</button>
            <button className="rest-btn" onClick={() => restTimer.add(15)} aria-label="Добавить 15 секунд">+15</button>
            <button className="rest-btn" onClick={() => restTimer.stop()} aria-label="Остановить таймер"><Icon name="close" size={16} strokeWidth={2.6} /></button>
          </div>
        )
      })()}
      {timer.endsAt === null && timer.finishedAt !== null && (
        <div className={`rest-bar done ${raised ? 'raised' : ''}`} role="status">
          <button className="rest-time" onClick={() => restTimer.stop()}>
            <Icon name="bolt" size={18} />
            <span>Отдых окончен — следующий подход!</span>
          </button>
          <button className="rest-btn" onClick={() => restTimer.start(timer.duration)}>Ещё {formatRest(timer.duration)}</button>
        </div>
      )}
      {settings && <RestTimerSheet onClose={() => setSettings(false)} />}
    </>
  )
}

export function RestTimerButton() {
  const [open, setOpen] = useState(false)
  const timer = useRestTimer()
  return (
    <>
      <button className="btn-secondary" style={{ color: timer.endsAt ? C.green : C.orange }} onClick={() => setOpen(true)} aria-label="Таймер отдыха">
        <Icon name="clock" size={16} strokeWidth={2.4} /> Таймер
      </button>
      {open && <RestTimerSheet onClose={() => setOpen(false)} />}
    </>
  )
}

function RestTimerSheet({ onClose }: { onClose: () => void }) {
  const timer = useRestTimer()
  return (
    <Sheet title="Таймер отдыха" onClose={onClose} left={<button onClick={onClose}>Закрыть</button>}>
      <div className="footnote">Нажмите время, чтобы начать отдых. Выбранное время запомнится и будет запускаться после каждого подхода.</div>
      <div className="rest-presets">
        {REST_PRESETS.map((s) => (
          <button key={s} className={`rest-preset ${timer.defaultSeconds === s ? 'active' : ''}`}
            onClick={() => { restTimer.setDefault(s); restTimer.start(s); onClose() }}>
            <span className="num">{formatRest(s)}</span>
            <span className="caption">{s <= 90 ? 'объём, пампинг' : s <= 180 ? 'рабочие подходы' : 'тяжёлые, одиночки'}</span>
          </button>
        ))}
      </div>
      <div className="field-group" style={{ display: 'flex', flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', padding: '14px 16px', gap: 12 }}>
        <span>
          <span style={{ display: 'block', fontWeight: 600 }}>Запускать после подхода</span>
          <span className="caption">После «+ подход» и сохранения записи</span>
        </span>
        <Switch on={timer.autoStart} onChange={restTimer.setAutoStart} />
      </div>
      <div className="caption">Для силы и стритлифтинга отдыхают 3–5 минут, для мышечной массы 1,5–2 минуты, для выносливости около минуты. По окончании прозвучит сигнал — держите приложение открытым и звук включённым.</div>
      {timer.endsAt !== null && (
        <button className="btn-secondary" style={{ color: C.pink, justifyContent: 'center' }} onClick={() => { restTimer.stop(); onClose() }}>
          Остановить таймер
        </button>
      )}
    </Sheet>
  )
}
