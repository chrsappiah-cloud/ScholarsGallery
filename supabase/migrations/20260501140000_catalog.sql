-- Gallery catalog (read by ScholarsGalleryServer via service role; no public anon policies).
create table if not exists public.exhibitions (
    id uuid primary key,
    slug text not null unique,
    title text not null,
    subtitle text not null,
    opening_at timestamptz not null,
    manifest jsonb not null,
    sort_order int not null default 0
);

create table if not exists public.essays (
    id text primary key,
    title text not null,
    author text not null,
    markdown_body text not null,
    references jsonb not null default '[]'::jsonb
);

create table if not exists public.exhibition_artworks (
    id uuid primary key,
    exhibition_slug text not null,
    sort_order int not null,
    title text not null,
    tags text[] not null,
    hero_asset_path text not null,
    thumbnail_asset_path text,
    wall_label_markdown text not null,
    edition_number int,
    edition_total int
);

create index if not exists exhibition_artworks_slug_sort_idx
    on public.exhibition_artworks (exhibition_slug, sort_order);

alter table public.exhibitions enable row level security;
alter table public.essays enable row level security;
alter table public.exhibition_artworks enable row level security;

-- Seed (matches bundled static catalog in Vapor).
insert into public.exhibitions (id, slug, title, subtitle, opening_at, manifest, sort_order)
values (
    '11111111-1111-1111-1111-111111111111',
    'worlds-written-in-light',
    'Worlds Written in Light',
    'A scholarly immersive biennale of generative media.',
    now(),
    '{
      "exhibitionId": "worlds-written-in-light",
      "title": "Worlds Written in Light",
      "rooms": [
        {
          "id": "threshold",
          "kind": "intro",
          "title": "Threshold",
          "artworkIDs": ["a1", "a2"],
          "ambientAudio": "ambient/threshold.m4a",
          "lighting": {"preset": "soft_gold", "intensity": 0.45},
          "wallEssayID": null,
          "transitions": ["theory-hall"]
        },
        {
          "id": "theory-hall",
          "kind": "essay-space",
          "title": "Theory Hall",
          "artworkIDs": ["a3"],
          "ambientAudio": null,
          "lighting": {"preset": "neutral_white", "intensity": 0.30},
          "wallEssayID": "essay-001",
          "transitions": ["threshold"]
        }
      ]
    }'::jsonb,
    0
)
on conflict (slug) do nothing;

insert into public.essays (id, title, author, markdown_body, references)
values
    (
        'essay-001',
        'Generative Art as Scholarly Surface',
        'ScholarsGallery Editorial Board',
        E'This essay examines generative media as a scholarly object:\nprovenance, interpretation, and computational aesthetics.',
        '["teamLab", "ARTECHOUSE", "Museum of Other Realities"]'::jsonb
    ),
    (
        'essay-002',
        'Curation in Spatial Digital Museums',
        'Curatorial Systems Lab',
        E'Spatial digital museums ask curators to choreograph **attention, navigation, and evidence** across rooms that behave like essays, datasets, and stages at once.',
        '["Whitney Artport", "Serpentine R&D", "MoMA Post"]'::jsonb
    )
on conflict (id) do nothing;

insert into public.exhibition_artworks (
    id, exhibition_slug, sort_order, title, tags,
    hero_asset_path, thumbnail_asset_path, wall_label_markdown,
    edition_number, edition_total
)
values
    (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'worlds-written-in-light',
        1,
        'WCS — Three Apps Suite',
        array['WCS', 'Social', 'Product']::text[],
        'media/wcs-social-promo/promo_three_apps_suite_1080.png',
        'media/wcs-social-promo/promo_three_apps_suite_1080.png',
        'Social promo: the **ScholarsGallery** suite alongside companion WCS apps — one story across three surfaces.',
        1, 20
    ),
    (
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
        'worlds-written-in-light',
        2,
        'Explore WCS',
        array['WCS', 'Brand', 'Discovery']::text[],
        'media/wcs-social-promo/promo_explore_wcs_1080.png',
        'media/wcs-social-promo/promo_explore_wcs_1080.png',
        'Invitation to explore the **World Computational Salon** platform and gallery ecosystem.',
        2, 20
    ),
    (
        'cccccccc-cccc-cccc-cccc-cccccccccccc',
        'worlds-written-in-light',
        3,
        'WCS Platform',
        array['WCS', 'Platform', 'Scholarship']::text[],
        'media/wcs-social-promo/promo_wcs_platform_1080.png',
        'media/wcs-social-promo/promo_wcs_platform_1080.png',
        'Platform-wide social asset highlighting **scholarship, curation, and generative media** under WCS.',
        3, 20
    ),
    (
        'dddddddd-dddd-dddd-dddd-dddddddddddd',
        'worlds-written-in-light',
        4,
        'Ethereal Veil',
        array['WCS', 'Aesthetic', 'Light']::text[],
        'media/wcs-social-promo/promo_ethereal_veil_1080.png',
        'media/wcs-social-promo/promo_ethereal_veil_1080.png',
        'Brand-forward **ethereal veil** visual from the WCS social promo set — light, depth, and digital atmosphere.',
        4, 20
    )
on conflict (id) do nothing;
