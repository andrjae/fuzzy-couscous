/*<TOAD_FILE_CHUNK>*/
CREATE OR REPLACE PACKAGE emt_pricelist AS
   /********************************************************************
   **
   **  Module      :  BCCU1277
   **  Module Name :  EMT_PRICELIST
   **  Date Created:  15.11.2005
   **  Author      :  M.Sabul,H.Luhasalu
   **  Description :  This package contains procedures and functions used
   **                 in creating Monthly Charges for Master Accounts
   **                 of given Bill Cycle. Should be run before Main Bill.
   **
   ** -------------------------------------------------------------
   ** Version Date        Modified by Reason
   ** -------------------------------------------------------------
   **   1.6   09.01.2019  A.Jaek     DOBAS-1622: Uue DCH tüüpi kirjete daily_charge='Y' hõlmamine päringutes
   **                                         --Muudetud protseduurid ebpl_maac_services, ebpl_maac_services, mob_prli_sety_charges, mob_prli_sety_charges2, get_flags
   **   1.5   10.10.2012  E.Naarits  CHG-6099 : Muudetud protseduuri Ins_Mobile_Monthly_Charges.
   **   1.4   21.06.2012  E.Naarits  CHG-5827 : Lisatud protseduur Ins_Mobile_Monthly_Charges.
   **                                           Samuti lisatud Start_EBPL_MCH_RCH, mida saaks jobist välja kutsuda.
   **                                           Lisatud Ins_Mobile_Monthly_Charges protseduuri väljakutse
   **                                           protseduuri Start_EBPL.
   **   1.3   14.05.2012  H.Luhasalu CHG-5749 : MA teenused kustutatakse nüüd ka FLAG järgi
   **   1.2   03.12.2008  A.Soo      CHG-2795 : Uute veergude INSERT protseduuris Ins_EBPL.
   **   1.1   29.06.2007  S.Sokk     CHG-2110 : Replaced USER with sec.get_username
   **   1.0   15.11.2005  M.Sabul,   CHG- 464 : Algversioon.Abitabeli emt_bill_price_list
   **                     H.Luhasalu            täitmine kuumaksude arvutamiseks.
   ** -------------------------------------------------------------
   **/
   c_module_ref         CONSTANT VARCHAR2 (10) := 'BCCU1277';
   c_module_name        CONSTANT VARCHAR2 (70) := 'EMT_Pricelist';
   c_fcty_type          CONSTANT fixed_charge_types.type_code%TYPE := 'MCH';
   l_ebpl                        emt_bill_price_list%ROWTYPE;


   PROCEDURE get_flags (p_pro_rata           OUT fixed_charge_item_types.pro_rata%TYPE
                       ,p_once_off           OUT fixed_charge_item_types.once_off%TYPE
                       ,p_regular_charge     OUT fixed_charge_item_types.pro_rata%TYPE
                       ,p_daily_charge     OUT fixed_charge_item_types.daily_charge%TYPE  --DOBAS-1622
                       ,p_fcty_type       IN     fixed_charge_types.type_code%TYPE DEFAULT 'MCH'
                       );

   ------
   PROCEDURE get_period_start_end (p_start          OUT DATE
                                  ,p_end            OUT DATE
                                  ,p_check_date  IN     DATE DEFAULT SYSDATE
                                  );

   ------
   ------------------------
   PROCEDURE ins_ebpl (p_ebpl        IN     emt_bill_price_list%ROWTYPE
                      ,p_success        OUT BOOLEAN
                      ,p_error_text     OUT VARCHAR2
                      );

   ------------------------
   PROCEDURE ins_batch_messages (p_bame_row IN bcc_batch_messages%ROWTYPE);

   ------------------------
   FUNCTION monthly_charges_ok
      RETURN BOOLEAN;

   ------------------------
   PROCEDURE ebpl_maac_services (p_start_date  IN     DATE
                                ,p_end_date    IN     DATE
                                ,p_fcty_type   IN     fixed_charge_types.type_code%TYPE DEFAULT 'MCH'
                                ,p_success        OUT BOOLEAN
                                ,p_error_text     OUT VARCHAR2
                                );

   -----------
   PROCEDURE mob_sety_charges (p_fcty_type         fixed_charge_types.type_code%TYPE
                              ,p_start_period      DATE
                              ,p_end_period        DATE
                              ,p_success       OUT BOOLEAN
                              ,p_error_text    OUT VARCHAR2
                              );

   PROCEDURE start_ebpl (p_fcty_type IN fixed_charge_types.type_code%TYPE DEFAULT 'MCH');

   PROCEDURE ins_mobile_monthly_charges (p_success     OUT BOOLEAN
                                        ,p_error_text  OUT VARCHAR2
                                        );

   PROCEDURE start_ebpl_mch_rch;
-- KÄIVITATAV Põhiprogramm **
------------
END emt_pricelist;
/

