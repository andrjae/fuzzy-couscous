CREATE OR REPLACE PACKAGE MAIN_MONTHLY_CHARGES AS
/********************************************************************
**
**  Module      :  BCCU848
**  Module Name : MAIN_MONTHLY_CHARGES
**  Date Created:  15.03.2002
**  Author      :  U.Aarna
**  Description :  This package contains procedures and functions used
**                 in creating Monthly Charges for Master Accounts
**                 of given Bill Cycle. Should be run before Main Bill.
**
** -------------------------------------------------------------
** Version Date        Modified by Reason
** -------------------------------------------------------------
**   1.0   15.03.2002  U.Aarna     UPR-2111: Initial version. Monthly Charges calculation
**                                           taken out from Main Bill.
**   1.1   14.05.2003  H.Luhasalu  UPR-2598: Täidetud tabel TBCIS_PROCESSES
**   1.2   09.06.2004  H.Luhasalu  Upr-3028: MA kursorisse võetud ainult perioodis aktiivsed MA'd
**   1.3   27.09.2004  U.Aarna     UPR-3124: Enne kontrollitakse, kas Masterile on jooksval kuul üldse tehtud vahearveid.
**                                           Kui pole, siis pole mõtet ka proovida kuumakse sealt tagasi võtta. Sama
**                                           parameeter (on/ei ole) antakse kaasa ka kuumaksude arvutusse.
**   1.4  28.10.2004   H.Luhasalu  UPR-3182  KAS MA kuumaksud arvutatud? Võtta ka pere kuumaks arvesse !
**   1.5  20.04.2005   U.Aarna     CHG-69    Lisatud päevade arvust sõltumatu (non-prorata) paketi kuutasu arvutus ette antud
**                                           arveldustsükli ja koondarvete jaoks. Uus protseduur Start_Package_Fees.
**   1.6  06.07.2005   U.Aarna     CHG-210   Enne kuumaksude arvutamist kontrollida, kas arveldustsüklile on kuumakse üldse
**                                           vaja arvutada (bill_cycles.calculate_monthly_charges).
**   1.7  16.11.2005   U.Aarna     CHG-464   Teenuse kuumaksude arvutus mälutabelitesse loetud hinnakirja alusel.
**                                           Protseduuri Start_Monthly_Charges lisatud mälutabelite haldus.
**   1.8  04.07.2006   U.Aarna     CHG-1044  Täiendatud kuutasude arvel olemasolu kontrolli protseduuris Chk_Monthly_Charges_Exist.
**                                           Teenusele YK (pere kuutasu) lisandunud ka teenus PK (perepakett).
**   1.9  03.07.2007   S.Sokk      CHG-2110: Replaced USER with sec.get_username
**   1.10 14.08.2008   A.Soo       CHG-3180: Chk_Monthly_Charges_Exist - kursorist välja kommenteeritud 'prorata = 'y' '
**   1.10 14.08.2008   A.Soo       CHG-3180: Chk_Monthly_Charges_Exist - kursorist välja kommenteeritud 'prorata = 'y' '
**   1.11 22.08.2008   A.Soo       CHG-3231: Eemaldatud muudatus CHG-3180.
**   1.12 08.12.2008   A.Soo       CHG-2795: Teenuste FIX tasude erinevad häälestused.
**                                           Muudetud protseduure: 
**                                             -- Start_Monthly_Charges
**                                             -- Empty_Price_List_Tables
**   1.13 11.05.2009   A.Soo       CHG-3832: POP. Kuutasude arvutamine regular_type põhiselt.
**                                           Muudetud protseduure: 
**                                             -- Start_Package_Fees: Uus sisendparameeter p_regular_type
**                     H.Luhasalu              -- TravelSimi päevade arvust sõltuvat kuumaksu ei arvutata.
**   1.14 19.06.2009   A.Soo       CHG-3861: Eemaldatud CHG-3832 muudatused protseduurst Start_Package_Fees.
**                                           Uued protseduurid:
**                                             -- Chk_Proc_Run_In_Period
**                                             -- Start_RegType_Package_Fees
**   1.15 20.11.2010   H.Luhasalu  CHG-4700: Bill stardiaja muut
**   1.16 24.05.2012   A.Soo       CHG-5854: Taastatud CHG-3180 välja kommenteeritud tingimus prorata = Y.
**                                           Muudetud protseduuri:
**                                             -- Chk_Monthly_Charges_Exist
**   1.17 09.01.2019   A.Jaek      DOBAS-1622: Lisatud tingimus daily_charge is null
**                                           Muudetud protseduuri:
**                                             -- Chk_Monthly_Charges_Exist
**********************************************************************/
/*
  ** Type declarations.
*/
TYPE t_date         IS TABLE OF DATE INDEX BY BINARY_INTEGER;
TYPE t_ref_num      IS TABLE OF NUMBER(10) INDEX BY BINARY_INTEGER;
TYPE t_number       IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
TYPE t_char4        IS TABLE OF VARCHAR2(4) INDEX BY BINARY_INTEGER;
TYPE t_char3        IS TABLE OF VARCHAR2(3) INDEX BY BINARY_INTEGER;
/*
  ** Global declarations
*/
g_sety_fcit_tab           t_char3;
g_sety_taty_tab           t_char3;
g_sety_bise_tab           t_char3;
g_sety_charge_tab         t_number;
g_sety_sept_tab           t_char4;
g_sety_sety_tab           t_ref_num;
g_sety_sepv_tab           t_ref_num;
g_sety_sepa_tab           t_ref_num;
g_sety_start_date_tab     t_date;
g_sety_end_date_tab       t_date;
g_sety_sety_index_tab     t_ref_num;
g_key_sety_tab            t_ref_num; -- CHG-2795
g_key_sety_charge_tab     t_number;  -- CHG-2795
--
g_ma_sety_fcit_tab        t_char3;
g_ma_sety_taty_tab        t_char3;
g_ma_sety_bise_tab        t_char3;
g_ma_sety_charge_tab      t_number;
g_ma_sety_chca_tab        t_char3;
g_ma_sety_sety_tab        t_ref_num;
g_ma_sety_sepv_tab        t_ref_num;
g_ma_sety_sepa_tab        t_ref_num;
g_ma_sety_start_date_tab  t_date;
g_ma_sety_end_date_tab    t_date;
g_ma_sety_sety_index_tab  t_ref_num;
g_ma_key_sety_tab         t_ref_num; -- CHG-2795
g_ma_key_sety_charge_tab  t_number;  -- CHG-2795

/*
  ** Constant declarations.
*/
C_SQL_ERR                CONSTANT NUMBER := 142;
C_BICY_CYCLE             CONSTANT NUMBER := 174;
C_ACCO_PROC              CONSTANT NUMBER := 173;
C_PROGRAM_START          CONSTANT NUMBER := 175;
C_NORM_TERM              CONSTANT NUMBER := 176;
C_ERR_TERM               CONSTANT NUMBER := 602;
C_GENERAL_ERROR_MSG      CONSTANT NUMBER := 9999;
C_PROD_DATE_ERROR        CONSTANT NUMBER := 623;
C_MAAC_COUNT_MSG         CONSTANT NUMBER := 173; -- CHG-3861
--
C_MODULE_REF             CONSTANT VARCHAR2(10) := 'BCCU848';
C_MODULE_REF_SHORT       CONSTANT VARCHAR2(10) := 'U848';
C_MODULE_NAME            CONSTANT VARCHAR2(70) := 'Main_Monthly_Charges';
/*
  ** Procedure and Function declarations.
*/
FUNCTION Chk_Monthly_Charges_Exist (p_invo_ref_num IN  invoices.ref_num%TYPE
) RETURN BOOLEAN;
--
PROCEDURE Get_Invoice(p_maac_ref_num      IN  accounts.ref_num%TYPE
                     ,p_period_start_date IN  DATE
                     ,p_cutoff_date       IN  DATE
                     ,p_success           OUT BOOLEAN
                     ,p_skip_maac         OUT BOOLEAN
                     ,p_invo_rec          OUT invoices%ROWTYPE
                     ,p_error_text        OUT VARCHAR2
                     ,p_module_ref        IN  VARCHAR2 DEFAULT 'BCCU848'
);
--
PROCEDURE Calculate_Monthly_Charges (p_maac_ref_num IN            accounts.ref_num%TYPE
                                    ,p_bill_cutoff  IN            DATE
                                    ,p_invo_rec     IN OUT NOCOPY invoices%ROWTYPE
                                    ,p_success         OUT        BOOLEAN
                                    ,p_error_text      OUT        VARCHAR2
);
--
PROCEDURE Start_Monthly_Charges (p_bill_cycle IN VARCHAR2 DEFAULT 'ALL'
                                ,p_start_maac IN NUMBER   DEFAULT  0
                                ,p_end_maac   IN NUMBER   DEFAULT  9999999999
                                ,p_commit     IN VARCHAR2 DEFAULT 'Y'
);
--
PROCEDURE Start_Package_Fees (p_bill_cycle   IN VARCHAR2 DEFAULT 'ALL'
                             ,p_start_maac   IN NUMBER   DEFAULT  0
                             ,p_end_maac     IN NUMBER   DEFAULT  9999999999
                             ,p_commit       IN VARCHAR2 DEFAULT 'Y'
);
--
PROCEDURE Start_RegType_Package_Fees (p_start_maac   IN NUMBER   DEFAULT  0
                                     ,p_end_maac     IN NUMBER   DEFAULT  9999999999
                                     ,p_regular_type IN VARCHAR2 DEFAULT 'REPL'
                                     ,p_commit       IN VARCHAR2 DEFAULT 'Y'
);
--
END Main_Monthly_Charges;
/

