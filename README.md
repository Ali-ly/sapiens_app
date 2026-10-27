# SAPIENS

MVP Flutter baru untuk peternak sapi Potong atau Perah. Mode ditetapkan di akun lokal; satu sapi menjadi konteks pencatatan dan evaluasi. Navigasi: Beranda, Ternak, Pakan, Profil.

## Menjalankan

Diuji dengan Flutter 3.24.5 / Dart 3.5.4.

```sh
flutter pub get
flutter run -d chrome --web-port 8736
```

Gateway default: `https://almighty-haphazard-pawing.ngrok-free.dev`. Mengganti lingkungan:

```sh
flutter run -d chrome --dart-define=API_BASE_URL=https://gateway.example
```

Backend perlu menyediakan CORS untuk origin web yang digunakan. Data web terikat origin: gunakan port yang konsisten dan ekspor cadangan sebelum pindah origin/perangkat. Tidak ada seed data produksi.

## Verifikasi

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --concurrency 1
flutter test --platform chrome
flutter build web --release
```

Pengujian live terpisah dan opt-in; hanya memakai ternak sintetis serta foto publik yang diberikan lewat path:

```sh
flutter test --dart-define=LIVE_GATEWAY=true --dart-define=LIVE_PHOTO=/absolute/path/public-cow.jpg tool/live_gateway_test.dart
flutter test --platform chrome --dart-define=LIVE_GATEWAY=true test/live_gateway_test.dart
```

## Batas MVP

Akun dan data tersimpan lokal, tanpa login/cloud. Ekspor/impor cadangan tersedia. Mengganti mode dengan konfirmasi `GANTI` menghapus seluruh data sapi dalam akun lokal. Frontend lama dan format penyimpanannya tidak dipakai atau dimigrasikan.

Lihat [arsitektur](docs/architecture.md), [kontrak dan keterbatasan backend](docs/backend-contract.md), dan [hasil verifikasi](docs/mvp-report.md).
