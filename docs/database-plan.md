# Rencana database PostgreSQL

Status: rancangan awal untuk backend Supabase di tahap berikutnya. SQL pada `supabase/schema.sql` belum dijalankan pada proyek Supabase mana pun.

## Pembagian layanan

- PostgreSQL akan disediakan oleh Supabase.
- Supabase Auth menjadi sumber identitas akun; `auth.uid()` dipakai untuk membatasi akses baris.
- Vercel akan meng-host hasil Flutter Web statis. Vercel bukan host database untuk rancangan ini.
- Frontend yang sekarang dibuat tidak terhubung ke Supabase dan tidak mengirim atau merekam data pasien maupun sesi latihan.

## Tabel awal

| Tabel | Tujuan | Kunci pemilik |
| --- | --- | --- |
| `profiles` | Preferensi nama tampilan dasar yang terkait ke akun Supabase Auth | `id = auth.users.id` |
| `user_preferences` | Preferensi tampilan dan umpan balik UI | `user_id = auth.users.id` |
| `matras_devices` | Identitas perangkat yang ditautkan ke akun; tidak menyimpan kredensial jaringan | `user_id = auth.users.id` |

Setiap tabel mengaktifkan Row Level Security dan membatasi operasi pengguna ke baris miliknya. Kredensial Wi-Fi tidak disimpan di PostgreSQL. Cara provisioning dan protokol komunikasi Wi-Fi matras masih perlu ditentukan sebelum integrasi perangkat.

## Data latihan ditunda

Tabel sesi latihan, metrik, data langkah, kalibrasi, dan catatan fisioterapis belum dimasukkan ke SQL awal. Bentuk, tujuan, masa simpan, dan izin akses data tersebut perlu disepakati sebelum pencatatan dibuat. Dengan begitu, frontend pratinjau tidak mengunci definisi data yang belum ditentukan.

## Langkah saat backend dimulai

1. Buat proyek Supabase dan aktifkan autentikasi yang dipilih.
2. Tinjau serta jalankan migrasi SQL setelah kebijakan privasi dan model akun disetujui.
3. Tambahkan klien Supabase ke aplikasi dan gunakan anon key melalui konfigurasi build; jangan menanam service-role key di aplikasi.
4. Tentukan metode pairing Wi-Fi, identitas perangkat, dan protokol komunikasi dengan firmware matras.
5. Rancang tabel sesi beserta RLS setelah format data dan aturan retensi disepakati.
