# Stepping Grid Trainer

Sistem Terapi Jalan Interaktif Berbasis ESP32 dengan *Interactive Visual-Auditory Feedback* untuk Rehabilitasi Penyintas Stroke.

> **Proyek Capstone Computing Project**  
> Program Studi S-1 Informatika, Direktorat Kampus Surabaya, Universitas Telkom (2026)  
> Di bawah naungan *Center of Excellence Mobile and Smart Health Ecosystem (CoE MOSHEE)*.

---

## 🏛️ Arsitektur Sistem

Sistem terdiri dari empat subsistem terintegrasi:

1. **Frontend Pasien (Flutter)**:
   - Aplikasi seluler lintas platform (Android, iOS, Web) dengan antarmuka ramah lansia (*high-contrast*, teks besar, WCAG 2.1).
   - Pemilihan 3 layout modular (2×2, Horizontal 1×4, T-Shape) dan panduan posisi awal.
   - Pemantauan langkah langsung (*Live Feedback*), statistik latihan harian, dan wawasan AI (*Saran AI & Estimasi AI*).

2. **Backend Cloud (Supabase)**:
   - **PostgreSQL**: Skema lengkap 11 tabel relasional (`app_user`, `device`, `training_mode`, `layout`, `tile_position`, `training_session`, `session_config`, `step_log`, `session_result`, `ai_prediction`, `ai_recommendation`).
   - **Row Level Security (RLS)**: Pembatasan ketat data pasien sesuai UU PDP.
   - **Supabase Realtime (WebSocket)**: Sinkronisasi status sesi dan injakan kaki seketika (<1 detik).
   - **Stored Procedures (RPC)**: `create_session`, `update_device_heartbeat`, `get_daily_summary`.
   - **Edge Functions**: `device-heartbeat` untuk pemeliharaan status hardware.

3. **Layanan Sistem Cerdas AI & Analitik (Python, FastAPI, scikit-learn)**:
   - **Ekstraksi Fitur (M-08)**: Akurasi langkah, rata-rata waktu inisiasi (ms), total durasi, dan rasio transfer berat badan kiri-kanan (*weight shifting*).
   - **Estimasi Capai Target (M-09)**: Model regresi linear dengan regularisasi (*Ridge Regression* `linreg-v1`) untuk memprediksi hari pencapaian target akurasi 90%.
   - **Rekomendasi Adaptif (M-10)**: Penyesuaian tempo otomatis (-10% atau +15%) dan eskalasi mode latihan berdasarkan performa riwayat pasien.
   - Dipicu otomatis lewat *Database Webhook* saat sesi selesai (`completed`).

4. **Hardware & Firmware IoT (ESP32 DevKit V1 & Ubin Modular)**:
   - 4 ubin injak modular dengan pelat akrilik 5 mm, stopper beban hingga 120 kg, busa EVA, dan sensor microswitch.
   - Rangkaian 32 LED RGB WS2812B (8 LED per ubin) dan buzzer aktif untuk pemanduan visual-auditori seketika (<100 ms).
   - Klien & simulator pengujian di `backend/simulator/esp32_client.py`.

---

## 📂 Struktur Repositori

```
├── android/               # Konfigurasi native Android
├── assets/                # Aset ikon dan grafis antarmuka
├── backend/               # Layanan Sistem Cerdas Python & Simulator
│   ├── app/
│   │   ├── core/          # Konfigurasi Pydantic & validasi keamanan
│   │   ├── models/        # Skema Pydantic data sesi, AI, dan webhook
│   │   ├── repositories/  # Klien Supabase PostgREST
│   │   ├── services/      # Ekstraksi fitur, Ridge regression, rekomendasi adaptif
│   │   └── routers/       # Endpoint /health, /webhook, /api/analytics
│   ├── simulator/         # Simulator hardware ESP32 DevKit V1
│   ├── tests/             # Pengujian otomatis pytest
│   ├── Dockerfile         # Kontainerisasi layanan AI
│   ├── docker-compose.yml # Orkestrasi kontainer
│   └── requirements.txt   # Dependensi pustaka Python
├── docs/                  # Dokumentasi teknis & rencana database
│   └── database-plan.md
├── fonts/                 # Tipografi Inter
├── ios/                   # Konfigurasi native iOS
├── lib/                   # Kode aplikasi Flutter
│   ├── models/            # Model data domain Dart (Session, Layout, AI, dll)
│   ├── services/          # Integrasi klien Supabase & Realtime
│   └── main.dart          # Antarmuka utama aplikasi
├── supabase/              # Artefak Backend Supabase
│   ├── functions/         # Edge Functions (device-heartbeat, session-webhook)
│   ├── migrations/        # Migrasi SQL PostgreSQL
│   └── schema.sql         # Skema DDL lengkap, RLS, seed data & RPC
├── pubspec.yaml           # Manajemen dependensi Flutter
└── README.md
```

---

## 🛠️ Panduan Memulai Cepat

### 1. Inisialisasi Database Supabase
1. Buat proyek baru di [Supabase Dashboard](https://supabase.com).
2. Buka menu **SQL Editor** pada proyek Anda.
3. Jalankan seluruh isi script [supabase/schema.sql](file:///f:/computing%20project/supabase/schema.sql).
4. Catat `Project URL`, `anon public key`, dan `service_role key` dari menu **Project Settings -> API**.

### 2. Menjalankan Backend AI & Analytics
```bash
cd backend
python -m venv venv
.\venv\Scripts\activate      # Windows
# source venv/bin/activate  # Linux/macOS

pip install -r requirements.txt
cp .env.example .env
# Edit .env dan masukkan SUPABASE_URL & SUPABASE_SERVICE_ROLE_KEY

# Jalankan server API
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Akses dokumentasi interaktif API di `http://localhost:8000/docs`.

### 3. Menjalankan Simulator ESP32 (Uji Alur Sesi)
Untuk menguji aliran data real-time tanpa alat fisik:
```bash
python backend/simulator/esp32_client.py --device SGT-01 --auto
```

### 4. Menjalankan Aplikasi Flutter
```bash
flutter pub get
flutter run
```
Untuk menjalankan versi Web:
```bash
flutter run -d chrome
```
