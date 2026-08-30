# Multi-Role Deployment Checklist

Dokumen ini menjelaskan verifikasi setelah migration disetujui dan dijalankan oleh administrator.

## Prasyarat

1. Verifikasi enum `public.user_role` dan definisi policy production.
2. Review `supabase/migrations/20260830_add_additional_roles.sql`.
3. Review migration policy yang diperlukan setelah definisi `qual` dan `with_check` production tersedia.
4. Jalankan `supabase/verify_multirole_rls_after_migration.sql` setelah perubahan database diterapkan.
5. Pastikan source `create-parent-account` sudah diverifikasi di deployment Supabase karena source-nya tidak tersedia di repository.

## Model role

- `profiles.role` adalah role utama.
- `user_additional_roles.role` adalah role tambahan.
- Satu user tetap memiliki satu akun Auth.
- Role utama dan role tambahan tidak boleh duplikat.
- Akses role bersifat additive melalui `has_role(required_role)`.

## Test scenario

### Case 1 — Wali Kelas + Guru Quran

```text
profiles.role = wali_kelas
user_additional_roles.role = guru_quran
```

Expected:

- akses Wali Kelas = YES
- akses Guru Al-Qur'an = YES
- login = satu akun
- daftar akun = satu baris

### Case 2 — Guru Quran + Wali Kelas

```text
profiles.role = guru_quran
user_additional_roles.role = wali_kelas
```

Expected:

- akses Guru Al-Qur'an = YES
- akses Wali Kelas = YES
- login = satu akun
- daftar akun = satu baris

### Case 3 — Wali Kelas saja

```text
profiles.role = wali_kelas
additional roles = kosong
```

Expected:

- akses Wali Kelas = YES
- akses Guru Al-Qur'an = NO

### Case 4 — Guru Quran saja

```text
profiles.role = guru_quran
additional roles = kosong
```

Expected:

- akses Guru Al-Qur'an = YES
- akses Wali Kelas = NO

### Case 5 — Admin sebagai role tambahan

```text
profiles.role = wali_kelas
user_additional_roles.role = admin
```

Expected:

- authorization admin = YES jika kebijakan organisasi mengizinkan admin sebagai role tambahan
- akses tetap dibatasi oleh policy ownership dan status data
- tidak ada akun Auth kedua

### Case 6 — Orang Tua

```text
profiles.role = orang_tua
```

Expected:

- akses hanya pada siswa yang memiliki relasi `orang_tua_siswa`
- tidak ada akses global ke data siswa lain

### Case 7 — Tanpa role valid

```text
profiles.role = NULL atau tidak valid
additional roles = kosong
```

Expected:

- tidak mendapat akses role-specific
- tidak dapat mengelola role tambahan
- tidak dapat memakai akses admin

## Regression checks

- User multi-role tidak membuat row akun duplikat.
- Filter role menampilkan user pada setiap role yang dimilikinya.
- Role utama tidak dapat ditambahkan sebagai role tambahan.
- User biasa tidak dapat mengubah role tambahan.
- User orang tua tetap dibatasi `auth.uid()` dan relasi anak.
- Semua predicate `guru_id`, `wali_kelas_id`, `siswa_id`, `diusulkan_oleh`, ownership, dan status tetap berlaku.
- Tidak ada policy yang berubah menjadi hanya `has_role()` tanpa predicate data.
- Tidak ada service-role key di frontend.

