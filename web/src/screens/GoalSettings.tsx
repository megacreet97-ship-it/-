import { useState } from 'react'
import { Icon, type IconName } from '../icons'
import { GOALS, goalSubtitle, goalTitle, type Goal } from '../body'
import { num } from '../logic'
import { actions, effectiveGoal, useData } from '../store'
import { C, IconBadge, Segmented, Sheet, alpha } from '../ui'

export const goalIcon: Record<Goal, IconName> = { ms: 'trophy', recomp: 'sparkles', fatLoss: 'trendDown', muscle: 'trendUp' }
export const goalColor: Record<Goal, string> = { ms: C.orange, recomp: C.violet, fatLoss: C.green, muscle: C.blue }

/** Prominent goal button for the top of the goal tab. */
export function GoalSwitch({ goal }: { goal: Goal }) {
  const [open, setOpen] = useState(false)
  return (
    <>
      <button className="goal-switch" style={{ color: goalColor[goal], background: alpha(goalColor[goal], 0.15) }} onClick={() => setOpen(true)}>
        <Icon name={goalIcon[goal]} size={15} strokeWidth={2.4} />
        Цель: {goalTitle[goal]}
        <span className="goal-switch-action">Сменить <Icon name="chevronDown" size={14} strokeWidth={2.6} /></span>
      </button>
      {open && <GoalSettingsSheet onClose={() => setOpen(false)} />}
    </>
  )
}

export function GoalPicker({ value, onPick }: { value: Goal | null; onPick: (goal: Goal) => void }) {
  return (
    <div className="stack" style={{ gap: 10 }}>
      {GOALS.map((g) => (
        <button key={g} className="card" onClick={() => onPick(g)}
          style={{ flexDirection: 'row', alignItems: 'center', textAlign: 'left', gap: 14, padding: 16,
            borderColor: value === g ? alpha(goalColor[g], 0.6) : undefined, background: value === g ? alpha(goalColor[g], 0.1) : undefined }}>
          <IconBadge icon={goalIcon[g]} color={goalColor[g]} size={44} />
          <div className="stack" style={{ gap: 3, flex: 1, minWidth: 0 }}>
            <span className="headline">{goalTitle[g]}</span>
            <span className="footnote">{goalSubtitle[g]}</span>
          </div>
          {value === g && <Icon name="check" size={20} strokeWidth={3} style={{ color: goalColor[g], flex: 'none' }} />}
        </button>
      ))}
    </div>
  )
}

export function OptionalField({ label, value, onChange, suffix }: { label: string; value: string; onChange: (v: string) => void; suffix: string }) {
  return (
    <div className="field">
      <label>{label}</label>
      <input type="text" inputMode="decimal" placeholder="не мерил(а)" value={value} style={{ width: 120 }}
        onChange={(e) => onChange(e.target.value.replace(/[^\d.,]/g, ''))} />
      <span className="secondary">{suffix}</span>
    </div>
  )
}

export const parseOptional = (text: string) => {
  const v = parseFloat(text.replace(',', '.'))
  return Number.isFinite(v) && v > 0 ? v : undefined
}

function StoredField({ label, value, suffix, onCommit }: { label: string; value: number | undefined; suffix: string; onCommit: (v: number | undefined) => void }) {
  const [text, setText] = useState(value ? num(value) : '')
  return <OptionalField label={label} value={text} suffix={suffix} onChange={(t) => { setText(t); onCommit(parseOptional(t)) }} />
}

export function GoalSettingsSheet({ onClose }: { onClose: () => void }) {
  const data = useData()
  const { profile } = data
  const goal = effectiveGoal(data)
  return (
    <Sheet title="Цель" onClose={onClose} left={<button onClick={onClose}>Готово</button>}>
      <GoalPicker value={goal} onPick={(g) => actions.updateProfile({ goal: g })} />
      {goal && goal !== 'ms' && <GoalTargets />}
      {goal === 'ms' && <div className="footnote">Федерацию, весовую и разряд для МС настройте в профиле.</div>}
      {profile.goal === undefined && goal === 'ms' && <div className="caption">Сейчас выбрано автоматически: в дневнике есть стритлифтинг.</div>}
    </Sheet>
  )
}

export function GoalTargets() {
  const { profile } = useData()
  return (
    <>
      <div className="group-label">Целевые показатели</div>
      <div className="field-group">
        <StoredField label="Целевой вес" value={profile.targetWeight} suffix="кг" onCommit={(v) => actions.updateProfile({ targetWeight: v })} />
        <StoredField label="Целевая талия" value={profile.targetWaist} suffix="см" onCommit={(v) => actions.updateProfile({ targetWaist: v })} />
      </div>
      <div className="group-label">Тренировок в неделю</div>
      <Segmented<number> options={[2, 3, 4, 5, 6].map((n) => ({ value: n, label: String(n) }))} value={profile.weeklyWorkouts ?? 3}
        onChange={(n) => actions.updateProfile({ weeklyWorkouts: n })} />
    </>
  )
}
