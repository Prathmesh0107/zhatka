-- READ-ONLY. Password hashes cannot be tested in SQL; the app does it at startup and forces a change (see the server log
-- line "still use a well-known default password"). This lists accounts so you can review who exists.
select id, username, role, active, must_change_password, created_at from public.users order by id;   -- use private.users after 0004
select count(*) as live_sessions from public.sessions where expires_at > extract(epoch from now())::bigint;
