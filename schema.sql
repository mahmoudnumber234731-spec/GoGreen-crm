-- ============================================================
-- GoGreen CRM — Database Schema
-- شغّل الملف ده مرة واحدة من Supabase Dashboard → SQL Editor → New query
-- ============================================================

create extension if not exists "pgcrypto";

-- ---------- الأقسام (Departments) ----------
create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  icon text default '📁',
  color text default '#52B788',
  created_at timestamptz default now()
);

insert into public.departments (name, icon, color)
values ('القسم المالي', '💰', '#A9814A')
on conflict do nothing;

-- ---------- بيانات المستخدمين (Profiles) ----------
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  username text unique not null,
  full_name text,
  avatar_url text,
  department_id uuid references public.departments(id) on delete set null,
  role text not null default 'employee' check (role in ('admin','employee')),
  last_seen timestamptz default now(),
  created_at timestamptz default now()
);

-- إنشاء بروفايل تلقائي لأي مستخدم جديد يتسجل
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, full_name)
  values (new.id, split_part(new.email, '@', 1), split_part(new.email, '@', 1))
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- تفعيل الحماية (Row Level Security) ----------
alter table public.profiles enable row level security;
alter table public.departments enable row level security;

-- أي مستخدم مسجّل دخول يقدر يشوف كل البروفايلات (عشان لوحة أونلاين/أوفلاين)
drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated" on public.profiles
  for select using (auth.role() = 'authenticated');

-- المستخدم يقدر يعدّل بياناته هو بس
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- أي مستخدم مسجّل يشوف الأقسام
drop policy if exists "departments_select_authenticated" on public.departments;
create policy "departments_select_authenticated" on public.departments
  for select using (auth.role() = 'authenticated');

-- الأدمن بس يقدر يضيف/يعدّل/يمسح أقسام
drop policy if exists "departments_admin_insert" on public.departments;
create policy "departments_admin_insert" on public.departments
  for insert with check (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

drop policy if exists "departments_admin_update" on public.departments;
create policy "departments_admin_update" on public.departments
  for update using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

drop policy if exists "departments_admin_delete" on public.departments;
create policy "departments_admin_delete" on public.departments
  for delete using (
    exists (select 1 from public.profiles where id = auth.uid() and role = 'admin')
  );

-- ---------- تخزين الصور الشخصية (Storage) ----------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatars_user_upload" on storage.objects;
create policy "avatars_user_upload" on storage.objects
  for insert with check (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "avatars_user_update" on storage.objects;
create policy "avatars_user_update" on storage.objects
  for update using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ============================================================
-- عشان تعمل أول أدمن: بعد ما تسجل حساب من صفحة الدخول (لازم تعمله
-- من Supabase Dashboard → Authentication → Users → Add user)
-- روح لجدول profiles وغيّر عمود role للمستخدم ده يبقى 'admin'
-- ============================================================
