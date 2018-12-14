drop table aj_temp_32 purge

create table aj_temp_33 as 
select * from aj_temp_31
where 1=0

select * from subs_serv_groups
where trunc(suac_ref_num, -3) = :p_maac

insert into aj_temp_33

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
), servs as (
select /*+ MATERIALIZE */ * from (
SELECT prli.sety_ref_num sety_ref_num
           FROM price_lists prli, service_types sety
          WHERE NVL (prli.par_value_charge, 'N') = 'N'
            AND prli.once_off = 'N'
            AND prli.pro_rata = 'N'
            AND prli.regular_charge = 'Y'
            AND prli.start_date <= :p_end_date + 1
            AND NVL (prli.end_date, :p_start_date) >= :p_start_date
            AND sety.ref_num = prli.sety_ref_num
            AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV')
UNION
SELECT ficv.sety_ref_num sety_ref_num
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
            AND ficv.start_date <= :p_end_date
            AND NVL (ficv.end_date, :p_start_date) >= :p_start_date
            AND sety.ref_num = ficv.sety_ref_num
            AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV')
)            
--where sety_ref_num = 5802234
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
and (stpe.susg_ref_num = :p_susg)----
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
and (ssst.susg_ref_num = :p_susg)----
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
and (susp.susg_ref_num = :p_susg)----
), discless as (
select /*+ */ greatest(supa_start_date, stpe_start_date, susp_start_date, ssst_start_date) starts, 
least(supa_end_date, stpe_end_date, susp_end_date, ssst_end_date) ends,
--supa_end, serv_ends, sepv_ends, act_ends, mipo_end, sepv_end, serv_end, act_end, next_sepv_start, next_serv_start, next_act_start, sepv_start, serv_start, act_start,
t.maac, t.susg, t.sept_type_code, t.sept_description, nvl(ficv.fcit_billing_selector, fcit.billing_selector) fcit_billing_selector, nvl(ficv.fcit_type_code, fcit.type_code) fcit_type_code, 
nvl(ficv.fcit_desc, fcit.description) fcit_desc, nvl(ficv.fcit_fcdt_type_code, fcit.fcdt_type_code) fcit_fcdt_type_code, q6.real_susp_start sepv_start_real, q4.sety_ref_num,
nvl(prli.charge_value,0) prli_charge_value, ficv.charge_value ficv_charge_value, coalesce(ficv.charge_value, prli.charge_value, 0) charge_value, q6.sepv_ref_num  
from t JOIN q4 ON to_char(t.susg)=to_char(q4.susg)
       JOIN q5 ON to_char(t.susg)=to_char(q5.susg)
       JOIN q6 ON to_char(t.susg)=to_char(q6.susg)
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
and (t.susg = :p_susg)----
), ftco0 as (
select ftco.ref_num ftco_ref_num, ftco.sept_type_code ftco_sept_type_code, ftco.mixed_packet_code, ftco.susg_ref_num, ftco.ebs_order_number, ftco.sept_type_code, 
greatest(nvl(ftco.start_date, :p_start_date), :p_start_date) start_date_c, ftco.end_date, ftco.date_closed, 
trunc(least(coalesce(date_closed, end_date, :p_end_date),coalesce(end_date, :p_end_date), :p_end_date)) end_date_c
from fixed_term_contracts ftco
where (ftco.susg_ref_num = :p_susg)----
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
                            and (sudi.susg_ref_num = :p_susg)----                                                 
left join part_dico_details padi ON PADI.PADI_REF_NUM = sudi.padi_ref_num
                                                   and padi.cadc_ref_num = cadc.ref_num
), qq1 as (
select case when (starts <= nvl(disc_end, :p_end_date) AND ends >= nvl(disc_start, :p_start_date)) 
             and (starts <= nvl(mipo_end_date, :p_end_date) AND ends >= nvl(mipo_start_date, :p_start_date))
             then 1 else 0 end discountable,
case when sudi_ref_num is null and nvl(discounted, 0) = 0 then 0 else 1 end discounts_available,       
--bcdv3.description disc_all_bise, 
t.maac, t.susg, t.fcit_billing_selector, bcdv1.description fcit_bise, t.fcit_type_code, t.fcit_desc, t.fcit_fcdt_type_code, t.starts, t.ends, t.sepv_start_real, t.sety_ref_num,
t.prli_charge_value, t.ficv_charge_value, t.charge_value, t.sept_type_code, t.sept_description, t.sepv_ref_num,
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
and (nvl(disc_start, :p_start_date) <= nvl(mipo_end_date, :p_end_date) AND nvl(disc_end, :p_end_date) >= nvl(mipo_start_date, :p_start_date))
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
1 else 0 end apply_corr,
qq2.*
from qq2
), qq7 as (
select row_number() over (partition by susg, starts order by discountable desc, discounts_available desc, sudi_ref_num) rn, 
apply_corr, REAL_DISC_START, case apply_corr when 1 then max_real_disc_end else real_disc_end end REAL_DISC_END, 
ends+1-starts main_days, case apply_corr when 1 then max_real_disc_end else real_disc_end end + 1 - real_disc_start disc_days,
DISCOUNTABLE, discounts_available, MAAC, SUSG, service_name, FCIT_BILLING_SELECTOR, FCIT_BISE, FCIT_TYPE_CODE,
FCIT_DESC, FCIT_FCDT_TYPE_CODE, STARTS, ENDS, SEPV_START_REAL, SETY_REF_NUM, PRLI_CHARGE_VALUE, FICV_CHARGE_VALUE, CHARGE_VALUE, SEPT_TYPE_CODE, SEPT_DESCRIPTION, SEPV_REF_NUM,
SEPV_PARAM_VALUE, SEPV_DESCRIPTION,
DISC_START, DISC_END, CADC_REF_NUM, PRECENTAGE, COUNT_FOR_MONTHS, 
COUNT_FOR_DAYS, DISCOUNT_CODE, DISC_DESCR, DISC_BILLING_SELECTOR, DISC_BISE, PRICING, MINIMUM_PRICE, SUDI_START_DATE, DISC_PERCENTAGE, DISC_ABSOLUTE, PRICE, 
padi_ref_num, SUDI_REF_NUM, CRM, MIXED_SERVICE, 
FTCO_REF_NUM, SUSG_REF_NUM, ftco_sept_type_code, MIPO_START_DATE, MIPO_END_DATE, DISCOUNTED, MONTHLY_DISC_RATE, MONTHLY_MARKDOWN, PACKET_CODE, PACKET_DESCRIPTION, BICY_CYCLE_CODE 
from qq3
where not (apply_corr = 1 and max_real_disc_end < real_disc_start)
), qq5 as (
select case rn when 1 then charge_value else 0 end real_charge_value, add_months(trunc(:p_start_date), 1) -trunc(:p_start_date) month_days,  
qq7.* 
from qq7
where not (discountable*discounts_available = 0 and rn > 1)
)
select  
qq4.MAAC, qq4.SUSG, qq4.PERIOD_CHARGE, qq4.FCIT_BILLING_SELECTOR, qq4.FCIT_TYPE_CODE, qq4.FCIT_BISE, qq4.FCIT_DESC, qq4.DISC_BILLING_SELECTOR, qq4.DISC_BISE, qq4.DISC_DESCR, 
qq4.FCIT_FCDT_TYPE_CODE, qq4.CADC_REF_NUM, -least(sum(qq4.discount) over (partition by qq4.susg order by qq4.rnx) - qq4.discount + qq4.charge_value, - qq4.discount) DISCOUNT, 
qq4.START_DATE_CORR, qq4.END_DATE_CORR, qq4.PERIOD_DAYS_CORR, qq4.SEPV_START_REAL, qq4.SUDI_END, qq4.period_days_main, qq4.starts start_date_main, qq4.ends end_date_main, qq4.sudi_ref_num
from (
select maac, susg, 
round(real_charge_value*main_days/month_days,2) period_charge, 
fcit_billing_selector, fcit_type_code, fcit_bise,  fcit_desc,  disc_billing_selector, disc_bise, disc_descr, fcit_fcdt_type_code, cadc_ref_num,
-case when disc_days is not null and nvl(discounted, 0) = 0 then 
      case when price is not null then
         round(greatest(charge_value-price, 0)*disc_days/month_days, 2)
      when price is null and (disc_percentage is not null or disc_absolute is not null) then
         round(greatest((nvl(disc_percentage,0)/100)*charge_value, least(nvl(disc_absolute, 0), charge_value))*disc_days/month_days, 2)
      else
        case when pricing = 'Y' then
          round((charge_value - least((nvl(precentage,100)/100)*charge_value, least(nvl(minimum_price, charge_value), charge_value)))*disc_days/month_days, 2)
        else
          round(greatest((nvl(precentage,0)/100)*charge_value, least(nvl(minimum_price, 0), charge_value))*disc_days/month_days, 2)
        end
      end
else
  null  
end discount
,real_disc_start start_date_corr, real_disc_end end_date_corr, disc_days period_days_corr, sepv_start_real, rn rnx, charge_value, month_days, count_for_months, count_for_days, sudi_start_date,
case when count_for_months is null and count_for_days is null or sudi_start_date is null then null 
               else add_months(trunc(sudi_start_date), nvl(count_for_months,0)) + nvl(count_for_days,0) end sudi_end
, starts, ends, main_days period_days_main, sudi_ref_num  
from qq5
) qq4

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

