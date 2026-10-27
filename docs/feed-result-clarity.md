# Hasil evaluasi pakan — penjelasan dan hierarki

Masalah: hasil sebelumnya menampilkan response backend sebagai daftar key/value. Status proses `ok` diterjemahkan menjadi “Tersedia”, kebutuhan dan pasokan berjauhan, unit teknis tampil mentah, serta `profile_coverage_fraction: 1` mudah disalahartikan sebagai kecukupan pakan.

Perubahan utama:

- Kesimpulan pembuka memakai status nutrien dari backend, bukan status keberhasilan request. Bahan yang tidak ikut dihitung didahulukan agar hasil parsial tidak terlihat lengkap.
- Setiap komponen memasangkan “Dari pakan” dengan “Kebutuhan” atau “Perkiraan konsumsi”, dengan satuan per hari dan persentase dari backend.
- BK dijelaskan sebagai bahan kering, berbeda dari berat pakan segar. TDN ditandai sebagai indikator energi yang dipakai layanan. Tidak menambah formula atau saran jumlah pakan.
- Data belum evaluable dipisahkan. Nilai nol akibat profil yang tidak lengkap tidak disajikan sebagai bukti kandungan nutrien nol.
- Dairy yang `not_fully_evaluable` tidak diberi status cukup/kurang. Perbandingan konsumsi BK tidak dijadikan kesimpulan seluruh nutrien.
- Bahan dan jumlah input tetap terbaca; bahan yang dikecualikan diberi label. Peringatan umum yang diketahui diterjemahkan; response asli tetap utuh dalam disclosure teknis.
- Kelengkapan data dan keyakinan layanan dipisahkan dari kecukupan pakan. Fraksi cakupan yang diketahui ditampilkan sebagai persentase cakupan data, bukan raw `1` dan bukan persentase kebutuhan.
- Sumber/metode/asumsi/metadata lengkap tetap tersedia, dengan response JSON asli khusus developer. Tidak mengubah snapshot, model, persistence, request, backend, atau alur evaluasi/simpan.

Implementasi: `result_page.dart` untuk UI dan `result_presentation.dart` sebagai adapter presentasi non-persisted. Tidak ada klasifikasi berdasarkan threshold lokal; angka kebutuhan, pasokan, persentase dan status berasal dari backend. Progress indicator hanya menormalkan persentase untuk visualisasi, bukan menghitung kebutuhan. Unit BK/TDN adalah penjelasan satuan, tanpa konversi numerik.

Pengujian mencakup Beef/Dairy, response `ok` yang nutriennya masih kurang, bahan tidak dihitung, nol akibat data tidak lengkap, coverage, unknown unit/status, missing data, metadata opsional, immutable snapshot, ekspansi data teknis, 320/390/1280 px dan teks 200%. Hasil: format 64 file tanpa perubahan, analyzer tanpa issue, VM 75 lulus/3 dilewati, Chrome 76 lulus/2 dilewati, 16 test khusus hasil evaluasi lulus, web release build lulus, dan `git diff --check` bersih. Browser review pada 1280×720 tanpa error console. Tidak melakukan live backend E2E baru; fixture response yang tersedia digunakan untuk pemeriksaan UI. Screenshot contoh memakai angka yang terlihat pada screenshot pengguna, bukan snapshot lengkap ternaknya.

Preview: [hasil evaluasi](design/feed-result-after.png).
