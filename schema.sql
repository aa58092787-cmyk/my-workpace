-- 새 프로젝트의 Supabase SQL Editor에서 한 번 실행합니다.
-- 기존 tasks 테이블이 있다면 백업 후 충돌 여부를 먼저 확인하세요.
begin;
create table public.tasks (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 title text not null check (length(btrim(title)) between 1 and 150),
 description text not null default '' check (length(description)<=5000),
 status text not null default 'todo' check (status in ('todo','doing','done')),
 priority text not null default 'medium' check (priority in ('low','medium','high')),
 due date check (due between date '0001-01-01' and date '9999-12-31'),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index tasks_owner_created_idx on public.tasks(user_id,created_at,id);
alter table public.tasks enable row level security;
revoke all on public.tasks from anon;
grant select,insert,update,delete on public.tasks to authenticated;
create policy tasks_select on public.tasks for select to authenticated using ((select auth.uid())=user_id);
create policy tasks_insert on public.tasks for insert to authenticated with check ((select auth.uid())=user_id);
create policy tasks_update on public.tasks for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy tasks_delete on public.tasks for delete to authenticated using ((select auth.uid())=user_id);
create function public.touch_task_updated_at() returns trigger language plpgsql set search_path='' as $$
begin new.updated_at=now();return new;end;
$$;
create trigger tasks_updated_at before update on public.tasks for each row execute function public.touch_task_updated_at();
-- 백업 교체는 단일 트랜잭션. 하나라도 잘못되면 삭제까지 모두 롤백됩니다.
-- 과거 로컬 백업의 비 UUID id도 허용하도록 복원 시 새 UUID를 생성합니다.
create function public.replace_my_tasks(p_tasks jsonb) returns void
language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if p_tasks is null or jsonb_typeof(p_tasks)<>'array' then raise exception 'Expected task array';end if;
 if jsonb_array_length(p_tasks)>10000 then raise exception 'Maximum 10000 tasks';end if;
 -- 동일 계정의 복원 요청은 직렬화합니다.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 delete from public.tasks where user_id=auth.uid();
 insert into public.tasks(user_id,title,description,status,priority,due)
 select auth.uid(), x->>'title', x->>'description', x->>'status', x->>'priority', nullif(x->>'due','')::date
 from jsonb_array_elements(p_tasks) as x;
end;
$$;
revoke all on function public.replace_my_tasks(jsonb) from public,anon;
grant execute on function public.replace_my_tasks(jsonb) to authenticated;
commit;
