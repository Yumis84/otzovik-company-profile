-- CANDIDATE ONLY. Not approved or applied to hosted Supabase.
-- Additive to PR #31. No changes to company objects or existing settings RPCs.
BEGIN;
SET LOCAL statement_timeout='60s';
DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls)) THEN RAISE EXCEPTION 'Trusted BYPASSRLS owner required'; END IF; END $$;
CREATE TABLE public.specialist_channel_sets (
 specialist_id uuid PRIMARY KEY REFERENCES public.specialist_profiles(id) ON DELETE CASCADE,
 version integer NOT NULL CHECK(version>0),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.specialist_contact_channels (
 id uuid PRIMARY KEY,
 specialist_id uuid NOT NULL REFERENCES public.specialist_channel_sets(specialist_id) ON DELETE CASCADE,
 kind text NOT NULL CHECK(kind IN ('telegram','max','vk','whatsapp','ok','website','portfolio')),
 value_raw text NOT NULL CHECK(char_length(value_raw)<=500),
 href text NOT NULL CHECK(char_length(href)<=500 AND href LIKE 'https://%'),
 label text NOT NULL DEFAULT '' CHECK(char_length(label)<=40),
 sort_order integer NOT NULL CHECK(sort_order BETWEEN 0 AND 19),
 is_preferred boolean NOT NULL DEFAULT false,
 accepts_inquiries boolean NOT NULL DEFAULT false,
 is_public boolean NOT NULL DEFAULT false CHECK(NOT is_public),
 UNIQUE(specialist_id,kind,href), UNIQUE(specialist_id,sort_order)
);
CREATE UNIQUE INDEX specialist_contact_one_preferred ON public.specialist_contact_channels(specialist_id) WHERE is_preferred;
ALTER TABLE public.specialist_channel_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_channel_sets FORCE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_contact_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.specialist_contact_channels FORCE ROW LEVEL SECURITY;
REVOKE ALL ON public.specialist_channel_sets,public.specialist_contact_channels FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.specialist_channel_normalize(p_kind text,p_value text)
RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $fn$
DECLARE s text:=btrim(p_value); m text[]; host text; path text; q text; segment text;
BEGIN
 IF p_kind IS NULL OR p_kind NOT IN ('telegram','max','vk','whatsapp','ok','website','portfolio')
 OR s IS NULL OR s='' OR char_length(s)>500 OR s ~ '[^!-~]' OR s ~ $r$[\\<>"']$r$
 OR s ~* '%(0[0-9a-f]|1[0-9a-f]|7f|5c|3c|3e|22|27)' THEN RAISE EXCEPTION 'Invalid contact' USING ERRCODE='22023'; END IF;
 IF p_kind='telegram' AND s ~ '^@[A-Za-z][A-Za-z0-9_]{0,31}$' THEN s:='https://t.me/'||substr(s,2); END IF;
 IF p_kind='whatsapp' AND s ~ '^\+[1-9][0-9]{7,14}$' THEN s:='https://wa.me/'||ltrim(s,'+'); END IF;
 m:=regexp_match(s,'^https://([^/?#]+)([^?#]*)(\?[^#]*)?$');
 IF s ~* '%([^0-9a-f]|[0-9a-f]([^0-9a-f]|$)|$)' OR s ~* '(/|%2f)(\.|%2e){1,2}(/|%2f|\?|$)' THEN RAISE EXCEPTION 'Invalid URL path' USING ERRCODE='22023'; END IF;
 IF m IS NULL THEN RAISE EXCEPTION 'HTTPS URL required' USING ERRCODE='22023'; END IF;
 host:=lower(m[1]);path:=coalesce(nullif(m[2],''),'/');q:=coalesce(m[3],'');
 IF char_length(host)>253 OR host !~ '\.[a-z]{2,63}$' OR host ~ '\.(local|localhost|internal|invalid|test|example)$' THEN RAISE EXCEPTION 'Invalid host' USING ERRCODE='22023'; END IF;
 FOREACH segment IN ARRAY string_to_array(host,'.') LOOP
 IF segment !~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$' OR segment LIKE 'xn--%' THEN RAISE EXCEPTION 'Invalid host label' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF p_kind='telegram' THEN
 IF host NOT IN ('t.me','telegram.me') OR path !~ '^/[A-Za-z][A-Za-z0-9_]{0,31}/?$' OR q<>'' OR replace(path,'/','') ~* '^(share|proxy|socks|login|joinchat|addstickers|addemoji|boost|giftcode|invoice|iv|c|s|bg|contact|confirmphone|setlanguage)$' THEN RAISE EXCEPTION 'Invalid Telegram profile' USING ERRCODE='22023';END IF;
 host:='t.me';path:='/'||lower(replace(path,'/',''));
 ELSIF p_kind='whatsapp' THEN
 IF host<>'wa.me' OR path !~ '^/[1-9][0-9]{7,14}$' OR q<>'' THEN RAISE EXCEPTION 'Invalid WhatsApp number' USING ERRCODE='22023'; END IF;
 ELSIF p_kind='vk' THEN
 IF host NOT IN ('vk.com','m.vk.com') OR path !~ '^/[A-Za-z0-9_.-]+/?$' OR q<>'' OR path ~* '^/(away(\.php)?|login|oauth|share|cc)/?$' THEN RAISE EXCEPTION 'Invalid VK profile' USING ERRCODE='22023'; END IF;
 host:='vk.com';path:=lower(rtrim(path,'/'));
 ELSIF p_kind='ok' THEN
 IF host NOT IN ('ok.ru','m.ok.ru') OR path !~ '^/(profile/[0-9]+|[A-Za-z0-9_.-]+)/?$' OR q<>'' OR path ~* '^/(dk|login|help|outlink|away)/?$' THEN RAISE EXCEPTION 'Invalid OK profile' USING ERRCODE='22023'; END IF;
 host:='ok.ru';path:=lower(rtrim(path,'/'));
 ELSIF p_kind='max' THEN
 IF host<>'max.ru' OR path='/' OR q<>'' THEN RAISE EXCEPTION 'Copied MAX profile URL required' USING ERRCODE='22023'; END IF;
 END IF;
 RETURN 'https://'||host||path||q;
END $fn$;
REVOKE ALL ON FUNCTION public.specialist_channel_normalize(text,text) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.list_my_specialist_channels(p_specialist_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v integer; rows jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft';
 IF NOT FOUND THEN RAISE EXCEPTION 'Draft not found' USING ERRCODE='42501'; END IF;
 SELECT version INTO v FROM public.specialist_channel_sets WHERE specialist_id=p_specialist_id;
 SELECT coalesce(jsonb_agg(to_jsonb(c)-'specialist_id' ORDER BY c.sort_order),'[]'::jsonb) INTO rows FROM public.specialist_contact_channels c WHERE specialist_id=p_specialist_id;
 RETURN jsonb_build_object('version',coalesce(v,0),'channels',rows);
END $fn$;

CREATE FUNCTION public.save_my_specialist_channels(p_specialist_id uuid,p_version integer,p_channels jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $fn$
DECLARE v integer; r jsonb; normalized text; ord integer:=0; preferred integer:=0; cid uuid; lbl text; k text; flag text; allrows jsonb:='[]'; ids uuid[]:='{}'; keys text[]:='{}'; dedup text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 PERFORM 1 FROM public.specialist_profiles WHERE id=p_specialist_id AND owner_user_id=auth.uid() AND profile_status='draft' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Draft not found' USING ERRCODE='42501'; END IF;
 SELECT version INTO v FROM public.specialist_channel_sets WHERE specialist_id=p_specialist_id FOR UPDATE;
 IF p_version IS NULL OR p_version<0 OR p_version<>coalesce(v,0) THEN RAISE EXCEPTION 'Contacts changed; reload' USING ERRCODE='PT409'; END IF;
 IF p_channels IS NULL OR jsonb_typeof(p_channels)<>'array' THEN RAISE EXCEPTION 'Array required' USING ERRCODE='22023'; END IF;
 IF jsonb_array_length(p_channels)>20 THEN RAISE EXCEPTION 'Maximum 20 contacts' USING ERRCODE='54000'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_channels) LOOP
 IF jsonb_typeof(r)<>'object' THEN RAISE EXCEPTION 'Object required' USING ERRCODE='22023'; END IF;
 FOR k IN SELECT jsonb_object_keys(r) LOOP
 IF k NOT IN ('id','kind','value_raw','label','is_preferred','accepts_inquiries','is_public') THEN RAISE EXCEPTION 'Unknown field' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF jsonb_typeof(r->'id') IS DISTINCT FROM 'string' OR (r->>'id') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 OR jsonb_typeof(r->'kind') IS DISTINCT FROM 'string' OR jsonb_typeof(r->'value_raw') IS DISTINCT FROM 'string'
 OR (r ? 'label' AND jsonb_typeof(r->'label') IS DISTINCT FROM 'string') THEN RAISE EXCEPTION 'Invalid field type' USING ERRCODE='22023'; END IF;
 FOREACH flag IN ARRAY ARRAY['is_preferred','accepts_inquiries','is_public'] LOOP
 IF r ? flag AND jsonb_typeof(r->flag) IS DISTINCT FROM 'boolean' THEN RAISE EXCEPTION 'Boolean required' USING ERRCODE='22023'; END IF;
 END LOOP;
 IF coalesce((r->>'is_public')::boolean,false) THEN RAISE EXCEPTION 'Public contacts not enabled' USING ERRCODE='22023'; END IF;
 cid:=(r->>'id')::uuid;
 IF cid=ANY(ids) THEN RAISE EXCEPTION 'Duplicate ID' USING ERRCODE='23505'; END IF;
 IF EXISTS(SELECT 1 FROM public.specialist_contact_channels WHERE id=cid AND specialist_id<>p_specialist_id) THEN RAISE EXCEPTION 'Foreign contact' USING ERRCODE='42501'; END IF;
 ids:=array_append(ids,cid);
 normalized:=public.specialist_channel_normalize(r->>'kind',r->>'value_raw');lbl:=btrim(coalesce(r->>'label',''));
 IF char_length(lbl)>40 OR lbl ~ '[[:cntrl:]]' THEN RAISE EXCEPTION 'Invalid label' USING ERRCODE='22023'; END IF;
 dedup:=(r->>'kind')||'|'||normalized;
 IF dedup=ANY(keys) THEN RAISE EXCEPTION 'Duplicate contact' USING ERRCODE='23505'; END IF;
 keys:=array_append(keys,dedup);
 IF coalesce((r->>'is_preferred')::boolean,false) THEN preferred:=preferred+1;END IF;
 IF preferred>1 THEN RAISE EXCEPTION 'One preferred contact only' USING ERRCODE='22023'; END IF;
 allrows:=allrows||jsonb_build_array(jsonb_build_object('id',cid,'kind',r->>'kind','value_raw',r->>'value_raw','href',normalized,'label',lbl,'sort_order',ord,'is_preferred',coalesce((r->>'is_preferred')::boolean,false),'accepts_inquiries',coalesce((r->>'accepts_inquiries')::boolean,false),'is_public',false));ord:=ord+1;
 END LOOP;
 INSERT INTO public.specialist_channel_sets(specialist_id,version) VALUES(p_specialist_id,1) ON CONFLICT(specialist_id) DO UPDATE SET version=public.specialist_channel_sets.version+1,updated_at=now();
 DELETE FROM public.specialist_contact_channels WHERE specialist_id=p_specialist_id;
 INSERT INTO public.specialist_contact_channels SELECT x.id,p_specialist_id,x.kind,x.value_raw,x.href,x.label,x.sort_order,x.is_preferred,x.accepts_inquiries,x.is_public
 FROM jsonb_to_recordset(allrows) AS x(id uuid,kind text,value_raw text,href text,label text,sort_order integer,is_preferred boolean,accepts_inquiries boolean,is_public boolean);
 RETURN public.list_my_specialist_channels(p_specialist_id);
END $fn$;
REVOKE ALL ON FUNCTION public.list_my_specialist_channels(uuid),public.save_my_specialist_channels(uuid,integer,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.list_my_specialist_channels(uuid),public.save_my_specialist_channels(uuid,integer,jsonb) TO authenticated;
COMMIT;
