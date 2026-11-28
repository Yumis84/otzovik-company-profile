BEGIN;
SET LOCAL lock_timeout='3s';
SET LOCAL statement_timeout='30s';
ALTER TABLE public.company_locations ADD CONSTRAINT company_locations_company_id_id_key UNIQUE(company_id,id);
CREATE TABLE public.review_sources (
id uuid PRIMARY KEY DEFAULT gen_random_uuid(), company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE, location_id uuid, name text NOT NULL, source_type text NOT NULL, profile_url text NOT NULL, collection_method text NOT NULL, terms_notes text, status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published','archived')), checked_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(company_id,profile_url), UNIQUE(company_id,id), FOREIGN KEY(company_id,location_id) REFERENCES public.company_locations(company_id,id) ON DELETE RESTRICT);
CREATE TABLE public.source_ratings (
id uuid PRIMARY KEY DEFAULT gen_random_uuid(), source_id uuid NOT NULL REFERENCES public.review_sources(id) ON DELETE CASCADE, rating numeric(4,2) NOT NULL CHECK(rating>=0), rating_scale numeric(4,2) NOT NULL DEFAULT 5 CHECK(rating_scale>0), rating_count integer CHECK(rating_count>=0), review_count integer CHECK(review_count>=0), checked_at timestamptz NOT NULL, status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published','archived')), created_at timestamptz NOT NULL DEFAULT now(), UNIQUE(source_id,checked_at), CHECK(rating<=rating_scale));
CREATE TABLE public.reviews (
id uuid PRIMARY KEY DEFAULT gen_random_uuid(), company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE, source_id uuid NOT NULL, location_id uuid, source_review_id text, source_url text NOT NULL, author_display_name text, published_at timestamptz, source_updated_at timestamptz, collected_at timestamptz NOT NULL, rating numeric(4,2) CHECK(rating>=0), rating_scale numeric(4,2) DEFAULT 5 CHECK(rating_scale>0), excerpt text, language text NOT NULL DEFAULT 'ru', content_hash text NOT NULL, provenance jsonb NOT NULL DEFAULT '{}', status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published','removed','disputed','archived')), created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), body text NOT NULL, UNIQUE(source_id,content_hash), UNIQUE(source_id,source_review_id), FOREIGN KEY(company_id,source_id) REFERENCES public.review_sources(company_id,id) ON DELETE RESTRICT, FOREIGN KEY(company_id,location_id) REFERENCES public.company_locations(company_id,id) ON DELETE RESTRICT, CHECK(rating<=rating_scale));
ALTER TABLE public.review_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.source_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.review_sources,public.source_ratings,public.reviews FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.review_sources,public.source_ratings,public.reviews TO service_role;
COMMIT;
