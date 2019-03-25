CREATE OR REPLACE PACKAGE TBCIS.PROCESS_DAILY_CHARGES AS
/******************************************************************************
   **  Module      :  BCCU1545
   **  Module Name : PROCESS_DAILY_CHARGES
   **  Date Created:  05.02.2019
   **  Author      :  A.Jaek
   **  Description :  Pakett sisaldab protseduure DCH tüüpi
   **                 teenuse kuumaksude leidmiseks.
   **

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2019.02.05      AndresJaek       1. Created this package body.
******************************************************************************/
   c_calculate_mode CONSTANT  VARCHAR2(4) := 'CALC';
   c_proc_module_ref    CONSTANT VARCHAR2 (10) := '1545';
   c_module_ref    CONSTANT VARCHAR2 (10) := 'BCCU1545';
  
  PROCEDURE proc_daily_charges (  --see process_monthly_service_fees.proc_mob_nonker_serv_fees
       p_bill_cycle  IN  VARCHAR2 DEFAULT NULL
      ,p_mode        IN  VARCHAR2 DEFAULT c_calculate_mode   -- CALC/RECALC/CONTINUE
   );
   
  PROCEDURE proc_daily_charges_ma (
       p_maac_ref_num  IN      accounts.ref_num%TYPE
      ,p_invo_ref_num  IN      invoices.ref_num%TYPE
      ,p_period_start  IN      DATE
      ,p_period_end    IN      DATE
      ,p_success       OUT     BOOLEAN
      ,p_error_text    OUT     VARCHAR2
      ,p_susg_ref_num  IN      subs_serv_groups.ref_num%TYPE DEFAULT NULL
      ,p_interim       IN      BOOLEAN DEFAULT FALSE
   );
   
  
   FUNCTION main_query(p_one_susg VARCHAR2 DEFAULT 'N') RETURN CLOB;
        
   PROCEDURE calculate_daily_charges (
       p_start_date DATE
      ,p_end_date DATE 
      ,p_maac_ref_num IN NUMBER DEFAULT NULL
      ,p_susg_ref_num IN NUMBER DEFAULT NULL
      ,p_interim IN BOOLEAN DEFAULT FALSE 
      ,p_bill_cycle  IN  VARCHAR2 DEFAULT NULL 
   );

   PROCEDURE clean_obsolete_invoice_entries(p_start_date IN DATE, p_bill_cycle IN VARCHAR2);
END PROCESS_DAILY_CHARGES;
/

