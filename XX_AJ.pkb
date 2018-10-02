CREATE OR REPLACE PACKAGE BODY XX_AJ AS
/******************************************************************************
   NAME:       XX_AJ
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/10/2018      Andres       1. Created this package body.
******************************************************************************/

function get_list_susg (p_start_date DATE, p_end_date DATE, p_min_susg NUMBER, p_max_susg NUMBER)
return t_susg_maac_tab pipelined IS
CURSOR c_acco IS
with q1 as (
select sept.type_code, sept.category
from package_categories paca, serv_package_types sept
where paca.end_date IS NULL
AND sept.CATEGORY = paca.package_category
AND paca.nety_type_code = NVL (sept.nety_type_code, 'GSM')
AND paca.prepaid <> 'Y'
)
select supa.gsm_susg_ref_num susg, TRUNC (supa.suac_ref_num, -3) maac, q1.category, supa.start_date, supa.end_date, supa.sept_type_code--, count(*) over (partition by gsm_susg_ref_num) c 
from subs_packages supa, q1
where 1=1
AND NVL (supa.end_date, p_start_date) >= p_start_date
AND supa.start_date <= p_end_date
AND q1.type_code = supa.sept_type_code
AND supa.gsm_susg_ref_num between p_min_susg AND p_max_susg
;
TYPE t_acco_cur IS table OF c_acco%ROWTYPE;
--l_acco_tab t_acco_cur;
l_acco_row c_acco%ROWTYPE;
BEGIN
    OPEN c_acco;
--    FETCH c_acco BULK COLLECT into l_acco_tab;
--    FOR i in 1 .. l_acco_tab.COUNT LOOP
--        PIPE ROW (l_acco_tab(i));
--    END LOOP;
    LOOP     
      FETCH c_acco INTO l_acco_row;
      EXIT WHEN c_acco%NOTFOUND;
      PIPE ROW (l_acco_row);  
    END LOOP;
    CLOSE c_acco;
END;

function get_list_susg_f (p_start_date DATE, p_end_date DATE, p_min_susg NUMBER, p_max_susg NUMBER, p_bicy VARCHAR2)
return t_susg_maac_tab pipelined IS
CURSOR c_acco_f IS
with q1 as (
select ref_num, count(*) over (partition by ref_num) c 
from accounts where bicy_cycle_code = p_bicy
AND ref_num NOT IN (SELECT TO_NUMBER (value_code) AS large_maac_ref_num
                                                          FROM bcc_domain_values
                                                         WHERE doma_type_code = 'LAMA')
)
select t1.* 
from table(get_list_susg (p_start_date, p_end_date, p_min_susg, p_max_susg)) t1, q1
where t1.maac = q1.ref_num
;
TYPE t_acco_f_cur IS table OF c_acco_f%ROWTYPE;
--l_acco_tab t_acco_cur;
l_acco_f_row c_acco_f%ROWTYPE;
BEGIN
    OPEN c_acco_f;
--    FETCH c_acco BULK COLLECT into l_acco_tab;
--    FOR i in 1 .. l_acco_tab.COUNT LOOP
--        PIPE ROW (l_acco_tab(i));
--    END LOOP;
    LOOP     
      FETCH c_acco_f INTO l_acco_f_row;
      EXIT WHEN c_acco_f%NOTFOUND;
      PIPE ROW (l_acco_f_row);  
    END LOOP;
    CLOSE c_acco_f;
END;

    
END XX_AJ;

/
