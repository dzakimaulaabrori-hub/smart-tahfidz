const { createClient } = require('@supabase/supabase-js');

const corsHeaders = {
  'Access-Control-Allow-Origin': process.env.ADMIN_ACCOUNTS_ORIGIN || '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (statusCode, body) => ({
  statusCode,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});

function serviceClient() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const missing = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'].filter(name => !process.env[name]);
  if (missing.length) throw Object.assign(new Error(`Konfigurasi credential server belum lengkap: ${missing.join(', ')} belum diatur di Netlify Function.`), { statusCode: 503 });
  return createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } });
}

async function requireAdmin(event, adminClient) {
  const header = event.headers.authorization || event.headers.Authorization || '';
  const token = header.replace(/^Bearer\s+/i, '').trim();
  if (!token) throw Object.assign(new Error('Sesi admin tidak ditemukan.'), { statusCode: 401 });

  // Validate the caller's JWT with the public client. The service key never
  // leaves this function and is not used to trust a client-supplied role.
  if (!process.env.SUPABASE_ANON_KEY) {
    throw Object.assign(new Error('Konfigurasi credential server belum lengkap: SUPABASE_ANON_KEY belum diatur di Netlify Function.'), { statusCode: 503 });
  }
  const publicClient = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: userError } = await publicClient.auth.getUser(token);
  if (userError || !user) throw Object.assign(new Error('Sesi tidak valid atau sudah berakhir.'), { statusCode: 401 });
  const { data: profile, error: profileError } = await adminClient
    .from('profiles').select('id, role').eq('id', user.id).maybeSingle();
  const { data: additionalRoles, error: additionalRoleError } = await adminClient
    .from('user_additional_roles').select('role').eq('user_id', user.id);
  const isAdmin = profile?.role === 'admin' || (additionalRoles || []).some(row => row.role === 'admin');
  if (profileError || additionalRoleError || !profile || !isAdmin) {
    throw Object.assign(new Error('Hanya Admin yang dapat mengelola akun.'), { statusCode: 403 });
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
  if (!nama) throw new Error('Nama wajib diisi.');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new Error('Email login tidak valid.');
  if (password.length < 6) throw new Error('Password awal minimal 6 karakter.');
  if (!roles.includes(role)) throw new Error('Role akun tidak tersedia.');
  if (kelasId && !['guru_quran', 'wali_kelas', 'kepala_sekolah'].includes(role)) {
    throw new Error('Penugasan kelas hanya tersedia untuk akun guru.');
  }
  return { nama, email, password, role, kelasId, isKepalaSekolah };
}

const VALID_ADDITIONAL_ROLES = ['admin', 'wali_kelas', 'guru_quran', 'kepala_sekolah', 'orang_tua'];
async function setAdditionalRoles(input, sb) {
  const userId = String(input.user_id || '').trim();
  const { data: profile, error: profileError } = await sb.from('profiles').select('id, role').eq('id', userId).maybeSingle();
  if (profileError || !profile) throw Object.assign(new Error('Profil akun tidak ditemukan.'), { statusCode: 404 });
  const roles = [...new Set(Array.isArray(input.roles) ? input.roles.map(role => String(role).trim()) : [])];
  if (roles.some(role => !VALID_ADDITIONAL_ROLES.includes(role)) || roles.includes(profile.role)) {
    throw Object.assign(new Error('Role tambahan tidak valid atau sama dengan role utama.'), { statusCode: 400 });
  }
  const { data: existing, error: existingError } = await sb.from('user_additional_roles').select('role').eq('user_id', userId);
  if (existingError) throw new Error(existingError.message);
  const existingRoles = new Set((existing || []).map(row => row.role));
  const remove = [...existingRoles].filter(role => !roles.includes(role));
  const add = roles.filter(role => !existingRoles.has(role));
  for (const role of remove) {
    const { error } = await sb.from('user_additional_roles').delete().eq('user_id', userId).eq('role', role);
    if (error) throw new Error(error.message);
  }
  if (add.length) {
    const { error } = await sb.from('user_additional_roles').insert(add.map(role => ({ user_id: userId, role })));
    if (error) throw new Error(error.message);
  }
  return { user_id: userId, additional_roles: roles };
}

async function createAccount(input, sb) {
  const account = validateAccount(input);
  const { data: created, error: authError } = await sb.auth.admin.createUser({
    email: account.email,
    password: account.password,
    email_confirm: true,
  });
  if (authError) {
    const duplicate = /already|registered|duplicate|exists/i.test(authError.message || '');
    throw Object.assign(new Error(duplicate ? 'Email sudah terdaftar.' : authError.message), { statusCode: duplicate ? 409 : 400 });
  }

  const userId = created.user.id;
  try {
    const { error: profileError } = await sb.from('profiles').insert({
      id: userId,
      nama: account.nama,
      role: account.role,
      // Insert false first so the existing partial unique index can never
      // reject a replacement principal during account creation.
      is_kepala_sekolah: false,
    });
    if (profileError) throw new Error(profileError.message);

    if (account.isKepalaSekolah) {
      const { error } = await sb.from('profiles').update({ is_kepala_sekolah: false })
        .eq('is_kepala_sekolah', true).neq('id', userId);
      if (error) throw new Error(error.message);
      const { error: setError } = await sb.from('profiles').update({ is_kepala_sekolah: true }).eq('id', userId);
      if (setError) throw new Error(setError.message);
    }
    if (account.kelasId) {
      const { error } = await sb.from('kelas').update({ wali_kelas_id: userId }).eq('id', account.kelasId);
      if (error) throw new Error(error.message);
    }
  } catch (error) {
    // Compensating cleanup prevents an auth user without its required profile.
    await sb.auth.admin.deleteUser(userId);
    throw Object.assign(new Error('Akun tidak dibuat: ' + error.message), { statusCode: 400 });
  }
  return { id: userId, nama: account.nama, email: account.email, role: account.role };
}

