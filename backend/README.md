# Stepping Grid Trainer - Backend AI & Analytics Service

Layanan backend cerdas berbasis Python (FastAPI, NumPy, scikit-learn) untuk sistem terapi jalan pasca-stroke **Stepping Grid Trainer**.

Sesuai spesifikasi **Software Design Document (SDD) Subbab 3.2.8 - 3.2.10, 7.6** dan **Software Requirement Specification (SRS) FR-05, FR-06, FR-07**.

---

## 🌟 Fitur Utama

1. **Modul Ekstraksi Fitur Sesi (M-08 / FR-05)**:
   - Menghitung akurasi langkah (`accuracy_percent`).
   - Menghitung rata-rata waktu reaksi (`average_reaction_ms`).
   - Menghitung durasi sesi (`total_duration_ms`).
   - Menghitung rasio langkah kiri-kanan (`left_right_ratio`) untuk evaluasi *weight shifting* dan simetri bilateral berdasarkan layout (2×2, Horizontal 1×4, T-Shape).
   - Menyimpan metrik ke tabel `session_result`.

2. **Modul Prediksi Estimasi Capai Target (M-09 / FR-07)**:
   - Model regresi linear dengan regularisasi (*Ridge Regression* `linreg-v1`).
   - Estimasi waktu (hari/sesi) pasien mencapai target pemulihan akurasi 90%.
   - Perhitungan *confidence score* berdasarkan kecocokan model ($R^2$) dan jumlah riwayat sesi (minimal 5 sesi).
   - Penanganan outlier (*winsorizing*) dan deteksi tren non-positif.
   - Menyimpan hasil ke tabel `ai_prediction`.

3. **Modul Rekomendasi Adaptif (M-10 / FR-06)**:
   - Penyesuaian tempo otomatis: percepat 10% jika akurasi $\ge 90\%$, perlambat 15% jika akurasi $< 70\%$, pertahankan tempo jika akurasi $70\% - 89\%$.
   - Kenaikan mode latihan otomatis (misal *Sekuensial* $\rightarrow$ *Acak Reaksi*) setelah 3 sesi berturut-turut mencapai akurasi $\ge 90\%$.
   - Pembangkitan teks motivasi dan edukasi dalam Bahasa Indonesia yang ramah bagi lansia.
   - Menyimpan hasil ke tabel `ai_recommendation`.

4. **Webhook & API Integration**:
   - `POST /webhook/session-completed`: Dipicu otomatis oleh Database Webhook Supabase saat status sesi menjadi `completed`. Mengembalikan respons cepat `202 Accepted` dan mengeksekusi pipeline di background task.
   - `POST /api/sessions/{session_id}/analyze`: Endpoint on-demand / manual testing.
   - `GET /health`: Health-check endpoint.

5. **Simulator ESP32 DevKit V1**:
   - Simulator hardware di `simulator/esp32_client.py` untuk menguji alur langkah, debounce, pengiriman log, heartbeat, dan penyelesaian sesi tanpa hardware fisik.

---

## 🚀 Panduan Menjalankan Layanan

### Prasyarat
- Python 3.10+ atau Docker & Docker Compose
- Proyek Supabase aktif (lokal atau cloud di supabase.com)

### 1. Instalasi Dependensi Lokal
```bash
cd backend
python -m venv venv
# Windows:
.\venv\Scripts\activate
# Linux/macOS:
source venv/bin/activate

pip install -r requirements.txt
```

### 2. Konfigurasi Variabel Lingkungan (`.env`)
Salin file template:
```bash
cp .env.example .env
```
Isi konfigurasi pada `.env`:
```ini
SUPABASE_URL=https://<your-project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<your-service-role-key>
WEBHOOK_SECRET=your-secret-if-enabled
```

### 3. Menjalankan Server FastAPI
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Buka dokumentasi interaktif Swagger UI di browser:
- [http://localhost:8000/docs](http://localhost:8000/docs)

### 4. Menjalankan dengan Docker
```bash
docker compose up --build -d
```

### 5. Menjalankan Unit Tests
```bash
pytest
```

---

## 🤖 Menjalankan Simulator ESP32

Simulator mensimulasikan control box ESP32 yang terhubung ke 4 ubin:
```bash
# Melakukan 1 kali pemeriksaan dan simulasi sesi latihan:
python simulator/esp32_client.py --device SGT-01

# Menjalankan daemon mode otomatis (polling tiap 2 detik):
python simulator/esp32_client.py --device SGT-01 --auto
```
