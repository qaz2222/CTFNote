CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE FUNCTION ctfnote.register (LOGIN text, PASSWORD text)
  RETURNS ctfnote.jwt
  AS $$
DECLARE
  is_first_user boolean;
  new_user ctfnote_private.user;
  new_profile ctfnote.profile;
BEGIN
  SELECT
    (count(id) = 0) INTO is_first_user
  FROM
    ctfnote_private.user;
  INSERT INTO ctfnote_private.user ("login", "password", "role")
    VALUES (login, crypt("password", gen_salt('bf')), (
        CASE WHEN (is_first_user) THEN
          'user_admin'::ctfnote.role
        ELSE
          'user_guest'::ctfnote.role
        END))
  RETURNING
    * INTO new_user;
  INSERT INTO ctfnote.profile ("id", "username")
    VALUES (new_user.id, login)
  RETURNING
    * INTO new_profile;
  RETURN ctfnote_private.new_token (new_user.id);
END;
$$
LANGUAGE plpgsql
STRICT
SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION ctfnote.register (text, text) TO user_anonymous;

CREATE FUNCTION ctfnote.login ("login" text, "password" text)
  RETURNS ctfnote.jwt
  AS $$
DECLARE
  log_user ctfnote_private.user;
BEGIN
  SELECT
    * INTO log_user
  FROM
    ctfnote_private.user
  WHERE
    "user"."login" = "login"."login";
  IF log_user."password" = crypt("password", log_user."password") THEN
    RETURN ctfnote_private.new_token (log_user.id);
  ELSE
    RETURN NULL;
  END IF;
END;
$$
LANGUAGE plpgsql
STRICT
SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION ctfnote.login (text, text) TO user_anonymous;

CREATE FUNCTION ctfnote_private.user_id ()
  RETURNS integer
  AS $$
  SELECT
    nullif (current_setting('jwt.claims.user_id', TRUE), '')::integer;

$$
LANGUAGE sql
STABLE;

GRANT EXECUTE ON FUNCTION ctfnote_private.user_id () TO user_guest;

CREATE TYPE ctfnote.me_response AS (
  "profile" ctfnote.profile,
  "role" ctfnote.role,
  "jwt" ctfnote.jwt
);

CREATE FUNCTION ctfnote.me ()
  RETURNS ctfnote.me_response
  AS $$
DECLARE
  me ctfnote.profile;
BEGIN
  SELECT
    * INTO me
  FROM
    ctfnote.profile
  WHERE
    id = ctfnote_private.user_id ()
  LIMIT 1;
  IF me IS NOT NULL THEN
    RETURN (me,
      ctfnote.profile_role (me.id),
      ctfnote_private.new_token (me.id)::ctfnote.me_response);
  ELSE
    RETURN NULL;
  END IF;
END;
$$
LANGUAGE plpgsql
STRICT STABLE;

GRANT EXECUTE ON FUNCTION ctfnote.me () TO user_anonymous;

