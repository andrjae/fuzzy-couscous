with q4 as (
select susg_ref_num, sety_ref_num, start_date, end_date , count(*) over (partition by susg_ref_num, sety_ref_num) c
from status_periods stpe
where susg_ref_num =15790516
AND NVL (stpe.end_date, date '2018-08-01' + 1) > date '2018-08-01'
AND stpe.start_date < date '2018-08-31' + 1
AND stpe.sety_ref_num IN (5802234) /*(SELECT DISTINCT prli.sety_ref_num sety_ref_num
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
                                                    AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV'))*/
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
), q7 as (
select ftco.sept_type_code, ftco.mixed_packet_code, mose.sety_ref_num, ftco.susg_ref_num, ftco.start_date, coalesce(ftco.date_closed, ftco.end_date, trunc(sysdate)+1) nend 
from fixed_term_contracts ftco
, mixed_packet_orders  mipo
, mixed_order_services mose
where 1=1
   and mose.sety_ref_num = 5802234
AND ftco.mixed_packet_code = mipo.mixed_packet_code
AND ftco.ebs_order_number = mipo.ebs_order_number
AND Nvl(mipo.term_request_type, '*') <> 'NULLIFY'
AND mose.mipo_ref_num = mipo.ref_num
--AND coalesce(ftco.date_closed, ftco.end_date, date '2018-08-01') >= date '2018-08-01'
--AND ftco.start_date <= date '2018-08-31'
AND (coalesce(ftco.date_closed, ftco.end_date, date '2018-08-31'+1)  between date '2018-08-01' AND date '2018-08-31'
OR ftco.start_date between date '2018-08-01' AND date '2018-08-31')
)
select /*+ MONITOR LEADING(t)*/ t.maac, t.susg, t.cat, t.sept_type_code, 
greatest(trunc(t.start_date), date '2018-08-01') supa_start, least(trunc(nvl(t.end_date, date '2018-08-31')) + 1 - 1/24/60/60, date '2018-08-31' + 1 - 1/24/60/60) supa_end,
q4.sety_ref_num, 
greatest(q4.start_date, date '2018-08-01') serv_start, least(nvl(q4.end_date, date '2018-08-31' + 1 - 1/24/60/60), date '2018-08-31' + 1 - 1/24/60/60) serv_end, 
greatest(q5.start_date, date '2018-08-01') act_start,  least(nvl(q5.end_date, date '2018-08-31' + 1 - 1/24/60/60), date '2018-08-31' + 1 - 1/24/60/60) act_end, 
q6.sepa_ref_num, q6.sepv_ref_num, 
greatest(q6.start_date, date '2018-08-01') sepv_start,  least(nvl(q6.end_date, date '2018-08-31' + 1 - 1/24/60/60), date '2018-08-31' + 1 - 1/24/60/60) sepv_end, 
q5.rnk, last_status
,case when trunc(q5.start_date) = trunc(q5.end_date) OR trunc(q4.start_date) = trunc(q4.end_date) then 0 else 1 end active
--q4.*, q5.* --q6.*, q7.*, 
from table(xx_aj.get_list_susg_f (date '2018-08-01', date '2018-08-31', 
--102,
13796675, 
--14251850,
--14606161,
--15145486,
--15369942,
15815200, 
--15373059,
--15373059,
'MN4')) t JOIN q4 ON q4.susg_ref_num = t.susg
          JOIN q5 ON q5.susg_ref_num = t.susg
     LEFT JOIN q6 ON q6.susg_ref_num = t.susg and q6.sety_ref_num = q4.sety_ref_num
--     LEFT JOIN q7 ON q7.susg_ref_num = t.susg --and q7.sety_ref_num = q4.sety_ref_num
where 1=1
and t.susg=15790516
--and q7.susg_ref_num is not null
--and (t.start_date between q5.start_date and nvl(q5.end_date, date '2018-08-31'+1) OR q5.start_date between t.start_date and nvl(t.end_date, date '2018-08-31'+1))
order by t.susg

