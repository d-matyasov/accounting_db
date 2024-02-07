create or replace function get_facts_row_as_json_object(p_date_from date default null::date, p_date_to date default null::date)
	returns table("row" jsonb, date date, id integer, pair_operation_id integer, index_by_date integer, po_index_by_date integer)
	language plpgsql
as $function$

	declare
		
		v_last_fact_operation_date date;
		v_show_facts_operation_id integer;
		v_facts_json jsonb;
	
	begin
	
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
	
		if (v_last_fact_operation_date between coalesce(p_date_from, v_last_fact_operation_date) and coalesce(p_date_to, v_last_fact_operation_date))
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
				json_build_object(
					'date', o.date
					, 'indexByDate', case when o.pair_operation_id is null then o.index_by_date + 1 else o.index_by_date + 2 end
					, 'isFact', true
					, 'isFactsRow', true
					, 'showFactsOperationId', v_show_facts_operation_id
					)::jsonb ||
					v_facts_json row,
				o.date,
				null::integer id,
				null::integer pair_operation_id,
				case when o.pair_operation_id is null then o.index_by_date + 1 else o.index_by_date + 2 end index_by_date,
				null::integer po_index_by_date
			from
				operation o
			where 
				o.id = v_show_facts_operation_id;

	end;

$function$
;