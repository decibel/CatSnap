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

CREATE FUNCTION _cat_snap.subtract_code(
  typename text
  , attributes attribute[]
  , subtract_keys text[]
  , subtract_counters text[]
  , subtract_fields text[]
) RETURNS text SET search_path FROM CURRENT LANGUAGE plpgsql AS $body$
DECLARE
  operations text[];
BEGIN
  -- First, build the set of comparisons
  operations := array(
      SELECT logic FROM (
      SELECT CASE
        WHEN array[attribute_name] <@ subtract_keys THEN
          format(
            $$_cat_snap.verify_equal( (a).%1$I, (b).%1$I, %1$L || 'must match' )$$
            , attribute_name
          )
        -- TODO: Replace counter subtraction with real logic
        WHEN array[attribute_name] <@ subtract_counters
          OR array[attribute_name] <@ subtract_fields
          THEN
          format(
            $$(a).%1$I - (b).%1$I$$
            , attribute_name
          )
        ELSE format(
            $$(a).%I$$
            , attribute_name
          )
        END AS logic
      FROM unnest(attributes) a
    ) l
    WHERE logic IS NOT NULL
  );
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
    , array_to_string( operations, E'\n  , ' )
  );
END
$body$;

CREATE FUNCTION pg_temp.exec(
  sql text
) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE sql;
END
$$;

SELECT count( pg_temp.exec( _cat_snap.subtract_code(
      replace(entity, 'pg_', 'raw_'), attributes, subtract_keys, subtract_counters, subtract_fields
    ) ) )
  FROM cat_snap.entity
  WHERE entity_type = 'Stats File'
;
/*
*/
-- vi: expandtab ts=2 sw=2
