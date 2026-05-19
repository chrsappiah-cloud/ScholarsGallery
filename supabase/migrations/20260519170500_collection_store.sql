-- Collection and favorites persistence for ScholarsGallery UI/server sync.
create table if not exists public.collection_records (
    id text primary key,
    artwork_id text not null,
    acquired_at timestamptz not null,
    certificate_id text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint collection_records_id_not_blank check (char_length(btrim(id)) > 0),
    constraint collection_records_artwork_id_not_blank check (char_length(btrim(artwork_id)) > 0),
    constraint collection_records_certificate_id_not_blank check (char_length(btrim(certificate_id)) > 0)
);

create index if not exists collection_records_artwork_id_idx
    on public.collection_records (artwork_id);

create index if not exists collection_records_acquired_at_idx
    on public.collection_records (acquired_at desc);

create table if not exists public.collection_favorites (
    artwork_id text primary key,
    created_at timestamptz not null default now(),
    constraint collection_favorites_artwork_id_not_blank check (char_length(btrim(artwork_id)) > 0)
);

alter table public.collection_records enable row level security;
alter table public.collection_favorites enable row level security;

-- No anon policies: clients go through ScholarsGalleryServer with service role credentials.
