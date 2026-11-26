/** Short taps. iPhone's browser ignores them; the installed app uses the real Taptic Engine. */
export function haptic(kind: 'select' | 'add' | 'success' | 'delete') {
  const pattern = { select: 10, add: [12, 40, 16], success: 14, delete: [10, 50, 24] }[kind]
  navigator.vibrate?.(pattern)
}
