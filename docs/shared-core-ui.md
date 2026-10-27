# Shared Core UI

Alur utama tetap tambah sapi, profil, bobot, pakan, lalu riwayat. Kelompok/kandang tetap opsional. Tidak ada perubahan besar pada shell navigasi atau penyimpanan platform.

## Pengaturan dan profil

Pengaturan peternakan mendukung Beef, Dairy, atau keduanya. Farm lama boleh belum memilih sistem. Perubahan yang bertentangan dengan kategori sapi tersimpan ditolak tanpa menyimpan sebagian pengaturan, termasuk bila sapi tersebut sudah tidak aktif.

Sapi baru mengikuti kategori otomatis pada farm dengan satu sistem produksi. Farm dengan kedua sistem mengharuskan pilihan kategori. Kategori sapi lama tidak ditebak. Perubahan kategori membutuhkan alasan dan mempertahankan histori serta data modul sebelumnya.

Profil menampilkan kategori, status, tahap hidup, kepastian umur, referensi identitas yang tersedia, ringkasan kesehatan, dan akses timeline. Tahap hidup dicatat pengguna tanpa ambang umur otomatis. Referensi induk/pejantan ditampilkan hanya jika tersedia; tidak ada workflow membership atau perpindahan kelompok baru.

## Status dan kesehatan

Status mencakup aktif, dijual, diafkir, dipotong, dipindahkan, mati, dan diarsipkan. Perubahan menambah histori tanpa menghapus profil, foto, bobot, atau rencana pakan. Daftar aktif dan ringkasan menggunakan ternak aktif; profil nonaktif masih dapat dibaca. Koreksi kembali aktif menambah event baru.

Status memakai waktu pencatatan. Model belum memiliki tanggal efektif terpisah; form tidak menawarkan backdate. Catatan kesehatan membedakan waktu kejadian dan waktu pencatatan serta mendukung observasi, perawatan, vaksinasi, obat cacing, dan pencegahan dengan jadwal lanjutan opsional. Ini merupakan pencatatan pengguna, tanpa diagnosis atau saran obat. Jadwal belum mengirim notifikasi OS.

Timeline mengurutkan event tersimpan berdasarkan waktu pencatatan. Histori lama tanpa event tidak diberi event buatan; bobot dan foto tersebut tetap tersedia pada bagian profil masing-masing.

## Umur dan batas fitur

Tampilan membedakan umur pasti, estimasi, dan tidak diketahui. Tanggal lahir atau zona waktu yang tidak tercatat tidak ditebak. Estimasi bulan tidak bertambah otomatis karena waktu acuannya belum tersedia. Edit identitas mempertahankan bukti umur pasti, tidak diketahui, atau estimasi dengan tanggal lahir; input angka bulan hanya tersedia untuk estimasi tanpa tanggal lahir. Sapi baru masih menggunakan estimasi bulan. Editor tanggal lahir dan pencatatan umur tanpa angka memerlukan pengembangan model berikutnya.

Input umur pada hasil pakan lama ditandai sebagai snapshot input, bukan umur terverifikasi saat ini. Kontrak API dan rumus pakan tidak berubah. Pemilihan Dairy belum menyediakan kebutuhan nutrisi laktasi, pencatatan susu, atau workflow reproduksi. Modul produksi berikutnya harus mendefinisikan routing dan batas rekomendasi tersebut.

## Verifikasi

`test/shared_core_ui_test.dart` mencakup pengaturan produksi, kategori wajib, konflik dan form tertinggal, kegagalan simpan, status keluar/koreksi, pencatatan kesehatan, validasi waktu, timeline setelah reload, kepastian umur, filter aktif/nonaktif, guard input belum disimpan, serta layout 320 dan 390 piksel. Tes ini berjalan pada VM dan Chrome bersama regresi migrasi dan fitur existing.

Kamera/galeri native, keyboard perangkat, date picker, kuota penyimpanan, aksesibilitas perangkat, dan signing iOS tetap perlu diuji manual sebelum rilis.
