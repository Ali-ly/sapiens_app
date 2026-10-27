# Phase 4 — Beef Module

Alur utama tetap profil individual. Dari profil berkategori Beef, buka Growth, Feeding, Harvest, atau Reproduction (khusus tujuan Pembibitan). Ringkasan menyediakan tautan Beef saat ada sapi Beef aktif; tab Pakan menyediakan Stok & kebutuhan Beef. Profil Dairy dan kelompok mandiri tetap menggunakan jalur existing.

## Histori domain

Namespace `modules.beef` versi 2 berisi daftar immutable `BeefRecord`. Setiap record memiliki ID, kind, recordedAt, occurredAt dan catatan/alasan wajib. Semua operasi menambah record. Waktu kejadian diisi pengguna, sedangkan recordedAt berasal dari clock store; waktu masa depan ditolak. Histori diurutkan menurut pencatatan, bukan menebak kapan kondisi biologis berubah.

| Record | Data |
| --- | --- |
| purpose | Penggemukan atau Pembibitan |
| phase | Anak, Lepas sapih, Pertumbuhan, Penggemukan, Finishing, Siap dievaluasi untuk jual |
| target | Target kg dan batas mendekati target dalam kg opsional, keduanya dipilih pengguna |
| service | Catatan breeding/IB, pejantan terdaftar opsional |
| pregnancy | Breeding terkait, hasil manual positif/negatif/belum pasti |
| calving | Pemeriksaan positif terkait, profil anak existing opsional |

Fase dipilih manual, boleh dikoreksi dengan catatan berikutnya, dan tidak memakai ambang umur/bobot otomatis. Target memakai rentang bobot teknis aplikasi existing (hingga 2.000 kg); rentang tersebut bukan standar kesiapan jual.

Reproduksi hanya dicatat pada induk betina dengan tujuan Pembibitan. Pemeriksaan merujuk breeding yang belum ditutup; kelahiran merujuk pemeriksaan terbaru yang positif untuk breeding tersebut. Waktu kejadian tidak boleh mendahului catatan yang dirujuk. Kelahiran menutup rangkaian itu tanpa menyimpulkan diagnosis atau durasi gestasi. Untuk siklus berikutnya, buat breeding baru.

Jika profil anak ditautkan, penambahan catatan kelahiran dan referensi dam/sire anak disimpan atomik. Referensi existing yang bertentangan, self-link, siklus silsilah, anak yang sudah ditautkan pada kelahiran lain, serta penyimpanan berulang untuk breeding yang sudah ditutup ditolak. Histori dan namespace tetap tersimpan ketika sapi keluar, diarsipkan atau berganti kategori.

Profil anak baru lahir tidak dibuat otomatis: kontrak identitas existing masih mensyaratkan ageMonths minimal 1. Aplikasi tidak memalsukan umur atau DOB demi membuat profil. Kelahiran dapat dicatat tanpa tautan anak; editor relasi/koreksi event yang lebih lengkap memerlukan pengembangan berikutnya.

## Growth dan Harvest

`BeefGrowth` adalah proyeksi deterministik tanpa menulis data:

- Selisih bobot dan ADG memakai dua catatan terakhir dalam urutan histori yang disimpan; ADG = selisih kg / durasi dalam hari pecahan (mikrodetik dibagi mikrodetik per hari).
- Histori kosong/satu catatan tidak memiliki ADG. Bobot tidak valid, waktu berulang/tidak meningkat, bobot masa depan, atau timestamp legacy tanpa zona waktu meniadakan ADG. Tidak mencari pasangan pengganti diam-diam dan tidak mengedit histori agar valid.
- ADG negatif/nol tetap ditampilkan sebagai tren turun/tetap, tanpa proyeksi kenaikan. Tidak ada label ADG baik/buruk dengan cutoff ilmiah.
- Progress adalah rasio bobot terakhir/target (0–100%), bukan pencapaian dari baseline penggemukan. Sisa kg minimal nol.
- Proyeksi hari = sisa kg / ADG, hanya bila ADG positif dan target belum tercapai. Titik acuannya bobot terakhir. Batas representabilitas teknis mencegah nilai ekstrem; tidak ada jaminan pertumbuhan atau pemodelan ketidakpastian estimasi AI.
- Harvest membandingkan bobot dengan target pengguna. Di bawah target: Belum siap; bila batas mendekati target opsional pengguna terpenuhi: Mendekati target; bila target terpenuhi: Siap dievaluasi. Tidak ada persentase 80/90/95% yang diasumsikan sebagai standar.
- UI Harvest hanya menyatakan kesiapan terkini pada tujuan Penggemukan dengan bobot yang tidak perlu diperbarui menurut interval farm existing. Data lama tetap ditampilkan sebagai perbandingan historis. Tidak menjual/mengubah status secara otomatis.

## Feeding: batas backend eksplisit

Gateway existing hanya menerima `weight`, `target`, `available_feeds`. Purpose, fase, kategori, status reproduksi, BCS, umur dan laktasi tidak menjadi input nutrisi backend.

