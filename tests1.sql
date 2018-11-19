iprocess_monthly_service_fees

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


select * from (

select /*+ MONITOR  ALL_ROWS*/
t.*, --row_number() over (partition by t.susg order by sudi.ref_num nulls last) cnt, 
cadc.REF_NUM cadc_ref_num, cadc.DISCOUNT_CODE cadc_discount_code, START_BILL_PERIOD, NEXT_BILL_PERIOD, SEC_AMOUNT, CALL_TYPE, cadc.FCIT_TYPE_CODE cadc_fcit_type_code, BILLING_SELECTOR, 
DISCOUNT_COMPLETED, cadc.DATE_CREATED cadc_date_created, cadc.CREATED_BY cadc_reated_by, cadc.DATE_UPDATED cadc_date_updated, cadc.LAST_UPDATED_BY cadc_last_updated_by, 
cadc.SEPT_TYPE_CODE cadc_sept_type_code, END_BILL_PERIOD, SUBS_DISCOUNT_CODE, NEW_MOBILE, DURATION, SUMMARY_DISCOUNT, PRECENTAGE, cadc.DICO_REF_NUM cadc_dico_ref_num, DESCRIPTION, 
TATY_TYPE_CODE, cadc.START_DATE cadc_start_date, cadc.END_DATE cadc_end_date, PRIORITY, COUNT_FOR_MONTHS, COUNT_FOR_DAYS, FROM_DAY, FOR_DAY_CLASS, FOR_CHAR_ANAL_CODE, FOR_BILLING_SELECTOR, 
FOR_FCIT_TYPE_CODE, FOR_SETY_REF_NUM, FOR_SEPV_REF_NUM, DISC_BILLING_SELECTOR, PRINT_REQUIRED, CRM, COUNT, TIME_BAND_START, TIME_BAND_END, SEC_MONTHLY_AMOUNT, CHG_DURATION, PERIOD_SEK, 
SEC_MINIMUM_PRICE, SINGLE_COUNT, DECREASE, PRICING, CHCA_TYPE_CODE, BILL_SEL_SUM, FROM_COUNT, MIN_PRICE_UNIT, SEC_CONTROL_AMOUNT, SEC_INVO_AMOUNT, SEC_INVE_AMOUNT, 
cadc.SEC_CURR_CODE cadc_sec_curr_code, AMOUNT, CONTROL_AMOUNT, cadc.CURR_CODE cadc_curr_code, INVE_AMOUNT, INVO_AMOUNT, MINIMUM_PRICE, MONTHLY_AMOUNT, CALC, MIXED_SERVICE
--,sudi.REF_NUM sudi_REF_NUM, sudi.SUSG_REF_NUM sudi_susg_ref_num, sudi.DISCOUNT_CODE sudi_DISCOUNT_CODE, CONNECTION_EXIST, sudi.SUDI_REF_NUM sudi_sudi_ref_num, CLOSED, 
--REASON_CODE, sudi.DATE_CREATED sudi_DATE_CREATED, sudi.CREATED_BY sudi_CREATED_BY, sudi.DATE_UPDATED sudi_DATE_UPDATED, sudi.LAST_UPDATED_BY sudi_last_updated_by, DOC_TYPE, 
--DOC_NUM, sudi.START_DATE sudi_start_date, sudi.END_DATE sudi_end_date, sudi.CADC_REF_NUM sudi_cadc_ref_num, sudi.DICO_REF_NUM sudi_dico_ref_num, SEC_AMT, DICO_SUDI_REF_NUM, 
--sudi.SEC_CURR_CODE sudi_sec_curr_code, EEK_AMT, sudi.CURR_CODE sudi_curr_code, sudi.MIXED_PACKET_CODE sudi_mixed_packet_code, PADI_REF_NUM, USRE_REF_NUM, CAOF_REF_NUM
from aj_temp_1 t
 JOIN call_discount_codes cadc ON cadc.for_fcit_type_code = t.fcit_type_code and cadc.for_billing_selector = t.fcit_billing_selector and cadc.call_type = 'REGU'
                                     and date '2018-09-30' BETWEEN cadc.start_date AND NVL (cadc.end_date, date '2018-09-30') and NVL (cadc.discount_completed, 'N') <> 'Y'
                                     and nvl(cadc.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num 
                                     and exists (select 1 from subs_discounts sudix 
                                                 where sudix.dico_ref_num = cadc.dico_ref_num 
                                                 and sudix.cadc_ref_num is null
                                                 and sudix.susg_ref_num = t.susg)

left join subs_discounts sudi ON sudi.susg_ref_num = t.susg AND sudi.cadc_ref_num IS NULL AND NVL (sudi.closed, 'N') <> 'Y'  and cadc.dico_ref_num = sudi.dico_ref_num
where 1=1
--and t.susg=15823780
and (sudi.padi_ref_num is null OR (sudi.padi_ref_num is not null AND exists (select 1 from part_dico_details padd 
                                                                             where PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                                             and padd.cadc_ref_num = cadc.ref_num) ))

with t as (
select susg, starts, ends, fcit_type_code, fcit_billing_selector, sepv_ref_num, sept_type_code, mixed_packet_code, sety_ref_num
from aj_temp_1
)
select count(*) over (partition by t1.susg, t1.starts, t1.sety_ref_num) cc, t1.*, cadc.*, sudi.* from t
 JOIN call_discount_codes cadc ON cadc.for_fcit_type_code = t.fcit_type_code and cadc.for_billing_selector = t.fcit_billing_selector and cadc.call_type = 'REGU'
                                     and date '2018-09-30' BETWEEN cadc.start_date AND NVL (cadc.end_date, date '2018-09-30') and NVL (cadc.discount_completed, 'N') <> 'Y'
                                     and nvl(cadc.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num 
                                     and exists (select 1 from subs_discounts sudix 
                                                 where sudix.dico_ref_num = cadc.dico_ref_num 
                                                 and sudix.cadc_ref_num is null
                                                 and sudix.susg_ref_num = t.susg)
join subs_discounts sudi ON sudi.susg_ref_num = t.susg AND sudi.cadc_ref_num IS NULL AND NVL (sudi.closed, 'N') <> 'Y'  and cadc.dico_ref_num = sudi.dico_ref_num   
                            AND nvl(SUDI.end_date,date '2018-09-30') >= date '2018-09-30' 
                            AND sudi.start_date + NVL (cadc.from_day, 0) <= date '2018-09-30'
                            AND ( NVL(sudi.end_date,ADD_MONTHS (sudi.start_date, NVL (cadc.count_for_months, 0))
                                  + NVL (cadc.count_for_days, 0)) >= date '2018-09-30'
                               OR (cadc.count_for_days IS NULL AND cadc.count_for_months IS NULL)
                              )
                            and (sudi.padi_ref_num is null OR (sudi.padi_ref_num is not null AND exists (select 1 from part_dico_details padd 
                                                                             where PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                                             and padd.cadc_ref_num = cadc.ref_num) ))
RIGHT JOIN aj_temp_1 t1 ON t1.susg = t.susg and t1.starts = t.starts  and t1.sety_ref_num = t.sety_ref_num   
where 1=1
--and t1.susg = 6177509      
and t1.sety_ref_num = 5802234
and cadc.ref_num is not null                                     
order by 4 desc ,1 desc, t1.maac, t1.susg, t1.starts

select greatest(sudi.start_date, cadc.start_date, p_start_date) disc_start,  
least(sudi.end_date, cadc.end_date, ADD_MONTHS(sudi_start_date, NVL(cadc.count_for_months,0))+NVL(cadc.count_for_days)  p_start_date) disc_end, *
from (
select * from  call_discount_codes cadc where cadc.call_type = 'REGU'
                                     and NVL (cadc.end_date, p_start_date) >= p_start_date
                                     and cadc.start_date < p_end_date + 1
                                     and NVL (cadc.discount_completed, 'N') <> 'Y'
) cadc
join subs_discounts sudi ON sudi.cadc_ref_num IS NULL AND NVL (sudi.closed, 'N') <> 'Y'  
	                                       and cadc.dico_ref_num = sudi.dico_ref_num   
                                              and NVL (sudi.end_date, p_start_date) >= p_start_date
                                              and sudi.start_date < p_end_date + 1
                            AND ( NVL(sudi.end_date,ADD_MONTHS (sudi.start_date, NVL (cadc.count_for_months, 0))
                                  + NVL (cadc.count_for_days, 0)) >= p_start_date
                               OR (cadc.count_for_days IS NULL AND cadc.count_for_months IS NULL)
                              )
                            and (sudi.padi_ref_num is null OR (sudi.padi_ref_num is not null AND 
                                                                   exists (select 1 from part_dico_details padd 
                                                                             where PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                                             and padd.cadc_ref_num = cadc.ref_num)))
left join part_dico_details padd ON PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                   and padd.cadc_ref_num = cadc.ref_num

with q1 as (
select greatest(sudi.start_date, cadc.start_date, date '2018-10-01') disc_start
,least(nvl(sudi.end_date, date '2018-10-31'), nvl(cadc.end_date, date '2018-10-31'), ADD_MONTHS(sudi.start_date, NVL(cadc.count_for_months,0))+NVL(cadc.count_for_days,0),  date '2018-10-31') disc_end
,cadc.*,
sudi.REF_NUM sudi_ref_num0, SUSG_REF_NUM, sudi.DISCOUNT_CODE sudi_discount_code, CONNECTION_EXIST, SUDI_REF_NUM, CLOSED, REASON_CODE, sudi.DATE_CREATED sudi_date_created, 
sudi.CREATED_BY sudi_created_by, sudi.DATE_UPDATED sudi_date_updated, sudi.LAST_UPDATED_BY sudi_last_update_by, DOC_TYPE, DOC_NUM, sudi.START_DATE sudi_start_date, sudi.END_DATE sudi_end_date, 
sudi.CADC_REF_NUM sudi_cadc_ref_num, sudi.DICO_REF_NUM sudi_dico_ref_num, SEC_AMT, DICO_SUDI_REF_NUM, sudi.SEC_CURR_CODE sudi_sec_curr_code, EEK_AMT, sudi.CURR_CODE sudi_curr_code, MIXED_PACKET_CODE, 
sudi.PADI_REF_NUM, USRE_REF_NUM, CAOF_REF_NUM, padi.PADI_REF_NUM padi_padi_ref_num, padi.CADC_REF_NUM padi_cadc_ref_num, 
DISC_PERCENTAGE, DISC_ABSOLUTE, PRICE, padi.CREATED_BY padi_created_by, padi.DATE_CREATED padi_date_created, padi.LAST_UPDATED_BY padi_last_updated_by, padi.DATE_UPDATED padi_date_updated
from (
select * from  call_discount_codes cadc where cadc.call_type = 'REGU'
                                     and NVL (cadc.end_date, date '2018-10-01') >= date '2018-10-01'
                                     and cadc.start_date < date '2018-10-31' + 1
                                     and NVL (cadc.discount_completed, 'N') <> 'Y'
) cadc
join subs_discounts sudi ON sudi.cadc_ref_num IS NULL AND NVL (sudi.closed, 'N') <> 'Y'  and cadc.dico_ref_num = sudi.dico_ref_num   
                                              and NVL (sudi.end_date, date '2018-10-01') >= date '2018-10-01'
                                              and sudi.start_date < date '2018-10-31' + 1
                            AND NVL(sudi.end_date,ADD_MONTHS (sudi.start_date, NVL (cadc.count_for_months, 0))
                                  + NVL (cadc.count_for_days, 0)) >= date '2018-10-01'
                            and (sudi.padi_ref_num is null OR (sudi.padi_ref_num is not null AND exists (select 1 from part_dico_details padd 
                                                                             where PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                                             and padd.cadc_ref_num = cadc.ref_num) ))
left join part_dico_details padi ON PADI.PADI_REF_NUM = sudi.padi_ref_num
                                                   and padi.cadc_ref_num = cadc.ref_num
)
select t.*,
DISC_START, DISC_END, REF_NUM, DISCOUNT_CODE, START_BILL_PERIOD, NEXT_BILL_PERIOD, SEC_AMOUNT, CALL_TYPE, q1.FCIT_TYPE_CODE cadc_fcit_type_code, BILLING_SELECTOR, DISCOUNT_COMPLETED, DATE_CREATED, CREATED_BY, 
DATE_UPDATED, LAST_UPDATED_BY, q1.SEPT_TYPE_CODE cadc_sept_type_code, END_BILL_PERIOD, SUBS_DISCOUNT_CODE, NEW_MOBILE, DURATION, SUMMARY_DISCOUNT, PRECENTAGE, DICO_REF_NUM, DESCRIPTION, TATY_TYPE_CODE, 
START_DATE, END_DATE, PRIORITY, COUNT_FOR_MONTHS, COUNT_FOR_DAYS, FROM_DAY, FOR_DAY_CLASS, FOR_CHAR_ANAL_CODE, FOR_BILLING_SELECTOR, FOR_FCIT_TYPE_CODE, FOR_SETY_REF_NUM, 
FOR_SEPV_REF_NUM, DISC_BILLING_SELECTOR, PRINT_REQUIRED, CRM, COUNT, TIME_BAND_START, TIME_BAND_END, SEC_MONTHLY_AMOUNT, CHG_DURATION, PERIOD_SEK, SEC_MINIMUM_PRICE, SINGLE_COUNT, 
DECREASE, PRICING, CHCA_TYPE_CODE, BILL_SEL_SUM, FROM_COUNT, MIN_PRICE_UNIT, SEC_CONTROL_AMOUNT, SEC_INVO_AMOUNT, SEC_INVE_AMOUNT, SEC_CURR_CODE, AMOUNT, CONTROL_AMOUNT, CURR_CODE, 
INVE_AMOUNT, INVO_AMOUNT, MINIMUM_PRICE, MONTHLY_AMOUNT, CALC, MIXED_SERVICE, SUDI_REF_NUM0, SUSG_REF_NUM, SUDI_DISCOUNT_CODE, CONNECTION_EXIST, SUDI_REF_NUM, CLOSED, REASON_CODE, 
SUDI_DATE_CREATED, SUDI_CREATED_BY, SUDI_DATE_UPDATED, SUDI_LAST_UPDATE_BY, DOC_TYPE, DOC_NUM, SUDI_START_DATE, SUDI_END_DATE, SUDI_CADC_REF_NUM, SUDI_DICO_REF_NUM, SEC_AMT, DICO_SUDI_REF_NUM, 
SUDI_SEC_CURR_CODE, EEK_AMT, SUDI_CURR_CODE, q1.MIXED_PACKET_CODE sudi_mixed_packet_code, PADI_REF_NUM, USRE_REF_NUM, CAOF_REF_NUM, padi_padi_ref_num, padi_cadc_ref_num, 
DISC_PERCENTAGE, DISC_ABSOLUTE, PRICE, padi_created_by, padi_date_created, padi_last_updated_by, padi_date_updated
from aj_temp_2 t left join q1 on q1.susg_ref_num = t.susg and q1.for_fcit_type_code = t.fcit_type_code and q1.for_billing_selector = t.fcit_billing_selector
and nvl(q1.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num
where 1=1
--and t.mixed_packet_code is not null
--and ref_num is not null
--and monthly_markdown is not null
--and susg in (14556708, 14187291, 13647015)
--and susg=15399650
and susg=14946136
--and susg=11773459
--and susg=41902

select * from service_param_values 
where ref_num = 10029

select * from fixed_charge_item_types

select * from fixed_charge_values ficv
where sepv_ref_num = 10029

select * from price_lists
where sepv_ref_num = 10029

select acco.name, susg.* from 
accounts acco, subs_serv_groups susg
where lower(acco.name) like '% jaek'
and acco.ref_num = trunc(susg.suac_ref_num, -3)

select * from subs_serv_groups

select * from disc_call_amounts
where susg_ref_num=6177509

15777236
6177509

select * from aj_temp_1
where susg=15167162

select count(*) c,susg, fcit_type_code, fcit_billing_selector, sepv_ref_num--, starts--, sept_type_code--, mixed_packet_code 
from t
group by susg, fcit_type_code, fcit_billing_selector, sepv_ref_num--, starts--, sept_type_code--, mixed_packet_code
order by 1 desc



select * from invoices
where ref_num=69567216


delete from invoice_entries
where ref_num in (939575406, 939575407);

select rowid, ie.* from invoice_entries ie
where 1=1
--and susg_ref_num = 13647015
--and susg_ref_num = 15399650
--and invo_ref_num = 69141549
and susg_ref_num = 14946136 
--and susg_ref_num=11773459
--and invo_ref_num=69064841
--and susg_ref_num = 41902
--and invo_ref_num = 68721868
order by billing_selector, date_created


20 21.65  Mix
8  21.65 16,66
3  24,17

GGR

11 8.58



and ref_num in (939575406, 939575407);



insert into invoice_entries
select * from invoice_entries AS OF timestamp sysdate-2/24
where ref_num in (939575406, 939575407);

delete from subs_discounts
where  ref_num = 38706111

select * from subs_discounts
where ref_num in ( 37651810, 37651811)
union all
select * from subs_discounts AS OF TIMESTAMP sysdate -2/24
where ref_num in ( 37651810, 37651811)

select * from discount_codes
where ref_num = 18942

select * from subs_discounts
where padi_ref_num in (
select ref_num from party_discounts
where pagr_ref_num = 1092
)
order by susg_ref_num, start_date

select * from party_groups
where ref_num = 1092

select rowid, sd.* from subs_discounts sd
where 1=1 
and susg_ref_num = 15777236

and ref_num = 38706111

insert into subs_discounts
select * from subs_discounts  AS OF timestamp sysdate-2/24
where 1=1 
and ref_num = 38706111

select count(*) over (partition by susg_ref_num) c, d.* from subs_discounts d
where date_created between timestamp '2018-10-01 01:00:00'  and timestamp '2018-10-01 02:00:00'
order by 1 desc

select * from invoice_entries
where date_created between timestamp '2018-10-01 01:00:00'  and timestamp '2018-10-01 02:00:00'
order by 1

select * from invoice_entries
where susg_ref_num = 13710290
order by 1 desc

select * from subs_discounts
where susg_ref_num = 15317222





UNION ALL


select * from subs_discounts
where date_created > add_months(trunc(sysdate,'MM'), -1)

select * from all_source
where lower(text) like '%subs_discounts%'

select t.* from subs_discounts t 
where susg_ref_num = 15823946
and end_date is null

select rowid, t.* from subs_discounts t 
where susg_ref_num = 13710290
--and end_date is null

select * from subs_discounts

where eek_amt =0

         SELECT inen.rowid, inen.* 
         --SUM (inen.eek_amt)
           FROM invoice_entries  as of timestamp sysdate -3 inen
           , invoices invo
          WHERE 1=1
          and invo.maac_ref_num = 2983623000
          --and cadc_ref_num is not null 
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN date '2018-09-01' AND date '2018-09-30'
            AND inen.invo_ref_num = invo.ref_num
--            AND (inen.susg_ref_num = p_susg_ref_num OR inen.susg_ref_num IS NULL AND p_susg_ref_num IS NULL
--                )   -- CHG-4418
            --AND    inen.billing_selector = p_billing_selector CHG-3946: commented out
            
            AND inen.fcit_type_code IN (SELECT type_code
                                          FROM fixed_charge_item_types
                                         WHERE (   sety_ref_num = 5802234
--                                                OR sety_ref_num IS NULL AND type_code = p_fcit_type_code
                                               )
                                           AND regular_charge = 'Y'
                                           AND once_off = 'N'
                                           AND pro_rata = 'N')
                                           
select * from                                            

select * from subs_discounts
where susg_ref_num in (
select susg from aj_temp_1
where fcit_billing_selector = 'KTO'
and fcit_type_code = 'GGA'
and sepv_ref_num = 9106
and susg_ref_num = 15125699
)

select * from aj_temp_1
where susg = 15125699


select * from fixed_charge_types

SELECT *
           FROM discount_codes dico
          WHERE 1=1
          --and date '2018-09-30' BETWEEN dico.start_date AND NVL (dico.end_date, date '2018-09-30')
            AND dico.MANUAL = 'N'
            AND dico.for_all = 'Y';

select * from aj_temp_1

where monthly_disc_rate is not null


select * from fixed_charge_values
where sety_ref_num = 5802234
and sept_type_code = 'VAKA'
and sepv_ref_num = 7745

select * from invoices
where maac_ref_num =2846914000

select * from invoice_entries
where invo_ref_num=69078550

select * from common_monthly_charges
where invo_ref_num=69078550

delete from  common_monthly_charges
where ref_num = 939933541;


         SELECT comc.*
         FROM common_monthly_charges comc
            , invoices invo
         WHERE invo.maac_ref_num = 2983650000
           AND invo.billing_inv = 'Y'
           AND invo.period_start BETWEEN date '2018-09-01' AND date '2018-09-30'
           AND comc.invo_ref_num = invo.ref_num
           AND (comc.susg_ref_num = 15823988)
           AND comc.fcit_type_code IN (SELECT type_code
                                       FROM fixed_charge_item_types
                                       WHERE (   sety_ref_num = 5802234
                                              )
                                         AND regular_charge = 'Y'
                                         AND once_off = 'N'
                                         AND pro_rata = 'N')
                                         
           AND EXISTS (select 1
                       from invoice_entries inen
                          , fixed_charge_item_types fcit
                          , fixed_charge_item_types fcit_bill
                       where inen.invo_ref_num = invo.ref_num
                         and fcit.type_code = comc.fcit_type_code
                         and fcit.billing_selector = comc.billing_selector
                         and fcit_bill.type_code = fcit.bill_fcit_type_code
                         and inen.fcit_type_code = fcit_bill.type_code
                         and inen.billing_selector = fcit_bill.billing_selector)
           AND comc.num_of_days IS NULL


DECLARE
-- Declarations
var_P_PERIOD_START DATE;
var_P_PERIOD_END DATE;
var_P_TBPR_REC tbcis_processes%ROWTYPE;
var_P_SUCCESS BOOLEAN;
var_P_ERROR_TEXT VARCHAR2(32767);
var P_MAAC_REF_NUM NUMBER;
BEGIN
-- Initialization
var_P_PERIOD_START := date '2018-08-01';
var_P_PERIOD_END := date '2018-08-31';
var_P_TBPR_REC := NULL;
var P_MAAC_REF_NUM := 2978944000;
-- Call
TBCIS.PROCESS_MONTHLY_SERVICE_FEES.CHK_MOBILE_NONKER_SERVICE_FEES(P_PERIOD_START => var_P_PERIOD_START, P_PERIOD_END => var_P_PERIOD_END, P_TBPR_REC => var_P_TBPR_REC, P_SUCCESS => var_P_SUCCESS, P_ERROR_TEXT => var_P_ERROR_TEXT);

-- Transaction Control


-- Output values, do not modify
:4 := var_P_TBPR_REC.MODULE_REF;
:5 := var_P_TBPR_REC.MODULE_DESC;
:6 := var_P_TBPR_REC.MODULE_PARAMS;
:7 := var_P_TBPR_REC.START_DATE;
:8 := var_P_TBPR_REC.END_DATE;
:9 := var_P_TBPR_REC.EVERYDAY;
:10 := var_P_TBPR_REC.END_CODE;
:11 := var_P_TBPR_REC.SEND_EMAIL;
:12 := var_P_TBPR_REC.SEND_SMS;
:13 := var_P_TBPR_REC.DATE_CREATED;
:14 := var_P_TBPR_REC.CREATED_BY;
:15 := var_P_TBPR_REC.LAST_UPDATED;
:16 := var_P_TBPR_REC.LAST_UPDATED_BY;
:17 := var_P_TBPR_REC.FINANCIAL_YEAR;
:18 := var_P_TBPR_REC.PERIOD_NUM;
:19 := var_P_TBPR_REC.PROC_RUN_ORDER;
:20 := var_P_TBPR_REC.PROC_INT_ORDER;
:21 := var_P_TBPR_REC.CYCLE_BASED;
:22 := var_P_TBPR_REC.LIGHT_UP_RULE;
:23 := var_P_TBPR_REC.OTHER_PARAMS;
:24 := BOOL2CHAR(var_P_SUCCESS);
:25 := var_P_ERROR_TEXT;END;