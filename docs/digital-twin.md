# Fondasi 2 — Digital Twin Ternak

SAPIENS mengutamakan peternak kecil melalui profil sapi individual. Alur utama: **Tambah sapi → profil → bobot → pakan → riwayat**. Pengguna tidak perlu membuat kandang. Kelompok/kandang adalah entitas bulk mandiri yang opsional bagi peternak dengan ternak banyak.

## Flow utama

Home menampilkan **Tambah sapi pertama** jika belum ada sapi, atau **Lihat sapimu** untuk membuka daftar sapi. Tab **Ternak** langsung membuka daftar individual dengan pencarian, filter, dan tombol tambah. Menyimpan sapi baru langsung membuka profilnya; bobot manual/estimasi foto mengaktifkan perhitungan pakan. Riwayat bobot dan rencana tetap berada pada profil yang sama.

Tab **Pakan** mengutamakan rencana per sapi. Rekap persiapan pakan membuka cakupan individual meski sudah ada kelompok. Data kelompok tidak mengalihkan default flow tersebut.

## Flow kelompok opsional

1. Buka **Ternak → Kelompok/kandang (opsional)**. Tautan tambahan juga tersedia di bagian bawah Ringkasan dan Pakan. Kelompok dibuka pada halaman terpisah; tombol kembali mengembalikan konteks individual.
2. Buat kelompok: nama, jumlah sapi, bobot rata-rata (boleh belum diisi), target pemeliharaan, dan catatan.
3. Setelah jumlah lebih dari nol dan bobot rata-rata tersedia, buka perhitungan pakan; pilih bahan yang tersedia.
4. API menghitung takaran per ekor dari bobot rata-rata. Aplikasi menampilkan takaran per ekor, total kelompok per hari, serta rincian bahan. Simpan hasil ke kelompok.
5. Edit jumlah, bobot, atau target saat kondisi berubah. Setiap penyimpanan menambah histori; input pakan yang berubah meminta perhitungan ulang. Riwayat hasil lama tetap dapat dibuka dengan input aslinya.
6. Di **Pakan → Persiapan pakan**, pilih cakupan kelompok atau individual dan jumlah hari. Pintasan **Rekap pakan kelompok** di daftar kelompok langsung membuka cakupan kelompok. Keduanya tidak dijumlahkan otomatis, karena profil individual mungkin mewakili sapi yang sama.

Kelompok dengan jumlah nol boleh disimpan, tetapi perhitungan pakan dinonaktifkan. Arsip dapat dilakukan meski jumlah sapi masih terisi. Arsip menyimpan semua data dan mengeluarkan kelompok dari rekap aktif; pemulihan tidak menghapus riwayat.

## Model dan persistensi

`LivestockGroup` menyimpan ID, tanggal dibuat, dan histori immutable `GroupRecord`. Setiap catatan berisi snapshot nama, jumlah sapi, bobot rata-rata, target, catatan, status arsip, tanggal, dan sumber. Snapshot terakhir adalah sumber data kini. Riwayat tidak direkonstruksi dari profil individual.

`GroupFeedPlan` menyimpan input dan revisi kelompok yang dipakai saat menghitung serta takaran API per ekor. Total bahan dihitung dengan mengalikan takaran per ekor dan jumlah sapi pada rencana tersebut. `FeedRation` memvalidasi respons bersama alur individual; tidak ada sapi dummy, endpoint baru, atau rekomendasi lokal pengganti saat API gagal.

Jumlah, bobot rata-rata, atau target yang berubah membatalkan kecocokan rencana terkini, termasuk jika nilainya kemudian dikembalikan seperti semula. Edit nama/catatan tidak membatalkannya. Rencana yang tertinggal akibat edit saat request berjalan ditolak ketika disimpan.

Semua mutasi memakai antrean `FarmStore`. State baru diterbitkan sesudah disk berhasil ditulis. `GroupRules` digunakan untuk mutasi, load, dan impor: memeriksa ID/nama, batas jumlah dan bobot, urutan histori, sumber, relasi input rencana, serta angka hasil API. Edit/hapus sapi individual tidak mengubah data kelompok.

## Disederhanakan dari implementasi sebelumnya

Picker anggota, perpindahan sapi, filter kelompok pada profil individual, rekap dari anggota, dan syarat mengosongkan anggota sebelum arsip dihapus dari alur aktif. Tidak ada kewajiban keanggotaan atau sinkronisasi otomatis dari sapi ke kelompok. Tidak ada dua sumber kebenaran untuk jumlah ternak kelompok.

`LegacyGroupMembership` hanya menyimpan baris lama sebagai lampiran cadangan read-only, tanpa operasi keanggotaan baru. Ini menjaga data lama tanpa menambah kompleksitas operasional.

## Migrasi dan kompatibilitas

Penyimpanan/ekspor memakai **schema 4**: `groups` dengan histori, `groupFeedPlans`, dan `legacyMemberships`, di samping sapi/rencana individual/settings. Data versi 2 dan format tanpa versi tetap didukung dan dimulai tanpa kelompok.

Untuk versi 3, nama, ID, tanggal dibuat, catatan, dan arsip kelompok dipertahankan. Jumlah awal berasal dari anggota aktif lama sekali saja saat migrasi. Bobot rata-rata awal hanya diisi jika seluruh anggota tersebut punya bobot; jika sebagian belum punya, bobot rata-rata tetap kosong agar tidak memberi angka yang menyesatkan. Target awal adalah pemeliharaan. Peternak perlu meninjau data hasil migrasi dan menghitung pakan kelompok pertama. Rencana individual tetap disimpan, tanpa diklaim sebagai rencana kelompok.

Baris relasi versi 3 dipertahankan untuk ekspor ulang. Setelah migrasi, data kelompok tidak lagi mengikuti perubahan sapi individual. Cadangan schema 4 tidak dapat dibaca build lama yang hanya mendukung schema 3. Key storage, lokasi file, package Dart, dan bundle ID tidak berubah.

## Batas dan perluasan

Perhitungan kelompok mengasumsikan kondisi ternak relatif seragam sesuai bobot rata-rata dan target. Peternak mengelola perubahan jumlah/bobot secara eksplisit. Ini belum inventaris transaksi kelahiran/penjualan, pencatatan pakan aktual, stok, atau audit pengguna. Riwayat menyimpan waktu pencatatan, bukan tanggal efektif kejadian masa lalu.

ID stabil, histori bertanggal, sumber, dan snapshot input rencana dapat menjadi dasar Insight Engine, Halo Moo, dan pengukuran IoT berikutnya. Membership/perpindahan baru perlu ditambahkan jika kebutuhan produk nyata menuntutnya; jangan menjadikannya prasyarat kelompok. Sinkronisasi cloud dan konflik antarperangkat belum termasuk.

## Profil individual

Bobot manual, estimasi foto, histori, rencana pakan, dan pencarian/filter individual tetap tersedia langsung di **Ternak**. Tombol **Hitung kebutuhan pakan** nonaktif saat bobot belum pernah dicatat; aktif kembali sesudah bobot tersimpan. Profil tidak wajib tergabung ke kelompok.