CREATE OR REPLACE PACKAGE BODY emt_pricelist IS
   PROCEDURE get_flags (p_pro_rata           OUT fixed_charge_item_types.pro_rata%TYPE
                       ,p_once_off           OUT fixed_charge_item_types.once_off%TYPE
                       ,p_regular_charge     OUT fixed_charge_item_types.pro_rata%TYPE
                       ,p_daily_charge     OUT fixed_charge_item_types.daily_charge%TYPE
                       ,p_fcty_type       IN     fixed_charge_types.type_code%TYPE DEFAULT 'MCH'
                       ) IS
      CURSOR c IS
         SELECT pro_rata
               ,once_off
               ,regular_charge
               ,nvl(daily_charge, 'N')  -- DOBAS-1622
           FROM fixed_charge_types
          WHERE type_code = p_fcty_type;
   BEGIN
      OPEN c;

      FETCH c
      INTO p_pro_rata, p_once_off, p_regular_charge, p_daily_charge; -- DOBAS-1622

      CLOSE c;
   END get_flags;

   -------------------------
   PROCEDURE get_period_start_end (p_start          OUT DATE
                                  ,p_end            OUT DATE
                                  ,p_check_date  IN     DATE DEFAULT SYSDATE
                                  ) IS
      -- 1. määratleb perioodi , millised hinnakirja andmed võtab kaasa
      -- kuumaksude hinnakirja vahetabel moodustatakse :
      -- a) kui jooksev kuupäev >= kuu viimane kuupäev - 3 (päeva):
      -- jooksva kuu 1.kuupäevast kuni järgmise kuu viimase kuupäevani
      -- b) kui jooksev kuupäev < kuu viimane kuupäev - 3 (päeva): :
      -- jooksvale kuule eelneva kuu 1.kuupäevast  kuni jooksva kuu viimase kuupäevani
      --******************************************************************************

      l_prev_start                  DATE := LAST_DAY (ADD_MONTHS (TRUNC (p_check_date), -2)) + 1; -- eelmise kuu 1.kuupäev(sysdate'st)
      l_curr_start                  DATE := LAST_DAY (ADD_MONTHS (TRUNC (p_check_date), -1)) + 1; -- jooksva kuu 1.kuupäev(sysdate'st)
      l_last_day                    VARCHAR2 (2) := TO_CHAR (LAST_DAY (p_check_date) - 5, 'dd');
   BEGIN
      -- 1. määratleb perioodi , millised hinnakirja andmed võtab kaasa

      IF TO_CHAR (p_check_date, 'dd') < l_last_day THEN -- < kuu viimane päev -3
         p_start := l_prev_start; -- eelmise kuu 1. kuupäev
         p_end := TO_DATE (TO_CHAR (LAST_DAY (TRUNC (p_check_date)), 'dd.mm.yyyy') || ' 23:59:59'
                          ,'dd.mm.yyyy hh24:mi:ss'
                          );
      ELSE -- on kuuviimane päev
         p_start := l_curr_start; -- jooksva kuu 1.kuupäev
         p_end := TO_DATE (TO_CHAR (LAST_DAY (TRUNC (p_check_date + 1)), 'dd.mm.yyyy') || ' 23:59:59'
                          ,'dd.mm.yyyy hh24:mi:ss'
                          );
      END IF;
   END get_period_start_end;

   ------------------------
   PROCEDURE ins_ebpl (p_ebpl        IN     emt_bill_price_list%ROWTYPE
                      ,p_success        OUT BOOLEAN
                      ,p_error_text     OUT VARCHAR2
                      ) IS
      -- CHG-2795
      CURSOR c_key IS
         SELECT key_sety_ref_num
               ,key_charge_value
           FROM fixed_dependent_prices
          WHERE     fcit_type_code = p_ebpl.fcit_type_code
                AND p_ebpl.start_date >= start_date
                AND (p_ebpl.start_date <= end_date OR end_date IS NULL);

      --
      l_key_sety_ref_num            emt_bill_price_list.key_sety_ref_num%TYPE;
      l_key_charge_value            emt_bill_price_list.key_charge_value%TYPE;
   BEGIN
      --
      OPEN c_key;

      FETCH c_key
      INTO l_key_sety_ref_num, l_key_charge_value;

      CLOSE c_key;

      --
      INSERT
        INTO emt_bill_price_list (fcty_type
                                 ,what
                                 ,list_type
                                 ,fcit_type_code
                                 ,taty_type_code
                                 ,billing_selector
                                 ,charge_value
                                 ,sept_type_code
                                 ,sety_ref_num
                                 ,sepa_ref_num
                                 ,sepv_ref_num
                                 ,start_date
                                 ,end_date
                                 ,chca_type_code
                                 ,chargeable
                                 ,key_sety_ref_num
                                 , -- CHG-2795
                                  key_charge_value
                                 , -- CHG-2795
                                  created_by
                                 ,date_created
                                 )
      VALUES (p_ebpl.fcty_type
             ,p_ebpl.what
             ,p_ebpl.list_type
             ,p_ebpl.fcit_type_code
             ,p_ebpl.taty_type_code
             ,p_ebpl.billing_selector
             ,p_ebpl.charge_value
             ,p_ebpl.sept_type_code
             ,p_ebpl.sety_ref_num
             ,p_ebpl.sepa_ref_num
             ,p_ebpl.sepv_ref_num
             ,p_ebpl.start_date
             ,p_ebpl.end_date
             ,p_ebpl.chca_type_code
             ,p_ebpl.chargeable
             ,l_key_sety_ref_num
             , -- CHG-2795
              l_key_charge_value
             , -- CHG-2795
              NVL (p_ebpl.created_by, sec.get_username)
             ,NVL (p_ebpl.date_created, SYSDATE)
             );


      p_success := TRUE;
      p_error_text := NULL;
   EXCEPTION
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := 'Viga! <Ins_EBPL> ' || SQLERRM;
   END ins_ebpl;

   ------------------
   PROCEDURE ins_batch_messages (p_bame_row IN bcc_batch_messages%ROWTYPE) IS
   BEGIN
      INSERT
        INTO bcc_batch_messages (module_ref
                                ,module_desc
                                ,run_by_user
                                ,mesg_num
                                ,MESSAGE_TEXT
                                ,message_date
                                ,bcc_msg_num
                                ,parameters
                                )
      VALUES (p_bame_row.module_ref
             ,p_bame_row.module_desc
             ,NVL (p_bame_row.run_by_user, sec.get_username)
             ,bame_ref_num_s.NEXTVAL
             ,p_bame_row.MESSAGE_TEXT
             ,SYSDATE
             ,p_bame_row.bcc_msg_num
             ,p_bame_row.parameters
             );
   EXCEPTION
      WHEN OTHERS THEN
         NULL;
   END ins_batch_messages;

   --------------------------------------------------------------------------------
   FUNCTION monthly_charges_ok
      RETURN BOOLEAN IS
      CURSOR c IS
         SELECT '1'
           -- a.start_date,a.end_date, a.end_code
           FROM tbcis.tbcis_processes a
          WHERE module_ref = 'BCCU848'
                AND NOT (    start_date < SYSDATE
                         AND NVL (end_date, SYSDATE + 1) < SYSDATE
                         AND TO_CHAR (start_date, 'mm') = TO_CHAR (SYSDATE, 'mm')
                         AND TO_CHAR (end_date, 'mm') = TO_CHAR (SYSDATE, 'mm')
                         AND NVL (end_code, 'XX') = 'OK');

      l_dummy                       VARCHAR2 (1) := NULL;
      l_found                       BOOLEAN;
   -- RETURN false - kuumaksudega pole asjad korras
   -- RETURN true  - kuumaksudega OK, asjad korras
   BEGIN
      OPEN c;

      FETCH c INTO l_dummy;

      l_found := c%FOUND;

      CLOSE c;

      RETURN (NOT l_found);
   END monthly_charges_ok;

   -----------------
   ------------------------------------
   PROCEDURE ebpl_maac_services (p_start_date  IN     DATE -- period start
                                ,p_end_date    IN     DATE -- period end
                                ,p_fcty_type   IN     fixed_charge_types.type_code%TYPE DEFAULT 'MCH'
                                ,p_success        OUT BOOLEAN
                                ,p_error_text     OUT VARCHAR2
                                ) IS
      l_min_start                   DATE := TO_DATE ('18.05.2001', 'dd.mm.yyyy'); -- väiksem PRLI.start
      l_curr_start                  DATE := NULL; --jooksev start kuupäev
      l_curr_end                    DATE := NULL; --jooksev end kuupäev
      l_curr_end_ins                DATE := NULL; --vahemuutuja, l_curr_end>=p_end_date korral:=null;
      l_exit_ficv                   INTEGER := 0; -- 0 -jätka ; 1- exit
      l_exit_prli                   INTEGER := 0; -- 0 -jätka ; 1- exit
      --
      l_what                        emt_bill_price_list.what%TYPE := 'Konto teenused';
      l_list_type_p                 emt_bill_price_list.list_type%TYPE := 'Põhihind';
      l_list_type_e                 emt_bill_price_list.list_type%TYPE := 'Erihind';
      l_pro_rata                    fixed_charge_item_types.pro_rata%TYPE;
      l_once_off                    fixed_charge_item_types.once_off%TYPE;
      l_regular_charge              fixed_charge_item_types.regular_charge%TYPE;
      l_daily_charge                fixed_charge_item_types.daily_charge%TYPE;  -- DOBAS-1622
      l_count                       INTEGER := 0;
      l_count_prli                  INTEGER := 0;
      l_ficv_count                  INTEGER := 0;
      l_success                     BOOLEAN;
      l_error_text                  VARCHAR2 (255) := NULL;
      --
      some_errors                   EXCEPTION;

      CURSOR c_chca IS
         SELECT type_code chca
           FROM char_cats_v
          WHERE nety_type_code = 'MAC' AND NVL (arhive, 'N') = 'N';


      CURSOR c_sety_gr (
         p_pro_rata        IN fixed_charge_item_types.pro_rata%TYPE
        ,p_once_off        IN fixed_charge_item_types.once_off%TYPE
        ,p_regular_charge  IN fixed_charge_item_types.regular_charge%TYPE
        ,p_daily_charge  IN fixed_charge_item_types.daily_charge%TYPE) IS  -- DOBAS-1622
         SELECT   prli.sety_ref_num sety
                 ,prli.sepa_ref_num sepa
                 ,prli.sepv_ref_num sepv
                 ,COUNT (*) arv
             FROM price_lists prli, fixed_charge_item_types fcit
            WHERE     prli.sety_ref_num IS NOT NULL
                  AND NVL (prli.end_date, p_start_date) >= p_start_date
                  AND prli.start_date <= p_end_date
                  AND EXISTS
                         (SELECT ref_num
                            FROM service_types sety
                           WHERE     prli.sety_ref_num = sety.ref_num
                                 AND sety.information_pack IN ('KONTO')
                                 AND NVL (sety.end_date, p_start_date) >= p_start_date
                                 AND sety.start_date <= p_end_date)
                  AND prli.channel_type IS NULL
                  AND prli.once_off = p_once_off
                  AND prli.pro_rata = p_pro_rata
                  AND prli.regular_charge = p_regular_charge
                  and NVL(prli.daily_charge, 'N') = p_daily_charge  -- DOBAS-1622
                  AND fcit.once_off = p_once_off
                  AND fcit.pro_rata = p_pro_rata
                  AND fcit.regular_charge = p_regular_charge
                  and NVL(fcit.daily_charge, 'N') = p_daily_charge  -- DOBAS-1622
                  AND prli.sety_ref_num = fcit.sety_ref_num
                  AND fcit.package_category IS NULL
         GROUP BY prli.sety_ref_num, prli.sepa_ref_num, prli.sepv_ref_num
         ORDER BY 1, 2, 3;

      --------------------------------------------------------------------------------
      --------------------------------------------------------------------------------
      CURSOR c_prli (
         p_pro_rata        IN fixed_charge_item_types.pro_rata%TYPE
        ,p_once_off        IN fixed_charge_item_types.once_off%TYPE
        ,p_regular_charge  IN fixed_charge_item_types.regular_charge%TYPE
        ,p_daily_charge    IN fixed_charge_item_types.daily_charge%TYPE  -- DOBAS-1622
        ,p_sety            IN service_types.ref_num%TYPE
        ,p_sepa            IN service_parameters.ref_num%TYPE
        ,p_sepv            IN service_param_values.ref_num%TYPE) IS
         SELECT   l_list_type_p hinnakiri
                 ,fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,prli.charge_value charge_value
                 ,prli.sety_ref_num sety
                 ,prli.sepa_ref_num sepa
                 ,prli.sepv_ref_num sepv
                 ,GREATEST (prli.start_date, p_start_date) start_date
                 ,prli.end_date end_date
             FROM price_lists prli, fixed_charge_item_types fcit
            WHERE     prli.sety_ref_num = p_sety
                  AND NVL (prli.sepa_ref_num, 9999999999) = NVL (p_sepa, 9999999999)
                  AND NVL (prli.sepv_ref_num, 9999999999) = NVL (p_sepv, 9999999999)
                  AND NVL (prli.end_date, p_start_date) >= p_start_date
                  AND prli.start_date <= p_end_date
                  AND prli.channel_type IS NULL
                  AND NVL (prli.par_value_charge, 'N') = 'N'
                  AND prli.once_off = p_once_off
                  AND prli.pro_rata = p_pro_rata
                  AND prli.regular_charge = p_regular_charge
                  and NVL(prli.daily_charge, 'N') = p_daily_charge  -- DOBAS-1622
                  AND fcit.once_off = p_once_off
                  AND fcit.pro_rata = p_pro_rata
                  AND fcit.regular_charge = p_regular_charge
                  and NVL(fcit.daily_charge, 'N') = p_daily_charge  -- DOBAS-1622
                  AND prli.sety_ref_num = fcit.sety_ref_num
                  AND fcit.package_category IS NULL
         ORDER BY 6, 7, 8, 9;

      ---
      CURSOR c_ficv (
         p_pro_rata        IN fixed_charge_item_types.pro_rata%TYPE
        ,p_once_off        IN fixed_charge_item_types.once_off%TYPE
        ,p_regular_charge  IN fixed_charge_item_types.regular_charge%TYPE
        ,p_daily_charge    IN fixed_charge_item_types.daily_charge%TYPE  -- DOBAS-1622
        ,p_sety            IN service_types.ref_num%TYPE
        ,p_sepa            IN service_parameters.ref_num%TYPE
        ,p_sepv            IN service_param_values.ref_num%TYPE
        ,p_chca            IN subs_charging_categories.chca_type_code%TYPE
        ,p_curr_start      IN DATE) IS
         SELECT   l_list_type_e hinnakiri
                 ,fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,ficv.charge_value charge_value
                 ,ficv.sety_ref_num sety
                 ,ficv.sepa_ref_num sepa
                 ,ficv.sepv_ref_num sepv
                 ,ficv.chca_type_code chca
                 ,GREATEST (ficv.start_date, p_start_date) start_date
                 ,ficv.end_date end_date
             FROM fixed_charge_values ficv, fixed_charge_item_types fcit
            WHERE     ficv.sety_ref_num IS NOT NULL
                  AND ficv.sept_type_code IS NULL
                  AND ficv.chca_type_code IS NOT NULL
                  AND ficv.channel_type IS NULL
                  AND NVL (ficv.par_value_charge, 'N') = 'N'
                  AND ficv.fcit_charge_code = fcit.type_code
                  AND fcit.once_off = p_once_off
                  AND fcit.pro_rata = p_pro_rata ---vaadata parameeter
                  AND fcit.regular_charge = p_regular_charge
                  and NVL(fcit.daily_charge, 'N') = p_daily_charge  -- DOBAS-1622
                  AND ficv.start_date >= p_curr_start
                  AND NVL (ficv.end_date, p_start_date) >= p_start_date
                  AND ficv.sety_ref_num = p_sety
                  AND ficv.sety_ref_num = fcit.sety_ref_num
                  AND NVL (ficv.sepa_ref_num, 9999999999) = NVL (p_sepa, 9999999999)
                  AND NVL (ficv.sepv_ref_num, 9999999999) = NVL (p_sepv, 9999999999)
                  AND ficv.chca_type_code = p_chca
         ORDER BY 10;
   -----------------------

   --
   BEGIN -- Start
      ---
      --- 2. võta lipud:
      emt_pricelist.get_flags (l_pro_rata, l_once_off, l_regular_charge, l_daily_charge, p_fcty_type);  -- DOBAS-1622

      -- 1. kustuta eelmine seis:
      DELETE emt_bill_price_list
       WHERE what = l_what AND fcty_type = p_fcty_type;

      -- 3. täida  -- pricelist master teenustele
      -- 0.sety_gr loop ; Grupeeritult teenused sety,sepa,sepv- neile on vaja teha hindu
      FOR i IN c_sety_gr (l_pro_rata, l_once_off, l_regular_charge, l_daily_charge) LOOP -- DOBAS-1622
         l_curr_start := NULL;

         -- 1.chca loop
         FOR j IN c_chca LOOP
            -- DBMS_OUTPUT.put_line('c_sety_gr, sety='||TO_CHAR(i.sety)||' ,sepa='||TO_CHAR(i.sepa)||
            --' ,sepv='||TO_CHAR(i.sepv)||' ,arv='||TO_CHAR(i.arv)||'c_chca='||j.chca);
            l_count_prli := 0;
            l_exit_prli := 0;
            --3.PRLI LOOP
            l_curr_start := l_min_start;
            l_curr_end := NULL;
            l_curr_end_ins := NULL;
            ---
            l_ebpl := NULL;
            l_ebpl.fcty_type := p_fcty_type;
            l_ebpl.what := l_what;
            l_ebpl.sety_ref_num := i.sety;
            l_ebpl.sepa_ref_num := i.sepa;
            l_ebpl.sepv_ref_num := i.sepv;
            l_ebpl.chargeable := 'Y'; -- esialgu kõik hinnatavateks
            l_ebpl.chca_type_code := j.chca;

            FOR k IN c_prli (l_pro_rata, l_once_off, l_regular_charge, l_daily_charge, i.sety, i.sepa, i.sepv) LOOP  -- DOBAS-1622
               --IF k.sety=3487015 THEN
               --DBMS_OUTPUT.put_line('c_prli, sety='||TO_CHAR(k.sety)||
               --   ' ,sepa='||TO_CHAR(k.sepa)||
               -- ' ,sepv='||TO_CHAR(k.sepv)||' ,start='||TO_CHAR(k.START_DATE,'dd.mm.yyyy')
               -- ||' ,end='||TO_CHAR(k.end_DATE,'dd.mm.yyyy')
               -- ||' ,charge_value='||TO_CHAR(k.charge_value)
               -- ||' ,j.chca='||j.chca
               -- );
               --END IF;
               l_ficv_count := 0; -- lipp,näitab , kas oli tingimustega erihindu
               l_count_prli := l_count_prli + 1;
               l_exit_ficv := 0;
               l_exit_prli := 0;

               --3.FICV LOOP
               FOR l
                  IN c_ficv (l_pro_rata, l_once_off, l_regular_charge, l_daily_charge, i.sety, i.sepa, i.sepv, j.chca, l_curr_start) LOOP  -- DOBAS-1622
                  l_ficv_count := l_ficv_count + 1; -- oli erihind

                  --IF k.sety=3487015 THEN
                  -- DBMS_OUTPUT.put_line('c_ficv* '||'l_ficv_count:='||TO_CHAR(l_ficv_count)
                  --||', l_curr_start='||TO_CHAR(l_curr_start,'dd.mm.yyyy')
                  --  ||', l_curr_end='||TO_CHAR(l_curr_end,'dd.mm.yyyy')
                  -- ||', PRLI k.start_date='||TO_CHAR(k.start_date,'dd.mm.yyyy')
                  -- ||', PRLI k.start_end='||TO_CHAR(k.end_date,'dd.mm.yyyy')
                  -- ||', FICV l.start_date='||TO_CHAR(l.start_date,'dd.mm.yyyy')
                  -- ||', FICV l.end_date='||TO_CHAR(l.end_date,'dd.mm.yyyy')
                  -- ||' ,j.chca='||j.chca
                  --);
                  --END IF;
                  -----------------------------------------------------------------------
                  IF GREATEST (k.start_date, l_curr_start) < l.start_date THEN
                     -- põhihinna.start < erihinna.start =>  aluseks PRLI
                     ----------------------------------------------------------------
                     l_curr_start := GREATEST (k.start_date, l_curr_start);

                     IF NVL (k.end_date, p_end_date) < l.start_date THEN
                        l_curr_end := k.end_date; -- ebareaalne et null,kuna l.START_DATE perioodi sees
                        l_exit_ficv := 1; -- järgmisena võta uus põhihinnakirja kirje aluseks
                     ELSE
                        l_curr_end := l.start_date - 1;
                     END IF;

                     --    IF k.sety=3487015 THEN
                     --    DBMS_OUTPUT.put_line('1.Täida PRLI järgi:l_curr_start='||
                     --  TO_CHAR(l_curr_start,'dd.mm.yyyy')||
                     --    ', l_curr_end='||TO_CHAR(l_curr_end,'dd.mm.yyyy')||', j.chca='||j.chca||
                     --    ', k.charge_value='||to_char(k.charge_value)||
                     --  ', l_exit_ficv='||to_char(l_exit_ficv));
                     -- END IF;
                     -- täida PRLI poolt ära algus pricelist on k.
                     IF l_curr_end >= p_end_date THEN
                        l_curr_end_ins := NULL;
                     ELSE
                        l_curr_end_ins := l_curr_end;
                     END IF;

                     l_ebpl.list_type := k.hinnakiri;
                     l_ebpl.fcit_type_code := k.fcit_type_code;
                     l_ebpl.taty_type_code := k.taty_type_code;
                     l_ebpl.billing_selector := k.billing_selector;
                     l_ebpl.charge_value := k.charge_value;
                     l_ebpl.start_date := l_curr_start;
                     l_ebpl.end_date := l_curr_end_ins;

                     emt_pricelist.ins_ebpl (l_ebpl, l_success, l_error_text);

                     IF (NOT l_success) THEN
                        RAISE some_errors;
                     END IF;

                     ---
                     -- Kui end_date sisestamisel oli null, võta järgmine  chca
                     IF l_curr_end_ins IS NULL THEN
                        l_exit_prli := 1;
                     END IF;

                     l_curr_start := l_curr_end + 1;

                     IF l_exit_ficv = 1 THEN -- võta aluseks uus prli kirje
                        EXIT; -- välju erihinnast ????
                     END IF;

                     -- uued piirid erihinna järgi
                     l_curr_end := l.end_date;

                     IF l_curr_end > p_end_date THEN
                        l_curr_end := NULL;
                     END IF;
                  --------------------------------------------------------------------------
                  ELSIF GREATEST (k.start_date, l_curr_start) >= l.start_date THEN
                     -- põhihinna.start >= erihinna.start   => sisesta ERIHINNA järgi
                     --------------------------------------------------------------------------
                     l_curr_start := l.start_date; -- erihinna.start
                     l_curr_end := LEAST (NVL (l.end_date, p_end_date), p_end_date);

                     IF l_curr_end >= p_end_date THEN -- erihinnakirja järgi lõpuni
                        -- l_curr_end:=NULL;  -- või jätan tuleviku end_date'i ??????????,vale koht
                        l_exit_prli := 1;
                     ELSIF l_curr_end >= NVL (k.end_date, p_end_date) THEN
                        -- võta järgmine PRLI kirje
                        l_exit_ficv := 1;
                     END IF;
                  -------------------------------------------------------------------------
                  END IF; --IF k.START_DATE < l.START_DATE THEN -- põhihinna.start < erihinna.start

                  --------------------------- Sisesta erihinnakirja poolt -----------------
                  --IF k.sety=3487015 THEN
                  -- DBMS_OUTPUT.put_line('2.Täida FICV järgi:l_curr_start='
                  -- TO_CHAR(l_curr_start,'dd.mm.yyyy')||
                  -- ', l_curr_end='||TO_CHAR(l_curr_end,'dd.mm.yyyy')||', j.chca='||j.chca||
                  -- ', l_exit_ficv='||to_char(l_exit_ficv)||
                  -- ', l_exit_prli='||to_char(l_exit_prli)
                  -- );
                  -- END IF;
                  IF l_curr_end >= p_end_date THEN
                     l_curr_end_ins := NULL;
                  ELSE
                     l_curr_end_ins := l_curr_end;
                  END IF;

                  l_ebpl.list_type := l.hinnakiri;
                  l_ebpl.fcit_type_code := l.fcit_type_code;
                  l_ebpl.taty_type_code := l.taty_type_code;
                  l_ebpl.billing_selector := l.billing_selector;
                  l_ebpl.charge_value := l.charge_value;
                  l_ebpl.start_date := l_curr_start;
                  l_ebpl.end_date := l_curr_end_ins;
                  emt_pricelist.ins_ebpl (l_ebpl, l_success, l_error_text);

                  IF (NOT l_success) THEN
                     RAISE some_errors;
                  END IF;

                  -------------------------------------------------------------------------
                  -- Kui end_date sisestamisel oli null, võta järgmine  chca
                  IF l_curr_end_ins IS NULL THEN
                     l_exit_prli := 1;
                  END IF;

                  l_curr_start := l_curr_end + 1;

                  IF l_curr_end >= NVL (k.end_date, p_end_date) OR (l_exit_ficv = 1) OR (l_exit_prli = 1) THEN -- võta järgmine PRLI kirje
                     EXIT;
                  END IF;
               END LOOP; -- ficv LOOP

               IF l_exit_prli = 1 THEN
                  -- erihinnakiri kirjutas perioodi lõpuni ennast täis , pole mõtet
                  -- põhihinnakirja vaadata
                  EXIT;
               END IF;

               IF l_ficv_count = 0 OR (l_ficv_count > 0 AND l_curr_start < NVL (k.end_date, p_end_date)) THEN
                  IF l_ficv_count = 0 THEN -- setyl puudub erihind vahet pole kas 1 hind või 2 hinda
                     -- täida tabel põhihinnakirja järgi:
                     l_curr_start := k.start_date;
                  END IF;

                  IF k.end_date >= p_end_date THEN
                     l_curr_end := NULL;
                  ELSE
                     l_curr_end := k.end_date;
                  END IF;

                  -- täida tabel põhihinnakirja järgi:
                  --DBMS_OUTPUT.put_line('4.Täida PRLI järgi:l_curr_start='
                  --||TO_CHAR(l_curr_start,'dd.mm.yyyy')||
                  --', k.end_date='||TO_CHAR(k.end_date,'dd.mm.yyyy')||', j.chca='||j.chca||
                  --', k.charge_value='||to_char(k.charge_value)||
                  --', l_exit_ficv='||to_char(l_exit_ficv));
                  l_ebpl.list_type := k.hinnakiri;
                  l_ebpl.fcit_type_code := k.fcit_type_code;
                  l_ebpl.taty_type_code := k.taty_type_code;
                  l_ebpl.billing_selector := k.billing_selector;
                  l_ebpl.charge_value := k.charge_value;
                  l_ebpl.start_date := l_curr_start;
                  l_ebpl.end_date := l_curr_end;
                  emt_pricelist.ins_ebpl (l_ebpl, l_success, l_error_text);

                  IF (NOT l_success) THEN
                     RAISE some_errors;
                  END IF;
               END IF; --IF l_ficv_count=0 or ....THEN ..LÕPP
            --
            END LOOP; -- PRLI loop
         END LOOP; -- chca loop
      END LOOP; --c_sety_gr loop

      --
      UPDATE emt_bill_price_list a1
         SET chargeable = 'N'
       WHERE what = l_what AND fcty_type = p_fcty_type
             AND sety_ref_num IN
                    (SELECT   sety_ref_num
                         FROM emt_bill_price_list a
                        WHERE a.what = l_what AND a.fcty_type = p_fcty_type
                              AND NOT EXISTS
                                         (SELECT 1
                                            FROM emt_bill_price_list b
                                           WHERE     a.sety_ref_num = b.sety_ref_num
                                                 AND b.what = l_what
                                                 AND fcty_type = p_fcty_type
                                                 AND b.charge_value <> 0)
                              AND NOT EXISTS
                                         (SELECT 1
                                            FROM master_service_adjustments masa
                                           WHERE     NVL (masa.charge_value, 0) > 0
                                                 AND masa.start_date <= p_end_date
                                                 AND NVL (masa.end_date, p_end_date) >= p_start_date
                                                 AND masa.sety_ref_num = a.sety_ref_num
                                                 AND ROWNUM = 1)
                     GROUP BY sety_ref_num);

      COMMIT;
   ---

   EXCEPTION
      WHEN some_errors THEN
         p_success := FALSE;
         p_error_text := l_error_text;
         ROLLBACK;
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := 'Viga! <EBPL_maac_services> ' || SQLERRM;
         ROLLBACK;
   END ebpl_maac_services;

   --------------------------------------------------------------------------------
   --------------------------------------------------------------------------------
   PROCEDURE mob_sety_charges (p_fcty_type         fixed_charge_types.type_code%TYPE
                              ,p_start_period      DATE
                              ,p_end_period        DATE
                              ,p_success       OUT BOOLEAN
                              ,p_error_text    OUT VARCHAR2
                              ) IS
      --

      CURSOR c_pack (p_start_date DATE) IS
         SELECT *
           FROM serv_package_types
          WHERE NVL (end_date, SYSDATE) > p_start_date --and type_code='DESE'
                                                      ;

      --

      CURSOR c_service (
         p_pro_rata         VARCHAR2
        ,p_once_off         VARCHAR2
        ,p_regular_charge   VARCHAR2
        ,p_daily_charge   VARCHAR2) IS  -- DOBAS-1622
         SELECT *
           FROM service_types s
          WHERE EXISTS
                   (SELECT 1
                      FROM price_lists
                     WHERE     sety_ref_num = s.ref_num
                           AND pro_rata = p_pro_rata
                           AND once_off = p_once_off
                           AND nvl(daily_charge, 'N') = p_daily_charge -- DOBAS-1622
                           AND regular_charge = p_regular_charge)
                AND secl_class_code NOT IN ('M', 'Q')
                AND NVL (information_pack, '*') <> 'KONTO' --and ref_num=3977077
                                                          ;

      --

      CURSOR c_values_sety_value (
         p_sety_ref_num     service_types.ref_num%TYPE
        ,p_sept_type_code   subs_packages.sept_type_code%TYPE
        ,p_pro_rata         VARCHAR2
        ,p_once_off         VARCHAR2
        ,p_regular_charge   VARCHAR2
        ,p_daily_charge     VARCHAR2  -- DOBAS-1622
        ,p_end_date         DATE
        ,p_start_date       DATE) IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,ficv.charge_value charge_value
                 ,fcit.future_period fcit_future_period
                 ,ficv.sepv_ref_num sepv_ref_num
                 ,ficv.sepa_ref_num sepa_ref_num
                 ,fcit.package_category package_category
                 ,GREATEST (ficv.start_date, p_start_date) start_date
                 ,LEAST (NVL (ficv.end_date, p_end_date), p_end_date) end_date
                 ,ficv.end_date save_end_date
             FROM fixed_charge_values ficv, fixed_charge_item_types fcit
            WHERE     ficv.sety_ref_num = p_sety_ref_num
                  AND ficv.sept_type_code = p_sept_type_code
                  AND ficv.chca_type_code IS NULL
                  AND ficv.channel_type IS NULL
                  AND NVL (ficv.par_value_charge, 'N') = 'N'
                  AND ficv.fcit_charge_code = fcit.type_code
                  AND fcit.once_off = p_once_off
                  AND fcit.pro_rata = p_pro_rata ---vaadata parameeter
                  AND fcit.regular_charge = p_regular_charge
                  and NVL(fcit.daily_charge, 'N') = p_daily_charge  -- DOBAS-1622
                  AND ficv.start_date <= p_end_date
                  AND NVL (ficv.end_date, p_end_date) >= p_start_date
         ORDER BY ficv.start_date, ficv.end_date;

      l_end_value_date              DATE := NULL;
      l_start_value_date            DATE;
      l_start_date                  DATE;
      l_end_date                    DATE;
      l_charge_value                NUMBER (14, 2);
      l_on_pack                     NUMBER := 0;
      l_discount_type               VARCHAR2 (4);
      l_ebpl_row                    emt_bill_price_list%ROWTYPE;
      l_pro_rata                    fixed_charge_item_types.pro_rata%TYPE := 'Y';
      l_once_off                    fixed_charge_item_types.once_off%TYPE := 'N';
      l_regular_charge              fixed_charge_item_types.regular_charge%TYPE := 'N';
      l_daily_charge                fixed_charge_item_types.daily_charge%TYPE := 'N';  -- DOBAS-1622

      u_err_creating                EXCEPTION;


      PROCEDURE mob_prli_sety_charges (p_success           IN OUT BOOLEAN
                                      ,p_error_text        IN OUT VARCHAR2
                                      ,p_period                   DATE
                                      ,p_sept_type_code           subs_packages.sept_type_code%TYPE
                                      ,p_sety_ref_num             service_types.ref_num%TYPE
                                      ,p_start_date               DATE
                                      ,p_end_date                 DATE
                                      ,p_last_date                DATE
                                      , --kuni milleni
                                       p_nety_type_code           subs_serv_groups.nety_type_code%TYPE
                                      ,p_package_category         price_lists.package_category%TYPE
                                      ,p_pro_rata                 fixed_charge_item_types.pro_rata%TYPE
                                      ,p_once_off                 fixed_charge_item_types.pro_rata%TYPE
                                      ,p_regular_charge           fixed_charge_item_types.regular_charge%TYPE
                                      ,p_daily_charge             fixed_charge_item_types.daily_charge%TYPE  -- DOBAS-1622
                                      ) IS
         --teenuse hinnad tabelist price_lists
         CURSOR c_prices_cat_sety_values (
            p_package_category   VARCHAR2
           ,p_nety_type_code     VARCHAR2
           ,p_sety_ref_num       service_types.ref_num%TYPE
           ,p_start_date         DATE
           ,p_end_date           DATE) IS
            SELECT   fcit.type_code fcit_type_code
                    ,fcit.taty_type_code taty_type_code
                    ,fcit.billing_selector billing_selector
                    ,prli.charge_value charge_value
                    ,fcit.future_period fcit_future_period
                    ,prli.sepv_ref_num sepv_ref_num
                    ,prli.sepa_ref_num sepa_ref_num
                    ,prli.package_category package_category
                    ,GREATEST (prli.start_date, p_start_date) start_date
                    ,LEAST (NVL (prli.end_date, p_end_date), p_end_date) end_date
                    ,prli.end_date save_end_date
                FROM price_lists prli, fixed_charge_item_types fcit
               WHERE     prli.sety_ref_num = p_sety_ref_num
                     AND (prli.package_category = p_package_category AND prli.nety_type_code = p_nety_type_code)
                     AND prli.channel_type IS NULL
                     AND NVL (prli.par_value_charge, 'N') = 'N'
                     AND prli.once_off = p_once_off
                     AND prli.pro_rata = p_pro_rata
                     AND prli.regular_charge = p_regular_charge
                     and NVL(prli.daily_charge, 'N') = p_daily_charge  -- DOBAS-1622
                  AND fcit.once_off = p_once_off
                     AND fcit.pro_rata = p_pro_rata
                     AND fcit.regular_charge = p_regular_charge
                     and NVL(fcit.daily_charge, 'N') = p_daily_charge  -- DOBAS-1622
                     AND prli.sety_ref_num = fcit.sety_ref_num
                     AND fcit.package_category = p_package_category
                     AND prli.start_date <= p_end_date
                     AND NVL (prli.end_date, p_end_date) >= p_start_date
            ORDER BY prli.start_date;

         --
         l_on_pack                     NUMBER := 0;
         l_charge_value                invoice_entries.eek_amt%TYPE;
         l_discount_type               VARCHAR2 (4);
         l_success                     BOOLEAN;

         ll_start_date                 DATE;
         ll_end_date                   DATE;

         e_mob_sety_2                  EXCEPTION;

         PROCEDURE mob_prli_sety_charges_2 (p_success           IN OUT BOOLEAN
                                           , --hh
                                            p_error_text        IN OUT VARCHAR2
                                           ,p_period                   DATE
                                           ,p_sept_type_code           subs_packages.sept_type_code%TYPE
                                           ,p_sety_ref_num             service_types.ref_num%TYPE
                                           ,p_start_date               DATE
                                           ,p_end_date                 DATE
                                           ,p_last_date                DATE
                                           , --kuni milleni
                                            p_nety_type_code           subs_serv_groups.nety_type_code%TYPE
                                           ,p_package_category         price_lists.package_category%TYPE
                                           ,p_pro_rata                 fixed_charge_item_types.pro_rata%TYPE
                                           ,p_once_off                 fixed_charge_item_types.pro_rata%TYPE
                                           ,p_regular_charge           fixed_charge_item_types.regular_charge%TYPE
                                           ,p_daily_charge             fixed_charge_item_types.daily_charge%TYPE  -- DOBAS-1622
                                           ) IS
            CURSOR c_prices_sety_values (
               p_package_category   VARCHAR2
              ,p_nety_type_code     VARCHAR2
              ,p_sety_ref_num       service_types.ref_num%TYPE
              ,p_start_date         DATE
              ,p_end_date           DATE) IS
               SELECT   fcit.type_code fcit_type_code
                       ,fcit.taty_type_code taty_type_code
                       ,fcit.billing_selector billing_selector
                       ,prli.charge_value charge_value
                       ,fcit.future_period fcit_future_period
                       ,prli.sepv_ref_num sepv_ref_num
                       ,prli.sepa_ref_num sepa_ref_num
                       ,prli.package_category package_category
                       ,GREATEST (prli.start_date, p_start_date) start_date
                       ,LEAST (NVL (prli.end_date, p_end_date), p_end_date) end_date
                       ,prli.end_date save_end_date
                   FROM price_lists prli, fixed_charge_item_types fcit
                  WHERE     prli.sety_ref_num = p_sety_ref_num
                        AND prli.package_category IS NULL
                        AND prli.channel_type IS NULL
                        AND NVL (prli.par_value_charge, 'N') = 'N'
                        AND prli.once_off = p_once_off
                        AND prli.pro_rata = p_pro_rata
                        AND prli.regular_charge = p_regular_charge
                        and NVL(prli.daily_charge, 'N') = p_daily_charge  -- DOBAS-1622
                        AND fcit.once_off = p_once_off
                        AND fcit.pro_rata = p_pro_rata
                        AND fcit.regular_charge = p_regular_charge
                        and NVL(fcit.daily_charge, 'N') = p_daily_charge  -- DOBAS-1622
                        AND prli.sety_ref_num = fcit.sety_ref_num
                        AND fcit.package_category = p_package_category
                        AND prli.start_date <= p_end_date
                        AND NVL (prli.end_date, p_end_date) >= p_start_date
               ORDER BY prli.start_date;

            --
            e_ins_ebpl                    EXCEPTION;
         BEGIN
            FOR rec_pp
               IN c_prices_sety_values (p_package_category, p_nety_type_code, p_sety_ref_num, p_start_date, p_end_date) LOOP
               l_ebpl_row := NULL;
               l_ebpl_row.fcty_type := p_fcty_type;
               l_ebpl_row.what := 'Mobiili teenused';
               l_ebpl_row.list_type := 'Põhihind';
               l_ebpl_row.fcit_type_code := rec_pp.fcit_type_code;
               l_ebpl_row.taty_type_code := rec_pp.taty_type_code;
               l_ebpl_row.billing_selector := rec_pp.billing_selector;
               l_ebpl_row.charge_value := rec_pp.charge_value;
               l_ebpl_row.sept_type_code := p_sept_type_code;
               l_ebpl_row.sety_ref_num := p_sety_ref_num;
               l_ebpl_row.sepa_ref_num := rec_pp.sepa_ref_num;
               l_ebpl_row.sepv_ref_num := rec_pp.sepv_ref_num;
               l_ebpl_row.chargeable := 'Y'; -- esialgu kõik hinnatavateks
               l_ebpl_row.start_date := rec_pp.start_date;

               IF p_last_date = p_end_date THEN
                  l_ebpl_row.end_date := rec_pp.save_end_date;
                  emt_pricelist.ins_ebpl (l_ebpl_row, l_success, p_error_text);

                  IF NOT l_success THEN
                     RAISE e_ins_ebpl;
                  END IF;
               ELSE
                  l_ebpl_row.end_date := rec_pp.end_date;
                  emt_pricelist.ins_ebpl (l_ebpl_row, l_success, p_error_text);

                  IF NOT l_success THEN
                     RAISE e_ins_ebpl;
                  END IF;
               END IF;
            END LOOP;

            p_success := TRUE;
         EXCEPTION
            WHEN e_ins_ebpl THEN
               ROLLBACK;
               insert_batch_messages (c_module_ref, c_module_name, 9999, SQLCODE || SQLERRM, ' ');
               insert_batch_messages (c_module_ref
                                     ,c_module_name
                                     ,9999
                                     ,'Vigane lõpp. Mob_sety_prices :' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                                     ,' '
                                     );
               p_success := FALSE;
            WHEN OTHERS THEN
               p_success := FALSE;
               insert_batch_messages (c_module_ref, c_module_name, 9999, SQLCODE || SQLERRM, ' ');
               insert_batch_messages (c_module_ref
                                     ,c_module_name
                                     ,9999
                                     ,'Vigane lõpp. Mob_sety_prices :' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                                     ,' '
                                     );
         END mob_prli_sety_charges_2;
      -------------------------------------------------------------------------------

      BEGIN
         ll_start_date := p_start_date;
         ll_end_date := p_end_date;


         FOR rec_p
            IN c_prices_cat_sety_values (p_package_category
                                        ,p_nety_type_code
                                        ,p_sety_ref_num
                                        ,p_start_date
                                        ,p_end_date
                                        ) LOOP
            IF rec_p.start_date > ll_start_date THEN
               -- alates ll_start_date
               ll_end_date := rec_p.start_date - 1;
               -- hinda paketita kuni start_dateni-----------------------------------------
               mob_prli_sety_charges_2 (p_success
                                       ,p_error_text
                                       ,l_start_date
                                       ,p_sept_type_code
                                       ,p_sety_ref_num
                                       ,ll_start_date
                                       ,ll_end_date
                                       ,p_last_date
                                       ,p_nety_type_code
                                       ,p_package_category
                                       ,p_pro_rata
                                       ,p_once_off
                                       ,p_regular_charge
                                       ,p_daily_charge  -- DOBAS-1622
                                       );

               IF NOT p_success THEN
                  RAISE e_mob_sety_2;
               END IF;

               ll_start_date := ll_end_date + 1;
            END IF;

            --dbms_output.put_line('MON_PRLI_SETY: category '||rec_p.package_category ||' nety '
            --|| p_nety_type_code||
            --' start '||to_char(rec_p.start_date)||' end '||to_char(rec_p.end_date)
            --||' hind '||to_char(rec_p.charge_value));


            --dbms_output.put_line('MON_PRLI_SETY: rec_p.charge_value >0');

            l_ebpl_row := NULL;
            l_ebpl_row.fcty_type := p_fcty_type;
            l_ebpl_row.what := 'Mobiili teenused';
            l_ebpl_row.list_type := 'Põhihind';
            l_ebpl_row.fcit_type_code := rec_p.fcit_type_code;
            l_ebpl_row.taty_type_code := rec_p.taty_type_code;
            l_ebpl_row.billing_selector := rec_p.billing_selector;
            l_ebpl_row.charge_value := rec_p.charge_value;
            l_ebpl_row.sept_type_code := p_sept_type_code;
            l_ebpl_row.sety_ref_num := p_sety_ref_num;
            l_ebpl_row.sepa_ref_num := rec_p.sepa_ref_num;
            l_ebpl_row.sepv_ref_num := rec_p.sepv_ref_num;
            l_ebpl_row.chargeable := 'Y'; -- esialgu kõik hinnatavateks
            l_ebpl_row.start_date := rec_p.start_date;


            IF p_last_date = p_end_date THEN
               l_ebpl_row.end_date := rec_p.save_end_date;
               ll_start_date := rec_p.end_date + 1;
               emt_pricelist.ins_ebpl (l_ebpl_row, p_success, p_error_text);
            ELSE
               l_ebpl_row.end_date := rec_p.end_date;
               ll_start_date := rec_p.end_date + 1;
               emt_pricelist.ins_ebpl (l_ebpl_row, p_success, p_error_text);
            END IF;



            ll_start_date := rec_p.end_date + 1;
         END LOOP;

         IF ll_start_date < p_end_date THEN
            mob_prli_sety_charges_2 (p_success
                                    ,p_error_text
                                    ,l_start_date
                                    ,p_sept_type_code
                                    ,p_sety_ref_num
                                    ,ll_start_date
                                    ,p_end_date
                                    ,p_last_date
                                    ,p_nety_type_code
                                    ,p_package_category
                                    ,p_pro_rata
                                    ,p_once_off
                                    ,p_regular_charge
                                    ,p_daily_charge  -- DOBAS-1622
                                    );

            IF NOT p_success THEN
               RAISE e_mob_sety_2;
            END IF;
         END IF;

         p_success := TRUE;
      EXCEPTION
         WHEN e_mob_sety_2 THEN
            p_success := FALSE;
         WHEN OTHERS THEN
            ROLLBACK;
            p_success := FALSE;

            p_error_text := SQLCODE || SQLERRM;

            insert_batch_messages (c_module_ref, c_module_name, 9999, SQLCODE || SQLERRM, ' ');
            insert_batch_messages (c_module_ref
                                  ,c_module_name
                                  ,9999
                                  ,'Vigane lõpp. Mob_CAT_sety_prices :' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                                  ,' '
                                  );
      END mob_prli_sety_charges;
   -------------------------------------------------------------------------
   -------------------------------------------------------------------------
   ---teenuse hind tabelist fixed_charge_values

   BEGIN
      --DBMS_OUTPUT.enable(1000000);
      --DBMS_OUTPUT.Put_Line('...'||to_char(r.));

      insert_batch_messages (c_module_ref
                            ,c_module_name
                            ,9999
                            ,'Mobiili teenused(Mob_sety_prices) algus :' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                            ,' '
                            );


      DELETE FROM emt_bill_price_list
            WHERE sept_type_code IS NOT NULL AND sety_ref_num IS NOT NULL AND fcty_type = p_fcty_type;

      l_start_date := p_start_period;
      l_end_date := NVL (p_end_period, LAST_DAY (SYSDATE));

      emt_pricelist.get_flags (l_pro_rata, l_once_off, l_regular_charge, l_daily_charge, p_fcty_type);  -- DOBAS-1622

      FOR r_pack IN c_pack (l_start_date) LOOP
         --DBMS_OUTPUT.Put_Line('...'||r_pack.type_code);


         FOR c_serv IN c_service (l_pro_rata, l_once_off, l_regular_charge, l_daily_charge) LOOP -- DOBAS-1622
            l_end_value_date := NULL;
            l_start_value_date := NULL;
            l_charge_value := NULL;

            --DBMS_OUTPUT.Put_Line('...'||to_char(c_serv.ref_num));
            FOR rec_v
               IN c_values_sety_value (c_serv.ref_num
                                      ,r_pack.type_code
                                      ,l_pro_rata
                                      ,l_once_off
                                      ,l_regular_charge
                                      ,l_daily_charge  -- DOBAS-1622
                                      ,l_end_date
                                      ,l_start_date
                                      ) LOOP
               --dbms_output.put_line('MON_SETY: fcit_type_code: ' || rec_v.fcit_type_code ||
               -- ' biL-sel: '|| rec_v.billing_selector || ' charge: '|| rec_v.charge_value ||
               -- ' sepv: ' ||  rec_v.sepv_ref_num || ' sepa: ' || rec_v.sepa_ref_num  || ' pac_cat: ' ||
               --rec_v.package_category || ' start: ' || rec_v.start_date || ' end: ' || rec_v.end_date);

               IF l_start_value_date IS NULL THEN
                  IF rec_v.start_date > l_start_date THEN
                     ----hinda prli p_start_date kuni rec_v.start_date-1 st. hinda algus
                     --dbms_output.put_line('MON_SETY:  call MONTHLY_PRLI_SETY_CHARGE 1');
                     mob_prli_sety_charges (p_success
                                           ,p_error_text
                                           ,l_start_date
                                           ,r_pack.type_code
                                           ,c_serv.ref_num
                                           ,l_start_date
                                           ,rec_v.start_date - 1
                                           ,l_end_date
                                           ,r_pack.nety_type_code
                                           ,r_pack.category
                                           ,l_pro_rata
                                           ,l_once_off
                                           ,l_regular_charge
                                           ,l_daily_charge  -- DOBAS-1622
                                           );

                     IF NOT p_success THEN
                        RAISE u_err_creating;
                     END IF;
                  END IF;

                  l_start_value_date := rec_v.start_date;
               ELSE
                  IF TRUNC (rec_v.start_date) > TRUNC (l_end_value_date + 1) THEN
                     ----hinda prli l_end_value_date kuni rec_v.start_date-1( auk values-is) st hinda auk
                     --dbms_output.put_line('MON_SETY:  call MONTHLY_PRLI_SETY_CHARGE 2');
                     mob_prli_sety_charges (p_success
                                           ,p_error_text
                                           ,l_start_date
                                           ,r_pack.type_code
                                           ,c_serv.ref_num
                                           ,l_end_value_date + 1
                                           ,rec_v.start_date - 1
                                           ,l_end_date
                                           ,r_pack.nety_type_code
                                           ,r_pack.category
                                           ,l_pro_rata
                                           ,l_once_off
                                           ,l_regular_charge
                                           ,l_daily_charge  -- DOBAS-1622
                                           );

                     IF NOT p_success THEN
                        RAISE u_err_creating;
                     END IF;
                  END IF;
               END IF;

               --hinda nüüd leitud ficv rec_v.start_date kuni rec_v.end_date
               l_ebpl_row := NULL;
               l_ebpl_row.fcty_type := p_fcty_type;
               l_ebpl_row.what := 'Mobiili teenused';
               l_ebpl_row.list_type := 'Erihind';
               l_ebpl_row.fcit_type_code := rec_v.fcit_type_code;
               l_ebpl_row.taty_type_code := rec_v.taty_type_code;
               l_ebpl_row.billing_selector := rec_v.billing_selector;
               l_ebpl_row.charge_value := rec_v.charge_value;
               l_ebpl_row.sept_type_code := r_pack.type_code;
               l_ebpl_row.sety_ref_num := c_serv.ref_num;
               l_ebpl_row.sepa_ref_num := rec_v.sepa_ref_num;
               l_ebpl_row.sepv_ref_num := rec_v.sepv_ref_num;
               l_ebpl_row.chargeable := 'Y'; -- esialgu kõik hinnatavateks
               l_ebpl_row.start_date := rec_v.start_date;
               l_ebpl_row.end_date := rec_v.save_end_date;

               emt_pricelist.ins_ebpl (l_ebpl_row, p_success, p_error_text);


               l_end_value_date := GREATEST (NVL (l_end_value_date, rec_v.end_date), rec_v.end_date);
            END LOOP;

            IF l_start_value_date IS NOT NULL THEN
               IF l_end_value_date < l_end_date THEN
                  --hinda prli l_end_value_date+1 kuni p_end_date
                  --dbms_output.put_line('MON_SETY:  call MONTHLY_PRLI_SETY_CHARGE 3');
                  mob_prli_sety_charges (p_success
                                        ,p_error_text
                                        ,l_start_date
                                        ,r_pack.type_code
                                        ,c_serv.ref_num
                                        ,l_end_value_date + 1
                                        ,l_end_date
                                        ,l_end_date
                                        ,r_pack.nety_type_code
                                        ,r_pack.category
                                        ,l_pro_rata
                                        ,l_once_off
                                        ,l_regular_charge
                                        ,l_daily_charge  -- DOBAS-1622
                                        );

                  IF NOT p_success THEN
                     RAISE u_err_creating;
                  END IF;
               END IF;
            ELSE
               --dbms_output.put_line('MON_SETY: call MONTHLY_PRLI_SETY_CHARGE 4');
               mob_prli_sety_charges (p_success
                                     ,p_error_text
                                     ,l_start_date
                                     ,r_pack.type_code
                                     ,c_serv.ref_num
                                     ,l_start_date
                                     ,l_end_date
                                     ,l_end_date
                                     ,r_pack.nety_type_code
                                     ,r_pack.category
                                     ,l_pro_rata
                                     ,l_once_off
                                     ,l_regular_charge
                                     ,l_daily_charge  -- DOBAS-1622
                                     );

               IF NOT p_success THEN
                  RAISE u_err_creating;
               END IF;
            END IF;
         END LOOP;
      END LOOP;

      p_success := TRUE;
      insert_batch_messages (c_module_ref
                            ,c_module_name
                            ,9999
                            ,'Mobiili teenused(Mob_sety_prices) lõpp :' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                            ,' '
                            );
   EXCEPTION
      WHEN u_err_creating THEN
         ROLLBACK;
         p_success := FALSE;
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_error_text := SQLCODE || SQLERRM;
         insert_batch_messages (c_module_ref, c_module_name, 9999, SQLCODE || SQLERRM, ' ');
         insert_batch_messages (c_module_ref
                               ,c_module_name
                               ,9999
                               ,'Vigane lõpp. Mob_sety_values :' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                               ,' '
                               );
   END mob_sety_charges;

   --------------------------------------------------------------------------------
   --------------------------------------------------------------------------------
   PROCEDURE start_ebpl (p_fcty_type IN fixed_charge_types.type_code%TYPE DEFAULT 'MCH') IS
      -- KÄIVITATAV programm **
      --------------------------------------------------------------------------------
      -- NB! Tähelepanekud:
      -- a)võibolla kuumaksude töötamise ajal(MAIN BILL) panna peale piirang, et tabelit ei uuendata
      -- seda igaks juhuks
      -- !!! Ei kontrolli.Las uuendab. !!!
      -- b)Protsess võiks käia iga tööpäeva lõpus näit.kell 22.00 või hiljem
      -- Funktsionaalsus:
      -- Kui tabelis emt_bill_price_list.chargeable='N' , siis kuumakse sellele sety_ref_num'le
      -- ei arvutata (siis pole ka parameetritega väärtust sellel sety'l hinnakirjas)
      --------------------------------------------------------------------------------
      -- 2. Konto taseme teenuste hinnakirja tabelisse viimine
      -- 3. Mobiili taseme teenuste hinnakirja tabelisse viimine
      -- 4. Mobiili paketi kuumaksude hinnakirja tabelisse viimine
      --
      CURSOR c_tbcis_proc IS
         SELECT *
           FROM tbcis_processes
          WHERE module_ref = 'BCCU1277';

      l_tbpr_row                    tbcis_processes%ROWTYPE := NULL;
      --
      l_what                        emt_bill_price_list.what%TYPE := NULL;
      l_list_type_p                 emt_bill_price_list.list_type%TYPE := 'Põhihind';
      l_list_type_e                 emt_bill_price_list.list_type%TYPE := 'Erihind';
      --------------------------------------------------------------------------------
      --l_check_date  DATE:=TRUNC(SYSDATE);
      -- hinnakirja kandmise vahemik: l_start ja l_end
      -- Kui hinnakirjas teenus pole lõpetatud, siis end_date jääb tühjaks
      l_start                       DATE := NULL;
      l_end                         DATE := NULL;
      -------------------------------------------
      l_db_name                     VARCHAR2 (30) := NULL;
      l_bame_row                    bcc_batch_messages%ROWTYPE := NULL;
      l_success                     BOOLEAN;
      l_error_text                  VARCHAR2 (255) := NULL;
      l_found                       BOOLEAN;
      --
      errors                        EXCEPTION;
   ----------------------------------------------------------------

   BEGIN
      DBMS_OUTPUT.enable (1000000000);

      SELECT SYS_CONTEXT ('USERENV', 'DB_NAME') INTO l_db_name FROM DUAL;

      --0.1.Registreeri start ;tabel:bcc_Batch_Messages

      l_bame_row.module_ref := c_module_ref;
      l_bame_row.module_desc := c_module_name;
      l_bame_row.MESSAGE_TEXT :=    'Start_EBPL. EMT-i hinnakirja uuendamine. Algus:'
                                 || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                                 || ' ,param.:'
                                 || p_fcty_type;
      l_bame_row.parameters := p_fcty_type;
      ins_batch_messages (l_bame_row);
      COMMIT;

      ------------------------------------------------------------------------------
      -- 0.2.kontrolli/registreeri käivitus tabelisse <tbcis_processes>
      OPEN c_tbcis_proc;

      FETCH c_tbcis_proc INTO l_tbpr_row;

      l_found := c_tbcis_proc%FOUND;

      CLOSE c_tbcis_proc;

      --
      IF (NOT l_found) THEN
         --  registreeri käivitus tabelisse <tbcis_processes>,koos uue kirje loomisega
         INSERT
           INTO tbcis_processes (module_ref
                                ,module_desc
                                ,module_params
                                ,start_date
                                ,end_date
                                ,everyday
                                ,date_created
                                ,created_by
                                )
         VALUES (c_module_ref
                ,c_module_name
                ,c_fcty_type
                ,SYSDATE
                ,NULL
                ,'Y'
                ,SYSDATE
                ,sec.get_username
                );

         COMMIT;
      ELSE
         IF l_tbpr_row.end_date IS NULL THEN -- protsess töötab
            -- kõigil ülejäänud juhtudel stardi protsess
            l_bame_row.MESSAGE_TEXT := 'Töötab juba,ei käivitu uuesti,tabel <Tbcis_processes.end_date is null> !';
            ins_batch_messages (l_bame_row);
            COMMIT;
            RAISE errors;
         END IF;
      END IF;

      --
      -- registreeri käivitus tabelisse <tbcis_processes>
      UPDATE tbcis_processes
         SET start_date = SYSDATE
            ,last_updated = SYSDATE
            ,last_updated_by = sec.get_username
            ,end_date = NULL
            ,end_code = NULL
       WHERE module_ref = c_module_ref;

      COMMIT;
      ------------------------------------------------------------------------------
      -- 0.3.kontrolli kas kuumaksud on edukalt lõpetanud
      -- NB! EI KONTROLLI !!!!
      /*
      IF l_db_name = 'LIVE' THEN -- kontrolli vaid LIVES
         IF (NOT  Monthly_Charges_OK) THEN
            l_bame_row.message_text:='VIGA !!! Kuumaksudega pole kõik OK ! Process ei käivitu';
            Ins_Batch_Messages(l_bame_row);
            COMMIT;
            RAISE errors;
         END IF;
      END IF;
      */
      -- 1. määratleb perioodi , millised hinnakirja andmed võtab kaasa
      get_period_start_end (l_start, l_end);

      IF l_start IS NULL OR l_end IS NULL OR l_end < l_start THEN
         l_bame_row.MESSAGE_TEXT :=    'VIGA perioodi start/end kuupäevades !'
                                    || ' l_start='
                                    || TO_CHAR (l_start, 'dd.mm.yyyy hh24:mi:ss')
                                    || ' l_end='
                                    || TO_CHAR (l_end, 'dd.mm.yyyy hh24:mi:ss');
         --
         ins_batch_messages (l_bame_row);
         COMMIT;
         RAISE errors;
      END IF;

      -- 2. Konto taseme teenuste hinnakirja tabelisse viimine algus ****************

      -- 2.a registreeri samm
      l_bame_row.MESSAGE_TEXT :=    'Konto teenused(EBPL_maac_services), algus:'
                                 || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                                 || ' ,param.:'
                                 || p_fcty_type;
      l_bame_row.parameters := p_fcty_type;
      ins_batch_messages (l_bame_row);
      COMMIT;

      ebpl_maac_services (l_start, l_end, p_fcty_type, l_success, l_error_text);

      -- 2.a registreeri sammu lõpp
      IF (NOT l_success) THEN --mitteeduks
         ROLLBACK;
         l_bame_row.MESSAGE_TEXT := 'VIGA! Konto teenuseid ei uuendatud!' || l_error_text;
         ins_batch_messages (l_bame_row);
         COMMIT;
         RAISE errors;
      ELSE --edukas
         l_bame_row.MESSAGE_TEXT :=    'Konto teenused(EBPL_maac_services), lõpp:'
                                    || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                                    || ' ,param.:'
                                    || p_fcty_type;
         ins_batch_messages (l_bame_row);
         COMMIT;
      END IF;

      -- 2. Konto taseme teenuste hinnakirja tabelisse viimise lõpp******************
      --*****************************************************************************

      -- 3. Mobiili taseme teenuste hinnakirja tabelisse viimine
      mob_sety_charges (p_fcty_type, l_start, l_end, l_success, l_error_text);

      IF (NOT l_success) THEN
         ROLLBACK;
         l_bame_row.MESSAGE_TEXT := 'VIGA! Mobiili teenuseid ei uuendatud!' || l_error_text;
         ins_batch_messages (l_bame_row);
         COMMIT;
         RAISE errors;
      ELSE
         IF p_fcty_type='RCH' THEN
         Tbcis.Temp_EMT_hinnakiri;
         l_bame_row.MESSAGE_TEXT := 'RCH Teenuste hinnad täiendatud!' ;
         ins_batch_messages (l_bame_row);
         END IF;
         IF p_fcty_type='DCH' THEN
           Tbcis.Temp_EMT_hinnakiri2;
           l_bame_row.MESSAGE_TEXT := 'RCH Teenuste hinnad täiendatud!' ;
           ins_batch_messages (l_bame_row);
         END IF;
      END IF; 
      -- 5. Normaalse töölõpu registreerimine

      --- tabel:bcc_Batch_Messages
      l_bame_row.MESSAGE_TEXT := 'Start_EBPL. Normaalne lõpp.';
      ins_batch_messages (l_bame_row);

      --- tabel:tbcis_processes
      UPDATE tbcis_processes
         SET last_updated = SYSDATE, last_updated_by = sec.get_username, end_date = SYSDATE, end_code = 'OK'
       WHERE module_ref = c_module_ref;

      COMMIT;
   EXCEPTION
      WHEN errors THEN
         --- tabel:bcc_Batch_Messages
         l_bame_row.MESSAGE_TEXT := 'Start_EBPL. Ebanormaalne lõpp!';
         ins_batch_messages (l_bame_row);

         --
         --- tabel:tbcis_processes
         UPDATE tbcis_processes tbpr
            SET start_date = DECODE (tbpr.start_date, NULL, SYSDATE, tbpr.start_date)
               ,module_params = p_fcty_type
               ,last_updated = SYSDATE
               ,last_updated_by = sec.get_username
               ,end_date = SYSDATE
               ,end_code = 'ERR'
          WHERE module_ref = c_module_ref;

         --
         send_mail ('Milvi@sms.emt.ee'
                   ,sec.get_username || ' Hinnakiri,Error ' || TO_CHAR (SQLCODE) || ' - ' || SQLERRM
                   ,''
                   );
         send_mail ('3725067300@sms.emt.ee'
                   ,sec.get_username || ' Hinnakiri,Error ' || TO_CHAR (SQLCODE) || ' - ' || SQLERRM
                   ,''
                   );
         COMMIT;
      ---------------------------------------------------------------------------------
      WHEN OTHERS THEN
         ROLLBACK;
         --- tabel:bcc_Batch_Messages
         l_bame_row.MESSAGE_TEXT := 'Start_EBPL.Ebanormaalne töö lõpp! ' || SQLERRM;
         ins_batch_messages (l_bame_row);

         --- tabel:tbcis_processes
         UPDATE tbcis_processes tbpr
            SET start_date = DECODE (tbpr.start_date, NULL, SYSDATE, tbpr.start_date)
               ,module_params = p_fcty_type
               ,last_updated = SYSDATE
               ,last_updated_by = sec.get_username
               ,end_date = SYSDATE
               ,end_code = 'ERR'
          WHERE module_ref = c_module_ref;

         --
         send_mail ('Milvi@sms.emt.ee'
                   ,sec.get_username || ' Hinnakiri,Error ' || TO_CHAR (SQLCODE) || ' - ' || SQLERRM
                   ,''
                   );
         send_mail ('3725067300@sms.emt.ee'
                   ,sec.get_username || ' Hinnakiri,Error ' || TO_CHAR (SQLCODE) || ' - ' || SQLERRM
                   ,''
                   );
         COMMIT;
   END start_ebpl;

   PROCEDURE ins_mobile_monthly_charges (p_success     OUT BOOLEAN
                                        ,p_error_text  OUT VARCHAR2
                                        ) IS
   
   begin
   
   null;
   
   
   
   END ins_mobile_monthly_charges;

   PROCEDURE start_ebpl_mch_rch IS
   BEGIN
      start_ebpl ('MCH');
      start_ebpl ('RCH');
      start_ebpl ('DCH');
   END;
----------------
END emt_pricelist;
/

