select * from fixed_charge_types

select * from price_lists
where fcty_type_code = 'DCH'

emt_pricelist

main_monthly_charges


daily_charges_setup

select process_daily_charges.main_query('N') from dual

select * from daily_charges_descr_temp


where susg = 13491059

select * from daily_charges_inen_temp
where susg_ref_num = 13491059


begin
    process_daily_charges.calculate_daily_charges(date '2018-12-01', date '2018-12-31');
end;     


daily_charges_setup


select * from fixed_charge_types


select * from fixed_charge_item_types
where type_code like 'GG%'


select * from iemt_bill_price_list
where sety_ref_num = 5802234
order by 1,11,4

drop table iemt_bill_price_list2 purge

create table iemt_bill_price_list2 as 
select * from iemt_bill_price_list

truncate table iemt_bill_price_list

SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM iEMT_BILL_PRICE_LIST20
intersect
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.iEMT_BILL_PRICE_LIST21

SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.iEMT_BILL_PRICE_LIST2
minus
(
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.iEMT_BILL_PRICE_LIST20
union
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.iEMT_BILL_PRICE_LIST21
)

(
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.iEMT_BILL_PRICE_LIST20
union
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.iEMT_BILL_PRICE_LIST21
)
minus
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST2

select * from iemt_bill_price_list2
where fcit_type_code = 'YSW'
and sept_type_code = 'HI10'
and sety_ref_num = 6920081

select * from fixed_charge_values
where fcit_charge_code = 'YSW'

select * from price_lists
where sety_ref_num = 6920081


 


SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.iEMT_BILL_PRICE_LIST2
  where sety_ref_num = 5802234
minus
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.EMT_BILL_PRICE_LIST
  where sety_ref_num = 5802234

SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.EMT_BILL_PRICE_LIST
  where sety_ref_num = 5802234
minus
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       
       trunc(DATE_CREATED, 'MM') dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST2
  where sety_ref_num = 5802234


SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST
  --where sety_ref_num = 5802234
minus
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED)+2 dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST2
  --where sety_ref_num = 5802234
  
RCH	Mobiili teenused	Erihind	GGW	S	KTO		VMIN	5802234	2021	6705	12/1/2018	1/1/2019		Y	TBCIS	1/23/2019		5	EUR			
RCH	Mobiili teenused	Põhihind	GGW	S	KTO		VMIN	5802234	2021	6705	1/1/2019			Y	TBCIS	1/23/2019		14.13	EUR			


SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED)+2 dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST2
  --where sety_ref_num = 5802234
minus
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       END_DATE,       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST
  --where sety_ref_num = 5802234
  
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       
       case when (fcty_type = 'RCH' and (fcit_type_code like 'GG%' OR fcit_type_code = 'GMT') and end_date >= date '2018-12-31') then CAST(null as date) else end_date end END_DATE,       
       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST1
  --where sety_ref_num = 5802234
minus
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       
       case when (fcty_type = 'RCH' and (fcit_type_code like 'GG%' OR fcit_type_code = 'GMT') and end_date >= date '2018-12-31') then CAST(null as date) else end_date end END_DATE,       
       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST2
  --where sety_ref_num = 5802234
  

SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       
       case when (fcty_type = 'RCH' and (fcit_type_code like 'GG%' OR fcit_type_code = 'GMT') and end_date >= date '2018-12-31') then CAST(null as date) else end_date end END_DATE,       
       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST2
  where sety_ref_num = 5802234
minus
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       
       case when (fcty_type = 'RCH' and (fcit_type_code like 'GG%' OR fcit_type_code = 'GMT') and end_date >= date '2018-12-31') then CAST(null as date) else end_date end END_DATE,       
       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc ,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST1
  where sety_ref_num = 5802234

select *  FROM TBCIS.IEMT_BILL_PRICE_LIST1
where 1=1
and fcit_type_code in ('GMT')
and sept_type_code = 'SIMT'
and sepv_ref_num = 13675
union all
select *  FROM TBCIS.IEMT_BILL_PRICE_LIST2
where 1=1
and fcit_type_code in ('GMT')
and sept_type_code = 'SIMT'
and sepv_ref_num = 13675


