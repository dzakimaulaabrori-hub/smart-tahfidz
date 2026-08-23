// ============================================================
// TILMIDZ — Bulk Account Creator
// Baca template-akun-tilmidz.xlsx, bikin akun Auth + profile
// + hubungkan orang tua ke anak / wali kelas ke kelas.
//
// CARA PAKAI:
//   1. npm install
//   2. Isi file .env (lihat .env.example)
//   3. node create-accounts.js
// ============================================================

require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const XLSX = require('xlsx');
const path = require('path');

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('❌ SUPABASE_URL atau SUPABASE_SERVICE_ROLE_KEY belum diisi di file .env');
  process.exit(1);
}

// PENTING: service_role key cuma dipakai di sini (script lokal),
// JANGAN PERNAH dipasang di kode frontend/HTML/browser.
const sb = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

const VALID_ROLES = ['admin', 'wali_kelas', 'guru_quran', 'kepala_sekolah', 'orang_tua'];

async function main() {
  const filePath = path.join(__dirname, 'template-akun-tilmidz.xlsx');
  const wb = XLSX.readFile(filePath);
  const sheet = wb.Sheets['Data Akun'];
  const rows = XLSX.utils.sheet_to_json(sheet, { defval: '' });

  console.log(`📄 Ditemukan ${rows.length} baris data akun.\n`);

  const results = { sukses: 0, gagal: 0, detail: [] };

  for (const [i, row] of rows.entries()) {
    const rowNum = i + 2; // +2 karena baris 1 = header
    const nama = String(row.nama || '').trim();
    const email = String(row.email || '').trim().toLowerCase();
    const password = String(row.password || '').trim();
    const role = String(row.role || '').trim();

    if (!nama || !email || !password || !role) {
      console.log(`⚠️  Baris ${rowNum}: dilewati (ada kolom wajib kosong)`);
      results.gagal++;
      results.detail.push({ rowNum, email, status: 'dilewati - data tidak lengkap' });
      continue;
    }

    if (!VALID_ROLES.includes(role)) {
      console.log(`⚠️  Baris ${rowNum} (${email}): role "${role}" tidak valid, dilewati`);
      results.gagal++;
      results.detail.push({ rowNum, email, status: `role tidak valid: ${role}` });
      continue;
    }

    try {
      // 1. Buat akun di Supabase Auth
      const { data: userData, error: userError } = await sb.auth.admin.createUser({
        email,
        password,
        email_confirm: true, // langsung aktif, tidak perlu verifikasi email
      });

      if (userError) throw new Error('Auth: ' + userError.message);
      const userId = userData.user.id;

      // 2. Insert ke tabel profiles
      const { error: profileError } = await sb.from('profiles').insert({
        id: userId, nama, role
      });
      if (profileError) throw new Error('Profile: ' + profileError.message);

      // 3. Kalau orang_tua, hubungkan ke siswa via NIS
      if (role === 'orang_tua' && row.nis_anak) {
        const nisList = String(row.nis_anak).split(',').map(s => s.trim()).filter(Boolean);
        const hubungan = String(row.hubungan || 'wali').trim();

        for (const nis of nisList) {
          const { data: siswaData, error: siswaError } = await sb
            .from('siswa').select('id').eq('nis', nis).single();

          if (siswaError || !siswaData) {
            console.log(`   ⚠️  NIS "${nis}" tidak ditemukan di database, lewati relasi ini`);
            continue;
          }
          await sb.from('orang_tua_siswa').insert({
            user_id: userId, siswa_id: siswaData.id, hubungan
          });
        }
      }

      // 4. Kalau wali_kelas, tautkan ke kelas via nama_kelas
      if (role === 'wali_kelas' && row.nama_kelas) {
        const namaKelas = String(row.nama_kelas).trim();
        const { data: kelasData, error: kelasError } = await sb
          .from('kelas').select('id').eq('nama_kelas', namaKelas).single();

        if (kelasError || !kelasData) {
          console.log(`   ⚠️  Kelas "${namaKelas}" tidak ditemukan di database, lewati penautan`);
        } else {
          await sb.from('kelas').update({ wali_kelas_id: userId }).eq('id', kelasData.id);
        }
      }

      console.log(`✅ Baris ${rowNum}: ${nama} (${email}) — role: ${role}`);
      results.sukses++;
      results.detail.push({ rowNum, email, status: 'berhasil' });

    } catch (err) {
      console.log(`❌ Baris ${rowNum} (${email}): ${err.message}`);
      results.gagal++;
      results.detail.push({ rowNum, email, status: 'gagal - ' + err.message });
    }
  }

  console.log('\n============================================');
  console.log(`SELESAI. Berhasil: ${results.sukses}, Gagal/dilewati: ${results.gagal}`);
  console.log('============================================');

  if (results.gagal > 0) {
    console.log('\nDetail yang gagal/dilewati:');
    results.detail.filter(d => d.status !== 'berhasil').forEach(d => {
      console.log(`  Baris ${d.rowNum} (${d.email}): ${d.status}`);
    });
  }
}

main().catch(err => {
  console.error('Script berhenti karena error tak terduga:', err);
  process.exit(1);
});
