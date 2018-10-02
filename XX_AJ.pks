CREATE OR REPLACE PACKAGE XX_AJ AS
/******************************************************************************
   NAME:       XX_AJ
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/10/2018      Andres       1. Created this package.
******************************************************************************/

TYPE t_susg_maac IS RECORD (
susg TBCIS.SUBS_SERV_GROUPS.REF_NUM%TYPE,
maac TBCIS.ACCOUNTS.REF_NUM%TYPE,
cat TBCIS.SERV_PACKAGE_TYPES.CATEGORY%TYPE,
start_date DATE,
end_date DATE,
sept_type_code TBCIS.SERV_PACKAGE_TYPES.TYPE_CODE%TYPE
);
TYPE t_susg_maac_tab is TABLE OF t_susg_maac;
function get_list_susg (p_start_date DATE, p_end_date DATE, p_min_susg NUMBER, p_max_susg NUMBER)
return t_susg_maac_tab pipelined;
function get_list_susg_f (p_start_date DATE, p_end_date DATE, p_min_susg NUMBER, p_max_susg NUMBER, p_bicy VARCHAR2)
return t_susg_maac_tab pipelined;
END XX_AJ;

/