SELECT case when (sety_ref_num = 5802234 and nvl(end_date, :1)+1 > :1)  then 'DCH' else fcty_type end FCTY_TYPE,       WHAT,       LIST_TYPE,       
case when (sety_ref_num = 5802234 and nvl(end_date, :1)+1 > :1) then decode(fcit_type_code, 'GMT', 'CG1', 'C'||substr(fcit_type_code, 2,2)) else fcit_type_code end FCIT_TYPE_CODE,       
TATY_TYPE_CODE,       BILLING_SELECTOR,       
SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,      
       case when (sety_ref_num = 5802234 and nvl(end_date, :1)+1 > :1) then :1 else start_date end START_DATE,       END_DATE,    CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST2
 -- where not(start_date >= date '2019-01-01' and nvl(sety_ref_num,1) = 5802234)
  --where sety_ref_num = 5802234
minus
SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       
       END_DATE,       
       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST1
  --where sety_ref_num = 5802234
  

SELECT FCTY_TYPE,       WHAT,       LIST_TYPE,       FCIT_TYPE_CODE,       TATY_TYPE_CODE,       BILLING_SELECTOR,       SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,       
       END_DATE,       
       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST1
  where 1=1
and not(nvl(end_date, :1) < :1 and nvl(sety_ref_num, 1) = 5802234 and fcty_type='RCH')
  --where sety_ref_num = 5802234
minus
SELECT case when (sety_ref_num = 5802234 and nvl(end_date, :1)+1 > :1)  then 'DCH' else fcty_type end FCTY_TYPE,       WHAT,       LIST_TYPE,       
case when (sety_ref_num = 5802234 and nvl(end_date, :1)+1 > :1) then decode(fcit_type_code, 'GMT', 'CG1', 'C'||substr(fcit_type_code, 2,2)) else fcit_type_code end FCIT_TYPE_CODE,       
TATY_TYPE_CODE,       BILLING_SELECTOR,       
SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,      
       case when (sety_ref_num = 5802234 and nvl(end_date, :1)+1 > :1) then :1 else start_date end START_DATE,       END_DATE,    CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE
  FROM TBCIS.IEMT_BILL_PRICE_LIST2
  --where not(start_date >= date '2019-01-01' and nvl(sety_ref_num,1) = 5802234)
  --where sety_ref_num = 5802234
  
  select * from TBCIS.IEMT_BILL_PRICE_LIST10
  where sety_ref_num = 5802234
  
SELECT FCTY_TYPE,   fcty_type fcty_type2, WHAT,  LIST_TYPE,   FCIT_TYPE_CODE, FCIT_TYPE_CODE FCIT_TYPE_CODE2,  TATY_TYPE_CODE,  BILLING_SELECTOR,  SEC_CHARGE_VALUE,  SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,       START_DATE,  start_date s2,     
       END_DATE, end_date e2,      
       CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE, '10' x
  FROM TBCIS.IEMT_BILL_PRICE_LIST10
