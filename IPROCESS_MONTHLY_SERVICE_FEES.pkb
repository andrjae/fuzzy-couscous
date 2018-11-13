CREATE OR REPLACE PACKAGE BODY TBCIS.iPROCESS_MONTHLY_SERVICE_FEES AS
   /*
     ** Package level type declarations.
   */
   TYPE t_date IS TABLE OF DATE
      INDEX BY BINARY_INTEGER;

   TYPE t_ref_num IS TABLE OF NUMBER (10)
      INDEX BY BINARY_INTEGER;

   TYPE t_stat_param IS TABLE OF service_types.station_param%TYPE
      INDEX BY BINARY_INTEGER;

   TYPE t_number IS TABLE OF NUMBER
      INDEX BY BINARY_INTEGER;

   TYPE t_char4 IS TABLE OF VARCHAR2 (4)
      INDEX BY BINARY_INTEGER;

   TYPE t_char3 IS TABLE OF VARCHAR2 (3)
      INDEX BY BINARY_INTEGER;

   TYPE t_char1 IS TABLE OF VARCHAR2 (1)
      INDEX BY BINARY_INTEGER;

   TYPE t_char6 IS TABLE OF VARCHAR2 (6)
      INDEX BY BINARY_INTEGER;

   TYPE t_char10 IS TABLE OF VARCHAR2 (10)
      INDEX BY BINARY_INTEGER;   -- CHG-2795

   TYPE t_char25 IS TABLE OF VARCHAR2 (25)
      INDEX BY BINARY_INTEGER;

   TYPE t_sety_ref IS TABLE OF service_types.ref_num%TYPE
      INDEX BY BINARY_INTEGER;

   --
   TYPE r_serv_data IS RECORD (
      susg_ref_num                  subs_serv_groups.ref_num%TYPE
     ,start_date                    status_periods.start_date%TYPE
     ,end_date                      status_periods.end_date%TYPE
     ,sety_ref_num                  service_types.ref_num%TYPE
     ,station_param                 service_types.station_param%TYPE
   );

   TYPE t_serv_data IS TABLE OF r_serv_data
      INDEX BY BINARY_INTEGER;

   --
   TYPE r_prli_data IS RECORD (
      fcit_type_code                fixed_charge_item_types.type_code%TYPE
     ,taty_type_code                fixed_charge_item_types.taty_type_code%TYPE
     ,billing_selector              fixed_charge_item_types.billing_selector%TYPE
     ,charge_value                  price_lists.charge_value%TYPE
     ,start_date                    DATE
     ,end_date                      DATE
   );

   TYPE t_prli_data IS TABLE OF r_prli_data
      INDEX BY BINARY_INTEGER;

   -- CHG-3714
   TYPE r_calculated_fee IS RECORD (
      fcit_type_code                fixed_charge_item_types.type_code%TYPE
     ,susg_ref_num                  subs_serv_groups.ref_num%TYPE
     ,eek_amt                       invoice_entries.eek_amt%TYPE
   );

   TYPE t_calculated_fee IS TABLE OF r_calculated_fee
      INDEX BY BINARY_INTEGER;

   /*
     ** Package level constant declarations.
   */
   c_one_second         CONSTANT NUMBER := 1 / 86400;
   c_message_nr         CONSTANT NUMBER := 9999;
   c_ker_parameter      CONSTANT VARCHAR2 (10) := 'KER';
   c_non_ker_parameter  CONSTANT VARCHAR2 (10) := 'NONKER';
   c_master_serv_parameter CONSTANT VARCHAR2 (10) := 'MAAC';
   c_invoicing_parameter CONSTANT VARCHAR2 (10) := 'INVOICING';
   c_ok_end_code        CONSTANT tbcis_processes.end_code%TYPE := 'OK';
   c_error_end_code     CONSTANT tbcis_processes.end_code%TYPE := 'ERR';
   c_default_bill_service CONSTANT service_types.service_name%TYPE := 'PARVE';
   c_default_channel    CONSTANT price_lists.channel_type%TYPE := 'PM';
   
   /*
     ** CHG-4482: New variables for optimazing NonKer process.
   */
   TYPE r_price_table IS RECORD (
        fcit_type_code          fixed_charge_item_types.type_code%TYPE
       ,taty_type_code          fixed_charge_item_types.taty_type_code%TYPE
       ,billing_selector        fixed_charge_item_types.billing_selector%TYPE
       ,charge_parameter        fixed_charge_item_types.valid_charge_parameter%TYPE
       ,first_prorated_charge   fixed_charge_item_types.first_prorated_charge%TYPE
       ,last_prorated_charge    fixed_charge_item_types.last_prorated_charge%TYPE
       ,sety_first_prorated     fixed_charge_item_types.sety_first_prorated%TYPE
       ,charge_value            fixed_charge_values.charge_value%TYPE
       ,sepv_ref_num            fixed_charge_values.sepv_ref_num%TYPE
       ,sepa_ref_num            fixed_charge_values.sepa_ref_num%TYPE
       ,start_date              DATE
       ,end_date                DATE
       ,sequence                NUMBER
       -- search parameters
       ,sety_ref_num            service_types.ref_num%TYPE
       ,sept_type_code          serv_package_types.type_code%TYPE
       ,category                serv_package_types.category%TYPE
       ,susg_ref_num            subs_serv_groups.ref_num%TYPE
   );
   --
   TYPE t_price_table IS TABLE OF r_price_table
      INDEX BY BINARY_INTEGER;
   -- Price tables
   g_price_table_ficv     t_price_table;
   g_price_table_prli     t_price_table;
   --
   
   TYPE r_marker_table IS RECORD (
        start_num    NUMBER
       ,end_num      NUMBER
   );
   --
   TYPE t_marker_table IS TABLE OF r_marker_table
      INDEX BY BINARY_INTEGER;
   -- Marker tables for service prices
   g_marker_ficv           t_marker_table;
   g_marker_prli           t_marker_table;
   
   -- SSFC services table
   g_ssfc_serv_tab         t_ref_num;

   /*
     **
     **   LOCAL PROGRAM UNITS used inside current package
     **
   */
   /***************************************************************************
   **
   **   Function Name :  GET_MASTER_ACCOUNT_REC
   **
   **   Description : Funktsioon leiab ette antud masterkonto andmed.
   **
   ****************************************************************************/
   FUNCTION get_master_account_rec (
      p_maac_ref_num  IN  master_accounts_v.ref_num%TYPE
   )
      RETURN master_accounts_v%ROWTYPE IS
      --
      CURSOR c_maac IS
         SELECT *
           FROM master_accounts_v
          WHERE ref_num = p_maac_ref_num;

      --
      l_maac_rec                    master_accounts_v%ROWTYPE;
   BEGIN
      OPEN c_maac;

      FETCH c_maac
       INTO l_maac_rec;

      CLOSE c_maac;

      --
      RETURN l_maac_rec;
   END get_master_account_rec;

   /***************************************************************************
   **
   **   Procedure Name :  GET_SERVICE_PACKAGE_DATA
   **
   **   Description : Protseduur leiab ette antud kuupäeval kehtiva
   **                 teenuspaketi mobiilile.
   **
   ****************************************************************************/
   PROCEDURE get_package_at_date (
      p_susg_ref_num    IN      subs_serv_groups.ref_num%TYPE
     ,p_chk_date        IN      DATE
     ,p_sept_type_code  OUT     serv_package_types.type_code%TYPE
     ,p_category        OUT     serv_package_types.CATEGORY%TYPE
   ) IS
      --
      CURSOR c_sept IS
         SELECT sept.type_code
               ,sept.CATEGORY
           FROM serv_package_types sept, subs_packages supa
          WHERE supa.gsm_susg_ref_num = p_susg_ref_num
            AND TRUNC (p_chk_date) BETWEEN supa.start_date AND NVL (supa.end_date, TRUNC (p_chk_date))
            AND sept.type_code = supa.sept_type_code;
   BEGIN
      OPEN c_sept;

      FETCH c_sept
       INTO p_sept_type_code
           ,p_category;

      CLOSE c_sept;
   END get_package_at_date;

   /*
     ** Funktsioon kontrollib, kas ette antud Masteri (+ mobiili) vaadeldava perioodi arveldusarvetel
     ** esineb k?nesündmusi v?i mitte.
   */
   FUNCTION chk_events_on_period_invo (
      p_maac_ref_num       IN  accounts.ref_num%TYPE
     ,p_period_start_date  IN  DATE
     ,p_period_end_date    IN  DATE
     ,p_susg_ref_num       IN  subs_serv_groups.ref_num%TYPE DEFAULT NULL
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_chk_inen IS
         SELECT 1
           FROM invoices invo, invoice_entries inen
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start_date AND p_period_end_date
            AND inen.invo_ref_num = invo.ref_num
            AND (inen.susg_ref_num = p_susg_ref_num OR p_susg_ref_num IS NULL)
            AND inen.rounding_indicator = 'N'
            AND inen.fcit_type_code IS NULL
            AND inen.vmct_type_code IS NULL
            AND inen.fcdt_type_code IS NULL
            AND inen.cadc_ref_num IS NULL
            AND inen.evre_data_volume IS NULL
            AND inen.eek_amt >= 0
            AND inen.evre_count > 0
            AND inen.billing_selector IS NOT NULL
            AND ROWNUM = 1;

      --
      l_dummy                       NUMBER;
      l_found                       BOOLEAN;
   BEGIN
      OPEN c_chk_inen;

      FETCH c_chk_inen
       INTO l_dummy;

      l_found := c_chk_inen%FOUND;

      CLOSE c_chk_inen;

      --
      RETURN l_found;
   END chk_events_on_period_invo;

   --
   FUNCTION get_call_disc_codes_rec (
      p_cadc_ref_num  IN  call_discount_codes.ref_num%TYPE
   )
      RETURN call_discount_codes%ROWTYPE IS
      --
      CURSOR c_cadc IS
         SELECT *
           FROM call_discount_codes
          WHERE ref_num = p_cadc_ref_num;

      --
      l_cadc_rec                    call_discount_codes%ROWTYPE;
   BEGIN
      OPEN c_cadc;

      FETCH c_cadc
       INTO l_cadc_rec;

      CLOSE c_cadc;

      --
      RETURN l_cadc_rec;
   END get_call_disc_codes_rec;

   /***************************************************************************
   **
   **   Function Name :  Chk_KER_Service_Fee
   **
   **   Description : Funktsioon kontrollib, kas antud KER teenus (mobiil+teenus)
   **                 kuulub reeglite järgi maksustamisele.
   **                 1) Teenus avatud perioodi l?pu seisuga v?i suletud koos mobiiliga.
   **                 2) Paketile vastav hind > 0.
   **                 3) Arvel k?nesündmused. S?ltumata k?nesündmuste olemasolust
   **                    arvatakse kirje siiski vahetabelisse (k?ned v?idakse peale lugeda
   **                    enne l?plikku arvele kandmist).
   **                 Väljatab info, kas kanda vahetabelisse v?i mitte + vahetabeli
   **                 loomiseks vajalikud andmed.
   **
   ****************************************************************************/
   FUNCTION chk_ker_service_fee (
      p_susg_ref_num       IN      subs_serv_groups.ref_num%TYPE
     ,p_sety_ref_num       IN      service_types.ref_num%TYPE
     ,p_stpe_end_date      IN      DATE
     ,p_period_start_date  IN      DATE
     ,p_period_end_date    IN      DATE
     ,p_sept_type_code     IN      serv_package_types.type_code%TYPE
     ,p_maac_ref_num       IN      accounts.ref_num%TYPE
     ,p_category           IN      package_categories.package_category%TYPE
     ,p_mobile_end_date    IN OUT  DATE
     ,p_channel            IN OUT  price_lists.channel_type%TYPE
     ,p_bicy_cycle_code    IN OUT  bill_cycles.cycle_code%TYPE
     ,p_events_exist       IN OUT  VARCHAR2
     ,p_price              OUT     NUMBER
     ,p_sepv_ref_num       OUT     service_param_values.ref_num%TYPE
     ,p_taty_type_code     OUT     tax_types.tax_type_code%TYPE
     ,p_billing_selector   OUT     billing_selectors_v.type_code%TYPE
     ,p_fcit_type_code     OUT     fixed_charge_item_types.type_code%TYPE
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_get_channel (
         p_maac_end_date  IN  DATE
      ) IS
         SELECT sety.service_media
           FROM master_account_services maas, service_types sety
          WHERE maas.maac_ref_num = p_maac_ref_num
            AND (   (    NVL (p_maac_end_date, p_period_end_date) >= p_period_end_date
                     AND p_period_end_date BETWEEN maas.start_date AND NVL (maas.end_date, p_period_end_date)
                    )
                 OR (p_maac_end_date < p_period_end_date AND TRUNC (maas.end_date) >= TRUNC (p_maac_end_date))
                )
            AND sety.ref_num = maas.sety_ref_num
            AND sety.station_param = 'KER';

      --
      CURSOR c_acst IS
         SELECT   *
             FROM account_statuses
            WHERE acco_ref_num = p_maac_ref_num AND acst_code = 'AC'
         ORDER BY start_date DESC;

      --
      l_events_exist                BOOLEAN;
      l_maac_rec                    master_accounts_v%ROWTYPE;
      l_sesu_rec                    senu_susg%ROWTYPE;
      l_allowed                     BOOLEAN;
      l_channel                     price_lists.channel_type%TYPE;
      l_price                       NUMBER;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_sepv_ref_num                service_param_values.ref_num%TYPE;
      l_acst_rec                    account_statuses%ROWTYPE;
   BEGIN
      /*
        ** Kui teenuse periood on suletud enne arveldusperioodi l?ppu, siis kuulub maksustamisele ainult juhul,
        ** kui teenus on suletud koos mobiili sulgemisega.
      */
      IF p_stpe_end_date < p_period_end_date THEN
         IF p_mobile_end_date IS NULL THEN
            l_sesu_rec := service_numbers_p.get_sesu_row_with_susg (p_susg_ref_num);
            --
            -- Kui tühi (avatud), siis fiktiivne väärtus, mis alati näitab nagu teenus oleks suletud enne mobiili
            p_mobile_end_date := NVL (l_sesu_rec.end_date, p_period_end_date + 1);
         END IF;

         --
         IF TRUNC (p_stpe_end_date) >= TRUNC (p_mobile_end_date) THEN
            l_allowed := TRUE;
         ELSE
            l_allowed := FALSE;
         END IF;
      ELSE
         l_allowed := TRUE;
      END IF;

      --
      IF l_allowed THEN
         /*
           ** Väljundkanal maksustamiseks tuleb leida vastavast M/A teenusest. Kui vastav M/A teenus puudub,
           ** siis kasutatakse vaikimisi väärtust.
         */
         IF p_channel IS NULL THEN
            OPEN c_acst;

            FETCH c_acst
             INTO l_acst_rec;

            CLOSE c_acst;

            --
            OPEN c_get_channel (l_acst_rec.end_date);

            FETCH c_get_channel
             INTO p_channel;

            CLOSE c_get_channel;

            --
            IF p_channel IS NULL THEN
               p_channel := c_default_channel;
            END IF;
         END IF;

         /*
           ** Leiame hinnakirjajärgse- v?i erihinna.
         */
         icalculate_fixed_charges.get_non_prorata_mob_serv_price
                                                      (p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                                      ,p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                                      ,LEAST (NVL (p_stpe_end_date, p_period_end_date)
                                                             ,p_period_end_date
                                                             )   -- p_end_date         IN     DATE
                                                      ,p_channel   -- IN     price_lists.channel_type%TYPE
                                                      ,p_sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                                      ,p_category   -- IN     serv_package_types.category%TYPE
                                                      ,l_price   --    OUT NUMBER
                                                      ,l_taty_type_code   --    OUT tax_types.tax_type_code%TYPE
                                                      ,l_billing_selector   --    OUT billing_selectors_v.type_code%TYPE
                                                      ,l_fcit_type_code   --    OUT fixed_charge_item_types.type_code%TYPE
                                                      ,l_sepv_ref_num   --    OUT service_param_values.ref_num%TYPE
                                                      );

         IF NVL (l_price, 0) > 0 THEN
            IF p_events_exist IS NULL THEN
               l_events_exist :=
                  chk_events_on_period_invo (p_maac_ref_num   -- IN accounts.ref_num%TYPE
                                            ,p_period_start_date   -- IN DATE
                                            ,p_period_end_date   -- IN DATE
                                            ,p_susg_ref_num   -- IN subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                            );

               IF l_events_exist THEN
                  p_events_exist := 'Y';
               ELSE
                  p_events_exist := 'N';
               END IF;
            END IF;

            /*
              ** Leiame masterkonto andmed.
            */
            IF p_bicy_cycle_code IS NULL THEN
               l_maac_rec := get_master_account_rec (p_maac_ref_num);
               --
               p_bicy_cycle_code := l_maac_rec.bicy_cycle_code;
            END IF;

            --
            p_price := l_price;
            p_sepv_ref_num := l_sepv_ref_num;
            p_taty_type_code := l_taty_type_code;
            p_billing_selector := l_billing_selector;
            p_fcit_type_code := l_fcit_type_code;
         ELSE
            l_allowed := FALSE;
         END IF;
      END IF;

      --
      RETURN l_allowed;
   END chk_ker_service_fee;

   /***************************************************************************
   **
   **   Procedure Name :  Ins_Monthly_Service_Fees
   **
   **   Description : Protseduur salvestab andmed PL/SQL tabelitest Ab tabelisse
   **                 Monthly Service Fees ning seejärel tühjendab PL/SQL tabelid
   **                 lähteandmetest.
   **
   ****************************************************************************/
   PROCEDURE ins_monthly_service_fees (
      p_maac_ref_num_tab           IN OUT  t_ref_num
     ,p_susg_ref_num_tab           IN OUT  t_ref_num
     ,p_sety_ref_num_tab           IN OUT  t_ref_num
     ,p_price_tab                  IN OUT  t_number
     ,p_sept_type_code_tab         IN OUT  t_char4
     ,p_bill_cycle_tab             IN OUT  t_char3
     ,p_channel_type_tab           IN OUT  t_char6
     ,p_events_exist_tab           IN OUT  t_char1
     ,p_inen_exists_tab            IN OUT  t_char1
     ,p_bill_serv_chg_allowed_tab  IN OUT  t_char1
     ,p_station_param_tab          IN OUT  t_char25
     ,p_maas_ref_num_tab           IN OUT  t_ref_num
     ,p_end_date_tab               IN OUT  t_date
     ,p_category_tab               IN OUT  t_char1
     ,p_chca_type_code_tab         IN OUT  t_char3
     ,p_period_start_date          IN      DATE
     ,p_period_end_date            IN      DATE
   ) IS
      --
      l_count                       NUMBER;
   BEGIN
      l_count := p_maac_ref_num_tab.COUNT;
      FORALL i IN 1 .. l_count
         INSERT INTO monthly_service_fees
                     (maac_ref_num   -- NOT NULL NUMBER(10)
                     ,sety_ref_num   -- NOT NULL NUMBER(10)
                     ,period_start_date   -- NOT NULL DATE
                     ,period_end_date   -- NOT NULL DATE
                     ,price   -- NOT NULL NUMBER
                     ,processed   -- NOT NULL VARCHAR2(1)
                     ,susg_ref_num   --          NUMBER(10)
                     ,sept_type_code   --          VARCHAR2(4)
                     ,bill_cycle   --          VARCHAR2(3)
                     ,channel_type   --          VARCHAR2(6)
                     ,events_exist   --          VARCHAR2(1)
                     ,inen_exists   --          VARCHAR2(1)
                     ,bill_serv_chg_allowed   --          VARCHAR2(1)
                     ,station_param   --          VARCHAR2(25)
                     ,maas_ref_num   --          NUMBER(10)
                     ,end_date   --          DATE
                     ,CATEGORY   --          VARCHAR2(1)
                     ,chca_type_code   --          VARCHAR2(3)
                     )
              VALUES (p_maac_ref_num_tab (i)
                     ,p_sety_ref_num_tab (i)
                     ,p_period_start_date
                     ,p_period_end_date
                     ,p_price_tab (i)
                     ,'N'
                     ,p_susg_ref_num_tab (i)
                     ,p_sept_type_code_tab (i)
                     ,p_bill_cycle_tab (i)
                     ,p_channel_type_tab (i)
                     ,p_events_exist_tab (i)
                     ,p_inen_exists_tab (i)
                     ,p_bill_serv_chg_allowed_tab (i)
                     ,p_station_param_tab (i)
                     ,p_maas_ref_num_tab (i)
                     ,p_end_date_tab (i)
                     ,p_category_tab (i)
                     ,p_chca_type_code_tab (i)
                     );
      --
      p_maac_ref_num_tab.DELETE;
      p_susg_ref_num_tab.DELETE;
      p_sety_ref_num_tab.DELETE;
      p_price_tab.DELETE;
      p_sept_type_code_tab.DELETE;
      p_bill_cycle_tab.DELETE;
      p_channel_type_tab.DELETE;
      p_events_exist_tab.DELETE;
      p_inen_exists_tab.DELETE;
      p_bill_serv_chg_allowed_tab.DELETE;
      p_station_param_tab.DELETE;
      p_maas_ref_num_tab.DELETE;
      p_end_date_tab.DELETE;
      p_category_tab.DELETE;
      p_chca_type_code_tab.DELETE;
   END ins_monthly_service_fees;

   /***************************************************************************
   **
   **   Procedure Name :  Ins_Monthly_Service_Fees_Rec
   **
   **   Description : Protseduur salvestab 1 kirje tabelisse Monthly Service Fees.
   **
   ****************************************************************************/
   PROCEDURE ins_monthly_service_fees_rec (
      p_mosf_rec  IN  monthly_service_fees%ROWTYPE
   ) IS
   BEGIN
      INSERT INTO monthly_service_fees
                  (maac_ref_num   -- NOT NULL NUMBER(10)
                  ,sety_ref_num   -- NOT NULL NUMBER(10)
                  ,period_start_date   -- NOT NULL DATE
                  ,period_end_date   -- NOT NULL DATE
                  ,price   -- NOT NULL NUMBER
                  ,processed   -- NOT NULL VARCHAR2(1)
                  ,susg_ref_num   --          NUMBER(10)
                  ,sept_type_code   --          VARCHAR2(4)
                  ,bill_cycle   --          VARCHAR2(3)
                  ,channel_type   --          VARCHAR2(6)
                  ,events_exist   --          VARCHAR2(1)
                  ,inen_exists   --          VARCHAR2(1)
                  ,bill_serv_chg_allowed   --          VARCHAR2(1)
                  ,station_param   --          VARCHAR2(25)
                  ,maas_ref_num   --          NUMBER(10)
                  ,end_date   --          DATE
                  ,CATEGORY   --          VARCHAR2(1)
                  ,chca_type_code   --          VARCHAR2(3)
                  )
           VALUES (p_mosf_rec.maac_ref_num
                  ,p_mosf_rec.sety_ref_num
                  ,p_mosf_rec.period_start_date
                  ,p_mosf_rec.period_end_date
                  ,p_mosf_rec.price
                  ,'N'
                  ,p_mosf_rec.susg_ref_num
                  ,p_mosf_rec.sept_type_code
                  ,p_mosf_rec.bill_cycle
                  ,p_mosf_rec.channel_type
                  ,p_mosf_rec.events_exist
                  ,p_mosf_rec.inen_exists
                  ,p_mosf_rec.bill_serv_chg_allowed
                  ,p_mosf_rec.station_param
                  ,p_mosf_rec.maas_ref_num
                  ,p_mosf_rec.end_date
                  ,p_mosf_rec.CATEGORY
                  ,p_mosf_rec.chca_type_code
                  );
   END ins_monthly_service_fees_rec;

   /***************************************************************************
   **
   **   Function Name :  Chk_MAAC_Service_Chg_Rules
   **
   **   Description : Funktsioon kontrollib Master teenuse maksustamise lubatavust
   **                 vastavalt reeglitele s?ltuvalt teenuse parameetrist.
   **
   ****************************************************************************/
   FUNCTION chk_maac_service_chg_rules (
      p_maac_ref_num      IN      master_accounts_v.ref_num%TYPE
     ,p_sety_ref_num      IN      service_types.ref_num%TYPE
     ,p_station_param     IN      service_types.station_param%TYPE
     ,p_period_start      IN      DATE
     ,p_period_end        IN      DATE
     ,p_sety_ref_num_tab  IN OUT  t_sety_ref
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_vasc IS
         SELECT sety_ref_num_valid
           FROM valid_serv_combs
          WHERE sety_ref_num = p_sety_ref_num AND condition_type = 'A';

      --
      CURSOR c_invo IS
         SELECT   *
             FROM invoices
            WHERE maac_ref_num = p_maac_ref_num
              AND billing_inv = 'Y'
              AND period_start BETWEEN p_period_start AND p_period_end
         ORDER BY invoice_date;

      --
      l_dummy                       NUMBER;
      l_allowed                     BOOLEAN;
   BEGIN
      IF p_station_param = 'KER' THEN
         /*
           ** KER maksustatakse ainult siis, kui perioodi arveldusarvetel esineb seotud k?nesündmusi.
         */
         l_allowed := chk_events_on_period_invo (p_maac_ref_num   -- IN accounts.ref_num%TYPE
                                                ,p_period_start   -- IN DATE
                                                ,p_period_end   -- IN DATE
                                                );
      ELSIF p_station_param = 'ARVE' THEN
         /*
           ** ARVE maksustatakse ainult siis, kui Masterkonto omab aruandeperioodis arveldusarveid
           ** ja avatud billingarvel olemas arveread.
           ** 1) Kontrollida, kas jooksval arvel on trükitavaid ridu. Kui jah, siis maksusta, kui ei, siis
           ** 2) kontrollida, kas on perioodis eelnevalt suletud arveid (INP, INT), kui jah, siis maksusta,
           ** kui ei, siis ära maksusta.
           ** 3) vahearveid p?hjusega VNV (v?lan?ude vahearved) ei arvestata
         */
         l_allowed := FALSE;

         FOR l_invo_rec IN c_invo LOOP
            IF l_invo_rec.invoice_type = 'INT' AND l_invo_rec.creation_reason = 'VNV' THEN
               NULL;
            ELSE
               IF l_invo_rec.invoice_date IS NOT NULL THEN
                  l_allowed := TRUE;
               ELSE
                  l_allowed :=
                     bcc_main_bill.chk_print_of_invoice_required (l_invo_rec.ref_num   -- IN invoices.ref_num%TYPE
                                                                 ,   l_invo_rec.total_amt
                                                                   + l_invo_rec.total_vat   -- p_total        IN NUMBER
                                                                 );
               END IF;
            END IF;

            --
            IF l_allowed THEN
               EXIT;
            END IF;
         END LOOP;

         --
         IF l_allowed THEN
            p_sety_ref_num_tab (p_sety_ref_num) := p_sety_ref_num;
         END IF;
      ELSIF p_station_param = 'TEAV' THEN
         /*
           ** TEAVitus maksustatakse ainult siis, kui omab Available seost ja seotud ARVE teenus lubatud maksustada.
         */
         l_allowed := FALSE;

         FOR l_vasc IN c_vasc LOOP
            IF p_sety_ref_num_tab.EXISTS (l_vasc.sety_ref_num_valid) THEN
               l_allowed := TRUE;
               EXIT;
            END IF;
         END LOOP;
      END IF;

      --
      RETURN l_allowed;
   END chk_maac_service_chg_rules;

   /***************************************************************************
   **
   **   Procedure Name :  Chk_One_MAAC_Service_Fee
   **
   **   Description : Protseduur kontrollib 1 ette antud master teenuse maksustamise
   **                 tingimusi.
   **
   ****************************************************************************/
   PROCEDURE chk_one_maac_service_fee (
      p_maac_ref_num       IN      master_accounts_v.ref_num%TYPE
     ,p_maas_ref_num       IN      master_account_services.ref_num%TYPE
     ,p_sety_ref_num       IN      service_types.ref_num%TYPE
     ,p_station_param      IN      service_types.station_param%TYPE
     ,p_end_date           IN      DATE
     ,p_period_start       IN      DATE
     ,p_period_end         IN      DATE
     ,p_chca_type_code     IN OUT  maac_charging_categories.chca_type_code%TYPE
     ,p_sety_ref_num_tab   IN OUT  t_sety_ref
     ,p_allow_billserv_ch  OUT     VARCHAR2
     ,p_events_exist       OUT     VARCHAR2
     ,p_inen_exists        OUT     VARCHAR2
     ,p_price              OUT     NUMBER
   ) IS
      --
      l_price                       NUMBER;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_allowed                     BOOLEAN;
      l_masa_rec                    master_service_adjustments%ROWTYPE;
   BEGIN
      /*
        ** Kontrollime teenuse maksustamise lubatavust.
      */
      l_allowed := chk_maac_service_chg_rules (p_maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                              ,p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                              ,p_station_param   -- IN     service_types.station_param%TYPE
                                              ,p_period_start   -- IN     DATE
                                              ,p_period_end   -- IN     DATE
                                              ,p_sety_ref_num_tab   -- IN OUT t_sety_ref
                                              );

      --
      IF p_station_param = 'KER' THEN
         IF l_allowed THEN
            p_events_exist := 'Y';
         ELSE
            p_events_exist := 'N';
         END IF;
      ELSIF p_station_param = 'ARVE' THEN
         IF l_allowed THEN
            p_inen_exists := 'Y';
         ELSE
            p_inen_exists := 'N';
         END IF;
      ELSIF p_station_param = 'TEAV' THEN
         IF l_allowed THEN
            p_allow_billserv_ch := 'Y';
         ELSE
            p_allow_billserv_ch := 'N';
         END IF;
      END IF;

      /*
        ** Leiame hinnakirjajärgse- v?i erihinna.
      */
      icalculate_fixed_charges.get_non_prorata_ma_serv_price
                                                (p_maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                                ,p_maas_ref_num   -- IN     master_account_services.ref_num%TYPE
                                                ,p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                                ,p_end_date   -- IN     DATE
                                                ,p_chca_type_code   -- IN OUT maac_charging_categories.chca_type_code%TYPE
                                                ,l_price   --    OUT NUMBER
                                                ,l_taty_type_code   --    OUT tax_types.tax_type_code%TYPE
                                                ,l_billing_selector   --    OUT billing_selectors_v.type_code%TYPE
                                                ,l_fcit_type_code   --    OUT fixed_charge_item_types.type_code%TYPE
                                                ,l_masa_rec   --    OUT master_service_adjustments%ROWTYPE
                                                );
      p_price := l_price;
   END chk_one_maac_service_fee;

   /***************************************************************************
   **
   **   Procedure Name :  Invoice_Mobile_Service
   **
   **   Description : Protseduur kannab arvele 1 mobiili teenuse päevade arvust
   **                 s?ltumatu kuutasu ja arvutab samale teenusele ka soodustused.
   **
   ****************************************************************************/
   PROCEDURE invoice_mobile_service (
      p_susg_ref_num    IN      subs_serv_groups.ref_num%TYPE
     ,p_maac_ref_num    IN      accounts.ref_num%TYPE
     ,p_sety_ref_num    IN      service_types.ref_num%TYPE
     ,p_end_date        IN      DATE
     ,p_channel         IN      price_lists.channel_type%TYPE
     ,p_sept_type_code  IN      serv_package_types.type_code%TYPE
     ,p_category        IN      serv_package_types.CATEGORY%TYPE
     ,p_invo_ref_num    IN      invoices.ref_num%TYPE
     ,p_discount_type   IN      VARCHAR2
     ,p_success         OUT     BOOLEAN
     ,p_error_text      OUT     VARCHAR2
   ) IS
      --
      l_price                       NUMBER;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_sepv_ref_num                service_param_values.ref_num%TYPE;
      --
      e_processing                  EXCEPTION;
   BEGIN
      /*
        ** Leiame hinnakirjajärgse- v?i erihinna.
      */
      icalculate_fixed_charges.get_non_prorata_mob_serv_price
                                                     (p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                                     ,p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                                     ,p_end_date   -- IN     DATE
                                                     ,p_channel   -- IN     price_lists.channel_type%TYPE
                                                     ,p_sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                                     ,p_category   -- IN     serv_package_types.category%TYPE
                                                     ,l_price   --    OUT NUMBER
                                                     ,l_taty_type_code   --    OUT tax_types.tax_type_code%TYPE
                                                     ,l_billing_selector   --    OUT billing_selectors_v.type_code%TYPE
                                                     ,l_fcit_type_code   --    OUT fixed_charge_item_types.type_code%TYPE
                                                     ,l_sepv_ref_num   --    OUT service_param_values.ref_num%TYPE
                                                     );

      --
      IF NVL (l_price, 0) > 0 THEN
         icalculate_fixed_charges.create_entries
                         (p_success   -- IN OUT BOOLEAN
                         ,p_error_text   -- IN OUT varchar2
                         ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                         ,l_fcit_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TYPE_CODE%TYPE
                         ,l_taty_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TATY_TYPE_CODE%TYPE
                         ,l_billing_selector   -- IN     FIXED_CHARGE_ITEM_TYPES.BILLING_SELECTOR%TYPE
                         ,l_price   -- p_charge_value     IN     NUMBER
                         ,p_susg_ref_num   -- IN     SUBS_SERV_GROUPS.ref_num%TYPE
                         ,NULL   -- p_num_of_days         IN     NUMBER
                         ,c_module_ref_short   -- p_module_ref       IN     invoice_entries.module_ref%TYPE default 'U659'
                         );

         IF p_success = FALSE THEN
            RAISE e_processing;
         END IF;

         --
         icalculate_discounts.find_oo_conn_discounts (p_discount_type   -- VARCHAR2
                                                    ,p_invo_ref_num   -- NUMBER
                                                    ,l_fcit_type_code   -- VARCHAR2
                                                    ,l_billing_selector   -- VARCHAR2
                                                    ,l_sepv_ref_num   -- NUMBER
                                                    ,p_sept_type_code   -- VARCHAR2
                                                    ,l_price   -- NUMBER
                                                    ,p_susg_ref_num   -- NUMBER
                                                    ,p_maac_ref_num   -- NUMBER
                                                    ,p_end_date   -- DATE
                                                    ,'INS'   -- p_mode              VARCHAR2  --'INS';'DEL'
                                                    ,p_error_text   -- IN out VARCHAR2
                                                    ,p_success   -- IN out BOOLEAN
                                                    );

         IF p_success = FALSE THEN
            RAISE e_processing;
         END IF;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
   END invoice_mobile_service;

   /***************************************************************************
   **
   **   Procedure Name :  Invoice_Master_Service
   **
   **   Description : Protseduur kannab arvele 1 masterkonto teenuse päevade arvust
   **                 s?ltumatu kuutasu ja arvutab samale teenusele ka soodustused.
   **
   ****************************************************************************/
   PROCEDURE invoice_master_service (
      p_maac_ref_num    IN      master_accounts_v.ref_num%TYPE
     ,p_maas_ref_num    IN      master_account_services.ref_num%TYPE
     ,p_sety_ref_num    IN      service_types.ref_num%TYPE
     ,p_end_date        IN      DATE
     ,p_chca_type_code  IN OUT  maac_charging_categories.chca_type_code%TYPE
     ,p_invo_ref_num    IN      invoices.ref_num%TYPE
     ,p_success         OUT     BOOLEAN
     ,p_error_text      OUT     VARCHAR2
     ,p_interim_bal     IN      BOOLEAN DEFAULT FALSE
   ) IS
      --
      l_price                       NUMBER;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_masa_rec                    master_service_adjustments%ROWTYPE;
      l_inen_rowid                  VARCHAR2 (30);
      l_discount_amount             NUMBER;
      l_cadc_rec                    call_discount_codes%ROWTYPE;
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;
      --
      e_processing                  EXCEPTION;
   BEGIN
      /*
        ** Leiame hinnakirjajärgse- v?i erihinna.
      */
      icalculate_fixed_charges.get_non_prorata_ma_serv_price
                                               (p_maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                               ,p_maas_ref_num   -- IN     master_account_services.ref_num%TYPE
                                               ,p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                               ,p_end_date   -- IN     DATE
                                               ,p_chca_type_code   -- IN OUT maac_charging_categories.chca_type_code%TYPE
                                               ,l_price   --    OUT NUMBER
                                               ,l_taty_type_code   --    OUT tax_types.tax_type_code%TYPE
                                               ,l_billing_selector   --    OUT billing_selectors_v.type_code%TYPE
                                               ,l_fcit_type_code   --    OUT fixed_charge_item_types.type_code%TYPE
                                               ,l_masa_rec   --    OUT master_service_adjustments%ROWTYPE
                                               );

      IF NVL (l_price, 0) > 0 THEN
         IF p_interim_bal THEN
            close_interim_billing_invoice.cre_upd_interim_inen (p_success   -- OUT BOOLEAN
                                                               ,p_error_text   -- OUT VARCHAR2
                                                               ,p_invo_ref_num   -- IN     NUMBER
                                                               ,l_fcit_type_code   -- IN     VARCHAR2
                                                               ,l_billing_selector   -- IN     VARCHAR2
                                                               ,l_taty_type_code   -- IN     VARCHAR2
                                                               ,l_price   -- IN     NUMBER
                                                               ,NULL   -- p_num_of_days       IN     NUMBER
                                                               ,NULL   -- p_susg_ref_num      IN     NUMBER
                                                               ,p_maas_ref_num   -- IN     NUMBER default null
                                                               );

            IF p_success = FALSE THEN
               RAISE e_processing;
            END IF;
         ELSE
            icalculate_fixed_charges.g_inen_rowid := NULL;
            icalculate_fixed_charges.create_entries
                        (p_success   -- IN OUT BOOLEAN
                        ,p_error_text   -- IN OUT varchar2
                        ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                        ,l_fcit_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TYPE_CODE%TYPE
                        ,l_taty_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TATY_TYPE_CODE%TYPE
                        ,l_billing_selector   -- IN     FIXED_CHARGE_ITEM_TYPES.BILLING_SELECTOR%TYPE
                        ,l_price   -- p_charge_value     IN     NUMBER
                        ,NULL   -- p_susg_ref_num     IN     SUBS_SERV_GROUPS.ref_num%TYPE
                        ,NULL   -- p_num_of_days         IN     NUMBER
                        ,c_module_ref_short   -- p_module_ref       IN     invoice_entries.module_ref%TYPE default 'U659'
                        ,p_maas_ref_num   -- IN     master_account_services.ref_num%TYPE default null
                        );

            IF p_success = FALSE THEN
               RAISE e_processing;
            END IF;

            --
            l_inen_rowid := icalculate_fixed_charges.g_inen_rowid;
            icalculate_fixed_charges.g_inen_rowid := NULL;

            /*
              ** Leitakse soodustus, kui Master teenusele on registreeritud kampaaniaga seotud soodustus.
            */
            IF l_masa_rec.cadc_ref_num IS NOT NULL THEN
               /*
                 ** Leiab soodustuse suuruse.
               */
               l_cadc_rec := get_call_disc_codes_rec (l_masa_rec.cadc_ref_num);
               --
               l_discount_amount :=
                  icalculate_discounts.get_ma_serv_discount_amount
                                (l_price   -- p_full_chg_value   IN NUMBER
                                ,l_price   -- p_remain_chg_value IN NUMBER
                                ,l_masa_rec.charge_value   -- p_cadc_amount   IN call_discount_codes.minimum_price%TYPE
                                ,l_masa_rec.credit_rate_value   -- p_percentage    IN call_discount_codes.precentage%TYPE
                                ,l_cadc_rec.pricing   -- IN call_discount_codes.pricing%TYPE
                                );
               --
               l_fcit_rec := icalculate_fixed_charges.get_fcit_rec (l_fcit_type_code);
               --
               icalculate_discounts.invoice_discount
                                        (p_maas_ref_num   -- IN     master_account_services.ref_num%TYPE
                                        ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                        ,l_inen_rowid   -- IN     VARCHAR2
                                        ,l_discount_amount   -- IN     NUMBER
                                        ,l_cadc_rec   -- IN     call_discount_codes%ROWTYPE
                                        ,p_end_date   -- p_chk_date         IN     DATE
                                        ,l_fcit_rec.fcdt_type_code   -- IN     fixed_charge_item_types.fcdt_type_code%TYPE
                                        ,p_success   --    OUT BOOLEAN
                                        ,p_error_text   --    OUT VARCHAR2
                                        );

               IF p_success = FALSE THEN
                  RAISE e_processing;
               END IF;
            END IF;
         END IF;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
   END invoice_master_service;

   /***************************************************************************
   **
   **   Procedure Name :  Get_Invoice
   **
   **   Description : Protseduur leiab ette antud masterkontole perioodi INB arve.
   **                 Kui arvet veel pole, siis üritatakse see luua.
   **
   ****************************************************************************/
   PROCEDURE get_invoice (
      p_maac_ref_num       IN      accounts.ref_num%TYPE
     ,p_period_start_date  IN      DATE
     ,p_success            OUT     BOOLEAN
     ,p_error_text         OUT     VARCHAR2
     ,p_invo_rec           OUT     invoices%ROWTYPE
   ) IS
      --
      CURSOR c_invo IS
         SELECT invo.*
           FROM invoices invo
          WHERE maac_ref_num = p_maac_ref_num AND invoice_type = 'INB' AND period_start = p_period_start_date;

      --
      l_found                       BOOLEAN;
      --
      e_create_invoice              EXCEPTION;
      e_invo_closed                 EXCEPTION;
   BEGIN
      /*
        ** Try to get debit billing invoice for this period.
      */
      OPEN c_invo;

      FETCH c_invo
       INTO p_invo_rec;

      l_found := c_invo%FOUND;

      CLOSE c_invo;

      --
      IF NOT l_found THEN
         /*
           ** This period debit billing invoice not existing yet. Try to create it now.
         */
         open_invoice.create_billing_debit_invoice (p_maac_ref_num, 'INB', p_period_start_date, p_invo_rec, p_success);

         IF NOT p_success THEN
            RAISE e_create_invoice;
         END IF;
      END IF;

      --
--ii      IF p_invo_rec.period_end IS NOT NULL THEN
--ii         RAISE e_invo_closed;
--ii      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_create_invoice THEN
         p_success := FALSE;
         p_error_text :=    'Masterile '
                         || TO_CHAR (p_maac_ref_num)
                         || ' ei ?nnestunud luua INB arvet perioodiks algusega '
                         || TO_CHAR (p_period_start_date, 'dd.mm.yyyy hh24:mi:ss');
      WHEN e_invo_closed THEN
         p_success := FALSE;
         p_error_text := 'Masteri ' || TO_CHAR (p_maac_ref_num) || ' jooksva perioodi arve on juba suletud';
   END get_invoice;
   /***************************************************************************
   **
   **   Procedure Name :  GET_SERVICE_NAME_FROM_SETY_REF
   **
   **   Description : Funktsioon tagastab teenuse nime ref_num'i järgi.
   **
   ****************************************************************************/
   FUNCTION get_service_name_from_sety_ref(p_sety_ref_num IN NUMBER) RETURN VARCHAR2 AS
      --
      CURSOR c_get_service_name IS
         SELECT service_name
          FROM service_types
          WHERE ref_num = p_sety_ref_num
      ;
      --
      l_service_name   service_types.service_name%TYPE;
   BEGIN
      --
      OPEN c_get_service_name;
       FETCH c_get_service_name INTO l_service_name;
       CLOSE c_get_service_name;
      --
       RETURN l_service_name;
   END get_service_name_from_sety_ref;


   /***************************************************************************
   **
   **   Procedure Name :  Get_Period_Max_Price
   **
   **   Description : Protseduur leiab ette antud perioodil vastavalt kehtiva häälestusejärgi hinna
   **                 antud teenusele ja teenuspaketile. Koos arvutatud hinnaga väljastatakse
   **                 ka sinna juurde kuuluvad atribuudid hinna arvele kandmiseks
   **                 (FCIT+BISE+TATY).
   **                 Protseduuri loogika on p?him?tteliselt järgmine:
   **                 K?igepealt leitakse perioodid ja hinnad, kus paketile määratud
   **                 erihind ja need lähevad alati arvesse (on k?ige prioriteetsemad).
   **                 Paketikategooria ja üldhindadega täiendatakse neid ajaperioode,
   **                 kus erihinda määratud ei ole.
   **                 P?him?tteliselt on lisaks arvutatud hinnale PL/SQL tabelites olemas
   **                 ka k?ik ajaperioodid koos vastavate hindadega.
   **
   **      CHG-2795 : Fikseeritud kuutasuga mobiilitaseme teenuste kuutasu arvutatakse vastavalt
   **                 tellimuses toodud häälestuse variantidele:
   **                  1. Rakendub viimasena määratud kuutasu (mis on arveldusperioodi l?pus aktiivne).
   **                  2. Rakendub esimesena määratud kuutasu (mis oli arveldusperioodi alguses v?i
   **                    teenuse tellimisel kui teenus telliti antud arveldusperioodis), muudetud kuutasu
   **                     (mis on aktiivne arveldusperioodi l?pus) rakendub järgmisest arveldusperioodist.
   **                  3. Rakendub arveldusperioodi jooksul olnud erinevatest arvutuslikest kuutasudest suurim.
   **                  4. Rakendub arveldusperioodi jooksul olnud erinevatest arvutuslikest kuutasudest väikseim
   **                  5. Liitumise kuul ja mitte samas perioodis l?petanud arvutatakse aktiivsete päevade
   **                    arvu p?hiselt, l?petamiskuul täies mahus vastavalt häälestusele
   **
   ****************************************************************************/
   PROCEDURE get_period_max_price (
      p_susg_ref_num          IN      subs_serv_groups.ref_num%TYPE
     ,p_sety_ref_num          IN      service_types.ref_num%TYPE
     ,p_start_date            IN      DATE
     ,p_end_date              IN      DATE
     ,p_sept_type_code        IN      serv_package_types.type_code%TYPE
     ,p_category              IN      serv_package_types.CATEGORY%TYPE
     ,p_charge_prorata        IN      VARCHAR2  -- CHG-5762
     ,p_price                 OUT     NUMBER
     ,p_taty_type_code        OUT     tax_types.tax_type_code%TYPE
     ,p_billing_selector      OUT     billing_selectors_v.type_code%TYPE
     ,p_fcit_type_code        OUT     fixed_charge_item_types.type_code%TYPE
     ,p_charge_parameter      OUT     fixed_charge_item_types.valid_charge_parameter%TYPE   -- CHG-3704
     ,p_first_prorated        OUT     BOOLEAN   -- CHG-3704
     ,p_priced_sepv_ref_num   OUT     subs_service_parameters.sepv_ref_num%TYPE   -- CHG-3908
     ,p_num_of_days           OUT     NUMBER    -- CHG-5762
     ,p_monthly_price         OUT     NUMBER    -- CHG-5762
     ,p_test_period_sept_type IN      mixed_packet_orders.sept_category_type%TYPE DEFAULT NULL  -- CHG-6386
     ,p_newmob_order          IN      mixed_packet_orders.newmob_order%TYPE DEFAULT NULL        -- CHG-6386
     ,p_prev_sepv_ref_num     IN      subs_service_parameters.sepv_ref_num%TYPE DEFAULT NULL    -- CHG-6386
   ) IS
      --
      CURSOR c_prli IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,fcit.valid_charge_parameter charge_parameter   -- CHG-2795
                 ,fcit.first_prorated_charge first_prorated_charge   -- CHG-2795
                 ,fcit.last_prorated_charge  last_prorated_charge    -- CHG-6214
                 ,fcit.sety_first_prorated sety_first_prorated   -- CHG-3714
                 ,ficv.charge_value charge_value
                 ,ficv.sepv_ref_num sepv_ref_num
                 ,ficv.sepa_ref_num sepa_ref_num
                 ,TRUNC (GREATEST (ficv.start_date, p_start_date)) start_date
                 ,TRUNC (LEAST (NVL (ficv.end_date, p_end_date), p_end_date)) end_date
                 ,1 SEQUENCE
             FROM fixed_charge_values ficv, fixed_charge_item_types fcit
            WHERE ficv.sety_ref_num = p_sety_ref_num
              AND ficv.sept_type_code = p_sept_type_code
              AND ficv.chca_type_code IS NULL
              AND ficv.channel_type IS NULL
              AND NVL (ficv.par_value_charge, 'N') = 'N'
              AND ficv.fcit_charge_code = fcit.type_code
              AND fcit.once_off = 'N'
              AND fcit.pro_rata = 'N'
              AND fcit.regular_charge = 'Y'
              AND ficv.start_date <= p_end_date
              AND NVL (ficv.end_date, p_end_date) >= TRUNC (p_start_date)   -- Hinnakiri päeva täpsusega
         UNION ALL
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,fcit.valid_charge_parameter charge_parameter   -- CHG-2795
                 ,fcit.first_prorated_charge first_prorated_charge   -- CHG-2795
                 ,fcit.last_prorated_charge  last_prorated_charge    -- CHG-6214
                 ,fcit.sety_first_prorated sety_first_prorated   -- CHG-3714
                 ,prli.charge_value charge_value
                 ,prli.sepv_ref_num sepv_ref_num
                 ,prli.sepa_ref_num sepa_ref_num
                 ,TRUNC (GREATEST (prli.start_date, p_start_date)) start_date
                 ,TRUNC (LEAST (NVL (prli.end_date, p_end_date), p_end_date)) end_date
                 ,DECODE (prli.package_category, NULL, 3, 2) SEQUENCE
             FROM price_lists prli, fixed_charge_item_types fcit
            WHERE prli.sety_ref_num = p_sety_ref_num
              AND prli.channel_type IS NULL
              AND NVL (prli.par_value_charge, 'N') = 'N'
              AND prli.once_off = 'N'
              AND prli.pro_rata = 'N'
              AND prli.regular_charge = 'Y'
              AND fcit.once_off = 'N'
              AND fcit.pro_rata = 'N'
              AND fcit.regular_charge = 'Y'
              AND prli.sety_ref_num = fcit.sety_ref_num
              AND fcit.package_category = p_category
              AND (fcit.package_category = prli.package_category OR prli.package_category IS NULL)
              AND prli.start_date <= p_end_date
              AND NVL (prli.end_date, p_end_date) >= TRUNC (p_start_date)   -- Hinnakiri päeva täpsusega
         UNION ALL   /* CHG-741: Lisatud juurde erihinnad mobiili tasemel, millised on k?ige prioriteetsemad */
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,fcit.valid_charge_parameter charge_parameter   -- CHG-2795
                 ,fcit.first_prorated_charge first_prorated_charge   -- CHG-2795
                 ,fcit.last_prorated_charge  last_prorated_charge    -- CHG-6214
                 ,fcit.sety_first_prorated sety_first_prorated   -- CHG-3714
                 ,ssfc.charge_value charge_value
                 ,TO_NUMBER (NULL) sepv_ref_num
                 ,TO_NUMBER (NULL) sepa_ref_num
                 ,TRUNC (GREATEST (ssfc.start_date, p_start_date)) start_date
                 ,TRUNC (LEAST (NVL (ssfc.end_date, p_end_date), p_end_date)) end_date
                 ,0 SEQUENCE
             FROM subs_serv_fixed_charges ssfc, fixed_charge_item_types fcit
            WHERE ssfc.susg_ref_num = p_susg_ref_num
              AND ssfc.sety_ref_num = p_sety_ref_num
              AND fcit.once_off = 'N'
              AND fcit.pro_rata = 'N'
              AND fcit.regular_charge = 'Y'
              AND ssfc.sety_ref_num = fcit.sety_ref_num
              AND fcit.package_category = p_category
              AND ssfc.start_date <= p_end_date
              AND NVL (ssfc.end_date, p_end_date) >= p_start_date
         ORDER BY SEQUENCE, start_date
      ;
      -- CHG-4482: Ainult erihinnad mobiili tasemel
      CURSOR c_ssfc IS
         SELECT fcit.type_code fcit_type_code
              , fcit.taty_type_code taty_type_code
              , fcit.billing_selector billing_selector
              , fcit.valid_charge_parameter charge_parameter   -- CHG-2795
              , fcit.first_prorated_charge first_prorated_charge   -- CHG-2795
              , fcit.last_prorated_charge  last_prorated_charge    -- CHG-6214
              , fcit.sety_first_prorated sety_first_prorated   -- CHG-3714
              , ssfc.charge_value charge_value
              , TO_NUMBER (NULL) sepv_ref_num
              , TO_NUMBER (NULL) sepa_ref_num
              , TRUNC (GREATEST (ssfc.start_date, p_start_date)) start_date
              , TRUNC (LEAST (NVL (ssfc.end_date, p_end_date), p_end_date)) end_date
              , 0 SEQUENCE
         FROM subs_serv_fixed_charges ssfc, fixed_charge_item_types fcit
         WHERE ssfc.susg_ref_num = p_susg_ref_num
           AND ssfc.sety_ref_num = p_sety_ref_num
           AND fcit.once_off = 'N'
           AND fcit.pro_rata = 'N'
           AND fcit.regular_charge = 'Y'
           AND ssfc.sety_ref_num = fcit.sety_ref_num
           AND fcit.package_category = p_category
           AND ssfc.start_date <= p_end_date
           AND NVL (ssfc.end_date, p_end_date) >= p_start_date
         ORDER BY start_date      
      ;
      --
      CURSOR c_susp (
         p_sepa_ref_num  IN  service_parameters.ref_num%TYPE
      ) IS
         SELECT   sepv_ref_num
                 ,GREATEST (start_date, p_start_date) start_date
                 ,LEAST (NVL (end_date, p_end_date), p_end_date) end_date
                 ,TRUNC (end_date) closed_date   -- CHG-2795
             FROM subs_service_parameters
            WHERE susg_ref_num = p_susg_ref_num
              AND sety_ref_num = p_sety_ref_num
              AND sepa_ref_num = p_sepa_ref_num
              AND start_date <= p_end_date
              AND NVL (end_date, p_end_date) >= p_start_date
              -- CHG-5762: Päevapõhisel hinnastusel paketivahetusel ei tohi võtta perioodi alguskuupäeval
              --           lõppenud parameetri hinda
              AND (Nvl(p_charge_prorata, 'N') = 'N' OR
                   Trunc(Nvl(end_date, p_end_date)) <> p_start_date AND p_charge_prorata = 'Y')
              -- 
         ORDER BY start_date;

      -- CHG-2795
      CURSOR c_stpe_end IS
         SELECT   end_date
             FROM status_periods
            WHERE susg_ref_num = p_susg_ref_num
              AND sety_ref_num = p_sety_ref_num
              AND start_date < p_end_date
              AND (end_date > p_start_date OR end_date IS NULL)
         ORDER BY start_date DESC;

      -- CHG-6214
      CURSOR c_sept_closed IS
         SELECT 1
         FROM subs_packages
         WHERE sept_type_code = p_sept_type_code
           AND gsm_susg_ref_num = p_susg_ref_num
           AND end_date BETWEEN p_start_date AND p_end_date
      ;
      --
      l_fcit_type_code_tab          t_char3;
      l_taty_type_code_tab          t_char1;
      l_bise_tab                    t_char3;
      l_charge_value_tab            t_number;
      l_charge_parameter_tab        t_char10;   -- CHG-2795
      l_first_prorated_charge_tab   t_char1;   -- CHG-2795
      l_last_prorated_charge_tab    t_char1;   -- CHG-6214
      l_prorated_by_sety_tab        t_char1;   -- CHG-3714
      l_sepv_ref_num_tab            t_ref_num;
      l_sepa_ref_num_tab            t_ref_num;
      l_prli_start_tab              t_date;
      l_prli_end_tab                t_date;
      l_sequence_tab                t_number;
      l_susp_sepv_tab               t_ref_num;
      l_susp_start_tab              t_date;
      l_susp_end_tab                t_date;
      l_susp_close_tab              t_date;   -- CHG-2795
      l_prli_data_tab               t_prli_data;
      l_dummy                       NUMBER;  -- CHG-6214
      l_prli_idx                    NUMBER;
      l_susp_idx                    NUMBER;
      l_susp_prorated_idx           NUMBER;   -- CHG-2795
      l_prices_idx                  NUMBER;
      l_max_price_idx               NUMBER;
      l_max_price                   NUMBER;
      l_sum_price                   NUMBER;   -- CHG-2795
      l_next_start_date             DATE;
      l_found_sepa_ref_num          service_parameters.ref_num%TYPE;
      l_prli_data_tab_idx           NUMBER;
      l_min_sequence                NUMBER;
      l_num_days                    NUMBER;   -- CHG-2795
      l_days_charge                 NUMBER;   -- CHG-2795
      l_diff_charge                 NUMBER;   -- CHG-2795
      l_first                       BOOLEAN;   -- CHG-2795
      l_last                        BOOLEAN;   -- CHG-2795
      l_smallest                    BOOLEAN;   -- CHG-2795
      l_biggest                     BOOLEAN;   -- CHG-2795
      l_prorated                    BOOLEAN;   -- CHG-2795
      l_unspecified                 BOOLEAN;   -- CHG-2795
      l_found                       BOOLEAN;   -- CHG-2795
      l_prorated_by_sety_dates      BOOLEAN;   -- CHG-3714
      l_prorated_start_date         DATE;   -- CHG-3714
      l_prorated_end_date           DATE;   -- CHG-3714
      l_prorated_closed_date        DATE;   -- CHG-3714
      l_charge_prorata              VARCHAR2(1);  -- CHG-6214
      l_last_idx                    NUMBER;  -- CHG-4482
      l_pricetab_idx                NUMBER;  -- CHG-4482
      l_start_num                   NUMBER;  -- CHG-4482
      l_end_num                     NUMBER;  -- CHG-4482
   BEGIN
      --
      l_sum_price := 0;
      l_diff_charge := 0;
      
      /*
        ** CHG-6386: Testperioodil tagastamisel uue lepingu puhul hinnastamist ei toimu
      */
      IF p_test_period_sept_type IN ('MBB','MDU') AND
         p_newmob_order = 'Y'
      THEN
         RETURN;
      END IF;


      l_charge_prorata := p_charge_prorata;  -- CHG-6214
      
      /*
        ** CHG-4482: Kontrollime, kas on tegemist MAIN_BILL'iga - hinnakirja mälutabelite olemasolu
      */
      IF g_marker_ficv.EXISTS(p_sety_ref_num) OR
         g_marker_prli.EXISTS(p_sety_ref_num)
      THEN
         /*
           ** CHG-4482: Hinnakiri mälutabelitest
         */
         l_last_idx := 0;

         -- 1) Kui mobiilile kehtib erihind, siis täidame hinnatabelid kõigepealt sellega
         IF g_ssfc_serv_tab.EXISTS(p_sety_ref_num) THEN
            --
            OPEN  c_ssfc;
            FETCH c_ssfc BULK COLLECT INTO l_fcit_type_code_tab
                                         , l_taty_type_code_tab
                                         , l_bise_tab
                                         , l_charge_parameter_tab   -- CHG-2795
                                         , l_first_prorated_charge_tab   -- CHG-2795
                                         , l_last_prorated_charge_tab    -- CHG-6214
                                         , l_prorated_by_sety_tab   -- CHG-3714
                                         , l_charge_value_tab
                                         , l_sepv_ref_num_tab
                                         , l_sepa_ref_num_tab
                                         , l_prli_start_tab
                                         , l_prli_end_tab
                                         , l_sequence_tab;

            CLOSE c_ssfc;
            --
         END IF;
         --
         IF l_fcit_type_code_tab.EXISTS(1) THEN
            l_last_idx := l_fcit_type_code_tab.LAST;
         ELSE
            l_last_idx := 0;  -- mobiili erihindu pole
         END IF;
         
         -- 2) FCIV hinnad
         IF g_marker_ficv.EXISTS(p_sety_ref_num) THEN
            --
            l_start_num := g_marker_ficv(p_sety_ref_num).start_num;
            l_end_num   := g_marker_ficv(p_sety_ref_num).end_num;
            --
            FOR i IN l_start_num .. l_end_num LOOP
               --
               IF g_price_table_ficv(i).sept_type_code = p_sept_type_code THEN
                  --
                  l_last_idx := l_last_idx + 1;
                  --
                  l_fcit_type_code_tab(l_last_idx)        := g_price_table_ficv(i).fcit_type_code;
                  l_taty_type_code_tab(l_last_idx)        := g_price_table_ficv(i).taty_type_code;
                  l_bise_tab(l_last_idx)                  := g_price_table_ficv(i).billing_selector;
                  l_charge_parameter_tab(l_last_idx)      := g_price_table_ficv(i).charge_parameter;
                  l_first_prorated_charge_tab(l_last_idx) := g_price_table_ficv(i).first_prorated_charge;
                  l_last_prorated_charge_tab(l_last_idx)  := g_price_table_ficv(i).last_prorated_charge;
                  l_prorated_by_sety_tab(l_last_idx)      := g_price_table_ficv(i).sety_first_prorated;
                  l_charge_value_tab(l_last_idx)          := g_price_table_ficv(i).charge_value;
                  l_sepv_ref_num_tab(l_last_idx)          := g_price_table_ficv(i).sepv_ref_num;
                  l_sepa_ref_num_tab(l_last_idx)          := g_price_table_ficv(i).sepa_ref_num;
                  l_prli_start_tab(l_last_idx)            := g_price_table_ficv(i).start_date;
                  l_prli_end_tab(l_last_idx)              := g_price_table_ficv(i).end_date;
                  l_sequence_tab(l_last_idx)              := g_price_table_ficv(i).sequence;
                  --
               END IF;
               --
            END LOOP;
            --
         END IF;
         
         -- 3) PRLI hinnad
         IF g_marker_prli.EXISTS(p_sety_ref_num) THEN
            --
            l_start_num := g_marker_prli(p_sety_ref_num).start_num;
            l_end_num   := g_marker_prli(p_sety_ref_num).end_num;
            --
            FOR i IN l_start_num .. l_end_num LOOP
               --
               IF g_price_table_prli(i).category = p_category THEN
                  --
                  l_last_idx := l_last_idx + 1;
                  --
                  l_fcit_type_code_tab(l_last_idx)        := g_price_table_prli(i).fcit_type_code;
                  l_taty_type_code_tab(l_last_idx)        := g_price_table_prli(i).taty_type_code;
                  l_bise_tab(l_last_idx)                  := g_price_table_prli(i).billing_selector;
                  l_charge_parameter_tab(l_last_idx)      := g_price_table_prli(i).charge_parameter;
                  l_first_prorated_charge_tab(l_last_idx) := g_price_table_prli(i).first_prorated_charge;
                  l_last_prorated_charge_tab(l_last_idx)  := g_price_table_prli(i).last_prorated_charge;
                  l_prorated_by_sety_tab(l_last_idx)      := g_price_table_prli(i).sety_first_prorated;
                  l_charge_value_tab(l_last_idx)          := g_price_table_prli(i).charge_value;
                  l_sepv_ref_num_tab(l_last_idx)          := g_price_table_prli(i).sepv_ref_num;
                  l_sepa_ref_num_tab(l_last_idx)          := g_price_table_prli(i).sepa_ref_num;
                  l_prli_start_tab(l_last_idx)            := g_price_table_prli(i).start_date;
                  l_prli_end_tab(l_last_idx)              := g_price_table_prli(i).end_date;
                  l_sequence_tab(l_last_idx)              := g_price_table_prli(i).sequence;
                  --
               END IF;
               --
            END LOOP;
            --
         END IF;
         --
      ELSE      
         /*
           ** Leiame ette antud ajavahemikul teenusele määratud hinnakirja- ja erihinnad.
           ** CHG-4482: Üksiku MAAC-i põhine käivitus
         */
         OPEN  c_prli;
         FETCH c_prli
         BULK COLLECT INTO l_fcit_type_code_tab
                         , l_taty_type_code_tab
                         , l_bise_tab
                         , l_charge_parameter_tab   -- CHG-2795
                         , l_first_prorated_charge_tab   -- CHG-2795
                         , l_last_prorated_charge_tab    -- CHG-6214
                         , l_prorated_by_sety_tab   -- CHG-3714
                         , l_charge_value_tab
                         , l_sepv_ref_num_tab
                         , l_sepa_ref_num_tab
                         , l_prli_start_tab
                         , l_prli_end_tab
                         , l_sequence_tab;
         CLOSE c_prli;
         --
      END IF;

      /*
        ** Kontrollime hinnakirjast, kas esineb hinda parameetri väärtuse alusel ja leiame vajadusel
        ** parameetri väärtuste vahemikud.
        ** Loodetavasti ei hinnata perioodi sees teenust erinevate parameetrite (sepa) väärtuste alusel.
      */
      l_prli_idx := l_fcit_type_code_tab.FIRST;

      --
      WHILE l_prli_idx IS NOT NULL LOOP
         IF l_sepa_ref_num_tab (l_prli_idx) IS NOT NULL THEN
            l_found_sepa_ref_num := l_sepa_ref_num_tab (l_prli_idx);
            EXIT;
         END IF;

         --
         l_prli_idx := l_fcit_type_code_tab.NEXT (l_prli_idx);
      END LOOP;

      /*
        ** Kui leidub parameetri väärtuse alusel hindamist, siis leiame teenuse parameetri väärtuste
        ** perioodid. Kui parameetri väärtuse alusel hindamist pole, siis on k?ik 1 periood.
      */
      IF l_found_sepa_ref_num IS NOT NULL AND
         p_prev_sepv_ref_num IS NULL  -- CHG-6386: Hinnastamine toimub kaasaantud parameetri järgi
      THEN
         OPEN c_susp (l_found_sepa_ref_num);

         FETCH c_susp
         BULK COLLECT INTO l_susp_sepv_tab
               ,l_susp_start_tab
               ,l_susp_end_tab
               ,l_susp_close_tab;   -- CHG-2795

         CLOSE c_susp;
      ELSE
         l_susp_start_tab (1) := p_start_date;
         l_susp_end_tab (1)   := p_end_date;
         l_susp_sepv_tab (1)  := p_prev_sepv_ref_num; -- CHG-6386: Hinnastamine toimub kaasaantud parameetri järgi. -- NULL;

         /*
           ** CHG-2795: Leiame, kas teenus on antud perioodis suletud.
         */
         OPEN c_stpe_end;

         FETCH c_stpe_end
          INTO l_susp_close_tab (1);

         l_found := c_stpe_end%FOUND;

         CLOSE c_stpe_end;

         --
         IF NOT l_found THEN
            l_susp_close_tab (1) := NULL;
         END IF;
      --
      END IF;

      /*
        ** Järgnevalt paneme kokku hinnatavate perioodide tabeli lähtudes teenusparameetri väärtuse perioodidest.
      */
      l_susp_idx := l_susp_start_tab.FIRST;

      --
      WHILE l_susp_idx IS NOT NULL LOOP
         l_min_sequence := 9999;   -- CHG-741
         -- CHG-2795
         l_first := FALSE;
         l_last := FALSE;
         l_smallest := FALSE;
         l_biggest := FALSE;
         l_prorated := FALSE;
         l_unspecified := FALSE;
         l_prorated_by_sety_dates := FALSE;
         -- CHG-5762: Kui parameeter väärtustatud, siis arveldame alati päevapõhiselt.
         IF p_charge_prorata = 'Y' THEN
            l_prorated := TRUE;
         END IF;
         /*
           ** Käime läbi PL/SQL tabelitesse salvestatud hinnakirja alates prioriteetsematest hindadest
           ** (erihinnad mobiilile) ja salvestame hinnatud vahemikud. Hindamata jäänud vahemikud
           ** hindame seejärel vähemprioriteetsete hindadega (erihinnad paketile -> hinnakirja hinnad paketikategooriale ->
           ** üldised hinnakirja hinnad).
         */
         l_prli_idx := l_fcit_type_code_tab.FIRST;

         --
         WHILE l_prli_idx IS NOT NULL LOOP
            /*
              ** CHG-2795: Väärtustame määrangute lipud
            */
            IF l_prli_idx = 1 THEN
               IF l_charge_parameter_tab (l_prli_idx) = 'FIRST' THEN
                  l_first := TRUE;
               ELSIF l_charge_parameter_tab (l_prli_idx) = 'LAST' THEN
                  l_last := TRUE;
               ELSIF l_charge_parameter_tab (l_prli_idx) = 'SMALLEST' THEN
                  l_smallest := TRUE;
               ELSIF l_charge_parameter_tab (l_prli_idx) = 'BIGGEST' THEN
                  l_biggest := TRUE;
               ELSE
                  l_unspecified := TRUE;
               END IF;

               --
               IF l_first_prorated_charge_tab (l_prli_idx) = 'Y' THEN
                  l_prorated := TRUE;
               END IF;
               
               -- CHG-6214
               IF l_last_prorated_charge_tab (l_prli_idx) = 'Y' THEN
                  -- Check if package closed in period - charge prorata
                  OPEN  c_sept_closed;
                  FETCH c_sept_closed INTO l_dummy;
                  l_found := c_sept_closed%FOUND;
                  CLOSE c_sept_closed;
                  --
                  IF l_found THEN
                     l_prorated := TRUE;
                     l_charge_prorata := 'Y';  -- CHG-6214
                  END IF;
                  --
               END IF;

               -- CHG-3714
               IF l_prorated_by_sety_tab (l_prli_idx) = 'Y' THEN
                  l_prorated_by_sety_dates := TRUE;
               END IF;
            END IF;

            /*
              ** CHG-3704: Väärtustame väljundparameetrid
                */
            p_charge_parameter := l_charge_parameter_tab (l_prli_idx);
            p_first_prorated := l_prorated;

            --
            IF     l_prli_start_tab (l_prli_idx) <= l_susp_end_tab (l_susp_idx)
               AND l_prli_end_tab (l_prli_idx) >= TRUNC (l_susp_start_tab (l_susp_idx))
               AND   -- Teenusparameetrid ajafaktoriga, hinnakiri päeva täpsusega
                   (   l_sepv_ref_num_tab (l_prli_idx) IS NULL
                    OR l_sepv_ref_num_tab (l_prli_idx) = l_susp_sepv_tab (l_susp_idx)
                   ) THEN
               IF l_sequence_tab (l_prli_idx) < l_min_sequence THEN   -- CHG-741
                  l_min_sequence := l_sequence_tab (l_prli_idx);
               END IF;

               /*
                 ** Hinnad min prioriteediga kuuluvad alati arvestamisele, kui vähegi parameetri väärtus sobib.
                 ** Madalamate prioriteetide korral kuuluvad arvestamisele selles vahemikus, kus veel pole hinda.
               */
               IF l_sequence_tab (l_prli_idx) <= l_min_sequence THEN
                  l_prli_data_tab_idx := TO_NUMBER (TO_CHAR (GREATEST (l_susp_start_tab (l_susp_idx)
                                                                      ,l_prli_start_tab (l_prli_idx)
                                                                      )
                                                            ,'YYMMDDHH24MI'
                                                            )
                                                   );

                  /*
                    ** CHG-2795: Fikseeritud kuutasuga mobiilitaseme teenuste kuutasu arvutatakse vastavalt
                    **           tellimuses toodud häälestuse variantidele.
                  */
                  IF l_first THEN
                     -- Esimene kehtiv kuutasu
                     IF l_prli_idx = 1 THEN
                        l_max_price := l_charge_value_tab (l_prli_idx);
                        l_max_price_idx := l_prli_data_tab_idx;
                        p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                        IF l_prorated THEN
                           l_susp_prorated_idx := l_susp_idx;
                        END IF;
                     END IF;
                  --
                  ELSIF l_smallest THEN
                     -- Väikseim erinevatest kuutasudest
                     IF l_charge_value_tab (l_prli_idx) < l_max_price OR l_max_price IS NULL THEN
                        l_max_price := l_charge_value_tab (l_prli_idx);
                        l_max_price_idx := l_prli_data_tab_idx;
                        p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                        IF l_prorated THEN
                           l_susp_prorated_idx := l_susp_idx;
                        END IF;
                     END IF;
                  --
                  ELSIF l_biggest THEN
                     -- Suurim erinevatest kuutasudest
                     IF l_charge_value_tab (l_prli_idx) > l_max_price OR l_max_price IS NULL THEN   -- CHG-3714: OR l_max_price IS NULL
                        l_max_price := l_charge_value_tab (l_prli_idx);
                        l_max_price_idx := l_prli_data_tab_idx;
                        p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                        IF l_prorated THEN
                           l_susp_prorated_idx := l_susp_idx;
                        END IF;
                     END IF;
                  --
                  ELSIF l_last THEN
                     -- Viimane kehtiv kuutasu
                     l_max_price := l_charge_value_tab (l_prli_idx);
                     l_max_price_idx := l_prli_data_tab_idx;
                     p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                     IF l_prorated THEN
                        l_susp_prorated_idx := l_susp_idx;
                     END IF;
                  --
                  ELSE
                     --Määrangud määramata
                     IF l_charge_value_tab (l_prli_idx) > l_max_price OR l_max_price IS NULL THEN   -- CHG-3714: OR l_max_price IS NULL
                        l_max_price := l_charge_value_tab (l_prli_idx);
                        l_max_price_idx := l_prli_data_tab_idx;
                     END IF;

                     --
                     IF l_prorated THEN
                        l_susp_prorated_idx := l_susp_idx;
                     END IF;
                  --
                  END IF;

                  --
                  l_prli_data_tab (l_prli_data_tab_idx).fcit_type_code := l_fcit_type_code_tab (l_prli_idx);
                  l_prli_data_tab (l_prli_data_tab_idx).taty_type_code := l_taty_type_code_tab (l_prli_idx);
                  l_prli_data_tab (l_prli_data_tab_idx).billing_selector := l_bise_tab (l_prli_idx);
                  l_prli_data_tab (l_prli_data_tab_idx).charge_value := l_charge_value_tab (l_prli_idx);
                  l_prli_data_tab (l_prli_data_tab_idx).start_date :=
                                         TRUNC (GREATEST (l_susp_start_tab (l_susp_idx), l_prli_start_tab (l_prli_idx)));
                  l_prli_data_tab (l_prli_data_tab_idx).end_date :=
                                                        LEAST (l_susp_end_tab (l_susp_idx), l_prli_end_tab (l_prli_idx));
               --
               ELSIF l_found_sepa_ref_num IS NOT NULL THEN   -- CHG-2795: ELSE
                  /*
                    ** Madalama prioriteediga hinnad arvestatakse ainult nendes vahemikes, kus pole ees
                    ** k?rgema prioriteediga hindasid.
                  */
                  l_prices_idx := l_prli_data_tab.FIRST;
                  l_next_start_date := TRUNC (GREATEST (l_susp_start_tab (l_susp_idx), l_prli_start_tab (l_prli_idx)));

                  --
                  WHILE l_prices_idx IS NOT NULL LOOP
                     IF     l_prli_data_tab (l_prices_idx).start_date <=
                                                       LEAST (l_susp_end_tab (l_susp_idx), l_prli_end_tab (l_prli_idx))
                        AND l_prli_data_tab (l_prices_idx).end_date >=
                               TRUNC
                                  (GREATEST (l_susp_start_tab (l_susp_idx), l_prli_start_tab (l_prli_idx)))   -- Teenusparameetrid ajafaktoriga, hinnakiri päeva täpsusega
                                                                                                           THEN
                        IF l_prli_data_tab (l_prices_idx).start_date > l_next_start_date THEN
                           /*
                             ** Leitud tühi vahemik hindades, kuhu see hind sobib.
                             ** CHG-2795: Fikseeritud kuutasuga mobiilitaseme teenuste kuutasu arvutatakse vastavalt
                             **           tellimuses toodud häälestuse variantidele.
                           */
                           l_prli_data_tab_idx := TO_NUMBER (TO_CHAR (l_next_start_date, 'YYMMDDHH24MI'));

                           --
                           IF l_first THEN
                              -- Esimene kehtiv kuutasu
                              IF l_prli_idx = 1 THEN
                                 l_max_price := l_charge_value_tab (l_prli_idx);
                                 l_max_price_idx := l_prli_data_tab_idx;
                                 p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                                 IF l_prorated THEN
                                    l_susp_prorated_idx := l_susp_idx;
                                 END IF;
                              END IF;
                           --
                           ELSIF l_smallest THEN
                              -- Väikseim erinevatest kuutasudest
                              IF l_charge_value_tab (l_prli_idx) < l_max_price OR l_max_price IS NULL THEN
                                 l_max_price := l_charge_value_tab (l_prli_idx);
                                 l_max_price_idx := l_prli_data_tab_idx;
                                 p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                                 IF l_prorated THEN
                                    l_susp_prorated_idx := l_susp_idx;
                                 END IF;
                              END IF;
                           --
                           ELSIF l_biggest THEN
                              -- Suurim erinevatest kuutasudest
                              IF l_charge_value_tab (l_prli_idx) > l_max_price OR l_max_price IS NULL THEN   -- CHG-3714: OR l_max_price IS NULL
                                 l_max_price := l_charge_value_tab (l_prli_idx);
                                 l_max_price_idx := l_prli_data_tab_idx;
                                 p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                                 IF l_prorated THEN
                                    l_susp_prorated_idx := l_susp_idx;
                                 END IF;
                              END IF;
                           --
                           ELSIF l_last THEN
                              -- Viimane kehtiv kuutasu
                              l_max_price := l_charge_value_tab (l_prli_idx);
                              l_max_price_idx := l_prli_data_tab_idx;
                              p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                              IF l_prorated THEN
                                 l_susp_prorated_idx := l_susp_idx;
                              END IF;
                           --
                           ELSE
                              --Määrangud määramata
                              IF l_charge_value_tab (l_prli_idx) > l_max_price OR l_max_price IS NULL THEN   -- CHG-3714: OR l_max_price IS NULL
                                 l_max_price := l_charge_value_tab (l_prli_idx);
                                 l_max_price_idx := l_prli_data_tab_idx;
                              END IF;

                              --
                              IF l_prorated THEN
                                 l_susp_prorated_idx := l_susp_idx;
                              END IF;
                           --
                           END IF;

                           --
                           l_prli_data_tab (l_prli_data_tab_idx).fcit_type_code := l_fcit_type_code_tab (l_prli_idx);
                           l_prli_data_tab (l_prli_data_tab_idx).taty_type_code := l_taty_type_code_tab (l_prli_idx);
                           l_prli_data_tab (l_prli_data_tab_idx).billing_selector := l_bise_tab (l_prli_idx);
                           l_prli_data_tab (l_prli_data_tab_idx).charge_value := l_charge_value_tab (l_prli_idx);
                           l_prli_data_tab (l_prli_data_tab_idx).start_date := l_next_start_date;
                           l_prli_data_tab (l_prli_data_tab_idx).end_date :=
                                                                           l_prli_data_tab (l_prices_idx).start_date - 1;
                        END IF;

                        --
                        l_next_start_date := l_prli_data_tab (l_prices_idx).end_date + 1;
                     END IF;

                     --
                     IF l_next_start_date > LEAST (l_susp_end_tab (l_susp_idx), l_prli_end_tab (l_prli_idx)) THEN
                        EXIT;
                     END IF;

                     --
                     l_prices_idx := l_prli_data_tab.NEXT (l_prices_idx);
                  END LOOP;

                  /*
                    ** Kui ajaperioodide l?pus on tühimik, siis see täidetakse nüüd.
                    ** CHG-2795: Fikseeritud kuutasuga mobiilitaseme teenuste kuutasu arvutatakse vastavalt
                    **           tellimuses toodud häälestuse variantidele.
                  */
                  IF l_next_start_date <= LEAST (l_susp_end_tab (l_susp_idx), l_prli_end_tab (l_prli_idx)) THEN
                     l_prli_data_tab_idx := TO_NUMBER (TO_CHAR (l_next_start_date, 'YYMMDDHH24MI'));

                     --
                     IF l_first THEN
                        -- Esimene kehtiv kuutasu
                        IF l_prli_idx = 1 THEN
                           l_max_price := l_charge_value_tab (l_prli_idx);
                           l_max_price_idx := l_prli_data_tab_idx;
                           p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                           IF l_prorated THEN
                              l_susp_prorated_idx := l_susp_idx;
                           END IF;
                        END IF;
                     --
                     ELSIF l_smallest THEN
                        -- Väikseim erinevatest kuutasudest
                        IF l_charge_value_tab (l_prli_idx) < l_max_price OR l_max_price IS NULL THEN
                           l_max_price := l_charge_value_tab (l_prli_idx);
                           l_max_price_idx := l_prli_data_tab_idx;
                           p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                           IF l_prorated THEN
                              l_susp_prorated_idx := l_susp_idx;
                           END IF;
                        END IF;
                     --
                     ELSIF l_biggest THEN
                        -- Suurim erinevatest kuutasudest
                        IF l_charge_value_tab (l_prli_idx) > l_max_price OR l_max_price IS NULL THEN   -- CHG-3714: OR l_max_price IS NULL
                           l_max_price := l_charge_value_tab (l_prli_idx);
                           l_max_price_idx := l_prli_data_tab_idx;
                           p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                           IF l_prorated THEN
                              l_susp_prorated_idx := l_susp_idx;
                           END IF;
                        END IF;
                     --
                     ELSIF l_last THEN
                        -- Viimane kehtiv kuutasu
                        l_max_price := l_charge_value_tab (l_prli_idx);
                        l_max_price_idx := l_prli_data_tab_idx;
                        p_priced_sepv_ref_num := l_susp_sepv_tab (l_susp_idx);   -- CHG-3908

                        IF l_prorated THEN
                           l_susp_prorated_idx := l_susp_idx;
                        END IF;
                     --
                     ELSE
                        --Määrangud määramata
                        IF l_charge_value_tab (l_prli_idx) > l_max_price OR l_max_price IS NULL THEN   -- CHG-3714: OR l_max_price IS NULL
                           l_max_price := l_charge_value_tab (l_prli_idx);
                           l_max_price_idx := l_prli_data_tab_idx;
                        END IF;

                        --
                        IF l_prorated THEN
                           l_susp_prorated_idx := l_susp_idx;
                        END IF;
                     --
                     END IF;

                     --
                     l_prli_data_tab (l_prli_data_tab_idx).fcit_type_code := l_fcit_type_code_tab (l_prli_idx);
                     l_prli_data_tab (l_prli_data_tab_idx).taty_type_code := l_taty_type_code_tab (l_prli_idx);
                     l_prli_data_tab (l_prli_data_tab_idx).billing_selector := l_bise_tab (l_prli_idx);
                     l_prli_data_tab (l_prli_data_tab_idx).charge_value := l_charge_value_tab (l_prli_idx);
                     l_prli_data_tab (l_prli_data_tab_idx).start_date := l_next_start_date;
                     l_prli_data_tab (l_prli_data_tab_idx).end_date :=
                                                TRUNC (LEAST (l_susp_end_tab (l_susp_idx), l_prli_end_tab (l_prli_idx)));
                  END IF;
               END IF;   -- IF l_sequence_tab(l_prli_idx) = 1 THEN
            END IF;

            --
            l_prli_idx := l_fcit_type_code_tab.NEXT (l_prli_idx);
         END LOOP;

         --Määrangud määramata, arveldusperioodi erinevad kuutasud summeeritakse
         IF l_unspecified THEN
            l_sum_price := l_sum_price + l_max_price;   -- CHG-2795
         END IF;

         --
         l_susp_idx := l_susp_start_tab.NEXT (l_susp_idx);
      END LOOP;

      /*
        ** Kontrolli m?ttes väljastaks loodud hindade tabeli.
      */
      /*
      l_prices_idx := l_prli_data_tab.First;
      --
      WHILE l_prices_idx IS NOT NULL LOOP
         dbms_output.put_line(
               'SUSG=' || to_char(p_susg_ref_num) ||
               ', SETY=' || to_char(p_sety_ref_num) ||
               ', SEPT=' || p_sept_type_code || ': ' ||
               to_char(l_prli_data_tab(l_prices_idx).start_date, 'DD.MM.YYYY') || '-' ||
               to_char(l_prli_data_tab(l_prices_idx).end_date, 'DD.MM.YYYY') || ': ' ||
               to_char(l_prli_data_tab(l_prices_idx).charge_value)
         );
         --
         l_prices_idx := l_prli_data_tab.Next(l_prices_idx);
      END LOOP;
      */

      /*
        ** Teenusega või teenuse parameetriga liitumise kuul arvutatakse
        ** aktiivsete päevade arvu põhiselt kui samas perioodis ei ole lõpetanud ehk mõjutab
        ** aruandeperioodi lõpus kehtivat teenustasu (lõpetamiskuul täies mahus).
      */
      IF l_prorated AND l_max_price_idx IS NOT NULL   -- CHG-3811
                                                   THEN
         /*
           ** CHG-3714: Kui on määratud teenusepõhine liitumiskuu aktiivsete päevade arvu põhine
           **    hinnastamine, siis arvutame päevade arvu põhise hinna teenuse aktiivsete päevade
           **    järgi, hoolimata teenuse parameetrite kuupäevadest.
         */
         IF l_prorated_by_sety_dates THEN
            l_prorated_start_date := l_susp_start_tab (l_susp_start_tab.FIRST);
            l_prorated_end_date := l_susp_end_tab (l_susp_end_tab.LAST);

            --
            IF l_susp_close_tab (l_susp_close_tab.LAST) IS NOT NULL THEN
               /* CHG-3861 */
               IF l_susp_close_tab (l_susp_close_tab.LAST) > LAST_DAY (TRUNC (p_end_date)) + 1 - 1 / 86000 THEN
                  -- Parameeter suletud järgmises arveldusperioodis
                  l_prorated_closed_date := l_susp_close_tab (l_susp_close_tab.LAST);
               ELSE
                  -- Paketivahetus MinuEMT-st teise paketti enne arveldusperioodi lõppu (CG teenus jääb lahti, vastasel korral tuleks päevapõhine hind)
                  -- Sulgemiskuupäevaks võtta pakett+teenus kombinatsiooni sulgemisaeg.
                  l_prorated_closed_date := l_prorated_end_date;
               END IF;
            /* End CHG-3861 */
            ELSE
               l_prorated_closed_date := NULL;
            END IF;
         ELSE
            l_prorated_start_date := l_susp_start_tab (l_susp_prorated_idx);
            l_prorated_end_date := l_susp_end_tab (l_susp_prorated_idx);
            l_prorated_closed_date := l_susp_close_tab (l_susp_prorated_idx);
         END IF;

         /*
           ** CHG-2795: L_susp_prorated_idx'i l_prli_data_tab(l_max_price_idx).charge_value tuleb arvutada
           **    päevade p?hiseks kui start_date aruandeperioodis ja End_date = null.
           **    Summeeritud kuutasu korrigeerida charge_value ja arvutatud päevade arvu p?hise hinna vahega.
         */
         IF     l_prorated_end_date IS NOT NULL
            AND (   l_prorated_start_date > p_start_date
                 OR l_prorated_start_date > TRUNC (LAST_DAY (ADD_MONTHS (p_start_date, -1)) + 1)
                 OR l_charge_prorata = 'Y' -- CHG-5762: Maksustame alati päevapõhiselt!
                )
            AND (   l_prorated_closed_date > p_end_date 
                 OR l_prorated_closed_date IS NULL
                 OR l_charge_prorata = 'Y' -- CHG-5762: Maksustame alati päevapõhiselt!
                )             
         THEN
            -- Leida num_of_days
            p_num_of_days := NVL (TRUNC (l_prorated_end_date), p_end_date) - TRUNC (l_prorated_start_date - 1);
            -- Kuutasu päevade põhiseks
            l_num_days := TO_NUMBER (TO_CHAR (LAST_DAY (p_end_date), 'dd'));
            l_days_charge := (l_prli_data_tab (l_max_price_idx).charge_value / l_num_days) * p_num_of_days;
            -- Leida vahe korrigeerimiseks
            l_diff_charge := l_prli_data_tab (l_max_price_idx).charge_value - l_days_charge;

            -- Leida vahe korrigeerimiseks, kui määrangud määramata.
            IF NVL (l_sum_price, 0) > 0 THEN
               l_diff_charge := l_sum_price - ((l_sum_price / l_num_days) * p_num_of_days);
            END IF;
         END IF;
      --
      END IF;

      /*
        ** Protseduuri väljundi moodustamine: max hind + sellele vastavast reast arvele kandmise atribuudid (FCIT, BISE, TATY).
      */
      IF l_max_price_idx IS NOT NULL THEN
         --
         IF NVL (l_sum_price, 0) > 0 THEN
            p_price := l_sum_price - NVL (l_diff_charge, 0);
            p_monthly_price := l_sum_price; -- CHG-5762
         ELSE
            p_price := l_prli_data_tab (l_max_price_idx).charge_value - NVL (l_diff_charge, 0);
            p_monthly_price := l_prli_data_tab (l_max_price_idx).charge_value; -- CHG-5762
         END IF;

         --
         p_price := ROUND (p_price, 2);
         p_fcit_type_code := l_prli_data_tab (l_max_price_idx).fcit_type_code;
         p_billing_selector := l_prli_data_tab (l_max_price_idx).billing_selector;
         p_taty_type_code := l_prli_data_tab (l_max_price_idx).taty_type_code;
      END IF;
   --
   END get_period_max_price;

   /***************************************************************************
   **
   **   Procedure Name :  Invoice_MAAC_NonKER_Serv_Fees
   **
   **   Description : Protseduur leiab perioodi INB arve ette antud masterile.
   **                 Kui arvet veel pole, siis luuakse uus arve.
   **                 Leitud arvele kantakse PL/SQL tabelisse salvestatud teenuste
   **                 kuutasude read antud masterile.
   **
   ****************************************************************************/
   PROCEDURE invoice_maac_nonker_serv_fees (
      p_maac_ref_num  IN      accounts.ref_num%TYPE
     ,p_period_start  IN      DATE
     ,p_inen_tab      IN OUT  icalculate_fixed_charges.t_inen
     ,p_success       OUT     BOOLEAN
     ,p_error_text    OUT     VARCHAR2
     ,p_invo_ref_num  IN      invoices.ref_num%TYPE   -- vahearvete, vahesaldode korral on arve ref teada
     ,p_interim       IN      BOOLEAN
   ) IS
      --
      l_invo_rec                    invoices%ROWTYPE;
      --
      e_creating_invoice            EXCEPTION;
   BEGIN
      IF p_invo_ref_num IS NOT NULL THEN
         l_invo_rec.ref_num := p_invo_ref_num;
      ELSE
         /*
           ** Leiame arve, kuhu masteri arveread kanda.
         */
         get_invoice (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                     ,p_period_start   -- IN     DATE
                     ,p_success   --    OUT BOOLEAN
                     ,p_error_text   --    OUT VARCHAR2
                     ,l_invo_rec   --    OUT invoices%ROWTYPE
                     );

         IF NOT p_success THEN
            RAISE e_creating_invoice;
         END IF;
      END IF;

      /*
        ** Kui arve edukalt leitud, siis kanname masteri arveread leitud arvele.
      */
      icalculate_fixed_charges.write_down_invoice_entries
                                            (p_inen_tab   -- IN OUT t_inen
                                            ,l_invo_rec.ref_num   -- IN     invoices.ref_num%TYPE
                                            ,c_module_ref_short   -- p_module_ref   IN     invoice_entries.module_ref%TYPE
                                            ,p_interim   -- IN     BOOLEAN DEFAULT FALSE
                                            );
      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_creating_invoice THEN
         p_success := FALSE;
   END invoice_maac_nonker_serv_fees;

   /***************************************************************************
   **
   **   Procedure Name :  Create_NonKER_Serv_Fee_INEN
   **
   **   Description : Protseduur kontrollib leitud kuutasu summa arvele kandmise vajalikkust:
   **                 kui > seni perioodi arvetele kantud summa (nende teenuste kohta
   **                 läheb arvele max väärtusega hind perioodis).
   **                 Kui arvele kandmine OK, siis luuakse arverea struktuuriga PL/SQL
   **                 tabeli kirje.
   **                 CHG-3946: Leiame arvel oleva teenuse kuutasu ilma billing_selectorit vaatamata.
   **                 Arvesse võetakse kõik FCIT-id, mis vastavad teenusele. Kui teenus puudub,
   **                 siis leitakse arverida ainult FCIT-i järgi (MinuEMT lahendustasu).
   **                 CHG-4635: Eemaldatud kursorist tingimus 'p_sety_ref_num IS NULL AND'
   **
   ****************************************************************************/
   PROCEDURE create_nonker_serv_fee_inen (
      p_maac_ref_num      IN      accounts.ref_num%TYPE
     ,p_susg_ref_num      IN      subs_serv_groups.ref_num%TYPE
     ,p_sety_ref_num      IN      service_types.ref_num%TYPE
     ,p_period_start      IN      DATE
     ,p_period_end        IN      DATE
     ,p_fcit_type_code    IN      fixed_charge_item_types.type_code%TYPE
     ,p_taty_type_code    IN      fixed_charge_item_types.taty_type_code%TYPE
     ,p_billing_selector  IN      fixed_charge_item_types.billing_selector%TYPE
     ,p_price             IN      NUMBER
     ,p_inen_tab          IN OUT  icalculate_fixed_charges.t_inen
     ,p_sum_to_invoice    OUT     NUMBER   -- CHG-3984
     ,p_num_of_days       IN      NUMBER DEFAULT NULL  -- CHG-5762
     ,p_charge_prorata    IN      VARCHAR2 DEFAULT 'N' -- CHG-5762
     ,p_sol_fee_indicator IN      VARCHAR2 DEFAULT NULL  -- CHG-13617
     ,p_interim           IN      BOOLEAN DEFAULT FALSE  -- CHG-13641
   ) IS
      --
      CURSOR c_inen IS
         SELECT SUM (inen.eek_amt)
           FROM invoice_entries inen, invoices invo
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start AND p_period_end
            AND inen.invo_ref_num = invo.ref_num
            AND (inen.susg_ref_num = p_susg_ref_num OR inen.susg_ref_num IS NULL AND p_susg_ref_num IS NULL
                )   -- CHG-4418
            --AND    inen.billing_selector = p_billing_selector CHG-3946: commented out
            AND inen.fcit_type_code IN (SELECT type_code
                                          FROM fixed_charge_item_types
                                         WHERE (   sety_ref_num = p_sety_ref_num
                                                OR sety_ref_num IS NULL AND type_code = p_fcit_type_code
                                               )
                                           AND regular_charge = 'Y'
                                           AND once_off = 'N'
                                           AND pro_rata = 'N')
      ;
      -- CHG-5762
      CURSOR c_comc_sum IS
         SELECT Sum(comc.eek_amt)
         FROM common_monthly_charges comc
            , invoices invo
         WHERE invo.maac_ref_num = p_maac_ref_num
           AND invo.billing_inv = 'Y'
           AND invo.period_start BETWEEN p_period_start AND p_period_end
           AND comc.invo_ref_num = invo.ref_num
           AND (comc.susg_ref_num = p_susg_ref_num OR comc.susg_ref_num IS NULL AND p_susg_ref_num IS NULL)
           AND comc.fcit_type_code IN (SELECT type_code
                                       FROM fixed_charge_item_types
                                       WHERE (   sety_ref_num = p_sety_ref_num
                                               OR sety_ref_num IS NULL AND type_code = p_fcit_type_code
                                              )
                                         AND regular_charge = 'Y'
                                         AND once_off = 'N'
                                         AND pro_rata = 'N')
           AND comc.iadn_ref_num IS NOT NULL  -- PAK komplekti teenustasu (läheb alati lahendustasu sisse)
           AND comc.num_of_days IS NOT NULL
      ;      
      -- CHG-13641: Teenuse miinimumkuutasu
      CURSOR c_min_fix_fee IS
         SELECT mose.min_fix_monthly_fee
              , mose.mipo_ref_num
              , mose.mips_ref_num
         FROM mixed_packet_orders mipo
            , mixed_order_services mose
            , fixed_term_contracts ftco
         WHERE mipo.mixed_packet_code = ftco.mixed_packet_code
           AND mipo.ebs_order_number = ftco.ebs_order_number
           AND mose.mipo_ref_num = mipo.ref_num
           AND mose.sety_ref_num = p_sety_ref_num
           AND ftco.susg_ref_num = p_susg_ref_num
           AND ftco.start_date <= p_period_end
           AND Nvl(ftco.date_closed, ftco.end_date) >= p_period_start
      ;
      -- CHG-13641
      CURSOR c_mips_dico (p_mips_ref_num  NUMBER) IS
         SELECT monthly_disc_rate, monthly_markdown
         FROM mixed_packet_services
         WHERE ref_num = p_mips_ref_num
      ;
      --
      l_invoiced_sum                NUMBER;
      l_comc_sum                    NUMBER; -- CHG-5762
      l_sum_to_invoice              NUMBER;
      l_inen_sum_tab                icalculate_fixed_charges.t_inen_sum;
      l_max_sum_to_invoice          NUMBER;                              -- CHG-13641
      l_monthly_fee                 NUMBER;                              -- CHG-13641
      l_min_fix_fee                 NUMBER;                              -- CHG-13641
      l_disc_rate                   NUMBER;                              -- CHG-13641
      l_disc_amount                 NUMBER;                              -- CHG-13641
      l_discount                    NUMBER;                              -- CHG-13641
      l_mipo_ref_num                mixed_packet_orders.ref_num%TYPE;    -- CHG-13641
      l_mips_ref_num                mixed_packet_services.ref_num%TYPE;  -- CHG-13641
   BEGIN
      /*
        ** Leiame perioodi (vahe)arvetele kantud teenuse kuutasude summa.
        ** Arvele läheb leitud max hinna ja juba arvetele kantud summa vahe, kui see on > 0.
        ** Kui max hind on juba perioodi arvetele kantud, siis siin enam ei kanta.
      */
      OPEN  c_inen;
      FETCH c_inen INTO l_invoiced_sum;
      CLOSE c_inen;
      
      /*
        ** CHG-5762: Leiame ka common_monthly_charges tabelisse kantud Paketeeritud lahendustasus
        **           sisalduvate teenuste kuutasude summa juhul, kui tegemist päevapõhise hinnastusskeemiga.
      */
      IF p_charge_prorata = 'Y' THEN
         --
         OPEN  c_comc_sum;
         FETCH c_comc_sum INTO l_comc_sum;
         CLOSE c_comc_sum;
         --
         l_invoiced_sum := l_invoiced_sum + Nvl(l_comc_sum, 0);
         --
      END IF;
      
      /*
        ** CHG-13641: Saldostopi puhul ei kanta PAK teenuseid COMC tabelisse. 
        **            Leiame ka kompleki teenuse soodustused ning miinimumkuutasud.
      */
      IF p_interim THEN
         -- Leiame, kas on tegemist PAK müügiga
         -- Leiame teenuse miinimumkuutasu
        
         OPEN  c_min_fix_fee;
         FETCH c_min_fix_fee INTO l_min_fix_fee
                                , l_mipo_ref_num
                                , l_mips_ref_num;
         CLOSE c_min_fix_fee;
         --
         l_min_fix_fee := Nvl(l_min_fix_fee, 0);
         

         IF l_mips_ref_num IS NOT NULL THEN
            -- Leiame teenuse soodustuse (viimase kehtiva teenus+pakett vahemikus).
            OPEN  c_mips_dico(l_mips_ref_num);
            FETCH c_mips_dico INTO l_disc_rate
                                 , l_disc_amount;
            CLOSE c_mips_dico;
               
            -- Leiame soodustuse
            IF l_disc_rate > 0 THEN
               --
               l_discount := Round( (p_price * l_disc_rate)/100, 2);
               --
            ELSIF l_disc_amount IS NOT NULL THEN  -- MOBE-221: l_disc_amount > 0 -> IS NOT NULL (markup)
               IF l_disc_amount > p_price THEN
                  l_discount := p_price;
               ELSE
                  l_discount := l_disc_amount;
               END IF;
            END IF;
            --
         END IF;
         
         /*
           ** Kui eksisteerib miinimumkuutasu, siis võrdleme seda vastu soodustusega kuutasu
           ** Leiame päevapõhise hinna neist kahest suurimast.
         */
         --DOBAS-158 Ei kasuta enam teenuse min kuutasu l_min_fix_fee
         --l_monthly_fee := Greatest( (p_price - Nvl(l_discount, 0)), Nvl(l_min_fix_fee, 0) ); 
         l_monthly_fee :=  p_price - Nvl(l_discount, 0);               
               
         -- Leiame maksimaalse puuduoleva osa kuutasust
         l_max_sum_to_invoice := Greatest((l_monthly_fee - l_invoiced_sum), 0);
               
         -- Teenuse päevapõhine hind soodustusega
         l_sum_to_invoice := Round(l_monthly_fee, 2);
               
         -- Teenuse hind ei tohi ületada maksimaalset arveldatavad osa
         IF l_sum_to_invoice > l_max_sum_to_invoice THEN
            l_sum_to_invoice := l_max_sum_to_invoice;
         END IF;

         --
      ELSE
         --
         l_sum_to_invoice := p_price - NVL (l_invoiced_sum, 0);
         --
      END IF;
      /* End CHG-13641 */
      

      --
      IF l_sum_to_invoice > 0 THEN
         /*
           ** Tekitatakse arverida PL/SQL tabelis (esialgul ilma arve ref-ita).
         */
         icalculate_fixed_charges.add_invoice_entry
                                 (p_inen_tab           -- IN OUT t_inen
                                 ,l_inen_sum_tab       -- IN OUT t_inen_sum; seda siin tegelikult ei kasutata
                                 ,NULL                 -- p_invo_ref_num     IN     invoices.ref_num%TYPE
                                 ,p_fcit_type_code     -- IN     FIXED_CHARGE_ITEM_TYPES.TYPE_CODE%TYPE
                                 ,p_taty_type_code     -- IN     FIXED_CHARGE_ITEM_TYPES.TATY_TYPE_CODE%TYPE
                                 ,p_billing_selector   -- IN     FIXED_CHARGE_ITEM_TYPES.BILLING_SELECTOR%TYPE
                                 ,l_sum_to_invoice     -- p_charge_value     IN     NUMBER
                                 ,p_susg_ref_num       -- IN     SUBS_SERV_GROUPS.ref_num%TYPE
                                 ,p_num_of_days        -- CHG-5762  IN     NUMBER
                                 ,c_module_ref_short   -- p_module_ref       IN     invoice_entries.module_ref%TYPE
                                 ,NULL                 -- p_maas_ref_num     IN     master_account_services.ref_num%TYPE
                                 ,NULL                 -- p_sept_type_code   IN     serv_package_types.type_code%TYPE; ei kasutata siin
                                 ,NULL                 -- p_start_date       IN     DATE; ei kasutata siin
                                 ,p_sol_fee_indicator  --p_sol_fee_indicator IN      VARCHAR2 DEFAULT NULL  -- CHG-13617
                                 );
         /*
           ** CHG-3984: Tagastada arvele kantud summa
         */
         p_sum_to_invoice := l_sum_to_invoice;
      END IF;
   END create_nonker_serv_fee_inen;
   /***************************************************************************
   **
   **   Procedure Name :  Create_NonKER_Serv_Fee_COMC
   **
   **   Description : Protseduur kannab abitabelisse komplekti teenuste kuutasud.
   **                 1) Leitakse arvele kantud teenuse tasud
   **                 2) Leitakse MinuEMT lahendustasus sisalduv teenuse kuutasu comc tabelist
   **                    (MAX comc kirje, millel num_of_days täitmata)
   **                 3) Leiakse PAK lahendustasus sisalduv teenuse kuutasu comc tabelist
   **                    (summeeritakse comc kirjed, millel num_of_days täidetud)
   **                 4) Leitakse teenuse arveldamata osa koos soodustusega
   **                    (soodustus tabelis mixed_packet_services)
   **                 5) Leitakse teenuse miinimumkuutasu     
   **                    Kui eksisteerib miinimumkuutasu, siis võrdleme seda vastu soodustusega kuutasu
   **                    Kui minimaalne kuutasu on suurem soodustusega teenusest, siis paneme arvele
   **                    puuduoleva osa teenuse minimaalsest kuutasust.
   **                 6) Kanname leitud teenuse kuutasu tabelisse common_monthly_charges
   **
   **                 MOBET-107: Kui teenusele kehtib komplektis kuutasu soodustus, siis ei tohi rakenduda pakkumise kuutasu soodustus (SUDI) '
   **                 Komplekti teenuse kuutasu arvutatakse päevapõhiselt. Kui aruandeperioodis esineb teenusel komplektita ja komplektiga perioode, siis 
   **                 1. komplektita perioodides rakendatakse pakkumise (SUDI) soodustust  
   **                 2. Komplektiga perioodides rakendub komplektis defineeritud soodustus
   **                 3. Komplektiga perioodids kui puudub komplektis defineeritud soodustus, rakendatakse pakkumise soodustust
   **
   ****************************************************************************/
   PROCEDURE create_nonker_serv_fee_comc (
      p_invo_ref_num          IN      invoices.ref_num%TYPE
     ,p_maac_ref_num          IN      accounts.ref_num%TYPE
     ,p_susg_ref_num          IN      subs_serv_groups.ref_num%TYPE
     ,p_sety_ref_num          IN      service_types.ref_num%TYPE
     ,p_mixed_packet_code     IN      mixed_packets.packet_code%TYPE
     ,p_ebs_order_number      IN      mixed_packet_orders.ebs_order_number%TYPE
     ,p_stpe_start_date       IN      DATE
     ,p_stpe_end_date         IN      DATE
     ,p_period_start          IN      DATE
     ,p_period_end            IN      DATE
     ,p_fcit_type_code        IN      fixed_charge_item_types.type_code%TYPE
     ,p_taty_type_code        IN      fixed_charge_item_types.taty_type_code%TYPE
     ,p_billing_selector      IN      fixed_charge_item_types.billing_selector%TYPE
     ,p_price                 IN      NUMBER
     ,p_num_of_days           IN      NUMBER  
     ,p_monthly_price         IN      NUMBER
     ,p_sepv_ref_num          IN      NUMBER    -- MOBET-22/107
     ,p_sept_type_code        IN      VARCHAR2  -- MOBET-22/107
     ,p_interim               IN      BOOLEAN   -- MOBET-22/107
     ,p_test_period_sept_type IN      mixed_packet_orders.sept_category_type%TYPE DEFAULT NULL  -- CHG-6386
     ,p_newmob_order          IN      mixed_packet_orders.newmob_order%TYPE DEFAULT NULL        -- CHG-6386

   ) IS
      --
      CURSOR c_inen IS
         SELECT SUM (inen.eek_amt)
           FROM invoice_entries inen, invoices invo
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start AND p_period_end
            AND inen.invo_ref_num = invo.ref_num
            AND (inen.susg_ref_num = p_susg_ref_num OR inen.susg_ref_num IS NULL AND p_susg_ref_num IS NULL
                )   -- CHG-4418
            --AND    inen.billing_selector = p_billing_selector CHG-3946: commented out
            AND inen.fcit_type_code IN (SELECT type_code
                                          FROM fixed_charge_item_types
                                         WHERE (   sety_ref_num = p_sety_ref_num
                                                OR sety_ref_num IS NULL AND type_code = p_fcit_type_code
                                               )
                                           AND regular_charge = 'Y'
                                           AND once_off = 'N'
                                           AND pro_rata = 'N')
      ;
      -- Lahendustasu teenused täiskuutasuna (leiame suurima)
      CURSOR c_comc_max IS
         SELECT Max(comc.eek_amt)
         FROM common_monthly_charges comc
            , invoices invo

         WHERE invo.maac_ref_num = p_maac_ref_num
           AND invo.billing_inv = 'Y'
           AND invo.period_start BETWEEN p_period_start AND p_period_end
           AND comc.invo_ref_num = invo.ref_num
           AND (comc.susg_ref_num = p_susg_ref_num OR comc.susg_ref_num IS NULL AND p_susg_ref_num IS NULL)
           AND comc.fcit_type_code IN (SELECT type_code
                                       FROM fixed_charge_item_types
                                       WHERE (   sety_ref_num = p_sety_ref_num
                                               OR sety_ref_num IS NULL AND type_code = p_fcit_type_code
                                              )
                                         AND regular_charge = 'Y'
                                         AND once_off = 'N'
                                         AND pro_rata = 'N')
           AND EXISTS (select 1
                       from invoice_entries inen
                          , fixed_charge_item_types fcit
                          , fixed_charge_item_types fcit_bill
                       where inen.invo_ref_num = invo.ref_num
                         and fcit.type_code = comc.fcit_type_code
                         and fcit.billing_selector = comc.billing_selector
                         and fcit_bill.type_code = fcit.bill_fcit_type_code
                         and inen.fcit_type_code = fcit_bill.type_code
                         and inen.billing_selector = fcit_bill.billing_selector)
           AND comc.num_of_days IS NULL
      ;
      --  Lahendustasu teenused päevapõhiselt (summeerime)
      CURSOR c_comc_sum IS
         SELECT Sum(comc.eek_amt)
         FROM common_monthly_charges comc
            , invoices invo

         WHERE invo.maac_ref_num = p_maac_ref_num
           AND invo.billing_inv = 'Y'
           AND invo.period_start BETWEEN p_period_start AND p_period_end
           AND comc.invo_ref_num = invo.ref_num
           AND (comc.susg_ref_num = p_susg_ref_num OR comc.susg_ref_num IS NULL AND p_susg_ref_num IS NULL)
           AND comc.fcit_type_code IN (SELECT type_code
                                       FROM fixed_charge_item_types
                                       WHERE (   sety_ref_num = p_sety_ref_num
                                               OR sety_ref_num IS NULL AND type_code = p_fcit_type_code
                                              )
                                         AND regular_charge = 'Y'
                                         AND once_off = 'N'
                                         AND pro_rata = 'N')
           AND (comc.iadn_ref_num IS NOT NULL  -- PAK komplekti teenustasu (läheb alati lahendustasu sisse)
                OR
                EXISTS (select 1  -- MinuEMT teenustasu päevapõhiselt
                        from invoice_entries inen
                           , fixed_charge_item_types fcit
                           , fixed_charge_item_types fcit_bill
                        where inen.invo_ref_num = invo.ref_num
                          and fcit.type_code = comc.fcit_type_code
                          and fcit.billing_selector = comc.billing_selector
                          and fcit_bill.type_code = fcit.bill_fcit_type_code
                          and inen.fcit_type_code = fcit_bill.type_code
                          and inen.billing_selector = fcit_bill.billing_selector)
               )
           AND comc.num_of_days IS NOT NULL
      ;
      -- Teenuse miinimumkuutasu
      CURSOR c_min_fix_fee IS
         SELECT mose.min_fix_monthly_fee
              , mose.mipo_ref_num
              , mose.mips_ref_num
         FROM mixed_packet_orders mipo
            , mixed_order_services mose
         WHERE mipo.mixed_packet_code = p_mixed_packet_code
           AND mipo.ebs_order_number = p_ebs_order_number
           AND mose.mipo_ref_num = mipo.ref_num
           AND mose.sety_ref_num = p_sety_ref_num
      ; 
      --
      CURSOR c_mips_dico (p_mips_ref_num  NUMBER) IS
         SELECT monthly_disc_rate, monthly_markdown
         FROM mixed_packet_services
         WHERE ref_num = p_mips_ref_num
      ;
      --
      CURSOR c_bise_fcit IS
         SELECT monthly_billing_selector
              , monthly_fcit_type_code
         FROM mixed_packets
         WHERE packet_code = p_mixed_packet_code
      ;
      -- MOBET-22
      CURSOR c_fcit IS
         SELECT *
         FROM fixed_charge_item_types
         WHERE type_code = p_fcit_type_code
      ;
      --
      l_invoiced_sum            NUMBER;
      l_inen_sum                NUMBER;
      l_comc_max                NUMBER;
      l_comc_sum                NUMBER;
      l_sum_to_invoice          NUMBER;
      l_max_sum_to_invoice      NUMBER;
      l_min_fix_fee             NUMBER;
      l_disc_rate               NUMBER;
      l_disc_amount             NUMBER;
      l_discount                NUMBER;
      l_monthly_fee             NUMBER;
      l_num_days                NUMBER;
      l_serv_discount_exists    BOOLEAN;  -- MOBET-22
      l_serv_disc_amount        NUMBER;   -- MOBET-22
      l_mipo_ref_num            mixed_packet_orders.ref_num%TYPE;
      l_mips_ref_num            mixed_packet_services.ref_num%TYPE;
      l_monthly_bise            mixed_packets.monthly_billing_selector%TYPE;
      l_monthly_fcit            mixed_packets.monthly_fcit_type_code%TYPE;
      l_discount_type           fixed_charge_types.discount_type%TYPE;   -- MOBET-22
      l_error_text              VARCHAR2(1000);                          -- MOBET-22
      l_success                 BOOLEAN;                                 -- MOBET-22
      l_inen_rec                invoice_entries%ROWTYPE;
      l_fcit_rec                fixed_charge_item_types%ROWTYPE; -- MOBET-22
   BEGIN
      -- MOBET-22
      l_serv_discount_exists := FALSE;
      
      /*
        ** Leiame perioodi (vahe)arvetele kantud teenuse kuutasude summa.
        ** Arvele läheb leitud max hinna ja juba arvetele kantud summa vahe, kui see on > 0.
        ** Kui max hind on juba perioodi arvetele kantud, siis siin enam ei kanta.
      */
      OPEN  c_inen;
      FETCH c_inen INTO l_inen_sum;
      CLOSE c_inen;
      --
      l_invoiced_sum := Nvl(l_inen_sum, 0);
      
      
      -- Leiame teenuse miinimumkuutasu
      OPEN  c_min_fix_fee;
      FETCH c_min_fix_fee INTO l_min_fix_fee
                             , l_mipo_ref_num
                             , l_mips_ref_num;
      CLOSE c_min_fix_fee;
      --
      l_min_fix_fee := Nvl(l_min_fix_fee, 0);
      
      /*
        ** CHG-6386: Testperioodis tagastatud PAK müügi puhul ei kehti komplektis olev fikseeritud kuutasu
      */
      IF p_test_period_sept_type = 'MBB' AND p_newmob_order = 'N' THEN
         -- 
         l_min_fix_fee := 0;
         --
      END IF;

      
      
      --DOBAS-158 IF l_invoiced_sum < Greatest(p_monthly_price, l_min_fix_fee) THEN
      IF l_invoiced_sum < p_monthly_price THEN
         /*
           ** Kui arvel olev teenuse kuutasu puudub või on väiksem täiskuutasust, siis vaatame
           ** common_monthly_charges tabelis olevaid teenuse kuutasusid, mis sisalduvad lahendustasus.
           ** Leiame, kas lahendustasu sees on täiskuutasu.
         */
         OPEN  c_comc_max;
         FETCH c_comc_max INTO l_comc_max;
         CLOSE c_comc_max;
         --
         l_invoiced_sum := l_invoiced_sum + Nvl(l_comc_max, 0);
         
         --DOBAS-158 IF l_invoiced_sum < Greatest(p_monthly_price, l_min_fix_fee) THEN
         IF l_invoiced_sum < p_monthly_price THEN
            /*
              ** Kui arvel olevad teenuse kuutasud ja COMC tabelis olevad täiskuutasud ei anna kokku
              ** viimati kehtinud täiskuutasu, siis vaatame ka päevapõhiseid hindu COMC tabelis.
            */
            OPEN  c_comc_sum;
            FETCH c_comc_sum INTO l_comc_sum;
            CLOSE c_comc_sum;
            --
            l_invoiced_sum := l_invoiced_sum + Nvl(l_comc_sum, 0);
            
            --DOBAS-158 IF l_invoiced_sum < Greatest(p_monthly_price, l_min_fix_fee) THEN
            IF l_invoiced_sum < p_monthly_price THEN
      
               /*
                 ** Arveldame puuduoleva osa teenuse kuutasust.
                 ** TEENUSE MIINIMUMKUUTASU ?!?
                 ** p_price - soodustus -> Arveldamata osa
                 ** ARVELDATUD OSA + ARVELDAMATA osa võrrelda vastu miinimumkuutasu
                 **  - kui summa > miinimumist, siis läheb arvele
                 **  - summa < miinimumist, leiame miinimumi ja arveldatud osa vahe ning kanname arvele 
                 **     (miinimumkuutasu paneme fixed_charge_value välja?)
                 
                 euref-194 14.09.2017 Enam ei arvestata min kuutasu !
               */
               
                    -- Leiame teenuse soodustuse (viimase kehtiva teenus+pakett vahemikus).
                  OPEN  c_mips_dico(l_mips_ref_num);
                  FETCH c_mips_dico INTO l_disc_rate
                                       , l_disc_amount;
                  CLOSE c_mips_dico;
               
                  -- Leiame soodustuse
                  IF l_disc_rate > 0 THEN
                     --
                     l_discount := Round( (p_monthly_price * l_disc_rate)/100, 2);
                     --
                  ELSIF l_disc_amount IS NOT NULL THEN  -- MOBE-221: l_disc_amount > 0 -> IS NOT NULL (markup)
                     IF l_disc_amount > p_monthly_price THEN
                        l_discount := p_monthly_price;
                     ELSE
                        l_discount := l_disc_amount;
                     END IF;
                  END IF;
                  --
                      
               /*
                 ** Kui eksisteerib miinimumkuutasu, siis võrdleme seda vastu soodustusega kuutasu
                 ** Leiame päevapõhise hinna neist kahest suurimast.
               */
--               l_monthly_fee := Greatest( (p_monthly_price - Nvl(l_discount, 0)), Nvl(l_min_fix_fee, 0) );
               l_monthly_fee := p_monthly_price - Nvl(l_discount, 0);
               --
               l_num_days := To_Number(To_Char(Last_Day (p_period_end), 'DD'));
               
               
               -- Leiame maksimaalse puuduoleva osa kuutasust
               l_max_sum_to_invoice := Greatest((l_monthly_fee - l_invoiced_sum), 0);
               
               -- Teenuse päevapõhine hind soodustusega
               l_sum_to_invoice := Round( ((l_monthly_fee / l_num_days) * p_num_of_days), 2);
               
               -- Teenuse hind ei tohi ületada maksimaalset arveldatavad osa
               IF l_sum_to_invoice > l_max_sum_to_invoice THEN
                  l_sum_to_invoice := l_max_sum_to_invoice;
               END IF;
               
               
               /*
                 ** Kanname teenuse kuutasu tabelisse common_monthly_charges
               */
               IF l_sum_to_invoice > 0 THEN
                  /*
                    ** Leiame lahendustasu FCIT kirje
                  */
                  OPEN  c_bise_fcit;
                  FETCH c_bise_fcit INTO l_monthly_bise
                                       , l_monthly_fcit;
                  CLOSE c_bise_fcit;
                  --
                  l_inen_rec.invo_ref_num       := p_invo_ref_num;
                  l_inen_rec.acc_amount         := l_sum_to_invoice;
                  l_inen_rec.rounding_indicator := 'N';
                  l_inen_rec.under_dispute      := 'N';
                  l_inen_rec.billing_selector   := p_billing_selector;
                  l_inen_rec.fcit_type_code     := p_fcit_type_code;
                  l_inen_rec.taty_type_code     := p_taty_type_code;
                  l_inen_rec.manual_entry       := 'N';
                  l_inen_rec.module_ref         := c_module_ref_short;
                  l_inen_rec.susg_ref_num       := p_susg_ref_num;
                  l_inen_rec.num_of_days        := p_num_of_days;
                  l_inen_rec.pri_curr_code      := get_pri_curr_code();
                  l_inen_rec.vmct_type_code     := l_monthly_bise;
                  l_inen_rec.fcdt_type_code     := l_monthly_fcit;
                  l_inen_rec.iadn_ref_num       := l_mipo_ref_num;
                  l_inen_rec.fixed_charge_value := p_monthly_price;
                  --
                  iCalculate_Fixed_Charges.ins_common_monthly_charges (l_inen_rec);
                  --
               END IF;

               -- MOBET-107 
               IF l_sum_to_invoice > 0  and nvl(l_discount,0) = 0  THEN
            
                  --  ** MOBET-22/107: Leiame teenuse kuutasu soodustuse                 
                  
                  OPEN  c_fcit;
                  FETCH c_fcit INTO l_fcit_rec;
                  CLOSE c_fcit;
                  -- 
                  l_discount_type := iCalculate_Discounts.find_discount_type(l_fcit_rec.pro_rata
                                                                           ,l_fcit_rec.regular_charge                                                                         ,l_fcit_rec.once_off
                                                                           );
                  --
                  iCalculate_Discounts.find_oo_conn_discounts(l_discount_type
                                                            ,p_invo_ref_num
                                                            ,p_fcit_type_code
                                                            ,p_billing_selector
                                                            ,p_sepv_ref_num 
                                                            ,p_sept_type_code
                                                            ,NVL (l_sum_to_invoice, 0)   -- CHG-3984: replace l_max_price
                                                            ,p_susg_ref_num
                                                            ,p_maac_ref_num
                                                            ,p_period_end   -- CHG-3984: replaced SYSDATE --p_date
                                                            ,'INS'   --p_mode
                                                            ,l_error_text
                                                            ,l_success
                                                            ,l_serv_discount_exists
                                                            ,l_serv_disc_amount
                                                            ,p_price   -- CHG-4079
                                                            ,p_interim   -- CHG-3360
                                                             );
               END IF;
              -- End MOBET-22/107 
            
            
            END IF;
            --
         END IF;
         --
      END IF;

   END create_nonker_serv_fee_comc;

   /***************************************************************************
   **
   **   Procedure Name :  Calc_Mob_NonKER_Serv_Fee
   **
   **   Description : Protseduur leiab ette antud teenus+pakett vahemikega kattuvad
   **                 mobiili AC vahemikud ning iga vahemiku kohta kehtinud max hinna.
   **
   ****************************************************************************/
   PROCEDURE calc_mob_nonker_serv_fee (
      p_susg_ref_num          IN      subs_serv_groups.ref_num%TYPE
     ,p_sety_ref_num          IN      service_types.ref_num%TYPE
     ,p_sept_type_code        IN      serv_package_types.type_code%TYPE
     ,p_category              IN      serv_package_types.CATEGORY%TYPE
     ,p_charge_prorata        IN      VARCHAR2 -- CHG-5762
     ,p_serv_start_date       IN      DATE
     ,p_serv_end_date         IN      DATE
     ,p_period_start_date     IN      DATE
     ,p_period_end_date       IN      DATE
     ,p_ac_start_date_tab     IN OUT  t_date
     ,p_ac_end_date_tab       IN OUT  t_date
     ,p_skip_susg             IN OUT  BOOLEAN
     ,p_new_susg              IN OUT  BOOLEAN
     ,p_max_price             IN OUT  NUMBER
     ,p_taty_type_code        IN OUT  tax_types.tax_type_code%TYPE
     ,p_billing_selector      IN OUT  billing_selectors_v.type_code%TYPE
     ,p_fcit_type_code        IN OUT  fixed_charge_item_types.type_code%TYPE
     ,p_priced_sepv_ref_num   IN OUT  subs_service_parameters.sepv_ref_num%TYPE   -- CHG-3908 / CHG-4535 added 'IN'
     ,p_num_of_days              OUT  NUMBER  -- CHG-5762
     ,p_monthly_price         IN OUT  NUMBER  -- CHG-5762
     ,p_test_period_sept_type IN      mixed_packet_orders.sept_category_type%TYPE -- CHG-6386
     ,p_newmob_order          IN      mixed_packet_orders.newmob_order%TYPE       -- CHG-6386
     ,p_prev_sepv_ref_num     IN      subs_service_parameters.sepv_ref_num%TYPE   -- CHG-6386

   ) IS
      --
      CURSOR c_ssst IS
         SELECT   GREATEST (start_date, p_period_start_date) start_date
                 ,LEAST (NVL (end_date, p_period_end_date), p_period_end_date) end_date
             FROM ssg_statuses
            WHERE susg_ref_num = p_susg_ref_num
              AND status_code = 'AC'
              AND start_date <= p_period_end_date
              AND NVL (end_date, p_period_start_date) >= p_period_start_date
         ORDER BY start_date;

      --
      l_idx                         NUMBER;
      l_price                       NUMBER;
      l_prev_price                  NUMBER;  -- CHG-6386
      l_num_of_days                 NUMBER;  -- CHG-5762
      l_monthly_price               NUMBER;  -- CHG-5762
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_charge_parameter            fixed_charge_item_types.valid_charge_parameter%TYPE;   -- CHG-3704
      l_first_prorated              BOOLEAN;   -- CHG-3704
      l_priced_sepv_ref_num         subs_service_parameters.sepv_ref_num%TYPE;   -- CHG-4467
   BEGIN
      IF p_new_susg THEN
         /*
           ** Töödeldava SUSG-i vahetus - leiame uue mobiili AC perioodid.
         */
         p_ac_start_date_tab.DELETE;
         p_ac_end_date_tab.DELETE;

         --
         OPEN c_ssst;

         FETCH c_ssst
         BULK COLLECT INTO p_ac_start_date_tab
               ,p_ac_end_date_tab;

         CLOSE c_ssst;

         /*
           ** Kui mobiil pole vaadeldavas perioodis üldse AC olnud, siis seda mobiili nende teenuste osas
           ** vaadelda pole vaja.
         */
         IF NOT p_ac_start_date_tab.EXISTS (1) THEN
            p_skip_susg := TRUE;
         END IF;

         --
         p_new_susg := FALSE;
      END IF;

      --

      /*
        ** CHG-3946: Teenuse hinnastamine toimub teenuse enda perioodide järgi, mitte enam AC järgi.
      */
      p_ac_start_date_tab.DELETE;
      p_ac_end_date_tab.DELETE;
      --
      p_ac_start_date_tab (1) := p_serv_start_date;
      p_ac_end_date_tab (1) := p_serv_end_date;

      /*
        ** CHG-3946: Ei hinnastata neid teenuseid/mobiile, mis on suletud arveldusperioodi esimesel
        ** kuupäeval enne ettenähtud kella-aega.
      */
      IF     NOT p_skip_susg
         AND p_serv_end_date >=   TRUNC (p_serv_end_date, 'MM')
                                + 1 / 24 * TO_NUMBER (get_system_parameter (624))   -- CHG-3946
                                                                                 THEN
         /*
           ** Kontrollime, kas ette antud hindamisele kuuluvas perioodis (teenus+pakett kombinatsioon)
           ** on mobiil olnud AC. Leiame iga perioodi kohta (teenus+pakett+AC) max hinna.
         */
         l_idx := p_ac_start_date_tab.FIRST;

         WHILE l_idx IS NOT NULL LOOP
            IF p_ac_start_date_tab (l_idx) <= p_serv_end_date AND p_ac_end_date_tab (l_idx) >= p_serv_start_date THEN
               get_period_max_price (p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                    ,p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                    ,GREATEST (p_serv_start_date, p_ac_start_date_tab (l_idx))   -- IN     DATE
                                    ,LEAST (p_serv_end_date, p_ac_end_date_tab (l_idx))   -- IN     DATE
                                    ,p_sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                    ,p_category   -- IN     serv_package_types.category%TYPE
                                    ,p_charge_prorata      -- IN      VARCHAR2 -- CHG-5762
                                    ,l_price   --    OUT NUMBER
                                    ,l_taty_type_code   --    OUT tax_types.tax_type_code%TYPE
                                    ,l_billing_selector   --    OUT billing_selectors_v.type_code%TYPE
                                    ,l_fcit_type_code   --    OUT fixed_charge_item_types.type_code%TYPE
                                    ,l_charge_parameter   -- CHG-3704
                                    ,l_first_prorated   -- CHG-3704
                                    ,l_priced_sepv_ref_num   -- CHG-4467 p_priced_sepv_ref_num -- CHG-3908
                                    ,l_num_of_days    -- CHG-5762  OUT
                                    ,l_monthly_price  -- CHG-5762  OUT
                                    ,p_test_period_sept_type -- CHG-6386
                                    ,p_newmob_order          -- CHG-6386
                                    );
                                    
               /*
                 ** CHG-6386: ERIJUHTUM: Kui on tegemist MBB ja newmob_order = N, 
                 **           siis antakse ka kaasa viimane kehtinud maksustamisparameetri väärtus enne testperioodiga PAK-i.
                 **           Antud juhul võrreldakse ka 4G parameetri päevapõhist hinda ning eelneva parameetriga kehtinud hinda.
                 **           Leitud hindadest tagastatakse väiksem hind ( > 0).
               */
               IF p_test_period_sept_type = 'MBB' AND
                  p_newmob_order = 'N' AND
                  p_prev_sepv_ref_num IS NOT NULL 
               THEN
                 --
                  l_prev_price := NULL;
                  --
                  get_period_max_price (p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                       ,p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                       ,GREATEST (p_serv_start_date, p_ac_start_date_tab (l_idx))   -- IN     DATE
                                       ,LEAST (p_serv_end_date, p_ac_end_date_tab (l_idx))   -- IN     DATE
                                       ,p_sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                       ,p_category   -- IN     serv_package_types.category%TYPE
                                       ,p_charge_prorata      -- IN      VARCHAR2 -- CHG-5762
                                       ,l_prev_price   --    OUT NUMBER
                                       ,l_taty_type_code   --    OUT tax_types.tax_type_code%TYPE
                                       ,l_billing_selector   --    OUT billing_selectors_v.type_code%TYPE
                                       ,l_fcit_type_code   --    OUT fixed_charge_item_types.type_code%TYPE
                                       ,l_charge_parameter   -- CHG-3704
                                       ,l_first_prorated   -- CHG-3704
                                       ,l_priced_sepv_ref_num   -- CHG-4467 p_priced_sepv_ref_num -- CHG-3908
                                       ,l_num_of_days    -- CHG-5762  OUT
                                       ,l_monthly_price  -- CHG-5762  OUT
                                       ,p_test_period_sept_type
                                       ,p_newmob_order
                                       ,p_prev_sepv_ref_num
                                       );
                  --
                  IF l_price > 0 AND l_prev_price > 0 THEN
                     l_price := Least(l_price, l_prev_price);
                  ELSIF Nvl(l_price, 0) = 0 AND l_prev_price > 0 THEN
                     l_price := l_prev_price;
                  END IF;
                  --
               END IF; -- End CHG-6386


               /*
                 ** CHG-3704: Paketivahetusel hindamisele kuuluvas perioodis leitakse hinnad kõikidele
                 ** teenus+pakett kombinatsioonidele. Toimub hinna asendamine vastavalt määratud määrangule.
                 ** Kui määrangud on määramata, leitakse perioodil kehtinud maksimaalne hind.
               */
               IF l_charge_parameter = 'FIRST' THEN
                  IF p_max_price IS NULL THEN
                     p_max_price := l_price;
                     p_taty_type_code := l_taty_type_code;
                     p_billing_selector := l_billing_selector;
                     p_fcit_type_code := l_fcit_type_code;
                     p_priced_sepv_ref_num := l_priced_sepv_ref_num;   -- CHG-4467
                     p_num_of_days := l_num_of_days;     -- CHG-5762
                     p_monthly_price := l_monthly_price; -- CHG-5762
                  END IF;
               ELSIF l_charge_parameter = 'LAST' THEN
                  p_max_price := l_price;
                  p_taty_type_code := l_taty_type_code;
                  p_billing_selector := l_billing_selector;
                  p_fcit_type_code := l_fcit_type_code;
                  p_priced_sepv_ref_num := l_priced_sepv_ref_num;   -- CHG-4467
                  p_num_of_days := l_num_of_days;     -- CHG-5762
                  p_monthly_price := l_monthly_price; -- CHG-5762
               ELSIF l_charge_parameter = 'BIGGEST' THEN
                  IF p_max_price < l_price OR p_max_price IS NULL THEN  -- ETEENUP-146: OR p_max_price IS NULL
                     p_max_price := l_price;
                     p_taty_type_code := l_taty_type_code;
                     p_billing_selector := l_billing_selector;
                     p_fcit_type_code := l_fcit_type_code;
                     p_priced_sepv_ref_num := l_priced_sepv_ref_num;   -- CHG-4467
                     p_num_of_days := l_num_of_days;     -- CHG-5762
                     p_monthly_price := l_monthly_price; -- CHG-5762
                  END IF;
               ELSIF l_charge_parameter = 'SMALLEST' THEN
                  IF p_max_price >= l_price OR p_max_price IS NULL THEN
                     p_max_price := l_price;
                     p_taty_type_code := l_taty_type_code;
                     p_billing_selector := l_billing_selector;
                     p_fcit_type_code := l_fcit_type_code;
                     p_priced_sepv_ref_num := l_priced_sepv_ref_num;   -- CHG-4467
                     p_num_of_days := l_num_of_days;     -- CHG-5762
                     p_monthly_price := l_monthly_price; -- CHG-5762
                  END IF;
               ELSE
                  IF NVL (l_price, 0) > NVL (p_max_price, 0) OR p_max_price IS NULL THEN -- ETEENUP-132: OR p_max_price IS NULL
                     p_max_price := l_price;
                     p_taty_type_code := l_taty_type_code;
                     p_billing_selector := l_billing_selector;
                     p_fcit_type_code := l_fcit_type_code;
                     p_priced_sepv_ref_num := l_priced_sepv_ref_num;   -- CHG-4467
                     p_num_of_days := l_num_of_days;     -- CHG-5762
                     p_monthly_price := l_monthly_price; -- CHG-5762
                  END IF;
               END IF;
            --
            END IF;

            --
            IF p_ac_start_date_tab (l_idx) > p_serv_end_date THEN
               /*
                 ** Teenus+pakett vahemikust juba üle loetud - v?ib katkestada.
               */
               EXIT;
            END IF;

            --
            l_idx := p_ac_start_date_tab.NEXT (l_idx);
         END LOOP;
      END IF;
   END calc_mob_nonker_serv_fee;

   /***************************************************************************
   **
   **   Procedure Name :  Proc_One_MAAC_NonKER_Serv_Fees
   **
   **   Description : Protseduur kannab ette antud masteri päevade arvust s?ltumatud
   **                 teenuse kuutasud arvele ja salvestab muudatused.
   **                 Muudatuste salvestamine/tagasi v?tmine toimub masteri kaupa.
   **
   ****************************************************************************/
   PROCEDURE proc_one_maac_nonker_serv_fees (
      p_maac_ref_num         IN      accounts.ref_num%TYPE
     ,p_period_start         IN      DATE
     ,p_period_end           IN      DATE
     ,p_susg_ref_num_tab     IN      t_ref_num
     ,p_sety_ref_num_tab     IN      t_ref_num
     ,p_sept_type_tab        IN      t_char4
     ,p_start_date_tab       IN      t_date
     ,p_end_date_tab         IN      t_date
     ,p_category_tab         IN      t_char1
     ,p_mixed_packet_tab     IN      t_char6   -- CHG-5762
     ,p_ebs_order_number_tab IN      t_number  -- CHG-5762
     ,p_prorata_tab          IN      t_char1   -- CHG-5762
     ,p_success              OUT     BOOLEAN
     ,p_error_text           OUT     VARCHAR2
     ,p_invo_ref_num         IN      invoices.ref_num%TYPE DEFAULT NULL   -- vahearvete, vahesaldode korral on arve ref teada
     ,p_interim              IN      BOOLEAN DEFAULT FALSE
   ) IS
      -- CHG-3714
      CURSOR c_fcit (
         p_fcit_type_code  fixed_charge_item_types.type_code%TYPE
      ) IS
         SELECT *
           FROM fixed_charge_item_types
          WHERE type_code = p_fcit_type_code;

      --
      l_idx                         NUMBER;
      l_last_susg_ref_num           subs_serv_groups.ref_num%TYPE;
      l_last_sety_ref_num           service_types.ref_num%TYPE;
      l_last_mixed_packet_code      mixed_packet_orders.mixed_packet_code%TYPE; -- CHG-5762
      l_ebs_order_number            mixed_packet_orders.ebs_order_number%TYPE;  -- CHG-5762
      l_last_sept_type_code         serv_package_types.type_code%TYPE;          -- MOBET-22
      l_charge_prorata              VARCHAR2(1); -- CHG-5762
      l_stpe_start_date             DATE;  -- CHG-5762
      l_stpe_end_date               DATE;  -- CHG-5762
      l_max_price                   NUMBER;
      l_invoice_price               NUMBER;   -- CHG-3984
      l_num_of_days                 NUMBER;   -- CHG-5762
      l_monthly_price               NUMBER;   -- CHG-5762
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_inen_tab                    icalculate_fixed_charges.t_inen;
      l_invo_rec                    invoices%ROWTYPE;   -- CHG-3908
      l_invo_ref_num                invoices.ref_num%TYPE;   -- CHG-3714
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;   -- CHG-3714
      l_priced_sepv_ref_num         subs_service_parameters.sepv_ref_num%TYPE;   -- CHG-3908
      l_discount_type               fixed_charge_types.discount_type%TYPE;   -- CHG-3908
      l_error_text                  VARCHAR2 (500);   -- CHG-3908
      l_success                     BOOLEAN;   -- CHG-3908
      l_skip_susg                   BOOLEAN;
      l_new_susg                    BOOLEAN;
      l_ac_start_date_tab           t_date;
      l_ac_end_date_tab             t_date;
      l_test_period_sept_type       mixed_packet_orders.sept_category_type%TYPE;  -- CHG-6386
      l_newmob_order                mixed_packet_orders.newmob_order%TYPE;        -- CHG-6386
      l_prev_sepv_ref_num           service_param_values.ref_num%TYPE;            -- CHG-6386
      --
      e_processing                  EXCEPTION;
   BEGIN
      l_idx := p_susg_ref_num_tab.FIRST;

      --
      WHILE l_idx IS NOT NULL LOOP
         /*
           ** Iga mobiil+teenus kombinatsiooni jaoks kantakse arvele max hind perioodis.
           ** Teenuse vahetusel leiame uue max hinna.
         */
         IF    p_susg_ref_num_tab (l_idx) <> NVL (l_last_susg_ref_num, -1)
            OR p_sety_ref_num_tab (l_idx) <> NVL (l_last_sety_ref_num, -1) 
            OR Nvl(p_mixed_packet_tab (l_idx), '*') <> Nvl(l_last_mixed_packet_code, '*') -- CHG-5762
            -- CHG-6319: Garantii korras seadme vahetusel tekib uus EBS number
            OR p_susg_ref_num_tab (l_idx) = l_last_susg_ref_num AND
               p_sety_ref_num_tab (l_idx) = l_last_sety_ref_num AND
               p_mixed_packet_tab (l_idx) = l_last_mixed_packet_code AND
               p_ebs_order_number_tab (l_idx) <> l_ebs_order_number
         THEN
            /*
              ** Eelnevalt töödeldud teenuse andmed tuleks arvereale kanda, kui summa > 0.
            */
            IF l_last_susg_ref_num IS NOT NULL AND 
               l_last_sety_ref_num IS NOT NULL AND 
               (l_max_price > 0 OR Nvl(l_max_price, 0) = 0 AND l_last_mixed_packet_code IS NOT NULL) -- ETEENUP-132            
            THEN
               --
               IF l_last_mixed_packet_code IS NOT NULL THEN -- CHG-5762
                  --  Leida või avada invoice
                  IF p_invo_ref_num IS NOT NULL THEN
                     l_invo_ref_num := p_invo_ref_num;
                  ELSIF l_invo_ref_num IS NULL THEN
                     get_invoice (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                 ,p_period_start   -- IN     DATE
                                 ,l_success   --    OUT BOOLEAN
                                 ,l_error_text   --    OUT VARCHAR2
                                 ,l_invo_rec   --    OUT invoices%ROWTYPE
                                 );
                     --
                     l_invo_ref_num := l_invo_rec.ref_num;
                  END IF;
                  /*
                    ** Lisame kirje COMMON_MONTHLY_CHARGES tabelisse
                  */
                  --
                  create_nonker_serv_fee_comc (l_invo_ref_num      --IN      invoices.re
                                              ,p_maac_ref_num      --IN      accounts.ref
                                              ,l_last_susg_ref_num --IN      subs_ser
                                              ,l_last_sety_ref_num --IN      service_type
                                              ,l_last_mixed_packet_code --IN      mixed_p
                                              ,l_ebs_order_number  --IN      mixed_packe
                                              ,l_stpe_start_date   --IN      DATE
                                              ,l_stpe_end_date     --IN      DATE
                                              ,p_period_start      --IN      DATE
                                              ,p_period_end        --IN      DATE
                                              ,l_fcit_type_code    --IN      fixed_charge
                                              ,l_taty_type_code    --IN      fixed_charge
                                              ,l_billing_selector  --IN      fixed_charge
                                              ,Nvl(l_max_price, 0) --IN      NUMBER
                                              ,l_num_of_days       --IN      NUMBER  
                                              ,Nvl(l_monthly_price, 0)  --IN      NUMBER
                                              ,l_priced_sepv_ref_num    --IN   MOBET-22/107
                                              ,p_sept_type_tab (l_idx)  --IN   MOBET-22/107
                                              ,p_interim                --IN   MOBET-22/107
                                              ,l_test_period_sept_type  -- CHG-6386
                                              ,l_newmob_order           -- CHG-6386
                  );
                  --
               ELSIF l_max_price > 0 THEN
                  --            
                  create_nonker_serv_fee_inen (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                              ,l_last_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                              ,l_last_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                              ,p_period_start   -- IN     DATE
                                              ,p_period_end   -- IN     DATE
                                              ,l_fcit_type_code   -- IN     fixed_charge_item_types.type_code%TYPE
                                              ,l_taty_type_code   -- IN     fixed_charge_item_types.taty_type_code%TYPE
                                              ,l_billing_selector   -- IN     fixed_charge_item_types.billing_selector%TYPE
                                              ,l_max_price   -- IN     NUMBER
                                              ,l_inen_tab   -- IN OUT Calculate_Fixed_Charges.t_inen
                                              ,l_invoice_price   -- CHG-3984
                                              ,l_num_of_days     -- CHG-5762
                                              ,l_charge_prorata  -- CHG-5762
                                              ,NULL              -- CHG-13641
                                              ,p_interim         -- CHG-13641
                                              );

                  -- CHG-3946
                  OPEN c_fcit (l_fcit_type_code);
                  FETCH c_fcit INTO l_fcit_rec;
                  CLOSE c_fcit;

                  /*
                    ** CHG-3908: Leiame, kas teenuse kuutasule kehtib soodustus
                  */
                  l_discount_type := NULL;
                  --
                  l_discount_type := icalculate_discounts.find_discount_type (l_fcit_rec.pro_rata
                                                                            ,l_fcit_rec.regular_charge
                                                                            ,l_fcit_rec.once_off
                                                                            );

                  -- Leida või avada invoice soodustuse mahakirjutamiseks
                  IF p_invo_ref_num IS NOT NULL THEN
                     l_invo_ref_num := p_invo_ref_num;
                  ELSIF l_invo_ref_num IS NULL THEN
                     get_invoice (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                 ,p_period_start   -- IN     DATE
                                 ,l_success   --    OUT BOOLEAN
                                 ,l_error_text   --    OUT VARCHAR2
                                 ,l_invo_rec   --    OUT invoices%ROWTYPE
                                 );
                     --
                     l_invo_ref_num := l_invo_rec.ref_num;
                  END IF;

                  --
                  icalculate_discounts.find_oo_conn_discounts (l_discount_type
                                                             ,l_invo_ref_num
                                                             ,l_fcit_type_code
                                                             ,l_billing_selector
                                                             ,l_priced_sepv_ref_num   --p_sepv_ref_num
                                                             ,p_sept_type_tab (l_idx)   --p_sept_type_code
                                                             ,NVL (l_invoice_price, 0)   -- CHG-3984: replace l_max_price
                                                             ,l_last_susg_ref_num
                                                             ,p_maac_ref_num
                                                             ,p_period_end   -- CHG-3984: replaced SYSDATE --p_date
                                                             ,'INS'   --p_mode
                                                             ,l_error_text
                                                             ,l_success
                                                             ,l_max_price   -- CHG-4079
                                                             ,p_interim   -- CHG-3360
                                                             );
               /* End CHG-3908 */
               END IF; -- CHG-5762
               --
            END IF;

            --
            /*
              ** CHG-3704: Asendatud 0 NULL-iga, et teenus+pakett kombinatsioonile hinna leidmisel oleks
              ** võimalik kindlaks teha, kas on tegemist esimese (FIRST) määranguga hinna leidmisega.
            */
            l_max_price := NULL;   -- CHG-3704: Replaced 0 with NULL;
            l_taty_type_code := NULL;
            l_billing_selector := NULL;
            l_fcit_type_code := NULL;
            l_priced_sepv_ref_num := NULL;   -- CHG-3908 / CHG-4535 moved here
            l_num_of_days := NULL;   -- CHG-5762
            l_monthly_price := NULL; -- CHG-5762
            --
         END IF;

         --
         IF p_susg_ref_num_tab (l_idx) <> NVL (l_last_susg_ref_num, -1) THEN
            /*
              ** Loeme välja uue SUSG-i arveldusperioodi sisse jäävad AC perioodid ja
              ** kustutame eelmisena töödeldud SUSG-i andmed.
            */
            l_skip_susg := FALSE;
            l_new_susg := TRUE;
         END IF;

         --
         l_test_period_sept_type := NULL;  -- CHG-6386
         l_newmob_order          := NULL;  -- CHG-6386
         l_prev_sepv_ref_num     := NULL;  -- CHG-6386
         --
         IF NOT l_skip_susg THEN
            /*
              ** CHG-6386: Leiame, kas on tegemist PAK müügi tagastusega testperioodis
            */
            IF p_ebs_order_number_tab (l_idx) IS NOT NULL AND
               get_service_name_from_sety_ref(p_sety_ref_num_tab (l_idx)) = 'CHGGP'
            THEN
               -- Leiame GPRS teenuse puhul, kas tegemist testperioods tagastamisega, newmob_order ja sept_category_type
               Get_Test_Period_Data (p_ebs_order_number_tab (l_idx) --IN      mixed_packet_orders.ebs_order_number%TYPE
                                    ,p_susg_ref_num_tab (l_idx)     --IN      subs_serv_groups.ref_num%TYPE
                                    ,p_period_start                 --IN      DATE
                                    ,p_period_end                   --IN      DATE
                                    ,l_test_period_sept_type        --   OUT  mixed_packet_orders.sept_category_type%TYPE
                                    ,l_newmob_order                 --   OUT  mixed_packet_orders.newmob_order%TYPE
                                    ,l_prev_sepv_ref_num            --   OUT  subs_service_parameters.sepv_ref_num%TYPE
                                    );
               --
            END IF;

            --
            calc_mob_nonker_serv_fee (p_susg_ref_num_tab (l_idx)   -- IN     subs_serv_groups.ref_num%TYPE
                                     ,p_sety_ref_num_tab (l_idx)   -- IN     service_types.ref_num%TYPE
                                     ,p_sept_type_tab (l_idx)   -- IN     serv_package_types.type_code%TYPE
                                     ,p_category_tab (l_idx)   -- IN     serv_package_types.category%TYPE
                                     ,p_prorata_tab (l_idx)    -- IN   CHG-5762
                                     ,p_start_date_tab (l_idx)   -- IN     DATE
                                     ,p_end_date_tab (l_idx)   -- IN     DATE
                                     ,p_period_start   -- IN     DATE
                                     ,p_period_end   -- IN     DATE
                                     ,l_ac_start_date_tab   -- IN OUT t_date
                                     ,l_ac_end_date_tab   -- IN OUT t_date
                                     ,l_skip_susg   -- IN OUT BOOLEAN
                                     ,l_new_susg   -- IN OUT BOOLEAN
                                     ,l_max_price   -- IN OUT NUMBER
                                     ,l_taty_type_code   -- IN OUT tax_types.tax_type_code%TYPE
                                     ,l_billing_selector   -- IN OUT billing_selectors_v.type_code%TYPE
                                     ,l_fcit_type_code   -- IN OUT fixed_charge_item_types.type_code%TYPE
                                     ,l_priced_sepv_ref_num   -- OUT CHG-3908
                                     ,l_num_of_days         -- OUT  NUMBER  CHG-5762
                                     ,l_monthly_price       -- OUT  NUMBER  CHG-5762
                                     ,l_test_period_sept_type  -- CHG-6386
                                     ,l_newmob_order           -- CHG-6386
                                     ,l_prev_sepv_ref_num      -- CHG-6386
                                     );
         END IF;

         --
         l_last_susg_ref_num := p_susg_ref_num_tab (l_idx);
         l_last_sety_ref_num := p_sety_ref_num_tab (l_idx);
         l_last_mixed_packet_code := p_mixed_packet_tab (l_idx);     -- CHG-5762
         l_ebs_order_number       := p_ebs_order_number_tab (l_idx); -- CHG-5762
         l_charge_prorata         := p_prorata_tab (l_idx);          -- CHG-5762
         l_stpe_start_date        := p_start_date_tab (l_idx);       -- CHG-5762
         l_stpe_end_date          := p_end_date_tab (l_idx);         -- CHG-5762
     --    l_last_sept_type_code    := p_sept_type_tab (l_idx);        -- MOBET-22
         l_idx := p_susg_ref_num_tab.NEXT (l_idx);
      END LOOP;

      /*
        ** Nüüd tuleb veel maha kanda viimase teenuse andmed.
        ** Eelnevalt töödeldud teenuse andmed tuleks arvereale kanda, kui summa > 0.
      */
      IF l_last_susg_ref_num IS NOT NULL AND 
         l_last_sety_ref_num IS NOT NULL AND
         (l_max_price > 0 OR Nvl(l_max_price, 0) = 0 AND l_last_mixed_packet_code IS NOT NULL) -- ETEENUP-132
      THEN
         --
         IF l_last_mixed_packet_code IS NOT NULL THEN -- CHG-5762
            --  Leida või avada invoice
            IF p_invo_ref_num IS NOT NULL THEN
               l_invo_ref_num := p_invo_ref_num;
            ELSIF l_invo_ref_num IS NULL THEN
               get_invoice (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                           ,p_period_start   -- IN     DATE
                           ,l_success   --    OUT BOOLEAN
                           ,l_error_text   --    OUT VARCHAR2
                           ,l_invo_rec   --    OUT invoices%ROWTYPE
                           );
               --
               l_invo_ref_num := l_invo_rec.ref_num;
            END IF;
            /*
              ** Lisame kirje COMMON_MONTHLY_CHARGES tabelisse
            */
            create_nonker_serv_fee_comc (l_invo_ref_num      --IN      invoices.re
                                        ,p_maac_ref_num      --IN      accounts.ref
                                        ,l_last_susg_ref_num --IN      subs_ser
                                        ,l_last_sety_ref_num --IN      service_type
                                        ,l_last_mixed_packet_code --IN      mixed_p
                                        ,l_ebs_order_number  --IN      mixed_packe
                                        ,l_stpe_start_date   --IN      DATE
                                        ,l_stpe_end_date     --IN      DATE
                                        ,p_period_start      --IN      DATE
                                        ,p_period_end        --IN      DATE
                                        ,l_fcit_type_code    --IN      fixed_charge
                                        ,l_taty_type_code    --IN      fixed_charge
                                        ,l_billing_selector  --IN      fixed_charge
                                        ,Nvl(l_max_price, 0) --IN      NUMBER
                                        ,l_num_of_days       --IN      NUMBER  
                                        ,Nvl(l_monthly_price, 0)  --IN      NUMBER
                                        ,l_priced_sepv_ref_num    --IN   MOBET-22/107
                                        ,l_last_sept_type_code    --IN   MOBET-22/107
                                        ,p_interim                --IN   MOBET-22/107
                                        ,l_test_period_sept_type  -- CHG-6386
                                        ,l_newmob_order           -- CHG-6386
            );
         ELSIF l_max_price > 0 THEN
            --
            create_nonker_serv_fee_inen (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                        ,l_last_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                        ,l_last_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                        ,p_period_start   -- IN     DATE
                                        ,p_period_end   -- IN     DATE
                                        ,l_fcit_type_code   -- IN     fixed_charge_item_types.type_code%TYPE
                                        ,l_taty_type_code   -- IN     fixed_charge_item_types.taty_type_code%TYPE
                                        ,l_billing_selector   -- IN     fixed_charge_item_types.billing_selector%TYPE
                                        ,l_max_price   -- IN     NUMBER
                                        ,l_inen_tab   -- IN OUT Calculate_Fixed_Charges.t_inen
                                        ,l_invoice_price   -- CHG-3984
                                        ,l_num_of_days  -- IN
                                        ,l_charge_prorata -- CHG-5762
                                        ,NULL              -- CHG-13641
                                        ,p_interim         -- CHG-13641
                                        );

            /*
              ** CHG-4247: Leiame FCIT kirje soodustuse tüübi määramiseks.
            */
            OPEN c_fcit (l_fcit_type_code);
            FETCH c_fcit INTO l_fcit_rec;
            CLOSE c_fcit;

            /*
              ** CHG-3908: Leiame, kas teenuse kuutasule kehtib soodustus
            */
            l_discount_type := icalculate_discounts.find_discount_type (l_fcit_rec.pro_rata
                                                                      ,l_fcit_rec.regular_charge
                                                                      ,l_fcit_rec.once_off
                                                                      );

            -- Leida või avada invoice soodustuse mahakirjutamiseks
            IF p_invo_ref_num IS NOT NULL THEN
               l_invo_ref_num := p_invo_ref_num;
            ELSIF l_invo_ref_num IS NULL THEN
               get_invoice (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                           ,p_period_start   -- IN     DATE
                           ,l_success   --    OUT BOOLEAN
                           ,l_error_text   --    OUT VARCHAR2
                           ,l_invo_rec   --    OUT invoices%ROWTYPE
                           );
               --
               l_invo_ref_num := l_invo_rec.ref_num;
            END IF;

            --
              icalculate_discounts.find_oo_conn_discounts (l_discount_type
                                                       ,l_invo_ref_num
                                                       ,l_fcit_type_code
                                                       ,l_billing_selector
                                                       ,l_priced_sepv_ref_num   --p_sepv_ref_num
                                                       ,NULL   --p_sept_type_tab(l_idx) --p_sept_type_code
                                                       ,NVL (l_invoice_price, 0)   -- CHG-3984: replace l_max_price
                                                       ,l_last_susg_ref_num
                                                       ,p_maac_ref_num
                                                       ,p_period_end   -- CHG-3984: replaced SYSDATE --p_date
                                                       ,'INS'   --p_mode
                                                       ,l_error_text
                                                       ,l_success
                                                       ,l_max_price   -- CHG-4079
                                                       ,p_interim   -- CHG-3360
                                                       );
            /* mobet-22 välja kommenteeritud ja asendatud ülaval oleva väljakutsega
            icalculate_discounts.find_oo_conn_discounts (l_discount_type
                                                       ,l_invo_ref_num
                                                       ,l_fcit_type_code
                                                       ,l_billing_selector
                                                       ,l_priced_sepv_ref_num   --p_sepv_ref_num
                                                       ,l_last_sept_type_code -- MOBET-22: NULL->l_last_sept_type_code |   --p_sept_type_tab(l_idx) --p_sept_type_code
                                                       ,NVL (l_invoice_price, 0)   -- CHG-3984: replace l_max_price
                                                       ,l_last_susg_ref_num
                                                       ,p_maac_ref_num
                                                       ,p_period_end   -- CHG-3984: replaced SYSDATE --p_date
                                                       ,'INS'   --p_mode
                                                       ,l_error_text
                                                       ,l_success
                                                       ,l_max_price   -- CHG-4079
                                                       ,p_interim   -- CHG-3360
                                                       );
                                                       */
         /* End CHG-3908 */
         END IF; -- CHG-5762
         --
      END IF;

      --
      IF l_inen_tab.EXISTS (1) THEN
         /*
           ** CHG-3714: Check for Calculated fees based on Service fees.
           **    Create Calculated fee INENs instead of Service fee INENs.
           **     If p_invo_ref_num IS NULL then get the invoice to write down
           **    service fees to common_monthly_charges that create calculated fees.
         */
         IF p_invo_ref_num IS NOT NULL THEN
            l_invo_ref_num := p_invo_ref_num;
         END IF;

         --
         chk_one_maac_calculated_fees (p_maac_ref_num
                                      ,p_period_start
                                      ,p_period_end
                                      ,l_invo_ref_num
                                      ,l_inen_tab
                                      ,p_interim
                                      );
         --
         invoice_maac_nonker_serv_fees
                     (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                     ,p_period_start   -- IN     DATE
                     ,l_inen_tab   -- IN OUT Calculate_Fixed_Charges.t_inen
                     ,p_success   --    OUT BOOLEAN
                     ,p_error_text   --    OUT VARCHAR2
                     ,l_invo_ref_num   -- IN     invoices.ref_num%TYPE -- vahearvete, vahesaldode korral on arve ref teada
                     ,p_interim   -- IN     BOOLEAN
                     );

         IF NOT p_success THEN
            RAISE e_processing;
         END IF;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
   END proc_one_maac_nonker_serv_fees;

   /***************************************************************************
   **
   **   Procedure Name :  Add_Mixed_Packet_Service_Dates
   **
   **   Description :  Protseduur kontrollib, kas SUSG-il eksisteeris arveldusperioodis PAK
   **                 komplekt ning muudab vajadusel Teenus+Pakett kombinatsioonid ümber
   **                 Teenus+Pakett+Komplekt kombinatsioonideks lisades ette/vahele/taha
   **                 vajalikud perioodid.
   **
   **                  Lisaks täidetakse mälutabelitesse Mixed_Packet_code, eBS_Order_Number
   **                 ning päevapõhise hinnastamise tunnused.
   **
   ****************************************************************************/
   PROCEDURE Add_Mixed_Packet_Service_Dates (p_period_start         IN      DATE
                                            ,p_period_end           IN      DATE                                            
                                            ,p_susg_ref_num_tab     IN OUT  t_ref_num
                                            ,p_sety_ref_num_tab     IN OUT  t_ref_num
                                            ,p_sept_type_tab        IN OUT  t_char4
                                            ,p_start_date_tab       IN OUT  t_date
                                            ,p_end_date_tab         IN OUT  t_date
                                            ,p_category_tab         IN OUT  t_char1
                                            ,p_mixed_packet_tab     IN OUT  t_char6
                                            ,p_ebs_order_number_tab IN OUT  t_number
                                            ,p_prorata_tab          IN OUT  t_char1
                                            ,p_invo_ref_num         IN      NUMBER DEFAULT NULL
                                            ,p_interim              IN      BOOLEAN DEFAULT FALSE
   ) IS
      --
      l_start_date                  DATE;
      l_end_date                    DATE;
      --
      l_prorata_serv_tab            t_ref_num;
      l_minuemt_serv_tab            t_ref_num;
      l_start_date_tab              t_date;
      l_end_date_tab                t_date;
      l_mixed_packet_tab            t_char6;
      l_ebs_order_number_tab        t_number;
      -- 
      l_add_susg_ref_num_tab        t_ref_num;
      l_add_sety_ref_num_tab        t_ref_num;
      l_add_sept_type_tab           t_char4;
      l_add_start_date_tab          t_date;
      l_add_end_date_tab            t_date;
      l_add_category_tab            t_char1;
      l_add_mixed_packet_tab        t_char6;
      l_add_ebs_order_number_tab    t_number;
      l_add_prorata_tab             t_char1;
      --
      l_temp_susg_ref_num_tab       t_ref_num;
      l_temp_sety_ref_num_tab       t_ref_num;
      l_temp_sept_type_tab          t_char4;
      l_temp_start_date_tab         t_date;
      l_temp_end_date_tab           t_date;
      l_temp_category_tab           t_char1;
      l_temp_mixed_packet_tab       t_char6;
      l_temp_ebs_order_number_tab   t_number;
      l_temp_prorata_tab            t_char1;
      --
      l_special_mark           serv_package_types.special_mark%TYPE;
      l_charging_allowed       BOOLEAN;
      l_dummy                  NUMBER;
      l_idx                    NUMBER;
      l_add_idx                NUMBER;
      l_temp_idx               NUMBER;
      l_ftco_idx               NUMBER;
      l_ftco_count             NUMBER;
      l_prev_susg              NUMBER;
      l_mixed_packet           BOOLEAN;
      l_add_orig_end           BOOLEAN;
      l_chg_orig_end           BOOLEAN;
      l_orig_closed            BOOLEAN;
      l_orig_end_start_date    DATE;
      l_original_start_date    DATE;
      l_original_end_date      DATE;
      l_first_orig_period_end  DATE;
      l_prev_ftco_end_date     DATE;
      --
      l_invo_rec               invoices%ROWTYPE;
      
      
      -- Pro-rata teenused (leida kõik teenused tabelis MOSE, mis antud ajaperioodil kehtisid - need kõik päevapõhiseks)
      CURSOR c_serv_prorata (p_susg_ref_num  NUMBER
                            ,p_start_date    DATE
                            ,p_end_date      DATE
      ) IS
         SELECT mose.sety_ref_num
         FROM fixed_term_contracts ftco
            , mixed_packet_orders  mipo
            , mixed_order_services mose
         WHERE ftco.susg_ref_num = p_susg_ref_num
           AND ftco.mixed_packet_code = mipo.mixed_packet_code
           AND ftco.ebs_order_number = mipo.ebs_order_number
           AND mose.mipo_ref_num = mipo.ref_num  
           AND Nvl(mipo.term_request_type, '*') <> 'NULLIFY'
           AND ftco.start_date <= p_end_date
           AND Nvl(ftco.date_closed, ftco.end_date) > p_start_date
      ;
      -- MinuEMT teenused (MEM paketis need kõik päevapõhiseks)
      CURSOR c_serv_minuemt (p_start_date  DATE
                            ,p_end_date    DATE
      ) IS
         SELECT ref_num
         FROM service_types
         WHERE station_param = 'MINU'
           AND station_type = 'TSV'
           AND start_date <= p_end_date
           AND Nvl(end_date, p_end_date) > p_start_date
      ;
      -- Mixed tähtajaliste komplektide lepingu kuupäevad
      CURSOR c_ftco_mixed (p_susg_ref_num  NUMBER) IS
         SELECT start_date
              , (Trunc(Nvl(date_closed, end_date)) + 1 - c_one_second) end_date  -- CHG-13755: Lisatud Trunc() et vältida sama kuupäeva ülekatet
              , mixed_packet_code
              , ebs_order_number
         FROM fixed_term_contracts ftco
         WHERE susg_ref_num = p_susg_ref_num
           AND mixed_packet_code IS NOT NULL
           AND start_date <= p_period_end
           AND Nvl(date_closed, end_date) > p_period_start
           AND NOT EXISTS (select 1
                           from mixed_packet_orders
                           where ebs_order_number = ftco.ebs_order_number
                             and mixed_packet_code = ftco.mixed_packet_code
                             and term_request_type = 'NULLIFY'
                          )
         ORDER BY start_date
      ;
      -- Kontrollime, kas arveldusperioodis on olnud MinuEMT pakett
      CURSOR c_special_mark (p_susg_ref_num  NUMBER
                            ,p_start_date    DATE
                            ,p_end_date      DATE      
      ) IS
         SELECT sept.special_mark
         FROM serv_package_types sept
            , subs_packages      supa
         WHERE sept.special_mark = 'MEM'
           AND sept.type_code = supa.sept_type_code
           AND supa.gsm_susg_ref_num = p_susg_ref_num
           AND Nvl(supa.end_date, p_start_date) >= p_start_date
           AND supa.start_date < p_end_date
      ;
      -- Kas on tegemist VNV vahearvega
      CURSOR c_invo IS
         SELECT *
         FROM invoices
         WHERE ref_num = p_invo_ref_num
          -- AND creation_reason = 'VNV'
      ;
      --
      /*
        ** Functsioon kontrollib, kas antud teenus kuulub komplekti juurde või on MinuEMT-i teenus.
      */
      FUNCTION Chk_Is_ProRata_Service (p_sety_ref_num      NUMBER
                                      ,p_special_mark      VARCHAR2
                                      ,p_prorata_serv_tab  t_ref_num
                                      ,p_minuemt_serv_tab  t_ref_num
      ) RETURN BOOLEAN IS
         l_idx         NUMBER;
         l_is_prorata  BOOLEAN;
      BEGIN
         --
         l_is_prorata := FALSE;
         -- Kas teenus esineb MOSE tabelis?
         l_idx := p_prorata_serv_tab.FIRST;
         WHILE l_idx IS NOT NULL LOOP
            IF p_sety_ref_num = p_prorata_serv_tab(l_idx) THEN
               l_is_prorata := TRUE;
            END IF;
            --
            l_idx := p_prorata_serv_tab.NEXT(l_idx);
         END LOOP;
         -- Kui MEM pakett, siis kas on MinuEMT teenus?
         IF NOT l_is_prorata AND p_special_mark = 'MEM' THEN
            l_idx := p_minuemt_serv_tab.FIRST;
            WHILE l_idx IS NOT NULL LOOP
               IF p_sety_ref_num = p_minuemt_serv_tab(l_idx) THEN
                  l_is_prorata := TRUE;
               END IF;
               --
               l_idx := p_minuemt_serv_tab.NEXT(l_idx);
            END LOOP;
         END IF;
         --
         RETURN l_is_prorata;
      END Chk_Is_ProRata_Service;
   BEGIN
      --
      l_add_idx := 0;
      
      -- Vaatleme komplekti teenuseid ja MinuEMT teenuseid terve arveldusperioodi lõikes
      l_start_date := Trunc(p_period_start, 'MM');
      l_end_date   := Trunc(Last_Day(p_period_end)) + 1 - c_one_second;
      
      
      -- Kui on tegemist vahearvega, siis komplekti olemasolul vahearvele teenuse kuutasusid ei kanta (va VNV puhul).
      -- Arvutama ei minda ka komplekti eelseid/järgseid teenuseid, kui neil eksisteeris arveldusperioodis komplekt.
      l_charging_allowed := TRUE;
      --
      IF p_invo_ref_num IS NOT NULL AND NOT p_interim THEN  -- CHG-5826: NOT p_interim
         --
         OPEN  c_invo;
         FETCH c_invo INTO l_invo_rec;
         CLOSE c_invo;
         --
         IF l_invo_rec.invoice_type = 'INT' AND Nvl(l_invo_rec.creation_reason, '*') <> 'VNV' THEN
            l_charging_allowed := FALSE;
         END IF;
         --
      ELSIF p_interim THEN
         l_charging_allowed := FALSE;
      END IF;

   
      -- 1) MinuEMT teenused pl/sql tabelisse
      OPEN  c_serv_minuemt (l_start_date, l_end_date);
      FETCH c_serv_minuemt BULK COLLECT INTO l_minuemt_serv_tab;
      CLOSE c_serv_minuemt;
      


      
      l_idx := p_susg_ref_num_tab.FIRST;
      --
      WHILE l_idx IS NOT NULL LOOP
         --
         l_original_start_date   := p_start_date_tab(l_idx);
         l_original_end_date     := p_end_date_tab(l_idx);
         l_orig_closed           := FALSE;
         l_first_orig_period_end := NULL;
         
         IF p_susg_ref_num_tab(l_idx) <> Nvl(l_prev_susg, '-1') THEN
            --
            l_mixed_packet := FALSE;
            l_prev_ftco_end_date := NULL;  -- CHG-13755
            --
            OPEN  c_special_mark(p_susg_ref_num_tab(l_idx), l_start_date, l_end_date);
            FETCH c_special_mark INTO l_special_mark;
            CLOSE c_special_mark;
            --
            OPEN  c_serv_prorata(p_susg_ref_num_tab(l_idx), l_start_date, l_end_date);
            FETCH c_serv_prorata BULK COLLECT INTO l_prorata_serv_tab;
            CLOSE c_serv_prorata;
            
            IF l_prorata_serv_tab.FIRST IS NOT NULL THEN
               l_mixed_packet := TRUE;
               -- Leida kõik ajavahemikku jäävad MIXED perioodid
               OPEN  c_ftco_mixed(p_susg_ref_num_tab(l_idx));
               FETCH c_ftco_mixed BULK COLLECT INTO l_start_date_tab
                                                  , l_end_date_tab
                                                  , l_mixed_packet_tab
                                                  , l_ebs_order_number_tab;
               CLOSE c_ftco_mixed;
               --
            END IF;
            --
         END IF;
         --
         l_prev_susg := p_susg_ref_num_tab(l_idx);
         
         
         /*
           ** SUSG-il eksisteeris arveldusperioodis PAK komplekt.
           ** Muudame ringi pl/sql mälutabelid ning lisame juurde vajalikud perioodid.
         */
         IF l_mixed_packet THEN
            --
            
            -- Kontrollida, kas teenus on komplekti oma
            --   - kui JAH, siis lähme kuupäevade kontrolli
            --   - kui ei, siis MEM puhul kontrollime, kas tegu MinuEMT teenusega, kui jah, siis kuupäevade kontrolli
            --   - kui teenus ei kuulu kumbagi kategooriasse, siis ei tee midagi
            IF Chk_Is_ProRata_Service (p_sety_ref_num_tab(l_idx)
                                      ,l_special_mark
                                      ,l_prorata_serv_tab
                                      ,l_minuemt_serv_tab )
            THEN
               --
               IF l_charging_allowed THEN
                  --
                  p_prorata_tab(l_idx) := 'Y'; -- Päevapõhine hinnastamine teenusele
                  l_add_orig_end       := FALSE;
               
               
                  -- Vaatleme teenus+pakett kuupäevi ning võrdleme LOOP-is FTCO kuupäevade vastu
                  --  1) teenuse kuupäevad jäävad FTCO kuupäevade vahele - pole vaja midagi teha
                  --  2) kui tuleb hakata lõikuma perioodi, siis uued kirjed lokaalsesse tabelisse ning protseduuri lõpus 
                  --     vajalikud read vahele panna
                  l_ftco_idx := l_start_date_tab.FIRST;
                  l_ftco_count := 0;
                  --
                  WHILE l_ftco_idx IS NOT NULL LOOP
               
                     -- FTCO algus või lõpp jääb teenus+pakett kuupäevade vahemikku.
                     IF l_start_date_tab(l_ftco_idx) > p_start_date_tab(l_idx) AND l_start_date_tab(l_ftco_idx) < p_end_date_tab(l_idx) OR
                        l_end_date_tab(l_ftco_idx) > p_start_date_tab(l_idx) AND l_end_date_tab(l_ftco_idx) < p_end_date_tab(l_idx)
                     THEN
                        --
                        l_ftco_count := l_ftco_count + 1;
                     
                     
                        -- Kui kahe FTCO vahele jääb lünk, siis panna sinna originaalkirje lõik asemele.
                        IF l_start_date_tab(l_ftco_idx) - l_prev_ftco_end_date > 1 THEN
                           -- Lisada tabelisse FTCO kirje
                           l_add_idx := l_add_idx + 1;
                           --
                           l_add_susg_ref_num_tab(l_add_idx) := p_susg_ref_num_tab(l_idx);
                           l_add_sety_ref_num_tab(l_add_idx) := p_sety_ref_num_tab(l_idx);
                           l_add_sept_type_tab(l_add_idx)    := p_sept_type_tab(l_idx);
                           l_add_start_date_tab(l_add_idx)   := l_prev_ftco_end_date + c_one_second;
                           l_add_end_date_tab(l_add_idx)     := l_start_date_tab(l_ftco_idx) - c_one_second;
                           l_add_category_tab(l_add_idx)     := p_category_tab(l_idx);
                           l_add_mixed_packet_tab(l_add_idx) := NULL;
                           l_add_ebs_order_number_tab(l_add_idx) := NULL;
                           l_add_prorata_tab(l_add_idx)      := 'Y';
                           --
                        END IF;
                     
                        -- 
                        IF l_start_date_tab(l_ftco_idx) > p_start_date_tab(l_idx) THEN
                        
                           IF l_add_orig_end AND 
                              NOT l_orig_closed AND
                              l_end_date_tab(l_ftco_idx) > p_end_date_tab(l_idx) 
                           THEN
                              -- Teenus+pakett kaetakse ära mitme erineva FTCO-ga. Muudame originaalkirjet
                              -- CHG-13755: Uue FTCO alguskuupäevaks läheb eelmise lõpp, et vältida teenuse hinnastamise ülekatet
                              p_start_date_tab(l_idx)       := Greatest(l_start_date_tab(l_ftco_idx), Nvl(l_prev_ftco_end_date + c_one_second, l_start_date_tab(l_ftco_idx)));
                              p_mixed_packet_tab(l_idx)     := l_mixed_packet_tab(l_ftco_idx);
                              p_ebs_order_number_tab(l_idx) := l_ebs_order_number_tab(l_ftco_idx);
                              p_prorata_tab(l_idx)          := 'Y';
                              --
                              l_add_orig_end := FALSE;
                              --
                           ELSE

                              -- Lisada tabelisse FTCO kirje
                              l_add_idx := l_add_idx + 1;
                              --
                              l_add_susg_ref_num_tab(l_add_idx) := p_susg_ref_num_tab(l_idx);
                              l_add_sety_ref_num_tab(l_add_idx) := p_sety_ref_num_tab(l_idx);
                              l_add_sept_type_tab(l_add_idx)    := p_sept_type_tab(l_idx);
                              l_add_start_date_tab(l_add_idx)   := l_start_date_tab(l_ftco_idx);
                              l_add_end_date_tab(l_add_idx)     := Least(p_end_date_tab(l_idx), l_end_date_tab(l_ftco_idx), p_period_end);
                              l_add_category_tab(l_add_idx)     := p_category_tab(l_idx);
                              l_add_mixed_packet_tab(l_add_idx) := l_mixed_packet_tab(l_ftco_idx);
                              l_add_ebs_order_number_tab(l_add_idx) := l_ebs_order_number_tab(l_ftco_idx);
                              l_add_prorata_tab(l_add_idx)      := 'Y';
                              --
                        
                              -- Kui FTCO lõppeb enne teenuse lõppu, siis lisada originaalkirje osa
                              IF l_end_date_tab(l_ftco_idx) < p_end_date_tab(l_idx) THEN
                                 l_add_orig_end := TRUE;
                                 l_orig_end_start_date := l_end_date_tab(l_ftco_idx) + c_one_second;
                              ELSE
                                 l_add_orig_end := FALSE;
                              END IF;
                              -- FTCO start hilisem, originaalkirje lõpukuupäev ära muuta.
                              IF l_ftco_count = 1 THEN
                                 --
                                 l_first_orig_period_end := Trunc(l_start_date_tab(l_ftco_idx)) - c_one_second;
                                 l_orig_closed := TRUE; -- Originaalkirje esimene lõik suletud
                                 --
                              END IF;
                        
                           END IF;
                           --
                           l_prev_ftco_end_date := l_end_date_tab(l_ftco_idx);
                           --
                        ELSIF l_end_date_tab(l_ftco_idx) < p_end_date_tab(l_idx) THEN
                           -- FTCO algus enne teenus+pakett algust ning lõpp varasem. Lisada kirje algusesse.
                           l_add_idx := l_add_idx + 1;
                           --
                           l_add_susg_ref_num_tab(l_add_idx) := p_susg_ref_num_tab(l_idx);
                           l_add_sety_ref_num_tab(l_add_idx) := p_sety_ref_num_tab(l_idx);
                           l_add_sept_type_tab(l_add_idx)    := p_sept_type_tab(l_idx);
                           l_add_start_date_tab(l_add_idx)   := p_start_date_tab(l_idx);
                           l_add_end_date_tab(l_add_idx)     := l_end_date_tab(l_ftco_idx);
                           l_add_category_tab(l_add_idx)     := p_category_tab(l_idx);
                           l_add_mixed_packet_tab(l_add_idx) := l_mixed_packet_tab(l_ftco_idx);
                           l_add_ebs_order_number_tab(l_add_idx) := l_ebs_order_number_tab(l_ftco_idx);
                           l_add_prorata_tab(l_add_idx)      := 'Y';
                           --
                           l_chg_orig_end := TRUE;
                           l_add_orig_end := TRUE;
                           l_orig_end_start_date := l_end_date_tab(l_ftco_idx) + c_one_second;
                           --
                           l_prev_ftco_end_date := l_end_date_tab(l_ftco_idx);
                           --
                        END IF;
                     
                        --
                     ELSIF l_start_date_tab(l_ftco_idx) <= p_start_date_tab(l_idx) AND
                           l_end_date_tab(l_ftco_idx) >= p_end_date_tab(l_idx)
                     THEN
                        --
                        l_ftco_count := l_ftco_count + 1;
                        -- FTCO katab ära teenus+pakett kuupäevade vahemiku. Lisame MIXED tunnuse
                        p_mixed_packet_tab(l_idx)     := l_mixed_packet_tab(l_ftco_idx);   
                        p_ebs_order_number_tab(l_idx) := l_ebs_order_number_tab(l_ftco_idx);                  
                        --
                     END IF;
               
                     l_ftco_idx := l_start_date_tab.NEXT(l_ftco_idx);
                     --                  
                  END LOOP;
               
               
                  -- Esimene periood originaalkirje. Paneme lõpukuupäeva
                  IF l_first_orig_period_end IS NOT NULL THEN
                     p_end_date_tab(l_idx) := l_first_orig_period_end;
                  END IF;
               
                  -- Lisame lõppu FTCO-st puudu jäänud originaalkirje vahemiku
                  IF l_add_orig_end THEN
                     IF l_chg_orig_end THEN
                        --
                        p_start_date_tab(l_idx) := l_orig_end_start_date;
                        --
                     ELSE
                        --
                        l_add_idx := l_add_idx + 1;
                        --
                        l_add_susg_ref_num_tab(l_add_idx) := p_susg_ref_num_tab(l_idx);
                        l_add_sety_ref_num_tab(l_add_idx) := p_sety_ref_num_tab(l_idx);
                        l_add_sept_type_tab(l_add_idx)    := p_sept_type_tab(l_idx);
                        l_add_start_date_tab(l_add_idx)   := l_orig_end_start_date;
                        l_add_end_date_tab(l_add_idx)     := l_original_end_date;
                        l_add_category_tab(l_add_idx)     := p_category_tab(l_idx);
                        l_add_mixed_packet_tab(l_add_idx) := NULL;
                        l_add_ebs_order_number_tab(l_add_idx) := NULL;
                        l_add_prorata_tab(l_add_idx)      := 'Y';
                        --
                     END IF;
                     --
                  END IF;
               
               ELSE
                  -- Kustutada originaalkirje, ei tohi minna vahearvele
                  p_susg_ref_num_tab.DELETE(l_idx);
                  p_sety_ref_num_tab.DELETE(l_idx);
                  p_sept_type_tab.DELETE(l_idx);
                  p_start_date_tab.DELETE(l_idx);
                  p_end_date_tab.DELETE(l_idx);
                  p_category_tab.DELETE(l_idx);
                  p_mixed_packet_tab.DELETE(l_idx);
                  p_ebs_order_number_tab.DELETE(l_idx);
                  p_prorata_tab.DELETE(l_idx);
                  --
               END IF;
               --
            END IF;
                   
            --
         END IF;
         
         --         
         l_idx := p_susg_ref_num_tab.NEXT(l_idx);
      END LOOP;
      
    
      ---------------------------------------------
      -- Lisame uued tekkinud perioodid tabelisse
      ---------------------------------------------
      l_temp_idx := 0;
      --
      IF l_add_idx <> 0 THEN
         --
         l_idx := p_susg_ref_num_tab.FIRST;
         WHILE l_idx IS NOT NULL LOOP

            -- Uue kirje alguskuupäev varasem, lisame originaalkirje ette
            l_add_idx := l_add_susg_ref_num_tab.FIRST;
            WHILE l_add_idx IS NOT NULL LOOP
               -- 
               IF p_susg_ref_num_tab(l_idx) = l_add_susg_ref_num_tab(l_add_idx) AND
                  p_sety_ref_num_tab(l_idx) = l_add_sety_ref_num_tab(l_add_idx) AND
                  p_sept_type_tab(l_idx)    = l_add_sept_type_tab(l_add_idx) AND
                  p_start_date_tab(l_idx) > l_add_start_date_tab(l_add_idx)
               THEN
                  --
                  l_temp_idx := l_temp_idx + 1;
                  --
                  l_temp_susg_ref_num_tab(l_temp_idx)     := l_add_susg_ref_num_tab(l_add_idx);
                  l_temp_sety_ref_num_tab(l_temp_idx)     := l_add_sety_ref_num_tab(l_add_idx);
                  l_temp_sept_type_tab(l_temp_idx)        := l_add_sept_type_tab(l_add_idx);
                  l_temp_start_date_tab(l_temp_idx)       := l_add_start_date_tab(l_add_idx);
                  l_temp_end_date_tab(l_temp_idx)         := l_add_end_date_tab(l_add_idx);
                  l_temp_category_tab(l_temp_idx)         := l_add_category_tab(l_add_idx);
                  l_temp_mixed_packet_tab(l_temp_idx)     := l_add_mixed_packet_tab(l_add_idx);
                  l_temp_ebs_order_number_tab(l_temp_idx) := l_add_ebs_order_number_tab(l_add_idx);
                  l_temp_prorata_tab(l_temp_idx)          := l_add_prorata_tab(l_add_idx);
                  -- Kustutada lisatud kirjed ADD tabelist
                  l_add_susg_ref_num_tab.DELETE(l_add_idx);
                  l_add_sety_ref_num_tab.DELETE(l_add_idx);
                  l_add_sept_type_tab.DELETE(l_add_idx);
                  l_add_start_date_tab.DELETE(l_add_idx);
                  l_add_end_date_tab.DELETE(l_add_idx);
                  l_add_category_tab.DELETE(l_add_idx);
                  l_add_mixed_packet_tab.DELETE(l_add_idx);
                  l_add_ebs_order_number_tab.DELETE(l_add_idx);
                  l_add_prorata_tab.DELETE(l_add_idx);
                  --
               END IF;             
               --
               l_add_idx := l_add_susg_ref_num_tab.NEXT(l_add_idx);
            END LOOP;
            
            -- Lisame (muudetud) originaalkirje
            l_temp_idx := l_temp_idx + 1;
            --
            l_temp_susg_ref_num_tab(l_temp_idx)     := p_susg_ref_num_tab(l_idx);
            l_temp_sety_ref_num_tab(l_temp_idx)     := p_sety_ref_num_tab(l_idx);
            l_temp_sept_type_tab(l_temp_idx)        := p_sept_type_tab(l_idx);
            l_temp_start_date_tab(l_temp_idx)       := p_start_date_tab(l_idx);
            l_temp_end_date_tab(l_temp_idx)         := p_end_date_tab(l_idx);
            l_temp_category_tab(l_temp_idx)         := p_category_tab(l_idx);
            l_temp_mixed_packet_tab(l_temp_idx)     := p_mixed_packet_tab(l_idx);
            l_temp_ebs_order_number_tab(l_temp_idx) := p_ebs_order_number_tab(l_idx);
            l_temp_prorata_tab(l_temp_idx)          := p_prorata_tab(l_idx);
            
            -- Uue kirje alguskuupäev hilisem, lisame originaalkirje järgi
            l_add_idx := l_add_susg_ref_num_tab.FIRST;
            WHILE l_add_idx IS NOT NULL LOOP
               -- 
               IF p_susg_ref_num_tab(l_idx) = l_add_susg_ref_num_tab(l_add_idx) AND
                  p_sety_ref_num_tab(l_idx) = l_add_sety_ref_num_tab(l_add_idx) AND
                  p_sept_type_tab(l_idx)    = l_add_sept_type_tab(l_add_idx) AND
                  p_start_date_tab(l_idx) < l_add_start_date_tab(l_add_idx)
               THEN
                  --
                  l_temp_idx := l_temp_idx + 1;
                  --
                  l_temp_susg_ref_num_tab(l_temp_idx)     := l_add_susg_ref_num_tab(l_add_idx);
                  l_temp_sety_ref_num_tab(l_temp_idx)     := l_add_sety_ref_num_tab(l_add_idx);
                  l_temp_sept_type_tab(l_temp_idx)        := l_add_sept_type_tab(l_add_idx);
                  l_temp_start_date_tab(l_temp_idx)       := l_add_start_date_tab(l_add_idx);
                  l_temp_end_date_tab(l_temp_idx)         := l_add_end_date_tab(l_add_idx);
                  l_temp_category_tab(l_temp_idx)         := l_add_category_tab(l_add_idx);
                  l_temp_mixed_packet_tab(l_temp_idx)     := l_add_mixed_packet_tab(l_add_idx);
                  l_temp_ebs_order_number_tab(l_temp_idx) := l_add_ebs_order_number_tab(l_add_idx);
                  l_temp_prorata_tab(l_temp_idx)          := l_add_prorata_tab(l_add_idx);
                  -- Kustutada lisatud kirjed ADD tabelist
                  l_add_susg_ref_num_tab.DELETE(l_add_idx);
                  l_add_sety_ref_num_tab.DELETE(l_add_idx);
                  l_add_sept_type_tab.DELETE(l_add_idx);
                  l_add_start_date_tab.DELETE(l_add_idx);
                  l_add_end_date_tab.DELETE(l_add_idx);
                  l_add_category_tab.DELETE(l_add_idx);
                  l_add_mixed_packet_tab.DELETE(l_add_idx);
                  l_add_ebs_order_number_tab.DELETE(l_add_idx);
                  l_add_prorata_tab.DELETE(l_add_idx);
                  --
               END IF;             
               --
               l_add_idx := l_add_susg_ref_num_tab.NEXT(l_add_idx);
            END LOOP;
            
            --
            l_idx := p_susg_ref_num_tab.NEXT(l_idx);
         END LOOP;
         
         
         -- Asendame originaaltabeli muudetud tabeliga
         p_susg_ref_num_tab     := l_temp_susg_ref_num_tab;
         p_sety_ref_num_tab     := l_temp_sety_ref_num_tab;
         p_sept_type_tab        := l_temp_sept_type_tab;
         p_start_date_tab       := l_temp_start_date_tab;
         p_end_date_tab         := l_temp_end_date_tab;
         p_category_tab         := l_temp_category_tab;
         p_mixed_packet_tab     := l_temp_mixed_packet_tab;
         p_ebs_order_number_tab := l_temp_ebs_order_number_tab;
         p_prorata_tab          := l_temp_prorata_tab;
         
         
         --
      END IF;
      
      
   END Add_Mixed_Packet_Service_Dates; 
   /****************************************************************************
   **
   **   Procedure Name :  Create_Price_Tables
   **
   **   Description : Protseduur leiab etteantud perioodis kehtivad hinnakirjad tabelitest:
   **                   - fixed_charge_values
   **                   - price_lists
   **                 ning koondab need mälutabelitesse kiiremaks hindade leidmiseks protseduuris get_period_max_price
   **
   **                 Lisaks pannakse mälutabelisse erihindade (subs_serv_fixed_charges) teenuste ref_num-id hiljem
   **                 erihindade otsimiseks protseduuris get_period_max_price
   **
   ****************************************************************************/
   PROCEDURE Create_Price_Tables (p_start_date  IN      DATE
                                 ,p_end_date    IN      DATE
   ) IS
      --
      CURSOR c_prices_ficv IS
         SELECT fcit.type_code               fcit_type_code
              , fcit.taty_type_code          taty_type_code
              , fcit.billing_selector        billing_selector
              , fcit.valid_charge_parameter  charge_parameter
              , fcit.first_prorated_charge   first_prorated_charge
              , fcit.last_prorated_charge    last_prorated_charge
              , fcit.sety_first_prorated     sety_first_prorated
              , ficv.charge_value            charge_value
              , ficv.sepv_ref_num            sepv_ref_num
              , ficv.sepa_ref_num            sepa_ref_num
              , TRUNC (GREATEST (ficv.start_date, p_start_date)) start_date
              , TRUNC (LEAST (NVL (ficv.end_date, p_end_date), p_end_date)) end_date
              , 1                            sequence
              --
              , ficv.sety_ref_num            sety_ref_num
              , ficv.sept_type_code          sept_type_code
              , NULL                         category
              , NULL                         susg_ref_num
          FROM fixed_charge_values ficv
             , fixed_charge_item_types fcit
          WHERE ficv.chca_type_code IS NULL
            AND ficv.channel_type IS NULL
            AND NVL (ficv.par_value_charge, 'N') = 'N'
            AND ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = 'N'
            AND fcit.pro_rata = 'N'
            AND fcit.regular_charge = 'Y'
            AND ficv.start_date <= p_end_date
            AND NVL (ficv.end_date, p_end_date) >= TRUNC (p_start_date)
            AND ficv.sety_ref_num IS NOT NULL
         ORDER BY ficv.sety_ref_num, start_date  
      ;
      --
      CURSOR c_prices_prli IS
         SELECT fcit.type_code               fcit_type_code
              , fcit.taty_type_code          taty_type_code
              , fcit.billing_selector        billing_selector
              , fcit.valid_charge_parameter  charge_parameter   -- CHG-2795
              , fcit.first_prorated_charge   first_prorated_charge   -- CHG-2795
              , fcit.last_prorated_charge    last_prorated_charge    -- CHG-6214
              , fcit.sety_first_prorated     sety_first_prorated   -- CHG-3714
              , prli.charge_value            charge_value
              , prli.sepv_ref_num            sepv_ref_num
              , prli.sepa_ref_num            sepa_ref_num
              , TRUNC (GREATEST (prli.start_date, p_start_date)) start_date
              , TRUNC (LEAST (NVL (prli.end_date, p_end_date), p_end_date)) end_date
              , DECODE (prli.package_category, NULL, 3, 2) SEQUENCE
              --
              , prli.sety_ref_num            sety_ref_num
              , NULL                         sept_type_code
              , fcit.package_category        category
              , NULL                         susg_ref_num
         FROM price_lists prli
            , fixed_charge_item_types fcit
         WHERE prli.channel_type IS NULL
           AND NVL (prli.par_value_charge, 'N') = 'N'
           AND prli.once_off = 'N'
           AND prli.pro_rata = 'N'
           AND prli.regular_charge = 'Y'
           AND fcit.once_off = 'N'
           AND fcit.pro_rata = 'N'
           AND fcit.regular_charge = 'Y'
           AND prli.sety_ref_num = fcit.sety_ref_num
           AND (fcit.package_category = prli.package_category OR prli.package_category IS NULL)
           AND prli.start_date <= p_end_date
           AND NVL (prli.end_date, p_end_date) >= TRUNC (p_start_date)
           AND prli.sety_ref_num IS NOT NULL
         ORDER BY prli.sety_ref_num, sequence, start_date
      ;
      -- Leiame teenused, mille puhul avatakse kursor c_ssfc protseduuris get_period_max_price
      CURSOR c_ssfc_services IS
         SELECT DISTINCT ssfc.sety_ref_num
         FROM subs_serv_fixed_charges ssfc
            , fixed_charge_item_types fcit
         WHERE fcit.once_off = 'N'
           AND fcit.pro_rata = 'N'
           AND fcit.regular_charge = 'Y'
           AND ssfc.sety_ref_num = fcit.sety_ref_num
           AND ssfc.start_date <= p_end_date
           AND NVL (ssfc.end_date, p_end_date) >= p_start_date
      ;
      --
      l_curr_sety_ref_num    NUMBER;
      l_prev_sety_ref_num    NUMBER;
      l_idx                  NUMBER;
      l_count                NUMBER;
   BEGIN
      ----------------------------------------------
      -- FICV prices
      ----------------------------------------------
      g_price_table_ficv.DELETE;
      --
      OPEN  c_prices_ficv;
      FETCH c_prices_ficv BULK COLLECT INTO g_price_table_ficv;
      CLOSE c_prices_ficv;
      -- Create marker table for FICV prices - index by sety_ref_num
      g_marker_ficv.DELETE;
      l_count := 0;
      l_curr_sety_ref_num := NULL;
      l_prev_sety_ref_num := NULL;
      --
      l_idx := g_price_table_ficv.FIRST;
      --
      WHILE l_idx IS NOT NULL LOOP
         l_count := l_count + 1;
         
         l_curr_sety_ref_num := g_price_table_ficv(l_idx).sety_ref_num;
         --
         IF l_prev_sety_ref_num IS NULL OR
            l_prev_sety_ref_num <> l_curr_sety_ref_num
         THEN
            --
            g_marker_ficv(l_curr_sety_ref_num).start_num := l_count;
            --
            IF l_prev_sety_ref_num IS NOT NULL AND
               l_prev_sety_ref_num <> l_curr_sety_ref_num
            THEN
               g_marker_ficv(l_prev_sety_ref_num).end_num := (l_count - 1);
            END IF;
            --
         END IF;     
         
         l_prev_sety_ref_num := g_price_table_ficv(l_idx).sety_ref_num;
         --
         l_idx := g_price_table_ficv.NEXT(l_idx);
      END LOOP;
      -- Täidame viimase end_num'i samuti ära
      g_marker_ficv(l_prev_sety_ref_num).end_num    := l_count;
      
      
      ----------------------------------------------
      -- PRLI prices
      ----------------------------------------------
      g_price_table_prli.DELETE;
      --
      OPEN  c_prices_prli;
      FETCH c_prices_prli BULK COLLECT INTO g_price_table_prli;
      CLOSE c_prices_prli;
      -- Create marker table for FICV prices - index by sety_ref_num
      g_marker_prli.DELETE;
      l_count := 0;
      l_curr_sety_ref_num := NULL;
      l_prev_sety_ref_num := NULL;
      --
      l_idx := g_price_table_prli.FIRST;
      --
      WHILE l_idx IS NOT NULL LOOP
         l_count := l_count + 1;
         
         l_curr_sety_ref_num := g_price_table_prli(l_idx).sety_ref_num;
         --
         IF l_prev_sety_ref_num IS NULL OR
            l_prev_sety_ref_num <> l_curr_sety_ref_num
         THEN
            --
            g_marker_prli(l_curr_sety_ref_num).start_num := l_count;
            --
            IF l_prev_sety_ref_num IS NOT NULL AND
               l_prev_sety_ref_num <> l_curr_sety_ref_num
            THEN
               g_marker_prli(l_prev_sety_ref_num).end_num := (l_count - 1);
            END IF;
            --
         END IF;     
         
         l_prev_sety_ref_num := g_price_table_prli(l_idx).sety_ref_num;
         --
         l_idx := g_price_table_prli.NEXT(l_idx);
      END LOOP;
      -- Täidame viimase end_num'i samuti ära
      g_marker_prli(l_prev_sety_ref_num).end_num    := l_count;
      
      
      ----------------------------------------------
      -- SSFC services
      ----------------------------------------------
      g_ssfc_serv_tab.DELETE;
      --
      FOR rec IN c_ssfc_services LOOP
         --
         g_ssfc_serv_tab(rec.sety_ref_num) := rec.sety_ref_num;
         --
      END LOOP;
      
      --
   END Create_Price_Tables;
   /***************************************************************************
   **
   **   Procedure Name :  Chk_Mobile_NonKER_Service_Fees
   **
   **   Description : Protseduur töötleb k?ik mitte-KER teenused, millistele kehtib
   **                 päevade arvust s?ltumatu kuutasu.
   **                 Töötlemine järjestatult: master->mobiil->teenus->teenuse alguskp.
   **                 Salvestamine iga masteri töötlemise järel. Salvestatakse, kas
   **                 kogu master v?i v?etakse kogu master tagasi.
   **
   ****************************************************************************/
   PROCEDURE chk_mobile_nonker_service_fees (
      p_period_start  IN      DATE
     ,p_period_end    IN      DATE
     ,p_tbpr_rec      IN OUT  tbcis_processes%ROWTYPE
     ,p_success       OUT     BOOLEAN
     ,p_error_text    OUT     VARCHAR2
     ,p_maac_ref_num  IN      master_accounts_v.ref_num%TYPE DEFAULT NULL
     ,p_bill_cycle    IN      VARCHAR2 DEFAULT NULL  -- CHG-4482
   ) IS
      --
      c_proc_module_ref    CONSTANT VARCHAR2 (10) := 'BCCU1284NK';
      c_module_name        CONSTANT bcc_batch_messages.module_desc%TYPE := 'Check Mobile Non KER Service Fees';
      --
      CURSOR c_stpe IS
         SELECT   /*+ INDEX(supa supa_fk4) INDEX (stpe stpe_di3) */
                  stpe.susg_ref_num
                 ,stpe.sety_ref_num
                 ,supa.sept_type_code
                 ,TRUNC (supa.suac_ref_num, -3) maac_ref_num
                 ,GREATEST (stpe.start_date, supa.start_date, p_period_start) start_date
                 ,LEAST (NVL (stpe.end_date, p_period_end)
                        ,NVL (supa.end_date + 1 - c_one_second, p_period_end)
                        ,p_period_end
                        ) end_date
                 ,sept.CATEGORY
                 ,NULL mixed_packet_code  -- CHG-5762
                 ,NULL ebs_order_number   -- CHG-5762
                 ,'N'  prorata            -- CHG-5762
             FROM subs_packages supa, status_periods stpe, serv_package_types sept, package_categories paca
            WHERE NVL (supa.end_date, p_period_start) >= p_period_start
              AND (p_maac_ref_num IS NULL OR TRUNC (supa.suac_ref_num, -3) = p_maac_ref_num
                  )   -- CHG-3908: For testing with one MAAC
              AND (p_bill_cycle IS NULL OR                                                                              -- CHG-4482
                   p_bill_cycle = (select bicy_cycle_code from accounts where ref_num = TRUNC (supa.suac_ref_num, -3))  -- CHG-4482
                  )
              AND supa.start_date <= p_period_end
              AND stpe.susg_ref_num = supa.gsm_susg_ref_num
              AND stpe.sety_ref_num IN (SELECT DISTINCT prli.sety_ref_num sety_ref_num
                                                   FROM price_lists prli, service_types sety
                                                  WHERE NVL (prli.par_value_charge, 'N') = 'N'
                                                    AND prli.once_off = 'N'
                                                    AND prli.pro_rata = 'N'
                                                    AND prli.regular_charge = 'Y'
                                                    -- CHG-1241                   AND    prli.charge_value > 0
                                                    AND prli.start_date <= p_period_end
                                                    AND NVL (prli.end_date, p_period_start) >= p_period_start
                                                    AND sety.ref_num = prli.sety_ref_num
                                                    AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV')
                                        UNION
                                        SELECT DISTINCT ficv.sety_ref_num sety_ref_num
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
                                                    AND ficv.start_date <= p_period_end
                                                    AND NVL (ficv.end_date, p_period_start) >= p_period_start
                                                    AND sety.ref_num = ficv.sety_ref_num
                                                    AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV'))
              AND NVL (stpe.end_date, p_period_start) >= p_period_start
              AND stpe.start_date <= p_period_end
              AND NVL (supa.end_date, stpe.start_date) >= TRUNC (stpe.start_date)
              AND supa.start_date <= NVL (stpe.end_date, supa.start_date)
              AND sept.type_code = supa.sept_type_code
              -- CHG-662: Välja arvata ettemaksukaardid
              AND sept.CATEGORY = paca.package_category
              AND paca.end_date IS NULL
              AND paca.nety_type_code = NVL (sept.nety_type_code, 'GSM')
              AND paca.prepaid <> 'Y'
              -- CHG-3861: Välistada LAMA domeeni koondarved (kõnekaardid ja TravelSim)
              AND TRUNC (supa.suac_ref_num, -3) NOT IN (SELECT TO_NUMBER (value_code) AS large_maac_ref_num
                                                          FROM bcc_domain_values
                                                         WHERE doma_type_code = 'LAMA')
              -- CHG-6381: Välistada teenuse perioodi ülekattumine paketivahetusel
              AND (CASE WHEN Trunc(stpe.end_date) = supa.start_date AND stpe.start_date < supa.start_date THEN 0 ELSE 1 END) <> 0
         --
         ORDER BY supa.suac_ref_num, stpe.susg_ref_num, stpe.sety_ref_num, stpe.start_date, supa.start_date   -- CHG-3704
                                                                                                           ;

      --
      l_last_maac_ref_num           accounts.ref_num%TYPE;
      l_last_proc_maac              accounts.ref_num%TYPE;
      l_susg_ref_num_tab            t_ref_num;
      l_sety_ref_num_tab            t_ref_num;
      l_sept_type_tab               t_char4;
      l_start_date_tab              t_date;
      l_end_date_tab                t_date;
      l_category_tab                t_char1;
      l_mixed_packet_tab            t_char6;   -- CHG-5762
      l_ebs_order_number_tab        t_number;  -- CHG-5762
      l_prorata_tab                 t_char1;   -- CHG-5762
      l_count                       NUMBER;
      l_max_allowed_errors          NUMBER;    -- CHG-4482
      l_error_count                 NUMBER;    -- CHG-4482
      l_param_level                 VARCHAR2(1); -- CHG-4482
      --
      e_processing                  EXCEPTION;
   BEGIN
      l_last_proc_maac := TO_NUMBER (p_tbpr_rec.other_params);
      
      -- Maksimaalne lubatud vigade arv
      l_max_allowed_errors := To_Number(get_system_parameter(663));  -- CHG-4482
      l_error_count        := 0;                                     -- CHG-4482

      /*
        ** CHG-4482: Laeme hinnakirjad mälutabelitesse
      */
      Create_Price_Tables (p_period_start  --p_start_date  IN      DATE
                          ,p_period_end    --p_end_date    IN      DATE
                          );
                          
      -- CHG-4482: Kui toimub BICY põhine töötlus, siis peab tbcis_processes update olema ka tsüklipõhine.
      IF p_bill_cycle IS NOT NULL THEN
         l_param_level := 'Y';
      ELSE
         l_param_level := 'N';
      END IF;

      /*
        ** Leitakse k?ik mitte-KER teenused, millel eksisteerib päevade arvust s?ltumatu kuutasu.
        ** Järjestus MAAC -> SUSG -> teenus -> alguskp.
      */
      FOR l_stpe IN c_stpe LOOP
         /*
           ** Kui on jätkukäivitus, siis juba töödeldud mastereid ei töödelda uuesti.
         */
         IF l_last_proc_maac IS NULL OR l_stpe.maac_ref_num > l_last_proc_maac THEN
            IF l_stpe.maac_ref_num <> NVL (l_last_maac_ref_num, -1) THEN
               /*
                 ** Kogume k?ik masteri teenused PL/SQL tabelitesse.
                 ** Töötlemine/salvestamine seejärel juba masteri kaupa PL/SQL tabelite alusel.
               */
               IF l_last_maac_ref_num IS NOT NULL THEN
                  /*
                    ** CHG-5762: Lisame vahetabelisse PAK komplektiteenuste kuupäevad ja tunnused
                  */
                  Add_Mixed_Packet_Service_Dates (p_period_start     --IN      DATE
                                                 ,p_period_end       --IN      DATE
                                                 ,l_susg_ref_num_tab --IN OUT  t_ref_num
                                                 ,l_sety_ref_num_tab --IN OUT  t_ref_num
                                                 ,l_sept_type_tab    --IN OUT  t_char4
                                                 ,l_start_date_tab   --IN OUT  t_date
                                                 ,l_end_date_tab     --IN OUT  t_date
                                                 ,l_category_tab     --IN OUT  t_char1
                                                 ,l_mixed_packet_tab --IN OUT  t_char6
                                                 ,l_ebs_order_number_tab
                                                 ,l_prorata_tab      --IN OUT  t_char1
                                                 );

                  --
                  proc_one_maac_nonker_serv_fees (l_last_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                 ,p_period_start   -- IN     DATE
                                                 ,p_period_end   -- IN     DATE
                                                 ,l_susg_ref_num_tab   -- IN     t_ref_num
                                                 ,l_sety_ref_num_tab   -- IN     t_ref_num
                                                 ,l_sept_type_tab   -- IN     t_char4
                                                 ,l_start_date_tab   -- IN     t_date
                                                 ,l_end_date_tab   -- IN     t_date
                                                 ,l_category_tab   -- IN     t_char1
                                                 ,l_mixed_packet_tab --IN t_char6       CHG-5762
                                                 ,l_ebs_order_number_tab --IN t_number  CHG-5762
                                                 ,l_prorata_tab      --IN t_char1       CHG-5762
                                                 ,p_success   --    OUT BOOLEAN
                                                 ,p_error_text   --    OUT VARCHAR2
                                                 );

                  IF NOT p_success THEN
                     -- CHG-4482: Kui vigade arv jääb alla lubatud miinimumi, siis laseme protsessil edasi minna
                     l_error_count := l_error_count + 1;
                     ROLLBACK;
                     --
                     gen_bill.msg (c_module_ref
                                  ,c_module_name
                                  ,c_message_nr
                                  ,'MAAC='||l_last_maac_ref_num||', '||p_error_text||'. '
                                  ,NULL
                                  ,p_bill_cycle  -- CHG-4482
                      );
                      --
                     --COMMIT;
                     
                     IF l_error_count > l_max_allowed_errors THEN
                        RAISE e_processing;
                     END IF;
                  END IF;

                  /*
                    ** Regitreerime viimase töödeldud MAACi, et vea korral jätkata sealt, kus pooleli jäi.
                    ** CHG-3908: Ühe MAACiga testimisel ei ole vaja Tbcis Processes tabelit uuendada!
                  */
                  IF p_maac_ref_num IS NULL THEN
                     --
                     p_tbpr_rec.other_params := TO_CHAR (l_last_maac_ref_num);
                     tbcis_common.update_tbcis_process (p_tbpr_rec, l_param_level);
                  --
                  END IF;

                  --
                  --COMMIT;
               END IF;

               --
               l_count := 0;
               l_susg_ref_num_tab.DELETE;
               l_sety_ref_num_tab.DELETE;
               l_sept_type_tab.DELETE;
               l_start_date_tab.DELETE;
               l_end_date_tab.DELETE;
               l_category_tab.DELETE;
               l_mixed_packet_tab.DELETE;      -- CHG-5762
               l_ebs_order_number_tab.DELETE;  -- CHG-5762
               l_prorata_tab.DELETE;           -- CHG-5762
            END IF;

            --
            l_count := l_count + 1;
            l_susg_ref_num_tab (l_count) := l_stpe.susg_ref_num;
            l_sety_ref_num_tab (l_count) := l_stpe.sety_ref_num;
            l_sept_type_tab (l_count) := l_stpe.sept_type_code;
            l_start_date_tab (l_count) := l_stpe.start_date;
            l_end_date_tab (l_count) := l_stpe.end_date;
            l_category_tab (l_count) := l_stpe.CATEGORY;
            l_mixed_packet_tab (l_count) := l_stpe.mixed_packet_code;    -- CHG-5762
            l_ebs_order_number_tab (l_count) := l_stpe.ebs_order_number; -- CHG-5762
            l_prorata_tab (l_count) := l_stpe.prorata;                   -- CHG-5762
            --
            l_last_maac_ref_num := l_stpe.maac_ref_num;
         END IF;
      END LOOP;

      /*
        ** CHG-5762: Lisame vahetabelisse PAK komplektiteenuste kuupäevad ja tunnused
      */
      Add_Mixed_Packet_Service_Dates (p_period_start     --IN      DATE
                                     ,p_period_end       --IN      DATE
                                     ,l_susg_ref_num_tab --IN OUT  t_ref_num
                                     ,l_sety_ref_num_tab --IN OUT  t_ref_num
                                     ,l_sept_type_tab    --IN OUT  t_char4
                                     ,l_start_date_tab   --IN OUT  t_date
                                     ,l_end_date_tab     --IN OUT  t_date
                                     ,l_category_tab     --IN OUT  t_char1
                                     ,l_mixed_packet_tab --IN OUT  t_char6
                                     ,l_ebs_order_number_tab
                                     ,l_prorata_tab      --IN OUT  t_char1
      );


      /*
        ** Nüüd tuleb veel töödelda viimase masteri andmed.
        ** Eelnevalt töödeldud teenuse andmed tuleks arvereale kanda, kui summa > 0.
      */
      proc_one_maac_nonker_serv_fees (l_last_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                     ,p_period_start   -- IN     DATE
                                     ,p_period_end   -- IN     DATE
                                     ,l_susg_ref_num_tab   -- IN     t_ref_num
                                     ,l_sety_ref_num_tab   -- IN     t_ref_num
                                     ,l_sept_type_tab   -- IN     t_char4
                                     ,l_start_date_tab   -- IN     t_date
                                     ,l_end_date_tab   -- IN     t_date
                                     ,l_category_tab   -- IN     t_char1
                                     ,l_mixed_packet_tab --IN t_char6       CHG-5762
                                     ,l_ebs_order_number_tab --IN t_number  CHG-5762
                                     ,l_prorata_tab      --IN t_char1       CHG-5762
                                     ,p_success   --    OUT BOOLEAN
                                     ,p_error_text   --    OUT VARCHAR2
                                     );

      IF NOT p_success THEN
         -- CHG-4482: Kui vigade arv jääb alla lubatud miinimumi, siis laseme protsessil edasi minna
         l_error_count := l_error_count + 1;
         ROLLBACK;
         --
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      ,'MAAC='||l_last_maac_ref_num||', '||p_error_text||'. '
                      ,NULL
                      ,p_bill_cycle  -- CHG-4482
                      );
         --
         --COMMIT;
                     
         IF l_error_count > l_max_allowed_errors THEN
            RAISE e_processing;
         END IF;
      END IF;

      /*
        ** Regitreerime viimase töödeldud MAACi, et vea korral jätkata sealt, kus pooleli jäi.
        ** CHG-3908: Ühe MAACiga testimisel ei ole vaja Tbcis Processes tabelit uuendada!
      */
      IF p_maac_ref_num IS NULL THEN
         --
         p_tbpr_rec.other_params := TO_CHAR (l_last_maac_ref_num);
         tbcis_common.update_tbcis_process (p_tbpr_rec, l_param_level);
      --
      END IF;

      --
      --COMMIT;
      --
      IF l_error_count > 0 THEN
         p_success := FALSE;
         p_error_text := 'NonKer teenuste töötlemisel tekkis '||l_error_count||' viga!';
      ELSE
         p_success := TRUE;
      END IF;
   EXCEPTION
      WHEN e_processing THEN
         /*
           ** Salvestamine masteri kaupa, et oleks v?imalik taaskäivitamisel jätkata sealt, kus pooleli jäi ->
           ** kogu viimase masteri salvestamata muutused v?etakse tagasi.
         */
         ROLLBACK;
         p_error_text := 'Lubatud maksimaalne vigade arv ületatud. Protsess katkestatud!';
         p_success := FALSE;
      WHEN OTHERS THEN
         /*
           ** Salvestamine masteri kaupa, et oleks v?imalik taaskäivitamisel jätkata sealt, kus pooleli jäi ->
           ** kogu viimase masteri salvestamata muutused v?etakse tagasi.
         */
         ROLLBACK;
         p_success := FALSE;
         p_error_text := SQLERRM;
   END chk_mobile_nonker_service_fees;

   /***************************************************************************
   **
   **   Procedure Name :  Proc_One_MAAC_MobKER_Serv_Fees
   **
   **   Description : Protseduur kannab ette antud masteri mobiilide KER teenuste
   **                 kuutasud vahetabelisse (hilisemaks arvetele kandmiseks).
   **
   ****************************************************************************/
   PROCEDURE proc_one_maac_mobker_serv_fees (
      p_maac_ref_num      IN      accounts.ref_num%TYPE
     ,p_period_start      IN      DATE
     ,p_period_end        IN      DATE
     ,p_susg_ref_num_tab  IN      t_ref_num
     ,p_sety_ref_num_tab  IN      t_ref_num
     ,p_sept_type_tab     IN      t_char4
     ,p_end_date_tab      IN      t_date
     ,p_category_tab      IN      t_char1
     ,p_tbpr_rec          IN OUT  tbcis_processes%ROWTYPE
   ) IS
      --
      l_idx                         NUMBER;
      l_last_susg_ref_num           subs_serv_groups.ref_num%TYPE;
      l_channel                     price_lists.channel_type%TYPE;
      l_bicy_cycle_code             bill_cycles.cycle_code%TYPE;
      l_events_exist                VARCHAR2 (1);
      l_price                       NUMBER;
      l_sepv_ref_num                service_param_values.ref_num%TYPE;
      l_calc_fc_allowed             BOOLEAN;
      l_ins_count                   NUMBER;
      l_sety_ref_num_tab            t_ref_num;
      l_maac_ref_num_tab            t_ref_num;
      l_susg_ref_num_tab            t_ref_num;
      l_price_tab                   t_number;
      l_sept_type_code_tab          t_char4;
      l_bill_cycle_tab              t_char3;
      l_channel_type_tab            t_char6;
      l_events_exist_tab            t_char1;
      l_inen_exists_tab             t_char1;
      l_bill_serv_chg_allowed_tab   t_char1;
      l_station_param_tab           t_char25;
      l_maas_ref_num_tab            t_ref_num;
      l_end_date_tab                t_date;
      l_category_tab                t_char1;
      l_chca_type_code_tab          t_char3;
      l_mobile_end_date             DATE;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
   BEGIN
      l_ins_count := 0;
      l_idx := p_susg_ref_num_tab.FIRST;

      --
      WHILE l_idx IS NOT NULL LOOP
         IF p_susg_ref_num_tab (l_idx) <> NVL (l_last_susg_ref_num, -1) THEN
            /*
              ** Mobiili vahetusel nullida mobiili taseme muutujad.
              ** Masteri taseme muutujad on kasutatavad masteri k?igi mobiilide korral.
            */
            l_mobile_end_date := NULL;
            l_events_exist := NULL;
         END IF;

         /*
           ** Iga mobiil+teenus kombinatsioon on PL/SQL tabelites ainult 1-kordselt - maksustatakse
           ** ainult arveldusperioodi viimast teenusperioodi.
         */
         l_calc_fc_allowed :=
            chk_ker_service_fee (p_susg_ref_num_tab (l_idx)   -- IN     subs_serv_groups.ref_num%TYPE
                                ,p_sety_ref_num_tab (l_idx)   -- IN     service_types.ref_num%TYPE
                                ,p_end_date_tab (l_idx)   -- IN     DATE
                                ,p_period_start   -- IN     DATE
                                ,p_period_end   -- IN     DATE
                                ,p_sept_type_tab (l_idx)   -- IN     serv_package_types.type_code%TYPE
                                ,p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                ,p_category_tab (l_idx)   -- IN     package_categories.package_category%TYPE
                                ,l_mobile_end_date   -- IN OUT DATE
                                ,l_channel   -- IN OUT price_lists.channel_type%TYPE
                                ,l_bicy_cycle_code   -- IN OUT bill_cycles.cycle_code%TYPE
                                ,l_events_exist   -- IN OUT VARCHAR2
                                ,l_price   --    OUT NUMBER
                                ,l_sepv_ref_num   --    OUT service_param_values.ref_num%TYPE
                                ,l_taty_type_code   --    OUT tax_types.tax_type_code%TYPE
                                ,l_billing_selector   --    OUT billing_selectors_v.type_code%TYPE
                                ,l_fcit_type_code   --    OUT fixed_charge_item_types.type_code%TYPE
                                );

         /*
           ** Kui maksustamine lubatud, siis salvestame maksustamiseks vajalikud andmed PL/SQL tabelitesse.
         */
         IF l_calc_fc_allowed THEN
            l_ins_count := l_ins_count + 1;
            l_maac_ref_num_tab (l_ins_count) := p_maac_ref_num;
            l_sety_ref_num_tab (l_ins_count) := p_sety_ref_num_tab (l_idx);
            l_price_tab (l_ins_count) := NVL (l_price, 0);
            l_susg_ref_num_tab (l_ins_count) := p_susg_ref_num_tab (l_idx);
            l_sept_type_code_tab (l_ins_count) := p_sept_type_tab (l_idx);
            l_bill_cycle_tab (l_ins_count) := l_bicy_cycle_code;
            l_channel_type_tab (l_ins_count) := l_channel;
            l_events_exist_tab (l_ins_count) := l_events_exist;
            l_inen_exists_tab (l_ins_count) := NULL;
            l_bill_serv_chg_allowed_tab (l_ins_count) := NULL;
            l_station_param_tab (l_ins_count) := 'KER';
            l_maas_ref_num_tab (l_ins_count) := NULL;
            l_end_date_tab (l_ins_count) := p_end_date_tab (l_idx);
            l_category_tab (l_ins_count) := p_category_tab (l_idx);
            l_chca_type_code_tab (l_ins_count) := NULL;
         END IF;

         --
         l_last_susg_ref_num := p_susg_ref_num_tab (l_idx);
         l_idx := p_susg_ref_num_tab.NEXT (l_idx);
      END LOOP;

      /*
        ** Masteri k?igi arveldatavate teenuste read kantakse korraga maha ja salvestatakse.
      */
      IF l_maac_ref_num_tab.EXISTS (1) THEN
         ins_monthly_service_fees (l_maac_ref_num_tab   -- IN OUT t_ref_num
                                  ,l_susg_ref_num_tab   -- IN OUT t_ref_num
                                  ,l_sety_ref_num_tab   -- IN OUT t_ref_num
                                  ,l_price_tab   -- IN OUT t_number
                                  ,l_sept_type_code_tab   -- IN OUT t_char4
                                  ,l_bill_cycle_tab   -- IN OUT t_char3
                                  ,l_channel_type_tab   -- IN OUT t_char6
                                  ,l_events_exist_tab   -- IN OUT t_char1
                                  ,l_inen_exists_tab   -- IN OUT t_char1
                                  ,l_bill_serv_chg_allowed_tab   -- IN OUT t_char1
                                  ,l_station_param_tab   -- IN OUT t_char25
                                  ,l_maas_ref_num_tab   -- IN OUT t_ref_num
                                  ,l_end_date_tab   -- IN OUT t_date
                                  ,l_category_tab   -- IN OUT t_char1
                                  ,l_chca_type_code_tab   -- IN OUT t_char3
                                  ,p_period_start   -- IN     DATE
                                  ,p_period_end   -- IN     DATE
                                  );
      END IF;

      /*
        ** Regitreerime viimase töödeldud MAACi, et vea korral jätkata sealt, kus pooleli jäi.
      */
      p_tbpr_rec.module_params := TO_CHAR (p_maac_ref_num);
      tbcis_common.update_tbcis_process (p_tbpr_rec);
      --
      --COMMIT;
   END proc_one_maac_mobker_serv_fees;


   /*
     **
     **   -- GLOBAL PROGRAM UNITS seen also outside current package
     **
   */

   /***************************************************************************
   **
   **   Procedure Name :  Chk_Mobile_KER_Service_Fees
   **
   **   Description : Protseduur päevade arvust s?ltumatute mobiilitaseme KER teenuste
   **                 maksustamise andmete ettevalmistamiseks vahetabelis Monthly_Service_Fees.
   **
   ****************************************************************************/
   PROCEDURE chk_mobile_ker_service_fees (
      p_mode  IN  VARCHAR2 DEFAULT c_calculate_mode   -- CALC/RECALC/CONTINUE
   ) IS
      --
      c_module_name        CONSTANT bcc_batch_messages.module_desc%TYPE := 'Check Mobile KER Service Fees';
      c_proc_module_ref    CONSTANT VARCHAR2 (10) := 'BCCU1284KE';

      --
      CURSOR c_stpe (
         p_period_start  IN  DATE
        ,p_period_end    IN  DATE
      ) IS
         SELECT   /*+ INDEX(supa supa_fk4) INDEX (stpe stpe_di3) */
                  stpe.susg_ref_num
                 ,stpe.sety_ref_num
                 ,supa.sept_type_code
                 ,TRUNC (supa.suac_ref_num, -3) maac_ref_num
                 ,stpe.end_date
                 ,sept.CATEGORY
             FROM subs_packages supa, status_periods stpe, serv_package_types sept, package_categories paca
            WHERE stpe.sety_ref_num IN (SELECT DISTINCT prli.sety_ref_num sety_ref_num
                                                   FROM price_lists prli, service_types sety
                                                  WHERE NVL (prli.par_value_charge, 'N') = 'N'
                                                    AND prli.once_off = 'N'
                                                    AND prli.pro_rata = 'N'
                                                    AND prli.regular_charge = 'Y'
                                                    AND prli.charge_value > 0
                                                    AND prli.start_date <= p_period_end
                                                    AND NVL (prli.end_date, p_period_start) >= p_period_start
                                                    AND sety.ref_num = prli.sety_ref_num
                                                    AND sety.secl_class_code NOT IN ('M', 'Q', 'T', 'V', 'O')
                                                    AND sety.station_param = 'KER'
                                        UNION
                                        SELECT DISTINCT ficv.sety_ref_num sety_ref_num
                                                   FROM fixed_charge_values ficv
                                                       ,fixed_charge_item_types fcit
                                                       ,service_types sety
                                                  WHERE ficv.chca_type_code IS NULL
                                                    AND NVL (ficv.par_value_charge, 'N') = 'N'
                                                    AND ficv.charge_value > 0
                                                    AND ficv.fcit_charge_code = fcit.type_code
                                                    AND fcit.once_off = 'N'
                                                    AND fcit.pro_rata = 'N'
                                                    AND fcit.regular_charge = 'Y'
                                                    AND ficv.start_date <= p_period_end
                                                    AND NVL (ficv.end_date, p_period_start) >= p_period_start
                                                    AND sety.ref_num = ficv.sety_ref_num
                                                    AND sety.secl_class_code NOT IN ('M', 'Q', 'T', 'V', 'O')
                                                    AND sety.station_param = 'KER')
              AND NVL (stpe.end_date, p_period_start) >= p_period_start
              AND stpe.start_date <= p_period_end
              AND supa.gsm_susg_ref_num = stpe.susg_ref_num
              AND NVL (supa.end_date, p_period_start) >= p_period_start
              AND supa.start_date <= p_period_end
              AND TRUNC (LEAST (p_period_end, NVL (stpe.end_date, p_period_end)))   -- V?etakse pakett, milline kehtib kuu l?pus v?i teenuse sulgemisel
                     BETWEEN supa.start_date
                         AND NVL (supa.end_date, p_period_end)
              AND sept.type_code = supa.sept_type_code
              -- CHG-662: Välja arvata ettemaksukaardid
              AND sept.CATEGORY = paca.package_category
              AND paca.end_date IS NULL
              AND paca.nety_type_code = NVL (sept.nety_type_code, 'GSM')
              AND paca.prepaid <> 'Y'
         -- End CHG-662
         ORDER BY supa.suac_ref_num, stpe.susg_ref_num, stpe.sety_ref_num, stpe.start_date DESC;

      --
      l_salp_rec                    sales_ledger_periods%ROWTYPE;
      l_period_start_date           DATE;
      l_period_end_date             DATE;
      l_maac_ref_num                accounts.ref_num%TYPE;
      l_ker_proc_rec                tbcis_processes%ROWTYPE;
      l_message                     bcc_batch_messages.MESSAGE_TEXT%TYPE;
      l_cur_param                   VARCHAR2 (10);
      l_susg_ref_num_tab            t_ref_num;
      l_sety_ref_num_tab            t_ref_num;
      l_sept_type_tab               t_char4;
      l_end_date_tab                t_date;
      l_category_tab                t_char1;
      l_count                       NUMBER;
      l_last_susg_ref_num           subs_serv_groups.ref_num%TYPE;
      l_last_sety_ref_num           service_types.ref_num%TYPE;
      l_last_proc_maac_ref          accounts.ref_num%TYPE;
      
      l_bill_start             DATE; 
      l_bill_cutoff            DATE;
      l_prodn_date             DATE;
      l_success                BOOLEAN;
      --
      e_initializing                EXCEPTION;
   BEGIN
      gen_bill.msg (c_module_ref
                   ,c_module_name
                   ,c_message_nr
                   , 'Protsess käivitatud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                   , 'Mode=' || p_mode
                   );
      /*
        ** Leiame vaadeldava arveldusperioodi = esimese avatud perioodi info.
      */
      l_salp_rec := gen_bill.first_open_salp_rec;
      l_period_start_date := l_salp_rec.start_date;
      l_period_end_date := TRUNC (l_salp_rec.end_date) + 1 - c_one_second;


 BCC_Misc_Processing.Set_Cut_Off_Date     (l_success      
                                           ,null
                                           ,l_bill_start             -- OUT DATE
                                           ,l_bill_cutoff            -- OUT DATE 23:59:59
                                           ,l_prodn_date             -- OUT DATE
                                           );
      --
      IF SYSDATE <= l_prodn_date THEN
         l_message := 'Protsessi ei saa käivitada jooksva perioodi kohta';
         RAISE e_initializing;
      END IF;

      /*
        ** Leiame vastava TBCIS protsessi kirje KER teenuse jaoks.
      */
      l_ker_proc_rec := tbcis_common.get_tbcis_process (c_proc_module_ref);   -- IN tbcis_processes.module_ref%TYPE

      --
      IF p_mode = c_calculate_mode THEN   -- CALC
         IF     NVL (l_ker_proc_rec.financial_year, 0) = l_salp_rec.financial_year
            AND NVL (l_ker_proc_rec.period_num, 0) = l_salp_rec.period_num THEN
            l_message :=    'Protsess on perioodile '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' juba käivitatud. Kasutage ümberhindamise (RECALC) v?i jätkamise (CONTINUE) v?imalust';
            RAISE e_initializing;
         END IF;

         /*
           ** Kustutame tabeli eelmise perioodi andmetest tühjaks ja hakkame otsast uuesti täitma.
         */
         DELETE FROM monthly_service_fees
               WHERE susg_ref_num IS NOT NULL AND station_param = 'KER';

         --COMMIT;
      ELSIF p_mode = c_recalculate_mode THEN   -- RECALC
         IF TO_CHAR (NVL (l_ker_proc_rec.financial_year, 0)) || TO_CHAR (NVL (l_ker_proc_rec.period_num, 0)) <>
                                                  TO_CHAR (l_salp_rec.financial_year)
                                                  || TO_CHAR (l_salp_rec.period_num) THEN
            l_message :=    'Protsess ei ole perioodile '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' veel käivitatud. Kasutage esmakordse käivituse (CALC) v?imalust';
            RAISE e_initializing;
         END IF;

         /*
           ** Kustutame tabeli andmetest tühjaks ja hakkame otsast uuesti täitma.
         */
         DELETE FROM monthly_service_fees
               WHERE susg_ref_num IS NOT NULL AND station_param = 'KER';

         --COMMIT;
      ELSIF p_mode = c_continue_mode THEN   -- CONTINUE
         IF TO_CHAR (NVL (l_ker_proc_rec.financial_year, 0)) || TO_CHAR (NVL (l_ker_proc_rec.period_num, 0)) <>
                                                  TO_CHAR (l_salp_rec.financial_year)
                                                  || TO_CHAR (l_salp_rec.period_num) THEN
            l_message :=    'Protsess ei ole perioodile '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' veel käivitatud. Kasutage esmakordse käivituse (CALC) v?imalust';
            RAISE e_initializing;
         END IF;
      ELSE
         l_message :=    'Tundmatu käivitusviis '
                      || p_mode
                      || '. Lubatud on '
                      || c_calculate_mode
                      || ', '
                      || c_recalculate_mode
                      || ', '
                      || c_continue_mode
                      || '.';
         RAISE e_initializing;
      END IF;

      /*
        ** Registreerime protsessi alguse.
        ** Parameetrina on kasutusel viimane MAAC, milline eelmisel käivitusel edukalt töödeldi.
        ** Continue korral on v?imalik sellest MAACist edasi minna, CALC/RECALC korral tuleks param väärtus nullida
        ** ja k?ik masterid esmakordselt/uuesti töödelda.
      */
      IF p_mode IN (c_calculate_mode   -- CALC
                                    , c_recalculate_mode   -- RECALC
                                                        ) THEN
         l_cur_param := NULL;
      ELSE
         l_cur_param := l_ker_proc_rec.module_params;
      END IF;

      --
      tbcis_common.register_process_start
                             (c_proc_module_ref   -- IN VARCHAR2
                             ,l_cur_param   -- p_parameter      IN VARCHAR2
                             ,c_module_name   -- p_module_desc    IN VARCHAR2
                             ,'N'   -- p_param_level    IN VARCHAR2 DEFAULT 'Y'  -- Kas protsess reg-itakse param tasemel?
                             ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                             ,l_salp_rec.financial_year   -- p_salp_year      IN NUMBER DEFAULT NULL
                             ,l_salp_rec.period_num   -- p_salp_month     IN NUMBER DEFAULT NULL
                             );
      --
      l_ker_proc_rec := tbcis_common.get_tbcis_process (c_proc_module_ref);   -- IN tbcis_processes.module_ref%TYPE
      l_last_proc_maac_ref := TO_NUMBER (l_ker_proc_rec.module_params);

      /*
        ** Leiame mobiili taseme KER teenused, milledel esineb päevade arvust s?ltumatu kuumaks > 0.
        ** Siin leitakse k?ik aruandeperioodis avatud teenuseperioodid. Maksustamise m?ttes pakuvad aga
        ** huvi ainult iga mobiili viimased teenusperioodid, kuna maksustamisele kuulub, kui teenus on perioodi
        ** l?pus avatud v?i suletud koos mobiiliga. Ülejäänud perioodid v?ib vaatamata jätta.
      */
      FOR l_stpe IN c_stpe (l_period_start_date, l_period_end_date) LOOP
         /*
           ** Kui on jätkukäivitus, siis juba töödeldud mastereid ei töödelda uuesti.
         */
         IF l_last_proc_maac_ref IS NULL OR l_stpe.maac_ref_num > l_last_proc_maac_ref THEN
            IF l_stpe.maac_ref_num <> NVL (l_maac_ref_num, -1) THEN
               /*
                 ** Andmete salvestamine masterite kaupa. Masterite vahetusel eelmise masteri read salvestatakse.
               */
               IF l_maac_ref_num IS NOT NULL THEN
                  proc_one_maac_mobker_serv_fees (l_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                 ,l_period_start_date   -- IN     DATE
                                                 ,l_period_end_date   -- IN     DATE
                                                 ,l_susg_ref_num_tab   -- IN     t_ref_num
                                                 ,l_sety_ref_num_tab   -- IN     t_ref_num
                                                 ,l_sept_type_tab   -- IN     t_char4
                                                 ,l_end_date_tab   -- IN     t_date
                                                 ,l_category_tab   -- IN     t_char1
                                                 ,l_ker_proc_rec   -- IN OUT tbcis_processes%ROWTYPE
                                                 );
               END IF;

               --
               l_count := 0;
               l_susg_ref_num_tab.DELETE;
               l_sety_ref_num_tab.DELETE;
               l_sept_type_tab.DELETE;
               l_end_date_tab.DELETE;
               l_category_tab.DELETE;
            END IF;

            /*
              ** Iga teenuse kohta loetakse ainult aruandeperioodi viimane teenusperiood. Kursoris on see
              ** periood järjestatud esimeseks. Ülejäänud teenusperioode v?ib ignoreerida.
            */
            IF l_stpe.susg_ref_num = l_last_susg_ref_num AND l_stpe.sety_ref_num = l_last_sety_ref_num THEN
               NULL;
            ELSE
               l_count := l_count + 1;
               l_susg_ref_num_tab (l_count) := l_stpe.susg_ref_num;
               l_sety_ref_num_tab (l_count) := l_stpe.sety_ref_num;
               l_sept_type_tab (l_count) := l_stpe.sept_type_code;
               l_end_date_tab (l_count) := l_stpe.end_date;
               l_category_tab (l_count) := l_stpe.CATEGORY;
            END IF;

            --
            l_maac_ref_num := l_stpe.maac_ref_num;
            l_last_susg_ref_num := l_stpe.susg_ref_num;
            l_last_sety_ref_num := l_stpe.sety_ref_num;
         END IF;
      END LOOP;

      /*
        ** Viimase PL/SQL tabelitesse loetud masteri teenused on veel töötlemata.
      */
      proc_one_maac_mobker_serv_fees (l_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                     ,l_period_start_date   -- IN     DATE
                                     ,l_period_end_date   -- IN     DATE
                                     ,l_susg_ref_num_tab   -- IN     t_ref_num
                                     ,l_sety_ref_num_tab   -- IN     t_ref_num
                                     ,l_sept_type_tab   -- IN     t_char4
                                     ,l_end_date_tab   -- IN     t_date
                                     ,l_category_tab   -- IN     t_char1
                                     ,l_ker_proc_rec   -- IN OUT tbcis_processes%ROWTYPE
                                     );
      /*
        ** Märgime KER teenuste töötlemise l?petatuks.
      */
      tbcis_common.register_process_end
                             (c_proc_module_ref   -- IN VARCHAR2
                             ,NULL   -- p_parameter      IN VARCHAR2
                             ,1   -- p_result         IN NUMBER
                             ,'N'   -- p_param_level    IN VARCHAR2 DEFAULT 'Y'  -- Kas protsess reg-itakse param tasemel?
                             ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                             );
      /*
        ** Registreerime l?petamise teate.
      */
      gen_bill.msg (c_module_ref
                   ,c_module_name
                   ,c_message_nr
                   , 'Protsess edukalt l?petanud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                   , 'Mode=' || p_mode
                   );
   EXCEPTION
      WHEN e_initializing THEN
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, l_message);
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Protsess l?petanud veaga ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                      , 'Mode=' || p_mode
                      );
      WHEN OTHERS THEN
         ROLLBACK;
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, SQLERRM);
         tbcis_common.register_process_end
                            (c_proc_module_ref   -- IN VARCHAR2
                            ,NULL   -- p_parameter      IN VARCHAR2
                            ,0   -- p_result         IN NUMBER
                            ,'N'   -- p_param_level    IN VARCHAR2 DEFAULT 'Y'  -- Kas protsess reg-itakse param tasemel?
                            ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                            );
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Protsess l?petanud veaga ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss')
                      , 'Mode=' || p_mode
                      );
   END chk_mobile_ker_service_fees;

   /***************************************************************************
   **
   **   Procedure Name :  Chk_Master_Service_Fees
   **
   **   Description : Protseduur päevade arvust s?ltumatute masteri teenuste
   **                 maksustamise andmete ettevalmistamiseks vahetabelis Monthly_Service_Fees.
   **
   ****************************************************************************/
   PROCEDURE chk_master_service_fees (
      p_mode  IN  VARCHAR2 DEFAULT c_calculate_mode   -- CALC/RECALC/CONTINUE
   ) IS
      --
      c_module_name        CONSTANT bcc_batch_messages.module_desc%TYPE := 'Check Master Service Fees';

      --
      CURSOR c_maas (
         p_period_start_date  IN  DATE
        ,p_period_end_date    IN  DATE
      ) IS
         SELECT   maas.ref_num
                 ,maas.sety_ref_num
                 ,sety.station_param
                 ,maas.end_date
                 ,maas.maac_ref_num
                 ,maac.bicy_cycle_code
             FROM master_account_services maas, service_types sety, account_statuses acst, master_accounts_v maac
            WHERE acst.acco_ref_num = maac.ref_num
              AND acst.acst_code = 'AC'
              AND NVL (acst.end_date, p_period_start_date) >= p_period_start_date
              AND acst.start_date <= p_period_end_date
              AND maas.maac_ref_num = maac.ref_num
              AND (   (    NVL (acst.end_date, p_period_end_date) >= p_period_end_date
                       AND p_period_end_date BETWEEN maas.start_date AND NVL (maas.end_date, p_period_end_date)
                      )
                   OR (acst.end_date < p_period_end_date AND TRUNC (maas.end_date) >= TRUNC (acst.end_date))
                  )
              AND sety.ref_num = maas.sety_ref_num
              AND sety.station_param IN ('KER', 'ARVE', 'TEAV')
              AND maac.bicy_cycle_code IS NOT NULL    -- CHG-6518
              AND maac.bicy_cycle_code NOT IN ('MN3') -- CHG-6518
         ORDER BY maas.maac_ref_num, sety.station_param;

      --
      CURSOR c_maac (
         p_period_start_date  IN  DATE
        ,p_period_end_date    IN  DATE
      ) IS
         SELECT maac.ref_num
               ,acst.end_date
               ,maac.bicy_cycle_code
           FROM master_accounts_v maac, account_statuses acst
          WHERE acst.acco_ref_num = maac.ref_num
            AND acst.acst_code = 'AC'
            AND NVL (acst.end_date, p_period_start_date) >= p_period_start_date
            AND acst.start_date <= p_period_end_date
            AND maac.bicy_cycle_code IS NOT NULL    -- CHG-6527
            AND maac.bicy_cycle_code NOT IN ('MN3') -- CHG-6527
      ;
      --
      CURSOR c_mosf (
         p_period_start_date  IN  DATE
        ,p_period_end_date    IN  DATE
      ) IS
         SELECT maac_ref_num
               ,maas_ref_num
           FROM monthly_service_fees
          WHERE period_start_date = p_period_start_date AND period_end_date = p_period_end_date AND susg_ref_num IS NULL;

      --
      l_chca_type_code              maac_charging_categories.chca_type_code%TYPE;
      l_rel_sety_tab                t_sety_ref;
      l_last_maac_ref_num           accounts.ref_num%TYPE;
      l_default_sety_rec            service_types%ROWTYPE;
      l_salp_rec                    sales_ledger_periods%ROWTYPE;
      l_period_start_date           DATE;
      l_period_end_date             DATE;
      l_bill_serv_maac_tab          t_ref_num;
      l_allow_billserv_ch           VARCHAR2 (1);
      l_events_exist                VARCHAR2 (1);
      l_inen_exists                 VARCHAR2 (1);
      l_price                       NUMBER;
      l_ins_count                   NUMBER;
      l_sety_ref_num_tab            t_ref_num;
      l_maac_ref_num_tab            t_ref_num;
      l_susg_ref_num_tab            t_ref_num;
      l_price_tab                   t_number;
      l_sept_type_code_tab          t_char4;
      l_sepv_ref_num_tab            t_ref_num;
      l_bill_cycle_tab              t_char3;
      l_channel_type_tab            t_char6;
      l_events_exist_tab            t_char1;
      l_inen_exists_tab             t_char1;
      l_bill_serv_chg_allowed_tab   t_char1;
      l_station_param_tab           t_char25;
      l_maas_ref_num_tab            t_ref_num;
      l_process_rec                 tbcis_processes%ROWTYPE;
      l_message                     bcc_batch_messages.MESSAGE_TEXT%TYPE;
      l_exis_maac_ref_num_tab       t_ref_num;
      l_exis_maas_ref_num_tab       t_ref_num;
      l_chk_maas_ref_num_tab        t_ref_num;
      l_chk_maac_ref_num_tab        t_ref_num;
      l_idx                         NUMBER;
      l_skip                        BOOLEAN;
      l_end_date_tab                t_date;
      l_category_tab                t_char1;
      l_chca_type_code_tab          t_char3;
      l_mosf_rec                    monthly_service_fees%ROWTYPE;
      l_maac_idx                    NUMBER;   -- CHG-1379
      
      l_bill_start             DATE; 
      l_bill_cutoff            DATE;
      l_prodn_date             DATE;
      l_success                BOOLEAN;
      
      
      --
      e_initializing                EXCEPTION;
   BEGIN
      gen_bill.msg (c_module_ref
                   ,c_module_name
                   ,c_message_nr
                   , 'Protsess käivitatud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                   , 'Mode=' || p_mode
                   );
      /*
        ** Leiame vaikimisi arve teenuse, mida kasutada Masterite korral, kellel pole avatud arve teenust.
      */
      l_default_sety_rec := service.get_sety_row_by_service_name (c_default_bill_service);
      /*
        ** Leiame vaadeldava arveldusperioodi = esimese avatud perioodi info.
      */
      l_salp_rec := gen_bill.first_open_salp_rec;
      l_period_start_date := l_salp_rec.start_date;
      l_period_end_date := TRUNC (l_salp_rec.end_date) + 1 - c_one_second;
      
      
      ----- siia
      BCC_Misc_Processing.Set_Cut_Off_Date     (l_success      
                                           ,null
                                           ,l_bill_start             -- OUT DATE
                                           ,l_bill_cutoff            -- OUT DATE 23:59:59
                                           ,l_prodn_date             -- OUT DATE
                                           );
      

      --
      IF SYSDATE <= l_prodn_date THEN
         l_message := 'Protsessi ei saa käivitada jooksva perioodi kohta';
         RAISE e_initializing;
      END IF;

      /*
        ** Leiame vastava TBCIS protsessi kirje
      */
      l_process_rec :=
         tbcis_common.get_tbcis_process_for_param
                                                (c_module_ref   -- IN tbcis_processes.module_ref%TYPE
                                                ,c_master_serv_parameter   -- IN tbcis_processes.module_params%TYPE -- MAAC
                                                );

      --
      IF p_mode = c_calculate_mode THEN   -- CALC
         IF     NVL (l_process_rec.financial_year, 0) = l_salp_rec.financial_year
            AND NVL (l_process_rec.period_num, 0) = l_salp_rec.period_num THEN
            l_message :=    'Protsess on perioodile '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' juba käivitatud. Kasutage ümberhindamise (RECALC) v?i jätkamise (CONTINUE) v?imalust';
            RAISE e_initializing;
         END IF;

         /*
           ** Kustutame tabeli eelmise perioodi andmetest tühjaks ja hakkame otsast uuesti täitma.
         */
         DELETE FROM monthly_service_fees
               WHERE susg_ref_num IS NULL;

         --COMMIT;
      ELSIF p_mode = c_recalculate_mode THEN   -- RECALC
         IF TO_CHAR (NVL (l_process_rec.financial_year, 0)) || TO_CHAR (NVL (l_process_rec.period_num, 0)) <>
                                                  TO_CHAR (l_salp_rec.financial_year)
                                                  || TO_CHAR (l_salp_rec.period_num) THEN
            l_message :=    'Protsess ei ole perioodile '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' veel käivitatud. Kasutage esmakordse käivituse (CALC) v?imalust';
            RAISE e_initializing;
         END IF;

         /*
           ** Kustutame tabeli andmetest tühjaks ja hakkame otsast uuesti täitma.
         */
         DELETE FROM monthly_service_fees
               WHERE susg_ref_num IS NULL;

         --COMMIT;
      ELSIF p_mode = c_continue_mode THEN   -- CONTINUE
         IF TO_CHAR (NVL (l_process_rec.financial_year, 0)) || TO_CHAR (NVL (l_process_rec.period_num, 0)) <>
                                                  TO_CHAR (l_salp_rec.financial_year)
                                                  || TO_CHAR (l_salp_rec.period_num) THEN
            l_message :=    'Protsess ei ole perioodile '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' veel käivitatud. Kasutage esmakordse käivituse (CALC) v?imalust';
            RAISE e_initializing;
         END IF;

         /*
           ** Kontrollime, et protsess on l?ppenud vigaselt
         */
         IF l_process_rec.end_code = c_ok_end_code THEN
            l_message :=    'Protsess on perioodis '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' edukalt l?petanud - pole midagi töödelda';
            RAISE e_initializing;
         END IF;

         /*
           ** Tabel peaks olema eelneva käivitusega vanadest andmetest juba tühjendatud.
           ** Jätkamise korral (CONTINUE) tuleks välja lugeda tabelis olevad andmed, et saaks kirje lisamise vajadust kontrollida.
         */
         OPEN c_mosf (l_period_start_date, l_period_end_date);

         FETCH c_mosf
         BULK COLLECT INTO l_exis_maac_ref_num_tab
               ,l_exis_maas_ref_num_tab;

         CLOSE c_mosf;

         /*
           ** Kanname välja loetud andmed PL/SQL tabelitesse selliste indeksitega, et kirjete olemasolu oleks
           ** v?imalikult lihtne kontrollida. 1) reaalsed teenused indexeeritult maas_ref_num järgi,
           ** 2) vaikimisi arve teenused indekseeritult maac_ref_num järgi.
         */
         l_idx := l_exis_maac_ref_num_tab.FIRST;

         WHILE l_idx IS NOT NULL LOOP
            IF l_exis_maas_ref_num_tab (l_idx) IS NOT NULL THEN
               l_chk_maas_ref_num_tab (l_exis_maas_ref_num_tab (l_idx)) := l_exis_maas_ref_num_tab (l_idx);
            ELSE
               l_maac_idx := TO_NUMBER (SUBSTR (TO_CHAR (l_exis_maac_ref_num_tab (l_idx))
                                               ,1
                                               , LENGTH (TO_CHAR (l_exis_maac_ref_num_tab (l_idx))) - 3
                                               )
                                       );   -- CHG-1379
               l_chk_maac_ref_num_tab (l_maac_idx) := l_exis_maac_ref_num_tab (l_idx);
            END IF;

            --
            l_idx := l_exis_maac_ref_num_tab.NEXT (l_idx);
         END LOOP;

         --
         l_exis_maac_ref_num_tab.DELETE;
         l_exis_maas_ref_num_tab.DELETE;
      ELSE
         l_message :=    'Tundmatu käivitusviis '
                      || p_mode
                      || '. Lubatud on '
                      || c_calculate_mode
                      || ', '
                      || c_recalculate_mode
                      || ', '
                      || c_continue_mode
                      || '.';
         RAISE e_initializing;
      END IF;

      /*
        ** Registreerime protsessi alguse.
      */
      tbcis_common.register_process_start
                             (c_module_ref   -- IN VARCHAR2
                             ,c_master_serv_parameter   -- p_parameter      IN VARCHAR2
                             ,c_module_name   -- p_module_desc    IN VARCHAR2
                             ,'Y'   -- p_param_level    IN VARCHAR2 DEFAULT 'Y'  -- Kas protsess reg-itakse param tasemel?
                             ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                             ,l_salp_rec.financial_year   -- p_salp_year      IN NUMBER DEFAULT NULL
                             ,l_salp_rec.period_num   -- p_salp_month     IN NUMBER DEFAULT NULL
                             );

      /*
        ** 1. Avatud Masterite teenused, millised on perioodi l?pu seisuga avatud.
        ** 2. Perioodi jooksul suletud Masterite teenused, millised on suletud samal päeval koos Masteriga.
      */
      FOR l_maas IN c_maas (l_period_start_date, l_period_end_date) LOOP
         IF l_maas.maac_ref_num <> NVL (l_last_maac_ref_num, 0) THEN
            /*
              ** Andmete salvestamine 1 masteri kaupa. PL/SQL tabelid tühjendatakse järgmise masteri andmete kogumiseks.
            */
            IF l_maac_ref_num_tab.EXISTS (1) THEN
               ins_monthly_service_fees (l_maac_ref_num_tab   -- IN OUT t_ref_num
                                        ,l_susg_ref_num_tab   -- IN OUT t_ref_num
                                        ,l_sety_ref_num_tab   -- IN OUT t_ref_num
                                        ,l_price_tab   -- IN OUT t_number
                                        ,l_sept_type_code_tab   -- IN OUT t_char4
                                        ,l_bill_cycle_tab   -- IN OUT t_char3
                                        ,l_channel_type_tab   -- IN OUT t_char6
                                        ,l_events_exist_tab   -- IN OUT t_char1
                                        ,l_inen_exists_tab   -- IN OUT t_char1
                                        ,l_bill_serv_chg_allowed_tab   -- IN OUT t_char1
                                        ,l_station_param_tab   -- IN OUT t_char25
                                        ,l_maas_ref_num_tab   -- IN OUT t_ref_num
                                        ,l_end_date_tab   -- IN OUT t_date
                                        ,l_category_tab   -- IN OUT t_char1
                                        ,l_chca_type_code_tab   -- IN OUT t_char3
                                        ,l_period_start_date   -- IN     DATE
                                        ,l_period_end_date   -- IN     DATE
                                        );
               --
               --COMMIT;
            END IF;

            --
            l_ins_count := 0;
            l_rel_sety_tab.DELETE;
            l_chca_type_code := NULL;
         END IF;

         --
         l_skip := FALSE;

         IF p_mode = c_continue_mode AND l_chk_maas_ref_num_tab.EXISTS (l_maas.ref_num) THEN
            l_skip := TRUE;
         END IF;

         --
         IF NOT l_skip THEN
            chk_one_maac_service_fee (l_maas.maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                     ,l_maas.ref_num   -- IN     master_account_services.ref_num%TYPE
                                     ,l_maas.sety_ref_num   -- IN     service_types.ref_num%TYPE
                                     ,l_maas.station_param   -- IN     service_types.station_param%TYPE
                                     ,LEAST (l_period_end_date, NVL (l_maas.end_date, l_period_end_date))   -- p_end_date          IN     DATE
                                     ,l_period_start_date   -- IN     DATE
                                     ,l_period_end_date   -- IN     DATE
                                     ,l_chca_type_code   -- IN OUT maac_charging_categories.chca_type_code%TYPE
                                     ,l_rel_sety_tab   -- IN OUT t_sety_ref
                                     ,l_allow_billserv_ch   --    OUT VARCHAR2
                                     ,l_events_exist   --    OUT VARCHAR2
                                     ,l_inen_exists   --    OUT VARCHAR2
                                     ,l_price   --    OUT VARCHAR2
                                     );
            l_ins_count := l_ins_count + 1;
            l_maac_ref_num_tab (l_ins_count) := l_maas.maac_ref_num;
            l_sety_ref_num_tab (l_ins_count) := l_maas.sety_ref_num;
            l_price_tab (l_ins_count) := NVL (l_price, 0);
            l_susg_ref_num_tab (l_ins_count) := NULL;
            l_sept_type_code_tab (l_ins_count) := NULL;
            l_bill_cycle_tab (l_ins_count) := l_maas.bicy_cycle_code;
            l_channel_type_tab (l_ins_count) := NULL;
            l_events_exist_tab (l_ins_count) := l_events_exist;
            l_inen_exists_tab (l_ins_count) := l_inen_exists;
            l_bill_serv_chg_allowed_tab (l_ins_count) := l_allow_billserv_ch;
            l_station_param_tab (l_ins_count) := l_maas.station_param;
            l_maas_ref_num_tab (l_ins_count) := l_maas.ref_num;
            l_end_date_tab (l_ins_count) := l_maas.end_date;
            l_category_tab (l_ins_count) := NULL;
            l_chca_type_code_tab (l_ins_count) := l_chca_type_code;
         END IF;

         /*
           ** Kui on ARVE teenus, siis salvestame masteri ref-i PL/SQL tabelisse.
         */
         IF l_maas.station_param = 'ARVE' THEN
            l_maac_idx := TO_NUMBER (SUBSTR (TO_CHAR (l_maas.maac_ref_num), 1
                                            , LENGTH (TO_CHAR (l_maas.maac_ref_num)) - 3)
                                    );   -- CHG-1379
            l_bill_serv_maac_tab (l_maac_idx) := l_maas.maac_ref_num;
         END IF;

         --
         l_last_maac_ref_num := l_maas.maac_ref_num;
      END LOOP;

      /*
        ** Viimase masteri andmed on veel salvestamata.
        ** Ins_Monthly_Service_Fees: Salvestab andmed PL/SQL tabelitest andmebaasi ja tühjendab seejärel
        ** PL/SQL tabelid lähteandmetest.
      */
      IF l_ins_count > 0 THEN
         ins_monthly_service_fees (l_maac_ref_num_tab   -- IN OUT t_ref_num
                                  ,l_susg_ref_num_tab   -- IN OUT t_ref_num
                                  ,l_sety_ref_num_tab   -- IN OUT t_ref_num
                                  ,l_price_tab   -- IN OUT t_number
                                  ,l_sept_type_code_tab   -- IN OUT t_char4
                                  ,l_bill_cycle_tab   -- IN OUT t_char3
                                  ,l_channel_type_tab   -- IN OUT t_char6
                                  ,l_events_exist_tab   -- IN OUT t_char1
                                  ,l_inen_exists_tab   -- IN OUT t_char1
                                  ,l_bill_serv_chg_allowed_tab   -- IN OUT t_char1
                                  ,l_station_param_tab   -- IN OUT t_char25
                                  ,l_maas_ref_num_tab   -- IN OUT t_ref_num
                                  ,l_end_date_tab   -- IN OUT t_date
                                  ,l_category_tab   -- IN OUT t_char1
                                  ,l_chca_type_code_tab   -- IN OUT t_char3
                                  ,l_period_start_date   -- IN     DATE
                                  ,l_period_end_date   -- IN     DATE
                                  );
         --
         --COMMIT;
      END IF;

      /*
        ** Masteritele, kellel puudub ARVE teenus, tuleb proovida maksustada vaikimisi arveteenust.
        ** Selleks loeme järgnevalt välja k?ik perioodis aktiivsed masterid ja viskame välja need,
        ** kellele arve teenus juba leitud.
      */
      FOR l_maac IN c_maac (l_period_start_date, l_period_end_date) LOOP
         l_maac_idx := TO_NUMBER (SUBSTR (TO_CHAR (l_maac.ref_num), 1, LENGTH (TO_CHAR (l_maac.ref_num)) - 3));   -- CHG-1379

         --
         IF NOT l_bill_serv_maac_tab.EXISTS (l_maac_idx) THEN
            l_chca_type_code := NULL;
            l_rel_sety_tab.DELETE;
            --
            l_skip := FALSE;

            IF p_mode = c_continue_mode AND l_chk_maac_ref_num_tab.EXISTS (l_maac_idx) THEN   -- CHG-1379
               l_skip := TRUE;
            END IF;

            --
            IF NOT l_skip THEN
               chk_one_maac_service_fee (l_maac.ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                        ,NULL   -- IN     master_account_services.ref_num%TYPE
                                        ,l_default_sety_rec.ref_num   -- IN     service_types.ref_num%TYPE
                                        ,l_default_sety_rec.station_param   -- IN     service_types.station_param%TYPE
                                        ,LEAST (l_period_end_date, NVL (l_maac.end_date, l_period_end_date))   -- p_end_date          IN     DATE
                                        ,l_period_start_date   -- IN     DATE
                                        ,l_period_end_date   -- IN     DATE
                                        ,l_chca_type_code   -- IN OUT maac_charging_categories.chca_type_code%TYPE
                                        ,l_rel_sety_tab   -- IN OUT t_sety_ref
                                        ,l_allow_billserv_ch   --    OUT VARCHAR2
                                        ,l_events_exist   --    OUT VARCHAR2
                                        ,l_inen_exists   --    OUT VARCHAR2
                                        ,l_price   --    OUT VARCHAR2
                                        );
               --
               l_mosf_rec := NULL;
               l_mosf_rec.maac_ref_num := l_maac.ref_num;
               l_mosf_rec.sety_ref_num := l_default_sety_rec.ref_num;
               l_mosf_rec.period_start_date := l_period_start_date;
               l_mosf_rec.period_end_date := l_period_end_date;
               l_mosf_rec.price := NVL (l_price, 0);
               l_mosf_rec.bill_cycle := l_maac.bicy_cycle_code;
               l_mosf_rec.station_param := l_default_sety_rec.station_param;
               l_mosf_rec.events_exist := l_events_exist;
               l_mosf_rec.inen_exists := l_inen_exists;
               l_mosf_rec.bill_serv_chg_allowed := l_allow_billserv_ch;
               l_mosf_rec.end_date := l_maac.end_date;
               l_mosf_rec.chca_type_code := l_chca_type_code;
               --
               ins_monthly_service_fees_rec (l_mosf_rec);
               --COMMIT;
            END IF;
         END IF;
      END LOOP;

      /*
        ** Märgime protsessi l?pu.
      */
      tbcis_common.register_process_end
                             (c_module_ref   -- IN VARCHAR2
                             ,c_master_serv_parameter   -- p_parameter      IN VARCHAR2
                             ,1   -- p_result         IN NUMBER
                             ,'Y'   -- p_param_level    IN VARCHAR2 DEFAULT 'Y'  -- Kas protsess reg-itakse param tasemel?
                             ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                             );
      /*
        ** Registreerime l?petamise teate.
      */
      gen_bill.msg (c_module_ref
                   ,c_module_name
                   ,c_message_nr
                   , 'Protsess edukalt l?petanud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                   , 'Mode=' || p_mode
                   );
   EXCEPTION
      WHEN e_initializing THEN
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, l_message);
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Protsess l?petanud veaga ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                      , 'Mode=' || p_mode
                      );
      WHEN OTHERS THEN
         ROLLBACK;
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, SQLERRM);
         tbcis_common.register_process_end
                            (c_module_ref   -- IN VARCHAR2
                            ,c_master_serv_parameter   -- p_parameter      IN VARCHAR2
                            ,0   -- p_result         IN NUMBER
                            ,'Y'   -- p_param_level    IN VARCHAR2 DEFAULT 'Y'  -- Kas protsess reg-itakse param tasemel?
                            ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                            );
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Protsess l?petanud veaga ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                      , 'Mode=' || p_mode
                      );
   END chk_master_service_fees;

   /***************************************************************************
   **
   **   Procedure Name :  Invoice_Service_Fees
   **
   **   Description : Protseduur päevade arvust s?ltumatute teenuste tasude
   **                 kandmiseks arvetele.
   **
   ****************************************************************************/
   PROCEDURE invoice_service_fees (
      p_bicy_cycle_code  IN  bill_cycles.cycle_code%TYPE DEFAULT NULL   -- CHG-1379
   ) IS
      --
      c_module_name        CONSTANT bcc_batch_messages.module_desc%TYPE := 'Invoice Service Fees';

      --
      CURSOR c_mosf (
         p_period_start_date  IN  DATE
        ,p_period_end_date    IN  DATE
      ) IS
         SELECT   mosf.ROWID
                 ,mosf.*
             FROM monthly_service_fees mosf
            WHERE period_start_date = p_period_start_date
              AND period_end_date = p_period_end_date
              AND processed = 'N'
              AND NVL (bill_cycle, '***') = NVL (p_bicy_cycle_code, NVL (bill_cycle, '***'))   -- CHG-1379
         ORDER BY bill_cycle, maac_ref_num, susg_ref_num, station_param;

      --
      l_salp_rec                    sales_ledger_periods%ROWTYPE;
      l_period_start_date           DATE;
      l_period_end_date             DATE;
      l_last_bill_cycle             bill_cycles.cycle_code%TYPE;
      l_allowed                     BOOLEAN;
      l_invoicing_allowed           BOOLEAN;
      l_sety_ref_num_tab            t_sety_ref;
      l_last_maac_ref_num           accounts.ref_num%TYPE;
      l_discount_type               fixed_charge_types.discount_type%TYPE;
      l_invo_rec                    invoices%ROWTYPE;
      l_invo_ref_num                invoices.ref_num%TYPE;
      l_message                     bcc_batch_messages.MESSAGE_TEXT%TYPE;
      l_success                     BOOLEAN;
      l_error_maac_tab              t_ref_num;
      l_success_count               NUMBER;
      l_error_count                 NUMBER;
      l_total_error_count           NUMBER;
      l_process_result              NUMBER;
      l_maac_idx                    NUMBER;   -- CHG-1379
      
      l_bill_start             DATE; 
      l_bill_cutoff            DATE;
      l_prodn_date             DATE;
      
      --
      e_processing                  EXCEPTION;
      e_skip_maac                   EXCEPTION;
      e_initializing                EXCEPTION;
   BEGIN
      gen_bill.msg (c_module_ref
                   ,c_module_name
                   ,c_message_nr
                   , 'Protsess käivitatud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '.'
                   );
      /*
        ** Leiame vaadeldava arveldusperioodi = esimese avatud perioodi info.
      */
      l_salp_rec := gen_bill.first_open_salp_rec;
      l_period_start_date := l_salp_rec.start_date;
      l_period_end_date := TRUNC (l_salp_rec.end_date) + 1 - c_one_second;


     --- siia
     BCC_Misc_Processing.Set_Cut_Off_Date     (l_success      
                                           ,null
                                           ,l_bill_start             -- OUT DATE
                                           ,l_bill_cutoff            -- OUT DATE 23:59:59
                                           ,l_prodn_date             -- OUT DATE
                                           );

      --
      IF SYSDATE <= l_prodn_date THEN
         l_message := 'Protsessi ei saa käivitada jooksva perioodi kohta';
         RAISE e_initializing;
      END IF;

      /*
        ** Registreerime protsessi alguse.
      */
      tbcis_common.register_process_start
                             (c_module_ref   -- IN VARCHAR2
                             ,c_invoicing_parameter   -- p_parameter      IN VARCHAR2
                             ,c_module_name   -- p_module_desc    IN VARCHAR2
                             ,'Y'   -- p_param_level    IN VARCHAR2 DEFAULT 'Y'  -- Kas protsess reg-itakse param tasemel?
                             ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                             ,l_salp_rec.financial_year   -- p_salp_year      IN NUMBER DEFAULT NULL
                             ,l_salp_rec.period_num   -- p_salp_month     IN NUMBER DEFAULT NULL
                             );
      /*
        ** Leiame päevade arvust s?ltumatute kuutasude soodustuse tüübi.
      */
      l_discount_type := icalculate_discounts.find_discount_type ('N'   -- p_pro_rata       IN VARCHAR2
                                                                ,'Y'   -- p_regular_charge IN VARCHAR2
                                                                ,'N'   -- p_once_off       IN VARCHAR2
                                                                );
      --
      l_total_error_count := 0;

      FOR l_mosf IN c_mosf (l_period_start_date, l_period_end_date) LOOP
         BEGIN
            /*
              ** Arveldustsükli vahetus. Eelmisel arveldustsüklil määrata teenuse makstete l?petamine, uuel tsüklil alustamine.
            */
            IF NVL (l_mosf.bill_cycle, '*') <> NVL (l_last_bill_cycle, '*') THEN
               IF l_last_bill_cycle IS NOT NULL THEN
                  gen_bill.msg (c_module_ref
                               ,c_module_name
                               ,c_message_nr
                               , 'Arveldustsükkel ' || l_last_bill_cycle || ' töödeldud. '
                               ,    'Edukalt töödeldud '
                                 || TO_CHAR (l_success_count)
                                 || ' kirjet, vigased '
                                 || TO_CHAR (l_error_count)
                                 || ' kirjet.'
                               );

                  IF l_error_count <= 0 THEN
                     UPDATE bill_cycles
                        SET end_service_fees = SYSDATE
                      WHERE cycle_code = l_last_bill_cycle;
                  END IF;
               END IF;

               --
               UPDATE bill_cycles
                  SET start_service_fees = SYSDATE
                WHERE cycle_code = l_mosf.bill_cycle;

               --
               --COMMIT;
               --
               l_success_count := 0;
               l_error_count := 0;
            END IF;

            --
            IF NVL (l_last_maac_ref_num, 0) <> l_mosf.maac_ref_num THEN
               l_sety_ref_num_tab.DELETE;
               l_invo_rec := NULL;
               l_invo_ref_num := NULL;
            END IF;

            /*
              ** Kontrollime, kas sellele masterile on registreeritud arve avamise viga ->
              ** kui jah, siis v?ib selle masteri k?ik kirjed vahele jätta.
            */
            l_maac_idx := TO_NUMBER (SUBSTR (TO_CHAR (l_mosf.maac_ref_num), 1
                                            , LENGTH (TO_CHAR (l_mosf.maac_ref_num)) - 3)
                                    );   -- CHG-1379

            IF l_error_maac_tab.EXISTS (l_maac_idx) THEN
               RAISE e_skip_maac;
            END IF;

            --
            l_invoicing_allowed := FALSE;

            IF l_mosf.susg_ref_num IS NOT NULL AND l_mosf.station_param = 'KER' AND l_mosf.price > 0 THEN
               /*
                 ** Mobiili taseme KER teenused. Kui on sündmusi perioodi arvetel, siis v?ib maksustada.
                 ** Kui sündmusi pole, siis uuesti üle kontrollida, kas on vahepeal tekkinud.
               */
               IF NVL (l_mosf.events_exist, 'N') <> 'Y' THEN
                  l_allowed :=
                     chk_events_on_period_invo (l_mosf.maac_ref_num   -- IN accounts.ref_num%TYPE
                                               ,l_period_start_date   -- IN DATE
                                               ,l_period_end_date   -- IN DATE
                                               ,l_mosf.susg_ref_num   -- IN subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                               );

                  IF l_allowed THEN
                     l_mosf.events_exist := 'Y';
                  END IF;
               END IF;

               --
               IF l_mosf.events_exist = 'Y' THEN
                  l_invoicing_allowed := TRUE;
               END IF;
            ELSIF l_mosf.susg_ref_num IS NULL THEN
               /*
                 ** Masterkonto teenused.
               */
               IF l_mosf.station_param = 'KER' AND l_mosf.price > 0 THEN
                  IF NVL (l_mosf.events_exist, 'N') <> 'Y' THEN
                     l_allowed :=
                        chk_maac_service_chg_rules (l_mosf.maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                                   ,l_mosf.sety_ref_num   -- IN     service_types.ref_num%TYPE
                                                   ,l_mosf.station_param   -- IN     service_types.station_param%TYPE
                                                   ,l_period_start_date   -- IN     DATE
                                                   ,l_period_end_date   -- IN     DATE
                                                   ,l_sety_ref_num_tab   -- IN OUT t_sety_ref
                                                   );

                     IF l_allowed THEN
                        l_mosf.events_exist := 'Y';
                     END IF;
                  END IF;

                  --
                  IF l_mosf.events_exist = 'Y' THEN
                     l_invoicing_allowed := TRUE;
                  END IF;
               ELSIF l_mosf.station_param = 'ARVE' THEN
                  /*
                    ** Arve teenuste korral kontrollime ka 0-se hinnaga kirjeid, kuna sellest v?ib s?ltuda teavitusteenuste maksustamine.
                  */
                  IF l_mosf.inen_exists = 'Y' THEN
                     l_sety_ref_num_tab (l_mosf.sety_ref_num) := l_mosf.sety_ref_num;
                  ELSE
                     l_allowed :=
                        chk_maac_service_chg_rules (l_mosf.maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                                   ,l_mosf.sety_ref_num   -- IN     service_types.ref_num%TYPE
                                                   ,l_mosf.station_param   -- IN     service_types.station_param%TYPE
                                                   ,l_period_start_date   -- IN     DATE
                                                   ,l_period_end_date   -- IN     DATE
                                                   ,l_sety_ref_num_tab   -- IN OUT t_sety_ref
                                                   );

                     IF l_allowed THEN
                        l_mosf.inen_exists := 'Y';
                     END IF;
                  END IF;

                  --
                  IF l_mosf.inen_exists = 'Y' AND l_mosf.price > 0 THEN
                     l_invoicing_allowed := TRUE;
                  END IF;
               ELSIF l_mosf.station_param = 'TEAV' THEN
                  /*
                    ** Teavituse teenuste korral korrigeerime maksustamise lubatavust vastavalt arve teenuste
                    ** maksustamise lubatavuse muutustele.
                  */
                  IF NVL (l_mosf.bill_serv_chg_allowed, 'N') <> 'Y' THEN
                     l_allowed :=
                        chk_maac_service_chg_rules (l_mosf.maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                                   ,l_mosf.sety_ref_num   -- IN     service_types.ref_num%TYPE
                                                   ,l_mosf.station_param   -- IN     service_types.station_param%TYPE
                                                   ,l_period_start_date   -- IN     DATE
                                                   ,l_period_end_date   -- IN     DATE
                                                   ,l_sety_ref_num_tab   -- IN OUT t_sety_ref
                                                   );

                     IF l_allowed THEN
                        l_mosf.bill_serv_chg_allowed := 'Y';
                     END IF;
                  END IF;

                  --
                  IF l_mosf.bill_serv_chg_allowed = 'Y' AND l_mosf.price > 0 THEN
                     l_invoicing_allowed := TRUE;
                  END IF;
               END IF;
            END IF;

            /*
              ** Kui maksustamine lubatud, siis kanname järgnevalt teenuse tasud ja soodustused arvele.
            */
            IF l_invoicing_allowed THEN
               IF l_invo_ref_num IS NULL THEN
                  get_invoice (l_mosf.maac_ref_num   -- IN     accounts.ref_num%TYPE
                              ,l_period_start_date   -- IN     DATE
                              ,l_success   -- OUT BOOLEAN
                              ,l_message   -- OUT VARCHAR2
                              ,l_invo_rec   -- OUT invoices%ROWTYPE
                              );

                  /*
                    ** Kui viga arve avamisel, siis kantakse MAAC vigaste maacide tabelisse -> pole m?tet üritada selle
                    ** maaci ülejäänud teenuseid ka arveldada.
                  */
                  IF NOT l_success THEN
                     l_maac_idx := TO_NUMBER (SUBSTR (TO_CHAR (l_mosf.maac_ref_num)
                                                     ,1
                                                     , LENGTH (TO_CHAR (l_mosf.maac_ref_num)) - 3
                                                     )
                                             );   -- CHG-1379
                     l_error_maac_tab (l_maac_idx) := l_mosf.maac_ref_num;
                     RAISE e_processing;
                  END IF;

                  --
                  l_invo_ref_num := l_invo_rec.ref_num;
               END IF;

               --
               IF l_mosf.susg_ref_num IS NOT NULL THEN
                  invoice_mobile_service (l_mosf.susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                         ,l_mosf.maac_ref_num   -- IN     accounts.ref_num%TYPE
                                         ,l_mosf.sety_ref_num   -- IN     service_types.ref_num%TYPE
                                         ,LEAST (NVL (l_mosf.end_date, l_period_end_date), l_period_end_date)   -- p_end_date         IN     DATE
                                         ,l_mosf.channel_type   -- IN     price_lists.channel_type%TYPE
                                         ,l_mosf.sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                         ,l_mosf.CATEGORY   -- IN     serv_package_types.category%TYPE
                                         ,l_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                         ,l_discount_type   -- IN     VARCHAR2
                                         ,l_success   --    OUT BOOLEAN
                                         ,l_message   --    OUT varchar2
                                         );
               ELSE
                  invoice_master_service (l_mosf.maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                         ,l_mosf.maas_ref_num   -- IN     master_account_services.ref_num%TYPE
                                         ,l_mosf.sety_ref_num   -- IN     service_types.ref_num%TYPE
                                         ,LEAST (NVL (l_mosf.end_date, l_period_end_date), l_period_end_date)   -- p_end_date       IN     DATE
                                         ,l_mosf.chca_type_code   -- IN OUT maac_charging_categories.chca_type_code%TYPE
                                         ,l_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                         ,l_success   -- OUT BOOLEAN
                                         ,l_message   -- OUT varchar2
                                         );
               END IF;

               --
               IF NOT l_success THEN
                  RAISE e_processing;
               END IF;

               --
               l_mosf.processed := 'Y';
            ELSE
               l_mosf.processed := 'S';
            END IF;

            --
            UPDATE monthly_service_fees
               SET processed = l_mosf.processed
                  ,events_exist = l_mosf.events_exist
                  ,inen_exists = l_mosf.inen_exists
                  ,bill_serv_chg_allowed = l_mosf.bill_serv_chg_allowed
             WHERE ROWID = l_mosf.ROWID;

            --
            --COMMIT;
            l_success_count := l_success_count + 1;
            l_last_bill_cycle := l_mosf.bill_cycle;
            l_last_maac_ref_num := l_mosf.maac_ref_num;
         EXCEPTION
            WHEN e_processing THEN
               ROLLBACK;
               l_error_count := l_error_count + 1;
               l_total_error_count := l_total_error_count + 1;
               gen_bill.msg (c_module_ref, c_module_name, c_message_nr, l_message);

               --
               UPDATE monthly_service_fees
                  SET events_exist = l_mosf.events_exist
                     ,inen_exists = l_mosf.inen_exists
                     ,bill_serv_chg_allowed = l_mosf.bill_serv_chg_allowed
                WHERE ROWID = l_mosf.ROWID;

               --
               --COMMIT;
               l_last_bill_cycle := l_mosf.bill_cycle;
               l_last_maac_ref_num := l_mosf.maac_ref_num;
            WHEN e_skip_maac THEN
               l_error_count := l_error_count + 1;
               l_total_error_count := l_total_error_count + 1;
               l_last_bill_cycle := l_mosf.bill_cycle;
               l_last_maac_ref_num := l_mosf.maac_ref_num;
         END;
      END LOOP;

      /*
        ** Märgime viimase läbitud arveldustsükli töödelduks.
      */
      IF l_last_bill_cycle IS NOT NULL THEN
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Arveldustsükkel ' || l_last_bill_cycle || ' töödeldud. '
                      ,    'Edukalt töödeldud '
                        || TO_CHAR (l_success_count)
                        || ' kirjet, vigased '
                        || TO_CHAR (l_error_count)
                        || ' kirjet.'
                      );

         IF l_error_count <= 0 THEN
            UPDATE bill_cycles
               SET end_service_fees = SYSDATE
             WHERE cycle_code = l_last_bill_cycle;

            --
            --COMMIT;
         END IF;
      END IF;

      /*
        ** CHG-873: Märgime töötluse aja nendele arveldustsüklitele, mille jaoks ei eksisteerinud ühtegi vastavat
        ** tüüpi teenustasu.
      */
      UPDATE bill_cycles
         SET start_service_fees = SYSDATE
            ,end_service_fees = SYSDATE
       WHERE (start_service_fees IS NULL OR start_service_fees < TRUNC (SYSDATE, 'MM'));

      --
      --COMMIT;
      /* End CHG-873 */
      gen_bill.msg (c_module_ref
                   ,c_module_name
                   ,c_message_nr
                   , 'Protsess l?petanud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                   );

      /*
        ** Märgime protsessi l?pu.
      */
      IF l_total_error_count > 0 THEN
         l_process_result := 0;   -- Error
      ELSE
         l_process_result := 1;   -- OK
      END IF;

      --
      tbcis_common.register_process_end
                             (c_module_ref   -- IN VARCHAR2
                             ,c_invoicing_parameter   -- p_parameter      IN VARCHAR2
                             ,l_process_result   -- p_result         IN NUMBER
                             ,'Y'   -- p_param_level    IN VARCHAR2 DEFAULT 'Y'  -- Kas protsess reg-itakse param tasemel?
                             ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                             );
   EXCEPTION
      WHEN e_initializing THEN
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, l_message);
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Protsess l?petanud veaga ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                      );
      WHEN OTHERS THEN
         ROLLBACK;
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, SQLERRM);
         tbcis_common.register_process_end
                            (c_module_ref   -- IN VARCHAR2
                            ,c_invoicing_parameter   -- p_parameter      IN VARCHAR2
                            ,0   -- p_result         IN NUMBER
                            ,'Y'   -- p_param_level    IN VARCHAR2 DEFAULT 'Y'  -- Kas protsess reg-itakse param tasemel?
                            ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                            );
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Protsess l?petanud veaga ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                      );
   END invoice_service_fees;

   /***************************************************************************
   **
   **   Procedure Name :  Proc_Mob_NonKER_Service_Fees
   **
   **   Description : P?hiprotseduur päevade arvust s?ltumatute mobiilitaseme mitte-KER teenuste
   **                 maksustamiseks main bill protsessi koosseisus.
   **                 Protseduur valideerib käivituse parameetrid, registreerib
   **                 protsessi teated ja protsessi alguse ning l?pu ja kustub
   **                 välja teenuste maksustamist teostava protseduuri
   **
   **                 CHG-4482: Protsessi käivitus toimub ainult BILL_CYCLE põhiselt
   **
   ****************************************************************************/
   PROCEDURE proc_mob_nonker_service_fees (
       p_bill_cycle  IN  VARCHAR2  -- CHG-4482
      ,p_mode        IN  VARCHAR2 DEFAULT c_calculate_mode   -- CALC/RECALC/CONTINUE
   ) IS
      --
      c_proc_module_ref    CONSTANT VARCHAR2 (10) := 'BCCU1284NK';
      c_module_name        CONSTANT bcc_batch_messages.module_desc%TYPE := 'Check Mobile Non KER Service Fees';
      --
      l_salp_rec                    sales_ledger_periods%ROWTYPE;
      l_period_start_date           DATE;
      l_period_end_date             DATE;
      l_non_ker_proc_rec            tbcis_processes%ROWTYPE;
      l_success                     BOOLEAN;
      l_message                     bcc_batch_messages.MESSAGE_TEXT%TYPE;
      l_cur_param                   VARCHAR2 (10);
      l_result                      NUMBER;
      l_result_char                 VARCHAR2 (10);
      
      l_bill_start             DATE; 
      l_bill_cutoff            DATE;
      l_prodn_date             DATE;
      
      
      --
      e_initializing                EXCEPTION;
   BEGIN
      gen_bill.msg (c_module_ref
                   ,c_module_name
                   ,c_message_nr
                   , 'Protsess käivitatud '||TO_CHAR(SYSDATE, 'dd.mm.yyyy hh24:mi:ss')||'. '
                   , 'BICY = '||p_bill_cycle||'. Mode=' || p_mode
                   ,p_bill_cycle  -- CHG-4482
                   );
      /*
        ** Leiame vaadeldava arveldusperioodi = esimese avatud perioodi info.
      */
      l_salp_rec := gen_bill.first_open_salp_rec;
      l_period_start_date := l_salp_rec.start_date;
      l_period_end_date := TRUNC (l_salp_rec.end_date) + 1 - c_one_second;

      ---- siia
      BCC_Misc_Processing.Set_Cut_Off_Date (l_success      
                                           ,null
                                           ,l_bill_start             -- OUT DATE
                                           ,l_bill_cutoff            -- OUT DATE 23:59:59
                                           ,l_prodn_date             -- OUT DATE
                                           );

      --
      IF SYSDATE <= l_prodn_date THEN
         l_message := 'Protsessi ei saa käivitada jooksva perioodi kohta';
         RAISE e_initializing;
      END IF;

      /*
        ** Leiame vastava TBCIS protsessi kirje mitte-KER teenuse jaoks.
      */
      l_non_ker_proc_rec := Tbcis_Common.Get_Tbcis_Process_For_Param (c_proc_module_ref, p_bill_cycle);

      --
      IF p_mode = c_calculate_mode THEN   -- CALC
         IF NVL (l_non_ker_proc_rec.financial_year, 0) = l_salp_rec.financial_year AND
            NVL (l_non_ker_proc_rec.period_num, 0) = l_salp_rec.period_num 
         THEN
            l_message :=    'Protsess on perioodile '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' juba käivitatud. Kasutage ümberhindamise (RECALC) v?i jätkamise (CONTINUE) v?imalust';
            RAISE e_initializing;
         END IF;
      ELSIF p_mode IN (c_recalculate_mode   -- RECALC
                      ,c_continue_mode )    -- CONTINUE
      THEN
         IF TO_CHAR (NVL (l_non_ker_proc_rec.financial_year, 0)) || TO_CHAR (NVL (l_non_ker_proc_rec.period_num, 0)) <>
                                                  TO_CHAR (l_salp_rec.financial_year)
                                                  || TO_CHAR (l_salp_rec.period_num) 
         THEN
            l_message :=    'Protsess ei ole perioodile '
                         || TO_CHAR (l_salp_rec.financial_year)
                         || TO_CHAR (l_salp_rec.period_num)
                         || ' veel käivitatud. Kasutage esmakordse käivituse (CALC) v?imalust';
            RAISE e_initializing;
         END IF;
      ELSE
         IF l_non_ker_proc_rec.module_ref IS NOT NULL THEN  -- CHG-4482: Välistada vea tekkimine protsessi esmakordsel käivitamisel
            l_message :=    'Tundmatu käivitusviis '
                         || p_mode
                         || '. Lubatud on '
                         || c_calculate_mode
                         || ', '
                         || c_recalculate_mode
                         || ', '
                         || c_continue_mode
                         || '.';
            RAISE e_initializing;
         END IF;
      END IF;

      /*
        ** Registreerime protsessi alguse.
        ** Parameetrina on kasutusel viimane MAAC, milline eelmisel käivitusel edukalt töödeldi.
        ** Continue korral on v?imalik sellest MAACist edasi minna, CALC/RECALC korral tuleks param väärtus nullida
        ** ja k?ik masterid esmakordselt/uuesti töödelda.
      */
      IF p_mode IN (c_calculate_mode      -- CALC
                   ,c_recalculate_mode )  -- RECALC
      THEN
         l_cur_param := NULL;
      ELSE
         l_cur_param := l_non_ker_proc_rec.other_params;  -- CHG-4482: MAACi kasutus uues väljas (vana: module_params)
      END IF;

      --
      Tbcis_Common.Register_Process_Start (p_module_ref     => c_proc_module_ref
                                          ,p_parameter      => p_bill_cycle  -- CHG-4482
                                          ,p_module_desc    => c_module_name
                                          ,p_param_level    => 'Y'           -- CHG-4482
                                          ,p_commit         => 'Y'
                                          ,p_salp_year      => l_salp_rec.financial_year
                                          ,p_salp_month     => l_salp_rec.period_num
                                          ,p_other_params   => l_cur_param   -- CHG-4482
                                          );
      --
      l_non_ker_proc_rec := Tbcis_Common.Get_Tbcis_Process_For_Param (c_proc_module_ref, p_bill_cycle);
      /*
        ** Järgnevalt p?hiprotseduur, milles töödeldakse k?igi mobiilide k?ik mitte-KER teenused,
        ** millised omavad päevade arvust s?ltumatut kuutasu.
      */
      chk_mobile_nonker_service_fees (l_period_start_date  -- IN     DATE
                                     ,l_period_end_date    -- IN     DATE
                                     ,l_non_ker_proc_rec   -- p_tbpr_rec       IN OUT tbcis_processes%ROWTYPE
                                     ,l_success            -- OUT BOOLEAN
                                     ,l_message            -- OUT VARCHAR2
                                     ,NULL                 -- IN master_accounts_v.ref_num%TYPE DEFAULT NULL
                                     ,p_bill_cycle         -- IN VARCHAR2 DEFAULT NULL  -- CHG-4482
                                     );

      --
      IF NOT l_success THEN
         l_result := 0;
         l_result_char := 'vigadega';
         --
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, l_message, NULL, p_bill_cycle);
      ELSE
         l_result := 1;
         l_result_char := 'edukalt';
      END IF;

      /*
        ** Märgime mitte-KER teenuste töötlemise l?petatuks.
      */
      Tbcis_Common.Register_Process_End
                             (c_proc_module_ref   -- IN VARCHAR2
                             ,p_bill_cycle   -- p_parameter      IN VARCHAR2 -- CHG-4482
                             ,l_result   -- p_result         IN NUMBER
                             ,'Y'   -- p_param_level    CHG-4482: N -> Y
                             ,'Y'   -- p_commit         IN VARCHAR2 DEFAULT 'Y'
                             );
      /*
        ** Registreerime l?petamise teate.
      */
      gen_bill.msg (c_module_ref
                   ,c_module_name
                   ,c_message_nr
                   , 'Protsess ' || l_result_char || ' l?petanud ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                   , 'BICY = '||p_bill_cycle||'. Mode=' || p_mode
                   ,p_bill_cycle  -- CHG-4482
                   );
   EXCEPTION
      WHEN e_initializing THEN
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, l_message, NULL, p_bill_cycle);
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Protsess l?petanud veaga ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                      , 'BICY = '||p_bill_cycle||'. Mode=' || p_mode
                      ,p_bill_cycle  -- CHG-4482
                      );
      WHEN OTHERS THEN
         ROLLBACK;
         gen_bill.msg (c_module_ref, c_module_name, c_message_nr, SQLERRM, NULL, p_bill_cycle);
         gen_bill.msg (c_module_ref
                      ,c_module_name
                      ,c_message_nr
                      , 'Protsess l?petanud veaga ' || TO_CHAR (SYSDATE, 'dd.mm.yyyy hh24:mi:ss') || '. '
                      , 'BICY = '||p_bill_cycle||'. Mode=' || p_mode
                      ,p_bill_cycle  -- CHG-4482
                      );
   END proc_mob_nonker_service_fees;

   /***************************************************************************
   **
   **   Procedure Name :  Chk_Mob_NonKER_Serv_Fees_By_MA
   **
   **   Description : Protseduur 1 ette antud masteri (v?i mobiili) mitte-KER teenuste
   **                 päevade arvust s?ltumatute kuutasude arvele kandmiseks.
   **                 Protseduur on välja kutsutav vahearvete ja vahesaldode arvutusest.
   **
   ****************************************************************************/
   PROCEDURE chk_mob_nonker_serv_fees_by_ma (
      p_maac_ref_num  IN      accounts.ref_num%TYPE
     ,p_invo_ref_num  IN      invoices.ref_num%TYPE
     ,p_period_start  IN      DATE
     ,p_period_end    IN      DATE
     ,p_success       OUT     BOOLEAN
     ,p_error_text    OUT     VARCHAR2
     ,p_susg_ref_num  IN      subs_serv_groups.ref_num%TYPE DEFAULT NULL
     ,p_interim       IN      BOOLEAN DEFAULT FALSE
   ) IS
      --
      CURSOR c_stpe IS
         SELECT   stpe.susg_ref_num
                 ,stpe.sety_ref_num
                 ,supa.sept_type_code
                 ,GREATEST (stpe.start_date, supa.start_date, p_period_start) start_date
                 ,LEAST (NVL (stpe.end_date, p_period_end)
                        ,NVL (supa.end_date + 1 - c_one_second, p_period_end)
                        ,p_period_end
                        ) end_date
                 ,sept.CATEGORY
                 ,NULL mixed_packet_code  -- CHG-5762
                 ,NULL ebs_order_number   -- CHG-5762
                 ,'N'  prorata            -- CHG-5762
             FROM subs_packages supa, status_periods stpe, subs_accounts_v suac, serv_package_types sept
            WHERE NVL (supa.end_date, p_period_start) >= p_period_start
              AND supa.start_date <= p_period_end
              AND stpe.susg_ref_num = supa.gsm_susg_ref_num
              AND stpe.sety_ref_num IN (SELECT DISTINCT prli.sety_ref_num sety_ref_num
                                                   FROM price_lists prli, service_types sety
                                                  WHERE NVL (prli.par_value_charge, 'N') = 'N'
                                                    AND prli.once_off = 'N'
                                                    AND prli.pro_rata = 'N'
                                                    AND prli.regular_charge = 'Y'
                                                    AND prli.charge_value > 0
                                                    AND TRUNC (p_period_end) BETWEEN prli.start_date
                                                                                 AND NVL (prli.end_date
                                                                                         ,TRUNC (p_period_end)
                                                                                         )
                                                    AND sety.ref_num = prli.sety_ref_num
                                                    AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV')
                                        UNION
                                        SELECT DISTINCT ficv.sety_ref_num sety_ref_num
                                                   FROM fixed_charge_values ficv
                                                       ,fixed_charge_item_types fcit
                                                       ,service_types sety
                                                  WHERE ficv.chca_type_code IS NULL
                                                    AND NVL (ficv.par_value_charge, 'N') = 'N'
                                                    AND ficv.charge_value > 0
                                                    AND ficv.fcit_charge_code = fcit.type_code
                                                    AND fcit.once_off = 'N'
                                                    AND fcit.pro_rata = 'N'
                                                    AND fcit.regular_charge = 'Y'
                                                    AND TRUNC (p_period_end) BETWEEN ficv.start_date
                                                                                 AND NVL (ficv.end_date
                                                                                         ,TRUNC (p_period_end)
                                                                                         )
                                                    AND sety.ref_num = ficv.sety_ref_num
                                                    AND NVL (sety.station_param, '*') NOT IN ('KER', 'ARVE', 'TEAV'))
              AND NVL (stpe.end_date, p_period_start) >= p_period_start
              AND stpe.start_date <= p_period_end
              AND NVL (supa.end_date, stpe.start_date) >= TRUNC (stpe.start_date)
              AND supa.start_date <= NVL (stpe.end_date, supa.start_date)
              AND suac.ref_num = supa.suac_ref_num
              AND suac.maac_ref_num = p_maac_ref_num
              AND stpe.susg_ref_num = NVL (p_susg_ref_num, stpe.susg_ref_num)
              AND supa.gsm_susg_ref_num = NVL (p_susg_ref_num, supa.gsm_susg_ref_num)
              AND sept.type_code = supa.sept_type_code
              -- CHG-6381: Välistada teenuse perioodi ülekattumine paketivahetusel
              AND (CASE WHEN Trunc(stpe.end_date) = supa.start_date AND stpe.start_date < supa.start_date THEN 0 ELSE 1 END) <> 0
         ORDER BY supa.suac_ref_num, stpe.susg_ref_num, stpe.sety_ref_num, stpe.start_date, supa.start_date   -- CHG-3946
                                                                                                           ;

      --
      l_susg_ref_num_tab            t_ref_num;
      l_sety_ref_num_tab            t_ref_num;
      l_sept_type_tab               t_char4;
      l_start_date_tab              t_date;
      l_end_date_tab                t_date;
      l_category_tab                t_char1;
      l_mixed_packet_tab            t_char6;   -- CHG-5762
      l_ebs_order_number_tab        t_number;  -- CHG-5762
      l_prorata_tab                 t_char1;   -- CHG-5762
      --
      e_processing                  EXCEPTION;
   BEGIN
      /*
        ** Leitakse k?ik mitte-KER teenused, millel eksisteerib päevade arvust s?ltumatu kuutasu
        ** ette antud MAAC (v?i SUSG) kontekstis.
      */
      OPEN c_stpe;

      FETCH c_stpe 
      BULK COLLECT INTO l_susg_ref_num_tab
                       ,l_sety_ref_num_tab
                       ,l_sept_type_tab
                       ,l_start_date_tab
                       ,l_end_date_tab
                       ,l_category_tab
                       ,l_mixed_packet_tab      -- CHG-5762
                       ,l_ebs_order_number_tab  -- CHG-5762
                       ,l_prorata_tab;          -- CHG-5762


      CLOSE c_stpe;
      
      /*
        ** CHG-5762: Lisame vahetabelisse PAK komplektiteenuste kuupäevad ja tunnused
      */
      IF NOT p_interim THEN -- CHG-6068: Saldostop peab arvutama teenuste kuutasud PAK-ile.
         --
         Add_Mixed_Packet_Service_Dates (p_period_start     --IN      DATE
                                        ,p_period_end       --IN      DATE
                                        ,l_susg_ref_num_tab --IN OUT  t_ref_num
                                        ,l_sety_ref_num_tab --IN OUT  t_ref_num
                                        ,l_sept_type_tab    --IN OUT  t_char4
                                        ,l_start_date_tab   --IN OUT  t_date
                                        ,l_end_date_tab     --IN OUT  t_date
                                        ,l_category_tab     --IN OUT  t_char1
                                        ,l_mixed_packet_tab --IN OUT  t_char6
                                        ,l_ebs_order_number_tab
                                        ,l_prorata_tab      --IN OUT  t_char1
                                        ,p_invo_ref_num     --IN      NUMBER DEFAULT NULL
                                        ,p_interim          --IN      BOOLEAN DEFAULT FALSE
         );
         --
      END IF;


      /*
        ** Kanname maksustamisele kuuluvad teenused MAAC arvele.
      */
      proc_one_maac_nonker_serv_fees
         (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
         ,p_period_start   -- IN     DATE
         ,p_period_end   -- IN     DATE
         ,l_susg_ref_num_tab   -- IN     t_ref_num
         ,l_sety_ref_num_tab   -- IN     t_ref_num
         ,l_sept_type_tab   -- IN     t_char4
         ,l_start_date_tab   -- IN     t_date
         ,l_end_date_tab   -- IN     t_date
         ,l_category_tab   -- IN     t_char1
         ,l_mixed_packet_tab --IN t_char6       CHG-5762
         ,l_ebs_order_number_tab --IN t_number  CHG-5762
         ,l_prorata_tab      --IN t_char1       CHG-5762
         ,p_success   --    OUT BOOLEAN
         ,p_error_text   --    OUT VARCHAR2
         ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE DEFAULT NULL -- vahearvete, vahesaldode korral on arve ref teada
         ,p_interim   -- IN     BOOLEAN DEFAULT FALSE
         );

      IF NOT p_success THEN
         RAISE e_processing;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_processing THEN
         ROLLBACK;
         p_success := FALSE;
   END chk_mob_nonker_serv_fees_by_ma;

   /*
     ** Protseduur leiab kuutasud mobiili taseme k?nedeeristuse teenustele.
     ** Kutsutakse välja 1 masteri kontekstis, kasutatav vahesaldode arvutamiseks.
   */
   PROCEDURE calc_non_prorata_ker_susg_chg (
      p_maac_ref_num       IN      master_accounts_v.ref_num%TYPE
     ,p_invo_ref_num       IN      invoices.ref_num%TYPE
     ,p_period_start_date  IN      DATE
     ,p_period_end_date    IN      DATE
     ,p_discount_type      IN      fixed_charge_types.discount_type%TYPE
     ,p_success            OUT     BOOLEAN
     ,p_error_text         OUT     VARCHAR2
     ,p_interim_balance    IN      BOOLEAN DEFAULT FALSE
     ,p_susg_ref_num       IN      subs_serv_groups.ref_num%TYPE DEFAULT NULL
   ) IS
      --
      CURSOR c_stpe IS
         SELECT stpe.*
           FROM subs_accounts_v suac, subs_serv_groups susg, status_periods stpe
          WHERE suac.maac_ref_num = p_maac_ref_num
            AND susg.suac_ref_num = suac.ref_num
            AND stpe.susg_ref_num = susg.ref_num
            AND stpe.susg_ref_num = NVL (p_susg_ref_num, stpe.susg_ref_num)
            AND stpe.start_date <= p_period_end_date
            AND NVL (stpe.end_date, p_period_start_date) >= p_period_start_date
            AND stpe.start_date = (SELECT MAX (start_date)
                                     FROM status_periods
                                    WHERE susg_ref_num = susg.ref_num
                                      AND sety_ref_num = stpe.sety_ref_num
                                      AND start_date <= p_period_end_date
                                      AND NVL (end_date, p_period_start_date) >= p_period_start_date)
            AND EXISTS (SELECT 1
                          FROM service_types
                         WHERE ref_num = stpe.sety_ref_num AND station_param = 'KER')
            AND EXISTS (SELECT 1
                          FROM price_lists
                         WHERE sety_ref_num = stpe.sety_ref_num
                           AND regular_charge = 'Y'
                           AND pro_rata = 'N'
                           AND once_off = 'N');

      --
      l_allowed                     BOOLEAN;
      l_channel                     price_lists.channel_type%TYPE;
      l_price                       NUMBER;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_sept_type_code              serv_package_types.type_code%TYPE;
      l_category                    serv_package_types.CATEGORY%TYPE;
      l_sepv_ref_num                service_param_values.ref_num%TYPE;
      l_mobile_end_date             DATE;
      l_bicy_cycle_code             bill_cycles.cycle_code%TYPE;
      l_events_exist                VARCHAR2 (1);
      --
      e_processing                  EXCEPTION;
   BEGIN
      /*
        ** Leiab mobiili KER teenused (max alguskuupäevaga perioodid), millised on arveldusperioodi jooksul avatud.
      */
      FOR l_stpe IN c_stpe LOOP
         l_mobile_end_date := NULL;
         l_events_exist := NULL;   -- CHG-662
         /*
           ** Leiame mobiili kehtiva teenuspaketi (perioodi l?pus v?i teenuse sulgemisel).
         */
         get_package_at_date (l_stpe.susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                             ,LEAST (NVL (l_stpe.end_date, p_period_end_date), p_period_end_date)   -- p_end_date IN DATE
                             ,l_sept_type_code   --    OUT serv_package_types.type_code%TYPE
                             ,l_category   --    OUT serv_package_types.category%TYPE
                             );
         /*
           ** Kontrollime, kas teenus kuulub maksustamisele.
           ** Kui teenuse periood on suletud enne arveldusperioodi l?ppu, siis kuulub maksustamisele ainult juhul,
           ** kui teenus on suletud koos mobiili sulgemisega.
         */
         l_allowed := chk_ker_service_fee (l_stpe.susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                          ,l_stpe.sety_ref_num   -- IN     service_types.ref_num%TYPE
                                          ,l_stpe.end_date   -- IN     DATE
                                          ,p_period_start_date   -- IN     DATE
                                          ,p_period_end_date   -- IN     DATE
                                          ,l_sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                          ,p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                          ,l_category   -- IN     package_categories.package_category%TYPE
                                          ,l_mobile_end_date   -- IN OUT DATE
                                          ,l_channel   -- IN OUT price_lists.channel_type%TYPE
                                          ,l_bicy_cycle_code   -- IN OUT bill_cycles.cycle_code%TYPE
                                          ,l_events_exist   -- IN OUT VARCHAR2
                                          ,l_price   --    OUT NUMBER
                                          ,l_sepv_ref_num   --    OUT service_param_values.ref_num%TYPE
                                          ,l_taty_type_code   --    OUT tax_types.tax_type_code%TYPE
                                          ,l_billing_selector   --    OUT billing_selectors_v.type_code%TYPE
                                          ,l_fcit_type_code   --    OUT fixed_charge_item_types.type_code%TYPE
                                          );

         --
         IF l_allowed AND NVL (l_price, 0) > 0 AND l_events_exist = 'Y' THEN
            IF p_interim_balance THEN
               close_interim_billing_invoice.cre_upd_interim_inen (p_success   -- OUT BOOLEAN
                                                                  ,p_error_text   -- OUT VARCHAR2
                                                                  ,p_invo_ref_num   -- IN     NUMBER
                                                                  ,l_fcit_type_code   -- IN     VARCHAR2
                                                                  ,l_billing_selector   -- IN     VARCHAR2
                                                                  ,l_taty_type_code   -- IN     VARCHAR2
                                                                  ,l_price   -- IN     NUMBER
                                                                  ,NULL   -- p_num_of_days       IN     NUMBER
                                                                  ,l_stpe.susg_ref_num   -- IN     NUMBER
                                                                  );

               IF p_success = FALSE THEN
                  RAISE e_processing;
               END IF;
            ELSE
               icalculate_fixed_charges.create_entries
                                            (p_success   -- IN OUT BOOLEAN
                                            ,p_error_text   -- IN OUT varchar2
                                            ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                            ,l_fcit_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TYPE_CODE%TYPE
                                            ,l_taty_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TATY_TYPE_CODE%TYPE
                                            ,l_billing_selector   -- IN     FIXED_CHARGE_ITEM_TYPES.BILLING_SELECTOR%TYPE
                                            ,l_price   -- p_charge_value     IN     NUMBER
                                            ,l_stpe.susg_ref_num   -- IN     SUBS_SERV_GROUPS.ref_num%TYPE
                                            ,NULL   -- p_num_of_days         IN     NUMBER
                                            );

               IF p_success = FALSE THEN
                  RAISE e_processing;
               END IF;

               --
               icalculate_discounts.find_oo_conn_discounts (p_discount_type   -- VARCHAR2
                                                          ,p_invo_ref_num   -- NUMBER
                                                          ,l_fcit_type_code   -- VARCHAR2
                                                          ,l_billing_selector   -- VARCHAR2
                                                          ,l_sepv_ref_num   -- NUMBER
                                                          ,l_sept_type_code   -- VARCHAR2
                                                          ,l_price   -- NUMBER
                                                          ,l_stpe.susg_ref_num   -- NUMBER
                                                          ,p_maac_ref_num   -- NUMBER
                                                          ,LEAST (NVL (l_stpe.end_date, p_period_end_date)
                                                                 ,p_period_end_date
                                                                 )   -- DATE
                                                          ,'INS'   -- p_mode              VARCHAR2  --'INS';'DEL'
                                                          ,p_error_text   -- IN out VARCHAR2
                                                          ,p_success   -- IN out BOOLEAN
                                                          );

               IF p_success = FALSE THEN
                  RAISE e_processing;
               END IF;
            END IF;
         END IF;
      END LOOP;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
   END calc_non_prorata_ker_susg_chg;

   /*
     ** Protseduur leiab kuumaksud arve- ja k?nedeeristuse M/A teenustele.
     ** Kutsutakse välja 1 masteri kontekstis, kasutatav vahesaldode arvutamiseks.
   */
   PROCEDURE calc_non_prorata_ker_maas_chg (
      p_maac_ref_num       IN      master_accounts_v.ref_num%TYPE
     ,p_invo_ref_num       IN      invoices.ref_num%TYPE
     ,p_period_start_date  IN      DATE
     ,p_period_end_date    IN      DATE
     ,p_maac_end_date      IN      DATE
     ,p_default_bill_sety  IN      service_types.ref_num%TYPE
     ,p_success            OUT     BOOLEAN
     ,p_error_text         OUT     VARCHAR2
     ,p_interim_balance    IN      BOOLEAN DEFAULT FALSE
   ) IS
      --
      CURSOR c_maas IS
         SELECT   maas.ref_num
                 ,maas.sety_ref_num
                 ,sety.station_param
                 ,maas.end_date
             FROM master_account_services maas, service_types sety
            WHERE maas.maac_ref_num = p_maac_ref_num
              AND (   (    NVL (p_maac_end_date, p_period_end_date) >= p_period_end_date
                       AND p_period_end_date BETWEEN maas.start_date AND NVL (maas.end_date, p_period_end_date)
                      )
                   OR (p_maac_end_date < p_period_end_date AND TRUNC (maas.end_date) >= TRUNC (p_maac_end_date))
                  )
              AND sety.ref_num = maas.sety_ref_num
              AND sety.station_param IN ('KER', 'ARVE', 'TEAV')
         ORDER BY sety.station_param;

      --
      l_chca_type_code              maac_charging_categories.chca_type_code%TYPE;
      l_sety_ref_num_tab            t_sety_ref;
      l_bill_sety_found             BOOLEAN;
      --
      e_maac_processing             EXCEPTION;

      --
      PROCEDURE process_one_maac_service (
         p_maac_ref_num      IN      master_accounts_v.ref_num%TYPE
        ,p_maas_ref_num      IN      master_account_services.ref_num%TYPE
        ,p_sety_ref_num      IN      service_types.ref_num%TYPE
        ,p_invo_ref_num      IN      invoices.ref_num%TYPE
        ,p_station_param     IN      service_types.station_param%TYPE
        ,p_end_date          IN      DATE
        ,p_period_start      IN      DATE
        ,p_period_end        IN      DATE
        ,p_chca_type_code    IN OUT  maac_charging_categories.chca_type_code%TYPE
        ,p_sety_ref_num_tab  IN OUT  t_sety_ref
        ,p_success           OUT     BOOLEAN
        ,p_err_text          OUT     VARCHAR2
        ,p_interim_balance   IN      BOOLEAN
      ) IS
         --
         l_allowed                     BOOLEAN;
         --
         e_creating_inve               EXCEPTION;
      BEGIN
         /*
           ** Kontrollime, kas teenuse maksustamine on reeglite järgi lubatud.
         */
         l_allowed := chk_maac_service_chg_rules (p_maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                                 ,p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                                 ,p_station_param   -- IN     service_types.station_param%TYPE
                                                 ,p_period_start   -- IN     DATE
                                                 ,p_period_end   -- IN     DATE
                                                 ,p_sety_ref_num_tab   -- IN OUT t_sety_ref
                                                 );

         --
         IF l_allowed THEN
            /*
              ** Kui teenuse maksustamine lubatud, siis kanname arvele.
            */
            invoice_master_service (p_maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                   ,p_maas_ref_num   -- IN     master_account_services.ref_num%TYPE
                                   ,p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                   ,p_end_date   -- IN     DATE
                                   ,p_chca_type_code   -- IN OUT maac_charging_categories.chca_type_code%TYPE
                                   ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                   ,p_success   --    OUT BOOLEAN
                                   ,p_err_text   --    OUT varchar2
                                   ,p_interim_balance   --    IN     BOOLEAN DEFAULT FALSE
                                   );

            IF p_success = FALSE THEN
               RAISE e_creating_inve;
            END IF;
         END IF;

         --
         p_success := TRUE;
      EXCEPTION
         WHEN e_creating_inve THEN
            p_success := FALSE;
      END process_one_maac_service;
   BEGIN
      l_bill_sety_found := FALSE;

      /*
        ** 1. Avatud Masterite teenused, millised on perioodi l?pu seisuga avatud.
        ** 2. Perioodi jooksul suletud Masterite teenused, millised on suletud samal päeval koos Masteriga.
      */
      FOR l_maas IN c_maas LOOP
         process_one_maac_service (p_maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                  ,l_maas.ref_num   -- IN     master_account_services.ref_num%TYPE
                                  ,l_maas.sety_ref_num   -- IN     service_types.ref_num%TYPE
                                  ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                  ,l_maas.station_param   -- IN     service_types.station_param%TYPE
                                  ,LEAST (p_period_end_date, NVL (l_maas.end_date, p_period_end_date))   -- p_end_date   IN     DATE
                                  ,p_period_start_date   -- IN     DATE
                                  ,p_period_end_date   -- IN     DATE
                                  ,l_chca_type_code   -- IN OUT maac_charging_categories.chca_type_code%TYPE
                                  ,l_sety_ref_num_tab   -- IN OUT t_sety_ref
                                  ,p_success   --    OUT BOOLEAN
                                  ,p_error_text   --    OUT varchar2
                                  ,p_interim_balance   -- IN     BOOLEAN
                                  );

         IF NOT p_success THEN
            RAISE e_maac_processing;
         END IF;

         --
         IF l_maas.station_param = 'ARVE' THEN
            l_bill_sety_found := TRUE;
         END IF;
      END LOOP;

      /*
        ** Kui ühtegi ARVE teenust ei ole avatud, siis kasutatakse vaikimisi teenust.
      */
      IF NOT l_bill_sety_found THEN
         process_one_maac_service (p_maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
                                  ,NULL   -- IN     master_account_services.ref_num%TYPE
                                  ,p_default_bill_sety   -- IN     service_types.ref_num%TYPE
                                  ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                  ,'ARVE'   -- IN     service_types.station_param%TYPE
                                  ,p_period_end_date   -- p_end_date   IN     DATE
                                  ,p_period_start_date   -- IN     DATE
                                  ,p_period_end_date   -- IN     DATE
                                  ,l_chca_type_code   -- IN OUT maac_charging_categories.chca_type_code%TYPE
                                  ,l_sety_ref_num_tab   -- IN OUT t_sety_ref
                                  ,p_success   --    OUT BOOLEAN
                                  ,p_error_text   --    OUT varchar2
                                  ,p_interim_balance   -- IN     BOOLEAN
                                  );

         IF NOT p_success THEN
            RAISE e_maac_processing;
         END IF;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_maac_processing THEN
         p_success := FALSE;
   END calc_non_prorata_ker_maas_chg;

   /****************************************************************************
   **
   **   Function Name:   CHK_KER_SERVICE_FEES_EXIST
   **
   **   Description:     This function checks if service fees for KER services have already
   **                    been created for given invoice.
   **
   *****************************************************************************/
   FUNCTION chk_ker_service_fees_exist (
      p_invo_ref_num  IN  invoices.ref_num%TYPE
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_inen IS
         SELECT 1
           FROM invoice_entries inen, fixed_charge_item_types fcit, service_types sety
          WHERE inen.invo_ref_num = p_invo_ref_num
            AND NVL (inen.manual_entry, 'Y') <> 'Y'
            AND fcit.type_code = inen.fcit_type_code
            AND fcit.pro_rata = 'N'
            AND fcit.regular_charge = 'Y'
            AND fcit.once_off = 'N'
            AND sety.ref_num = fcit.sety_ref_num
            AND sety.station_param IN ('KER', 'ARVE', 'TEAV')
            AND ROWNUM = 1;

      --
      l_dummy                       NUMBER;
      l_found                       BOOLEAN;
   BEGIN
      OPEN c_inen;

      FETCH c_inen
       INTO l_dummy;

      l_found := c_inen%FOUND;

      CLOSE c_inen;

      --
      RETURN l_found;
   END chk_ker_service_fees_exist;

   /****************************************************************************
   **
   **   Function Name:   CHK_ONE_MAAC_SOLUTION_FEES
   **
   **   Description:     This procedure loops through NonKER Service fees INEN tab
   **                   for services with BILL FCIT, sums them into temp PL/SQL table
   **                   by FCIT+SUSG and deletes INEN tab records with these service fees.
   **                    After re-organizing INEN tab, new Calculated fees are added
   **                   to the INEN tab.
   **
   *****************************************************************************/
   PROCEDURE chk_one_maac_calculated_fees (
      p_maac_ref_num  IN      accounts.ref_num%TYPE
     ,p_period_start  IN      DATE
     ,p_period_end    IN      DATE
     ,p_invo_ref_num  IN OUT  invoices.ref_num%TYPE
     ,p_inen_tab      IN OUT  icalculate_fixed_charges.t_inen
     ,p_interim       IN      BOOLEAN
   ) IS
      --
      CURSOR c_bill_fcit (
         p_fcit_type_code  VARCHAR2
      ) IS
         SELECT *
           FROM fixed_charge_item_types
          WHERE type_code = p_fcit_type_code;

      --
      CURSOR c_fcit (
         p_fcit_type_code  VARCHAR2
      ) IS
         SELECT *
           FROM fixed_charge_item_types
          WHERE type_code = p_fcit_type_code;

      --
      l_idx                         NUMBER;
      l_cnt                         NUMBER;
      l_sol_idx                     NUMBER;
      l_inen_price                  NUMBER;   -- CHG-3984
      l_exists                      BOOLEAN;
      l_success                     BOOLEAN;
      l_error_text                  VARCHAR2 (500);
      l_comc_rec                    common_monthly_charges%ROWTYPE;
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;
      l_bill_fcit_rec               fixed_charge_item_types%ROWTYPE;   -- CHG-3832
      l_calculated_tab              t_calculated_fee;
      l_inen_tab                    icalculate_fixed_charges.t_inen;
      l_invo_rec                    invoices%ROWTYPE;
      l_inen_rec                    invoice_entries%ROWTYPE;
      l_discount_type               fixed_charge_types.discount_type%TYPE;   -- CHG-3832
      l_solution_fee_indicator      VARCHAR2(8);  -- CHG-13617
   BEGIN
      l_calculated_tab.DELETE;
      l_inen_tab.DELETE;
      /*
        ** Loop through inen tab to find service fees with Bill FCIT
      */
      l_idx := p_inen_tab.FIRST;
      
      l_solution_fee_indicator := To_Char(SYSDATE, 'DDMMYYYY');  -- CHG-13617

      --
      WHILE l_idx IS NOT NULL LOOP
         --
         l_inen_rec := p_inen_tab (l_idx);

         --
         IF p_inen_tab (l_idx).fcit_type_code IS NOT NULL THEN
            /*
              ** Get Bill FCIT for Service fee, if exists.
            */
            OPEN c_bill_fcit (p_inen_tab (l_idx).fcit_type_code);

            FETCH c_bill_fcit
             INTO l_bill_fcit_rec;

            CLOSE c_bill_fcit;

            --
            IF l_bill_fcit_rec.bill_fcit_type_code IS NOT NULL THEN
               /*
                 ** Get the invoice where to add invoice_entries.
               */
               IF p_invo_ref_num IS NOT NULL THEN
                  l_inen_rec.invo_ref_num := p_invo_ref_num;
               ELSE
                  get_invoice (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                              ,p_period_start   -- IN     DATE
                              ,l_success   --    OUT BOOLEAN
                              ,l_error_text   --    OUT VARCHAR2
                              ,l_invo_rec   --    OUT invoices%ROWTYPE
                              );
                  --
                  p_invo_ref_num := l_invo_rec.ref_num;
                  l_inen_rec.invo_ref_num := p_invo_ref_num;
               END IF;

               /*
                 ** Add Service fee to Common_Monthly_Charges table
               */
               IF NOT p_interim THEN
                  --
                  l_inen_rec.last_updated_by := l_solution_fee_indicator;  -- CHG-13617
                  --
                  icalculate_fixed_charges.ins_common_monthly_charges (l_inen_rec);
                  --
               END IF;

               /*
                 ** Add Service fee to Calculated fee tab.
               */
               l_exists := FALSE;
               l_sol_idx := l_calculated_tab.FIRST;

               -- Sum if FCIT+SUSG exists
               WHILE l_sol_idx IS NOT NULL LOOP
                  --
                  IF     l_calculated_tab (l_sol_idx).fcit_type_code = l_bill_fcit_rec.bill_fcit_type_code
                     AND l_calculated_tab (l_sol_idx).susg_ref_num = p_inen_tab (l_idx).susg_ref_num THEN
                     l_calculated_tab (l_sol_idx).eek_amt :=   l_calculated_tab (l_sol_idx).eek_amt
                                                             + NVL (p_inen_tab (l_idx).eek_amt, 0);
                     --
                     l_exists := TRUE;
                  END IF;

                  --
                  l_sol_idx := l_calculated_tab.NEXT (l_sol_idx);
               END LOOP;

               -- Add new FCIT+SUSG
               IF NOT l_exists THEN
                  l_sol_idx := l_calculated_tab.COUNT + 1;
                  --
                  l_calculated_tab (l_sol_idx).fcit_type_code := l_bill_fcit_rec.bill_fcit_type_code;
                  l_calculated_tab (l_sol_idx).susg_ref_num := p_inen_tab (l_idx).susg_ref_num;
                  l_calculated_tab (l_sol_idx).eek_amt := NVL (p_inen_tab (l_idx).eek_amt, 0);
               END IF;

               /*
                 ** Delete Service fee from INEN tab.
               */
               p_inen_tab.DELETE (l_idx);
            END IF;
         --
         END IF;

         --
         l_idx := p_inen_tab.NEXT (l_idx);
      END LOOP;

      /*
        ** Reorder p_inen_tab for Create_NonKER_Serv_Fee_INEN would work properly.
      */
      l_idx := p_inen_tab.FIRST;
      l_cnt := 0;

      --
      WHILE l_idx IS NOT NULL LOOP
         l_cnt := l_cnt + 1;
         --
         l_inen_tab (l_cnt) := p_inen_tab (l_idx);
         --
         l_idx := p_inen_tab.NEXT (l_idx);
      END LOOP;

      --
      p_inen_tab := l_inen_tab;
      /*
        ** Now add Calculated fees to p_inen_tab.
      */
      l_sol_idx := l_calculated_tab.FIRST;

      --
      WHILE l_sol_idx IS NOT NULL LOOP
         --
         OPEN c_fcit (l_calculated_tab (l_sol_idx).fcit_type_code);
         FETCH c_fcit INTO l_fcit_rec;
         CLOSE c_fcit;
         --
         create_nonker_serv_fee_inen
                                    (p_maac_ref_num                              -- IN     accounts.ref_num%TYPE
                                    ,l_calculated_tab (l_sol_idx).susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                    ,NULL                                        -- IN     service_types.ref_num%TYPE
                                    ,p_period_start                              -- IN     DATE
                                    ,p_period_end                                -- IN     DATE
                                    ,l_fcit_rec.type_code                        -- IN     fixed_charge_item_types.type_code%TYPE
                                    ,l_fcit_rec.taty_type_code                   -- IN     fixed_charge_item_types.taty_type_code%TYPE
                                    ,l_fcit_rec.billing_selector                 -- IN     fixed_charge_item_types.billing_selector%TYPE
                                    ,l_calculated_tab (l_sol_idx).eek_amt        -- IN     NUMBER
                                    ,p_inen_tab                                  -- IN OUT Calculate_Fixed_Charges.t_inen
                                    ,l_inen_price                                -- CHG-3984
                                    ,NULL                                        -- IN      NUMBER DEFAULT NULL  -- CHG-5762
                                    ,'N'                                         -- IN      VARCHAR2 DEFAULT 'N' -- CHG-5762
                                    ,l_solution_fee_indicator                    -- IN      VARCHAR2 DEFAULT NULL  -- CHG-13617
                                    );
         /*
           ** CHG-3946: Check for discount after adding Solution fee
         */
         l_discount_type := NULL;
         --
         l_discount_type := icalculate_discounts.find_discount_type (l_fcit_rec.pro_rata
                                                                   ,l_fcit_rec.regular_charge
                                                                   ,l_fcit_rec.once_off
                                                                   );
         --
         icalculate_discounts.find_oo_conn_discounts (l_discount_type
                                                    ,p_invo_ref_num
                                                    ,l_fcit_rec.type_code
                                                    ,l_fcit_rec.billing_selector
                                                    ,NULL
                                                    ,NULL   --p_sept_type_code
                                                    ,l_calculated_tab (l_sol_idx).eek_amt
                                                    ,l_calculated_tab (l_sol_idx).susg_ref_num
                                                    ,p_maac_ref_num
                                                    ,p_period_end   -- CHG-3984: replaced SYSDATE --p_date
                                                    ,'INS'   --p_mode
                                                    ,l_error_text
                                                    ,l_success
                                                    );
         --
         l_sol_idx := l_calculated_tab.NEXT (l_sol_idx);
      END LOOP;
   END chk_one_maac_calculated_fees;

   /****************************************************************************
   **
   **   Function Name:   RUN_ONE_MAAC_NONKER_SERV_FEES
   **
   **   Description:     Protseduur on loodud ainult testimise eesmärgil!!!
   **                    LIVE baasis mitte käivitada!!!
   **                    Protseduur kannab arvele ühe MAACi NonKER teenustasud vastavalt
   **                    kas etteantud perioodile või siis viimase avatud SALP perioodile.
   **
   *****************************************************************************/
   PROCEDURE run_one_maac_nonker_serv_fees (
      p_maac_ref_num  IN  master_accounts_v.ref_num%TYPE
     ,p_period_start  IN  DATE
     ,p_period_end    IN  DATE
     ,p_susg_ref_num  IN  NUMBER DEFAULT NULL
     ,p_invo_ref_num  IN  NUMBER DEFAULT NULL
   ) IS
      --
      l_success                     BOOLEAN;
      l_error_text                  VARCHAR2 (500);
      --
      e_maac_missing                EXCEPTION;
      e_processing_error            EXCEPTION;
   BEGIN
      --
      IF p_maac_ref_num IS NULL THEN
         RAISE e_maac_missing;
      END IF;

      chk_mob_nonker_serv_fees_by_ma (p_maac_ref_num  --IN      accounts.ref_num%TYPE
                                     ,p_invo_ref_num  --IN      invoices.ref_num%TYPE
                                     ,p_period_start  --IN      DATE
                                     ,p_period_end    --IN      DATE
                                     ,l_success       --OUT     BOOLEAN
                                     ,l_error_text    --OUT     VARCHAR2
                                     ,p_susg_ref_num  --IN      subs_serv_groups.ref_num%TYPE DEFAULT NULL
      );

      --
      IF NOT l_success THEN
         RAISE e_processing_error;
      END IF;

      --
      --COMMIT;
   --
   EXCEPTION
      WHEN e_maac_missing THEN
         DBMS_OUTPUT.put_line ('MAAC ref_num cannot be NULL!');
      --
      WHEN e_processing_error THEN
         DBMS_OUTPUT.put_line (l_error_text);
   END run_one_maac_nonker_serv_fees;

   /****************************************************************************
   **
   **   Function Name:   CHK_ONE_MAAC_MA_CALCULATED_FEE
   **
   **   Description:     Protseduur MeieEMT lahendustasu leidmiseks.
   **
   *****************************************************************************/
   PROCEDURE chk_one_maac_ma_calculated_fee (
      p_maac_ref_num  IN  master_accounts_v.ref_num%TYPE
     ,p_period_start  IN  DATE DEFAULT NULL
     ,p_period_end    IN  DATE DEFAULT NULL
     ,p_invo_ref_num  IN  invoices.ref_num%TYPE
     ,p_interim       IN  BOOLEAN DEFAULT FALSE
   ) IS
      -- CHG-4803: Changed station_param 'MEIE' with sept_type_code
      CURSOR c_maas IS
         SELECT   maas.ref_num maas_ref_num
                 ,maas.sety_ref_num
                 ,maas.start_date
                 ,NVL (maas.end_date, p_period_end) end_date
             FROM master_account_services maas
            WHERE maas.maac_ref_num = p_maac_ref_num
              AND maas.start_date <= p_period_end
              AND NVL (maas.end_date, p_period_start) >= p_period_start
              AND EXISTS (SELECT 1
                            FROM service_types
                           WHERE ref_num = maas.sety_ref_num AND sept_type_code IS NOT NULL)
         ORDER BY maas.sety_ref_num, maas.start_date;

      -- CHG-4707: If MA doesn't have active mobiles but has active Fixed Term Contract, then charge.
      -- CHG-4803: Check if package is defined in service types. No need to use SEPT with special mark.
      CURSOR c_act_mob (
         p_start_date    DATE
        ,p_end_date      DATE
        ,p_sety_ref_num  NUMBER
      ) IS
         SELECT supa.suac_ref_num
           FROM subs_packages supa
              , ssg_statuses ssst
          WHERE TRUNC (supa.suac_ref_num, -3) = p_maac_ref_num
            AND supa.start_date <= p_end_date
            AND NVL (supa.end_date, p_end_date) >= p_start_date
            AND supa.gsm_susg_ref_num = ssst.susg_ref_num
            AND ssst.status_code = 'AC'
            AND ssst.start_date <= p_end_date
            AND NVL (ssst.end_date, p_end_date) >= p_start_date
            AND EXISTS (SELECT 1
                        FROM service_types
                        WHERE sept_type_code = supa.sept_type_code
                          AND ref_num = p_sety_ref_num )
      ;
      -- CHG-4707
      CURSOR c_act_tl (
         p_start_date    DATE
        ,p_end_date      DATE
        ,p_sety_ref_num  NUMBER
      ) IS
         SELECT acco.ref_num suac_ref_num
           FROM fixed_term_maac_contracts ftmc, accounts acco
          WHERE ftmc.maac_ref_num = p_maac_ref_num
            AND ftmc.start_date < p_end_date
            AND NVL (ftmc.date_closed, NVL (ftmc.end_date, p_start_date)) > p_start_date
            AND ftmc.maac_ref_num = acco.maac_ref_num
            AND ftmc.sety_ref_num = p_sety_ref_num
            AND (ftmc.termination_reason IS NULL OR ftmc.termination_reason NOT IN ('CR'));

      -- CHG-4635
      -- CHG-4803: Check first mobile by packages defined in service types.
      CURSOR c_first_supa (
         p_start_date    DATE
        ,p_suac_ref_num  NUMBER
        ,p_sety_ref_num  NUMBER  -- CHG-4803
      ) IS
         SELECT MIN (supa.start_date)
           FROM subs_packages supa
          WHERE supa.suac_ref_num = p_suac_ref_num
            AND TRUNC (supa.start_date) >= TRUNC (p_start_date)
            AND EXISTS (select 1
                        from service_types
                        where ref_num = p_sety_ref_num
                          and sept_type_code = supa.sept_type_code )
      ;

      -- CHG-4707
      CURSOR c_ftmc_cr (
         p_sety_ref_num  NUMBER
      ) IS
         SELECT 1
           FROM fixed_term_maac_contracts
          WHERE maac_ref_num = p_maac_ref_num
            AND termination_reason = 'CR'
            AND sety_ref_num = p_sety_ref_num
            AND date_closed BETWEEN p_period_start AND p_period_end;

      --
      CURSOR c_fcit (
         p_fcit_type_code  VARCHAR2
      ) IS
         SELECT *
           FROM fixed_charge_item_types
          WHERE type_code = p_fcit_type_code;

      --
      l_found                       BOOLEAN;
      l_exists                      BOOLEAN;
      l_chk_mobiles                 BOOLEAN;
      l_chk_charges                 BOOLEAN;   -- CHG-4707
      l_act_mob_exists              BOOLEAN;   -- CHG-4707
      l_success                     BOOLEAN;
      l_error_text                  VARCHAR2 (500);
      l_dummy                       NUMBER;
      l_price                       NUMBER;
      l_inen_price                  NUMBER;
      l_idx                         NUMBER;
      l_calc_idx                    NUMBER;
      l_inen_tab                    icalculate_fixed_charges.t_inen;
      l_calc_tab                    icalculate_fixed_charges.t_inen;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_new_fcit_type_code          fixed_charge_item_types.type_code%TYPE;  -- CHG-4803
      l_charge_parameter            fixed_charge_item_types.valid_charge_parameter%TYPE;
      l_prev_sety_ref_num           service_types.ref_num%TYPE;
      l_suac_ref_num                subs_packages.suac_ref_num%TYPE;   -- CHG-4635
      l_first_supa_start            subs_packages.start_date%TYPE;   -- CHG-4635
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;
      l_bill_fcit_rec               fixed_charge_item_types%ROWTYPE;
      l_priced_sepv_ref_num         master_service_parameters.sepv_ref_num%TYPE;   -- CHG-4707
      --
      e_do_not_charge               EXCEPTION;
   BEGIN
      --
      l_inen_tab.DELETE;
      l_idx := 0;
      l_chk_mobiles := FALSE;
      l_act_mob_exists := FALSE;

      --
      FOR l_maas_rec IN c_maas LOOP
         --
         l_chk_charges := TRUE;

         /*
           ** CHG-4707: Check if there is no closed Fixed Term Contracts by CR.
           **           If exists, then do not charge - Credo has already charged.
         */
         OPEN c_ftmc_cr (l_maas_rec.sety_ref_num);

         FETCH c_ftmc_cr
          INTO l_dummy;

         l_found := c_ftmc_cr%FOUND;

         CLOSE c_ftmc_cr;

         --
         IF l_found THEN
            l_chk_charges := FALSE;
         END IF;

         /*
           ** Check if MAAC has active MeieEMT mobiles.
         */
         IF l_chk_charges THEN
            --
            l_suac_ref_num := NULL;

            --
            OPEN c_act_mob (GREATEST (p_period_start, l_maas_rec.start_date)
                           ,LEAST (p_period_end, NVL (l_maas_rec.end_date, p_period_end))
                           ,l_maas_rec.sety_ref_num  -- CHG-4803
                           );

            FETCH c_act_mob
             INTO l_suac_ref_num;

            l_act_mob_exists := c_act_mob%FOUND;

            CLOSE c_act_mob;
           --
         END IF;

         /*
           ** If MAAC doesn't have active MeieEMT mobiles, then check if active TL service exists.
         */
         IF NOT l_act_mob_exists THEN
            --
            l_suac_ref_num := NULL;

            --
            OPEN c_act_tl (GREATEST (p_period_start, l_maas_rec.start_date)
                          ,LEAST (p_period_end, NVL (l_maas_rec.end_date, p_period_end))
                          ,l_maas_rec.sety_ref_num
                          );

            FETCH c_act_tl
             INTO l_suac_ref_num;

            l_found := c_act_tl%FOUND;

            CLOSE c_act_tl;

            --
            IF NOT l_found THEN
               l_chk_charges := FALSE;
            END IF;
         --
         END IF;

         /*
           ** Now find service price
         */
         IF l_chk_charges THEN   -- CHG-4707
            IF l_maas_rec.sety_ref_num <> NVL (l_prev_sety_ref_num, -1) THEN
               --
               l_idx := l_idx + 1;
               l_inen_tab (l_idx).invo_ref_num := p_invo_ref_num;
               l_inen_tab (l_idx).rounding_indicator := 'N';
               l_inen_tab (l_idx).under_dispute := 'N';
               --
               l_price := NULL;
               l_taty_type_code := NULL;
               l_billing_selector := NULL;
               l_fcit_type_code := NULL;
               l_charge_parameter := NULL;
            --
            END IF;

            /*
              ** CHG-4635: Get first mobile start date (with MeieEMT package).
              ** MA service pricing starts after first mobile has joined the package.
            */
            l_first_supa_start := NULL;
            l_priced_sepv_ref_num := NULL;

            --
            OPEN c_first_supa (l_maas_rec.start_date
                              ,l_suac_ref_num
                              ,l_maas_rec.sety_ref_num  -- CHG-4803
                              );
            FETCH c_first_supa INTO l_first_supa_start;
            CLOSE c_first_supa;

            /*
              ** Get service price
            */
            get_period_ma_serv_price
                    (p_maac_ref_num   --p_maac_ref_num      IN     master_accounts_v.ref_num%TYPE
                    ,l_maas_rec.maas_ref_num   --p_maas_ref_num      IN     master_account_services.ref_num%TYPE
                    ,l_maas_rec.sety_ref_num   --p_sety_ref_num      IN     service_types.ref_num%TYPE
                    ,p_period_start   --p_period_start      IN     DATE
                    ,p_period_end   --p_period_end        IN     DATE
                    ,GREATEST (l_maas_rec.start_date, NVL (l_first_supa_start, l_maas_rec.start_date))   -- CHG-4635   --p_sety_start_date   IN     DATE
                    ,l_maas_rec.end_date   --p_sety_end_date     IN     DATE
                    ,l_price   --p_price                OUT NUMBER
                    ,l_taty_type_code   --p_taty_type_code       OUT tax_types.tax_type_code%TYPE
                    ,l_billing_selector   --p_billing_selector     OUT billing_selectors_v.type_code%TYPE
                    ,l_fcit_type_code   --p_fcit_type_code       OUT fixed_charge_item_types.type_code%TYPE
                    ,l_charge_parameter   --p_charge_parameter     OUT fixed_charge_item_types.valid_charge_parameter%TYPE
                    ,l_priced_sepv_ref_num   --p_priced_sepv_ref_num  OUT     master_service_parameters.sepv_ref_num%TYPE
                    );

            --

            /*
              ** Toimub hinna asendamine vastavalt määratud määrangule.
              ** Kui määrangud on määramata, leitakse perioodil kehtinud maksimaalne hind.
            */
            IF l_charge_parameter = 'FIRST' THEN
               IF l_inen_tab (l_idx).eek_amt IS NULL THEN
                  l_inen_tab (l_idx).acc_amount := ROUND (l_price, g_get_inen_acc_precision);   -- CHG4594
                  l_inen_tab (l_idx).eek_amt := ROUND (l_inen_tab (l_idx).acc_amount, 2);   -- CHG4594
                  l_inen_tab (l_idx).taty_type_code := l_taty_type_code;
                  l_inen_tab (l_idx).billing_selector := l_billing_selector;
                  l_inen_tab (l_idx).fcit_type_code := l_fcit_type_code;
                  l_inen_tab (l_idx).maas_ref_num := l_maas_rec.maas_ref_num;   -- CHG-4707: temporary container for discounts
                  l_inen_tab (l_idx).cadc_ref_num := l_priced_sepv_ref_num;   -- CHG-4707: temporary container for discounts
               END IF;
            ELSIF l_charge_parameter = 'LAST' THEN
               l_inen_tab (l_idx).acc_amount := ROUND (l_price, g_get_inen_acc_precision);   -- CHG4594
               l_inen_tab (l_idx).eek_amt := ROUND (l_inen_tab (l_idx).acc_amount, 2);   -- CHG4594
               l_inen_tab (l_idx).taty_type_code := l_taty_type_code;
               l_inen_tab (l_idx).billing_selector := l_billing_selector;
               l_inen_tab (l_idx).fcit_type_code := l_fcit_type_code;
               l_inen_tab (l_idx).maas_ref_num := l_maas_rec.maas_ref_num;   -- CHG-4707: temporary container for discounts
               l_inen_tab (l_idx).cadc_ref_num := l_priced_sepv_ref_num;   -- CHG-4707: temporary container for discounts
            ELSIF l_charge_parameter = 'BIGGEST' THEN
               IF NVL (l_inen_tab (l_idx).eek_amt, 0) < l_price THEN
                  l_inen_tab (l_idx).acc_amount := ROUND (l_price, g_get_inen_acc_precision);   -- CHG4594
                  l_inen_tab (l_idx).eek_amt := ROUND (l_inen_tab (l_idx).acc_amount, 2);   -- CHG4594
                  l_inen_tab (l_idx).taty_type_code := l_taty_type_code;
                  l_inen_tab (l_idx).billing_selector := l_billing_selector;
                  l_inen_tab (l_idx).fcit_type_code := l_fcit_type_code;
                  l_inen_tab (l_idx).maas_ref_num := l_maas_rec.maas_ref_num;   -- CHG-4707: temporary container for discounts
                  l_inen_tab (l_idx).cadc_ref_num := l_priced_sepv_ref_num;   -- CHG-4707: temporary container for discounts
               END IF;
            ELSIF l_charge_parameter = 'SMALLEST' THEN
               IF l_inen_tab (l_idx).eek_amt >= l_price OR l_inen_tab (l_idx).eek_amt IS NULL THEN
                  l_inen_tab (l_idx).acc_amount := ROUND (l_price, g_get_inen_acc_precision);   -- CHG4594
                  l_inen_tab (l_idx).eek_amt := ROUND (l_inen_tab (l_idx).acc_amount, 2);   -- CHG4594
                  l_inen_tab (l_idx).taty_type_code := l_taty_type_code;
                  l_inen_tab (l_idx).billing_selector := l_billing_selector;
                  l_inen_tab (l_idx).fcit_type_code := l_fcit_type_code;
                  l_inen_tab (l_idx).maas_ref_num := l_maas_rec.maas_ref_num;   -- CHG-4707: temporary container for discounts
                  l_inen_tab (l_idx).cadc_ref_num := l_priced_sepv_ref_num;   -- CHG-4707: temporary container for discounts
               END IF;
            ELSE
               IF NVL (l_price, 0) > NVL (l_inen_tab (l_idx).eek_amt, 0) THEN
                  l_inen_tab (l_idx).acc_amount := ROUND (l_price, g_get_inen_acc_precision);   -- CHG4594
                  l_inen_tab (l_idx).eek_amt := ROUND (l_inen_tab (l_idx).acc_amount, 2);   -- CHG4594
                  l_inen_tab (l_idx).taty_type_code := l_taty_type_code;
                  l_inen_tab (l_idx).billing_selector := l_billing_selector;
                  l_inen_tab (l_idx).fcit_type_code := l_fcit_type_code;
               END IF;
            END IF;
         END IF;   -- check charges

         --
         l_prev_sety_ref_num := l_maas_rec.sety_ref_num;
      --
      END LOOP;

      /*
        ** Now write down common montly charges and create Solution Fee SQL table
      */
      l_idx := l_inen_tab.FIRST;
      l_calc_idx := 0;
      l_calc_tab.DELETE;

      --
      WHILE l_idx IS NOT NULL LOOP
         --
         l_fcit_rec := NULL;

         --
         OPEN c_fcit (l_inen_tab (l_idx).fcit_type_code);
         FETCH c_fcit INTO l_fcit_rec;
         CLOSE c_fcit;
         --
         l_new_fcit_type_code := l_fcit_rec.type_code;  -- CHG-4803
         

         IF l_fcit_rec.bill_fcit_type_code IS NOT NULL THEN
            --
            OPEN c_fcit (l_fcit_rec.bill_fcit_type_code);
            FETCH c_fcit INTO l_bill_fcit_rec;
            CLOSE c_fcit;
            --
            l_new_fcit_type_code := l_bill_fcit_rec.type_code; -- CHG-4803

            /*
              ** Add Service fee to Common_Monthly_Charges table
            */
            IF NOT p_interim THEN
               --
               icalculate_fixed_charges.ins_common_monthly_charges (l_inen_tab (l_idx));
            --
            END IF;
            --
         END IF; -- CHG-4803

            /*
              ** Add Service fee to Calculated fee tab.
            */
            l_exists := FALSE;
            l_calc_idx := l_calc_tab.FIRST;

            -- Sum if FCIT exists
            WHILE l_calc_idx IS NOT NULL LOOP
               IF l_calc_tab (l_calc_idx).fcit_type_code = l_new_fcit_type_code THEN
                  l_calc_tab (l_calc_idx).acc_amount := ROUND (  l_calc_tab (l_calc_idx).acc_amount
                                                               + NVL (l_inen_tab (l_idx).eek_amt, 0)
                                                              ,g_get_inen_acc_precision
                                                              );   -- CHG4594
                  l_calc_tab (l_calc_idx).eek_amt := ROUND (l_calc_tab (l_calc_idx).acc_amount, 2);   -- CHG4594
                  --
                  l_exists := TRUE;
               END IF;

               --
               l_calc_idx := l_calc_tab.NEXT (l_calc_idx);
            END LOOP;

            -- Add new FCIT
            IF NOT l_exists THEN
               l_calc_idx := l_calc_tab.COUNT + 1;
               --
               l_calc_tab (l_calc_idx).fcit_type_code := l_new_fcit_type_code;
               l_calc_tab (l_calc_idx).acc_amount := ROUND (NVL (l_inen_tab (l_idx).eek_amt, 0)
                                                           ,g_get_inen_acc_precision);   -- CHG4594
               l_calc_tab (l_calc_idx).eek_amt := ROUND (l_calc_tab (l_calc_idx).acc_amount, 2);   -- CHG4594
            END IF;

            /*
              ** CHG-4707: Add Master level service discounts
            */
            IF NVL (l_inen_tab (l_idx).eek_amt, 0) > 0 THEN
               --
               iprocess_monthly_service_fees.chk_one_maac_ma_discounts
                  (l_inen_tab (l_idx).maas_ref_num   --p_maas_ref_num      IN       master_account_services.ref_num%TYPE
                  ,l_inen_tab (l_idx).cadc_ref_num   --p_charged_sepv_ref  IN       master_service_parameters.sepv_ref_num%TYPE
                  ,p_period_start   --p_period_start      IN       DATE
                  ,p_period_end   --p_period_end        IN       DATE
                  ,l_inen_tab (l_idx).eek_amt   --p_price             IN       NUMBER
                  ,p_invo_ref_num   --p_invo_ref_num      IN       invoices.ref_num%TYPE
                  ,p_interim   --p_interim           IN       BOOLEAN DEFAULT FALSE
                  );
            --
            END IF;

         l_idx := l_inen_tab.NEXT (l_idx);
      END LOOP;

      /*
        ** Now add Calculated fees to l_inen_tab.
      */
      l_calc_idx := l_calc_tab.FIRST;
      l_inen_tab.DELETE;

      WHILE l_calc_idx IS NOT NULL LOOP
         IF l_calc_idx >= 100 THEN
            -- Avoid loop lock
            EXIT;
         END IF;

         OPEN c_fcit (l_calc_tab (l_calc_idx).fcit_type_code);

         FETCH c_fcit
          INTO l_fcit_rec;

         CLOSE c_fcit;

         create_nonker_serv_fee_inen
                                    (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                    ,NULL   -- IN     subs_serv_groups.ref_num%TYPE
                                    ,l_fcit_rec.sety_ref_num  -- CHG-4803   -- IN     service_types.ref_num%TYPE
                                    ,TRUNC (p_period_start, 'MM')   -- CHG-4535: Check full charging period     -- IN     DATE
                                    ,p_period_end   -- IN     DATE
                                    ,l_fcit_rec.type_code   -- IN     fixed_charge_item_types.type_code%TYPE
                                    ,l_fcit_rec.taty_type_code   -- IN     fixed_charge_item_types.taty_type_code%TYPE
                                    ,l_fcit_rec.billing_selector   -- IN     fixed_charge_item_types.billing_selector%TYPE
                                    ,l_calc_tab (l_calc_idx).eek_amt   -- IN     NUMBER
                                    ,l_inen_tab   -- IN OUT Calculate_Fixed_Charges.t_inen
                                    ,l_inen_price   -- CHG-3984
                                    );
         --
         l_calc_idx := l_calc_tab.NEXT (l_calc_idx);
      END LOOP;

      /*
        ** Now add calculated charges to invoice entries.
      */
      l_calc_idx := l_calc_tab.FIRST;

      --
      IF l_calc_idx IS NOT NULL THEN
         --
         invoice_maac_nonker_serv_fees
            (p_maac_ref_num   --p_maac_ref_num IN     accounts.ref_num%TYPE
            ,p_period_start   --p_period_start IN     DATE
            ,l_inen_tab   --p_inen_tab     IN OUT Calculate_Fixed_Charges.t_inen
            ,l_success   --p_success         OUT BOOLEAN
            ,l_error_text   --p_error_text      OUT VARCHAR2
            ,p_invo_ref_num   --p_invo_ref_num IN     invoices.ref_num%TYPE -- vahearvete, vahesaldode korral on arve ref teada
            ,p_interim   --p_interim      IN     BOOLEAN
            );
      --
      END IF;
   --
   EXCEPTION
      WHEN e_do_not_charge THEN
         NULL;
   END chk_one_maac_ma_calculated_fee;

   /****************************************************************************
   **
   **   Function Name:   GET_PERIOD_MA_SERV_PRICE
   **
   **   Description:     Protseduur leiab Master teenuse kuutasu
   **
   *****************************************************************************/
   PROCEDURE get_period_ma_serv_price (
      p_maac_ref_num         IN      master_accounts_v.ref_num%TYPE
     ,p_maas_ref_num         IN      master_account_services.ref_num%TYPE
     ,p_sety_ref_num         IN      service_types.ref_num%TYPE
     ,p_period_start         IN      DATE
     ,p_period_end           IN      DATE
     ,p_sety_start_date      IN      DATE
     ,p_sety_end_date        IN      DATE
     ,p_price                OUT     NUMBER
     ,p_taty_type_code       OUT     tax_types.tax_type_code%TYPE
     ,p_billing_selector     OUT     billing_selectors_v.type_code%TYPE
     ,p_fcit_type_code       OUT     fixed_charge_item_types.type_code%TYPE
     ,p_charge_parameter     OUT     fixed_charge_item_types.valid_charge_parameter%TYPE
     ,p_priced_sepv_ref_num  OUT     master_service_parameters.sepv_ref_num%TYPE   -- CHG-4707
   ) IS
      --
      CURSOR c_prli IS
         SELECT fcit.type_code fcit_type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,fcit.valid_charge_parameter charge_parameter   -- CHG-2795
               ,fcit.first_prorated_charge first_prorated_charge
               ,fcit.last_prorated_charge  last_prorated_charge   -- CHG-6214
               ,prli.charge_value charge_value
               ,prli.sepv_ref_num sepv_ref_num
               ,prli.sepa_ref_num sepa_ref_num
               ,GREATEST (prli.start_date, p_period_start) start_date
               ,LEAST (NVL (prli.end_date, p_period_end), p_period_end) end_date
               ,fcit.free_periods free_periods
           FROM price_lists prli, fixed_charge_item_types fcit
          WHERE prli.sety_ref_num = p_sety_ref_num
            AND prli.channel_type IS NULL
            AND NVL (prli.par_value_charge, 'N') = 'N'
            AND prli.once_off = 'N'
            AND prli.pro_rata = 'N'
            AND prli.regular_charge = 'Y'
            AND fcit.once_off = 'N'
            AND fcit.pro_rata = 'N'
            AND fcit.regular_charge = 'Y'
            AND prli.sety_ref_num = fcit.sety_ref_num
            AND fcit.package_category IS NULL
            AND prli.start_date <= p_period_end
            AND NVL (prli.end_date, p_period_end) >= p_period_start;

      --
      CURSOR c_masp (
         p_sepa_ref_num  NUMBER
      ) IS
         SELECT   sepv_ref_num
                 ,GREATEST (start_date, p_period_start) start_date
                 ,LEAST (NVL (end_date, p_period_end), p_period_end) end_date
             FROM master_service_parameters
            WHERE maas_ref_num = p_maas_ref_num
              AND sepa_ref_num = p_sepa_ref_num
              AND start_date <= p_period_end
              AND NVL (end_date, p_period_end) >= p_period_start
         ORDER BY start_date
      ;
      -- CHG-6214
      CURSOR c_act_supa IS
         SELECT end_date
         FROM subs_packages  supa
            , accounts       acco
         WHERE acco.maac_ref_num = p_maac_ref_num
           AND acco.ref_num = supa.suac_ref_num
           AND supa.sept_type_code IN (select sept_type_code 
                                       from service_types 
                                       where ref_num = p_sety_ref_num)
           AND (end_date IS NULL OR end_date BETWEEN p_period_start AND p_period_end)
         ORDER BY end_date DESC
      ;
      --
      l_fcit_type_code_tab          t_char3;
      l_taty_type_code_tab          t_char1;
      l_bise_tab                    t_char3;
      l_charge_value_tab            t_number;
      l_charge_parameter_tab        t_char10;
      l_first_prorated_charge_tab   t_char1;
      l_last_prorated_charge_tab    t_char1;  -- CHG-6214
      l_sepv_ref_num_tab            t_ref_num;
      l_sepa_ref_num_tab            t_ref_num;
      l_prli_start_tab              t_date;
      l_prli_end_tab                t_date;
      l_free_periods_tab            t_number;
      l_masp_sepv_tab               t_ref_num;
      l_masp_start_tab              t_date;
      l_masp_end_tab                t_date;
      --
      l_prli_idx                    NUMBER;
      l_masp_idx                    NUMBER;
      l_susp_prorated_idx           NUMBER;
      l_found_sepa_ref_num          service_parameters.ref_num%TYPE;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_charge_parameter            fixed_charge_item_types.valid_charge_parameter%TYPE;
      l_last_closed_supa            subs_packages.end_date%TYPE;  -- CHG-6214
      l_last_sept_closed_date       subs_packages.end_date%TYPE;  -- CHG-6214
      l_first                       BOOLEAN;
      l_last                        BOOLEAN;
      l_smallest                    BOOLEAN;
      l_biggest                     BOOLEAN;
      l_prorated                    BOOLEAN;
      l_prorated_last               BOOLEAN;  -- CHG-6214
      l_unspecified                 BOOLEAN;
      l_found                       BOOLEAN;  -- CHG-6214
      l_dummy                       NUMBER;   -- CHG-6214
      l_max_price                   NUMBER;
      l_sum_price                   NUMBER;
      l_num_of_days                 NUMBER;
      l_num_days                    NUMBER;
      l_days_charge                 NUMBER;
      l_diff_charge                 NUMBER;
      l_free_periods                NUMBER;
   --
   BEGIN
      /*
        ** Leiame ette antud ajavahemikul teenusele määratud hinnakirja- ja erihinnad.
      */
      OPEN c_prli;

      FETCH c_prli
      BULK COLLECT INTO l_fcit_type_code_tab
            ,l_taty_type_code_tab
            ,l_bise_tab
            ,l_charge_parameter_tab
            ,l_first_prorated_charge_tab
            ,l_last_prorated_charge_tab  -- CHG-6214
            ,l_charge_value_tab
            ,l_sepv_ref_num_tab
            ,l_sepa_ref_num_tab
            ,l_prli_start_tab
            ,l_prli_end_tab
            ,l_free_periods_tab;

      CLOSE c_prli;

      /*
        ** Kontrollime hinnakirjast, kas esineb hinda parameetri väärtuse alusel ja leiame vajadusel
        ** parameetri väärtuste vahemikud.
      */
      l_prli_idx := l_fcit_type_code_tab.FIRST;

      --
      WHILE l_prli_idx IS NOT NULL LOOP
         --
         IF l_free_periods_tab (l_prli_idx) IS NOT NULL THEN
            l_free_periods := l_free_periods_tab (l_prli_idx);
         END IF;

         --
         IF l_sepa_ref_num_tab (l_prli_idx) IS NOT NULL THEN
            l_found_sepa_ref_num := l_sepa_ref_num_tab (l_prli_idx);
            EXIT;
         END IF;

         --
         l_prli_idx := l_fcit_type_code_tab.NEXT (l_prli_idx);
      END LOOP;

      /*
        ** Kui leidub parameetri väärtuse alusel hindamist, siis leiame teenuse parameetri väärtuste
        ** perioodid. Kui parameetri väärtuse alusel hindamist pole, siis on k?ik 1 periood.
      */
      IF l_found_sepa_ref_num IS NOT NULL THEN
         OPEN c_masp (l_found_sepa_ref_num);

         FETCH c_masp
         BULK COLLECT INTO l_masp_sepv_tab
               ,l_masp_start_tab
               ,l_masp_end_tab;

         CLOSE c_masp;
      ELSE
         l_masp_start_tab (1) := p_period_start;
         l_masp_end_tab (1) := p_period_end;
         l_masp_sepv_tab (1) := NULL;
      END IF;

      /*
        ** Järgnevalt paneme kokku hinnatavate perioodide tabeli lähtudes teenusparameetri väärtuse perioodidest.
      */
      l_masp_idx := l_masp_start_tab.FIRST;

      --
      WHILE l_masp_idx IS NOT NULL LOOP
         --
         l_first := FALSE;
         l_last := FALSE;
         l_smallest := FALSE;
         l_biggest := FALSE;
         l_prorated := FALSE;
         l_prorated_last := FALSE;  -- CHG-6214
         l_unspecified := FALSE;
         /*
           ** Käime läbi PL/SQL tabelitesse salvestatud hinnakirja alates prioriteetsematest hindadest
           ** (erihinnad mobiilile) ja salvestame hinnatud vahemikud. Hindamata jäänud vahemikud
           ** hindame seejärel vähemprioriteetsete hindadega (erihinnad paketile -> hinnakirja hinnad paketikategooriale ->
           ** üldised hinnakirja hinnad).
         */
         l_prli_idx := l_fcit_type_code_tab.FIRST;

         --
         WHILE l_prli_idx IS NOT NULL LOOP
            /*
              ** CHG-2795: Väärtustame määrangute lipud
            */
            IF l_prli_idx = 1 THEN
               IF l_charge_parameter_tab (l_prli_idx) = 'FIRST' THEN
                  l_first := TRUE;
               ELSIF l_charge_parameter_tab (l_prli_idx) = 'LAST' THEN
                  l_last := TRUE;
               ELSIF l_charge_parameter_tab (l_prli_idx) = 'SMALLEST' THEN
                  l_smallest := TRUE;
               ELSIF l_charge_parameter_tab (l_prli_idx) = 'BIGGEST' THEN
                  l_biggest := TRUE;
               ELSE
                  l_unspecified := TRUE;
               END IF;

               --
               IF l_first_prorated_charge_tab (l_prli_idx) = 'Y' THEN
                  l_prorated := TRUE;
               END IF;
               
               -- CHG-6214
               IF l_last_prorated_charge_tab (l_prli_idx) = 'Y' THEN
                  /*
                    ** Check if all service related MAAC packages are still open. 
                    ** If all closed, then charge prorata
                  */
                  l_last_closed_supa := NULL;
                  --
                  OPEN  c_act_supa;
                  FETCH c_act_supa INTO l_last_closed_supa;
                  l_found := c_act_supa%FOUND;
                  CLOSE c_act_supa;
                  --
                  IF l_found AND l_last_closed_supa IS NOT NULL THEN
                     l_prorated := TRUE;
                     l_prorated_last := TRUE;
                     l_last_sept_closed_date := l_last_closed_supa;
                  END IF;
                  --
               END IF;
               
                  --
                  /*IF l_prorated_by_sety_tab(l_prli_idx) = 'Y' THEN
                     l_prorated_by_sety_dates := TRUE;
            END IF;*/
            END IF;

            --
            IF     l_prli_start_tab (l_prli_idx) <= l_masp_end_tab (l_masp_idx)
               AND l_prli_end_tab (l_prli_idx) >= TRUNC (l_masp_start_tab (l_masp_idx))
               AND   -- Teenusparameetrid ajafaktoriga, hinnakiri päeva täpsusega
                   (   l_sepv_ref_num_tab (l_prli_idx) IS NULL
                    OR l_sepv_ref_num_tab (l_prli_idx) = l_masp_sepv_tab (l_masp_idx)
                   ) THEN
               /*
                 ** Fikseeritud kuutasuga mobiilitaseme teenuste kuutasu arvutatakse vastavalt
                 ** tellimuses toodud häälestuse variantidele.
               */
               IF l_first THEN
                  -- Esimene kehtiv kuutasu
                  IF l_prli_idx = 1 THEN
                     --
                     l_max_price := l_charge_value_tab (l_prli_idx);
                     l_taty_type_code := l_taty_type_code_tab (l_prli_idx);
                     l_billing_selector := l_bise_tab (l_prli_idx);
                     l_fcit_type_code := l_fcit_type_code_tab (l_prli_idx);
                     l_charge_parameter := l_charge_parameter_tab (l_prli_idx);
                     p_priced_sepv_ref_num := l_sepv_ref_num_tab (l_prli_idx);

                     --
                     IF l_prorated THEN
                        l_susp_prorated_idx := l_masp_idx;
                     END IF;
                  END IF;
               --
               ELSIF l_smallest THEN
                  -- Väikseim erinevatest kuutasudest
                  IF l_charge_value_tab (l_prli_idx) < l_max_price OR l_max_price IS NULL THEN
                     --
                     l_max_price := l_charge_value_tab (l_prli_idx);
                     l_taty_type_code := l_taty_type_code_tab (l_prli_idx);
                     l_billing_selector := l_bise_tab (l_prli_idx);
                     l_fcit_type_code := l_fcit_type_code_tab (l_prli_idx);
                     l_charge_parameter := l_charge_parameter_tab (l_prli_idx);
                     p_priced_sepv_ref_num := l_sepv_ref_num_tab (l_prli_idx);

                     --
                     IF l_prorated THEN
                        l_susp_prorated_idx := l_masp_idx;
                     END IF;
                  END IF;
               --
               ELSIF l_biggest THEN
                  -- Suurim erinevatest kuutasudest
                  IF l_charge_value_tab (l_prli_idx) > l_max_price OR l_max_price IS NULL THEN   -- CHG-3714: OR l_max_price IS NULL
                     --
                     l_max_price := l_charge_value_tab (l_prli_idx);
                     l_taty_type_code := l_taty_type_code_tab (l_prli_idx);
                     l_billing_selector := l_bise_tab (l_prli_idx);
                     l_fcit_type_code := l_fcit_type_code_tab (l_prli_idx);
                     l_charge_parameter := l_charge_parameter_tab (l_prli_idx);
                     p_priced_sepv_ref_num := l_sepv_ref_num_tab (l_prli_idx);

                     --
                     IF l_prorated THEN
                        l_susp_prorated_idx := l_masp_idx;
                     END IF;
                  END IF;
               --
               ELSIF l_last THEN
                  -- Viimane kehtiv kuutasu
                  l_max_price := l_charge_value_tab (l_prli_idx);
                  l_taty_type_code := l_taty_type_code_tab (l_prli_idx);
                  l_billing_selector := l_bise_tab (l_prli_idx);
                  l_fcit_type_code := l_fcit_type_code_tab (l_prli_idx);
                  l_charge_parameter := l_charge_parameter_tab (l_prli_idx);
                  p_priced_sepv_ref_num := l_sepv_ref_num_tab (l_prli_idx);

                  --
                  IF l_prorated THEN
                     l_susp_prorated_idx := l_masp_idx;
                  END IF;
               --
               ELSE
                  --Määrangud määramata
                  IF l_charge_value_tab (l_prli_idx) > l_max_price OR l_max_price IS NULL THEN   -- CHG-3714: OR l_max_price IS NULL
                     l_max_price := l_charge_value_tab (l_prli_idx);
                     l_taty_type_code := l_taty_type_code_tab (l_prli_idx);
                     l_billing_selector := l_bise_tab (l_prli_idx);
                     l_fcit_type_code := l_fcit_type_code_tab (l_prli_idx);
                     l_charge_parameter := l_charge_parameter_tab (l_prli_idx);
                  END IF;

                  --
                  IF l_prorated THEN
                     l_susp_prorated_idx := l_masp_idx;
                  END IF;
               --
               END IF;
            --
            END IF;

            --
            l_prli_idx := l_fcit_type_code_tab.NEXT (l_prli_idx);
         END LOOP;

         --Määrangud määramata, arveldusperioodi erinevad kuutasud summeeritakse
         IF l_unspecified THEN
            l_sum_price := l_sum_price + l_max_price;   -- CHG-2795
         END IF;

         --
         l_masp_idx := l_masp_start_tab.NEXT (l_masp_idx);
      END LOOP;

      /*
        ** Liitumiskuul/lõpetamiskuul päevapõhine
      */
      IF (l_prorated AND 
         p_sety_start_date > p_period_start AND 
         NVL (p_sety_end_date, p_period_end) >= p_period_end ) 
         OR
         l_prorated_last  -- CHG-6214: Lõpetamiskuu
      THEN
         -- Leida num_of_days
         IF l_prorated_last THEN  -- CHG-6214: Lõpetamisekuul päevade arvu loogika teine
            l_num_of_days := Trunc(l_last_sept_closed_date) - TRUNC (Greatest(p_sety_start_date, p_period_start)) + 1;
         ELSE
            l_num_of_days := TRUNC (p_period_end) - TRUNC (Greatest(p_sety_start_date, p_period_start)) + 1;
         END IF;
         -- Kuutasu päevade põhiseks
         l_num_days := TO_NUMBER (TO_CHAR (LAST_DAY (p_period_end), 'dd'));
         l_days_charge := (l_max_price / l_num_days) * l_num_of_days;
         -- Leida vahe korrigeerimiseks
         l_diff_charge := l_max_price - l_days_charge;

         -- Leida vahe korrigeerimiseks, kui määrangud määramata.
         IF NVL (l_sum_price, 0) > 0 THEN
            l_diff_charge := l_sum_price - ((l_sum_price / l_num_days) * l_num_of_days);
         END IF;
      END IF;

      /*
        ** Protseduuri väljundi moodustamine: max hind + sellele vastavast reast arvele kandmise atribuudid (FCIT, BISE, TATY).
      */
      IF l_max_price IS NOT NULL OR l_sum_price IS NOT NULL THEN
         --
         IF p_period_end < TRUNC (ADD_MONTHS (p_sety_start_date, NVL (l_free_periods, 0)), 'MM') THEN
            p_price := NULL;   -- Free period, do not charge
         ELSIF NVL (l_sum_price, 0) > 0 THEN
            p_price := l_sum_price - NVL (l_diff_charge, 0);
         ELSE
            p_price := l_max_price - NVL (l_diff_charge, 0);
         END IF;

         --
         p_price := ROUND (p_price, 2);
         p_fcit_type_code := l_fcit_type_code;
         p_billing_selector := l_billing_selector;
         p_taty_type_code := l_taty_type_code;
         p_charge_parameter := l_charge_parameter;
      END IF;
   --
   END get_period_ma_serv_price;

   /****************************************************************************
   **
   **   Function Name:   CHK_ONE_MAAC_MA_DISCOUNTS
   **
   **   Description:     Protseduur leiab Master teenuse kuutasu soodustused.
   **
   *****************************************************************************/
   PROCEDURE chk_one_maac_ma_discounts (
      p_maas_ref_num      IN  master_account_services.ref_num%TYPE
     ,p_charged_sepv_ref  IN  master_service_parameters.sepv_ref_num%TYPE
     ,p_period_start      IN  DATE
     ,p_period_end        IN  DATE
     ,p_price             IN  NUMBER
     ,p_invo_ref_num      IN  invoices.ref_num%TYPE
     ,p_interim           IN  BOOLEAN DEFAULT FALSE
   ) IS
      --
      CURSOR c_maas IS
         SELECT *
           FROM master_account_services
          WHERE ref_num = p_maas_ref_num;

      --
      CURSOR c_cadc (
         p_maac_ref_num  master_account_services.maac_ref_num%TYPE
        ,p_sety_ref_num  master_account_services.sety_ref_num%TYPE
      ) IS
         SELECT cadc.*
           FROM master_service_adjustments masa, call_discount_codes cadc
          WHERE masa.maac_ref_num = p_maac_ref_num
            AND masa.sety_ref_num = p_sety_ref_num
            AND masa.dico_ref_num = cadc.dico_ref_num
            AND masa.sety_ref_num = cadc.for_sety_ref_num
            AND NVL (cadc.for_sepv_ref_num, NVL (p_charged_sepv_ref, -1)) = NVL (p_charged_sepv_ref, -1)
            AND cadc.call_type = 'REGU'
            AND masa.start_date <= p_period_end
            AND NVL (masa.end_date, p_period_start) >= p_period_start
            AND cadc.start_date <= p_period_end
            AND NVL (cadc.end_date, p_period_start) >= p_period_start;

      --
      CURSOR c_inen (
         p_maac_ref_num      IN  master_account_services.maac_ref_num%TYPE
        ,p_cadc_ref_num      IN  call_discount_codes.ref_num%TYPE
        ,p_billing_selector  IN  call_discount_codes.disc_billing_selector%TYPE
      ) IS
         SELECT SUM (inen.eek_amt)
           FROM invoice_entries inen, invoices invo
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start AND p_period_end
            AND inen.invo_ref_num = invo.ref_num
            AND inen.susg_ref_num IS NULL
            AND inen.billing_selector = p_billing_selector
            AND inen.cadc_ref_num = p_cadc_ref_num;

      CURSOR c_fcit (
         p_fcit_type_code  VARCHAR2
      ) IS
         SELECT *
           FROM fixed_charge_item_types
          WHERE type_code = p_fcit_type_code;

      --
      l_inen_idx                    NUMBER;
      l_inen_tab                    icalculate_fixed_charges.t_inen;
      l_inen_sum_tab                icalculate_fixed_charges.t_inen_sum;
      l_maas_rec                    master_account_services%ROWTYPE;
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;
      l_disc_amount                 NUMBER;
      l_inen_price                  NUMBER;
      l_invoiced_sum                NUMBER;
      l_sum_to_invoice              NUMBER;
      l_success                     BOOLEAN;
      l_error_text                  VARCHAR2 (500);
   BEGIN
      -- Get MAAS record
      OPEN c_maas;

      FETCH c_maas
       INTO l_maas_rec;

      CLOSE c_maas;

      l_inen_tab.DELETE;

      --
      FOR l_cadc_rec IN c_cadc (l_maas_rec.maac_ref_num, l_maas_rec.sety_ref_num) LOOP
         --
         l_disc_amount := NULL;
         l_invoiced_sum := 0;
         --
         l_disc_amount :=
            icalculate_discounts.get_ma_serv_discount_amount
                             (p_price   --p_full_chg_value    IN  NUMBER
                             ,p_price   --p_remain_chg_value  IN  NUMBER
                             ,l_cadc_rec.minimum_price   --p_cadc_min_price    IN  call_discount_codes.minimum_price%TYPE
                             ,l_cadc_rec.precentage   --p_percentage        IN  call_discount_codes.precentage%TYPE
                             ,l_cadc_rec.pricing   --p_discount_schema   IN  call_discount_codes.pricing%TYPE
                             );

         --
         IF NVL (l_disc_amount, 0) > 0 THEN
            --
            OPEN c_inen (l_maas_rec.maac_ref_num, l_cadc_rec.ref_num, l_cadc_rec.disc_billing_selector);

            FETCH c_inen
             INTO l_invoiced_sum;

            CLOSE c_inen;

            l_sum_to_invoice := l_disc_amount - NVL (l_invoiced_sum, 0) * (-1);

            --
            IF l_sum_to_invoice > 0 THEN
               --
               OPEN c_fcit (l_cadc_rec.for_fcit_type_code);

               FETCH c_fcit
                INTO l_fcit_rec;

               CLOSE c_fcit;

               --
               icalculate_discounts.invoice_discount
                    (NULL   --p_maas_ref_num      IN      master_account_services.ref_num%TYPE
                    ,p_invo_ref_num   --p_invo_ref_num      IN      invoices.ref_num%TYPE
                    ,NULL   --p_inen_rowid        IN      VARCHAR2
                    ,l_sum_to_invoice   --p_discounted_value  IN      NUMBER
                    ,l_cadc_rec   --p_cadc_rec          IN      call_discount_codes%ROWTYPE
                    ,p_period_start   --p_chk_date          IN      DATE
                    ,l_fcit_rec.fcdt_type_code   --p_fcdt_type_code    IN      fixed_charge_item_types.fcdt_type_code%TYPE
                    ,l_success   --p_success           OUT     BOOLEAN
                    ,l_error_text   --p_message           OUT     VARCHAR2
                    );
            --
            END IF;
         --
         END IF;
      --
      END LOOP;
   --
   END chk_one_maac_ma_discounts;
   /****************************************************************************
   **
   **   Function Name:   GET_TEST_PERIOD_DATA
   **
   **   Description:     Protseduur leiab, kas on tegemist PAK müügi tagastamisega testperioodis.
   **                    Kui on tegemist tagastamisega, siis protseduur väljastab:
   **                     - mixed_packet_orders.sept_category_type
   **                     - mixed_packet_orders.newmob_order
   **
   **                    Kui sept_category_type = MBB ja newmob_order = N, siis tagastatakse ka
   **                    enne testperioodi kehtinud GPRS maksustamise parameeter.
   **
   *****************************************************************************/
   PROCEDURE Get_Test_Period_Data (p_ebs_order_number     IN      mixed_packet_orders.ebs_order_number%TYPE
                                  ,p_susg_ref_num           IN      subs_serv_groups.ref_num%TYPE
                                  ,p_period_start         IN      DATE
                                  ,p_period_end           IN      DATE
                                  ,p_sept_category_type      OUT  mixed_packet_orders.sept_category_type%TYPE
                                  ,p_newmob_order            OUT  mixed_packet_orders.newmob_order%TYPE
                                  ,p_prev_sepv_ref_num       OUT  subs_service_parameters.sepv_ref_num%TYPE
   ) IS
      --
      CURSOR c_mipo IS
         SELECT sept_category_type
              , newmob_order
              , start_date
         FROM mixed_packet_orders
         WHERE ebs_order_number = p_ebs_order_number
           AND test_period = 'Y'
           AND term_request_type = 'RETURNS'
           AND term_request_date BETWEEN start_date AND (Trunc(test_end_date) + 1 - 1/86000)
           AND term_request_date BETWEEN p_period_start AND p_period_end
      ;
      --
      CURSOR c_last_sepv (p_chk_date  DATE) IS
         SELECT susp.sepv_ref_num
         FROM subs_service_parameters susp
            , service_parameters      sepa
            , service_types           sety
         WHERE susp.sety_ref_num = sety.ref_num
           AND susp.sepa_ref_num = sepa.ref_num
           AND sepa.sety_ref_num = sety.ref_num
           AND sety.service_name = 'CHGGP'
           AND sepa.nw_param_name = 'CHARGETYPE'
           AND susp.susg_ref_num = p_susg_ref_num
           AND Trunc(susp.end_date) = Trunc(p_chk_date)
         ORDER BY susp.start_date desc
      ;
      --
      l_mipo_start_date  DATE;
   BEGIN
      --
      OPEN  c_mipo;
      FETCH c_mipo INTO p_sept_category_type
                      , p_newmob_order
                      , l_mipo_start_date;
      CLOSE c_mipo;
      --
      IF p_sept_category_type = 'MBB' AND p_newmob_order = 'N' THEN
         /*
           ** MBB ja newmob_order puhul leiame enne testperioodiga PAK-i kehtinud GPRS maksustamise parameetri
         */
         OPEN  c_last_sepv (l_mipo_start_date);
         FETCH c_last_sepv INTO p_prev_sepv_ref_num;
         CLOSE c_last_sepv;
         --
      END IF;
      --
   END Get_Test_Period_Data;

   
    
--
END iprocess_monthly_service_fees;
/