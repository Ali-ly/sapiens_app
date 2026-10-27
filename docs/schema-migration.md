# Phase 2 — Legacy Data Migration & Schema Upgrade

Schema aktif adalah **5**, minimum reader **5**, shared foundation **2**, dengan
namespace Beef/Dairy tetap versi **1**. Tidak ada workflow domain baru.

## Envelope dan downgrade

```json
{
  "format": "sapiens.farm",
  "schemaVersion": 5,
  "minimumReaderVersion": 5,
  "data": {
    "farmId": "...",
    "farmIdentityOrigin": "legacyDerived",
    "foundation": {"version": 2},
    "farmer": "...",
    "farm": "...",
    "reminderDays": 7,
    "demo": false,
    "cattle": [],
    "feedPlans": [],
    "groups": [],
    "groupFeedPlans": [],
    "legacyMemberships": []
  }
}
```

Export menambah `exportedAt` pada envelope sebagai waktu pembuatan backup,
bukan timestamp observasi. Preview/import tidak menulis data. Tidak tersedia
export downgrade ke schema 4 karena dapat membuang fondasi baru.

Payload tidak memiliki alias root `cattle`/`farmer`/`farm`. Ini disengaja:
reader pertama di repo (`22c533c`) mengabaikan versi pada load, tetapi memakai
cast wajib field root dan memblokir write setelah load gagal. Envelope membuat
reader itu gagal sebelum mempublikasikan state. Reader `cc1f696`, `4492edd`, dan
baseline Phase 1 menolak schema 5 secara eksplisit dan memiliki write guard.
Restore versi lama juga menolak backup schema 5.

Uji terhadap salinan source historis tanpa modifikasi production code
mengonfirmasi guard tersebut dan membuktikan marker versi saja tidak cukup
untuk reader pertama. Ini bukan jaminan terhadap setiap binary di luar riwayat
repo, client yang mengabaikan error, atau pengguna yang sengaja mengganti data
lewat restore backup lama. Format/nomor versi bukan mekanisme autentikasi.

Storage key/browser origin dan lokasi file native tetap sama. Mengganti key
akan membuat data lama tidak terbaca dan tidak menyelesaikan migrasi.

## Alur migrasi

1. Decode shape unversioned/2/3/4 yang benar-benar didukung; cek field, tipe,
   enum, versi, histori dan referensi terlebih dahulu. Field persisted yang
   tidak dikenali ditolak agar tidak dibuang diam-diam. Whitelist mengikuti
   versi: unversioned/2 tidak menerima field kelompok; 3 memakai groups +
   memberships; 4/5 memakai groups + groupFeedPlans + legacyMemberships. Alias
   dari versi lain ditolak meskipun berisi array kosong atau data yang sama,
   karena decoder tidak boleh diam-diam mengabaikan salah satu histori. Field
   farmId/origin pada payload legacy juga ditolak; kepemilikan field itu mulai
   schema 5, bukan metadata lama yang boleh ditebak asal-usulnya.
2. Unversioned/2 memakai model individual lama. Versi 3 membentuk snapshot
   kelompok turunan dan mempertahankan membership lama sebagai arsip read-only.
   Versi 4 mempertahankan seluruh histori kelompok dan fondasi versi 1 existing.
3. `SnapshotUpgrade.complete` mengisi identitas farm/record/media yang belum ada,
   menautkan PhotoRecord existing ke media stabil, dan memvalidasi model final.
   Fungsi ini murni: tanpa clock, random, write atau event sintetis.
4. `FarmStore.load` menulis schema 5 setelah validasi dan sebelum menerbitkan
   snapshot hasil migrasi. Write gagal mempertahankan snapshot sebelumnya,
   menyimpan error dan memblokir mutasi normal sampai recovery/reload berhasil.
5. Load schema 5 hanya memvalidasi/membaca; tidak backfill diam-diam atau rewrite.
   Impor legacy memakai jalur yang sama. Restore tetap replacement eksplisit
   dengan konfirmasi UI existing dan publish sesudah write berhasil.

Farm baru mendapat nonce lokal dari secure RNG dan dipersist saat inisialisasi
kosong berhasil, sehingga ID tetap sama walau belum ada sapi. Kegagalan write
awal tidak mempublikasikan farm sementara dan tidak dapat diekspor sebagai
backup yang seolah valid. Satu instance tetap memakai antrean write existing;
ini belum mengunci penulisan dari beberapa tab/proses/perangkat.

## Identitas deterministik

Legacy farm tanpa ID: `farm-legacy-` + SHA-256 dari UTF-8 JSON array
`["farm-v1", farmer, farm, sorted(cattleIds), sorted(groupIds)]`.
Origin disimpan sebagai `legacyDerived`. Perubahan histori, urutan key JSON,
atau exportedAt tidak mengubah seed. Setelah ID tersimpan, rename atau perubahan
koleksi tidak menghitung ulang ID.

Farm baru: `farm-local-` + nonce 128-bit; origin `localRandom`. Backup/restore
mempertahankan ID dan origin. Keduanya bukan bukti kepemilikan atau jaminan
identitas global: backup legacy yang tidak dapat dibedakan dan clone backup
akan memiliki ID sama. Nama/anggota yang berbeda pada snapshot pra-migrasi
juga dapat menghasilkan ID legacy berbeda untuk farm fisik yang sama. Sinkronisasi
nanti harus melakukan binding/rekonsiliasi, bukan auto-merge berdasarkan nama.

