drop table daily_charges_descr_temp purge

delete from aj_temp_30;

CREATE TABLE DAILY_CHARGES_DESCR_TEMP (
BICY_CYCLE_CODE VARCHAR2(10), MAAC NUMBER, SUSG NUMBER , SETY_REF_NUM NUMBER, SERVICE_NAME VARCHAR2(40), SEPT_TYPE_CODE VARCHAR2(10), SEPT_DESCRIPTION VARCHAR2(40), 
SEPV_REF_NUM NUMBER, SEPV_DESCRIPTION VARCHAR2(40), PACKET_DISCOUNT VARCHAR2(10), STARTS DATE, ENDS DATE, MAIN_DAYS NUMBER, CHARGE_VALUE NUMBER, CURR_CODE VARCHAR2(3), PERIOD_CHARGE NUMBER, 
INCL_DISC NUMBER, FCIT_BILLING_SELECTOR VARCHAR2(10), FCIT_TYPE_CODE VARCHAR2(10), FCIT_TATY_TYPE_CODE VARCHAR2(10), FCIT_BISE VARCHAR2(40), FCIT_DESC VARCHAR2(40), DISC_START DATE, 
DISC_END DATE, DISC_DAYS NUMBER, DISCOUNT NUMBER, DISCOUNT_CODE VARCHAR2(40), DISCOUNT_DESCRIPTION VARCHAR2(40), disc_billing_selector VARCHAR2(10), fcit_fcdt_type_code VARCHAR2(10), 
disc_bise VARCHAR2(40), disc_description VARCHAR2(40), CADC_REF_NUM NUMBER, SUDI_REF_NUM NUMBER, CRM VARCHAR2(1), BILLED_INVO_END DATE 
)

drop table aj_temp_3 purge

create table aj_temp_3 as 
select * from aj_temp_30
where 1=0


create table aj_temp_30 as 
select * from aj_temp_3
where 1=0


select * from aj_temp_30
order by maac,susg

