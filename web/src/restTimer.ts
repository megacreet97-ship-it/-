import { useSyncExternalStore } from 'react'

export interface RestTimerState {
  endsAt: number | null
  duration: number
  /** Seconds used when the timer starts by itself after a set. */
  defaultSeconds: number
  autoStart: boolean
  finishedAt: number | null
}

export const REST_PRESETS = [60, 90, 120, 180, 300]

const KEY = 'streetlog.rest'

function load(): RestTimerState {
  const base: RestTimerState = { endsAt: null, duration: 120, defaultSeconds: 120, autoStart: true, finishedAt: null }
  try {
    const saved = JSON.parse(localStorage.getItem(KEY) ?? '{}') as Partial<RestTimerState>
    const state = { ...base, ...saved, finishedAt: null }
    if (state.endsAt && state.endsAt < Date.now()) state.endsAt = null
    return state
  } catch {
    return base
  }
}

let state = load()
const listeners = new Set<() => void>()
let audio: AudioContext | null = null
let scheduled: OscillatorNode[] = []
let finishTimer: ReturnType<typeof setTimeout> | undefined

function set(next: Partial<RestTimerState>) {
  state = { ...state, ...next }
  const { endsAt, duration, defaultSeconds, autoStart } = state
  localStorage.setItem(KEY, JSON.stringify({ endsAt, duration, defaultSeconds, autoStart }))
  listeners.forEach((l) => l())
}

/** Beeps are scheduled on the audio clock, so they sound on time even if timers are throttled. */
function scheduleBeeps(secondsFromNow: number) {
  scheduled.forEach((o) => { try { o.stop() } catch { /* already stopped */ } })
  scheduled = []
  try {
    audio ??= new AudioContext()
    if (audio.state === 'suspended') void audio.resume()
    const start = audio.currentTime + Math.max(0, secondsFromNow)
    for (let i = 0; i < 3; i++) {
      const osc = audio.createOscillator()
      const gain = audio.createGain()
      osc.frequency.value = i === 2 ? 1320 : 880
      gain.gain.setValueAtTime(0.0001, start + i * 0.35)
      gain.gain.exponentialRampToValueAtTime(0.4, start + i * 0.35 + 0.02)
      gain.gain.exponentialRampToValueAtTime(0.0001, start + i * 0.35 + 0.25)
      osc.connect(gain).connect(audio.destination)
      osc.start(start + i * 0.35)
      osc.stop(start + i * 0.35 + 0.3)
      scheduled.push(osc)
    }
  } catch {
    // No Web Audio: the visual alert and vibration still work.
  }
}

function armFinish() {
  clearTimeout(finishTimer)
  if (!state.endsAt) return
  finishTimer = setTimeout(() => {
    navigator.vibrate?.([300, 150, 300])
    set({ endsAt: null, finishedAt: Date.now() })
    setTimeout(() => { if (state.finishedAt && Date.now() - state.finishedAt >= 6000) set({ finishedAt: null }) }, 6000)
  }, state.endsAt - Date.now())
}

armFinish()

export const restTimer = {
  start(seconds = state.defaultSeconds) {
    set({ endsAt: Date.now() + seconds * 1000, duration: seconds, finishedAt: null })
    scheduleBeeps(seconds)
    armFinish()
  },
  /** Called after a set is logged. */
  autoStart() {
    if (state.autoStart) restTimer.start()
  },
  add(seconds: number) {
    if (!state.endsAt) return
    const endsAt = Math.max(Date.now() + 1000, state.endsAt + seconds * 1000)
    set({ endsAt, duration: Math.max(state.duration + seconds, 1) })
    scheduleBeeps((endsAt - Date.now()) / 1000)
    armFinish()
  },
  stop() {
    scheduled.forEach((o) => { try { o.stop() } catch { /* already stopped */ } })
    scheduled = []
    clearTimeout(finishTimer)
    set({ endsAt: null, finishedAt: null })
  },
  setDefault(seconds: number) {
    set({ defaultSeconds: seconds })
  },
  setAutoStart(autoStart: boolean) {
    set({ autoStart })
  },
}

const subscribe = (l: () => void) => {
  listeners.add(l)
  return () => listeners.delete(l)
}

export const useRestTimer = () => useSyncExternalStore(subscribe, () => state)

export const formatRest = (seconds: number) => {
  const s = Math.max(0, Math.ceil(seconds))
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
}
