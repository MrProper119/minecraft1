# 🎮 Colossal Engineering & Magic Modpack (Minecraft 1.21.1 NeoForge)

[English](#-english) | [Українська](#-українська)

---

# 🇬🇧 English

A next-generation Minecraft modpack built for high-tech survival, dynamic physics-based engineering, and deep spellcasting with friends. Powered by **Git** and **Packwiz** for seamless background synchronization, with full native **TLauncher** integration.

* **Minecraft Version:** `1.21.1`
* **Mod Loader:** `NeoForge 21.1.265` (compatible with `21.1.226+`)
* **Total Mods:** 230+
* **Primary Themes:** Dynamic Physics (Walking Mechs & Airships), Extreme Height Overworld (768 blocks), Realistic Nuclear Engineering, Advanced Magic & Boss Dungeons, Next-Gen Visuals (Distant Horizons & Sodium/Veil).

---

## ✨ Custom Mods & Engine Fixes

This modpack includes custom-built and patched mods developed specifically to ensure seamless compatibility between high-tech machinery, spatial travel, and movable physical structures:

### 1. 🏔️ TallWorld Engine (`tallworld-1.21.1-1.0.0.jar`)
A custom Overworld height expansion engine:
* **768-Block World Height:** Expands the Overworld vertical limits from standard 384 blocks to **768 blocks** (`Y = -64` to `Y = 704`).
* **Elevated Sea Level:** Shifted to `Y = 288` (default was 63), creating a natural 50/50 vertical balance:
  * **~350 blocks of subterranean depth** below sea level for colossal cavern systems, underground biomes, and deep abysses.
  * **~400 blocks of sky & mountainous elevation** above sea level with cloud-piercing peaks and plateaus.
* **Proportional Ore Re-balancing:** All vanilla and modded ores (Iron, Copper, Coal, Gold, Redstone, Lapis, Diamond, Zinc, Tin, Lead, Uranium, Fluorite, Osmium) are automatically redistributed across the 768-block depth so mining remains engaging, deep, and rewarding.
* **Structure Re-anchoring:** Automatically re-anchors surface villages, towers, and dungeons to the new sea level and terrain height.

### 2. ⚡ SableFixes (`sablefixes-1.21.1-1.0.0.jar`)
A dedicated compatibility bridge between moving physical structures (**Sable / Aeronautics / Let It Walk**) and dimensional / spatial transport mods:
* **Mekanism Teleporter Support on Mobile Structures:**
  * **Multiplayer & Structure Tracking:** Fixed player synchronization so that other players standing on moving physical structures remain fully visible to each other and are not displaced into shipyard plots on the minimap.
  * **Precise World Coordinates (Zero Void Teleports):** Fixes double-projection calculations where teleporting back from the world onto a moving structure threw players into the void or below bedrock (`-20,000,000 X / -341 Y`). Teleports now deliver you directly to the teleporter pad on the moving structure.
  * **Client Rendering Crash Fix (`MekanismRenderTeleporterMixin`):** Prevents client crashes caused by `NullPointerException` when rendering teleporter frequency rings/colors while a physical mech or airship is moving.
* **Iron's Spells and Spellbooks Portal Stabilization:**
  * Ensures portal frames remain intact and operable on moving physical structures.

### 3. ⚙️ Create Mekanism Compat (Custom Patched)
* Provides smooth coordinate mapping between Create contraptions, Sable physical entities, and Mekanism transport lines.

---

## 🚀 Key Gameplay Pillars

### 🏭 1. Physics, Mechanics & Aeronautics
* **Create + The Factory Must Grow (TFMG):** Heavy industrial metallurgy, blast furnaces, distillation towers, rotational kinetics, and logistics networks.
* **Create New Age & Crafts & Additions:** Electrical generation, dynamos, and electromechanical conversion.
* **Sable & Let It Walk:** Assemble physical walking mechs, airships, mobile bases, and dynamic combat machines that move with real-time physics and collisions.

### ⚛️ 2. Advanced Technology & Nuclear Power
* **Mekanism & Mekanism Generators:** 5-tier ore quadrupling/quintupling processing lines, digital mining, jetpacks, and MekaSuit armor.
* **Realistic Nuclear & Fusion Reactors:** In-depth radiation mechanics, hazardous waste disposal, turbine cooling loops, and colossal power generation.

### 🌌 3. Colossal Worldgen & Visual Immersion
* **Terralith & Big Globe:** Spectacular terrain features, vast mountain ranges, and rich diverse biomes designed for 768m heights.
* **Distant Horizons (DH):** Level-of-Detail (LOD) rendering allowing 128+ chunk render distance with high performance.
* **Sodium / Embeddium / Veil:** Fully optimized GPU rendering pipeline delivering smooth framerates even around massive mechanical factories.

### 🔮 4. Magic, Dungeons & Boss Combat
* **Iron's Spells 'n Spellbooks:** Complete magic system featuring elemental spellbooks, customizable scrolls, mage gear, and boss encounters.
* **L_Ender's Cataclysm:** High-difficulty endgame dungeons featuring monstrous bosses (Ignis, Netherite Monstrosity, Harbinger) with unique drops and mechanics.
* **Farmer's Delight:** Expanded culinary system, cooking pots, and nutritious feasts.

---

## 📥 Quick Start / How to Install & Play

To set up the modpack from scratch, follow these simple steps:

1. **Install TLauncher:**
   * Download and install [TLauncher](https://tlauncher.org/) (if not already installed).
2. **Create a Modpack/Version in TLauncher:**
   * Open TLauncher and click the **TL MODS** button (bottom right) or go to version management.
   * Create a new modpack/version profile (e.g. named `Test`, `Modpack`, or any name) with **Game Version:** `1.21.1` and **NeoForge**.
3. **Download Repository & Launch Script:**
   * Clone or download this repository (make sure `sync.bat` and `sync.ps1` are present).
   * Double-click and run **`sync.bat`**.
4. **Synchronization Window:**
   * The synchronization GUI window will pop up.
   * **Step 1:** Select the folder of your created version inside `.minecraft\versions\` (e.g. `Test`).
   * **Step 2:** Select the active branch (`test2`, `main`, etc.) or desired commit.
   * Click **"Завантажити та запустити TLauncher"** (Download and launch TLauncher).
5. **Ready to Play:**
   * The script automatically downloads all 230+ mods, configs, and engine patches, sets up the version files, and launches TLauncher ready for action!

---

## ⚡ Automated Synchronization (`sync.bat` / `sync.ps1`)

The modpack includes an automated PowerShell-based synchronizer that hooks directly into **TLauncher** or can be run standalone:

### How it Works:
1. **First-Time Setup:** Running `sync.bat` installs a transparent wrapper for `TLauncher.exe`. From then on, starting TLauncher automatically presents the sync manager.
2. **Step 1 — Target Version Directory:**
   * Select any existing version folder inside `.minecraft\versions\` (e.g. `Test` or `3`).
   * Or create a new version folder (`[N]`), browse via Windows Explorer (`[B]`), or type a custom path (`[P]`).
   * Press `0` anytime to skip synchronization and launch the game immediately.
3. **Step 2 — Branch & Commit Selector:**
   * Automatically queries GitHub for active branches (`test2`, `test`, `main`, etc.) and recent commits.
   * Enter a commit number, branch code (`B1`, `B2`), or custom Git commit hash.
4. **Step 3 — Clean Sync & Safe Backup:**
   * Downloads mods and configs for the selected commit.
   * Safely moves outdated or conflicting mods into `mods_backup/`.
   * Preserves your player saves (`saves/`), waypoints (`xaero/`), and keybindings.
   * Configures `<FolderName>.json` and `<FolderName>.jar` and auto-selects this version in TLauncher.

---

## 🛠️ Contributor & Modpack Tools

* **`add_mod.bat`**: Easily install new mods. Paste a Modrinth or CurseForge URL (or mod name), and it will automatically download via Packwiz and refresh the index.
* **`push_changes.bat`**: Synchronizes local changes to GitHub. Automatically updates Packwiz indexes, commits files, and pushes to your target branch (`test2`, `test`, etc.).

---

## 💻 System Requirements & JVM Setup

* **Java Version:** Java 21 (64-bit) is required by NeoForge 1.21.1.
* **RAM Allocation:**
  * **Minimum:** 6 GB (`-Xmx6G`)
  * **Recommended:** 8 – 10 GB (`-Xmx8G` to `-Xmx10G`)
* **GPU:** Dedicated graphics card (NVIDIA GTX 1060 / AMD RX 580 or newer recommended) due to Distant Horizons and shader processing.
* **Recommended JVM Arguments:**
  ```text
  -Xms4G -Xmx8G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+AlwaysPreTouch
  ```

---
---

# 🇺🇦 Українська

Нове покоління збірки Minecraft, створене для комфортної гри з друзями: динамічна інженерія з реальною фізикою, глибока магія та високі технології. Оснащена автоматичною синхронізацією через **Git** та **Packwiz**, а також вбудованою інтеграцією з **TLauncher**.

* **Версія Minecraft:** `1.21.1`
* **Завантажувач модів:** `NeoForge 21.1.265` (сумісно з `21.1.226+`)
* **Кількість модів:** 230+
* **Ключові напрямки:** Фізичні крокуючі мехи та дирижаблі, збільшена висота світу до 768 блоків, реалістичні ядерні реактори, магічні битви з босами, ультра-дистанція огляду (Distant Horizons) та оптимізація Sodium/Veil.

---

## ✨ Власні моди та виправлення рушія

У цій збірці реалізовано власні моди та виправлення, розроблені спеціально для усунення конфліктів між фізичними мехами, порталами та технологічними модами:

### 1. 🏔️ Рушій TallWorld (`tallworld-1.21.1-1.0.0.jar`)
Мод генерації світу зі збільшеною висотою Верхнього світу (Overworld):
* **Висота світу 768 блоків:** Збільшує вертикальні межі світу зі стандартних 384 блоків до **768 блоків** (від `Y = -64` до `Y = 704`).
* **Рівень моря піднято до Y = 288** (замість стандартного 63), що створює ідеальний вертикальний баланс 50/50:
  * **~350 блоків підземель** нижче рівня моря: велетенські печерні розломи, підземні біоми та безодні.
  * **~400 блоків висоти** над рівнем моря: величні гірські хребти, плато та небесні простори.
* **Перерахунок генерації руд:** Усі ванільні та модифіковані руди (залізо, мідь, вугілля, золото, редстоун, лазурит, алмази, цинк, олово, свинець, уран, флюорит, осмій) збалансовано розподілені по всій висоті 768 блоків.
* **Адаптація структур:** Села, фортеці та підземелля коректно генеруються з прив'язкою до нового рівня моря.

### 2. ⚡ Мод SableFixes (`sablefixes-1.21.1-1.0.0.jar`)
Спеціальний міст сумісності між рухомими фізичними структурами (**Sable / Aeronautics / Let It Walk**) та просторовими/портальними модами:
* **Підтримка телепортів Mekanism на фізичних структурах:**
  * **Видимість гравців у мультиплеєрі:** Виправлено відстеження та проекцію координат для інших гравців на рухомих структурах (усунуто зникнення друзів зі структури та їх відображення за мільйони блоків на мінікарті).
  * **Точні світові координати (без викидання в безодню):** Виправлено подвійну трансформацію координат, яка відкидала гравця на координати `-20,000,000 X / -341 Y` під бедрок при поверненні зі світу на рухому структуру. Тепер телепортація приземляє чітко на платформу.
  * **Виправлення крашу клієнта (`MekanismRenderTeleporterMixin`):** Усунуто виліт гри через помилку рендеру кольорового променя телепорту під час руху мехів або дирижаблів.
* **Стабілізація порталів Iron's Spells and Spellbooks:**
  * Дозволяє портальним рамкам залишатися стабільними та активними на рухомих фізичних конструкціях.

### 3. ⚙️ Create Mekanism Compat (Спеціальний патч)
* Забезпечує синхронізацію та проекцію координат між механізмами Create, фізичними структурами Sable та лініями передачі Mekanism.

---

## 🚀 Основні аспекти гри

### 🏭 1. Інженерія, кінематика та аеронавтика
* **Create + The Factory Must Grow (TFMG):** Важка металургія, доменні печі, дистиляційні колони, обертова механіка та логістика.
* **Create New Age та Crafts & Additions:** Генерація електроенергії, електродвигуни та конвертація енергії.
* **Sable та Let It Walk:** Створення повноцінних крокуючих бойових роботів, летючих крейсерів та мобільних баз із реальною фізикою зіткнень.

### ⚛️ 2. Високі технології та ядерна енергетика
* **Mekanism + доповнення:** 5-рівнева переробка руди, цифрові шахтарі, джетпаки та броня MekaSuit.
* **Реалістичні ядерні та термоядерні реактори:** Справжня радіація, утилізація відходів, турбінні охолоджувальні контури та колосальні обсяги енергії.

### 🌌 3. Величний світ та візуальна складова
* **Terralith + Big Globe:** Грандіозні ландшафти, масштабні гори та унікальні біоми під висоту 768м.
* **Distant Horizons (DH):** Технологія LOD-рендеру, що забезпечує дальність промальовування понад 128 чанків без просідання FPS.
* **Sodium / Embeddium / Veil:** Повний пакет графічної оптимізації для високого та стабільного фреймрейту навіть біля великих фабрик.

### 🔮 4. Магія, підземелля та боси
* **Iron's Spells 'n Spellbooks:** Повноцінна магічна система зі створенням сувоїв, книгами заклинань, магічним спорядженням та школами магії.
* **L_Ender's Cataclysm:** Складні епічні боси (Ігніс, Незеритова Монструозність, Провісник) в унікальних підземеллях.
* **Farmer's Delight:** Розширена кулінарія, приготування поживних страв та фермерство.

---

## 📥 Швидкий старт / Як встановити збірку

Щоб завантажити та налаштувати збірку з нуля для себе або друга:

1. **Встановіть TLauncher:**
   * Завантажте та встановіть [TLauncher](https://tlauncher.org/) (якщо ще не встановлено).
2. **Створіть збірку/версію в TLauncher:**
   * Відкрийте TLauncher і перейдіть у вкладку **TL MODS** (у правому нижньому кутку) або перейдіть до створення версії.
   * Створіть нову збірку/версію (наприклад, з назвою `Test`, `Modpack` або будь-якою іншою), обравши версію гри **1.21.1** та завантажувач **NeoForge**.
3. **Завантажте файли репозиторію та запустіть скрипт:**
   * Завантажте або склонуйте цей репозиторій (переконайтеся, що є файли `sync.bat` та `sync.ps1`).
   * Запустіть файл **`sync.bat`**.
4. **Віконце синхронізації:**
   * На екрані з'явиться віконце скрипта синхронізації.
   * **Крок 1:** Оберіть створену в TLauncher папку збірки у списку `.minecraft\versions\` (наприклад, `Test`).
   * **Крок 2:** Оберіть потрібну гілку (наприклад, `test2` або `main`) чи останній коміт зі списку.
   * Натисніть **«Завантажити та запустити TLauncher»**.
5. **Готово до гри:**
   * Скрипт автоматично завантажить усі 230+ модів, конфігурації, файли версії (`.json`/`.jar`) та відкриє TLauncher із повністю налаштованою та готовою до запуску грою!

---

## ⚡ Як працює синхронізація (`sync.bat` / `sync.ps1`)

Збірка містить інтерактивний скрипт синхронізації, який інтегрується безпосередньо у запуск **TLauncher**:

1. **Автоматична інтеграція:** При першому запуску `sync.bat` встановлює обгортку для `TLauncher.exe`. Надалі при кожному запуску TLauncher відкривається меню вибору синхронізації.
2. **Крок 1 — Вибір версії гри:**
   * Оберіть будь-яку папку у `.minecraft\versions\` (наприклад, `Test` або `3`).
   * Створіть нову папку (`[N]`), відкрийте Провідник (`[B]`) або вкажіть власний шлях (`[P]`).
   * Натисніть `0`, якщо синхронізація зараз не потрібна — TLauncher відкриється миттєво.
3. **Крок 2 — Вибір гілки або коміту:**
   * Скрипт автоматично отримує актуальний список гілок (`test2`, `test`, `main` тощо) та останніх комітів з GitHub.
   * Оберіть потрібний коміт за номером зі списку, введіть код гілки (`B1`, `B2`) або хеш вручну.
4. **Крок 3 — Завантаження та захист даних:**
   * Скрипт завантажує потрібну версію збірки.
   * Старі або конфліктні моди переносяться у `mods_backup/`.
   * Ваші світи (`saves/`), мітки та карти (`xaero/`) та налаштування повністю зберігаються.
   * Створюються необхідні файли версії (`.json`, `.jar`) і версія автоматично обирається у TLauncher.

---

## 🛠️ Інструменти розробника та оновлення

* **`add_mod.bat`**: Швидке додавання нових модів. Введіть посилання на Modrinth чи CurseForge (або назву), і скрипт завантажить мод через Packwiz та оновить індекси.
* **`push_changes.bat`**: Відправка ваших змін на GitHub. Скрипт автоматично оновить `Packwiz`, сформує коміт та завантажить зміни у потрібну гілку (`test2`, `test` тощо).

---

## 💻 Системні вимоги та налаштування

* **Версія Java:** Java 21 (64-bit) обов'язкова для NeoForge 1.21.1.
* **Оперативна пам'ять (RAM):**
  * **Мінімум:** 6 ГБ (`-Xmx6G`)
  * **Рекомендовано:** 8 – 10 ГБ (`-Xmx8G` — `-Xmx10G`)
* **Відеокарта:** Дискретна відеокарта (NVIDIA GTX 1060 / AMD RX 580 або новіша) для коректної роботи Distant Horizons та графічних шейдерів.
* **Рекомендовані параметри запуску (JVM Flags):**
  ```text
  -Xms4G -Xmx8G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+AlwaysPreTouch
  ```
