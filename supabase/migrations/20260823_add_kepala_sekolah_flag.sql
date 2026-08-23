-- Additive migration: keeps the existing profiles.role (and auth permissions)
-- unchanged. Apply this migration in Supabase SQL Editor before using the
-- Kepala Sekolah selector in Panel Admin.
alter table if exists public.profiles
  add column if not exists is_kepala_sekolah boolean not null default false;

create index if not exists profiles_kepala_sekolah_idx
  on public.profiles (is_kepala_sekolah)
  where is_kepala_sekolah = true;

-- At most one active principal. This is a partial unique index rather than a
-- trigger so it is safe, small, and does not touch existing account roles.
create unique index if not exists profiles_one_kepala_sekolah_idx
  on public.profiles (is_kepala_sekolah)
  where is_kepala_sekolah = true;
