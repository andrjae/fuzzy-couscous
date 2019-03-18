CREATE OR REPLACE PROCEDURE TBCIS.DAILY_CHARGES_SETUP(p_start_date VARCHAR2) IS
   /*
   **  Module Name : DAILY_CHARGES_SETUP
   **  Date Created:  17.01.2019
   **  Author      :  Andres Jaek
   **  Description :  Procedure creates new setup for daily charges starting from p_start_date (DD.MM.YYYY)
   **
   ** Change History.
   ** ----------------------------------------------------------------------
   ** Version Date         Modified by  Reason
   **
   **  1.0    24.01.2019   A.Jaek   DOBAS-1695    New
   **
   **----------------------------------------------------------------------------
   */
l_start_date DATE;
BEGIN
l_start_date := TO_DATE(p_start_date, 'DD.MM.YYYY');

MERGE INTO TBCIS.FIXED_CHARGE_TYPES d
USING (
  Select
    'DCH' as TYPE_CODE,
    'Daily Charge Type' as DESCRIPTION,
    'Y' as REGULAR_CHARGE,
    'N' as ONCE_OFF,
    sysdate as DATE_CREATED,
    sec.get_username as CREATED_BY,
    sysdate as DATE_UPDATED,
    sec.get_username as LAST_UPDATED_BY,
    'Y' as PRO_RATA,
    'REGU' as DISCOUNT_TYPE,
    'Y' as DAILY_CHARGE
  From Dual) s
ON
  (d.TYPE_CODE = s.TYPE_CODE )
WHEN MATCHED
THEN
UPDATE SET
  d.DESCRIPTION = s.DESCRIPTION,
  d.REGULAR_CHARGE = s.REGULAR_CHARGE,
  d.ONCE_OFF = s.ONCE_OFF,
  d.DATE_UPDATED = s.DATE_UPDATED,
  d.LAST_UPDATED_BY = s.LAST_UPDATED_BY,
  d.PRO_RATA = s.PRO_RATA,
  d.DISCOUNT_TYPE = s.DISCOUNT_TYPE,
  d.DAILY_CHARGE = s.DAILY_CHARGE
WHEN NOT MATCHED
THEN
INSERT (
  TYPE_CODE, DESCRIPTION, REGULAR_CHARGE,
  ONCE_OFF, DATE_CREATED, CREATED_BY,
  DATE_UPDATED, LAST_UPDATED_BY, PRO_RATA,
  DISCOUNT_TYPE, DAILY_CHARGE)
VALUES (
  s.TYPE_CODE, s.DESCRIPTION, s.REGULAR_CHARGE,
  s.ONCE_OFF, s.DATE_CREATED, s.CREATED_BY,
  null, null, s.PRO_RATA,
  s.DISCOUNT_TYPE, s.DAILY_CHARGE);

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
       sec.get_username created_by,
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
and nvl(trunc(end_date), l_start_date)+1 > trunc(l_start_date)
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and nvl(daily_charge, 'N') = 'N'
); 

update TBCIS.fixed_charge_item_types
set sety_ref_num=5802234
where type_code = 'GGA';

update TBCIS.fixed_charge_item_types fcit1
set pro_rata = 'Y', last_updated_by = sec.get_username, date_updated = sysdate, daily_charge = 'Y', fcdt_type_code = type_code || 'D', sety_ref_num = (
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
and nvl(trunc(end_date), l_start_date)+1 > trunc(l_start_date)
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and nvl(daily_charge, 'N') = 'N'
);

