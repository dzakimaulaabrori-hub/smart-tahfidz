-- SMART TAHFIDZ: read-only production compatibility audit.
-- This file contains SELECT statements only. It does not change the database.

-- 1. Inventory of every public-schema RLS policy, with role-sensitive markers.
with policy_text as (
  select
    p.schemaname,
    p.tablename,
    p.policyname,
    p.permissive,
    p.roles,
    p.cmd,
    p.qual,
    p.with_check,
    lower(concat_ws(' ', p.qual, p.with_check)) as expression_text
  from pg_policies p
  where p.schemaname = 'public'
)
select
  schemaname as schema_name,
  tablename as table_name,
  policyname as policy_name,
  permissive,
  roles,
  cmd as command,
  qual,
  with_check,
  (expression_text like '%profiles.role%'
    or expression_text like '%profile.role%') as uses_profiles_role,
  expression_text like '%my_role(%' as uses_my_role,
  expression_text ~ $$'(admin|wali_kelas|guru_quran|kepala_sekolah|orang_tua)'$$ as compares_known_role,
  expression_text like '%auth.uid(%' as uses_auth_uid,
  case
    when expression_text like '%profiles.role%'
      or expression_text like '%profile.role%'
      or expression_text like '%my_role(%'
    then 'NEEDS_UPDATE'
    when expression_text ~ $$'(admin|wali_kelas|guru_quran|kepala_sekolah|orang_tua)'$$
    then 'POTENTIAL_RISK'
    else 'SAFE'
  end as multi_role_compatibility
from policy_text
order by tablename, policyname;

-- 2. Focused view of the application tables most likely to contain access rules.
with focus_tables(table_name) as (
  values
    ('absensi_siswa'),
    ('guru_quran_kelompok'),
    ('kelompok_siswa'),
    ('siswa'),
    ('tahfidz_quran'),
    ('tahsin_quran'),
    ('tilawah_harian'),
    ('penilaian_karakter'),
    ('rapor_periodik'),
    ('target_hafalan'),
    ('tahun_ajaran'),
    ('orang_tua_siswa'),
    ('notifikasi'),
    ('profiles'),
    ('kelas')
), policy_text as (
  select
    p.*,
    lower(concat_ws(' ', p.qual, p.with_check)) as expression_text
  from pg_policies p
  join focus_tables f on f.table_name = p.tablename
  where p.schemaname = 'public'
)
select
  tablename as table_name,
  policyname as policy_name,
  cmd as command,
  roles,
  qual,
  with_check,
  (expression_text like '%profiles.role%'
    or expression_text like '%profile.role%') as uses_profiles_role,
  expression_text like '%my_role(%' as uses_my_role,
  expression_text ~ $$'(admin|wali_kelas|guru_quran|kepala_sekolah|orang_tua)'$$ as compares_known_role,
  case
    when expression_text like '%profiles.role%'
      or expression_text like '%profile.role%'
      or expression_text like '%my_role(%'
    then 'NEEDS_UPDATE'
    when expression_text ~ $$'(admin|wali_kelas|guru_quran|kepala_sekolah|orang_tua)'$$
    then 'POTENTIAL_RISK'
    else 'SAFE'
  end as multi_role_compatibility
from policy_text
order by tablename, policyname;

-- 3. Policies that are unable to see an additional role by construction.
select
  schemaname as schema_name,
  tablename as table_name,
  policyname as policy_name,
  cmd as command,
  roles,
  qual,
  with_check,
  case
    when lower(concat_ws(' ', qual, with_check)) like '%profiles.role%'
      then 'Direct profiles.role reference only sees the primary role.'
    when lower(concat_ws(' ', qual, with_check)) like '%profile.role%'
      then 'Direct profile.role reference only sees the primary role.'
    when lower(concat_ws(' ', qual, with_check)) like '%my_role(%'
      then 'my_role() returns the primary role; additional roles are not included.'
  end as reason
from pg_policies
where schemaname = 'public'
  and (
    lower(concat_ws(' ', qual, with_check)) like '%profiles.role%'
    or lower(concat_ws(' ', qual, with_check)) like '%profile.role%'
    or lower(concat_ws(' ', qual, with_check)) like '%my_role(%'
  )
order by tablename, policyname;

-- 4. Policy expressions that mention each known role literal.
select
  schemaname as schema_name,
  tablename as table_name,
  policyname as policy_name,
  cmd as command,
  roles,
  qual,
  with_check,
  role_name
