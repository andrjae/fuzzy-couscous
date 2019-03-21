select * from fixed_charge_item_types
where type_code = 'GGA'

select * from fixed_charge_values
where sety_ref_num = 5802234
order by 3

select user from dual

select * from fixed_charge_item_types
where type_code like 'CG%'

select * from fixed_charge_types

SELECT (select fcit2.type_code from fixed_charge_item_types fcit2 
                    where fcit2.package_category=fcit.package_category and fcit2.billing_selector=fcit.billing_selector and fcit2.description=fcit.description
                    and fcit2.once_off=fcit.once_off and fcit2.regular_charge=fcit.regular_charge and fcit2.type_code != fcit.type_code) type_code2,  
       DESCRIPTION, ONCE_OFF, TATY_TYPE_CODE, user CREATED_BY, sysdate DATE_CREATED, 'Y' PRO_RATA, BILLING_SELECTOR, FUTURE_PERIOD, user LAST_UPDATED_BY, sysdate DATE_UPDATED, REGULAR_CHARGE,
       PACKAGE_CATEGORY, NOTES, ARCHIVE, SETY_REF_NUM, PRLI_PACKAGE_CATEGORY, PREV_FCIT_TYPE_CODE, FCDT_TYPE_CODE, VALID_CHARGE_PARAMETER, FIRST_PRORATED_CHARGE, BILL_FCIT_TYPE_CODE,
       REGULAR_TYPE, SETY_FIRST_PRORATED, FREE_PERIODS, LAST_PRORATED_CHARGE, 'Y' DAILY_CHARGE
       
       
       select * from fixed_charge_item_types
       order by date_updated desc nulls last

INSERT INTO TBCIS.BCC_DOMAIN_VALUES (
   DOMA_TYPE_CODE, VALUE_CODE, DESCRIPTION, 
   CREATED_BY, DATE_CREATED, NUMERIC_VALUE, 
   DATE_VALUE, LAST_UPDATED_BY, DATE_UPDATED, 
   TEXT_VALUE, TEXT1, TEXT2, 
   ARHIVE, DECO_TYPE) 
SELECT DOMA_TYPE_CODE,
(select fcit2.type_code || 'D' from TBCIS.fixed_charge_item_types fcit2, TBCIS.fixed_charge_item_types fcit  
                    where fcit2.package_category=fcit.package_category and fcit2.billing_selector=fcit.billing_selector and fcit2.description=fcit.description
                    and fcit2.once_off=fcit.once_off and fcit2.regular_charge=fcit.regular_charge and fcit.type_code=substr(bcdv.value_code,1,3) and fcit2.type_code != fcit.type_code)
       VALUE_CODE,
       DESCRIPTION,
       user created_by,
       sysdate DATE_CREATED,
       NUMERIC_VALUE,
       DATE_VALUE,
       LAST_UPDATED_BY,
       DATE_UPDATED,
       TEXT_VALUE,
       TEXT1,
       TEXT2,
       ARHIVE,
       DECO_TYPE
  FROM TBCIS.BCC_DOMAIN_VALUES bcdv
where doma_type_code = 'FCDT'
and value_code in (
  select type_code || 'D' 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from TBCIS.fixed_charge_values
where sety_ref_num = 5802234
and nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and daily_charge = 'N'
); 

update TBCIS.fixed_charge_item_types
set sety_ref_num=5802234
where type_code = 'GGA';
update TBCIS.fixed_charge_item_types fcit1
set pro_rata = 'Y', last_updated_by = user, date_updated = sysdate, daily_charge = 'Y', fcdt_type_code = type_code || 'D', sety_ref_num = (
select fcit0.sety_ref_num from TBCIS.fixed_charge_item_types fcit0 
                    where fcit0.package_category=fcit1.package_category and fcit0.billing_selector=fcit1.billing_selector and fcit0.description=fcit1.description
                    and fcit0.once_off=fcit1.once_off and fcit0.regular_charge=fcit1.regular_charge and fcit0.type_code != fcit1.type_code) 
where type_code in
(
select (
select fcit2.type_code from TBCIS.fixed_charge_item_types fcit2 
                    where fcit2.package_category=fcit.package_category and fcit2.billing_selector=fcit.billing_selector and fcit2.description=fcit.description
                    and fcit2.once_off=fcit.once_off and fcit2.regular_charge=fcit.regular_charge and fcit2.type_code != fcit.type_code) type_code2
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from TBCIS.fixed_charge_values
where sety_ref_num = 5802234
and nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and daily_charge = 'N'
);

