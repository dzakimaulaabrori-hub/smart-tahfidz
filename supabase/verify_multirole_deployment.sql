-- SMART TAHFIDZ: read-only deployment audit for additive roles.
-- This file contains metadata and SELECT queries only. It must be run after
-- the migrations have been reviewed/executed by the database owner.

-- 1. Required objects and role enum.
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

-- 2. RLS status for all role-sensitive tables.
with required(table_name) as (
  values
    ('absensi_siswa'), ('guru_quran_kelompok'), ('indikator_karakter'),
    ('kelas'), ('kelompok_siswa'), ('orang_tua_siswa'),
    ('penilaian_karakter'), ('profiles'), ('rapor_periodik'), ('siswa'),
    ('tahfidz_quran'), ('tahsin_quran'), ('tahun_ajaran'),
    ('target_hafalan'), ('tilawah_harian'), ('user_additional_roles')
)
select
  r.table_name,
  c.oid is not null as table_exists,
  coalesce(c.relrowsecurity, false) as rls_enabled,
  coalesce(c.relforcerowsecurity, false) as rls_forced
from required r
left join pg_class c
  on c.relname = r.table_name
 and c.relnamespace = 'public'::regnamespace
order by r.table_name;

-- 3. Complete public policy inventory, including qual and with_check.
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

-- 4. Expected policy presence and current multi-role indicators.
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
), policy_rows as materialized (
  select
    schemaname,
    tablename,
    policyname,
    cmd,
    roles,
    qual,
    with_check,
    lower(concat_ws(' ', qual, with_check)) as expression_text
  from pg_policies
  where schemaname = 'public'
)
select
  e.table_name,
  e.policy_name,
  case when p.policyname is null then 'MISSING' else 'PRESENT' end as presence,
  p.cmd,
  p.roles,
  p.qual,
  p.with_check,
  case
    when p.policyname is null then 'POTENTIAL_RISK'
    when p.expression_text like '%my_role(%'
      or p.expression_text like '%profiles.role%'
      or p.expression_text like '%profile.role%'
      then 'NEEDS_UPDATE'
    when p.expression_text like '%has_role(%'
      then 'SAFE'
    else 'REVIEW'
  end as multi_role_compatibility
from expected e
left join policy_rows p
  on p.tablename = e.table_name
 and p.policyname = e.policy_name
order by e.table_name, e.policy_name;

-- 5. Role-sensitive policy references. This reports every policy containing
-- a role helper, profiles.role, auth.uid(), or a known role literal.
select
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check,
  case
    when lower(concat_ws(' ', qual, with_check)) like '%has_role(%'
      then 'HAS_ROLE'
    when lower(concat_ws(' ', qual, with_check)) like '%my_role(%'
      then 'MY_ROLE'
    when lower(concat_ws(' ', qual, with_check)) like '%profiles.role%'
      or lower(concat_ws(' ', qual, with_check)) like '%profile.role%'
      then 'PRIMARY_ROLE_DIRECT'
    else 'OTHER'
  end as role_check_kind,
  case
    when lower(concat_ws(' ', qual, with_check)) like '%auth.uid(%'
      then 'PRESENT'
    else 'NOT_DETECTED'
  end as auth_uid_reference
from pg_policies
where schemaname = 'public'
  and (
    lower(concat_ws(' ', qual, with_check)) like '%profiles.role%'
    or lower(concat_ws(' ', qual, with_check)) like '%profile.role%'
    or lower(concat_ws(' ', qual, with_check)) like '%my_role(%'
    or lower(concat_ws(' ', qual, with_check)) like '%has_role(%'
    or lower(concat_ws(' ', qual, with_check)) like '%admin%'
    or lower(concat_ws(' ', qual, with_check)) like '%wali_kelas%'
    or lower(concat_ws(' ', qual, with_check)) like '%guru_quran%'
    or lower(concat_ws(' ', qual, with_check)) like '%kepala_sekolah%'
    or lower(concat_ws(' ', qual, with_check)) like '%orang_tua%'
  )
order by tablename, policyname;

-- 6. Role helper functions only. The materialized CTE and prokind filter keep
-- aggregate routines such as array_agg out of function-definition calls.
with role_functions as materialized (
  select
    p.oid,
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type,
    p.prokind,
    p.prosecdef as security_definer,
    p.proconfig as function_configuration,
    p.proacl as function_acl,
    pg_get_functiondef(p.oid) as definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where p.prokind in ('f', 'p')
    and n.nspname = 'public'
)
select
  schema_name,
  function_name,
  arguments,
  return_type,
  prokind,
  security_definer,
  function_configuration,
  function_acl,
  has_function_privilege('anon', oid, 'EXECUTE') as anon_can_execute,
  has_function_privilege('authenticated', oid, 'EXECUTE') as authenticated_can_execute,
  has_function_privilege('public', oid, 'EXECUTE') as public_can_execute,
  definition,
  case
    when security_definer is not true then 'POTENTIAL_RISK'
    when not exists (
      select 1
      from unnest(coalesce(function_configuration, '{}'::text[])) config
      where config like 'search_path=public%'
    ) then 'POTENTIAL_RISK'
    when has_function_privilege('anon', oid, 'EXECUTE') then 'POTENTIAL_RISK'
    when not has_function_privilege('authenticated', oid, 'EXECUTE') then 'POTENTIAL_RISK'
    when not has_function_privilege('service_role', oid, 'EXECUTE') then 'POTENTIAL_RISK'
    else 'SAFE'
  end as helper_security_status
from role_functions
where function_name in ('has_role', 'my_role', 'is_admin_or_kepsek')
   or definition ilike '%profiles.role%'
   or definition ilike '%user_additional_roles%'
order by schema_name, function_name, arguments;