CREATE OR REPLACE PACKAGE BODY MAIN_MONTHLY_CHARGES IS
/*
  ** PACKAGE LEVEL CONSTANTS
*/
c_one_second         CONSTANT NUMBER := 1/86400;
/*
  ** LOCAL PROCEDURES AND FUNCTIONS
*/
/****************************************************************************
**
**   Function Name:   CHK_PACKAGE_FEES_EXIST
**
**   Description:     This function checks if package fees (non-prorata) have already
**                    been created for given invoice.
**
*****************************************************************************/
FUNCTION Chk_Package_Fees_Exist (p_invo_ref_num IN  invoices.ref_num%TYPE
) RETURN BOOLEAN IS
   --
   CURSOR c_inen IS
      SELECT 1
      FROM   invoice_entries         inen
            ,fixed_charge_item_types fcit
      WHERE  inen.invo_ref_num = p_invo_ref_num
      AND    NVL(inen.manual_entry, 'Y') <> 'Y'
      AND    fcit.type_code = inen.fcit_type_code
      AND    fcit.pro_rata = 'N'
      AND    fcit.regular_charge = 'Y'
      AND    fcit.once_off = 'N'
      AND    fcit.sety_ref_num IS NULL
      AND    fcit.prli_package_category IS NOT NULL
      AND    ROWNUM = 1;
   --
   l_dummy         NUMBER;
   l_found         BOOLEAN;
BEGIN
   OPEN  c_inen;
   FETCH c_inen INTO l_dummy;
   l_found := c_inen%FOUND;
   CLOSE c_inen;
   --
   RETURN l_found;
END Chk_Package_Fees_Exist;
/****************************************************************************
**
**   Procedure Name:   EMPTY_PRICE_LIST_TABLES
**
**   Description:     This procedure deletes contents of price list PL/SQL tabels.
**
*****************************************************************************/
PROCEDURE Empty_Price_List_Tables IS
BEGIN
   g_sety_fcit_tab.Delete;
   g_sety_taty_tab.Delete;
   g_sety_bise_tab.Delete;
   g_sety_charge_tab.Delete;
   g_sety_sept_tab.Delete;
   g_sety_sety_tab.Delete;
   g_sety_sepv_tab.Delete;
   g_sety_sepa_tab.Delete;
   g_sety_start_date_tab.Delete;
   g_sety_end_date_tab.Delete;
   g_sety_sety_index_tab.Delete;
   g_key_sety_tab.Delete;        -- CHG-2795
   g_key_sety_charge_tab.Delete; -- CHG-2795
   --
   g_ma_sety_fcit_tab.Delete;
   g_ma_sety_taty_tab.Delete;
   g_ma_sety_bise_tab.Delete;
   g_ma_sety_charge_tab.Delete;
   g_ma_sety_chca_tab.Delete;
   g_ma_sety_sety_tab.Delete;
   g_ma_sety_sepv_tab.Delete;
   g_ma_sety_sepa_tab.Delete;
   g_ma_sety_start_date_tab.Delete;
   g_ma_sety_end_date_tab.Delete;
   g_ma_sety_sety_index_tab.Delete;
   g_ma_key_sety_tab.Delete;        -- CHG-2795
   g_ma_key_sety_charge_tab.Delete; -- CHG-2795
END Empty_Price_List_Tables;
/****************************************************************************
**
**   Function Name:   CHK_PROC_RUN_CURR_PERIOD
**
**   Description:     This function checks if procedure given by module ref has
**                 run successfully between given dates.
**
*****************************************************************************/
FUNCTION Chk_Proc_Run_In_Period (p_module_ref  VARCHAR2
                                ,p_start_date  DATE
                                ,p_end_date    DATE
) RETURN BOOLEAN IS
   --
   CURSOR c_tbpr IS
      SELECT 1
      FROM tbcis_processes
      WHERE module_ref = p_module_ref
        AND end_date BETWEEN p_start_date AND p_end_date
        AND end_code = 'OK'
   ;
   --
   l_dummy   NUMBER;
   l_found   BOOLEAN;
BEGIN
   --
   OPEN  c_tbpr;
   FETCH c_tbpr INTO l_dummy;
   l_found := c_tbpr%FOUND;
   CLOSE c_tbpr;
   --
   RETURN l_found;
END Chk_Proc_Run_In_Period;
/*
  ** GLOBAL PROCEDURES AND FUNCTIONS
*/
/****************************************************************************
**
**   Function Name:   CHK_MONTHLY_CHARGES_EXIST
**
**   Description:     This function checks if monthly charges have already
**                    been created for given invoice.
**
*****************************************************************************/
FUNCTION Chk_Monthly_Charges_Exist (p_invo_ref_num IN  invoices.ref_num%TYPE
) RETURN BOOLEAN IS
   --
   CURSOR c_inen IS
      SELECT  1
      FROM    invoice_entries         inen
             ,fixed_charge_item_types fcit
      WHERE   inen.invo_ref_num = p_invo_ref_num
      AND     NVL(inen.manual_entry, 'Y') <> 'Y'
      AND     fcit.type_code = inen.fcit_type_code
      AND   ((fcit.pro_rata = 'Y'
        AND   fcit.regular_charge = 'Y'
        AND   fcit.once_off = 'N'
        AND   nvl(fcit.daily_charge, 'N') = 'N'  -- DOBAS-1622  
        AND   NVL(inen.num_of_days, 0) <> 0)
            OR  fcit.billing_selector = 'MAY') -- CHG-1044: pere kuutasud (teenused YK, PK)
      AND     ROWNUM = 1;
   --
   l_dummy         NUMBER;
   l_found         BOOLEAN;
BEGIN
   OPEN  c_inen;
   FETCH c_inen INTO l_dummy;
   l_found := c_inen%FOUND;
   CLOSE c_inen;
   --
   RETURN l_found;
END Chk_Monthly_Charges_Exist;
/****************************************************************************
**
**   Procedure Name:   GET_INVOICE
**
**   Description:     This procedure checks if this period debit billing
**                    invoice exists for given Master Account.
**                    It also checks that: 1) this invoice is open,
**                    2) and has not got calculated monthly charges/package fees already.
**                    If no invoice exists then trying to create it.
**
*****************************************************************************/
PROCEDURE Get_Invoice(p_maac_ref_num      IN  accounts.ref_num%TYPE
                     ,p_period_start_date IN  DATE
                     ,p_cutoff_date       IN  DATE
                     ,p_success           OUT BOOLEAN
                     ,p_skip_maac         OUT BOOLEAN
                     ,p_invo_rec          OUT invoices%ROWTYPE
                     ,p_error_text        OUT VARCHAR2
                     ,p_module_ref        IN  VARCHAR2 DEFAULT 'BCCU848'
) IS
   --
   CURSOR c_invo IS
      SELECT *
      FROM   invoices invo
      WHERE  invo.maac_ref_num = p_maac_ref_num
      AND    invo.billing_inv = 'Y'
      AND    invo.credit = 'N'
      AND    NVL(invo.invoice_type, 'INB') = 'INB'
      AND    invo.period_start >= p_period_start_date
      AND    invo.period_start <= p_cutoff_date;
   --
   l_found            boolean;
   l_success          BOOLEAN;
   --
   E_CREATE_INVOICE   EXCEPTION;
BEGIN
   p_skip_maac      := FALSE;
   /*
     ** Try to get debit billing invoice for this period.
   */
   OPEN  c_invo;
   FETCH c_invo INTO p_invo_rec;
   l_found := c_invo%FOUND;
   CLOSE c_invo;
   --
   IF l_found THEN
      /*
        ** Check that invoice is not closed already.
      */
      IF p_invo_rec.period_end IS NOT NULL THEN
         /*
           ** Main Bill has run already and closed this period
           ** debit billing invoice for given Master Account.
         */
         p_skip_maac := TRUE;
      ELSE
         /*
           ** Invoice is open.
           ** Now check if monthly charges/package fees have been calculated for this Master Account.
         */
         IF p_module_ref = 'BCCU848PF' THEN
            l_found := Chk_Package_Fees_Exist (p_invo_rec.ref_num);
         ELSIF p_module_ref = 'BCCU848RP' THEN -- CHG-3861
            l_found := FALSE; -- No need to check package fees
         ELSE
            l_found := Chk_Monthly_Charges_Exist (p_invo_rec.ref_num);
         END IF;
         --
         IF l_found THEN
            /*
              ** Monthly charges/package fees already calculated.
            */
            p_skip_maac := TRUE;
         END IF;
      END IF;
   ELSE
      /*
        ** This period debit billing invoice not existing yet. Try to create it now.
      */
      Open_Invoice.CREATE_BILLING_DEBIT_INVOICE (p_maac_ref_num
                                                ,'INB'
                                                ,p_period_start_date
                                                ,p_invo_rec
                                                ,l_success);
      IF NOT l_success THEN
         RAISE E_CREATE_INVOICE;
      END IF;
   END IF;
   --
   p_success := TRUE;
EXCEPTION
   WHEN E_CREATE_INVOICE THEN
      p_success := FALSE;
      p_error_text := 'Unable to generate Billing Debit Invoice for M/A ' || to_char(p_maac_ref_num) ||
                      ' for period starting at ' || to_char(p_period_start_date, 'dd.mm.yyyy hh24:mi:ss');
