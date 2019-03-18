CREATE OR REPLACE PACKAGE CLOSE_INTERIM_BILLING_INVOICE IS
   --
   --Reference: BCCU691
   --Purpose:   To create a temporary bill (within a Bill Period).
   --           The Bill Period End Date has not been reached yet.
   --
   --Overview:  This package could be called from a form or a utility.
   --
   --  Procedure Calculate_Interim_Bill() accepts the following input parameters:
   --  1) <p_maac_ref_num> - Master Account reference number. Mandatory.
   --  2) <p_susg_ref_num> - Subscriber Service Group reference number. Optional.
   --  3) <p_bill_cycle>   - Bill Cycle Code. Mandatory.
   --  4) <p_date_run>     - Date of current run. Optional. Defaults to <SYSDATE>.
   --     and returns the following output parameters:
   --  5) <p_maac_balance> - Balance of specified Master Account.
   --  6) <p_susg_balance> - Balance of Subscriber Service Group (if specified).
   --  7) <p_success>      - TRUE if no errors occured otherwise FALSE.
   --  8) <p_err_mesg>     - Error message text if error occured.
   --
   --  In procedure Calculate_Interim_Bill() the following steps are performed:
   --  1. If the utility been called on the same day, it will not calculate
   --     a temporary Bill again. In this case it calculates output balance from
   --       existing data.
   --  2. If the Bill Period is unequal to the open Sales Ledger Period then
   --     the utility cannot be run. (Most likely Billing is running.)
   --  3. Checks if the specified Master Account ise active within current Bill Period.
   --  4. Deletes the data of previous run of the Master Account from tables
   --     INVOICES_INTERIM and INVOICE_ENTRIES_INTERIM.
   --  5. Inserts new values into tables INVOICES_INTERIM and INVOICE_ENTRIES_INTERIM.
   --     The records in tables INVOICES and INVOICE_ENTRIES will be copied into these
   --     temporary tables. If no Invoice existed, a temporary Invoice will be created.
   --  6. If errors occured then an error message will be returned which could be shown
   --     on the screen.
   --
   -- MODIFICATION HISTORY
   -- Module BCCU691
   -- Person      Ver. Date        UPR      Comments
   -- ----------- ---- ----------- -------- ---------------------------------------------------------
   -- A.Jaek      2.19 05.02.2019  DOBAS-1721: Lisatud process.daily_charges.proc_daily_charges_ma väljakutsed
   -- O.Vaiknemets 2.18 27.05.2016 MOBE-545 additional_entry_text
   -- A.Soo       2.17 10.01.2013  CHG-6068 Paketeeritud m??gi seadmete kuutasud
   --                                       Muudetud protseduuri:
   --                                         -- calculate_interim_bill
   --                                         -- insert_interim_inen
   -- I.Jentson   2.16 23.11.2012  CHG-5772 IS-9828 parandatud curr_code t?mist
   -- T.Talvik    2.15 04.06.2012  CHG-5772 IS-9828 v?a kommenteeritud SEC_ v?adega seotud loogika
   -- A.Soo       2.14 19.04.2011  CHG-4899 K?emaks arvutatud 3-kohta peale koma. Eemaldatud EURO-le ?leminemise kood.
   --                                       Eemaldatud:
   --                                         -- inin_recalc_metadata_t
   --                                         -- inin_recalc_metadata
   --                                       Muudetud protseduure:
   --                                         -- inin_totals
   --                                         -- rounding_invoices
   --                                         -- calc_interim_totals
   --                                         -- calc_interim_taxes
   -- K.Peil      2.13 10.12.2010  CHG4783, IS-6841: ROUNDING_INVOICES, CALC_TAXES ja CALC_TOTALS realiseeritud eurole
   --                                       ?lemineku perioodi arvete k?tlus. Parandatud ?mardamisel n?utava EUR
   --                                       kogusumma leidmine.
   -- K.Peil      2.12 13.08.2010  CHG4594, IS-5573: Muudetud alamprogramme:
   --                                       - INSERT_INTERIM_INEN, lisatud valuutakoodide sisestamine ja realiseeritud
   --                                         summa sisendi lugemine INEN.ACC_AMOUNT v?alt
   --                                       - CRE_UPD_INTERIM_INEN, realiseeritud summa DML sisendi koostamine
   --                                         INEN.ACC_AMOUNT v?ale
   --                                       - CREATE_INTERIM_ROAMING_MARKUP, realiseeritud summa DML sisendi koostamine
   --                                         INEN.ACC_AMOUNT v?ale
   --                                       - ROUNDING_INVOICES, realiseeritud ?mardusrea valuutap?hine koostamine
   -- A.Soo       2.11 23.04.2009  CHG-3714 Muudetud protseduuri: calculate_interim_bill
   -- A.Soo       2.10 14.08.2008  CHG-3180 Lisandusid paketeeritud teenuspakettide paketitasud protseduuri 'calculate_interim_bill'
   -- A.Soo        2.9 31.03.2008  CHG-2833 Eemaldatud 'create_interim_roaming_markup' v?akutse protseduurist calculate_interim_bill.
   -- A.Mestserski 2.8 14.02.2008  CHG-2716 Panin ?ige versioon ja tegin muudatused CHG-2580 uuesti
   -- A.Mestserski 2.7 24.01.2008  CHG-2580 Vahetatud 3-es kohas CHG-498 ja CHG-69 lisatud koodi blokkide j?estus:
   --                                       Esmalt k?itatakse CHG-498, seej?l CHG-69
   -- S.Sokk      2.6  27.06.2007  CHG-2110 Replaced USER with sec.get_username
   -- A.Soo       2.5  16.04.2007  CHG-1174 Eemaldatud vana GKP k?neposti konstant 'bcc_discount_percentage_kp'
   -- M.Teino     2.4  20.03.2006  CHG-776  eemaldasin eesti kroonide kirjutamise ..._CURR v?adesse,
   --                                       samuti eemaldasin 'EEK'-v?tuse kirjutamise CURR_CODE v?ale
   --                                       PROCEDURE create_interim_roaming_markup, cre_upd_interim_inen, calc_interim_taxes, rounding_invoices, calc_interim_totals -
   --                                       rahav?ade ?mardamine kahe komakohani
   -- U.Aarna     2.3  14.12.2005  CHG-499  Detail Bill kasutus kustutatud.
   -- U.Aarna     2.2  02.12.2005  CHG-498  Lisatud p?ade arvust s?ltumatute (non-prorata) teenuse kuutasude arvutus.
   -- U.Aarna     2.1  21.04.2005  CHG-69   Lisatud p?ade arvust s?ltumatu (non-prorata) paketi kuutasude arvutus.
   --                                       Muudetud protseduuri Calculate_Interim_Bill.
   -- H.Luhasalu  2.0  20.05.2004  3031     K?emaksuta MA'd
   -- I.Reeder    1.10 08.10.2003  2757     Tabelist Interim_invoice kustutatud v? payment_plan_status
   -- I.Reeder    1.9  17.01.2003  2427     Roaming MarkUp
   -- H.Luhasalu  1.8  10.09.2002  2273     likvideeritud tabel first_ssg_statuses
   -- U.Aarna     1.7  02.05.2002  2150     If p_susg_ref_num given then calculate invoice entries
   --                                       only for given susg.
   -- H.Luhasalu                            Upr1991-lisatud inei:cadc_ref_num ja fcdt_type_code
   -- H.Luhasalu  1.6  17.08.2001  1913     Lisatud INP sulgemisel saadud kuumaksud.
   -- M.Sabul     1.5  25.05.2001  1805     Lisatud Cre_Upd_Interim_Inen -i parameeter p_maas_ref_num,
   --                                       Invoice_Entries_INterim tabelisse uus v? maas_ref_num
   --                                       ,Insert_Interim_Inen
   -- M.Kampus                              GPRS jaoks v? evre_data_volume
   -- M.Sabul     1.4  04.05.2001  1508     Lisatud v?akutse Calculate_Fixed_charges.
   --                                       Main_Master_service_charges
   -- H.Luhasalu  1.3  26.04.2001  1771     Lisatud protseduuri Calculate_Interim_Balances
   --                                       arvel mitte olevad, kuid hinnatud k?ned.
   -- H.Luhasalu  1.2  01.04.2001  1667     Arvestab eelmise perioodi hindamata,
   --                                       jooksva perioodi hindamata,saadetud
   --                                       vahearveid jooksvas perioodis ei n?a.
   -- H.Luhasalu  1.1  17.02.2001  1649     Kasutab calculate_fixed_charge protseduure.
   --                                       Muudetud: close_invoice.
   --                                       Kustutatud mittekasutatavad protseduurid.
   -------------------------------------------------------------------------------------------
   -- Virgo        1.0  12.12.2000  Removed redundant code. Minor fixes.
   --        Tax Calculation <Calc_Interim_Taxes()> made compatible with Main Bill.
   --        Added Rounding Invoice Entry generation code <Rounding_Invoices()>
   --        to the end of Close Invoice <Close_Invoice()>.
   --        Removed unneccessary run modes and the corresponding code.
   --       * Merged packages: Close_Billing_Inv and Calculate_Temp_Bill.
   --       * Tables: INVOICES_TEMP, INVOICE_ENTRIES_TEMP
   --         Sequences: INVO_REF_NUM_TEMP_S, INEN_REF_NUM_TEMP_S.
   --       * Procedure Close_Interim_Billing_Invoice.Calculate_Interim_Bill() accepts
   --         <p_susg_ref_num> as an input parameter and returns <p_maac_balance>
   --         and <p_susg_balance> as output parameters.
   --       * If bill already calculated on current date, calculates balances from
   --         existing data.
   --       * Added procedure Calculate_Interim_Bill().
   --       * Several optimizations.
   --
   -- U.Aarna      1.0      30.08.2000  Error corrected.
   --
   -- G.Ruijs      1.0      14.07.2000  Initial version.
   --
   c_emt_registration_date CONSTANT DATE := TRUNC (TO_DATE (get_system_parameter (84), 'DD.MM.RRRR HH24:MI:SS'));
   --
   bcc_sql_err          CONSTANT NUMBER := 142;
   bcc_sql_values       CONSTANT NUMBER := 158;
   bcc_err_calc_days    CONSTANT NUMBER := 222;
   bcc_sql_rollback     CONSTANT NUMBER := 143;
   bcc_err_roaming      CONSTANT NUMBER := 170;
   bcc_err_det_bill     CONSTANT NUMBER := 433;
   --
   bcc_roaming          CONSTANT VARCHAR2 (3) := 'M5';   -- UPR-1474
   bcc_detail_bill      CONSTANT VARCHAR2 (3) := 'ED';   -- UPR-1474
   --
   g_prov_bill_ref_num           NUMBER;

   --
   FUNCTION get_fixed_charge (
      p_invo_end_date   IN      DATE
     ,p_chca_type_code  IN      VARCHAR2
     ,p_bill_sel        IN      VARCHAR2
     ,p_value           OUT     NUMBER
     ,p_fcit_code       OUT     VARCHAR2
     ,p_taty_type_code  OUT     VARCHAR2
     ,p_err_mesg        OUT     VARCHAR2
   )
      RETURN BOOLEAN;

   --
   PROCEDURE cre_upd_interim_inen (
      p_success         OUT     BOOLEAN
     ,p_err_mesg        OUT     VARCHAR2
     ,p_invo_ref_num    IN      NUMBER
     ,p_fcit_type_code  IN      VARCHAR2
     ,p_bill_sel        IN      VARCHAR2
     ,p_tax_type        IN      VARCHAR2
     ,p_fixed_amount    IN      NUMBER
     ,p_num_of_days     IN      NUMBER
     ,p_susg_ref_num    IN      NUMBER
     ,p_maas_ref_num    IN      NUMBER DEFAULT NULL
   );

   --
   PROCEDURE calc_interim_taxes (
      p_success       OUT  BOOLEAN
     ,p_err_mesg      OUT  VARCHAR2
     ,p_invo_ref_num       invoices.ref_num%TYPE
   );

   --
   PROCEDURE calc_interim_totals (
      p_success       OUT     BOOLEAN
     ,p_err_mesg      OUT     VARCHAR2
     ,p_invo_details  IN OUT  invoices%ROWTYPE
   );

   --
   PROCEDURE calculate_interim_balances (
      p_maac_ref_num  IN      NUMBER
     ,p_susg_ref_num  IN      NUMBER
     ,p_invo_ref_num  IN      NUMBER
     ,p_maac_balance  OUT     NUMBER
     ,p_susg_balance  OUT     NUMBER
   );

   --
   PROCEDURE calculate_interim_bill (
      p_maac_ref_num      IN      NUMBER
     ,p_susg_ref_num      IN      NUMBER
     ,p_date_run          IN      DATE
     ,p_maac_balance      OUT     NUMBER
     ,p_susg_balance      OUT     NUMBER
     ,p_success           OUT     BOOLEAN
     ,p_err_mesg          OUT     VARCHAR2
     ,p_calc_monthly_chg  IN      BOOLEAN DEFAULT TRUE
   );

   --
   PROCEDURE insert_interim_invo (
      p_invo  IN OUT NOCOPY  invoices%ROWTYPE
   );

   --
   PROCEDURE insert_interim_inen (
      p_inve  IN OUT NOCOPY  invoice_entries%ROWTYPE
   );