CREATE OR REPLACE PACKAGE BODY TBCIS.PROCESS_DAILY_CHARGES AS
/******************************************************************************
   NAME:       PROCESS_DAILY_CHARGES
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  -------------------------------------------------------------------------------------
   1.0        2018.11.21      AndresJaek       Created this package body.
   1.1        2019.03.18      AndresJaek       DOBAS-1932 fixes not creating invoices while running parallel with other  invoice
                                               creating procedures              
*******************************************************************************************************************************/

  
   FUNCTION main_query(p_one_susg VARCHAR2 DEFAULT 'N') RETURN CLOB IS
   l_clob CLOB;
   
   BEGIN
        l_clob := 
        q'[BEGIN
        insert into daily_charges_descr_]' || case p_one_susg when 'Y' then 's_' end || q'[temp
        with t1 as (
        select sept.type_code, sept.description, sept.category
        from package_categories paca, serv_package_types sept
        where paca.end_date IS NULL
        AND sept.CATEGORY = paca.package_category
        AND paca.nety_type_code = NVL (sept.nety_type_code, 'GSM')
        AND paca.prepaid <> 'Y'
        ), t as (
        select supa.gsm_susg_ref_num susg, TRUNC (supa.suac_ref_num, -3) maac, t1.category, supa.sept_type_code, t1.description sept_description, 
        greatest(nvl(trunc(supa.start_date), :1), :1) supa_start_date, 
        least(
        nvl(trunc(supa.end_date), :2), 
        :2, 
        nvl(trunc(lead(supa.start_date) over (partition by supa.gsm_susg_ref_num order by supa.start_date, supa.end_date nulls last)) - 1, :2)
        ) supa_end_date
        from subs_packages supa JOIN t1 on to_char(supa.sept_type_code) = to_char(t1.type_code) 
        where 1=1
        AND TRUNC (supa.suac_ref_num, -3) not IN (SELECT TO_NUMBER (value_code) AS large_maac_ref_num
                                                                  FROM bcc_domain_values
                                                                 WHERE doma_type_code = 'LAMA')
        AND NVL (supa.end_date, :1) >= :1
        AND supa.start_date < :2 + 1
        ), q4 as (
        select /*+ NO_INDEX(stpe stpe_di1 stpe_di2) NO_PARALLEL */ susg_ref_num susg, sety_ref_num, start_date real_stpe_start, end_date real_stpe_end,
        greatest(nvl(trunc(stpe.start_date), :1), :1) stpe_start_date, 
        least(
        nvl(trunc(stpe.end_date), :2), 
        :2, 
        nvl(trunc(lead(stpe.start_date) over (partition by stpe.susg_ref_num, stpe.sety_ref_num order by stpe.start_date, stpe.end_date nulls last)) - 1, :2)
        ) stpe_end_date
        from status_periods stpe
        where NVL (stpe.end_date, :1) >= :1
        AND stpe.start_date < :2 + 1
        AND stpe.sety_ref_num = :3]' ||
        CASE p_one_susg when 'Y' then ' and (stpe.susg_ref_num = :5)' else '' end || q'[
        ), q5 as (
        select * from (
        select /*+ NO_INDEX(ssst ssst_di2 ssst_di3 ssst_di5 ssst_di6)  */ susg_ref_num susg, start_date real_ssst_start, end_date real_ssst_end, status_code,
        greatest(nvl(trunc(ssst.start_date), :1), :1) ssst_start_date, 
        least(
        nvl(trunc(ssst.end_date), :2), 
        :2, 
        nvl(trunc(lead(ssst.start_date) over (partition by ssst.susg_ref_num, ssst.status_code order by ssst.start_date, ssst.end_date nulls last)) - 1, :2)
        ) ssst_end_date,
        lead(ssst.status_code) over (partition by ssst.susg_ref_num order by ssst.start_date, ssst.end_date nulls last) next_status,
        lag(ssst.status_code) over (partition by ssst.susg_ref_num order by ssst.start_date, ssst.end_date nulls last) prev_status
        from ssg_statuses ssst
        where  1=1
        AND NVL (ssst.end_date, :1) >= :1-1
        AND ssst.start_date < :2 + 2 ]' || 
        CASE p_one_susg when 'Y' then ' and (ssst.susg_ref_num = :5)' else '' end || q'[
        )
        where  1=1
        AND NVL (real_ssst_end, :1+1) > :1 + 12/24
        AND real_ssst_start < :2 + 1
        and status_code = 'AC'
        and NOT (
        next_status is not null and prev_status is not null 
        and (nvl(real_ssst_end, :2)-nvl(real_ssst_start,:1)<24/24 and trunc(real_ssst_end)-trunc(real_ssst_start)!=0 OR nvl(real_ssst_end, :2)-nvl(real_ssst_start,:1)<12/24)
        )
        ), q6 as (
        select ]' || CASE nvl(p_one_susg, 'N') when 'N' then '/*+ NO_INDEX (susp susp_sk1 susp_sk2 susp_i1) */ ' else '' end || 
        q'[susp.susg_ref_num susg, susp.sety_ref_num, susp.start_date real_susp_start, susp.end_date real_susp_end, susp.sepa_ref_num, susp.sepv_ref_num, 
        greatest(nvl(trunc(susp.start_date), :1), :1) susp_start_date, 
        least(
        nvl(trunc(susp.end_date), :2), 
        :2, 
        nvl(trunc(lead(susp.start_date) over (partition by susp.susg_ref_num, susp.sety_ref_num order by susp.start_date, susp.end_date nulls last)) - 1, :2)
        ) susp_end_date
        from subs_service_parameters susp
        where  1=1
        AND NVL (susp.end_date, :1) >= :1
        AND susp.start_date < :2 + 1
        AND susp.sety_ref_num = :3]' ||
        CASE p_one_susg when 'Y' then ' and (susp.susg_ref_num = :5)' else '' end || q'[
        ), discless as (
        select greatest(supa_start_date, stpe_start_date, susp_start_date, ssst_start_date) starts, 
        least(supa_end_date, stpe_end_date, susp_end_date, ssst_end_date) ends,
        t.maac, t.susg, t.sept_type_code, t.sept_description, nvl(ficv.fcit_billing_selector, fcit.billing_selector) fcit_billing_selector, nvl(ficv.fcit_type_code, fcit.type_code) fcit_type_code,
        nvl(ficv.fcit_taty_type_code, fcit.taty_type_code) fcit_taty_type_code, nvl(ficv.curr_code, prli.curr_code) curr_code, 
        nvl(ficv.fcit_desc, fcit.description) fcit_desc, nvl(ficv.fcit_fcdt_type_code, fcit.fcdt_type_code) fcit_fcdt_type_code, q6.real_susp_start sepv_start_real, q4.sety_ref_num,
        nvl(prli.charge_value,0) prli_charge_value, ficv.charge_value ficv_charge_value, coalesce(ficv.charge_value, prli.charge_value, 0) charge_value, q6.sepv_ref_num,
        case when ficv.charge_value is null then 'Põhihind' else 'Erihind' end price_type
        from t JOIN q4 ON to_char(t.susg)=to_char(q4.susg)
               JOIN q5 ON to_char(t.susg)=to_char(q5.susg)
               JOIN q6 ON to_char(t.susg)=to_char(q6.susg)
          LEFT JOIN (
                  select ficv.sepv_ref_num, ficv.sepa_ref_num,ficv.sept_type_code, ficv.sety_ref_num, ficv.charge_value,--ficv.*, 
                  fcit.description fcit_desc, fcit.type_code fcit_type_code, fcit.billing_selector fcit_billing_selector, 
                  fcit.fcdt_type_code fcit_fcdt_type_code, fcit.taty_type_code fcit_taty_type_code, ficv.curr_code 
                  from fixed_charge_values ficv, fixed_charge_item_types fcit
                  WHERE NVL (ficv.end_date, :1) >= :1
                  AND ficv.start_date < :2 + 1
                  and ficv.FCIT_CHARGE_CODE = fcit.TYPE_CODE
                  and fcit.regular_charge='Y' and fcit.ONCE_OFF='N' and nvl(fcit.daily_charge, 'N')='Y'
                  ) ficv ON ficv.sety_ref_num = q4.sety_ref_num AND ficv.sept_type_code = t.sept_type_code AND ficv.sepa_ref_num = q6.sepa_Ref_num and ficv.sepv_ref_num = q6.sepv_ref_num 
          LEFT JOIN (
                  select /*+ NO_INDEX (prli) */ * from price_lists prli 
                  WHERE NVL (prli.end_date, :1) >= :1
                  AND prli.start_date < :2 + 1
                  ) prli ON prli.sety_ref_num = q4.sety_ref_num AND nvl(prli.package_category, t.category) = t.category AND prli.fcty_type_code='DCH' 
                         AND prli.sepa_ref_num = q6.sepa_Ref_num and prli.sepv_ref_num = q6.sepv_ref_num
          LEFT JOIN fixed_charge_item_types fcit ON fcit.sety_ref_num = q4.sety_ref_num AND fcit.package_category = t.category
                     and fcit.regular_charge='Y' and fcit.ONCE_OFF='N' and nvl(fcit.daily_charge, 'N')='Y'  
        where susp_start_date<=susp_end_date
        and supa_start_date<=supa_end_date
        and stpe_start_date<=stpe_end_date
        and ssst_start_date<=ssst_end_date
        and (ssst_start_date <= supa_end_date AND ssst_end_date >= supa_start_date)  
        and (susp_start_date <= supa_end_date AND susp_end_date >= supa_start_date)  
        and (stpe_start_date <= supa_end_date AND stpe_end_date >= supa_start_date)  
        and (stpe_start_date <= susp_end_date AND stpe_end_date >= susp_start_date)  
        and (stpe_start_date <= ssst_end_date AND stpe_end_date >= ssst_start_date)  
        and (susp_start_date <= ssst_end_date AND susp_end_date >= ssst_start_date)  
        --and coalesce(ficv.charge_value, prli.charge_value, 0) != 0
        and q4.sety_ref_num = q6.sety_ref_num]' ||
        CASE p_one_susg when 'Y' then ' and (t.susg = :5)' else '' end || q'[
        ), ftco0 as (
        select ftco.ref_num ftco_ref_num, ftco.sept_type_code ftco_sept_type_code, ftco.mixed_packet_code, ftco.susg_ref_num, ftco.ebs_order_number, ftco.sept_type_code, 
        greatest(nvl(ftco.start_date, :1), :1) start_date_c, ftco.end_date, ftco.date_closed, 
        trunc(least(coalesce(date_closed, end_date, :2),coalesce(end_date, :2), :2)) end_date_c
        from fixed_term_contracts ftco]' ||
        CASE p_one_susg when 'Y' then ' where (ftco.susg_ref_num = :5)' else '' end || q'[
        ), ftco1 as (
        select ftco0.ftco_ref_num, ftco0.susg_ref_num, ftco_sept_type_code,  
        lead(start_date_c) over (partition by susg_ref_num order by start_date_c, end_date_c) next_start_date,  
        lag(end_date_c) over (partition by susg_ref_num order by end_date_c, start_date_c) prev_end_date,
        start_date_c,
        least(end_date_c, nvl(lead(start_date_c) over (partition by susg_ref_num order by start_date_c, end_date_c) - 1, end_date_c), :2) end_date_c ,
        mips.monthly_disc_rate, mips.monthly_markdown, mipa.packet_code, mipa.packet_description
        from ftco0
        , mixed_packet_orders  mipo
        , mixed_order_services mose
        , mixed_packets mipa
        , mixed_packet_services mips
        , service_types sety
        where 1=1
        and mose.sety_ref_num = sety.ref_num
        and ftco0.mixed_packet_code = mipa.packet_code
        and mose.mips_ref_num = mips.ref_num
        and mose.sety_ref_num = :3
        AND ftco0.mixed_packet_code = mipo.mixed_packet_code
        AND ftco0.ebs_order_number = mipo.ebs_order_number
        AND Nvl(mipo.term_request_type, '*') <> 'NULLIFY'
        AND mose.mipo_ref_num = mipo.ref_num
        AND (mips.monthly_disc_rate is not null or mips.MONTHLY_MARKDOWN is not null)
        AND ftco0.start_date_c <  :2+1
        and     ftco0.end_date_c >= :1
        and     ftco0.end_date_c >= ftco0.start_date_c
        ), ftco_disc as (
        select ftco_ref_num, susg_ref_num, ftco_sept_type_code, start_date_c mipo_start_date, end_date_c mipo_end_date, 1 discounted, monthly_disc_rate, monthly_markdown, packet_code, packet_description
        from ftco1
        union all
        select ftco_ref_num, susg_ref_num, ftco_sept_type_code, end_date_c + 1 mipo_start_date, nvl(next_start_date - 1 , :2) mipo_end_date, 0 discounted, null, null, null, null
        from ftco1
        where end_date_c < :2
        and nvl(next_start_date - 1 , :2) >=  end_date_c + 1
        union all
        select ftco_ref_num, susg_ref_num, ftco_sept_type_code, :1 mipo_start_date, start_date_c-1 mipo_end_date, 0 discounted, null, null, null, null
        from ftco1
        where start_date_c > :1
        and prev_end_date is null
        ), qa1 as (
        select t.STARTS t_starts, t.ENDS t_ends, greatest(t.starts, nvl(mipo_start_date, :1)) starts, least(t.ends, nvl(mipo_end_date, :2)) ends,
              t.MAAC, t.SUSG, t.SEPT_TYPE_CODE, t.SEPT_DESCRIPTION, FCIT_BILLING_SELECTOR, FCIT_TYPE_CODE, FCIT_TATY_TYPE_CODE, CURR_CODE, FCIT_DESC, FCIT_FCDT_TYPE_CODE, SEPV_START_REAL, 
              SETY_REF_NUM, PRLI_CHARGE_VALUE, FICV_CHARGE_VALUE, CHARGE_VALUE, SEPV_REF_NUM, PRICE_TYPE, ftco_disc.FTCO_REF_NUM, SUSG_REF_NUM, FTCO_SEPT_TYPE_CODE, MIPO_START_DATE, MIPO_END_DATE, DISCOUNTED, 
              MONTHLY_DISC_RATE, MONTHLY_MARKDOWN, PACKET_CODE, PACKET_DESCRIPTION
        from discless t
        LEFT JOIN ftco_disc ON ftco_disc.susg_ref_num = t.susg  and ftco_disc.ftco_sept_type_code = t.sept_type_code
        where 1=1
        and (starts <= nvl(mipo_end_date, :2) AND ends >= nvl(mipo_start_date, :1))
        ), q01 as (
        select greatest(cadc.start_date, :1) discall_start
        ,least(cadc.end_date, :2) discall_end
        ,cadc.ref_num, cadc.precentage, cadc.count_for_months, cadc.count_for_days, cadc.discount_code, cadc.description, cadc.disc_billing_selector, cadc.pricing, cadc.minimum_price, 
        cadc.for_fcit_type_code, cadc.for_billing_selector, cadc.for_sepv_ref_num, cadc.for_sety_ref_num,  cadc.crm, cadc.mixed_service
        from  call_discount_codes cadc, discount_codes dico
        WHERE cadc.dico_ref_num = dico.ref_num 
        and cadc.call_type = 'REGU'
        and NVL (cadc.end_date, :1) >= :1
        and cadc.start_date < :2 + 1
        and NVL (cadc.discount_completed, 'N') <> 'Y'
        AND dico.manual = 'Y'
        and dico.for_all = 'Y'
        ), q1 as (
        select greatest(sudi.start_date, cadc.cadc_start_date, :1) disc_start
        ,least (
        nvl(trunc(sudi.end_date), 
            case when cadc.count_for_months is not null or cadc.count_for_days is not null then ADD_MONTHS(sudi.start_date, NVL(cadc.count_for_months,0))+NVL(cadc.count_for_days,0) else  :2 end)
        ,:2) disc_end    
        ,sudi.start_date, sudi.end_date, cadc_start_date, cadc_end_date    
        ,cadc.ref_num, cadc.precentage, cadc.count_for_months, cadc.count_for_days, cadc.discount_code, cadc.description, cadc.disc_billing_selector, cadc.pricing, cadc.minimum_price, 
        cadc.for_fcit_type_code, cadc.for_billing_selector, cadc.for_sepv_ref_num, cadc.for_sety_ref_num,  cadc.crm, cadc.mixed_service,
        sudi.ref_num sudi_ref_num, sudi.SUSG_REF_NUM, sudi.START_DATE sudi_start_date, padi.DISC_PERCENTAGE, padi.DISC_ABSOLUTE, padi.PRICE, padi.padi_ref_num
        from (
        select greatest(nvl(cadc.start_date, :1), :1) cadc_start_date,
        least(nvl(trunc(cadc.end_date), :2), :2) cadc_end_date,  
        cadc.ref_num, cadc.precentage, cadc.count_for_months, cadc.count_for_days, cadc.discount_code, cadc.description, cadc.disc_billing_selector, cadc.pricing, cadc.minimum_price, 
        cadc.for_fcit_type_code, cadc.for_billing_selector, cadc.for_sepv_ref_num, cadc.for_sety_ref_num, cadc.dico_ref_num, cadc.mixed_service, cadc.crm
        from  call_discount_codes cadc, discount_codes dico 
        where cadc.call_type = 'REGU'
        and cadc.dico_ref_num = dico.ref_num
        and NVL (cadc.end_date, :1) >= :1
        and cadc.start_date < :2 + 1
        and NVL (cadc.discount_completed, 'N') <> 'Y'
        and dico.for_all = 'N'
        ) cadc
        join subs_discounts sudi ON sudi.cadc_ref_num IS NULL AND (NVL (sudi.closed, 'N') <> 'Y' OR sudi.date_updated >= :2 + 1)  
                                                      and cadc.dico_ref_num = sudi.dico_ref_num   
                                                      and NVL (sudi.end_date, :1) >= :1
                                                      and sudi.start_date < :2 + 1
                                    AND (NVL(sudi.end_date,ADD_MONTHS (sudi.start_date, NVL (cadc.count_for_months, 0))
                                          + NVL (cadc.count_for_days, 0)) >= :1
                                          OR (cadc.count_for_days IS NULL AND cadc.count_for_months IS NULL)
                                        )  
                                    and (sudi.padi_ref_num is null OR (sudi.padi_ref_num is not null AND exists (select 1 from part_dico_details padd 
                                                                                     where PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                                                     and padd.cadc_ref_num = cadc.ref_num) ))]' ||
        CASE p_one_susg when 'Y' then ' and (sudi.susg_ref_num = :5)' else '' end || q'[
        left join part_dico_details padi ON PADI.PADI_REF_NUM = sudi.padi_ref_num
                                                           and padi.cadc_ref_num = cadc.ref_num
        ), qq1 as (
        select case when (starts <= nvl(disc_end, :2) AND ends >= nvl(disc_start, :1)) 
                     --and (starts <= nvl(mipo_end_date, :2) AND ends >= nvl(mipo_start_date, :1))
                     then 1 else 0 end discountable,
        case when sudi_ref_num is null OR nvl(discounted, 0) = 1 then 0 else 1 end discounts_available,
        qa1.T_STARTS, qa1.T_ENDS, qa1.STARTS, qa1.ENDS, 
        qa1.maac, qa1.susg, qa1.fcit_billing_selector, bcdv1.description fcit_bise, qa1.fcit_type_code, qa1.fcit_taty_type_code, qa1.fcit_desc, qa1.fcit_fcdt_type_code, qa1.sepv_start_real, 
        qa1.sety_ref_num, qa1.prli_charge_value, qa1.ficv_charge_value, qa1.charge_value, qa1.curr_code, qa1.sept_type_code, qa1.sept_description, qa1.sepv_ref_num, qa1.price_type,
        case when q01.ref_num is null then q1.DISC_START else q01.discall_start end disc_start, case when q01.ref_num is null then q1.DISC_END else q01.discall_end end disc_end, 
        nvl(q01.ref_num, q1.REF_NUM) cadc_ref_num, case when q01.ref_num is null then q1.PRECENTAGE else q01.precentage end precentage, 
        case when q01.ref_num is null then q1.COUNT_FOR_MONTHS else q01.count_for_months end count_for_months, 
        case when q01.ref_num is null then q1.COUNT_FOR_DAYS else q01.count_for_days end count_for_days, 
        case when q01.ref_num is null then q1.DESCRIPTION else q01.description end disc_descr, case when q01.ref_num is null then q1.DISCOUNT_CODE else q01.discount_code end discount_code,
        case when q01.ref_num is null then q1.DISC_BILLING_SELECTOR else q01.disc_billing_selector end  DISC_BILLING_SELECTOR, 
        case when q01.ref_num is null then bcdv2.description else bcdv3.description end disc_bise, 
        case when q01.ref_num is null then q1.pricing else q01.pricing end PRICING, case when q01.ref_num is null then q1.MINIMUM_PRICE else q01.MINIMUM_PRICE end MINIMUM_PRICE,
        case when q01.ref_num is null then q1.SUDI_START_DATE else null end SUDI_START_DATE, case when q01.ref_num is null then q1.DISC_PERCENTAGE else null end DISC_PERCENTAGE,
        case when q01.ref_num is null then q1.DISC_ABSOLUTE else null end DISC_ABSOLUTE, case when q01.ref_num is null then q1.PRICE else null end PRICE,
        case when q01.ref_num is null then q1.sudi_ref_num else null end sudi_ref_num, case when q01.ref_num is null then q1.padi_ref_num else null end padi_ref_num,
        case when q01.ref_num is null then q1.crm else q01.crm end crm, case when q01.ref_num is null then q1.mixed_service else null end mixed_service,
        qa1.FTCO_REF_NUM, qa1.SUSG_REF_NUM, qa1.FTCO_SEPT_TYPE_CODE, qa1.MIPO_START_DATE, qa1.MIPO_END_DATE, qa1.DISCOUNTED, qa1.MONTHLY_DISC_RATE, qa1.MONTHLY_MARKDOWN, qa1.PACKET_CODE, 
        qa1.PACKET_DESCRIPTION
        from qa1  LEFT JOIN q1 on qa1.susg=q1.susg_ref_num and q1.for_fcit_type_code = qa1.fcit_type_code 
                                         and q1.for_billing_selector = qa1.fcit_billing_selector
                                         and q1.for_sety_ref_num = qa1.sety_ref_num  
                                         and q1.for_sepv_ref_num = qa1.sepv_ref_num
                         LEFT JOIN q01 on q01.for_fcit_type_code = qa1.fcit_type_code 
                                         and q01.for_billing_selector = qa1.fcit_billing_selector
                                         and q01.for_sety_ref_num = qa1.sety_ref_num  
                                         and q01.for_sepv_ref_num = qa1.sepv_ref_num
                         LEFT join bcc_domain_values bcdv1 on bcdv1.value_code = qa1.fcit_billing_selector and bcdv1.doma_type_code = 'BISE'
                         left join bcc_domain_values bcdv2 on bcdv2.value_code = q1.disc_billing_selector and bcdv2.doma_type_code = 'BISE'
                         left join bcc_domain_values bcdv3 on bcdv3.value_code = q01.disc_billing_selector and bcdv3.doma_type_code = 'BISE'
        where 1=1
        --and (starts <= nvl(mipo_end_date, :2) AND ends >= nvl(mipo_start_date, :1))
        and nvl(disc_start, :1) <= nvl(disc_end, :2)
        ), qq2 as (
        select /*+ NO_INDEX (sepv) */ 
        case when discountable*discounts_available = 0 then null 
             else greatest(starts, nvl(disc_start, :1), case when nvl(discounted,0)= 0 then :1 else nvl(mipo_start_date, :1) end) 
        end real_disc_start,
        case when discountable*discounts_available = 0 then null
             else least(ends, nvl(disc_end, :2), case when nvl(discounted,0)= 0 then :2 else nvl(mipo_end_date, :2) end) 
        end real_disc_end,
        qq1.*, acco.bicy_cycle_code, sety.service_name, sepv.param_value sepv_param_value, sepv.description sepv_description
        from qq1  JOIN accounts acco on qq1.maac = acco.ref_num
                  JOIN service_types sety on qq1.sety_ref_num = sety.ref_num
                  JOIN service_param_values sepv on qq1.sepv_ref_num = sepv.ref_num
        where acco.bicy_cycle_code = nvl(:4, acco.bicy_cycle_code)
        and not (discountable = 0 and sudi_ref_num is null and nvl(discounted, 0) = 0)
        ), qq3 as (
        select 
        nvl(lead(real_disc_start) over (partition by susg, starts order by real_disc_start, real_disc_end nulls last)/*next_real_disc_start*/, :2 + 1) - 1 max_real_disc_end,
        case when nvl(lead(real_disc_start) over (partition by susg, starts order by real_disc_start, real_disc_end nulls last), :2 + 1) - 1 /*max_real_disc_end*/ = real_disc_end - 1 then
        1 else 0 end apply_corr, add_months(trunc(:1), 1) -trunc(:1) month_days,
        qq2.*
        from qq2
        ), qq7 as (
        select row_number() over (partition by susg, starts order by discountable desc, discounts_available desc, sudi_ref_num) rn, 
        apply_corr, REAL_DISC_START, case apply_corr when 1 then max_real_disc_end else real_disc_end end REAL_DISC_END, 
        ends+1-starts main_days, case apply_corr when 1 then max_real_disc_end else real_disc_end end + 1 - real_disc_start disc_days,
        DISCOUNTABLE, discounts_available, MAAC, SUSG, service_name, FCIT_BILLING_SELECTOR, FCIT_BISE, FCIT_TYPE_CODE, FCIT_TATY_TYPE_CODE,
        FCIT_DESC, 
        case when discountable*discounts_available = 0 then null else FCIT_FCDT_TYPE_CODE end FCIT_FCDT_TYPE_CODE, STARTS, ENDS, SEPV_START_REAL, SETY_REF_NUM, PRLI_CHARGE_VALUE, FICV_CHARGE_VALUE, 
        CHARGE_VALUE, price_type, curr_code, SEPT_TYPE_CODE, SEPT_DESCRIPTION, SEPV_REF_NUM, SEPV_PARAM_VALUE, SEPV_DESCRIPTION, DISC_START, DISC_END, 
        case when discountable*discounts_available = 0 then null else CADC_REF_NUM end CADC_REF_NUM, PRECENTAGE, COUNT_FOR_MONTHS, COUNT_FOR_DAYS, 
        case when discountable*discounts_available = 0 then null else DISCOUNT_CODE end DISCOUNT_CODE, 
        case when discountable*discounts_available = 0 then null else DISC_DESCR end DISC_DESCR, 
        case when discountable*discounts_available = 0 then null else DISC_BILLING_SELECTOR end DISC_BILLING_SELECTOR, 
        case when discountable*discounts_available = 0 then null else DISC_BISE end DISC_BISE, PRICING, MINIMUM_PRICE, SUDI_START_DATE, DISC_PERCENTAGE, DISC_ABSOLUTE, PRICE, 
        padi_ref_num, SUDI_REF_NUM, 
        case when discountable*discounts_available = 0 then null else CRM end CRM, MIXED_SERVICE, 
        FTCO_REF_NUM, SUSG_REF_NUM, ftco_sept_type_code, MIPO_START_DATE, MIPO_END_DATE, DISCOUNTED, MONTHLY_DISC_RATE, MONTHLY_MARKDOWN, PACKET_CODE, PACKET_DESCRIPTION, BICY_CYCLE_CODE,
        month_days 
        from qq3
        where not (apply_corr = 1 and max_real_disc_end < real_disc_start)
        ), qq5 as (
        select * 
        from qq7
        where not (discountable*discounts_available = 0 and rn > 1)
        ), qq4 as (
        select maac, susg,  
        case rn when 1 then 
        (charge_value-case discounted when 1 then greatest(least(nvl(monthly_markdown,0), charge_value), charge_value*nvl(monthly_disc_rate,0)/100) else 0 end)*main_days/month_days 
        else 0 end period_charge, 
        case rn when 1 then 
        (-case discounted when 1 then greatest(least(nvl(monthly_markdown,0), charge_value), charge_value*nvl(monthly_disc_rate,0)/100) else 0 end * main_days/month_days)
        else 0 end incl_disc,
        fcit_billing_selector, fcit_type_code, fcit_taty_type_code, fcit_bise,  fcit_desc,  disc_billing_selector, disc_bise, disc_descr, fcit_fcdt_type_code, cadc_ref_num,
        -case when disc_days is not null and nvl(discounted, 0) = 0 then 
              case when price is not null then
                 greatest(charge_value-price, 0)*disc_days/month_days
              when price is null and (disc_percentage is not null or disc_absolute is not null) then
                 greatest((nvl(disc_percentage,0)/100)*charge_value, least(nvl(disc_absolute, 0), charge_value))*disc_days/month_days
              else
                case when pricing = 'Y' then
                  (charge_value - least((nvl(precentage,100)/100)*charge_value, least(nvl(minimum_price, charge_value), charge_value)))*disc_days/month_days
                else
                  greatest((nvl(precentage,0)/100)*charge_value, least(nvl(minimum_price, 0), charge_value))*disc_days/month_days
                end
              end
        else
          null  
        end discount
        ,real_disc_start, real_disc_end, disc_days, sepv_start_real, rn, charge_value, price_type, curr_code, month_days, count_for_months, count_for_days, sudi_start_date,
        case when count_for_months is null and count_for_days is null or sudi_start_date is null then null 
                       else add_months(trunc(sudi_start_date), nvl(count_for_months,0)) + nvl(count_for_days,0) end sudi_end
        , starts, ends, 
        case rn when 1 then main_days else 0 end main_days, 
        sudi_ref_num,  
        APPLY_CORR, DISCOUNTABLE, DISCOUNTS_AVAILABLE, SERVICE_NAME, SETY_REF_NUM, PRLI_CHARGE_VALUE, FICV_CHARGE_VALUE, SEPT_TYPE_CODE, SEPT_DESCRIPTION, SEPV_REF_NUM, 
        SEPV_PARAM_VALUE, SEPV_DESCRIPTION, DISC_START, DISC_END, PRECENTAGE, DISCOUNT_CODE, PRICING, MINIMUM_PRICE, DISC_PERCENTAGE, DISC_ABSOLUTE, PRICE, PADI_REF_NUM, CRM, MIXED_SERVICE, 
        FTCO_REF_NUM, SUSG_REF_NUM, FTCO_SEPT_TYPE_CODE, MIPO_START_DATE, MIPO_END_DATE, DISCOUNTED, MONTHLY_DISC_RATE, MONTHLY_MARKDOWN, PACKET_CODE, PACKET_DESCRIPTION, BICY_CYCLE_CODE
        from qq5
        ), int_inv as (
        select max(invo.invo_end) invo_end, inen.billing_selector, inen.fcit_type_code, inen.susg_ref_num 
        from invoices invo, invoice_entries inen
        where 1=1 
        and invo.ref_num = inen.invo_ref_num
        and invo.period_start = :1 
        and invo.invoice_type = 'INT']' ||
        CASE p_one_susg when 'Y' then ' and (inen.susg_ref_num = :5)' else '' end || q'[
        group by inen.billing_selector, inen.fcit_type_code, inen.fcdt_type_code, inen.susg_ref_num
        ), qq6a as (
        select qq4.*,   sum(qq4.discount) over (partition by qq4.susg, qq4.starts order by qq4.rn) x, 
        least(-least(sum(qq4.discount) over (partition by qq4.susg, qq4.starts order by qq4.rn) - qq4.discount + qq4.charge_value, - qq4.discount),0) discountx, 
        case when nvl(qq4.discount,0) = 0 then 
            null 
        else (
            case when qq4.padi_ref_num is null then 
                case qq4.pricing when 'N' then '-' else '' end || 
                case when qq4.precentage is not null then qq4.precentage || '% ' else '' end || 
                case when qq4.minimum_price is not null then qq4.minimum_price || ' ' else '' end   
            else 
                'Party discount ' || qq4.padi_ref_num || ': ' || qq4.price 
            end 
        ) end discount_description,
        int_inv.invo_end
        from qq4 LEFT JOIN int_inv on int_inv.susg_ref_num = qq4.susg AND int_inv.billing_selector = qq4.fcit_billing_selector and int_inv.fcit_type_code = qq4.fcit_type_code
        ), qq6 as (
        select ]' ||
        CASE p_one_susg when 'Y' then '' else '/*+ NO_INDEX(sesu) */ ' end ||
        q'[qq6a.*, sesu.serv_num,
        row_number() over (partition by qq6a.susg, qq6a.starts, qq6a.sudi_ref_num order by sesu.end_date desc nulls first) r1
        from qq6a LEFT JOIN senu_susg sesu on qq6a.susg = sesu.susg_ref_num
        where not(sesu.end_date < :1 and sesu.end_date is not null)
        )
        select qq6.bicy_cycle_code, qq6.maac, qq6.susg, qq6.serv_num, qq6.sety_ref_num, qq6.service_name, qq6.sept_type_code, qq6.sept_description, qq6.sepv_ref_num, qq6.sepv_description, 
        qq6.packet_code packet_discount, case rn when 1 then qq6.starts else null end starts, case rn when 1 then qq6.ends else null end ends, qq6.main_days, qq6.charge_value, qq6.price_type, 
        qq6.curr_code, qq6.period_charge, qq6.incl_disc, qq6.fcit_billing_selector, qq6.fcit_type_code, qq6.fcit_taty_type_code, qq6.fcit_bise, qq6.fcit_desc, qq6.real_disc_start disc_start, 
        qq6.real_disc_end disc_end, qq6.disc_days, qq6.discountx discount, qq6.discount_code, qq6.discount_description,
        qq6.disc_billing_selector, qq6.fcit_fcdt_type_code, qq6.disc_bise, qq6.disc_descr, qq6.cadc_ref_num, qq6.sudi_ref_num, qq6.crm, qq6.invo_end
        from qq6
        where r1=1;
        END;
        ]';
        
        return l_clob;
   END;

