create or replace procedure shift(p_id integer, p_direction integer)
 language plpgsql
as $procedure$

	declare 

		i record;
    	v_date date;
    	v_index_by_date integer;
    	v_pair_operation_id integer;
    	v_sort_direction text;
    	v_comparison_sign text;
        q text;
		v_nearby_id integer;
		v_nearby_date date;
		v_initial_date date;
		v_initial_index_by_date integer;
		v_start_from integer;
		v_shift_size integer;
		
    begin
	    
	    if p_direction not in (-1, 1)
			then raise exception 'Параметр p_direction должен быть одним из: -1, 1 (вверх или вниз соответственно).';
		end if;
	    
		select date, index_by_date, pair_operation_id into v_date, v_index_by_date, v_pair_operation_id from operation where id = p_id;
	
	   	if p_direction = -1
	   	then
	   		v_sort_direction = 'desc';
	   		v_comparison_sign = '<';
	   	elsif p_direction = 1
	   	then
	   		v_sort_direction = 'asc';
	   		v_comparison_sign = '>';
	   	end if;

	       	q = 'select
					id
					, date
				from (
					select
						row_number() over (order by o.date %sort_direction%, o.index_by_date  %sort_direction%)
						, o.id
						, o.date
					from
						operation_as_json_object_view o
					where
						o.date %comparison_sign% $1
						or (o.date = $1 and o.index_by_date %comparison_sign% $2)
					) q
				where row_number = 1';
		
		q = replace(q, '%sort_direction%', v_sort_direction);
		q = replace(q, '%comparison_sign%', v_comparison_sign);
    
		execute q using v_date, v_index_by_date into v_nearby_id, v_nearby_date;
	

	   
		--Если смежная дата не содержит операцию:
		--  если сдвиг вверх, то запомнить дату сдвигаемой операции;
		--	в сдвигаемой операции установить смежную дату и индексы 1 /2/;
		--	если сдвиг вверх, то пересчитать все индексы для даты: дата сдвигаемой операции до пересчёта;

		if v_nearby_id is null and v_nearby_date is not null
			then 
			
				if p_direction = -1 then v_initial_date = v_date; end if;
				
				update operation set date = v_nearby_date, index_by_date = 1 where id = p_id;
				update operation set date = v_nearby_date, index_by_date = 2 where pair_operation_id = p_id;
				
				if p_direction = -1 then call recalculate_indexes_by_date(v_initial_date); end if;

		--иначе, если есть смежная операция:
		--	создать дырку: дата - из смежной операции, индекс - если сдвиг вверх, то минимальный из смежной операции, иначе максимальный из смежной операции + 1, размер - если сдвигаемая операция не парная, то 1, иначе 2;
		--	запомнить дату и индекс сдвигаемой операции до пересчёта дат и индексов в ней, пересчитать даты и индексы в сдвигаемой операции /сдвигаемой парной операции/: дата и индекс - те же, что при создании дырки, /дата - та же, что при создании дырки, индекс - тот, что при создании дырки + 1/;
		--	если сдвиг вверх и дата сдвигаемой операции до пересчёта отличается от даты смежной операции, то пересчитать индексы для даты: дата сдвигаемой операции до пересчёта;
		--	если дата сдвигаемой операции до пересчёта совпадает с датой смежной операции, то пересчитать индексы: дата сдвигаемой операции до пересчёта, начальный индекс <индекс сдвигаемой операции до пересчёта>;
		--	если в сдвигаемой операции и в смежной операции есть совпадающие объекты учёта, то по соответствюущим записям пересчитать суммы объектов учёта.
			
		elsif v_nearby_id is not null
			then
				
				v_start_from = (select case when p_direction = -1 then min(index_by_date) else max(index_by_date) + 1 end from operation where id = v_nearby_id or pair_operation_id = v_nearby_id);
				v_shift_size = (select case when v_pair_operation_id is null then 1 else 2 end);
				call recalculate_indexes_by_date(v_nearby_date, v_start_from, v_shift_size);
				
				select date, index_by_date into v_initial_date, v_initial_index_by_date from operation where id = p_id;
				
				update operation set date = v_nearby_date, index_by_date = v_start_from where id = p_id;
				update operation set date = v_nearby_date, index_by_date = v_start_from + 1 where pair_operation_id = p_id;
			
				if p_direction = -1 and v_initial_date != v_nearby_date then call recalculate_indexes_by_date(v_initial_date); end if;
				if v_initial_date = v_nearby_date then call recalculate_indexes_by_date(v_initial_date, v_initial_index_by_date); end if;
			
				for i in (
							select
								o.accounting_object_id
								, o.date range_start_date
								, o.index_by_date range_start_index_by_date
								, o1.date range_finish_date
								, o1.index_by_date range_finish_index_by_date
							from
								operation o
							join	operation o1 on o1.accounting_object_id = o.accounting_object_id 
							where
								p_id in (o.id, o.pair_operation_id)
								and v_nearby_id in (o1.id, o1.pair_operation_id)
						 )
				 loop 
				 	call recalculate_accounting_object_amounts(i.accounting_object_id, i.range_start_date, i.range_start_index_by_date, i.range_finish_date, i.range_finish_index_by_date);
				 end loop;
				 
		end if;

    end;

$procedure$
;