--
END close_interim_billing_invoice;
/

CREATE OR REPLACE PACKAGE BODY CLOSE_INTERIM_BILLING_INVOICE IS
   --
   --Module BCCU691
   --


   -- CHG4783
   TYPE inin_totals_t IS RECORD (
      pri_amt_sum                   invoice_entries_interim.eek_amt%TYPE
     ,pri_tax_sum                   invoice_entries_interim.amt_tax%TYPE
   );


   -- CHG4594
   FUNCTION inin_totals (
      p_inin_ref_num           IN  invoices.ref_num%TYPE
     ,p_include_rounding_inei  IN  BOOLEAN := TRUE
   )
      RETURN inin_totals_t IS
      --
      CURSOR c_inin_totals (
         p_inin_ref_num                IN  invoices.ref_num%TYPE
        ,p_include_rounding_inei_flag  IN  NUMBER
      ) IS
         SELECT NVL (SUM (inei.eek_amt), 0) AS pri_amt_sum
               ,NVL (SUM (inei.amt_tax), 0) AS pri_tax_sum
           FROM invoice_entries_interim inei
          WHERE inei.invo_ref_num = p_inin_ref_num
            AND ( p_include_rounding_inei_flag = 1
                  OR NOT ( inei.rounding_indicator = 'Y'
                           AND inei.eek_amt = 0
                           AND NVL (inei.amt_in_curr, 0) = 0
                          )
                );


      l_inin_totals                 inin_totals_t;
   BEGIN
      OPEN c_inin_totals (p_inin_ref_num                    => p_inin_ref_num
                         ,p_include_rounding_inei_flag      => (CASE
                                                                   WHEN p_include_rounding_inei THEN 1
                                                                   ELSE 0
                                                                END)
                         );

      FETCH c_inin_totals
       INTO l_inin_totals.pri_amt_sum
           ,l_inin_totals.pri_tax_sum;

      CLOSE c_inin_totals;

      RETURN l_inin_totals;
   END inin_totals;

   --
   PROCEDURE insert_interim_invo (
      p_invo  IN OUT NOCOPY  invoices%ROWTYPE
   ) IS
   BEGIN
      SELECT invo_ref_num_interim_s.NEXTVAL
        INTO p_invo.ref_num
        FROM SYS.DUAL;

      --dbms_output.put_line('invo seq:'||to_char(p_invo.ref_num));
      p_invo.created_by := sec.get_username;
      p_invo.date_created := SYSDATE;

      --dbms_output.put_line('inserdin:'||to_char(p_invo.ref_num));
      INSERT INTO invoices_interim invo
                  (invo.ref_num   -- NOT NULL NUMBER(10)
                  ,invo.invoice_number   -- NOT NULL VARCHAR2(10)
                  ,invo.maac_ref_num   -- NOT NULL NUMBER(10)
                  ,invo.total_amt   -- NOT NULL NUMBER(14,2)
                  ,invo.total_vat   -- NOT NULL NUMBER(14,2)
                  ,invo.outstanding_amt   -- NOT NULL NUMBER(14,2)
                  ,invo.created_by   -- NOT NULL VARCHAR2(15)
                  ,invo.date_created   -- NOT NULL DATE
                  ,invo.credit   -- NOT NULL VARCHAR2(1)
                  ,invo.billed   -- NOT NULL VARCHAR2(1)
                  ,invo.billing_inv   -- NOT NULL VARCHAR2(1)
                  ,invo.print_req   -- NOT NULL VARCHAR2(1)
                  ,invo.stat_ref_num   --          NUMBER(10)
                  ,invo.due_date   --          DATE
                  ,invo.salp_fina_year   --          NUMBER(4)
                  ,invo.salp_per_num   --          NUMBER(2)
                  ,invo.invoice_date   --          DATE
                  ,invo.period_start   --          DATE
                  ,invo.period_end   --          DATE
                  ,invo.date_printed   --          DATE
                  ,invo.last_updated_by   --          VARCHAR2(15)
                  ,invo.date_updated   --          DATE
                  ,invo.sully_paid   --          DATE
                  ,invo.fully_paid   --          DATE
                  ,invo.bicy_cycle_code   --          VARCHAR2(3)
                  ,invo.invo_sequence   -- NOT NULL NUMBER(11)
                  ,invo.curr_code
                  )
           VALUES (p_invo.ref_num
                  ,p_invo.invoice_number
                  ,p_invo.maac_ref_num
                  ,p_invo.total_amt
                  ,p_invo.total_vat
                  ,p_invo.outstanding_amt
                  ,p_invo.created_by
                  ,p_invo.date_created
                  ,p_invo.credit
                  ,p_invo.billed
                  ,p_invo.billing_inv
                  ,p_invo.print_req
                  ,p_invo.stat_ref_num
                  ,p_invo.due_date
                  ,p_invo.salp_fina_year
                  ,p_invo.salp_per_num
                  ,p_invo.invoice_date
                  ,p_invo.period_start
                  ,p_invo.period_end
                  ,p_invo.date_printed
                  ,p_invo.last_updated_by
                  ,p_invo.date_updated
                  ,p_invo.sully_paid
                  ,p_invo.fully_paid
                  ,p_invo.bicy_cycle_code
                  ,p_invo.invo_sequence
                  ,get_pri_curr_code()
                  );
   END insert_interim_invo;

   --
   PROCEDURE insert_interim_inen (
      p_inve  IN OUT NOCOPY  invoice_entries%ROWTYPE
   ) IS
   BEGIN
      --dbms_output.put_line('soovin insertida invoice_entries_interim-i'||to_char(p_inve.ref_num));
      SELECT inen_ref_num_interim_s.NEXTVAL
        INTO p_inve.ref_num
        FROM SYS.DUAL;

      p_inve.created_by := sec.get_username;
      p_inve.date_created := SYSDATE;
      p_inve.acc_amount := ROUND (p_inve.acc_amount, get_inen_acc_precision);   -- CHG4594
      p_inve.sec_acc_amount := ROUND (p_inve.sec_acc_amount, get_inen_acc_precision);   -- CHG4594
      p_inve.eek_amt := ROUND (p_inve.acc_amount, 2);   -- CHG4594

      IF p_inve.rounding_indicator = 'Y' THEN
         p_inve.sec_amt := ROUND (p_inve.sec_acc_amount, 2);   -- CHG4594
      END IF;

      INSERT INTO invoice_entries_interim inve
                  (ref_num   --NOT NULL NUMBER(10)
                  ,invo_ref_num   --NOT NULL NUMBER(10)
                  ,eek_amt   --NOT NULL NUMBER(14,2)
                  ,amt_in_curr   -- CHG4594
                  ,rounding_indicator   --NOT NULL VARCHAR2(1)
                  ,under_dispute   --NOT NULL VARCHAR2(1)
                  ,created_by   --NOT NULL VARCHAR2(15)
                  ,date_created   --NOT NULL DATE
                  ,billing_selector   --         VARCHAR2(3)
                  ,fcit_type_code   --         VARCHAR2(3)
                  ,taty_type_code   --         VARCHAR2(3)
                  ,susg_ref_num   --         NUMBER(10)
                  ,iadn_ref_num   --         NUMBER(10)
                  ,vmct_type_code   --         VARCHAR2(3)
                  ,last_updated_by   --         VARCHAR2(15)
                  ,date_updated   --         DATE
                  ,description   --         VARCHAR2(60)
                  ,amt_tax   --         NUMBER(14,2)
                  ,manual_entry   --         VARCHAR2(1)
                  ,evre_count   --         NUMBER
                  ,evre_duration   --         NUMBER
                  ,module_ref   --         VARCHAR2(4)
                  ,fixed_charge_value   --         NUMBER(11,2)
                  ,evre_char_usage   --         NUMBER
                  ,print_required   --         VARCHAR2(1)
                  ,vmct_rate_value   --         NUMBER(5,2)
                  ,num_of_days   --         NUMBER(2)
                  ,maas_ref_num
                  ,evre_data_volume
                  ,cadc_ref_num
                  ,fcdt_type_code
                  ,curr_code   -- CHG4594
                  --,sec_curr_code   -- CHG4594
				  ,additional_entry_text --MOBE-545
                  )
           VALUES (p_inve.ref_num
                  ,p_inve.invo_ref_num
                  ,p_inve.eek_amt
                  ,p_inve.sec_amt   -- CHG4594
                  ,p_inve.rounding_indicator
                  ,p_inve.under_dispute
                  ,p_inve.created_by
                  ,p_inve.date_created
                  ,p_inve.billing_selector
                  ,p_inve.fcit_type_code
                  ,p_inve.taty_type_code
                  ,p_inve.susg_ref_num
                  ,p_inve.iadn_ref_num
                  ,p_inve.vmct_type_code
                  ,p_inve.last_updated_by
                  ,p_inve.date_updated
                  ,p_inve.description
                  ,p_inve.amt_tax
                  ,p_inve.manual_entry
                  ,p_inve.evre_count
                  ,p_inve.evre_duration
                  ,p_inve.module_ref
                  ,p_inve.fixed_charge_value
                  ,p_inve.evre_char_usage
                  ,p_inve.print_required
                  ,p_inve.vmct_rate_value
                  ,p_inve.num_of_days
                  ,p_inve.maas_ref_num
                  ,p_inve.evre_data_volume
                  ,p_inve.cadc_ref_num
                  ,p_inve.fcdt_type_code
                  ,Nvl(p_inve.pri_curr_code, get_pri_curr_code())   -- CHG4594 / CHG-6068
                  --,Nvl(p_inve.sec_curr_code, get_sec_curr_code())   -- CHG4594 / CHG-6068
				  ,p_inve.additional_entry_text --MOBE-545
                  );
   --dbms_output.put_line('l?petasin num of days:'||to_char(p_inve.num_of_days));
   END insert_interim_inen;

   --
   --
   PROCEDURE cre_upd_interim_inen (
      p_success         OUT     BOOLEAN
     ,p_err_mesg        OUT     VARCHAR2
     ,p_invo_ref_num    IN      NUMBER
     ,p_fcit_type_code  IN      VARCHAR2
     ,p_bill_sel        IN      VARCHAR2
     ,p_tax_type        IN      VARCHAR2
     ,p_fixed_amount    IN      NUMBER
     ,p_num_of_days     IN      NUMBER
     ,p_susg_ref_num    IN      NUMBER
     ,p_maas_ref_num    IN      NUMBER DEFAULT NULL
   ) IS
      l_inve                        invoice_entries%ROWTYPE;
   BEGIN
      l_inve.invo_ref_num := p_invo_ref_num;
      l_inve.acc_amount := ROUND (NVL (p_fixed_amount, 0), get_inen_acc_precision);   -- CHG4594
      l_inve.eek_amt := ROUND (l_inve.acc_amount, 2);   -- CHG4594
      l_inve.rounding_indicator := 'N';
      l_inve.under_dispute := 'N';
      l_inve.billing_selector := p_bill_sel;
      l_inve.fcit_type_code := p_fcit_type_code;
      l_inve.taty_type_code := p_tax_type;
      l_inve.susg_ref_num := p_susg_ref_num;
      l_inve.manual_entry := 'N';
      l_inve.num_of_days := NVL (p_num_of_days, 0);
      l_inve.maas_ref_num := p_maas_ref_num;

      -- upr-1128 V3.16
      SELECT /*+RULE*/
             MIN (inve.ref_num)
        INTO l_inve.ref_num
        FROM invoice_entries_interim inve
       WHERE (inve.invo_ref_num = l_inve.invo_ref_num)
         AND (NVL (inve.susg_ref_num, 0) = NVL (l_inve.susg_ref_num, 0))
         AND (NVL (inve.maas_ref_num, 0) = NVL (l_inve.maas_ref_num, 0))
         AND (UPPER (inve.fcit_type_code) = l_inve.fcit_type_code)
         AND (inve.manual_entry = l_inve.manual_entry);

      IF (l_inve.ref_num IS NULL) THEN
         insert_interim_inen (l_inve);
      ELSE
         UPDATE invoice_entries_interim inve
            SET inve.eek_amt = ROUND (inve.eek_amt + l_inve.eek_amt, 2)
               ,inve.num_of_days = NVL (inve.num_of_days, 0) + l_inve.num_of_days
          WHERE (ref_num = l_inve.ref_num);
      END IF;

      p_success := TRUE;
      p_err_mesg := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_err_mesg := SUBSTR (   ('Cre_Upd_Interim_INEN Invoice: ' || TO_CHAR (p_invo_ref_num) || 'Susg: ')
                               || (TO_CHAR (p_susg_ref_num) || SQLERRM)
                              ,1
                              ,200
                              );
   END cre_upd_interim_inen;

   --
   --
   FUNCTION get_fixed_charge (
      p_invo_end_date   IN      DATE
     ,p_chca_type_code  IN      VARCHAR2
     ,p_bill_sel        IN      VARCHAR2
     ,p_value           OUT     NUMBER
     ,p_fcit_code       OUT     VARCHAR2
     ,p_taty_type_code  OUT     VARCHAR2
     ,p_err_mesg        OUT     VARCHAR2
   )
      RETURN BOOLEAN IS
      CURSOR c_fixed_charge IS
         SELECT --+RULE
                ficv.charge_value ficv_charge_value
               ,fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit
          WHERE (TRUNC (p_invo_end_date) BETWEEN ficv.start_date AND NVL (ficv.end_date, TRUNC (p_invo_end_date)))
            AND (ficv.chca_type_code = p_chca_type_code)
            AND (ficv.fcit_charge_code = fcit.type_code)
            AND (fcit.billing_selector = p_bill_sel)
            AND (fcit.regular_charge = 'Y')
            AND (fcit.pro_rata = 'N')
            AND (fcit.once_off = 'N')   -- UPR-769 v3.1
                                     ;

      e_fcit                        EXCEPTION;
   BEGIN
      OPEN c_fixed_charge;

      FETCH c_fixed_charge
       INTO p_value
           ,p_fcit_code
           ,p_taty_type_code;

      IF c_fixed_charge%NOTFOUND THEN
         CLOSE c_fixed_charge;

         RAISE e_fcit;
      END IF;

      CLOSE c_fixed_charge;

      p_err_mesg := NULL;
      RETURN TRUE;
   EXCEPTION
      WHEN e_fcit THEN
         p_err_mesg := SUBSTR (   'Get_Fixed_Charge: can NOT retrieve Fixed Charge for '
                               || p_bill_sel
                               || '/Charg. Cat: '
                               || p_chca_type_code
                              ,1
                              ,200
                              );
         RETURN FALSE;
      WHEN OTHERS THEN
         p_err_mesg := SUBSTR ('Get_Fixed_Charge: error ' || SQLERRM, 1, 200);
         RETURN FALSE;
   END get_fixed_charge;

   --
   PROCEDURE create_interim_roaming_markup (
      p_success        OUT     BOOLEAN
     ,p_err_mesg       OUT     VARCHAR2
     ,p_invo_ref_num   IN      NUMBER
     ,p_invo_end_date  IN      DATE
   ) IS
      CURSOR c_roaming_events IS
         SELECT   /*+RULE*/
                  SUM (inen.eek_amt) sum_eek
                 ,inen.susg_ref_num susg_ref_num
                 ,susg.chca_type_code chca_type_code
             FROM invoice_entries_interim inen, invoices_interim invo, subs_serv_groups susg
            WHERE (invo.ref_num = p_invo_ref_num)
              AND (invo.ref_num = inen.invo_ref_num)
              AND (inen.fcit_type_code IS NULL)
              AND (inen.vmct_type_code IS NULL)
              AND (inen.rounding_indicator = 'N')
              AND (inen.eek_amt >= 1)
              AND (susg.ref_num = inen.susg_ref_num)
              AND (inen.billing_selector IN (SELECT evty.billing_selector   --Upr2427
                                               FROM event_types evty
                                              WHERE roaming = 'Y' AND calc_roaming_markup = 'Y'
                                                                                               -- kui Inen olemas, siis tuleb ka arvutada olenemata EVTY End-ist
                   ))
         GROUP BY inen.susg_ref_num, susg.chca_type_code;

      l_value                       NUMBER;
      l_fcit_code                   fixed_charge_item_types.type_code%TYPE;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      u_err_no_markup               EXCEPTION;
      l_prev_chca_type_code         subs_serv_groups.chca_type_code%TYPE;
      l_err_mesg                    VARCHAR2 (200);
      l_inve                        invoice_entries%ROWTYPE;
   BEGIN
      l_prev_chca_type_code := NULL;

      FOR c_rec_events IN c_roaming_events LOOP
         IF (l_prev_chca_type_code IS NULL) OR (l_prev_chca_type_code <> c_rec_events.chca_type_code) THEN
            IF NOT get_fixed_charge (p_invo_end_date
                                    ,c_rec_events.chca_type_code
                                    ,bcc_roaming
                                    ,l_value
                                    ,l_fcit_code
                                    ,l_taty_type_code
                                    ,l_err_mesg
                                    ) THEN
               RAISE u_err_no_markup;
            END IF;

            l_prev_chca_type_code := c_rec_events.chca_type_code;
         END IF;

         l_inve.invo_ref_num := p_invo_ref_num;
         l_inve.acc_amount := ROUND (NVL (c_rec_events.sum_eek, 0) * l_value / 100, get_inen_acc_precision);   -- CHG4594
         l_inve.rounding_indicator := 'N';
         l_inve.under_dispute := 'N';
         l_inve.billing_selector := bcc_roaming;
         l_inve.fcit_type_code := l_fcit_code;
         l_inve.taty_type_code := l_taty_type_code;
         l_inve.susg_ref_num := c_rec_events.susg_ref_num;
         l_inve.manual_entry := 'N';
         insert_interim_inen (l_inve);
      END LOOP;

      p_success := TRUE;
      p_err_mesg := NULL;
   EXCEPTION
      WHEN u_err_no_markup THEN
         ROLLBACK;
         p_err_mesg := l_err_mesg;
         p_success := FALSE;
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_err_mesg := SUBSTR ('Roaming Markup: ' || SQLERRM, 1, 200);
   END create_interim_roaming_markup;

   --
   PROCEDURE calc_interim_taxes (
      p_success       OUT  BOOLEAN
     ,p_err_mesg      OUT  VARCHAR2
     ,p_invo_ref_num       invoices.ref_num%TYPE
   ) IS
      c_sysdate            CONSTANT DATE := SYSDATE;

      CURSOR c_maac IS
         SELECT maac_ref_num
           FROM invoices_interim
          WHERE ref_num = p_invo_ref_num;

      CURSOR c_tax (
         p_maac  NUMBER
      ) IS
         SELECT tax_code
           FROM maac_receipts_tax
          WHERE maac_ref_num = p_maac AND SYSDATE BETWEEN start_date AND NVL (end_date, SYSDATE) AND ROWNUM = 1;

      l_tax                         VARCHAR2 (1);
      l_maac_ref_num                accounts.ref_num%TYPE;
   BEGIN
      p_success := FALSE;
      p_err_mesg := NULL;

      OPEN c_maac;

      FETCH c_maac
       INTO l_maac_ref_num;

      CLOSE c_maac;

      OPEN c_tax (l_maac_ref_num);

      FETCH c_tax
       INTO l_tax;

      CLOSE c_tax;

      l_tax := NVL (l_tax, 'S');

      IF (p_invo_ref_num IS NOT NULL) THEN

         UPDATE invoice_entries_interim inen
            SET amt_tax = (SELECT ROUND (inen.eek_amt * NVL (tara.rate_value, 0) / 100, 3)  -- CHG-4899: Round(,3)
                             FROM tax_types taty, tax_rates tara
                            WHERE taty.tax_type_code = DECODE (inen.taty_type_code, 'S', l_tax, inen.taty_type_code)
                              AND tara.taty_type_code = taty.tax_type_code
                              AND SYSDATE BETWEEN tara.start_date AND NVL (tara.end_date, SYSDATE))
               ,taty_type_code = DECODE (inen.taty_type_code, 'S', l_tax, inen.taty_type_code)
          WHERE (inen.invo_ref_num = p_invo_ref_num);

      END IF;

      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         p_err_mesg := SUBSTR ('Calc_Taxes: can NOT add the Tax: ' || SQLERRM, 1, 200);
   END calc_interim_taxes;

   --
   PROCEDURE calc_interim_totals (
      p_success       OUT     BOOLEAN
     ,p_err_mesg      OUT     VARCHAR2
     ,p_invo_details  IN OUT  invoices%ROWTYPE
   ) IS
      l_inin_totals        CONSTANT inin_totals_t := inin_totals (p_invo_details.ref_num);
   BEGIN
      p_invo_details.total_amt := l_inin_totals.pri_amt_sum;
      p_invo_details.total_vat := l_inin_totals.pri_tax_sum;

      ----------------------------------------------------------------
      -- This UPDATE 'closes' the Invoice. Closing an Invoice means
      -- Calculating all the Totals, AND setting the PERIOD_END Date.
      UPDATE invoices_interim invo
         SET invo.total_amt = ROUND (NVL (p_invo_details.total_amt, 0), 2)
            ,invo.total_vat = ROUND (NVL (p_invo_details.total_vat, 0), 2)
            ,invo.outstanding_amt = ROUND (NVL (p_invo_details.total_amt, 0) + NVL (p_invo_details.total_vat, 0), 2)
            ,invo.period_end = p_invo_details.invoice_date
            ,invo.invoice_date = p_invo_details.invoice_date
       WHERE (invo.ref_num = p_invo_details.ref_num);

      ----------------------------------------------------------------
      p_success := TRUE;
      p_err_mesg := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_err_mesg := SUBSTR ('Calc_Totals invoice: ' || TO_CHAR (p_invo_details.ref_num) || '/' || SQLERRM, 1, 200);
   END calc_interim_totals;

   ---------------------------------------------------------------------------------------------------------------------