-- 7. Trigger, FK, unique constraint, and index checks.
select
  n.nspname as schema_name,
  c.relname as table_name,
  t.tgname as trigger_name,
  t.tgenabled as trigger_enabled,
  pg_get_triggerdef(t.oid) as trigger_definition,
  p.proname as trigger_function,
  p.prosecdef as function_security_definer,
  p.proconfig as function_configuration
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
  con.contype,
  pg_get_constraintdef(con.oid) as definition
from pg_constraint con
join pg_class child on child.oid = con.conrelid
left join pg_class parent on parent.oid = con.confrelid
join pg_namespace ns on ns.oid = child.relnamespace
where ns.nspname = 'public'
  and child.relname = 'user_additional_roles'
order by con.conname;

select
  schemaname,
  tablename,
  indexname,
  indexdef
from pg_indexes
where schemaname = 'public'
  and tablename = 'user_additional_roles'
order by indexname;

-- 8. Data-integrity checks. These return rows only when a problem exists.
select
  p.id as user_id,
  p.role as primary_role,
  uar.role as duplicate_additional_role
from public.profiles p
join public.user_additional_roles uar
  on uar.user_id = p.id
 and uar.role::text = p.role::text
order by p.id;

-- 9. Conservative overall status. SAFE_TO_DEPLOY requires all expected
-- policies to be present, all listed tables to have RLS, and all helper
-- functions to pass the basic SECURITY DEFINER checks above. This result is
-- a metadata gate, not a substitute for reviewing each policy expression.
with required_tables(table_name) as (
  values
    ('absensi_siswa'), ('guru_quran_kelompok'), ('indikator_karakter'),
    ('kelas'), ('kelompok_siswa'), ('orang_tua_siswa'),
    ('penilaian_karakter'), ('profiles'), ('rapor_periodik'), ('siswa'),
    ('tahfidz_quran'), ('tahsin_quran'), ('tahun_ajaran'),
    ('target_hafalan'), ('tilawah_harian'), ('user_additional_roles')
), required_policies(policy_name, table_name) as (
  values
    ('absensi_update', 'absensi_siswa'), ('absensi_delete', 'absensi_siswa'),
    ('absensi_insert', 'absensi_siswa'), ('gqk_write', 'guru_quran_kelompok'),
    ('indikator_karakter_write', 'indikator_karakter'), ('kelas_write', 'kelas'),
    ('ks_write', 'kelompok_siswa'), ('ots_write', 'orang_tua_siswa'),
    ('karakter_delete', 'penilaian_karakter'), ('karakter_insert', 'penilaian_karakter'),
    ('karakter_update', 'penilaian_karakter'), ('profiles_insert_admin', 'profiles'),
    ('profiles_update_own_or_admin', 'profiles'), ('rapor_write', 'rapor_periodik'),
    ('siswa_write', 'siswa'), ('siswa_select', 'siswa'),
    ('tahfidz_insert', 'tahfidz_quran'), ('tahfidz_delete', 'tahfidz_quran'),
    ('tahfidz_update', 'tahfidz_quran'), ('tahsin_insert', 'tahsin_quran'),
    ('tahsin_update', 'tahsin_quran'), ('tahsin_delete', 'tahsin_quran'),
    ('tahun_ajaran_write', 'tahun_ajaran'), ('target_hafalan_write', 'target_hafalan'),
    ('tilawah_insert', 'tilawah_harian'), ('tilawah_select', 'tilawah_harian'),
    ('tilawah_delete', 'tilawah_harian'), ('tilawah_update_ortu', 'tilawah_harian'),
    ('tilawah_update_guru', 'tilawah_harian')
), table_gate as (
  select count(*) = count(c.oid)
     and bool_and(coalesce(c.relrowsecurity, false)) as ok
  from required_tables r
  left join pg_class c
    on c.relname = r.table_name
   and c.relnamespace = 'public'::regnamespace
), policy_gate as (
  select
    count(*) = count(p.policyname)
    and bool_and(
      lower(concat_ws(' ', p.qual, p.with_check)) not like '%my_role(%'
      and lower(concat_ws(' ', p.qual, p.with_check)) not like '%profiles.role%'
      and lower(concat_ws(' ', p.qual, p.with_check)) not like '%profile.role%'
    ) as ok
  from required_policies r
  left join pg_policies p
    on p.schemaname = 'public'
   and p.tablename = r.table_name
   and p.policyname = r.policy_name
), helper_candidates as materialized (
  select
    p.oid,
    p.proname,
    p.prosecdef,
    p.proconfig
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prokind in ('f', 'p')
), expected_helpers(function_signature) as (
  values
    ('public.has_role(public.user_role)'),
    ('public.my_role()'),
    ('public.is_admin_or_kepsek()')
), function_gate as (
  select
    count(h.oid) = count(e.function_signature)
    and bool_and(
      h.prosecdef
      and exists (
        select 1
        from unnest(coalesce(h.proconfig, '{}'::text[])) config
        where config like 'search_path=public%'
      )
      and not has_function_privilege('anon', h.oid, 'EXECUTE')
      and has_function_privilege('authenticated', h.oid, 'EXECUTE')
      and has_function_privilege('service_role', h.oid, 'EXECUTE')
    ) as ok
  from expected_helpers e
  left join helper_candidates h
    on h.oid = to_regprocedure(e.function_signature)::oid
)
select
  case when table_gate.ok and policy_gate.ok and function_gate.ok
    then 'SAFE_TO_DEPLOY'
    else 'BLOCKED'
  end as deployment_status,
  table_gate.ok as required_tables_and_rls_ok,
  policy_gate.ok as required_policies_ok,
  function_gate.ok as role_helpers_security_ok
from table_gate, policy_gate, function_gate;