INSERT INTO TBCIS.FIXED_CHARGE_VALUES (
   REF_NUM, START_DATE, FCIT_CHARGE_CODE, 
   SEC_CHARGE_VALUE, CHCA_TYPE_CODE, CREATED_BY, 
   DATE_CREATED, SEPT_TYPE_CODE, SETY_REF_NUM, 
   END_DATE, LAST_UPDATED_BY, DATE_UPDATED, 
   SEPV_REF_NUM, SEPA_REF_NUM, PAR_VALUE_CHARGE, 
   CHANNEL_TYPE, SEC_CURR_CODE, CHARGE_VALUE, 
   CURR_CODE) 
select 
tbcis.gen_ref_num_s.nextval,
:p_start_date start_date,
(select fcit2.type_code from TBCIS.fixed_charge_item_types fcit2, TBCIS.fixed_charge_item_types fcit1  
                    where fcit2.package_category=fcit1.package_category and fcit2.billing_selector=fcit1.billing_selector and fcit2.description=fcit1.description
                    and fcit2.once_off=fcit1.once_off and fcit2.regular_charge=fcit1.regular_charge and fcit1.type_code=ficv.fcit_charge_code and fcit2.type_code != fcit1.type_code) fcit_charge_code,
   SEC_CHARGE_VALUE, CHCA_TYPE_CODE, user CREATED_BY, 
   sysdate DATE_CREATED, SEPT_TYPE_CODE, SETY_REF_NUM, 
   END_DATE, null LAST_UPDATED_BY, null DATE_UPDATED, 
   SEPV_REF_NUM, SEPA_REF_NUM, PAR_VALUE_CHARGE, 
   CHANNEL_TYPE, SEC_CURR_CODE, CHARGE_VALUE, 
   CURR_CODE
from tbcis.fixed_charge_values ficv
where ficv.fcit_charge_code 
in (
  select type_code 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from TBCIS.fixed_charge_values
where sety_ref_num = 5802234
and nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
and pro_rata='N'
   and daily_charge = 'N'
)
and nvl(trunc(ficv.end_date), sysdate+1) > trunc(sysdate);

update 
tbcis.fixed_charge_values ficv
set end_date = :p_start_date-1, last_updated_by = user
where ficv.fcit_charge_code 
in (
  select type_code 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from TBCIS.fixed_charge_values
where sety_ref_num = 5802234
and nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
and pro_rata='N'
   and daily_charge = 'N'
)
and nvl(trunc(ficv.end_date), sysdate+1) > trunc(sysdate);
delete 
from TBCIS.price_lists
where sety_ref_num = 5802234
and regular_charge='Y'
and once_off='N'
and daily_charge = 'Y';

INSERT INTO TBCIS.PRICE_LISTS (
   REF_NUM, PACKAGE_CATEGORY, SETY_REF_NUM, 
   SEPA_REF_NUM, SEPV_REF_NUM, ONCE_OFF, 
   PRO_RATA, REGULAR_CHARGE, SEC_CHARGE_VALUE, 
   DESCRIPTION, START_DATE, END_DATE, 
   CREATED_BY, DATE_CREATED, LAST_UPDATED_BY, 
   DATE_UPDATED, PAR_VALUE_CHARGE, FCTY_TYPE_CODE, 
   NETY_TYPE_CODE, CHANNEL_TYPE, SEC_CURR_CODE, 
   CHARGE_VALUE, CURR_CODE, DAILY_CHARGE)
select 
   prli_ref_num_s.nextval, 
   PACKAGE_CATEGORY, SETY_REF_NUM, 
   SEPA_REF_NUM, SEPV_REF_NUM, ONCE_OFF, 
   'Y' PRO_RATA, REGULAR_CHARGE, SEC_CHARGE_VALUE, 
   DESCRIPTION, :p_start_date START_DATE, END_DATE, 
   user CREATED_BY, sysdate DATE_CREATED, null LAST_UPDATED_BY, 
   null DATE_UPDATED, PAR_VALUE_CHARGE, 'DCH' FCTY_TYPE_CODE, 
   NETY_TYPE_CODE, CHANNEL_TYPE, SEC_CURR_CODE, 
   CHARGE_VALUE, CURR_CODE, DAILY_CHARGE 
from TBCIS.price_lists
where sety_ref_num = 5802234
and nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
and regular_charge='Y'
and once_off='N'
and pro_rata='N'
and daily_charge = 'N';