PROCEDURE fill_inen_temp(p_start_date DATE) 
   IS
   BEGIN
   insert into daily_charges_inen_temp
    with q1 as (
    select REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, max(DATE_CREATED) date_created, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, 
    IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, 
    EVRE_CHAR_USAGE, PRINT_REQUIRED, VMCT_RATE_VALUE, SUM(NUM_OF_DAYS) num_of_days, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, 
    AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, SUM(ACC_AMOUNT) acc_amount, BILLING_SELECTOR_TEXT, ENTRY_TEXT, 
    ADDITIONAL_ENTRY_TEXT, maac
    from (
    select /*+ NO_PARALLEL */ null REF_NUM, null INVO_REF_NUM, null SEC_AMT, 'N' ROUNDING_INDICATOR, 'N' UNDER_DISPUTE, null CREATED_BY, sysdate DATE_CREATED, null AMT_IN_CURR, fcit_billing_selector BILLING_SELECTOR, 
    FCIT_TYPE_CODE, fcit_taty_type_code TATY_TYPE_CODE, susg SUSG_REF_NUM, null IADN_REF_NUM, null CURR_CODE, null VMCT_TYPE_CODE, null LAST_UPDATED_BY, null DATE_UPDATED, null DESCRIPTION, 
    null SEC_AMT_TAX, null AMT_TAX_CURR, 'N' MANUAL_ENTRY, null EVRE_COUNT, null EVRE_DURATION, null MODULE_REF, null SEC_FIXED_CHARGE_VALUE, null EVRE_CHAR_USAGE, null PRINT_REQUIRED, 
    null VMCT_RATE_VALUE, greatest(ends+1-greatest(nvl(trunc(billed_invo_end)+1, p_start_date),starts),0) NUM_OF_DAYS, 
    null EVRE_DATA_VOLUME, null MAAS_REF_NUM, null CADC_REF_NUM, null FCDT_TYPE_CODE, null SEC_FF_DISC_AMT, null SEC_CURR_CODE, 
    null AMT_TAX, curr_code PRI_CURR_CODE, null FF_DISC_AMT, null FIXED_CHARGE_VALUE, null SEC_ACC_AMOUNT, 
    case crm when 'N' then period_charge + nvl(discount,0) else period_charge end ACC_AMOUNT, 
    fcit_bise BILLING_SELECTOR_TEXT,fcit_desc ENTRY_TEXT, null ADDITIONAL_ENTRY_TEXT, maac
    from daily_charges_descr_temp
    where period_charge != 0 OR nvl(crm, 'X') = 'N' 
    )
    group by REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, 
    CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, 
    PRINT_REQUIRED, VMCT_RATE_VALUE, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, AMT_TAX, 
    PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, maac
    ), q2 as (
    select REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, max(DATE_CREATED) date_created, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, 
    IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, 
    EVRE_CHAR_USAGE, PRINT_REQUIRED, VMCT_RATE_VALUE, SUM(NUM_OF_DAYS) num_of_days, EVRE_DATA_VOLUME, MAAS_REF_NUM, max(CADC_REF_NUM) cadc_ref_num, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, 
    AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, SUM(ACC_AMOUNT) acc_amount, BILLING_SELECTOR_TEXT, ENTRY_TEXT, 
    ADDITIONAL_ENTRY_TEXT, maac,sudi_ref_num, row_number() over (partition by susg_ref_num, fcdt_type_code order by sum(acc_amount) desc) rn, 
    sum(SUM(ACC_AMOUNT)) over (partition by susg_ref_num, fcdt_type_code order by min(disc_start), sudi_ref_num) s 
    from (
    select /*+ NO_PARALLEL */ null REF_NUM, null INVO_REF_NUM, null SEC_AMT, 'N' ROUNDING_INDICATOR, 'N' UNDER_DISPUTE, null CREATED_BY, sysdate DATE_CREATED, null AMT_IN_CURR, disc_billing_selector BILLING_SELECTOR, 
    null FCIT_TYPE_CODE, fcit_taty_type_code TATY_TYPE_CODE, susg SUSG_REF_NUM, null IADN_REF_NUM, null CURR_CODE, null VMCT_TYPE_CODE, null LAST_UPDATED_BY, null DATE_UPDATED, null DESCRIPTION, 
    null SEC_AMT_TAX, null AMT_TAX_CURR, 'N' MANUAL_ENTRY, 1 EVRE_COUNT, null EVRE_DURATION, null MODULE_REF, null SEC_FIXED_CHARGE_VALUE, null EVRE_CHAR_USAGE, crm PRINT_REQUIRED, 
    null VMCT_RATE_VALUE, greatest(disc_end+1-greatest(nvl(trunc(billed_invo_end)+1, p_start_date),disc_start),0) NUM_OF_DAYS, 
    null EVRE_DATA_VOLUME, null MAAS_REF_NUM, cadc_ref_num CADC_REF_NUM, fcit_fcdt_type_code FCDT_TYPE_CODE, null SEC_FF_DISC_AMT, null SEC_CURR_CODE, 
    null AMT_TAX, curr_code PRI_CURR_CODE, null FF_DISC_AMT, null FIXED_CHARGE_VALUE, null SEC_ACC_AMOUNT, discount ACC_AMOUNT, disc_bise BILLING_SELECTOR_TEXT, 
    disc_description ENTRY_TEXT, null ADDITIONAL_ENTRY_TEXT, maac, sudi_ref_num, disc_start
    from daily_charges_descr_temp
    where 1=1
    and crm = 'Y'
    )
    group by REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, 
    CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, 
    PRINT_REQUIRED, VMCT_RATE_VALUE, EVRE_DATA_VOLUME, MAAS_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, AMT_TAX, 
    PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, maac, sudi_ref_num
    ), q3 as (
    select /*+ NO_INDEX(invo) */ min(invo.invo_start) invo_start, max(invo.invo_end) invo_end, inen.billing_selector, inen.fcit_type_code, inen.fcdt_type_code, inen.susg_ref_num , 
    sum(coalesce(inen.acc_amount,inen.eek_amt, 0)) invo_amount
    from invoices invo, invoice_entries inen
    where 1=1 
    and invo.ref_num = inen.invo_ref_num
    and invo.period_start = p_start_date 
    and invo.invoice_type = 'INT'
    group by inen.billing_selector, inen.fcit_type_code, inen.fcdt_type_code, inen.susg_ref_num
    ), q4 as (
    select q1.REF_NUM, q1.INVO_REF_NUM, q1.SEC_AMT, q1.ROUNDING_INDICATOR, q1.UNDER_DISPUTE, q1.CREATED_BY, q1.DATE_CREATED, q1.AMT_IN_CURR, q1.BILLING_SELECTOR, q1.FCIT_TYPE_CODE, 
    q1.TATY_TYPE_CODE, q1.SUSG_REF_NUM, q1.IADN_REF_NUM, q1.CURR_CODE, q1.VMCT_TYPE_CODE, q1.LAST_UPDATED_BY, q1.DATE_UPDATED, q1.DESCRIPTION, q1.SEC_AMT_TAX, q1.AMT_TAX_CURR, q1.MANUAL_ENTRY, 
    q1.EVRE_COUNT, q1.EVRE_DURATION, q1.MODULE_REF, q1.SEC_FIXED_CHARGE_VALUE, q1.EVRE_CHAR_USAGE, q1.PRINT_REQUIRED, q1.VMCT_RATE_VALUE, q1.NUM_OF_DAYS, q1.EVRE_DATA_VOLUME, q1.MAAS_REF_NUM, 
    q1.CADC_REF_NUM, q1.FCDT_TYPE_CODE, q1.SEC_FF_DISC_AMT, q1.SEC_CURR_CODE, q1.AMT_TAX, q1.PRI_CURR_CODE, q1.FF_DISC_AMT, q1.FIXED_CHARGE_VALUE, 
    q1.SEC_ACC_AMOUNT, q1.ACC_AMOUNT - nvl(q3.invo_amount, 0) acc_amount, q1.BILLING_SELECTOR_TEXT, q1.ENTRY_TEXT, q1.ADDITIONAL_ENTRY_TEXT, q1.MAAC, q3.invo_amount 
    from q1 LEFT JOIN q3 on q1.billing_selector = q3.billing_selector and q1.susg_ref_num = q3.susg_ref_num and q1.fcit_type_code = q3.fcit_type_code
    UNION ALL
    select q2.REF_NUM, q2.INVO_REF_NUM, q2.SEC_AMT, q2.ROUNDING_INDICATOR, q2.UNDER_DISPUTE, q2.CREATED_BY, q2.DATE_CREATED, q2.AMT_IN_CURR, q2.BILLING_SELECTOR, q2.FCIT_TYPE_CODE, 
    q2.TATY_TYPE_CODE, q2.SUSG_REF_NUM, q2.IADN_REF_NUM, q2.CURR_CODE, q2.VMCT_TYPE_CODE, q2.LAST_UPDATED_BY, q2.DATE_UPDATED, q2.DESCRIPTION, q2.SEC_AMT_TAX, q2.AMT_TAX_CURR, q2.MANUAL_ENTRY, 
    q2.EVRE_COUNT, q2.EVRE_DURATION, q2.MODULE_REF, q2.SEC_FIXED_CHARGE_VALUE, q2.EVRE_CHAR_USAGE, q2.PRINT_REQUIRED, q2.VMCT_RATE_VALUE, q2.NUM_OF_DAYS, q2.EVRE_DATA_VOLUME, q2.MAAS_REF_NUM, 
    q2.CADC_REF_NUM, q2.FCDT_TYPE_CODE, q2.SEC_FF_DISC_AMT, q2.SEC_CURR_CODE, q2.AMT_TAX, q2.PRI_CURR_CODE, q2.FF_DISC_AMT, q2.FIXED_CHARGE_VALUE, q2.SEC_ACC_AMOUNT, 
    least(least(q2.s-nvl(q3.invo_amount,0),0) - least(q2.s-q2.acc_amount-nvl(q3.invo_amount,0),0),0) acc_amount, q2.BILLING_SELECTOR_TEXT, q2.ENTRY_TEXT, q2.ADDITIONAL_ENTRY_TEXT, 
    q2.MAAC , q3.invo_amount
    from q2 LEFT JOIN q3 on q2.billing_selector = q3.billing_selector and q2.susg_ref_num = q3.susg_ref_num and q2.fcdt_type_code = q3.fcdt_type_code
    )
    select REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, 
    CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, 
    PRINT_REQUIRED, VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, round(ACC_AMOUNT,2) EEK_AMT, AMT_TAX, PRI_CURR_CODE, 
    FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, round(ACC_AMOUNT, 4) ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, MAAC , invo_amount
    from (
    select /*+ NO_INDEX(invo) */ q4.REF_NUM, INVO.REF_NUM INVO_REF_NUM, q4.SEC_AMT, q4.ROUNDING_INDICATOR, q4.UNDER_DISPUTE, q4.CREATED_BY, q4.DATE_CREATED, q4.AMT_IN_CURR, q4.BILLING_SELECTOR, q4.FCIT_TYPE_CODE, 
    q4.TATY_TYPE_CODE, q4.SUSG_REF_NUM, q4.IADN_REF_NUM, q4.CURR_CODE, q4.VMCT_TYPE_CODE, q4.LAST_UPDATED_BY, q4.DATE_UPDATED, q4.DESCRIPTION, q4.SEC_AMT_TAX, q4.AMT_TAX_CURR, q4.MANUAL_ENTRY, 
    q4.EVRE_COUNT, q4.EVRE_DURATION, q4.MODULE_REF, q4.SEC_FIXED_CHARGE_VALUE, q4.EVRE_CHAR_USAGE, q4.PRINT_REQUIRED, q4.VMCT_RATE_VALUE, q4.NUM_OF_DAYS, q4.EVRE_DATA_VOLUME, q4.MAAS_REF_NUM, 
    q4.CADC_REF_NUM, q4.FCDT_TYPE_CODE, q4.SEC_FF_DISC_AMT, q4.SEC_CURR_CODE, 
    q4.AMT_TAX, q4.PRI_CURR_CODE, q4.FF_DISC_AMT, q4.FIXED_CHARGE_VALUE, q4.SEC_ACC_AMOUNT, 
    case  when nvl(q4.invo_amount,0)=0 then q4.acc_amount when q4.invo_amount > 0 then greatest(q4.acc_amount, 0) else least(q4.acc_amount, 0) end ACC_AMOUNT,
    q4.BILLING_SELECTOR_TEXT, q4.ENTRY_TEXT, q4.ADDITIONAL_ENTRY_TEXT, q4.MAAC , q4.invo_amount
    from q4 LEFT JOIN invoices invo ON q4.maac = invo.maac_ref_num and invo.invoice_type = 'INB' and period_start = p_start_date
    where q4.acc_amount > 0.01 OR q4.acc_amount < -0.01
    )
    where acc_amount != 0
    ;
   END;   

   PROCEDURE fill_inen_temp_small(p_start_date DATE) 
   IS
   BEGIN
   insert into daily_charges_inen_s_temp
    with q1 as (
    select REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, max(DATE_CREATED) date_created, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, 
    IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, 
    EVRE_CHAR_USAGE, PRINT_REQUIRED, VMCT_RATE_VALUE, SUM(NUM_OF_DAYS) num_of_days, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, 
    AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, SUM(ACC_AMOUNT) acc_amount, BILLING_SELECTOR_TEXT, ENTRY_TEXT, 
    ADDITIONAL_ENTRY_TEXT, maac
    from (
    select /*+ NO_PARALLEL */ null REF_NUM, null INVO_REF_NUM, null SEC_AMT, 'N' ROUNDING_INDICATOR, 'N' UNDER_DISPUTE, null CREATED_BY, sysdate DATE_CREATED, null AMT_IN_CURR, fcit_billing_selector BILLING_SELECTOR, 
    FCIT_TYPE_CODE, fcit_taty_type_code TATY_TYPE_CODE, susg SUSG_REF_NUM, null IADN_REF_NUM, null CURR_CODE, null VMCT_TYPE_CODE, null LAST_UPDATED_BY, null DATE_UPDATED, null DESCRIPTION, 
    null SEC_AMT_TAX, null AMT_TAX_CURR, 'N' MANUAL_ENTRY, null EVRE_COUNT, null EVRE_DURATION, null MODULE_REF, null SEC_FIXED_CHARGE_VALUE, null EVRE_CHAR_USAGE, null PRINT_REQUIRED, 
    null VMCT_RATE_VALUE, greatest(ends+1-greatest(nvl(trunc(billed_invo_end)+1, p_start_date),starts),0) NUM_OF_DAYS, 
    null EVRE_DATA_VOLUME, null MAAS_REF_NUM, null CADC_REF_NUM, null FCDT_TYPE_CODE, null SEC_FF_DISC_AMT, null SEC_CURR_CODE, 
    null AMT_TAX, curr_code PRI_CURR_CODE, null FF_DISC_AMT, null FIXED_CHARGE_VALUE, null SEC_ACC_AMOUNT, 
    case crm when 'N' then period_charge + nvl(discount,0) else period_charge end ACC_AMOUNT, 
    fcit_bise BILLING_SELECTOR_TEXT,fcit_desc ENTRY_TEXT, null ADDITIONAL_ENTRY_TEXT, maac
    from daily_charges_descr_s_temp
    where period_charge != 0 OR nvl(crm, 'X') = 'N'
    )
    group by REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, 
    CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, 
    PRINT_REQUIRED, VMCT_RATE_VALUE, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, AMT_TAX, 
    PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, maac
    ), q2 as (
    select REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, max(DATE_CREATED) date_created, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, 
    IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, 
    EVRE_CHAR_USAGE, PRINT_REQUIRED, VMCT_RATE_VALUE, SUM(NUM_OF_DAYS) num_of_days, EVRE_DATA_VOLUME, MAAS_REF_NUM, max(CADC_REF_NUM) cadc_ref_num, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, 
    AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, SUM(ACC_AMOUNT) acc_amount, BILLING_SELECTOR_TEXT, ENTRY_TEXT, 
    ADDITIONAL_ENTRY_TEXT, maac, sudi_ref_num, row_number() over (partition by susg_ref_num, fcdt_type_code order by sum(acc_amount) desc) rnx, 
    sum(SUM(ACC_AMOUNT)) over (partition by susg_ref_num, fcdt_type_code order by min(disc_start), sudi_ref_num) s 
    from (
    select /*+ NO_PARALLEL */null REF_NUM, null INVO_REF_NUM, null SEC_AMT, 'N' ROUNDING_INDICATOR, 'N' UNDER_DISPUTE, null CREATED_BY, sysdate DATE_CREATED, null AMT_IN_CURR, disc_billing_selector BILLING_SELECTOR, 
    null FCIT_TYPE_CODE, fcit_taty_type_code TATY_TYPE_CODE, susg SUSG_REF_NUM, null IADN_REF_NUM, null CURR_CODE, null VMCT_TYPE_CODE, null LAST_UPDATED_BY, null DATE_UPDATED, null DESCRIPTION, 
    null SEC_AMT_TAX, null AMT_TAX_CURR, 'N' MANUAL_ENTRY, 1 EVRE_COUNT, null EVRE_DURATION, null MODULE_REF, null SEC_FIXED_CHARGE_VALUE, null EVRE_CHAR_USAGE, crm PRINT_REQUIRED, 
    null VMCT_RATE_VALUE, greatest(disc_end+1-greatest(nvl(trunc(billed_invo_end)+1, p_start_date),disc_start),0) NUM_OF_DAYS, 
    null EVRE_DATA_VOLUME, null MAAS_REF_NUM, cadc_ref_num CADC_REF_NUM, fcit_fcdt_type_code FCDT_TYPE_CODE, null SEC_FF_DISC_AMT, null SEC_CURR_CODE, 
    discount EEK_AMT, null AMT_TAX, curr_code PRI_CURR_CODE, null FF_DISC_AMT, null FIXED_CHARGE_VALUE, null SEC_ACC_AMOUNT, discount ACC_AMOUNT, disc_bise BILLING_SELECTOR_TEXT, 
    disc_description ENTRY_TEXT, null ADDITIONAL_ENTRY_TEXT, maac, sudi_ref_num, disc_start
    from daily_charges_descr_s_temp
    where 1=1
    and crm = 'Y'
    )
    group by REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, 
    CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, 
    PRINT_REQUIRED, VMCT_RATE_VALUE, EVRE_DATA_VOLUME, MAAS_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, AMT_TAX, 
    PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, maac, sudi_ref_num
    ), q4 as (
    select REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, 
    TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, 
    EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, 
    CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, 
    SEC_ACC_AMOUNT, ACC_AMOUNT - nvl(invo_amount, 0) acc_amount, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, MAAC, invo_amount 
    from (
    select /*+ no_index (INVO invo_pest_i1) */ 
    sum(case when invo.ref_num is null then 0 else coalesce(inen.eek_amt, inen.acc_amount,0) end) over (partition by inen.billing_selector, inen.fcit_type_code, inen.susg_ref_num)  invo_amount,
    row_number() over (partition by q1.billing_selector, q1.fcit_type_code, q1.susg_ref_num order by null) rn, 
    q1.*    
    from q1 LEFT JOIN invoice_entries inen on q1.billing_selector = inen.billing_selector and q1.susg_ref_num = inen.susg_ref_num and q1.fcit_type_code = inen.fcit_type_code
            LEFT JOIN invoices invo on inen.invo_ref_num = invo.ref_num and invo.invoice_type = 'INT' and invo.period_start = p_start_date
    )
    where rn = 1
    union all
    select REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, 
    TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, 
    EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, 
    CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, 
    AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, 
    least(least(s-nvl(invo_amount,0),0) - least(s-acc_amount-nvl(invo_amount,0),0),0) acc_amount, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, 
    MAAC, invo_amount 
    from (
    select /*+ no_index (INVO invo_pest_i1) */ 
    sum(case when invo.ref_num is null then 0 else coalesce(inen.eek_amt, inen.acc_amount,0) end) over (partition by inen.billing_selector, inen.fcdt_type_code, inen.susg_ref_num)  invo_amount,
    row_number() over (partition by q2.billing_selector, q2.fcdt_type_code, q2.susg_ref_num order by null) rn, 
    q2.*    
    from q2 LEFT JOIN invoice_entries inen on q2.billing_selector = inen.billing_selector and q2.susg_ref_num = inen.susg_ref_num and q2.fcdt_type_code = inen.fcdt_type_code
            LEFT JOIN invoices invo on inen.invo_ref_num = invo.ref_num and invo.invoice_type = 'INT' and invo.period_start = p_start_date
    )
    where rn = 1
    )
    select REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, 
    CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, 
    PRINT_REQUIRED, VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, round(ACC_AMOUNT,2) EEK_AMT, AMT_TAX, PRI_CURR_CODE, 
    FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, round(ACC_AMOUNT, 4) ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, MAAC , invo_amount
    from (
    select /*+ no_index (INVO invo_pest_i1)*/ q4.REF_NUM, INVO.REF_NUM INVO_REF_NUM, q4.SEC_AMT, q4.ROUNDING_INDICATOR, q4.UNDER_DISPUTE, q4.CREATED_BY, q4.DATE_CREATED, q4.AMT_IN_CURR, q4.BILLING_SELECTOR, q4.FCIT_TYPE_CODE, 
    q4.TATY_TYPE_CODE, q4.SUSG_REF_NUM, q4.IADN_REF_NUM, q4.CURR_CODE, q4.VMCT_TYPE_CODE, q4.LAST_UPDATED_BY, q4.DATE_UPDATED, q4.DESCRIPTION, q4.SEC_AMT_TAX, q4.AMT_TAX_CURR, q4.MANUAL_ENTRY, 
    q4.EVRE_COUNT, q4.EVRE_DURATION, q4.MODULE_REF, q4.SEC_FIXED_CHARGE_VALUE, q4.EVRE_CHAR_USAGE, q4.PRINT_REQUIRED, q4.VMCT_RATE_VALUE, q4.NUM_OF_DAYS, q4.EVRE_DATA_VOLUME, q4.MAAS_REF_NUM, 
    q4.CADC_REF_NUM, q4.FCDT_TYPE_CODE, q4.SEC_FF_DISC_AMT, q4.SEC_CURR_CODE, 
    q4.AMT_TAX, q4.PRI_CURR_CODE, q4.FF_DISC_AMT, q4.FIXED_CHARGE_VALUE, q4.SEC_ACC_AMOUNT, 
    case  when nvl(q4.invo_amount,0)=0 then q4.acc_amount when q4.invo_amount > 0 then greatest(q4.acc_amount, 0) else least(q4.acc_amount, 0) end ACC_AMOUNT,
    q4.BILLING_SELECTOR_TEXT, q4.ENTRY_TEXT, q4.ADDITIONAL_ENTRY_TEXT, q4.MAAC , q4.invo_amount
    from q4 LEFT JOIN invoices invo ON q4.maac = invo.maac_ref_num and invo.invoice_type = 'INB' and period_start = p_start_date
    where q4.acc_amount > 0.01 OR q4.acc_amount < -0.01
    )
    where acc_amount != 0 
    ;
   END;   
   
   PROCEDURE create_missing_invoices(p_period_start_date IN DATE
                                     ,p_bill_cycle IN VARCHAR2
                                     ,p_success OUT BOOLEAN
                                     ) IS
   CURSOR c_maac IS
        select maac from (
        select maac, sum(nvl(period_charge,0)) charge, sum(nvl(discount,0)) discount 
        from daily_charges_descr_temp t
        where t.bicy_cycle_code = nvl(p_bill_cycle, t.bicy_cycle_code)
        group by maac
        )
        where (charge != 0 OR discount != 0)
        and maac not in (
            select /*+ FULL(invo) */ maac_ref_num from invoices invo
            where invo.invoice_type = 'INB' and period_start = p_period_start_date
        );
   CURSOR c_maac_2 IS
        select maac from (
        select maac, sum(nvl(period_charge,0)) charge, sum(nvl(discount,0)) discount 
        from daily_charges_descr_temp t
        where t.bicy_cycle_code = nvl(p_bill_cycle, t.bicy_cycle_code)
        group by maac
        )
        where (charge != 0 OR discount != 0)
          and maac in (
              select maac 
              from daily_charges_inen_temp
              where invo_ref_num is null
              );
    l_invo_rec invoices%ROWTYPE;
    l_success BOOLEAN;
    l_counter NUMBER := 0;
    l_err_count NUMBER := 0;
   
   BEGIN
   FOR maac_rec in c_maac LOOP
        begin
        open_invoice.create_billing_debit_invoice (maac_rec.maac, 'INB', p_period_start_date, l_invo_rec, l_success);
        exception
          when others then
            l_success := FALSE;
        end;
        IF l_success THEN
            update daily_charges_inen_temp
            set invo_ref_num = l_invo_rec.ref_num
            where maac = maac_rec.maac;
        ELSE
          BEGIN
            select * 
            into l_invo_rec
            from invoices
            where maac_ref_num = maac_rec.maac
            and invoice_type = 'INB' and period_start = p_period_start_date;  --DOBAS-1932 
            update daily_charges_inen_temp
            set invo_ref_num = l_invo_rec.ref_num
            where maac = maac_rec.maac;
          EXCEPTION
          when others then
            null;
          END;               
        END IF;
        l_counter := l_counter + 1;
        if mod(l_counter,30) = 0 then
           commit;
        end if;   
   END LOOP;
   commit;
     --DOBAS-1932
    update daily_charges_inen_temp dcit
    set dcit.invo_ref_num = (
    select ref_num 
    from invoices invo
    where dcit.maac = invo.maac_ref_num
    and invo.invoice_type = 'INB' 
    and invo.period_start = p_period_start_date 
    )
    where dcit.invo_ref_num is null;
    commit;
    
   FOR maac_rec in c_maac_2 LOOP
        begin
        open_invoice.create_billing_debit_invoice (maac_rec.maac, 'INB', p_period_start_date, l_invo_rec, l_success);
        exception
          when others then
            l_success := FALSE;
        end;
        IF l_success THEN
            update daily_charges_inen_temp
            set invo_ref_num = l_invo_rec.ref_num
            where maac = maac_rec.maac;
        ELSE
          BEGIN
            select * 
            into l_invo_rec
            from invoices
            where maac_ref_num = maac_rec.maac
            and invoice_type = 'INB' and period_start = p_period_start_date; 
            update daily_charges_inen_temp
            set invo_ref_num = l_invo_rec.ref_num
            where maac = maac_rec.maac;
          EXCEPTION
          when others then
            l_err_count := l_err_count + 1;
          END;               
        END IF;
        commit;
   END LOOP;
   
   if l_err_count > 0 then 
   p_success := FALSE;
   else  
  --DOBAS-1932 END
   p_success := TRUE;
   end if;  --DOBAS-1932

   END;

   PROCEDURE merge_subs_discounts(p_bill_cycle IN VARCHAR2) IS
   BEGIN
   
        MERGE INTO TBCIS.SUBS_DISCOUNTS d
        USING (
        select t.susg, t.discount_code, min(t.disc_start) disc_start, t.cadc_ref_num, dico.ref_num dico_ref_num, t.sudi_ref_num, round(-sum(t.discount),2) eek_amt, t.curr_code 
        from daily_charges_descr_temp t , 
        (select * from (select row_number () over (partition by discount_code order by date_updated desc) rn, discount_code, ref_num from discount_codes) where rn =1)  dico
        where 1=1
        and t.discount_code = dico.discount_code
        and t.bicy_cycle_code = nvl(p_bill_cycle, t.bicy_cycle_code)
        group by t.susg, t.discount_code, t.cadc_ref_num, dico.ref_num, t.sudi_ref_num, t.curr_code
        ) s
        ON
          (d.susg_ref_num = s.susg AND d.cadc_ref_num = s.cadc_ref_num AND
           d.dico_ref_num = s.dico_ref_num AND d.curr_code = s.curr_code AND d.dico_sudi_ref_num = s.sudi_ref_num)
        WHEN MATCHED THEN
        UPDATE SET
          d.EEK_AMT = nvl(d.eek_amt, 0) + nvl(s.EEK_AMT,0) --,d.DATE_UPDATED = sysdate, d.LAST_UPDATED_BY = user, d.discount_code = s.discount_code
        WHEN NOT MATCHED THEN
        INSERT (
          REF_NUM, SUSG_REF_NUM, DISCOUNT_CODE, CONNECTION_EXIST, DATE_CREATED, CREATED_BY, START_DATE,
          CADC_REF_NUM, DICO_REF_NUM, DICO_SUDI_REF_NUM, EEK_AMT, CURR_CODE)
        VALUES (
          sudi_ref_num_s.nextval, s.SUSG, s.DISCOUNT_CODE, 'N', sysdate, sec.get_username, s.disc_start,
          s.CADC_REF_NUM, s.DICO_REF_NUM,s.SUDI_REF_NUM, s.EEK_AMT, s.CURR_CODE);

    END;
    
   PROCEDURE clean_obsolete_invoice_entries(p_start_date IN DATE, p_bill_cycle IN VARCHAR2) IS
   BEGIN
      IF p_bill_cycle IS null THEN
        delete from invoice_entries
        where invo_ref_num in (
        select /*+ NO_PARALLEL NO_INDEX(invo) */ ref_num from invoices invo
        where ref_num in (
        select invo_ref_num from daily_charges_inen_temp
        )
        and period_start = p_start_date
        and invoice_type = 'INB'
        )
        and module_ref = c_proc_module_ref;
      ELSE  

        delete from invoice_entries
        where invo_ref_num in (
        select /*+ NO_PARALLEL NO_INDEX(invo) */ ref_num 
        from invoices invo
        where ref_num in (
        select invo_ref_num from daily_charges_inen_temp
        )
        and maac_ref_num in (
        select maac from  daily_charges_descr_temp
        where bicy_cycle_code = p_bill_cycle
        )
        and period_start = p_start_date
        and invoice_type = 'INB'
        )
        and module_ref = c_proc_module_ref;
      END IF;  

    END;
    
    PROCEDURE insert_invoice_entries IS
    l_user VARCHAR2(15);
    l_date DATE;
    BEGIN
        l_user := sec.get_username;
        l_date := sysdate;
        INSERT INTO TBCIS.INVOICE_ENTRIES (
           REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, 
           FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, 
           SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, 
           VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, EEK_AMT, 
           AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT) 
        SELECT 
           inen_ref_num_s.nextval, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, l_user, l_date, AMT_IN_CURR, BILLING_SELECTOR, 
           FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, 
           SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, c_proc_module_ref, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, 
           VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, EEK_AMT, 
           AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT
        FROM TBCIS.DAILY_CHARGES_INEN_TEMP
        where invo_ref_num is not null;
        commit;
    END;
    
    PROCEDURE insert_invoice_entries(p_bill_cycle VARCHAR2) IS
    l_user VARCHAR2(15);
    l_date DATE;
    BEGIN
        l_user := sec.get_username;
        l_date := sysdate;
        INSERT INTO TBCIS.INVOICE_ENTRIES (
           REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, 
           FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, 
           SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, 
           VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, EEK_AMT, 
           AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT) 
        SELECT 
           inen_ref_num_s.nextval, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, l_user, l_date, AMT_IN_CURR, BILLING_SELECTOR, 
           FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, 
           SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, c_proc_module_ref, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, 
           VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, EEK_AMT, 
           AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT
        FROM TBCIS.DAILY_CHARGES_INEN_TEMP
        where invo_ref_num is not null
        and maac in (
            select maac
            from TBCIS.DAILY_CHARGES_DESCR_TEMP
            where bicy_cycle_code = p_bill_cycle
        );
        commit;
    END;
    
   PROCEDURE get_invoice (
      p_maac_ref_num       IN      accounts.ref_num%TYPE
     ,p_period_start_date  IN      DATE
     ,p_success            OUT     BOOLEAN
     ,p_error_text         OUT     VARCHAR2
     ,p_invo_rec           OUT     invoices%ROWTYPE
   ) IS
      --
      CURSOR c_invo IS
         SELECT invo.*
           FROM invoices invo
          WHERE maac_ref_num = p_maac_ref_num AND invoice_type = 'INB' AND period_start = p_period_start_date;

      --
      l_found                       BOOLEAN;
      --
      e_create_invoice              EXCEPTION;
      e_invo_closed                 EXCEPTION;
   BEGIN
      /*
        ** Try to get debit billing invoice for this period.
      */
      OPEN c_invo;

      FETCH c_invo
       INTO p_invo_rec;

      l_found := c_invo%FOUND;

      CLOSE c_invo;

      --
      IF NOT l_found THEN
         /*
           ** This period debit billing invoice not existing yet. Try to create it now.
         */
         open_invoice.create_billing_debit_invoice (p_maac_ref_num, 'INB', p_period_start_date, p_invo_rec, p_success);

         IF NOT p_success THEN
            RAISE e_create_invoice;
         END IF;
      END IF;

      --
      IF p_invo_rec.period_end IS NOT NULL THEN
         RAISE e_invo_closed;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_create_invoice THEN
         p_success := FALSE;
         p_error_text :=    'Masterile '
                         || TO_CHAR (p_maac_ref_num)
                         || ' ei õnnestunud luua INB arvet perioodiks algusega '
                         || TO_CHAR (p_period_start_date, 'dd.mm.yyyy hh24:mi:ss');
      WHEN e_invo_closed THEN
         p_success := FALSE;
         p_error_text := 'Masteri ' || TO_CHAR (p_maac_ref_num) || ' jooksva perioodi arve on juba suletud';
   END get_invoice;

   PROCEDURE invoice_maac_nonker_serv_fees (
      p_maac_ref_num  IN      accounts.ref_num%TYPE
     ,p_period_start  IN      DATE
     ,p_inen_tab      IN OUT  calculate_fixed_charges.t_inen
     ,p_success       OUT     BOOLEAN
     ,p_error_text    OUT     VARCHAR2
     ,p_invo_ref_num  IN      invoices.ref_num%TYPE   -- vahearvete, vahesaldode korral on arve ref teada
     ,p_interim       IN      BOOLEAN
   ) IS
      --
      l_invo_rec                    invoices%ROWTYPE;
      --
      e_creating_invoice            EXCEPTION;
   BEGIN
      IF p_invo_ref_num IS NOT NULL THEN
         l_invo_rec.ref_num := p_invo_ref_num;
      ELSE
         /*
           ** Leiame arve, kuhu masteri arveread kanda.
         */
         get_invoice (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                     ,p_period_start   -- IN     DATE
                     ,p_success   --    OUT BOOLEAN
                     ,p_error_text   --    OUT VARCHAR2
                     ,l_invo_rec   --    OUT invoices%ROWTYPE
                     );

         IF NOT p_success THEN
            RAISE e_creating_invoice;
         END IF;
      END IF;

      /*
        ** Kui arve edukalt leitud, siis kanname masteri arveread leitud arvele.
      */
        
      IF p_interim = TRUE THEN
         FORALL i IN p_inen_tab.FIRST .. p_inen_tab.LAST
            INSERT INTO TBCIS.INVOICE_ENTRIES_INTERIM (
               REF_NUM, INVO_REF_NUM, AMT_IN_CURR, 
               ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, 
               DATE_CREATED, EEK_AMT, BILLING_SELECTOR, 
               FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, 
               IADN_REF_NUM, SEC_CURR_CODE, VMCT_TYPE_CODE, 
               LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, 
               AMT_TAX_CURR, AMT_TAX, MANUAL_ENTRY, 
               EVRE_COUNT, EVRE_DURATION, MODULE_REF, 
               SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, 
               VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, 
               MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, 
               CURR_CODE, FIXED_CHARGE_VALUE, ADDITIONAL_ENTRY_TEXT) 
            VALUES ( inen_ref_num_s.NEXTVAL, l_invo_rec.ref_num, p_inen_tab(i).AMT_IN_CURR,
               p_inen_tab(i).ROUNDING_INDICATOR, p_inen_tab(i).UNDER_DISPUTE, sec.get_username, 
               sysdate, p_inen_tab(i).EEK_AMT, p_inen_tab(i).BILLING_SELECTOR, 
               p_inen_tab(i).FCIT_TYPE_CODE, p_inen_tab(i).TATY_TYPE_CODE, p_inen_tab(i).SUSG_REF_NUM, 
               p_inen_tab(i).IADN_REF_NUM, p_inen_tab(i).SEC_CURR_CODE, p_inen_tab(i).VMCT_TYPE_CODE, 
               p_inen_tab(i).LAST_UPDATED_BY, p_inen_tab(i).DATE_UPDATED, p_inen_tab(i).DESCRIPTION, 
               p_inen_tab(i).AMT_TAX_CURR, p_inen_tab(i).AMT_TAX, p_inen_tab(i).MANUAL_ENTRY, 
               p_inen_tab(i).EVRE_COUNT, p_inen_tab(i).EVRE_DURATION, c_proc_module_ref, 
               p_inen_tab(i).SEC_FIXED_CHARGE_VALUE, p_inen_tab(i).EVRE_CHAR_USAGE, p_inen_tab(i).PRINT_REQUIRED, 
               p_inen_tab(i).VMCT_RATE_VALUE, p_inen_tab(i).NUM_OF_DAYS, p_inen_tab(i).EVRE_DATA_VOLUME, 
               p_inen_tab(i).MAAS_REF_NUM, p_inen_tab(i).CADC_REF_NUM, p_inen_tab(i).FCDT_TYPE_CODE, 
               p_inen_tab(i).PRI_CURR_CODE, p_inen_tab(i).FIXED_CHARGE_VALUE, p_inen_tab(i).ADDITIONAL_ENTRY_TEXT   
               );
      ELSE
         FORALL i IN p_inen_tab.FIRST .. p_inen_tab.LAST
                INSERT INTO TBCIS.INVOICE_ENTRIES (
                   REF_NUM, INVO_REF_NUM, SEC_AMT, 
                   ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, 
                   DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, 
                   FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, 
                   IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, 
                   LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, 
                   SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, 
                   EVRE_COUNT, EVRE_DURATION, MODULE_REF, 
                   SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, 
                   VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, 
                   MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, 
                   SEC_FF_DISC_AMT, SEC_CURR_CODE, EEK_AMT, 
                   AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, 
                   FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, ACC_AMOUNT, 
                   BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT) 
                VALUES ( inen_ref_num_s.NEXTVAL, l_invo_rec.ref_num, p_inen_tab(i).SEC_AMT,
                   p_inen_tab(i).ROUNDING_INDICATOR, p_inen_tab(i).UNDER_DISPUTE, sec.get_username, 
                   sysdate, p_inen_tab(i).AMT_IN_CURR, p_inen_tab(i).BILLING_SELECTOR, 
                   p_inen_tab(i).FCIT_TYPE_CODE, p_inen_tab(i).TATY_TYPE_CODE, p_inen_tab(i).SUSG_REF_NUM, 
                   p_inen_tab(i).IADN_REF_NUM, p_inen_tab(i).CURR_CODE, p_inen_tab(i).VMCT_TYPE_CODE, 
                   p_inen_tab(i).LAST_UPDATED_BY, p_inen_tab(i).DATE_UPDATED, p_inen_tab(i).DESCRIPTION, 
                   p_inen_tab(i).SEC_AMT_TAX, p_inen_tab(i).AMT_TAX_CURR, p_inen_tab(i).MANUAL_ENTRY, 
                   p_inen_tab(i).EVRE_COUNT, p_inen_tab(i).EVRE_DURATION, c_proc_module_ref, 
                   p_inen_tab(i).SEC_FIXED_CHARGE_VALUE, p_inen_tab(i).EVRE_CHAR_USAGE, p_inen_tab(i).PRINT_REQUIRED, 
                   p_inen_tab(i).VMCT_RATE_VALUE, p_inen_tab(i).NUM_OF_DAYS, p_inen_tab(i).EVRE_DATA_VOLUME, 
                   p_inen_tab(i).MAAS_REF_NUM, p_inen_tab(i).CADC_REF_NUM, p_inen_tab(i).FCDT_TYPE_CODE, 
                   p_inen_tab(i).SEC_FF_DISC_AMT, p_inen_tab(i).SEC_CURR_CODE, p_inen_tab(i).EEK_AMT, 
                   p_inen_tab(i).AMT_TAX, p_inen_tab(i).PRI_CURR_CODE, p_inen_tab(i).FF_DISC_AMT, 
                   p_inen_tab(i).FIXED_CHARGE_VALUE, p_inen_tab(i).SEC_ACC_AMOUNT, p_inen_tab(i).ACC_AMOUNT, 
                   p_inen_tab(i).BILLING_SELECTOR_TEXT, p_inen_tab(i).ENTRY_TEXT, p_inen_tab(i).ADDITIONAL_ENTRY_TEXT);
          END IF;         

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_creating_invoice THEN
         p_success := FALSE;
   END invoice_maac_nonker_serv_fees;
    
    
  PROCEDURE calculate_daily_charges (
       p_start_date DATE
      ,p_end_date DATE 
      ,p_maac_ref_num IN NUMBER DEFAULT NULL
      ,p_susg_ref_num IN NUMBER DEFAULT NULL
      ,p_interim IN BOOLEAN DEFAULT FALSE 
      ,p_bill_cycle  IN  VARCHAR2 DEFAULT NULL 
   ) IS
    CURSOR c_service_type IS
    select distinct sety_ref_num from (
    SELECT prli.sety_ref_num sety_ref_num
               FROM price_lists prli
              WHERE NVL (prli.par_value_charge, 'N') = 'N'
                AND prli.regular_charge = 'Y'
                AND prli.once_off = 'N'
                AND prli.pro_rata = 'Y'  --change to Y
                AND nvl(prli.daily_charge, 'N') = 'Y' --change to Y
                AND prli.start_date < p_end_date + 1
                AND NVL (prli.end_date, p_start_date) >= p_start_date
    UNION
    SELECT ficv.sety_ref_num sety_ref_num
               FROM fixed_charge_values ficv
                   ,fixed_charge_item_types fcit
              WHERE ficv.chca_type_code IS NULL
                AND NVL (ficv.par_value_charge, 'N') = 'N'
                -- CHG-1241                   AND    ficv.charge_value > 0
                AND ficv.fcit_charge_code = fcit.type_code
                AND fcit.regular_charge = 'Y'
                AND fcit.once_off = 'N'
                AND fcit.pro_rata = 'Y' --change to Y
                AND nvl(fcit.daily_charge, 'N') = 'Y' --change to Y
                AND ficv.start_date < p_end_date+1
                AND NVL (ficv.end_date, p_start_date) >= p_start_date
    )
    ;

    CURSOR c_susg IS
    SELECT ref_num susg
    FROM subs_serv_groups
    WHERE     (   p_maac_ref_num IS NULL
                OR TRUNC (suac_ref_num, -3) = p_maac_ref_num)
           AND ( p_susg_ref_num IS NULL OR ref_num = p_susg_ref_num)
    ;
                     
    l_is_large_account NUMBER;
    l_query CLOB;
   
   BEGIN
   
     IF p_maac_ref_num IS NULL AND p_susg_ref_num IS NULL THEN
       IF p_bill_cycle is null THEN  
         DELETE FROM DAILY_CHARGES_DESCR_TEMP;
         DELETE FROM DAILY_CHARGES_INEN_TEMP;
       ELSE
         DELETE FROM DAILY_CHARGES_INEN_TEMP
         where maac in (
            select maac from daily_charges_descr_temp
            where bicy_cycle_code = p_bill_cycle
         );
         DELETE FROM DAILY_CHARGES_DESCR_TEMP
         where bicy_cycle_code = p_bill_cycle;
       END IF;  
     ELSE    
         DELETE FROM DAILY_CHARGES_DESCR_S_TEMP;
         DELETE FROM DAILY_CHARGES_INEN_S_TEMP;
     END IF;    
     FOR service_type_rec IN c_service_type LOOP
        IF p_maac_ref_num IS NULL AND p_susg_ref_num IS NULL THEN
            l_query := main_query(p_one_susg => 'N');
            --dbms_output.put_line(l_query);
            EXECUTE IMMEDIATE l_query USING p_start_date, p_end_date, service_type_rec.sety_ref_num, p_bill_cycle;
        ELSE

            SELECT count(*) 
            INTO l_is_large_account
            FROM bcc_domain_values
            WHERE doma_type_code = 'LAMA' 
            AND value_code = to_char(p_maac_ref_num);
            
            IF l_is_large_account = 0 THEN
                l_query := main_query(p_one_susg => 'Y');
                FOR susg_rec IN c_susg LOOP
                    dbms_output.put_line(susg_rec.susg);
