with q4 as (
select susg_ref_num, sety_ref_num, start_date, end_date , count(*) over (partition by susg_ref_num, sety_ref_num) c
from status_periods stpe
where 1=1--susg_ref_num =15790516
AND NVL (stpe.end_date, date '2018-08-01' + 1) > date '2018-08-01'
AND stpe.start_date < date '2018-08-31' + 1
AND stpe.sety_ref_num IN  (SELECT DISTINCT prli.sety_ref_num sety_ref_num
                                                   FROM price_lists prli, service_types sety
                                                  WHERE NVL (prli.par_value_charge, 'N') = 'N'
                                                    AND prli.once_off = 'N'
                                                    AND prli.pro_rata = 'N'
                                                    AND prli.regular_charge = 'Y'
                                                    -- CHG-1241                   AND    prli.charge_value > 0
                                                    AND prli.start_date <= date '2018-08-31'
                                                    AND NVL (prli.end_date, date '2018-08-01') >= date '2018-08-01'
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
                                                    AND ficv.start_date <= date '2018-08-31'
                                                    AND NVL (ficv.end_date, date '2018-08-01') >= date '2018-08-01'
                                                    AND sety.ref_num = ficv.sety_ref_num
                                                    AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV'))
), q5 as (
select susg_ref_num, start_date, end_date, rnk, last_status from (
select susg_ref_num, start_date, end_date, status_code
,rank() over (partition by susg_ref_num order by start_date) rnk
,lag(status_code) over (partition by susg_ref_num order by start_date) last_status  
--,count(*) over (partition by susg_ref_num)
from ssg_statuses stpe
)
where  1=1
AND NVL (end_date, date '2018-08-01'+1) > date '2018-08-01'
AND start_date < date '2018-08-31' + 1
and status_code = 'AC'
), q6 as (
select susg_ref_num, sety_ref_num, start_date, end_date, sepa_ref_num, sepv_ref_num from subs_service_parameters susp
where  1=1
AND NVL (susp.end_date, date '2018-08-01' + 1) > date '2018-08-01'
AND susp.start_date < date '2018-08-31' + 1
), qmix As (
select SEPT_TYPE_CODE, MIXED_PACKET_CODE, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, 
case when trunc(end_date) >= trunc(next_start_date) then trunc(next_start_date)-1/24/60/60 else trunc(end_date)+1-1/24/60/60 end END_DATE, 
NEXT_START_DATE, PREV_END_DATE  
from (
select ftco.sept_type_code, ftco.mixed_packet_code, mose.sety_ref_num, ftco.susg_ref_num, ftco.start_date, ftco.end_date, 
lead(ftco.start_date) over (partition by mose.sety_ref_num, ftco.susg_ref_num order by ftco.start_date, ftco.end_date) next_start_date,  
lag(ftco.end_date) over (partition by mose.sety_ref_num, ftco.susg_ref_num order by ftco.end_date, ftco.start_date) prev_end_date
from (
select sept_type_code, mixed_packet_code, susg_ref_num, greatest(start_date, date '2018-08-01') start_date,
least(coalesce(case when coalesce(date_closed, end_date)=trunc(coalesce(date_closed, end_date)) 
         then coalesce(date_closed, end_date)+1-1/24/60/60 else coalesce(date_closed, end_date) end,
         date '2018-08-31'+1-1/24/60/60), date '2018-08-31'+1-1/24/60/60) end_date, date_closed, ebs_order_number 
from fixed_term_contracts ftco 
) ftco
, mixed_packet_orders  mipo
, mixed_order_services mose
where 1=1
   and mose.sety_ref_num = 5802234
AND ftco.mixed_packet_code = mipo.mixed_packet_code
AND ftco.ebs_order_number = mipo.ebs_order_number
AND Nvl(mipo.term_request_type, '*') <> 'NULLIFY'
AND mose.mipo_ref_num = mipo.ref_num
AND ftco.start_date < date '2018-08-31'+1
AND coalesce(ftco.end_date, date '2018-08-31') >= date '2018-08-01'
)
), qmix0 AS (
select * 
from qmix
where 1=1
and end_date = date '2018-08-31'+1-1/24/60/60
and start_date = date '2018-08-01'
), qmix1 AS (
select sept_type_code, mixed_packet_code, sety_ref_num, susg_ref_num, start_date, end_date, coalesce(next_start_date, date '2018-08-31'+1) next_start_date, 
coalesce(prev_end_date, date '2018-08-01') prev_end_date 
from qmix
where 1=1
and start_date < end_date
AND (end_date  < date '2018-08-31'+1-1/24/60/60
OR start_date > date '2018-08-01')
), q7 as (
select '' SEPT_TYPE_CODE, '' MIXED_PACKET_CODE, SETY_REF_NUM, SUSG_REF_NUM, --prev_date, start_date, end_date, next_date 
prev_end_date START_DATE, start_date -1/24/60/60 END_DATE 
from qmix1
where prev_end_date = date '2018-08-01'  --only month start not covered
and start_date > date '2018-08-01'
union all
select '' SEPT_TYPE_CODE, '' MIXED_PACKET_CODE, SETY_REF_NUM, SUSG_REF_NUM, --prev_date, start_date, end_date, next_date --
end_date+1/24/60/60 START_DATE, next_start_date -1/24/60/60 END_DATE 
from qmix1
where next_start_date > end_date+1/24/60/60
union all
select SEPT_TYPE_CODE, MIXED_PACKET_CODE, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, END_DATE
from qmix1
union all
select SEPT_TYPE_CODE, MIXED_PACKET_CODE, SETY_REF_NUM, SUSG_REF_NUM, START_DATE, END_DATE
from qmix0
), qx AS (
select /* LEADING(t) USE_HASH(t q4) NO_PARALLEL */ t.maac, t.susg, t.cat, t.sept_type_code, 
greatest(trunc(t.start_date), date '2018-08-01') supa_start, least(trunc(nvl(t.end_date, date '2018-08-31')) + 1 - 1/24/60/60, date '2018-08-31' + 1 - 1/24/60/60) supa_end,
q4.sety_ref_num, 
greatest(q4.start_date+0.125, date '2018-08-01') serv_start, least(nvl(q4.end_date+0.125, date '2018-08-31' + 1 - 1/24/60/60), date '2018-08-31' + 1 - 1/24/60/60) serv_end 
from table(xx_aj.get_list_susg_f (date '2018-08-01', date '2018-08-31', 
--102,
--13796675, 
--14251850,
--14606161,
--15145486,
--15369942,
--15824129
15215382,
15215382
--3743768,
--3743768 
--15222851,
--15222851
--15813374,
--15813374
--15806974,
--15806974
, null
)) t JOIN q4 ON q4.susg_ref_num = t.susg
where t.susg = 15215382
--15222851
--15813374
--15806974
)
select greatest(supa_start, serv_starts, sepv_starts, act_starts, nvl(mipo_start, date '2018-08-01')) starts, 
least(supa_end, serv_ends, sepv_ends, act_ends, nvl(mipo_end, date '2018-08-31'+1)) ends,
count(*) over (partition by susg) c, 
main.* from (
select  trunc(sepv_start) sepv_starts,
case when trunc(sepv_end) >= trunc(next_sepv_start) then trunc(next_sepv_start)-1/24/60/60 else trunc(sepv_end)+1-1/24/60/60 end sepv_ends,
trunc(serv_start) serv_starts,
case when trunc(serv_end) >= trunc(next_serv_start) then trunc(next_serv_start+0.125)-1/24/60/60 else trunc(serv_end)+1-1/24/60/60 end serv_ends,
trunc(act_start) act_starts,
case when trunc(act_end) >= trunc(next_act_start) then trunc(next_act_start)-1/24/60/60 else trunc(act_end)+1-1/24/60/60 end act_ends,
m1.* from (
select /* USE_HASH(qx q6) */ qx.* , 
q6.sepa_ref_num, q6.sepv_ref_num, 
greatest(q6.start_date+0.125, date '2018-08-01') sepv_start,  least(nvl(q6.end_date+0.125, date '2018-08-31' + 1 - 1/24/60/60), date '2018-08-31' + 1 - 1/24/60/60) sepv_end, 
lead(q6.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.serv_start, qx.supa_start order by q6.start_date) +0.125 next_sepv_start, 
lead(qx.serv_start) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q6.start_date, q5.start_date, qx.supa_start order by qx.serv_start) next_serv_start, 
lead(q5.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q6.start_date, qx.serv_start, qx.supa_start order by q5.start_date) +0.125 next_act_start, 
--lead(q6.end_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.supa_start order by q6.start_date) next_sepv_end, 
--lag(q6.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.supa_start order by q6.start_date) prev_sepv_start, 
--lag(q6.end_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q7.start_date, q5.start_date, qx.supa_start order by q6.start_date) prev_sepv_end,
greatest(q5.start_date+0.125, date '2018-08-01') act_start,  least(nvl(q5.end_date+0.125, date '2018-08-31' + 1 - 1/24/60/60), date '2018-08-31' + 1 - 1/24/60/60) act_end, 
q5.rnk, q5.last_status,
ficv.charge_value ficv_charge_value, prli.charge_value prli_charge_value,
q7.sept_type_code mipo_sept_type, q7.mixed_packet_code, q7.start_date mipo_start, q7.end_date mipo_end
from qx      JOIN q5 ON q5.susg_ref_num = qx.susg
        LEFT JOIN q6 ON q6.susg_ref_num = qx.susg and q6.sety_ref_num = qx.sety_ref_num
        LEFT JOIN q7 ON q7.susg_ref_num = qx.susg
        LEFT JOIN (
          select ficv.* from fixed_charge_values ficv, fixed_charge_item_types fcit
          WHERE NVL (ficv.end_date, date '2018-08-01'+1) > date '2018-08-01'
          AND ficv.start_date < date '2018-08-31' + 1
          and ficv.FCIT_CHARGE_CODE = fcit.TYPE_CODE
          and fcit.regular_charge='Y' and fcit.ONCE_OFF='N'
          ) ficv ON ficv.sety_ref_num = qx.sety_ref_num AND ficv.sept_type_code = qx.sept_type_code AND ficv.sepa_ref_num = q6.sepa_Ref_num and ficv.sepv_ref_num = q6.sepv_ref_num 
        LEFT JOIN (
          select * from price_lists
          WHERE NVL (end_date, date '2018-08-01'+1) > date '2018-08-01'
          AND start_date < date '2018-08-31' + 1
          ) prli ON prli.sety_ref_num = qx.sety_ref_num AND prli.package_category is null AND prli.fcty_type_code='RCH' AND prli.sepa_ref_num = q6.sepa_Ref_num and prli.sepv_ref_num = q6.sepv_ref_num
) m1
where 1=1
--and trunc(sepv_start) != nvl(trunc(prev_sepv_start),date '2018-08-31'+1) 
)  main        
where 1=1
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



where 1=1
--and t.susg=15814963
--and q7.susg_ref_num is not null
--and (t.start_date between q5.start_date and nvl(q5.end_date, date '2018-08-31'+1) OR q5.start_date between t.start_date and nvl(t.end_date, date '2018-08-31'+1))
order by t.susg

