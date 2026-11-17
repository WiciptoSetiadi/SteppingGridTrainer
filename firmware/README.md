# Panduan Koneksi Perangkat IoT ESP32 - Stepping Grid Trainer

Dokumen ini menjelaskan secara lengkap cara menghubungkan mikrokontroler **ESP32 DevKit V1** dengan sistem **Stepping Grid Trainer** (Aplikasi Mobile Flutter, Frontend Web, Supabase Cloud Database, dan Backend AI Analytics).

---

## 🏗️ 1. Arsitektur Komunikasi IoT

Sistem Stepping Grid Trainer menggunakan arsitektur **Cloud-Connected IoT** dengan jembatan utama **Supabase Cloud REST API & Realtime Webhooks**:

```
[Aplikasi Pasien]                [Supabase Cloud Database]              [Hardware ESP32 Matras]
 (Flutter / Web)                 (rtvtralxxvzxitdqjrco)                     (DevKit V1)
       |                                    |                                    |
       | 1. Pasien klik "Mulai Latihan"     |                                    |
       |----------------------------------->|                                    |
       |    Status sesi: 'waiting'          |                                    |
       |                                    | 2. ESP32 Polling Sesi (tiap 2 dtk) |
       |                                    |<-----------------------------------|
       |                                    |    Menerima: Layout, Tempo, Pola   |
       |                                    |----------------------------------->|
       |                                    |                                    |
       |                                    | 3. Ubah status sesi: 'running'     |
       |                                    |<-----------------------------------|
       |                                    |                                    |
       |                                    | 4. Pasien melangkah pada ubin matras
       |                                    |    - LED sasaran menyala           |
       |                                    |    - Sensor kaki tertekan          |
       |                                    |    - Buzzer konfirmasi berbunyi    |
       |                                    |                                    |
       |                                    | 5. Kirim data langkah (step_log)   |
       |                                    |<-----------------------------------|
       |                                    |                                    |
       |                                    | 6. Sesi berakhir: 'completed'      |
       |                                    |<-----------------------------------|
       |                                    |                                    |
       | 7. Hasil evaluasi & saran AI       |                                    |
       |<-----------------------------------|                                    |
```

---

## 🔌 2. Skema Wiring & Pinout ESP32 DevKit V1

Perangkat menggunakan 4 port modul ubin (**P1, P2, P3, P4**), 1 buzzer nada, dan indikator status Wi-Fi.

| Port / Modul | Fungsi Komponen | Tipe Pin | Pin GPIO ESP32 | Keterangan Sambungan |
| :--- | :--- | :--- | :--- | :--- |
| **Port P1** | Sensor Injak Ubin 1 | Digital INPUT | **GPIO 18** | Terhubung ke Saklar/Sensor Ubin (ke GND, Internal Pull-Up) |
| **Port P1** | Lampu LED Ubin 1 | Digital OUTPUT | **GPIO 13** | Terhubung ke Anoda (+) LED melalui resistor 220Ω |
| **Port P2** | Sensor Injak Ubin 2 | Digital INPUT | **GPIO 19** | Terhubung ke Saklar/Sensor Ubin (ke GND, Internal Pull-Up) |
| **Port P2** | Lampu LED Ubin 2 | Digital OUTPUT | **GPIO 14** | Terhubung ke Anoda (+) LED melalui resistor 220Ω |
| **Port P3** | Sensor Injak Ubin 3 | Digital INPUT | **GPIO 22** | Terhubung ke Saklar/Sensor Ubin (ke GND, Internal Pull-Up) |
| **Port P3** | Lampu LED Ubin 3 | Digital OUTPUT | **GPIO 27** | Terhubung ke Anoda (+) LED melalui resistor 220Ω |
| **Port P4** | Sensor Injak Ubin 4 | Digital INPUT | **GPIO 23** | Terhubung ke Saklar/Sensor Ubin (ke GND, Internal Pull-Up) |
| **Port P4** | Lampu LED Ubin 4 | Digital OUTPUT | **GPIO 26** | Terhubung ke Anoda (+) LED melalui resistor 220Ω |
| **Buzzer** | Umpan Balik Suara | PWM OUTPUT | **GPIO 25** | Terhubung ke Pin Positif Buzzer Pasif |
| **Status Wi-Fi** | Indikator Online | OUTPUT | **GPIO 2** | LED On-Board ESP32 (Menyala jika Wi-Fi terkoneksi) |
| **GND** | Ground Bersama | Power | **GND** | Sambungkan seluruh Katoda (-) LED dan Saklar ke GND |

> [!TIP]
> **Sensor Ubin**: Menggunakan mode `INPUT_PULLUP`. Saklar ubin atau sensor pijakan menghubungkan pin GPIO ke `GND` saat diinjak (Active LOW). Tidak memerlukan resistor eksternal tambahan untuk sensor.

