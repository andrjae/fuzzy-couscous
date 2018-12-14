drop table aj_temp_31 purge

create table aj_temp_31 as 
select * from aj_temp_3
where 1=0

insert into aj_temp_31
with ftco0 as (
select ftco.ref_num ftco_ref_num, ftco.sept_type_code, ftco.mixed_packet_code, ftco.susg_ref_num, ftco.ebs_order_number,
greatest(nvl(ftco.start_date, :p_start_date), :p_start_date) start_date_c, ftco.end_date, ftco.date_closed, 
trunc(least(coalesce(date_closed, end_date, :p_end_date),coalesce(end_date, :p_end_date), :p_end_date)) end_date_c
from fixed_term_contracts ftco
), ftco1 as (
select ftco0.ftco_ref_num, ftco0.susg_ref_num,  
lead(start_date_c) over (partition by susg_ref_num order by start_date_c, end_date_c) next_start_date,  
lag(end_date_c) over (partition by susg_ref_num order by end_date_c, start_date_c) prev_end_date,
start_date_c,
least(end_date_c, nvl(lead(start_date_c) over (partition by susg_ref_num order by start_date_c, end_date_c) - 1, end_date_c), :p_end_date) end_date_c 
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
   and mose.sety_ref_num = 5802234
AND ftco0.mixed_packet_code = mipo.mixed_packet_code
AND ftco0.ebs_order_number = mipo.ebs_order_number
AND Nvl(mipo.term_request_type, '*') <> 'NULLIFY'
AND mose.mipo_ref_num = mipo.ref_num
AND (mips.monthly_disc_rate is not null or mips.MONTHLY_MARKDOWN is not null)
AND ftco0.start_date_c <  :p_end_date+1
and     ftco0.end_date_c >= :p_start_date
and     ftco0.end_date_c >= ftco0.start_date_c
), ftco_disc as (
select ftco_ref_num, susg_ref_num, start_date_c mipo_start_date, end_date_c mipo_end_date, 1 discounted
from ftco1
union all
select ftco_ref_num, susg_ref_num, end_date_c + 1 mipo_start_date, nvl(next_start_date - 1 , :p_end_date) mipo_end_date, 0 discounted
from ftco1
where end_date_c < :p_end_date
and nvl(next_start_date - 1 , :p_end_date) >=  end_date_c + 1
union all
select ftco_ref_num, susg_ref_num, :p_start_date mipo_start_date, start_date_c-1 mipo_end_date, 0 discounted  
from ftco1
where start_date_c > :p_start_date
and prev_end_date is null
), q1 as (
select greatest(sudi.start_date, cadc.cadc_start_date, :p_start_date) disc_start
,least(nvl(trunc(sudi.end_date), :p_end_date), cadc.cadc_end_date, 
   case when cadc.count_for_months is not null or cadc.count_for_days is not null then ADD_MONTHS(sudi.start_date, NVL(cadc.count_for_months,0))+NVL(cadc.count_for_days,0) else  :p_end_date end,
   :p_end_date) disc_end
,cadc.ref_num, cadc.precentage, cadc.count_for_months, cadc.count_for_days, cadc.description, cadc.disc_billing_selector, cadc.pricing, cadc.minimum_price, cadc.for_fcit_type_code, 
cadc.for_billing_selector, cadc.for_sepv_ref_num, sudi.ref_num sudi_ref_num, sudi.SUSG_REF_NUM, sudi.START_DATE sudi_start_date, padi.DISC_PERCENTAGE, padi.DISC_ABSOLUTE, padi.PRICE
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
join subs_discounts sudi ON sudi.cadc_ref_num IS NULL AND (NVL (sudi.closed, 'N') <> 'Y' OR sudi.date_updated >= :p_end_date + 1)  
                                              and cadc.dico_ref_num = sudi.dico_ref_num   
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
), discounts as (
select greatest(disc_start, nvl(mipo_start_date, disc_start)) start_date, greatest(disc_end, nvl(mipo_end_date, disc_end)) end_date, DISC_START, DISC_END, REF_NUM, PRECENTAGE, COUNT_FOR_MONTHS, 
COUNT_FOR_DAYS, DESCRIPTION, DISC_BILLING_SELECTOR, PRICING, MINIMUM_PRICE, FOR_FCIT_TYPE_CODE, FOR_BILLING_SELECTOR, FOR_SEPV_REF_NUM, SUDI_REF_NUM, q1.SUSG_REF_NUM, SUDI_START_DATE, 
DISC_PERCENTAGE, DISC_ABSOLUTE, PRICE, FTCO_REF_NUM, MIPO_START_DATE, MIPO_END_DATE, DISCOUNTED
from q1 LEFT JOIN ftco_disc ON q1.susg_ref_num = ftco_disc.susg_ref_num
where (disc_start <= mipo_end_date AND disc_end >= mipo_start_date AND discounted = 0 OR discounted is null)
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
), t1 as (
select sept.type_code, sept.category
from package_categories paca, serv_package_types sept
where paca.end_date IS NULL
AND sept.CATEGORY = paca.package_category
AND paca.nety_type_code = NVL (sept.nety_type_code, 'GSM')
AND paca.prepaid <> 'Y'
), t as (
select supa.gsm_susg_ref_num susg, TRUNC (supa.suac_ref_num, -3) maac, t1.category, supa.start_date, supa.end_date, supa.sept_type_code
from subs_packages supa JOIN t1 on to_char(supa.sept_type_code) = to_char(t1.type_code) 
where 1=1
AND TRUNC (supa.suac_ref_num, -3) not IN (SELECT TO_NUMBER (value_code) AS large_maac_ref_num
                                                          FROM bcc_domain_values
                                                         WHERE doma_type_code = 'LAMA')
AND NVL (supa.end_date, :p_start_date) >= :p_start_date
AND supa.start_date <= :p_end_date
), qx AS (
select /*+ CARDINALITY (t 2000000) NO_PARALLEL */ /* LEADING(t) USE_HASH(t q4) NO_PARALLEL */ t.maac, t.susg, t.sept_type_code, t.category cat,  
greatest(trunc(t.start_date), date '2018-10-01') supa_start, least(trunc(nvl(t.end_date, date '2018-10-31')) + 1 - 1/24/60/60, date '2018-10-31' + 1 - 1/24/60/60) supa_end,
q4.sety_ref_num, 
greatest(q4.start_date, date '2018-10-01') serv_start, least(nvl(q4.end_date, date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) serv_end 
from 
--table(xx_aj.get_list_susg_x (date '2018-10-01', date '2018-10-31', 
--102,
   --13796675, 
    --14251850,
    --14606161,
    --15145486,
    --15369942,
--16222436
    --15814963, 
    --15814963,
--)) 
t JOIN q4 ON to_char(q4.susg_ref_num) = to_char(t.susg)
), discless as (
select greatest(supa_start, serv_starts, sepv_starts, act_starts) starts, 
least(supa_end, serv_ends, sepv_ends, act_ends) ends,
--supa_end, serv_ends, sepv_ends, act_ends, mipo_end, sepv_end, serv_end, act_end, next_sepv_start, next_serv_start, next_act_start, sepv_start, serv_start, act_start,
main.maac, main.susg, main.fcit_billing_selector, main.fcit_type_code, main.fcit_desc, main.fcit_fcdt_type_code, main.sepv_start_real, 
main.sety_ref_num, main.prli_charge_value, main.ficv_charge_value, main.sepv_ref_num
from (
select  trunc(sepv_start/**/) sepv_starts, 
case when trunc(sepv_end/**/) >= trunc(next_sepv_start/**/) then trunc(next_sepv_start)-1/24/60/60 else trunc(sepv_end)+1-1/24/60/60 end sepv_ends,
trunc(serv_start) serv_starts,
case when trunc(serv_end) >= trunc(next_serv_start) then trunc(next_serv_start)-1/24/60/60 else trunc(serv_end)+1-1/24/60/60 end serv_ends,
trunc(act_start) act_starts,
case when trunc(act_end) >= trunc(next_act_start) then trunc(next_act_start)-1/24/60/60 else trunc(act_end)+1-1/24/60/60 end act_ends,
--sepv_end, serv_end, act_end, next_sepv_start, next_serv_start, next_act_start,
--sepv_start, serv_start, act_start,
--m1.*
m1.supa_start, m1.supa_end, m1.sepv_ref_num, m1.maac, m1.susg, m1.fcit_billing_selector, m1.fcit_type_code, m1.fcit_desc, m1.fcit_fcdt_type_code, 
m1.sepv_start_real, m1.sety_ref_num, m1.prli_charge_value, m1.ficv_charge_value
from (
select /*+ USE_HASH(qx q6) */ 
qx.serv_start, qx.serv_end, qx.supa_start, qx.supa_end, qx.maac, qx.susg, qx.sety_ref_num, q6.sepv_ref_num, ficv.charge_value ficv_charge_value, prli.charge_value prli_charge_value, 
 nvl(ficv.fcit_desc, fcit.description) fcit_desc, nvl(ficv.fcit_type_code, fcit.type_code) fcit_type_code, nvl(ficv.fcit_billing_selector, fcit.billing_selector) fcit_billing_selector, 
greatest(q6.start_date, date '2018-10-01') sepv_start,  least(nvl(q6.end_date, date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) sepv_end, 
q6.start_date sepv_start_real/**/, --q6.end_date_real sepv_end_real,
greatest(q5.start_date , date '2018-10-01') act_start,  least(nvl(q5.end_date , date '2018-10-31' + 1 - 1/24/60/60), date '2018-10-31' + 1 - 1/24/60/60) act_end, 
nvl(ficv.fcit_fcdt_type_code, fcit.fcdt_type_code) fcit_fcdt_type_code, 
lead(q6.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q5.start_date, qx.serv_start, qx.supa_start order by q6.start_date) next_sepv_start, 
lead(qx.serv_start) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q6.start_date, q5.start_date, qx.supa_start order by qx.serv_start) next_serv_start, 
lead(q5.start_date) over (partition by qx.susg, qx.sety_ref_num, q6.sepa_ref_num, q6.start_date, qx.serv_start, qx.supa_start order by q5.start_date) next_act_start
from qx      JOIN q5 ON q5.susg_ref_num = qx.susg
        LEFT JOIN q6 ON q6.susg_ref_num = qx.susg and q6.sety_ref_num = qx.sety_ref_num
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
) m1 
where 1=1
)  main, service_param_values sepv
where 1=1
and  main.sepv_ref_num = sepv.ref_num
--and main.prli_charge_value is not null
and main.sepv_starts<main.sepv_ends
and main.serv_starts<main.serv_ends
and main.act_starts<main.act_ends
and (main.act_starts < main.supa_end AND main.act_ends > main.supa_start)  
and (main.sepv_starts < main.supa_end AND main.sepv_ends > main.supa_start)
and (main.serv_starts < main.supa_end AND main.serv_ends > main.supa_start)
and (main.act_starts < main.sepv_ends AND main.act_ends > main.sepv_starts)  
and (main.act_starts < main.serv_ends AND main.act_ends > main.serv_starts)  
and (main.sepv_starts < main.serv_ends AND main.sepv_ends > main.serv_starts)
)
select  
qq4.MAAC, qq4.SUSG, qq4.PERIOD_CHARGE, qq4.FCIT_BILLING_SELECTOR, qq4.FCIT_TYPE_CODE, qq4.FCIT_BISE, qq4.FCIT_DESC, qq4.DISC_BILLING_SELECTOR, qq4.DISC_BISE, qq4.DISC_DESCR, 
qq4.FCIT_FCDT_TYPE_CODE, qq4.CADC_REF_NUM, -least(sum(qq4.discount) over (partition by qq4.susg order by qq4.rnx) - qq4.discount + qq4.charge_value, - qq4.discount) DISCOUNT, 
qq4.START_DATE_CORR, qq4.END_DATE_CORR, qq4.PERIOD_DAYS_CORR, qq4.SEPV_START_REAL, qq4.SUDI_END, qq4.period_days_main, qq4.starts start_date_main, qq4.ends end_date_main, qq4.sudi_ref_num
--, discount disc_orig, RNX, STARTS, ENDS, STARTX, ENDX, NEXT_STARTX, CHARGE_VALUE, PRICE, MINIMUM_PRICE, PRECENTAGE, DISC_PERCENTAGE, DISC_ABSOLUTE, 
--sum(discount) over (partition by susg order by rnx) - discount dx, sum(discount) over (partition by susg order by rnx) - discount + charge_value xx  
from (
select maac, susg, 
case rnx when 1 then round(charge_value*period_days_main/month_days,2) else 0 end period_charge, 
fcit_billing_selector, fcit_type_code, fcit_bise,  fcit_desc,  disc_billing_selector, disc_bise, disc_descr, fcit_fcdt_type_code, cadc_ref_num,
-case when disc_start is not null then 
      case when price is not null then
         round(greatest(charge_value-price, 0)*period_days_corr/month_days, 2)
      when price is null and (disc_percentage is not null or disc_absolute is not null) then
         round(greatest((nvl(disc_percentage,0)/100)*charge_value, least(nvl(disc_absolute, 0), charge_value))*period_days_corr/month_days, 2)
      else
        case when pricing = 'Y' then
          round((charge_value - least((nvl(precentage,100)/100)*charge_value, least(nvl(minimum_price, charge_value), charge_value)))*period_days_corr/month_days, 2)
        else
          round(greatest((nvl(precentage,0)/100)*charge_value, least(nvl(minimum_price, 0), charge_value))*period_days_corr/month_days, 2)
        end
      end
else
  null  
end discount
,start_date_corr, end_date_corr, period_days_corr, sepv_start_real, rnx, charge_value, month_days, count_for_months, count_for_days, sudi_start_date, 
case when count_for_months is null and count_for_days is null or sudi_start_date is null then null else add_months(trunc(sudi_start_date), nvl(count_for_months,0)) + nvl(count_for_days,0) end sudi_end
, starts, ends, period_days_main, sudi_ref_num  
--startx, endx, next_startx-------------------------XXX
--,price, minimum_price, precentage, disc_percentage, disc_absolute-------------------------XXX 
from (
select case when disc_start is null then starts else startx end start_date_corr,
case when disc_start is null then trunc(ends) else case when next_startx is null or next_startx > endx then endx else next_startx-1 end  end end_date_corr,
case when disc_start is null then trunc(ends) else case when next_startx is null or next_startx > endx then endx else next_startx-1 end  end + 1 -  
   case when disc_start is null then starts else startx end  period_days_corr, /**/
add_months(trunc(:p_start_date), 1) -trunc(:p_start_date) month_days /**/,    
coalesce(ficv_charge_value, prli_charge_value, 0) charge_value, /**/
--qq2.* 
qq2.maac, qq2.susg, qq2.fcit_billing_selector, qq2.fcit_type_code, qq2.fcit_bise, qq2.fcit_desc, qq2.disc_billing_selector, qq2.disc_bise, qq2.disc_descr, qq2.fcit_fcdt_type_code, 
qq2.cadc_ref_num, qq2.disc_start, qq2.price, qq2.disc_percentage, qq2.disc_absolute, qq2.precentage, qq2.minimum_price, qq2.sepv_start_real, 
qq2.sudi_ref_num, qq2.sudi_start_date, qq2.count_for_months, qq2.count_for_days, qq2.sety_ref_num, qq2.pricing, qq2.rnx, 
trunc(qq2.starts) starts, trunc(qq2.ends) ends, trunc(qq2.ends) +1 - trunc(qq2.starts) period_days_main 
--qq2.startx, qq2.endx, qq2.next_startx-------------------------XXX
from (
select lead(startx) over (partition by susg, cadc_ref_num order by startx, endx) next_startx,  row_number() over (partition by susg, starts, ends order by startx, endx, sudi_ref_num desc) rnx,
--qq.*  
qq.maac, qq.susg, qq.fcit_billing_selector, qq.fcit_type_code, qq.fcit_bise, qq.fcit_desc, qq.disc_billing_selector, qq.disc_bise, qq.disc_descr, qq.fcit_fcdt_type_code, qq.cadc_ref_num,
qq.disc_start, qq.price, qq.disc_percentage, qq.disc_absolute, qq.precentage, qq.sepv_start_real, qq.sudi_start_date, qq.count_for_months,
qq.count_for_days, qq.minimum_price, qq.sety_ref_num, qq.pricing, qq.starts, qq.ends, qq.ficv_charge_value, qq.prli_charge_value, qq.startx, qq.endx, qq.sudi_ref_num 
from (
select greatest(starts, disc_start) startx /**/, least(trunc(ends), disc_end) endx,  
bcdv1.description fcit_bise, bcdv2.description disc_bise, --bcdv3.description disc_all_bise, 
t.maac, t.susg, t.fcit_billing_selector, t.fcit_type_code, t.fcit_desc, t.fcit_fcdt_type_code, t.starts, t.ends, t.sepv_start_real, t.sety_ref_num,
t.prli_charge_value, t.ficv_charge_value,
q1.start_date DISC_START, q1.end_date DISC_END, q1.REF_NUM cadc_ref_num, q1.PRECENTAGE, q1.COUNT_FOR_MONTHS, q1.COUNT_FOR_DAYS, q1.DESCRIPTION disc_descr, q1.DISC_BILLING_SELECTOR, q1.PRICING, 
q1.MINIMUM_PRICE, q1.SUDI_START_DATE, q1.DISC_PERCENTAGE, q1.DISC_ABSOLUTE, q1.PRICE, q1.sudi_ref_num 
from discless t left join discounts q1 on q1.susg_ref_num = t.susg and q1.for_fcit_type_code = t.fcit_type_code 
                                 and q1.for_billing_selector = t.fcit_billing_selector 
                                 and nvl(q1.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num
--                 left join q2 on q2.for_fcit_type_code = t.fcit_type_code and q2.for_billing_selector = t.fcit_billing_selector
--                                 and nvl(q2.for_sepv_ref_num, t.sepv_ref_num) = t.sepv_ref_num
                 LEFT join bcc_domain_values bcdv1 on bcdv1.value_code = t.fcit_billing_selector and bcdv1.doma_type_code = 'BISE'
                 left join bcc_domain_values bcdv2 on bcdv2.value_code = q1.disc_billing_selector and bcdv2.doma_type_code = 'BISE'
                 --left join bcc_domain_values bcdv3 on bcdv3.value_code = q2.disc_billing_selector and bcdv3.doma_type_code = 'BISE'
where 1=1
--and t.susg = 3582834
) qq
where 1=1
and starts <= nvl(disc_end, starts)
and nvl(disc_start, trunc(ends)) <= trunc(ends) 
) qq2
) qq3
) qq4
where end_date_corr >= start_date_corr
----------
--and period_days_corr = month_days
--and sepv_start_real < :p_start_date
    --and sepv_start_real >= :p_start_date
--and add_months(trunc(nvl(sudi_start_date, sysdate)), nvl(count_for_months,0)) + nvl(count_for_days,0) != :p_end_date
    --and add_months(trunc(nvl(sudi_start_date, sysdate)), nvl(count_for_months,0)) + nvl(count_for_days,0) = :p_end_date
order by 1, 2, 3,5

