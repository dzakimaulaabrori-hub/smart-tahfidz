# Tilmidz — Bulk Account Creator

Script sekali-jalan buat bikin banyak akun (guru, wali kelas, kepala sekolah,
orang tua) sekaligus di Supabase, dari data yang diisi lewat Excel.

## Cara pakai

1. **Install Node.js** kalau belum ada (download di nodejs.org, pilih versi LTS).

2. **Install dependency**, buka folder ini di terminal, jalankan:
   ```
   npm install
   ```

3. **Siapkan file `.env`**:
   - Copy `.env.example` jadi `.env`
   - Isi `SUPABASE_URL` (sudah terisi contoh, sesuaikan kalau beda project)
   - Isi `SUPABASE_SERVICE_ROLE_KEY` dengan kunci **"service_role" / "kunci rahasia"**
     dari Supabase (Project Settings → API Keys → bagian "Kunci rahasia", yang
     namanya `sb_secret_...`). **Jangan pernah share atau commit file ini.**

4. **Isi data akun** di `template-akun-tilmidz.xlsx`:
   - Buka sheet "Petunjuk" dulu buat baca aturan pengisian
   - Isi data di sheet "Data Akun"
   - **Hapus baris contoh (warna kuning)** sebelum isi data asli
   - Simpan file (tetap dengan nama `template-akun-tilmidz.xlsx`, di folder yang sama)

5. **Jalankan script**:
   ```
   node create-accounts.js
   ```

6. Script bakal nampilin progress tiap baris (✅ berhasil / ❌ gagal / ⚠️ dilewati),
   dan ringkasan di akhir. Kalau ada yang gagal, baca pesan errornya — biasanya
   karena email udah kepake, atau NIS/nama kelas yang dirujuk belum ada di database.

## Catatan penting

- Script ini **aman dijalankan berkali-kali** kalau ada baris yang gagal — baris
  yang sudah berhasil dibuat sebelumnya nggak akan dibuat dobel selama emailnya
  beda/belum ada, tapi kalau emailnya sama akan muncul error "sudah terdaftar"
  (itu wajar, bukan bug).
- Password yang diisi di Excel adalah password sementara. Sebaiknya informasikan
  ke guru/orang tua untuk ganti password setelah login pertama.
- File `.env` berisi kunci rahasia — **jangan upload ke Google Drive publik,
  jangan kirim lewat WhatsApp/email tanpa enkripsi, jangan commit ke GitHub.**

## Legacy Netlify Function (fallback/reference)

Versi lama memakai `/.netlify/functions/admin-accounts`. Versi ini tidak lagi
dipanggil oleh frontend setelah migrasi Cloudflare. Jika fallback tersebut
masih dipakai sementara, environment variable berikut harus tersedia di
Netlify, bukan di `index.html` atau `supabase-config.js`:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (server-side only)
- opsional `ADMIN_ACCOUNTS_ORIGIN` untuk membatasi origin Function

Function memvalidasi access token dengan Supabase Auth dan memeriksa `profiles.role = 'admin'` sebelum memakai service key untuk membuat user Auth dan profile. Password hanya diteruskan ke Auth dan tidak dikembalikan ke browser, localStorage, database custom, atau log.

## Audit relasi kelas

`supabase/audit_kelas_foreign_keys.sql` adalah query read-only untuk menemukan semua foreign key yang mereferensikan `public.kelas(id)` beserta aturan `ON DELETE`. Jalankan di SQL Editor sebelum mengubah constraint. Implementasi ini tidak mengubah `ON DELETE`, menghapus histori, atau menambahkan migration destructive.

## Cloudflare Pages deployment

Deployment target baru adalah Cloudflare Pages dengan Pages Function:

- Static application: repository root (`pages_build_output_dir = "."`)
- Build command: `npm run build`
- Function source: `functions/api/admin-accounts.js`
- Endpoint frontend: `/api/admin-accounts`
- Configuration: `wrangler.toml`

Set Secrets/Environment Variables pada Cloudflare Pages untuk Production dan Preview sesuai kebutuhan:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (wajib server-side; jangan masukkan ke file frontend)
- `ADMIN_ACCOUNTS_ORIGIN` (opsional; batasi ke origin domain resmi)

Nilai secret tidak boleh ditulis ke repository, README, `index.html`, `supabase-config.js`, localStorage, atau log. Pages Function membaca secret dari `context.env` dan memvalidasi access token serta `profiles.role = 'admin'` sebelum operasi privileged.

Di Cloudflare Dashboard: Workers & Pages ? Create application ? Pages ? Connect to Git, pilih repository ini, gunakan build command `npm run build`, output directory `.` dan tambahkan variables/secrets di Settings ? Environment variables. Hubungkan custom domain melalui Pages ? Custom domains. Jangan mengubah DNS/nameserver dari repository ini.

`netlify/functions/admin-accounts.js` dan `netlify.toml` sengaja tetap disimpan sebagai fallback/reference selama deployment Cloudflare belum divalidasi. Keduanya tidak lagi dipanggil oleh frontend.
