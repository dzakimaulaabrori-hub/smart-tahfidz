// Cloudflare Pages Function: privileged Admin account and empty-class actions.
// Secrets are read only from context.env and are never sent to the browser.

class HttpError extends Error {
  constructor(status, message, extra = {}) {
    super(message);
    this.status = status;
    Object.assign(this, extra);
  }
}

function json(request, env, status, body) {
  const allowedOrigin = env.ADMIN_ACCOUNTS_ORIGIN || '*';
  return new Response(status === 204 ? null : JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      'Access-Control-Allow-Origin': allowedOrigin,
      'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Vary': 'Origin',
    },
  });
}

function requiredEnv(env, names) {
  const missing = names.filter(name => !env[name]);
  if (missing.length) {
    throw new HttpError(503, `Konfigurasi credential Cloudflare belum lengkap: ${missing.join(', ')} belum diatur pada Pages Function.`);
  }
}

function supabaseUrl(env) {
  return String(env.SUPABASE_URL || '').replace(/\/$/, '');
}

async function supabaseFetch(env, path, options = {}, key = env.SUPABASE_SERVICE_ROLE_KEY) {
  const headers = new Headers(options.headers || {});
  headers.set('apikey', key);
  if (!headers.has('Authorization')) headers.set('Authorization', `Bearer ${key}`);
  if (options.body && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json');
  const response = await fetch(`${supabaseUrl(env)}${path}`, { ...options, headers });
  const text = await response.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch (_) { data = text; }
  if (!response.ok) {
    const message = data?.message || data?.msg || data?.error_description || data?.error || `Supabase request gagal (${response.status}).`;
    throw new HttpError(response.status, message, { code: data?.code });
  }
  return data;
}

function filterValue(value) {
  return encodeURIComponent(`eq.${String(value)}`);
}

async function requireAdmin(request, env) {
  requiredEnv(env, ['SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY']);
  const authorization = request.headers.get('Authorization') || '';
  const token = authorization.replace(/^Bearer\s+/i, '').trim();
  if (!token) throw new HttpError(401, 'Sesi admin tidak ditemukan.');

  const user = await supabaseFetch(env, '/auth/v1/user', {
    headers: { Authorization: `Bearer ${token}`, apikey: env.SUPABASE_ANON_KEY },
  }, env.SUPABASE_ANON_KEY).catch(() => {
    throw new HttpError(401, 'Sesi tidak valid atau sudah berakhir.');
  });
  const [profiles, additionalRoles] = await Promise.all([
    supabaseFetch(env, `/rest/v1/profiles?select=id,role&id=${filterValue(user.id)}&limit=1`),
    supabaseFetch(env, `/rest/v1/user_additional_roles?select=role&user_id=${filterValue(user.id)}`),
  ]);
  const isAdmin = profiles?.[0]?.role === 'admin'
    || (additionalRoles || []).some(row => row.role === 'admin');
  if (!isAdmin) {
    throw new HttpError(403, 'Hanya Admin yang dapat mengelola akun.');
  }
  return user;
}

function validateAccount(input) {
  const nama = String(input.nama || '').trim();
  const email = String(input.email || '').trim().toLowerCase();
  const password = String(input.password || '');
  const role = String(input.role || '').trim();
  const kelasId = input.kelas_id ? String(input.kelas_id) : null;
  const isKepalaSekolah = Boolean(input.is_kepala_sekolah);
  const roles = ['admin', 'guru_quran', 'kepala_sekolah', 'wali_kelas'];
  if (!nama) throw new HttpError(400, 'Nama wajib diisi.');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new HttpError(400, 'Email login tidak valid.');
  if (password.length < 6) throw new HttpError(400, 'Password awal minimal 6 karakter.');
  if (!roles.includes(role)) throw new HttpError(400, 'Role akun tidak tersedia.');
  if (kelasId && !['guru_quran', 'wali_kelas', 'kepala_sekolah'].includes(role)) {
    throw new HttpError(400, 'Penugasan kelas hanya tersedia untuk akun guru.');
  }
  return { nama, email, password, role, kelasId, isKepalaSekolah };
}

const VALID_ROLES = ['admin', 'wali_kelas', 'guru_quran', 'kepala_sekolah', 'orang_tua'];
function validateAdditionalRoles(input, primaryRole) {
  const roles = Array.isArray(input) ? input.map(role => String(role).trim()) : [];
  const unique = [...new Set(roles)];
  if (unique.some(role => !VALID_ROLES.includes(role))) {
    throw new HttpError(400, 'Role tambahan tidak tersedia.');
  }
  if (unique.includes(primaryRole)) {
    throw new HttpError(400, 'Role utama tidak boleh menjadi role tambahan.');
  }
  return unique;
}

async function createAccount(input, env) {
  const account = validateAccount(input);
  let created;
  try {
    created = await supabaseFetch(env, '/auth/v1/admin/users', {
      method: 'POST',
      body: JSON.stringify({ email: account.email, password: account.password, email_confirm: true }),
    });
  } catch (error) {
    if (/already|registered|duplicate|exists/i.test(error.message || '')) {
      throw new HttpError(409, 'Email sudah terdaftar.');
    }
    throw new HttpError(400, error.message);
  }

  const userId = created.id;
  try {
    await supabaseFetch(env, '/rest/v1/profiles', {
      method: 'POST',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify({ id: userId, nama: account.nama, role: account.role, is_kepala_sekolah: false }),
    });
    if (account.isKepalaSekolah) {
      await supabaseFetch(env, `/rest/v1/profiles?is_kepala_sekolah=eq.true&id=not.eq.${encodeURIComponent(userId)}`, {
        method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ is_kepala_sekolah: false }),
      });
      await supabaseFetch(env, `/rest/v1/profiles?id=${filterValue(userId)}`, {
        method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ is_kepala_sekolah: true }),
      });
    }
    if (account.kelasId) {
      await supabaseFetch(env, `/rest/v1/kelas?id=${filterValue(account.kelasId)}`, {
        method: 'PATCH', headers: { Prefer: 'return=minimal' }, body: JSON.stringify({ wali_kelas_id: userId }),
      });
    }
  } catch (error) {
    // Compensating cleanup prevents an Auth user without its required profile.
    await supabaseFetch(env, `/auth/v1/admin/users/${encodeURIComponent(userId)}`, { method: 'DELETE' }).catch(() => {});
    throw new HttpError(400, 'Akun tidak dibuat: ' + error.message);
  }
  return { id: userId, nama: account.nama, email: account.email, role: account.role };
}

