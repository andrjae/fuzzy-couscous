CREATE OR REPLACE PACKAGE TBCIS.Main_Monthly_Batch IS
/********************************************************
**
**  Module Name : main_monthly_batch     (BCCU1527)
**  Date Created: 20.04.2016
**  Description : stardib kuumaksude protsessid
**
**
*********************************************************


Change History
   Date       Person     Description
   ---------- -------- ----------------------------------------------------------
   20.04.2016 V.Tänover V 1.0  ARVO-442: Initial version. Kuulmaksude protsessid.
   05.02.2018 A.Jaek    V 1.1  DOBAS-1721: Added DCH cycle



*/

FUNCTION chk_batch_mes(p_module  VARCHAR2) RETURN BOOLEAN;
FUNCTION chk_batch_err(p_module  VARCHAR2) RETURN BOOLEAN;
FUNCTION chk_protspar(p_module VARCHAR2,p_param VARCHAR2) RETURN BOOLEAN;
FUNCTION chk_prots(p_module VARCHAR2) RETURN BOOLEAN;
FUNCTION chk_all_prots(p_module VARCHAR2) RETURN BOOLEAN;
FUNCTION chk_protsstarted(p_module VARCHAR2,p_param VARCHAR2) RETURN BOOLEAN;
PROCEDURE dbsms(p_reason IN varchar2,p_text IN VARCHAR2);
PROCEDURE start_cycle (p_cycle IN VARCHAR2);
PROCEDURE start_NKKE_cycle (p_cycle IN VARCHAR2);
PROCEDURE start_DCH_cycle (p_cycle IN VARCHAR2 DEFAULT NULL);
PROCEDURE start_KE;
PROCEDURE start_NKKE;

PROCEDURE start_monthly_charges;

END main_monthly_batch;
/


CREATE OR REPLACE PACKAGE BODY TBCIS.main_monthly_batch IS
-----

FUNCTION chk_batch_mes(p_module  VARCHAR2) RETURN BOOLEAN IS
CURSOR c_mess IS
 SELECT message_text FROM bcc_batch_messages WHERE module_ref=p_module
 and message_date > (sysdate-0.001)
 ORDER BY mesg_num DESC;
 l_result BOOLEAN;
BEGIN
l_result := FALSE;
FOR rec IN c_mess LOOP
IF rec.message_text LIKE '%rollback segment%' THEN
  DBMS_OUTPUT.PUT_LINE('Rollback Problem !  '||rec.message_text);
  tbcis.send_dba_sms('Snapshot error on '||p_module,'BILL');
  l_result := TRUE;
END IF;
END LOOP;
RETURN l_result;
END chk_batch_mes;
-------------------------------------------------------------
-- leia veatüüp on selline , mille puhul võib protsessi korrata (rollback error)
FUNCTION chk_batch_err(p_module  VARCHAR2) RETURN BOOLEAN IS
CURSOR c_mess IS
 SELECT message_text FROM bcc_batch_messages WHERE module_ref=p_module
 and MODULE_DESC='Check Mobile Non KER Service Fees'
 and message_date > (sysdate-0.001)
 ORDER BY mesg_num DESC;
BEGIN
FOR rec IN c_mess LOOP
IF rec.message_text LIKE '%rollback segment%' 
OR SUBSTR(rec.message_text,1,9) IN ('ORA-30036','ORA-01652','ORA-12801') 
OR TRIM(rec.message_text) = 'ORA-00001: unique constraint (TBCIS.INVO_UK1) violated'
THEN
  DBMS_OUTPUT.PUT_LINE('Batch error !  '||rec.message_text);
  tbcis.send_dba_sms('Batch error on '||p_module,'MONTHCHG');
  RETURN TRUE;
ELSE
RETURN FALSE;
END IF;
END LOOP;
RETURN FALSE;
END chk_batch_err;
-------------------------------------------------------------
-- kas protsess on lõppenud edukalt
FUNCTION chk_protspar(p_module VARCHAR2,p_param VARCHAR2) RETURN BOOLEAN IS
CURSOR c_proc (p_module VARCHAR2,p_param VARCHAR2) IS
    SELECT end_code FROM tbcis.tbcis_processes
    WHERE MODULE_REF=p_module AND module_params=p_param
    AND START_DATE IS NOT NULL AND START_DATE >= tbcis.set_bill_allow_date
    AND END_CODE='OK';
