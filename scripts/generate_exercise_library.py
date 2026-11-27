"""Generates the exercise library for the web app and the iOS app from one list.

Run from anywhere: python3 scripts/generate_exercise_library.py
Bump LIBRARY_VERSION / ExerciseLibrary.version when the list changes.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

LIB = {
  "Стритлифтинг": [
    ("Подтягивания с отягощением", "pullUp"),
    ("Отжимания на брусьях с отягощением", "dip"),
    ("Подтягивания с отягощением — одиночки", "pullUp"),
    ("Брусья с отягощением — одиночки", "dip"),
    ("Подтягивания с паузой над перекладиной", None),
    ("Брусья с паузой внизу", None),
    ("Негативные подтягивания с отягощением", None),
    ("Негативные отжимания на брусьях с отягощением", None),
    ("Частичные подтягивания (дожимы)", None),
    ("Частичные отжимания на брусьях", None),
  ],
  "Турник": [
    ("Подтягивания", None),
    ("Подтягивания широким хватом", None),
    ("Подтягивания узким хватом", None),
    ("Подтягивания обратным хватом", None),
    ("Подтягивания параллельным хватом", None),
    ("Подтягивания к груди", None),
    ("Подтягивания за голову", None),
    ("Подтягивания на полотенцах", None),
    ("Подтягивания в стиле лучника", None),
    ("Подтягивания на одной руке (с помощью)", None),
    ("Негативные подтягивания", None),
    ("Подтягивания с резинкой", None),
    ("Австралийские подтягивания", None),
    ("Вис на перекладине (сек)", None),
    ("Выход силой на перекладине", None),
    ("Подъём переворотом", None),
  ],
  "Брусья": [
    ("Отжимания на брусьях", None),
    ("Отжимания на брусьях с наклоном (на грудь)", None),
    ("Отжимания на брусьях прямо (на трицепс)", None),
    ("Негативные отжимания на брусьях", None),
    ("Отжимания на брусьях с резинкой", None),
    ("Отжимания на кольцах", None),
    ("Упор на брусьях (сек)", None),
    ("Выход силой на брусьях", None),
  ],
  "Грудь": [
    ("Отжимания от пола", None),
    ("Отжимания широким хватом", None),
    ("Отжимания с ногами на возвышении", None),
    ("Отжимания с хлопком", None),
    ("Отжимания с отягощением", None),
    ("Жим лёжа", None),
    ("Жим лёжа узким хватом", None),
    ("Жим штанги на наклонной скамье", None),
    ("Жим гантелей лёжа", None),
    ("Жим гантелей на наклонной скамье", None),
    ("Разведение гантелей лёжа", None),
    ("Сведение рук в кроссовере", None),
    ("Сведение рук в тренажёре (бабочка)", None),
    ("Жим в тренажёре на грудь", None),
    ("Пуловер с гантелью", None),
  ],
  "Спина": [
    ("Тяга штанги в наклоне", None),
    ("Тяга гантели в наклоне одной рукой", None),
    ("Тяга верхнего блока к груди", None),
    ("Тяга верхнего блока узким хватом", None),
    ("Тяга горизонтального блока", None),
    ("Тяга Т-грифа", None),
    ("Тяга в тренажёре (рычажная)", None),
    ("Пуловер на блоке прямыми руками", None),
    ("Становая тяга", None),
    ("Румынская тяга", None),
    ("Гиперэкстензия", None),
    ("Шраги со штангой", None),
    ("Шраги с гантелями", None),
  ],
  "Плечи": [
    ("Жим штанги стоя", None),
    ("Жим гантелей сидя", None),
    ("Жим Арнольда", None),
    ("Махи гантелями в стороны (разводка на средние дельты)", None),
    ("Махи гантелями перед собой", None),
    ("Махи в наклоне (на задние дельты)", None),
    ("Разведение в тренажёре на задние дельты", None),
    ("Махи в сторону на нижнем блоке", None),
    ("Тяга штанги к подбородку", None),
    ("Тяга каната к лицу (фейс-пулл)", None),
    ("Отжимания в стойке на руках", None),
    ("Пайк-отжимания", None),
    ("Внешняя ротация плеча с резинкой", None),
  ],
  "Бицепс": [
    ("Сгибания на бицепс", None),
    ("Сгибания со штангой стоя", None),
    ("Сгибания с EZ-грифом", None),
    ("Сгибания с гантелями стоя", None),
    ("Сгибания с гантелями сидя на наклонной скамье", None),
    ("Молотки с гантелями", None),
    ("Концентрированные сгибания", None),
    ("Сгибания на скамье Скотта", None),
    ("Сгибания на нижнем блоке", None),
  ],
  "Трицепс": [
    ("Французский жим", None),
    ("Французский жим с гантелями", None),
    ("Разгибания на блоке (канат)", None),
    ("Разгибания на блоке (прямая рукоять)", None),
    ("Разгибание гантели из-за головы", None),
    ("Разгибание руки с гантелью в наклоне", None),
    ("Отжимания от скамьи", None),
    ("Алмазные отжимания", None),
  ],
  "Предплечья и хват": [
    ("Сгибания запястий со штангой", None),
    ("Разгибания запястий со штангой", None),
    ("Прогулка фермера", None),
    ("Удержание грифа (сек)", None),
    ("Эспандер кистевой", None),
  ],
  "Ноги": [
    ("Приседания", None),
    ("Приседания со штангой", None),
    ("Фронтальные приседания", None),
    ("Гоблет-приседания с гантелью", None),
    ("Выпады с гантелями", None),
    ("Выпады со штангой", None),
    ("Выпады назад", None),
    ("Выпады в ходьбе", None),
    ("Болгарские сплит-приседания", None),
    ("Зашагивания на тумбу с гантелями", None),
    ("Жим ногами", None),
    ("Гакк-приседания", None),
    ("Разгибания ног в тренажёре", None),
    ("Сгибания ног в тренажёре", None),
    ("Пистолетик (приседание на одной ноге)", None),
    ("Прыжки на тумбу", None),
    ("Сведение ног в тренажёре", None),
    ("Разведение ног в тренажёре", None),
  ],
  "Ягодицы": [
    ("Ягодичный мост со штангой", None),
    ("Ягодичный мост", None),
    ("Отведение ноги назад на блоке", None),
    ("Махи ногой назад в кроссовере", None),
    ("Румынская тяга с гантелями", None),
    ("Свинги с гирей", None),
  ],
  "Икры": [
    ("Подъёмы на носки стоя", None),
    ("Подъёмы на носки сидя", None),
    ("Подъёмы на носки в тренажёре", None),
  ],
  "Пресс и кор": [
    ("Подъём ног в висе", None),
    ("Подъём коленей в висе", None),
    ("Уголок в упоре (сек)", None),
    ("Планка (сек)", None),
    ("Боковая планка (сек)", None),
    ("Скручивания", None),
    ("Обратные скручивания", None),
    ("Велосипед", None),
    ("Русские скручивания", None),
    ("Ролик для пресса", None),
    ("Скручивания на блоке", None),
    ("Дровосек на блоке", None),
    ("Лодочка (сек)", None),
    ("Драконий флаг", None),
    ("Подъём ног лёжа", None),
  ],
  "Кардио": [
    ("Бег (мин)", None),
    ("Велотренажёр (мин)", None),
    ("Гребной тренажёр (мин)", None),
    ("Скакалка", None),
    ("Берпи", None),
    ("Прыжки «Джек»", None),
    ("Альпинист", None),
    ("Эллипс (мин)", None),
  ],
  "Растяжка и мобильность": [
    ("Растяжка плеч (сек)", None),
    ("Растяжка грудных в дверном проёме (сек)", None),
    ("Вис для разгрузки позвоночника (сек)", None),
    ("Наклоны к ногам (сек)", None),
    ("Мостик (сек)", None),
    ("Выкруты с палкой", None),
  ],
}

names = [n for v in LIB.values() for n, _ in v]
assert len(names) == len(set(names)), [n for n in names if names.count(n) > 1]
print(f'{len(names)} exercises')

ts = ["import type { Lift } from './logic'", "",
      "/** Bump when the list changes so existing users get the new exercises. */",
      "export const LIBRARY_VERSION = 1", "",
      "export const EXERCISE_CATEGORIES = [" + ", ".join(f"'{c}'" for c in LIB) + "]", "",
      "export const EXERCISE_LIBRARY: [name: string, category: string, lift: Lift | null][] = ["]
for cat, items in LIB.items():
    for n, l in items:
        ts.append(f"  ['{n}', '{cat}', {repr(l) if l else 'null'}],".replace('"', "'"))
ts.append("]")
ts += ["", "export function compareCategories(a: string, b: string): number {",
       "  const ia = EXERCISE_CATEGORIES.indexOf(a)", "  const ib = EXERCISE_CATEGORIES.indexOf(b)",
       "  if (ia === -1 && ib === -1) return a.localeCompare(b, 'ru')", "  if (ia === -1) return 1",
       "  if (ib === -1) return -1", "  return ia - ib", "}"]
open(ROOT / 'web/src/exerciseLibrary.ts', 'w').write("\n".join(ts) + "\n")

sw = ["import Foundation", "", "enum ExerciseLibrary {",
      "    /// Bump when the list changes so existing users get the new exercises.",
      "    static let version = 1", "",
      "    static let categories: [String] = [" + ", ".join(f'"{c}"' for c in LIB) + "]", "",
      "    static let all: [(name: String, category: String, lift: Lift?)] = ["]
for cat, items in LIB.items():
    for n, l in items:
        sw.append(f'        ("{n}", "{cat}", {"." + l if l else "nil"}),')
sw += ["    ]", "",
       "    /// Library categories first, in library order; custom categories after, alphabetically.",
       "    static func areInOrder(_ lhs: String, _ rhs: String) -> Bool {",
       "        switch (categories.firstIndex(of: lhs), categories.firstIndex(of: rhs)) {",
       "        case let (l?, r?): return l < r",
       "        case (_?, nil): return true",
       "        case (nil, _?): return false",
       "        case (nil, nil): return lhs.localizedCompare(rhs) == .orderedAscending",
       "        }",
       "    }",
       "}"]
open(ROOT / 'StreetLog/Logic/ExerciseLibrary.swift', 'w').write("\n".join(sw) + "\n")

MUSCLES = ["chest", "lats", "traps", "lowerBack", "frontDelts", "sideDelts", "rearDelts", "biceps", "triceps",
           "forearms", "abs", "obliques", "quads", "hamstrings", "glutes", "adductors", "calves", "cardio"]
KINDS = {"c": "compound", "i": "isolation", "s": "static", "k": "cardio", "m": "stretch"}

info = {}
for line in open(ROOT / 'scripts/exercise_info.txt', encoding='utf-8'):
    line = line.strip()
    if not line or line.startswith('#'):
        continue
    name, primary, secondary, kind, equipment, level, rating, tip = [p.strip() for p in line.split('|')]
    muscles = lambda s: [] if s == '—' else s.split()
    entry = (muscles(primary), muscles(secondary), KINDS[kind], '' if equipment == '—' else equipment, int(level), int(rating), tip)
    assert all(m in MUSCLES for m in entry[0] + entry[1]), name
    assert entry[0] and 1 <= entry[4] <= 3 and 1 <= entry[5] <= 5, name
    assert name not in info, name
    info[name] = entry
missing = [n for n in names if n not in info]
extra = [n for n in info if n not in names]
assert not missing and not extra, (missing, extra)

photos = {}
for line in open(ROOT / 'scripts/exercise_images.txt', encoding='utf-8'):
    line = line.strip()
    if not line or line.startswith('#'):
        continue
    name, source = [p.strip() for p in line.split('|')]
    assert name in info and name not in photos, name
    photos[name] = re.sub(r'[^a-z0-9]+', '-', source.lower()).strip('-')

def fetch_photos():
    """Downloads start/end photos once and stores small JPEGs for both apps."""
    import io, urllib.request
    from PIL import Image
    web_dir = ROOT / 'web/public/exercise-photos'
    ios_dir = ROOT / 'StreetLog/Resources/ExercisePhotos'
    web_dir.mkdir(parents=True, exist_ok=True)
    ios_dir.mkdir(parents=True, exist_ok=True)
    sources = {}
    for line in open(ROOT / 'scripts/exercise_images.txt', encoding='utf-8'):
        if line.strip() and not line.startswith('#'):
            name, source = [p.strip() for p in line.split('|')]
            sources[photos[name]] = source
    for slug, source in sorted(sources.items()):
        for i in (0, 1):
            out = web_dir / f'{slug}-{i}.jpg'
            if not out.exists():
                url = f'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/{source}/{i}.jpg'
                img = Image.open(io.BytesIO(urllib.request.urlopen(url).read())).convert('RGB')
                img.thumbnail((480, 480))
                img.save(out, 'JPEG', quality=72, optimize=True, progressive=True)
            (ios_dir / out.name).write_bytes(out.read_bytes())

fetch_photos()

def ts_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"

ti = ["// Generated by scripts/generate_exercise_library.py from scripts/exercise_info.txt — do not edit.",
      "import type { ExerciseInfo } from './muscles'", "",
      "export const EXERCISE_INFO: Record<string, ExerciseInfo> = {"]
for n in names:
    p, s, k, e, lv, r, tip = info[n]
    ti.append(f"  {ts_str(n)}: {{ primary: [{', '.join(ts_str(m) for m in p)}], secondary: [{', '.join(ts_str(m) for m in s)}], "
              f"kind: '{k}', equipment: {ts_str(e)}, level: {lv}, rating: {r}, tip: {ts_str(tip)}{f", photo: {ts_str(photos[n])}" if n in photos else ""} }},")
ti.append("}")
open(ROOT / 'web/src/exerciseInfo.ts', 'w').write("\n".join(ti) + "\n")

def sw_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

si = ["// Generated by scripts/generate_exercise_library.py from scripts/exercise_info.txt — do not edit.",
      "import Foundation", "", "extension ExerciseInfo {",
      "    /// Built with statements instead of one literal to keep type-checking fast.",
      "    static let library: [String: ExerciseInfo] = {",
      "        var d: [String: ExerciseInfo] = [:]"]
for n in names:
    p, s, k, e, lv, r, tip = info[n]
    si.append(f"        d[{sw_str(n)}] = ExerciseInfo(primary: [{', '.join('.' + m for m in p)}], secondary: [{', '.join('.' + m for m in s)}], "
              f"kind: .{k}, equipment: {sw_str(e)}, level: {lv}, rating: {r}, tip: {sw_str(tip)}{f", photo: {sw_str(photos[n])}" if n in photos else ""})")
si += ["        return d", "    }()", "}"]
open(ROOT / 'StreetLog/Logic/ExerciseInfoData.swift', 'w').write("\n".join(si) + "\n")
print(f'{len(info)} exercise descriptions, {len(photos)} with photos')
