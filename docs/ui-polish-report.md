# SAPIENS — UI refinement

27 Oktober 2026. Fokus: presentasi Flutter dan usability, dengan semua fitur, perhitungan, alur dan kontrak data yang ada dipertahankan.

## Sistem visual

Lihat [DESIGN.md](../DESIGN.md) untuk token, typography, component anatomy, states, dan responsive rules. Referensi konsep dibuat memakai built-in Image Gen dari konten profil yang sudah ada: [profile-reference.png](design/profile-reference.png). Prompt mempertahankan identitas, metadata, lima tab, empat metrik, dan evaluasi pakan; tidak meminta fitur, metrik, atau klaim baru.

| Sebelum | Sesudah |
| --- | --- |
| Radius, warna sekunder dan hierarchy tidak seragam | Forest/sage palette, semantic colors, typography dan spacing terpusat |
| Label fase bersaing dengan angka utama | Text-valued metrics lebih kecil, angka tabular, tinggi kartu sebaris selaras |
| Tab berupa chip/checkmark terpisah | Strip tab dengan underline, selected state jelas, horizontal overflow yang tetap dapat digunakan |
| Profil memakai header berukuran tetap | Identity dan isi terkoordinasi saat scroll; nama/ID panjang dan 200% text tidak memblokir konten |
| Label dropdown susu dapat overflow | Pilihan membungkus pada lebar yang tersedia, nilai dan callbacks tetap sama |
| Heading + aksi berpotensi overflow | Action wrapping mengikuti lebar dan pembesaran teks |
| Backup onboarding tampil setara aksi utama | Restore menjadi secondary action; fungsi, busy, error dan retry tetap tersedia |
| Error memakai warna warning | Error, warning dan info memiliki presentasi yang berbeda |
| Placeholder memakai paw generik | Satu cattle-outline glyph untuk avatar kosong dan navigasi |

## Ruang perubahan

Theme dan komponen bersama, layout profil/ringkasan, header beranda, onboarding, loading/error states, dropdown presentation, dan tampilan susu. Tidak ada perubahan pada `lib/api`, `lib/application`, `lib/domain`, atau `lib/data`. Tidak mengubah schema, dependencies, persistensi, formula, backend, mode selection, urutan form, atau empat destination utama.

Pemilihan tab tetap memakai callback dan guard existing, termasuk tab susu yang tidak aktif untuk Dairy jantan. Scroll position dikelola sebagai state presentasi agar tab yang dipilih terlihat dan pergantian tab tidak mengembalikan pengguna ke awal identity yang panjang.

## Fidelity ledger

| Titik inspeksi | Referensi → hasil |
| --- | --- |
| Copy dan urutan | Identitas → tab → ringkasan → data → evaluasi dipertahankan; tidak ada metrik atau klaim baru |
| Typography | Sans existing, label 12–14, data 26, text-valued metric 20, judul 18–32 |
| Palette | Forest #163D35, warm near-white #F6F7F3, sage #E4EDE5; tanpa gradient/decorative shadow |
| Components | Border 1 px, radius 16/12, strip tab dengan underline; callbacks dan disabled state dipertahankan |
| Spacing/alignment | Gutter terpusat, kartu sebaris setinggi sama, form memiliki batas lebar yang nyaman |
| Responsive | Compact/enlarged text satu kolom, phone biasa dua, empat metrik sebaris pada desktop |
| Asset treatment | Placeholder icon-native; foto pengguna tetap dari galeri existing, tidak diganti foto contoh |

Adaptasi yang disengaja: referensi gambar menumpuk metrik pada phone; implementasi mempertahankan dua kolom pada phone yang cukup lebar, lalu satu kolom untuk compact/text scaling. Lima tab tidak diperkecil agar dipaksakan muat, tetapi tetap bisa digulir. Label mode pada beranda dipindahkan ke bawah greeting dan memakai normal case; isi faktual tetap sama. Tidak ada tambahan promosi atau navigasi. Bottom navigation tetap digunakan.

## Verifikasi akhir

| Pemeriksaan | Hasil |
| --- | --- |
| Format | 62 berkas Dart; 0 perubahan |
| `flutter analyze` | 0 issue |
| Full VM tests | 59 lulus; 3 skip (live opt-in dan IndexedDB khusus web) |
| Full Chrome tests | 60 lulus; 2 skip live opt-in |
| Render preview Flutter | 1 tes lulus; 12 preview phone/tablet/desktop/text scaling |
| Web release build | Berhasil |
| `git diff --check` | Bersih |
| Diff API/application/domain/data/dependencies | Kosong |
| Impeccable mechanical detector | Tidak ada finding; validasi visual/Flutter tetap dilakukan terpisah |

Delapan regression tests baru mencakup contrast, lima viewport, secondary action busy/error/retry dan reduced-motion loading. Layout diperiksa pada 320×568, 390×844, 768×1024, 844×390 (landscape), dan 1440×900, dengan text scale 100%, 160%, 200%. Pada compact 200%, semua tab profil dibuka untuk memastikan isi tetap dapat dijangkau. Form tambah sapi, kondisi, susu, daftar ternak, pakan, pengaturan, ringkasan dan result turut dirender dengan nama/ID panjang.

Konsep dan render terbaru diperiksa dengan `view_image`, meliputi copy/order, palette, typography, card anatomy, tab selection, spacing, icon, dan responsive behavior. [Browser profile terbaru](design/profile-after.png) dibandingkan dengan [referensi konsep](design/profile-reference.png). Adaptasi di atas bersifat sengaja, termasuk native controls dan tab compact aligned-start; bukan penggantian user flow. Tidak ada mismatch fungsional atau clipping yang tersisa pada cakupan yang diuji.

Browser/IAB dipakai langsung pada build release 1280×720, tanpa Playwright eksternal. Pointer/keyboard nyata memverifikasi: pilih Perah → tambah sapi dua langkah → required-weight error dan recovery → bobot manual 500 kg → pilih Laktasi awal → profil → AM saja 8 kg berstatus parsial → koreksi PM 7 kg menjadi 15 kg lengkap → ringkasan/riwayat → pakan dengan konteks belum lengkap → kembali dan reload. Angka adalah data QA, bukan data contoh produksi. Console error kosong. Data bertahan setelah reload. Data uji hanya berada di origin lokal terpisah `localhost:8737`; origin aplikasi pengguna `localhost:8736` tidak direset atau diubah melalui UI pengujian.

Satu percobaan suite Chrome sempat berakhir `did not complete`; targeted rerun lulus dan full Chrome serial rerun lulus 60 tes. Tidak mengubah test assertion atau business behavior untuk menutupi kegagalan tersebut. Proxy text-entry semantik IAB tidak andal untuk field dinamis Flutter; interaksi form diverifikasi lewat pointer/keyboard canvas-native. Ini bukan sertifikasi screen-reader/native accessibility.

## Batas verifikasi

Browser dan widget tests tidak menggantikan pengecekan kamera/galeri serta screen reader di perangkat Android/iOS fisik. Tidak ada perubahan izin, plugin native, atau native release pada pass ini. Perubahan UI masih lokal dan belum di-commit/push. Data untuk screenshot dan interaksi QA dibuat pada lingkungan uji terpisah, tidak mengganti data pengguna.