l_avail VARCHAR2(15);
BEGIN
OPEN c_proc(p_module,p_param);
FETCH c_proc INTO l_avail;
IF c_proc%FOUND THEN   --  OK
CLOSE c_proc;
RETURN TRUE;
ELSE
CLOSE c_proc;
RETURN FALSE;
END IF;
END chk_protspar;
-------------------------------------------------------------
FUNCTION chk_prots(p_module VARCHAR2) RETURN BOOLEAN IS
CURSOR c_proc (p_module VARCHAR2) IS
    SELECT end_code FROM tbcis.tbcis_processes
    WHERE MODULE_REF=p_module 
    AND START_DATE IS NOT NULL AND START_DATE >= tbcis.set_bill_allow_date
    AND END_CODE='OK';
l_avail VARCHAR2(15);
BEGIN
OPEN c_proc(p_module);
FETCH c_proc INTO l_avail;
IF c_proc%FOUND THEN   --  OK
CLOSE c_proc;
RETURN TRUE;
ELSE
CLOSE c_proc;
RETURN FALSE;
END IF;
END chk_prots;
-------------------------------------------------------------
-- kas protsess on juba käinud
FUNCTION chk_protsstarted(p_module VARCHAR2,p_param VARCHAR2) RETURN BOOLEAN IS
CURSOR c_proc (p_module VARCHAR2,p_param VARCHAR2) IS
    SELECT end_code FROM tbcis.tbcis_processes
    WHERE MODULE_REF=p_module AND module_params=NVL(p_param,module_params)
    AND START_DATE IS NOT NULL AND START_DATE >= tbcis.set_bill_allow_date;
l_avail VARCHAR2(15);
BEGIN
OPEN c_proc(p_module,p_param);
FETCH c_proc INTO l_avail;
IF c_proc%FOUND THEN   --  OK
CLOSE c_proc;
RETURN TRUE;
ELSE
CLOSE c_proc;
RETURN FALSE;
END IF;
END chk_protsstarted;
----------------------------------------------------------------------
-- kas protsess on luppenud edukalt
FUNCTION chk_all_prots(p_module VARCHAR2) RETURN BOOLEAN IS

CURSOR c_proc (p_module VARCHAR2) IS
    SELECT end_code FROM tbcis.tbcis_processes
    WHERE MODULE_REF=p_module
    AND (START_DATE IS NOT NULL AND START_DATE < tbcis.set_bill_allow_date
        OR (START_DATE >= tbcis.set_bill_allow_date   
    AND nvl(END_CODE,'ERR')<>'OK'));
    
l_avail VARCHAR2(15);

BEGIN

OPEN c_proc(p_module);
FETCH c_proc INTO l_avail;
IF c_proc%FOUND THEN   --  OK
CLOSE c_proc;
RETURN FALSE;
ELSE
CLOSE c_proc;
RETURN TRUE;
END IF;

END chk_all_prots;
----------------------------------------------------------------------
procedure dbsms (p_reason IN varchar2,p_text IN VARCHAR2) IS

Cursor c_mob is
select * from bcc_domain_values
where doma_type_code='DBSM'
and text1=p_reason
and nvl(arhive,'N')='N'
;

begin

for r in c_mob loop

if r.text2='SMS' then
Send_Sms(r.text_value, p_text, '159', 'ISE',   NULL,null,null, null);
end if;

IF r.text2='MAIL' then
Send_Mail(r.text_value,p_text,r.text1);
end if;

end loop;
commit;
end dbsms;


----------------------------------------------------------------------

-- kuumaksude ühe tsükli käivitus
PROCEDURE start_cycle (p_cycle VARCHAR2) IS
l_run BOOLEAN;
BEGIN
l_run := TRUE;
WHILE l_run LOOP 
Main_Monthly_Charges.Start_Monthly_Charges(p_cycle,0,9999999999,'Y'); 
l_run := chk_batch_mes('BCCU848');
END LOOP;
END start_cycle;

-------------------------------------------------------------
-- BCCU1284NK käivitus
PROCEDURE start_NKKE_cycle (p_cycle VARCHAR2) IS
l_run BOOLEAN;
BEGIN
l_run := TRUE;
WHILE l_run LOOP 
-- kordamisel  param (CONTINUE);
IF chk_protsstarted('BCCU1284NK',p_cycle) = TRUE THEN
TBCIS.Process_Monthly_Service_Fees.Proc_Mob_NonKER_Service_Fees(p_cycle,'CONTINUE');
ELSE
TBCIS.Process_Monthly_Service_Fees.Proc_Mob_NonKER_Service_Fees(p_cycle);
END IF;
IF chk_protspar('BCCU1284NK',p_cycle) = TRUE THEN
l_run := FALSE;
ELSE
l_run := chk_batch_err('BCCU1284NK');
END IF;
END LOOP;
END start_NKKE_cycle;

