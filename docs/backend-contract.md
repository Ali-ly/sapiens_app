# Kontrak backend dan keputusan integrasi

Sumber teknis: OpenAPI Gateway aktif dan source Python pada `MyDrive/Cattle_App_MVP`, diverifikasi 27 Oktober 2026. Backend tidak diubah dalam rebuild ini. Fixture tes berasal dari respons live, bukan kontrak frontend lama.

| Operasi | Endpoint |
| --- | --- |
| Health | GET `/health` |
| Bahan valid untuk mode | GET `/v2/feeds/beef` atau `/v2/feeds/dairy` |
| Evaluasi nutrisi | POST `/v2/nutrition` |
| Estimasi bobot | POST `/v2/weight`, multipart `files`, 1–4 foto |

## Request dan snapshot

Nutrition mengirim `production_category`, `cattle`, dan `feed_items` dengan `feed_id` + `as_fed_kg_day`. Bahan difilter memakai `valid_for`; tidak ada daftar bahan/formula nutrisi lokal. Backend mengembalikan requirement, feed_supply/supply, adequacy, warnings, coverage dan metadata opsional. Field response dipertahankan dalam snapshot; confidence/asumsi tampil hanya bila ada. Response Dairy `not_fully_evaluable` tetap “Belum dapat dievaluasi penuh”, tidak diberi kesimpulan cukup/kurang.

Konteks berasal dari sapi yang dipilih. Input lanjutan yang benar-benar dibutuhkan dikumpulkan di Perawatan, tanpa default target ADG, paritas, susu, atau tanggal kelahiran palsu. Bobot terbaru dipakai apa adanya; nilai di luar rentang layanan tidak di-clamp.

## Capability gap yang eksplisit

- Beef Penggemukan didukung dalam domain tabel backend; target ADG wajib eksplisit. Pembibitan masih `not_implemented`, sehingga diblokir sebelum evaluasi. Engine pertumbuhan saat ini tidak menggunakan fase Awal/Akhir; fase tetap merupakan histori pemeliharaan dan tidak diklaim sebagai formula berbeda.
- Dairy Fresh/Early/Mid/Late dan Close-Up mempunyai jalur perhitungan. Stage pedet, dara tumbuh, dara bunting, dan kering kandang dikenali tetapi belum diimplementasikan. Profil dan pencatatan tetap bisa digunakan; evaluasi menjelaskan keterbatasan.
- Dairy jantan belum mempunyai jalur nutrisi yang sesuai. Tidak pernah dialihkan ke kalkulator Beef.
- Laktasi memakai DIM dari calving aktual, produksi lengkap dalam kg/hari, kelompok paritas dari nomor laktasi valid, dan lemak susu yang diisi. Susu liter tidak dikonversi menjadi kg. DIM 0 disimpan benar namun API mensyaratkan DIM > 0; evaluasi hari kelahiran diblokir.
- Close-Up meminta minggu menuju kelahiran, NDF ransum dan status heifer secara eksplisit. Rentang/rule nutrisi tetap ditegakkan backend.
- Product-specific ditandai dari `profile_status`; profil conditional bukan otomatis produk spesifik. Request backend hanya menerima identitas bahan dan jumlah; UI belum menawarkan override label/lab yang akan diabaikan backend.
- Tidak ada endpoint auth/cloud pada kontrak ini, sehingga akun MVP lokal dan dijelaskan di UI.

## Verifikasi live

Client Flutter diuji dengan sapi sintetis: katalog 7 bahan per domain, Beef response `ok`, Dairy response `partial`, serta snapshot tersimpan dan terbaca kembali. Foto sapi publik menghasilkan estimasi 451.3 kg, 1 foto valid, 0 ditolak. Ini bukan klaim akurasi model atau validasi ilmiah. Nilai 451.3 kg berada di luar tabel pertumbuhan Beef yang diuji; aplikasi tidak mengubah hasil untuk memaksakan evaluasi.

Foto uji: [Cow female black white](https://commons.wikimedia.org/wiki/File:Cow_female_black_white.jpg), Keith Weller/USDA, public domain. Foto hanya dikirim untuk tes opt-in; tidak dimasukkan sebagai ternak/asset produksi.

Dampak keputusan produk yang perlu direview: kg/liter produksi susu, pengisian konteks lanjutan, akun lokal, keterbatasan stage/backend, serta kebutuhan backend untuk input produk spesifik. Tidak ada rekomendasi medis, ambang ilmiah baru, atau formula pengganti di frontend.
