select * from fixed_charge_item_types

iprocess_monthly_service_fees

calculate_fixed_charges

calculate_discounts


proc_mobile_nonker_serv_fees

2978944000	15814200
2978944000	15814204

select case when t.mixed_packet_code is null AND nvl(inen.eek_amt,0) != 0 then  nvl(ficv_charge_value,prli_charge_value)/30*nvl(inen.num_of_days,30) else 1 end / 
       case when t.mixed_packet_code is null AND nvl(inen.eek_amt,0) != 0 then inen.eek_amt else 1 end z1 , 
t.*, 'XXX1' x1, invo.*, 'XXX2' x2, inen.*, 'XXX3' x3, inen2.*, 'XXX4' x4, comc.*   
from aj_temp_1 t
LEFT JOIN invoices invo ON t.maac= invo.maac_ref_num and invo.billing_inv = 'Y' AND invo.period_start BETWEEN date '2018-09-01' AND date '2018-09-30' 
LEFT JOIN invoice_entries inen ON inen.invo_ref_num = invo.ref_num and inen.susg_Ref_num = t.susg  and inen.fcit_type_code = t.fcit_type_code
                                   and inen.billing_selector = t.fcit_billing_selector
LEFT JOIN invoice_entries inen2 ON inen2.invo_ref_num = invo.ref_num and inen2.susg_Ref_num = t.susg  and inen2.fcit_type_code = t.monthly_fcit_type_code
                                   and inen2.billing_selector = t.monthly_billing_selector
LEFT JOIN common_monthly_charges comc ON comc.invo_ref_num = invo.ref_num and comc.susg_Ref_num = t.susg  and comc.fcit_type_code = t.fcit_type_code
                                   and comc.billing_selector = t.fcit_billing_selector
where t.maac =2983471000
--order by maac, susg