async function listAccounts(env) {
  const [userPage, profiles, additionalRoles, classes] = await Promise.all([
    supabaseFetch(env, '/auth/v1/admin/users?page=1&per_page=1000'),
    supabaseFetch(env, '/rest/v1/profiles?select=id,nama,role,is_kepala_sekolah&order=nama.asc'),
    supabaseFetch(env, '/rest/v1/user_additional_roles?select=user_id,role&order=role.asc'),
    supabaseFetch(env, '/rest/v1/kelas?select=id,nama_kelas,wali_kelas_id&order=nama_kelas.asc'),
  ]);
  const classByTeacher = {};
  (classes || []).forEach(k => { if (k.wali_kelas_id) (classByTeacher[k.wali_kelas_id] ||= []).push(k.nama_kelas); });
  const profileById = Object.fromEntries((profiles || []).map(p => [p.id, p]));
  const additionalByUser = {};
  (additionalRoles || []).forEach(row => { (additionalByUser[row.user_id] ||= []).push(row.role); });
  return (userPage?.users || []).map(user => ({
    id: user.id,
    email: user.email || '',
    status: user.banned_until ? 'Diblokir' : 'Aktif',
    ...(profileById[user.id] || { nama: '-', role: 'belum ada profil', is_kepala_sekolah: false }),
    additional_roles: additionalByUser[user.id] || [],
    roles: [profileById[user.id]?.role, ...(additionalByUser[user.id] || [])].filter(Boolean),
    wali_kelas: classByTeacher[user.id] || [],
  }));
}

