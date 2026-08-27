// Read-only audit/preview. Tidak membuat akun dan tidak mengubah database.
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const { DEFAULT_FILE, readParentRows, generateEmails } = require('./parent-account-utils');

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !serviceKey) throw new Error('SUPABASE_URL atau SUPABASE_SERVICE_ROLE_KEY belum tersedia di .env');
const sb = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });

async function listAllAuthUsers() {
  const users = [];
  for (let page = 1; page <= 100; page++) {
    const response = await fetch(`${url.replace(/\/$/, '')}/auth/v1/admin/users?page=${page}&per_page=1000`, { headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` } });
    const data = await response.json();
    if (!response.ok) throw new Error(data?.message || `Auth request gagal (${response.status}).`);
    const pageUsers = data?.users || [];
    users.push(...pageUsers);
    if (pageUsers.length < 1000) break;
  }
  return users;
}

async function main() {
  const input = process.argv[2] || DEFAULT_FILE;
  const source = readParentRows(input);
  const [users, { data: siswa, error: siswaError }, { data: profiles, error: profilesError }] = await Promise.all([
    listAllAuthUsers(),
    sb.from('siswa').select('id, nis, nama'),
    sb.from('profiles').select('id, role, nama'),
  ]);
  if (siswaError) throw siswaError;
  if (profilesError) throw profilesError;

  const existingEmails = new Set(users.map(user => String(user.email || '').trim().toLowerCase()).filter(Boolean));
  const profileById = new Map((profiles || []).map(profile => [profile.id, profile]));
  const siswaByNis = new Map();
  for (const student of siswa || []) siswaByNis.set(String(student.nis || '').trim().toLowerCase(), student);

  const generated = generateEmails(source.rows, existingEmails);
  const nameFirstCount = new Map();
  for (const row of source.rows) {
    const first = String(row.nama).trim().split(/\s+/)[0].toLowerCase();
    nameFirstCount.set(first, (nameFirstCount.get(first) || 0) + 1);
  }
  const seenNis = new Set();
  const seenEmails = new Set();
  const audit = generated.map(row => {
    const student = siswaByNis.get(row.nis.toLowerCase());
    const authUser = users.find(user => String(user.email || '').trim().toLowerCase() === row.email);
    const profile = authUser ? profileById.get(authUser.id) : null;
    const reasons = [];
    if (!row.nama) reasons.push('nama orang tua kosong');
    if (!row.nis) reasons.push('NIS kosong');
    if (row.nis && !student) reasons.push('NIS tidak ditemukan');
    if (!['ayah', 'ibu', 'wali'].includes(row.hubungan)) reasons.push('hubungan tidak valid');
    if (seenNis.has(row.nis.toLowerCase()) && row.nis) reasons.push('NIS duplicate di file');
    if (seenEmails.has(row.email)) reasons.push('email duplicate di hasil generate');
    seenNis.add(row.nis.toLowerCase());
    seenEmails.add(row.email);
    if (authUser && profile?.role !== 'orang_tua') reasons.push('email sudah dipakai akun non-orang_tua');
    return { ...row, student, authUser, profile, reasons };
  });

  const valid = audit.filter(row => row.reasons.length === 0);
  const nisEmpty = audit.filter(row => row.reasons.includes('NIS kosong')).length;
  const nisMissing = audit.filter(row => row.reasons.includes('NIS tidak ditemukan')).length;
  const emailCounts = new Map();
  for (const row of audit) emailCounts.set(row.email, (emailCounts.get(row.email) || 0) + 1);
  const emailDuplicate = [...emailCounts.values()].filter(count => count > 1).reduce((sum, count) => sum + count, 0);
  const emailNeedDisambiguation = audit.filter(row => row.emailConflict).length;
  const existingAccount = audit.filter(row => row.authUser && row.profile?.role === 'orang_tua').length;
  const existingConflict = audit.filter(row => row.authUser && row.profile?.role !== 'orang_tua').length;

  console.log(`File: ${source.filePath}`);
  console.log(`Sheet: ${source.sheetName}`);
  console.log(`Header sumber nama: ${source.sourceNameHeader}${source.sourceNameHeader === 'email' ? ' (terdeteksi berisi nama, bukan email)' : ''}`);
  console.log(`\nPreview 10 data pertama:`);
  console.table(audit.slice(0, 10).map(row => ({ baris: row.excelRow, nama: row.nama, nis: row.nis, email: row.email, hubungan: row.hubungan, siswa: row.student?.nama || '-', status: row.reasons.join('; ') || (row.authUser ? 'akun existing' : 'valid') })));
  console.log('\nRingkasan audit:');
  console.log(`- total data: ${audit.length}`);
  console.log(`- valid: ${valid.length}`);
  console.log(`- NIS tidak ditemukan: ${nisMissing}`);
  console.log(`- NIS kosong: ${nisEmpty}`);
  console.log(`- email duplicate pada hasil generate: ${emailDuplicate}`);
  console.log(`- email perlu pembeda karena konflik nama depan: ${emailNeedDisambiguation}`);
  console.log(`- nama depan duplicate: ${[...nameFirstCount.values()].filter(count => count > 1).reduce((sum, count) => sum + count, 0)}`);
  console.log(`- akun existing (role orang_tua): ${existingAccount}`);
  console.log(`- email existing non-orang_tua: ${existingConflict}`);
  console.log(`- akun baru yang akan dibuat: ${valid.filter(row => !row.authUser).length}`);
  console.log(`- hubungan default yang digunakan: ayah`);
  const failures = audit.filter(row => row.reasons.length);
  if (failures.length) {
    console.log('\nBaris yang perlu perhatian:');
    console.table(failures.map(row => ({ baris: row.excelRow, nama: row.nama || '-', nis: row.nis || '-', email: row.email, alasan: row.reasons.join('; ') })));
  }
}

main().catch(error => { console.error('Audit gagal:', error.message); process.exitCode = 1; });
