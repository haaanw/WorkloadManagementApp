-- RPC function: delete_own_account
-- Allows authenticated users to delete their own account.
-- Runs with SECURITY DEFINER to access auth.users.
-- Called from the iOS app via: client.rpc("delete_own_account")

CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete athlete row (cascades to workouts, snapshots, etc. via FK)
  DELETE FROM public.athletes WHERE user_id = _uid;

  -- Delete the auth user (removes session, identities, etc.)
  DELETE FROM auth.users WHERE id = _uid;
END;
$$;

-- Grant execute to authenticated users only
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;