-------------------------------------------------------------
-- BCCU1545 käivitus
PROCEDURE start_DCH_cycle (p_cycle VARCHAR2 DEFAULT NULL) IS
l_run BOOLEAN;
l_cycle VARCHAR2(10);
BEGIN
l_run := TRUE;
l_cycle := nvl(p_cycle, 'ALL');
WHILE l_run LOOP 
-- kordamisel  param (CONTINUE);
IF chk_protsstarted('BCCU1545',l_cycle) = TRUE THEN
    IF p_cycle is not null then
        TBCIS.Process_Daily_Charges.proc_daily_charges(p_cycle,'RECALC');
    ELSE
        l_run := FALSE;
    END IF;
ELSE
    TBCIS.Process_Daily_Charges.proc_daily_charges(p_cycle);
END IF;
IF chk_protspar('BCCU1545',l_cycle) = TRUE THEN
    l_run := FALSE;
END IF;
END LOOP;
END start_DCH_cycle;
-------------------------------------------------------------
PROCEDURE start_KE IS
BEGIN 
-- Enne peaksid valmis olema BCCU1284NK ( regu tüüpi teenused)- start_NKKE
-- kordamisel  param (CONTINUE);
IF chk_protsstarted('BCCU1284KE',NULL) = TRUE THEN
--BCCU1284KE
TBCIS.Process_Monthly_Service_Fees.Chk_Mobile_KER_Service_Fees('CONTINUE');
ELSE
TBCIS.Process_Monthly_Service_Fees.Chk_Mobile_KER_Service_Fees;
END IF;

IF chk_protsstarted('BCCU1284',NULL) = TRUE THEN
--BCCU1284
TBCIS.Process_Monthly_Service_Fees.Chk_Master_Service_Fees('CONTINUE');
ELSE
TBCIS.Process_Monthly_Service_Fees.Chk_Master_Service_Fees;
END IF;

IF chk_prots('BCCU1284NK') = TRUE THEN
--Reg tüüpi makseid peab ootama---------------------------------------------
--BCCU1473PF:
tbcis.Process_Mixed_Packet_Fees.Start_Mixed_Product_Fees;
 IF chk_prots('BCCU1473PF') = TRUE THEN
 --BCCU1473SF:
 tbcis.Process_Mixed_Packet_Fees.Start_Mixed_Solution_Fees;
  IF chk_prots('BCCU1473SF') = TRUE THEN
  --BCCU1473VK
  tbcis.PROCESS_MIXED_PACKET_FEES.Calc_Mix_Intermediate_Balance;
  
dbsms('MIX','Mixed müük valmis');
  
  END IF;
 END IF;
END IF;
--BCCU848RP (AMP paketi 0 kuutasud):
TBCIS.Main_Monthly_Charges.START_REGTYPE_PACKAGE_FEES;

IF chk_prots('BCCU1284NK') = FALSE OR chk_prots('BCCU1284KE') = FALSE OR chk_protspar('BCCU1284','MAAC') = FALSE THEN
--DBMS_OUTPUT.PUT_LINE('Can''t start , invoicing MonthServs not finished ! ('||TO_CHAR(l_arv)||')');

dbsms('ERROR','MonthServ_Error');

ELSE
--  DBMS_OUTPUT.PUT_LINE('MonthServ OK');
NULL;
END IF;

END start_KE;
-------------------------------------------------------------
-- BCCU1284NKKe kõigi tsüklite käivitus
PROCEDURE start_NKKE IS
l_run BOOLEAN;
BEGIN
--
DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1284NKKE_MN2',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_NKKE_cycle(''MN2'');',
start_date => CURRENT_DATE+1/288,
enabled=>true,auto_drop=>true);

DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1284NKKE_MN1',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_NKKE_cycle(''MN1'');',
start_date => CURRENT_DATE+2/288,
enabled=>true,auto_drop=>true);

DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1284NKKE_MNV',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_NKKE_cycle(''MNV'');',
start_date => CURRENT_DATE+3/288,
enabled=>true,auto_drop=>true);

DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1284NKKE_MNE',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_NKKE_cycle(''MNE'');',
start_date => CURRENT_DATE+4/288,
enabled=>true,auto_drop=>true);

DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1284NKKE_MN3',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_NKKE_cycle(''MN3'');',
start_date => CURRENT_DATE+5/288,
enabled=>true,auto_drop=>true);

DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1284NKKE_MN5',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_NKKE_cycle(''MN5'');',
start_date => CURRENT_DATE+6/288,
enabled=>true,auto_drop=>true);


DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1284NKKE_NB1',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_NKKE_cycle(''NB1'');',
start_date => CURRENT_DATE+7/288,
enabled=>true,auto_drop=>true);

DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1284NKKE_MN4',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_NKKE_cycle(''MN4'');',
start_date => CURRENT_DATE+8/288,
enabled=>true,auto_drop=>true);

DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1284NKKE_NB2',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_NKKE_cycle(''NB2'');',
start_date => CURRENT_DATE+9/288,
enabled=>true,auto_drop=>true);

l_run := TRUE;
WHILE l_run LOOP
 IF chk_all_prots('BCCU1284NK') = TRUE 
 THEN l_run := FALSE;
 ELSE l_run := TRUE;
 DBMS_LOCK.SLEEP(120);
 END IF;
END LOOP;




DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1284KE',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_KE;',
enabled=>true,auto_drop=>true);

dbsms('REGU','REGU valmis');

END start_NKKE;
-------------------------------------------------------------
-- kuumaksude käivitus
PROCEDURE start_monthly_charges IS
l_run BOOLEAN;
l_num_errors NUMBER := 0;
BEGIN
IF SYSDATE >= tbcis.set_bill_allow_date THEN

TBCIS.BREAK_DISCOUNT.BREAKS;
DBMS_SCHEDULER.CREATE_JOB (job_name => 'BCCU1545',job_type => 'PLSQL_BLOCK',
job_action => 'TBCIS.main_monthly_batch.start_DCH_cycle;',
start_date => CURRENT_DATE+1/288,
enabled=>true,auto_drop=>true);
l_run := TRUE;
WHILE l_run LOOP
 IF chk_all_prots('BCCU1545') = TRUE 
 THEN l_run := FALSE;
 ELSE l_run := TRUE;
 DBMS_LOCK.SLEEP(120);
 END IF;
END LOOP;

-- BCCU848 ja BCCU1284 NK KE

-- job-na , et paralleelselt käiks
DBMS_SCHEDULER.CREATE_JOB (
  job_name => 'MONTHCHG_MN4',
  job_type => 'PLSQL_BLOCK',
  job_action => 'TBCIS.main_monthly_batch.start_cycle(''MN4'');',
  enabled=>true,
  auto_drop=>true);

start_cycle('MN7');
start_cycle('MN9');

DBMS_SCHEDULER.CREATE_JOB (
  job_name => 'MONTHCHG_MN5',
  job_type => 'PLSQL_BLOCK',
  job_action => 'TBCIS.main_monthly_batch.start_cycle(''MN5'');',
  enabled=>true,
  auto_drop=>true);

start_cycle('MN6');
start_cycle('MN1');

DBMS_SCHEDULER.CREATE_JOB (
  job_name => 'NKKE',
  job_type => 'PLSQL_BLOCK',
  job_action => 'TBCIS.main_monthly_batch.start_NKKE;',
  enabled=>true,
  auto_drop=>true);



start_cycle('MN3');
start_cycle('NB1');
start_cycle('NB2');
start_cycle('NB6');
start_cycle('JH2');
start_cycle('NB8');
start_cycle('MN8');
start_cycle('NB7');
start_cycle('JH7');
start_cycle('MNV');
start_cycle('MNE');
start_cycle('STN');
start_cycle('TRV');

l_run := TRUE;
WHILE l_run LOOP
 IF chk_all_prots('BCCU848') = TRUE 
 THEN l_run := FALSE;
 ELSE l_run := TRUE;
 DBMS_LOCK.SLEEP(120);
 END IF;
END LOOP;

dbsms('MON','MON valmis');

--  BCCP1173 - discount_anaysis
TBCIS.CALL_DISCOUNTS_ANALYSIS;

--  BCCP1243
tbcis.MONTHLY_SUSG_FEES_ANALYSIS;

-- BCCU1089
l_run := TRUE;
WHILE l_run LOOP
 IF l_num_errors = 0 THEN
  tbcis.Partnership_Agreements_Billing.Start_Partnership_Bill ;
 ELSE
-- korduskaivitamine
  tbcis.Partnership_Agreements_Billing.Start_Partnership_Bill('CON');
 END IF;
l_run := chk_batch_mes('BCCU1089');
l_num_errors := l_num_errors + 1;
END LOOP;


-- BCCU1375
--tbcis.Process_Packet_Fees. Start_Packet_Fees;

-- BCCU1375VK
--tbcis.Process_Packet_Fees.Calculate_Intermediate_Balance;


-- vale tariifiklassiga tasuliste suunamiste hinna nullimine
tbcis.temp_suunamine_hind_0; 

END IF; -- SYSDATE >= tbcis.set_bill_allow_date

END start_monthly_charges;


END main_monthly_batch;
/