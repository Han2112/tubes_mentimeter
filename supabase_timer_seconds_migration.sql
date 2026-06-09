alter table public.slides
add column if not exists timer_seconds integer not null default 30;

update public.slides
set timer_seconds = 30
where timer_seconds is null;