END Get_Invoice;
/****************************************************************************
**
**   Procedure Name:   CALCULATE_MONTHLY_CHARGES
**
**   Description:     This procedure calls routines for all monthly charges
**                    creation:
**                    1) Master Account Services Monthly Charges,
**                    2) All mobiles package Monthly Charges for this Master Account,
**                    3) Credit rows for monthly charges already created with
**                       Interim Invoice.
**
*****************************************************************************/
PROCEDURE Calculate_Monthly_Charges (p_maac_ref_num IN            accounts.ref_num%TYPE
                                    ,p_bill_cutoff  IN            DATE
                                    ,p_invo_rec     IN OUT NOCOPY invoices%ROWTYPE
                                    ,p_success         OUT        BOOLEAN
                                    ,p_error_text      OUT        VARCHAR2
) IS
  --
  CURSOR c_chk_int_invo IS
     SELECT 1
     FROM   invoices invo
     WHERE  invo.maac_ref_num = p_maac_ref_num
     and    invo.invoice_type = 'INT'
     and    trunc(invo.period_start) >= trunc(p_invo_rec.period_start)
     and    trunc(last_day(invo.period_start)) <= trunc(p_bill_cutoff)
     AND    ROWNUM = 1;
  --
  CURSOR c_all_prev IS
     SELECT inen.eek_amt            eek_amt,
            inen.billing_selector   billing_selector,
            inen.fcit_type_code     fcit_type_code,
            inen.num_of_days        num_of_days,
            inen.susg_ref_num       susg_ref_num,
            inen.taty_type_code     taty_type_code,
            inen.maas_ref_num       maas_ref_num
     FROM   invoice_entries         inen,
            invoices                invo,
            fixed_charge_item_types fcit
     WHERE  invo.maac_ref_num = p_maac_ref_num
       and  invo.invoice_type = 'INT'
       and  trunc(invo.period_start) >= trunc(p_invo_rec.period_start)
       and  inen.invo_ref_num = invo.ref_num
       and  trunc(last_day(invo.period_start)) <= trunc(p_bill_cutoff)
       and  nvl(inen.num_of_days,0) <> 0
       and  nvl(inen.manual_entry,'Y') <> 'Y'
       and  fcit.type_code = inen.fcit_type_code
       and  fcit.pro_rata = 'Y'
       and  fcit.regular_charge = 'Y'
       and  fcit.once_off = 'N'
       and  nvl(fcit.daily_charge, 'N') = 'N';  -- DOBAS-1622  
   --
   l_dummy           NUMBER;
   l_int_invo_exists BOOLEAN;
   --
   U_ERR_CREATING    EXCEPTION;
BEGIN
   /*
     ** Kontrollime, kas Masterile sellel kuul on ?ldse vahearveid tehtud. Kui ei ole, siis pole m?tet
     ** ka kuumakse vahearvete pealt p??da tagasi v?tta.
   */
   OPEN  c_chk_int_invo;
   FETCH c_chk_int_invo INTO l_dummy;
   l_int_invo_exists := c_chk_int_invo%FOUND;
   CLOSE c_chk_int_invo;
   --
   -- master accounti kuumaksud
   --dbms_output.put_line('Going to calculate MA service charges');
   IF Calculate_fixed_Charges.exist_chargeable_maac_serv(p_maac_ref_num
                           ,p_invo_rec.period_start,trunc(p_bill_cutoff))
   THEN
     -- existeerib hinnastavaid masteri kuumaksulisi teenuseid
     Calculate_fixed_Charges.Main_Master_service_charges(p_maac_ref_num
                                                       ,p_invo_rec
                                                       ,p_success
                                                       ,p_error_text
                                                       ,p_invo_rec.period_start
                                                       ,p_bill_cutoff
                                                       ,'B'
                                                       ,TRUE -- p_main_bill in BOOLEAN DEFAULT FALSE
                                                       );
     if not p_success then
        RAISE u_err_creating;
     end if;
   END IF;
   /*
     ** Mobile packages monthly charges for this Master Account.
   */
   --dbms_output.put_line('Going to calculate mobile charges');
   CALCULATE_FIXED_CHARGES.PERIOD_FIXED_CHARGES (p_maac_ref_num
                                                ,null             -- susg_ref_num
                                                ,p_invo_rec
                                                ,p_success
                                                ,p_error_text
                                                ,p_invo_rec.period_start
                                                ,TRUNC(p_bill_cutoff)      -- Package end dates are trunced
                                                ,'B'
                                                ,C_MODULE_REF_SHORT
                                                ,l_int_invo_exists -- UPR-3124
                                                ,TRUE   -- p_main_bill       BOOLEAN DEFAULT FALSE -- CHG-464
                                                );
   IF not p_success THEN
      RAISE U_ERR_CREATING;
   END IF;
   /*
     ** Create credit entries for monthly charges contained in Interim Invoice
     ** in order not to calculate duplicate monthly charges for the days involved.
   */
   --dbms_output.put_line('Going to recalculate INT invoice charges');
   IF l_int_invo_exists THEN
      FOR rec_prev in c_all_prev LOOP
         Calculate_Fixed_Charges.Create_Entries (p_success
                                                ,p_error_text
                                                ,p_invo_rec.ref_num
                                                ,rec_prev.fcit_type_code
                                                ,rec_prev.taty_type_code
                                                ,rec_prev.billing_selector
                                                ,-1*rec_prev.eek_amt
                                                ,rec_prev.susg_ref_num
                                                ,-1*rec_prev.num_of_days
                                                ,C_MODULE_REF_SHORT
                                                ,rec_prev.maas_ref_num
                                                );
         IF not p_success THEN
            RAISE U_ERR_CREATING;
         END IF;
      END LOOP;
   END IF;
EXCEPTION
   WHEN U_ERR_CREATING THEN
      p_success := FALSE;
END Calculate_Monthly_Charges;
/****************************************************************************
**
**   Procedure Name:   START_MONTHLY_CHARGES
**
**   Description:     This is the main (outer) procedure for Main Bill
**                    Monthly Charges creation.
**
*****************************************************************************/
PROCEDURE Start_Monthly_Charges (p_bill_cycle IN VARCHAR2 DEFAULT 'ALL'
                                ,p_start_maac IN NUMBER   DEFAULT  0
                                ,p_end_maac   IN NUMBER   DEFAULT  9999999999
                                ,p_commit     IN VARCHAR2 DEFAULT 'Y'
) IS
   --
   l_date_curr_run        DATE;
   l_salp_start           DATE;
   l_salp_cutoff          DATE;
   l_curr_salp_start_date DATE;
   l_curr_salp_end_date   DATE;
   l_success              BOOLEAN := TRUE;
   l_bill_start           DATE;
   l_bill_cutoff          DATE;
   l_prodn_date           DATE;
   l_account_count        NUMBER := 0;
   l_accounts_ignored     NUMBER := 0;
   l_skip_maac            BOOLEAN;
   l_found                BOOLEAN;
   l_invo_rec             invoices%ROWTYPE;
   l_error_text           bcc_batch_messages.message_text%TYPE;
   l_first_open_salp      sales_ledger_periods%ROWTYPE;
   l_idx                  NUMBER;
   l_last_sety_ref_num    service_types.ref_num%TYPE;
   l_message              bcc_batch_messages.message_text%TYPE;
   --
   e_curr_salp_not_exist  EXCEPTION;
   e_processing_error     EXCEPTION;
   e_missing_parameter    EXCEPTION;
   U_PROD_DATE_ERROR      EXCEPTION;
   U_PRC_STAT_ERROR       EXCEPTION;
   --
   CURSOR c_bicy IS
      SELECT *
      FROM   bill_cycles
      WHERE (cycle_code = Decode(p_bill_cycle, 'ALL', cycle_code, p_bill_cycle))
      ORDER BY cycle_code;

   --
   CURSOR c_maac(p_bill_cycle IN VARCHAR2
                ,p_start_maac IN NUMBER
                ,p_end_maac   IN NUMBER
                ,p_start_date  IN date
                ,p_end_date    IN date
   ) IS
     SELECT acco.ref_num maac_ref_num
     FROM   accounts    acco,account_statuses acst
     WHERE  acco.master_acc      = 'Y'
     AND    acco.bicy_cycle_code = p_bill_cycle
     AND    acco.ref_num BETWEEN p_start_maac AND p_end_maac
     and    acst.acco_ref_num=acco.ref_num
     and    acst.acst_code='AC'
     and    nvl(acst.end_date,sysdate)>=p_start_date
     and    acst.start_date<=p_end_date
     and    acco.ref_num not in (2025410000)
     ORDER BY acco.ref_num;
   --
   CURSOR c_ebpl (p_start_date IN DATE
                 ,p_end_date   IN DATE
   ) IS
      SELECT fcit_type_code
            ,taty_type_code
            ,billing_selector
            ,charge_value
            ,sept_type_code
            ,sety_ref_num
            ,sepv_ref_num
            ,sepa_ref_num
            ,greatest(start_date, p_start_date)   start_date
            ,least(nvl(end_date, p_end_date), p_end_date)   end_date
            ,key_sety_ref_num -- CHG-2795
            ,key_charge_value -- CHG-2795
      FROM   emt_bill_price_list
      WHERE  chca_type_code IS NULL
      AND    fcty_type = 'MCH'
      AND    sept_type_code IS NOT NULL
      AND    sety_ref_num IS NOT NULL
      AND    chargeable = 'Y'
      AND    charge_value > 0
      AND    start_date <= p_end_date
      AND    nvl(end_date, p_start_date) >= p_start_date
      ORDER BY sety_ref_num
              ,sept_type_code
              ,start_date
              ,end_date
   ;
   --
   CURSOR c_ebpl_maas (p_start_date IN DATE
                      ,p_end_date   IN DATE
   ) IS
      SELECT fcit_type_code
            ,taty_type_code
            ,billing_selector
            ,charge_value
            ,chca_type_code
            ,sety_ref_num
            ,sepv_ref_num
            ,sepa_ref_num
            ,greatest(start_date, p_start_date)   start_date
            ,least(nvl(end_date, p_end_date), p_end_date)   end_date
            ,key_sety_ref_num -- CHG-2795
            ,key_charge_value -- CHG-2795
      FROM   emt_bill_price_list
      WHERE  chca_type_code IS NOT NULL
      AND    fcty_type = 'MCH'
      AND    sept_type_code IS NULL
      AND    sety_ref_num IS NOT NULL
      AND    chargeable = 'Y'
      AND    start_date <= p_end_date
      AND    nvl(end_date, p_start_date) >= p_start_date
      ORDER BY sety_ref_num
              ,chca_type_code
              ,start_date
              ,end_date
   ;
