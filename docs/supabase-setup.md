# Supabase 接入说明

## 1. 创建项目

1. 在 Supabase 控制台创建一个新项目。
2. 记下以下配置：
   - `Project URL`
   - `anon public key`
3. 在 `Authentication` 中启用一种登录方式。

这版代码使用的是：
- `Email`
- 验证方式选择 `OTP code`
- 不要只开 `Magic Link`

## 2. 建表

在 `SQL Editor` 执行下面的 SQL：

```sql
create table if not exists public.daily_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  date text not null,
  breakfast smallint,
  lunch smallint,
  dinner smallint,
  weight numeric,
  body_fat numeric,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, date)
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

drop trigger if exists daily_records_set_updated_at on public.daily_records;

create trigger daily_records_set_updated_at
before update on public.daily_records
for each row
execute function public.set_updated_at();
```

## 3. 开启 RLS

```sql
alter table public.daily_records enable row level security;

create policy "Users can read own daily records"
on public.daily_records
for select
using (auth.uid() = user_id);

create policy "Users can insert own daily records"
on public.daily_records
for insert
with check (auth.uid() = user_id);

create policy "Users can update own daily records"
on public.daily_records
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
```

## 4. 在项目中填写配置

编辑以下文件：

- `entry/src/main/ets/sync/SupabaseConfig.ets`

需要填写：

- `ENABLED = true`
- `PROJECT_URL`
- `ANON_KEY`

注意：

- `ACCESS_TOKEN` 和 `USER_ID` 现在不需要手填，登录成功后会自动写入运行时会话。
- 不建议把正式环境密钥提交到 Git。

## 5. 当前实现的范围

当前代码已经完成：

- 本地数据库增加同步元数据字段
- 新增邮箱 OTP 登录与本地 session 持久化
- Repository 层接管 ViewModel 的数据访问
- 应用启动时尝试恢复登录并自动同步
- 保存记录时会把记录标记为待上传

当前还需要你继续补完的部分：

- 删除记录的云端同步
- 更细致的同步状态 UI

## 6. 相关代码位置

- `entry/src/main/ets/sync/SupabaseConfig.ets`
- `entry/src/main/ets/sync/SupabaseAuthService.ets`
- `entry/src/main/ets/sync/SupabaseDailyRecordService.ets`
- `entry/src/main/ets/repository/DailyRecordRepository.ets`
- `entry/src/main/ets/viewmodel/AuthViewModel.ets`
