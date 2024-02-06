create or replace procedure change_ids(p_current_id integer, p_id integer, p_pair_operation_id integer)
 language plpgsql
as $procedure$

	declare 
		
		v_current_pair_operation_id integer;
    
	begin
		
	    v_current_pair_operation_id = (select pair_operation_id from operation where id = p_current_id);
	    
	    update operation set pair_operation_id = null where id = v_current_pair_operation_id;
	    
	    update operation set id = p_id where id = p_current_id;
	   
	    update operation set pair_operation_id = p_id where id = v_current_pair_operation_id;
	    
	    if p_pair_operation_id is not null
	    
	    then
	    	
	    	update operation set pair_operation_id = null where id = p_id;
    	    
	    	update operation set id = p_pair_operation_id where id = v_current_pair_operation_id;
	    
	    	update operation set pair_operation_id = p_pair_operation_id where id = p_id;
	    
	    end if;
	  
    end;
   
$procedure$
;