insert into daily_charges_descr_temp
with t1 as (
select sept.type_code, sept.description, sept.category
from package_categories paca, serv_package_types sept
where paca.end_date IS NULL
AND sept.CATEGORY = paca.package_category
AND paca.nety_type_code = NVL (sept.nety_type_code, 'GSM')
AND paca.prepaid <> 'Y'
), t as (
select supa.gsm_susg_ref_num susg, TRUNC (supa.suac_ref_num, -3) maac, t1.category, supa.sept_type_code, t1.description sept_description, 
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
AND stpe.sety_ref_num = :p_sety_ref_num
--AND stpe.sety_ref_num IN (select sety_ref_num from servs)
----and (stpe.susg_ref_num = :p_susg)----
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
----and (ssst.susg_ref_num = :p_susg)----
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
AND susp.sety_ref_num = :p_sety_ref_num
--AND susp.sety_ref_num IN (select sety_ref_num from servs)
----and (susp.susg_ref_num = :p_susg)----
), discless as (
select /*+ */ greatest(supa_start_date, stpe_start_date, susp_start_date, ssst_start_date) starts, 
least(supa_end_date, stpe_end_date, susp_end_date, ssst_end_date) ends,
--supa_end, serv_ends, sepv_ends, act_ends, mipo_end, sepv_end, serv_end, act_end, next_sepv_start, next_serv_start, next_act_start, sepv_start, serv_start, act_start,
t.maac, t.susg, t.sept_type_code, t.sept_description, nvl(ficv.fcit_billing_selector, fcit.billing_selector) fcit_billing_selector, nvl(ficv.fcit_type_code, fcit.type_code) fcit_type_code,
nvl(ficv.fcit_taty_type_code, fcit.taty_type_code) fcit_taty_type_code, nvl(ficv.curr_code, prli.curr_code) curr_code, 
nvl(ficv.fcit_desc, fcit.description) fcit_desc, nvl(ficv.fcit_fcdt_type_code, fcit.fcdt_type_code) fcit_fcdt_type_code, q6.real_susp_start sepv_start_real, q4.sety_ref_num,
nvl(prli.charge_value,0) prli_charge_value, ficv.charge_value ficv_charge_value, coalesce(ficv.charge_value, prli.charge_value, 0) charge_value, q6.sepv_ref_num  
from t JOIN q4 ON to_char(t.susg)=to_char(q4.susg)
       JOIN q5 ON to_char(t.susg)=to_char(q5.susg)
       JOIN q6 ON to_char(t.susg)=to_char(q6.susg)
  LEFT JOIN (
          select ficv.sepv_ref_num, ficv.sepa_ref_num,ficv.sept_type_code, ficv.sety_ref_num, ficv.charge_value,--ficv.*, 
          fcit.description fcit_desc, fcit.type_code fcit_type_code, fcit.billing_selector fcit_billing_selector, 
          fcit.fcdt_type_code fcit_fcdt_type_code, fcit.taty_type_code fcit_taty_type_code, ficv.curr_code 
          from fixed_charge_values ficv, fixed_charge_item_types fcit
          WHERE NVL (ficv.end_date, :p_start_date) >= :p_start_date
          AND ficv.start_date < :p_end_date + 1
          and ficv.FCIT_CHARGE_CODE = fcit.TYPE_CODE
          and fcit.regular_charge='Y' and fcit.ONCE_OFF='N'
          ) ficv ON ficv.sety_ref_num = q4.sety_ref_num AND ficv.sept_type_code = t.sept_type_code AND ficv.sepa_ref_num = q6.sepa_Ref_num and ficv.sepv_ref_num = q6.sepv_ref_num 
  LEFT JOIN (
          select /*+ NO_INDEX (prli) */ * from price_lists prli 
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
and coalesce(ficv.charge_value, prli.charge_value, 0) != 0
and q4.sety_ref_num = q6.sety_ref_num
----and (t.susg = :p_susg)----
), ftco0 as (
select ftco.ref_num ftco_ref_num, ftco.sept_type_code ftco_sept_type_code, ftco.mixed_packet_code, ftco.susg_ref_num, ftco.ebs_order_number, ftco.sept_type_code, 
greatest(nvl(ftco.start_date, :p_start_date), :p_start_date) start_date_c, ftco.end_date, ftco.date_closed, 
trunc(least(coalesce(date_closed, end_date, :p_end_date),coalesce(end_date, :p_end_date), :p_end_date)) end_date_c
from fixed_term_contracts ftco
----where (ftco.susg_ref_num = :p_susg)----
), ftco1 as (
select ftco0.ftco_ref_num, ftco0.susg_ref_num, ftco_sept_type_code,  
lead(start_date_c) over (partition by susg_ref_num order by start_date_c, end_date_c) next_start_date,  
lag(end_date_c) over (partition by susg_ref_num order by end_date_c, start_date_c) prev_end_date,
start_date_c,
least(end_date_c, nvl(lead(start_date_c) over (partition by susg_ref_num order by start_date_c, end_date_c) - 1, end_date_c), :p_end_date) end_date_c ,
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
and mose.sety_ref_num = :p_sety_ref_num
--AND mose.sety_ref_num IN (select sety_ref_num from servs)
AND ftco0.mixed_packet_code = mipo.mixed_packet_code
AND ftco0.ebs_order_number = mipo.ebs_order_number
AND Nvl(mipo.term_request_type, '*') <> 'NULLIFY'
AND mose.mipo_ref_num = mipo.ref_num
AND (mips.monthly_disc_rate is not null or mips.MONTHLY_MARKDOWN is not null)
AND ftco0.start_date_c <  :p_end_date+1
and     ftco0.end_date_c >= :p_start_date
and     ftco0.end_date_c >= ftco0.start_date_c
), ftco_disc as (
select ftco_ref_num, susg_ref_num, ftco_sept_type_code, start_date_c mipo_start_date, end_date_c mipo_end_date, 1 discounted, monthly_disc_rate, monthly_markdown, packet_code, packet_description
from ftco1
union all
select ftco_ref_num, susg_ref_num, ftco_sept_type_code, end_date_c + 1 mipo_start_date, nvl(next_start_date - 1 , :p_end_date) mipo_end_date, 0 discounted, null, null, null, null
from ftco1
where end_date_c < :p_end_date
and nvl(next_start_date - 1 , :p_end_date) >=  end_date_c + 1
union all
select ftco_ref_num, susg_ref_num, ftco_sept_type_code, :p_start_date mipo_start_date, start_date_c-1 mipo_end_date, 0 discounted, null, null, null, null
from ftco1
where start_date_c > :p_start_date
and prev_end_date is null
), q01 as (
select greatest(cadc.start_date, :p_start_date) discall_start
,least(cadc.end_date, :p_end_date) discall_end
,cadc.ref_num, cadc.precentage, cadc.count_for_months, cadc.count_for_days, cadc.discount_code, cadc.description, cadc.disc_billing_selector, cadc.pricing, cadc.minimum_price, 
cadc.for_fcit_type_code, cadc.for_billing_selector, cadc.for_sepv_ref_num, cadc.for_sety_ref_num,  cadc.crm, cadc.mixed_service
from  call_discount_codes cadc, discount_codes dico
WHERE cadc.dico_ref_num = dico.ref_num 
and cadc.call_type = 'REGU'
and NVL (cadc.end_date, :p_start_date) >= :p_start_date
and cadc.start_date < :p_end_date + 1
and NVL (cadc.discount_completed, 'N') <> 'Y'
AND dico.manual = 'Y'
and dico.for_all = 'Y'
), q1 as (
select greatest(sudi.start_date, cadc.cadc_start_date, :p_start_date) disc_start
,least(nvl(trunc(sudi.end_date), :p_end_date), cadc.cadc_end_date, 
   case when cadc.count_for_months is not null or cadc.count_for_days is not null then ADD_MONTHS(sudi.start_date, NVL(cadc.count_for_months,0))+NVL(cadc.count_for_days,0) else  :p_end_date end,
   :p_end_date) disc_end
,sudi.start_date, sudi.end_date, cadc_start_date, cadc_end_date    
,cadc.ref_num, cadc.precentage, cadc.count_for_months, cadc.count_for_days, cadc.discount_code, cadc.description, cadc.disc_billing_selector, cadc.pricing, cadc.minimum_price, 
cadc.for_fcit_type_code, cadc.for_billing_selector, cadc.for_sepv_ref_num, cadc.for_sety_ref_num,  cadc.crm, cadc.mixed_service,
sudi.ref_num sudi_ref_num, sudi.SUSG_REF_NUM, sudi.START_DATE sudi_start_date, padi.DISC_PERCENTAGE, padi.DISC_ABSOLUTE, padi.PRICE, padi.padi_ref_num
from (
select greatest(nvl(cadc.start_date, :p_start_date), :p_start_date) cadc_start_date,
least(nvl(trunc(cadc.end_date), :p_end_date), :p_end_date) cadc_end_date,  
cadc.ref_num, cadc.precentage, cadc.count_for_months, cadc.count_for_days, cadc.discount_code, cadc.description, cadc.disc_billing_selector, cadc.pricing, cadc.minimum_price, 
cadc.for_fcit_type_code, cadc.for_billing_selector, cadc.for_sepv_ref_num, cadc.for_sety_ref_num, cadc.dico_ref_num, cadc.mixed_service, cadc.crm
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
----                            and (sudi.susg_ref_num = :p_susg)----                                                 
left join part_dico_details padi ON PADI.PADI_REF_NUM = sudi.padi_ref_num
                                                   and padi.cadc_ref_num = cadc.ref_num
), qq1 as (
select case when (starts <= nvl(disc_end, :p_end_date) AND ends >= nvl(disc_start, :p_start_date)) 
             and (starts <= nvl(mipo_end_date, :p_end_date) AND ends >= nvl(mipo_start_date, :p_start_date))
             then 1 else 0 end discountable,
case when sudi_ref_num is null and nvl(discounted, 0) = 0 then 0 else 1 end discounts_available,       
--bcdv3.description disc_all_bise, 
t.maac, t.susg, t.fcit_billing_selector, bcdv1.description fcit_bise, t.fcit_type_code, t.fcit_taty_type_code, t.fcit_desc, t.fcit_fcdt_type_code, 
greatest(t.starts, nvl(mipo_start_date, :p_start_date)) starts, least(t.ends, nvl(mipo_end_date, :p_end_date)) ends, 
t.sepv_start_real, t.sety_ref_num, t.prli_charge_value, t.ficv_charge_value, t.charge_value, t.curr_code, t.sept_type_code, t.sept_description, t.sepv_ref_num,
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
ftco_disc.*
from discless t  LEFT JOIN q1 on t.susg=q1.susg_ref_num and q1.for_fcit_type_code = t.fcit_type_code 
                                 and q1.for_billing_selector = t.fcit_billing_selector
                                 and q1.for_sety_ref_num = t.sety_ref_num  
                                 and q1.for_sepv_ref_num = t.sepv_ref_num
                 LEFT JOIN q01 on q01.for_fcit_type_code = t.fcit_type_code 
                                 and q01.for_billing_selector = t.fcit_billing_selector
                                 and q01.for_sety_ref_num = t.sety_ref_num  
                                 and q01.for_sepv_ref_num = t.sepv_ref_num
                 LEFT join bcc_domain_values bcdv1 on bcdv1.value_code = t.fcit_billing_selector and bcdv1.doma_type_code = 'BISE'
                 left join bcc_domain_values bcdv2 on bcdv2.value_code = q1.disc_billing_selector and bcdv2.doma_type_code = 'BISE'
                 left join bcc_domain_values bcdv3 on bcdv3.value_code = q01.disc_billing_selector and bcdv3.doma_type_code = 'BISE'
                 LEFT JOIN ftco_disc ON ftco_disc.susg_ref_num = t.susg  and ftco_disc.ftco_sept_type_code = t.sept_type_code
where 1=1
--not (starts <= nvl(disc_end, :p_end_date) AND ends >= nvl(disc_start, :p_start_date))
--not (starts <= nvl(mipo_end_date, :p_end_date) AND ends >= nvl(mipo_start_date, :p_start_date))
and (starts <= nvl(mipo_end_date, :p_end_date) AND ends >= nvl(mipo_start_date, :p_start_date))
and nvl(disc_start, :p_start_date) <= nvl(disc_end, :p_end_date)
), qq2 as (
select /*+ NO_INDEX (sepv) */ 
case when discountable*discounts_available = 0 then null 
     else greatest(starts, nvl(disc_start, :p_start_date), case when nvl(discounted,0)= 0 then :p_start_date else nvl(mipo_start_date, :p_start_date) end) 
end real_disc_start,
case when discountable*discounts_available = 0 then null
     else least(ends, nvl(disc_end, :p_end_date), case when nvl(discounted,0)= 0 then :p_end_date else nvl(mipo_end_date, :p_end_date) end) 
end real_disc_end,
qq1.*, acco.bicy_cycle_code, sety.service_name, sepv.param_value sepv_param_value, sepv.description sepv_description
from qq1  JOIN accounts acco on qq1.maac = acco.ref_num
          JOIN service_types sety on qq1.sety_ref_num = sety.ref_num
          JOIN service_param_values sepv on qq1.sepv_ref_num = sepv.ref_num
where acco.bicy_cycle_code = nvl(:p_bicy, acco.bicy_cycle_code)
and not (discountable = 0 and sudi_ref_num is null and nvl(discounted, 0) = 0)
), qq3 as (
select 
nvl(lead(real_disc_start) over (partition by susg, starts order by real_disc_start, real_disc_end nulls last)/*next_real_disc_start*/, :p_end_date + 1) - 1 max_real_disc_end,
case when nvl(lead(real_disc_start) over (partition by susg, starts order by real_disc_start, real_disc_end nulls last), :p_end_date + 1) - 1 /*max_real_disc_end*/ = real_disc_end - 1 then
1 else 0 end apply_corr, add_months(trunc(:p_start_date), 1) -trunc(:p_start_date) month_days,
qq2.*
from qq2
), qq7 as (
select row_number() over (partition by susg, starts order by discountable desc, discounts_available desc, sudi_ref_num) rn, 
apply_corr, REAL_DISC_START, case apply_corr when 1 then max_real_disc_end else real_disc_end end REAL_DISC_END, 
ends+1-starts main_days, case apply_corr when 1 then max_real_disc_end else real_disc_end end + 1 - real_disc_start disc_days,
DISCOUNTABLE, discounts_available, MAAC, SUSG, service_name, FCIT_BILLING_SELECTOR, FCIT_BISE, FCIT_TYPE_CODE, FCIT_TATY_TYPE_CODE,
FCIT_DESC, 
case when discountable*discounts_available = 0 then null else FCIT_FCDT_TYPE_CODE end FCIT_FCDT_TYPE_CODE, STARTS, ENDS, SEPV_START_REAL, SETY_REF_NUM, PRLI_CHARGE_VALUE, FICV_CHARGE_VALUE, 
CHARGE_VALUE, curr_code, SEPT_TYPE_CODE, SEPT_DESCRIPTION, SEPV_REF_NUM, SEPV_PARAM_VALUE, SEPV_DESCRIPTION, DISC_START, DISC_END, 
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
-case discounted when 1 then greatest(least(nvl(monthly_markdown,0), charge_value), charge_value*nvl(monthly_disc_rate,0)/100) else 0 end * main_days/month_days incl_disc,
fcit_billing_selector, fcit_type_code, fcit_taty_type_code, fcit_bise,  fcit_desc,  disc_billing_selector, disc_bise, disc_descr, fcit_fcdt_type_code, cadc_ref_num,
-case when disc_days is not null and nvl(discounted, 0) = 0 and crm='Y' then 
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
,real_disc_start, real_disc_end, disc_days, sepv_start_real, rn, charge_value, curr_code, month_days, count_for_months, count_for_days, sudi_start_date,
case when count_for_months is null and count_for_days is null or sudi_start_date is null then null 
               else add_months(trunc(sudi_start_date), nvl(count_for_months,0)) + nvl(count_for_days,0) end sudi_end
, starts, ends, main_days, sudi_ref_num,  
APPLY_CORR, DISCOUNTABLE, DISCOUNTS_AVAILABLE, SERVICE_NAME, SETY_REF_NUM, PRLI_CHARGE_VALUE, FICV_CHARGE_VALUE, SEPT_TYPE_CODE, SEPT_DESCRIPTION, SEPV_REF_NUM, 
SEPV_PARAM_VALUE, SEPV_DESCRIPTION, DISC_START, DISC_END, PRECENTAGE, DISCOUNT_CODE, PRICING, MINIMUM_PRICE, DISC_PERCENTAGE, DISC_ABSOLUTE, PRICE, PADI_REF_NUM, CRM, MIXED_SERVICE, 
FTCO_REF_NUM, SUSG_REF_NUM, FTCO_SEPT_TYPE_CODE, MIPO_START_DATE, MIPO_END_DATE, DISCOUNTED, MONTHLY_DISC_RATE, MONTHLY_MARKDOWN, PACKET_CODE, PACKET_DESCRIPTION, BICY_CYCLE_CODE
from qq5
), int_inv as (
select max(invo.invo_end) invo_end, inen.billing_selector, inen.fcit_type_code, inen.susg_ref_num 
from invoices invo, invoice_entries inen
where 1=1 
and invo.ref_num = inen.invo_ref_num
and invo.period_start = :p_start_date 
--and invo.invo_end < trunc(:p_end_date)+1-1/24/24 
and invo.invoice_type = 'INT'
----and inen.susg_ref_num = :p_susg
group by inen.billing_selector, inen.fcit_type_code, inen.fcdt_type_code, inen.susg_ref_num
)
select qq4.bicy_cycle_code, qq4.maac, qq4.susg, qq4.sety_ref_num, qq4.service_name, qq4.sept_type_code, qq4.sept_description, qq4.sepv_ref_num, qq4.sepv_description, 
qq4.packet_code packet_discount, qq4.starts, qq4.ends, qq4.main_days, qq4.charge_value, qq4.curr_code, qq4.period_charge, qq4.incl_disc, qq4.fcit_billing_selector, qq4.fcit_type_code, 
qq4.fcit_taty_type_code, qq4.fcit_bise, qq4.fcit_desc, qq4.real_disc_start disc_start, qq4.real_disc_end disc_end, qq4.disc_days, 
-least(sum(qq4.discount) over (partition by qq4.susg order by qq4.rn) - qq4.discount + qq4.charge_value, - qq4.discount) discount, qq4.discount_code, 
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
qq4.disc_billing_selector, qq4.fcit_fcdt_type_code, qq4.disc_bise, qq4.disc_descr, qq4.cadc_ref_num, qq4.sudi_ref_num, qq4.crm, int_inv.invo_end
from qq4 LEFT JOIN int_inv on int_inv.susg_ref_num = qq4.susg AND int_inv.billing_selector = qq4.fcit_billing_selector and int_inv.fcit_type_code = qq4.fcit_type_code  

select * from aj_temp_30

drop table DAILY_CHARGES_INEN_TMP PURGE

CREATE TABLE DAILY_CHARGES_INEN_TEMP
(
  REF_NUM                 NUMBER(10),
  INVO_REF_NUM            NUMBER(10),
  SEC_AMT                 NUMBER(16,4),
  ROUNDING_INDICATOR      VARCHAR2(1 BYTE),
  UNDER_DISPUTE           VARCHAR2(1 BYTE),
  CREATED_BY              VARCHAR2(15 BYTE),
  DATE_CREATED            DATE,
  AMT_IN_CURR             NUMBER(16,4),
  BILLING_SELECTOR        VARCHAR2(3 BYTE),
  FCIT_TYPE_CODE          VARCHAR2(3 BYTE),
  TATY_TYPE_CODE          VARCHAR2(3 BYTE),
  SUSG_REF_NUM            NUMBER(10),
  IADN_REF_NUM            NUMBER(10),
  CURR_CODE               VARCHAR2(3 BYTE),
  VMCT_TYPE_CODE          VARCHAR2(3 BYTE),
  LAST_UPDATED_BY         VARCHAR2(15 BYTE),
  DATE_UPDATED            DATE,
  DESCRIPTION             VARCHAR2(60 BYTE),
  SEC_AMT_TAX             NUMBER(16,4),
  AMT_TAX_CURR            NUMBER(16,4),
  MANUAL_ENTRY            VARCHAR2(1 BYTE),
  EVRE_COUNT              NUMBER,
  EVRE_DURATION           NUMBER,
  MODULE_REF              VARCHAR2(4 BYTE),
  SEC_FIXED_CHARGE_VALUE  NUMBER(16,4),
  EVRE_CHAR_USAGE         NUMBER,
  PRINT_REQUIRED          VARCHAR2(1 BYTE),
  VMCT_RATE_VALUE         NUMBER(5,2),
  NUM_OF_DAYS             NUMBER(2),
  EVRE_DATA_VOLUME        NUMBER,
  MAAS_REF_NUM            NUMBER(10),
  CADC_REF_NUM            NUMBER(10),
  FCDT_TYPE_CODE          VARCHAR2(4 BYTE),
  SEC_FF_DISC_AMT         NUMBER(16,4),
  SEC_CURR_CODE           VARCHAR2(3 BYTE),
  EEK_AMT                 NUMBER(16,4),
  AMT_TAX                 NUMBER(16,4),
  PRI_CURR_CODE           VARCHAR2(3 BYTE),
  FF_DISC_AMT             NUMBER(16,4),
  FIXED_CHARGE_VALUE      NUMBER(16,4),
  SEC_ACC_AMOUNT          NUMBER(16,4),
  ACC_AMOUNT              NUMBER(16,4),
  BILLING_SELECTOR_TEXT   VARCHAR2(40 BYTE),
  ENTRY_TEXT              VARCHAR2(40 BYTE),
  ADDITIONAL_ENTRY_TEXT   VARCHAR2(40 BYTE),
  MAAC                    NUMBER,
  INVO_AMOUNT             NUMBER
)

drop table aj_temp_33

insert into daily_charges_inen_tmp

with q1 as (
select REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, max(DATE_CREATED) date_created, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, 
IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, 
EVRE_CHAR_USAGE, PRINT_REQUIRED, VMCT_RATE_VALUE, SUM(NUM_OF_DAYS) num_of_days, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, 
round(sum(EEK_AMT),2) eek_amt, AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, round(SUM(ACC_AMOUNT),2) acc_amount, BILLING_SELECTOR_TEXT, ENTRY_TEXT, 
ADDITIONAL_ENTRY_TEXT, maac
from (
select /*+ NO_PARALLEL */ null REF_NUM, null INVO_REF_NUM, null SEC_AMT, 'N' ROUNDING_INDICATOR, 'N' UNDER_DISPUTE, null CREATED_BY, sysdate DATE_CREATED, null AMT_IN_CURR, fcit_billing_selector BILLING_SELECTOR, 
FCIT_TYPE_CODE, fcit_taty_type_code TATY_TYPE_CODE, susg SUSG_REF_NUM, null IADN_REF_NUM, null CURR_CODE, null VMCT_TYPE_CODE, null LAST_UPDATED_BY, null DATE_UPDATED, null DESCRIPTION, 
null SEC_AMT_TAX, null AMT_TAX_CURR, 'N' MANUAL_ENTRY, null EVRE_COUNT, null EVRE_DURATION, '???' MODULE_REF, null SEC_FIXED_CHARGE_VALUE, null EVRE_CHAR_USAGE, null PRINT_REQUIRED, 
null VMCT_RATE_VALUE, main_days NUM_OF_DAYS, null EVRE_DATA_VOLUME, null MAAS_REF_NUM, null CADC_REF_NUM, null FCDT_TYPE_CODE, null SEC_FF_DISC_AMT, null SEC_CURR_CODE, period_charge EEK_AMT, 
null AMT_TAX, curr_code PRI_CURR_CODE, null FF_DISC_AMT, null FIXED_CHARGE_VALUE, null SEC_ACC_AMOUNT, period_charge ACC_AMOUNT, fcit_bise BILLING_SELECTOR_TEXT, 
fcit_desc ENTRY_TEXT, null ADDITIONAL_ENTRY_TEXT, maac
from daily_charges_descr_temp
)
group by REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, 
CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, 
PRINT_REQUIRED, VMCT_RATE_VALUE, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, AMT_TAX, 
PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, maac
), q2 as (
select REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, max(DATE_CREATED) date_created, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, 
IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, 
EVRE_CHAR_USAGE, PRINT_REQUIRED, VMCT_RATE_VALUE, SUM(NUM_OF_DAYS) num_of_days, EVRE_DATA_VOLUME, MAAS_REF_NUM, max(CADC_REF_NUM) cadc_ref_num, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, 
round(sum(EEK_AMT),2) eek_amt, AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, round(SUM(ACC_AMOUNT),4) acc_amount, BILLING_SELECTOR_TEXT, ENTRY_TEXT, 
ADDITIONAL_ENTRY_TEXT, maac
from (
select /*+ NO_PARALLEL */ null REF_NUM, null INVO_REF_NUM, null SEC_AMT, 'N' ROUNDING_INDICATOR, 'N' UNDER_DISPUTE, null CREATED_BY, sysdate DATE_CREATED, null AMT_IN_CURR, disc_billing_selector BILLING_SELECTOR, 
null FCIT_TYPE_CODE, fcit_taty_type_code TATY_TYPE_CODE, susg SUSG_REF_NUM, null IADN_REF_NUM, null CURR_CODE, null VMCT_TYPE_CODE, null LAST_UPDATED_BY, null DATE_UPDATED, null DESCRIPTION, 
null SEC_AMT_TAX, null AMT_TAX_CURR, 'N' MANUAL_ENTRY, 1 EVRE_COUNT, null EVRE_DURATION, '???' MODULE_REF, null SEC_FIXED_CHARGE_VALUE, null EVRE_CHAR_USAGE, crm PRINT_REQUIRED, 
null VMCT_RATE_VALUE, main_days NUM_OF_DAYS, null EVRE_DATA_VOLUME, null MAAS_REF_NUM, cadc_ref_num CADC_REF_NUM, fcit_fcdt_type_code FCDT_TYPE_CODE, null SEC_FF_DISC_AMT, null SEC_CURR_CODE, 
discount EEK_AMT, null AMT_TAX, curr_code PRI_CURR_CODE, null FF_DISC_AMT, null FIXED_CHARGE_VALUE, null SEC_ACC_AMOUNT, discount ACC_AMOUNT, disc_bise BILLING_SELECTOR_TEXT, 
disc_description ENTRY_TEXT, null ADDITIONAL_ENTRY_TEXT, maac, sudi_ref_num
from daily_charges_descr_temp
where 1=1
and disc_billing_selector is not null
)
group by REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, 
CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, 
PRINT_REQUIRED, VMCT_RATE_VALUE, EVRE_DATA_VOLUME, MAAS_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, AMT_TAX, 
PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, maac, sudi_ref_num
), q3 as (
select /*+ NO_INDEX(invo) */ min(invo.invo_start) invo_start, max(invo.invo_end) invo_end, inen.billing_selector, inen.fcit_type_code, inen.fcdt_type_code, inen.susg_ref_num , 
sum(coalesce(inen.eek_amt, inen.acc_amount,0)) invo_amount
from invoices invo, invoice_entries inen
where 1=1 
and invo.ref_num = inen.invo_ref_num
and invo.period_start = :p_start_date 
and invo.invoice_type = 'INT'
group by inen.billing_selector, inen.fcit_type_code, inen.fcdt_type_code, inen.susg_ref_num
), q4 as (
select q1.REF_NUM, q1.INVO_REF_NUM, q1.SEC_AMT, q1.ROUNDING_INDICATOR, q1.UNDER_DISPUTE, q1.CREATED_BY, q1.DATE_CREATED, q1.AMT_IN_CURR, q1.BILLING_SELECTOR, q1.FCIT_TYPE_CODE, 
q1.TATY_TYPE_CODE, q1.SUSG_REF_NUM, q1.IADN_REF_NUM, q1.CURR_CODE, q1.VMCT_TYPE_CODE, q1.LAST_UPDATED_BY, q1.DATE_UPDATED, q1.DESCRIPTION, q1.SEC_AMT_TAX, q1.AMT_TAX_CURR, q1.MANUAL_ENTRY, 
q1.EVRE_COUNT, q1.EVRE_DURATION, q1.MODULE_REF, q1.SEC_FIXED_CHARGE_VALUE, q1.EVRE_CHAR_USAGE, q1.PRINT_REQUIRED, q1.VMCT_RATE_VALUE, q1.NUM_OF_DAYS, q1.EVRE_DATA_VOLUME, q1.MAAS_REF_NUM, 
q1.CADC_REF_NUM, q1.FCDT_TYPE_CODE, q1.SEC_FF_DISC_AMT, q1.SEC_CURR_CODE, q1.EEK_AMT - nvl(q3.invo_amount, 0) eek_amt, q1.AMT_TAX, q1.PRI_CURR_CODE, q1.FF_DISC_AMT, q1.FIXED_CHARGE_VALUE, 
q1.SEC_ACC_AMOUNT, q1.ACC_AMOUNT - nvl(q3.invo_amount, 0) acc_amount, q1.BILLING_SELECTOR_TEXT, q1.ENTRY_TEXT, q1.ADDITIONAL_ENTRY_TEXT, q1.MAAC, q3.invo_amount 
from q1 LEFT JOIN q3 on q1.billing_selector = q3.billing_selector and q1.susg_ref_num = q3.susg_ref_num and q1.fcit_type_code = q3.fcit_type_code
UNION ALL
select q2.REF_NUM, q2.INVO_REF_NUM, q2.SEC_AMT, q2.ROUNDING_INDICATOR, q2.UNDER_DISPUTE, q2.CREATED_BY, q2.DATE_CREATED, q2.AMT_IN_CURR, q2.BILLING_SELECTOR, q2.FCIT_TYPE_CODE, 
q2.TATY_TYPE_CODE, q2.SUSG_REF_NUM, q2.IADN_REF_NUM, q2.CURR_CODE, q2.VMCT_TYPE_CODE, q2.LAST_UPDATED_BY, q2.DATE_UPDATED, q2.DESCRIPTION, q2.SEC_AMT_TAX, q2.AMT_TAX_CURR, q2.MANUAL_ENTRY, 
q2.EVRE_COUNT, q2.EVRE_DURATION, q2.MODULE_REF, q2.SEC_FIXED_CHARGE_VALUE, q2.EVRE_CHAR_USAGE, q2.PRINT_REQUIRED, q2.VMCT_RATE_VALUE, q2.NUM_OF_DAYS, q2.EVRE_DATA_VOLUME, q2.MAAS_REF_NUM, 
q2.CADC_REF_NUM, q2.FCDT_TYPE_CODE, q2.SEC_FF_DISC_AMT, q2.SEC_CURR_CODE, q2.EEK_AMT - nvl(q3.invo_amount, 0) eek_amt, q2.AMT_TAX, q2.PRI_CURR_CODE, q2.FF_DISC_AMT, q2.FIXED_CHARGE_VALUE, 
q2.SEC_ACC_AMOUNT, q2.ACC_AMOUNT - nvl(q3.invo_amount, 0) acc_amount, q2.BILLING_SELECTOR_TEXT, q2.ENTRY_TEXT, q2.ADDITIONAL_ENTRY_TEXT, q2.MAAC , q3.invo_amount
from q2 LEFT JOIN q3 on q2.billing_selector = q3.billing_selector and q2.susg_ref_num = q3.susg_ref_num and q2.fcdt_type_code = q3.fcdt_type_code
)
select /*+ MONITOR NO_INDEX(invo) */q4.REF_NUM, INVO.REF_NUM INVO_REF_NUM, q4.SEC_AMT, q4.ROUNDING_INDICATOR, q4.UNDER_DISPUTE, q4.CREATED_BY, q4.DATE_CREATED, q4.AMT_IN_CURR, q4.BILLING_SELECTOR, q4.FCIT_TYPE_CODE, 
q4.TATY_TYPE_CODE, q4.SUSG_REF_NUM, q4.IADN_REF_NUM, q4.CURR_CODE, q4.VMCT_TYPE_CODE, q4.LAST_UPDATED_BY, q4.DATE_UPDATED, q4.DESCRIPTION, q4.SEC_AMT_TAX, q4.AMT_TAX_CURR, q4.MANUAL_ENTRY, 
q4.EVRE_COUNT, q4.EVRE_DURATION, q4.MODULE_REF, q4.SEC_FIXED_CHARGE_VALUE, q4.EVRE_CHAR_USAGE, q4.PRINT_REQUIRED, q4.VMCT_RATE_VALUE, q4.NUM_OF_DAYS, q4.EVRE_DATA_VOLUME, q4.MAAS_REF_NUM, 
q4.CADC_REF_NUM, q4.FCDT_TYPE_CODE, q4.SEC_FF_DISC_AMT, q4.SEC_CURR_CODE, q4.EEK_AMT, q4.AMT_TAX, q4.PRI_CURR_CODE, q4.FF_DISC_AMT, q4.FIXED_CHARGE_VALUE, 
q4.SEC_ACC_AMOUNT, q4.ACC_AMOUNT, q4.BILLING_SELECTOR_TEXT, q4.ENTRY_TEXT, q4.ADDITIONAL_ENTRY_TEXT, q4.MAAC , q4.invo_amount
from q4 LEFT JOIN invoices invo ON q4.maac = invo.maac_ref_num and invo.invoice_type = 'INB' and period_start = :p_start_date

select count(*) over (partition by susg_ref_num, billing_selector, fcit_type_code), x.* from (
select * from aj_temp_33
UNION ALL
select inen.*, invo.maac_ref_num maac, null 
from invoice_entries inen, invoices invo
where 1=1 
and invo.ref_num = inen.invo_ref_num
--and inen.susg_ref_num=15790231
and invo.salp_fina_year = 2018
and invo.salp_per_num = 11
and billing_selector like 'KT%'
and (fcit_type_code like 'G%' OR fcdt_type_code like 'G%') 
and invo.invoice_type = 'INB'
union all
select comc.*, null, null, null, null, invo.maac_ref_num maac, null from common_monthly_charges comc, invoices invo 
where 1=1 
and invo.ref_num = comc.invo_ref_num
--and comc.susg_ref_num=15790231
and invo.salp_fina_year = 2018
and invo.salp_per_num = 11
and billing_selector like 'KT%'
and (fcit_type_code like 'G%' OR fcdt_type_code like 'G%') 
and invo.invoice_type = 'INB'
) x
order by maac, susg_ref_num, billing_selector


REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, FF_DISC_AMT, SEC_CURR_CODE, EEK_AMT, AMT_TAX, PRI_CURR_CODE, SEC_FF_DISC_AMT, FIXED_CHARGE_VALUE, INVO_INEN_REF_NUM
REF_NUM, INVO_REF_NUM, SEC_AMT, ROUNDING_INDICATOR, UNDER_DISPUTE, CREATED_BY, DATE_CREATED, AMT_IN_CURR, BILLING_SELECTOR, FCIT_TYPE_CODE, TATY_TYPE_CODE, SUSG_REF_NUM, IADN_REF_NUM, CURR_CODE, VMCT_TYPE_CODE, LAST_UPDATED_BY, DATE_UPDATED, DESCRIPTION, SEC_AMT_TAX, AMT_TAX_CURR, MANUAL_ENTRY, EVRE_COUNT, EVRE_DURATION, MODULE_REF, SEC_FIXED_CHARGE_VALUE, EVRE_CHAR_USAGE, PRINT_REQUIRED, VMCT_RATE_VALUE, NUM_OF_DAYS, EVRE_DATA_VOLUME, MAAS_REF_NUM, CADC_REF_NUM, FCDT_TYPE_CODE, SEC_FF_DISC_AMT, SEC_CURR_CODE, EEK_AMT, AMT_TAX, PRI_CURR_CODE, FF_DISC_AMT, FIXED_CHARGE_VALUE, SEC_ACC_AMOUNT, ACC_AMOUNT, BILLING_SELECTOR_TEXT, ENTRY_TEXT, ADDITIONAL_ENTRY_TEXT, MAAC, NULL

select * from invoices

select * from ssg_statuses
where susg_ref_num = 14317837

select *--invo.invo_start, invo.invo_end, inen.billing_selector, inen.fcit_type_code, inen.fcdt_type_code, inen.susg_ref_num , inen.eek_amt, inen.acc_amount
from invoices invo, invoice_entries inen
where 1=1 
and invo.ref_num = inen.invo_ref_num
--and invo.invo_start = :p_start_date 
--and invo.invoice_type = 'INT'
--and invo.invo_end < :p_end_date + 1 -1/24/60/60
--and invo.salp_fina_year = 2018
--and invo.salp_per_num = 11
--and inen.date_created < trunc(:p_end_date)+1
--and inen.billing_selector like 'KT%'
--and inen.fcit_type_code like 'G%'
and susg_ref_num = 16223058



select * from dba_tables
where table_name like '%INTERIM%'

EEK_AMT	BILLING_SELECTOR	FCIT_TYPE_CODE	TATY_TYPE_CODE	SUSG_REF_NUM
-4.99	KTS		S	7440310
11.49	KTO	GGW	S	7440310


select * from invoice_entries_interim 




union all

select inen.* 
from invoice_entries inen, invoices invo
where 1=1 
and invo.ref_num = inen.invo_ref_num
and inen.susg_ref_num=16223058
and invo.salp_fina_year = 2018
and invo.salp_per_num = 11
and billing_selector like 'KT%'



select *
from aj_temp_30
where susg=16223058


select * from fixed_charge_item_types
where type_code = 'GMT'

select inen.* 
from invoice_entries inen, invoices invo
where 1=1 
and invo.ref_num = inen.invo_ref_num
and inen.susg_ref_num=14026506
and invo.salp_fina_year = 2018
and invo.salp_per_num = 11
--and evre_count > 1
--and inen.billing_selector like 'K%'

select * from common_monthly_charges
where susg_ref_num = 15323739

select * from aj_temp_30
where susg=14026506

select * from aj_temp_30
where susg=14580179

select qq4.*, -least(sum(qq4.discount) over (partition by qq4.susg order by qq4.rn) - qq4.discount + qq4.charge_value, - qq4.discount) corrected_discount 
from qq4

select  qq4.MAAC, qq4.SUSG, qq4.PERIOD_CHARGE, qq4.FCIT_BILLING_SELECTOR, qq4.FCIT_TYPE_CODE, qq4.FCIT_BISE, qq4.FCIT_DESC, qq4.DISC_BILLING_SELECTOR, qq4.DISC_BISE, qq4.DISC_DESCR, 
qq4.FCIT_FCDT_TYPE_CODE, qq4.CADC_REF_NUM, -least(sum(qq4.discount) over (partition by qq4.susg order by qq4.rn) - qq4.discount + qq4.charge_value, - qq4.discount) DISCOUNT, 
qq4.real_disc_start START_DATE_CORR, qq4.real_disc_end END_DATE_CORR, qq4.disc_days PERIOD_DAYS_CORR, qq4.SEPV_START_REAL, qq4.SUDI_END, qq4.main_days period_days_main, 
qq4.starts start_date_main, qq4.ends end_date_main, qq4.sudi_ref_num
from qq4

order by maac, susg

select * from call_discount_codes


select * from party_discounts
where ref_num = 7128

where end_date between date '2018-10-01' and date '2018-10-31' 

select * from parties
where ref_num = 20921

select * from part_dico_details


where mixed_service = 'Y'


count(*) over (partition by susg, starts) cnt, 


 case rn when 1 then charge_value else 0 end real_charge_value,
order by maac, susg

select * from fixed_term_contracts


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

