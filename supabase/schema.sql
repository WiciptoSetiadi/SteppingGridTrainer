-- Rancangan awal untuk Supabase PostgreSQL.
-- Belum dijalankan; tinjau kebijakan privasi dan model akun sebelum migrasi.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  text_size text not null default 'standard'
    check (text_size in ('standard', 'large', 'extra_large')),
  high_contrast boolean not null default true,
  reminders_enabled boolean not null default false,
  audio_guidance_enabled boolean not null default true,
  visual_cues_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.matras_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  device_identifier text not null unique,
  display_label text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();
drop trigger if exists user_preferences_set_updated_at on public.user_preferences;
create trigger user_preferences_set_updated_at
  before update on public.user_preferences
  for each row execute function public.set_updated_at();
drop trigger if exists matras_devices_set_updated_at on public.matras_devices;
create trigger matras_devices_set_updated_at
  before update on public.matras_devices
  for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.user_preferences enable row level security;
alter table public.matras_devices enable row level security;

drop policy if exists "Users can read their own profile" on public.profiles;
drop policy if exists "Users can create their own profile" on public.profiles;
drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can read their own profile"
  on public.profiles for select
  using (auth.uid() = id);
create policy "Users can create their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);
create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Users can read their own preferences" on public.user_preferences;
drop policy if exists "Users can create their own preferences" on public.user_preferences;
drop policy if exists "Users can update their own preferences" on public.user_preferences;
create policy "Users can read their own preferences"
  on public.user_preferences for select
  using (auth.uid() = user_id);
create policy "Users can create their own preferences"
  on public.user_preferences for insert
  with check (auth.uid() = user_id);
create policy "Users can update their own preferences"
  on public.user_preferences for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can read their own matras" on public.matras_devices;
drop policy if exists "Users can add their own matras" on public.matras_devices;
drop policy if exists "Users can update their own matras" on public.matras_devices;
drop policy if exists "Users can remove their own matras" on public.matras_devices;
create policy "Users can read their own matras"
  on public.matras_devices for select
  using (auth.uid() = user_id);
create policy "Users can add their own matras"
  on public.matras_devices for insert
  with check (auth.uid() = user_id);
create policy "Users can update their own matras"
  on public.matras_devices for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "Users can remove their own matras"
  on public.matras_devices for delete
  using (auth.uid() = user_id);
