-- 神楽 -KAGURA ASCENT- 世界のランキング用テーブル
-- Supabase の SQL Editor に貼って実行する。anon（公開鍵）は insert と select だけ許可。
create table if not exists public.scores (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  run_id      text not null unique,
  name        text not null default '名無しの巫女' check (char_length(name) <= 16),
  score       integer not null check (score >= 0 and score < 100000000),
  wave        integer not null default 0,
  stage       integer not null default 1,
  level       integer not null default 1,
  cleared     boolean not null default false,
  endless     boolean not null default false,
  version     text not null default 'dev',
  commit      text not null default '',
  build_time  text not null default '',
  platform    text not null default '',
  familiar    text not null default '',
  gods        jsonb not null default '[]'::jsonb,
  kami_lv     jsonb not null default '{}'::jsonb,
  relics      jsonb not null default '[]'::jsonb,
  boons       jsonb not null default '{}'::jsonb,
  curses      jsonb not null default '[]'::jsonb,
  duration    real not null default 0
);

create index if not exists scores_score_idx on public.scores (score desc, created_at asc);
create index if not exists scores_version_idx on public.scores (version);

alter table public.scores enable row level security;

drop policy if exists "anon can insert scores" on public.scores;
create policy "anon can insert scores" on public.scores
  for insert to anon with check (true);

drop policy if exists "anon can update own run" on public.scores;
create policy "anon can update own run" on public.scores
  for update to anon using (true) with check (true);

drop policy if exists "anyone can read scores" on public.scores;
create policy "anyone can read scores" on public.scores
  for select to anon, authenticated using (true);

-- 既存の表への追加（初回作成後に列を足したとき）
alter table public.scores add column if not exists curses jsonb not null default '[]'::jsonb;
