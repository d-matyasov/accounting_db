create or replace function get_operation_as_json_object(p_date_from date default null::date, p_date_to date default null::date, p_id integer default null::integer)
	returns table("row" jsonb, date date, id integer, pair_operation_id integer, index_by_date integer, po_index_by_date integer)
	language plpgsql
as $function$

declare
	
	v_calendar_date_to date;
	v_last_fact_operation_date date;
	v_show_facts_operation_id integer;
	v_facts_json jsonb;

begin
	
	select case when p_date_to is not null then p_date_to else (select max(o.date) from operation o) end into v_calendar_date_to;
	
	if p_date_from is not null
		then call extend_calendar(p_date_from, v_calendar_date_to);
	end if;

	select
		q.date into v_last_fact_operation_date
	from
		(select
				row_number() over (order by o.date desc, o.index_by_date desc)
				, o.id, o.date
		from
				operation o
		where
				o.is_fact = true
		) q
	where
		row_number = 1;

	if p_date_from is not null and v_last_fact_operation_date between p_date_from and coalesce(p_date_to, v_last_fact_operation_date)
		then
			select
				q.id into v_show_facts_operation_id
			from
				(select
					row_number() over (order by o.index_by_date desc)
					, o.id
				from
					operation o
				left join	operation po on po.id = o.pair_operation_id 
				where
					o.date = v_last_fact_operation_date
					and (po.index_by_date > o.index_by_date
						or (o.id is not null and o.pair_operation_id is null)
						)
				) q
			where row_number = 1;
			
			select
				jsonb_object_agg('accountingObject' || ao_id, current_amount) ||
				jsonb_object_agg('sumByCurrency' || c_id, sum) into v_facts_json
			from
				(
				select
					ao.id ao_id
					, ao.current_amount
					, c.id c_id
					, sum(ao.current_amount) over (partition by c.id) sum
				from
					accounting_object ao
				join	currency c on c.id = ao.currency_id 
				where
					v_last_fact_operation_date between ao.open_date and coalesce(ao.close_date, v_last_fact_operation_date)
				) q;
	end if;

    return query
    
		select
			case
				when o.id is not null and po.id is not null
				then
					jsonb_build_object(
						'id', o.id
						, 'pairOperationId', po.id
						, 'month', case when (row_number() over(partition by c.month_short_name order by c.date, o.index_by_date)) = 1 then c.month_short_name else null end
						, 'week', case when (row_number() over(partition by c.week_number order by c.date, o.index_by_date)) = 1 then c.week_number::text else null end
						, 'day', c.day_short_name
						, 'date', c.date
						, 'indexByDate', o.index_by_date
						, 'amountPlus', po.amount_plus
						, 'amountMinus', o.amount_minus
						, 'isFact', coalesce(o.is_fact, false)
						, 'accountingObjectOrTransferId', '{' || o.accounting_object_id || ',' || po.accounting_object_id || '}'
						, 'accountingObjectOrTransferName', aoatv.name
						, 'accountingObject' || o.accounting_object_id::text, o.accounting_object_amount
						, 'accountingObject' || po.accounting_object_id::text, po.accounting_object_amount
						, 'categoryId', o.category_id
						, 'categoryAddon', o.category_addon
						, 'category', oc.name || case when o.category_addon is not null then ' (' || o.category_addon || ')' else '' end
						, 'comment', o.comment
						) ||
						get_sums_json(o.id)
				when o.id is not null and po.id is null
				then
					jsonb_build_object(
						'id', o.id
						, 'month', case when (row_number() over(partition by c.month_short_name order by c.date, o.index_by_date)) = 1 then c.month_short_name else null end
						, 'week', case when (row_number() over(partition by c.week_number order by c.date, o.index_by_date)) = 1 then c.week_number::text else null end
						, 'day', c.day_short_name
						, 'date', c.date
						, 'indexByDate', o.index_by_date
						, 'amountPlus', o.amount_plus
						, 'amountMinus', o.amount_minus
						, 'isFact', coalesce(o.is_fact, false)
						, 'accountingObjectOrTransferId', '{' || o.accounting_object_id || '}'
						, 'accountingObjectOrTransferName', aoatv.name
						, 'accountingObject' || o.accounting_object_id::text, o.accounting_object_amount
						, 'categoryId', o.category_id
						, 'categoryAddon', o.category_addon
						, 'category', oc.name || case when o.category_addon is not null then ' (' || o.category_addon || ')' else '' end
						, 'comment', o.comment
						) ||
						get_sums_json(o.id)
				else 
					jsonb_build_object(
						'month', case when (row_number() over(partition by c.month_short_name order by c.date)) = 1 then c.month_short_name else null end
						, 'week', case when (row_number() over(partition by c.week_number order by c.date)) = 1 then c.week_number::text else null end
						, 'day', c.day_short_name
						, 'date', c.date
						, 'isFact', false
						)
			end row,
			c.date,
			o.id,
			o.pair_operation_id,
			o.index_by_date,
			po.index_by_date as po_index_by_date
		from
			calendar c
		left join operation o on o.date = c.date
		left join operation po on po.id = o.pair_operation_id and po.index_by_date > o.index_by_date
		left join accounting_objects_and_transfers_view aoatv on aoatv.accounting_object_id = o.accounting_object_id and coalesce(aoatv.pair_accounting_object_id, '-1'::integer) = coalesce(po.accounting_object_id, '-1'::integer)
		left join operation_category oc on oc.id = o.category_id
		where
			(
			(o.id is not null and coalesce(o.pair_operation_id, -1) = coalesce(po.id, -1))
			or (o.id is null and c.date >= (
											select
												coalesce(max(o_1.date), (select min(operation.date) as min from operation)) as "coalesce"
											from
												operation o_1
											where
												o_1.is_fact = true
												and not exists (select 1 from operation o1 where o1.date < o_1.date and o1.is_fact = false)
											)
				)
			)
			and ((case when p_date_from is null then 1 else 0 end) = 1 or c.date >= p_date_from)
			and ((case when p_date_to is null then 1 else 0 end) = 1 or c.date <= p_date_to)
			and ((case when p_id is null then 1 else 0 end) = 1 or o.id = p_id)
		
		union all
		
		select
			json_build_object(
				'date', o.date
				, 'indexByDate', case when o.pair_operation_id is null then o.index_by_date + 1 else o.index_by_date + 2 end
				, 'isFact', true
				, 'isFactsRow', true
				)::jsonb ||
				v_facts_json row,
			o.date,
			null id,
			null pair_operation_id,
			case when o.pair_operation_id is null then o.index_by_date + 1 else o.index_by_date + 2 end index_by_date,
			null po_index_by_date
		from
			operation o
		where 
			o.id = v_show_facts_operation_id
			and v_facts_json is not null
		;
end; 

$function$
;