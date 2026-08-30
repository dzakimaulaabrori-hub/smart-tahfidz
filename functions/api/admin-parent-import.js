// Cloudflare Pages Function untuk import relasi orang_tua_siswa.
// Tidak membuat user Auth baru: email pada file harus sudah memiliki akun
// orang_tua yang dibuat melalui mekanisme akun yang sudah ada.

class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

function json(env, status, body) {
  return new Response(status === 204 ? null : JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'Access-Control-Allow-Origin': env.ADMIN_ACCOUNTS_ORIGIN || '*',
      'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      Vary: 'Origin',
    },
  });
}

function filterValue(value) { return encodeURIComponent(`eq.${String(value)}`); }
function requiredEnv(env) {
  const missing = ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY'].filter(k => !env[k]);
  if (missing.length) throw new HttpError(503, `Konfigurasi Function belum lengkap: ${missing.join(', ')}.`);
}
async function supabaseFetch(env, path, options = {}, key = env.SUPABASE_SERVICE_ROLE_KEY) {
  const headers = new Headers(options.headers || {});
  headers.set('apikey', key);
  if (!headers.has('Authorization')) headers.set('Authorization', `Bearer ${key}`);
  if (options.body && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json');
  const response = await fetch(`${String(env.SUPABASE_URL).replace(/\/$/, '')}${path}`, { ...options, headers });
  const text = await response.text();
  let data; try { data = text ? JSON.parse(text) : null; } catch (_) { data = null; }
  if (!response.ok) throw new HttpError(response.status, data?.message || data?.msg || data?.error || `Supabase request gagal (${response.status}).`);
  return data;
}
async function requireAdmin(request, env) {
  requiredEnv(env);
  const token = (request.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '').trim();
  if (!token) throw new HttpError(401, 'Sesi admin tidak ditemukan.');
  let user;
  try {
    user = await supabaseFetch(env, '/auth/v1/user', { headers: { Authorization: `Bearer ${token}`, apikey: env.SUPABASE_ANON_KEY } }, env.SUPABASE_ANON_KEY);
  } catch (_) { throw new HttpError(401, 'Sesi tidak valid atau sudah berakhir.'); }
  const [profiles, additionalRoles] = await Promise.all([
    supabaseFetch(env, `/rest/v1/profiles?select=id,role&id=${filterValue(user.id)}&limit=1`),
    supabaseFetch(env, `/rest/v1/user_additional_roles?select=role&user_id=${filterValue(user.id)}`),
  ]);
  const isAdmin = profiles?.[0]?.role === 'admin'
    || (additionalRoles || []).some(row => row.role === 'admin');
  if (!isAdmin) throw new HttpError(403, 'Hanya Admin yang dapat mengimpor data orang tua.');
}

function validateRows(rows) {
  if (!Array.isArray(rows)) throw new HttpError(400, 'Data Excel tidak valid.');
  if (rows.length > 5000) throw new HttpError(400, 'Maksimal 5.000 baris per import.');
  return rows;
}

async function importParents(rows, env) {
  const [usersResponse, profiles, additionalRoles, students, relations] = await Promise.all([
    supabaseFetch(env, '/auth/v1/admin/users?page=1&per_page=1000'),
    supabaseFetch(env, '/rest/v1/profiles?select=id,nama,role'),
    supabaseFetch(env, '/rest/v1/user_additional_roles?select=user_id,role'),
    supabaseFetch(env, '/rest/v1/siswa?select=id,nis,nama'),
    supabaseFetch(env, '/rest/v1/orang_tua_siswa?select=user_id,siswa_id'),
  ]);
  const profileById = Object.fromEntries((profiles || []).map(p => [p.id, p]));
  const additionalByUser = {};
  (additionalRoles || []).forEach(row => { (additionalByUser[row.user_id] ||= []).push(row.role); });
  const userByEmail = Object.fromEntries((usersResponse?.users || []).map(u => [String(u.email || '').trim().toLowerCase(), u]));
  const studentByNis = Object.fromEntries((students || []).map(s => [String(s.nis || '').trim().toLowerCase(), s]));
  const existing = new Set((relations || []).map(r => `${r.user_id}:${r.siswa_id}`));
  const result = { read: rows.length, success: 0, failed: 0, skipped: 0, errors: [] };
  const seen = new Set();

  for (const [index, raw] of rows.entries()) {
    const excelRow = index + 2;
    const email = String(raw.email ?? '').trim().toLowerCase();
    const nis = String(raw.nis_anak ?? '').trim();
    const hubungan = String(raw.hubungan ?? '').trim().toLowerCase();
    let studentName = nis || '-';
    const fail = reason => { result.failed++; result.errors.push({ row: excelRow, nama_siswa: studentName, reason }); };
    if (!email || !nis || !hubungan) { fail('Kolom wajib kosong (email, nis_anak, atau hubungan).'); continue; }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { fail('Format email orang tua tidak valid.'); continue; }
    if (!['ayah', 'ibu', 'wali'].includes(hubungan)) { fail('Hubungan harus ayah, ibu, atau wali.'); continue; }
    const student = studentByNis[nis.toLowerCase()];
    if (student) studentName = student.nama || nis;
    if (!student) { fail('Siswa dengan NIS tersebut tidak ditemukan.'); continue; }
    const user = userByEmail[email];
    if (!user) { fail('Akun Auth dengan email tersebut tidak ditemukan. Buat akun orang tua terlebih dahulu.'); continue; }
    const profile = profileById[user.id];
    if (!profile || (profile.role !== 'orang_tua' && !(additionalByUser[user.id] || []).includes('orang_tua'))) {
      fail('Email tidak terdaftar sebagai akun orang_tua.'); continue;
    }
    const key = `${user.id}:${student.id}`;
    if (existing.has(key) || seen.has(key)) { result.skipped++; continue; }
    try {
      await supabaseFetch(env, '/rest/v1/orang_tua_siswa', {
        method: 'POST', headers: { Prefer: 'return=minimal' },
        body: JSON.stringify({ user_id: user.id, siswa_id: student.id, hubungan }),
      });
      seen.add(key); result.success++;
    } catch (error) {
      if (/duplicate|already exists|unique/i.test(error.message || '')) result.skipped++;
      else fail(error.message || 'Gagal menyimpan relasi.');
    }
  }
  return result;
}

export async function onRequestOptions({ env }) { return json(env, 204, {}); }
export async function onRequestPost({ request, env }) {
  try {
    await requireAdmin(request, env);
    const input = await request.json();
    return json(env, 200, { result: await importParents(validateRows(input.rows), env) });
  } catch (error) { return json(env, error.status || 500, { error: error.message || 'Kesalahan server.' }); }
}
