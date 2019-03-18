CREATE OR REPLACE PROCEDURE TBCIS.DAILY_CHARGES_SETUP2(p_start_date VARCHAR2) IS
   /*
   **  Module Name : DAILY_CHARGES_SETUP2
   **  Date Created:  17.01.2019
   **  Author      :  Andres Jaek
   **  Description :  Procedure creates new setup for daily charges starting from p_start_date (DD.MM.YYYY)
   **
   ** Change History.
   ** ----------------------------------------------------------------------
   ** Version Date         Modified by  Reason
   **
   **  1.0    17.01.2019   A.Jaek   DOBAS-1695    New
   **
   **----------------------------------------------------------------------------
   */
l_start_date DATE;
BEGIN
l_start_date := TO_DATE(p_start_date, 'DD.MM.YYYY');
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
and end_date = l_start_date-1
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
and end_date = l_start_date-1
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

commit;
   EXCEPTION
     WHEN OTHERS THEN
       ROLLBACK;
END DAILY_CHARGES_SETUP2;
/