--                    dbms_output.put_line(l_query);
                    EXECUTE IMMEDIATE l_query USING p_start_date, p_end_date, service_type_rec.sety_ref_num, susg_rec.susg, p_bill_cycle;
                END LOOP;
            END IF;
        END IF;                
     END LOOP;
     
     IF p_maac_ref_num IS NULL AND p_susg_ref_num IS NULL THEN
        fill_inen_temp(p_start_date);
     ELSE 
        fill_inen_temp_small(p_start_date);
     END IF;   
   END; 
   
  PROCEDURE calculate_daily_charges (
       p_start_date DATE
      ,p_end_date DATE 
      ,p_maac_ref_num IN NUMBER DEFAULT NULL
      ,p_susg_ref_num IN NUMBER DEFAULT NULL
      ,p_interim IN BOOLEAN DEFAULT FALSE 
      ,p_bill_cycle  IN  VARCHAR2 DEFAULT NULL 
      ,p_success OUT BOOLEAN
      ,p_error_text OUT VARCHAR2
   ) IS
   BEGIN
   calculate_daily_charges (trunc(p_start_date+1-1/24/60/60), trunc(p_end_date), p_maac_ref_num, p_susg_ref_num, p_interim, p_bill_cycle);
   p_success := TRUE;
   EXCEPTION
    WHEN OTHERS THEN
        p_error_text := SQLERRM;
        ROLLBACK;
        p_success := FALSE;
   END;


  PROCEDURE proc_daily_charges_ma (
       p_maac_ref_num  IN      accounts.ref_num%TYPE
      ,p_invo_ref_num  IN      invoices.ref_num%TYPE
      ,p_period_start  IN      DATE
      ,p_period_end    IN      DATE
      ,p_success       OUT     BOOLEAN
      ,p_error_text    OUT     VARCHAR2
      ,p_susg_ref_num  IN      subs_serv_groups.ref_num%TYPE DEFAULT NULL
      ,p_interim       IN      BOOLEAN DEFAULT FALSE
) IS
  l_inen_tab calculate_fixed_charges.t_inen;
  l_success BOOLEAN;
  BEGIN
    calculate_daily_charges (p_period_start, p_period_end, p_maac_ref_num, p_susg_ref_num, p_interim, null, l_success, p_error_text);
    IF l_success THEN
        SELECT 
        null, p_invo_ref_num, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, 
        FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, 
        SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, 
        VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, EEK_AMT, 
        AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT 
        BULK COLLECT INTO l_inen_tab
        FROM TBCIS.DAILY_CHARGES_INEN_S_TEMP;
        invoice_maac_nonker_serv_fees(p_maac_ref_num, p_period_start, l_inen_tab, p_success, p_error_text, p_invo_ref_num, p_interim);
    ELSE
        p_success := FALSE;
    END IF;    
  END;         
       
  PROCEDURE proc_daily_charges (  
       p_bill_cycle  IN  VARCHAR2 DEFAULT NULL 
      ,p_mode        IN  VARCHAR2 DEFAULT c_calculate_mode   -- CALC/RECALC/CONTINUE
   ) IS
      c_module_name        CONSTANT bcc_batch_messages.module_desc%TYPE := 'Process daily charges';
      c_message_nr         CONSTANT NUMBER := 9999;
      c_recalculate_mode   CONSTANT VARCHAR2 (10) := 'RECALC';
      c_continue_mode      CONSTANT VARCHAR2 (10) := 'CONTINUE';

      l_salp_rec                    sales_ledger_periods%ROWTYPE;
      l_period_start_date           DATE;
      l_period_end_date             DATE;
      l_non_ker_proc_rec            tbcis_processes%ROWTYPE;
      l_success                     BOOLEAN;
      l_message                     bcc_batch_messages.MESSAGE_TEXT%TYPE;
      l_error_text                  VARCHAR2(200);
      l_cur_param                   VARCHAR2 (10);
      l_result                      NUMBER;
      l_result_char                 VARCHAR2 (10);
      l_bill_cycle                  VARCHAR2(10);
      
      l_bill_start             DATE; 
      l_bill_cutoff            DATE;
      l_prodn_date             DATE;
      e_initializing                EXCEPTION;
      
  BEGIN
      l_bill_cycle := nvl(p_bill_cycle, 'ALL');
      gen_bill.msg (c_module_ref
                   ,c_module_name
                   ,c_message_nr
                   , 'Protsess käivitatud '||TO_CHAR(SYSDATE, 'dd.mm.yyyy hh24:mi:ss')||'. '
                   , 'BICY = '||l_bill_cycle||'. Mode=' || p_mode
                   ,p_bill_cycle  -- CHG-4482
                   );
      /*
        ** Leiame vaadeldava arveldusperioodi = esimese avatud perioodi info.
      */
      l_salp_rec := gen_bill.first_open_salp_rec;
      l_period_start_date := l_salp_rec.start_date;
      l_period_end_date := TRUNC (l_salp_rec.end_date);

      IF SYSDATE <= l_period_end_date + 1 THEN
         l_message := 'Protsessi ei saa käivitada jooksva perioodi kohta';
         RAISE e_initializing;
      END IF;
      /*
        ** Leiame vastava TBCIS protsessi kirje mitte-KER teenuse jaoks.
      */
      l_non_ker_proc_rec := Tbcis_Common.Get_Tbcis_Process_For_Param (c_module_ref, l_bill_cycle);

      --
      IF p_mode = c_calculate_mode THEN   -- CALC
         IF NVL (l_non_ker_proc_rec.financial_year, 0) = l_salp_rec.financial_year AND
            NVL (l_non_ker_proc_rec.period_num, 0) = l_salp_rec.period_num 
         THEN
            l_message :=    'Protsess on perioodile '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' juba käivitatud. Kasutage ümberhindamise (RECALC) või jätkamise (CONTINUE) võimalust';
            RAISE e_initializing;
         END IF;
      ELSIF p_mode IN (c_recalculate_mode   -- RECALC
                      ,c_continue_mode )    -- CONTINUE
      THEN
         IF TO_CHAR (NVL (l_non_ker_proc_rec.financial_year, 0)) || TO_CHAR (NVL (l_non_ker_proc_rec.period_num, 0)) <>
                                                  TO_CHAR (l_salp_rec.financial_year)
                                                  || TO_CHAR (l_salp_rec.period_num) 
         THEN
            l_message :=    'Protsess ei ole perioodile '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' veel käivitatud. Kasutage esmakordse käivituse (CALC) võimalust';
            RAISE e_initializing;
         END IF;
      ELSE
         IF l_non_ker_proc_rec.module_ref IS NOT NULL THEN  -- CHG-4482: Välistada vea tekkimine protsessi esmakordsel käivitamisel
            l_message :=    'Tundmatu käivitusviis '
                         || p_mode
                         || '. Lubatud on '
                         || c_calculate_mode
                         || ', '
                         || c_recalculate_mode
                         || ', '
                         || c_continue_mode
                         || '.';
            RAISE e_initializing;
         END IF;
      END IF;

      /*
        ** Registreerime protsessi alguse.
        ** Parameetrina on kasutusel viimane MAAC, milline eelmisel käivitusel edukalt töödeldi.
        ** Continue korral on võimalik sellest MAACist edasi minna, CALC/RECALC korral tuleks param väärtus nullida
        ** ja kõik masterid esmakordselt/uuesti töödelda.
      */
      IF p_mode IN (c_calculate_mode      -- CALC
                   ,c_recalculate_mode )  -- RECALC
      THEN
         l_cur_param := NULL;
      ELSE
         l_cur_param := l_non_ker_proc_rec.other_params;  -- CHG-4482: MAACi kasutus uues väljas (vana: module_params)
      END IF;

      --
      Tbcis_Common.Register_Process_Start (p_module_ref     => c_module_ref
                                          ,p_parameter      => l_bill_cycle  -- CHG-4482
                                          ,p_module_desc    => c_module_name
                                          ,p_param_level    => 'Y'           -- CHG-4482
                                          ,p_commit         => 'Y'
                                          ,p_salp_year      => l_salp_rec.financial_year
                                          ,p_salp_month     => l_salp_rec.period_num
                                          ,p_other_params   => l_cur_param   -- CHG-4482
                                          );
      --
      l_non_ker_proc_rec := Tbcis_Common.Get_Tbcis_Process_For_Param (c_module_ref, p_bill_cycle);
      /*
        ** Järgnevalt põhiprotseduur, milles töödeldakse kõigi mobiilide kõik mitte-KER teenused,
        ** millised omavad päevade arvust sõltuvat kuutasu.
      */

