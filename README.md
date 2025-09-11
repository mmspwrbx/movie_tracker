# 🎬 Movie Tracker

[English](README.md) • [Русский](README.RU.md)

A lightweight Flutter app to track movies you watch and plan to watch.  
It pulls data from **TMDb** (with optional **OMDb** ratings), stores your library locally via **Drift** (SQLite), and offers recommendations based on your history.

## ✨ Features

- 🔎 **Search** movies (TMDb)
- 🧠 **Recommendations** based on your recently watched
- 🗂️ **Lists**: *Watched* and *Watch later* (+ quick toggle on cards)
- 🎥 **Movie details**: synopsis, genres, runtime, backdrops
- ⭐ **Ratings badges**: TMDb always; IMDb & Rotten Tomatoes when OMDb key is provided
- 📝 **Reviews**: personal 10-point rating (with halves) + text notes
- 🧹 **List cleanup**: swipe to remove in list details
- 🧰 **Filters** in recommendations: genres, year range, min TMDb score
- 👤 **Profile**: name, email, avatar; local onboarding if profile not created
- 💾 **Local DB**: Drift/SQLite (works offline)

## 🧱 Tech Stack

- Flutter + Material 3
- State: **Riverpod**
- Navigation: **go_router**
- HTTP: **Dio**
- DB: **Drift** (SQLite)
- Config: **flutter_dotenv**
- APIs: **TMDb** (+ optional **OMDb**)

## 🔧 Setup

1. **Flutter**: install a recent stable SDK.
2. **API keys**:
   - Get a TMDb API key.
   - (Optional) Get an OMDb key for IMDb/RT badges.
3. Create `assets/.env`:
   ```env
   TMDB_API_KEY=your_tmdb_key_here
   OMDB_API_KEY=your_omdb_key_here
   TMDB_IMAGE_BASE=https://image.tmdb.org/t/p/