update TBCIS.price_lists
set end_date = :p_start_date-1, last_updated_by=user, date_updated=sysdate
where sety_ref_num = 5802234
and nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
and regular_charge='Y'
and once_off='N'
and pro_rata='N'
and daily_charge = 'N';

calculate_discounts


select * from price_lists
where nvl(date_updated, date_created) > trunc(sysdate)
order by sepv_ref_num


order by nvl(date_updated, date_created) desc

  select * 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from TBCIS.fixed_charge_values
where sety_ref_num = 5802234
and nvl(trunc(end_date)+2, sysdate)+1 > trunc(sysdate)
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
order by package_category, description, type_code



cadc_ref_num_s

INSERT INTO TBCIS.CALL_DISCOUNT_CODES (
   REF_NUM, DISCOUNT_CODE, START_BILL_PERIOD, 
   NEXT_BILL_PERIOD, SEC_AMOUNT, CALL_TYPE, 
   FCIT_TYPE_CODE, BILLING_SELECTOR, DISCOUNT_COMPLETED, 
   DATE_CREATED, CREATED_BY, DATE_UPDATED, 
   LAST_UPDATED_BY, SEPT_TYPE_CODE, END_BILL_PERIOD, 
   SUBS_DISCOUNT_CODE, NEW_MOBILE, DURATION, 
   SUMMARY_DISCOUNT, PRECENTAGE, DICO_REF_NUM, 
   DESCRIPTION, TATY_TYPE_CODE, START_DATE, 
   END_DATE, PRIORITY, COUNT_FOR_MONTHS, 
   COUNT_FOR_DAYS, FROM_DAY, FOR_DAY_CLASS, 
   FOR_CHAR_ANAL_CODE, FOR_BILLING_SELECTOR, FOR_FCIT_TYPE_CODE, 
   FOR_SETY_REF_NUM, FOR_SEPV_REF_NUM, DISC_BILLING_SELECTOR, 
   PRINT_REQUIRED, CRM, COUNT, 
   TIME_BAND_START, TIME_BAND_END, SEC_MONTHLY_AMOUNT, 
   CHG_DURATION, PERIOD_SEK, SEC_MINIMUM_PRICE, 
   SINGLE_COUNT, DECREASE, PRICING, 
   CHCA_TYPE_CODE, BILL_SEL_SUM, FROM_COUNT, 
   MIN_PRICE_UNIT, SEC_CONTROL_AMOUNT, SEC_INVO_AMOUNT, 
   SEC_INVE_AMOUNT, SEC_CURR_CODE, AMOUNT, 
   CONTROL_AMOUNT, CURR_CODE, INVE_AMOUNT, 
   INVO_AMOUNT, MINIMUM_PRICE, MONTHLY_AMOUNT, 
   CALC, MIXED_SERVICE) 