Bobot/media tanpa ID: `{weight|media}-backfill-` + SHA-256 array
`["slot-v1", farmId, cattleId, originalIndex]`. Index membedakan timestamp, bobot,
bytes dan nama foto yang identik. Semua ID existing dicadangkan sebelum alokasi;
collision candidate diselesaikan dengan suffix deterministik. ID existing tidak
diganti. ID bobot/media existing yang ambigu/duplikat ditolak, bukan dinomori
ulang diam-diam.

Media tetap `SelectedImage` berisi bytes read-only, nama eksplisit, file handle
kompatibilitas, dan ID. `withId` memakai buffer immutable yang sama. Tidak ada
pemindahan file, kompresi atau konversi format foto; base64 tetap dipakai.
PhotoRecord existing tetap memiliki index lama dan mendapat `mediaId` ke foto
itu; kedua referensi divalidasi konsisten. Galeri legacy hanya mendapat identitas,
bukan tanggal capture, sumber AI, link bobot atau event foto rekaan.

## Timestamp dan provenance

`PersistedTime` menyimpan literal asal pada model bobot, plan, kelompok,
membership dan shared record. Offset eksplisit (`Z`, `+07:00`, dll.) dan string
local tanpa offset tetap diekspor dengan teks yang sama. Tanggal kalender/offset
invalid ditolak, tidak dinormalisasi menjadi tanggal lain.

DateTime view memakai aturan parsing local yang sudah dipakai aplikasi. String
tanpa offset tidak dinyatakan sebagai UTC; `TimestampBasis.legacyLocalUnknown`
menandai ketidakpastian ini. Asal timezone tidak dapat direkonstruksi. Data baru
yang memang dibuat dengan clock aplikasi diserialkan UTC bila tidak membawa
literal asal. Mapper plan mempertahankan literal waktu bobot yang dirujuk,
sehingga konteks plan baru tidak memberi kepastian UTC palsu pada bobot legacy.

Plan lama tetap menyimpan weight/date snapshot yang ada. Migrasi tidak menebak
referensi WeightRecord baru untuk plan berdasarkan timestamp duplikat. Link
weightRecordId yang sudah eksplisit pada PhotoRecord dipertahankan.

Migrasi kelompok schema 3 tidak lagi memakai waktu load. Catatan proyeksi awal
memakai `archivedAt`, atau `createdAt` jika tidak diarsipkan, sebagai **anchor**
deterministik dengan `source=migration` dan `timeBasis=legacyAnchor`. Itu bukan
waktu observasi/migrasi. UI menyebutnya waktu acuan. Membership, jumlah aktif
dan bobot rata-rata diturunkan dengan aturan kompatibilitas existing tanpa
workflow membership baru. Record migrasi schema 4 yang sudah tersimpan tidak
dituliskan ulang waktunya; jika belum memiliki basis, ditandai legacyUnspecified.
Tidak ada event ternak/status/kesehatan buatan akibat upgrade.

## Umur dan production context

`ageMonths` tetap nilai observasi lama. `AgeEvidence` membedakan exact,
estimated dan unknown. Legacy menjadi estimated, tanpa birthDate atau as-of
rekaan. Exact memerlukan tanggal lahir eksplisit yang valid; unknown tidak
mengandung tanggal lahir. Tidak menghitung mundur DOB dari umur atau histori.
UI/form lama tetap memasukkan estimasi bulan; mengubah nilainya mereset bukti
usia ke estimated tanpa mempertahankan klaim DOB exact yang bertentangan.

productionSystems dan productionCategory null tetap unclassified, termasuk
ketika gender/target pakan/namespace domain mungkin memberi petunjuk. Beef/Dairy
namespace versi 1 serta seluruh payload/histori existing tetap dipertahankan.
Tidak ada klasifikasi massal, rumus nutrisi baru atau workflow Dairy di tahap ini.

## Verifikasi dan batas berikutnya

Fixture JSON merepresentasikan format repo unversioned/2/3/4 dan golden schema 5.
Timestamp duplikat, foto identik, offset unknown/eksplisit, plan historis,
namespace domain, referensi foto/bobot dan status keluar disertakan. Bundle
Dart digenerate untuk tes VM/Chrome dan dicek CI agar tidak berbeda dari JSON.

Phase 3 perlu memutuskan UX klasifikasi, usia unknown/as-of, timeline dan exit;
category-aware plan/domain routing; rekonsiliasi farm legacy saat sync;
referensi media saat delete/reorder; dan aturan analisis waktu ambigu. Jangan
mengubah DOB/zone/provenance yang tidak diketahui menjadi fakta. Belum ada
cloud, auth, database rewrite, IoT, Halo Moo atau perubahan threshold ilmiah.

Sebelum menjalankan upgrade pada data perangkat nyata, simpan backup lama dan
uji pada salinan dengan origin/path yang sama. Adapter existing tetap menulis
file sementara lalu rename (native) dan localStorage (web). Tes injection tidak
membuktikan crash/power-loss, quota perangkat, atau koordinasi multi-tab nyata.
