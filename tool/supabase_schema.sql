-- ═══════════════════════════════════════════════════════════════════════
-- Dindin Controller: esquema de sincronização (Supabase / PostgreSQL)
-- ═══════════════════════════════════════════════════════════════════════
-- Como usar: cole este script INTEIRO no "SQL Editor" do painel do
-- Supabase e clique em "Run". Pode rodar de novo sem quebrar nada.
--
-- Regra de ouro: só o usuário LOGADO (authenticated) acessa os próprios
-- dados; o RLS (Row Level Security) garante isso. A chave publishable
-- não dá acesso a nada sem login.

-- ─── Tabelas da sincronização ───────────────────────────────────────────
-- Cada registro tem um sync_id único (UUID), carimbo de tempo
-- (updated_at) e marca de exclusão (deleted, para a exclusão viajar
-- entre aparelhos).

create table if not exists public.accounts (
  sync_id uuid primary key,
  user_id uuid not null default auth.uid(),
  name text not null,
  type text not null,
  initial_balance_cents bigint not null default 0,
  color_value bigint not null default 4284513675,
  archived boolean not null default false,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  sync_id uuid primary key,
  user_id uuid not null default auth.uid(),
  name text not null,
  type text not null,
  icon text not null default 'more_horiz',
  color_value bigint not null default 4287332747,
  archived boolean not null default false,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.transactions (
  sync_id uuid primary key,
  user_id uuid not null default auth.uid(),
  type text not null,
  amount_cents bigint not null,
  date date not null,
  account_sync uuid not null,
  to_account_sync uuid,
  category_sync uuid,
  note text,
  title text,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

-- v4: título próprio do lançamento (para bancos já existentes; inofensivo
-- em bancos novos, que já nascem com a coluna).
alter table public.transactions add column if not exists title text;

create table if not exists public.investments (
  sync_id uuid primary key,
  user_id uuid not null default auth.uid(),
  ticker text not null,
  kind text not null,
  quantity bigint not null default 0,
  avg_price_cents bigint not null default 0,
  note text,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.dividends (
  sync_id uuid primary key,
  user_id uuid not null default auth.uid(),
  date date not null,
  ticker text,
  amount_cents bigint not null,
  note text,
  deleted boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.settings (
  user_id uuid not null default auth.uid(),
  key text not null,
  value text not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, key)
);

-- ─── Segurança (RLS): cada usuário só enxerga o que é dele ─────────────
alter table public.accounts     enable row level security;
alter table public.categories   enable row level security;
alter table public.transactions enable row level security;
alter table public.investments  enable row level security;
alter table public.dividends    enable row level security;
alter table public.settings     enable row level security;

drop policy if exists dono_acesso on public.accounts;
create policy dono_acesso on public.accounts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists dono_acesso on public.categories;
create policy dono_acesso on public.categories for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists dono_acesso on public.transactions;
create policy dono_acesso on public.transactions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists dono_acesso on public.investments;
create policy dono_acesso on public.investments for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists dono_acesso on public.dividends;
create policy dono_acesso on public.dividends for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists dono_acesso on public.settings;
create policy dono_acesso on public.settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Pronto. Agora é só criar sua conta dentro do app e sincronizar.
