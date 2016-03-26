CREATE FUNCTION _cat_snap.throw(
  message text
) RETURNS boolean LANGUAGE plpgsql AS $body$
BEGIN
  RAISE EXCEPTION '%', message;
  RETURN false;
END
$body$;

CREATE FUNCTION _cat_snap.verify_equal(
  a anyelement
  , b anyelement
  , message text
) RETURNS anyelement LANGUAGE sql IMMUTABLE AS $body$
SELECT CASE WHEN a IS DISTINCT FROM b THEN
  -- This case is here just to get return types to agree. throw() always returns false
  CASE WHEN _cat_snap.throw(message) THEN NULL END
  ELSE a
  END
$body$;

CREATE FUNCTION pg_temp.subtract_code(
  typename text
  , attributes attribute[]
  , subtract_keys text[]
  , subtract_counters text[]
  , subtract_fields text[]
) RETURNS text LANGUAGE plpgqsl AS $body$
DECLARE
  logic text[];
BEGIN
  -- First, build the set of comparisons
  logic := array(
    SELECT logic FROM (
    SELECT CASE
      WHEN attribute_name <@ subtract_keys THEN
        format(
          $$_cat_snap.verify_equal( (a).%1$I, (b).%1$I, %1$L || 'must match' )$$
          , attribute_name
        )
      -- TODO: Replace counter subtraction with real logic
      WHEN attribute_name <@ subtract_counters
        OR attribute_name <@ subtract_fields
        THEN
        format(
          $$(a).%1$I - (b).%1$I$$
          , attribute_name
        )
      END AS logic
    FROM unnest(attributes) a
  ) l
  WHERE logic IS NOT NULL
  ;
  RETURN format(
$template$
CREATE FUNCTION _cat_snap.subtract(
  a cat_snap.%1$s
  , b cat_snap.%1$s
) RETURNS cat_snap.%1$s LANGUAGE sql IMMUTABLE STRICT AS $subtract$
SELECT %s
$subtract$;
$template$
    , typename
    , array_to_string( logic, E'\n  , ' )
  );
END
$body$;

-- vi: expandtab ts=2 sw=2