select /*+ MONITOR */ t.*, 'XXXXX' x1, --cadc.*, 'XXXXX2' x2, 
sudi.*  , 'XXXXX2' x2, cadc.*
from aj_temp_1 t 
left join subs_discounts sudi ON sudi.susg_ref_num = t.susg AND sudi.cadc_ref_num IS NULL AND NVL (sudi.closed, 'N') <> 'Y'
LEFT JOIN call_discount_codes cadc ON cadc.for_fcit_type_code = t.fcit_type_code and cadc.for_billing_selector = t.fcit_billing_selector and cadc.call_type = 'REGU'
                                     and date '2018-09-30' BETWEEN cadc.start_date AND NVL (cadc.end_date, date '2018-09-30') and NVL (cadc.discount_completed, 'N') <> 'Y'
                                     and nvl(cadc.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num -- and cadc.dico_ref_num = sudi.dico_ref_num
where t.maac =2662118000
order by t.MAAC, t.susg

select * from aj_temp_1 t 
where t.susg =13710290




select greatest(sudi.start_date, cadc.start_date, :p_start_date) disc_start,  
least(sudi.end_date, cadc.end_date, ADD_MONTHS(sudi_start_date, NVL(cadc.count_for_months,0))+NVL(cadc.count_for_days)  :p_start_date) disc_end, *
from (
select * from  call_discount_codes cadc where cadc.call_type = 'REGU'
                                     and NVL (cadc.end_date, :p_start_date) >= :p_start_date
                                     and cadc.start_date < :p_end_date + 1
                                     and NVL (cadc.discount_completed, 'N') <> 'Y'
) cadc
join subs_discounts sudi ON sudi.cadc_ref_num IS NULL AND NVL (sudi.closed, 'N') <> 'Y'  
	                                       and cadc.dico_ref_num = sudi.dico_ref_num   
                                              and NVL (sudi.end_date, :p_start_date) >= _p_start_date
                                              and sudi.start_date < :p_end_date + 1
                            AND ( NVL(sudi.end_date,ADD_MONTHS (sudi.start_date, NVL (cadc.count_for_months, 0))
                                  + NVL (cadc.count_for_days, 0)) >= :p_start_date
                               OR (cadc.count_for_days IS NULL AND cadc.count_for_months IS NULL)
                              )
                            and (sudi.padi_ref_num is null OR (sudi.padi_ref_num is not null AND 
                                                                   exists (select 1 from part_dico_details padd 
                                                                             where PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                                             and padd.cadc_ref_num = cadc.ref_num)))
left join part_dico_details padd ON PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                   and padd.cadc_ref_num = cadc.ref_num


select * from part_dico_details
where padi_ref_num in (13200, 9643)

select * from party_discounts
where ref_num in (13200, 9643)

select * from discount_codes where ref_num in (18942, 20518)

MAAC, SUSG, PERIOD_CHARGE, FCIT_BILLING_SELECTOR, FCIT_TYPE_CODE, FCIT_BISE, FCIT_DESC, DISC_BILLING_SELECTOR, DISC_BISE, DESCRIPTION, FCIT_FCDT_TYPE_CODE, REF_NUM, DISCOUNT
525000	15216922	16.99	KTO	GGW	Teenuste kuutasud	Interneti kuutasu	KTS	Teenuste kuutasude soodustus	Mobiilne internet 12GB äri	GGWD	21291	8.49

create table aj_temp_3 as
SELECT invo.maac_ref_num maac, 
       inen.SUSG_REF_NUM susg,
       inen.ACC_AMOUNT period_charge,
       inen.BILLING_SELECTOR fcit_billing_selector,       
       inen.FCIT_TYPE_CODE,
       inen.BILLING_SELECTOR_TEXT fcit_bise,
       inen.ENTRY_TEXT fcit_desc,
       inen.BILLING_SELECTOR disc_billing_selector,       
       inen.BILLING_SELECTOR_TEXT disc_bise,
       inen.ENTRY_TEXT disc_descr,
       inen.fcdt_type_code fcit_fcdt_type_code, 
       inen.cadc_ref_num,
       inen.acc_amount discount 
  FROM TBCIS.INVOICE_ENTRIES inen, invoices invo
  where inen.invo_ref_num = invo.ref_num  
  and inen. susg_ref_num in (15216922)
  and (inen.billing_selector = 'KTO' AND inen.fcit_type_code like 'G%' OR inen.billing_selector = 'KTS' AND inen.fcdt_type_code like 'G%')
  and 1=0   
and trunc(inen.date_created) = date '2018-10-01';


select * from fixed_charge_types

select * from fixed_charge_item_types

select * from price_lists

select * from aj_temp_32
minus
select * from aj_temp_33

SELECT MAAC,
       SUSG,
       PERIOD_CHARGE,
       FCIT_BILLING_SELECTOR,
       FCIT_TYPE_CODE,
       FCIT_BISE,
       FCIT_DESC,
       DISC_BILLING_SELECTOR,
       DISC_BISE,
       DISC_DESCR,
       FCIT_FCDT_TYPE_CODE,
       CADC_REF_NUM,
       DISCOUNT,
 case when  discount is null then null else START_DATE_CORR end   START_DATE_CORR,
 case when  discount is null then null else END_DATE_CORR end      END_DATE_CORR,
  case when discount is null then null else PERIOD_DAYS_CORR end     PERIOD_DAYS_CORR,
       SEPV_START_REAL,
       SUDI_END,
       PERIOD_DAYS_MAIN,
       START_DATE_MAIN,
       END_DATE_MAIN,
       SUDI_REF_NUM
  FROM TBCIS.AJ_TEMP_32
  where (period_charge != 0 or nvl(discount, 0) != 0)
  and susg=15391370
  
union all
--minus

SELECT MAAC,
       SUSG,
       PERIOD_CHARGE,
       FCIT_BILLING_SELECTOR,
       FCIT_TYPE_CODE,
       FCIT_BISE,
       FCIT_DESC,
  case when  discount is null then null else DISC_BILLING_SELECTOR end     DISC_BILLING_SELECTOR,
  case when  discount is null then null else DISC_BISE end     DISC_BISE,
  case when  discount is null then null else DISC_DESCR end     DISC_DESCR,
       FCIT_FCDT_TYPE_CODE,
  case when  discount is null then null else CADC_REF_NUM end     CADC_REF_NUM,
       DISCOUNT,
 case when  discount is null then null else START_DATE_CORR end   START_DATE_CORR,
 case when  discount is null then null else END_DATE_CORR end      END_DATE_CORR,
  case when discount is null then null else PERIOD_DAYS_CORR end     PERIOD_DAYS_CORR,
       SEPV_START_REAL,
  case when  discount is null then null else SUDI_END end     SUDI_END,
       PERIOD_DAYS_MAIN,
       START_DATE_MAIN,
       END_DATE_MAIN,
  case when  discount is null then null else SUDI_REF_NUM end     SUDI_REF_NUM
from aj_temp_33
where susg=15391370

order by sudi_ref_num, cadc_ref_num


with q1 as (
select MAAC_REF_NUM, SUSG_REF_NUM, sum(EEK_AMT) eek_amt, BILLING_SELECTOR, FCIT_TYPE_CODE, BILLING_SELECTOR_TEXT, ENTRY_TEXT, FCDT_TYPE_CODE, CADC_REF_NUM, sepv_start_real, 
ITYPE from  (
SELECT invo.maac_ref_num, 
       inen.SUSG_REF_NUM,
       case when invo.credit = 'Y' then -inen.eek_amt else inen.EEK_AMT end eek_amt,
       inen.BILLING_SELECTOR,       
       inen.FCIT_TYPE_CODE,
       inen.BILLING_SELECTOR_TEXT,
       inen.ENTRY_TEXT,
       inen.fcdt_type_code, 
       inen.cadc_ref_num, 
       null sepv_start_real,
       'INEN' itype
  FROM TBCIS.INVOICE_ENTRIES inen, invoices invo
  where inen.invo_ref_num = invo.ref_num
  and (inen.billing_selector = 'KTO' AND inen.fcit_type_code like 'G%' OR inen.billing_selector = 'KTS' AND inen.fcdt_type_code like 'G%' OR inen.billing_selector = 'TTO' AND inen.fcit_type_code like 'GMT')
and invo.salp_fina_year = 2018 and invo.salp_per_num = 10
and invo.billed='Y' and invo.billing_inv='Y'
UNION ALL
select invo.maac_ref_num,
       comc.SUSG_REF_NUM,
       case when nvl(comc.fixed_charge_value,0) = 0 then comc.eek_amt else case when comc.num_of_days < 31 then comc.eek_amt else comc.fixed_charge_value end end,
       comc.BILLING_SELECTOR,       
       comc.FCIT_TYPE_CODE,
       null BILLING_SELECTOR_TEXT,
       null ENTRY_TEXT,
       null fcdt_type_code, 
       null cadc_ref_num,
       null sepv_start_real,
       'COMC' itype
from common_monthly_charges comc, invoices invo
where comc.invo_ref_num = invo.ref_num
and invo.salp_fina_year = 2018 and invo.salp_per_num = 10
and invo.billed='Y' and invo.billing_inv='Y'
and (comc.billing_selector = 'KTO' AND comc.fcit_type_code like 'G%' OR comc.billing_selector = 'TTO' AND comc.fcit_type_code like 'GMT')
)
group by MAAC_REF_NUM, SUSG_REF_NUM, BILLING_SELECTOR, FCIT_TYPE_CODE, BILLING_SELECTOR_TEXT, ENTRY_TEXT, FCDT_TYPE_CODE, CADC_REF_NUM, sepv_start_real, ITYPE 
), q2 as (
select maac, susg, case when pcda.price is null then aj3.period_charge 
                        when pcda.price < 0 then aj3.period_charge + pcda.price 
                        else pcda.price - nvl(aj3.discount,0) end period_charge, 
aj3.fcit_billing_selector, aj3.fcit_type_code, aj3.fcit_bise, aj3.fcit_desc, null fcdt_type_code, null cadc_ref_num, sepv_start_real  
from aj_temp_33 aj3 , public_contract_data pcda
where aj3.period_charge > 0
  and aj3.susg = pcda.susg_ref_num(+)
  and aj3.fcit_type_code = pcda.fcit_type_code(+)  
and  pcda.end_date(+) >= date '2018-10-01'
and  pcda.start_date(+) <= date '2018-10-31'
union all
select maac, susg, discount, disc_billing_selector, null, disc_bise, disc_descr, fcit_fcdt_type_code, cadc_ref_num , sepv_start_real 
from aj_temp_33
where discount < 0
)
select count(distinct maac_ref_num) over (partition by null) c_maac,  count(distinct susg_ref_num) over (partition by null) c_susg,
MAAC_REF_NUM, SUSG_REF_NUM, EEK_AMT, BILLING_SELECTOR, FCIT_TYPE_CODE, 
case comc_flag when 1 then null else BILLING_SELECTOR_TEXT end BILLING_SELECTOR_TEXT, case comc_flag when 1 then null else ENTRY_TEXT end ENTRY_TEXT, 
FCDT_TYPE_CODE, CADC_REF_NUM, sepv_start_real, sum(CURR), sum(PROJECTED) from ( 
select MAAC_REF_NUM, SUSG_REF_NUM, EEK_AMT, BILLING_SELECTOR, FCIT_TYPE_CODE, BILLING_SELECTOR_TEXT, ENTRY_TEXT, FCDT_TYPE_CODE, CADC_REF_NUM,
max(sepv_start_real) over (partition by susg_ref_num) sepv_start_real, 
itype, max(decode(itype, 'COMC', 1, 0)) over (partition by susg_ref_num) comc_flag,  CURR, PROJECTED from (
select q1.*, 1 curr, 0 projected from q1
union all
select q2.*, 'PROJ' itype, 0 curr, 1 projected  from q2
)
)
group by MAAC_REF_NUM, SUSG_REF_NUM, EEK_AMT, BILLING_SELECTOR, FCIT_TYPE_CODE, 
case comc_flag when 1 then null else BILLING_SELECTOR_TEXT end, case comc_flag when 1 then null else ENTRY_TEXT end, FCDT_TYPE_CODE, CADC_REF_NUM, sepv_start_real 
having  not (sum(curr) = 1 and sum(projected) = 1)
order by 4

select * from aj_temp_32
minus 
select * from aj_temp_31

select * from aj_temp_31
minus 
select * from aj_temp_32

select * from aj_temp_31
where susg = 13348141
union all
select * from aj_temp_32
where susg = 13348141

13893128
13348141


with q1 as (
SELECT invo.maac_ref_num, 
       inen.SUSG_REF_NUM,
       inen.EEK_AMT,
       inen.BILLING_SELECTOR,       
       inen.FCIT_TYPE_CODE,
       inen.BILLING_SELECTOR_TEXT,
       inen.ENTRY_TEXT,
       inen.fcdt_type_code, 
       inen.cadc_ref_num, 
       'INEN' itype
  FROM TBCIS.INVOICE_ENTRIES inen, invoices invo
  where inen.invo_ref_num = invo.ref_num  
  and (inen.billing_selector = 'KTO' AND inen.fcit_type_code like 'G%' OR inen.billing_selector = 'KTS' AND inen.fcdt_type_code like 'G%' OR inen.billing_selector = 'TTO' AND inen.fcit_type_code like 'GMT')
and invo.salp_fina_year = 2018 and invo.salp_per_num = 10
and invo.billed='Y'
UNION ALL
select invo.maac_ref_num,
       comc.SUSG_REF_NUM,
       case when nvl(comc.fixed_charge_value,0) = 0 then comc.eek_amt else comc.fixed_charge_value end,
       comc.BILLING_SELECTOR,       
       comc.FCIT_TYPE_CODE,
       null BILLING_SELECTOR_TEXT,
       null ENTRY_TEXT,
       null fcdt_type_code, 
       null cadc_ref_num,
       'COMC' itype
from common_monthly_charges comc, invoices invo
where comc.invo_ref_num = invo.ref_num
and invo.salp_fina_year = 2018 and invo.salp_per_num = 10
and invo.billed='Y'
and (comc.billing_selector = 'KTO' AND comc.fcit_type_code like 'G%' OR comc.billing_selector = 'TTO' AND comc.fcit_type_code like 'GMT') 
), q2 as (
select maac, susg, period_charge, fcit_billing_selector, fcit_type_code, fcit_bise, fcit_desc, null fcdt_type_code, null cadc_ref_num  
from aj_temp_3
where period_charge > 0
union all
select maac, susg, discount, disc_billing_selector, null, disc_bise, disc_descr, fcit_fcdt_type_code, cadc_ref_num  
from aj_temp_3 
where discount < 0
)
select * from q1


select MAAC_REF_NUM, SUSG_REF_NUM, EEK_AMT, BILLING_SELECTOR, FCIT_TYPE_CODE, 
case comc_flag when 1 then null else BILLING_SELECTOR_TEXT end BILLING_SELECTOR_TEXT, case comc_flag when 1 then null else ENTRY_TEXT end ENTRY_TEXT, 
FCDT_TYPE_CODE, CADC_REF_NUM, sum(CURR), sum(PROJECTED) from ( 
select MAAC_REF_NUM, SUSG_REF_NUM, EEK_AMT, BILLING_SELECTOR, FCIT_TYPE_CODE, BILLING_SELECTOR_TEXT, ENTRY_TEXT, FCDT_TYPE_CODE, CADC_REF_NUM, itype,
      max(decode(itype, 'COMC', 1, 0)) over (partition by susg_ref_num) comc_flag,  CURR, PROJECTED from (
select q1.*, 1 curr, 0 projected from q1
union all
select q2.*, 'PROJ' itype, 0 curr, 1 projected  from q2
)
)
group by MAAC_REF_NUM, SUSG_REF_NUM, EEK_AMT, BILLING_SELECTOR, FCIT_TYPE_CODE, 
case comc_flag when 1 then null else BILLING_SELECTOR_TEXT end, case comc_flag when 1 then null else ENTRY_TEXT end, FCDT_TYPE_CODE, CADC_REF_NUM 
having sum(curr) != sum(projected)
order by 2



select * from aj_temp_3

select * from aj_temp_2
where susg= 14619011

select * from invoices
where maac_ref_num = 2824158000


select * from invoice_entries
where susg_ref_num = 4172
order by billing_selector, date_created



order by billing_selector, invo_ref_num

select * from aj_temp_3

truncate table aj_temp_3

insert into aj_temp_3



with q1 as (
select greatest(sudi.start_date, cadc.cadc_start_date, :p_start_date) disc_start
,least(nvl(trunc(sudi.end_date), :p_end_date), cadc.cadc_end_date, 
   case when cadc.count_for_months is not null or cadc.count_for_days is not null then ADD_MONTHS(sudi.start_date, NVL(cadc.count_for_months,0))+NVL(cadc.count_for_days,0) else  :p_end_date end,
   :p_end_date) disc_end
,cadc.*,
sudi.REF_NUM sudi_ref_num0, SUSG_REF_NUM, sudi.DISCOUNT_CODE sudi_discount_code, CONNECTION_EXIST, SUDI_REF_NUM, CLOSED, REASON_CODE, sudi.DATE_CREATED sudi_date_created, 
sudi.CREATED_BY sudi_created_by, sudi.DATE_UPDATED sudi_date_updated, sudi.LAST_UPDATED_BY sudi_last_update_by, DOC_TYPE, DOC_NUM, sudi.START_DATE sudi_start_date, sudi.END_DATE sudi_end_date, 
sudi.CADC_REF_NUM sudi_cadc_ref_num, sudi.DICO_REF_NUM sudi_dico_ref_num, SEC_AMT, DICO_SUDI_REF_NUM, sudi.SEC_CURR_CODE sudi_sec_curr_code, EEK_AMT, sudi.CURR_CODE sudi_curr_code, MIXED_PACKET_CODE, 
sudi.PADI_REF_NUM, USRE_REF_NUM, CAOF_REF_NUM, padi.PADI_REF_NUM padi_padi_ref_num, padi.CADC_REF_NUM padi_cadc_ref_num, 
DISC_PERCENTAGE, DISC_ABSOLUTE, PRICE, padi.CREATED_BY padi_created_by, padi.DATE_CREATED padi_date_created, padi.LAST_UPDATED_BY padi_last_updated_by, padi.DATE_UPDATED padi_date_updated
from (
select greatest(nvl(cadc.start_date, :p_start_date), :p_start_date) cadc_start_date,
least(nvl(trunc(cadc.end_date), :p_end_date), :p_end_date) cadc_end_date,  
cadc.* 
from  call_discount_codes cadc, discount_codes dico 
where cadc.call_type = 'REGU'
and cadc.dico_ref_num = dico.ref_num
and NVL (cadc.end_date, :p_start_date) >= :p_start_date
and cadc.start_date < :p_end_date + 1
and NVL (cadc.discount_completed, 'N') <> 'Y'
and dico.for_all = 'N'
) cadc
join subs_discounts sudi ON sudi.cadc_ref_num IS NULL AND NVL (sudi.closed, 'N') <> 'Y'  and cadc.dico_ref_num = sudi.dico_ref_num   
                                              and NVL (sudi.end_date, :p_start_date) >= :p_start_date
                                              and sudi.start_date < :p_end_date + 1
                            AND (NVL(sudi.end_date,ADD_MONTHS (sudi.start_date, NVL (cadc.count_for_months, 0))
                                  + NVL (cadc.count_for_days, 0)) >= :p_start_date
                                  OR (cadc.count_for_days IS NULL AND cadc.count_for_months IS NULL)
                                )  
                            and (sudi.padi_ref_num is null OR (sudi.padi_ref_num is not null AND exists (select 1 from part_dico_details padd 
                                                                             where PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                                             and padd.cadc_ref_num = cadc.ref_num) ))
left join part_dico_details padi ON PADI.PADI_REF_NUM = sudi.padi_ref_num
                                                   and padi.cadc_ref_num = cadc.ref_num
), q2 as (
SELECT greatest(nvl(cadc.start_date, :p_start_date), :p_start_date) start_date,
   least(nvl(trunc(cadc.end_date), :p_end_date), :p_end_date) end_date,  
   cadc.REF_NUM, cadc.DISCOUNT_CODE, cadc.START_BILL_PERIOD, cadc.NEXT_BILL_PERIOD, cadc.SEC_AMOUNT, cadc.CALL_TYPE, cadc.FCIT_TYPE_CODE, cadc.BILLING_SELECTOR, cadc.DISCOUNT_COMPLETED, 
   cadc.DATE_CREATED, cadc.CREATED_BY, cadc.DATE_UPDATED, cadc.LAST_UPDATED_BY, cadc.SEPT_TYPE_CODE, cadc.END_BILL_PERIOD, cadc.SUBS_DISCOUNT_CODE, cadc.NEW_MOBILE, cadc.DURATION, 
   cadc.SUMMARY_DISCOUNT, cadc.PRECENTAGE, cadc.DICO_REF_NUM, cadc.DESCRIPTION, cadc.TATY_TYPE_CODE, cadc.START_DATE cadc_start_date, cadc.END_DATE cadc_end_date, cadc.PRIORITY, 
   cadc.COUNT_FOR_MONTHS, cadc.COUNT_FOR_DAYS, cadc.FROM_DAY, cadc.FOR_DAY_CLASS, cadc.FOR_CHAR_ANAL_CODE, cadc.FOR_BILLING_SELECTOR, cadc.FOR_FCIT_TYPE_CODE, cadc.FOR_SETY_REF_NUM, 
   cadc.FOR_SEPV_REF_NUM, cadc.DISC_BILLING_SELECTOR, cadc.PRINT_REQUIRED, cadc.CRM, cadc.COUNT, cadc.TIME_BAND_START, cadc.TIME_BAND_END, cadc.SEC_MONTHLY_AMOUNT, cadc.CHG_DURATION, 
   cadc.PERIOD_SEK, cadc.SEC_MINIMUM_PRICE, cadc.SINGLE_COUNT, cadc.DECREASE, cadc.PRICING, cadc.CHCA_TYPE_CODE, cadc.BILL_SEL_SUM, cadc.FROM_COUNT, cadc.MIN_PRICE_UNIT, 
   cadc.SEC_CONTROL_AMOUNT, cadc.SEC_INVO_AMOUNT, cadc.SEC_INVE_AMOUNT, cadc.SEC_CURR_CODE, cadc.AMOUNT, cadc.CONTROL_AMOUNT, cadc.CURR_CODE, cadc.INVE_AMOUNT, cadc.INVO_AMOUNT, 
   cadc.MINIMUM_PRICE, cadc.MONTHLY_AMOUNT, cadc.CALC, cadc.MIXED_SERVICE,
   dico.DISCOUNT_CODE dico_discount_code, dico.DESCRIPTION dico_description, dico.DISCOUNT_PERCENT, dico.START_DATE dico_start_date, dico.END_DATE dico_end_date, 
   dico.CREATED_BY dico_created_by, dico.DATE_CREATED dico_created, dico.LAST_UPDATED_BY dico_last_updated_by, dico.DATE_UPDATED dico_date_upated, 
   dico.PRINT_REQUIRED dico_print_required, dico.DISCOUNT_TYPE, dico.PARENT_DISCOUNT, dico.CRM dico_crm, dico.VMCT_MAAC_TYPE, dico.MOBILE_PART, 
   dico.DISC_BILLING_SELECTOR dico_disc_billing_selector, dico.REF_NUM dico_ref_num0, dico.PARENT_DICO_REF_NUM, 
   dico.EXCLUDE_DICO_REF_NUM, dico.PARENT_SPOC_REF_NUM, dico.SEVERAL_MAAC, dico.SEVERAL_MOBILE, dico.PARTY_TYPE, dico.MONTH_OF_SERV, dico.NEW_MAAC, dico.ALLOWED_COUNT, dico.GIVEN_COUNT, 
   dico.NEW_MOBILE dico_new_mobile, dico.FOR_ALL, dico.MANUAL, dico.DEALER_ALLOWED, dico.ORDER_TYPE, dico.PART_MONTH_OF_SERV, dico.SHORT_DESCRIPTION, dico.SMS_TEXT_TYPE, dico.DOMA_TYPE_CODE, 
   dico.PACKAGE_IMPACT, dico.DISCOUNT_SUSPEND, dico.SHOW_ITB, dico.VMCT_TYPE_CODE, dico.PADI_SEQ
from  call_discount_codes cadc, discount_codes dico
WHERE cadc.dico_ref_num = dico.ref_num 
and cadc.call_type = 'REGU'
and NVL (cadc.end_date, :p_start_date) >= :p_start_date
and cadc.start_date < :p_end_date + 1
and NVL (cadc.discount_completed, 'N') <> 'Y'
and NVL (dico.end_date, :p_start_date) >= :p_start_date
and dico.start_date < :p_end_date + 1
and cadc.start_date <= nvl(dico.end_date, cadc.start_date)
and dico.start_date <= nvl(cadc.end_date, dico.start_date) 
AND dico.manual = 'Y'
and dico.for_all = 'Y'
)
select maac, susg, 
--starts, ends, disc_start, disc_end,  ----COMMENT  
round(charge_value*period_days_corr/month_days,2) period_charge, 
--monthly_disc_rate, monthly_markdown, precentage, minimum_price, pricing, price,  ----COMMENT
fcit_billing_selector, fcit_type_code, fcit_bise,  fcit_desc,  disc_billing_selector, disc_bise, description disc_descr, fcit_fcdt_type_code, ref_num cadc_ref_num,
-case when disc_start is not null then 
    case when monthly_disc_rate is not null or monthly_markdown is not null  or (station_param='MINU' and station_type='TSV') then
      null
    else
      case when price is not null or disc_percentage is not null or disc_absolute is not null then
         round(greatest(charge_value-price, 0)*period_days_corr/month_days, 2)
      else
        case when pricing = 'Y' then
          round((charge_value - least((nvl(precentage,100)/100)*charge_value, least(nvl(minimum_price, charge_value), charge_value)))*period_days_corr/month_days, 2)
        else
          round(greatest((nvl(precentage,0)/100)*charge_value, least(nvl(minimum_price, 0), charge_value))*period_days_corr/month_days, 2)
        end
      end
    end
else
  null  
end discount
--, qq3.*  ----COMMENT
from (
select case when disc_start is null then starts else startx end start_date_corr,
case when disc_start is null then trunc(ends) else case when next_startx is null or next_startx > endx then endx else next_startx-1 end  end end_date_corr,
case when disc_start is null then trunc(ends) else case when next_startx is null or next_startx > endx then endx else next_startx-1 end  end + 1 -  
   case when disc_start is null then starts else startx end  period_days_corr,
nvl(ficv_charge_value, prli_charge_value) charge_value,
qq2.* 
from (
select lead(startx) over (partition by susg order by startx, endx) next_startx,  
qq.*  
from (
select greatest(starts, disc_start) startx, least(trunc(ends), disc_end) endx,  
add_months(trunc(:p_start_date), 1) -trunc(:p_start_date) month_days, ends + 1/24/60/60 - starts  period_days,
--case when disc_start is null then null else least(ends+1/24/60/60, disc_end+1) - greatest(starts, disc_start) end disc_days,
bcdv1.description fcit_bise, bcdv2.description disc_bise, bcdv3.description disc_all_bise, 
t.*,
q1.DISC_START, q1.DISC_END, q1.REF_NUM, q1.DISCOUNT_CODE, q1.START_BILL_PERIOD, q1.NEXT_BILL_PERIOD, q1.SEC_AMOUNT, q1.CALL_TYPE, q1.FCIT_TYPE_CODE cadc_fcit_type_code, q1.BILLING_SELECTOR, 
q1.DISCOUNT_COMPLETED, q1.DATE_CREATED, q1.CREATED_BY, q1.DATE_UPDATED, q1.LAST_UPDATED_BY, q1.SEPT_TYPE_CODE cadc_sept_type_code, q1.END_BILL_PERIOD, q1.SUBS_DISCOUNT_CODE, q1.NEW_MOBILE, 
q1.DURATION, q1.SUMMARY_DISCOUNT, q1.PRECENTAGE, q1.DICO_REF_NUM, q1.DESCRIPTION, q1.TATY_TYPE_CODE, q1.CADC_START_DATE, q1.CADC_END_DATE, q1.PRIORITY, q1.COUNT_FOR_MONTHS, q1.COUNT_FOR_DAYS, 
q1.FROM_DAY, q1.FOR_DAY_CLASS, q1.FOR_CHAR_ANAL_CODE, q1.FOR_BILLING_SELECTOR, q1.FOR_FCIT_TYPE_CODE, q1.FOR_SETY_REF_NUM, q1.FOR_SEPV_REF_NUM, q1.DISC_BILLING_SELECTOR, q1.PRINT_REQUIRED, 
q1.CRM, q1.COUNT, q1.TIME_BAND_START, q1.TIME_BAND_END, q1.SEC_MONTHLY_AMOUNT, q1.CHG_DURATION, q1.PERIOD_SEK, q1.SEC_MINIMUM_PRICE, q1.SINGLE_COUNT, q1.DECREASE, q1.PRICING, 
q1.CHCA_TYPE_CODE, q1.BILL_SEL_SUM, q1.FROM_COUNT, q1.MIN_PRICE_UNIT, q1.SEC_CONTROL_AMOUNT, q1.SEC_INVO_AMOUNT, q1.SEC_INVE_AMOUNT, q1.SEC_CURR_CODE, q1.AMOUNT, 
q1.CONTROL_AMOUNT, q1.CURR_CODE, q1.INVE_AMOUNT, q1.INVO_AMOUNT, q1.MINIMUM_PRICE, q1.MONTHLY_AMOUNT, q1.CALC, q1.MIXED_SERVICE, q1.SUDI_REF_NUM0, q1.SUSG_REF_NUM, q1.SUDI_DISCOUNT_CODE, 
q1.CONNECTION_EXIST, q1.SUDI_REF_NUM, q1.CLOSED, q1.REASON_CODE, 
SUDI_DATE_CREATED, SUDI_CREATED_BY, SUDI_DATE_UPDATED, SUDI_LAST_UPDATE_BY, DOC_TYPE, DOC_NUM, SUDI_START_DATE, SUDI_END_DATE, SUDI_CADC_REF_NUM, SUDI_DICO_REF_NUM, SEC_AMT, DICO_SUDI_REF_NUM, 
SUDI_SEC_CURR_CODE, EEK_AMT, SUDI_CURR_CODE, q1.MIXED_PACKET_CODE sudi_mixed_packet_code, PADI_REF_NUM, USRE_REF_NUM, CAOF_REF_NUM, padi_padi_ref_num, padi_cadc_ref_num, 
DISC_PERCENTAGE, DISC_ABSOLUTE, PRICE, padi_created_by, padi_date_created, padi_last_updated_by, padi_date_updated
from aj_temp_2 t left join q1 on q1.susg_ref_num = t.susg and q1.for_fcit_type_code = t.fcit_type_code and q1.for_billing_selector = t.fcit_billing_selector
                                 and nvl(q1.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num
                 left join q2 on q2.for_fcit_type_code = t.fcit_type_code and q2.for_billing_selector = t.fcit_billing_selector
                                 and nvl(q2.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num
                 LEFT join bcc_domain_values bcdv1 on bcdv1.value_code = t.fcit_billing_selector and bcdv1.doma_type_code = 'BISE'
                 left join bcc_domain_values bcdv2 on bcdv2.value_code = q1.disc_billing_selector and bcdv2.doma_type_code = 'BISE'
                 left join bcc_domain_values bcdv3 on bcdv3.value_code = q2.disc_billing_selector and bcdv3.doma_type_code = 'BISE'
where 1=1
and t.susg = 5554
--and t.mixed_packet_code is not null
--and ref_num is not null
--and monthly_markdown is not null
--and susg in (14556708, 14187291, 13647015)
--and susg=15399650
--and susg=14946136
--and susg=11773459
--and susg in (14381968, 14946136, 14363640)
--and susg = 14789323
--and susg in (3577785)
--and susg in (11532124,15823801,4885009,9457163,12646971,3840741,4534183,14973743,15332260,14147754,11864467,12492643,15595759,12985931,13330415,13348141,13416850,13997873,13997873,15395199,
--14938623,15333495,15388264)
) qq
where 1=1
and starts <= nvl(disc_end, starts)
and nvl(disc_start, trunc(ends)) <= trunc(ends) 
--and disc_start is not null and period_days != 30
--and(nvl(precentage, 0) != 0 or minimum_price is not null)
--and case when disc_start is null then null else least(ends+1/24/60/60, disc_end+1) - greatest(starts, disc_start) end != period_days 
--and padi_ref_num is not null 
--and price is not null --or disc_amount is not null 
--and fcit_desc != 'Interneti kuutasu' --and minimum_price is not null and pricing = 'Y'
--and (monthly_markdown is not null or monthly_disc_rate is not null)
--and minimum_price > nvl(ficv_charge_value, prli_charge_value)*period_days/month_days
) qq2
) qq3
where end_date_corr >= start_date_corr
----------
--and period_days_corr = month_days
--and sepv_start_real < :p_start_date
--and nvl(add_months(trunc(sudi_start_date), count_for_months), sysdate) != :p_end_date
and sety_ref_num = 5802234
order by 1, 2, 3,5


truncate table aj_temp_3

insert into aj_temp_3

with q1 as (
select greatest(sudi.start_date, cadc.cadc_start_date, :p_start_date) disc_start
,least(nvl(trunc(sudi.end_date), :p_end_date), cadc.cadc_end_date, 
   case when cadc.count_for_months is not null or cadc.count_for_days is not null then ADD_MONTHS(sudi.start_date, NVL(cadc.count_for_months,0))+NVL(cadc.count_for_days,0) else  :p_end_date end,
   :p_end_date) disc_end
--,cadc.*,
,cadc.ref_num, cadc.precentage, cadc.count_for_months, cadc.count_for_days, cadc.description, cadc.disc_billing_selector, cadc.pricing, cadc.minimum_price, cadc.for_fcit_type_code, 
cadc.for_billing_selector, cadc.for_sepv_ref_num, sudi.SUSG_REF_NUM, sudi.START_DATE sudi_start_date, padi.DISC_PERCENTAGE, padi.DISC_ABSOLUTE, padi.PRICE
--sudi.REF_NUM sudi_ref_num0, sudi.DISCOUNT_CODE sudi_discount_code, CONNECTION_EXIST, SUDI_REF_NUM, CLOSED, REASON_CODE, sudi.DATE_CREATED sudi_date_created, 
--sudi.CREATED_BY sudi_created_by, sudi.DATE_UPDATED sudi_date_updated, sudi.LAST_UPDATED_BY sudi_last_update_by, DOC_TYPE, DOC_NUM,  sudi.END_DATE sudi_end_date, 
--sudi.CADC_REF_NUM sudi_cadc_ref_num, sudi.DICO_REF_NUM sudi_dico_ref_num, SEC_AMT, DICO_SUDI_REF_NUM, sudi.SEC_CURR_CODE sudi_sec_curr_code, EEK_AMT, sudi.CURR_CODE sudi_curr_code, MIXED_PACKET_CODE, 
--sudi.PADI_REF_NUM, USRE_REF_NUM, CAOF_REF_NUM, padi.PADI_REF_NUM padi_padi_ref_num, padi.CADC_REF_NUM padi_cadc_ref_num, 
--padi.CREATED_BY padi_created_by, padi.DATE_CREATED padi_date_created, padi.LAST_UPDATED_BY padi_last_updated_by, padi.DATE_UPDATED padi_date_updated
from (
select greatest(nvl(cadc.start_date, :p_start_date), :p_start_date) cadc_start_date,
least(nvl(trunc(cadc.end_date), :p_end_date), :p_end_date) cadc_end_date,  
--cadc.* 
cadc.ref_num, cadc.precentage, cadc.count_for_months, cadc.count_for_days, cadc.description, cadc.disc_billing_selector, cadc.pricing, cadc.minimum_price, cadc.for_fcit_type_code, 
cadc.for_billing_selector, cadc.for_sepv_ref_num, cadc.dico_ref_num
from  call_discount_codes cadc, discount_codes dico 
where cadc.call_type = 'REGU'
and cadc.dico_ref_num = dico.ref_num
and NVL (cadc.end_date, :p_start_date) >= :p_start_date
and cadc.start_date < :p_end_date + 1
and NVL (cadc.discount_completed, 'N') <> 'Y'
and dico.for_all = 'N'
) cadc
join subs_discounts sudi ON sudi.cadc_ref_num IS NULL AND NVL (sudi.closed, 'N') <> 'Y'  and cadc.dico_ref_num = sudi.dico_ref_num   
                                              and NVL (sudi.end_date, :p_start_date) >= :p_start_date
                                              and sudi.start_date < :p_end_date + 1
                            AND (NVL(sudi.end_date,ADD_MONTHS (sudi.start_date, NVL (cadc.count_for_months, 0))
                                  + NVL (cadc.count_for_days, 0)) >= :p_start_date
                                  OR (cadc.count_for_days IS NULL AND cadc.count_for_months IS NULL)
                                )  
                            and (sudi.padi_ref_num is null OR (sudi.padi_ref_num is not null AND exists (select 1 from part_dico_details padd 
                                                                             where PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                                             and padd.cadc_ref_num = cadc.ref_num) ))
left join part_dico_details padi ON PADI.PADI_REF_NUM = sudi.padi_ref_num
                                                   and padi.cadc_ref_num = cadc.ref_num
), q2 as (
SELECT greatest(nvl(cadc.start_date, :p_start_date), :p_start_date) start_date,
   least(nvl(trunc(cadc.end_date), :p_end_date), :p_end_date) end_date,  
   cadc.REF_NUM, cadc.DISCOUNT_CODE, cadc.START_BILL_PERIOD, cadc.NEXT_BILL_PERIOD, cadc.SEC_AMOUNT, cadc.CALL_TYPE, cadc.FCIT_TYPE_CODE, cadc.BILLING_SELECTOR, cadc.DISCOUNT_COMPLETED, 
   cadc.DATE_CREATED, cadc.CREATED_BY, cadc.DATE_UPDATED, cadc.LAST_UPDATED_BY, cadc.SEPT_TYPE_CODE, cadc.END_BILL_PERIOD, cadc.SUBS_DISCOUNT_CODE, cadc.NEW_MOBILE, cadc.DURATION, 
   cadc.SUMMARY_DISCOUNT, cadc.PRECENTAGE, cadc.DICO_REF_NUM, cadc.DESCRIPTION, cadc.TATY_TYPE_CODE, cadc.START_DATE cadc_start_date, cadc.END_DATE cadc_end_date, cadc.PRIORITY, 
   cadc.COUNT_FOR_MONTHS, cadc.COUNT_FOR_DAYS, cadc.FROM_DAY, cadc.FOR_DAY_CLASS, cadc.FOR_CHAR_ANAL_CODE, cadc.FOR_BILLING_SELECTOR, cadc.FOR_FCIT_TYPE_CODE, cadc.FOR_SETY_REF_NUM, 
   cadc.FOR_SEPV_REF_NUM, cadc.DISC_BILLING_SELECTOR, cadc.PRINT_REQUIRED, cadc.CRM, cadc.COUNT, cadc.TIME_BAND_START, cadc.TIME_BAND_END, cadc.SEC_MONTHLY_AMOUNT, cadc.CHG_DURATION, 
   cadc.PERIOD_SEK, cadc.SEC_MINIMUM_PRICE, cadc.SINGLE_COUNT, cadc.DECREASE, cadc.PRICING, cadc.CHCA_TYPE_CODE, cadc.BILL_SEL_SUM, cadc.FROM_COUNT, cadc.MIN_PRICE_UNIT, 
   cadc.SEC_CONTROL_AMOUNT, cadc.SEC_INVO_AMOUNT, cadc.SEC_INVE_AMOUNT, cadc.SEC_CURR_CODE, cadc.AMOUNT, cadc.CONTROL_AMOUNT, cadc.CURR_CODE, cadc.INVE_AMOUNT, cadc.INVO_AMOUNT, 
   cadc.MINIMUM_PRICE, cadc.MONTHLY_AMOUNT, cadc.CALC, cadc.MIXED_SERVICE,
   dico.DISCOUNT_CODE dico_discount_code, dico.DESCRIPTION dico_description, dico.DISCOUNT_PERCENT, dico.START_DATE dico_start_date, dico.END_DATE dico_end_date, 
   dico.CREATED_BY dico_created_by, dico.DATE_CREATED dico_created, dico.LAST_UPDATED_BY dico_last_updated_by, dico.DATE_UPDATED dico_date_upated, 
   dico.PRINT_REQUIRED dico_print_required, dico.DISCOUNT_TYPE, dico.PARENT_DISCOUNT, dico.CRM dico_crm, dico.VMCT_MAAC_TYPE, dico.MOBILE_PART, 
   dico.DISC_BILLING_SELECTOR dico_disc_billing_selector, dico.REF_NUM dico_ref_num0, dico.PARENT_DICO_REF_NUM, 
   dico.EXCLUDE_DICO_REF_NUM, dico.PARENT_SPOC_REF_NUM, dico.SEVERAL_MAAC, dico.SEVERAL_MOBILE, dico.PARTY_TYPE, dico.MONTH_OF_SERV, dico.NEW_MAAC, dico.ALLOWED_COUNT, dico.GIVEN_COUNT, 
   dico.NEW_MOBILE dico_new_mobile, dico.FOR_ALL, dico.MANUAL, dico.DEALER_ALLOWED, dico.ORDER_TYPE, dico.PART_MONTH_OF_SERV, dico.SHORT_DESCRIPTION, dico.SMS_TEXT_TYPE, dico.DOMA_TYPE_CODE, 
   dico.PACKAGE_IMPACT, dico.DISCOUNT_SUSPEND, dico.SHOW_ITB, dico.VMCT_TYPE_CODE, dico.PADI_SEQ
from  call_discount_codes cadc, discount_codes dico
WHERE cadc.dico_ref_num = dico.ref_num 
and cadc.call_type = 'REGU'
and NVL (cadc.end_date, :p_start_date) >= :p_start_date
and cadc.start_date < :p_end_date + 1
and NVL (cadc.discount_completed, 'N') <> 'Y'
and NVL (dico.end_date, :p_start_date) >= :p_start_date
and dico.start_date < :p_end_date + 1
and cadc.start_date <= nvl(dico.end_date, cadc.start_date)
and dico.start_date <= nvl(cadc.end_date, dico.start_date) 
AND dico.manual = 'Y'
and dico.for_all = 'Y'
)
select maac, susg, 
--starts, ends, disc_start, disc_end,  ----COMMENT  
round(charge_value*period_days_corr/month_days,2) period_charge, 
--monthly_disc_rate, monthly_markdown, precentage, minimum_price, pricing, price,  ----COMMENT
fcit_billing_selector, fcit_type_code, fcit_bise,  fcit_desc,  disc_billing_selector, disc_bise, disc_descr, fcit_fcdt_type_code, cadc_ref_num,
-case when disc_start is not null then 
    case when monthly_disc_rate is not null or monthly_markdown is not null  /*or (station_param='MINU' and station_type='TSV')*/ then
      null
    else
      case when price is not null or disc_percentage is not null or disc_absolute is not null then
         round(greatest(charge_value-price, 0)*period_days_corr/month_days, 2)
      else
        case when pricing = 'Y' then
          round((charge_value - least((nvl(precentage,100)/100)*charge_value, least(nvl(minimum_price, charge_value), charge_value)))*period_days_corr/month_days, 2)
        else
          round(greatest((nvl(precentage,0)/100)*charge_value, least(nvl(minimum_price, 0), charge_value))*period_days_corr/month_days, 2)
        end
      end
    end
else
  null  
end discount
--, qq3.*  ----COMMENT
from (
select case when disc_start is null then starts else startx end start_date_corr,
case when disc_start is null then trunc(ends) else case when next_startx is null or next_startx > endx then endx else next_startx-1 end  end end_date_corr,
case when disc_start is null then trunc(ends) else case when next_startx is null or next_startx > endx then endx else next_startx-1 end  end + 1 -  
   case when disc_start is null then starts else startx end  period_days_corr, /**/
add_months(trunc(:p_start_date), 1) -trunc(:p_start_date) month_days /**/,    
nvl(ficv_charge_value, prli_charge_value) charge_value, /**/
--qq2.* 
qq2.maac, qq2.susg, qq2.fcit_billing_selector, qq2.fcit_type_code, qq2.fcit_bise, qq2.fcit_desc, qq2.disc_billing_selector, qq2.disc_bise, qq2.disc_descr, qq2.fcit_fcdt_type_code, 
qq2.cadc_ref_num, qq2.disc_start, qq2.monthly_disc_rate, qq2.monthly_markdown, qq2.price, qq2.disc_percentage, qq2.disc_absolute, qq2.precentage, qq2.minimum_price, qq2.sepv_start_real, 
qq2.sudi_start_date, qq2.count_for_months, qq2.count_for_days, qq2.sety_ref_num, qq2.pricing
from (
select lead(startx) over (partition by susg order by startx, endx) next_startx,  
--qq.*  
qq.maac, qq.susg, qq.fcit_billing_selector, qq.fcit_type_code, qq.fcit_bise, qq.fcit_desc, qq.disc_billing_selector, qq.disc_bise, qq.disc_descr, qq.fcit_fcdt_type_code, qq.cadc_ref_num,
qq.disc_start, qq.monthly_disc_rate, qq.monthly_markdown, qq.price, qq.disc_percentage, qq.disc_absolute, qq.precentage, qq.sepv_start_real, qq.sudi_start_date, qq.count_for_months,
qq.count_for_days, qq.minimum_price, qq.sety_ref_num, qq.pricing, qq.starts, qq.ends, qq.ficv_charge_value, qq.prli_charge_value, qq.startx, qq.endx 
from (
select greatest(starts, disc_start) startx /**/, least(trunc(ends), disc_end) endx/**/,  
--ends + 1/24/60/60 - starts  period_days,
--case when disc_start is null then null else least(ends+1/24/60/60, disc_end+1) - greatest(starts, disc_start) end disc_days,
bcdv1.description fcit_bise, bcdv2.description disc_bise, bcdv3.description disc_all_bise, 
--t.*, 
t.maac, t.susg, t.fcit_billing_selector, t.fcit_type_code, t.fcit_desc, t.fcit_fcdt_type_code, t.starts, t.ends, t.monthly_disc_rate, t.monthly_markdown, t.sepv_start_real, t.sety_ref_num,
t.prli_charge_value, t.ficv_charge_value,
q1.DISC_START, q1.DISC_END, q1.REF_NUM cadc_ref_num, q1.PRECENTAGE, q1.COUNT_FOR_MONTHS, q1.COUNT_FOR_DAYS, q1.DESCRIPTION disc_descr, q1.DISC_BILLING_SELECTOR, q1.PRICING, q1.MINIMUM_PRICE,
q1.SUDI_START_DATE, DISC_PERCENTAGE, DISC_ABSOLUTE, PRICE 
--q1.DISCOUNT_CODE, q1.START_BILL_PERIOD, q1.NEXT_BILL_PERIOD, q1.SEC_AMOUNT, q1.CALL_TYPE, q1.FCIT_TYPE_CODE cadc_fcit_type_code, q1.BILLING_SELECTOR, 
--q1.DISCOUNT_COMPLETED, q1.DATE_CREATED, q1.CREATED_BY, q1.DATE_UPDATED, q1.LAST_UPDATED_BY, q1.SEPT_TYPE_CODE cadc_sept_type_code, q1.END_BILL_PERIOD, q1.SUBS_DISCOUNT_CODE, q1.NEW_MOBILE, 
--q1.DURATION, q1.SUMMARY_DISCOUNT, q1.DICO_REF_NUM, q1.TATY_TYPE_CODE, q1.CADC_START_DATE, q1.CADC_END_DATE, q1.PRIORITY, 
--q1.FROM_DAY, q1.FOR_DAY_CLASS, q1.FOR_CHAR_ANAL_CODE, q1.FOR_BILLING_SELECTOR, q1.FOR_FCIT_TYPE_CODE, q1.FOR_SETY_REF_NUM, q1.FOR_SEPV_REF_NUM,  q1.PRINT_REQUIRED, 
--q1.CRM, q1.COUNT, q1.TIME_BAND_START, q1.TIME_BAND_END, q1.SEC_MONTHLY_AMOUNT, q1.CHG_DURATION, q1.PERIOD_SEK, q1.SEC_MINIMUM_PRICE, q1.SINGLE_COUNT, q1.DECREASE,  
--q1.CHCA_TYPE_CODE, q1.BILL_SEL_SUM, q1.FROM_COUNT, q1.MIN_PRICE_UNIT, q1.SEC_CONTROL_AMOUNT, q1.SEC_INVO_AMOUNT, q1.SEC_INVE_AMOUNT, q1.SEC_CURR_CODE, q1.AMOUNT, 
--q1.CONTROL_AMOUNT, q1.CURR_CODE, q1.INVE_AMOUNT, q1.INVO_AMOUNT,  q1.MONTHLY_AMOUNT, q1.CALC, q1.MIXED_SERVICE, q1.SUDI_REF_NUM0, q1.SUSG_REF_NUM, q1.SUDI_DISCOUNT_CODE, 
--q1.CONNECTION_EXIST, q1.SUDI_REF_NUM, q1.CLOSED, q1.REASON_CODE, 
--SUDI_DATE_CREATED, SUDI_CREATED_BY, SUDI_DATE_UPDATED, SUDI_LAST_UPDATE_BY, DOC_TYPE, DOC_NUM,  SUDI_END_DATE, SUDI_CADC_REF_NUM, SUDI_DICO_REF_NUM, SEC_AMT, DICO_SUDI_REF_NUM, 
--SUDI_SEC_CURR_CODE, EEK_AMT, SUDI_CURR_CODE, q1.MIXED_PACKET_CODE sudi_mixed_packet_code, PADI_REF_NUM, USRE_REF_NUM, CAOF_REF_NUM, padi_padi_ref_num, padi_cadc_ref_num, 
--padi_created_by, padi_date_created, padi_last_updated_by, padi_date_updated
from aj_temp_2 t left join q1 on q1.susg_ref_num = t.susg and q1.for_fcit_type_code = t.fcit_type_code and q1.for_billing_selector = t.fcit_billing_selector
                                 and nvl(q1.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num
                 left join q2 on q2.for_fcit_type_code = t.fcit_type_code and q2.for_billing_selector = t.fcit_billing_selector
                                 and nvl(q2.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num
                 LEFT join bcc_domain_values bcdv1 on bcdv1.value_code = t.fcit_billing_selector and bcdv1.doma_type_code = 'BISE'
                 left join bcc_domain_values bcdv2 on bcdv2.value_code = q1.disc_billing_selector and bcdv2.doma_type_code = 'BISE'
                 left join bcc_domain_values bcdv3 on bcdv3.value_code = q2.disc_billing_selector and bcdv3.doma_type_code = 'BISE'
where 1=1
--and t.mixed_packet_code is not null
--and ref_num is not null
--and monthly_markdown is not null
--and susg in (14556708, 14187291, 13647015)
--and susg=15399650
--and susg=14946136
--and susg=11773459
--and susg in (14381968, 14946136, 14363640)
--and susg = 14789323
--and susg in (3577785)
--and susg in (11532124,15823801,4885009,9457163,12646971,3840741,4534183,14973743,15332260,14147754,11864467,12492643,15595759,12985931,13330415,13348141,13416850,13997873,13997873,15395199,
--14938623,15333495,15388264)
) qq
where 1=1
and starts <= nvl(disc_end, starts)
and nvl(disc_start, trunc(ends)) <= trunc(ends) 
--and disc_start is not null and period_days != 30
--and(nvl(precentage, 0) != 0 or minimum_price is not null)
--and case when disc_start is null then null else least(ends+1/24/60/60, disc_end+1) - greatest(starts, disc_start) end != period_days 
--and padi_ref_num is not null 
--and price is not null --or disc_amount is not null 
--and fcit_desc != 'Interneti kuutasu' --and minimum_price is not null and pricing = 'Y'
--and (monthly_markdown is not null or monthly_disc_rate is not null)
--and minimum_price > nvl(ficv_charge_value, prli_charge_value)*period_days/month_days
) qq2
) qq3
where end_date_corr >= start_date_corr
----------
and period_days_corr = month_days
and sepv_start_real < :p_start_date
and add_months(trunc(nvl(sudi_start_date, sysdate)), nvl(count_for_months,0)) + nvl(count_for_days,0) != :p_end_date
and sety_ref_num = 5802234
order by 1, 2, 3,5
