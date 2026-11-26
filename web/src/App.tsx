import { useEffect, useState } from 'react'
import { Icon, type IconName } from './icons'
import { AnalyticsScreen } from './screens/Analytics'
import { DiaryScreen } from './screens/Diary'
import { MasterScreen } from './screens/Master'
import { ProfileScreen } from './screens/Profile'

const TABS: { label: string; icon: IconName }[] = [
  { label: 'Дневник', icon: 'calendar' },
  { label: 'Мастер спорта', icon: 'trophy' },
  { label: 'Аналитика', icon: 'chart' },
  { label: 'Профиль', icon: 'user' },
]

const initialTab = () => {
  const fromUrl = Number(new URLSearchParams(location.search).get('tab'))
  return Number.isInteger(fromUrl) && fromUrl >= 0 && fromUrl < TABS.length ? fromUrl : 0
}

export default function App() {
  const [tab, setTab] = useState(initialTab)

  useEffect(() => {
    window.scrollTo(0, 0)
  }, [tab])

  return (
    <>
      {tab === 0 && <DiaryScreen />}
      {tab === 1 && <MasterScreen />}
      {tab === 2 && <AnalyticsScreen />}
      {tab === 3 && <ProfileScreen />}
      <nav className="tabbar">
        {TABS.map((t, i) => (
          <button key={t.label} className={i === tab ? 'active' : ''} onClick={() => setTab(i)} aria-current={i === tab ? 'page' : undefined}>
            <Icon name={t.icon} size={24} strokeWidth={i === tab ? 2.4 : 2} />
            {t.label}
          </button>
        ))}
      </nav>
    </>
  )
}
