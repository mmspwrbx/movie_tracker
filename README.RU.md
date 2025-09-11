# 🎬 Movie Tracker

[English](README.md) • [Русский](README.RU.md)

Лёгкое Flutter-приложение для ведения личной фильмотеки.
Данные берутся из TMDb (при желании добавляются оценки из OMDb), библиотека хранится локально в Drift (SQLite), рекомендации строятся по вашей истории.

## ✨ Возможности

- 🔎 **Поиск** фильмов (TMDb)
- 🧠 **Рекомендации** по недавно просмотренным
- 🗂️ **Списки**: *Просмотрено* and *Хочу посмотреть* (+ быстрый тумблер на карточках)
- 🎥 **Карточка фильма**: описание, жанры, длительность, кадры
- ⭐ **Бейджи оценок**: TMDb всегда; IMDb и Rotten Tomatoes при наличии OMDb-ключа
- 📝 **Рецензии**: своя 10-бальная оценка (с половинками) + текст
- 🧹 **Удаление свайпом**: в деталях списка
- 🧰 **Фильтры** рекомендаций: жанры, годы, минимальная TMDb-оценка
- 👤 **Профиль**: имя, почта, аватар; онбординг при первом запуске
- 💾 **Локальная БД**: Drift/SQLite (офлайн)

## 🧱 Стек

- Flutter + Material 3
- State: **Riverpod**
- Navigation: **go_router**
- HTTP: **Dio**
- DB: **Drift** (SQLite)
- Config: **flutter_dotenv**
- APIs: **TMDb** (+ optional **OMDb**)

## 🔧 Установка и запус

1. **Flutter**: install a recent stable SDK.
2. **API keys**:
   - Get a TMDb API key.
   - (Optional) Get an OMDb key for IMDb/RT badges.
3. Create `assets/.env`:
   ```env
   TMDB_API_KEY=your_tmdb_key_here
   OMDB_API_KEY=your_omdb_key_here
   TMDB_IMAGE_BASE=https://image.tmdb.org/t/p/