select cadc_ref_num_s.nextval ref_num, 
   DISCOUNT_CODE, START_BILL_PERIOD, 
   NEXT_BILL_PERIOD, SEC_AMOUNT, CALL_TYPE, 
   FCIT_TYPE_CODE, BILLING_SELECTOR, DISCOUNT_COMPLETED, 
   DATE_CREATED, CREATED_BY, DATE_UPDATED, 
   LAST_UPDATED_BY, SEPT_TYPE_CODE, END_BILL_PERIOD, 
   SUBS_DISCOUNT_CODE, NEW_MOBILE, DURATION, 
   SUMMARY_DISCOUNT, PRECENTAGE, DICO_REF_NUM, 
   DESCRIPTION, TATY_TYPE_CODE, START_DATE, 
   END_DATE, PRIORITY, COUNT_FOR_MONTHS, 
   COUNT_FOR_DAYS, FROM_DAY, FOR_DAY_CLASS, 
   FOR_CHAR_ANAL_CODE, FOR_BILLING_SELECTOR, 
   FOR_FCIT_TYPE_CODE, 
   FOR_SETY_REF_NUM, FOR_SEPV_REF_NUM, DISC_BILLING_SELECTOR, 
   PRINT_REQUIRED, CRM, COUNT, 
   TIME_BAND_START, TIME_BAND_END, SEC_MONTHLY_AMOUNT, 
   CHG_DURATION, PERIOD_SEK, SEC_MINIMUM_PRICE, 
   SINGLE_COUNT, DECREASE, PRICING, 
   CHCA_TYPE_CODE, BILL_SEL_SUM, FROM_COUNT, 
   MIN_PRICE_UNIT, SEC_CONTROL_AMOUNT, SEC_INVO_AMOUNT, 
   SEC_INVE_AMOUNT, SEC_CURR_CODE, AMOUNT, 
   CONTROL_AMOUNT, CURR_CODE, INVE_AMOUNT, 
   INVO_AMOUNT, MINIMUM_PRICE, MONTHLY_AMOUNT, 
   CALC, MIXED_SERVICE from ( 
select row_number() over (partition by dico_ref_num, for_sepv_ref_num, for_sety_ref_num, minimum_price, substr(for_fcit_type_code, 2,2) order by ref_num) rn,
   DISCOUNT_CODE, START_BILL_PERIOD, 
   NEXT_BILL_PERIOD, SEC_AMOUNT, CALL_TYPE, 
   FCIT_TYPE_CODE, BILLING_SELECTOR, DISCOUNT_COMPLETED, 
   sysdate DATE_CREATED, user CREATED_BY, null DATE_UPDATED, 
   null LAST_UPDATED_BY, SEPT_TYPE_CODE, END_BILL_PERIOD, 
   SUBS_DISCOUNT_CODE, NEW_MOBILE, DURATION, 
   SUMMARY_DISCOUNT, PRECENTAGE, DICO_REF_NUM, 
   DESCRIPTION, TATY_TYPE_CODE, START_DATE, 
   END_DATE, PRIORITY, COUNT_FOR_MONTHS, 
   COUNT_FOR_DAYS, FROM_DAY, FOR_DAY_CLASS, 
   FOR_CHAR_ANAL_CODE, FOR_BILLING_SELECTOR, 
   (select fcit2.type_code from TBCIS.fixed_charge_item_types fcit2, TBCIS.fixed_charge_item_types fcit1  
                    where fcit2.package_category=fcit1.package_category and fcit2.billing_selector=fcit1.billing_selector and fcit2.description=fcit1.description
                    and fcit2.once_off=fcit1.once_off and fcit2.regular_charge=fcit1.regular_charge and fcit1.type_code=cadc.for_fcit_type_code and fcit2.type_code != fcit1.type_code) 
   FOR_FCIT_TYPE_CODE, 
   FOR_SETY_REF_NUM, FOR_SEPV_REF_NUM, DISC_BILLING_SELECTOR, 
   PRINT_REQUIRED, CRM, COUNT, 
   TIME_BAND_START, TIME_BAND_END, SEC_MONTHLY_AMOUNT, 
   CHG_DURATION, PERIOD_SEK, SEC_MINIMUM_PRICE, 
   SINGLE_COUNT, DECREASE, PRICING, 
   CHCA_TYPE_CODE, BILL_SEL_SUM, FROM_COUNT, 
   MIN_PRICE_UNIT, SEC_CONTROL_AMOUNT, SEC_INVO_AMOUNT, 
   SEC_INVE_AMOUNT, SEC_CURR_CODE, AMOUNT, 
   CONTROL_AMOUNT, CURR_CODE, INVE_AMOUNT, 
   INVO_AMOUNT, MINIMUM_PRICE, MONTHLY_AMOUNT, 
   CALC, MIXED_SERVICE 
 from tbcis.call_discount_codes cadc
where for_fcit_type_code in (
  select type_code 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from fixed_charge_values
where sety_ref_num = 5802234
and end_date = :p_start_date-1
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and daily_charge = 'N'
) 
and nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
and for_sety_ref_num = 5802234
and call_type = 'REGU'
)
where rn=1;



select * from all_sequences
where last_number > 22442
order by last_number

select * from DISC_CALL_AMOUNTS

select * from evre_min_discounts

select count(*) over (partition by dico_ref_num, for_sepv_ref_num, for_sety_ref_num, minimum_price, substr(for_fcit_type_code, 2,2)) c, 
cadc.* from call_discount_codes cadc
where (for_fcit_type_code in (
  select type_code 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from fixed_charge_values
where sety_ref_num = 5802234
and end_date = :p_start_date-1
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and daily_charge = 'N'
) OR 
for_fcit_type_code in (
  select type_code 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from fixed_charge_values
where sety_ref_num = 5802234
and start_date = :p_start_date
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and daily_charge = 'Y'
)
)
and nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
and call_type = 'REGU'
order by 1

order by 2, for_sepv_ref_num, minimum_price, substr(for_fcit_type_code, 2,2)

select * from call_discount_codes
where ref_num in (22194, 22195)

