# SAPIENS — Fondasi 1: Farm Command Center

## Cakupan saat ini

Command Center merupakan pintu masuk operasional untuk data sapi, bobot, dan pakan yang telah ada. Perubahan ini memperluas aplikasi yang sama dan mempertahankan integrasi API dan lokasi data. Digital Twin dengan kelompok mandiri opsional memakai schema cadangan versi 4 dengan dukungan pembacaan versi 2 dan 3; lihat [Digital Twin](digital-twin.md).

| Area | Perilaku |
| --- | --- |
| Ringkasan | Jumlah sapi, sapi yang memerlukan catatan bobot, cakupan rencana aktif, total bobot yang tercatat |
| Prioritas | Paling banyak satu tindakan berikutnya per sapi; bobot merupakan prasyarat pakan |
| Antrean | Halaman tindakan dengan filter Semua/Bobot/Pakan dan tautan ke langkah terkait |
| Pakan | Kg pakan segar/hari, rincian bahan, jumlah sapi tercakup, serta peringatan cakupan belum lengkap |
| Aktivitas | Gabungan riwayat bobot dan rencana tersimpan, terbaru dahulu, tertaut ke detail |
| Kondisi awal | Data kosong dengan tombol tambah sapi, serta jalur baca ulang/pulihkan saat storage gagal |

## Aturan operasional

1. Belum ada bobot atau riwayat: catat bobot awal.
2. Riwayat terakhir melewati interval pengingat: periksa ulang bobot.
3. Bobot masih terkini tetapi rencana belum ada: buat rencana pakan.
4. Rencana tidak sesuai bobot/tanggal pengukuran/umur/jenis kelamin terkini: perbarui rencana.
5. Jika seluruh prasyarat terpenuhi, sapi tidak muncul sebagai tindakan tertunda.

Rencana bobot lama tidak dihitung dua kali atau digunakan untuk menutupi sapi yang belum memiliki rencana. Data contoh ditandai. Catatan manual, foto, dan contoh diberi label sumber dalam aktivitas.

Tidak ada status kesehatan otomatis, prediksi produktivitas, stok pakan, sensor online, atau pemberitahuan yang dianggap telah dikirim. Antrean tidak merupakan penjadwal tugas lengkap atau audit log; ia berubah mengikuti data sumber dan penghapusan sapi.

## Jalur pengembangan berikutnya

- **Farm Command Center:** tambahkan tugas persisten, penanggung jawab, dan penyelesaian aktual bila proses operasional sudah ditetapkan. Jangan memakai snapshot proyeksi sebagai penyimpanan tugas.
- **Digital Twin:** perluas identitas dan riwayat sapi yang sudah ada dengan event/domain yang jelas. Tidak perlu menyalin entity sapi untuk membuat dashboard lain.
- **Insight Engine:** konsumsi catatan dan waktu pengukuran yang sama; pisahkan hasil analisis dan tingkat ketidakpastiannya dari catatan faktual.
- **Halo Moo:** tambahkan service/use case yang beroperasi atas data tervalidasi, tanpa menaruh request model bahasa dalam widget.
- **IoT:** masukkan pengukuran melalui adapter dan validasi sumber/waktu; proyeksi Command Center dapat membaca state hasilnya tanpa bergantung pada protokol perangkat.

Tahap ini tidak membuat menu kosong atau stub integrasi untuk fondasi berikutnya. Pemisahan proyeksi, aturan status, state, dan service menjadi batas yang dapat diperluas saat kebutuhan tersebut konkret.

## Pemeriksaan manual sebelum rilis

- Jalankan analyzer dan seluruh tes di Flutter 3.24.5/Dart 3.5.4, kemudian build web.
- Buka data lokal lama dan impor cadangan versi 2. Verifikasi jumlah sapi, foto, riwayat bobot, dan rencana tidak berubah.
- Uji perpindahan tab, filter dari ringkasan, kembali sistem Android, gesture kembali iOS, serta pembatalan formulir belum disimpan.
- Jalankan kamera/galeri pada perangkat: profil → foto → review → simpan bobot saja dan simpan/lanjut hitung pakan. Pastikan tidak kembali ke langkah selesai dan catatan tidak tersimpan dua kali.
- Uji input bobot dari kalkulator, hasil API, simpan rencana lalu kembali sistem maupun tombol Selesai, cakupan/rekap, serta rencana yang menjadi tertinggal setelah perubahan data.
- Periksa ukuran 320/390/430 px, ukuran teks besar, keyboard, dan VoiceOver/TalkBack.
- Bersihkan/rebuild hasil native untuk nama aplikasi baru; uji signing dan installer di masing-masing platform. Origin web tetap perlu sama untuk membaca localStorage lama.
