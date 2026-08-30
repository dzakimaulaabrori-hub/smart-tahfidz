 # SMART TAHFIDZ — Production RLS Baseline

Source: Supabase Production pg_policies  
Audit mode: READ-ONLY  
Migration executed: NO  
Database modified: NO  

This document is a verbatim transcription of the production `pg_policies`
result supplied for this audit. `null` means the corresponding PostgreSQL
metadata column was NULL. Multiline `qual` and `with_check` expressions are
preserved as supplied.

Total policies captured: **49**

## Policy records

### 1. `absensi_siswa / absensi_delete`

- `schemaname`: `public`
- `tablename`: `absensi_siswa`
- `policyname`: `absensi_delete`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `DELETE`
- `qual`:

```sql
((my_role() = 'admin'::user_role) OR ((my_role() = 'wali_kelas'::user_role) AND (wali_kelas_id = auth.uid())))
```

- `with_check`: `null`

### 2. `absensi_siswa / absensi_insert`

- `schemaname`: `public`
- `tablename`: `absensi_siswa`
- `policyname`: `absensi_insert`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `INSERT`
- `qual`: `null`
- `with_check`:

```sql
((my_role() = 'wali_kelas'::user_role) AND (wali_kelas_id = auth.uid()))
```

### 3. `absensi_siswa / absensi_select`

- `schemaname`: `public`
- `tablename`: `absensi_siswa`
- `policyname`: `absensi_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`:

```sql
(is_admin_or_kepsek() OR (wali_kelas_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM orang_tua_siswa ots
  WHERE ((ots.siswa_id = absensi_siswa.siswa_id) AND (ots.user_id = auth.uid())))))
```

- `with_check`: `null`

### 4. `absensi_siswa / absensi_update`

- `schemaname`: `public`
- `tablename`: `absensi_siswa`
- `policyname`: `absensi_update`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `UPDATE`
- `qual`:

```sql
((my_role() = 'wali_kelas'::user_role) AND (wali_kelas_id = auth.uid()))
```

- `with_check`: `null`

### 5. `guru_quran_kelompok / gqk_select`

- `schemaname`: `public`
- `tablename`: `guru_quran_kelompok`
- `policyname`: `gqk_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`: `(is_admin_or_kepsek() OR (guru_id = auth.uid()))`
- `with_check`: `null`

### 6. `guru_quran_kelompok / gqk_write`

- `schemaname`: `public`
- `tablename`: `guru_quran_kelompok`
- `policyname`: `gqk_write`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `ALL`
- `qual`: `(my_role() = 'admin'::user_role)`
- `with_check`: `(my_role() = 'admin'::user_role)`

### 7. `indikator_karakter / indikator_karakter_select`

- `schemaname`: `public`
- `tablename`: `indikator_karakter`
- `policyname`: `indikator_karakter_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`: `(auth.uid() IS NOT NULL)`
- `with_check`: `null`

### 8. `indikator_karakter / indikator_karakter_write`

- `schemaname`: `public`
- `tablename`: `indikator_karakter`
- `policyname`: `indikator_karakter_write`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `ALL`
- `qual`: `(my_role() = 'admin'::user_role)`
- `with_check`: `(my_role() = 'admin'::user_role)`

### 9. `kelas / kelas_select`

- `schemaname`: `public`
- `tablename`: `kelas`
- `policyname`: `kelas_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`: `(auth.uid() IS NOT NULL)`
- `with_check`: `null`

### 10. `kelas / kelas_write`

- `schemaname`: `public`
- `tablename`: `kelas`
- `policyname`: `kelas_write`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `ALL`
- `qual`: `(my_role() = 'admin'::user_role)`
- `with_check`: `(my_role() = 'admin'::user_role)`

### 11. `kelompok_siswa / ks_select`

- `schemaname`: `public`
- `tablename`: `kelompok_siswa`
- `policyname`: `ks_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`:

```sql
(is_admin_or_kepsek() OR (EXISTS ( SELECT 1
   FROM guru_quran_kelompok g
  WHERE ((g.id = kelompok_siswa.kelompok_id) AND (g.guru_id = auth.uid())))))
```

- `with_check`: `null`

### 12. `kelompok_siswa / ks_write`

- `schemaname`: `public`
- `tablename`: `kelompok_siswa`
- `policyname`: `ks_write`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `ALL`
- `qual`: `(my_role() = 'admin'::user_role)`
- `with_check`: `(my_role() = 'admin'::user_role)`

### 13. `notifikasi / notif_insert`

- `schemaname`: `public`
- `tablename`: `notifikasi`
- `policyname`: `notif_insert`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `INSERT`
- `qual`: `null`
- `with_check`: `(auth.uid() IS NOT NULL)`

### 14. `notifikasi / notif_select_own`

- `schemaname`: `public`
- `tablename`: `notifikasi`
- `policyname`: `notif_select_own`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`: `(user_id = auth.uid())`
- `with_check`: `null`

### 15. `notifikasi / notif_update_own`

- `schemaname`: `public`
- `tablename`: `notifikasi`
- `policyname`: `notif_update_own`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `UPDATE`
- `qual`: `(user_id = auth.uid())`
- `with_check`: `null`

### 16. `orang_tua_siswa / ots_select`

- `schemaname`: `public`
- `tablename`: `orang_tua_siswa`
- `policyname`: `ots_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`: `(is_admin_or_kepsek() OR (user_id = auth.uid()))`
- `with_check`: `null`

### 17. `orang_tua_siswa / ots_write`

- `schemaname`: `public`
- `tablename`: `orang_tua_siswa`
- `policyname`: `ots_write`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `ALL`
- `qual`: `(my_role() = 'admin'::user_role)`
- `with_check`: `(my_role() = 'admin'::user_role)`

### 18. `penilaian_karakter / karakter_delete`

- `schemaname`: `public`
- `tablename`: `penilaian_karakter`
- `policyname`: `karakter_delete`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `DELETE`
- `qual`:

```sql
((my_role() = 'admin'::user_role) OR ((my_role() = 'wali_kelas'::user_role) AND (wali_kelas_id = auth.uid())))
```

- `with_check`: `null`

### 19. `penilaian_karakter / karakter_insert`

- `schemaname`: `public`
- `tablename`: `penilaian_karakter`
- `policyname`: `karakter_insert`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `INSERT`
- `qual`: `null`
- `with_check`:

```sql
((my_role() = 'wali_kelas'::user_role) AND (wali_kelas_id = auth.uid()))
```

### 20. `penilaian_karakter / karakter_select`

- `schemaname`: `public`
- `tablename`: `penilaian_karakter`
- `policyname`: `karakter_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`:

```sql
(is_admin_or_kepsek() OR (wali_kelas_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM orang_tua_siswa ots
  WHERE ((ots.siswa_id = penilaian_karakter.siswa_id) AND (ots.user_id = auth.uid())))))
```

- `with_check`: `null`

### 21. `penilaian_karakter / karakter_update`

- `schemaname`: `public`
- `tablename`: `penilaian_karakter`
- `policyname`: `karakter_update`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `UPDATE`
- `qual`: `((my_role() = 'wali_kelas'::user_role) AND (wali_kelas_id = auth.uid()))`
- `with_check`: `null`

### 22. `profiles / profiles_insert_admin`

- `schemaname`: `public`
- `tablename`: `profiles`
- `policyname`: `profiles_insert_admin`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `INSERT`
- `qual`: `null`
- `with_check`: `(my_role() = 'admin'::user_role)`

### 23. `profiles / profiles_select_all`

- `schemaname`: `public`
- `tablename`: `profiles`
- `policyname`: `profiles_select_all`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`: `(auth.uid() IS NOT NULL)`
- `with_check`: `null`

### 24. `profiles / profiles_update_own_or_admin`