from pg_policies
cross join lateral (
  select unnest(array[
    'admin',
    'wali_kelas',
    'guru_quran',
    'kepala_sekolah',
    'orang_tua'
  ]) as role_name
) known_roles
where schemaname = 'public'
  and lower(concat_ws(' ', qual, with_check)) like ('%' || quote_literal(role_name) || '%')
order by tablename, policyname, role_name;

-- 5. RLS status for all public tables, including the role-focused tables.
select
  n.nspname as schema_name,
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p')
order by c.relname;

-- 6. Database functions related to role and authorization.
-- The materialized boundary is intentional: pg_proc also contains
-- aggregates such as array_agg, which must never be passed to the
-- pg_get_function_* helpers.
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
  definition,
  case
    when definition ilike '%user_additional_roles%'
      and security_definer
      then 'POTENTIAL_RISK: SECURITY DEFINER reads role table; inspect ownership and auth.uid() guard.'
    when definition ilike '%profiles%'
      and definition ilike '%role%'
      then 'NEEDS_UPDATE: function may read only the primary role.'
    else 'SAFE'
  end as multi_role_compatibility
from role_functions
where function_name in ('my_role', 'is_admin_or_kepsek', 'has_role')
   or definition ilike '%profiles.role%'
   or definition ilike '%profile.role%'
   or definition ilike '%user_additional_roles%'
   or definition ilike '%auth.uid%'
order by schema_name, function_name, arguments;

-- 7. Function configuration and privilege details for the named helpers.
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer,
  p.proconfig as function_configuration,
  p.proacl as function_acl,
  has_function_privilege('anon', p.oid, 'EXECUTE') as anon_can_execute,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_can_execute,
  (p.proacl is null or p.proacl::text like '%=X%') as public_can_execute,
  pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.prokind in ('f', 'p')
  and p.proname in ('my_role', 'is_admin_or_kepsek', 'has_role')
order by p.proname, arguments;

-- 8. Trigger inventory for profiles and the additional-role table.
select
  n.nspname as schema_name,
  c.relname as table_name,
  t.tgname as trigger_name,
  t.tgenabled as trigger_enabled,
  pg_get_triggerdef(t.oid) as trigger_definition,
  fn.nspname as function_schema,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as function_arguments,
  p.prosecdef as function_security_definer,
  pg_get_functiondef(p.oid) as function_definition
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
join pg_proc p on p.oid = t.tgfoid
join pg_namespace fn on fn.oid = p.pronamespace
where not t.tgisinternal
  and n.nspname = 'public'
  and c.relname in ('profiles', 'user_additional_roles')
order by c.relname, t.tgname;

-- 9. Potential recursive-RLS signals for helper functions.
with role_functions as materialized (
  select
    p.oid,
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    p.prosecdef as security_definer,
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
  security_definer,
  (definition ilike '%user_additional_roles%') as reads_additional_roles,
  exists (
    select 1
    from pg_policies pol
    where pol.schemaname = 'public'
      and pol.tablename = 'user_additional_roles'
      and lower(concat_ws(' ', pol.qual, pol.with_check)) like ('%' || lower(function_name) || '(%')
  ) as referenced_by_additional_role_policy,
  definition
from role_functions
where function_name in ('my_role', 'is_admin_or_kepsek', 'has_role')
   or definition ilike '%user_additional_roles%'
order by function_name, arguments;

-- 10. A compact final status for the requested wali_kelas + guru_quran case.
with role_functions as materialized (
  select
    p.oid,
    p.prosecdef as security_definer,
    pg_get_functiondef(p.oid) as definition
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where p.prokind in ('f', 'p')
    and n.nspname = 'public'
),
policy_risk as (
  select exists (
    select 1
    from pg_policies p
    where p.schemaname = 'public'
      and (
        lower(concat_ws(' ', p.qual, p.with_check)) like '%profiles.role%'
        or lower(concat_ws(' ', p.qual, p.with_check)) like '%profile.role%'
        or lower(concat_ws(' ', p.qual, p.with_check)) like '%my_role(%'
      )
  ) as has_primary_only_policy
), function_risk as (
  select exists (
    select 1
    from role_functions fn
    where fn.security_definer
      and fn.definition ilike '%user_additional_roles%'
      and fn.definition not ilike '%auth.uid%'
  ) as has_unscoped_security_definer
)
select
  case
    when policy_risk.has_primary_only_policy then 'NEEDS_UPDATE'
    when function_risk.has_unscoped_security_definer then 'POTENTIAL_RISK'
    else 'SAFE'
  end as multi_role_compatibility,
  'wali_kelas primary + guru_quran additional requires every role-specific policy/function to use membership logic.' as interpretation
from policy_risk
cross join function_risk;
