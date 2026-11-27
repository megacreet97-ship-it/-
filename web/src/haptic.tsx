import { useRef, type MouseEvent as ReactMouseEvent } from 'react'

/** Android vibration. iPhone Safari ignores this; taps there hit HapticPad instead. */
export function haptic(kind: 'select' | 'add' | 'success' | 'delete') {
  const pattern = { select: 10, add: [12, 40, 16], success: 14, delete: [10, 50, 24] }[kind]
  navigator.vibrate?.(pattern)
}

/**
 * Invisible switch stretched over a button.
 * iOS only runs the Taptic Engine when a finger toggles a real switch,
 * and since iOS 26.5 a scripted click no longer counts — the tap has to land on this control.
 * The click is forwarded to the button so the original action still runs once.
 */
export function HapticPad() {
  const ref = useRef<HTMLInputElement>(null)
  const forward = (event: ReactMouseEvent<HTMLInputElement>) => {
    event.stopPropagation()
    const host = ref.current?.parentElement
    host?.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }))
  }
  return (
    <input
      ref={(el) => {
        ref.current = el
        el?.setAttribute('switch', '')
      }}
      type="checkbox"
      aria-hidden="true"
      tabIndex={-1}
      className="haptic-pad"
      onClick={forward}
    />
  )
}
