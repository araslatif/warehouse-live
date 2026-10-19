-- V100 incremental sync. Run on existing project; no restore/reset/reindex.
BEGIN;
CREATE TABLE IF NOT EXISTS public.warehouse_sync_pages100(page_key text PRIMARY KEY, hash text NOT NULL, data jsonb NOT NULL);
CREATE TABLE IF NOT EXISTS public.warehouse_sync_head100(id integer PRIMARY KEY CHECK(id=1),revision bigint NOT NULL,manifest jsonb NOT NULL);
ALTER TABLE public.warehouse_sync_pages100 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warehouse_sync_head100 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.warehouse_sync_pages100,public.warehouse_sync_head100 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.warehouse_materialize100(p_state jsonb,p_revision bigint,p_old jsonb DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='60s' AS $fn$
DECLARE entry record; chunk record; layout jsonb:='{}'; previous jsonb; spec jsonb; pages jsonb; kind text; step integer; key text; checksum text; alive text[]:='{}';
BEGIN
 SELECT manifest INTO previous FROM public.warehouse_sync_head100 WHERE id=1;
 FOR entry IN SELECT * FROM jsonb_each(p_state) LOOP
  IF p_old IS NOT NULL AND p_old->entry.key IS NOT DISTINCT FROM entry.value AND previous ? entry.key THEN
   spec:=previous->entry.key;
   SELECT alive||COALESCE(array_agg(value->>'key'),'{}'::text[]) INTO alive FROM jsonb_array_elements(spec->'pages');
   layout:=layout||jsonb_build_object(entry.key,spec);CONTINUE;
  END IF;
  kind:=jsonb_typeof(entry.value);pages:='[]';
  step:=CASE WHEN entry.key='reportArchive89' THEN 3 WHEN kind='object' THEN 1 ELSE 100 END;
  FOR chunk IN
   SELECT 0::bigint AS n,entry.value AS data WHERE kind NOT IN ('array','object')
   UNION ALL
   SELECT (ord-1)/step AS n,jsonb_agg(value ORDER BY ord) AS data FROM jsonb_array_elements(CASE WHEN kind='array' THEN entry.value ELSE '[]'::jsonb END) WITH ORDINALITY a(value,ord) GROUP BY (ord-1)/step
   UNION ALL
   SELECT (ord-1)/step AS n,jsonb_object_agg(k,v) AS data FROM (SELECT k,v,row_number() OVER(ORDER BY k) AS ord FROM jsonb_each(CASE WHEN kind='object' THEN entry.value ELSE '{}'::jsonb END) o(k,v)) o GROUP BY (ord-1)/step
   ORDER BY n
  LOOP
   key:=entry.key||':'||chunk.n::text;checksum:=md5(chunk.data::text);alive:=array_append(alive,key);
   INSERT INTO public.warehouse_sync_pages100(page_key,hash,data) VALUES(key,checksum,chunk.data)
    ON CONFLICT(page_key) DO UPDATE SET hash=EXCLUDED.hash,data=EXCLUDED.data WHERE warehouse_sync_pages100.hash IS DISTINCT FROM EXCLUDED.hash;
   pages:=pages||jsonb_build_array(jsonb_build_object('key',key,'hash',checksum));
  END LOOP;
  layout:=layout||jsonb_build_object(entry.key,jsonb_build_object('kind',kind,'pages',pages));
 END LOOP;
 DELETE FROM public.warehouse_sync_pages100 WHERE NOT(page_key=ANY(alive));
 INSERT INTO public.warehouse_sync_head100(id,revision,manifest) VALUES(1,p_revision,layout)
 ON CONFLICT(id) DO UPDATE SET revision=EXCLUDED.revision,manifest=EXCLUDED.manifest;
END $fn$;
REVOKE ALL ON FUNCTION public.warehouse_materialize100(jsonb,bigint,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.warehouse_projection_trigger100()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
BEGIN
 IF NEW.id=1 THEN PERFORM public.warehouse_materialize100(NEW.state,NEW.revision,CASE WHEN TG_OP='UPDATE' THEN OLD.state ELSE NULL END); END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION public.warehouse_projection_trigger100() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS warehouse_projection100 ON public.warehouse_state;
CREATE TRIGGER warehouse_projection100 AFTER INSERT OR UPDATE OF state,revision ON public.warehouse_state FOR EACH ROW EXECUTE FUNCTION public.warehouse_projection_trigger100();

CREATE OR REPLACE FUNCTION public.get_warehouse_manifest100(p_operation_ids text[] DEFAULT '{}',p_known_revision bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='15s' AS $fn$
DECLARE result jsonb;
BEGIN
 IF COALESCE(cardinality(p_operation_ids),0)>500 THEN RAISE EXCEPTION 'Too many operation IDs';END IF;
 SELECT jsonb_build_object('revision',h.revision,'manifest',CASE WHEN h.revision=p_known_revision THEN NULL ELSE h.manifest END,'applied_ids',COALESCE((SELECT jsonb_agg(o.operation_id) FROM public.warehouse_sync_operations_v61 o WHERE o.operation_id=ANY(p_operation_ids)),'[]'::jsonb)) INTO result FROM public.warehouse_sync_head100 h WHERE id=1;
 IF result IS NULL THEN RAISE EXCEPTION 'V100 sync is not initialized'; END IF;RETURN result;
END $fn$;

CREATE OR REPLACE FUNCTION public.get_warehouse_pages100(p_revision bigint,p_keys text[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='15s' AS $fn$
DECLARE current_revision bigint; result jsonb;
BEGIN
 IF p_keys IS NULL OR cardinality(p_keys)>4 THEN RAISE EXCEPTION 'Read at most four pages'; END IF;
 SELECT revision INTO current_revision FROM public.warehouse_sync_head100 WHERE id=1;
 IF current_revision IS DISTINCT FROM p_revision THEN RAISE EXCEPTION 'SYNC_CONFLICT: snapshot changed' USING ERRCODE='40001'; END IF;
 SELECT COALESCE(jsonb_agg(jsonb_build_object('key',page_key,'hash',hash,'data',data)),'[]'::jsonb) INTO result FROM public.warehouse_sync_pages100 WHERE page_key=ANY(p_keys);
 RETURN jsonb_build_object('revision',current_revision,'pages',result);
END $fn$;

CREATE TABLE IF NOT EXISTS public.warehouse_patch_parts100(upload_id text,part integer,total integer,hash text,data text,created_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(upload_id,part));
ALTER TABLE public.warehouse_patch_parts100 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.warehouse_patch_parts100 FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.stage_warehouse_patch100(p_upload_id text,p_index integer,p_total integer,p_data text,p_hash text)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public AS $fn$
BEGIN
 IF p_upload_id IS NULL OR length(p_upload_id)>240 OR p_index IS NULL OR p_total IS NULL OR p_index<0 OR p_total<1 OR p_total>2000 OR p_index>=p_total OR p_data IS NULL OR length(p_data)>100000 OR p_hash IS NULL OR p_hash!~'^[a-f0-9]{64}$' THEN RAISE EXCEPTION 'Invalid staged patch';END IF;
 INSERT INTO public.warehouse_patch_parts100(upload_id,part,total,hash,data) VALUES(p_upload_id,p_index,p_total,p_hash,p_data) ON CONFLICT(upload_id,part) DO UPDATE SET total=EXCLUDED.total,hash=EXCLUDED.hash,data=EXCLUDED.data;
 DELETE FROM public.warehouse_patch_parts100 WHERE created_at<now()-interval '1 day';
 RETURN p_index;
END $fn$;
REVOKE ALL ON FUNCTION public.stage_warehouse_patch100(text,integer,integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.stage_warehouse_patch100(text,integer,integer,text,text) TO anon,authenticated;

CREATE OR REPLACE FUNCTION public.save_warehouse_patch100(p_patch jsonb,p_expected_revision bigint,p_operation_ids text[],p_upload_id text DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public SET statement_timeout='60s' AS $fn$
DECLARE current_state jsonb; current_revision bigint; next_revision bigint; operation jsonb; path text[]; uploaded text; uploaded_hash text; total_parts integer; actual_parts integer;
BEGIN
 IF p_upload_id IS NOT NULL THEN
  SELECT count(*),max(total),min(hash),string_agg(data,'' ORDER BY part) INTO actual_parts,total_parts,uploaded_hash,uploaded FROM public.warehouse_patch_parts100 WHERE upload_id=p_upload_id;
  IF actual_parts IS DISTINCT FROM total_parts OR actual_parts<1 OR encode(sha256(convert_to(uploaded,'UTF8')),'hex') IS DISTINCT FROM uploaded_hash THEN RAISE EXCEPTION 'Staged patch incomplete or checksum mismatch';END IF;
  p_patch:=uploaded::jsonb;
 END IF;
 IF jsonb_typeof(p_patch) IS DISTINCT FROM 'array' OR jsonb_array_length(p_patch)>50000 OR p_operation_ids IS NULL OR cardinality(p_operation_ids)<1 OR cardinality(p_operation_ids)>500 OR EXISTS(SELECT 1 FROM unnest(p_operation_ids) x WHERE x IS NULL OR length(x)>200) THEN RAISE EXCEPTION 'Invalid sync patch';END IF;
 SELECT state,revision INTO current_state,current_revision FROM public.warehouse_state WHERE id=1 FOR UPDATE;
 IF current_revision IS NULL THEN RAISE EXCEPTION 'Warehouse state missing';END IF;
 IF current_revision IS DISTINCT FROM p_expected_revision OR EXISTS(SELECT 1 FROM public.warehouse_sync_operations_v61 WHERE operation_id=ANY(p_operation_ids)) THEN RAISE EXCEPTION 'SYNC_CONFLICT: refresh and retry' USING ERRCODE='40001';END IF;
 FOR operation IN SELECT value FROM jsonb_array_elements(p_patch) LOOP
  IF jsonb_typeof(operation->'path') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Invalid patch path';END IF;
  SELECT COALESCE(array_agg(value ORDER BY ord),'{}'::text[]) INTO path FROM jsonb_array_elements_text(operation->'path') WITH ORDINALITY a(value,ord);
  IF operation->>'op'='set' AND operation ? 'value' THEN
   IF cardinality(path)=0 THEN current_state:=operation->'value';ELSE current_state:=jsonb_set(current_state,path,operation->'value',true);END IF;
  ELSIF operation->>'op'='remove' AND cardinality(path)>0 THEN current_state:=current_state#-path;
  ELSE RAISE EXCEPTION 'Invalid patch operation';END IF;
 END LOOP;
 IF jsonb_typeof(current_state->'zones') IS DISTINCT FROM 'array' OR jsonb_typeof(current_state->'zoneMarkets') IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Invalid warehouse state';END IF;
 UPDATE public.warehouse_state SET state=current_state,revision=revision+1,updated_at=now() WHERE id=1 RETURNING revision INTO next_revision;
 INSERT INTO public.warehouse_sync_operations_v61(operation_id,revision) SELECT DISTINCT x,next_revision FROM unnest(p_operation_ids) x;
 IF p_upload_id IS NOT NULL THEN DELETE FROM public.warehouse_patch_parts100 WHERE upload_id=p_upload_id;END IF;
 RETURN next_revision;
END $fn$;
REVOKE ALL ON FUNCTION public.get_warehouse_manifest100(text[],bigint),public.get_warehouse_pages100(bigint,text[]),public.save_warehouse_patch100(jsonb,bigint,text[],text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_warehouse_manifest100(text[],bigint),public.get_warehouse_pages100(bigint,text[]),public.save_warehouse_patch100(jsonb,bigint,text[],text) TO anon,authenticated;
DO $init$ DECLARE row record;BEGIN
 SELECT state,revision INTO row FROM public.warehouse_state WHERE id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Warehouse state missing; setup required';END IF;
 PERFORM public.warehouse_materialize100(row.state,row.revision,NULL);
END $init$;
COMMIT;
NOTIFY pgrst,'reload schema';
SELECT revision,(SELECT count(*) FROM jsonb_object_keys(manifest)) AS sections FROM public.warehouse_sync_head100 WHERE id=1;
