import { useEffect, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'
import { Icon, type IconName } from './icons'
import { num, type Lift, type SportRank } from './logic'

export const C = {
  orange: '#ff7333',
  pink: '#ff3b73',
  blue: '#52a0ff',
  violet: '#a373ff',
  green: '#40db85',
  yellow: '#ffcc40',
}

export const liftColor: Record<Lift, string> = { pullUp: C.blue, dip: C.violet }
export const rankColor: Record<SportRank, string> = { kms: C.blue, ms: C.orange, msmk: C.violet }
export const liftIcon: Record<Lift, IconName> = { pullUp: 'pullUp', dip: 'dip' }

export const alpha = (hex: string, a: number) => {
  const n = parseInt(hex.slice(1), 16)
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`
}

export function Card({ title, icon, trailing, children, className = '' }: {
  title?: string; icon?: IconName; trailing?: ReactNode; children: ReactNode; className?: string
}) {
  return (
    <section className={`card ${className}`}>
      {title && (
        <div className="card-title">
          {icon && <Icon name={icon} size={18} />}
          <span>{title}</span>
          <span className="spacer" />
          {trailing}
        </div>
      )}
      {children}
    </section>
  )
}

export function Pill({ text, color, icon }: { text: string; color: string; icon?: IconName }) {
  return (
    <span className="pill" style={{ background: alpha(color, 0.18), color }}>
      {icon && <Icon name={icon} size={12} strokeWidth={2.6} />}
      {text}
    </span>
  )
}

export function IconBadge({ icon, color, size = 40 }: { icon: IconName; color: string; size?: number }) {
  return (
    <span className="icon-badge" style={{ width: size, height: size, borderRadius: size * 0.3, background: alpha(color, 0.18), color }}>
      <Icon name={icon} size={size * 0.5} />
    </span>
  )
}

export function Ring({ progress, size = 120, line = 12, children }: { progress: number; size?: number; line?: number; children?: ReactNode }) {
  const r = (size - line) / 2
  const circumference = 2 * Math.PI * r
  const clamped = Math.min(Math.max(progress, 0), 1)
  const id = `ring-${size}-${line}`
  return (
    <div style={{ position: 'relative', width: size, height: size, flex: 'none' }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <defs>
          <linearGradient id={id} x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor={C.orange} />
            <stop offset="1" stopColor={C.pink} />
          </linearGradient>
        </defs>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="rgba(255,255,255,0.1)" strokeWidth={line} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={`url(#${id})`} strokeWidth={line} strokeLinecap="round"
          strokeDasharray={circumference} strokeDashoffset={circumference * (1 - clamped)} style={{ transition: 'stroke-dashoffset 0.6s ease' }} />
      </svg>
      <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', textAlign: 'center' }}>{children}</div>
    </div>
  )
}

export function ProgressBar({ value, color, height = 8, marker }: { value: number; color: string; height?: number; marker?: number }) {
  return (
    <div style={{ position: 'relative', height, borderRadius: height, background: 'rgba(255,255,255,0.08)' }}>
      <div style={{ width: `${Math.min(Math.max(value, 0), 1) * 100}%`, height: '100%', borderRadius: height, background: color, transition: 'width 0.5s ease' }} />
      {marker !== undefined && marker > 0 && marker < 1 && (
        <div style={{ position: 'absolute', top: -3, bottom: -3, left: `${marker * 100}%`, width: 2, borderRadius: 1, background: '#fff' }} />
      )}
    </div>
  )
}

export function StatTile({ title, value, caption, color = C.orange, icon }: { title: string; value: string; caption?: string; color?: string; icon?: IconName }) {
  return (
    <div className="card" style={{ gap: 6, padding: 14, flex: 1, minWidth: 0 }}>
      <div className="row" style={{ gap: 6, color }}>
        {icon && <Icon name={icon} size={15} />}
        <span className="caption" style={{ color, fontWeight: 700 }}>{title}</span>
      </div>
      <div className="num" style={{ fontSize: 24, fontWeight: 800, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{value}</div>
      {caption && <div className="caption">{caption}</div>}
    </div>
  )
}

export function Segmented<T extends string | number>({ options, value, onChange }: {
  options: { value: T; label: string }[]; value: T; onChange: (value: T) => void
}) {
  return (
    <div className="segmented">
      {options.map((o) => (
        <button key={String(o.value)} className={o.value === value ? 'active' : ''} onClick={() => onChange(o.value)}>{o.label}</button>
      ))}
    </div>
  )
}

export function Switch({ on, onChange }: { on: boolean; onChange: (on: boolean) => void }) {
  return <button role="switch" aria-checked={on} className={`switch ${on ? 'on' : ''}`} onClick={() => onChange(!on)} />
}

export function BigStepper({ title, value, onChange, step = 1, min = 0, max = 999, unit, quickSteps, format = num }: {
  title: string; value: number; onChange: (v: number) => void; step?: number; min?: number; max?: number
  unit?: string; quickSteps?: number[]; format?: (v: number) => string
}) {
  const set = (v: number) => onChange(Math.round(Math.min(max, Math.max(min, v)) * 100) / 100)
  return (
    <div className="stepper">
      <div className="caption" style={{ fontWeight: 700, textTransform: 'uppercase', letterSpacing: 0.4 }}>{title}</div>
      <div className="controls">
        <button className="round-btn" aria-label="Меньше" onClick={() => set(value - step)}><Icon name="minus" /></button>
        <div className="num"><span className="value">{format(value)}</span>{unit && <span className="unit">{unit}</span>}</div>
        <button className="round-btn" aria-label="Больше" style={{ background: 'var(--gradient)' }} onClick={() => set(value + step)}><Icon name="plus" /></button>
      </div>
      {quickSteps && (
        <div className="quick-steps">
          {quickSteps.map((q) => (
            <button key={q} onClick={() => set(value + q)} style={{ color: q < 0 ? 'var(--secondary)' : 'var(--text)' }}>
              {q > 0 ? '+' : '−'}{num(Math.abs(q))}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

export function Sheet({ title, onClose, left, right, footer, children }: {
  title: string; onClose: () => void; left?: ReactNode; right?: ReactNode; footer?: ReactNode; children: ReactNode
}) {
  useEffect(() => {
    const previous = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', onKey)
    return () => {
      document.body.style.overflow = previous
      window.removeEventListener('keydown', onKey)
    }
  }, [onClose])

  return createPortal(
    <>
      <div className="sheet-backdrop" onClick={onClose} />
      <div className="sheet" role="dialog" aria-modal="true" aria-label={title}>
        <div className="sheet-grabber" />
        <div className="sheet-header">
          <span className="left">{left ?? <button onClick={onClose}>Отмена</button>}</span>
          <span>{title}</span>
          <span className="right">{right}</span>
        </div>
        <div className="sheet-body">{children}</div>
        {footer && <div className="sheet-footer">{footer}</div>}
      </div>
    </>,
    document.body,
  )
}

export function useToast(): [ReactNode, (text: string) => void] {
  const [text, setText] = useState<string | null>(null)
  useEffect(() => {
    if (!text) return
    const t = setTimeout(() => setText(null), 1800)
    return () => clearTimeout(t)
  }, [text])
  return [text ? <div className="toast">{text}</div> : null, setText]
}

export function NumberField({ label, value, onChange, step = 0.5, suffix = 'кг' }: {
  label: string; value: number; onChange: (v: number) => void; step?: number; suffix?: string
}) {
  const [text, setText] = useState(String(value).replace('.', ','))
  useEffect(() => {
    setText((prev) => (parseFloat(prev.replace(',', '.')) === value ? prev : String(value).replace('.', ',')))
  }, [value])
  return (
    <div className="field">
      <label>{label}</label>
      <input type="text" inputMode="decimal" value={text} step={step}
        onChange={(e) => {
          setText(e.target.value)
          const parsed = parseFloat(e.target.value.replace(',', '.'))
          if (!Number.isNaN(parsed)) onChange(parsed)
        }}
        style={{ width: 90 }} />
      <span className="secondary">{suffix}</span>
    </div>
  )
}

export const toDateInput = (ts: number) => {
  const d = new Date(ts)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

export const fromDateInput = (value: string, keepTimeOf?: number) => {
  const [y, m, d] = value.split('-').map(Number)
  const base = keepTimeOf ? new Date(keepTimeOf) : new Date()
  return new Date(y, m - 1, d, base.getHours(), base.getMinutes()).getTime()
}
