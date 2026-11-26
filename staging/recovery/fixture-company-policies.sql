CREATE POLICY anon_read_published_company_media ON storage.objects FOR SELECT TO anon USING (((bucket_id = 'company-media'::text) AND storage.allow_any_operation(ARRAY['object.get_authenticated_info'::text, 'object.get_authenticated'::text]) AND media_internal.is_published_company_media_object(name)));
CREATE POLICY company_media_owner_delete ON storage.objects FOR DELETE TO authenticated USING (((bucket_id = 'company-media'::text) AND ((storage.foldername(name))[1] IN ( SELECT (company_memberships.company_id)::text AS company_id
   FROM company_memberships
  WHERE ((company_memberships.user_id = ( SELECT auth.uid() AS uid)) AND (company_memberships.verification_status = 'verified'::text) AND (company_memberships.role = ANY (ARRAY['owner'::text, 'admin'::text])))))));
CREATE POLICY company_media_owner_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (((bucket_id = 'company-media'::text) AND ((storage.foldername(name))[1] IN ( SELECT (company_memberships.company_id)::text AS company_id
   FROM company_memberships
  WHERE ((company_memberships.user_id = auth.uid()) AND (company_memberships.verification_status = 'verified'::text) AND (company_memberships.role = ANY (ARRAY['owner'::text, 'admin'::text])))))));
CREATE POLICY company_media_owner_read ON storage.objects FOR SELECT TO authenticated USING (((bucket_id = 'company-media'::text) AND ((storage.foldername(name))[1] IN ( SELECT (company_memberships.company_id)::text AS company_id
   FROM company_memberships
  WHERE ((company_memberships.user_id = auth.uid()) AND (company_memberships.verification_status = 'verified'::text) AND (company_memberships.role = ANY (ARRAY['owner'::text, 'admin'::text])))))));
