// Jalankan hanya setelah hasil audit disetujui.
// Membuat akun Auth + profile, lalu relasi orang_tua_siswa. Service key hanya di script ini.
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const path = require('path');
const { readGeneratedRows } = require('./parent-account-utils');

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

async function createAuthUser(email, password) {
  const response = await fetch(`${url.replace(/\/$/, '')}/auth/v1/admin/users`, {
    method: 'POST', headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data?.message || data?.msg || `Auth create gagal (${response.status}).`);
  return data;
}

async function main() {
  const input = process.argv[2] || path.join(__dirname, 'data-orang-tua-generated.xlsx');
  const source = { rows: readGeneratedRows(input) };
  const [users, { data: siswa, error: siswaError }, { data: profiles, error: profilesError }] = await Promise.all([
    listAllAuthUsers(),
    sb.from('siswa').select('id, nis, nama'),
    sb.from('profiles').select('id, role, nama'),
  ]);
  if (siswaError) throw siswaError;
  if (profilesError) throw profilesError;
  const usersByEmail = new Map(users.map(user => [String(user.email || '').trim().toLowerCase(), user]));
  const profilesById = new Map((profiles || []).map(profile => [profile.id, profile]));
  const siswaByNis = new Map((siswa || []).map(student => [String(student.nis || '').trim().toLowerCase(), student]));
  const rows = source.rows;
  const results = { created: 0, reused: 0, linked: 0, skipped: 0, failed: 0, errors: [] };
  results.profile_success = 0;
  results.profile_failed = 0;
  results.relation_failed = 0;
  const linked = new Set();
  const { data: relations, error: relationError } = await sb.from('orang_tua_siswa').select('user_id, siswa_id');
  if (relationError) throw relationError;
  (relations || []).forEach(relation => linked.add(`${relation.user_id}:${relation.siswa_id}`));

  for (const row of rows) {
    try {
      const student = siswaByNis.get(row.nis.toLowerCase());
      if (!row.nama || !row.nis || !student) throw new Error('Nama atau siswa berdasarkan NIS tidak valid.');
      let user = usersByEmail.get(row.email);
      let profile = user ? profilesById.get(user.id) : null;
      if (user && profile && profile.role !== 'orang_tua') throw new Error('Email sudah digunakan akun non-orang_tua.');
      if (!user) {
        const data = await createAuthUser(row.email, row.password);
        // Supabase Auth Admin REST returns the user object directly (the JS
        // client wraps it as { data: { user } }).
        user = data.user || data;
        results.created++;
      } else results.reused++;
      if (!profile) {
        const { error: profileError } = await sb.from('profiles').insert({ id: user.id, nama: row.nama, role: 'orang_tua' });
        if (profileError) { results.profile_failed++; throw new Error(`Profile: ${profileError.message}`); }
        results.profile_success++;
      } else results.profile_success++;
      const key = `${user.id}:${student.id}`;
      if (linked.has(key)) { results.skipped++; continue; }
      const { error: insertError } = await sb.from('orang_tua_siswa').insert({ user_id: user.id, siswa_id: student.id, hubungan: 'ayah' });
      if (insertError) {
        if (/duplicate|already exists|unique/i.test(insertError.message || '')) { results.skipped++; continue; }
        results.relation_failed++;
        throw insertError;
      }
      linked.add(key); results.linked++;
    } catch (error) { results.failed++; results.errors.push({ row: row.excelRow, nama: row.nama, nis: row.nis, reason: error.message }); }
  }
  console.log(JSON.stringify(results, null, 2));
}

main().catch(error => { console.error('Pembuatan akun berhenti:', error.message); process.exitCode = 1; });