async function setAdditionalRoles(input, env) {
  const userId = String(input.user_id || '').trim();
  if (!userId) throw new HttpError(400, 'User ID tidak valid.');
  const profiles = await supabaseFetch(env, `/rest/v1/profiles?select=id,role&id=${filterValue(userId)}&limit=1`);
  if (!profiles?.[0]) throw new HttpError(404, 'Profil akun tidak ditemukan.');
  const roles = validateAdditionalRoles(input.roles, profiles[0].role);
  const existing = await supabaseFetch(env, `/rest/v1/user_additional_roles?select=role&user_id=${filterValue(userId)}`);
  const existingRoles = new Set((existing || []).map(row => row.role));
  const remove = [...existingRoles].filter(role => !roles.includes(role));
  const add = roles.filter(role => !existingRoles.has(role));
  if (remove.length) {
    await Promise.all(remove.map(role => supabaseFetch(env, `/rest/v1/user_additional_roles?user_id=${filterValue(userId)}&role=${filterValue(role)}`, {
      method: 'DELETE', headers: { Prefer: 'return=minimal' },
    })));
  }
  if (add.length) {
    await supabaseFetch(env, '/rest/v1/user_additional_roles', {
      method: 'POST', headers: { Prefer: 'return=minimal' },
      body: JSON.stringify(add.map(role => ({ user_id: userId, role }))),
    });
  }
  return { user_id: userId, additional_roles: roles };
}

async function deleteEmptyClass(classId, env) {
  if (!classId || typeof classId !== 'string') throw new HttpError(400, 'ID kelas tidak valid.');
  const kelas = (await supabaseFetch(env, `/rest/v1/kelas?select=id,nama_kelas&id=${filterValue(classId)}&limit=1`))[0];
  if (!kelas) throw new HttpError(404, 'Kelas tidak ditemukan.');
  const students = await supabaseFetch(env, `/rest/v1/siswa?select=id&kelas_id=${filterValue(classId)}`);
  if ((students || []).length) throw new HttpError(409, `Kelas ${kelas.nama_kelas} tidak dapat dihapus karena masih memiliki ${students.length} siswa terkait.`);
  const targets = await supabaseFetch(env, `/rest/v1/target_hafalan?select=kelas_id&kelas_id=${filterValue(classId)}`);
  if ((targets || []).length) {
    await supabaseFetch(env, `/rest/v1/target_hafalan?kelas_id=${filterValue(classId)}`, { method: 'DELETE', headers: { Prefer: 'return=minimal' } });
  }
  try {
    await supabaseFetch(env, `/rest/v1/kelas?id=${filterValue(classId)}`, { method: 'DELETE', headers: { Prefer: 'return=minimal' } });
  } catch (error) {
    throw new HttpError(409, `Target hafalan kelas ${kelas.nama_kelas} sudah dihapus, tetapi kelas gagal dihapus: ${error.message}. Tidak ada cleanup tambahan yang dijalankan.`, { partialFailure: true });
  }
  return { id: classId, nama_kelas: kelas.nama_kelas, deleted_target_hafalan: (targets || []).length };
}

export async function onRequestOptions({ request, env }) {
  return json(request, env, 204, {});
}

export async function onRequestPost({ request, env }) {
  try {
    await requireAdmin(request, env);
    const input = await request.json();
    if (input.action === 'list') return json(request, env, 200, { accounts: await listAccounts(env) });
    if (input.action === 'create') return json(request, env, 201, { account: await createAccount(input, env) });
    if (input.action === 'set_additional_roles') return json(request, env, 200, { account: await setAdditionalRoles(input, env) });
    if (input.action === 'delete_empty_class') return json(request, env, 200, { result: await deleteEmptyClass(input.class_id, env) });
    throw new HttpError(400, 'Action tidak dikenal.');
  } catch (error) {
    return json(request, env, error.status || 500, { error: error.message || 'Kesalahan server.', partial_failure: Boolean(error.partialFailure) });
  }
}