where 1=1
and not(nvl(end_date, :1) < :1 and nvl(sety_ref_num, 1) = 5802234 and fcty_type='RCH')
and fcit_type_code in ('CGA', 'GGA')
and sept_type_code = 'DEMT'
and sepv_ref_num = 4505
--and sety_ref_num = 8937255
union all
SELECT case when (sety_ref_num = 5802234 and nvl(end_date, :1)+1 > :1)  then 'DCH' else fcty_type end FCTY_TYPE, fcty_type fcty_type2,       WHAT,       LIST_TYPE,       
case when (sety_ref_num = 5802234 and nvl(end_date, :1)+1 > :1) then decode(fcit_type_code, 'GMT', 'CG1', 'C'||substr(fcit_type_code, 2,2)) else fcit_type_code end FCIT_TYPE_CODE, 
FCIT_TYPE_CODE FCIT_TYPE_CODE2,       
TATY_TYPE_CODE,       BILLING_SELECTOR,       
SEC_CHARGE_VALUE,       SEPT_TYPE_CODE,
       SETY_REF_NUM,       SEPA_REF_NUM,       SEPV_REF_NUM,      
       case when (sety_ref_num = 5802234 and nvl(end_date, :1)+1 > :1) then :1 else start_date end START_DATE, start_date s2,  
       END_DATE,    end_date e2,   CHCA_TYPE_CODE,       CHARGEABLE,       CREATED_BY,
       trunc(DATE_CREATED) dc,       SEC_CURR_CODE,       CHARGE_VALUE,       CURR_CODE,       KEY_SETY_REF_NUM,       SEC_KEY_CHARGE_VALUE,       KEY_CHARGE_VALUE, '20' x
  FROM TBCIS.IEMT_BILL_PRICE_LIST20
  where 1=1
and fcit_type_code in ('CGA', 'GGA')
and sept_type_code = 'DEMT'
and sepv_ref_num = 4505
--and sety_ref_num = 8937255

select t2.*, '20' x 
from TBCIS.IEMT_BILL_PRICE_LIST20 t2
where fcit_type_code in ('CGA', 'GGA')
and sept_type_code = 'DIPH'
and sepv_ref_num = 9289
union all
select t1.*, '10' x 
from TBCIS.IEMT_BILL_PRICE_LIST10 t1
where fcit_type_code in ('CGA', 'GGA')
and sept_type_code = 'DIPH'
and sepv_ref_num = 9289
  
select t1.*, '10' x 
from TBCIS.IEMT_BILL_PRICE_LIST t1
where fcit_type_code in ('CGA', 'GGA')
and sept_type_code = 'DIKA'
and sepv_ref_num = 2523

delete from TBCIS.IEMT_BILL_PRICE_LIST;

insert into iemt_bill_price_list11
select * from iemt_bill_price_list

create table iemt_bill_price_list1 as 
select * from iemt_bill_price_list

temp_emt_hinnakiri

begin
iemt_pricelist2.start_ebpl_mch_rch;
end;

begin
itemp_emt_hinnakiri;
end;

begin
itemp_emt_hinnakiri2;
end;

select * from ifcit1

select * from iprli1

select * from ificv1

select * from ificv0
where fcit_charge_code in ('GGA', 'CGA')
and sept_type_code = 'DIKA'
and sepv_ref_num = 2523
union all
select * from ificv1
where fcit_charge_code in ('GGA', 'CGA')
and sept_type_code = 'DIKA'
and sepv_ref_num = 2523

select * from iprli0
where 1=1
and sety_ref_num = 5802234
and sepv_ref_num = 2523
and once_off='N'
and regular_charge='Y'
and ((pro_rata='N' and daily_charge='N') OR nvl(daily_charge, 'N')='Y')
union all
select * from iprli1
where 1=1
and sety_ref_num = 5802234
and sepv_ref_num = 2523
and once_off='N'
and regular_charge='Y'
and ((pro_rata='N' and daily_charge='N') OR nvl(daily_charge, 'N')='Y')



delete from iemt_bill_price_list2;
insert into iemt_bill_price_list2
select * from iemt_bill_price_list;  
delete from iemt_bill_price_list;

delete from ificv1;
delete from iprli1;
delete from ifcit1;
insert into ificv1
select * from ificv0;
insert into iprli1
select * from iprli0;
insert into ifcit1
select * from ifcit0;

delete from ificv2;
delete from iprli2;
delete from ifcit2;
insert into ificv2
select * from ificv1;
insert into iprli2
select * from iprli1;
insert into ifcit2
select * from ifcit1;

create table ificv2 as
select * from ificv1;
create table iprli2 as
select * from iprli1;
create table ifcit2 as
select * from ifcit1;

