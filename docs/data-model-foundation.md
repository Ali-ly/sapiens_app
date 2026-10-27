# Phase 1 — Data Model Foundation

Catatan historis Phase 1. Schema aktif dan aturan upgrade sekarang dijelaskan
di [Phase 2 — Schema Migration](schema-migration.md); keputusan schema 4 di bawah
merupakan baseline sebelum upgrade, bukan format write aktif saat ini.

Model ini menambah fondasi data tanpa mengganti penyimpanan lokal, API backend,
atau flow sapi individual. Setup farm dan workflow lengkap Beef/Dairy belum
termasuk tahap ini.

## Komposisi

`FarmSnapshot.productionSystems` bertipe `FarmProductionSystems` (`beef`,
`dairy`, `both`). `null` menyatakan data lama belum diklasifikasikan. Hanya sapi
baru di farm single-system yang otomatis mendapat kategori. Farm Both mewajibkan
kategori saat membuat sapi baru; data lama tidak otomatis dijadikan Beef.
Perubahan sistem farm ditolak jika bertentangan dengan kategori sapi tersimpan,
termasuk sapi nonaktif. Perubahan kategori eksplisit memerlukan alasan dan
menambah event dengan kategori sebelum/sesudah; histori tidak dibuang.

`Cattle` adalah facade kompatibilitas layar/service untuk ID, `SharedTwinCore`,
dan `TwinModules`. Core terdiri dari:

- `TwinIdentity`: nama, gender, umur bulan, catatan, kategori produksi opsional.
- `TwinWeight`: nilai estimasi terakhir, konteks prediksi, histori bobot.
- `TwinPhotos`: galeri, foto peninjauan sementara, histori metadata foto.
- `TwinLifecycle`: histori status dan tahap hidup yang dicatat manual.
- Catatan kesehatan/preventif, event timeline, dan referensi induk/ID eksternal.

`BeefExtension` dan `DairyExtension` baru namespace bertipe dengan versi 1,
tanpa payload bisnis. Kedua namespace dapat tetap ada ketika kategori berubah.
Implementasi berikutnya harus mengembangkan model/codec domain tersendiri,
bukan menambahkan seluruh field Beef/Dairy ke `Cattle`.

## Mutasi dan histori

Semua mutasi memakai antrean transaksi `FarmStore` yang sudah ada. State baru
diterbitkan hanya setelah write berhasil. `recordWeight`, `addPhotos`,
`recordHealth`, `recordLifeStage`, `setCattleStatus`, dan `setProductionCategory`
menambah histori/event dari snapshot terkini. `updateIdentity` serta
`updateReferences` mengganti metadata yang dituju tanpa menyentuh histori.

`saveCattle` dipertahankan bagi pemanggil lama. Untuk ID existing, bobot dan
galeri harus mempertahankan seluruh prefix lama dan metadata fondasi harus
sama. Payload stale atau perubahan fondasi lewat replacement ditolak. Untuk
fitur baru, gunakan mutasi yang spesifik, bukan full-object replacement.

ID baru dialokasikan di dalam transaksi dan diperiksa terhadap semua ID yang
tersimpan (termasuk Twin nonaktif, histori dan plan), serta ID yang dialokasikan
dalam sesi tersebut. Clock yang sama/reload tidak boleh menimpa entitas lama.
Ini bukan protokol sinkronisasi multi-device atau penguncian beberapa tab.

`savePlan` dan `saveGroupPlan` bersifat append-only menurut ID: payload berbeda
untuk ID lama ditolak; payload identik adalah retry tanpa write. Retry identik
tetap diperbolehkan ketika input telah berubah atau sapi telah diarsipkan,
karena tidak menciptakan rencana baru. Rencana baru tetap harus cocok dengan
input aktif. Timestamp plan diserialkan sebagai UTC; pencocokan tanggal bobot
membandingkan instant, bukan bentuk UTC/local.

## Status keluar dan arsip

`active`, `sold`, `culled`, `slaughtered`, `transferred`, `deceased`, `archived`
merupakan status bersama, bukan penghapusan data. `remove` sekarang alias arsip
untuk kompatibilitas pemanggil. Bobot, foto, event, referensi, dan rencana pakan
tetap tersimpan. `cattle` adalah daftar operasional aktif; `allCattle` dan `byId`
mempertahankan akses ke seluruh Twin. Ringkasan dan total pakan hanya memakai
sapi aktif. Daftar Ternak menyediakan filter Arsip; profil nonaktif read-only
untuk edit/bobot/pakan baru, dan arsip dapat dipulihkan.

Status keluar selain arsip saat ini tersedia pada API store, belum melalui
form UI keluar ternak. API status mendukung koreksi eksplisit kembali aktif;
aturan izin/konfirmasi untuk kasus tersebut merupakan workflow lanjutan.
Pembersihan data contoh juga mengarsipkan Twin beserta histori rencananya.

## Kontrak JSON dan kompatibilitas

**Schema utama tetap 4. Tidak ada migrasi massal otomatis pada load.** Encoder
menambah envelope root `foundation: {version: 1, productionSystems?: ...}` bila
ada data baru, dan blok `foundation` versi 1 per sapi bila diperlukan. Field
legacy galeri dan bobot tetap berada di lokasi lama. ID bobot opsional supaya
catatan lama tidak diberi identitas atau waktu rekaan. Galeri lama tidak diberi
histori foto rekaan; foto baru merujuk index galeri yang hanya boleh bertambah,
dan dapat merujuk ID catatan bobot.

Versi 2/3/4 dan format legacy yang sudah didukung tetap dibaca. Data tanpa blok
baru tetap unassigned dan tanpa histori buatan. Load tidak menulis ulang disk.
Struktur, enum, versi/field baru yang tidak dikenal, ID histori duplikat,
referensi hilang/siklus, urutan histori tidak valid, serta kategori farm yang
bertentangan ditolak. Decode gagal tidak menimpa snapshot/disk yang valid.
Restore backup tetap operasi replacement seluruh snapshot yang disengaja,
dengan konfirmasi UI existing; bukan mutasi append-only harian.

**Aplikasi lama schema 4 dapat mengabaikan lalu menghapus blok fondasi saat
menyimpan.** Data yang sudah berisi fondasi tidak aman diedit/di-round-trip
melalui build lama. Phase 2 harus menetapkan schema/reader-version gate dan
strategi upgrade/rollback sebelum distribusi campuran. Penolakan field/versi
baru di reader ini mencegah kehilangan metadata pada pembaca berikutnya.

## Batas yang dipertahankan

`SelectedImage` masih berisi `XFile` dan byte read-only. Uji roundtrip legacy
menemukan bahwa XFile.fromData tidak mempertahankan nama file pada VM/native
seperti di web. Karena itu nama foto kini disimpan sebagai metadata eksplisit
`SelectedImage.name`, dipakai codec dan nama multipart upload. Picker tetap
memberi default dari file.name; decoder memberi nama dari JSON. Ini pemisahan
metadata minimal berdasarkan bug konkret, tanpa refactor seluruh media/domain
atau perubahan decoder preview yang sudah diuji. Tidak ada optimasi foto atau
perubahan format base64.

Belum ada farm ID/multi-farm, tanggal lahir pengganti umur statis, threshold
ilmiah, workflow produksi/reproduksi/laktasi, UI kesehatan, library pakan Dairy,
cloud, Halo Moo, atau IoT. Setup sistem produksi dan migrasi data legacy
memerlukan UX dan kebijakan eksplisit pada tahap berikutnya.
