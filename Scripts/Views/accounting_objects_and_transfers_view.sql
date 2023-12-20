create or replace view public.accounting_objects_and_transfers_view as 
with q as (
			select
				'{' || ao.id::text || case when ao.id = ao1.id then '' else ',' || ao1.id::text end || '}' id
				, case when false in (ao.is_actual, ao1.is_actual) then false else true end is_actual
				, ao.id accounting_object_id
				, case when ao.id = ao1.id then null else ao1.id end pair_accounting_object_id
				, coalesce(ao.name_short, ao.name) name
				, case when ao.id = ao1.id then null else coalesce(ao1.name_short, ao1.name) end pair_name
			from
				accounting_object ao
			cross join	accounting_object ao1
			)
select
	q.id
	, q.is_actual
	, q.accounting_object_id
	, q.pair_accounting_object_id
	, q.name || case when q.pair_name is null then '' else ' → ' || q.pair_name end name
from
	q q
order by
	q.name, q.pair_name nulls first;