- `schemaname`: `public`
- `tablename`: `profiles`
- `policyname`: `profiles_update_own_or_admin`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `UPDATE`
- `qual`: `((id = auth.uid()) OR (my_role() = 'admin'::user_role))`
- `with_check`: `null`

### 25. `quran_juz / quran master readable`

- `schemaname`: `public`
- `tablename`: `quran_juz`
- `policyname`: `quran master readable`
- `permissive`: `PERMISSIVE`
- `roles`: `{authenticated}`
- `cmd`: `SELECT`
- `qual`: `true`
- `with_check`: `null`

### 26. `quran_juz_surat / quran map readable`

- `schemaname`: `public`
- `tablename`: `quran_juz_surat`
- `policyname`: `quran map readable`
- `permissive`: `PERMISSIVE`
- `roles`: `{authenticated}`
- `cmd`: `SELECT`
- `qual`: `true`
- `with_check`: `null`

### 27. `quran_surat / quran surah readable`

- `schemaname`: `public`
- `tablename`: `quran_surat`
- `policyname`: `quran surah readable`
- `permissive`: `PERMISSIVE`
- `roles`: `{authenticated}`
- `cmd`: `SELECT`
- `qual`: `true`
- `with_check`: `null`

### 28. `rapor_periodik / rapor_select`

- `schemaname`: `public`
- `tablename`: `rapor_periodik`
- `policyname`: `rapor_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`:

```sql
(is_admin_or_kepsek() OR (EXISTS ( SELECT 1
   FROM (kelas k
     JOIN siswa s ON ((s.kelas_id = k.id)))
  WHERE ((s.id = rapor_periodik.siswa_id) AND (k.wali_kelas_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM orang_tua_siswa ots
  WHERE ((ots.siswa_id = rapor_periodik.siswa_id) AND (ots.user_id = auth.uid())))))
```

- `with_check`: `null`

### 29. `rapor_periodik / rapor_write`

- `schemaname`: `public`
- `tablename`: `rapor_periodik`
- `policyname`: `rapor_write`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `ALL`
- `qual`: `(my_role() = 'admin'::user_role)`
- `with_check`: `(my_role() = 'admin'::user_role)`

### 30. `siswa / siswa_select`

- `schemaname`: `public`
- `tablename`: `siswa`
- `policyname`: `siswa_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`:

```sql
(is_admin_or_kepsek() OR (my_role() = 'guru_quran'::user_role) OR (EXISTS ( SELECT 1
   FROM kelas
  WHERE ((kelas.id = siswa.kelas_id) AND (kelas.wali_kelas_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM orang_tua_siswa ots
  WHERE ((ots.siswa_id = siswa.id) AND (ots.user_id = auth.uid())))))
```

- `with_check`: `null`

### 31. `siswa / siswa_write`

- `schemaname`: `public`
- `tablename`: `siswa`
- `policyname`: `siswa_write`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `ALL`
- `qual`: `(my_role() = 'admin'::user_role)`
- `with_check`: `(my_role() = 'admin'::user_role)`

### 32. `tahfidz_quran / tahfidz_delete`

- `schemaname`: `public`
- `tablename`: `tahfidz_quran`
- `policyname`: `tahfidz_delete`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `DELETE`
- `qual`:

```sql
((my_role() = 'admin'::user_role) OR ((my_role() = 'guru_quran'::user_role) AND (guru_id = auth.uid())))
```

- `with_check`: `null`

### 33. `tahfidz_quran / tahfidz_insert`

- `schemaname`: `public`
- `tablename`: `tahfidz_quran`
- `policyname`: `tahfidz_insert`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `INSERT`
- `qual`: `null`
- `with_check`:

```sql
((my_role() = 'guru_quran'::user_role) AND (guru_id = auth.uid()))
```

### 34. `tahfidz_quran / tahfidz_select`

- `schemaname`: `public`
- `tablename`: `tahfidz_quran`
- `policyname`: `tahfidz_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`:

