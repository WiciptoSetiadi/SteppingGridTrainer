# Stepping Grid Trainer

Flutter frontend pratinjau untuk Android, iOS, dan Web, mengikuti tiga layar pasien pada file Figma.

## Menjalankan aplikasi

Pasang Flutter stable 3.41.6 atau yang lebih baru, lalu jalankan:

```sh
flutter pub get
flutter run
```

Untuk membangun aplikasi Web:

```sh
flutter build web --release
```

Output web berada di `build/web`.

## Deploy Flutter Web ke Vercel

`vercel.json` mengarahkan Vercel untuk menjalankan `scripts/vercel-build.sh` dan menyajikan `build/web`. Build script memasang Flutter 3.41.6 ke cache build, lalu membuat rilis Flutter Web. Hubungkan repository ini ke Vercel dan deploy; tidak ada backend yang diperlukan untuk pratinjau ini.

Android dan iOS dibangun sebagai aplikasi mobile terpisah. Vercel hanya meng-host versi Web.

## Batas pratinjau ini

- Tidak ada Supabase, autentikasi, atau pencatatan sesi yang terhubung.
- Preferensi, perpindahan periode, dan status koneksi Wi-Fi hanya state sementara selama aplikasi berjalan.
- Koneksi Wi-Fi matras masih simulasi UI. Protokol pairing dan komunikasi perangkat belum ditentukan.
- Rancangan PostgreSQL Supabase ada di `docs/database-plan.md` dan `supabase/schema.sql`. SQL belum dijalankan.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