select * from part_dico_details
where cadc_ref_num in (22194, 22195)


INSERT INTO TBCIS.PART_DICO_DETAILS (PADI_REF_NUM,
                                     CADC_REF_NUM,
                                     DISC_PERCENTAGE,
                                     DISC_ABSOLUTE,
                                     PRICE,
                                     CREATED_BY,
                                     DATE_CREATED,
                                     LAST_UPDATED_BY,
                                     DATE_UPDATED)
select   PADI_REF_NUM, 
  (select cadc2.ref_num 
   from TBCIS.call_discount_codes cadc2, TBCIS.call_discount_codes cadc1
   where cadc2.for_fcit_type_code =
   (select fcit2.type_code from TBCIS.fixed_charge_item_types fcit2, TBCIS.fixed_charge_item_types fcit1  
                    where fcit2.package_category=fcit1.package_category and fcit2.billing_selector=fcit1.billing_selector and fcit2.description=fcit1.description
                    and fcit2.once_off=fcit1.once_off and fcit2.regular_charge=fcit1.regular_charge and fcit1.type_code=cadc1.for_fcit_type_code and fcit2.type_code != fcit1.type_code)
   and cadc2.ref_num != cadc1.ref_num and cadc2.dico_ref_num = cadc1.dico_ref_num and cadc2.for_sepv_ref_num = cadc1.for_sepv_ref_num and cadc2.for_sety_ref_num = cadc1.for_sety_ref_num
   and nvl(cadc2.minimum_price, 1000000) = nvl(cadc1.minimum_price, 1000000)  and cadc1.ref_num = padi.cadc_ref_num  
   )
         CADC_REF_NUM,
         DISC_PERCENTAGE,
         DISC_ABSOLUTE,
         PRICE,
   user CREATED_BY,
sysdate DATE_CREATED,
   null LAST_UPDATED_BY,
   null DATE_UPDATED
from part_dico_details padi
where cadc_ref_num in (
select ref_num from call_discount_codes
where for_fcit_type_code in (
  select type_code 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from fixed_charge_values
where sety_ref_num = 5802234
and end_date = :p_start_date-1
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and daily_charge = 'N'
) 
and nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
and call_type = 'REGU'
)
and padi_ref_num in
(
select ref_num from party_discounts
where nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
);

select *
from part_dico_details
where cadc_ref_num in (
select ref_num from call_discount_codes
where (for_fcit_type_code in (
  select type_code 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from fixed_charge_values
where sety_ref_num = 5802234
and end_date = :p_start_date-1
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and daily_charge = 'N'
) OR 
for_fcit_type_code in (
  select type_code 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from fixed_charge_values
where sety_ref_num = 5802234
and start_date = :p_start_date
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and daily_charge = 'Y'
)
)
and nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
and call_type = 'REGU'
)
and padi_ref_num in
(
select ref_num from party_discounts
where nvl(trunc(end_date), sysdate)+1 > trunc(sysdate)
)
order by 1, 2



select * from all_tab_columns
where column_name = 'CADC_REF_NUM'
and owner = 'TBCIS'




GGA
GGK
GGH
GGC
GGD
GGE
 ggl
 ggm
GGN
GGP
GGQ
GGR
 ggi
GGT
 gmt
 ggu
GGW
GGX


select * from fixed_charge_item_types
where type_code like 'C%'
order by date_created desc, package_category

select 
* 
from fixed_charge_values
where (sepa_ref_num, sepv_ref_num) in (
select sepa_ref_num, sepv_ref_num from price_lists
where sety_ref_num = 5802234
and nvl(end_date, sysdate+1) > sysdate
and regular_charge='Y'
and once_off='N'
and sepv_ref_num in (
select ref_num from service_param_values
where nvl(trunc(end_date), sysdate+1) > trunc(sysdate)
)
)
and fcit_charge_code = 'TEM'

and sept_type_code in (
select type_code from serv_package_types
where nvl(trunc(end_date), sysdate+1) > trunc(sysdate) 
)

4766 4767 4768 5465



select * from serv_package_types
where nvl(end_date, sysdate+1) > sysdate 


select * from price_lists
where sety_ref_num = 5802234
and nvl(end_date, sysdate+1) > sysdate
and regular_charge='Y'
and once_off='N'


and sepv_ref_num in (
select ref_num from service_param_values
where nvl(trunc(end_date), sysdate+1) < trunc(sysdate)
)

select * from service_param_values

select * from serv_package_types
where type_code = 'NU4T'




select * from 