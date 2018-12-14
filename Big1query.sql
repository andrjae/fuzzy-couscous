alter table aj_temp_3 add (sudi_end date)

,start_date_corr, end_date_corr, period_days_corr, sepv_start_real, 


truncate table aj_temp_3

insert into aj_temp_3
with q1 as (
select greatest(sudi.start_date, cadc.cadc_start_date, :p_start_date) disc_start
,least(nvl(trunc(sudi.end_date), :p_end_date), cadc.cadc_end_date, 
   case when cadc.count_for_months is not null or cadc.count_for_days is not null then ADD_MONTHS(sudi.start_date, NVL(cadc.count_for_months,0))+NVL(cadc.count_for_days,0) else  :p_end_date end,
   :p_end_date) disc_end
,cadc.ref_num, cadc.precentage, cadc.count_for_months, cadc.count_for_days, cadc.description, cadc.disc_billing_selector, cadc.pricing, cadc.minimum_price, cadc.for_fcit_type_code, 
cadc.for_billing_selector, cadc.for_sepv_ref_num, sudi.SUSG_REF_NUM, sudi.START_DATE sudi_start_date, padi.DISC_PERCENTAGE, padi.DISC_ABSOLUTE, padi.PRICE
from (
select greatest(nvl(cadc.start_date, :p_start_date), :p_start_date) cadc_start_date,
least(nvl(trunc(cadc.end_date), :p_end_date), :p_end_date) cadc_end_date,  
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
), q4 as (
select susg_ref_num, sety_ref_num, start_date, end_date-- , count(*) over (partition by susg_ref_num, sety_ref_num) c
from status_periods stpe
where 1=1 --susg_ref_num =6177509
AND NVL (stpe.end_date, date '2018-10-01' + 1) > date '2018-10-01'
AND stpe.start_date < date '2018-10-31' + 1
AND stpe.sety_ref_num IN (5802234)
), q5 as (
select susg_ref_num, start_date, nvl(end_date, date '2018-10-31' + 1 - 1/24/60/60) end_date--, end_date end_date_real, rnk, last_status 
from (
select susg_ref_num, start_date, end_date, status_code
from ssg_statuses stpe
)
where  1=1
AND NVL (end_date, date '2018-10-01'+1) > date '2018-10-01'
AND start_date < date '2018-10-31' + 1
and status_code = 'AC'
), q6 as (
select susp.susg_ref_num, susp.sety_ref_num, susp.start_date, nvl(susp.end_date, date '2018-10-31' + 1 - 1/24/60/60) end_date, --susp.end_date end_date_real, 
susp.sepa_ref_num, susp.sepv_ref_num 
from subs_service_parameters susp
where  1=1
AND NVL (susp.end_date, date '2018-10-01' + 1) > date '2018-10-01'
AND susp.start_date < date '2018-10-31' + 1
), qmix As (
select SEPT_TYPE_CODE,-- MIXED_PACKET_CODE, ebs_order_number, 
SETY_REF_NUM, SUSG_REF_NUM, START_DATE, 
case when trunc(end_date) >= trunc(next_start_date) then trunc(next_start_date)-1/24/60/60 else trunc(end_date)+1-1/24/60/60 end END_DATE, --end_date end_date_real,
NEXT_START_DATE, PREV_END_DATE, --station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num, 
monthly_disc_rate, monthly_markdown--, monthly_billing_selector, monthly_fcit_type_code  
from (
select ftco.sept_type_code, --ftco.mixed_packet_code, ftco.ebs_order_number, 
mose.sety_ref_num, ftco.susg_ref_num, ftco.start_date, ftco.end_date, 
lead(ftco.start_date) over (partition by mose.sety_ref_num, ftco.susg_ref_num order by ftco.start_date, ftco.end_date) next_start_date,  
lag(ftco.end_date) over (partition by mose.sety_ref_num, ftco.susg_ref_num order by ftco.end_date, ftco.start_date) prev_end_date, 
mips.monthly_disc_rate, mips.monthly_markdown--, mipa.monthly_billing_selector, mipa.monthly_fcit_type_code
from (
select ftco.sept_type_code, ftco.mixed_packet_code, ftco.susg_ref_num, greatest(ftco.start_date, date '2018-10-01') start_date,
least(coalesce(case when coalesce(ftco.date_closed, ftco.end_date)=trunc(coalesce(ftco.date_closed, ftco.end_date)) 
         then coalesce(ftco.date_closed, ftco.end_date)+1-1/24/60/60 else coalesce(ftco.date_closed, ftco.end_date) end,
         date '2018-10-31'+1-1/24/60/60), date '2018-10-31'+1-1/24/60/60) end_date, ftco.date_closed, ftco.ebs_order_number 
from fixed_term_contracts ftco 
) ftco
, mixed_packet_orders  mipo
, mixed_order_services mose
, mixed_packets mipa
, mixed_packet_services mips
, service_types sety
where 1=1
and mose.sety_ref_num = sety.ref_num
and ftco.mixed_packet_code = mipa.packet_code
and mose.mips_ref_num = mips.ref_num
   and mose.sety_ref_num = 5802234
AND ftco.mixed_packet_code = mipo.mixed_packet_code
AND ftco.ebs_order_number = mipo.ebs_order_number
AND Nvl(mipo.term_request_type, '*') <> 'NULLIFY'
AND mose.mipo_ref_num = mipo.ref_num
AND ftco.start_date < date '2018-10-31'+1
AND coalesce(ftco.end_date, date '2018-10-31') >= date '2018-10-01'
)
), qmix0 AS (
select * 
from qmix
where 1=1
and end_date = date '2018-10-31'+1-1/24/60/60
and start_date = date '2018-10-01'
), qmix1 AS (
select sept_type_code, sety_ref_num, susg_ref_num, start_date, end_date,-- end_date_real, 
coalesce(next_start_date, date '2018-10-31'+1) next_start_date, 
coalesce(prev_end_date, date '2018-10-01') prev_end_date--, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num--
,  monthly_disc_rate, monthly_markdown--, monthly_billing_selector, monthly_fcit_type_code
from qmix
where 1=1
AND (end_date  < date '2018-10-31'+1-1/24/60/60
OR start_date > date '2018-10-01')
), q7 as (
select '' SEPT_TYPE_CODE, SETY_REF_NUM, SUSG_REF_NUM, --prev_date, start_date, end_date, next_date 
prev_end_date START_DATE, start_date -1/24/60/60 END_DATE --, '' station_param, '' station_type, null min_fix_monthly_fee, null mipo_ref_num, null mips_ref_num
,  null monthly_disc_rate, null monthly_markdown--, null monthly_billing_selector, null monthly_fcit_type_code, end_date_real
from qmix1
where prev_end_date = date '2018-10-01'  --only month start not covered
and start_date > date '2018-10-01'
and start_date < end_date
union all
select '' SEPT_TYPE_CODE, SETY_REF_NUM, SUSG_REF_NUM, --prev_date, start_date, end_date, next_date --
end_date+1/24/60/60 START_DATE, next_start_date -1/24/60/60 END_DATE--, '' station_param, '' station_type, null min_fix_monthly_fee, null mipo_ref_num, null mips_ref_num 
, null monthly_disc_rate, null monthly_markdown--, null monthly_billing_selector, null monthly_fcit_type_code, end_date_real
from qmix1 
where next_start_date > end_date+1/24/60/60
union all
select SEPT_TYPE_CODE, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, END_DATE--, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num
,  monthly_disc_rate, monthly_markdown--, monthly_billing_selector, monthly_fcit_type_code, end_date_real
from qmix1
union all
select SEPT_TYPE_CODE, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, END_DATE--, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num
,  monthly_disc_rate, monthly_markdown--, monthly_billing_selector, monthly_fcit_type_code, end_date_real
from qmix0
), qx AS (
select /*+ CARDINALITY (t 2000000) NO_PARALLEL */ /* LEADING(t) USE_HASH(t q4) NO_PARALLEL */ t.maac, t.susg, t.sept_type_code, t.cat,  
greatest(trunc(t.start_date), date '2018-10-01') supa_start, least(trunc(nvl(t.end_date, date '2018-10-31')) + 1 - 1/24/60/60, date '2018-10-31' + 1 - 1/24/60/60) supa_end,
q4.sety_ref_num, 
greatest(q4.start_date, date '2018-10-01') serv_start, least(nvl(q4.end_date, date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) serv_end 
from table(xx_aj.get_list_susg_x (date '2018-10-01', date '2018-10-31', 
102,
--13796675, 
--14251850,
--14606161,
--15145486,
--15369942,
15824129 
--15814963,
--15814963,
)) t JOIN q4 ON q4.susg_ref_num = t.susg
), discless as (
select greatest(supa_start, serv_starts, sepv_starts, act_starts, nvl(mipo_start, date '2018-10-01')) starts, 
least(supa_end, serv_ends, sepv_ends, act_ends, nvl(mipo_end, date '2018-10-31'+1)) ends,
main.maac, main.susg, main.fcit_billing_selector, main.fcit_type_code, main.fcit_desc, main.fcit_fcdt_type_code, main.monthly_disc_rate, main.monthly_markdown, main.sepv_start_real, 
main.sety_ref_num, main.prli_charge_value, main.ficv_charge_value, main.sepv_ref_num,
main.DISC_START, main.DISC_END, main.cadc_ref_num, main.PRECENTAGE, main.COUNT_FOR_MONTHS, main.COUNT_FOR_DAYS, main.disc_descr, main.DISC_BILLING_SELECTOR, main.PRICING, main.MINIMUM_PRICE,
main.SUDI_START_DATE, main.DISC_PERCENTAGE, main.DISC_ABSOLUTE, main.PRICE 
from (
select  trunc(sepv_start/**/) sepv_starts, 
case when trunc(sepv_end/**/) >= trunc(next_sepv_start/**/) then trunc(next_sepv_start)-1/24/60/60 else trunc(sepv_end)+1-1/24/60/60 end sepv_ends,
trunc(serv_start) serv_starts,
case when trunc(serv_end) >= trunc(next_serv_start) then trunc(next_serv_start)-1/24/60/60 else trunc(serv_end)+1-1/24/60/60 end serv_ends,
trunc(act_start) act_starts,
case when trunc(act_end) >= trunc(next_act_start) then trunc(next_act_start)-1/24/60/60 else trunc(act_end)+1-1/24/60/60 end act_ends,
--m1.*
m1.supa_start, m1.supa_end, m1.mipo_start, m1.mipo_end,
m1.sepv_ref_num, m1.maac, m1.susg, m1.fcit_billing_selector, m1.fcit_type_code, m1.fcit_desc, m1.fcit_fcdt_type_code, m1.monthly_disc_rate, 
m1.monthly_markdown, m1.sepv_start_real, m1.sety_ref_num, m1.prli_charge_value, m1.ficv_charge_value,
m1.DISC_START, m1.DISC_END, m1.cadc_ref_num, m1.PRECENTAGE, m1.COUNT_FOR_MONTHS, m1.COUNT_FOR_DAYS, m1.disc_descr, m1.DISC_BILLING_SELECTOR, m1.PRICING, m1.MINIMUM_PRICE,
m1.SUDI_START_DATE, m1.DISC_PERCENTAGE, m1.DISC_ABSOLUTE, m1.PRICE 
from (
select /*+ USE_HASH(qx q6) */ 
qx.serv_start, qx.serv_end, qx.supa_start, qx.supa_end, qx.maac, qx.susg, qx.sety_ref_num, q6.sepv_ref_num, ficv.charge_value ficv_charge_value, prli.charge_value prli_charge_value, 
 nvl(ficv.fcit_desc, fcit.description) fcit_desc, nvl(ficv.fcit_type_code, fcit.type_code) fcit_type_code, nvl(ficv.fcit_billing_selector, fcit.billing_selector) fcit_billing_selector, 
greatest(q6.start_date, date '2018-10-01') sepv_start,  least(nvl(q6.end_date, date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) sepv_end, 
q6.start_date sepv_start_real/**/, --q6.end_date_real sepv_end_real,
greatest(q5.start_date , date '2018-10-01') act_start,  least(nvl(q5.end_date , date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) act_end, 
nvl(ficv.fcit_fcdt_type_code, fcit.fcdt_type_code) fcit_fcdt_type_code, 
q7.monthly_disc_rate/**/, q7.monthly_markdown/**/, q7.start_date mipo_start, q7.end_date mipo_end,
lead(q6.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.serv_start, qx.supa_start order by q6.start_date) next_sepv_start, 
lead(qx.serv_start) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q6.start_date, q5.start_date, qx.supa_start order by qx.serv_start) next_serv_start, 
lead(q5.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q6.start_date, qx.serv_start, qx.supa_start order by q5.start_date) next_act_start,
q1.DISC_START, q1.DISC_END, q1.REF_NUM cadc_ref_num, q1.PRECENTAGE, q1.COUNT_FOR_MONTHS, q1.COUNT_FOR_DAYS, q1.DESCRIPTION disc_descr, q1.DISC_BILLING_SELECTOR, q1.PRICING, q1.MINIMUM_PRICE,
q1.SUDI_START_DATE, q1.DISC_PERCENTAGE, q1.DISC_ABSOLUTE, q1.PRICE 
from qx      JOIN q5 ON q5.susg_ref_num = qx.susg
        LEFT JOIN q6 ON q6.susg_ref_num = qx.susg and q6.sety_ref_num = qx.sety_ref_num
        LEFT JOIN q7 ON q7.susg_ref_num = qx.susg and q7.sety_ref_num = qx.sety_ref_num and nvl(q7.sept_type_code, qx.sept_type_code) = qx.sept_type_code 
        LEFT JOIN (
          select ficv.sepv_ref_num, ficv.sepa_ref_num,ficv.sept_type_code, ficv.sety_ref_num, ficv.charge_value,--ficv.*, 
          fcit.description fcit_desc, fcit.type_code fcit_type_code, fcit.billing_selector fcit_billing_selector, fcit.fcdt_type_code fcit_fcdt_type_code 
          from fixed_charge_values ficv, fixed_charge_item_types fcit
          WHERE NVL (ficv.end_date, date '2018-10-01'+1) > date '2018-10-01'
          AND ficv.start_date < date '2018-10-31' + 1
          and ficv.FCIT_CHARGE_CODE = fcit.TYPE_CODE
          and fcit.regular_charge='Y' and fcit.ONCE_OFF='N'
          ) ficv ON ficv.sety_ref_num = qx.sety_ref_num AND ficv.sept_type_code = qx.sept_type_code AND ficv.sepa_ref_num = q6.sepa_Ref_num and ficv.sepv_ref_num = q6.sepv_ref_num 
        LEFT JOIN (
          select * from price_lists 
          WHERE NVL (end_date, date '2018-10-01'+1) > date '2018-10-01'
          AND start_date < date '2018-10-31' + 1
          ) prli ON prli.sety_ref_num = qx.sety_ref_num AND nvl(prli.package_category, qx.cat) = qx.cat AND prli.fcty_type_code='RCH' AND prli.sepa_ref_num = q6.sepa_Ref_num and prli.sepv_ref_num = q6.sepv_ref_num
        LEFT JOIN fixed_charge_item_types fcit ON fcit.sety_ref_num = qx.sety_ref_num AND fcit.package_category = qx.cat and fcit.regular_charge='Y' and fcit.ONCE_OFF='N' 
        left join q1 on q1.susg_ref_num = qx.susg and q1.for_fcit_type_code = nvl(ficv.fcit_type_code, fcit.type_code) 
                                 and q1.for_billing_selector = nvl(ficv.fcit_billing_selector,fcit.billing_selector) 
                                 and nvl(q1.for_sepv_ref_num, q6.sepv_ref_num) = q6.sepv_ref_num
) m1 
where 1=1
)  main, service_param_values sepv
where 1=1
and  main.sepv_ref_num = sepv.ref_num
and main.prli_charge_value is not null
and main.sepv_starts<main.sepv_ends
and main.serv_starts<main.serv_ends
and main.act_starts<main.act_ends
and (main.mipo_start < main.supa_end AND main.mipo_end > main.supa_start OR main.mipo_start is null)
and (main.act_starts < main.supa_end AND main.act_ends > main.supa_start)  
and (main.sepv_starts < main.supa_end AND main.sepv_ends > main.supa_start)
and (main.serv_starts < main.supa_end AND main.serv_ends > main.supa_start)
and (main.sepv_starts < main.mipo_end AND main.sepv_ends > main.mipo_start OR main.mipo_start is null)
and (main.act_starts < main.mipo_end AND main.act_ends > main.mipo_start OR main.mipo_start is null)
and (main.serv_starts < main.mipo_end AND main.serv_ends > main.mipo_start OR main.mipo_start is null)
and (main.act_starts < main.sepv_ends AND main.act_ends > main.sepv_starts)  
and (main.act_starts < main.serv_ends AND main.act_ends > main.serv_starts)  
and (main.sepv_starts < main.serv_ends AND main.sepv_ends > main.serv_starts)
)
select maac, susg, 
round(charge_value*period_days_corr/month_days,2) period_charge, 
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
,start_date_corr, end_date_corr, period_days_corr, sepv_start_real, 
case when count_for_months is null and count_for_days is null or sudi_start_date is null then null else add_months(trunc(sudi_start_date), nvl(count_for_months,0)) + nvl(count_for_days,0) end sudi_end
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
select greatest(starts, disc_start) startx /**/, least(trunc(ends), disc_end) endx,  
bcdv1.description fcit_bise, bcdv2.description disc_bise, bcdv3.description disc_all_bise, 
t.maac, t.susg, t.fcit_billing_selector, t.fcit_type_code, t.fcit_desc, t.fcit_fcdt_type_code, t.starts, t.ends, t.monthly_disc_rate, t.monthly_markdown, t.sepv_start_real, t.sety_ref_num,
t.prli_charge_value, t.ficv_charge_value,
t.DISC_START, t.DISC_END, t.cadc_ref_num, t.PRECENTAGE, t.COUNT_FOR_MONTHS, t.COUNT_FOR_DAYS, t.disc_descr, t.DISC_BILLING_SELECTOR, t.PRICING, t.MINIMUM_PRICE,
t.SUDI_START_DATE, t.DISC_PERCENTAGE, t.DISC_ABSOLUTE, t.PRICE 
from discless t left join q2 on q2.for_fcit_type_code = t.fcit_type_code and q2.for_billing_selector = t.fcit_billing_selector
                                 and nvl(q2.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num
                 LEFT join bcc_domain_values bcdv1 on bcdv1.value_code = t.fcit_billing_selector and bcdv1.doma_type_code = 'BISE'
                 left join bcc_domain_values bcdv2 on bcdv2.value_code = t.disc_billing_selector and bcdv2.doma_type_code = 'BISE'
                 left join bcc_domain_values bcdv3 on bcdv3.value_code = q2.disc_billing_selector and bcdv3.doma_type_code = 'BISE'
where 1=1
) qq
where 1=1
and starts <= nvl(disc_end, starts)
and nvl(disc_start, trunc(ends)) <= trunc(ends) 
) qq2
) qq3
where end_date_corr >= start_date_corr
----------
and period_days_corr = month_days
--and sepv_start_real < :p_start_date
    --and sepv_start_real >= :p_start_date
and add_months(trunc(nvl(sudi_start_date, sysdate)), nvl(count_for_months,0)) + nvl(count_for_days,0) != :p_end_date
    --and add_months(trunc(nvl(sudi_start_date, sysdate)), nvl(count_for_months,0)) + nvl(count_for_days,0) = :p_end_date
order by 1, 2, 3,5
