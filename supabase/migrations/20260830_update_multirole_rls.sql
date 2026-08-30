-- SMART TAHFIDZ: make the production role-sensitive policies additive-role
-- aware. The policy metadata and non-role predicates are preserved from
-- supabase/production_rls_baseline.md. Run only after reviewing both
-- migrations; this file is not executed by the application.

-- absensi_siswa
drop policy if exists absensi_delete on public.absensi_siswa;
create policy absensi_delete
on public.absensi_siswa
as permissive
for delete
to public
using (
  (public.has_role('admin'::public.user_role) OR ((public.has_role('wali_kelas'::public.user_role)) AND (wali_kelas_id = auth.uid())))
);

drop policy if exists absensi_insert on public.absensi_siswa;
create policy absensi_insert
on public.absensi_siswa
as permissive
for insert
to public
with check (
  (public.has_role('wali_kelas'::public.user_role) AND (wali_kelas_id = auth.uid()))
);

drop policy if exists absensi_update on public.absensi_siswa;
create policy absensi_update
on public.absensi_siswa
as permissive
for update
to public
using (
  (public.has_role('wali_kelas'::public.user_role) AND (wali_kelas_id = auth.uid()))
);

-- guru_quran_kelompok
drop policy if exists gqk_write on public.guru_quran_kelompok;
create policy gqk_write
on public.guru_quran_kelompok
as permissive
for all
to public
using (public.has_role('admin'::public.user_role))
with check (public.has_role('admin'::public.user_role));

-- indikator_karakter
drop policy if exists indikator_karakter_write on public.indikator_karakter;
create policy indikator_karakter_write
on public.indikator_karakter
as permissive
for all
to public
using (public.has_role('admin'::public.user_role))
with check (public.has_role('admin'::public.user_role));

-- kelas
drop policy if exists kelas_write on public.kelas;
create policy kelas_write
on public.kelas
as permissive
for all
to public
using (public.has_role('admin'::public.user_role))
with check (public.has_role('admin'::public.user_role));

-- kelompok_siswa
drop policy if exists ks_write on public.kelompok_siswa;
create policy ks_write
on public.kelompok_siswa
as permissive
for all
to public
using (public.has_role('admin'::public.user_role))
with check (public.has_role('admin'::public.user_role));

-- orang_tua_siswa
drop policy if exists ots_write on public.orang_tua_siswa;
create policy ots_write
on public.orang_tua_siswa
as permissive
for all
to public
using (public.has_role('admin'::public.user_role))
with check (public.has_role('admin'::public.user_role));

-- penilaian_karakter
drop policy if exists karakter_delete on public.penilaian_karakter;
create policy karakter_delete
on public.penilaian_karakter
as permissive
for delete
to public
using (
  (public.has_role('admin'::public.user_role) OR ((public.has_role('wali_kelas'::public.user_role)) AND (wali_kelas_id = auth.uid())))
);

drop policy if exists karakter_insert on public.penilaian_karakter;
create policy karakter_insert
on public.penilaian_karakter
as permissive
for insert
to public
with check (
  (public.has_role('wali_kelas'::public.user_role) AND (wali_kelas_id = auth.uid()))
);

drop policy if exists karakter_update on public.penilaian_karakter;
create policy karakter_update
on public.penilaian_karakter
as permissive
for update
to public
using (
  (public.has_role('wali_kelas'::public.user_role) AND (wali_kelas_id = auth.uid()))
);

-- profiles
drop policy if exists profiles_insert_admin on public.profiles;
create policy profiles_insert_admin
on public.profiles
as permissive
for insert
to public
with check (public.has_role('admin'::public.user_role));

drop policy if exists profiles_update_own_or_admin on public.profiles;
create policy profiles_update_own_or_admin
on public.profiles
as permissive
for update
to public
using ((id = auth.uid()) OR public.has_role('admin'::public.user_role));

-- rapor_periodik
drop policy if exists rapor_write on public.rapor_periodik;
create policy rapor_write
on public.rapor_periodik
as permissive
for all
to public
using (public.has_role('admin'::public.user_role))
with check (public.has_role('admin'::public.user_role));

-- siswa
drop policy if exists siswa_select on public.siswa;
create policy siswa_select
on public.siswa
as permissive
for select
to public
using (
  (is_admin_or_kepsek() OR public.has_role('guru_quran'::public.user_role) OR (EXISTS ( SELECT 1
   FROM kelas
  WHERE ((kelas.id = siswa.kelas_id) AND (kelas.wali_kelas_id = auth.uid())))) OR (EXISTS ( SELECT 1
   FROM orang_tua_siswa ots
  WHERE ((ots.siswa_id = siswa.id) AND (ots.user_id = auth.uid())))))
);