```sql
(is_admin_or_kepsek() OR (guru_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM (kelas k
     JOIN siswa s ON ((s.kelas_id = k.id)))
  WHERE ((s.id = tahfidz_quran.siswa_id) AND (k.wali_kelas_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM orang_tua_siswa ots
  WHERE ((ots.siswa_id = tahfidz_quran.siswa_id) AND (ots.user_id = auth.uid())))))
```

- `with_check`: `null`

### 35. `tahfidz_quran / tahfidz_update`

- `schemaname`: `public`
- `tablename`: `tahfidz_quran`
- `policyname`: `tahfidz_update`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `UPDATE`
- `qual`: `((my_role() = 'guru_quran'::user_role) AND (guru_id = auth.uid()))`
- `with_check`: `null`

### 36. `tahsin_quran / parent reads own child tahsin`

- `schemaname`: `public`
- `tablename`: `tahsin_quran`
- `policyname`: `parent reads own child tahsin`
- `permissive`: `PERMISSIVE`
- `roles`: `{authenticated}`
- `cmd`: `SELECT`
- `qual`:

```sql
(EXISTS ( SELECT 1
   FROM orang_tua_siswa r
  WHERE ((r.user_id = auth.uid()) AND (r.siswa_id = tahsin_quran.siswa_id))))
```

- `with_check`: `null`

### 37. `tahsin_quran / tahsin_delete`

- `schemaname`: `public`
- `tablename`: `tahsin_quran`
- `policyname`: `tahsin_delete`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `DELETE`
- `qual`:

```sql
((my_role() = 'admin'::user_role) OR ((my_role() = 'guru_quran'::user_role) AND (guru_id = auth.uid())))
```

- `with_check`: `null`

### 38. `tahsin_quran / tahsin_insert`

- `schemaname`: `public`
- `tablename`: `tahsin_quran`
- `policyname`: `tahsin_insert`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `INSERT`
- `qual`: `null`
- `with_check`:

```sql
((my_role() = 'guru_quran'::user_role) AND (guru_id = auth.uid()))
```

### 39. `tahsin_quran / tahsin_select`

- `schemaname`: `public`
- `tablename`: `tahsin_quran`
- `policyname`: `tahsin_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`:

```sql
(is_admin_or_kepsek() OR (guru_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM (kelas k
     JOIN siswa s ON ((s.kelas_id = k.id)))
  WHERE ((s.id = tahsin_quran.siswa_id) AND (k.wali_kelas_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM orang_tua_siswa ots
  WHERE ((ots.siswa_id = tahsin_quran.siswa_id) AND (ots.user_id = auth.uid())))))
```

- `with_check`: `null`

### 40. `tahsin_quran / tahsin_update`

- `schemaname`: `public`
- `tablename`: `tahsin_quran`
- `policyname`: `tahsin_update`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `UPDATE`
- `qual`: `((my_role() = 'guru_quran'::user_role) AND (guru_id = auth.uid()))`
- `with_check`: `null`

### 41. `tahun_ajaran / tahun_ajaran_select`

- `schemaname`: `public`
- `tablename`: `tahun_ajaran`
- `policyname`: `tahun_ajaran_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`: `(auth.uid() IS NOT NULL)`
- `with_check`: `null`

### 42. `tahun_ajaran / tahun_ajaran_write`

- `schemaname`: `public`
- `tablename`: `tahun_ajaran`
- `policyname`: `tahun_ajaran_write`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `ALL`
- `qual`: `(my_role() = 'admin'::user_role)`
- `with_check`: `(my_role() = 'admin'::user_role)`

### 43. `target_hafalan / target_hafalan_select`

- `schemaname`: `public`
- `tablename`: `target_hafalan`
- `policyname`: `target_hafalan_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`: `(auth.uid() IS NOT NULL)`
- `with_check`: `null`

### 44. `target_hafalan / target_hafalan_write`

- `schemaname`: `public`
- `tablename`: `target_hafalan`
- `policyname`: `target_hafalan_write`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `ALL`
- `qual`: `(my_role() = 'admin'::user_role)`
- `with_check`: `(my_role() = 'admin'::user_role)`

