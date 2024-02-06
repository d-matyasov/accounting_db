create or replace function get_nearby_id(p_id integer, p_direction integer)
 returns integer
 language plpgsql
as $function$

    declare

    	v_date date;
    	v_index_by_date integer;
    	v_sort_direction text;
    	v_comparison_sign text;
        q text;
        result integer;
       
    begin
	    
	    if p_direction not in (-1, 1)
			then raise exception 'Параметр p_direction должен быть одним из: -1, 1 (предыдущая или следующая соответственно).';
		end if;
	    
	    v_date = (select date from operation where id = p_id);
	   	v_index_by_date = (select index_by_date from operation where id = p_id);
	    
	   	if p_direction = -1
	   	then
	   		v_sort_direction = 'desc';
	   		v_comparison_sign = '<';
	   	elsif p_direction = 1
	   	then
	   		v_sort_direction = 'asc';
	   		v_comparison_sign = '>';
	   	end if;
	   
    	q = 'select id from (
				select
					row_number() over(order by o.date %sort_direction%, index_by_date %sort_direction%)
					, o.id
				from 
					operation o 
				where
					((o.date %comparison_sign% $1
						or (o.date = $1 and o.index_by_date %comparison_sign% $2))
					)
					and (o.pair_operation_id is null
						or o.pair_operation_id not in (select o1.id from operation o1 where o1.date = $1 and o1.index_by_date = $2)
					)
					and not exists (select 1 from operation o1 where o1.id = o.pair_operation_id and o1.index_by_date < o.index_by_date)
				) q
			where
				row_number = 1';
		
		q = replace(q, '%sort_direction%', v_sort_direction);
		q = replace(q, '%comparison_sign%', v_comparison_sign);
    
		execute q using v_date, v_index_by_date into result;
	    return result;
	   
    end;
   
$function$
;