`BeefFeedContext` membatasi pemakaian generik pada Beef Penggemukan fase Pertumbuhan/Penggemukan/Finishing/Evaluasi. Pertumbuhan memerlukan target API `pertumbuhan`; fase lainnya memerlukan `penggemukan`. Pengguna harus menyetujui penjelasan mode terbatas sebelum perhitungan. API tidak diklaim sebagai ransum khusus fase.

Pembibitan, Dairy/laktasi, anak/lepas sapih, tujuan/fase belum dipilih, serta hasil pemeriksaan manual terakhir per breeding yang positif dan belum ditutup kelahiran ditolak dari alur generik. Ini guard kemampuan layanan, bukan diagnosis atau perhitungan nutrisi baru.

Rencana baru menyimpan konteks Beef (purpose, phase, revisi histori, mode genericWeightOnly). Perubahan histori Beef membuat konteks lama tertinggal; perubahan bobot tetap memakai matching existing. Rencana legacy tetap dapat dibaca tetapi tidak otomatis disahkan sebagai rencana Beef aktif. Penyimpanan baru dan rekap menggunakan guard yang sama. Command Center menawarkan Tinjau dukungan pakan untuk konteks yang belum didukung atau rencana legacy tanpa konteks Beef; aksi tersebut membuka konteks profil, bukan memerintahkan perhitungan yang belum tersedia. Bobot masa depan/timestamp tanpa zona serta rencana bertanggal masa depan tidak memenuhi kesiapan operasional Beef. Sapi legacy belum berkategori mempertahankan alur existing; kelompok tetap terpisah dan tidak diasumsikan mendapat konteks Beef individual.

## Stok dan Mini MRP

Ledger farm menerima stok masuk, pemakaian, dan koreksi bertanda (+/-) dalam **kg pakan segar**, untuk bahan yang sudah didukung API: rumput, jerami, dedak. Setiap transaksi memiliki ID, waktu pencatatan dan alasan. Jumlah harus finite dan nonnol, stok masuk/pemakaian positif, dan setiap saldo historis tidak boleh negatif. Tidak ada konversi satuan atau pengurangan stok otomatis dari rencana.

Kebutuhan hanya memakai rencana terbaru yang memenuhi syarat untuk sapi Beef individual aktif. Cakupan dan nama sapi yang dikecualikan ditampilkan. Kelompok/kandang, Dairy, rencana lama/tertinggal/tidak didukung dan profil nonaktif tidak digabung. Ini mencegah hitung ganda kelompok mandiri yang mungkin merepresentasikan ternak sama. Transaksi stok bertanggal masa depan tetap ada di ledger tetapi dikecualikan dari saldo saat ini dan ditandai untuk ditinjau.

Kebutuhan periode = total takaran harian × 1/7/30. Kekurangan = max(0, kebutuhan − stok); estimasi hari cukup = stok / takaran harian bila kebutuhan positif. Tanpa kebutuhan valid, hari cukup tidak ditampilkan sebagai tak terbatas. Proyeksi mengasumsikan kebutuhan tetap, tanpa pertumbuhan, susut, realisasi otomatis, atau optimasi pembelian.

## Persistensi dan konkurensi

Schema envelope tetap **5**; fondasi farm menjadi **3**, Shared Twin tetap **2**, Beef **2**, Dairy **1**. Ledger berada di blok fondasi farm. Reader Phase 3 menolak versi fondasi baru bahkan ketika stock ledger kosong, sehingga data tidak dibaca lalu ditulis tanpa stok. Unknown field/versi/satuan ditolak, termasuk pada import.

Schema 5 lama dengan fondasi farm 2/Beef 1 dimigrasikan menjadi ledger dan histori Beef kosong, tanpa event, tanggal, tujuan atau fase buatan. Upgrade harus berhasil ditulis sebelum state diterbitkan dan tidak ditulis ulang pada load berikutnya. Fixture `5.json` tetap mewakili Phase 3; `5-beef.json` merupakan expected upgrade yang ditinjau terpisah.

Mutasi memakai antrean transaksi FarmStore, immutable snapshot, ID yang tidak dipakai ulang, validasi lintas referensi dan write-before-publish. Form memakai farm ID serta revisi histori/ledger untuk menolak form tertinggal. Ini bukan locking lintas tab/perangkat atau sistem sinkronisasi cloud.

## Batas tahap

Tidak ada workflow Dairy/susu/laktasi, notifikasi pemberian pakan, protokol reproduksi, diagnosis, rumus nutrisi baru, stock consumption otomatis, ekonomi lanjutan, Insight Engine, Halo Moo, IoT, AI/CV baru, auth/cloud atau multi-farm. API produksi, kamera native, keyboard/date picker perangkat dan signing iOS tetap perlu diuji manual sebelum rilis. Formula/threshold ilmiah dan kontrak backend yang lebih kaya harus disepakati sebelum mode feeding produksi diperluas.
