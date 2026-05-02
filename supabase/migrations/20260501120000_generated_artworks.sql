-- Persisted AI generations (written only by ScholarsGalleryServer with service role).
create table if not exists public.generated_artworks (
    id uuid primary key,
    status text not null,
    image_url text not null,
    prompt text not null,
    provider text not null,
    created_at timestamptz not null default now()
);

create index if not exists generated_artworks_created_at_idx
    on public.generated_artworks (created_at desc);

alter table public.generated_artworks enable row level security;

-- No anon policies: clients use the Vapor API; server uses service role (bypasses RLS).