BEGIN
   DELETE bcc_batch_messages
   WHERE  module_ref   = c_module_ref
   AND    run_by_user  = sec.get_username
   AND    message_date < SYSDATE - 5;
   --
   IF (Nvl(p_commit, 'Y') = 'Y') THEN
      COMMIT;
   END IF;
   --
   Insert_Batch_Messages(C_MODULE_REF
                        ,C_MODULE_NAME
                        ,C_PROGRAM_START
                        ,To_Char(SYSDATE, 'DD.MM.YYYY HH24:MI:SS')
                        ,'Params : ' || p_bill_cycle          ||
                                 '/' || To_Char(p_start_maac) ||
                                 '/' || To_Char(p_end_maac)   ||
                                 '/' || p_commit
                         );
   --
   IF (Nvl(p_commit, 'Y') = 'Y') THEN
      COMMIT;
   END IF;
   --
   IF p_bill_cycle IS NULL OR p_start_maac IS NULL OR p_end_maac IS NULL THEN
      l_message := 'At least 1 mandatory input parameter (Bill Cycle, Start M/A, End M/A) is missing';
      RAISE e_missing_parameter;
   END IF;
   /*
     ** CHG-464: Lubada paralleelk?itus ts?klite kaupa, keelata ALL k?itus.
   */
   IF p_bill_cycle = 'ALL' THEN
      l_message := 'Not allowed to run ALL bill cycles. Specify bill cycle as a parameter.';
      RAISE e_missing_parameter;
   END IF;
   --
   BCC_MISC_PROCESSING.Check_Process_Status (l_success
                                            ,C_MODULE_REF || p_bill_cycle
   );
   IF NOT l_success THEN
      RAISE U_PRC_STAT_ERROR;
   END IF;
   --
   -- The Date of the Current Run is based on the System Date
   l_date_curr_run :=  SYSDATE;
   /*
     ** CHG-464:
     ** Loeme teenuste kuutasude hinnakirja andmed m?tabelitesse, et teenuste kuutasude arvutuses kasutada hinna
     ** otsimist ainult m?tabelitest.
   */
   Empty_Price_List_Tables;
   --
   l_first_open_salp := Gen_Bill.First_Open_SALP_Rec;
   l_first_open_salp.end_date := Trunc(l_first_open_salp.end_date)+1-c_one_second;
   --
   OPEN  c_ebpl(l_first_open_salp.start_date, l_first_open_salp.end_date);
   FETCH c_ebpl BULK COLLECT INTO g_sety_fcit_tab
                                 ,g_sety_taty_tab
                                 ,g_sety_bise_tab
                                 ,g_sety_charge_tab
                                 ,g_sety_sept_tab
                                 ,g_sety_sety_tab
                                 ,g_sety_sepv_tab
                                 ,g_sety_sepa_tab
                                 ,g_sety_start_date_tab
                                 ,g_sety_end_date_tab
                                 ,g_key_sety_tab         -- CHG-2795
                                 ,g_key_sety_charge_tab; -- CHG-2795
   CLOSE c_ebpl;
   /*
     ** Et otsimist lihtsustada, salvestama iga teenuse kohta tema algindeksi m?tabelis.
   */
   l_last_sety_ref_num := 0;
   l_idx := g_sety_sety_tab.First;
   WHILE l_idx IS NOT NULL LOOP
      IF g_sety_sety_tab(l_idx) <> NVL(l_last_sety_ref_num, 0) THEN
         g_sety_sety_index_tab(g_sety_sety_tab(l_idx)) := l_idx;
--         dbms_output.put_line('SETY=' || to_char(g_sety_sety_tab(l_idx)) ||
  --                            ', index=' || to_char(g_sety_sety_index_tab(g_sety_sety_tab(l_idx))));
      END IF;
      --
      l_last_sety_ref_num := g_sety_sety_tab(l_idx);
      l_idx := g_sety_sety_tab.Next(l_idx);
   END LOOP;
   /*
     ** Loeme m?u ka masterkonto teenuste hinnakirja.
   */
   OPEN  c_ebpl_maas (l_first_open_salp.start_date, l_first_open_salp.end_date);
   FETCH c_ebpl_maas BULK COLLECT INTO g_ma_sety_fcit_tab
                                      ,g_ma_sety_taty_tab
                                      ,g_ma_sety_bise_tab
                                      ,g_ma_sety_charge_tab
                                      ,g_ma_sety_chca_tab
                                      ,g_ma_sety_sety_tab
                                      ,g_ma_sety_sepv_tab
                                      ,g_ma_sety_sepa_tab
                                      ,g_ma_sety_start_date_tab
                                      ,g_ma_sety_end_date_tab
                                      ,g_ma_key_sety_tab         -- CHG-2795
                                      ,g_ma_key_sety_charge_tab; -- CHG-2795
   CLOSE c_ebpl_maas;
   /*
     ** Et otsimist lihtsustada, salvestama iga teenuse kohta tema algindeksi m?tabelis.
   */
   l_last_sety_ref_num := 0;
   l_idx := g_ma_sety_sety_tab.First;
   WHILE l_idx IS NOT NULL LOOP
      IF g_ma_sety_sety_tab(l_idx) <> NVL(l_last_sety_ref_num, 0) THEN
         g_ma_sety_sety_index_tab(g_ma_sety_sety_tab(l_idx)) := l_idx;
--         dbms_output.put_line('SETY=' || to_char(g_ma_sety_sety_tab(l_idx)) ||
  --                            ', index=' || to_char(g_ma_sety_sety_index_tab(g_ma_sety_sety_tab(l_idx))));
      END IF;
      --
      l_last_sety_ref_num := g_ma_sety_sety_tab(l_idx);
      l_idx := g_ma_sety_sety_tab.Next(l_idx);
   END LOOP;
   --
   -----------------------------------------------------------------------
   --  M A I N  L O O P: Bill Cycles                                     -
   -----------------------------------------------------------------------
   FOR l_bicy IN c_bicy LOOP
      Insert_Batch_Messages(C_MODULE_REF
                           ,C_MODULE_NAME
                           ,C_BICY_CYCLE
                           ,l_bicy.cycle_code || ' at ' || To_Char(SYSDATE, 'DD.MM.YYYY HH24:MI:SS')
                           ,NULL
                           );
      IF (Nvl(p_commit, 'Y') = 'Y') THEN
         COMMIT;
      END IF;
      --
      l_account_count    := 0;
      l_accounts_ignored := 0;
      --
      BCC_Misc_Processing.Set_Cut_Off_Date (
                                            l_bicy.cut_off_day_num
                                           ,l_bicy.production_day_num
                                           ,l_bicy.date_last_bill
                                           ,l_bill_start             -- OUT DATE
                                           ,l_bill_cutoff            -- OUT DATE
                                           ,l_prodn_date             -- OUT DATE
                                           );
        if l_bill_start is null or l_bill_cutoff is null or l_prodn_date is null then
--        DBMS_Output.Put_Line('MISC ei leia algust !');
        RAISE e_curr_salp_not_exist;
        end if;
      ---------------------------------------------------------------------
      -- Don't Generate Bills unless we reached the actual (Bills) Production Date.
      ---------------------------------------------------------------------
      IF l_date_curr_run < l_prodn_date THEN   --- sysdate< lubatud
--         DBMS_Output.Put_Line('Cannot run Bills as Production Date not reached.');
         RAISE u_prod_date_error;
      END IF;


      l_salp_start:=l_bill_start;
      l_salp_cutoff:=Trunc(l_bill_cutoff);

      ----------------------------------------------------------------------------
      --
      -- Print out all Dates  lines
      --
      ----------------------------------------------------------------------------
/**
      DBMS_Output.Put_Line('Bill Cycle         ' || l_bicy.cycle_code);
      DBMS_Output.Put_Line('Current Run Date   ' || To_Char(l_date_curr_run,       'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('Bill Start Date    ' || To_Char(l_bill_start,          'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('Bill Cut Off Date  ' || To_Char(l_bill_cutoff,         'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('Production Date    ' || To_Char(l_prodn_date,          'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('SALP Start Date    ' || To_Char(l_salp_start,          'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('SALP End Date      ' || To_Char(l_salp_cutoff,         'DD.MM.YYYY HH24:MI:SS'));
**/
      --
      IF p_start_maac = 0 THEN

            UPDATE bill_cycles bicy
               SET bicy.start_date_last_bill = SYSDATE
            WHERE  bicy.cycle_code = l_bicy.cycle_code;
            --
            update tbcis_processes
               set start_date=sysdate,
                   end_date=null,
                   end_code=null
            where  module_ref  = c_module_ref
              and  upper(module_desc) = upper(C_MODULE_NAME)
              and  module_params=l_bicy.cycle_code;
            --
            IF (Nvl(p_commit, 'Y') = 'Y') THEN
               COMMIT;
            END IF;

      END IF;
      /*
        ** CHG-210: Kontrollime, kas selle arveldusts?kli jaoks on ?ldse vaja kuumakse arvutada v?i v?ib vahele j?a.
      */
      IF l_bicy.calculate_monthly_charges = 'Y' THEN
         FOR REC_MAAC IN c_maac(l_bicy.cycle_code, p_start_maac, p_end_maac, l_bill_start,l_bill_cutoff)
         LOOP
            BEGIN
               l_account_count := l_account_count + 1;
               /*
                 ** Get or open debit billing invoice for this period.
               */
               Get_Invoice(rec_maac.maac_ref_num
                          ,GREATEST(l_bill_start,l_salp_start)
                          ,l_bill_cutoff
                          ,l_success
                          ,l_skip_maac
                          ,l_invo_rec
                          ,l_error_text);

--DBMS_OUTPUT.Put_Line( 'KUSTU1');
               IF Not l_success THEN