async function listAccounts(sb) {
  const [{ data: userPage, error: usersError }, { data: profiles, error: profilesError }, { data: additionalRoles, error: additionalRoleError }, { data: classes, error: classesError }] = await Promise.all([
    sb.auth.admin.listUsers({ page: 1, perPage: 1000 }),
    sb.from('profiles').select('id, nama, role, is_kepala_sekolah').order('nama'),
    sb.from('user_additional_roles').select('user_id, role').order('role'),
    sb.from('kelas').select('id, nama_kelas, wali_kelas_id').order('nama_kelas'),
  ]);
  if (usersError || profilesError || additionalRoleError || classesError) throw new Error((usersError || profilesError || additionalRoleError || classesError).message);
  const classByTeacher = {};
  (classes || []).forEach(k => { if (k.wali_kelas_id) (classByTeacher[k.wali_kelas_id] ||= []).push(k.nama_kelas); });
  const profileById = Object.fromEntries((profiles || []).map(p => [p.id, p]));
  const additionalByUser = {};
  (additionalRoles || []).forEach(row => { (additionalByUser[row.user_id] ||= []).push(row.role); });
  return ((userPage && userPage.users) || []).map(u => ({
    id: u.id, email: u.email || '', status: u.banned_until ? 'Diblokir' : 'Aktif',
    ...(profileById[u.id] || { nama: '-', role: 'belum ada profil', is_kepala_sekolah: false }),
    additional_roles: additionalByUser[u.id] || [],
    roles: [profileById[u.id]?.role, ...(additionalByUser[u.id] || [])].filter(Boolean),
    wali_kelas: classByTeacher[u.id] || [],
  }));
}

async function deleteEmptyClass(classId, sb) {
  if (!classId || typeof classId !== 'string') {
    throw Object.assign(new Error('ID kelas tidak valid.'), { statusCode: 400 });
  }
  const { data: kelas, error: classLookupError } = await sb.from('kelas')
    .select('id, nama_kelas').eq('id', classId).maybeSingle();
  if (classLookupError) throw new Error(classLookupError.message);
  if (!kelas) throw Object.assign(new Error('Kelas tidak ditemukan.'), { statusCode: 404 });

  // Source-of-truth preflight. Do not use a display count and do not filter
  // by student status: every siswa row blocks removal.
  const { data: students, error: studentError } = await sb.from('siswa')
    .select('id').eq('kelas_id', classId);
  if (studentError) throw new Error('Gagal memeriksa siswa kelas: ' + studentError.message);
  if ((students || []).length > 0) {
    throw Object.assign(new Error(`Kelas ${kelas.nama_kelas} tidak dapat dihapus karena masih memiliki ${(students || []).length} siswa terkait.`), { statusCode: 409 });
  }

  const { data: targets, error: targetLookupError } = await sb.from('target_hafalan')
    .select('kelas_id').eq('kelas_id', classId);
  if (targetLookupError) throw new Error('Gagal memeriksa target hafalan kelas: ' + targetLookupError.message);

  // Supabase JS does not provide a transaction for two arbitrary PostgREST
  // mutations. This is therefore deliberately ordered and guarded: no target
  // is touched while a student exists; if the second mutation fails, return a
  // clear partial-failure warning and do not perform further cleanup.
  if ((targets || []).length > 0) {
    const { error: targetDeleteError } = await sb.from('target_hafalan').delete().eq('kelas_id', classId);
    if (targetDeleteError) throw new Error('Target hafalan tidak dihapus sehingga kelas juga tidak dihapus: ' + targetDeleteError.message);
  }
  const { error: classDeleteError } = await sb.from('kelas').delete().eq('id', classId);
  if (classDeleteError) {
    throw Object.assign(new Error(`Target hafalan kelas ${kelas.nama_kelas} sudah dihapus, tetapi kelas gagal dihapus: ${classDeleteError.message}. Tidak ada cleanup tambahan yang dijalankan.`), { statusCode: 409, partialFailure: true });
  }
  return { id: classId, nama_kelas: kelas.nama_kelas, deleted_target_hafalan: (targets || []).length };
}

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return json(204, {});
  if (event.httpMethod !== 'POST') return json(405, { error: 'Method tidak diizinkan.' });
  try {
    const sb = serviceClient();
    await requireAdmin(event, sb);
    const input = JSON.parse(event.body || '{}');
    if (input.action === 'list') return json(200, { accounts: await listAccounts(sb) });
    if (input.action === 'create') return json(201, { account: await createAccount(input, sb) });
    if (input.action === 'set_additional_roles') return json(200, { account: await setAdditionalRoles(input, sb) });
    if (input.action === 'delete_empty_class') return json(200, { result: await deleteEmptyClass(input.class_id, sb) });
    return json(400, { error: 'Action tidak dikenal.' });
  } catch (error) {
    return json(error.statusCode || 500, { error: error.message || 'Kesalahan server.', partial_failure: Boolean(error.partialFailure) });
  }
};
