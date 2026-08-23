-- SMART TAHFIDZ: read-only Supabase diagnostics.
-- Jalankan setelah schema.sql dan seed.sql. File ini tidak mengubah data.

-- 1. Jumlah master: diharapkan 30 juz dan 114 surat.
select 'jumlah_juz' as pemeriksaan, count(*) as hasil from public.quran_juz;
select 'jumlah_surat' as pemeriksaan, count(*) as hasil from public.quran_surat;
select 'jumlah_mapping' as pemeriksaan, count(*) as hasil from public.quran_juz_surat;

-- 2. Duplicate mapping; hasil yang diharapkan adalah 0 baris.
select juz, surat, count(*) as jumlah
from public.quran_juz_surat
group by juz, surat
having count(*) > 1;

-- 3. Daftar juz.
select nomor, nama from public.quran_juz order by nomor;

-- 4. Daftar surat per juz.
select m.juz, j.nama as nama_juz, m.surat, s.nama as nama_surat, s.urutan
from public.quran_juz_surat m
join public.quran_juz j on j.nomor = m.juz
join public.quran_surat s on s.nomor = m.surat
order by m.juz, s.urutan;

-- 5. Tabel setoran dan kolom master tambahan.
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('profiles','kelas','siswa','orang_tua_siswa','tahfidz_quran','tilawah_harian','tahsin_quran','quran_juz','quran_surat','quran_juz_surat')
order by table_name, ordinal_position;

-- 6. Foreign key penting yang sudah terdaftar.
select tc.table_name, kcu.column_name, ccu.table_name as foreign_table_name, ccu.column_name as foreign_column_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu on tc.constraint_name = kcu.constraint_name and tc.table_schema = kcu.table_schema
join information_schema.constraint_column_usage ccu on ccu.constraint_name = tc.constraint_name and ccu.table_schema = tc.table_schema
where tc.constraint_type = 'FOREIGN KEY' and tc.table_schema = 'public'
  and tc.table_name in ('orang_tua_siswa','tahfidz_quran','tilawah_harian','tahsin_quran','quran_juz_surat')
order by tc.table_name, kcu.column_name;

-- 7. RLS status untuk tabel sensitif dan master Quran.
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('profiles','kelas','siswa','orang_tua_siswa','tahfidz_quran','tilawah_harian','tahsin_quran','quran_juz','quran_surat','quran_juz_surat')
order by c.relname;

-- 8. Policy yang aktif; audit scope admin/guru/orang_tua dilakukan dari hasil ini.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles','kelas','siswa','orang_tua_siswa','tahfidz_quran','tilawah_harian','tahsin_quran','quran_juz','quran_surat','quran_juz_surat')
order by tablename, policyname;
