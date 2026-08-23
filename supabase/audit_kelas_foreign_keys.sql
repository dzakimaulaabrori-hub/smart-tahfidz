-- READ-ONLY AUDIT. Jalankan di Supabase SQL Editor sebelum mengubah constraint.
-- Query ini menginventaris seluruh FK yang mereferensikan public.kelas(id),
-- termasuk aturan ON DELETE dan jumlah baris yang memblokir tiap kelas.
select
  c.conname as constraint_name,
  n.nspname as referencing_schema,
  child.relname as referencing_table,
  child_col.attname as referencing_column,
  parent.relname as referenced_table,
  parent_col.attname as referenced_column,
  case c.confdeltype when 'a' then 'NO ACTION' when 'r' then 'RESTRICT'
       when 'c' then 'CASCADE' when 'n' then 'SET NULL' when 'd' then 'SET DEFAULT' end as on_delete
from pg_constraint c
join pg_class child on child.oid = c.conrelid
join pg_namespace n on n.oid = child.relnamespace
join pg_class parent on parent.oid = c.confrelid
join lateral unnest(c.conkey) with ordinality ck(attnum, ord) on true
join lateral unnest(c.confkey) with ordinality pk(attnum, ord) on pk.ord = ck.ord
join pg_attribute child_col on child_col.attrelid = child.oid and child_col.attnum = ck.attnum
join pg_attribute parent_col on parent_col.attrelid = parent.oid and parent_col.attnum = pk.attnum
where c.contype = 'f'
  and parent.oid = 'public.kelas'::regclass
  and parent_col.attname = 'id'
order by referencing_schema, referencing_table, constraint_name;

-- Cek apakah mekanisme arsip sudah tersedia; query ini juga read-only.
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'kelas'
  and lower(column_name) in ('status','is_active','aktif','is_nonaktif','is_archived','archived_at');

-- Relasi keluar dari kelas, termasuk tahun ajaran. Relasi ini tidak memblokir
-- DELETE kelas secara langsung, tetapi membantu keputusan histori/master data.
select
  c.conname as constraint_name,
  child.relname as referencing_table,
  child_col.attname as referencing_column,
  parent.relname as referenced_table,
  parent_col.attname as referenced_column,
  case c.confdeltype when 'a' then 'NO ACTION' when 'r' then 'RESTRICT'
       when 'c' then 'CASCADE' when 'n' then 'SET NULL' when 'd' then 'SET DEFAULT' end as on_delete
from pg_constraint c
join pg_class child on child.oid = c.conrelid
join pg_class parent on parent.oid = c.confrelid
join lateral unnest(c.conkey) with ordinality ck(attnum, ord) on true
join lateral unnest(c.confkey) with ordinality pk(attnum, ord) on pk.ord = ck.ord
join pg_attribute child_col on child_col.attrelid = child.oid and child_col.attnum = ck.attnum
join pg_attribute parent_col on parent_col.attrelid = parent.oid and parent_col.attnum = pk.attnum
where c.contype = 'f'
  and child.oid = 'public.kelas'::regclass
order by c.conname;

-- Setelah hasil pertama diketahui, cek jumlah row yang benar-benar menunjuk
-- kelas tertentu. Jangan menjalankan DELETE/TRUNCATE dari file audit ini.
-- Contoh pola (ganti nama tabel/kolom dari hasil pertama):
-- select count(*) from public.nama_tabel where nama_kolom = '<kelas-id>';
