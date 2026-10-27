# Phase 5 — Dairy Module

Profil individual tetap jalur utama. Bagian Dairy membuka Milk, Lactation, Reproduction, Calf/Heifer, Feeding, dan Udder/Milk Health. Ringkasan menyediakan jumlah susu tercatat dan tautan Dairy & pemerahan. Dashboard menyediakan quick entry per sapi serta filter fase/aktif/nonaktif; filter fungsional tidak membuat membership atau sumber data kedua.

## Model dan persistensi

`DairyExtension` versi 2 berisi histori immutable `DairyRecord` dan `MilkRecord`. Fase, breeding, pregnancy check, calving, observasi ambing, dan masa tahan dicatat append-only melalui FarmStore. Snapshot diterbitkan setelah penyimpanan berhasil. Form membawa farm ID/revisi untuk menolak konteks tertinggal. Perubahan kategori/keluar tidak menghapus histori atau namespace.

Schema utama/minimum reader tetap **5**, fondasi farm **3**, Shared Twin **2**, Beef **2**; Dairy naik dari **1 ke 2**. Reader Phase 4 menolak Dairy 2 sebelum menulis. Farm tanpa namespace Dairy baru tidak membutuhkan perubahan root karena tidak memiliki data Dairy yang dapat dibuang. Namespace Dairy 1 dimigrasikan menjadi daftar kosong tanpa kejadian, susu, fase atau paritas buatan; upgrade write berhasil sebelum publish dan tidak berulang pada load berikutnya. Unknown versi/field/timestamp tanpa offset ditolak.

Tanggal Dairy adalah **tanggal kalender eksplisit** (`YYYY-MM-DD`), bukan timestamp legacy yang diberi timezone dugaan. `recordedAt` menyimpan instant UTC, sedangkan `recordedOn` menyimpan tanggal lokal perangkat saat pencatatan. Tanggal kejadian/susu tidak boleh melewati recordedOn; window masa tahan boleh direncanakan ke depan secara eksplisit. Perhitungan ordinal kalender memakai komponen tanggal sehingga tidak berubah karena DST atau durasi satu hari bukan 24 jam. Tanggal tampilan default mengikuti perangkat; belum ada pengaturan timezone farm lintas perangkat.

## Susu

Satu snapshot aktif per sapi/tanggal, dalam liter:

- Total harian **atau** AM+PM; kedua mode tidak dijumlahkan.
- Kolom kosong adalah belum dicatat. Angka 0 adalah nol yang dicatat pengguna. AM atau PM saja adalah parsial; volume yang diketahui boleh dijumlahkan sebagai volume tercatat, bukan total harian lengkap.
- Untuk melengkapi/koreksi, snapshot baru wajib menunjuk ID snapshot terakhir pada tanggal yang sama. Histori lama tetap ada. Duplikat tanpa koreksi, koreksi atas versi lama, koreksi tanggal lain dan pencampuran mode ditolak.
- Rata-rata seluruh histori dan window **7/30 hari** memakai hari lengkap yang tercatat saja. Window mencakup tanggal pilihan dan 6/29 hari sebelumnya. UI menampilkan jumlah hari lengkap/ukuran window. Hari kosong atau parsial tidak dianggap nol.
- Tren adalah selisih dua hari lengkap terakhir beserta jarak kalender keduanya; tidak mengisi gap. Latest/today bisa parsial dan diberi label.
- Peak adalah maksimum hari lengkap yang benar-benar tercatat dalam siklus terpilih. Kurva menampilkan titik observasi; garis hanya menghubungkan tanggal berurutan, bukan mengisi hari yang hilang.
- Ringkasan herd hanya profil Dairy betina aktif; jumlah lengkap, parsial dan belum dicatat ditampilkan. Profil nonaktif dan Beef tidak masuk total operasional. Kelompok mandiri tidak digabung. Catatan bertimestamp masa depan tidak masuk tampilan as-of.
- Volume harus finite/nonnegatif; total sesi/hari/herd yang melampaui kapasitas angka ditolak. Rata-rata memakai penjumlahan nilai yang sudah dibagi denominator agar tidak overflow pada jumlah yang tetap dapat direpresentasikan.

Mode 3x/custom tidak ditambahkan pada tahap ini; dua mode sederhana sudah mendukung pembaruan sesi tanpa kompleksitas konfigurasi sesi. Catatan kualitas teks tersedia, tanpa interpretasi klinis atau angka fat/protein/SCC yang diasumsikan.

## Fase dan laktasi

Fase manual: Pedet baru lahir, Pre-Weaning, Lepas sapih, Dara/Heifer, Dara siap breeding, Bunting pertama, Close-Up, Calving, Fresh Cow, Early, Mid, Late Lactation, Dry Period. Close-Up dapat dicatat lagi pada siklus berikutnya. Fresh berbeda dari Early; Dry berbeda dari Close-Up. Tidak ada cutoff umur/DIM atau transisi otomatis.

**Calving aktual**, bukan memilih fase Calving, menjadi sumber siklus baru. Siklus menggunakan ID event kelahiran; tidak ada objek siklus kedua yang dapat menyimpang. DIM adalah selisih tanggal kalender sejak calving, dengan tanggal calving = 0. Fase Dry/Close-Up tidak me-reset kalender; label ini bukan klaim bahwa sapi sedang menghasilkan susu setiap hari. Siklus sebelumnya ditutup oleh calving berikutnya dan tetap dapat dipilih beserta kurvanya.

