-- SMART TAHFIDZ: additive multi-role migration.
-- profiles.role remains the primary role for backward compatibility.
-- This migration is intentionally not executed by the application.

create table if not exists public.user_additional_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.user_role not null,
  created_at timestamptz not null default now(),
  constraint user_additional_roles_user_role_key unique (user_id, role)
);

create index if not exists user_additional_roles_user_id_idx
  on public.user_additional_roles(user_id);

-- A role cannot be both the primary role and an additional role. The
-- comparison is text-based so this remains compatible if profiles.role is
-- currently text/varchar rather than public.user_role.
create or replace function public.prevent_duplicate_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.user_additional_roles uar
    where uar.user_id = new.id
      and uar.role::text = new.role::text
  ) then
    raise exception 'Primary role already exists as an additional role';
  end if;
  return new;
end;
$$;

create or replace function public.prevent_duplicate_additional_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.profiles p
    where p.id = new.user_id
      and p.role::text = new.role::text
  ) then
    raise exception 'Additional role cannot equal the primary role';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_duplicate_profile_role() from public;
revoke all on function public.prevent_duplicate_additional_role() from public;

drop trigger if exists prevent_duplicate_profile_role_trigger on public.profiles;
create trigger prevent_duplicate_profile_role_trigger
before insert or update of role on public.profiles
for each row execute function public.prevent_duplicate_profile_role();

drop trigger if exists prevent_duplicate_additional_role_trigger on public.user_additional_roles;
create trigger prevent_duplicate_additional_role_trigger
before insert or update of user_id, role on public.user_additional_roles
for each row execute function public.prevent_duplicate_additional_role();

-- These helpers are intended for RLS and server-side authorization. They
-- check both the primary role and additional roles for the authenticated user.
create or replace function public.has_role(required_role public.user_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = (select auth.uid())
      and p.role::text = required_role::text
  )
  or exists (
    select 1
    from public.user_additional_roles uar
    where uar.user_id = (select auth.uid())
      and uar.role = required_role
  );
$$;

create or replace function public.my_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select p.role::public.user_role
  from public.profiles p
  where p.id = (select auth.uid())
  limit 1;
$$;

create or replace function public.is_admin_or_kepsek()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.has_role('admin'::public.user_role)
      or public.has_role('kepala_sekolah'::public.user_role);
$$;

revoke all on function public.has_role(public.user_role) from public;
revoke all on function public.my_role() from public;
revoke all on function public.is_admin_or_kepsek() from public;
grant execute on function public.has_role(public.user_role) to authenticated;
grant execute on function public.my_role() to authenticated;
grant execute on function public.is_admin_or_kepsek() to authenticated;

alter table public.user_additional_roles enable row level security;

-- Keep table privileges broad enough for RLS to decide access. The policies
-- below are the actual authorization boundary; authenticated users still
-- cannot write unless they satisfy the admin policy.
grant select, insert, update, delete on public.user_additional_roles to authenticated;

drop policy if exists "users read own additional roles" on public.user_additional_roles;
create policy "users read own additional roles"
on public.user_additional_roles
for select
to authenticated
using (
  user_id = (select auth.uid())
  or public.has_role('admin'::public.user_role)
);

drop policy if exists "admins manage additional roles" on public.user_additional_roles;
create policy "admins manage additional roles"
on public.user_additional_roles
for all
to authenticated
using (public.has_role('admin'::public.user_role))
with check (public.has_role('admin'::public.user_role));
