drop table AJ_TEMP_1 PURGE

create table AJ_TEMP_1 AS 
with q4 as (
select susg_ref_num, sety_ref_num, start_date, end_date , count(*) over (partition by susg_ref_num, sety_ref_num) c
from status_periods stpe
where 1=1 --susg_ref_num =6177509
AND NVL (stpe.end_date, date '2018-10-01' + 1) > date '2018-10-01'
AND stpe.start_date < date '2018-10-31' + 1
AND stpe.sety_ref_num IN (SELECT DISTINCT prli.sety_ref_num sety_ref_num
                                                   FROM price_lists prli, service_types sety
                                                  WHERE NVL (prli.par_value_charge, 'N') = 'N'
                                                    AND prli.once_off = 'N'
                                                    AND prli.pro_rata = 'N'
                                                    AND prli.regular_charge = 'Y'
                                                    -- CHG-1241                   AND    prli.charge_value > 0
                                                    AND prli.start_date <= date '2018-10-31'
                                                    AND NVL (prli.end_date, date '2018-10-01') >= date '2018-10-01'
                                                    AND sety.ref_num = prli.sety_ref_num
                                                    AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV')
                                        UNION
                                        SELECT DISTINCT ficv.sety_ref_num sety_ref_num
                                                   FROM fixed_charge_values ficv
                                                       ,fixed_charge_item_types fcit
                                                       ,service_types sety
                                                  WHERE ficv.chca_type_code IS NULL
                                                    AND NVL (ficv.par_value_charge, 'N') = 'N'
                                                    -- CHG-1241                   AND    ficv.charge_value > 0
                                                    AND ficv.fcit_charge_code = fcit.type_code
                                                    AND fcit.once_off = 'N'
                                                    AND fcit.pro_rata = 'N'
                                                    AND fcit.regular_charge = 'Y'
                                                    AND ficv.start_date <= date '2018-10-31'
                                                    AND NVL (ficv.end_date, date '2018-10-01') >= date '2018-10-01'
                                                    AND sety.ref_num = ficv.sety_ref_num
                                                    AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV'))
), q5 as (
select susg_ref_num, start_date, nvl(end_date, date '2018-10-31' + 1 - 1/24/60/60) end_date, rnk, last_status from (
select susg_ref_num, start_date, end_date, status_code
,rank() over (partition by susg_ref_num order by start_date) rnk
,lag(status_code) over (partition by susg_ref_num order by start_date) last_status  
--,count(*) over (partition by susg_ref_num)
from ssg_statuses stpe
)
where  1=1
AND NVL (end_date, date '2018-10-01'+1) > date '2018-10-01'
AND start_date < date '2018-10-31' + 1
and status_code = 'AC'
), q6 as (
select susp.susg_ref_num, susp.sety_ref_num, susp.start_date, nvl(susp.end_date, date '2018-10-31' + 1 - 1/24/60/60) end_date, susp.sepa_ref_num, susp.sepv_ref_num 
from subs_service_parameters susp
where  1=1
AND NVL (susp.end_date, date '2018-10-01' + 1) > date '2018-10-01'
AND susp.start_date < date '2018-10-31' + 1
), qmix As (
select SEPT_TYPE_CODE, MIXED_PACKET_CODE, ebs_order_number, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, 
case when trunc(end_date) >= trunc(next_start_date) then trunc(next_start_date)-1/24/60/60 else trunc(end_date)+1-1/24/60/60 end END_DATE, 
NEXT_START_DATE, PREV_END_DATE, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num, monthly_disc_rate, monthly_markdown, monthly_billing_selector, monthly_fcit_type_code  
from (
select ftco.sept_type_code, ftco.mixed_packet_code, ftco.ebs_order_number, mose.sety_ref_num, ftco.susg_ref_num, ftco.start_date, ftco.end_date, 
lead(ftco.start_date) over (partition by mose.sety_ref_num, ftco.susg_ref_num order by ftco.start_date, ftco.end_date) next_start_date,  
lag(ftco.end_date) over (partition by mose.sety_ref_num, ftco.susg_ref_num order by ftco.end_date, ftco.start_date) prev_end_date, sety.station_param, sety.station_type,
mose.min_fix_monthly_fee, mose.mipo_ref_num, mose.mips_ref_num,  mips.monthly_disc_rate, mips.monthly_markdown, mipa.monthly_billing_selector, mipa.monthly_fcit_type_code
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
select sept_type_code, mixed_packet_code, ebs_order_number, sety_ref_num, susg_ref_num, start_date, end_date, coalesce(next_start_date, date '2018-10-31'+1) next_start_date, 
coalesce(prev_end_date, date '2018-10-01') prev_end_date, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num--
,  monthly_disc_rate, monthly_markdown, monthly_billing_selector, monthly_fcit_type_code
from qmix
where 1=1
AND (end_date  < date '2018-10-31'+1-1/24/60/60
OR start_date > date '2018-10-01')
), q7 as (
select '' SEPT_TYPE_CODE, '' MIXED_PACKET_CODE, null ebs_order_number, SETY_REF_NUM, SUSG_REF_NUM, --prev_date, start_date, end_date, next_date 
prev_end_date START_DATE, start_date -1/24/60/60 END_DATE , '' station_param, '' station_type, null min_fix_monthly_fee, null mipo_ref_num, null mips_ref_num-- ,null monthly_disc_rate, null monthly_markdown
,  null monthly_disc_rate, null monthly_markdown, null monthly_billing_selector, null monthly_fcit_type_code
from qmix1
where prev_end_date = date '2018-10-01'  --only month start not covered
and start_date > date '2018-10-01'
and start_date < end_date
union all
select '' SEPT_TYPE_CODE, '' MIXED_PACKET_CODE, null ebs_order_number, SETY_REF_NUM, SUSG_REF_NUM, --prev_date, start_date, end_date, next_date --
end_date+1/24/60/60 START_DATE, next_start_date -1/24/60/60 END_DATE, '' station_param, '' station_type, null min_fix_monthly_fee, null mipo_ref_num, null mips_ref_num--, null monthly_disc_rate, null monthly_markdown 
, null monthly_disc_rate, null monthly_markdown, null monthly_billing_selector, null monthly_fcit_type_code
from qmix1 
where next_start_date > end_date+1/24/60/60
union all
select SEPT_TYPE_CODE, MIXED_PACKET_CODE, ebs_order_number, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, END_DATE, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num--,  monthly_disc_rate, monthly_markdown
,  monthly_disc_rate, monthly_markdown, monthly_billing_selector, monthly_fcit_type_code
from qmix1
union all
select SEPT_TYPE_CODE, MIXED_PACKET_CODE, ebs_order_number, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, END_DATE, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num--,  monthly_disc_rate, monthly_markdown
,  monthly_disc_rate, monthly_markdown, monthly_billing_selector, monthly_fcit_type_code
from qmix0
), qx AS (
select /* CARDINALITY (t 2000000) NO_PARALLEL */ /*+ LEADING(t) USE_HASH(t q4) NO_PARALLEL */ t.maac, t.susg, t.cat, t.sept_type_code, 
greatest(trunc(t.start_date), date '2018-10-01') supa_start, least(trunc(nvl(t.end_date, date '2018-10-31')) + 1 - 1/24/60/60, date '2018-10-31' + 1 - 1/24/60/60) supa_end,
q4.sety_ref_num, 
greatest(q4.start_date + 0.125, date '2018-10-01') serv_start, least(nvl(q4.end_date + 0.125, date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) serv_end 
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
)
select greatest(supa_start, serv_starts, sepv_starts, act_starts, nvl(mipo_start, date '2018-10-01')) starts, 
least(supa_end, serv_ends, sepv_ends, act_ends, nvl(mipo_end, date '2018-10-31'+1)) ends,
count(*) over (partition by susg) c, 
main.* from (
select  trunc(sepv_start) sepv_starts,
case when trunc(sepv_end) >= trunc(next_sepv_start) then trunc(next_sepv_start)-1/24/60/60 else trunc(sepv_end)+1-1/24/60/60 end sepv_ends,
trunc(serv_start) serv_starts,
case when trunc(serv_end) >= trunc(next_serv_start) then trunc(next_serv_start+0.125)-1/24/60/60 else trunc(serv_end)+1-1/24/60/60 end serv_ends,
trunc(act_start) act_starts,
case when trunc(act_end) >= trunc(next_act_start) then trunc(next_act_start)-1/24/60/60 else trunc(act_end)+1-1/24/60/60 end act_ends,
m1.* from (
select /*+ USE_HASH(qx q6) */ qx.* , 
q6.sepa_ref_num, q6.sepv_ref_num, 
greatest(q6.start_date + 0.125, date '2018-10-01') sepv_start,  least(nvl(q6.end_date + 0.125, date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) sepv_end, 
greatest(q5.start_date + 0.125, date '2018-10-01') act_start,  least(nvl(q5.end_date + 0.125, date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) act_end, 
q5.rnk, q5.last_status,
ficv.charge_value ficv_charge_value, prli.charge_value prli_charge_value,  
nvl(ficv.fcit_desc, fcit.description) fcit_desc, nvl(ficv.fcit_type_code, fcit.type_code) fcit_type_code, nvl(ficv.fcit_taty_type_code, fcit.taty_type_code) fcit_taty_type_code, 
nvl(ficv.fcit_billing_selector, fcit.billing_selector) fcit_billing_selector, nvl(ficv.fcit_charge_parameter, fcit.valid_charge_parameter) fcit_charge_parameter, 
nvl(ficv.fcit_first_prorated_charge, fcit.first_prorated_charge) fcit_first_prorated_charge, nvl(ficv.fcit_last_prorated_charge, fcit.last_prorated_charge) fcit_last_prorated_charge, 
nvl(ficv.fcit_sety_first_prorated, fcit.sety_first_prorated) fcit_sety_first_prorated, nvl(ficv.fcit_regular_charge, fcit.regular_charge) fcit_regular_charge, 
nvl(ficv.fcit_once_off, fcit.once_off) fcit_once_off,  nvl(ficv.fcit_pro_rata, fcit.pro_rata) fcit_pro_rata, nvl(ficv.fcit_package_category, fcit.package_category) fcit_package_category, 
nvl(ficv.fcit_fcdt_type_code, fcit.fcdt_type_code) fcit_fcdt_type_code, prli.package_category prli_package_category, 
row_number() over (partition by qx.susg, qx.sept_type_code, qx.sety_ref_num, q6.sepa_ref_num, q6.sepv_ref_num, q7.mixed_packet_code order by prli.package_category nulls last) rp,
q7.sept_type_code mipo_sept_type, q7.mixed_packet_code, q7.ebs_order_number, q7.start_date mipo_start, q7.end_date mipo_end, q7.sety_ref_num mose_sety_ref_num,
q7.station_param, q7.station_type , q7.min_fix_monthly_fee, q7.mipo_ref_num, q7.mips_ref_num, q7.monthly_disc_rate, q7.monthly_markdown, q7.monthly_billing_selector
, q7.monthly_fcit_type_code,
lead(q6.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.serv_start, qx.supa_start order by q6.start_date) + 0.125 next_sepv_start, 
lead(qx.serv_start) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q6.start_date, q5.start_date, qx.supa_start order by qx.serv_start) next_serv_start, 
lead(q5.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q6.start_date, qx.serv_start, qx.supa_start order by q5.start_date) + 0.125 next_act_start 
--lead(q6.end_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.supa_start order by q6.start_date) next_sepv_end, 
--lag(q6.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.supa_start order by q6.start_date) prev_sepv_start, 
--lag(q6.end_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.supa_start order by q6.start_date) prev_sepv_end
from qx      JOIN q5 ON q5.susg_ref_num = qx.susg
        LEFT JOIN q6 ON q6.susg_ref_num = qx.susg and q6.sety_ref_num = qx.sety_ref_num
        LEFT JOIN q7 ON q7.susg_ref_num = qx.susg and q7.sety_ref_num = qx.sety_ref_num and nvl(q7.sept_type_code, qx.sept_type_code) = qx.sept_type_code 
        LEFT JOIN (
          select ficv.*, fcit.description fcit_desc, fcit.type_code fcit_type_code, fcit.taty_type_code fcit_taty_type_code, fcit.billing_selector fcit_billing_selector, 
          fcit.valid_charge_parameter  fcit_charge_parameter, fcit.first_prorated_charge fcit_first_prorated_charge, fcit.last_prorated_charge fcit_last_prorated_charge,
          fcit.sety_first_prorated fcit_sety_first_prorated, fcit.regular_charge fcit_regular_charge, fcit.once_off fcit_once_off, fcit.pro_rata fcit_pro_rata, 
          fcit.package_category fcit_package_category, fcit.fcdt_type_code fcit_fcdt_type_code
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
) m1 
where 1=1
--and m1.sepv_end between trunc(m1.sepv_end) and trunc(m1.sepv_end)+3/24 
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
order by maac, susg




drop table AJ_TEMP_2 PURGE

create table AJ_TEMP_2 AS 
with q4 as (
select susg_ref_num, sety_ref_num, start_date, end_date , count(*) over (partition by susg_ref_num, sety_ref_num) c
from status_periods stpe
where 1=1 --susg_ref_num =6177509
AND NVL (stpe.end_date, date '2018-10-01' + 1) > date '2018-10-01'
AND stpe.start_date < date '2018-10-31' + 1
AND stpe.sety_ref_num IN (SELECT DISTINCT prli.sety_ref_num sety_ref_num
                                                   FROM price_lists prli, service_types sety
                                                  WHERE NVL (prli.par_value_charge, 'N') = 'N'
                                                    AND prli.once_off = 'N'
                                                    AND prli.pro_rata = 'N'
                                                    AND prli.regular_charge = 'Y'
                                                    -- CHG-1241                   AND    prli.charge_value > 0
                                                    AND prli.start_date <= date '2018-10-31'
                                                    AND NVL (prli.end_date, date '2018-10-01') >= date '2018-10-01'
                                                    AND sety.ref_num = prli.sety_ref_num
                                                    AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV')
                                        UNION
                                        SELECT DISTINCT ficv.sety_ref_num sety_ref_num
                                                   FROM fixed_charge_values ficv
                                                       ,fixed_charge_item_types fcit
                                                       ,service_types sety
                                                  WHERE ficv.chca_type_code IS NULL
                                                    AND NVL (ficv.par_value_charge, 'N') = 'N'
                                                    -- CHG-1241                   AND    ficv.charge_value > 0
                                                    AND ficv.fcit_charge_code = fcit.type_code
                                                    AND fcit.once_off = 'N'
                                                    AND fcit.pro_rata = 'N'
                                                    AND fcit.regular_charge = 'Y'
                                                    AND ficv.start_date <= date '2018-10-31'
                                                    AND NVL (ficv.end_date, date '2018-10-01') >= date '2018-10-01'
                                                    AND sety.ref_num = ficv.sety_ref_num
                                                    AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV'))
), q5 as (
select susg_ref_num, start_date, nvl(end_date, date '2018-10-31' + 1 - 1/24/60/60) end_date, end_date end_date_real, rnk, last_status from (
select susg_ref_num, start_date, end_date, status_code
,rank() over (partition by susg_ref_num order by start_date) rnk
,lag(status_code) over (partition by susg_ref_num order by start_date) last_status  
--,count(*) over (partition by susg_ref_num)
from ssg_statuses stpe
)
where  1=1
AND NVL (end_date, date '2018-10-01'+1) > date '2018-10-01'
AND start_date < date '2018-10-31' + 1
and status_code = 'AC'
), q6 as (
select susp.susg_ref_num, susp.sety_ref_num, susp.start_date, nvl(susp.end_date, date '2018-10-31' + 1 - 1/24/60/60) end_date, susp.end_date end_date_real, susp.sepa_ref_num, susp.sepv_ref_num 
from subs_service_parameters susp
where  1=1
AND NVL (susp.end_date, date '2018-10-01' + 1) > date '2018-10-01'
AND susp.start_date < date '2018-10-31' + 1
), qmix As (
select SEPT_TYPE_CODE, MIXED_PACKET_CODE, ebs_order_number, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, 
case when trunc(end_date) >= trunc(next_start_date) then trunc(next_start_date)-1/24/60/60 else trunc(end_date)+1-1/24/60/60 end END_DATE, end_date end_date_real,
NEXT_START_DATE, PREV_END_DATE, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num, monthly_disc_rate, monthly_markdown, monthly_billing_selector, monthly_fcit_type_code  
from (
select ftco.sept_type_code, ftco.mixed_packet_code, ftco.ebs_order_number, mose.sety_ref_num, ftco.susg_ref_num, ftco.start_date, ftco.end_date, 
lead(ftco.start_date) over (partition by mose.sety_ref_num, ftco.susg_ref_num order by ftco.start_date, ftco.end_date) next_start_date,  
lag(ftco.end_date) over (partition by mose.sety_ref_num, ftco.susg_ref_num order by ftco.end_date, ftco.start_date) prev_end_date, sety.station_param, sety.station_type,
mose.min_fix_monthly_fee, mose.mipo_ref_num, mose.mips_ref_num,  mips.monthly_disc_rate, mips.monthly_markdown, mipa.monthly_billing_selector, mipa.monthly_fcit_type_code
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
select sept_type_code, mixed_packet_code, ebs_order_number, sety_ref_num, susg_ref_num, start_date, end_date, end_date_real, coalesce(next_start_date, date '2018-10-31'+1) next_start_date, 
coalesce(prev_end_date, date '2018-10-01') prev_end_date, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num--
,  monthly_disc_rate, monthly_markdown, monthly_billing_selector, monthly_fcit_type_code
from qmix
where 1=1
AND (end_date  < date '2018-10-31'+1-1/24/60/60
OR start_date > date '2018-10-01')
), q7 as (
select '' SEPT_TYPE_CODE, '' MIXED_PACKET_CODE, null ebs_order_number, SETY_REF_NUM, SUSG_REF_NUM, --prev_date, start_date, end_date, next_date 
prev_end_date START_DATE, start_date -1/24/60/60 END_DATE , '' station_param, '' station_type, null min_fix_monthly_fee, null mipo_ref_num, null mips_ref_num-- ,null monthly_disc_rate, null monthly_markdown
,  null monthly_disc_rate, null monthly_markdown, null monthly_billing_selector, null monthly_fcit_type_code, end_date_real
from qmix1
where prev_end_date = date '2018-10-01'  --only month start not covered
and start_date > date '2018-10-01'
and start_date < end_date
union all
select '' SEPT_TYPE_CODE, '' MIXED_PACKET_CODE, null ebs_order_number, SETY_REF_NUM, SUSG_REF_NUM, --prev_date, start_date, end_date, next_date --
end_date+1/24/60/60 START_DATE, next_start_date -1/24/60/60 END_DATE, '' station_param, '' station_type, null min_fix_monthly_fee, null mipo_ref_num, null mips_ref_num--, null monthly_disc_rate, null monthly_markdown 
, null monthly_disc_rate, null monthly_markdown, null monthly_billing_selector, null monthly_fcit_type_code, end_date_real
from qmix1 
where next_start_date > end_date+1/24/60/60
union all
select SEPT_TYPE_CODE, MIXED_PACKET_CODE, ebs_order_number, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, END_DATE, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num--,  monthly_disc_rate, monthly_markdown
,  monthly_disc_rate, monthly_markdown, monthly_billing_selector, monthly_fcit_type_code, end_date_real
from qmix1
union all
select SEPT_TYPE_CODE, MIXED_PACKET_CODE, ebs_order_number, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, END_DATE, station_param, station_type, min_fix_monthly_fee, mipo_ref_num, mips_ref_num--,  monthly_disc_rate, monthly_markdown
,  monthly_disc_rate, monthly_markdown, monthly_billing_selector, monthly_fcit_type_code, end_date_real
from qmix0
), qx AS (
select /* CARDINALITY (t 2000000) NO_PARALLEL */ /*+ LEADING(t) USE_HASH(t q4) NO_PARALLEL */ t.maac, t.susg, t.cat, t.sept_type_code, 
greatest(trunc(t.start_date), date '2018-10-01') supa_start, least(trunc(nvl(t.end_date, date '2018-10-31')) + 1 - 1/24/60/60, date '2018-10-31' + 1 - 1/24/60/60) supa_end,
t.start_date supa_start_real, t.end_date supa_end_real,
q4.sety_ref_num, 
greatest(q4.start_date + 0.125, date '2018-10-01') serv_start, least(nvl(q4.end_date + 0.125, date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) serv_end, 
q4.start_date serv_start_real, q4.end_date serv_end_real
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
)
select greatest(supa_start, serv_starts, sepv_starts, act_starts, nvl(mipo_start, date '2018-10-01')) starts, 
least(supa_end, serv_ends, sepv_ends, act_ends, nvl(mipo_end, date '2018-10-31'+1)) ends,
count(*) over (partition by susg) c, 
main.* from (
select  trunc(sepv_start) sepv_starts, 
case when trunc(sepv_end) >= trunc(next_sepv_start) then trunc(next_sepv_start)-1/24/60/60 else trunc(sepv_end)+1-1/24/60/60 end sepv_ends,
trunc(serv_start) serv_starts,
case when trunc(serv_end) >= trunc(next_serv_start) then trunc(next_serv_start+0.125)-1/24/60/60 else trunc(serv_end)+1-1/24/60/60 end serv_ends,
trunc(act_start) act_starts,
case when trunc(act_end) >= trunc(next_act_start) then trunc(next_act_start)-1/24/60/60 else trunc(act_end)+1-1/24/60/60 end act_ends,
m1.* from (
select /*+ USE_HASH(qx q6) */ qx.* , 
q6.sepa_ref_num, q6.sepv_ref_num, 
greatest(q6.start_date + 0.125, date '2018-10-01') sepv_start,  least(nvl(q6.end_date + 0.125, date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) sepv_end, 
q6.start_date sepv_start_real, q6.end_date_real sepv_end_real,
greatest(q5.start_date + 0.125, date '2018-10-01') act_start,  least(nvl(q5.end_date + 0.125, date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) act_end, 
q5.start_date act_start_real, q5.end_date_real act_end_real,
q5.rnk, q5.last_status,
ficv.charge_value ficv_charge_value, prli.charge_value prli_charge_value,  
nvl(ficv.fcit_desc, fcit.description) fcit_desc, nvl(ficv.fcit_type_code, fcit.type_code) fcit_type_code, nvl(ficv.fcit_taty_type_code, fcit.taty_type_code) fcit_taty_type_code, 
nvl(ficv.fcit_billing_selector, fcit.billing_selector) fcit_billing_selector, nvl(ficv.fcit_charge_parameter, fcit.valid_charge_parameter) fcit_charge_parameter, 
nvl(ficv.fcit_first_prorated_charge, fcit.first_prorated_charge) fcit_first_prorated_charge, nvl(ficv.fcit_last_prorated_charge, fcit.last_prorated_charge) fcit_last_prorated_charge, 
nvl(ficv.fcit_sety_first_prorated, fcit.sety_first_prorated) fcit_sety_first_prorated, nvl(ficv.fcit_regular_charge, fcit.regular_charge) fcit_regular_charge, 
nvl(ficv.fcit_once_off, fcit.once_off) fcit_once_off,  nvl(ficv.fcit_pro_rata, fcit.pro_rata) fcit_pro_rata, nvl(ficv.fcit_package_category, fcit.package_category) fcit_package_category, 
nvl(ficv.fcit_fcdt_type_code, fcit.fcdt_type_code) fcit_fcdt_type_code, prli.package_category prli_package_category, 
row_number() over (partition by qx.susg, qx.sept_type_code, qx.sety_ref_num, q6.sepa_ref_num, q6.sepv_ref_num, q7.mixed_packet_code order by prli.package_category nulls last) rp,
q7.sept_type_code mipo_sept_type, q7.mixed_packet_code, q7.ebs_order_number, q7.start_date mipo_start, q7.end_date mipo_end, q7.end_date_real mipo_end_real, q7.sety_ref_num mose_sety_ref_num,
q7.station_param, q7.station_type , q7.min_fix_monthly_fee, q7.mipo_ref_num, q7.mips_ref_num, q7.monthly_disc_rate, q7.monthly_markdown, q7.monthly_billing_selector
, q7.monthly_fcit_type_code,
lead(q6.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.serv_start, qx.supa_start order by q6.start_date) + 0.125 next_sepv_start, 
lead(qx.serv_start) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q6.start_date, q5.start_date, qx.supa_start order by qx.serv_start) next_serv_start, 
lead(q5.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q6.start_date, qx.serv_start, qx.supa_start order by q5.start_date) + 0.125 next_act_start 
--lead(q6.end_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.supa_start order by q6.start_date) next_sepv_end, 
--lag(q6.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.supa_start order by q6.start_date) prev_sepv_start, 
--lag(q6.end_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.supa_start order by q6.start_date) prev_sepv_end
from qx      JOIN q5 ON q5.susg_ref_num = qx.susg
        LEFT JOIN q6 ON q6.susg_ref_num = qx.susg and q6.sety_ref_num = qx.sety_ref_num
        LEFT JOIN q7 ON q7.susg_ref_num = qx.susg and q7.sety_ref_num = qx.sety_ref_num and nvl(q7.sept_type_code, qx.sept_type_code) = qx.sept_type_code 
        LEFT JOIN (
          select ficv.*, fcit.description fcit_desc, fcit.type_code fcit_type_code, fcit.taty_type_code fcit_taty_type_code, fcit.billing_selector fcit_billing_selector, 
          fcit.valid_charge_parameter  fcit_charge_parameter, fcit.first_prorated_charge fcit_first_prorated_charge, fcit.last_prorated_charge fcit_last_prorated_charge,
          fcit.sety_first_prorated fcit_sety_first_prorated, fcit.regular_charge fcit_regular_charge, fcit.once_off fcit_once_off, fcit.pro_rata fcit_pro_rata, 
          fcit.package_category fcit_package_category, fcit.fcdt_type_code fcit_fcdt_type_code
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
) m1 
where 1=1
--and m1.sepv_end between trunc(m1.sepv_end) and trunc(m1.sepv_end)+3/24 
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
order by maac, susg


main, service_param_values sepv
where main.sepv_ref_num = sepv.ref_num
and main.prli_charge_value is not null
and (main.mipo_start < main.supa_end AND main.mipo_end > main.supa_start OR main.mipo_start is null)
and (main.act_start < main.supa_end AND main.act_end > main.supa_start)  
--where  sepv_end - sepv_start < 0.5
--and trunc(sepv_start) = trunc(prev_sepv_start)         
order by maac, susg


where 1=1
--and t.susg=15814963
--and q7.susg_ref_num is not null
--and (t.start_date between q5.start_date and nvl(q5.end_date, date '2018-10-31'+1) OR q5.start_date between t.start_date and nvl(t.end_date, date '2018-10-31'+1))
order by t.susg