### 45. `tilawah_harian / tilawah_delete`

- `schemaname`: `public`
- `tablename`: `tilawah_harian`
- `policyname`: `tilawah_delete`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `DELETE`
- `qual`: `((my_role() = 'admin'::user_role) OR (my_role() = 'guru_quran'::user_role))`
- `with_check`: `null`

### 46. `tilawah_harian / tilawah_insert`

- `schemaname`: `public`
- `tablename`: `tilawah_harian`
- `policyname`: `tilawah_insert`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `INSERT`
- `qual`: `null`
- `with_check`:

```sql
(((my_role() = 'orang_tua'::user_role) AND (diusulkan_oleh = auth.uid()) AND (EXISTS ( SELECT 1
   FROM orang_tua_siswa ots
  WHERE ((ots.siswa_id = tilawah_harian.siswa_id) AND (ots.user_id = auth.uid()))))) OR ((my_role() = ANY (ARRAY['wali_kelas'::user_role, 'guru_quran'::user_role])) AND (diusulkan_oleh = auth.uid())))
```

### 47. `tilawah_harian / tilawah_select`

- `schemaname`: `public`
- `tablename`: `tilawah_harian`
- `policyname`: `tilawah_select`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `SELECT`
- `qual`:

```sql
(is_admin_or_kepsek() OR (my_role() = 'guru_quran'::user_role) OR (diusulkan_oleh = auth.uid()) OR (EXISTS ( SELECT 1
   FROM (kelas k
     JOIN siswa s ON ((s.kelas_id = k.id)))
  WHERE ((s.id = tilawah_harian.siswa_id) AND (k.wali_kelas_id = auth.uid())))))
```

- `with_check`: `null`

### 48. `tilawah_harian / tilawah_update_guru`

- `schemaname`: `public`
- `tablename`: `tilawah_harian`
- `policyname`: `tilawah_update_guru`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `UPDATE`
- `qual`: `(my_role() = 'guru_quran'::user_role)`
- `with_check`: `null`

### 49. `tilawah_harian / tilawah_update_ortu`

- `schemaname`: `public`
- `tablename`: `tilawah_harian`
- `policyname`: `tilawah_update_ortu`
- `permissive`: `PERMISSIVE`
- `roles`: `{public}`
- `cmd`: `UPDATE`
- `qual`: `((my_role() = 'orang_tua'::user_role) AND (diusulkan_oleh = auth.uid()) AND (status = 'pending'::tilawah_status))`
- `with_check`: `null`

## Role-helper audit scope

The supplied production extract contains policy references to `my_role()` and
`is_admin_or_kepsek()`. It does not contain function-definition rows for
`public.my_role()`, `public.is_admin_or_kepsek()`, or `public.has_role()`;
therefore no function body, `SECURITY DEFINER` flag, `search_path`, or ACL is
invented in this baseline. The local `has_role()` implementation remains a
LOCAL IMPLEMENTATION, not production metadata.

## Candidate multi-role updates

The following policy records contain `my_role()` and are candidates for a
membership-based update. Their expressions above are unchanged from the
supplied production result:

```text
absensi_delete
absensi_insert
absensi_update
gqk_write
indikator_karakter_write
kelas_write
ks_write
ots_write
karakter_delete
karakter_insert
karakter_update
profiles_insert_admin
profiles_update_own_or_admin
rapor_write
siswa_select
siswa_write
tahfidz_delete
tahfidz_insert
tahfidz_update
tahsin_delete
tahsin_insert
tahsin_update
tahun_ajaran_write
target_hafalan_write
tilawah_delete
tilawah_insert
tilawah_select
tilawah_update_guru
tilawah_update_ortu
```

The policies whose supplied expressions contain `is_admin_or_kepsek()` are:

```text
absensi_select
gqk_select
ks_select
ots_select
karakter_select
rapor_select
siswa_select
tahfidz_select
tahsin_select
tilawah_select
```