--               DBMS_OUTPUT.Put_Line( 'KUSTU1 err');
                  RAISE e_processing_error;
               END IF;
               --
               IF NOT l_skip_maac THEN
                  Calculate_Monthly_Charges (rec_maac.maac_ref_num
                                            ,l_bill_cutoff
                                            ,l_invo_rec
                                            ,l_success
                                            ,l_error_text);
--DBMS_OUTPUT.Put_Line( 'KUSTU2'||l_error_text);
                  IF Not l_success THEN
--                  DBMS_OUTPUT.Put_Line( 'KUSTU2 err');
                     RAISE e_processing_error;
                  END IF;
                  --
                  IF (Nvl(p_commit, 'Y') = 'Y') THEN
                     COMMIT;
                  END IF;
               END IF;
            EXCEPTION
               WHEN e_processing_error THEN
                  ROLLBACK;
                  l_accounts_ignored := l_accounts_ignored + 1;
                  Insert_Batch_Messages(C_MODULE_REF
                                       ,C_MODULE_NAME
                                       ,C_GENERAL_ERROR_MSG
                                       ,l_error_text
                                       ,NULL
                                       );
                  IF (Nvl(p_commit, 'Y') = 'Y') THEN
                     COMMIT;
                  END IF;
                  --
                  IF Instr(l_error_text, '-6508') > 0 OR Instr(l_error_text, '-06508') > 0 OR
                     Instr(l_error_text, '-6550') > 0 OR Instr(l_error_text, '-06550') > 0
                  THEN
                     RAISE;    -- abort processing
                  END IF;
               WHEN others THEN
                  ROLLBACK;
                  l_accounts_ignored := l_accounts_ignored + 1;
                  Insert_Batch_Messages(C_MODULE_REF
                                       ,C_MODULE_NAME
                                       ,C_GENERAL_ERROR_MSG
                                       ,'MAAC ' || to_char(rec_maac.maac_ref_num) || ': ' || SQLERRM
                                       ,NULL
                                       );
                  IF (Nvl(p_commit, 'Y') = 'Y') THEN
                     COMMIT;
                  END IF;
                  --
                  IF SQLCODE IN (-6508, -6550) THEN
                     RAISE;    -- abort processing
                  END IF;
            END;
            --------------------------------------------------
            --   END  OF  LOOP   TO   PROCESS    MASTER   ACCOUNTS
            ----------------------------------------------------------------------
         END LOOP;
         -- Insert 'final' Batch Messages and update Billing Cycles
         Insert_Batch_Messages(C_MODULE_REF
                              ,C_MODULE_NAME
                              ,C_ACCO_PROC
                              ,To_Char(l_account_count)
                              ,To_Char(l_accounts_ignored) || ' for Bill Cycle ' || l_bicy.cycle_code);
         --
         IF (Nvl(p_commit, 'Y') = 'Y') THEN
            COMMIT;
         END IF;
      ELSE   -- Calculate_Monthly_Charges = N
         Gen_Bill.Msg (
                  c_module_ref   -- p_mod_ref     VARCHAR2
                 ,c_module_name  -- p_mod_desc    VARCHAR2
                 ,C_GENERAL_ERROR_MSG -- p_mesg_num    NUMBER
                 ,'Arveldusts?kli ' || l_bicy.cycle_code || ' kuumaksude arvutus vahele j?ud' -- p_param1      VARCHAR2 DEFAULT NULL
                 );
      END IF;
      /*
        ** If all Master Accounts of the Bill Cycle processed then set
        ** Monthly Charges calculation end date.
      */
      IF (l_accounts_ignored = 0) AND (p_start_maac = 0) THEN -- Only for Full Runs
         UPDATE bill_cycles bicy
            SET bicy.end_monthly_charges = SYSDATE
         WHERE (bicy.cycle_code = l_bicy.cycle_code);
         --
         update tbcis_processes
            set end_date=sysdate,
                end_code='OK'
         where  module_ref  =  c_module_ref
           and  upper(module_desc) = upper(C_MODULE_NAME)
           and  module_params=l_bicy.cycle_code;
         --
         IF (Nvl(p_commit, 'Y') = 'Y') THEN
            COMMIT;
         END IF;
      ELSE
         update tbcis_processes
            set  end_date=sysdate,
                 end_code='ERR'
         where  module_ref  =  c_module_ref
           and upper(module_desc) = upper(C_MODULE_NAME)
           and  module_params=l_bicy.cycle_code;
      END IF;
   END LOOP;
   ------------------------------------------------------------------------------
   --  END   OF   MAIN   LOOP   TO   PROCESS   BILL  CYCLES.
   ------------------------------------------------------------------------------
   Insert_Batch_Messages(C_MODULE_REF
                        ,C_MODULE_NAME
                        ,C_NORM_TERM
                        ,To_Char(SYSDATE, 'DD.MM.YYYY HH24:MI:SS')
                        ,NULL
                        );
   IF (Nvl(p_commit, 'Y') = 'Y') THEN
      COMMIT;
   END IF;
   /*
     ** CHG-464: Vabastame m?tabelid
   */
   Empty_Price_List_Tables;
   --
   dbms_application_info.set_client_info(' ');
EXCEPTION
   -------------------------------------------------------------------------------
   -- Process Status: when the Status of BCCU848 cannot be updated or other process
   --                 has already been started.
   -------------------------------------------------------------------------------
   WHEN U_PRC_STAT_ERROR THEN
      Insert_Batch_Messages(C_MODULE_REF
                           ,C_MODULE_NAME
                           ,C_GENERAL_ERROR_MSG
                           ,'Process ' || C_MODULE_REF || p_bill_cycle || ' has already been started. ' ||
                            'Cannot run 2 different instances at the same time.'
                           ,NULL
                           );
      IF (Nvl(p_commit, 'Y') = 'Y') THEN
         COMMIT;
      END IF;
   ---------------------------------------------------------------------------------
   -- System Date is before Production Date - Cannot Generate Bills
   ---------------------------------------------------------------------------------
   WHEN u_prod_date_error THEN
      Empty_Price_List_Tables;
      Insert_Batch_Messages(C_MODULE_REF
                           ,C_MODULE_NAME
                           ,C_PROD_DATE_ERROR
                           ,NULL
                           ,NULL
                           );
      IF (Nvl(p_commit, 'Y') = 'Y') THEN
         COMMIT;
      END IF;
      dbms_application_info.set_client_info(' ');
   WHEN e_curr_salp_not_exist THEN
      Empty_Price_List_Tables;
      Insert_Batch_Messages(C_MODULE_REF
                           ,C_MODULE_NAME
                           ,C_GENERAL_ERROR_MSG
                           ,'Sales Ledger Period ' || To_Char(SYSDATE, 'Mon YYYY') || ' is not existing!'
                           ,NULL
                           );
      IF (Nvl(p_commit, 'Y') = 'Y') THEN
         COMMIT;
      END IF;
      dbms_application_info.set_client_info(' ');
   WHEN e_missing_parameter THEN
      Empty_Price_List_Tables;
      Insert_Batch_Messages(C_MODULE_REF
                           ,C_MODULE_NAME
                           ,C_GENERAL_ERROR_MSG
                           ,l_message
                           ,NULL
                           );
      IF (Nvl(p_commit, 'Y') = 'Y') THEN
         COMMIT;
      END IF;
   WHEN others THEN
      Empty_Price_List_Tables;
      Insert_Batch_Messages(C_MODULE_REF
                           ,C_MODULE_NAME
                           ,C_SQL_ERR
                           ,SQLERRM
                           ,To_Char(SQLCODE));
      Insert_Batch_Messages(C_MODULE_REF
                           ,C_MODULE_NAME
                           ,C_ERR_TERM
                           ,To_Char(SYSDATE,'DD.MM.YYYY HH24:MI:SS')
                           ,NULL
                           );
            update tbcis_processes
               set    end_date=sysdate,
                      end_code='ERR'
             where  module_ref  =  c_module_ref
               and  upper(module_desc) = upper(C_MODULE_NAME)
               and  module_params is null;
      IF (Nvl(p_commit, 'Y') = 'Y') THEN
         COMMIT;
      END IF;
END Start_Monthly_Charges;
--
/****************************************************************************
**
**   Procedure Name:   START_PACKAGE_FEES
**
**   Description:     P?ade arvust s?ltumatute (non-prorata) paketitasude
**                    arvutamise p?hiprotseduur.
**
*****************************************************************************/
PROCEDURE Start_Package_Fees (p_bill_cycle   IN VARCHAR2 DEFAULT 'ALL'
                             ,p_start_maac   IN NUMBER   DEFAULT  0
                             ,p_end_maac     IN NUMBER   DEFAULT  9999999999
                             ,p_commit       IN VARCHAR2 DEFAULT 'Y'
) IS
   --
   c_module_ref           CONSTANT bcc_batch_messages.module_ref%TYPE  := 'BCCU848PF';
   c_module_desc          CONSTANT bcc_batch_messages.module_desc%TYPE := 'Start Package Fees';
   --
   l_date_curr_run        DATE;
   l_salp_start           DATE;
   l_salp_cutoff          DATE;
   l_curr_salp_start_date DATE;
   l_curr_salp_end_date   DATE;
   l_success              BOOLEAN := TRUE;
   l_bill_start           DATE;
   l_bill_cutoff          DATE;
   l_prodn_date           DATE;
   l_account_count        NUMBER := 0;
   l_accounts_ignored     NUMBER := 0;
   l_skip_maac            BOOLEAN;
   l_found                BOOLEAN;
   l_invo_rec             invoices%ROWTYPE;
   l_error_text           bcc_batch_messages.message_text%TYPE;
   l_salp_rec             sales_ledger_periods%ROWTYPE;
   --
   e_curr_salp_not_exist  EXCEPTION;
   e_processing_error     EXCEPTION;
   e_missing_parameter    EXCEPTION;
   U_PROD_DATE_ERROR      EXCEPTION;
   U_PRC_STAT_ERROR       EXCEPTION;
   e_monthly_ch_not_calc  EXCEPTION;
   e_call_disc_not_calc   EXCEPTION;
   --
   CURSOR c_bicy IS
      SELECT *
      FROM   bill_cycles
      WHERE (cycle_code = Decode(p_bill_cycle, 'ALL', cycle_code, p_bill_cycle))
      ORDER BY cycle_code;
   --
   CURSOR c_maac(p_bill_cycle IN VARCHAR2
                ,p_start_maac IN NUMBER
                ,p_end_maac   IN NUMBER
                ,p_start_date  IN date
                ,p_end_date    IN date
   ) IS
     SELECT acco.ref_num maac_ref_num
     FROM   accounts    acco
           ,account_statuses acst
     WHERE (acco.master_acc      = 'Y')
     AND   (acco.bicy_cycle_code = p_bill_cycle)
     AND   (acco.ref_num BETWEEN p_start_maac AND p_end_maac)
     and    acst.acco_ref_num=acco.ref_num
     and    acst.acst_code='AC'
     and    nvl(acst.end_date,sysdate) >= p_start_date
     and    acst.start_date <= p_end_date
     ORDER BY acco.ref_num
   ;
