-- Use only for this previously absent module before any real invitation/membership data.
BEGIN;
DO $guard$ BEGIN IF EXISTS(SELECT FROM public.company_access_invitations) THEN RAISE EXCEPTION 'Preserve invitation data before rollback'; END IF; END $guard$;
DROP FUNCTION public.accept_company_access_invitation(text);
DROP FUNCTION public.accept_my_company_invitation(uuid);
DROP FUNCTION public.decline_my_company_invitation(uuid);
DROP FUNCTION public.get_my_company_access(uuid);
DROP FUNCTION public.get_my_pending_company_invitations();
DROP FUNCTION public.revoke_company_access_invitation(uuid);
DROP FUNCTION public.owner_invite_existing_company_user(uuid,text,text);
DROP TABLE public.company_access_invitations;
NOTIFY pgrst,'reload schema';
COMMIT;
