import { useId } from 'react'
import { dayMonth, num, type DatedValue } from './logic'
import { C } from './ui'

const W = 340
const H = 190
const PAD = { left: 34, right: 10, top: 12, bottom: 24 }

function ticks(min: number, max: number, count = 4): number[] {
  const span = max - min || 1
  const raw = span / count
  const magnitude = Math.pow(10, Math.floor(Math.log10(raw)))
  const step = [1, 2, 2.5, 5, 10].map((m) => m * magnitude).find((s) => s >= raw) ?? raw
  const result: number[] = []
  for (let v = Math.ceil(min / step) * step; v <= max + 1e-9; v += step) result.push(Math.round(v * 100) / 100)
  return result
}

export function LiftChart({ points, estimates = [], trend, target, color, competition }: {
  points: DatedValue[]
  estimates?: DatedValue[]
  trend?: [DatedValue, DatedValue] | null
  target?: number
  color: string
  competition?: number | null
}) {
  const gid = useId()
  const all = [...points, ...estimates, ...(trend ?? [])]
  if (all.length === 0) {
    return <div className="footnote" style={{ height: 120, display: 'grid', placeItems: 'center' }}>Нет данных — добавьте первую попытку</div>
  }
  const dates = all.map((p) => p.date)
  if (competition) dates.push(competition)
  let x0 = Math.min(...dates)
  let x1 = Math.max(...dates)
  if (x1 - x0 < 86_400_000) { x0 -= 3 * 86_400_000; x1 += 3 * 86_400_000 }
  const values = all.map((p) => p.value)
  if (target) values.push(target)
  let y0 = Math.min(...values)
  let y1 = Math.max(...values)
  const pad = Math.max((y1 - y0) * 0.12, 2)
  y0 = Math.max(0, y0 - pad)
  y1 += pad

  const x = (d: number) => PAD.left + ((d - x0) / (x1 - x0)) * (W - PAD.left - PAD.right)
  const y = (v: number) => PAD.top + (1 - (v - y0) / (y1 - y0)) * (H - PAD.top - PAD.bottom)
  const line = points.map((p, i) => `${i ? 'L' : 'M'}${x(p.date).toFixed(1)},${y(p.value).toFixed(1)}`).join('')
  const area = points.length > 1 ? `${line}L${x(points[points.length - 1].date)},${H - PAD.bottom}L${x(points[0].date)},${H - PAD.bottom}Z` : ''
  const xLabels = [x0, (x0 + x1) / 2, x1]

  return (
    <svg viewBox={`0 0 ${W} ${H}`} width="100%" style={{ display: 'block', overflow: 'visible' }}>
      <defs>
        <linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={color} stopOpacity="0.35" />
          <stop offset="1" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      {ticks(y0, y1).map((t) => (
        <g key={t}>
          <line x1={PAD.left} x2={W - PAD.right} y1={y(t)} y2={y(t)} stroke="rgba(255,255,255,0.07)" />
          <text x={PAD.left - 6} y={y(t) + 4} textAnchor="end" fontSize="10" fill="rgba(235,235,245,0.45)">{num(t)}</text>
        </g>
      ))}
      {xLabels.map((d, i) => (
        <text key={i} x={x(d)} y={H - 6} textAnchor={i === 0 ? 'start' : i === 2 ? 'end' : 'middle'} fontSize="10" fill="rgba(235,235,245,0.45)">{dayMonth(d)}</text>
      ))}
      {target ? (
        <g>
          <line x1={PAD.left} x2={W - PAD.right} y1={y(target)} y2={y(target)} stroke={C.green} strokeDasharray="5 4" strokeWidth="1.5" />
          <text x={W - PAD.right} y={y(target) - 5} textAnchor="end" fontSize="10" fontWeight="700" fill={C.green}>цель {num(target)}</text>
        </g>
      ) : null}
      {competition ? <line x1={x(competition)} x2={x(competition)} y1={PAD.top} y2={H - PAD.bottom} stroke={C.yellow} strokeDasharray="2 3" /> : null}
      {area && <path d={area} fill={`url(#${gid})`} />}
      {trend && (
        <line x1={x(trend[0].date)} y1={y(trend[0].value)} x2={x(trend[1].date)} y2={y(trend[1].value)}
          stroke="rgba(255,255,255,0.55)" strokeDasharray="6 5" strokeWidth="1.5" />
      )}
      {line && <path d={line} fill="none" stroke={color} strokeWidth="3" strokeLinejoin="round" strokeLinecap="round" />}
      {estimates.map((p, i) => (
        <rect key={`e${i}`} x={x(p.date) - 3} y={y(p.value) - 3} width="6" height="6" fill={C.orange} fillOpacity="0.85"
          transform={`rotate(45 ${x(p.date)} ${y(p.value)})`} />
      ))}
      {points.map((p, i) => (
        <circle key={i} cx={x(p.date)} cy={y(p.value)} r={i === points.length - 1 ? 5 : 3.5} fill={color} stroke="#1c1c1e" strokeWidth="2" />
      ))}
    </svg>
  )
}

export function BarChart({ data, color = C.orange, format = num, height = 160 }: {
  data: DatedValue[]; color?: string; format?: (v: number) => string; height?: number
}) {
  const gid = useId()
  if (data.length === 0) {
    return <div className="footnote" style={{ height: 100, display: 'grid', placeItems: 'center' }}>Нет данных за период</div>
  }
  const h = height
  const bottom = 20
  const top = 16
  const max = Math.max(...data.map((d) => d.value), 1)
  const slot = (W - 8) / data.length
  const barW = Math.min(28, slot * 0.62)
  const labelEvery = Math.ceil(data.length / 6)
  return (
    <svg viewBox={`0 0 ${W} ${h}`} width="100%" style={{ display: 'block' }}>
      <defs>
        <linearGradient id={gid} x1="0" y1="1" x2="0" y2="0">
          <stop offset="0" stopColor={color} stopOpacity="0.55" />
          <stop offset="1" stopColor={color} />
        </linearGradient>
      </defs>
      {data.map((d, i) => {
        const barH = Math.max(3, (d.value / max) * (h - bottom - top))
        const cx = 4 + slot * i + slot / 2
        const isLast = i === data.length - 1
        return (
          <g key={d.date}>
            <rect x={cx - barW / 2} y={h - bottom - barH} width={barW} height={barH} rx={Math.min(7, barW / 2)} fill={`url(#${gid})`} opacity={isLast ? 1 : 0.85} />
            {(isLast || data.length <= 8) && (
              <text x={cx} y={h - bottom - barH - 4} textAnchor="middle" fontSize="10" fontWeight="700" fill="rgba(255,255,255,0.8)">{format(d.value)}</text>
            )}
            {(i % labelEvery === 0 || isLast) && (
              <text x={cx} y={h - 5} textAnchor="middle" fontSize="9.5" fill="rgba(235,235,245,0.45)">{dayMonth(d.date)}</text>
            )}
          </g>
        )
      })}
    </svg>
  )
}