BEGIN
   DELETE bcc_batch_messages
   WHERE  module_ref   = c_module_ref
     AND (run_by_user  = sec.get_username)
     AND (message_date < SYSDATE - 5);
   --
   IF (Nvl(p_commit, 'Y') = 'Y') THEN
      COMMIT;
   END IF;
   --
   Gen_Bill.Msg(C_MODULE_REF
               ,c_module_desc
               ,C_PROGRAM_START
               ,To_Char(SYSDATE, 'DD.MM.YYYY HH24:MI:SS')
               ,'Params : ' || p_bill_cycle          ||
                        '/' || To_Char(p_start_maac) ||
                        '/' || To_Char(p_end_maac)   ||
                        '/' || p_commit
               );
   --
   IF p_bill_cycle IS NULL OR p_start_maac IS NULL OR p_end_maac IS NULL THEN
      RAISE e_missing_parameter;
   END IF;
   --
   BCC_MISC_PROCESSING.Check_Process_Status (l_success
                                            ,C_MODULE_REF);
   IF NOT l_success THEN
      RAISE U_PRC_STAT_ERROR;
   END IF;
   --
   -- The Date of the Current Run is based on the System Date
   l_date_curr_run :=  SYSDATE;
   --
   -----------------------------------------------------------------------
   --  M A I N  L O O P: Bill Cycles                                     -
   -----------------------------------------------------------------------
   FOR l_bicy IN c_bicy LOOP
      Gen_Bill.Msg(C_MODULE_REF
                  ,c_module_desc
                  ,C_BICY_CYCLE
                  ,l_bicy.cycle_code || ' at ' || To_Char(SYSDATE, 'DD.MM.YYYY HH24:MI:SS')
                  );
      --
      l_account_count    := 0;
      l_accounts_ignored := 0;
      --
      BCC_Misc_Processing.Set_Cut_Off_Date (l_bicy.cut_off_day_num
                                           ,l_bicy.production_day_num
                                           ,l_bicy.date_last_bill
                                           ,l_bill_start             -- OUT DATE
                                           ,l_bill_cutoff            -- OUT DATE 23:59:59
                                           ,l_prodn_date             -- OUT DATE
                                           );
      ---------------------------------------------------------------------
      -- Don't Generate Bills unless we reached the actual (Bills) Production Date.
      ---------------------------------------------------------------------
      IF l_date_curr_run < l_prodn_date THEN
--         DBMS_Output.Put_Line('Cannot run Bills as Production Date not reached.');
         RAISE u_prod_date_error;
      END IF;
      /*
        ** Non-prorata kuutasusid ei ole lubatud arvutada enne, kui on arvutatud regulaarsed kuumaksud.
      */
      IF l_bicy.end_monthly_charges IS NULL OR                 -- Never calculated
         l_bicy.end_monthly_charges <= l_prodn_date OR        -- Calculated before this period end
         l_bicy.end_monthly_charges <= l_bicy.end_package_fees -- Latest run was Package Fees not Monthly Charges
      THEN
         RAISE e_monthly_ch_not_calc;
      END IF;
      /*
        ** Non-prorata kuutasusid ei ole lubatud arvutada enne, kui on arvutatud soodustused.
      */
      IF l_bicy.end_call_discounts IS NULL OR                  -- Never calculated
         l_bicy.end_call_discounts <= l_prodn_date OR         -- Calculated before this period end
         l_bicy.end_call_discounts <= l_bicy.end_package_fees  -- Latest run was Package Fees not Discounts
      THEN
         RAISE e_call_disc_not_calc;
      END IF;

      -----------------------------------------------------------------
      -- Get the SALP for this Cut Off Date.
      -----------------------------------------------------------------
      l_found := Gen_Bill.Get_Current_SALP_Rec (l_bill_start
                                               ,l_salp_rec   -- OUT sales_ledger_periods%ROWTYPE
                                               );
      l_salp_start  := Trunc(l_salp_rec.start_date);
      l_salp_cutoff := Trunc(l_salp_rec.end_date);
      --
      IF Trunc(l_bill_cutoff) <> l_salp_cutoff AND l_date_curr_run >= l_salp_cutoff THEN
         l_found := Gen_Bill.Get_Current_SALP_Rec (l_bill_cutoff
                                                  ,l_salp_rec   -- OUT sales_ledger_periods%ROWTYPE
                                                  );
         l_salp_start  := Trunc(l_salp_rec.start_date);
         l_salp_cutoff := Trunc(l_salp_rec.end_date);
      END IF;
      ----------------------------------------------------------------------------
      --
      -- Print out all Dates  lines
      --
      ----------------------------------------------------------------------------
/**
      DBMS_Output.Put_Line('Bill Cycle         ' || l_bicy.cycle_code);
      DBMS_Output.Put_Line('Current Run Date   ' || To_Char(l_date_curr_run,       'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('Date Last Billed   ' || To_Char(l_bicy.date_last_bill, 'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('Start Dt Last Bill ' || To_Char(l_bicy.start_date_last_bill,'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('Bill Start Date    ' || To_Char(l_bill_start,          'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('Bill Cut Off Date  ' || To_Char(l_bill_cutoff,         'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('Production Date    ' || To_Char(l_prodn_date,          'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('SALP Start Date    ' || To_Char(l_salp_start,          'DD.MM.YYYY HH24:MI:SS'));
      DBMS_Output.Put_Line('SALP End Date      ' || To_Char(l_salp_cutoff,         'DD.MM.YYYY HH24:MI:SS'));
**/
      --
      IF p_start_maac = 0 THEN
         l_found := Gen_Bill.Get_Current_SALP_Rec (SYSDATE
                                                  ,l_salp_rec   -- OUT sales_ledger_periods%ROWTYPE
                                                  );
         IF NOT l_found THEN
            RAISE e_curr_salp_not_exist;
         END IF;
         --
         l_curr_salp_start_date := Trunc(l_salp_rec.start_date);
         l_curr_salp_end_date   := Trunc(l_salp_rec.end_date);
         --
         IF (l_curr_salp_start_date > NVL(l_bicy.start_package_fees, l_curr_salp_start_date-1)) THEN
            UPDATE bill_cycles bicy
               SET bicy.start_package_fees = SYSDATE
            WHERE (bicy.cycle_code = l_bicy.cycle_code);
            --
            update tbcis_processes
               set start_date=sysdate
                  ,end_date=null
                  ,end_code=null
            where  module_ref  = c_module_ref
            and    upper(module_desc) = upper(C_MODULE_DESC)
            and    module_params = l_bicy.cycle_code;
            --
            IF (Nvl(p_commit, 'Y') = 'Y') THEN
               COMMIT;
            END IF;
         END IF;
      END IF;
      ---------------------------------------------------
      ---------------------------------------------------
      FOR REC_MAAC IN c_maac(l_bicy.cycle_code
                            ,p_start_maac
                            ,p_end_maac
                            ,LEAST(l_bill_start, l_salp_start)
                            ,l_bill_cutoff)   -- 23:59:59
      LOOP


         BEGIN
            l_account_count := l_account_count + 1;
            /*
              ** Get or open debit billing invoice for this period.
            */
            Get_Invoice(rec_maac.maac_ref_num
                       ,GREATEST(l_bill_start, l_salp_start)
                       ,l_bill_cutoff   -- 23:59:59
                       ,l_success
                       ,l_skip_maac
                       ,l_invo_rec
                       ,l_error_text
                       ,c_module_ref        -- IN  VARCHAR2 DEFAULT 'BCCU848'
                       );
            IF Not l_success THEN
               RAISE e_processing_error;
            END IF;
            --
            IF NOT l_skip_maac THEN
               Calculate_Fixed_Charges.Calc_Non_ProRata_Maac_Pkg_Chg (
                                         rec_maac.maac_ref_num -- IN     accounts.ref_num%TYPE
                                        ,NULL   -- p_susg_ref_num IN     subs_serv_groups.ref_num%TYPE
                                        ,l_invo_rec.ref_num -- IN     INVOICES.ref_num%TYPE
                                        ,GREATEST(l_bill_start,l_salp_start) -- p_period_start IN     DATE
                                        ,l_bill_cutoff -- p_period_end   IN     DATE   23:59:59
                                        ,l_success         -- OUT BOOLEAN
                                        ,l_error_text      -- OUT VARCHAR2
                                        );
               IF Not l_success THEN
                  RAISE e_processing_error;
               END IF;
               --
               IF (Nvl(p_commit, 'Y') = 'Y') THEN
                  COMMIT;
               END IF;
            END IF;
         EXCEPTION
            WHEN e_processing_error THEN
               ROLLBACK;
               l_accounts_ignored := l_accounts_ignored + 1;
               Gen_Bill.Msg(C_MODULE_REF
                           ,C_MODULE_DESC
                           ,C_GENERAL_ERROR_MSG
                           ,l_error_text
                           );
               IF Instr(l_error_text, '-6508') > 0 OR Instr(l_error_text, '-06508') > 0 OR
                  Instr(l_error_text, '-6550') > 0 OR Instr(l_error_text, '-06550') > 0
               THEN
                  RAISE;    -- abort processing
               END IF;
            WHEN others THEN
               ROLLBACK;
               l_accounts_ignored := l_accounts_ignored + 1;
               Gen_Bill.Msg(C_MODULE_REF
                           ,C_MODULE_DESC
                           ,C_GENERAL_ERROR_MSG
                           ,'MAAC ' || to_char(rec_maac.maac_ref_num) || ': ' || SQLERRM
                           );
               --
               IF SQLCODE IN (-6508, -6550) THEN
                  RAISE;    -- abort processing
               END IF;
         END;
         --------------------------------------------------
         --   END  OF  LOOP   TO   PROCESS    MASTER   ACCOUNTS
         ----------------------------------------------------------------------
      END LOOP;
      -- Insert 'final' Batch Messages and update Billing Cycles
      Gen_Bill.Msg(C_MODULE_REF
                  ,C_MODULE_DESC
                  ,C_ACCO_PROC
                  ,To_Char(l_account_count)
                  ,To_Char(l_accounts_ignored) || ' for Bill Cycle ' || l_bicy.cycle_code
                  );
      /*
        ** If all Master Accounts of the Bill Cycle processed then set
        ** Monthly Fee calculation end date.
      */
      IF (l_accounts_ignored = 0) AND (p_start_maac = 0) THEN -- Only for Full Runs
         UPDATE bill_cycles bicy
            SET bicy.end_package_fees = SYSDATE
         WHERE (bicy.cycle_code = l_bicy.cycle_code);
         --
         update tbcis_processes
            set end_date = sysdate
               ,end_code = 'OK'
         where  module_ref = c_module_ref
         and    upper(module_desc) = upper(C_MODULE_DESC)
         and    module_params = l_bicy.cycle_code;
      ELSIF l_accounts_ignored > 0 THEN
         update tbcis_processes
            set end_date = sysdate
               ,end_code = 'ERR'
         where  module_ref = c_module_ref
         and    upper(module_desc) = upper(C_MODULE_DESC)
         and    module_params = l_bicy.cycle_code;
      END IF;
      --
      IF (Nvl(p_commit, 'Y') = 'Y') THEN
         COMMIT;
      END IF;
   END LOOP;
   ------------------------------------------------------------------------------
   --  END   OF   MAIN   LOOP   TO   PROCESS   BILL  CYCLES.
   ------------------------------------------------------------------------------
   Gen_Bill.Msg(C_MODULE_REF
               ,C_MODULE_DESC
               ,C_NORM_TERM
               ,To_Char(SYSDATE, 'DD.MM.YYYY HH24:MI:SS')
               );
   --
   dbms_application_info.set_client_info(' ');
