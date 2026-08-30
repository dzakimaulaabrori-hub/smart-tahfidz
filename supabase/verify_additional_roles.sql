-- SMART TAHFIDZ: read-only verification for primary/additional roles.
-- Do not run migration statements from this file.

select
  to_regclass('public.user_additional_roles') as additional_roles_table,
  to_regclass('public.profiles') as profiles_table;

select
  table_schema,
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
  n.nspname as enum_schema,
  t.typname as enum_name,
  e.enumsortorder,
  e.enumlabel
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
  and tablename in ('profiles', 'user_additional_roles')
order by tablename, policyname;

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
  n.nspname as schema_name,
  c.relname as table_name,
  t.tgname as trigger_name,
  pg_get_triggerdef(t.oid) as trigger_definition
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where not t.tgisinternal
  and n.nspname = 'public'
  and c.relname in ('profiles', 'user_additional_roles')
order by c.relname, t.tgname;

select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('has_role', 'my_role', 'is_admin_or_kepsek',
                    'prevent_duplicate_profile_role',
                    'prevent_duplicate_additional_role')
order by p.proname;

select
  p.id,
  p.nama,
  p.role as primary_role,
  coalesce(array_agg(uar.role order by uar.role)
    filter (where uar.role is not null), '{}') as additional_roles
from public.profiles p
left join public.user_additional_roles uar on uar.user_id = p.id
group by p.id, p.nama, p.role
order by p.nama;