drop policy if exists siswa_write on public.siswa;
create policy siswa_write
on public.siswa
as permissive
for all
to public
using (public.has_role('admin'::public.user_role))
with check (public.has_role('admin'::public.user_role));

-- tahfidz_quran
drop policy if exists tahfidz_delete on public.tahfidz_quran;
create policy tahfidz_delete
on public.tahfidz_quran
as permissive
for delete
to public
using (
  (public.has_role('admin'::public.user_role) OR ((public.has_role('guru_quran'::public.user_role)) AND (guru_id = auth.uid())))
);

drop policy if exists tahfidz_insert on public.tahfidz_quran;
create policy tahfidz_insert
on public.tahfidz_quran
as permissive
for insert
to public
with check (
  (public.has_role('guru_quran'::public.user_role) AND (guru_id = auth.uid()))
);

drop policy if exists tahfidz_update on public.tahfidz_quran;
create policy tahfidz_update
on public.tahfidz_quran
as permissive
for update
to public
using (
  (public.has_role('guru_quran'::public.user_role) AND (guru_id = auth.uid()))
);

-- tahsin_quran
drop policy if exists tahsin_delete on public.tahsin_quran;
create policy tahsin_delete
on public.tahsin_quran
as permissive
for delete
to public
using (
  (public.has_role('admin'::public.user_role) OR ((public.has_role('guru_quran'::public.user_role)) AND (guru_id = auth.uid())))
);

drop policy if exists tahsin_insert on public.tahsin_quran;
create policy tahsin_insert
on public.tahsin_quran
as permissive
for insert
to public
with check (
  (public.has_role('guru_quran'::public.user_role) AND (guru_id = auth.uid()))
);

drop policy if exists tahsin_update on public.tahsin_quran;
create policy tahsin_update
on public.tahsin_quran
as permissive
for update
to public
using (
  (public.has_role('guru_quran'::public.user_role) AND (guru_id = auth.uid()))
);

-- tahun_ajaran
drop policy if exists tahun_ajaran_write on public.tahun_ajaran;
create policy tahun_ajaran_write
on public.tahun_ajaran
as permissive
for all
to public
using (public.has_role('admin'::public.user_role))
with check (public.has_role('admin'::public.user_role));

-- target_hafalan
drop policy if exists target_hafalan_write on public.target_hafalan;
create policy target_hafalan_write
on public.target_hafalan
as permissive
for all
to public
using (public.has_role('admin'::public.user_role))
with check (public.has_role('admin'::public.user_role));

-- tilawah_harian
drop policy if exists tilawah_delete on public.tilawah_harian;
create policy tilawah_delete
on public.tilawah_harian
as permissive
for delete
to public
using (
  (public.has_role('admin'::public.user_role) OR public.has_role('guru_quran'::public.user_role))
);

drop policy if exists tilawah_insert on public.tilawah_harian;
create policy tilawah_insert
on public.tilawah_harian
as permissive
for insert
to public
with check (
  (((public.has_role('orang_tua'::public.user_role)) AND (diusulkan_oleh = auth.uid()) AND (EXISTS ( SELECT 1
   FROM orang_tua_siswa ots
  WHERE ((ots.siswa_id = tilawah_harian.siswa_id) AND (ots.user_id = auth.uid()))))) OR ((public.has_role('wali_kelas'::public.user_role) OR public.has_role('guru_quran'::public.user_role)) AND (diusulkan_oleh = auth.uid())))
);

drop policy if exists tilawah_select on public.tilawah_harian;
create policy tilawah_select
on public.tilawah_harian
as permissive
for select
to public
using (
  (is_admin_or_kepsek() OR public.has_role('guru_quran'::public.user_role) OR (diusulkan_oleh = auth.uid()) OR (EXISTS ( SELECT 1
   FROM (kelas k
     JOIN siswa s ON ((s.kelas_id = k.id)))
  WHERE ((s.id = tilawah_harian.siswa_id) AND (k.wali_kelas_id = auth.uid())))))
);

drop policy if exists tilawah_update_guru on public.tilawah_harian;
create policy tilawah_update_guru
on public.tilawah_harian
as permissive
for update
to public
using (public.has_role('guru_quran'::public.user_role));

drop policy if exists tilawah_update_ortu on public.tilawah_harian;
create policy tilawah_update_ortu
on public.tilawah_harian
as permissive
for update
to public
using (
  (public.has_role('orang_tua'::public.user_role) AND (diusulkan_oleh = auth.uid()) AND (status = 'pending'::tilawah_status))
);