EXCEPTION
   -------------------------------------------------------------------------------
   -- Process Status: when the Status of BCCU848 cannot be updated or other process
   --                 has already been started.
   -------------------------------------------------------------------------------
   WHEN U_PRC_STAT_ERROR THEN
      Gen_Bill.Msg(C_MODULE_REF
                  ,c_module_desc
                  ,C_GENERAL_ERROR_MSG
                  ,'Process ' || C_MODULE_REF || ' has already been started. ' ||
                   'Cannot run 2 different instances at the same time.'
                  );
   ---------------------------------------------------------------------------------
   -- System Date is before Production Date - Cannot Generate Bills
   ---------------------------------------------------------------------------------
   WHEN u_prod_date_error THEN
      Gen_Bill.Msg(C_MODULE_REF
                  ,c_module_desc
                  ,C_PROD_DATE_ERROR
                  );
      dbms_application_info.set_client_info(' ');
   WHEN e_curr_salp_not_exist THEN
      Gen_Bill.Msg(C_MODULE_REF
                  ,c_module_desc
                  ,C_GENERAL_ERROR_MSG
                  ,'Sales Ledger Period ' || To_Char(SYSDATE, 'Mon YYYY') || ' is not existing!'
                  );
      dbms_application_info.set_client_info(' ');
   WHEN e_missing_parameter THEN
      Gen_Bill.Msg(C_MODULE_REF
                  ,c_module_desc
                  ,C_GENERAL_ERROR_MSG
                  ,'At least 1 mandatory input parameter (Bill Cycle, Start M/A, End M/A) is missing'
                  );
   WHEN e_monthly_ch_not_calc THEN
      Gen_Bill.Msg(C_MODULE_REF
                  ,C_MODULE_DESC
                  ,C_GENERAL_ERROR_MSG
                  ,'Not allowed to run Calculate Package Fees as Monthly Charges have not been created for this Bill Period'
                  );
      dbms_application_info.set_client_info(' ');
   WHEN e_call_disc_not_calc THEN
      Gen_Bill.Msg(C_MODULE_REF
                  ,C_MODULE_DESC
                  ,C_GENERAL_ERROR_MSG
                  ,'Not allowed to run Calculate Package Fees as Call Discounts have not been created for this Bill Period'
                  );
      dbms_application_info.set_client_info(' ');
   WHEN others THEN
      Gen_Bill.Msg(C_MODULE_REF
                  ,C_MODULE_DESC
                  ,C_SQL_ERR
                  ,SQLERRM
                  ,To_Char(SQLCODE)
                  );
      Gen_Bill.Msg(C_MODULE_REF
                  ,C_MODULE_DESC
                  ,C_ERR_TERM
                  ,To_Char(SYSDATE,'DD.MM.YYYY HH24:MI:SS')
                  );
      update tbcis_processes
         set end_date = sysdate
            ,end_code = 'ERR'
      where  module_ref = c_module_ref
      and    upper(module_desc) = upper(C_MODULE_DESC)
      and    module_params is null;
      --
      IF (Nvl(p_commit, 'Y') = 'Y') THEN
         COMMIT;
      END IF;
END Start_Package_Fees;
/****************************************************************************
**
**   Procedure Name:   START_REGTYPE_PACKAGE_FEES
**
**   Description:     . . .
**
*****************************************************************************/
PROCEDURE Start_RegType_Package_Fees (p_start_maac   IN NUMBER   DEFAULT  0
                                     ,p_end_maac     IN NUMBER   DEFAULT  9999999999
                                     ,p_regular_type IN VARCHAR2 DEFAULT 'REPL'
                                     ,p_commit       IN VARCHAR2 DEFAULT 'Y'
) IS
   --
   c_module_desc          CONSTANT bcc_batch_messages.module_desc%TYPE := 'Start_RegType_Package_Fees';

   c_repl_regular_type    CONSTANT VARCHAR2(4)  := 'REPL';
   c_repl_short_code      CONSTANT VARCHAR2(2)  := 'RP';

   c_nonker_module_ref    CONSTANT VARCHAR2(10) := 'BCCU1284NK'; -- Check Mobile Non KER Service Fees

   --
   CURSOR c_module (p_module_ref  VARCHAR2) IS
      SELECT 'Y'
      FROM tbcis_processes
      WHERE module_ref  = p_module_ref
        AND module_desc = c_module_desc
   ;
   --
   CURSOR c_nonker_fees (p_chk_date  DATE) IS
      SELECT 1
      FROM tbcis_processes
      WHERE module_ref = c_nonker_module_ref
        AND end_date > p_chk_date
        AND end_code = 'OK'
   ;
   --
   CURSOR c_salp IS
      SELECT start_date
           , (end_date + 1 - c_one_second) end_date
      FROM sales_ledger_periods
      WHERE date_closed IS NULL
      ORDER BY start_date
   ;
   --
   CURSOR c_invo (p_maac_ref_num  NUMBER
                 ,p_start_date    DATE
                 ,p_end_date      DATE
   ) IS
      SELECT *
      FROM   invoices invo
      WHERE  invo.maac_ref_num = p_maac_ref_num
      AND    invo.billing_inv = 'Y'
      AND    invo.credit = 'N'
      AND    NVL(invo.invoice_type, 'INB') = 'INB'
      AND    invo.period_start >= p_start_date
      AND    invo.period_start <= p_end_date;
   --
   --
   CURSOR c_maac_ref (p_start_date  DATE
                     ,p_end_date    DATE
   ) IS
      SELECT maac_ref_num
      FROM subs_accounts_v suac
      WHERE maac_ref_num BETWEEN p_start_maac AND p_end_maac
        AND EXISTS (select 1
                    from subs_packages           supa
                       , serv_package_types      sept
                       , fixed_charge_item_types fcit
                    where supa.suac_ref_num = suac.ref_num
                      and supa.start_date <= p_end_date
                      and NVL (supa.end_date, p_start_date) >= p_start_date
                      and sept.type_code = supa.sept_type_code
                      and fcit.package_category = sept.category
                      and fcit.sety_ref_num IS NULL
                      and fcit.regular_charge = 'Y'
                      and fcit.pro_rata = 'N'
                      and fcit.once_off = 'N'
                      and fcit.regular_type = 'REPL'
                   )
      ORDER BY maac_ref_num
   ;
   --
   l_c_module_ref         VARCHAR2(10);

   l_found                BOOLEAN;
   l_success              BOOLEAN;
   l_skip_maac            BOOLEAN;
   l_error_text           VARCHAR2(500);
   l_module_registed      VARCHAR2(1);
   l_dummy                NUMBER;
   l_total_count          NUMBER := 0;
   l_processed_count      NUMBER := 0;
   l_proc_start_date      DATE;
   l_salp_start_date      DATE;
   l_salp_end_date        DATE;
   l_current_maac         master_accounts_v.ref_num%TYPE;
   l_invo_rec             invoices%ROWTYPE;
   l_bill_start           DATE;
   l_bill_cutoff          DATE;
   l_prodn_date           DATE;
   --
   e_missing_parameter    EXCEPTION;
   u_proc_start_error     EXCEPTION;
   e_create_invoice       EXCEPTION;
   e_processing_error     EXCEPTION;
   e_unknown_regular_type EXCEPTION;