delete from ificv1;
delete from iprli1;
delete from ifcit1;
insert into ificv1
select * from ificv2
where 1=1
--and sepv_ref_num = 2523
and fcit_charge_code in ('GGA', 'CGA');
insert into iprli1
select * from iprli2
where 1=1
and sety_ref_num = 5802234
and sepv_ref_num = 2523
and once_off='N'
and regular_charge='Y'
and ((pro_rata='N' and daily_charge='N') OR nvl(daily_charge, 'N')='Y');
insert into ifcit1
select * from ifcit2
where type_code in ('GGA', 'CGA');



select * from (
select count(*) over (partition by FCTY_TYPE, WHAT, LIST_TYPE, FCIT_TYPE_CODE, TATY_TYPE_CODE,BILLING_SELECTOR, SEC_CHARGE_VALUE, SEPT_TYPE_CODE,SETY_REF_NUM, SEPA_REF_NUM, SEPV_REF_NUM) c, 
x.* from (
select a1.*, '1' x from iemt_bill_price_list a1
where sety_ref_num = 5802234
union all
select a2.*, '2' x from iemt_bill_price_list2 a2
where sety_ref_num = 5802234
) x
)
order by  2, 5, 9, 12, x

select count(*) over (partition by FCTY_TYPE, WHAT, LIST_TYPE, FCIT_TYPE_CODE, TATY_TYPE_CODE,BILLING_SELECTOR, SEC_CHARGE_VALUE, SEPT_TYPE_CODE,SETY_REF_NUM, SEPA_REF_NUM, SEPV_REF_NUM) c, 
x.* from (
select a1.*, '1' x from emt_bill_price_list a1
where sety_ref_num = 5802234
union all
select a2.*, '2' x from iemt_bill_price_list2 a2
where sety_ref_num = 5802234
) x
order by  2, 5, 9, 12, x

select * from iemt_bill_price_list2
where fcit_type_code in ('GGW', 'CGW')
and sept_type_code = 'HF10'
and sepv_ref_num = 9273

select * from iemt_bill_price_list2
where fcit_type_code in ('GGW', 'CGW')
and sept_type_code = 'AK04'
and sepv_ref_num = 7907

select * from iemt_bill_price_list
where fcit_type_code in ('GGA')
and sept_type_code = 'VMIN'
and sepv_ref_num = 6705

select * from fixed_charge_values
where fcit_charge_code = 'GGW'
and sepv_ref_num = 6705

select * from ificv1
where fcit_charge_code = 'GGW'
and sepv_ref_num = 6705

select * from iemt_bill_price_list


GGW AK04 7907

GGA IATG 5325

GGW HF10 9273


create table fcit1 as 
select * from fixed_charge_item_types

create table ficv1 as
select * from fixed_charge_values

create table prli1 as
select * from price_lists




select count(*) over (partition by type_code) c, q1.* from (
select f0.*, '0' x from fcit0 f0
union all
select f1.*, '1' from fcit1 f1
) q1
order by 2

select count(*) over (partition by ref_num) c, q1.* from (
select f0.*, '0' x from ficv0 f0
union all
select f1.*, '1' from ficv1 f1
) q1
order by 2

select count(*) over (partition by ref_num) c, q1.* from (
select f0.*, '0' x from prli0 f0
union all
select f1.*, '1' from prli1 f1
) q1
order by 2

delete from price_lists;
insert into price_lists
select * from prli0;

delete from fixed_charge_values;
insert into fixed_charge_values
select * from ficv0;

alter table fcit0 rename to ifcit0
alter table fcit1 rename to ifcit1
alter table ficv0 rename to ificv0
alter table ficv1 rename to ificv1
alter table prli0 rename to iprli0
alter table prli1 rename to iprli1

create table iemt_bill_price_list20 as 
select * from iemt_bill_price_list

delete from iemt_bill_price_list

create table iemt_bill_price_list21 as 
select * from iemt_bill_price_list

create table iemt_bill_price_list10 as 
select * from iemt_bill_price_list

create table iemt_bill_price_list11 as 
select * from iemt_bill_price_list

create table iemt_bill_price_list1 as 
select * from iemt_bill_price_list

