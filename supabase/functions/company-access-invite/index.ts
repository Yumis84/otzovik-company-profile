import { createClient } from "npm:@supabase/supabase-js@2.115.0";

const cabinetOrigin = "https://otzovik-pr51-preview-1lcsimwdp-yumis84-7003s-projects.vercel.app";
const roles = new Set(["admin", "manager", "analyst"]);

Deno.serve(async (request) => {
  const origin = request.headers.get("Origin");
  const headers = {
    "Access-Control-Allow-Origin": cabinetOrigin,
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Cache-Control": "no-store",
    "Vary": "Origin",
  };
  const reply = (status: number, detail: string) => Response.json({ detail }, { status, headers });

  if (origin !== cabinetOrigin) return reply(403, "Недопустимый источник запроса.");
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (request.method !== "POST") return reply(405, "Метод не поддерживается.");

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return reply(401, "Войдите в кабинет.");

  const body = await request.json().catch(() => null);
  const companyId = body?.company_id;
  const email = typeof body?.email === "string" ? body.email.trim().toLowerCase() : "";
  const role = body?.role;
  if (typeof companyId !== "string" ||
      !/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(companyId) ||
      email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
      !roles.has(role)) {
    return reply(400, "Проверьте компанию, email и роль.");
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (url !== "https://salmcnhexlftrgtiryyo.supabase.co" || !anonKey || !serviceKey) {
    return reply(503, "Приглашения временно недоступны.");
  }

  const auth = { persistSession: false, autoRefreshToken: false };
  const caller = createClient(url, anonKey, { auth, global: { headers: { Authorization: authorization } } });
  const args = { p_company_id: companyId, p_email: email, p_role: role };

  // The existing RPC checks verified ownership before looking up the recipient.
  const initial = await caller.rpc("owner_invite_existing_company_user", args);
  if (initial.error) return reply(403, "Не удалось создать приглашение для этой компании.");
  if (initial.data?.existing_user === true) return Response.json({ delivery: "cabinet" }, { headers });
  if (initial.data?.existing_user !== false) return reply(502, "Не удалось проверить получателя.");

  // Auth sends only a sign-in invitation. Company access still requires acceptance of
  // the pending invitation produced by the same owner-authorized RPC.
  const admin = createClient(url, serviceKey, { auth });
  const sent = await admin.auth.admin.inviteUserByEmail(email, {
    redirectTo: cabinetOrigin + "/account-home.html",
  });
  if (sent.error) return reply(502, "Не удалось отправить письмо. Попробуйте ещё раз.");

  const pending = await caller.rpc("owner_invite_existing_company_user", args);
  if (pending.error || pending.data?.existing_user !== true) {
    return reply(409, "Письмо отправлено, но доступ к компании ещё не предложен. Повторите приглашение из кабинета.");
  }
  return Response.json({ delivery: "email" }, { headers });
});
