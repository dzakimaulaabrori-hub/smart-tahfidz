-- SMART TAHFIDZ: read-only post-migration verification.
-- This file contains SELECT statements only.

select
  to_regclass('public.profiles') as profiles_table,
  to_regclass('public.user_additional_roles') as additional_roles_table,
  to_regtype('public.user_role') as user_role_type;

select
  table_name,
  column_name,
  data_type,
  udt_schema,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in ('profiles', 'user_additional_roles')
order by table_name, ordinal_position;

select
  e.enumlabel,
  e.enumsortorder
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
join pg_enum e on e.enumtypid = t.oid
where n.nspname = 'public'
  and t.typname = 'user_role'
order by e.enumsortorder;

select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('profiles', 'user_additional_roles')
order by c.relname;

select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

with expected(policy_name, table_name) as (
  values
    ('absensi_update', 'absensi_siswa'),
    ('absensi_delete', 'absensi_siswa'),
    ('absensi_insert', 'absensi_siswa'),
    ('gqk_write', 'guru_quran_kelompok'),
    ('indikator_karakter_write', 'indikator_karakter'),
    ('kelas_write', 'kelas'),
    ('ks_write', 'kelompok_siswa'),
    ('ots_write', 'orang_tua_siswa'),
    ('karakter_delete', 'penilaian_karakter'),
    ('karakter_insert', 'penilaian_karakter'),
    ('karakter_update', 'penilaian_karakter'),
    ('profiles_insert_admin', 'profiles'),
    ('profiles_update_own_or_admin', 'profiles'),
    ('rapor_write', 'rapor_periodik'),
    ('siswa_write', 'siswa'),
    ('siswa_select', 'siswa'),
    ('tahfidz_insert', 'tahfidz_quran'),
    ('tahfidz_delete', 'tahfidz_quran'),
    ('tahfidz_update', 'tahfidz_quran'),
    ('tahsin_insert', 'tahsin_quran'),
    ('tahsin_update', 'tahsin_quran'),
    ('tahsin_delete', 'tahsin_quran'),
    ('tahun_ajaran_write', 'tahun_ajaran'),
    ('target_hafalan_write', 'target_hafalan'),
    ('tilawah_insert', 'tilawah_harian'),
    ('tilawah_select', 'tilawah_harian'),
    ('tilawah_delete', 'tilawah_harian'),
    ('tilawah_update_ortu', 'tilawah_harian'),
    ('tilawah_update_guru', 'tilawah_harian')
)
select
  e.table_name,
  e.policy_name,
  case when p.policyname is null then 'MISSING' else 'PRESENT' end as status,
  p.cmd,
  p.roles,
  p.qual,
  p.with_check
from expected e
left join pg_policies p
  on p.schemaname = 'public'
 and p.tablename = e.table_name
 and p.policyname = e.policy_name
order by e.table_name, e.policy_name;

select
  schemaname as schema_name,
  tablename as table_name,
  policyname as policy_name,
  cmd,
  qual,
  with_check,
  case
    when lower(concat_ws(' ', qual, with_check)) like '%profiles.role%'
      or lower(concat_ws(' ', qual, with_check)) like '%profile.role%'
      or lower(concat_ws(' ', qual, with_check)) like '%my_role(%'
      then 'NEEDS_UPDATE'
    when lower(concat_ws(' ', qual, with_check)) like '%has_role(%'
      then 'SAFE'
    else 'REVIEW'
  end as multi_role_compatibility
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

with role_functions as materialized (
  select
    p.oid,
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type,
    p.prosecdef as security_definer,
    p.proconfig as function_configuration,
    p.proacl as function_acl,
    pg_get_functiondef(p.oid) as definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where p.prokind in ('f', 'p')
    and n.nspname not in ('pg_catalog', 'information_schema')
)
select
  schema_name,
  function_name,
  arguments,
  return_type,
  security_definer,
  function_configuration,
  function_acl,
  has_function_privilege('anon', oid, 'EXECUTE') as anon_can_execute,
  has_function_privilege('authenticated', oid, 'EXECUTE') as authenticated_can_execute,
  (function_acl is null or function_acl::text like '%=X%') as public_can_execute,
  definition
from role_functions
where function_name in ('my_role', 'is_admin_or_kepsek', 'has_role')
   or definition ilike '%profiles.role%'
   or definition ilike '%user_additional_roles%'
order by schema_name, function_name, arguments;

select
  n.nspname as schema_name,
  c.relname as table_name,
  t.tgname as trigger_name,
  t.tgenabled as trigger_enabled,
  pg_get_triggerdef(t.oid) as trigger_definition,
  p.proname as function_name,
  p.prosecdef as function_security_definer
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
join pg_proc p on p.oid = t.tgfoid
where not t.tgisinternal
  and n.nspname = 'public'
  and c.relname in ('profiles', 'user_additional_roles')
order by c.relname, t.tgname;

select
  con.conname as constraint_name,
  child.relname as child_table,
  parent.relname as parent_table,
  pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class child on child.oid = con.conrelid
join pg_class parent on parent.oid = con.confrelid
join pg_namespace ns on ns.oid = child.relnamespace
where ns.nspname = 'public'
  and child.relname = 'user_additional_roles'
order by con.conname;

select
  p.id,
  p.role as primary_role,
  count(uar.id) as additional_role_count,
  count(*) filter (where uar.role::text = p.role::text) as primary_additional_duplicates
from public.profiles p
left join public.user_additional_roles uar on uar.user_id = p.id
group by p.id, p.role
order by p.id;
