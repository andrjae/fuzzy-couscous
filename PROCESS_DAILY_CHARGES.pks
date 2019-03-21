CREATE OR REPLACE PACKAGE PROCESS_DAILY_CHARGES AS
/******************************************************************************
   NAME:       PROCESS_DAILY_CHARGES
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2018.11.21      AndresJaek       1. Created this package.
******************************************************************************/

   c_calculate_mode     CONSTANT VARCHAR2 (10) := 'CALC';
   c_recalculate_mode   CONSTANT VARCHAR2 (10) := 'RECALC';
   c_continue_mode      CONSTANT VARCHAR2 (10) := 'CONTINUE';
   /*
     ** Global constant declarations.
   */
--   c_module_ref         CONSTANT VARCHAR2 (10) := 'BCCU1284';
--   c_module_ref_short   CONSTANT VARCHAR2 (4) := '1284';


   PROCEDURE proc_daily_charges (  --see process_monthly_service_fees.proc_mob_nonker_serv_fees
       p_bill_cycle  IN  VARCHAR2  
      ,p_mode        IN  VARCHAR2 DEFAULT c_calculate_mode   -- CALC/RECALC/CONTINUE
   );

  PROCEDURE calculate_daily_charges (
       p_start_date DATE
      ,p_end_date DATE 
      ,p_maac_ref_num IN NUMBER DEFAULT NULL
      ,p_susg_ref_num IN NUMBER DEFAULT NULL
      ,p_bill_cycle  IN  VARCHAR2 DEFAULT NULL 
   );

   FUNCTION main_query(p_one_susg VARCHAR2 DEFAULT 'N') RETURN CLOB;

END PROCESS_DAILY_CHARGES;

/
