drop table aj_temp_32 purge

create table aj_temp_32 as 
select * from aj_temp_31
where 1=0

insert into aj_temp_32

with t1 as (
select sept.type_code, sept.category
from package_categories paca, serv_package_types sept
where paca.end_date IS NULL
AND sept.CATEGORY = paca.package_category
AND paca.nety_type_code = NVL (sept.nety_type_code, 'GSM')
AND paca.prepaid <> 'Y'
), t as (
select supa.gsm_susg_ref_num susg, TRUNC (supa.suac_ref_num, -3) maac, t1.category, supa.sept_type_code, 
greatest(nvl(trunc(supa.start_date), :p_start_date), :p_start_date) supa_start_date, 
least(
nvl(trunc(supa.end_date), :p_end_date), 
:p_end_date, 
nvl(trunc(lead(supa.start_date) over (partition by supa.gsm_susg_ref_num order by supa.start_date, supa.end_date nulls last)) - 1, :p_end_date)
) supa_end_date
from subs_packages supa JOIN t1 on to_char(supa.sept_type_code) = to_char(t1.type_code) 
where 1=1
AND TRUNC (supa.suac_ref_num, -3) not IN (SELECT TO_NUMBER (value_code) AS large_maac_ref_num
                                                          FROM bcc_domain_values
                                                         WHERE doma_type_code = 'LAMA')
AND NVL (supa.end_date, :p_start_date) >= :p_start_date
AND supa.start_date < :p_end_date + 1
), q4 as (
select /*+ NO_INDEX(stpe stpe_di1 stpe_di2) NO_PARALLEL */ susg_ref_num susg, sety_ref_num, start_date real_stpe_start, end_date real_stpe_end,
greatest(nvl(trunc(stpe.start_date), :p_start_date), :p_start_date) stpe_start_date, 
least(
nvl(trunc(stpe.end_date), :p_end_date), 
:p_end_date, 
nvl(trunc(lead(stpe.start_date) over (partition by stpe.susg_ref_num, stpe.sety_ref_num order by stpe.start_date, stpe.end_date nulls last)) - 1, :p_end_date)
) stpe_end_date
from status_periods stpe
where 1=1 --susg_ref_num =6177509
AND NVL (stpe.end_date, :p_start_date) >= :p_start_date
AND stpe.start_date < :p_end_date + 1
AND stpe.sety_ref_num IN (5802234)
), q5 as (
select /*+ NO_INDEX(ssst ssst_di2 ssst_di3 ssst_di5 ssst_di6)  */susg_ref_num susg, start_date real_ssst_start, end_date real_ssst_end, status_code,
greatest(nvl(trunc(ssst.start_date), :p_start_date), :p_start_date) ssst_start_date, 
least(
nvl(trunc(ssst.end_date), :p_end_date), 
:p_end_date, 
nvl(trunc(lead(ssst.start_date) over (partition by ssst.susg_ref_num order by ssst.start_date, ssst.end_date nulls last)) - 1, :p_end_date)
) ssst_end_date
from ssg_statuses ssst
where  1=1
AND NVL (ssst.end_date, :p_start_date) >= :p_start_date
AND ssst.start_date < :p_end_date + 1
and ssst.status_code = 'AC'
), q6 as (
select /*+ NO_INDEX (susp susp_sk1 susp_sk2) */ susp.susg_ref_num susg, susp.sety_ref_num, susp.start_date real_susp_start, susp.end_date real_susp_end, susp.sepa_ref_num, susp.sepv_ref_num, 
greatest(nvl(trunc(susp.start_date), :p_start_date), :p_start_date) susp_start_date, 
least(
nvl(trunc(susp.end_date), :p_end_date), 
:p_end_date, 
nvl(trunc(lead(susp.start_date) over (partition by susp.susg_ref_num, susp.sety_ref_num order by susp.start_date, susp.end_date nulls last)) - 1, :p_end_date)
) susp_end_date
from subs_service_parameters susp
where  1=1
AND NVL (susp.end_date, :p_start_date) >= :p_start_date
AND susp.start_date < :p_end_date + 1
AND susp.sety_ref_num IN (5802234)
), discless as (
select greatest(supa_start_date, stpe_start_date, susp_start_date, ssst_start_date) starts, 
least(supa_end_date, stpe_end_date, susp_end_date, ssst_end_date) ends,
--supa_end, serv_ends, sepv_ends, act_ends, mipo_end, sepv_end, serv_end, act_end, next_sepv_start, next_serv_start, next_act_start, sepv_start, serv_start, act_start,
t.maac, t.susg, nvl(ficv.fcit_billing_selector, fcit.billing_selector) fcit_billing_selector, nvl(ficv.fcit_type_code, fcit.type_code) fcit_type_code, 
nvl(ficv.fcit_desc, fcit.description) fcit_desc, nvl(ficv.fcit_fcdt_type_code, fcit.fcdt_type_code) fcit_fcdt_type_code, q6.real_susp_start sepv_start_real, q4.sety_ref_num,
nvl(prli.charge_value,0) prli_charge_value, ficv.charge_value ficv_charge_value, q6.sepv_ref_num  
from t JOIN q4 ON to_char(t.susg)=to_char(q4.susg)
       JOIN q5 ON to_char(t.susg)=to_char(q5.susg)
  LEFT JOIN q6 ON to_char(t.susg)=to_char(q6.susg)
  LEFT JOIN (
          select ficv.sepv_ref_num, ficv.sepa_ref_num,ficv.sept_type_code, ficv.sety_ref_num, ficv.charge_value,--ficv.*, 
          fcit.description fcit_desc, fcit.type_code fcit_type_code, fcit.billing_selector fcit_billing_selector, fcit.fcdt_type_code fcit_fcdt_type_code 
          from fixed_charge_values ficv, fixed_charge_item_types fcit
          WHERE NVL (ficv.end_date, :p_start_date) >= :p_start_date
          AND ficv.start_date < :p_end_date + 1
          and ficv.FCIT_CHARGE_CODE = fcit.TYPE_CODE
          and fcit.regular_charge='Y' and fcit.ONCE_OFF='N'
          ) ficv ON ficv.sety_ref_num = q4.sety_ref_num AND ficv.sept_type_code = t.sept_type_code AND ficv.sepa_ref_num = q6.sepa_Ref_num and ficv.sepv_ref_num = q6.sepv_ref_num 
  LEFT JOIN (
          select * from price_lists prli 
          WHERE NVL (prli.end_date, :p_start_date) >= :p_start_date
          AND prli.start_date < :p_end_date + 1
          ) prli ON prli.sety_ref_num = q4.sety_ref_num AND nvl(prli.package_category, t.category) = t.category AND prli.fcty_type_code='RCH' 
                 AND prli.sepa_ref_num = q6.sepa_Ref_num and prli.sepv_ref_num = q6.sepv_ref_num
  LEFT JOIN fixed_charge_item_types fcit ON fcit.sety_ref_num = q4.sety_ref_num AND fcit.package_category = t.category and fcit.regular_charge='Y' and fcit.ONCE_OFF='N' 
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
--and (t.susg = 3582834)
--and (q4.susg = 3582834)
--and (q5.susg = 3582834)
--and (q6.susg = 3582834)
), ftco0 as (
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
nvl(ficv_charge_value, prli_charge_value) charge_value, /**/
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
--and t.susg = 13573087
) qq
where 1=1
and starts <= nvl(disc_end, starts)
and nvl(disc_start, trunc(ends)) <= trunc(ends) 
) qq2
) qq3
) qq4
where end_date_corr >= start_date_corr

