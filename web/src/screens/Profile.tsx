import { useRef, useState } from 'react'
import { Icon } from '../icons'
import {
  FEDERATIONS, RANKS, classFor, classTitle, classesFor, federationTitle, kg, num, rankTitle, type Federation, type SportRank,
} from '../logic'
import { actions, exportCSV, parseBackup, useData } from '../store'
import { C, IconBadge, NumberField, Segmented, Sheet, alpha, fromDateInput, liftColor, liftIcon, toDateInput, useToast } from '../ui'
import { ExerciseForm } from './QuickLog'
import { compareCategories } from '../exerciseLibrary'

async function shareFile(name: string, text: string, mime: string) {
  const file = new File([text], name, { type: mime })
  if (navigator.canShare?.({ files: [file] })) {
    try {
      await navigator.share({ files: [file], title: name })
      return
    } catch (e) {
      if ((e as DOMException).name === 'AbortError') return
    }
  }
  const url = URL.createObjectURL(file)
  const a = document.createElement('a')
  a.href = url
  a.download = name
  a.click()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

const isStandalone = () =>
  window.matchMedia('(display-mode: standalone)').matches || (navigator as Navigator & { standalone?: boolean }).standalone === true

export function ProfileScreen() {
  const data = useData()
  const { profile } = data
  const [showExercises, setShowExercises] = useState(false)
  const [showInstall, setShowInstall] = useState(false)
  const [toast, showToast] = useToast()
  const fileInput = useRef<HTMLInputElement>(null)
  const suggested = classFor(profile.bodyweight, profile.federation)
  const custom = profile.weightClassLimit === 0
  const stamp = new Date().toISOString().slice(0, 10)

  const importBackup = async (file: File) => {
    const parsed = parseBackup(await file.text())
    if (!parsed) {
      alert('Файл не похож на резервную копию StreetLog')
      return
    }
    if (confirm(`Заменить текущие данные? В копии: ${parsed.entries.length} записей, ${parsed.attempts.length} попыток.`)) {
      actions.replaceAll(parsed)
      showToast('Данные восстановлены')
    }
  }

  return (
    <div className="screen stack">
      <div className="screen-header"><h1 className="large-title">Профиль</h1></div>

      <section className="hero" style={{ flexDirection: 'row', alignItems: 'center', gap: 16 }}>
        <div style={{ width: 64, height: 64, borderRadius: '50%', background: 'var(--gradient)', display: 'grid', placeItems: 'center', fontSize: 26, fontWeight: 800, flex: 'none' }}>
          {profile.name.trim() ? profile.name.trim()[0].toUpperCase() : <Icon name="user" size={30} />}
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <input value={profile.name} placeholder="Ваше имя" onChange={(e) => actions.updateProfile({ name: e.target.value })}
            style={{ background: 'transparent', border: 0, outline: 'none', fontSize: 22, fontWeight: 800, width: '100%' }} />
          <div className="footnote">{profile.weightClass || 'своя цель'} · цель {rankTitle[profile.goalRank]} · {federationTitle[profile.federation]}</div>
        </div>
      </section>

      {!isStandalone() && (
        <button className="card" style={{ flexDirection: 'row', alignItems: 'center', textAlign: 'left', background: alpha(C.orange, 0.12), borderColor: alpha(C.orange, 0.3) }} onClick={() => setShowInstall(true)}>
          <IconBadge icon="download" color={C.orange} size={40} />
          <div style={{ flex: 1 }}>
            <div className="headline">Установить на iPhone</div>
            <div className="footnote">Иконка на экране «Домой», работает без интернета</div>
          </div>
          <Icon name="chevronRight" size={16} style={{ color: C.orange }} />
        </button>
      )}

      <div className="group-label">Тело</div>
      <div className="field-group">
        <NumberField label="Вес тела" value={profile.bodyweight} onChange={(v) => actions.updateProfile({ bodyweight: v })} />
      </div>
      {suggested && suggested.limit !== profile.weightClassLimit && (
        <button className="group-footer" style={{ color: C.orange, textAlign: 'left' }} onClick={() => actions.updateProfile({ weightClassLimit: suggested.limit }, true)}>
          С весом {kg(profile.bodyweight)} вы в категории {classTitle(suggested)} — выбрать её целью
        </button>
      )}

      <div className="group-label">Цель</div>
      <div className="card" style={{ gap: 12 }}>
        <div className="caption">Федерация</div>
        <Segmented<Federation> options={FEDERATIONS.map((f) => ({ value: f, label: federationTitle[f] }))} value={profile.federation}
          onChange={(f) => actions.updateProfile({ federation: f }, true)} />
        <div className="caption">Весовая категория</div>
        <Segmented<number> options={[...classesFor(profile.federation).map((s) => ({ value: s.limit, label: classTitle(s) })), { value: 0, label: 'Своя' }]}
          value={profile.weightClassLimit} onChange={(limit) => actions.updateProfile({ weightClassLimit: limit, ...(limit === 0 ? { weightClass: '' } : {}) }, true)} />
        {!custom && (
          <>
            <div className="caption">Разряд</div>
            <Segmented<SportRank> options={RANKS.map((r) => ({ value: r, label: rankTitle[r] }))} value={profile.goalRank}
              onChange={(r) => actions.updateProfile({ goalRank: r }, true)} />
          </>
        )}
      </div>

      <div className="group-label">Целевые веса</div>
      <div className="field-group">
        {custom ? (
          <>
            <NumberField label="Подтягивания" value={profile.targetPullUp} onChange={(v) => actions.updateProfile({ targetPullUp: v, targetTotal: v + profile.targetDip })} />
            <NumberField label="Брусья" value={profile.targetDip} onChange={(v) => actions.updateProfile({ targetDip: v, targetTotal: profile.targetPullUp + v })} />
          </>
        ) : (
          <>
            {(['pullUp', 'dip'] as const).map((lift) => (
              <div key={lift} className="field">
                <IconBadge icon={liftIcon[lift]} color={liftColor[lift]} size={30} />
                <label>{lift === 'pullUp' ? 'Подтягивания' : 'Брусья'}</label>
                <span className="num" style={{ fontWeight: 700 }}>+{kg(lift === 'pullUp' ? profile.targetPullUp : profile.targetDip)}</span>
              </div>
            ))}
          </>
        )}
        <div className="field">
          <IconBadge icon="trophy" color={C.orange} size={30} />
          <label>Сумма</label>
          <span className="num" style={{ fontWeight: 800, color: C.orange }}>{kg(custom ? profile.targetPullUp + profile.targetDip : profile.targetTotal)}</span>
        </div>
      </div>
      <div className="group-footer">
        {custom ? 'Задайте свои цели по движениям.' : 'Норматив по сумме раскладывается на движения пропорционально таблице федерации, с шагом 1,25 кг.'}
      </div>

      <div className="group-label">Соревнования</div>
      <div className="field-group">
        <div className="field">
          <label>Название</label>
          <input type="text" placeholder="Кубок города" value={profile.competitionName} onChange={(e) => actions.updateProfile({ competitionName: e.target.value })} />
        </div>
        <div className="field">
          <label>Дата старта</label>
          <input type="date" value={profile.competitionDate ? toDateInput(profile.competitionDate) : ''}
            onChange={(e) => actions.updateProfile({ competitionDate: e.target.value ? fromDateInput(e.target.value) : null })} />
        </div>
        {profile.competitionDate && (
          <button className="list-row" style={{ color: C.pink }} onClick={() => actions.updateProfile({ competitionDate: null })}>Убрать дату</button>
        )}
      </div>

      <div className="group-label">Данные</div>
      <div className="field-group">
        <button className="list-row" onClick={() => setShowExercises(true)}>
          <IconBadge icon="dumbbell" color={C.orange} size={30} /><span style={{ flex: 1 }}>Упражнения</span>
          <span className="secondary">{data.exercises.length}</span><Icon name="chevronRight" size={16} className="tertiary" />
        </button>
        <button className="list-row" onClick={() => shareFile(`streetlog-${stamp}.csv`, exportCSV(data), 'text/csv')}>
          <IconBadge icon="share" color={C.blue} size={30} /><span style={{ flex: 1 }}>Экспорт в CSV (Excel, Numbers)</span>
        </button>
        <button className="list-row" onClick={() => shareFile(`streetlog-backup-${stamp}.json`, JSON.stringify(data), 'application/json')}>
          <IconBadge icon="download" color={C.green} size={30} /><span style={{ flex: 1 }}>Сохранить резервную копию</span>
        </button>
        <button className="list-row" onClick={() => fileInput.current?.click()}>
          <IconBadge icon="upload" color={C.violet} size={30} /><span style={{ flex: 1 }}>Восстановить из копии</span>
        </button>
      </div>
      <div className="group-footer">Данные хранятся только на этом телефоне. Раз в пару недель сохраняйте резервную копию в «Файлы» или iCloud.</div>
      <input ref={fileInput} type="file" accept="application/json,.json" hidden
        onChange={(e) => { const f = e.target.files?.[0]; if (f) void importBackup(f); e.target.value = '' }} />

      <div className="caption" style={{ textAlign: 'center', marginTop: 8 }}>
        StreetLog · {data.entries.length} записей · {data.attempts.length} попыток · {num(data.exercises.length)} упражнений
      </div>

      {showExercises && <ExercisesSheet onClose={() => setShowExercises(false)} />}
      {showInstall && <InstallSheet onClose={() => setShowInstall(false)} />}
      {toast}
    </div>
  )
}

function ExercisesSheet({ onClose }: { onClose: () => void }) {
  const data = useData()
  const [creating, setCreating] = useState(false)
  const categories = [...new Set(data.exercises.map((e) => e.category))].sort(compareCategories)
  return (
    <Sheet title="Упражнения" onClose={onClose} left={<button onClick={onClose}>Закрыть</button>}
      right={<button onClick={() => setCreating(true)} aria-label="Новое упражнение"><Icon name="plus" /></button>}>
      {categories.map((category) => (
        <div key={category} className="stack" style={{ gap: 8 }}>
          <div className="group-label" style={{ margin: '4px 16px 0' }}>{category}</div>
          <div className="field-group">
            {data.exercises.filter((e) => e.category === category).map((e) => (
              <div key={e.id} className="list-row">
                <IconBadge icon={e.lift ? liftIcon[e.lift] : 'dumbbell'} color={e.lift ? liftColor[e.lift] : C.orange} size={30} />
                <span style={{ flex: 1 }}>{e.name}</span>
                <button aria-label="Удалить" style={{ color: C.pink }} onClick={() => confirm(`Удалить «${e.name}»? Записи в дневнике останутся.`) && actions.deleteExercise(e.id)}>
                  <Icon name="trash" size={18} />
                </button>
              </div>
            ))}
          </div>
        </div>
      ))}
      {creating && <ExerciseForm onClose={() => setCreating(false)} />}
    </Sheet>
  )
}

export function InstallSheet({ onClose }: { onClose: () => void }) {
  const steps: [string, string][] = [
    ['Откройте эту страницу в Safari', 'Именно Safari: в Chrome и других браузерах на iPhone пункт может называться иначе или отсутствовать.'],
    ['Нажмите «Поделиться»', 'Квадрат со стрелкой вверх — внизу экрана (или справа от адреса). Если панели нет, коснитесь адресной строки.'],
    ['Выберите «На экран Домой»', 'Прокрутите список действий вниз. Включите «Открыть как веб-приложение», если такой переключатель есть.'],
    ['Нажмите «Добавить»', 'На рабочем столе появится иконка StreetLog. Открывайте приложение с неё — оно работает на весь экран и без интернета.'],
  ]
  return (
    <Sheet title="Установка на iPhone" onClose={onClose} left={<button onClick={onClose}>Закрыть</button>}>
      {steps.map(([title, text], i) => (
        <div key={title} className="card" style={{ flexDirection: 'row', alignItems: 'flex-start' }}>
          <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'var(--gradient)', display: 'grid', placeItems: 'center', fontWeight: 800, flex: 'none' }}>{i + 1}</div>
          <div className="stack" style={{ gap: 4 }}>
            <div className="headline">{title}</div>
            <div className="footnote">{text}</div>
          </div>
        </div>
      ))}
      <div className="footnote" style={{ padding: '0 4px' }}>
        Данные хранятся на телефоне. Если удалить иконку с экрана «Домой», данные удалятся вместе с ней — перед этим сохраните резервную копию в профиле.
      </div>
    </Sheet>
  )
}