Nomor laktasi/paritas pertama hanya tersedia bila dimasukkan pengguna. Bila tidak diketahui, tampilkan jumlah siklus yang tercatat, bukan menyebutnya paritas aktual. Calving berikutnya menaikkan nomor yang sudah diketahui satu angka; override yang tidak konsisten ditolak. Baseline baru boleh dinyatakan eksplisit bila sebelumnya unknown dan tidak bertentangan dengan jumlah kelahiran tercatat. Tanggal calving harus meningkat dan tidak boleh diduplikasi pada tanggal sama.

Susu merupakan fakta per sapi/tanggal yang independen dari siklus. Hubungan ke kurva dihitung dari rentang tanggal antar calving aktual. Mencatat kelahiran historis yang diketahui tidak menulis ulang volume susu atau menciptakan produksi/DOB.

## Reproduksi dan relasi anak

Breeding/IB dapat merujuk pejantan existing. Pemeriksaan manual menunjuk breeding yang belum ditutup dan hasil positif/tidak bunting/belum pasti. Calving dapat merujuk pemeriksaan positif terbaru. Kelahiran aktual pertama tanpa histori breeding boleh dicatat sebagai baseline tanpa membuat pregnancy event palsu.

- **Days Open ke konsepsi tercatat** = tanggal breeding yang dikonfirmasi sebagai konsepsi − tanggal calving siklus tersebut. Checkbox konfirmasi eksplisit diperlukan; pregnancy check positif saja tidak menebak tanggal konsepsi.
- **Services per Conception** = jumlah servis tercatat dalam siklus sampai servis yang dikonfirmasi, termasuk servis tersebut. Tidak mengklaim seluruh histori servis lengkap. Bila tidak ada siklus/konfirmasi atau ada beberapa servis positif yang ambigu, tampilkan belum tersedia.
- **Calving Interval** = selisih tanggal dua calving aktual berurutan. Tidak mengisi kelahiran yang tidak tercatat.

Calving, nomor siklus/paritas, dan referensi dam/sire anak disimpan atomik. Link yang bertentangan, self-link, cycle silsilah, ID hilang, anak dipakai kelahiran lain atau penggunaan ulang breeding tertutup ditolak. Disk failure tidak boleh menerbitkan sebagian perubahan.

Anak dapat menautkan profil existing. Pembuatan profil newborn otomatis belum dilakukan karena identitas existing mensyaratkan ageMonths minimal 1; tidak memalsukan DOB/umur agar lolos validator. Fase newborn/heifer tetap dapat dicatat manual tanpa mengubah bukti umur. Growth memakai tab bobot/grafik shared tanpa rumus ilmiah baru. Editor koreksi calving/tautan anak setelah event memerlukan rancangan berikutnya yang menjaga histori.

## Ambing, kualitas dan masa tahan

Observasi ambing/susu adalah catatan manual; boleh menautkan Shared Health/treatment sapi yang sama dan membuka catatan kesehatan existing. Observasi/treatment tidak otomatis menentukan diagnosis atau durasi masa tahan.

Window masa tahan memakai tanggal mulai inklusif dan tanggal tinjau kembali/safe-use eksklusif, **keduanya diisi dari pengguna/vet/label**. Susu pada seluruh tanggal dalam window dipisahkan secara konservatif. Window overlap merupakan union, bukan ditambah dua kali. Koreksi eksplisit mengganti window aktif dengan record baru, mempertahankan histori; boleh memendekkan/memperpanjang sesuai sumber. Tanggal mulai di masa depan tidak menahan susu sebelum tanggal tersebut. Koreksi window berlaku sebagai koreksi fakta, termasuk pada ringkasan historis.

UI menyebut volume **di luar masa tahan tercatat**, bukan jaminan aman atau layak jual. Tidak ada durasi obat, withdrawal rule, diagnosis mastitis, atau automatic safe claim. Seluruh referensi dalam UI menampilkan jenis/tanggal/catatan/nama; stable ID tetap internal.

## Feeding dan batas tahap

Backend existing hanya menerima bobot, target umum dan bahan. Dairy/laktasi tidak didukung dan tetap ditolak sebelum HTTP, saat save plan, serta dari rekap stok Beef. UI menampilkan fase/DIM/susu sebagai konteks tersimpan, tetapi tombol kalkulasi Dairy tidak aktif. Ransum Beef tidak diganti label atau dihitung dengan rumus nutrisi lokal. Command Center membuka konteks Dairy ketika meminta tinjauan dukungan pakan.

Belum ada Decision/Insight Engine, Halo Moo/LLM, IoT, AI/CV/BCS otomatis, diagnosis/protokol veteriner, cloud/auth/multi-farm, ekonomi lanjutan atau Phase 6. BCS serta quality numeric/scientific thresholds didefer; catatan kualitas manual teks tetap tersedia.

Sebelum rilis: uji API/CORS produksi, kamera/galeri native, keyboard/date lokal/aksesibilitas perangkat, kuota storage dan signing iOS. Sinkronisasi timezone farm antar perangkat dan koreksi peristiwa kelahiran perlu keputusan eksplisit sebelum perluasan.

## Batas siklus pada tanggal yang sama

Calving menutup breeding yang sudah tercatat dengan tanggal kejadian sebelum atau sama dengan tanggal kelahiran, termasuk bila calving tidak ditautkan ke pemeriksaan tertentu. Pada tanggal yang sama, urutan pencatatan menjadi batas operasional: servis sebelum calving tetap di siklus lama, servis yang dicatat sesudahnya menjadi bagian siklus baru. Pilihan breeding pada form mengikuti batas yang sama. Ini bukan perkiraan waktu biologis di dalam satu hari. Servis dengan tanggal kejadian lebih akhir tetap dapat berada di siklus baru bila calving aktual dimasukkan belakangan sebagai catatan historis. Histori dan ID tidak ditulis ulang.
