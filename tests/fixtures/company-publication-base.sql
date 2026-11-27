-- Deliberately synthetic isolated DB schema and data, never a hosted migration.
CREATE TABLE public.companies(id uuid PRIMARY KEY,slug text,name text,description text,legal_name text,website text,phone text,city text,profile_status text,status text,email text,updated_at timestamptz);
CREATE TABLE public.company_locations(id uuid PRIMARY KEY,company_id uuid,name text,relationship_type text,canonical_address text,city text,phone text,hours jsonb,official_url text,source_url text,verified_at timestamptz,status text);
CREATE TABLE public.company_services(id uuid PRIMARY KEY,company_id uuid,name text,category text,description text,official_url text,source_url text,verified_at timestamptz,status text);
CREATE TABLE public.company_media(id uuid PRIMARY KEY,company_id uuid,media_type text,storage_object_name text,sort_order int,alt_text text,caption text,updated_at timestamptz,status text);
INSERT INTO public.companies(id,slug,name,description,status,profile_status,email,updated_at) VALUES
('00000000-0000-0000-0000-000000000001','alpha','Synthetic Alpha','Synthetic company','active','ready','PRIVATE@example.invalid',now()),
('00000000-0000-0000-0000-000000000002','beta','Synthetic Beta','Foreign company','active','ready','FOREIGN@example.invalid',now());
