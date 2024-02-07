create or replace function get_sums_json(p_id integer)
	returns jsonb
	language plpgsql
as $function$

	declare

		v_date date;
		v_index_by_date integer;
		result jsonb;

	begin
		
		select max(o.date), max(o.index_by_date) into v_date, v_index_by_date from operation o where p_id in (o.id, o.pair_operation_id);
		
		select 
			jsonb_object_agg(param_name, sum) into result
		from (
			select
				'sumByCurrency' || id param_name
				, sum(amount) sum
			from
				(
				select
					rank() over (partition by ao.id order by o.date desc, o.index_by_date desc) rank
					, c.id 
					, case when o.accounting_object_amount is null then ao.start_amount else o.accounting_object_amount end amount
				from
					accounting_object ao 
				join	currency c on c.id = ao.currency_id 
				left join operation o on o.accounting_object_id = ao.id and (o.date < v_date or (o.date = v_date and o.index_by_date <= v_index_by_date))
				where 
					v_date between ao.open_date and coalesce(ao.close_date, v_date)
				) q
			where
				rank = 1
			group by
				id
			) q;
		
		return result;
		
	end;
	
$function$
;