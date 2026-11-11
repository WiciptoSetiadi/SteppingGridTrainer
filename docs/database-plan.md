# Rencana & Spesifikasi Database Supabase PostgreSQL

Status: **Diimplementasikan Lengkap** sesuai dengan Software Design Document (SDD) Versi 1.1 dan Software Requirement Specification (SRS) Versi 2.0.

File skema lengkap tersedia di:
- `supabase/schema.sql` (skema tunggal siap pakai)
- `supabase/migrations/20261111000000_full_schema.sql` (migrasi berbasis Supabase CLI)

---

## 1. Arsitektur & Relasi Database

Sistem dirancang dengan 11 tabel utama dan 2 view kompatibilitas:

| Nama Tabel | Deskripsi & Tujuan | Kunci Utama / Relasi |
| --- | --- | --- |
| `app_user` | Profil pasien yang terhubung ke Supabase Auth | `user_id` (PK, identity), `auth_uid` $\rightarrow$ `auth.users(id)` |
| `user_preferences` | Pengaturan aksesibilitas UI (ukuran font, kontras, audio) | `user_id` $\rightarrow$ `auth.users(id)` |
| `device` | Master perangkat hardware (control box ESP32) | `device_id` (PK), `device_code` (Unique) |
| `training_mode` | Master mode terapi (Sekuensial, Acak Reaksi, Tempo Dinamis) | `mode_id` (PK) |
| `layout` | Master 3 layout ubin modular (2×2, Horizontal 1×4, T-Shape) | `layout_id` (PK), `layout_code` (Unique) |
| `tile_position` | Master 12 posisi ubin fisik dan pemetaan port P1–P4 | `position_id` (PK), `layout_id` (FK) |
| `training_session` | Sesi latihan yang dijalankan pasien pada perangkat | `session_id` (PK), `user_id`, `device_id`, `mode_id` |
| `session_config` | Konfigurasi sesi (layout, target tempo, timeout, total target) | `session_id` (PK & FK 1:1) |
| `step_log` | Rekam kejadian tiap injakan kaki dan waktu inisiasi langkah | `step_log_id` (PK), `session_id` (FK), `step_number` (Unique) |
| `session_result` | Metrik agregat sesi (akurasi, waktu reaksi, rasio kiri-kanan) | `session_id` (PK & FK 1:1) |
| `ai_prediction` | Estimasi hari mencapai target akurasi 90% berbasis Ridge Regression | `prediction_id` (PK), `session_id` (FK) |
| `ai_recommendation` | Rekomendasi adaptif mode dan tempo untuk sesi berikutnya | `recommendation_id` (PK), `session_id` (FK) |

---

## 2. Seed Data Bawaan

### A. Layout Ubin Modular (`public.layout`)
1. **SQUARE_2X2**: Layout 2×2 (4 ubin: FL, FR, BL, BR), posisi awal `["BL", "BR"]`, pola: `["FR", "BR", "FL", "BL"]`.
2. **HORIZONTAL_1X4**: Layout Horizontal 1×4 (4 ubin: H1, H2, H3, H4), posisi awal `["H2", "H3"]`, pola: `["H4", "H3", "H1", "H2"]`.
3. **T_SHAPE**: Layout T (4 ubin: C, F, L, R), posisi awal `["C"]`, pola: `["F", "C", "L", "C", "R", "C"]`.

### B. Master Posisi Ubin (`public.tile_position`)
Tersedia 12 posisi ubin yang memetakan nomor port P1–P4 pada kontroler ESP32 ke posisi fisik dan penanda sisi kaki kiri/kanan (`side` = L/R/C) untuk perhitungan evaluasi perpindahan berat badan (*weight shifting*).

### C. Mode Latihan (`public.training_mode`)
- **Sekuensial** (ID 1, Aktif)
- **Acak Reaksi** (ID 2, Tersedia)
- **Tempo Dinamis** (ID 3, Tersedia)

### D. Perangkat Awal (`public.device`)
- Unit ID: `1`, Code: `SGT-01`, Label: `Stepping Grid Matras #01`.

---

## 3. Keamanan & Aksesibilitas Data (RLS)

- Seluruh tabel dilindungi dengan **Row Level Security (RLS)**.
- Pasien hanya dapat membaca dan menulis data miliknya sendiri melalui klaim JWT `auth.uid()`.
- Layanan sistem cerdas Python berkomunikasi menggunakan `service_role` key yang hanya ada di server cloud.
- Indeks unik parsial memastikan **hanya ada satu sesi aktif** (`waiting` atau `running`) per pasien dan per perangkat dalam satu waktu.

---

## 4. Stored Procedures & Supabase Realtime

- `create_session(...)`: Membuat baris `training_session` dan `session_config` secara atomik dalam satu transaksi database.
- `update_device_heartbeat(...)`: Memperbarui status online dan timestamp heartbeat ESP32.
- `get_daily_summary(...)`: Mengambil ringkasan sesi latihan harian dan rata-rata akurasi.
- **Supabase Realtime**: Terpasang pada tabel `training_session`, `step_log`, `device`, `session_result`, dan `ai_recommendation` untuk pembaruan instan (<1 detik) ke aplikasi mobile pasien.
