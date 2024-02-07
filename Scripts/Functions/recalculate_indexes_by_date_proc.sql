create or replace procedure recalculate_indexes_by_date(p_date date, p_start_from integer default null::integer, p_shift_size integer default null::integer)
	language plpgsql
as $procedure$

	declare 
		
		i record;
		v_max_index_by_date integer;
		v_start_from integer;
		v_shift_size integer;
		v_temporary_shift integer;
		
begin
	
	if p_start_from is null
		then v_start_from = 1;
		else v_start_from = p_start_from;
	end if;
	
	if p_start_from < 1
			then raise exception 'Параметр p_start_from должен быть больше нуля.';
		end if;
	
	if p_shift_size is null
		then v_shift_size = 0;
		else v_shift_size = p_shift_size;
	end if;
	
	if p_shift_size < 0
		then raise exception 'Параметр p_shift_size должен быть больше или равен нулю';
	end if;

	v_max_index_by_date = (select coalesce(max(index_by_date), 0) from operation where date = p_date);

	v_temporary_shift = v_start_from + v_shift_size + v_max_index_by_date;
	
	for i in
			select
				(row_number() over(order by index_by_date)) + v_temporary_shift - 1 temporary_index_by_date
				, id

				--f
				,index_by_date
				--f
			
			from
				operation
			where
				date = p_date
				and index_by_date >= v_start_from
			order by
				index_by_date
	loop

		update operation set index_by_date = i.temporary_index_by_date where id = i.id;

	end loop;
	
		update operation set index_by_date = index_by_date - v_max_index_by_date where date = p_date and index_by_date >= v_temporary_shift;
	
end;

$procedure$
;