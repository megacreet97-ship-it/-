import { useEffect, useState } from 'react'
import { Icon, type IconName } from './icons'
import { AnalyticsScreen } from './screens/Analytics'
import { DiaryScreen } from './screens/Diary'
import { ExercisesScreen } from './screens/Exercises'
import { GoalScreen, goalTabTitle } from './screens/Goal'
import { ProfileScreen } from './screens/Profile'
import { RestTimerBar } from './screens/RestTimer'
import { effectiveGoal, useData } from './store'

const TAB_COUNT = 5

const initialTab = () => {
  const fromUrl = Number(new URLSearchParams(location.search).get('tab'))
  return Number.isInteger(fromUrl) && fromUrl >= 0 && fromUrl < TAB_COUNT ? fromUrl : 0
}

export default function App() {
  const [tab, setTab] = useState(initialTab)
  const goal = effectiveGoal(useData())
  const tabs: { label: string; icon: IconName }[] = [
    { label: 'Дневник', icon: 'calendar' },
    { label: goalTabTitle(goal), icon: goal === 'ms' || goal === null ? 'trophy' : 'heart' },
    { label: 'Упражнения', icon: 'body' },
    { label: 'Аналитика', icon: 'chart' },
    { label: 'Профиль', icon: 'user' },
  ]

  useEffect(() => {
    window.scrollTo(0, 0)
  }, [tab])

  return (
    <>
      {tab === 0 && <DiaryScreen />}
      {tab === 1 && <GoalScreen onOpenExercises={() => setTab(2)} />}
      {tab === 2 && <ExercisesScreen />}
      {tab === 3 && <AnalyticsScreen />}
      {tab === 4 && <ProfileScreen />}
      <RestTimerBar raised={tab === 0} />
      <nav className="tabbar">
        {tabs.map((t, i) => (
          <button key={i} className={i === tab ? 'active' : ''} onClick={() => setTab(i)} aria-current={i === tab ? 'page' : undefined}>
            <Icon name={t.icon} size={24} strokeWidth={i === tab ? 2.4 : 2} />
            {t.label}
          </button>
        ))}
      </nav>
    </>
  )
}