--**--**--**--**
      calculate_daily_charges(l_period_start_date, l_period_end_date, null, null, null, p_bill_cycle, l_success, l_error_text);
      IF l_success THEN
          COMMIT;
          gen_bill.msg (c_module_ref ,c_module_name ,c_message_nr
                       , 'Protseduur  calculate_daily_charges lõpetanud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                       , 'BICY = '||l_bill_cycle||'. Mode=' || p_mode);
          create_missing_invoices(l_period_start_date, p_bill_cycle, l_success);
          IF l_success THEN 
              gen_bill.msg (c_module_ref ,c_module_name ,c_message_nr
                           , 'Protseduur  create_missing_invoices lõpetanud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                           , 'BICY = '||l_bill_cycle||'. Mode=' || p_mode);
              IF p_bill_cycle is null THEN 
                insert_invoice_entries;
              ELSE     
                insert_invoice_entries(p_bill_cycle);
              END IF;  
              gen_bill.msg (c_module_ref ,c_module_name ,c_message_nr
                           , 'Protseduur insert_invoice_entries lõpetanud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                           , 'BICY = '||l_bill_cycle||'. Mode=' || p_mode);
              merge_subs_discounts(p_bill_cycle);
          END IF;    
      END IF;
--**--**--**--**
      --
      IF NOT l_success THEN
         l_result := 0;
         l_result_char := 'vigadega';
         --
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, l_message, NULL, l_bill_cycle);
      ELSE
         l_result := 1;
         l_result_char := 'edukalt';
      END IF;

      /*
        ** Märgime mitte-KER teenuste töötlemise lõpetatuks.
      */
      Tbcis_Common.Register_Process_End
                             (c_module_ref   -- IN VARCHAR2
                             ,l_bill_cycle   -- p_parameter      IN VARCHAR2 -- CHG-4482
                             ,l_result   -- p_result         IN NUMBER
                             ,'Y'   -- p_param_level    CHG-4482: N -> Y
                             ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                             );
      /*
        ** Registreerime lõpetamise teate.
      */
      gen_bill.msg (c_module_ref
                   ,c_module_name
                   ,c_message_nr
                   , 'Protsess ' || l_result_char || ' lõpetanud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                   , 'BICY = '||l_bill_cycle||'. Mode=' || p_mode
                   ,l_bill_cycle  -- CHG-4482
                   );
      COMMIT;                   
   EXCEPTION
      WHEN e_initializing THEN
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, l_message, NULL, l_bill_cycle);
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Protsess lõpetanud veaga ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                      , 'BICY = '||l_bill_cycle||'. Mode=' || p_mode
                      ,l_bill_cycle 
                      );
      WHEN OTHERS THEN
         ROLLBACK;
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, SQLERRM, NULL, l_bill_cycle);
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Protsess lõpetanud veaga ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                      , 'BICY = '||l_bill_cycle||'. Mode=' || p_mode
                      ,l_bill_cycle 
                      );

  END;

END PROCESS_DAILY_CHARGES;
/