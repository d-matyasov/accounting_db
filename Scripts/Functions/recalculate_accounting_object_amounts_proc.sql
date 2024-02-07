create or replace procedure recalculate_accounting_object_amounts(p_accounting_object_id integer default null::integer, p_range_start_date date default null::date, p_range_start_index_by_date integer default null::integer, p_range_finish_date date default null::date, p_range_finish_index_by_date integer default null::integer)
	language plpgsql
as $procedure$

	declare

		v_accounting_object_ids int[];
		x int;
		v_amount bigint;
		v_range_start_date date;
		v_range_finish_date date;
		v_range_finish_index_by_date integer;
		i record;

	begin

		if p_accounting_object_id is null
			then v_accounting_object_ids = (select
												array_agg(ao.id) 
											from
												accounting_object ao 
											where
												(ao.open_date <= p_range_finish_date or p_range_finish_date is null)
												and (coalesce(ao.close_date, p_range_start_date) >= p_range_start_date or p_range_start_date is null));
			else v_accounting_object_ids = array[p_accounting_object_id];
		end if;
	
		foreach x in array v_accounting_object_ids
		loop
			
			if p_range_start_date is null
				then v_range_start_date = (select ao.open_date from accounting_object ao where ao.id = x);
				else v_range_start_date = p_range_start_date;
			end if;
			
			RAISE NOTICE 'v_accounting_object_ids = %', v_accounting_object_ids;
			
			v_amount = (select accounting_object_amount from (select row_number() over(order by o.date desc, o.index_by_date  desc), o.accounting_object_amount from operation o where o.accounting_object_id = x and (o.date < v_range_start_date or (o.date = v_range_start_date and o.index_by_date < coalesce(p_range_start_index_by_date, 1)))) a where a.row_number = 1);
			
			if v_amount is null
				then v_amount = (select ao.start_amount from accounting_object ao where ao.id = x);
			end if;
		
			if p_range_finish_date is null and p_range_finish_index_by_date is not null
				then
					v_range_finish_date = v_range_start_date;
					v_range_finish_index_by_date = p_range_finish_index_by_date;
			elsif p_range_finish_date is not null and p_range_finish_index_by_date is null
				then
					v_range_finish_date = p_range_finish_date;
					v_range_finish_index_by_date = (select max(index_by_date) from operation where date = p_range_finish_date);
			else
				v_range_finish_date = p_range_finish_date;
				v_range_finish_index_by_date = p_range_finish_index_by_date;
			end if;
			
		
			RAISE NOTICE 'v_amount = %', v_amount;
			
			for i in (
						select
							id
							, amount_plus 
							, amount_minus 
							
							--
							, date, index_by_date
							--
						from
							operation
						where
							accounting_object_id = x
							and (
									(date = v_range_start_date and index_by_date >= coalesce(p_range_start_index_by_date, 1))
									or date > v_range_start_date
								)
							and (
									(v_range_finish_date is null and v_range_finish_index_by_date is null)
									or ((date = v_range_finish_date and index_by_date <= v_range_finish_index_by_date)
										or date < v_range_finish_date)
								)
						order by
							date
							, index_by_date
					)
			loop
				v_amount = v_amount + coalesce(i.amount_plus, 0) - coalesce(i.amount_minus, 0);
				RAISE NOTICE 'id = %, date = %, index_by_date = %, f = %', i.id, i.date, i.index_by_date, v_range_finish_index_by_date;
				update operation set accounting_object_amount = v_amount where id = i.id;
			end loop;
		end loop;

	end;

$procedure$
;