---

## 💻 3. Persiapan & Upload Firmware melalui Arduino IDE

### Langkah 1: Instalasi Board ESP32 di Arduino IDE
1. Buka **Arduino IDE** (versi 2.x disarankan).
2. Masuk ke menu **File $\rightarrow$ Preferences**.
3. Di kolom **Additional boards manager URLs**, tambahkan URL:
   ```text
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
4. Buka **Tools $\rightarrow$ Board $\rightarrow$ Boards Manager**, cari `esp32` oleh *Espressif Systems*, lalu klik **Install**.

### Langkah 2: Instalasi Library Tambahan
Buka **Tools $\rightarrow$ Manage Libraries...**, cari dan instal library:
- **ArduinoJson** (oleh *Benoit Blanchon*, versi 6.21.x atau versi 7.x).

*(Library `WiFi.h`, `WiFiClientSecure.h`, dan `HTTPClient.h` sudah otomatis terinstal bersama board ESP32).*

### Langkah 3: Buka & Konfigurasi Kode Firmware
1. Buka file:
   `firmware/esp32_stepping_grid/esp32_stepping_grid.ino`
2. Sesuaikan konfigurasi Wi-Fi di baris 20-21:
   ```cpp
   const char* WIFI_SSID     = "NAMA_WIFI_RUMAH_ANDA";
   const char* WIFI_PASSWORD = "PASSWORD_WIFI_ANDA";
   ```
3. Konfigurasi Supabase sudah terisi otomatis sesuai project Anda (`rtvtralxxvzxitdqjrco.supabase.co`).

### Langkah 4: Upload ke Board ESP32
1. Hubungkan ESP32 DevKit V1 ke PC/Laptop menggunakan kabel Micro-USB atau USB-C.
2. Di Arduino IDE:
   - Pilih Board: **DOIT ESP32 DEVKIT V1** (atau *ESP32 Dev Module*).
   - Pilih Port: Port COM perangkat (misal `COM3`, `COM4`).
3. Klik tombol **Upload** (tanda panah ke kanan).
4. Jika proses upload menampilkan *"Connecting........_____"*, tekan dan tahan tombol **BOOT** pada board ESP32 selama 2 detik hingga proses flash berjalan.

---

## 🧪 4. Menguji Koneksi (Serial Monitor)

Setelah selesai di-upload:
1. Buka **Tools $\rightarrow$ Serial Monitor** di Arduino IDE.
2. Atur baud rate ke **115200 baud**.
3. Tekan tombol **EN / RST** pada board ESP32.
4. Anda akan melihat log proses seperti ini:
   ```text
   ==============================================
     STEPPING GRID TRAINER - ESP32 DevKit V1
     Sistem Terapi Jalan Pasca-Stroke IoT
   ==============================================
   [WiFi] Menghubungkan ke WIFI_ANDA
   .....
   [WiFi] Terhubung! IP: 192.168.1.45
   [IoT] Heartbeat terkirim: Device SGT-01 ONLINE
   ```

Pada aplikasi Stepping Grid Trainer (tab Beranda atau Pengaturan), banner status matras akan otomatis berstatus:
> **Matras terhubung via Wi-Fi · SGT-01 · Siap digunakan (Online)** ✅

---

## 🚀 5. Cara Menjalankan Sesi Latihan Bersama Perangkat

1. Buka aplikasi (Flutter atau Frontend Web).
2. Di halaman **Beranda**, tekan tombol **Mulai Latihan**.
3. Pilih tata letak ubin (misal `Layout 2×2`), mode latihan (`Sekuensial`), dan tempo yang diinginkan.
4. Tekan **Mulai Sesi Latihan**.
5. Seketika itu juga:
   - ESP32 mendeteksi sesi `waiting`.
   - Buzzer membunyikan nada pembuka (C5 - E5 - G5).
   - LED sasaran pertama menyala memandu langkah.
   - Pasien menginjak ubin. Jika benar $\rightarrow$ bunyi nada konfirmasi tinggi (880 Hz), data `step_log` terkirim ke Supabase, dan sasaran berpindah ke ubin berikutnya.
   - Setelah 20 target tercapai $\rightarrow$ sesi otomatis `completed`, dan model AI menghitung akurasi, waktu reaksi, dan rekomendasi baru.

---

## 🛠️ 6. Menguji Tanpa Hardware Fisik (Software Simulator)

Jika board ESP32 fisik sedang belum dirakit, Anda dapat menjalankan simulator Python bawaan:
```bash
# Masuk ke folder backend
cd backend

# Jalankan simulator ESP32 (otomatis polling sesi)
python simulator/esp32_client.py --auto
```
Simulator ini memiliki fungsi yang sama persis dengan firmware ESP32 di atas.