/*   PROCEDURE rounding_invoices (   -- CHG4783: realiseeritud analoogselt BCC_CALC.ROUNDING_INVOICES-le.
      p_success               OUT     BOOLEAN
     ,p_err_mesg              OUT     VARCHAR2
     ,p_inin_ref_num          IN      invoices.ref_num%TYPE
     ,p_process_eek_rounding  IN      BOOLEAN := TRUE
     ,p_process_eur_rounding  IN      BOOLEAN := TRUE
   ) IS
      l_pri_curr_code      CONSTANT invoices_interim.curr_code%TYPE := get_pri_curr_code;
      l_sec_curr_code      CONSTANT invoices_interim.sec_curr_code%TYPE := get_sec_curr_code;
      l_inin_recalc_metadata        inin_recalc_metadata_t := inin_recalc_metadata (p_inin_ref_num => p_inin_ref_num);
      l_inin_totals                 inin_totals_t
                                     := inin_totals (p_inin_ref_num               => p_inin_ref_num
                                                    ,p_include_rounding_inei      => TRUE);
      --
      l_pri_rounding_amt            invoice_entries_interim.eek_amt%TYPE := 0;
      l_sec_rounding_amt            invoice_entries_interim.amt_in_curr%TYPE := 0;
      --
      l_old_outstanding_amt         invoices_interim.total_amt_curr%TYPE;
      l_old_sec_outstanding_amt     invoices_interim.sec_outstanding_amt%TYPE;

      --
      PROCEDURE process_eek_rounding (
         p_pri_curr_code     IN             invoice_entries_interim.curr_code%TYPE
        ,p_sec_curr_code     IN             invoice_entries_interim.sec_curr_code%TYPE
        ,p_inin_totals       IN OUT NOCOPY  inin_totals_t
        ,p_pri_rounding_amt  IN OUT NOCOPY  invoice_entries_interim.eek_amt%TYPE
        ,p_sec_rounding_amt  IN OUT NOCOPY  invoice_entries_interim.amt_in_curr%TYPE
      ) IS
         l_pri_rounding_amt            invoice_entries_interim.eek_amt%TYPE := 0;
         l_sec_rounding_amt            invoice_entries_interim.amt_in_curr%TYPE := 0;
         --
         l_eek_rounding_inen           invoice_entries%ROWTYPE;
      BEGIN
         IF p_pri_curr_code = 'EEK' THEN
            l_pri_rounding_amt := gen_bill.eek_rounding_amount (p_eek_amount      => (  p_inin_totals.pri_amt_sum
                                                                                      + p_inin_totals.pri_tax_sum
                                                                                     )
                                                               );
            p_pri_rounding_amt := p_pri_rounding_amt + l_pri_rounding_amt;
         ELSE
            l_sec_rounding_amt := gen_bill.eek_rounding_amount (p_eek_amount      => (  p_inin_totals.sec_amt_sum
                                                                                      + p_inin_totals.sec_tax_sum
                                                                                     )
                                                               );
            p_sec_rounding_amt := p_sec_rounding_amt + l_sec_rounding_amt;
         END IF;

         IF (l_pri_rounding_amt != 0) OR (l_sec_rounding_amt != 0) THEN
            l_eek_rounding_inen.invo_ref_num := p_inin_ref_num;
            l_eek_rounding_inen.acc_amount := l_pri_rounding_amt;
            l_eek_rounding_inen.sec_acc_amount := l_sec_rounding_amt;
            l_eek_rounding_inen.rounding_indicator := 'Y';
            l_eek_rounding_inen.under_dispute := 'N';
            l_eek_rounding_inen.amt_tax := 0;
            l_eek_rounding_inen.manual_entry := 'N';
            l_eek_rounding_inen.pri_curr_code := l_pri_curr_code;
            l_eek_rounding_inen.sec_curr_code := l_sec_curr_code;
            insert_interim_inen (l_eek_rounding_inen);
         END IF;
      END process_eek_rounding;

      --
      PROCEDURE process_eur_rounding (
         p_pri_curr_code     IN             invoice_entries.pri_curr_code%TYPE
        ,p_sec_curr_code     IN             invoice_entries.sec_curr_code%TYPE
        ,p_inin_totals       IN             inin_totals_t
        ,p_pri_rounding_amt  IN OUT NOCOPY  invoice_entries_interim.eek_amt%TYPE
        ,p_sec_rounding_amt  IN OUT NOCOPY  invoice_entries_interim.amt_in_curr%TYPE
      ) IS
         l_pri_rounding_amt            invoice_entries_interim.eek_amt%TYPE := 0;
         l_sec_rounding_amt            invoice_entries_interim.amt_in_curr%TYPE := 0;
         --
         l_eur_rounding_inen           invoice_entries%ROWTYPE;
      BEGIN
         IF p_pri_curr_code = 'EUR' THEN
            p_pri_rounding_amt :=   ROUND (get_pri_amount (p_inin_totals.sec_amt_sum + p_inin_totals.sec_tax_sum), 2)
                                  - (p_inin_totals.pri_amt_sum + p_inin_totals.pri_tax_sum);
            p_pri_rounding_amt := p_pri_rounding_amt + l_pri_rounding_amt;
         ELSE
            p_sec_rounding_amt :=   ROUND (get_sec_amount (p_inin_totals.pri_amt_sum + p_inin_totals.pri_tax_sum), 2)
                                  - (p_inin_totals.sec_amt_sum + p_inin_totals.sec_tax_sum);
            p_sec_rounding_amt := p_sec_rounding_amt + l_sec_rounding_amt;
         END IF;

         IF (l_pri_rounding_amt != 0) OR (l_sec_rounding_amt != 0) THEN
            l_eur_rounding_inen.invo_ref_num := p_inin_ref_num;
            l_eur_rounding_inen.acc_amount := l_pri_rounding_amt;
            l_eur_rounding_inen.sec_acc_amount := l_sec_rounding_amt;
            l_eur_rounding_inen.rounding_indicator := 'Y';
            l_eur_rounding_inen.under_dispute := 'N';
            l_eur_rounding_inen.amt_tax := 0;
            l_eur_rounding_inen.manual_entry := 'N';
            l_eur_rounding_inen.pri_curr_code := l_pri_curr_code;
            l_eur_rounding_inen.sec_curr_code := l_sec_curr_code;
            insert_interim_inen (l_eur_rounding_inen);
         END IF;
      END process_eur_rounding;
   --
   BEGIN
      p_success := FALSE;
      p_err_mesg := NULL;

      IF l_inin_recalc_metadata.curr_code = 'EEK' THEN
         -- when in EEK or transition period, round EEK amount to 5 eek cents and add EUR rounding entry to make up for
         -- differences from EEK->EUR rounding.
         IF p_process_eek_rounding THEN
            process_eek_rounding (p_pri_curr_code         => l_pri_curr_code
                                 ,p_sec_curr_code         => l_sec_curr_code
                                 ,p_inin_totals           => l_inin_totals
                                 ,p_pri_rounding_amt      => l_pri_rounding_amt
                                 ,p_sec_rounding_amt      => l_sec_rounding_amt
                                 );
         END IF;

         IF p_process_eur_rounding THEN
            process_eur_rounding (p_pri_curr_code         => l_pri_curr_code
                                 ,p_sec_curr_code         => l_sec_curr_code
                                 ,p_inin_totals           => l_inin_totals
                                 ,p_pri_rounding_amt      => l_pri_rounding_amt
                                 ,p_sec_rounding_amt      => l_sec_rounding_amt
                                 );
         END IF;

         SELECT outstanding_amt
               ,sec_outstanding_amt
           INTO l_old_outstanding_amt
               ,l_old_sec_outstanding_amt
           FROM invoices_interim
          WHERE ref_num = p_inin_ref_num;

         IF l_pri_rounding_amt != 0 THEN
            UPDATE invoices_interim invo
               SET invo.total_amt = ROUND (l_inin_totals.pri_amt_sum, 2) + ROUND (l_pri_rounding_amt, 2)
                  ,invo.outstanding_amt =   ROUND (invo.outstanding_amt, 2)
                                          + (l_inin_totals.pri_amt_sum - invo.total_amt_curr)
                                          + ROUND (l_pri_rounding_amt, 2)
             WHERE (invo.ref_num = p_inin_ref_num);
         END IF;

         IF (l_inin_recalc_metadata.curr_code = 'EEK') AND ((l_pri_rounding_amt != 0) OR (l_sec_rounding_amt != 0)) THEN
            -- CHG4594: SEC-v?ade muutmine nii, et PRI v?a triger ei k?s
            UPDATE invoices_interim invo
               SET invo.total_amt_curr = ROUND (l_inin_totals.sec_amt_sum + l_sec_rounding_amt, 2)
                  ,invo.sec_outstanding_amt = ROUND (  l_old_sec_outstanding_amt
                                                     + (l_inin_totals.sec_amt_sum - invo.total_amt_curr)
                                                     + l_sec_rounding_amt
                                                    ,2
                                                    )
             WHERE (invo.ref_num = p_inin_ref_num);
         END IF;
      END IF;

      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         p_err_mesg := 'Rounding Error.: ' || 'Invoice: ' || TO_CHAR (p_inin_ref_num);
   END rounding_invoices;*/

   PROCEDURE rounding_invoices (p_success          OUT BOOLEAN
                               ,p_err_mesg         OUT VARCHAR2
                               ,p_inin_ref_num  IN     invoices.ref_num%TYPE
   ) IS
      --
      CURSOR c_tax_rounding_amt (p_inin_ref_num IN invoices.ref_num%TYPE) IS
         SELECT NVL (ROUND (amt_tax_sum, 2) - amt_tax_sum, 0)
         FROM (SELECT SUM (inei.amt_tax) amt_tax_sum
               FROM invoice_entries_interim inei
               WHERE inei.invo_ref_num = p_inin_ref_num);
      --
      l_tax_rounding_amt            invoice_entries.amt_tax%TYPE;
      l_tax_rounding_inen           invoice_entries%ROWTYPE;
      --
   BEGIN
      p_success := FALSE;
      p_err_mesg := NULL;

      OPEN c_tax_rounding_amt (p_inin_ref_num);
      FETCH c_tax_rounding_amt INTO l_tax_rounding_amt;
      CLOSE c_tax_rounding_amt;

      IF l_tax_rounding_amt <> 0 THEN
         --
         l_tax_rounding_inen.invo_ref_num := p_inin_ref_num;
         l_tax_rounding_inen.acc_amount := 0;
         l_tax_rounding_inen.sec_acc_amount := 0;
         l_tax_rounding_inen.rounding_indicator := 'Y';
         l_tax_rounding_inen.under_dispute := 'N';
         l_tax_rounding_inen.amt_tax := l_tax_rounding_amt;
         l_tax_rounding_inen.manual_entry := 'N';
         l_tax_rounding_inen.print_required := 'N';
         l_tax_rounding_inen.pri_curr_code := get_pri_curr_code;
         l_tax_rounding_inen.sec_curr_code := get_sec_curr_code;
         --
         insert_interim_inen (l_tax_rounding_inen);
         --
      END IF;

      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         p_err_mesg := 'Rounding Error.: ' || 'Invoice: ' || TO_CHAR (p_inin_ref_num);
   END rounding_invoices;


   ---------------------------------------------------------------------------------
   PROCEDURE calculate_interim_balances (
      p_maac_ref_num  IN      NUMBER
     ,p_susg_ref_num  IN      NUMBER
     ,p_invo_ref_num  IN      NUMBER
     ,p_maac_balance  OUT     NUMBER
     ,p_susg_balance  OUT     NUMBER
   ) IS
      CURSOR c_maac_balance IS
         SELECT NVL (invo.total_amt, 0) + NVL (invo.total_vat, 0)
           FROM invoices_interim invo
          WHERE ref_num = p_invo_ref_num;

      CURSOR c_susg_balance IS
         SELECT SUM (inve.eek_amt + inve.amt_tax)
           FROM invoice_entries_interim inve
          WHERE (inve.susg_ref_num = p_susg_ref_num) AND invo_ref_num = p_invo_ref_num;
   BEGIN
      IF p_susg_ref_num IS NULL THEN
         OPEN c_maac_balance;

         FETCH c_maac_balance
          INTO p_maac_balance;

         CLOSE c_maac_balance;

         p_maac_balance := p_maac_balance + account_balances.calc_uninvoiced_events (p_maac_ref_num, NULL);
      ELSE
         OPEN c_susg_balance;

         FETCH c_susg_balance
          INTO p_susg_balance;

         CLOSE c_susg_balance;

         p_susg_balance :=   NVL (p_susg_balance, 0)
                           + account_balances.calc_uninvoiced_events (p_maac_ref_num, p_susg_ref_num);
      END IF;
   END calculate_interim_balances;

   ------------------------------------------------------------------------------------
   ------------------------------------------------------------------------------------
   PROCEDURE calculate_interim_bill (
      p_maac_ref_num      IN      NUMBER
     ,p_susg_ref_num      IN      NUMBER
     ,p_date_run          IN      DATE
     ,p_maac_balance      OUT     NUMBER
     ,p_susg_balance      OUT     NUMBER
     ,p_success           OUT     BOOLEAN
     ,p_err_mesg          OUT     VARCHAR2
     ,p_calc_monthly_chg  IN      BOOLEAN DEFAULT TRUE
   ) IS
      --
      CURSOR c_invo (
         p_maac_ref_num  IN  NUMBER
        ,p_end_date      IN  DATE
      ) IS
         SELECT *
           FROM invoices invo
          WHERE (invo.maac_ref_num = p_maac_ref_num)
            AND (invo.billing_inv = 'Y')
            AND (invo.period_end IS NULL)
            AND NVL (invo.invoice_type, 'INB') = 'INB'
            AND (TRUNC (invo.period_start) <= TRUNC (p_end_date));

      --
      CURSOR c_invo_actual (
         p_maac_ref_num  IN  NUMBER
        ,p_end_date      IN  DATE
      ) IS
         SELECT *
           FROM invoices invo
          WHERE (invo.maac_ref_num = p_maac_ref_num)
            AND (invo.billing_inv = 'Y')
            AND (invo.period_end IS NULL)
            AND NVL (invo.invoice_type, 'INB') = 'INB'
            AND (TRUNC (invo.period_start)) > TRUNC (LAST_DAY (ADD_MONTHS (p_end_date, -1)));

      --
      CURSOR c_invo_not_invo (
         p_maac_ref_num  IN  NUMBER
        ,p_end_date      IN  DATE
      ) IS
         SELECT *
           FROM invoices invo
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND NVL (invo.invoice_type, 'INB') = 'INB'
            AND TRUNC (invo.period_start) <= TRUNC (p_end_date)
            AND TRUNC (invo.period_start) > ADD_MONTHS (p_end_date, -1);

      --
      CURSOR c_inve (
         p_invo_ref_num  IN  NUMBER
        ,p_susg_ref_num  IN  NUMBER
      ) IS
         SELECT *
           FROM invoice_entries inve
          WHERE (inve.invo_ref_num = p_invo_ref_num) AND (p_susg_ref_num IS NULL OR inve.susg_ref_num = p_susg_ref_num);

      --
      -- tagasiarvestus  vahearvetelt:
      CURSOR c_all_prev (
         cp_maac_ref_num  NUMBER
        ,cp_susg_ref_num  NUMBER
        ,cp_start_date    DATE
        ,cp_end_date      DATE
      ) IS
         SELECT inen.eek_amt eek_amt   -- CHG4594/TODO: siia ACC?
               ,inen.billing_selector billing_selector
               ,inen.fcit_type_code fcit_type_code
               ,inen.num_of_days num_of_days
               ,inen.susg_ref_num susg_ref_num
               ,inen.taty_type_code
               ,inen.maas_ref_num
           FROM invoice_entries inen, invoices invo, fixed_charge_item_types fcit
          WHERE invo.maac_ref_num = cp_maac_ref_num
            AND invo.invoice_type = 'INT'
            AND TRUNC (invo.period_start) >= TRUNC (cp_start_date)
            AND inen.invo_ref_num = invo.ref_num
            AND (cp_susg_ref_num IS NULL OR inen.susg_ref_num = cp_susg_ref_num)
            AND TRUNC (invo.period_start) <= TRUNC (cp_end_date)
            AND fcit.type_code = inen.fcit_type_code
            AND fcit.pro_rata = 'Y'
            AND fcit.regular_charge = 'Y'
            AND fcit.once_off = 'N'
            AND NVL (inen.manual_entry, 'N') = 'N';

      --inp entries lisamine -tulek
      CURSOR c_new_prev (
         cp_maac_ref_num  NUMBER
        ,cp_susg_ref_num  NUMBER
      ) IS
         SELECT inen.eek_amt eek_amt   -- CHG4594/TODO: siia ACC?
               ,inen.billing_selector billing_selector
               ,inen.fcit_type_code fcit_type_code
               ,inen.num_of_days num_of_days
               ,inen.susg_ref_num susg_ref_num
               ,inen.taty_type_code
               ,inen.maas_ref_num
           FROM invoice_entries inen, invoices invo
          WHERE invo.maac_ref_num = cp_maac_ref_num
            AND invo.period_end IS NULL
            AND invo.invoice_type = 'INP'
            AND inen.invo_ref_num = invo.ref_num
            AND (cp_susg_ref_num IS NULL OR inen.susg_ref_num = cp_susg_ref_num);

      ----  hindamata eelmise perioodi kuumaksud
      CURSOR c_no_price (
         cp_maac_ref_num  NUMBER
        ,cp_susg_ref_num  NUMBER
      ) IS
         SELECT invo_period_start
               ,susg_ref_num
           FROM interim_invoice_periods
          WHERE maac_ref_num = cp_maac_ref_num
            AND calculated <> 'Y'
            AND invo_ref_num_created IS NULL
            AND (cp_susg_ref_num IS NULL OR susg_ref_num = cp_susg_ref_num);

      ----  hindamata eelmise perioodi kuumaksud
      CURSOR c_inp_price_maac (
         cp_maac_ref_num  NUMBER
      ) IS
         SELECT susg_ref_num
               ,fcit_type_code
               ,billing_selector
               ,taty_type_code
               ,num_of_days
               ,eek_amt
               ,maas_ref_num
           FROM interim_monthly_charges
          WHERE susg_ref_num IN (SELECT ref_num
                                   FROM subs_serv_groups
                                  WHERE suac_ref_num IN (SELECT ref_num
                                                           FROM accounts
                                                          WHERE maac_ref_num = cp_maac_ref_num));

      --
      CURSOR c_inp_price_susg IS
         SELECT susg_ref_num
               ,fcit_type_code
               ,billing_selector
               ,taty_type_code
               ,num_of_days
               ,eek_amt
               ,maas_ref_num
           FROM interim_monthly_charges
          WHERE susg_ref_num = p_susg_ref_num;

      --
      CURSOR c_fiss (
         p_charge_start  DATE
        ,p_susg_ref_num  NUMBER
      ) IS
         SELECT 1
           FROM ssg_statuses
          WHERE susg_ref_num = p_susg_ref_num AND TRUNC (start_date) <= TRUNC (p_charge_start)
      ;
      -- CHG-6068
      CURSOR c_ftco_mixed (p_start_date  DATE
                          ,p_end_date    DATE
      ) IS
         SELECT 1
         FROM fixed_term_contracts ftco
         WHERE susg_ref_num = p_susg_ref_num
           AND mixed_packet_code IS NOT NULL
           AND start_date <= p_end_date
           AND Nvl(date_closed, end_date) > p_start_date
      ;
      --
      c_sysdate            CONSTANT DATE := SYSDATE;
      c_default_bill_service CONSTANT service_types.service_name%TYPE := 'PARVE';
      --
      l_date_curr_run               DATE;
      l_err_mesg                    VARCHAR2 (250);
      l_success                     BOOLEAN;
      l_found                       BOOLEAN;
      j                             INTEGER := 0;
      l_dummy                       NUMBER := 0;
      l_invo_ref_num                invoices.ref_num%TYPE;
      l_invo_interim                invoices%ROWTYPE;
      l_invo                        invoices%ROWTYPE;
      l_inve                        invoice_entries%ROWTYPE;
      l_start                       DATE;
      l_end                         DATE;
      l_end_with_time               DATE;
      l_prev_period                 BOOLEAN := FALSE;
      l_prev_start                  DATE;
      l_monthly_chg_exist           BOOLEAN;
      l_discount_type               fixed_charge_types.discount_type%TYPE;
      l_default_sety_rec            service_types%ROWTYPE;
      l_serv_fees_exist             BOOLEAN;
      --
      u_err_creating                EXCEPTION;
      e_unknown_bill_period         EXCEPTION;
      e_calc_not_allowed            EXCEPTION;
      e_ma_not_active               EXCEPTION;
      e_bill_already_exists         EXCEPTION;
      e_failed_to_close_invoice     EXCEPTION;
   BEGIN
      p_err_mesg := NULL;
      p_success := TRUE;
      l_date_curr_run := NVL (TRUNC (p_date_run), TRUNC (c_sysdate));
      /*
        ** CHG-498: Get discount type for mobile level discount calculation on KER services.
      */
      l_discount_type := calculate_discounts.find_discount_type ('N'   -- p_pro_rata       IN VARCHAR2
                                                                ,'Y'   -- p_regular_charge IN VARCHAR2
                                                                ,'N'   -- p_once_off       IN VARCHAR2
                                                                );
      /*
        ** CHG-498: Get default service for M/A service fees calculation (if no ARVE service open).
      */
      l_default_sety_rec := service.get_sety_row_by_service_name (c_default_bill_service);
      ---loo uus ja t?hi invoice
      l_invo_interim.maac_ref_num := p_maac_ref_num;
      l_invo_interim.invoice_number := TO_CHAR (c_sysdate, 'YYYYMMDD');
      l_invo_interim.total_amt := 0;
      l_invo_interim.total_vat := 0;
      l_invo_interim.outstanding_amt := 0;
      l_invo_interim.created_by := sec.get_username;
      l_invo_interim.date_created := c_sysdate;
      l_invo_interim.credit := 'N';
      l_invo_interim.billed := 'N';
      l_invo_interim.billing_inv := 'Y';
      l_invo_interim.print_req := 'N';
      l_invo_interim.invoice_date := TRUNC (l_date_curr_run);
      l_invo_interim.sully_paid := NULL;
      l_invo_interim.invo_sequence := TO_NUMBER (TO_CHAR (c_sysdate, 'YYYYMM'));
      insert_interim_invo (l_invo_interim);

      -- test
	  dbms_output.put_line( 'invo ref: '||to_char(l_invo_interim.ref_num) );

      --kas on olemas eelmise perioodi INB
      OPEN c_invo_not_invo (p_maac_ref_num, LAST_DAY (ADD_MONTHS (l_date_curr_run, -1)));

      FETCH c_invo_not_invo
       INTO l_invo;

      l_found := c_invo_not_invo%FOUND;

      CLOSE c_invo_not_invo;

      -- test
	  dbms_output.put_line( '1. eelmise perioodi INB-i pole olemas, arvuta eelmise perioodi kuumaksud' );
      IF NOT l_found THEN   -- 1. eelmise perioodi INB-i pole olemas, arvuta eelmise perioodi kuumaksud
         IF p_calc_monthly_chg THEN
            l_start := TRUNC (LAST_DAY (ADD_MONTHS (l_date_curr_run, -2)) + 1);
            l_end := TRUNC (LAST_DAY (ADD_MONTHS (l_date_curr_run, -1)));
            l_end_with_time := TO_DATE (TO_CHAR (l_end, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss');
            l_prev_period := TRUE;
            l_prev_start := l_start;

            -- master accounti teenuste kuumaksud,kui p_susg_ref_num is null
      -- test
	  dbms_output.put_line( 'master accounti teenuste kuumaksud,kui p_susg_ref_num is null' );
            IF p_susg_ref_num IS NULL THEN
               calculate_fixed_charges.main_master_service_charges
                                                            (p_maac_ref_num
                                                            ,l_invo_interim
                                                            ,p_success
                                                            ,p_err_mesg
                                                            ,l_start   --   eelmise kuu start 01.03.
                                                            ,l_end_with_time   --   eelmise kuu l?pp ,31.03 timefaktoriga
                                                            ,'I'
                                                            );

               IF NOT p_success THEN
                  RAISE u_err_creating;
               END IF;
            END IF;

            --teenuste ja pakettide kuumaksud
      -- test
	  dbms_output.put_line( 'teenuste ja pakettide kuumaksud' );
            calculate_fixed_charges.period_fixed_charges (p_maac_ref_num
                                                         ,p_susg_ref_num
                                                         ,l_invo_interim
                                                         ,p_success
                                                         ,p_err_mesg
                                                         ,l_start   --period_start
                                                         ,l_end   --period_end
                                                         ,'I'
                                                         );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;

            -- tagasiarvestus vahearvetelt eelmine periood:
      -- test
	  dbms_output.put_line( 'tagasiarvestus vahearvetelt eelmine periood' );
            FOR rec_prev IN c_all_prev (p_maac_ref_num, p_susg_ref_num, l_start, l_end) LOOP
               --dbms_output.put_line( 'SAIN olemata billi vahearve entries-e susg: '||to_char(rec_prev.susg_ref_num) );
               cre_upd_interim_inen (p_success
                                    ,p_err_mesg
                                    ,l_invo_interim.ref_num
                                    ,rec_prev.fcit_type_code
                                    ,rec_prev.billing_selector
                                    ,rec_prev.taty_type_code
                                    , -1 * rec_prev.eek_amt
                                    , -1 * rec_prev.num_of_days
                                    ,rec_prev.susg_ref_num
                                    ,rec_prev.maas_ref_num
                                    );

               IF NOT p_success THEN
                  RAISE u_err_creating;
               END IF;
            END LOOP;

            /*
              ** CHG-498: Lisatud mobiili taseme teenuste p?ade arvust s?ltumatute (non-prorata) kuutasude arvutus.
            */
      -- test
	  dbms_output.put_line( 'process_monthly_service_fees.chk_mob_nonker_serv_fees_by_ma' );
            process_monthly_service_fees.chk_mob_nonker_serv_fees_by_ma
                                                    (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                    ,l_invo_interim.ref_num   -- IN     invoices.ref_num%TYPE
                                                    ,l_start   -- p_period_start IN     DATE
                                                    ,l_end_with_time   -- p_period_end   IN     DATE
                                                    ,p_success   -- OUT BOOLEAN
                                                    ,p_err_mesg   -- OUT VARCHAR2
                                                    ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                    ,TRUE   -- p_interim      IN     BOOLEAN DEFAULT FALSE
                                                    );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;

         /*
           ** DOBAS-1721: DCH tasud.
         */
      -- test
	  dbms_output.put_line( 'process_daily_charges.proc_daily_charges_ma' );
            process_daily_charges.proc_daily_charges_ma
                                                    (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                    ,l_invo_interim.ref_num   -- IN     invoices.ref_num%TYPE
                                                    ,l_start   -- p_period_start IN     DATE
                                                    ,l_end   -- p_period_end   IN     DATE
                                                    ,p_success   -- OUT BOOLEAN
                                                    ,p_err_mesg   -- OUT VARCHAR2
                                                    ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                    ,TRUE   -- p_interim      IN     BOOLEAN DEFAULT FALSE
                                                    );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;

            /*
              ** CHG-6068: Paketeeritud m??gi seadmete kuutasud
            */
            OPEN  c_ftco_mixed (l_start
                               ,l_end_with_time );
            FETCH c_ftco_mixed INTO l_dummy;
            l_found := c_ftco_mixed%FOUND;
            CLOSE c_ftco_mixed;
            --
            IF l_found THEN
               -- Seadmete kuutasud
      -- test
	  dbms_output.put_line( 'Seadmete kuutasud' );
               Process_Mixed_Packet_Fees.Bill_One_MAAC_Packet_Orders (
                       p_maac_ref_num                                --p_maac_ref_num    IN     accounts.ref_num%TYPE
                      ,l_start                --p_period_start    IN     DATE
                      ,l_end_with_time --p_period_end      IN     DATE
                      ,p_success                            --p_success            OUT BOOLEAN
                      ,p_err_mesg                               --p_error_text         OUT VARCHAR2
                      ,l_invo_interim.ref_num                        --p_invo_ref_num    IN     invoices.ref_num%TYPE DEFAULT NULL
                      ,p_susg_ref_num                                --p_susg_ref_num    IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                      ,'N'                                   --p_commit          IN     VARCHAR2 DEFAULT 'Y'
                      ,TRUE                                  --p_interim         IN     BOOLEAN DEFAULT FALSE  -- CHG-6068
               );
               --
               IF NOT p_success THEN
                  RAISE u_err_creating;
               END IF;
               --
            END IF;

            /*
              ** CHG-69: P?ade arvust s?ltumatud (non-prorata) paketi kuutasud.
            */
      -- test
	  dbms_output.put_line( 'calculate_fixed_charges.calc_non_prorata_maac_pkg_chg' );
            calculate_fixed_charges.calc_non_prorata_maac_pkg_chg
                                                           (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                           ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                                           ,l_invo_interim.ref_num   -- IN     INVOICES.ref_num%TYPE
                                                           ,l_start   -- p_period_start    IN     DATE
                                                           ,l_end_with_time   -- p_period_end      IN     DATE -- 23:59:59
                                                           ,p_success   --   OUT BOOLEAN
                                                           ,p_err_mesg   --   OUT VARCHAR2
                                                           ,TRUE   -- p_interim_balance IN     BOOLEAN DEFAULT FALSE
                                                           ,'ALL'   -- CHG-3714 p_regular_type     IN
                                                           );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;

            /*
              ** CHG-3180: Paketeeritud teenusepakettide paketitasud
            */
      -- test
	  dbms_output.put_line( 'process_packet_fees.bill_maac_packet_fees' );
            process_packet_fees.bill_maac_packet_fees (p_maac_ref_num   --IN
                                                      ,l_invo_interim.ref_num   --IN
                                                      ,p_susg_ref_num   --IN
                                                      ,l_start   --p_period_start_date IN
                                                      ,l_end_with_time   --p_period_end_datetime IN
                                                      ,p_err_mesg   --p_error_text  IN OUT
                                                      ,p_success   -- IN  OUT   BOOLEAN
                                                      ,TRUE   --p_interim_balance IN
                                                      );

            --
            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;
         END IF;
      END IF;   --eelmise perioodi olemata INB --   if not l_found THEN

      --------------------------------------------------------------------------------------
         -- 2. Kas on l?petamata (sulgemata) eelmise perioodi INB'e;
      -- test
	  dbms_output.put_line( '2. Kas on l?petamata (sulgemata) eelmise perioodi INBe' );
      FOR rec_invo IN c_invo (p_maac_ref_num, LAST_DAY (ADD_MONTHS (l_date_curr_run, -1))) LOOP
         --dbms_output.put_line( 'olen l?petamata eelmises bill-s: '||to_char(l_invo_interim.ref_num) );
         l_invo := rec_invo;
         l_found := c_invo%FOUND;

         FOR rec_inve IN c_inve (l_invo.ref_num, p_susg_ref_num) LOOP
      -- test
	  dbms_output.put_line( 'inve tspkkel: inve_ref_num = '||rec_inve.ref_num );
            l_inve := rec_inve;
            l_inve.invo_ref_num := l_invo_interim.ref_num;
            insert_interim_inen (l_inve);
         END LOOP;

         l_start := TRUNC (l_invo.period_start);
         l_end := TRUNC (LAST_DAY (l_invo.period_start));
         l_end_with_time := TO_DATE (TO_CHAR (l_end, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss');

         IF p_calc_monthly_chg THEN
            /*
              ** Create monthly charges for previous period open invoice only in case
              ** main monthly charges process has not created them yet (to avoid duplicate monthly charges).
            */
            l_monthly_chg_exist := main_monthly_charges.chk_monthly_charges_exist (l_invo.ref_num);

            IF NOT l_monthly_chg_exist THEN
               -- master accounti teenuste kuumaksud
               IF p_susg_ref_num IS NULL THEN
      -- test
	  dbms_output.put_line( 'calculate_fixed_charges.main_master_service_charges' );
                  calculate_fixed_charges.main_master_service_charges (p_maac_ref_num
                                                                      ,l_invo_interim
                                                                      ,p_success
                                                                      ,p_err_mesg
                                                                      ,l_start
                                                                      ,l_end_with_time
                                                                      ,'I'
                                                                      );

                  --
                  IF NOT p_success THEN
                     RAISE u_err_creating;
                  END IF;
               END IF;

               --
      -- test
	  dbms_output.put_line( 'calculate_fixed_charges.period_fixed_charges' );
               calculate_fixed_charges.period_fixed_charges (p_maac_ref_num
                                                            ,p_susg_ref_num
                                                            ,l_invo_interim
                                                            ,p_success
                                                            ,p_err_mesg
                                                            ,l_start
                                                            ,l_end
                                                            ,'I'
                                                            );

               IF NOT p_success THEN
                  RAISE u_err_creating;
               END IF;

               -- tagasiarvestus vahearvetele:
               --dbms_output.put_line('.alustan l?petamata eelm bill vahearvete entries maac: '
               -- ||to_char(p_maac_ref_num) ||to_date(l_start) );
               --
               FOR rec_prev IN c_all_prev (p_maac_ref_num, p_susg_ref_num, l_start, l_end) LOOP
                  --dbms_output.put_line('.SAIN l?petamata eelm bill vahearvete entries-e susg: '
                  -- ||to_char(rec_prev.susg_ref_num) );
      -- test
	  dbms_output.put_line( 'cre_upd_interim_inen' );
                  cre_upd_interim_inen (p_success
                                       ,p_err_mesg
                                       ,l_invo_interim.ref_num
                                       ,rec_prev.fcit_type_code
                                       ,rec_prev.billing_selector
                                       ,rec_prev.taty_type_code
                                       , -1 * rec_prev.eek_amt
                                       , -1 * rec_prev.num_of_days
                                       ,rec_prev.susg_ref_num
                                       ,rec_prev.maas_ref_num
                                       );

                  IF NOT p_success THEN
                     RAISE u_err_creating;
                  END IF;
               END LOOP;
            END IF;

            /*
              ** CHG-498: Lisatud mobiili taseme teenuste p?ade arvust s?ltumatute (non-prorata) kuutasude arvutus.
            */
      -- test
	  dbms_output.put_line( 'process_monthly_service_fees.chk_mob_nonker_serv_fees_by_ma' );
            process_monthly_service_fees.chk_mob_nonker_serv_fees_by_ma
                                                    (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                    ,l_invo_interim.ref_num   -- IN     invoices.ref_num%TYPE
                                                    ,l_start   -- p_period_start IN     DATE
                                                    ,l_end_with_time   -- p_period_end   IN     DATE
                                                    ,p_success   -- OUT BOOLEAN
                                                    ,p_err_mesg   -- OUT VARCHAR2
                                                    ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                    ,TRUE   -- p_interim      IN     BOOLEAN DEFAULT FALSE
                                                    );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;

         /*
           ** DOBAS-1721: DCH tasud.
         */
      -- test
	  dbms_output.put_line( 'process_daily_charges.proc_daily_charges_ma' );
            process_daily_charges.proc_daily_charges_ma
                                                    (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                    ,l_invo_interim.ref_num   -- IN     invoices.ref_num%TYPE
                                                    ,l_start   -- p_period_start IN     DATE
                                                    ,l_end   -- p_period_end   IN     DATE
                                                    ,p_success   -- OUT BOOLEAN
                                                    ,p_err_mesg   -- OUT VARCHAR2
                                                    ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                    ,TRUE   -- p_interim      IN     BOOLEAN DEFAULT FALSE
                                                    );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;

            /*
              ** CHG-69: P?ade arvust s?ltumatud (non-prorata) paketi kuutasud.
            */
      -- test
	  dbms_output.put_line( 'calculate_fixed_charges.calc_non_prorata_maac_pkg_chg' );
            calculate_fixed_charges.calc_non_prorata_maac_pkg_chg
                                                           (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                           ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                                           ,l_invo_interim.ref_num   -- IN     INVOICES.ref_num%TYPE
                                                           ,l_start   -- p_period_start    IN     DATE
                                                           ,l_end_with_time   -- p_period_end      IN     DATE -- 23:59:59
                                                           ,p_success   --   OUT BOOLEAN
                                                           ,p_err_mesg   --   OUT VARCHAR2
                                                           ,TRUE   -- p_interim_balance IN     BOOLEAN DEFAULT FALSE
                                                           );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;
         END IF;

         --
         -- Kontrollime eelnevalt, et ei oleks juba arvel.
         l_serv_fees_exist := process_monthly_service_fees.chk_ker_service_fees_exist (l_invo.ref_num);

         --
         IF NOT l_serv_fees_exist THEN
            /*
              ** CHG-499: Mobiili taseme k?nede eristuse teenused.
            */
      -- test
	  dbms_output.put_line( 'process_monthly_service_fees.calc_non_prorata_ker_susg_chg' );
            process_monthly_service_fees.calc_non_prorata_ker_susg_chg
                                                    (p_maac_ref_num   -- IN     master_accounts_v.ref_num %TYPE
                                                    ,l_invo_interim.ref_num   -- IN     invoices.ref_num%TYPE
                                                    ,l_start   -- p_period_start_date IN     DATE
                                                    ,l_end_with_time   -- p_period_end_date   IN     DATE -- 23:59:59
                                                    ,l_discount_type   -- IN     fixed_charge_types.discount_type%TYPE
                                                    ,p_success   --    OUT BOOLEAN
                                                    ,p_err_mesg   -- OUT VARCHAR2
                                                    ,TRUE   -- p_interim_balance   IN     BOOLEAN DEFAULT FALSE
                                                    ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                    );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;

            /*
              ** CHG-498: Masteri taseme k?nede eristuse ja arve teenused - kui on k?itus masteri (mitte SUSGi) tasemel.
            */
            IF p_susg_ref_num IS NULL THEN
      -- test
	  dbms_output.put_line( 'process_monthly_service_fees.calc_non_prorata_ker_maas_chg' );
               process_monthly_service_fees.calc_non_prorata_ker_maas_chg
                                                       (p_maac_ref_num   -- IN     master_accounts_v.ref_num %TYPE
                                                       ,l_invo_interim.ref_num   -- IN     invoices.ref_num%TYPE
                                                       ,l_start   -- p_period_start_date IN     DATE
                                                       ,l_end_with_time   -- p_period_end_date   IN     DATE
                                                       ,NULL   -- p_maac_end_date     IN     DATE
                                                       ,l_default_sety_rec.ref_num   -- IN     service_types.ref_num%TYPE
                                                       ,p_success   -- OUT BOOLEAN
                                                       ,p_err_mesg   -- OUT VARCHAR2
                                                       ,TRUE   -- p_interim_balance   IN     BOOLEAN DEFAULT FALSE
                                                       );

               IF NOT p_success THEN
                  RAISE u_err_creating;
               END IF;
            END IF;
         END IF;
      END LOOP;

      -----------------------------------------------------------------------------------
      ----l? eelmiste perioodide l?petamata invoiced.
      -- test
	  dbms_output.put_line( '3. jooksa perioodi jaoks' );
         -- 3. jooksa perioodi jaoks
         --dbms_output.put_line( '.alustan jooksev periood, maac: '||to_char(p_maac_ref_num)
         --                       ||to_date(l_start) );
      OPEN c_invo_actual (p_maac_ref_num, l_date_curr_run);

      FETCH c_invo_actual
       INTO l_invo;

      l_found := c_invo_actual%FOUND;

      CLOSE c_invo_actual;

      --dbms_output.put_line('INVO=' || to_char(l_invo.ref_num));
      IF l_found THEN
         IF l_invo.period_end IS NULL THEN
            FOR rec_inve IN c_inve (l_invo.ref_num, p_susg_ref_num) LOOP
      -- test
	  dbms_output.put_line( 'inve tsykkel: inve_ref_num = '||rec_inve.ref_num );
               l_inve := rec_inve;
               l_inve.invo_ref_num := l_invo_interim.ref_num;
               insert_interim_inen (l_inve);
            END LOOP;
         ELSE
            RAISE e_unknown_bill_period;
         END IF;
      END IF;

      l_start := TRUNC (LAST_DAY (ADD_MONTHS (l_date_curr_run, -1)) + 1);
      l_end := l_date_curr_run;
      l_end_with_time := TO_DATE (TO_CHAR (l_end, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss');

      -- jooksev periood, sulgemata INB -id
      IF p_calc_monthly_chg THEN
         IF p_susg_ref_num IS NULL THEN
            -- master accounti teenuste kuumaksud
            calculate_fixed_charges.main_master_service_charges (p_maac_ref_num
                                                                ,l_invo_interim
                                                                ,p_success
                                                                ,p_err_mesg
                                                                ,l_start
                                                                ,l_end_with_time
                                                                ,'I'
                                                                );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;
         END IF;

         calculate_fixed_charges.period_fixed_charges (p_maac_ref_num
                                                      ,p_susg_ref_num
                                                      ,l_invo_interim
                                                      ,p_success
                                                      ,p_err_mesg
                                                      ,l_start
                                                      ,l_end
                                                      ,'I'
                                                      );

         IF NOT p_success THEN
            RAISE u_err_creating;
         END IF;

         -- vahearvete lahutamine (juba saadetud arve kuu arvest)
         FOR rec_prev IN c_all_prev (p_maac_ref_num, p_susg_ref_num, l_start, l_end) LOOP
            cre_upd_interim_inen (p_success
                                 ,p_err_mesg
                                 ,l_invo_interim.ref_num
                                 ,rec_prev.fcit_type_code
                                 ,rec_prev.billing_selector
                                 ,rec_prev.taty_type_code
                                 , -1 * rec_prev.eek_amt
                                 , -1 * rec_prev.num_of_days
                                 ,rec_prev.susg_ref_num
                                 ,rec_prev.maas_ref_num
                                 );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;
         END LOOP;

         /*
           ** CHG-498: Lisatud mobiili taseme teenuste p?ade arvust s?ltumatute (non-prorata) kuutasude arvutus.
         */
         process_monthly_service_fees.chk_mob_nonker_serv_fees_by_ma
                                                    (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                    ,l_invo_interim.ref_num   -- IN     invoices.ref_num%TYPE
                                                    ,l_start   -- p_period_start IN     DATE
                                                    ,l_end_with_time   -- p_period_end   IN     DATE
                                                    ,p_success   -- OUT BOOLEAN
                                                    ,p_err_mesg   -- OUT VARCHAR2
                                                    ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                    ,TRUE   -- p_interim      IN     BOOLEAN DEFAULT FALSE
                                                    );

         IF NOT p_success THEN
            RAISE u_err_creating;
         END IF;

         /*
           ** DOBAS-1721: DCH tasud.
         */
      -- test
	  dbms_output.put_line( 'process_daily_charges.proc_daily_charges_ma' );
            process_daily_charges.proc_daily_charges_ma
                                                    (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                    ,l_invo_interim.ref_num   -- IN     invoices.ref_num%TYPE
                                                    ,l_start   -- p_period_start IN     DATE
                                                    ,l_end   -- p_period_end   IN     DATE
                                                    ,p_success   -- OUT BOOLEAN
                                                    ,p_err_mesg   -- OUT VARCHAR2
                                                    ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                    ,TRUE   -- p_interim      IN     BOOLEAN DEFAULT FALSE
                                                    );

            IF NOT p_success THEN
               RAISE u_err_creating;
            END IF;
         /*
           ** CHG-69: P?ade arvust s?ltumatud (non-prorata) paketi kuutasud.
         */
         calculate_fixed_charges.calc_non_prorata_maac_pkg_chg
                                                           (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                           ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                                           ,l_invo_interim.ref_num   -- IN     INVOICES.ref_num%TYPE
                                                           ,l_start   -- p_period_start    IN     DATE
                                                           ,l_end_with_time   -- p_period_end      IN     DATE -- 23:59:59
                                                           ,p_success   --   OUT BOOLEAN
                                                           ,p_err_mesg   --   OUT VARCHAR2
                                                           ,TRUE   -- p_interim_balance IN     BOOLEAN DEFAULT FALSE
                                                           );

         IF NOT p_success THEN
            RAISE u_err_creating;
         END IF;

         /*
           ** CHG-3180: Paketeeritud teenusepakettide paketitasud
         */
         process_packet_fees.bill_maac_packet_fees (p_maac_ref_num   --IN
                                                   ,l_invo_interim.ref_num   --IN
                                                   ,p_susg_ref_num   --IN
                                                   ,l_start   --p_period_start_date IN
                                                   ,l_end_with_time   --p_period_end_datetime IN
                                                   ,p_err_mesg   --p_error_text  IN OUT
                                                   ,p_success   -- IN  OUT   BOOLEAN
                                                   ,TRUE   --p_interim_balance IN
                                                   );

         --
         IF NOT p_success THEN
            RAISE u_err_creating;
         END IF;
      END IF;

      --dbms_output.put_line( '.l? vahearvete entries-e maac: '||
      --  to_char(p_maac_ref_num) );

      /*
        ** CHG-499: Mobiili taseme k?nede eristuse teenused.
      */
      process_monthly_service_fees.calc_non_prorata_ker_susg_chg
                                                     (p_maac_ref_num   -- IN     master_accounts_v.ref_num %TYPE
                                                     ,l_invo_interim.ref_num   -- IN     invoices.ref_num%TYPE
                                                     ,l_start   -- p_period_start_date IN     DATE
                                                     ,l_end_with_time   -- p_period_end_date   IN     DATE -- 23:59:59
                                                     ,l_discount_type   -- IN     fixed_charge_types.discount_type%TYPE
                                                     ,p_success   --    OUT BOOLEAN
                                                     ,p_err_mesg   -- OUT VARCHAR2
                                                     ,TRUE   -- p_interim_balance   IN     BOOLEAN DEFAULT FALSE
                                                     ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                     );

      IF NOT p_success THEN
         RAISE u_err_creating;
      END IF;

      /*
        ** CHG-498: Masteri taseme k?nede eristuse ja arve teenused - kui on k?itus masteri (mitte SUSGi) tasemel.
      */
      IF p_susg_ref_num IS NULL THEN
         process_monthly_service_fees.calc_non_prorata_ker_maas_chg
                                                       (p_maac_ref_num   -- IN     master_accounts_v.ref_num %TYPE
                                                       ,l_invo_interim.ref_num   -- IN     invoices.ref_num%TYPE
                                                       ,l_start   -- p_period_start_date IN     DATE
                                                       ,l_end_with_time   -- p_period_end_date   IN     DATE
                                                       ,NULL   -- p_maac_end_date     IN     DATE
                                                       ,l_default_sety_rec.ref_num   -- IN     service_types.ref_num%TYPE
                                                       ,p_success   -- OUT BOOLEAN
                                                       ,p_err_mesg   -- OUT VARCHAR2
                                                       ,TRUE   -- p_interim_balance   IN     BOOLEAN DEFAULT FALSE
                                                       );

         IF NOT p_success THEN
            RAISE u_err_creating;
         END IF;
      END IF;

      ------------------------
      --4. eelmise perioodi s?ndmused INP'd
      FOR rec_prev_add IN c_new_prev (p_maac_ref_num, p_susg_ref_num) LOOP
         --dbms_output.put_line( '.sain eelmiste perioodide hinnatud saatmata  maac : '
         --||to_char(p_maac_ref_num) );
         cre_upd_interim_inen (p_success
                              ,p_err_mesg
                              ,l_invo_interim.ref_num
                              ,rec_prev_add.fcit_type_code
                              ,rec_prev_add.billing_selector
                              ,rec_prev_add.taty_type_code
                              ,rec_prev_add.eek_amt
                              ,rec_prev_add.num_of_days
                              ,rec_prev_add.susg_ref_num
                              ,rec_prev_add.maas_ref_num
                              );

         IF NOT p_success THEN
            RAISE u_err_creating;
         END IF;
      END LOOP;

        --dbms_output.put_line( '.eelmiste perioodide hinnatud saatmata l?  maac : '
        --  ||to_char(p_maac_ref_num) );
      --------------------------------------------------------------------
        --dbms_output.put_line( '.eelmiste perioodide hindamata algus  ' );
      IF p_calc_monthly_chg THEN
         FOR rec_no_price IN c_no_price (p_maac_ref_num, p_susg_ref_num)   --invo_period_start,susg_ref_num
                                                                        LOOP
            l_dummy := 0;

            --dbms_output.put_line( ' perioodi algus  '||to_char(rec_no_price.invo_period_start) );
            OPEN c_fiss (rec_no_price.invo_period_start, rec_no_price.susg_ref_num);

            FETCH c_fiss
             INTO l_dummy;

            CLOSE c_fiss;

            --dbms_output.put_line( 'dummy  '||to_char(l_dummy) );
            IF l_dummy = 1 THEN
               IF l_prev_period THEN
                  --dbms_output.put_line( 'l_prev_period true  ' );
                  IF TRUNC (rec_no_price.invo_period_start) < l_prev_start THEN
                     --  dbms_output.put_line( '?lemine - pool tellitust  ');
                     calculate_fixed_charges.period_fixed_charges (p_maac_ref_num
                                                                  ,rec_no_price.susg_ref_num
                                                                  ,l_invo_interim
                                                                  ,p_success
                                                                  ,p_err_mesg
                                                                  ,TRUNC (rec_no_price.invo_period_start)   --period_start
                                                                  ,l_prev_start   --period_end
                                                                  ,'I'
                                                                  );

                     IF NOT p_success THEN
                        RAISE u_err_creating;
                     END IF;
                  END IF;
               ELSE
                  --dbms_output.put_line( 'l_prev_period false  t? tellitud ' );
                  calculate_fixed_charges.period_fixed_charges (p_maac_ref_num
                                                               ,rec_no_price.susg_ref_num
                                                               ,l_invo_interim
                                                               ,p_success
                                                               ,p_err_mesg
                                                               ,TRUNC (rec_no_price.invo_period_start)   --period_start
                                                               ,LAST_DAY (ADD_MONTHS (TRUNC (SYSDATE), -1))   --period_end
                                                               ,'I'
                                                               );

                  IF NOT p_success THEN
                     RAISE u_err_creating;
                  END IF;
               END IF;
            END IF;
         END LOOP;
      END IF;

      --dbms_output.put_line( '.eelmiste perioodide hindamata l?   ' );
      -----------------------------------------------------------------------
      --arvutatud kuumaksud inp sulgemisel:
      IF p_calc_monthly_chg THEN
         IF NOT l_prev_period THEN
            IF p_susg_ref_num IS NOT NULL THEN
               FOR rec IN c_inp_price_susg LOOP
                  cre_upd_interim_inen (p_success
                                       ,p_err_mesg
                                       ,l_invo_interim.ref_num
                                       ,rec.fcit_type_code
                                       ,rec.billing_selector
                                       ,rec.taty_type_code
                                       ,rec.eek_amt
                                       ,rec.num_of_days
                                       ,rec.susg_ref_num
                                       ,rec.maas_ref_num
                                       );
               END LOOP;
            ELSE
               FOR rec IN c_inp_price_maac (p_maac_ref_num) LOOP
                  cre_upd_interim_inen (p_success
                                       ,p_err_mesg
                                       ,l_invo_interim.ref_num
                                       ,rec.fcit_type_code
                                       ,rec.billing_selector
                                       ,rec.taty_type_code
                                       ,rec.eek_amt
                                       ,rec.num_of_days
                                       ,rec.susg_ref_num
                                       ,rec.maas_ref_num
                                       );
               END LOOP;
            END IF;
         END IF;
      END IF;

      calc_interim_taxes (p_success, p_err_mesg, l_invo_interim.ref_num);

      IF NOT p_success THEN
         RAISE u_err_creating;
      END IF;

      calc_interim_totals (p_success, p_err_mesg, l_invo_interim);

      IF NOT p_success THEN
         RAISE u_err_creating;
      END IF;

      rounding_invoices (p_success, p_err_mesg, l_invo_interim.ref_num);

      IF NOT p_success THEN
         RAISE u_err_creating;
      END IF;

      p_success := TRUE;
      p_err_mesg := NULL;
      --Calculate interim balances.
      calculate_interim_balances (p_maac_ref_num, p_susg_ref_num, l_invo_interim.ref_num, p_maac_balance
                                 ,p_susg_balance);
   --dbms_output.put_line( 'maac balance '||to_char(p_maac_balance)
   -- ||' invo_ref '||to_char( l_invo_interim.ref_num));
   --dbms_output.put_line( 'susg balance '||to_char(p_maac_balance) );
   EXCEPTION
      WHEN u_err_creating THEN
         -- rollback;
         --dbms_output.put_line( '.error error: '||to_char(p_maac_ref_num) );
         p_success := FALSE;
      WHEN e_unknown_bill_period THEN
         --rollback;
         p_err_mesg := 'Can NOT calculate Monthly Charges. Unknown Bill Period.';
         p_success := FALSE;
      WHEN e_calc_not_allowed THEN
         p_err_mesg := 'NOT allowed to calculate Monthly Charges. Allowed only after Billing.';
         p_success := FALSE;
      WHEN e_ma_not_active THEN
         p_err_mesg := 'Master Acc. ' || TO_CHAR (p_maac_ref_num) || ' NOT active within the specified Bill Period.';
         p_success := FALSE;
      WHEN e_bill_already_exists THEN
         --Return existing interim balances.
         calculate_interim_balances (p_maac_ref_num
                                    ,p_susg_ref_num
                                    ,l_invo_interim.ref_num
                                    ,p_maac_balance
                                    ,p_susg_balance
                                    );
         p_err_mesg := 'Interim Bill already been created on ' || TO_CHAR (l_date_curr_run, 'DD.MM.YYYY') || '.';
      WHEN e_failed_to_close_invoice THEN
         -- ROLLBACK;
         p_err_mesg := NVL (l_err_mesg, SQLERRM);
         p_success := FALSE;
      WHEN OTHERS THEN
         --ROLLBACK;
         p_err_mesg := SQLERRM;
         p_success := FALSE;
   END calculate_interim_bill;
--
END close_interim_billing_invoice;
/