select * from fixed_charge_item_types
minus 
select * from fcit0

select * from fcit0
minus
select * from fixed_charge_item_types
 


MERGE INTO TBCIS.FIXED_CHARGE_ITEM_TYPES d
USING (
  Select * from fcit0
) s
ON
  (d.TYPE_CODE = s.TYPE_CODE )
WHEN MATCHED
THEN
UPDATE SET
  d.DESCRIPTION = s.DESCRIPTION,
  d.ONCE_OFF = s.ONCE_OFF,
  d.TATY_TYPE_CODE = s.TATY_TYPE_CODE,
  d.CREATED_BY = s.CREATED_BY,
  d.DATE_CREATED = s.DATE_CREATED,
  d.PRO_RATA = s.PRO_RATA,
  d.BILLING_SELECTOR = s.BILLING_SELECTOR,
  d.FUTURE_PERIOD = s.FUTURE_PERIOD,
  d.LAST_UPDATED_BY = s.LAST_UPDATED_BY,
  d.DATE_UPDATED = s.DATE_UPDATED,
  d.REGULAR_CHARGE = s.REGULAR_CHARGE,
  d.PACKAGE_CATEGORY = s.PACKAGE_CATEGORY,
  d.NOTES = s.NOTES,
  d.ARCHIVE = s.ARCHIVE,
  d.SETY_REF_NUM = s.SETY_REF_NUM,
  d.PRLI_PACKAGE_CATEGORY = s.PRLI_PACKAGE_CATEGORY,
  d.PREV_FCIT_TYPE_CODE = s.PREV_FCIT_TYPE_CODE,
  d.FCDT_TYPE_CODE = s.FCDT_TYPE_CODE,
  d.VALID_CHARGE_PARAMETER = s.VALID_CHARGE_PARAMETER,
  d.FIRST_PRORATED_CHARGE = s.FIRST_PRORATED_CHARGE,
  d.BILL_FCIT_TYPE_CODE = s.BILL_FCIT_TYPE_CODE,
  d.REGULAR_TYPE = s.REGULAR_TYPE,
  d.SETY_FIRST_PRORATED = s.SETY_FIRST_PRORATED,
  d.FREE_PERIODS = s.FREE_PERIODS,
  d.LAST_PRORATED_CHARGE = s.LAST_PRORATED_CHARGE,
  d.DAILY_CHARGE = s.DAILY_CHARGE
WHEN NOT MATCHED
THEN
INSERT (
  TYPE_CODE, DESCRIPTION, ONCE_OFF,
  TATY_TYPE_CODE, CREATED_BY, DATE_CREATED,
  PRO_RATA, BILLING_SELECTOR, FUTURE_PERIOD,
  LAST_UPDATED_BY, DATE_UPDATED, REGULAR_CHARGE,
  PACKAGE_CATEGORY, NOTES, ARCHIVE,
  SETY_REF_NUM, PRLI_PACKAGE_CATEGORY, PREV_FCIT_TYPE_CODE,
  FCDT_TYPE_CODE, VALID_CHARGE_PARAMETER, FIRST_PRORATED_CHARGE,
  BILL_FCIT_TYPE_CODE, REGULAR_TYPE, SETY_FIRST_PRORATED,
  FREE_PERIODS, LAST_PRORATED_CHARGE, DAILY_CHARGE)
VALUES (
  s.TYPE_CODE, s.DESCRIPTION, s.ONCE_OFF,
  s.TATY_TYPE_CODE, s.CREATED_BY, s.DATE_CREATED,
  s.PRO_RATA, s.BILLING_SELECTOR, s.FUTURE_PERIOD,
  s.LAST_UPDATED_BY, s.DATE_UPDATED, s.REGULAR_CHARGE,
  s.PACKAGE_CATEGORY, s.NOTES, s.ARCHIVE,
  s.SETY_REF_NUM, s.PRLI_PACKAGE_CATEGORY, s.PREV_FCIT_TYPE_CODE,
  s.FCDT_TYPE_CODE, s.VALID_CHARGE_PARAMETER, s.FIRST_PRORATED_CHARGE,
  s.BILL_FCIT_TYPE_CODE, s.REGULAR_TYPE, s.SETY_FIRST_PRORATED,
  s.FREE_PERIODS, s.LAST_PRORATED_CHARGE, s.DAILY_CHARGE);