DELETE from TBCIS.FIXED_CHARGE_VALUES ficv
where fcit_charge_code 
in (
  select type_code 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from TBCIS.FIXED_CHARGE_VALUES
where sety_ref_num = 5802234
and nvl(trunc(end_date), l_start_date)+1 > trunc(l_start_date)
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
and pro_rata='Y'
and nvl(daily_charge, 'N') = 'Y'
)
and nvl(trunc(ficv.end_date), l_start_date)+1 > trunc(l_start_date);

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
l_start_date start_date,
(select fcit2.type_code from TBCIS.fixed_charge_item_types fcit2, TBCIS.fixed_charge_item_types fcit1  
                    where fcit2.package_category=fcit1.package_category and fcit2.billing_selector=fcit1.billing_selector and fcit2.description=fcit1.description
                    and fcit2.once_off=fcit1.once_off and fcit2.regular_charge=fcit1.regular_charge and fcit1.type_code=ficv.fcit_charge_code and fcit2.type_code != fcit1.type_code) fcit_charge_code,
   SEC_CHARGE_VALUE, CHCA_TYPE_CODE, sec.get_username CREATED_BY, 
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
and nvl(trunc(end_date), l_start_date)+1 > trunc(l_start_date)
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
and pro_rata='N'
   and nvl(daily_charge, 'N') = 'N'
)
and nvl(trunc(ficv.end_date), l_start_date)+1 > trunc(l_start_date);

update 
tbcis.fixed_charge_values ficv
set end_date = l_start_date-1, last_updated_by = sec.get_username
where ficv.fcit_charge_code 
in (
  select type_code 
  FROM TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
  where (type_code in (
select distinct fcit_charge_code from TBCIS.fixed_charge_values
where sety_ref_num = 5802234
and nvl(trunc(end_date), l_start_date)+1 > trunc(l_start_date)
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
and pro_rata='N'
   and nvl(daily_charge, 'N') = 'N'
)
and nvl(trunc(ficv.end_date), l_start_date)+1 > trunc(l_start_date);

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
   DESCRIPTION, l_start_date START_DATE, END_DATE, 
   sec.get_username CREATED_BY, sysdate DATE_CREATED, null LAST_UPDATED_BY, 
   null DATE_UPDATED, PAR_VALUE_CHARGE, 'DCH' FCTY_TYPE_CODE, 
   NETY_TYPE_CODE, CHANNEL_TYPE, SEC_CURR_CODE, 
   CHARGE_VALUE, CURR_CODE, 'Y' DAILY_CHARGE 
from TBCIS.price_lists
where sety_ref_num = 5802234
and nvl(trunc(end_date), l_start_date)+1 > trunc(l_start_date)
and regular_charge='Y'
and once_off='N'
and pro_rata='N'
and nvl(daily_charge, 'N') = 'N';

update TBCIS.price_lists
set end_date = l_start_date-1, last_updated_by=sec.get_username, date_updated=sysdate
where sety_ref_num = 5802234
and nvl(trunc(end_date), l_start_date)+1 > trunc(l_start_date)
and regular_charge='Y'
and once_off='N'
and pro_rata='N'
and nvl(daily_charge, 'N') = 'N';

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
   sysdate DATE_CREATED, sec.get_username CREATED_BY, null DATE_UPDATED, 
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
and end_date = l_start_date-1
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and nvl(daily_charge, 'N') = 'N'
) 
and nvl(trunc(end_date), l_start_date)+1 > trunc(l_start_date)
and for_sety_ref_num = 5802234
and call_type = 'REGU'
)
where rn=1;

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
   sec.get_username CREATED_BY,
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
and end_date = l_start_date-1
) OR sety_ref_num = 5802234)
and regular_charge='Y'
and once_off='N'
   and nvl(daily_charge, 'N') = 'N'
) 
and nvl(trunc(end_date), l_start_date)+1 > trunc(l_start_date)
and call_type = 'REGU'
)
and padi_ref_num in
(
select ref_num from party_discounts
where nvl(trunc(end_date), l_start_date)+1 > trunc(l_start_date)
);

delete from TBCIS.FIXED_CHARGE_VALUES
where end_date < start_date
and start_date = l_start_date;

delete from TBCIS.PRICE_LISTS
where end_date < start_date
and start_date = l_start_date;

update TBCIS.FIXED_CHARGE_ITEM_TYPES fcit
set sety_ref_num = null 
where sety_ref_num = 5802234
and regular_charge='Y'
and once_off='N'
and nvl(daily_charge, 'N') = 'N';


commit;
   EXCEPTION
     WHEN OTHERS THEN
       ROLLBACK;
END DAILY_CHARGES_SETUP;
/