BEGIN
   --
   l_proc_start_date := SYSDATE;

   /*
     ** Add regular type short code to module ref
   */
   IF p_regular_type = c_repl_regular_type THEN
      -- BCCU848RP
      l_c_module_ref := c_module_ref || c_repl_short_code;
   ELSE
--      DBMS_OUTPUT.put_line('Unknown or missing Regular Type for processing package fees!');
      RAISE e_unknown_regular_type;
   END IF;

   /*
     ** Check if module is already registed in Tbcis Processes table.
   */
   OPEN  c_module (l_c_module_ref);
   FETCH c_module INTO l_module_registed;
   CLOSE c_module;

   IF l_module_registed = 'Y' THEN
      /*
        ** Set process execution time in Tbcis Processes table.
      */
      UPDATE tbcis_processes
         SET start_date = SYSDATE
           , end_code = NULL
           , module_params = NULL
       WHERE  module_ref  = l_c_module_ref
         AND  module_desc = c_module_desc;
   ELSE
      /*
        ** Add module to Tbcis Processes table
      */
      INSERT INTO tbcis_processes (
          module_ref
         ,module_desc
         ,start_date
         ,date_created
         ,created_by
      ) VALUES (
          l_c_module_ref
         ,c_module_desc
         ,SYSDATE
         ,SYSDATE
         ,sec.get_username
      );
   END IF;

   IF Nvl(p_commit,'Y') = 'Y' THEN
      COMMIT;
   END IF;



   DELETE bcc_batch_messages
   WHERE module_ref   = l_c_module_ref
     AND run_by_user  = sec.get_username
     AND message_date < SYSDATE - 5;
   --
   IF Nvl(p_commit, 'Y') = 'Y' THEN
      COMMIT;
   END IF;
   --
   Gen_Bill.Msg(l_c_module_ref
               ,c_module_desc
               ,c_program_start
               ,To_Char(SYSDATE, 'DD.MM.YYYY HH24:MI:SS')
               ,'Params : ' || To_Char(p_start_maac) ||
                        '/' || To_Char(p_end_maac)   ||
                        '/' || p_commit
               );

   --
   IF p_start_maac IS NULL OR p_end_maac IS NULL THEN
      l_error_text := 'At least 1 mandatory input parameter (Start M/A, End M/A) is missing';
      RAISE u_proc_start_error;
   END IF;

   --
   BCC_MISC_PROCESSING.Check_Process_Status (l_success
                                            ,l_c_module_ref);
   IF NOT l_success THEN
      l_error_text := 'Process ' || l_c_module_ref || ' has already been started. ' ||
                      'Cannot run 2 different instances at the same time.';
      RAISE u_proc_start_error;
   END IF;

   BCC_Misc_Processing.Set_Cut_Off_Date     (l_success
                                           ,null
                                           ,l_bill_start             -- OUT DATE
                                           ,l_bill_cutoff            -- OUT DATE 23:59:59
                                           ,l_prodn_date             -- OUT DATE
                                           );

   -- Get current SALP period
   OPEN  c_salp;
   FETCH c_salp INTO l_salp_start_date
                   , l_salp_end_date;
   CLOSE c_salp;





   /*
     ** Cannot run package fees for active billing period.
   */
   IF l_proc_start_date < l_prodn_date  THEN
      l_error_text := 'Cannot run Package fees as Production Date not reached!';
      RAISE u_proc_start_error;
   END IF;


   /*
     ** NonKER service fees must be processed before package fees.
   */
   IF NOT Chk_Proc_Run_In_Period (c_nonker_module_ref  -- p_module_ref IN
                                 ,l_prodn_date      -- p_start_date IN
                                 ,l_proc_start_date    -- p_end_date IN
                                 )
   THEN
      l_error_text := 'Cannot run Package fees as NonKER service fees ('|| c_nonker_module_ref ||') not calculated';
      RAISE u_proc_start_error;
   END IF;


   ----------------------------------------------------------------------------------------
   -- MAIN LOOP - Get all MA accounts that have REPL type package in current SALP period --
   ----------------------------------------------------------------------------------------
   FOR rec IN c_maac_ref (l_salp_start_date, l_salp_end_date) LOOP
      --
      l_current_maac := rec.maac_ref_num;

      /*
        ** Save current maac to tbcis_processes table
      */
      UPDATE tbcis_processes
         SET  module_params = l_current_maac
       WHERE  module_ref  = l_c_module_ref
         AND  module_desc = c_module_desc;
      --
      IF Nvl(p_commit, 'Y') = 'Y' THEN
         COMMIT;
      END IF;


      /*
        ** Get or open debit billing invoice for this period.
      */
      Get_Invoice (l_current_maac
                  ,l_salp_start_date
                  ,l_salp_end_date   -- 23:59:59
                  ,l_success
                  ,l_skip_maac
                  ,l_invo_rec
                  ,l_error_text
                  ,l_c_module_ref        -- IN  VARCHAR2 DEFAULT 'BCCU848'
                  );
      IF NOT l_success THEN
         RAISE e_processing_error;
      END IF;
      --
      IF NOT l_skip_maac THEN
         -- Calculate package fees
         Calculate_Fixed_Charges.Calc_Non_ProRata_Maac_Pkg_Chg (
                                l_current_maac -- IN     accounts.ref_num%TYPE
                               ,NULL   -- p_susg_ref_num IN     subs_serv_groups.ref_num%TYPE
                               ,l_invo_rec.ref_num -- IN     INVOICES.ref_num%TYPE
                               ,l_salp_start_date -- p_period_start IN     DATE
                               ,l_salp_end_date  -- p_period_end   IN     DATE   23:59:59
                               ,l_success         -- OUT BOOLEAN
                               ,l_error_text      -- OUT VARCHAR2
                               ,FALSE
                               ,p_regular_type
                               );
         IF NOT l_success THEN
            RAISE e_processing_error;
         END IF;
         --
         IF Nvl(p_commit, 'Y') = 'Y' THEN
            COMMIT;
         END IF;
         --
         l_processed_count := l_processed_count + 1;
         --
      END IF;
      --
      l_total_count := l_total_count + 1;

   END LOOP;
   ----------------------------------------------------------------------------------------
   -- End MAIN LOOP                                                                      --
   ----------------------------------------------------------------------------------------


   /*
     ** Set process end_date
   */
   UPDATE tbcis_processes
      SET end_date = SYSDATE
        , end_code = 'OK'
       WHERE  module_ref  = l_c_module_ref
         AND  module_desc = c_module_desc;
   --
   IF Nvl(p_commit, 'Y') = 'Y' THEN
      COMMIT;
   END IF;

   Gen_Bill.Msg(l_c_module_ref
               ,c_module_desc
               ,c_maac_count_msg
               ,l_processed_count
               ,(l_total_count - l_processed_count)
               );
   --
   Gen_Bill.Msg(l_c_module_ref
               ,c_module_desc
               ,c_norm_term
               ,To_Char(SYSDATE, 'DD.MM.YYYY HH24:MI:SS')
               );
   --
   dbms_application_info.set_client_info(' ');
EXCEPTION
   WHEN u_proc_start_error THEN
      Gen_Bill.Msg(l_c_module_ref
                  ,c_module_desc
                  ,C_GENERAL_ERROR_MSG
                  ,l_error_text
                  );
      --
      UPDATE tbcis_processes
         SET end_date = SYSDATE
           , end_code = 'ERR'
       WHERE  module_ref  = l_c_module_ref
         AND  module_desc = c_module_desc;
      --
      IF Nvl(p_commit, 'Y') = 'Y' THEN
         COMMIT;
      END IF;
      --
      dbms_application_info.set_client_info(' ');
      --
   WHEN e_processing_error THEN
      Gen_Bill.Msg(l_c_module_ref
                  ,c_module_desc
                  ,C_GENERAL_ERROR_MSG
                  ,l_error_text
                  );
      --
      UPDATE tbcis_processes
         SET end_date = SYSDATE
           , end_code = 'ERR'
           , module_params = l_current_maac
       WHERE  module_ref  = l_c_module_ref
         AND  module_desc = c_module_desc;
      --
      IF Nvl(p_commit, 'Y') = 'Y' THEN
         COMMIT;
      END IF;
      --
      dbms_application_info.set_client_info(' ');
      --
   WHEN OTHERS THEN
      --
      Gen_Bill.Msg(l_c_module_ref
                  ,c_module_desc
                  ,c_sql_err
                  ,SQLERRM
                  ,To_Char(SQLCODE)
                  );
      Gen_Bill.Msg(l_c_module_ref
                  ,c_module_desc
                  ,c_general_error_msg
                  ,'Process ' || l_c_module_ref || ' ended abnormally at '||
                    To_Char(SYSDATE, 'DD.MM.YYYY HH24:MI:SS')||'! '||
                   'Last MAAC '||l_current_maac
                  );
      --
      UPDATE tbcis_processes
         SET end_date = SYSDATE
           , end_code = 'ERR'
           , module_params = l_current_maac
       WHERE  module_ref  = l_c_module_ref
         AND  module_desc = c_module_desc;
      --
      IF Nvl(p_commit, 'Y') = 'Y' THEN
         COMMIT;
      END IF;
      --
      dbms_application_info.set_client_info(' ');
END Start_RegType_Package_Fees;
--
END Main_Monthly_Charges;
/