update prli1
set daily_charge = 'Y'
where fcty_type_code = 'DCH'

where type_code in ('GGW', 'CGW')

select * from fixed_charge_values
where fcit_charge_code in ('GGW', 'CGW')
and sept_type_code = 'HF10'
and sepv_ref_num = 9273

select * from fixed_charge_values
where fcit_charge_code in ('GGW', 'CGW')
and sept_type_code = 'AK04'
and sepv_ref_num = 7907

select * from fixed_charge_values
where fcit_charge_code in ('GGW', 'CGW')
and sept_type_code = 'AK65'
and sepv_ref_num = 9274

select * from fixed_charge_values
where fcit_charge_code in ('GGA')
and sept_type_code = 'DI30'
and sepv_ref_num = 2523

select * from price_lists
where sepv_ref_num = 2523
and fcty_type_code = 'RCH'

select * from fixed_charge_values
where end_date < start_date
and start_date = :l_start_date


select * from fixed_charge_values
where fcit_charge_code in ('GGA')
and sept_type_code = 'DEMT'
and sepv_ref_num = 2523

select * from price_lists


select * from fixed_charge_item_types
where type_code = 'GGA';

update fixed_charge_item_types
set sety_ref_num=5802234
where type_code = 'GGA';

select * 
from price_lists
where sety_ref_num = 5802234
and regular_charge='Y'
and once_off='N'
and daily_charge = 'Y';

select * 
from price_lists
where sety_ref_num = 5802234
and sepv_ref_num = 13812

delete 
from price_lists
where sety_ref_num = 5802234
and regular_charge='Y'
and once_off='N'
and daily_charge = 'Y';

begin
iemt_pricelist2.start_ebpl_mch_rch;
end;

begin
itemp_emt_hinnakiri;
end;


FCTY_TYPE	WHAT	LIST_TYPE	FCIT_TYPE_CODE	TATY_TYPE_CODE	BILLING_SELECTOR	SEC_CHARGE_VALUE	SEPT_TYPE_CODE	SETY_REF_NUM	SEPA_REF_NUM	SEPV_REF_NUM	START_DATE	END_DATE	CHCA_TYPE_CODE	CHARGEABLE	CREATED_BY	DATE_CREATED	SEC_CURR_CODE	CHARGE_VALUE	CURR_CODE	KEY_SETY_REF_NUM	SEC_KEY_CHARGE_VALUE	KEY_CHARGE_VALUE
RCH	Mobiili teenused	Põhihind	GGB	S	KTO		SIMB	5802234	2021	2524	12/1/2018			Y	TBCIS	1/22/2019 3:13:09 PM		24.37	EUR			
RCH	Mobiili teenused	Põhihind	GGB	S	KTO		BPLS	5802234	2021	2524	12/1/2018			Y	TBCIS	1/22/2019 3:13:11 PM		24.37	EUR			
RCH	Mobiili teenused	Põhihind	GGB	S	KTO		MAA1	5802234	2021	2524	12/1/2018			Y	TBCIS	1/22/2019 3:13:14 PM		24.37	EUR			
RCH	Mobiili teenused	Põhihind	GGB	S	KTO		BART	5802234	2021	2524	12/1/2018			Y	TBCIS	1/22/2019 3:13:13 PM		24.37	EUR			
RCH	Mobiili teenused	Põhihind	GGB	S	KTO		BARS	5802234	2021	2524	12/1/2018			Y	TBCIS	1/22/2019 3:13:12 PM		24.37	EUR			


select * from fixed_charge_item_types
where type_code = 'GGB'

select * from fixed_charge_values
where sety_ref_num = 5802234
and fcit_charge_code = 'GGB'
and sepv_ref_num = 2524


 


