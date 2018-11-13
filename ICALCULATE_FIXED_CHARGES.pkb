CREATE OR REPLACE PACKAGE BODY TBCIS.iCALCULATE_FIXED_CHARGES IS
   --
   --Module BCCU659
   --

   /*
     ** Local Type Declarations
   */

   /*
     ** Local Constants
   */
   c_common_mon_chg_service CONSTANT VARCHAR2 (5) := 'YKT';
   c_one_second         CONSTANT NUMBER := 1 / 86400;

   /*
     ** Local Procedures and Functions
   */

   --
   FUNCTION get_subs_service_parameter (
      p_susg_ref_num  IN  subs_serv_groups.ref_num%TYPE
     ,p_sety_ref_num  IN  service_types.ref_num%TYPE
     ,p_sepa_ref_num  IN  service_parameters.ref_num%TYPE
     ,p_chk_date      IN  DATE
   )
      RETURN subs_service_parameters%ROWTYPE IS
      --
      CURSOR c_susp IS
         SELECT *
           FROM subs_service_parameters
          WHERE susg_ref_num = p_susg_ref_num
            AND sety_ref_num = p_sety_ref_num
            AND sepa_ref_num = p_sepa_ref_num
            AND p_chk_date BETWEEN start_date AND NVL (end_date, p_chk_date);

      --
      l_susp_rec                    subs_service_parameters%ROWTYPE;
   BEGIN
      OPEN c_susp;

      FETCH c_susp
       INTO l_susp_rec;

      CLOSE c_susp;

      --
      RETURN l_susp_rec;
   END get_subs_service_parameter;

   --
   FUNCTION get_master_service_adjustment (
      p_maas_ref_num      IN  master_account_services.ref_num%TYPE
     ,p_chk_date          IN  DATE
     ,p_fcit_type_code    IN  fixed_charge_item_types.type_code%TYPE
     ,p_billing_selector  IN  billing_selectors_v.type_code%TYPE
   )
      RETURN master_service_adjustments%ROWTYPE IS
      --
      CURSOR c_masa IS
         SELECT   *
             FROM master_service_adjustments
            WHERE maas_ref_num = p_maas_ref_num
              AND TRUNC (p_chk_date) BETWEEN TRUNC (start_date) AND NVL (end_date, TRUNC (p_chk_date))
              AND fcit_charge_code = p_fcit_type_code
              AND billing_selector = p_billing_selector
         ORDER BY start_date DESC;

      --
      l_masa_rec                    master_service_adjustments%ROWTYPE;
   BEGIN
      OPEN c_masa;

      FETCH c_masa
       INTO l_masa_rec;

      CLOSE c_masa;

      --
      RETURN l_masa_rec;
   END get_master_service_adjustment;

   --
   FUNCTION get_master_chca (
      p_maac_ref_num  IN  master_accounts_v.ref_num%TYPE
     ,p_chk_date      IN  DATE
   )
      RETURN maac_charging_categories.chca_type_code%TYPE IS
      --
      CURSOR c_macc IS
         SELECT chca_type_code
           FROM maac_charging_categories
          WHERE maac_ref_num = p_maac_ref_num AND p_chk_date BETWEEN start_date AND NVL (end_date, p_chk_date);

      --
      l_chca_type_code              maac_charging_categories.chca_type_code%TYPE;
   BEGIN
      OPEN c_macc;

      FETCH c_macc
       INTO l_chca_type_code;

      CLOSE c_macc;

      --
      RETURN l_chca_type_code;
   END get_master_chca;

   --
   FUNCTION get_master_service_parameter (
      p_maas_ref_num  IN  master_account_services.ref_num%TYPE
     ,p_sepa_ref_num  IN  service_parameters.ref_num%TYPE
     ,p_chk_date      IN  DATE
   )
      RETURN master_service_parameters%ROWTYPE IS
      --
      CURSOR c_masp IS
         SELECT *
           FROM master_service_parameters
          WHERE maas_ref_num = p_maas_ref_num
            AND sepa_ref_num = p_sepa_ref_num
            AND p_chk_date BETWEEN start_date AND NVL (end_date, p_chk_date);

      --
      l_masp_rec                    master_service_parameters%ROWTYPE;
   BEGIN
      OPEN c_masp;

      FETCH c_masp
       INTO l_masp_rec;

      CLOSE c_masp;

      --
      RETURN l_masp_rec;
   END get_master_service_parameter;

   /*
     ** Leiab mobiilinumbrile vastava SUSG-i ette antud kuupäeval.
   */
   FUNCTION get_senu_susg_rec (
      p_senu_num        IN  service_numbers.number_id%TYPE
     ,p_nety_type_code  IN  senu_susg.nety_type_code%TYPE
     ,p_chk_date        IN  DATE
   )
      RETURN senu_susg%ROWTYPE IS
      --
      CURSOR c_sesu IS
         SELECT *
           FROM senu_susg
          WHERE senu_num = p_senu_num
            AND nety_type_code = p_nety_type_code
            AND p_chk_date BETWEEN start_date AND NVL (end_date, p_chk_date);

      --
      l_sesu_rec                    senu_susg%ROWTYPE;
   BEGIN
      OPEN c_sesu;

      FETCH c_sesu
       INTO l_sesu_rec;

      CLOSE c_sesu;

      --
      RETURN l_sesu_rec;
   END get_senu_susg_rec;

   --
   FUNCTION chk_pack_common_mon_cg_allowed (
      p_sept_type_code  IN  serv_package_types.type_code%TYPE
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_sept IS
         SELECT 1
           FROM serv_package_types
          WHERE type_code = p_sept_type_code AND ykt_allowed = 'Y';

      --
      l_dummy                       NUMBER;
      l_found                       BOOLEAN;
   BEGIN
      OPEN c_sept;

      FETCH c_sept
       INTO l_dummy;

      l_found := c_sept%FOUND;

      CLOSE c_sept;

      --
      RETURN l_found;
   END chk_pack_common_mon_cg_allowed;

   --
   PROCEDURE ins_common_monthly_charges (
      p_comc  IN OUT NOCOPY  invoice_entries%ROWTYPE   -- CHG4594
   ) IS
      --
      CURSOR c_ref IS
         SELECT inen_ref_num_s.NEXTVAL
           FROM DUAL;
   BEGIN
      OPEN c_ref;

      FETCH c_ref
       INTO p_comc.ref_num;

      CLOSE c_ref;

      --
      p_comc.created_by := NVL (p_comc.created_by, sec.get_username);
      p_comc.date_created := NVL (p_comc.date_created, SYSDATE);
      p_comc.acc_amount := ROUND (p_comc.acc_amount, g_inen_acc_precision);   -- CHG4594
      p_comc.eek_amt := ROUND (p_comc.acc_amount, 2);   -- CHG4594

      --
      INSERT INTO common_monthly_charges
                  (ref_num   --NOT NULL NUMBER(10)
                  ,invo_ref_num   --NOT NULL NUMBER(10)
                  ,eek_amt   --NOT NULL NUMBER(14,2)
                  ,rounding_indicator   --NOT NULL VARCHAR2(1)
                  ,under_dispute   --NOT NULL VARCHAR2(1)
                  ,created_by   --NOT NULL VARCHAR2(15)
                  ,date_created   --NOT NULL DATE
                  ,amt_in_curr   --         NUMBER(14,2)
                  ,billing_selector   --         VARCHAR2(3)
                  ,fcit_type_code   --         VARCHAR2(3)
                  ,taty_type_code   --         VARCHAR2(3)
                  ,susg_ref_num   --         NUMBER(10)
                  ,iadn_ref_num   --         NUMBER(10)
                  ,curr_code   --         VARCHAR2(3)
                  ,vmct_type_code   --         VARCHAR2(3)
                  ,last_updated_by   --         VARCHAR2(15)
                  ,date_updated   --         DATE
                  ,description   --         VARCHAR2(60)
                  ,amt_tax   --         NUMBER(14,2)
                  ,amt_tax_curr   --         NUMBER(14,2)
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
                  )
           VALUES (p_comc.ref_num
                  ,p_comc.invo_ref_num
                  ,p_comc.eek_amt
                  ,p_comc.rounding_indicator
                  ,p_comc.under_dispute
                  ,p_comc.created_by
                  ,p_comc.date_created
                  ,p_comc.amt_in_curr
                  ,p_comc.billing_selector
                  ,p_comc.fcit_type_code
                  ,p_comc.taty_type_code
                  ,p_comc.susg_ref_num
                  ,p_comc.iadn_ref_num
                  ,p_comc.curr_code
                  ,p_comc.vmct_type_code
                  ,p_comc.last_updated_by
                  ,p_comc.date_updated
                  ,p_comc.description
                  ,p_comc.amt_tax
                  ,p_comc.amt_tax_curr
                  ,p_comc.manual_entry
                  ,p_comc.evre_count
                  ,p_comc.evre_duration
                  ,p_comc.module_ref
                  ,p_comc.fixed_charge_value
                  ,p_comc.evre_char_usage
                  ,p_comc.print_required
                  ,p_comc.vmct_rate_value
                  ,p_comc.num_of_days
                  ,p_comc.maas_ref_num
                  ,p_comc.evre_data_volume
                  ,p_comc.cadc_ref_num
                  ,p_comc.fcdt_type_code
                  );
   END ins_common_monthly_charges;

   /*
     ** Kui käesolevale Masterile on koostatud vahearve(id), siis kontrollida, kas vahearve(te)le
     ** on kantud jooksvale kuumaksule vastavaid soodustusi. Kui on, siis võetakse need kuumaksu soodustused tagasi.
   */
   PROCEDURE recalc_int_invo_discount (
      p_maac_ref_num     IN      accounts.ref_num%TYPE
     ,p_susg_ref_num     IN      subs_serv_groups.ref_num%TYPE
     ,p_invo_ref_num     IN      invoices.ref_num%TYPE
     ,p_fcit_type_code   IN      fixed_charge_item_types.type_code%TYPE
     ,p_period_start     IN      DATE
     ,p_period_end       IN      DATE
     ,p_int_invo_exists  IN      BOOLEAN
     ,p_success          OUT     BOOLEAN
     ,p_error_text       OUT     VARCHAR2
   ) IS
      --
      CURSOR c_inen IS
         SELECT inen.*
           FROM invoice_entries inen, invoices invo, fixed_charge_item_types fcit
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.invoice_type = 'INT'
            AND TRUNC (invo.period_start) >= TRUNC (p_period_start)
            AND TRUNC (LAST_DAY (invo.period_start)) <= TRUNC (p_period_end)
            AND inen.invo_ref_num = invo.ref_num
            AND inen.susg_ref_num = p_susg_ref_num
            AND inen.manual_entry = 'N'
            AND inen.fcdt_type_code = fcit.fcdt_type_code
            AND fcit.type_code = p_fcit_type_code;

      --
      e_cre_inen_failure            EXCEPTION;
   BEGIN
      IF p_int_invo_exists = TRUE THEN
         FOR l_inen_rec IN c_inen LOOP
            create_entries (p_success
                           ,p_error_text
                           ,p_invo_ref_num
                           ,l_inen_rec.fcit_type_code
                           ,l_inen_rec.taty_type_code
                           ,l_inen_rec.billing_selector
                           ,-l_inen_rec.acc_amount   -- CHG4594
                           ,l_inen_rec.susg_ref_num
                           ,NULL   -- p_num_of_days
                           ,bcc_inve_mod_ref
                           ,l_inen_rec.maas_ref_num
                           ,l_inen_rec.cadc_ref_num
                           ,l_inen_rec.fcdt_type_code
                           );

            IF NOT p_success THEN
               RAISE e_cre_inen_failure;
            END IF;
         END LOOP;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_cre_inen_failure THEN
         p_success := FALSE;
   END recalc_int_invo_discount;

   /*
     ** Protseduur koostab M/A mobiilidest peregrupi vastavalt reeglitele: 1) suurimad kuumaksud, 2) sama kuumaksu
     ** korral vanemad susgid, 3) pakett kubatud peregrupiga liita -> max lubatud arv mobiile.
     ** Võrdleb ühise kuutasu ja peregrupi liikmete kuutasude summasid ning kallima kannab abitabelisse ning
     ** kustutab PL/SQL tabelist. Soodsam kantakse hiljem arvele (jääb PL/SQL tabelisse).
   */
   PROCEDURE compare_monthly_charges (
      p_inen_tab         IN OUT  t_inen
     ,p_inen_sum_tab     IN      t_inen_sum
     ,p_ykt_index        IN      NUMBER
     ,p_maac_ref_num     IN      accounts.ref_num%TYPE
     ,p_period_start     IN      DATE
     ,p_period_end       IN      DATE
     ,p_success          OUT     BOOLEAN
     ,p_error_text       OUT     VARCHAR2
     ,p_int_invo_exists  IN      BOOLEAN   -- UPR-3124
   ) IS
      --
      l_ordered_sum_tab             t_inen_sum;
      l_idx_sum                     NUMBER;
      l_idx                         NUMBER;
      l_delete_idx                  NUMBER;
      l_allowed                     BOOLEAN;
      l_mon_chg_total               NUMBER := 0;
      l_allowed_count               NUMBER;
      --
      e_processing                  EXCEPTION;
   BEGIN
      /*
        ** Järjestame mobiilide kuumaksude summad kahanevasse järjekorda
      */
      l_ordered_sum_tab := create_ordered_mon_chg_list (p_inen_sum_tab   -- IN  t_inen_sum
                                                       ,p_success   -- OUT BOOLEAN
                                                       ,p_error_text   -- OUT VARCHAR2
                                                       );

      IF NOT p_success THEN
         RAISE e_processing;
      END IF;

      /*
        ** Kuna mobiilid on järjestatud kuumaksude kahanemise järjekorras + vanemad susgid eespool, siis
        ** järgnevana tuleb leida kuni max lubatud arv mobiili peregruppi liitmiseks (kui viimane pakett
        ** seda lubab) ja ühise kuutasuga võrdlemiseks.
      */
      l_idx_sum := l_ordered_sum_tab.FIRST;

      WHILE l_idx_sum IS NOT NULL LOOP
         /*
           ** Kontrollime, kas käesolevat paketti võib liita peregruppi.
         */
         l_allowed := chk_pack_common_mon_cg_allowed (l_ordered_sum_tab (l_idx_sum).sept_type_code);

         --
         IF l_allowed THEN
            l_mon_chg_total := NVL (l_mon_chg_total, 0) + l_ordered_sum_tab (l_idx_sum).amount;
            l_allowed_count := NVL (l_allowed_count, 0) + 1;
            l_ordered_sum_tab (l_idx_sum).selected := 'Y';
         END IF;

         --
         IF l_allowed_count >= c_max_ykt_susgs THEN
            EXIT;
         END IF;

         --
         l_idx_sum := l_ordered_sum_tab.NEXT (l_idx_sum);
      END LOOP;

      --
      IF l_mon_chg_total < p_inen_tab (p_ykt_index).eek_amt OR l_allowed_count < c_min_ykt_susgs THEN
         /*
           ** Ühine kuutasu kallim kui peregrupi mobiilide kuumaksude summa või peregruppi sobib
           ** vähem mobiile kui min lubatud arv.
           ** Arvele lähevad grupi mobiilide kuutasud, ÜKT kantakse abitabelisse (ja kustutatakse
           ** seejärel PL/SQL tabelist, et seda arvele ei kantaks).
         */
         ins_common_monthly_charges (p_inen_tab (p_ykt_index));
         p_inen_tab.DELETE (p_ykt_index);
      ELSE
         /*
           ** Ühine kuutasu soodsam või võrdne peregrupi mobiilide kuumaksude summaga.
           ** Arvele läheb ÜKT, grupi mobiilide kuutasud kantakse abitabelisse (ja kustutatakse
           ** seejärel PL/SQL tabelist, et neid arvele ei kantaks).
         */
         l_allowed_count := NULL;
         l_idx_sum := l_ordered_sum_tab.FIRST;

         WHILE l_idx_sum IS NOT NULL LOOP
            IF l_ordered_sum_tab (l_idx_sum).selected = 'Y' THEN
               l_allowed_count := NVL (l_allowed_count, 0) + 1;
               --
               l_idx := p_inen_tab.FIRST;

               WHILE l_idx IS NOT NULL LOOP
                  l_delete_idx := NULL;

                  IF p_inen_tab (l_idx).susg_ref_num = l_ordered_sum_tab (l_idx_sum).susg_ref_num THEN
                     ins_common_monthly_charges (p_inen_tab (l_idx));
                     /*
                       ** Kui käesolevale Masterile on koostatud vahearve(id), siis kontrollida, kas vahearve(te)le
                       ** on kantud jooksvale kuumaksule vastavaid soodustusi. Kui on, siis tuleb ka need kuumaksu
                       ** soodustused siin tagasi võtta.
                     */
                     recalc_int_invo_discount
                                     (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                     ,p_inen_tab (l_idx).susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                     ,p_inen_tab (l_idx).invo_ref_num   -- IN     invoices.ref_num%TYPE
                                     ,p_inen_tab (l_idx).fcit_type_code   -- IN     fixed_charge_item_types.type_code%TYPE
                                     ,p_period_start   -- IN     DATE
                                     ,p_period_end   -- IN     DATE
                                     ,p_int_invo_exists   -- IN     BOOLEAN
                                     ,p_success   --    OUT BOOLEAN
                                     ,p_error_text   --    OUT VARCHAR2
                                     );

                     IF NOT p_success THEN
                        RAISE e_processing;
                     END IF;

                     --
                     l_delete_idx := l_idx;
                  END IF;

                  --
                  l_idx := p_inen_tab.NEXT (l_idx);

                  --
                  IF l_delete_idx IS NOT NULL THEN
                     p_inen_tab.DELETE (l_delete_idx);
                  END IF;
               END LOOP;
            END IF;

            --
            IF l_allowed_count >= c_max_ykt_susgs THEN
               EXIT;
            END IF;

            --
            l_idx_sum := l_ordered_sum_tab.NEXT (l_idx_sum);
         END LOOP;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
   END compare_monthly_charges;

   /*
     ** CHG-742:
     ** Protseduur töötab masterkonto teenusele pere kuutasu (on sarnane teenusele ühtne kuutasu).
     ** Pere kuutasu maksustamise reeglid:
     ** 1) peregruppi kuuluvad mobiilid on registreeritud maksustatava masterkonto teenuse parameetritena
     ** 2) soodsama variandi võrdlust ei toimu - s.t. arvele läheb alati pere kuutasu ja ei lähe
     **    peregruppi kuuluvate mobiilide paketi kuutasud
     ** 3) erandina ei lähe pere kuutasu arvele, kui kõigi gruppi kuuluvate mobiilide paketi kuutasud = 0
     **    (on olnud terve perioodi TC).
   */
   PROCEDURE exclude_mobile_package_charges (
      p_inen_tab         IN OUT  t_inen
     ,p_ykt_index        IN      NUMBER
     ,p_maac_ref_num     IN      accounts.ref_num%TYPE
     ,p_period_start     IN      DATE
     ,p_period_end       IN      DATE
     ,p_period_end_time  IN      DATE
     ,p_success          OUT     BOOLEAN
     ,p_error_text       OUT     VARCHAR2
     ,p_int_invo_exists  IN      BOOLEAN
   ) IS
      --
      /*
        ** CHG-1132: Lisatud ka teenuse parameetrid, millised on suletud seoses mobiili sulgemisega perioodi jooksul.
        ** Välja jäävad parameetrid, millised on suletud avatud mobiilidele.
      */
      CURSOR c_masp (
         p_maas_ref_num  IN  master_account_services.ref_num%TYPE
      ) IS
         SELECT *
           FROM master_service_parameters masp
          WHERE maas_ref_num = p_maas_ref_num
            AND (   p_period_end_time BETWEEN start_date AND NVL (end_date, p_period_end_time)
                 OR (    end_date >= p_period_start
                     AND end_date < p_period_end_time
                     AND EXISTS (SELECT 1
                                   FROM senu_susg
                                  WHERE senu_num = TO_NUMBER (masp.param_value)
                                    AND end_date IS NOT NULL
                                    AND nety_type_code = masp.nety_type_code   -- CHG-1394
                                    AND end_date BETWEEN masp.end_date - 1 / 2 AND masp.end_date + 1 / 2)
                    )
                );

      --
      CURSOR c_sesu (
         p_senu_num        IN  service_numbers.number_id%TYPE
        ,p_nety_type_code  IN  senu_susg.nety_type_code%TYPE
        ,p_start_date      IN  DATE   -- CHG-1132
        ,p_end_date        IN  DATE   -- CHG-1132
      ) IS
         SELECT *
           FROM senu_susg
          WHERE senu_num = p_senu_num
            AND nety_type_code = p_nety_type_code
            AND start_date <= p_end_date
            AND NVL (end_date, p_start_date) >= p_start_date;

      --
      l_maas_ref_num                master_account_services.ref_num%TYPE;
      l_idx                         NUMBER;
      l_delete_idx                  NUMBER;
      l_mon_chg_total               NUMBER := 0;
      l_susg_ref_num                subs_serv_groups.ref_num%TYPE;
      l_senu_num                    service_numbers.number_id%TYPE;
      l_start_date                  DATE;   -- CHG-1132
      l_end_date                    DATE;   -- CHG-1132
      --
      e_processing                  EXCEPTION;
   BEGIN
      l_maas_ref_num := p_inen_tab (p_ykt_index).maas_ref_num;

      /*
        ** Leiame peregruppi kuuluvad mobiilid = masterkonto teenuse kehtivad parameetrid arveldusperioodi lõpu seisuga.
      */
      FOR l_masp_rec IN c_masp (l_maas_ref_num) LOOP
         DECLARE
            e_invalid_data                EXCEPTION;
         BEGIN
            BEGIN
               l_senu_num := TO_NUMBER (l_masp_rec.param_value);
            EXCEPTION
               WHEN OTHERS THEN
                  RAISE e_invalid_data;
            END;

            --
            l_start_date := GREATEST (l_masp_rec.start_date, p_period_start);   -- CHG-1132
            l_end_date := LEAST (NVL (l_masp_rec.end_date, p_period_end_time), p_period_end_time);   -- CHG-1132

            /*
              ** CHG-978: Leiame arveldusperioodi jooksul mobiilinumbrile vastavad masterkonto SUSG-id.
            */
            FOR l_sesu_rec IN c_sesu (l_senu_num, NVL (l_masp_rec.nety_type_code, 'GSM'), l_start_date, l_end_date) LOOP   -- CHG-1132: start, end
               l_susg_ref_num := l_sesu_rec.susg_ref_num;
               /*
                 ** Arvele läheb alati Pere kuutasu, grupi mobiilide kuutasud kantakse abitabelisse (ja kustutatakse
                 ** seejärel PL/SQL tabelist, et neid arvele ei kantaks).
               */
               l_idx := p_inen_tab.FIRST;

               --
               WHILE l_idx IS NOT NULL LOOP
                  l_delete_idx := NULL;

                  --
                  IF p_inen_tab (l_idx).susg_ref_num = l_susg_ref_num THEN
                     ins_common_monthly_charges (p_inen_tab (l_idx));
                     l_mon_chg_total := NVL (l_mon_chg_total, 0) + p_inen_tab (l_idx).eek_amt;
                     /*
                       ** Kui käesolevale Masterile on koostatud vahearve(id), siis kontrollida, kas vahearve(te)le
                       ** on kantud jooksvale kuumaksule vastavaid soodustusi. Kui on, siis tuleb ka need kuumaksu
                       ** soodustused siin tagasi võtta.
                     */
                     recalc_int_invo_discount
                                     (p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                     ,l_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                     ,p_inen_tab (l_idx).invo_ref_num   -- IN     invoices.ref_num%TYPE
                                     ,p_inen_tab (l_idx).fcit_type_code   -- IN     fixed_charge_item_types.type_code%TYPE
                                     ,p_period_start   -- IN     DATE
                                     ,p_period_end   -- IN     DATE
                                     ,p_int_invo_exists   -- IN     BOOLEAN
                                     ,p_success   --    OUT BOOLEAN
                                     ,p_error_text   --    OUT VARCHAR2
                                     );

                     IF NOT p_success THEN
                        RAISE e_processing;
                     END IF;

                     --
                     l_delete_idx := l_idx;
                  END IF;

                  --
                  l_idx := p_inen_tab.NEXT (l_idx);

                  --
                  IF l_delete_idx IS NOT NULL THEN
                     p_inen_tab.DELETE (l_delete_idx);
                  END IF;
               END LOOP;
            END LOOP;
         EXCEPTION
            WHEN e_invalid_data THEN
               /*
                 ** Vigast teenusparameetrit töötluses lihtsalt ignoreeritakse.
               */
               NULL;
         END;
      END LOOP;

      /*
        ** Kui ei esine ühtegi mobiili kuutasu > 0 (kõik peregrupi mobiilid kogu kuu TC), siis ka pere kuutasu
        ** arvele kanda ei tohi. Kõigil muudel juhtudel kantakse pere kuutasu arvele.
      */
      IF l_mon_chg_total <= 0 THEN
         ins_common_monthly_charges (p_inen_tab (p_ykt_index));
         p_inen_tab.DELETE (p_ykt_index);
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
   END exclude_mobile_package_charges;

   ---
   ---
   /*
     **   Kui hinnakirjas on defineeritud mobiili teenuse kuumaksu või erihinna arvestus sõltuvalt
     **  mobiili teise teenuse olemasolust, siis teenusele sõltuvat kuumaksu või erihinda arvestatakse
     **  mõlema teenuse ühise aktiive perioodi eest, mitte ühist perioodi maksustatakse vastavalt paketist
     **  või paketikategooriast sõltuva hinnaga.
     **
     **  Kuumakse arvutatakse aruandeperioodis olenevalt teenuse ja mobiili kattuvate aktiivsete päevade
     **  arvust aruandeperioodis, st. kuumaksu ei arvestata päevade eest, mil
     **   - mobiilside oli piiratud ja teenus aktiivne
     **   - mobiilside piiratud ja teenuse kasutus piiratud
     **   - mobiilside aktiivne ja teenuse kasutus piiratud
     **
     **  Aruandeperioodis võib teenusel esineda üks või mitu piiratud kasutuse perioodi, sealjuures erineva
     **  põhjusega piiratud kasutuse perioodid võivad olla kas täielikult või osaliselt ülekattega.
   */
   PROCEDURE invoice_service_mon_charge (
      p_price_list      IN      emt_bill_price_list%ROWTYPE
     ,p_invo            IN      invoices%ROWTYPE
     ,p_maac_ref_num    IN      accounts.ref_num%TYPE
     ,p_susg_ref_num    IN      subs_serv_groups.ref_num%TYPE
     ,p_sept_type_code  IN      serv_package_types.type_code%TYPE
     ,p_end_day_num     IN      NUMBER
     ,p_create_entry    IN      VARCHAR2
     ,p_success         OUT     BOOLEAN
     ,p_err_text        OUT     VARCHAR2
   ) IS
      -- AVL-49
      CURSOR c_fcit (p_fcit_type_code VARCHAR2) IS
         SELECT future_period, free_periods
         FROM fixed_charge_item_types
         WHERE type_code = p_fcit_type_code
      ;
      --
      l_sety_days                   invoice_entries.num_of_days%TYPE;
      l_key_sety_days               invoice_entries.num_of_days%TYPE;   -- CHG-2795
      l_charge_value                emt_bill_price_list.charge_value%TYPE;
      l_key_charge_value            emt_bill_price_list.key_charge_value%TYPE;   -- CHG-2795
      l_future_period               fixed_charge_item_types.future_period%TYPE;  -- AVL-49
      l_free_periods                fixed_charge_item_types.free_periods%TYPE;   -- AVL-49
      --
      e_processing                  EXCEPTION;
   BEGIN
      /*
         dbms_output.put_line('SETY=' || to_char(p_price_list.sety_ref_num) ||
                              ', SUSG=' || to_char(p_susg_ref_num) ||
                              ', SEPT=' || p_sept_type_code ||
                              ', start=' || to_char(p_price_list.start_date, 'dd.mm.yy hh24:mi:ss') ||
                              ', end=' || to_char(p_price_list.end_date, 'dd.mm.yy hh24:mi:ss')
                              );
      */
      IF p_price_list.charge_value > 0 THEN
         IF p_price_list.sepv_ref_num IS NULL THEN
            -- AVL-49
            OPEN  c_fcit(p_price_list.fcit_type_code);
            FETCH c_fcit INTO l_future_period, l_free_periods;
            CLOSE c_fcit;
            --
            IF l_future_period > 0 and l_free_periods > 0 THEN -- AVL-49
               -- AVL-49: Leiame AVL teenuse aktiivsed päevad
               l_sety_days := find_avl_num_days (p_susg_ref_num             --p_susg_ref_num    IN  NUMBER
                                                ,p_price_list.sety_ref_num  --p_sety_ref_num    IN  NUMBER
                                                ,p_price_list.start_date    --p_prli_start_date IN  DATE
                                                ,p_price_list.end_date      --p_prli_end_date   IN  DATE
                                                ,l_future_period            --p_future_period   IN  NUMBER
                                                ,l_free_periods             --p_free_periods    IN  NUMBER
                                                );
               --
            ELSE -- AVL-49
               --
               l_sety_days := find_num_of_days (p_price_list.start_date
                                               ,p_price_list.end_date
                                               ,p_susg_ref_num
                                               ,p_price_list.sety_ref_num
                                               ,0   -- p_months_after NUMBER
                                               );
               --
            END IF; -- AVL-49

            -- dBMS_OUTPUT.PUT_LINE('MONT_SETY: l_sety_days: '|| to_char(l_sety_days));
            IF l_sety_days < 0 THEN
               p_err_text :=    'Find_Sety_Days: SUSG='
                             || TO_CHAR (p_susg_ref_num)
                             || ', SETY='
                             || TO_CHAR (p_price_list.sety_ref_num)
                             || ', INVO='
                             || TO_CHAR (p_invo.ref_num);
               RAISE e_processing;
            END IF;

            l_charge_value := p_price_list.charge_value * l_sety_days / p_end_day_num;

            /*
              ** CHG-2795: Lisame teise teenuse olemasolust sõltuva erihinna.
            */
            IF p_price_list.key_sety_ref_num IS NOT NULL THEN
               l_key_sety_days := find_num_of_days (p_price_list.start_date
                                                   ,p_price_list.end_date
                                                   ,p_susg_ref_num
                                                   ,p_price_list.key_sety_ref_num
                                                   ,0   -- p_months_after NUMBER
                                                   );

               --
               IF l_key_sety_days > 0 THEN
                  --
                  l_key_charge_value := p_price_list.key_charge_value * l_key_sety_days / p_end_day_num;

                  --
                  IF l_sety_days <= l_key_sety_days THEN
                     /*
                       ** Teenus periood on väiksem Dependent teenuse perioodist.
                       ** Teenuse päevad maksustatakse Dependent teenuse kuutasuga.
                     */
                     l_charge_value := p_price_list.key_charge_value * l_sety_days / p_end_day_num;
                  ELSE
                     /*
                       ** Teenuse periood on pikem Dependent teenuse perioodist.
                       ** Teenuse päevad ilma Dependent teenuseta maksustatakse teenuse kuutasuga,
                       ** ühised päevad maksustatakse Dependent teenuse kuutasuga.
                     */
                     l_charge_value :=   (p_price_list.charge_value * (l_sety_days - l_key_sety_days) / p_end_day_num)
                                       + l_key_charge_value;
                  END IF;
               --
               END IF;
            --
            END IF;
         ELSE   -- if sepv_ref_num is not null
            get_num_of_days (p_price_list.start_date
                            ,p_price_list.end_date
                            ,p_susg_ref_num
                            ,p_price_list.sety_ref_num
                            ,p_price_list.sepa_ref_num
                            ,p_price_list.sepv_ref_num
                            ,0   -- p_months_after NUMBER
                            ,l_sety_days
                            ,p_success
                            );

            IF NOT p_success THEN
               p_err_text :=    'Find_Sety_Days: SUSG='
                             || TO_CHAR (p_susg_ref_num)
                             || ', SETY='
                             || TO_CHAR (p_price_list.sety_ref_num)
                             || ', INVO='
                             || TO_CHAR (p_invo.ref_num);
               RAISE e_processing;
            END IF;

            l_charge_value := p_price_list.charge_value * l_sety_days / p_end_day_num;
         END IF;

         --
         IF l_charge_value <> 0 THEN
            --         dbms_output.put_line('MON_SETY: teenuse '||to_char(p_price_list.sety_ref_num)||' lõplik hind '||to_char(l_charge_value)
              --                         ||' päevad '||to_char(l_sety_days)||' ');
            IF p_create_entry = 'B' THEN
               create_entries (p_success
                              ,p_err_text
                              ,p_invo.ref_num
                              ,p_price_list.fcit_type_code
                              ,p_price_list.taty_type_code
                              ,p_price_list.billing_selector
                              ,l_charge_value
                              ,p_susg_ref_num
                              ,l_sety_days
                              );

               IF NOT p_success THEN
                  RAISE e_processing;
               END IF;

               --
               --  dbms_output.put_line('MONT_SETY: call Calculate_discounts.Find_MON_Discounts');
               calculate_discounts.find_mon_discounts
                        (calculate_discounts.c_discount_type_mon   --p_discount_type     VARCHAR2
                        ,p_invo   --,p_invo              invoices%rowtype
                        ,p_price_list.fcit_type_code   --,p_fcit_type_code    VARCHAR2
                        ,p_price_list.billing_selector   --,p_billing_selector  VARCHAR2
                        ,p_price_list.sety_ref_num   --,p_sety_ref_num      NUMBER
                        ,p_price_list.sepa_ref_num   --,p_sepa_ref_num      NUMBER
                        ,p_price_list.sepv_ref_num   --,p_sepv_ref_num      NUMBER
                        ,p_sept_type_code   --,p_sept_type_code    VARCHAR2
                        ,l_charge_value   --,p_charge_value      NUMBER
                        ,l_sety_days   --,p_num_of_days       NUMBER                         --,p_num_of_days       NUMBER
                        ,p_susg_ref_num   --,p_susg_ref_num      NUMBER
                        ,p_maac_ref_num   --,p_maac_ref_num      NUMBER
                        ,p_price_list.start_date   --,p_start_date        DATE
                        ,p_price_list.end_date   --,p_end_date          DATE
                        ,p_end_day_num   --,p_day_num           NUMBER
                        ,p_err_text   --,p_error_text   IN OUT VARCHAR2
                        ,p_success   --,p_success      IN OUT BOOLEAN
                        );

               IF NOT p_success THEN
                  RAISE e_processing;
               END IF;
            END IF;

            --
            IF p_create_entry = 'I' THEN
               close_interim_billing_invoice.cre_upd_interim_inen (p_success
                                                                  ,p_err_text
                                                                  ,p_invo.ref_num
                                                                  ,p_price_list.fcit_type_code
                                                                  ,p_price_list.billing_selector
                                                                  ,p_price_list.taty_type_code
                                                                  ,l_charge_value
                                                                  ,l_sety_days
                                                                  ,p_susg_ref_num
                                                                  );

               IF NOT p_success THEN
                  RAISE e_processing;
               END IF;
            END IF;
         END IF;   -- IF l_charge_value <> 0 THEN
      END IF;   --if charge_value>0

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
   END invoice_service_mon_charge;

   --------------------------------------------------------------------------------
   --p_invo_end_date-trunc!! p_start,p_end not trunc
   PROCEDURE calc_service_monthly_charge (
      p_success         IN OUT  BOOLEAN
     ,p_err_text        IN OUT  VARCHAR2
     ,p_invo            IN      invoices%ROWTYPE
     ,p_end_day_num     IN      NUMBER
     ,p_sept_type_code  IN      subs_packages.sept_type_code%TYPE
     ,p_sety_ref_num    IN      service_types.ref_num%TYPE
     ,p_start_date      IN      DATE
     ,p_end_date        IN      DATE
     ,p_susg_ref_num    IN      subs_serv_groups.ref_num%TYPE
     ,p_maac_ref_num    IN      accounts.ref_num%TYPE
     ,p_create_entry    IN      VARCHAR2
   ) IS
      --
      l_idx                         NUMBER;
      l_price_list                  emt_bill_price_list%ROWTYPE;
      --
      e_processing                  EXCEPTION;
   BEGIN
      -- Leiame selle teenuse algindeksi mälutabelites (et minimeerida läbitavate mälutabeli ridade hulka).
      IF main_monthly_charges.g_sety_sety_index_tab.EXISTS (p_sety_ref_num) THEN
         l_idx := main_monthly_charges.g_sety_sety_index_tab (p_sety_ref_num);
      ELSE
         l_idx := NULL;
      END IF;

         --
      /*
      dbms_output.put_line('SUSG=' || to_char(p_susg_ref_num) ||
                           ', SETY=' || to_char(p_sety_ref_num) ||
                           ', idx=' || to_char(l_idx));
      */
      WHILE l_idx IS NOT NULL LOOP
         l_price_list.fcit_type_code := main_monthly_charges.g_sety_fcit_tab (l_idx);
         l_price_list.taty_type_code := main_monthly_charges.g_sety_taty_tab (l_idx);
         l_price_list.billing_selector := main_monthly_charges.g_sety_bise_tab (l_idx);
         l_price_list.charge_value := main_monthly_charges.g_sety_charge_tab (l_idx);
         l_price_list.sept_type_code := main_monthly_charges.g_sety_sept_tab (l_idx);
         l_price_list.sety_ref_num := main_monthly_charges.g_sety_sety_tab (l_idx);
         l_price_list.sepv_ref_num := main_monthly_charges.g_sety_sepv_tab (l_idx);
         l_price_list.sepa_ref_num := main_monthly_charges.g_sety_sepa_tab (l_idx);
         l_price_list.start_date := main_monthly_charges.g_sety_start_date_tab (l_idx);
         l_price_list.end_date := main_monthly_charges.g_sety_end_date_tab (l_idx);
         l_price_list.key_sety_ref_num := main_monthly_charges.g_key_sety_tab (l_idx);   -- CHG-2795
         l_price_list.key_charge_value := main_monthly_charges.g_key_sety_charge_tab (l_idx);   -- CHG-2795

         --
         IF l_price_list.sety_ref_num > p_sety_ref_num OR l_price_list.sept_type_code > p_sept_type_code THEN
            /*
              ** Kuna järjestus on SETY+SEPT, siis on õigest kohast juba üle loetud ja järgnevad Pricelist kirjed
              ** enam huvi ei paku.
            */
            EXIT;
         ELSIF     l_price_list.sety_ref_num = p_sety_ref_num
               AND l_price_list.sept_type_code = p_sept_type_code
               AND l_price_list.start_date <= p_end_date
               AND NVL (l_price_list.end_date, p_start_date) >= p_start_date THEN
            l_price_list.start_date := GREATEST (l_price_list.start_date, p_start_date);
            l_price_list.end_date := LEAST (NVL (l_price_list.end_date, p_end_date), p_end_date);
            --
            invoice_service_mon_charge (l_price_list   -- IN     emt_bill_price_list%ROWTYPE
                                       ,p_invo   -- IN     invoices%ROWTYPE
                                       ,p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                       ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                       ,p_sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                       ,p_end_day_num   -- IN     NUMBER
                                       ,p_create_entry   -- IN     VARCHAR2
                                       ,p_success   --    OUT BOOLEAN
                                       ,p_err_text   --    OUT VARCHAR2
                                       );

            IF NOT p_success THEN
               RAISE e_processing;
            END IF;
         END IF;

         --
         l_idx := main_monthly_charges.g_sety_sety_tab.NEXT (l_idx);
      END LOOP;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_err_text := SUBSTR (   'Mon_Sety_Chg SUSG='
                               || TO_CHAR (p_susg_ref_num)
                               || ', SETY='
                               || TO_CHAR (p_sety_ref_num)
                               || ', INVO='
                               || TO_CHAR (p_invo.ref_num)
                               || ': '
                               || SQLERRM
                              ,1
                              ,250
                              );
   END calc_service_monthly_charge;

   --------------------------------------------------------------------------------
   --p_invo_end_date-trunc!! p_start,p_end not trunc
   PROCEDURE monthly_sety_charge (
      p_success         IN OUT  BOOLEAN
     ,p_err_text        IN OUT  VARCHAR2
     ,p_invo            IN      invoices%ROWTYPE
     ,p_end_day_num     IN      NUMBER
     ,p_sept_type_code  IN      subs_packages.sept_type_code%TYPE
     ,p_sety_ref_num    IN      service_types.ref_num%TYPE
     ,p_start_date      IN      DATE
     ,p_end_date        IN      DATE
     ,p_susg_ref_num    IN      subs_serv_groups.ref_num%TYPE
     ,p_maac_ref_num    IN      accounts.ref_num%TYPE
     ,p_create_entry    IN      VARCHAR2
   ) IS
      --
      CURSOR c_ebpl IS
         SELECT   *
             FROM emt_bill_price_list
            WHERE chca_type_code IS NULL
              AND fcty_type = 'MCH'
              AND sept_type_code = p_sept_type_code
              AND sety_ref_num = p_sety_ref_num
              AND start_date <= p_end_date
              AND NVL (end_date, p_start_date) >= p_start_date
         ORDER BY start_date, end_date;

      --
      e_processing                  EXCEPTION;
   BEGIN
      FOR l_price_list IN c_ebpl LOOP
         l_price_list.start_date := GREATEST (l_price_list.start_date, p_start_date);
         l_price_list.end_date := LEAST (NVL (l_price_list.end_date, p_end_date), p_end_date);
         --
         invoice_service_mon_charge (l_price_list   -- IN     emt_bill_price_list%ROWTYPE
                                    ,p_invo   -- IN     invoices%ROWTYPE
                                    ,p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                    ,p_susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                    ,p_sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                    ,p_end_day_num   -- IN     NUMBER
                                    ,p_create_entry   -- IN     VARCHAR2
                                    ,p_success   --    OUT BOOLEAN
                                    ,p_err_text   --    OUT VARCHAR2
                                    );

         --
         IF NOT p_success THEN
            RAISE e_processing;
         END IF;
      END LOOP;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_err_text := SUBSTR (   'Mon_Sety_Chg SUSG='
                               || TO_CHAR (p_susg_ref_num)
                               || ', SETY='
                               || TO_CHAR (p_sety_ref_num)
                               || ', INVO='
                               || TO_CHAR (p_invo.ref_num)
                               || ': '
                               || SQLERRM
                              ,1
                              ,250
                              );
   END monthly_sety_charge;
----------------------------------------------------------------------------------------------
   /** mobet-23/mobet-76
       Protseduur chk_one_maac_ma_MON_discounts
1.Leia selle perioodi ja selle sepv soodustus cadc (kuna on päevade arvu põhine, siis periood ei ole arvelduskuu) p_price on kogu summa.
2.CADC leidmisel võtame cursorisse kohe PADI info. 
3.Leia cadc järgi soodussumma get_ma_serv_discount_amount - PADI järgi  - soodussumma leidmine
4.summa taanda päevade arvule
5.Kanna arvele arvestades CADC kirjeldust calculate_discounts.invoice_discount + kui on eraldi rida, siis lisa juurde nimi (grupi nimi). 
Ehk kui põhi arvereal on lisatunnus väärtustatud, siis teeme seda ka siin.


   */
   PROCEDURE chk_one_maac_ma_MON_discounts (
         p_maas_ref_num          IN  master_account_services.ref_num%TYPE
        ,p_sety_ref_num          IN  service_types.ref_num%type
        ,p_charged_sepv_ref      IN  service_param_values.ref_num%TYPE
        ,p_period_start          IN  DATE
        ,p_period_end            IN  DATE
        ,p_price                 IN  NUMBER
        ,p_invo_ref_num          IN  invoices.ref_num%TYPE
        ,p_dico_ref_num          IN  call_discount_codes.dico_ref_num%type
        ,p_inen_rowid            IN  VARCHAR2
        ,p_sety_days             IN  NUMBER
        ,p_end_day_num           IN  NUMBER
        ,p_success               IN OUT BOOLEAN
        ,p_error_text            IN OUT VARCHAR2
    ) IS
   
    CURSOR c_cadc IS
    SELECT cadc.for_fcit_type_code,cadc.minimum_price,cadc.precentage,cadc.pricing,masa.padi_ref_num, cadc.ref_num
    FROM master_service_adjustments masa, call_discount_codes cadc
    WHERE masa.maas_ref_num = p_maas_ref_num
     AND masa.sety_ref_num = p_sety_ref_num
     AND masa.dico_ref_num = cadc.dico_ref_num
     AND masa.sety_ref_num = cadc.for_sety_ref_num
     AND NVL (cadc.for_sepv_ref_num, NVL (p_charged_sepv_ref, -1)) = NVL (p_charged_sepv_ref, -1)
     AND cadc.call_type = 'MON'
     AND masa.start_date <= p_period_end
     AND NVL (masa.end_date, p_period_start) >= p_period_start
     AND cadc.start_date <= p_period_end
     AND NVL (cadc.end_date, p_period_start) >= p_period_start;
     
     
        
    --mobet-76
    CURSOR c_padd(p_padi_ref_num number, p_cadc_ref_num number) IS    
    SELECT * 
     FROM PART_DICO_DETAILS 
    WHERE padi_ref_num = p_padi_ref_num
      AND cadc_ref_num = p_cadc_ref_num;
      --mobet-76 
     CURSOR c_cadc_rec(p_cadc_ref_num number) IS
     SELECT *
       FROM call_discount_codes      
      WHERE ref_num = p_cadc_ref_num;  

    
    CURSOR c_fcit(p_type_code varchar2) IS 
    select *
    from fixed_charge_item_types fcit
    where type_code = p_type_code;
   
    l_disc_amount             invoice_entries.eek_amt%type;  
    l_cadc_rec                call_discount_codes%rowtype := null;
    l_fcit_rec                fixed_charge_item_types%rowtype := null;
    l_success                 BOOLEAN := TRUE;
    l_error_text              VARCHAR2(512);
    l_masa_padi_ref_num       master_service_adjustments.padi_ref_num%type := null;  --mobet-76
    l_cadc_for_fcit_type_code call_discount_codes.for_fcit_type_code%type := null;   --mobet-76
    l_cadc_minimum_price      call_discount_codes.minimum_price%TYPE := null;   --mobet-76
    l_cadc_precentage         call_discount_codes.precentage%TYPE := null;   --mobet-76
    l_cadc_pricing            call_discount_codes.pricing%TYPE := null;   --mobet-76
    l_cadc_ref_num            call_discount_codes.ref_num%TYPE := null;   --mobet-76
    l_padd_rec                PART_DICO_DETAILS%rowtype := null;  --mobet-76
    
   BEGIN
     
      OPEN c_cadc;
      FETCH c_cadc INTO l_cadc_for_fcit_type_code,l_cadc_minimum_price,l_cadc_precentage,l_cadc_pricing,l_masa_padi_ref_num,l_cadc_ref_num;
      IF c_cadc%found THEN
       
        --mobet-76. Kuna eelmises kursoris oli vaja ka padi_ref_num, siis küsime uuesti cadc kirje, ref_num-i järgi
        OPEN c_cadc_rec(l_cadc_ref_num);
        FETCH c_cadc_rec INTO l_cadc_rec;
        CLOSE c_cadc_rec;

        OPEN c_fcit(l_cadc_rec.for_fcit_type_code);
        FETCH c_fcit INTO l_fcit_rec;
        CLOSE c_fcit;
   
      

       IF l_masa_padi_ref_num is not null THEN -- mobet-76 Kui masa.padi_ref_num on väärtustatud, siis
         
         OPEN c_padd(l_masa_padi_ref_num,l_cadc_ref_num);
         FETCH c_padd INTO l_padd_rec;
         CLOSE c_padd;

         IF l_padd_rec.padi_ref_num is null THEN 
            l_disc_amount := 0; -- kui masa.padi_ref_num on täidetud ja PADD-s pole kirjet, siis soodustust ei sisestata 
         ELSE
            --Kui on PRICE is not null => p_discount_schema := Y ja minimum_price := PADD.PRICE
            IF l_padd_rec.PRICE is not null THEN
               l_cadc_rec.pricing    := 'Y'; 
               l_cadc_rec.minimum_price  := l_padd_rec.PRICE;
               l_cadc_rec.precentage := null;
               
            ELSIF l_padd_rec.DISC_ABSOLUTE is not null THEN
               l_cadc_rec.pricing    := 'N'; 
               l_cadc_rec.minimum_price  := l_padd_rec.DISC_ABSOLUTE;
               l_cadc_rec.precentage := null;
            ELSE
               l_cadc_rec.precentage := l_padd_rec.DISC_PERCENTAGE;      
               l_cadc_rec.pricing   := null; 
               l_cadc_rec.minimum_price := null;
                
           END IF;
    
           --CADC kirjest leitud tunnustega leiame soodustatud summa funktsiooniga:
           l_disc_amount := calculate_discounts.get_ma_serv_discount_amount
                            (p_price --p_full_chg_value IN NUMBER
                            ,p_price --p_remain_chg_value IN NUMBER
                            ,l_cadc_rec.minimum_price --p_cadc_min_price IN call_discount_codes.minimum_price%TYPE
                            ,l_cadc_rec.precentage --p_percentage IN call_discount_codes.precentage%TYPE
                            ,l_cadc_rec.pricing --p_discount_schema IN call_discount_codes.pricing%TYPE
                                );
         END IF; --IF l_padd_rec.padi_ref_num is not null
       
       ELSE --l_masa_padi_ref_num is null
         --CADC kirjest leitud tunnustega leiame soodustatud summa funktsiooniga:
         l_disc_amount := calculate_discounts.get_ma_serv_discount_amount
                            (p_price --p_full_chg_value IN NUMBER
                            ,p_price --p_remain_chg_value IN NUMBER
                            ,l_cadc_rec.minimum_price --p_cadc_min_price IN call_discount_codes.minimum_price%TYPE
                            ,l_cadc_rec.precentage --p_percentage IN call_discount_codes.precentage%TYPE
                            ,l_cadc_rec.pricing --p_discount_schema IN call_discount_codes.pricing%TYPE
                                );
      
       END IF; --IF l_masa_padi_ref_num is not null
      
                                
       IF NVL (l_disc_amount,0) > 0 THEN 
         l_disc_amount := l_disc_amount * p_sety_days / p_end_day_num;

         /* 
         arvele kandmine, mis oskab arvestada CADC kirjeldusega, kas eraldi real või samal real põhikuutasuga
          */
         calculate_discounts.invoice_discount
                (p_maas_ref_num   --IN master_account_services.ref_num%TYPE
                ,p_invo_ref_num --p_invo_ref_num IN invoices.ref_num%TYPE
                ,p_inen_rowid --p_inen_rowid IN VARCHAR2
                ,l_disc_amount --p_discounted_value IN NUMBER
                ,l_cadc_rec --p_cadc_rec IN call_discount_codes%ROWTYPE
                ,p_period_start --p_chk_date IN DATE
                ,l_fcit_rec.fcdt_type_code --p_fcdt_type_code IN fixed_charge_item_types.fcdt_type_code%TYPE
                ,l_success --p_success OUT BOOLEAN
                ,l_error_text --p_message OUT VARCHAR2
                );
          IF not l_success THEN
             p_error_text := l_error_text;
          END IF;      
        END IF;

      --ELSE -- mis siis kui ei leia vastet cursorist CADC, kas väljub l_success = false + veateade ???  
      END IF;                   
      CLOSE c_cadc;
  ---  
   END chk_one_maac_ma_MON_discounts;

   --------------------------------------------------------------------------------
   --------------------------------------------------------------------------------
   PROCEDURE invoice_maac_service_month_chg (
      p_price_list         IN      emt_bill_price_list%ROWTYPE
     ,p_invo               IN      invoices%ROWTYPE
     ,p_start_date         IN      DATE  -- CHG-13643
     ,p_end_date           IN      DATE  -- CHG-13643
     ,p_maas_ref_num       IN      master_account_services.ref_num%TYPE
     ,p_end_day_num        IN      NUMBER
     ,p_credit_rate_value  IN      master_service_adjustments.credit_rate_value%TYPE
     ,p_first_susp_start   IN      DATE  -- CHG-13643
     ,p_create_entry       IN      VARCHAR2
     ,p_success            OUT     BOOLEAN
     ,p_err_text           OUT     VARCHAR2
     ,p_dico_ref_num       IN      NUMBER  --mobet-23
   ) IS
      -- CHG-13643
      CURSOR c_fcit IS
         SELECT free_periods
         FROM fixed_charge_item_types
         WHERE type_code = p_price_list.fcit_type_code
      ;
      -- SFILES-251
      CURSOR c_maas_tc (p_start_date  DATE
                       ,p_end_date    DATE
      ) IS
         SELECT Round((end_date - start_date),0) tc_days
         FROM master_service_tc_periods
         WHERE maas_ref_num = p_maas_ref_num
           AND Trunc(start_date) <= p_end_date
           AND Nvl(end_date, p_end_date) >= p_start_date
      ;
      -- MOBE-425
      CURSOR c_text IS
         SELECT Substr( Rtrim( xmlagg( xmlelement(e, param_value || ', ')).extract('//text()') ,', '), 0, 40) additional_entry_text 
         FROM master_service_parameters  masp
         WHERE maas_ref_num = p_maas_ref_num
           AND ref_num IN (SELECT max(masp.ref_num) 
                           FROM master_service_parameters  masp
                              , service_parameters         sepa
                           WHERE masp.maas_ref_num = p_maas_ref_num
                             AND masp.param_value IS NOT NULL
                             AND masp.sepa_ref_num = sepa.ref_num
                             AND sepa.on_bill = 'Y'
                             AND Trunc(masp.start_date) <= p_end_date
                             AND Nvl(masp.end_date, p_end_date) >= p_start_date
                             AND Trunc(sepa.start_date) <= p_end_date
                             AND Nvl(sepa.end_date, p_end_date) >= p_start_date
                           GROUP BY masp.sepa_ref_num         
         )
      ;
      --
      l_free_periods                fixed_charge_item_types.free_periods%TYPE;  -- CHG-13643
      l_sety_days                   invoice_entries.num_of_days%TYPE;
      l_charge_value                emt_bill_price_list.charge_value%TYPE;
      l_additional_entry_text       invoice_entries.additional_entry_text%TYPE;  -- MOBE-425
      --
      e_processing                  EXCEPTION;
   BEGIN
      /*
        ** CHG-13643: 1) Price listi tunnuse FCIT järgi küsime metaandmed tabelist FIXED_CHARGE_ITEM_TYPES tunnuse FREE_PERIODS.
        **            2) kui free_periods is not null, siis
        **                a) esmasele liitumisele (first_date) liidame free_periods oleva kuude arvu 
        **                b) leiame selle kuu esimese kuupäeva (selle leiame sellepärast, et tegemist on päevapõhise arveldusega, aga free_periods tunnus käib kogu kuu kohta).
        **                c) kontrollime kas see on > arveldatava perioodi end_date
        **                d) kui on suurem, siis ei ole vaja arveldada
      */
      IF p_first_susp_start IS NOT NULL THEN
         --
         OPEN  c_fcit;
         FETCH c_fcit INTO l_free_periods;
         CLOSE c_fcit;
         --
         IF l_free_periods IS NOT NULL AND
            Trunc(Add_Months(p_first_susp_start, l_free_periods), 'MM') > Last_Day(p_end_date)
         THEN
            --
            RETURN;
            --
         END IF;
         --
      END IF;
      /* End CHG-13643 */

      --
      IF p_price_list.charge_value > 0 THEN
         IF p_price_list.sepv_ref_num IS NULL THEN
            l_sety_days := p_price_list.end_date - p_price_list.start_date + 1;
            -- SFILES-251: Lahutame maha TC päevad
            FOR rec IN c_maas_tc(p_price_list.start_date, p_price_list.end_date) LOOP
               --
               l_sety_days := l_sety_days - rec.tc_days;
               --
            END LOOP;
            --
            l_sety_days := Greatest(l_sety_days, 0);
            --
         ELSE
            calculate_masp_days (p_maas_ref_num
                                ,p_price_list.sety_ref_num
                                ,p_price_list.start_date
                                ,p_price_list.end_date
                                ,p_price_list.sepa_ref_num
                                ,p_price_list.sepv_ref_num
                                ,l_sety_days
                                ,p_success
                                );
         END IF;

         --
         IF NOT p_success THEN
            p_err_text :=    'Error in Find_Masp_Days: SETY='
                          || TO_CHAR (p_price_list.sety_ref_num)
                          || ', INVO='
                          || TO_CHAR (p_invo.ref_num);
            RAISE e_processing;
         END IF;

         --
         l_charge_value := p_price_list.charge_value * l_sety_days / p_end_day_num;
         l_charge_value := GREATEST (NVL (l_charge_value, 0)
                                     - NVL (l_charge_value, 0) * NVL (p_credit_rate_value, 0) / 100
                                    ,0
                                    );

               --
         /*
         dbms_output.put_line('SETY=' || to_char(p_price_list.sety_ref_num) ||
                              ', Start=' || to_char(p_price_list.start_date, 'dd.mm.yy') ||
                              ', end=' || to_char(p_price_list.end_date, 'dd.mm.yy') ||
                              ', days=' || to_char(l_sety_days) ||
                              ', price=' || to_char(l_charge_value)
         );
         */
               --
         IF l_charge_value <> 0 THEN
            IF p_create_entry = 'B' THEN
               /*
                 ** MOBE-425: Leiame koondarve teenuse parameetrite väärtused, millel on on_bill = Y.
                 **           Kuna arverida koostatakse teenuse tasemel, siis võib teenusel olla mitu parameetrit, mille ON_BILL = ?Y?. 
                 **           Selleks leiame kõikide selliste parameetrite väärtused ja paneme need komaeralduses kokku.
               */
               l_additional_entry_text := NULL;
               --
               OPEN  c_text;
               FETCH c_text INTO l_additional_entry_text;
               CLOSE c_text;
               /* End MOBE-425 */
               
               --
               iCalculate_Fixed_Charges.create_entries (p_success          => p_success                     --IN OUT  BOOLEAN
                                                      ,p_err_text         => p_err_text                    --IN OUT  VARCHAR2
                                                      ,p_invo_ref_num     => p_invo.ref_num                --IN      invoices.ref_num%TYPE
                                                      ,p_fcit_type_code   => p_price_list.fcit_type_code   --IN      fixed_charge_item_types.type_code%TYPE
                                                      ,p_taty_type_code   => p_price_list.taty_type_code   --IN      fixed_charge_item_types.taty_type_code%TYPE
                                                      ,p_billing_selector => p_price_list.billing_selector --IN      fixed_charge_item_types.billing_selector%TYPE
                                                      ,p_charge_value     => l_charge_value                --IN      NUMBER
                                                      ,p_susg_ref_num     => NULL                          --IN      subs_serv_groups.ref_num%TYPE
                                                      ,p_num_of_days      => l_sety_days                   --IN      NUMBER
                                                      ,p_module_ref       => bcc_inve_mod_ref              --IN      invoice_entries.module_ref%TYPE DEFAULT 'U659'
                                                      ,p_maas_ref_num     => p_maas_ref_num                --IN      master_account_services.ref_num%TYPE DEFAULT NULL
                                                      ,p_add_entry_text   => l_additional_entry_text       --IN      invoice_entries.additional_entry_text%TYPE DEFAULT NULL  -- MOBE-425
                                                      );
               --
                IF  p_dico_ref_num is not null and p_success THEN --mobet-23, kui eelmine process lõpetas edukalt
--                IF  p_dico_ref_num is not null  THEN --mobet-23, kui eelmine process lõpetas edukalt
                    chk_one_maac_ma_MON_discounts(
   /*                          p_maas_ref_num
                            ,p_price_list.sepv_ref_num
                            ,p_period_start 
                            ,p_period_end
                            ,l_charge_value
                            ,p_invo_ref_num
                            ,p_dico_ref_num
                            ,g_inen_rowid       
                            ,l_sety_days
                            ,p_end_day_num
                            ,p_success
                            ,p_error_text);*/

                             p_maas_ref_num     => p_maas_ref_num
                            ,p_sety_ref_num     => p_price_list.sety_ref_num
                            ,p_charged_sepv_ref => p_price_list.sepv_ref_num
                            ,p_period_start     => p_price_list.start_date 
                            ,p_period_end       => p_price_list.end_date
                            ,p_price            => p_price_list.charge_value
                            ,p_invo_ref_num     => p_invo.ref_num
                            ,p_dico_ref_num     => p_dico_ref_num
                            ,p_inen_rowid       => g_inen_rowid       
                            ,p_sety_days        => l_sety_days
                            ,p_end_day_num      => p_end_day_num
                            ,p_success          => p_success
                            ,p_error_text       => p_err_text);

                    
                END IF;--mobet-23


            END IF;   --p_create_entry = 'B'

            --
            IF p_create_entry = 'I' THEN
               close_interim_billing_invoice.cre_upd_interim_inen (p_success
                                                                  ,p_err_text
                                                                  ,p_invo.ref_num
                                                                  ,p_price_list.fcit_type_code
                                                                  ,p_price_list.billing_selector
                                                                  ,p_price_list.taty_type_code
                                                                  ,l_charge_value
                                                                  ,l_sety_days
                                                                  ,NULL
                                                                  ,p_maas_ref_num
                                                                  );
            END IF;   --p_create_entry='I'

            --
            IF NOT p_success THEN
               RAISE e_processing;
            END IF;
         END IF;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
   END invoice_maac_service_month_chg;

   --------------------------------------------------------------------------------
   --------------------------------------------------------------------------------
   --p_invo_end_date-trunc!! p_start,p_end not trunczzzz
   PROCEDURE calc_maac_serv_monthly_charge (
      p_success            IN OUT  BOOLEAN
     ,p_err_text           IN OUT  VARCHAR2
     ,p_invo               IN      invoices%ROWTYPE
     ,p_end_day_num        IN      NUMBER
     ,p_chca_type_code     IN      subs_charging_categories.chca_type_code%TYPE
     ,p_sety_ref_num       IN      service_types.ref_num%TYPE
     ,p_maas_ref_num       IN      master_account_services.ref_num%TYPE
     ,p_start_date         IN      DATE
     ,p_end_date           IN      DATE
     ,p_credit_rate_value  IN      master_service_adjustments.credit_rate_value%TYPE
     ,p_charge_value       IN      master_service_adjustments.charge_value%TYPE
     ,p_first_susp_start   IN      DATE  -- CHG-13643
     ,p_create_entry       IN      VARCHAR2
     ,p_dico_ref_num       IN      NUMBER  --mobet-23
   ) IS
      --
      l_idx                         NUMBER;
      l_price_list                  emt_bill_price_list%ROWTYPE;
      --
      e_processing                  EXCEPTION;
   BEGIN
      -- Leiame selle teenuse algindeksi mälutabelites (et minimeerida läbitavate mälutabeli ridade hulka).
      IF main_monthly_charges.g_ma_sety_sety_index_tab.EXISTS (p_sety_ref_num) THEN
         l_idx := main_monthly_charges.g_ma_sety_sety_index_tab (p_sety_ref_num);
      ELSE
         l_idx := NULL;
      END IF;

         --
      /*   dbms_output.put_line('SUSG=' || to_char(p_susg_ref_num) ||
                              ', SETY=' || to_char(p_sety_ref_num) ||
                              ', idx=' || to_char(l_idx));*/
      WHILE l_idx IS NOT NULL LOOP
         l_price_list.fcit_type_code := main_monthly_charges.g_ma_sety_fcit_tab (l_idx);
         l_price_list.taty_type_code := main_monthly_charges.g_ma_sety_taty_tab (l_idx);
         l_price_list.billing_selector := main_monthly_charges.g_ma_sety_bise_tab (l_idx);
         l_price_list.charge_value := main_monthly_charges.g_ma_sety_charge_tab (l_idx);
         l_price_list.chca_type_code := main_monthly_charges.g_ma_sety_chca_tab (l_idx);
         l_price_list.sety_ref_num := main_monthly_charges.g_ma_sety_sety_tab (l_idx);
         l_price_list.sepv_ref_num := main_monthly_charges.g_ma_sety_sepv_tab (l_idx);
         l_price_list.sepa_ref_num := main_monthly_charges.g_ma_sety_sepa_tab (l_idx);
         l_price_list.start_date := main_monthly_charges.g_ma_sety_start_date_tab (l_idx);
         l_price_list.end_date := main_monthly_charges.g_ma_sety_end_date_tab (l_idx);

         --
         IF l_price_list.sety_ref_num > p_sety_ref_num OR l_price_list.chca_type_code > p_chca_type_code THEN
            /*
              ** Kuna järjestus on SETY+CHCA, siis on õigest kohast juba üle loetud ja järgnevad Pricelist kirjed
              ** enam huvi ei paku.
            */
            EXIT;
         ELSIF     l_price_list.sety_ref_num = p_sety_ref_num
               AND l_price_list.chca_type_code = p_chca_type_code
               AND l_price_list.start_date <= p_end_date
               AND NVL (l_price_list.end_date, p_start_date) >= p_start_date THEN
            l_price_list.start_date := GREATEST (l_price_list.start_date, p_start_date);
            l_price_list.end_date := LEAST (NVL (l_price_list.end_date, p_end_date), p_end_date);

            --
            IF p_charge_value IS NOT NULL THEN   -- Määratud erihind sellele Masteri teenusele
               l_price_list.charge_value := p_charge_value;
            END IF;

            --
            invoice_maac_service_month_chg
                                        (l_price_list   -- IN     emt_bill_price_list%ROWTYPE
                                        ,p_invo   -- IN     invoices%ROWTYPE
                                        ,p_start_date        -- IN      DATE  -- CHG-13643
                                        ,p_end_date          -- IN      DATE  -- CHG-13643
                                        ,p_maas_ref_num   -- IN     master_account_services.ref_num%TYPE
                                        ,p_end_day_num   -- IN     NUMBER
                                        ,p_credit_rate_value   -- IN     master_service_adjustments.credit_rate_value%TYPE
                                        ,p_first_susp_start  -- IN      DATE  -- CHG-13643
                                        ,p_create_entry   -- IN     VARCHAR2
                                        ,p_success   --    OUT BOOLEAN
                                        ,p_err_text   --    OUT VARCHAR2
                                        ,p_dico_ref_num     --mobet-23
                                        );

            IF NOT p_success THEN
               RAISE e_processing;
            END IF;
         END IF;

         --
         l_idx := main_monthly_charges.g_ma_sety_sety_tab.NEXT (l_idx);
      END LOOP;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_err_text := SUBSTR (   'MA_Sety_Mon_Chg MAAS='
                               || TO_CHAR (p_maas_ref_num)
                               || ', INVO='
                               || TO_CHAR (p_invo.ref_num)
                               || ': '
                               || SQLERRM
                              ,1
                              ,250
                              );
   END calc_maac_serv_monthly_charge;

   --------------------------------------------------------------------------------
   --------------------------------------------------------------------------------
   --p_invo_end_date-trunc!! p_start,p_end not trunczzzz
   PROCEDURE monthly_ma_sety_charge (
      p_success            IN OUT  BOOLEAN
     ,p_err_text           IN OUT  VARCHAR2
     ,p_invo               IN      invoices%ROWTYPE
     ,p_end_day_num        IN      NUMBER
     ,p_chca_type_code     IN      subs_charging_categories.chca_type_code%TYPE
     ,p_sety_ref_num       IN      service_types.ref_num%TYPE
     ,p_maas_ref_num       IN      master_account_services.ref_num%TYPE
     ,p_start_date         IN      DATE
     ,p_end_date           IN      DATE
     ,p_credit_rate_value  IN      master_service_adjustments.credit_rate_value%TYPE
     ,p_charge_value       IN      master_service_adjustments.charge_value%TYPE
     ,p_first_susp_start   IN      DATE  -- CHG-13643
     ,p_create_entry       IN      VARCHAR2
     ,p_main_bill          IN      BOOLEAN
     ,p_dico_ref_num       IN      NUMBER   --mobet-23
   ) IS
      --
      CURSOR c_ebpl IS
         SELECT   *
             FROM emt_bill_price_list
            WHERE chca_type_code = p_chca_type_code
              AND fcty_type = 'MCH'
              AND sept_type_code IS NULL
              AND sety_ref_num = p_sety_ref_num
              AND start_date <= p_end_date
              AND NVL (end_date, p_start_date) >= p_start_date
         ORDER BY start_date, end_date;

      --
      e_processing                  EXCEPTION;
   BEGIN
      IF p_main_bill THEN
         calc_maac_serv_monthly_charge (p_success   -- IN OUT BOOLEAN
                                       ,p_err_text   -- IN OUT VARCHAR2
                                       ,p_invo   -- IN     INVOICES%ROWTYPE
                                       ,p_end_day_num   -- IN     NUMBER
                                       ,p_chca_type_code   -- IN     subs_charging_categories.chca_type_code%TYPE
                                       ,p_sety_ref_num   -- IN     SERVICE_TYPES.ref_num%TYPE
                                       ,p_maas_ref_num   -- IN     master_account_servises.ref_num%TYPE
                                       ,p_start_date   -- IN     DATE
                                       ,p_end_date   -- IN     DATE
                                       ,p_credit_rate_value   -- IN     master_service_adjustments.credit_rate_value%TYPE
                                       ,p_charge_value   -- IN     master_service_adjustments.charge_value%TYPE
                                       ,p_first_susp_start  -- IN      DATE  -- CHG-13643
                                       ,p_create_entry   -- IN     VARCHAR2
                                       ,p_dico_ref_num      --mobet-23
                                       );

         IF NOT p_success THEN
            RAISE e_processing;
         END IF;
      ELSE
         FOR l_price_list IN c_ebpl LOOP
            l_price_list.start_date := GREATEST (l_price_list.start_date, p_start_date);
            l_price_list.end_date := LEAST (NVL (l_price_list.end_date, p_end_date), p_end_date);

            --
            IF p_charge_value IS NOT NULL THEN   -- Määratud erihind sellele Masteri teenusele
               l_price_list.charge_value := p_charge_value;
            END IF;

            --
            invoice_maac_service_month_chg
                                        (l_price_list   -- IN     emt_bill_price_list%ROWTYPE
                                        ,p_invo   -- IN     invoices%ROWTYPE
                                        ,p_start_date        -- IN      DATE  -- CHG-13643
                                        ,p_end_date          -- IN      DATE  -- CHG-13643
                                        ,p_maas_ref_num   -- IN     master_account_services.ref_num%TYPE
                                        ,p_end_day_num   -- IN     NUMBER
                                        ,p_credit_rate_value   -- IN     master_service_adjustments.credit_rate_value%TYPE
                                        ,p_first_susp_start  -- IN      DATE  -- CHG-13643
                                        ,p_create_entry   -- IN     VARCHAR2
                                        ,p_success   --    OUT BOOLEAN
                                        ,p_err_text   --    OUT VARCHAR2
                                        ,p_dico_ref_num -- mobet-23
                                        );

            IF NOT p_success THEN
               RAISE e_processing;
            END IF;
         END LOOP;
      END IF;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_err_text := SUBSTR (   'MA_Sety_Mon_Chg MAAS='
                               || TO_CHAR (p_maas_ref_num)
                               || ', INVO='
                               || TO_CHAR (p_invo.ref_num)
                               || ': '
                               || SQLERRM
                              ,1
                              ,250
                              );
   END monthly_ma_sety_charge;

   ---------------------------------------------------------------------------------------
   PROCEDURE monthly_maas_sety_charge (
      p_success          IN OUT  BOOLEAN
     ,p_err_text         IN OUT  VARCHAR2
     ,p_invo             IN      invoices%ROWTYPE
     ,p_end_day_num      IN      NUMBER   -- päevade arv kuus pp
     ,p_sety_ref_num     IN      service_types.ref_num%TYPE
     ,p_start_date       IN      DATE
     ,p_end_date         IN      DATE
     ,p_maas_ref_num     IN      master_account_services.ref_num%TYPE
     ,p_create_entry     IN      VARCHAR2
     ,p_chca_type_code   IN      VARCHAR2
     ,p_first_susp_start IN      DATE  -- CHG-13643
     ,p_main_bill        IN      BOOLEAN
   ) IS
      --
      CURSOR c_masa IS
         -- start ja end tuleb sisse trunc!!
         SELECT   TRUNC (GREATEST (p_start_date, start_date)) start_date
                 ,TRUNC (LEAST (p_end_date, NVL (end_date, p_end_date))) end_date
                 ,charge_value
                 ,credit_rate_value
                 ,DICO_REF_NUM --mobet-23
             FROM master_service_adjustments
            WHERE maas_ref_num = p_maas_ref_num
              AND start_date < TRUNC (p_end_date + 1)
              AND NVL (end_date, p_end_date) >= p_start_date
              AND (NVL (charge_value, 0) >= 0 OR NVL (credit_rate_value, 0) > 0 OR DICO_REF_NUM is not null) --mobet-23
         ORDER BY start_date;

      --
      l_prev_end_date               DATE;
      l_new_start                   DATE;
      --
      e_processing                  EXCEPTION;
   BEGIN
      l_new_start := p_start_date;

      --dbms_output.put_line('soodustuse algus/või mitte kutse '||to_char(p_start_date)||'-'
      --||to_char(p_end_date));
         --
      FOR rec IN c_masa LOOP
               -- tulemus start_date, end_date (timeta!!, kuid see päev kaasa arvatud),
               -- Kui soodustus algab hiljem, kui hindamisperiood, siis hinda kuni soodustuse alguseni ära!
         --dbms_output.put_line('----- ADJ '||to_char(rec.start_date)||'-'
         --||to_char(rec.end_date)||' maas KREEDIT %'||nvl(to_char(rec.credit_rate_value),'puudub')
         --||' value '||nvl(to_char(rec.charge_value),' puudub'));
         --
         --
         IF l_new_start < rec.start_date THEN
            l_prev_end_date := rec.start_date - 1;

            --
            -- hinda vahemik , mis ei ole masa's puuduv start kuni l_prev_end_date
            monthly_ma_sety_charge
                                  (p_success   -- IN OUT BOOLEAN
                                  ,p_err_text   -- IN OUT VARCHAR2
                                  ,p_invo   -- IN     INVOICES%ROWTYPE
                                  ,p_end_day_num   -- IN     NUMBER
                                  ,p_chca_type_code   -- IN     subs_charging_categories.chca_type_code%TYPE
                                  ,p_sety_ref_num   -- IN     SERVICE_TYPES.ref_num%TYPE
                                  ,p_maas_ref_num   -- IN     master_account_servises.ref_num%TYPE
                                  ,l_new_start   -- p_start_date        IN     DATE
                                  ,l_prev_end_date   -- p_end_date          IN     DATE
                                  ,NULL   -- p_credit_rate_value IN     master_service_adjustments.credit_rate_value%TYPE
                                  ,NULL   -- p_charge_value      IN     master_service_adjustments.charge_value%TYPE
                                  ,p_first_susp_start  -- IN      DATE  -- CHG-13643
                                  ,p_create_entry   -- IN     VARCHAR2
                                  ,p_main_bill   -- IN     BOOLEAN
                                  ,null    ---l_dico_ref_num  --mobet-23
                                  );

            IF NOT p_success THEN
               RAISE e_processing;
            END IF;

            --
            l_new_start := l_prev_end_date + 1;
         END IF;

         --
         -- hinda vahemik masa's rec.start_date kuni l_prev_end_date, arvestades MASA soodustust
         --
         IF GREATEST (l_new_start, rec.start_date) <= rec.end_date THEN
            IF rec.credit_rate_value = 100 OR rec.charge_value = 0 THEN
               NULL;
            ELSE
               monthly_ma_sety_charge
                                     (p_success   -- IN OUT BOOLEAN
                                     ,p_err_text   -- IN OUT VARCHAR2
                                     ,p_invo   -- IN     INVOICES%ROWTYPE
                                     ,p_end_day_num   -- IN     NUMBER
                                     ,p_chca_type_code   -- IN     subs_charging_categories.chca_type_code%TYPE
                                     ,p_sety_ref_num   -- IN     SERVICE_TYPES.ref_num%TYPE
                                     ,p_maas_ref_num   -- IN     master_account_servises.ref_num%TYPE
                                     ,GREATEST (l_new_start, rec.start_date)   -- p_start_date        IN     DATE
                                     ,rec.end_date   -- p_end_date          IN     DATE
                                     ,rec.credit_rate_value   -- IN     master_service_adjustments.credit_rate_value%TYPE
                                     ,rec.charge_value   -- IN     master_service_adjustments.charge_value%TYPE
                                     ,p_first_susp_start -- IN      DATE  -- CHG-13643
                                     ,p_create_entry   -- IN     VARCHAR2
                                     ,p_main_bill   -- IN     BOOLEAN
                                     ,rec.dico_ref_num  --mobet-23
                                     );

               IF NOT p_success THEN
                  RAISE e_processing;
               END IF;
            END IF;

            --
            l_new_start := rec.end_date + 1;
         END IF;
      END LOOP;

      --
      IF l_new_start <= p_end_date THEN
         -- kui Masa polnud, siis kõik ficv ja prli
         -- kui masa lõppes varem, siis masa lõpp+ chca lõpp ficv, prli
         monthly_ma_sety_charge (p_success   -- IN OUT BOOLEAN
                                ,p_err_text   -- IN OUT VARCHAR2
                                ,p_invo   -- IN     INVOICES%ROWTYPE
                                ,p_end_day_num   -- IN     NUMBER
                                ,p_chca_type_code   -- IN     subs_charging_categories.chca_type_code%TYPE
                                ,p_sety_ref_num   -- IN     SERVICE_TYPES.ref_num%TYPE
                                ,p_maas_ref_num   -- IN     master_account_servises.ref_num%TYPE
                                ,l_new_start   -- p_start_date        IN     DATE
                                ,p_end_date   -- IN     DATE
                                ,NULL   -- p_credit_rate_value IN     master_service_adjustments.credit_rate_value%TYPE
                                ,NULL   -- p_charge_value      IN     master_service_adjustments.charge_value%TYPE
                                ,p_first_susp_start -- IN      DATE  -- CHG-13643
                                ,p_create_entry   -- IN     VARCHAR2
                                ,p_main_bill   -- IN     BOOLEAN
                                ,null  --mobet-23
                                );

         IF NOT p_success THEN
            RAISE e_processing;
         END IF;
      END IF;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
   END monthly_maas_sety_charge;

   --
   PROCEDURE calc_non_prorata_package_chg (
      p_maac_ref_num        IN      master_accounts_v.ref_num%TYPE
     ,p_invo_ref_num        IN      invoices.ref_num%TYPE
     ,p_susg_ref_num        IN      subs_serv_groups.ref_num%TYPE
     ,p_nety_type_code      IN      subs_serv_groups.nety_type_code%TYPE
     ,p_package_type        IN      serv_package_types.type_code%TYPE
     ,p_category            IN      package_categories.package_category%TYPE
     ,p_period_start_date   IN      DATE
     ,p_period_end_date     IN      DATE   -- 23:59:59
     ,p_package_start_date  IN      DATE
     ,p_package_end_date    IN      DATE
     ,p_success             OUT     BOOLEAN
     ,p_error_text          OUT     VARCHAR2
     ,p_package_charge_set  OUT     BOOLEAN
     ,p_interim_balance     IN      BOOLEAN DEFAULT FALSE
   ) IS
      --
      CURSOR c_prices (
         p_end_date  IN  DATE
      ) IS
         SELECT   fcit.type_code
                 ,fcit.billing_selector
                 ,fcit.taty_type_code
                 ,prices.charge_value
             FROM fixed_charge_item_types fcit
                 , (SELECT 'PRLI' TYPE
                          ,prli.charge_value
                          ,fcit.type_code fcit_charge_code
                          ,fcit.billing_selector
                      FROM price_lists prli, fixed_charge_item_types fcit
                     WHERE prli.package_category = p_category
                       AND prli.nety_type_code = p_nety_type_code
                       AND prli.sety_ref_num IS NULL
                       AND prli.regular_charge = 'Y'
                       AND prli.once_off = 'N'
                       AND prli.pro_rata = 'N'
                       AND prli.channel_type IS NULL
                       AND NVL (prli.par_value_charge, 'N') = 'N'
                       AND p_end_date BETWEEN prli.start_date AND NVL (prli.end_date, p_end_date)
                       AND fcit.once_off = 'N'
                       AND fcit.pro_rata = 'N'
                       AND fcit.regular_charge = 'Y'
                       AND fcit.prli_package_category = p_category
                       AND fcit.sety_ref_num IS NULL
                       AND fcit.regular_type = 'MINB'   -- CHG-3714
                    UNION ALL
                    SELECT 'FICV' TYPE
                          ,ficv.charge_value
                          ,ficv.fcit_charge_code
                          ,fcit.billing_selector
                      FROM fixed_charge_values ficv, fixed_charge_item_types fcit
                     WHERE ficv.sept_type_code = p_package_type
                       AND ficv.chca_type_code IS NULL
                       AND ficv.sety_ref_num IS NULL
                       AND ficv.channel_type IS NULL
                       AND NVL (ficv.par_value_charge, 'N') = 'N'
                       AND p_end_date BETWEEN ficv.start_date AND NVL (ficv.end_date, p_end_date)
                       AND ficv.fcit_charge_code = fcit.type_code
                       AND fcit.once_off = 'N'
                       AND fcit.pro_rata = 'N'
                       AND fcit.regular_charge = 'Y'
                       AND fcit.regular_type = 'MINB'   -- CHG-3714
                                                     ) prices
            WHERE fcit.prev_fcit_type_code = prices.fcit_charge_code AND fcit.billing_selector = prices.billing_selector
         ORDER BY prices.TYPE;

      --
      CURSOR c_ssst (
         p_start_date  IN  DATE
        ,p_end_date    IN  DATE
      ) IS
         SELECT NVL (SUM (  LEAST (NVL (end_date, p_end_date), p_end_date)
                          - GREATEST (start_date, p_start_date)
                          + c_one_second
                         )
                    ,0
                    )
           FROM ssg_statuses ssst
          WHERE susg_ref_num = p_susg_ref_num
            AND status_code = 'AC'
            AND start_date <= p_end_date
            AND NVL (end_date, p_start_date) >= p_start_date;

      --
      CURSOR c_inen (
         p_period_end  IN  DATE
      ) IS
         SELECT inen.fcit_type_code
               ,inen.billing_selector
               ,inen.eek_amt
           FROM invoices invo, invoice_entries inen
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start_date AND p_period_end
            AND inen.invo_ref_num = invo.ref_num
            AND inen.susg_ref_num = p_susg_ref_num
            AND NOT EXISTS (SELECT 1
                              FROM billing_selectors_v
                             WHERE type_code = inen.billing_selector AND invoice_grouping = 'MK');

      --
      l_start_date                  DATE;
      l_end_date                    DATE;
      l_found                       BOOLEAN;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_charge_value                price_lists.charge_value%TYPE;
      l_prev_charge_amt             NUMBER;
      l_inen_sum                    NUMBER;
      l_ac_days                     NUMBER;
      --
      e_creating_inen               EXCEPTION;
   BEGIN
      p_package_charge_set := FALSE;

      /*
        ** Päevade arvust sõltumatu pakettide kuutasu kuulub arvestamisele, kui liitumine paketiga on toimunud
        ** kohe kuu algusest (või eelnevatel kuudel; ei kuulu arvestamisel poole kuu pealt liitumisel).
        ** Küll aga kuulub arvestamisele neile, kes on poole kuu pealt paketist loobunud.
      */
      IF p_package_start_date <= p_period_start_date OR p_package_end_date <= p_period_end_date THEN
         /*
           ** Kontrollime, kas sellele paketile (kategooriale) on üldse päevade arvust sõltumatu kuutasu defineeritud.
         */
         l_end_date := TRUNC (LEAST (p_period_end_date, NVL (p_package_end_date, p_period_end_date)));

         --
         OPEN c_prices (l_end_date);

         FETCH c_prices
          INTO l_fcit_type_code
              ,l_billing_selector
              ,l_taty_type_code
              ,l_charge_value;

         l_found := c_prices%FOUND;

         CLOSE c_prices;

         --
         IF l_found AND l_charge_value > 0 THEN
            /*
              ** Paketi tasu rakendumiseks peab mobiil vaadeldavas perioodis olema vähemalt 1 päev AC.
            */
            l_start_date := GREATEST (p_package_start_date, p_period_start_date);
            l_end_date := LEAST (p_period_end_date
                                ,NVL (TRUNC (p_package_end_date) + 1 - c_one_second, p_period_end_date)
                                );   -- Mobiilide staatused salvestatud koos ajafaktoriga

            --
            OPEN c_ssst (l_start_date, l_end_date);

            FETCH c_ssst
             INTO l_ac_days;

            CLOSE c_ssst;

            --
            IF NVL (l_ac_days, 0) >= c_min_ac_days_for_pkg_fees THEN
               /*
                 ** Kõik tingimused kuutasu peale panemiseks on täidetud. Kui nüüd panemata jääb, siis sellepärast, et
                 ** arve on juba piisavalt suur -> sel juhul pole mõtet aga kontrollida ka sama perioodi ülejäänud pakette
                 ** sellel mobiilil.
               */
               p_package_charge_set := TRUE;
               /*
                 ** Leiame perioodi billing arvete summa sellele mobiilile ilma M-kaubanduseta (ilma käibemaksuta summa).
               */
               l_prev_charge_amt := 0;
               l_inen_sum := 0;

               --
               FOR l_inen IN c_inen (p_period_end_date) LOOP
                  IF l_inen.billing_selector = l_billing_selector AND l_inen.fcit_type_code = l_fcit_type_code THEN
                     /*
                       ** Paketi haldustasu on juba eelnevalt võlanõude vahearvele kantud. Seda summat mobiili koondsummasse
                       ** ei arvata. Küll tuleb seda summat kasutada lõpliku paketi haldustasu korrigeerimiseks.
                     */
                     l_prev_charge_amt := NVL (l_prev_charge_amt, 0) + l_inen.eek_amt;
                  ELSE
                     l_inen_sum := NVL (l_inen_sum, 0) + l_inen.eek_amt;
                  END IF;
               END LOOP;

               /*
                 ** Leiame paketi haldustasu = paketi tasu - tegelikult kasutatud teenuste summa.
               */
               l_charge_value := GREATEST (NVL (l_charge_value, 0) - l_inen_sum, 0);
               /*
                 ** Kuna haldustasu kantakse peale 1 kord kuus, siis kui on juba vahearvele kantud, tuleb siin korrigeerida
                 ** vahearvele kantud tasu -> kui vahepeal teenuseid juurde tarbitud, siis vähendada selle võrra.
               */
               l_charge_value := l_charge_value - l_prev_charge_amt;

               /*
                 ** Kanname vajadusel arvutatud paketi haldustasu arvereale.
               */
               IF l_charge_value <> 0 THEN
                  IF p_interim_balance THEN
                     close_interim_billing_invoice.cre_upd_interim_inen (p_success   -- OUT BOOLEAN
                                                                        ,p_error_text   -- OUT VARCHAR2
                                                                        ,p_invo_ref_num   -- IN     NUMBER
                                                                        ,l_fcit_type_code   -- IN     VARCHAR2
                                                                        ,l_billing_selector   -- IN     VARCHAR2
                                                                        ,l_taty_type_code   -- IN     VARCHAR2
                                                                        ,l_charge_value   -- IN     NUMBER
                                                                        ,NULL   -- p_num_of_days       IN     NUMBER
                                                                        ,p_susg_ref_num   -- IN     NUMBER
                                                                        );
                  ELSE
                     create_entries (p_success   -- IN OUT BOOLEAN
                                    ,p_error_text   -- IN OUT varchar2
                                    ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                    ,l_fcit_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TYPE_CODE%TYPE
                                    ,l_taty_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TATY_TYPE_CODE%TYPE
                                    ,l_billing_selector   -- IN     FIXED_CHARGE_ITEM_TYPES.BILLING_SELECTOR%TYPE
                                    ,l_charge_value   -- IN     NUMBER
                                    ,p_susg_ref_num   -- IN     SUBS_SERV_GROUPS.ref_num%TYPE
                                    ,NULL   -- p_num_of_days      IN     NUMBER
                                    );
                  END IF;

                  --
                  IF NOT p_success THEN
                     RAISE e_creating_inen;
                  END IF;
               END IF;
            END IF;   -- IF NVL(l_ac_days, 0) >= 1 THEN
         END IF;   -- IF l_found THEN
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_creating_inen THEN
         p_success := FALSE;
   END calc_non_prorata_package_chg;

   /*
     ** Protseduur kannab arvele REPL regular_type tüüpi paketi kuutasu, kui
     ** pole juba eelnevalt arvele kantud summeeritud lahendustasu.
   */
   PROCEDURE calc_non_prorata_package_repl (
      p_maac_ref_num        IN      master_accounts_v.ref_num%TYPE
     ,p_invo_ref_num        IN      invoices.ref_num%TYPE
     ,p_susg_ref_num        IN      subs_serv_groups.ref_num%TYPE
     ,p_nety_type_code      IN      subs_serv_groups.nety_type_code%TYPE
     ,p_package_type        IN      serv_package_types.type_code%TYPE
     ,p_category            IN      package_categories.package_category%TYPE
     ,p_period_start_date   IN      DATE
     ,p_period_end_date     IN      DATE   -- 23:59:59
     ,p_package_start_date  IN      DATE
     ,p_package_end_date    IN      DATE
     ,p_success             OUT     BOOLEAN
     ,p_error_text          OUT     VARCHAR2
     ,p_interim_balance     IN      BOOLEAN DEFAULT FALSE
   ) IS
      --
      CURSOR c_prices (
         p_end_date  IN  DATE
      ) IS
         SELECT   2 sort_type
                 ,fcit.type_code
                 ,fcit.billing_selector
                 ,fcit.taty_type_code
                 ,prli.charge_value
                 ,fcit.first_prorated_charge
                 ,fcit.last_prorated_charge  -- CHG-6214
             FROM price_lists prli, fixed_charge_item_types fcit
            WHERE prli.package_category = p_category
              AND prli.nety_type_code = p_nety_type_code
              AND prli.sety_ref_num IS NULL
              AND prli.regular_charge = 'Y'
              AND prli.once_off = 'N'
              AND prli.pro_rata = 'N'
              AND prli.channel_type IS NULL
              AND NVL (prli.par_value_charge, 'N') = 'N'
              AND p_end_date BETWEEN prli.start_date AND NVL (prli.end_date, p_end_date)
              AND fcit.once_off = 'N'
              AND fcit.pro_rata = 'N'
              AND fcit.regular_charge = 'Y'
              AND fcit.prli_package_category = p_category
              AND fcit.sety_ref_num IS NULL
              AND fcit.regular_type = 'REPL'
         UNION ALL
         SELECT   1 sort_type
                 ,fcit.type_code
                 ,fcit.billing_selector
                 ,fcit.taty_type_code
                 ,ficv.charge_value
                 ,fcit.first_prorated_charge
                 ,fcit.last_prorated_charge  -- CHG-6214
             FROM fixed_charge_values ficv, fixed_charge_item_types fcit
            WHERE ficv.sept_type_code = p_package_type
              AND ficv.chca_type_code IS NULL
              AND ficv.sety_ref_num IS NULL
              AND ficv.channel_type IS NULL
              AND NVL (ficv.par_value_charge, 'N') = 'N'
              AND p_end_date BETWEEN ficv.start_date AND NVL (ficv.end_date, p_end_date)
              AND ficv.fcit_charge_code = fcit.type_code
              AND fcit.once_off = 'N'
              AND fcit.pro_rata = 'N'
              AND fcit.regular_charge = 'Y'
              AND fcit.regular_type = 'REPL'
         ORDER BY sort_type;

      --
      CURSOR c_ssst (
         p_start_date  IN  DATE
        ,p_end_date    IN  DATE
      ) IS
         SELECT NVL (SUM (  LEAST (NVL (end_date, p_end_date), p_end_date)
                          - GREATEST (start_date, p_start_date)
                          + c_one_second
                         )
                    ,0
                    )
           FROM ssg_statuses ssst
          WHERE susg_ref_num = p_susg_ref_num
            AND status_code = 'AC'
            AND start_date <= p_end_date
            AND NVL (end_date, p_start_date) >= p_start_date;

      --
      -- kas arvel leidub kuutasu
      CURSOR c_inen_pack_chg (
         p_period_end      IN  DATE
        ,p_fcit_type_code  IN  VARCHAR2
      ) IS
         SELECT SUM (inen.eek_amt)
           FROM invoices invo, invoice_entries inen
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start_date AND p_period_end
            AND inen.invo_ref_num = invo.ref_num
            AND inen.susg_ref_num = p_susg_ref_num
            AND inen.fcit_type_code = p_fcit_type_code;

      -- CHG-3832: kas interim arvel leidub kuutasu
      CURSOR c_inen_int_pack_chg (
         p_period_end      IN  DATE
        ,p_fcit_type_code  IN  VARCHAR2
      ) IS
         SELECT SUM (inen.eek_amt)
           FROM invoices_interim invo, invoice_entries_interim inen
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.invoice_date BETWEEN p_period_start_date AND p_period_end
            AND inen.invo_ref_num = invo.ref_num
            AND inen.susg_ref_num = p_susg_ref_num
            AND inen.fcit_type_code = p_fcit_type_code;

      --lahendustasu arvel, fcit prev viidaga
      CURSOR c_inen_prev_fcit (
         p_period_end      IN  DATE
        ,p_fcit_type_code  IN  VARCHAR2
      ) IS
         SELECT SUM (inen.eek_amt)
           FROM invoices invo, invoice_entries inen, fixed_charge_item_types fcit
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start_date AND p_period_end
            AND inen.invo_ref_num = invo.ref_num
            AND inen.susg_ref_num = p_susg_ref_num
            AND inen.fcit_type_code = fcit.type_code
            AND fcit.prev_fcit_type_code = p_fcit_type_code;

      -- CHG-3832: lahendustasu interim arvel, fcit prev viidaga
      CURSOR c_inen_int_prev_fcit (
         p_period_end      IN  DATE
        ,p_fcit_type_code  IN  VARCHAR2
      ) IS
         SELECT SUM (inen.eek_amt)
           FROM invoices_interim invo, invoice_entries_interim inen, fixed_charge_item_types fcit
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.invoice_date BETWEEN p_period_start_date AND p_period_end
            AND inen.invo_ref_num = invo.ref_num
            AND inen.susg_ref_num = p_susg_ref_num
            AND inen.fcit_type_code = fcit.type_code
            AND fcit.prev_fcit_type_code = p_fcit_type_code;

      --
      CURSOR c_inen (
         p_period_end      IN  DATE
        ,p_fcit_type_code  IN  VARCHAR2
      ) IS
         SELECT inen.*
           FROM invoices invo, invoice_entries inen
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start_date AND p_period_end
            AND inen.invo_ref_num = invo.ref_num
            AND inen.susg_ref_num = p_susg_ref_num
            AND inen.fcit_type_code = p_fcit_type_code;

      -- CHG-5762
      CURSOR c_ftco (p_period_start  DATE
                    ,p_period_end    DATE
      ) IS
         SELECT Greatest(start_date, p_period_start_date) start_date
              , Least(end_date, Nvl(date_closed,end_date), p_period_end_date) end_date
              , date_closed
         FROM fixed_term_contracts ftco
         WHERE susg_ref_num = p_susg_ref_num
           AND start_date <= p_period_end_date
           AND Nvl(date_closed, end_date) > p_period_start_date
           AND mixed_packet_code IS NOT NULL
           AND NOT EXISTS (select 1
                           from mixed_packet_orders
                           where ebs_order_number = ftco.ebs_order_number
                             and mixed_packet_code = ftco.mixed_packet_code
                             and term_request_type = 'NULLIFY'
                          )
         ORDER BY start_date
      ;
      --
      l_start_date                  DATE;
      l_end_date                    DATE;
      l_found                       BOOLEAN;
      l_inen_rec                    invoice_entries%ROWTYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_charge_value                price_lists.charge_value%TYPE;
      l_first_prorated_charge       fixed_charge_item_types.first_prorated_charge%TYPE;
      l_last_prorated_charge        fixed_charge_item_types.last_prorated_charge%TYPE;  -- CHG-6214
      l_prev_charge_amt             NUMBER;
      l_inen_sum                    NUMBER;
      l_ac_days                     NUMBER;
      l_package_charge              NUMBER;
      l_solution_charge             NUMBER;
      l_pack_daycnt                 NUMBER;
      l_per_daycnt                  NUMBER;
      l_sort_type                   NUMBER;
      l_ftco_pak_exists             BOOLEAN;  -- CHG-5762
      l_month_days                  NUMBER;   -- CHG-5762
      l_ftco_day_count              NUMBER;   -- CHG-5762
      l_charge_days                 NUMBER;   -- CHG-5762
      l_charge_period               NUMBER;   -- CHG-5762
      l_prev_date_closed            DATE;     -- CHG-5762
      --
      e_creating_inen               EXCEPTION;
   BEGIN
      /*
        ** Kontrollime, kas sellele paketile (kategooriale) on üldse kuutasu defineeritud.
      */
      l_end_date := TRUNC (LEAST (p_period_end_date, NVL (p_package_end_date, p_period_end_date)));

      --
      OPEN c_prices (l_end_date);
      FETCH c_prices
       INTO l_sort_type
           ,l_fcit_type_code
           ,l_billing_selector
           ,l_taty_type_code
           ,l_charge_value
           ,l_first_prorated_charge
           ,l_last_prorated_charge;  -- CHG-6214
      l_found := c_prices%FOUND;
      CLOSE c_prices;
      
      /*
        ** CHG-5762: PAK komplekti olemasolu korral perioodis maksustatakse ainult ilma komplektida päevad
      */
      l_ftco_pak_exists := FALSE;
      l_ftco_day_count  := 0;
      l_month_days      := Last_Day(trunc(p_period_end_date)) - Trunc(p_period_end_date, 'MM') + 1;
      --
      IF l_found AND l_charge_value > 0 THEN
         --
         FOR l_ftco_rec IN c_ftco(Greatest(p_package_start_date, p_period_start_date), p_period_end_date) LOOP   
            --
            IF Trunc(l_prev_date_closed) >= Trunc(l_ftco_rec.start_date) THEN
               -- Päevade ülekate, uus algas samal päeval või varem, kui eelmine lõpetati
               l_ftco_day_count := l_ftco_day_count + Trunc(l_ftco_rec.end_date) - Trunc(l_prev_date_closed);
            ELSE
               l_ftco_day_count := l_ftco_day_count +  Trunc(l_ftco_rec.end_date) - Trunc(l_ftco_rec.start_date) + 1;
            END IF;
            --
            l_prev_date_closed := l_ftco_rec.date_closed;
            l_ftco_pak_exists  := TRUE;
            --
         END LOOP;
         --
         IF l_ftco_pak_exists THEN
            --
            l_charge_period := Trunc(p_period_end_date) - Trunc(Greatest(p_package_start_date, p_period_start_date)) + 1;
            l_charge_days := Greatest((l_charge_period - l_ftco_day_count), 0);
            --
            IF l_ftco_day_count > 0 AND l_ftco_day_count <> l_month_days THEN
               -- PÄEVAPÕHINE HINNASTAMINE
               l_charge_value := Round((l_charge_value / l_month_days) * l_charge_days, 2);
               --
            ELSE
               --
               l_charge_value := 0;  -- POLE VAJA HINNASTADA!
               --
            END IF;
            --
         END IF;
         --
      END IF;
      /* End CHG-5762 */
      

      --
      IF l_found AND l_charge_value > 0 THEN
         /*
           ** Paketi tasu rakendumiseks peab mobiil vaadeldavas perioodis olema vähemalt 1 päev AC.
         */
         l_start_date := GREATEST (p_package_start_date, p_period_start_date);
         l_end_date := LEAST (p_period_end_date, NVL (TRUNC (p_package_end_date) + 1 - c_one_second, p_period_end_date));   -- Mobiilide staatused salvestatud koos ajafaktoriga

         --
         OPEN c_ssst (l_start_date, l_end_date);
         FETCH c_ssst INTO l_ac_days;
         CLOSE c_ssst;

         --
         IF NVL (l_ac_days, 0) >= c_min_ac_days_for_pkg_fees THEN
            /*
              ** Mobiil on olnud piisavalt aktiivne ja talle tuleb arvutada kuutasu
              ** Leiame arvel summa, mille PREV_FCIT_TYPE_CODE = paketi kuutasu FCIT (l_fcit_type_code).
            */
            IF p_package_start_date >= TRUNC (p_period_start_date, 'MM') AND
               NVL (p_package_end_date, p_period_end_date) + c_one_second > p_period_end_date AND
               NOT l_ftco_pak_exists -- CHG-5762
            THEN
               IF l_first_prorated_charge = 'Y' THEN
                  /*
                    ** CHG-3811: Muudetud päevade arvutamise loogikat.
                  */
                  l_pack_daycnt := TRUNC (p_period_end_date) - p_package_start_date + 1;
                  l_per_daycnt := TRUNC (LAST_DAY (p_period_end_date)) - p_period_start_date + 1;
                  l_charge_value := ROUND ((l_pack_daycnt * l_charge_value / l_per_daycnt), 2);
               ELSE
                  l_charge_value := 0;   -- liitumiskuul ei tule kuutasu
               END IF;
            END IF;
            /*
              ** CHG-6214: Paketi lõpetamise kuul päevapõhine kuutasu
            */
            IF l_last_prorated_charge = 'Y' AND
               p_package_end_date IS NOT NULL AND
               p_package_end_date < p_period_end_date + c_one_second AND            
               NOT l_ftco_pak_exists -- CHG-5762
            THEN
               --
               l_pack_daycnt  := Trunc(p_package_end_date) - Trunc(p_period_start_date) + 1;
               l_per_daycnt   := Trunc(Last_Day (p_period_end_date)) - p_period_start_date + 1;
               l_charge_value := Round((l_pack_daycnt * l_charge_value / l_per_daycnt), 2);
               --
            END IF;

            /*
              ** Leiame, kas kuutasu on juba arvele kantud
            */
            OPEN c_inen_pack_chg (p_period_end_date, l_fcit_type_code);

            FETCH c_inen_pack_chg
             INTO l_package_charge;

            CLOSE c_inen_pack_chg;

            /*
              ** CHG-3832: Kui tegemist Interim vahearvega, siis kontrollime kuutasu ka interim arvelt.
            */
            IF p_interim_balance AND l_package_charge IS NULL THEN
               OPEN c_inen_int_pack_chg (p_period_end_date, l_fcit_type_code);

               FETCH c_inen_int_pack_chg
                INTO l_package_charge;

               CLOSE c_inen_int_pack_chg;
            END IF;

            IF l_charge_value > 0 THEN
               /*
                 ** Leiame, kas lahendustasu on juba arvele kantud
               */
               OPEN c_inen_prev_fcit (p_period_end_date, l_fcit_type_code);

               FETCH c_inen_prev_fcit
                INTO l_solution_charge;

               CLOSE c_inen_prev_fcit;

               /*
                 ** CHG-3832: Kui tegemist Interim vahearvega, siis kontrollime lahendustasu ka interim arvelt.
               */
               IF p_interim_balance AND l_solution_charge IS NULL THEN
                  OPEN c_inen_int_prev_fcit (p_period_end_date, l_fcit_type_code);

                  FETCH c_inen_int_prev_fcit
                   INTO l_solution_charge;

                  CLOSE c_inen_int_prev_fcit;
               END IF;

               IF l_solution_charge > 0 THEN
                  -- lahendustasu on arvel
                  IF l_package_charge > 0 THEN
                     /*
                       ** Leiame ja modifitseerime arverea Common_Monthly_Charges tabelisse sisestamiseks,
                       ** kui pole tegemist INTERIM tüüpi vahearvega.
                     */
                     IF NOT p_interim_balance THEN
                        --
                        OPEN c_inen (p_period_end_date, l_fcit_type_code);

                        FETCH c_inen
                         INTO l_inen_rec;

                        CLOSE c_inen;

                        --
                        l_inen_rec.acc_amount := l_charge_value;   -- CHG4594
                        -- CHG-4899: l_inen_rec.amt_tax := 0;
                        l_inen_rec.created_by := sec.get_username ();
                        l_inen_rec.date_created := SYSDATE;
                        l_inen_rec.num_of_days := l_charge_days; -- CHG-5762
                        --
                        ins_common_monthly_charges (l_inen_rec);
                     END IF;

                     -- kuutasu on eelnevalt arvele kantud. Arvele tuleb viia 0-l_sum ehk neg summa.
                     l_charge_value := l_charge_value * (-1);
                  ELSE
                     /*
                       ** Lisame kuutasu Common_Monthly_Charges tabelisse.
                     */
                     IF NOT p_interim_balance THEN
                        --
                        l_inen_rec.invo_ref_num := p_invo_ref_num;
                        l_inen_rec.acc_amount := l_charge_value;   -- CHG4594
                        -- CHG-4899: l_inen_rec.amt_tax := 0;
                        l_inen_rec.rounding_indicator := 'N';
                        l_inen_rec.under_dispute := 'N';
                        l_inen_rec.billing_selector := l_billing_selector;
                        l_inen_rec.fcit_type_code := l_fcit_type_code;
                        l_inen_rec.taty_type_code := l_taty_type_code;
                        l_inen_rec.susg_ref_num := p_susg_ref_num;
                        l_inen_rec.created_by := sec.get_username ();
                        l_inen_rec.date_created := SYSDATE;
                        l_inen_rec.module_ref := 'U659';
                        l_inen_rec.num_of_days := l_charge_days; -- CHG-5762
                        --
                        ins_common_monthly_charges (l_inen_rec);
                     --
                     END IF;

                     -- kuutasu arvele ei kanna
                     l_charge_value := 0;
                  END IF;
               --
               ELSIF l_package_charge > 0 THEN
                  -- kuutasu on arvel
                  l_charge_value := l_charge_value - l_package_charge;
               END IF;
            --
            END IF;

            /*
              ** Kanname vajadusel arvutatud paketi haldustasu arvereale.
            */
            IF l_charge_value <> 0 THEN
               IF p_interim_balance THEN   -- vahearvele registreerimine
                  close_interim_billing_invoice.cre_upd_interim_inen (p_success   -- OUT BOOLEAN
                                                                     ,p_error_text   -- OUT VARCHAR2
                                                                     ,p_invo_ref_num   -- IN     NUMBER
                                                                     ,l_fcit_type_code   -- IN     VARCHAR2
                                                                     ,l_billing_selector   -- IN     VARCHAR2
                                                                     ,l_taty_type_code   -- IN     VARCHAR2
                                                                     ,l_charge_value   -- IN     NUMBER
                                                                     ,NULL   -- p_num_of_days       IN     NUMBER
                                                                     ,p_susg_ref_num   -- IN     NUMBER
                                                                     );
               ELSE
                  -- arve rea loomine
                  create_entries (p_success   -- IN OUT BOOLEAN
                                 ,p_error_text   -- IN OUT varchar2
                                 ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                 ,l_fcit_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TYPE_CODE%TYPE
                                 ,l_taty_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TATY_TYPE_CODE%TYPE
                                 ,l_billing_selector   -- IN     FIXED_CHARGE_ITEM_TYPES.BILLING_SELECTOR%TYPE
                                 ,l_charge_value   -- IN     NUMBER
                                 ,p_susg_ref_num   -- IN     SUBS_SERV_GROUPS.ref_num%TYPE
                                 ,l_charge_days -- CHG-5762   -- p_num_of_days      IN     NUMBER
                                 );
               END IF;

               --
               IF NOT p_success THEN
                  RAISE e_creating_inen;
               END IF;
            END IF;   -- IF l_charge_value <> 0
         END IF;   -- IF NVL(l_ac_days, 0) >= 1 THEN
      END IF;   -- IF l_found THEN

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_creating_inen THEN
         p_success := FALSE;
   END calc_non_prorata_package_repl;

   /*
     ** Protseduur leiab lähte- ja lõpp-väärtusest sõltuvad erihinnad (teenuse parameetri või
     ** paketi tasemel), kui sellised on registreeritud.
     ** CHG1634 - FIXED_SPECIAL_PRICES tabelisse on võimalik defineerida ühepoolseid erihindu.
     **           Erihinnad on sama tähendusega, mis FIXED_CHARGE_VALUES tabelis olevad hinnad.
     **           Erinevuseks on tähtajalisus, mida saab defineerida ainult FISP hindadele.
     **           Prioriteetseim on kahepoolne FROM-TO hind, kui seda ei leita, otsitakse ühepoolset hinda.
     ** CHG-4658: Koondarve tähtajalisus. Muudetud kursorit c_fisp_one_side_price, et oleks võimalik ka 
     **           leida hinda, millel puudub nii lähte- kui ka sihtpakett, aga on olemas tähtajalisuse tüüp ja pikkus. 
   */
   PROCEDURE get_from_to_special_price (
      p_sety_ref_num         IN      service_types.ref_num%TYPE
     ,p_once_off             IN      fixed_charge_item_types.once_off%TYPE
     ,p_pro_rata             IN      fixed_charge_item_types.pro_rata%TYPE
     ,p_regular_charge       IN      fixed_charge_item_types.regular_charge%TYPE
     ,p_chk_date             IN      DATE
     ,p_from_package         IN      serv_package_types.type_code%TYPE
     ,p_to_package           IN      serv_package_types.type_code%TYPE
     ,p_from_category        IN      package_categories.package_category%TYPE
     ,p_to_category          IN      package_categories.package_category%TYPE
     ,p_sepa_ref_num         IN      service_parameters.ref_num%TYPE
     ,p_from_sepv_ref_num    IN      service_param_values.ref_num%TYPE
     ,p_to_sepv_ref_num      IN      service_param_values.ref_num%TYPE
     ,p_channel_type         IN      fixed_special_prices.channel_type%TYPE
     ,p_fixed_term_category  IN      fixed_special_prices.fixed_term_category%TYPE
     ,p_fixed_term_length    IN      fixed_special_prices.fixed_term_length%TYPE
     ,p_fixed_term_sety      IN      fixed_special_prices.fixed_term_sety%TYPE
     ,p_fcit_type_code       OUT     fixed_charge_item_types.type_code%TYPE
     ,p_charge_value         OUT     fixed_special_prices.charge_value%TYPE
     ,p_taty_type_code       OUT     tax_types.tax_type_code%TYPE
     ,p_billing_selector     OUT     fixed_charge_item_types.billing_selector%TYPE
     ,p_fcdt_type_code       OUT     fixed_charge_item_types.fcdt_type_code%TYPE
     ,p_tax                  OUT     NUMBER
     ,p_success              IN OUT  BOOLEAN
     ,p_error_text           IN OUT  VARCHAR2
   ) IS
      l_found                       BOOLEAN := FALSE;

      --  CHG1634: kursor "kahepoolse hinna" pärimiseks
      CURSOR c_fisp_two_side_price IS
         SELECT   fisp.fcit_type_code
                 ,fisp.charge_value
                 ,fcit.taty_type_code
                 ,fcit.billing_selector
                 ,fcit.fcdt_type_code
                 , gen_bill.get_tax_rate (fcit.taty_type_code, p_chk_date) * fisp.charge_value tax
             FROM fixed_special_prices fisp, fixed_charge_item_types fcit
            WHERE fisp.sety_ref_num = p_sety_ref_num
              AND fisp.once_off = p_once_off
              AND fisp.pro_rata = p_pro_rata
              AND fisp.regular_charge = p_regular_charge
              AND NVL (fisp.channel_type, NVL (p_channel_type, '***')) = NVL (p_channel_type, '***')
              AND p_chk_date BETWEEN fisp.start_date AND NVL (fisp.end_date, p_chk_date)
              AND (fisp.from_package = p_from_package OR fisp.from_category = p_from_category)
              AND (fisp.to_package = p_to_package OR fisp.to_category = p_to_category)
              AND NVL (fisp.fixed_term_category, NVL (p_fixed_term_category, '***')) =
                                                                           NVL (p_fixed_term_category, '***')   -- CHG-3770
              AND NVL (fisp.fixed_term_length, NVL (p_fixed_term_length, -1)) = NVL (p_fixed_term_length, -1)
              AND NVL (fixed_term_sety, -1) = NVL (p_fixed_term_sety, -1)
              AND fisp.sepa_ref_num IS NULL
              AND fcit.type_code = fisp.fcit_type_code
         ORDER BY fisp.channel_type, fisp.from_package, fisp.to_package, fisp.fixed_term_category;   -- CHG-3770: fisp.fixed_term_category

      --  CHG1634: kursor "ühepoolse hinna" pärimiseks
      CURSOR c_fisp_one_side_price IS
         SELECT   fisp.fcit_type_code
                 ,fisp.charge_value
                 ,fcit.taty_type_code
                 ,fcit.billing_selector
                 ,fcit.fcdt_type_code
                 , gen_bill.get_tax_rate (fcit.taty_type_code, p_chk_date) * fisp.charge_value tax
             FROM fixed_special_prices fisp, fixed_charge_item_types fcit
            WHERE fisp.sety_ref_num = p_sety_ref_num
              AND fisp.once_off = 'Y'
              AND fisp.pro_rata = 'N'
              AND fisp.regular_charge = 'N'
              AND NVL (fisp.channel_type, NVL (p_channel_type, '***')) = NVL (p_channel_type, '***')
              AND p_chk_date BETWEEN fisp.start_date AND NVL (fisp.end_date, p_chk_date)
              AND (       (fisp.to_package = p_to_package OR fisp.to_category = p_to_category)
                      AND (fisp.from_package IS NULL AND fisp.from_category IS NULL)
                   OR     (fisp.from_package = p_from_package OR fisp.from_category = p_from_category)
                      AND (fisp.to_package IS NULL AND fisp.to_category IS NULL)
                   --- CHG-4658 ---------------------------------------------
                   OR (    fisp.from_package IS NULL
                       AND fisp.from_category IS NULL
                       AND fisp.to_package IS NULL
                       AND fisp.to_category IS NULL
                       AND p_to_package IS NULL
                       AND p_to_category IS NULL
                       AND p_from_package IS NULL
                       AND p_from_category IS NULL
                       AND fisp.sety_ref_num IN (SELECT ref_num
                                                   FROM service_types
                                                  WHERE ref_num = fisp.sety_ref_num AND secl_class_code IN ('M', 'Q'))
                      )
                  ----------------------------------------------------------
                  )
              AND NVL (fisp.fixed_term_category, '***') = NVL (p_fixed_term_category, '***')
              AND NVL (fisp.fixed_term_length, NVL (p_fixed_term_length, -1)) = NVL (p_fixed_term_length, -1)
              AND NVL (fixed_term_sety, -1) = NVL (p_fixed_term_sety, -1)
              AND fisp.sepa_ref_num IS NULL
              AND fcit.type_code = fisp.fcit_type_code
         ORDER BY fisp.channel_type, fisp.from_package, fisp.to_package;

      -- CHG-4313: Added Master Account service support - no need for package or category.
      CURSOR c_fisp_sepa IS
         SELECT   fisp.fcit_type_code
                 ,fisp.charge_value
                 ,fcit.taty_type_code
                 ,fcit.billing_selector
                 ,fcit.fcdt_type_code
                 , gen_bill.get_tax_rate (fcit.taty_type_code, p_chk_date) * fisp.charge_value tax
             FROM fixed_special_prices fisp, fixed_charge_item_types fcit
            WHERE fisp.sety_ref_num = p_sety_ref_num
              AND fisp.once_off = p_once_off
              AND fisp.pro_rata = p_pro_rata
              AND fisp.regular_charge = p_regular_charge
              AND NVL (fisp.channel_type, NVL (p_channel_type, '***')) = NVL (p_channel_type, '***')
              AND p_chk_date BETWEEN fisp.start_date AND NVL (fisp.end_date, p_chk_date)
              AND (   Nvl(fisp.to_package, p_to_package) = p_to_package AND  -- CHG-6472: Added NVL and changed 'OR' -> 'AND'
                      Nvl(fisp.to_category, p_to_category) = p_to_category   -- CHG-6472: Added NVL
                   OR fisp.sety_ref_num IN (SELECT ref_num
                                              FROM service_types
                                             WHERE ref_num = fisp.sety_ref_num AND secl_class_code = 'M')
                  )
              AND fisp.sepa_ref_num = p_sepa_ref_num
              AND fisp.from_sepv_ref_num = p_from_sepv_ref_num
              AND fisp.to_sepv_ref_num = p_to_sepv_ref_num
              AND fcit.type_code = fisp.fcit_type_code
         ORDER BY fisp.channel_type, fisp.to_package
      ;
      -- CHG-6472
      CURSOR c_fisp_seq IS
         SELECT *
         FROM fixed_special_prices
         WHERE sety_ref_num = p_sety_ref_num
           AND once_off = p_once_off
           AND pro_rata = p_pro_rata
           AND regular_charge = p_regular_charge
           AND Nvl(channel_type, Nvl(p_channel_type, '***')) = Nvl(p_channel_type, '***')
           AND p_chk_date BETWEEN start_date AND Nvl(end_date, SYSDATE)
           AND sepa_ref_num = p_sepa_ref_num
           AND from_sepv_ref_num = p_from_sepv_ref_num
           AND to_sepv_ref_num IS NULL
           AND to_seq_operator IS NOT NULL
      ;
      --  CHG-6472
      CURSOR c_sepv_seq (p_sepv_ref_num  NUMBER) IS
         SELECT param_value_seq
         FROM service_param_values
         WHERE ref_num = p_sepv_ref_num
      ;
      --  CHG-6472
      CURSOR c_fcit IS
         SELECT *
         FROM fixed_charge_item_types
         WHERE sety_ref_num = p_sety_ref_num
           AND once_off = p_once_off
           AND pro_rata = p_pro_rata
           AND regular_charge = p_regular_charge
           AND Nvl(package_category, Nvl(p_to_category, '***')) = Nvl(p_to_category, '***')
           AND Nvl(archive, 'N') = 'N'
      ;
      --
      TYPE RefCurType IS REF CURSOR;
      --
      l_ref_cur        RefCurType;
      l_dummy          NUMBER;
      l_fisp_rec       fixed_special_prices%ROWTYPE;
      l_fcit_rec       fixed_charge_item_types%ROWTYPE;
      l_from_sepv_seq  service_param_values.param_value_seq%TYPE;
      l_to_sepv_seq    service_param_values.param_value_seq%TYPE;
      l_query          VARCHAR2(500);
      --
   BEGIN
      p_success := TRUE;

      IF p_sety_ref_num IS NOT NULL AND p_once_off = 'Y' AND p_pro_rata = 'N' AND p_regular_charge = 'N' THEN
         --
         IF (p_fixed_term_category IS NOT NULL AND p_fixed_term_length IS NULL) THEN
            -- wrong usage, raise exception
            p_error_text :=
               'get_from_to_special_price wrong usage - p_fixed_term_category IS NOT NULL, but p_fixed_term_length IS NULL';
            p_success := FALSE;
         END IF;

         IF ((p_fixed_term_length IS NOT NULL OR p_fixed_term_sety IS NOT NULL) AND p_fixed_term_category IS NULL) THEN
            -- wrong usage, raise exception
            p_error_text :=
               'get_from_to_special_price wrong usage - fixed_term_length or p_fixed_term_sety IS NOT NULL, but p_fixed_term_category IS NULL';
            p_success := FALSE;
         END IF;

         IF (p_success) THEN
            IF p_sepa_ref_num IS NOT NULL THEN
               /*
                 ** Kui on väljakutse teenusparameetri tasemel (sisendis p_sepa_ref_num NOT NULL),
                 ** siis on mõtet kontrollida erihindu teenusparameetri from->to väärtuste jaoks.
               */
               OPEN c_fisp_sepa;
               FETCH c_fisp_sepa INTO p_fcit_type_code
                                     ,p_charge_value
                                     ,p_taty_type_code
                                     ,p_billing_selector
                                     ,p_fcdt_type_code
                                     ,p_tax;
               l_found := c_fisp_sepa%FOUND;  -- CHG-6472
               CLOSE c_fisp_sepa;
               
               /* CHG-6472 */
               IF NOT l_found THEN
                  --
                  OPEN  c_fisp_seq;
                  FETCH c_fisp_seq INTO l_fisp_rec;
                  l_found := c_fisp_seq%FOUND;
                  CLOSE c_fisp_seq;
                  --
                  IF l_found THEN
                     --
                     OPEN  c_sepv_seq(p_from_sepv_ref_num);
                     FETCH c_sepv_seq INTO l_from_sepv_seq;
                     CLOSE c_sepv_seq;
                     --
                     OPEN  c_sepv_seq(p_to_sepv_ref_num);
                     FETCH c_sepv_seq INTO l_to_sepv_seq;
                     CLOSE c_sepv_seq;
                     -- 
                     l_query := 'SELECT 1 FROM dual WHERE '||l_to_sepv_seq||' '||l_fisp_rec.to_seq_operator||' '||l_from_sepv_seq;
                     --
                     l_found := FALSE;
                     --
                     OPEN l_ref_cur FOR l_query;
                     LOOP
                        FETCH l_ref_cur INTO l_dummy;
                        EXIT WHEN l_ref_cur%NOTFOUND;
                        --
                        l_found := TRUE;
                        --
                     END LOOP;
                     --
                     IF l_found THEN
                        --
                        OPEN  c_fcit;
                        FETCH c_fcit INTO l_fcit_rec;
                        l_found := c_fcit%FOUND;
                        CLOSE c_fcit;
                        --
                        IF l_found THEN
                           --
                           p_charge_value     := l_fisp_rec.charge_value;
                           p_fcit_type_code   := l_fcit_rec.type_code;
                           p_billing_selector := l_fcit_rec.billing_selector;
                           p_taty_type_code   := l_fcit_rec.taty_type_code;   
                           p_fcdt_type_code   := l_fcit_rec.fcdt_type_code;
                           p_tax              := gen_bill.get_tax_rate (l_fcit_rec.taty_type_code, p_chk_date) * l_fisp_rec.charge_value;
                           --
                        ELSE
                           --
                           p_error_text := 'get_from_to_special_price missing data - Fixed Charge Item Types record not found!';
                           p_success := FALSE;
                           --
                        END IF;
                        --
                     END IF;
                     --
                  END IF;
                  --
               END IF;
               /* End CHG-6472 */
            ELSE
               /*
                 ** Kui on väljakutse teenuse tasemel (sisendis p_sepa_ref_num NULL),
                 ** siis on mõtet kontrollida erihindu from->to teenuspakettide jaoks.
               */

               -- CHG1634
               -- Otsime kahepoolset hinda
               OPEN c_fisp_two_side_price;

               FETCH c_fisp_two_side_price
                INTO p_fcit_type_code
                    ,p_charge_value
                    ,p_taty_type_code
                    ,p_billing_selector
                    ,p_fcdt_type_code
                    ,p_tax;

               l_found := c_fisp_two_side_price%FOUND;

               CLOSE c_fisp_two_side_price;

               IF (NOT l_found AND p_fixed_term_category IS NOT NULL) THEN
                  -- ei leidnud kahepoolset hinda, otsitakse tähtajalist hinda, siis püüame leida ühepoolset hinda
                  OPEN c_fisp_one_side_price;

                  FETCH c_fisp_one_side_price
                   INTO p_fcit_type_code
                       ,p_charge_value
                       ,p_taty_type_code
                       ,p_billing_selector
                       ,p_fcdt_type_code
                       ,p_tax;

                  CLOSE c_fisp_one_side_price;
               END IF;
            END IF;
         END IF;
      END IF;
   END get_from_to_special_price;

   /*
     ** Global Procedures and Functions
   */
   PROCEDURE once_off_charge (
      p_maac_ref_num           IN      accounts.ref_num%TYPE
     ,p_susg_ref_num           IN      subs_serv_groups.ref_num%TYPE
     ,p_chca_type_code         IN      subs_serv_groups.chca_type_code%TYPE
     ,p_package_type           IN      serv_package_types.type_code%TYPE
     ,p_service_date           IN      DATE
     ,p_sety_ref_num           IN      service_types.ref_num%TYPE
     ,p_sepv_ref_num           IN      service_param_values.ref_num%TYPE
     ,p_run_mode               IN      VARCHAR2   -- Fxxx,BATCH
     ,p_error_text             IN OUT  VARCHAR2   --200  Order System
     ,p_error_type             IN OUT  VARCHAR2   --W-warning/E-error
     ,p_success                IN OUT  BOOLEAN
     ,p_transact_mode          IN      VARCHAR2 DEFAULT 'INS'
     ,p_channel_type           IN      price_lists.channel_type%TYPE DEFAULT NULL
     ,p_par_value_charge       IN      price_lists.par_value_charge%TYPE DEFAULT 'N'
     ,p_count                  IN      NUMBER DEFAULT NULL
     ,p_sepa_ref_num           IN      service_parameters.ref_num%TYPE DEFAULT NULL
     ,p_char_amt               IN      NUMBER DEFAULT NULL   -- UPR-3007
     ,p_secondary_package      IN      serv_package_types.type_code%TYPE DEFAULT NULL   -- CHG-323: sekundaarne pakett maksustamiseks (sõltuvalt teenusest võib olla nii from kui to)
     ,p_secondary_category     IN      package_categories.package_category%TYPE DEFAULT NULL   -- CHG-323: sekundaarse paketi kategooria maksustamiseks (sõltuvalt teenusest võib olla nii from kui to)
     ,p_from_sepv_ref_num      IN      service_param_values.ref_num%TYPE DEFAULT NULL   -- CHG-323: teenusparameetri vana väärtus
     ,p_fixed_term_category    IN      fixed_special_prices.fixed_term_category%TYPE DEFAULT NULL   -- CHG1634
     ,p_fixed_term_length      IN      fixed_special_prices.fixed_term_length%TYPE DEFAULT NULL   -- CHG1634
     ,p_fixed_term_sety        IN      fixed_special_prices.fixed_term_sety%TYPE DEFAULT NULL   -- CHG1634
     ,p_mixed_service          IN      VARCHAR2 DEFAULT NULL -- CHG-5438
     ,p_mixed_packet_code      IN      mixed_packets.packet_code%TYPE DEFAULT NULL -- CHG-5438
     ,p_kw_serv_num            IN      fixed_term_maac_contracts.waiting_serv_num%TYPE DEFAULT NULL -- CHG-5438
     ,p_ebs_order_number       IN fixed_term_contracts.ebs_order_number%TYPE DEFAULT NULL -- CHG-5795
     ,p_additional_entry_text  IN      invoice_entries.additional_entry_text%TYPE DEFAULT NULL -- MOBE-540
     ,p_fcit_type_code         IN      VARCHAR2 DEFAULT NULL -- DOBAS-665
   ) IS
      --
      l_once_off                    VARCHAR2 (1);
      l_prorata                     VARCHAR2 (1);
      l_regular                     VARCHAR2 (1);
      l_inen_ref_num                invoice_entries.ref_num%TYPE;
      l_invo_ref_num                invoices.ref_num%TYPE;
      l_service_date                DATE;
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;   --DOBAS-665
      l_bise                        fixed_charge_item_types.BILLING_SELECTOR%TYPE;  
      l_fcit                        fixed_charge_item_types.TYPE_CODE%TYPE; 
      l_taty                        fixed_charge_item_types.TATY_TYPE_CODE%TYPE; 
      
   
      
   BEGIN
      bcc_proc_name := 'Once_Off_charging';
      l_once_off := 'Y';
      l_prorata := 'N';
      l_regular := 'N';
      l_service_date := TRUNC (p_service_date);
      --
      --DOBAS-665
      l_bise := NULL;  
      l_fcit := NULL; 
      l_taty := NULL;
      IF p_fcit_type_code IS NOT NULL THEN 
         l_fcit_rec := null;
         l_fcit_rec := get_fcit_rec(p_fcit_type_code);
         
         l_bise := l_fcit_rec.BILLING_SELECTOR;  
         l_fcit := l_fcit_rec.TYPE_CODE; 
         l_taty := l_fcit_rec.TATY_TYPE_CODE;
         
      END IF; --DOBAS-665
      --
      fixed_charge_calc
         (p_maac_ref_num
         ,p_susg_ref_num
         ,p_chca_type_code
         ,p_package_type
         ,l_service_date
         ,p_sety_ref_num
         ,p_sepv_ref_num
         ,p_run_mode   -- Fxxx,BATCH
         ,l_once_off
         ,l_prorata
         ,l_regular
         ,p_error_text   --200  Order System
         ,p_error_type   --W-warning/E-error
         ,p_success
         ,l_inen_ref_num
         ,l_invo_ref_num
         ,p_transact_mode
         ,NULL
         ,p_channel_type
         ,p_par_value_charge
         ,p_count
         ,p_sepa_ref_num
         ,p_char_amt   -- UPR-3007
         ,l_bise    --DOBAS665     NULL   -- p_bise              IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
         ,l_fcit    --DOBAS665     NULL   -- p_fcit_type_code    IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
         ,l_taty    --DOBAS665     NULL   -- p_taty_type_code    IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
         ,NULL   -- p_maas_ref_num      IN      master_account_services.ref_num%TYPE DEFAULT NULL   -- CHG-498
         ,p_secondary_package   -- IN     serv_package_types.type_code%TYPE default NULL -- CHG-323: sekundaarne pakett maksustamiseks (sõltuvalt teenusest võib olla nii from kui to)
         ,p_secondary_category  -- IN     package_categories.package_category%TYPE default NULL -- CHG-323: sekundaarse paketi kategooria maksustamiseks (sõltuvalt teenusest võib olla nii from kui to)
         ,p_from_sepv_ref_num   -- IN     service_param_values.ref_num%TYPE default NULL -- CHG-323: teenusparameetri vana väärtus
         ,TRUE
         ,p_fixed_term_category -- IN       fixed_special_prices.fixed_term_category%TYPE
         ,p_fixed_term_length   -- IN       fixed_special_prices.fixed_term_length%TYPE
         ,p_fixed_term_sety     -- IN       fixed_special_prices.fixed_term_sety%TYPE
         ,p_mixed_service       -- IN      VARCHAR2 DEFAULT NULL
         ,p_mixed_packet_code   -- IN      mixed_packets.packet_code%TYPE DEFAULT NULL -- CHG-5438
         ,p_kw_serv_num         -- IN      fixed_term_maac_contracts.waiting_serv_num%TYPE DEFAULT NULL -- CHG-5438
         ,p_ebs_order_number -- IN fixed_term_contracts.ebs_order_number%TYPE DEFAULT NULL -- CHG-5795
         ,p_additional_entry_text  --IN      invoice_entries.additional_entry_text%TYPE DEFAULT NULL -- MOBE-540
         );
   END once_off_charge;

   --
   PROCEDURE cond_fix_charge (
      p_maac_ref_num    IN      accounts.ref_num%TYPE
     ,p_susg_ref_num    IN      subs_serv_groups.ref_num%TYPE
     ,p_chca_type_code  IN      subs_serv_groups.chca_type_code%TYPE
     ,p_package_type    IN      serv_package_types.type_code%TYPE
     ,p_service_date    IN      DATE
     ,p_sety_ref_num    IN      service_types.ref_num%TYPE
     ,p_sepv_ref_num    IN      service_param_values.ref_num%TYPE
     ,p_run_mode        IN      VARCHAR2   -- Fxxx,BATCH
     ,p_error_text      IN OUT  VARCHAR2   --200  Order System
     ,p_error_type      IN OUT  VARCHAR2   --W-warning/E-error
     ,p_success         IN OUT  BOOLEAN
     ,p_inen_ref_num    OUT     invoice_entries.ref_num%TYPE
     ,p_invo_ref_num    OUT     invoices.ref_num%TYPE   -- UPR-2794
     ,p_char_amt        IN      NUMBER   -- UPR-2794
     ,p_bise            IN      VARCHAR2   -- UPR-2794
     ,p_fcit_type_code  IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
     ,p_taty_type_code  IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
     ,p_transact_mode   IN      VARCHAR2 DEFAULT 'INS'   -- UPR-2794
     ,p_open_salp_end   IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
   ) IS
      --
      l_once_off                    VARCHAR2 (1);
      l_prorata                     VARCHAR2 (1);
      l_regular                     VARCHAR2 (1);
      l_service_date                DATE;
   BEGIN
      bcc_proc_name := 'Conditional_charging';
      l_once_off := 'N';
      l_prorata := 'N';
      l_regular := 'N';
      l_service_date := TRUNC (p_service_date);
      --
      fixed_charge_calc (p_maac_ref_num
                        ,p_susg_ref_num
                        ,p_chca_type_code
                        ,p_package_type
                        ,l_service_date
                        ,p_sety_ref_num
                        ,p_sepv_ref_num
                        ,p_run_mode   -- Fxxx,BATCH
                        ,l_once_off
                        ,l_prorata
                        ,l_regular
                        ,p_error_text   --200  Order System
                        ,p_error_type   --W-warning/E-error
                        ,p_success
                        ,p_inen_ref_num   -- out
                        ,p_invo_ref_num   -- out
                        ,p_transact_mode
                        ,p_open_salp_end   -- p_order_date     IN DATE DEFAULT NULL,
                        ,NULL   -- p_channel_type     IN Price_Lists.channel_type%TYPE DEFAULT NULL,
                        ,'N'   -- p_par_value_charge IN Price_Lists.par_value_charge%TYPE DEFAULT 'N',
                        ,NULL   -- p_count            IN NUMBER DEFAULT null,
                        ,NULL   -- p_sepa_ref_num     IN service_parameters.ref_num%TYPE DEFAULT NULL
                        ,p_char_amt   -- UPR-2794
                        ,p_bise   -- UPR-2794
                        ,p_fcit_type_code   -- UPR-2794
                        ,p_taty_type_code   -- UPR-2794
                        );
   END cond_fix_charge;

   --------------------------------------------
   PROCEDURE fixed_charge_calc (
      p_maac_ref_num           IN      accounts.ref_num%TYPE
     ,p_susg_ref_num           IN      subs_serv_groups.ref_num%TYPE
     ,p_chca_type_code         IN      subs_serv_groups.chca_type_code%TYPE
     ,p_package_type           IN      serv_package_types.type_code%TYPE
     ,p_service_date           IN      DATE
     ,p_sety_ref_num           IN      service_types.ref_num%TYPE
     ,p_sepv_ref_num           IN      service_param_values.ref_num%TYPE
     ,p_run_mode               IN      VARCHAR2   -- Fxxx,BATCH
     ,p_once_off               IN      VARCHAR2
     ,p_prorata                IN      VARCHAR2
     ,p_regular                IN      VARCHAR2
     ,p_error_text             IN OUT  VARCHAR2   --200  Order System
     ,p_error_type             IN OUT  VARCHAR2   --W-warning/E-error
     ,p_success                IN OUT  BOOLEAN
     ,p_inen_ref_num           OUT     invoice_entries.ref_num%TYPE
     ,p_invo_ref_num           OUT     invoices.ref_num%TYPE   -- UPR-2794
     ,p_transact_mode          IN      VARCHAR2 DEFAULT 'INS'
     ,p_order_date             IN      DATE DEFAULT NULL
     ,p_channel_type           IN      price_lists.channel_type%TYPE DEFAULT NULL
     ,p_par_value_charge       IN      price_lists.par_value_charge%TYPE DEFAULT 'N'
     ,p_count                  IN      NUMBER DEFAULT NULL
     ,p_sepa_ref_num           IN      service_parameters.ref_num%TYPE DEFAULT NULL
     ,p_char_amt               IN      NUMBER DEFAULT NULL   -- UPR-2794
     ,p_bise                   IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
     ,p_fcit_type_code         IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
     ,p_taty_type_code         IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
     ,p_maas_ref_num           IN      master_account_services.ref_num%TYPE DEFAULT NULL   -- CHG-498
     ,p_secondary_package      IN      serv_package_types.type_code%TYPE DEFAULT NULL   -- CHG-323: sekundaarne pakett maksustamiseks (sõltuvalt teenusest võib olla nii from kui to)
     ,p_secondary_category     IN      package_categories.package_category%TYPE DEFAULT NULL   -- CHG-323: sekundaarse paketi kategooria maksustamiseks (sõltuvalt teenusest võib olla nii from kui to)
     ,p_from_sepv_ref_num      IN      service_param_values.ref_num%TYPE DEFAULT NULL   -- CHG-323: teenusparameetri vana väärtus
     ,p_check_pricelist        IN      BOOLEAN DEFAULT TRUE   -- CHG-3180
     ,p_fixed_term_category    IN      fixed_special_prices.fixed_term_category%TYPE DEFAULT NULL   -- CHG1634
     ,p_fixed_term_length      IN      fixed_special_prices.fixed_term_length%TYPE DEFAULT NULL   -- CHG1634
     ,p_fixed_term_sety        IN      fixed_special_prices.fixed_term_sety%TYPE DEFAULT NULL   -- CHG1634
     ,p_mixed_service          IN      VARCHAR2 DEFAULT NULL -- CHG-5438
     ,p_mixed_packet_code      IN      mixed_packets.packet_code%TYPE DEFAULT NULL -- CHG-5438
     ,p_kw_serv_num            IN      fixed_term_maac_contracts.waiting_serv_num%TYPE DEFAULT NULL -- CHG-5438
     ,p_ebs_order_number       IN      fixed_term_contracts.ebs_order_number%TYPE DEFAULT NULL -- CHG-5795
     ,p_additional_entry_text  IN      invoice_entries.additional_entry_text%TYPE DEFAULT NULL -- MOBE-540
   ) IS
      --
      CURSOR c_service_type (
         p_sety_ref  IN  NUMBER
      ) IS
         SELECT *   -- CHG-3516: type_code
           FROM service_types
          WHERE ref_num = p_sety_ref
      ;
      -- CHG-5186
      CURSOR c_sept_mark IS
         SELECT special_mark
         FROM serv_package_types
         WHERE type_code = p_package_type
      ;
      --
      fcit_not_exists               EXCEPTION;
      not_exists_master             EXCEPTION;
      master_closed                 EXCEPTION;
      invo_dup_val                  EXCEPTION;
      invo_create_error             EXCEPTION;
      create_enrty_error            EXCEPTION;
      l_master_date                 DATE := NULL;
      l_maac_invo_ref               invoices.ref_num%TYPE := NULL;
      l_inen_ref_num                invoice_entries.ref_num%TYPE;
      l_master_status               account_statuses.acst_code%TYPE;
      l_err_ref_num                 NUMBER := NULL;
      l_count                       NUMBER := NULL;
      l_sety_rec                    service_types%ROWTYPE;   -- CHG-3516
      l_service_type                service_types.type_code%TYPE;
      l_sept_special_mark           serv_package_types.special_mark%TYPE; -- CHG-5186
   --
   BEGIN
      --dbms_output.put_line('Starting Fixed Charge calculation.');
      --
      l_master_status := NULL;
      l_master_status := get_master_status (p_maac_ref_num);

      /*
        ** CHG-3516: Get SETY record and check if service is OnceOff - if Yes,
        **    then no need to check M/A status. OnceOff services can be ordered
        **    to closed M/A.
      */
      IF p_sety_ref_num IS NOT NULL THEN
         OPEN c_service_type (p_sety_ref_num);

         FETCH c_service_type
          INTO l_sety_rec;

         CLOSE c_service_type;

         --
         l_service_type := l_sety_rec.type_code;
      END IF;

      IF NVL (l_sety_rec.secl_class_code, '*') NOT IN ('O', 'Q') THEN   -- CHG-3516
         --
         IF l_master_status IS NULL THEN
            RAISE not_exists_master;
         END IF;

         --dbms_output.put_line('M/A='||to_char(p_maac_ref_num));
         IF l_master_status NOT IN ('AC') THEN
            RAISE master_closed;
         END IF;
      --
      END IF;

      --dbms_output.put_line('M/A staatus='||l_master_status);
      -- Get service type

      --dbms_output.put_line('SERV='||l_service_type);
      -- Fixed Charge exists
      IF p_char_amt IS NULL THEN   -- UPR-2794
         -- CHG-5186: Get SEPT special mark
         OPEN  c_sept_mark;
         FETCH c_sept_mark INTO l_sept_special_mark;
         CLOSE c_sept_mark;
         
         -- CHG-5438: Added mixed packet code and MFXTR logic
         IF (l_sety_rec.service_name = Or_Common.fixtr_service_name AND
             ( Nvl(l_sept_special_mark, '*?*') = 'PAK' OR p_mixed_packet_code IS NOT NULL)
            )
            OR
            (l_sety_rec.service_name = Or_Common.mfxtr_service_name AND
             p_mixed_packet_code IS NOT NULL)
         THEN
            --
            NULL;
            --
         ELSE
            --
            IF NOT check_fixed_charge (p_chca_type_code
                                      ,p_package_type
                                      ,p_service_date
                                      ,p_sety_ref_num
                                      ,p_once_off
                                      ,p_prorata
                                      ,p_regular
                                      ) THEN
               RAISE fcit_not_exists;
            END IF;
            --
         END IF;
      END IF;

      --dbms_output.put_line('F/C exists');
      -- Create or Select Invoice
      l_count := 0;
      p_success := TRUE;
      l_maac_invo_ref := NULL;

      /*
        ** UPR-2794: Kui on arverealt kustutamine ehk mode = DEL, siis uut arvet looma küll ei peaks -
        **           vastav parameeter peaks olema FALSE.
        **           Kui kustutatakse ette antud summaga (semafor = N+N+N) kirjet, siis alati
        **           otsitakse 1.-sele avatud perioodile vastavat INB arvet.
      */
      IF p_transact_mode = 'DEL' THEN
         IF p_char_amt IS NOT NULL THEN
            l_maac_invo_ref :=
               open_invoice.get_billing_invoice_ref_num (p_maac_ref_num
                                                        ,'INB'
                                                        ,p_order_date   -- 1.-se avatud perioodi lõpp antud juhul
                                                        );
         ELSE
            l_maac_invo_ref := open_invoice.get_open_invo (p_maac_ref_num, p_service_date, FALSE);
         END IF;
      ELSE
         l_maac_invo_ref := open_invoice.get_open_invo (p_maac_ref_num, p_service_date, TRUE);
      END IF;

      /* END UPR-2794 */
      --dbms_output.put_line('invoice '||to_char(l_maac_invo_ref));
      IF l_maac_invo_ref IS NULL THEN
         RAISE master_closed;
      END IF;
      
      --DOBAS-243  Kui koondarve on INI, staatusega, siis muudame selle AC-ks. Arve päis on juba olemas !
      IF l_master_status = 'INI' THEN
         Chg_INI_maac_to_AC(p_maac_ref_num,l_master_status, nvl(p_service_date,sysdate));   
      END IF;

      --dbms_output.put_line('INVO_REF='||to_char(l_maac_invo_ref));
      -- Create Entry
      create_invoice_entry
         (l_maac_invo_ref
         ,p_susg_ref_num
         ,p_sety_ref_num
         ,p_sepv_ref_num
         ,p_package_type
         ,p_chca_type_code
         ,p_service_date
         ,p_once_off
         ,p_prorata
         ,p_regular
         ,p_run_mode
         ,p_error_text
         ,p_error_type
         ,p_success
         ,l_inen_ref_num
         ,p_transact_mode
         ,p_order_date   -- praegu ei kasutata
         ,p_channel_type
         ,p_par_value_charge
         ,p_maac_ref_num
         ,p_count
         ,p_sepa_ref_num
         ,p_char_amt
         ,p_bise
         ,p_fcit_type_code
         ,p_taty_type_code
         ,p_maas_ref_num   -- master_account_services.ref_num%TYPE DEFAULT NULL -- CHG-498
         ,p_secondary_package   -- IN     serv_package_types.type_code%TYPE default NULL -- CHG-323: sekundaarne pakett maksustamiseks (sõltuvalt teenusest võib olla nii from kui to)
         ,p_secondary_category   -- IN     package_categories.package_category%TYPE default NULL -- CHG-323: sekundaarse paketi kategooria maksustamiseks (sõltuvalt teenusest võib olla nii from kui to)
         ,p_from_sepv_ref_num   -- IN     service_param_values.ref_num%TYPE default NULL -- CHG-323: teenusparameetri vana väärtus
         ,p_check_pricelist     -- IN     BOOLEAN DEFAULT TRUE   CHG-3180
         ,p_fixed_term_category   -- IN       fixed_special_prices.fixed_term_category%TYPE
         ,p_fixed_term_length   -- IN       fixed_special_prices.fixed_term_length%TYPE
         ,p_fixed_term_sety     -- IN       fixed_special_prices.fixed_term_sety%TYPE
         ,p_mixed_service       -- IN      VARCHAR2 DEFAULT NULL -- CHG-5438
         ,p_mixed_packet_code   -- IN      mixed_packets.packet_code%TYPE DEFAULT NULL CHG-5438
         ,p_kw_serv_num         -- IN      fixed_term_maac_contracts.waiting_serv_num%TYPE DEFAULT NULL -- CHG-5438
         ,p_ebs_order_number -- IN fixed_term_contracts.ebs_order_number%TYPE DEFAULT NULL -- CHG-5795
         ,p_additional_entry_text -- IN      invoice_entries.additional_entry_text%TYPE DEFAULT NULL -- MOBE-540
         );

      IF p_success = FALSE THEN
         RAISE create_enrty_error;
      END IF;

      -- OK!
      p_error_text := '';
      p_error_type := '';
      p_success := TRUE;
      p_inen_ref_num := l_inen_ref_num;
      p_invo_ref_num := l_maac_invo_ref;   -- UPR-2794
   --
   EXCEPTION
      WHEN fcit_not_exists THEN
         p_success := FALSE;
         p_error_type := 'W';
         p_error_text :=    bcc_proc_name
                         || ':'
                         || 'Fixed Charge Value not exists:'
                         || 'CHCA='
                         || p_chca_type_code
                         || ',PKG='
                         || p_package_type
                         || 'SERV='
                         || l_service_type;

         IF UPPER (p_run_mode) = 'BATCH' THEN
            put_batch_message (bcc_sql_values, bcc_module_ref, p_error_text);
            p_error_type := 'E';
         END IF;
      --Fixed Charge has NOT been added. Value not exist.
      WHEN not_exists_master THEN
         p_success := FALSE;
         p_error_type := 'E';
         p_error_text := bcc_proc_name || ':' || 'M/A ' || TO_CHAR (p_maac_ref_num) || 'not created yet in TBCIS';

         IF UPPER (p_run_mode) = 'BATCH' THEN
            put_batch_message (bcc_sql_values, bcc_module_ref, p_error_text);
         END IF;
      -- Master Account not created yet in TBCIS
      WHEN master_closed THEN
         p_success := FALSE;
         p_error_type := 'E';
         p_error_text :=    bcc_proc_name
                         || ':'
                         || 'M/A '
                         || TO_CHAR (p_maac_ref_num)
                         || ' closed already. Not allowed create the invoice';

         IF UPPER (p_run_mode) = 'BATCH' THEN
            put_batch_message (bcc_sql_values, bcc_module_ref, p_error_text);
         END IF;
      -- Master Account closed already. Not allowed create the invoice
      WHEN invo_create_error THEN
         p_success := FALSE;
         p_error_text :=    bcc_proc_name
                         || ': '
                         || 'M/A '
                         || TO_CHAR (p_maac_ref_num)
                         || ': Unable to get/create billing invoice.';
         p_error_type := 'E';

         IF UPPER (p_run_mode) = 'BATCH' THEN
            put_batch_message (bcc_sql_err, bcc_module_ref, p_error_text);
         END IF;
      WHEN invo_dup_val THEN
         p_success := FALSE;
         p_error_type := 'E';
         p_error_text := bcc_proc_name || ':M/A ' || TO_CHAR (p_maac_ref_num)
                         || ' Create invoice-Dup_Val_On_Index error';

         IF UPPER (p_run_mode) = 'BATCH' THEN
            put_batch_message (bcc_sql_err, bcc_module_ref, p_error_text);
         END IF;
      WHEN create_enrty_error THEN
         p_success := FALSE;
         p_error_type := 'E';

         IF UPPER (p_run_mode) = 'BATCH' THEN
            put_batch_message (bcc_sql_err, bcc_module_ref, p_error_text);
         END IF;
   END fixed_charge_calc;
   
   ----------------------------------------------------------------------------
   --DOBAS-243
   --Description : Check Master Account status. If this is INI then insert AC status for this Master Account.
   PROCEDURE Chg_INI_Maac_to_AC (p_maac_ref_num   IN  accounts.ref_num%TYPE
                                ,p_master_status  IN  account_statuses.acst_code%type
                                ,p_date     IN  DATE 
                                ) IS

   l_end_date          account_statuses.end_date%type;

   BEGIN

      --
      IF p_master_status = 'INI' THEN
         l_end_date := p_date - c_one_second;
         --
         UPDATE account_statuses
            SET end_date = l_end_date
         WHERE  acco_ref_num = p_maac_ref_num 
           AND  end_date is null
           AND  acst_code = 'INI' ;
         --
         INSERT INTO account_statuses (
             acco_ref_num
            ,acst_code
            ,start_date
            ,notes
            )
         VALUES (
             p_maac_ref_num
            ,'AC'
            ,p_date
            ,'Generated by CALCULATE_FIXED_CHARGES.Chg_INI_Maac_to_AC '
            );
      END IF;

   END Chg_INI_Maac_to_AC;

   ----------------------------------------------------------------------------
   FUNCTION check_fixed_charge (
      p_chca_type_code  IN  subs_serv_groups.chca_type_code%TYPE
     ,p_package_type    IN  serv_package_types.type_code%TYPE
     ,p_service_date    IN  DATE
     ,p_sety_ref_num    IN  service_types.ref_num%TYPE
     ,p_once_off        IN  fixed_charge_item_types.once_off%TYPE
     ,p_prorata         IN  fixed_charge_item_types.pro_rata%TYPE
     ,p_regular         IN  fixed_charge_item_types.regular_charge%TYPE
   )
      RETURN BOOLEAN IS
      CURSOR c_charge_exists IS
         SELECT 'Y'
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit
          WHERE p_service_date BETWEEN ficv.start_date AND NVL (ficv.end_date, p_service_date)
            AND NVL (ficv.sety_ref_num, 0) = NVL (p_sety_ref_num, 0)
            AND (   (ficv.sept_type_code = p_package_type AND ficv.chca_type_code IS NULL)
                 OR (ficv.chca_type_code = p_chca_type_code AND ficv.sept_type_code IS NULL)
                )
            AND ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = p_once_off
            AND fcit.regular_charge = p_regular
            AND fcit.pro_rata = p_prorata;

      --
      CURSOR c_charge_prli_exists (
         cp_package_category  IN  VARCHAR2
        ,cp_nety_type_code    IN  VARCHAR2
      ) IS
         SELECT 'Y'
           FROM price_lists prli, fixed_charge_item_types fcit
          WHERE p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date)
            AND NVL (prli.sety_ref_num, 0) = NVL (p_sety_ref_num, 0)
            AND NVL (prli.package_category, '*') = NVL (cp_package_category, '*')
            AND NVL (prli.nety_type_code, '*') = NVL (cp_nety_type_code, '*')
            AND NVL (prli.sety_ref_num, 0) = NVL (fcit.sety_ref_num, 0)
            AND NVL (prli.package_category, '*') = NVL (fcit.prli_package_category, '*')
            AND fcit.once_off = p_once_off
            AND fcit.regular_charge = p_regular
            AND fcit.pro_rata = p_prorata
            AND prli.once_off = p_once_off
            AND prli.regular_charge = p_regular
            AND prli.pro_rata = p_prorata;

      --
      CURSOR c_category IS
         SELECT CATEGORY
               ,nety_type_code
           FROM serv_package_types
          WHERE type_code = p_package_type;

      --
      l_package_category            serv_package_types.CATEGORY%TYPE := NULL;
      l_nety_type_code              serv_package_types.nety_type_code%TYPE := NULL;
      l_dummy                       VARCHAR2 (1) := 'N';
   BEGIN
      --dbms_output.put_line('Checking Fixed Charge for chca = ' || p_chca_type_code || ', package = ' || p_package_type ||
      --                      ',sety ref = ' || to_char(p_sety_ref_num));
      OPEN c_charge_exists;

      FETCH c_charge_exists
       INTO l_dummy;

      CLOSE c_charge_exists;

      IF l_dummy = 'Y' THEN
         --dbms_output.put_line('Fixed Charge exists.');
         RETURN TRUE;
      END IF;

      IF p_sety_ref_num IS NULL THEN
         OPEN c_category;

         FETCH c_category
          INTO l_package_category
              ,l_nety_type_code;

         CLOSE c_category;
      END IF;

      --dbms_output.put_line('otsin prices'||l_package_category||l_nety_type_code||to_char(p_sety_ref_num));
      OPEN c_charge_prli_exists (l_package_category, l_nety_type_code);

      FETCH c_charge_prli_exists
       INTO l_dummy;

      CLOSE c_charge_prli_exists;

      IF l_dummy = 'Y' THEN
         --dbms_output.put_line('leidsin prisest');
         RETURN TRUE;
      END IF;

      --dbms_output.put_line('ei leidnud');
      RETURN FALSE;
   END;

   ------------------------------------------------------------------
   FUNCTION get_master_first_date (
      p_ref_num  IN  NUMBER
   )
      RETURN DATE IS
      CURSOR c_acco (
         cp_ref_num  NUMBER
      ) IS
         SELECT MIN (start_date)
           FROM account_statuses
          WHERE acco_ref_num = cp_ref_num;

      l_first_start_date            DATE;
   BEGIN
      OPEN c_acco (p_ref_num);

      FETCH c_acco
       INTO l_first_start_date;

      CLOSE c_acco;

      RETURN l_first_start_date;
   END;

   ------------------------------------------------------------------
   FUNCTION get_master_status (
      p_ref_num  IN  NUMBER
   )
      RETURN VARCHAR2 IS
      CURSOR c_acco (
         cp_ref_num  NUMBER
      ) IS
         SELECT acst_code
           FROM account_statuses
          WHERE acco_ref_num = cp_ref_num AND end_date IS NULL;

      l_status                      account_statuses.acst_code%TYPE;
   BEGIN
      OPEN c_acco (p_ref_num);

      FETCH c_acco
       INTO l_status;

      CLOSE c_acco;

      RETURN l_status;
   END;

   ---------------------------
   FUNCTION exist_chargeable_maac_serv (
      p_maac_ref_num  NUMBER
     ,p_start_date    DATE
     ,p_end_date      DATE
     ,p_fcit_type     VARCHAR2 DEFAULT 'MCH'
   )
      RETURN BOOLEAN IS
      CURSOR c (
         cp_maac_ref_num  NUMBER
        ,cp_start_date    DATE
        ,cp_end_date      DATE
      ) IS
         SELECT COUNT (*)
           FROM master_account_services maas
          WHERE maas.maac_ref_num = cp_maac_ref_num
            AND maas.start_date <= cp_end_date
            AND NVL (maas.end_date, cp_end_date) >= cp_start_date
            AND EXISTS (SELECT 1
                          FROM tbcis.emt_bill_price_list a
                         WHERE a.sety_ref_num = maas.sety_ref_num
                           AND a.what = 'Konto teenused'
                           AND a.start_date <= cp_end_date
                           AND NVL (a.end_date, cp_end_date) >= cp_start_date
                           AND a.chargeable = 'Y'
                           AND a.fcty_type = p_fcit_type
                           AND ROWNUM = 1);

      l_count                       NUMBER;
      l_found                       BOOLEAN;
   BEGIN
      OPEN c (p_maac_ref_num, p_start_date, p_end_date);

      FETCH c
       INTO l_count;

      CLOSE c;

      IF l_count = 0 THEN
         l_found := FALSE;
      ELSE
         l_found := TRUE;
      END IF;

      RETURN l_found;
   END exist_chargeable_maac_serv;

   ---------------------------------------------------------------------------------------
   FUNCTION exist_fixed_charge_for_sety (
      p_service_start_date  IN  DATE
     ,p_service_end_date    IN  DATE
     ,p_sety_ref_num        IN  service_types.ref_num%TYPE
     ,p_once_off            IN  fixed_charge_item_types.once_off%TYPE
     ,p_prorata             IN  fixed_charge_item_types.pro_rata%TYPE
     ,p_regular             IN  fixed_charge_item_types.regular_charge%TYPE
   )
      RETURN BOOLEAN IS
      -- erihinnad
      CURSOR c_charge_exists IS
         SELECT 'Y'
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit
          WHERE ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = p_once_off
            AND fcit.regular_charge = p_regular
            AND fcit.pro_rata = p_prorata
            AND ficv.start_date <= p_service_end_date
            AND NVL (ficv.end_date, p_service_end_date) >= p_service_start_date
            AND ficv.sety_ref_num = p_sety_ref_num
            AND NVL (fcit.sety_ref_num, ficv.sety_ref_num) = ficv.sety_ref_num
            AND ficv.charge_value > 0;

      CURSOR c_charge_prli_exists IS
         SELECT 'Y'
           FROM price_lists prli, fixed_charge_item_types fcit
          WHERE prli.once_off = 'N'
            AND prli.pro_rata = 'Y'
            AND prli.regular_charge = 'Y'
            AND fcit.once_off = prli.once_off
            AND fcit.pro_rata = prli.pro_rata
            AND fcit.regular_charge = prli.regular_charge
            AND prli.package_category IS NULL
            AND fcit.package_category IS NULL
            AND prli.sety_ref_num = fcit.sety_ref_num
            AND prli.sety_ref_num = p_sety_ref_num
            AND fcit.ARCHIVE = 'N'
            AND start_date <= p_service_end_date
            AND NVL (end_date, p_service_end_date) >= p_service_start_date
            AND prli.charge_value > 0;

      l_dummy                       VARCHAR2 (1);
      fixed_charge_exists           EXCEPTION;
   BEGIN
      -- ** erihindades eksisteerib ? ***
      OPEN c_charge_exists;

      FETCH c_charge_exists
       INTO l_dummy;

      CLOSE c_charge_exists;

      IF l_dummy = 'Y' THEN
         RAISE fixed_charge_exists;
      END IF;

      -- ** kui ei eksisteeri erihindades , kas eksisteerib hinnakirjas ? **
      OPEN c_charge_prli_exists;

      FETCH c_charge_prli_exists
       INTO l_dummy;

      CLOSE c_charge_prli_exists;

      IF l_dummy = 'Y' THEN
         RAISE fixed_charge_exists;
      END IF;

      RETURN FALSE;
   EXCEPTION
      WHEN fixed_charge_exists THEN
         RETURN TRUE;
      WHEN OTHERS THEN
         RETURN FALSE;
   END exist_fixed_charge_for_sety;

   ------------------------------
   PROCEDURE create_invoice_entry (
      p_invo_ref_num           IN      NUMBER
     ,p_susg_ref_num           IN      NUMBER
     ,p_sety_ref_num           IN      NUMBER
     ,p_sepv_ref_num           IN      NUMBER
     ,p_package_type           IN      VARCHAR2
     ,p_chca_type_code         IN      VARCHAR2
     ,p_service_date           IN      DATE
     ,p_once_off               IN      VARCHAR2
     ,p_prorata                IN      VARCHAR2
     ,p_regular                IN      VARCHAR2
     ,p_run_mode               IN      VARCHAR2
     ,p_error_text             IN OUT  VARCHAR2
     ,p_error_type             IN OUT  VARCHAR2
     ,p_success                IN OUT  BOOLEAN
     ,p_inen_ref_num           OUT     invoice_entries.ref_num%TYPE
     ,p_transact_mode          IN      VARCHAR2 DEFAULT 'INS'
     ,p_order_date             IN      DATE DEFAULT NULL
     ,p_channel_type           IN      price_lists.channel_type%TYPE DEFAULT NULL
     ,p_par_value_charge       IN      price_lists.par_value_charge%TYPE DEFAULT 'N'
     ,p_maac_ref_num           IN      accounts.ref_num%TYPE DEFAULT NULL
     ,p_count                  IN      NUMBER DEFAULT NULL
     ,p_sepa_ref_num           IN      service_parameters.ref_num%TYPE DEFAULT NULL
     ,p_char_amt               IN      NUMBER DEFAULT NULL   -- UPR-2794
     ,p_bise                   IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
     ,p_fcit_type_code         IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
     ,p_taty_type_code         IN      VARCHAR2 DEFAULT NULL   -- UPR-2794
     ,p_maas_ref_num           IN      master_account_services.ref_num%TYPE DEFAULT NULL   -- CHG-71
     ,p_secondary_package      IN      serv_package_types.type_code%TYPE DEFAULT NULL   -- CHG-323: sekundaarne pakett maksustamiseks (sõltuvalt teenusest võib olla nii from kui to)
     ,p_secondary_category     IN      package_categories.package_category%TYPE DEFAULT NULL   -- CHG-323: sekundaarse paketi kategooria maksustamiseks (sõltuvalt teenusest võib olla nii from kui to)
     ,p_from_sepv_ref_num      IN      service_param_values.ref_num%TYPE DEFAULT NULL   -- CHG-323: teenusparameetri vana väärtus
     ,p_check_pricelist        IN      BOOLEAN DEFAULT TRUE   -- CHG-3180: erijuhtudel pole vaja pricelisti sisse minna
     ,p_fixed_term_category    IN      fixed_special_prices.fixed_term_category%TYPE DEFAULT NULL
     ,p_fixed_term_length      IN      fixed_special_prices.fixed_term_length%TYPE DEFAULT NULL
     ,p_fixed_term_sety        IN      fixed_special_prices.fixed_term_sety%TYPE DEFAULT NULL
     ,p_mixed_service          IN      VARCHAR2 DEFAULT NULL -- CHG-5438
     ,p_mixed_packet_code      IN      mixed_packets.packet_code%TYPE DEFAULT NULL -- CHG-5438
     ,p_kw_serv_num            IN      fixed_term_maac_contracts.waiting_serv_num%TYPE DEFAULT NULL -- CHG-5438
     ,p_ebs_order_number       IN      fixed_term_contracts.ebs_order_number%TYPE DEFAULT NULL -- CHG-5795
     ,p_additional_entry_text  IN      invoice_entries.additional_entry_text%TYPE DEFAULT NULL -- MOBE-540
   ) IS
      -------------------------------------------------------
      -- Modified by  T.Hipeli   20.03.2001  UPR 1991
      -- Kutsuda välja- NB!Pärast makse kirjutamist arve reale!- soodustuse arvutamiseks
      -- (juhul kui makse on > 0) protseduur Calculate_Discounts.Find_OO_Conn_Discounts.
      -- lisatuid p_maac_ref_num
      -------------------------------------------------------
        --HELVE-hinna leidmise kursorid:
      CURSOR c_values_chan_sety_value IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,ficv.charge_value charge_value
               , (ficv.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit, tax_rates tara
          WHERE ficv.sety_ref_num = p_sety_ref_num
            AND (   (ficv.sept_type_code = p_package_type AND ficv.chca_type_code IS NULL)
                 OR (ficv.chca_type_code = p_chca_type_code AND ficv.sept_type_code IS NULL)
                )
            AND ficv.channel_type = p_channel_type
            AND ficv.sepa_ref_num = p_sepa_ref_num
            AND NVL (ficv.sepv_ref_num, 0) = NVL (p_sepv_ref_num, 0)
            AND NVL (ficv.par_value_charge, 'N') = NVL (p_par_value_charge, 'N')
            AND ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN ficv.start_date AND NVL (ficv.end_date, p_service_date);

      --
      CURSOR c_values_chan_sety IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,ficv.charge_value charge_value
               , (ficv.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit, tax_rates tara
          WHERE ficv.sety_ref_num = p_sety_ref_num
            AND (   (ficv.sept_type_code = p_package_type AND ficv.chca_type_code IS NULL)
                 OR (ficv.chca_type_code = p_chca_type_code AND ficv.sept_type_code IS NULL)
                )
            AND ficv.channel_type = p_channel_type
            AND ficv.sepv_ref_num IS NULL
            AND ficv.par_value_charge IS NULL
            AND ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN ficv.start_date AND NVL (ficv.end_date, p_service_date);

      --
      CURSOR c_prices_chan_cat_sety_values (
         cp_package_category  IN  VARCHAR2
        ,cp_nety_type_code    IN  VARCHAR2
      ) IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               , (prli.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM price_lists prli, fixed_charge_item_types fcit, tax_rates tara
          WHERE prli.sety_ref_num = p_sety_ref_num
            AND prli.package_category = cp_package_category
            AND prli.nety_type_code = cp_nety_type_code
            AND prli.channel_type = p_channel_type
            AND prli.sepa_ref_num = p_sepa_ref_num
            AND NVL (prli.sepv_ref_num, 0) = NVL (p_sepv_ref_num, 0)
            AND NVL (prli.par_value_charge, 'N') = NVL (p_par_value_charge, 'N')
            AND prli.once_off = p_once_off
            AND prli.pro_rata = p_prorata
            AND prli.regular_charge = p_regular
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND prli.sety_ref_num = fcit.sety_ref_num
            AND (fcit.package_category = cp_package_category OR fcit.package_category IS NULL)
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date);

      --
      CURSOR c_prices_chan_cat_sety (
         cp_package_category  IN  VARCHAR2
        ,cp_nety_type_code    IN  VARCHAR2
      ) IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               , (prli.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM price_lists prli, fixed_charge_item_types fcit, tax_rates tara
          WHERE prli.sety_ref_num = p_sety_ref_num
            AND prli.package_category = cp_package_category
            AND prli.nety_type_code = cp_nety_type_code
            AND prli.channel_type = p_channel_type
            AND prli.sepv_ref_num IS NULL
            AND prli.par_value_charge IS NULL
            AND prli.once_off = p_once_off
            AND prli.pro_rata = p_prorata
            AND prli.regular_charge = p_regular
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND prli.sety_ref_num = fcit.sety_ref_num
            AND (fcit.package_category = cp_package_category OR fcit.package_category IS NULL)
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date);

      --
      CURSOR c_prices_chan_sety_values (
         cp_package_category  IN  VARCHAR2
      ) IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               , (prli.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM price_lists prli, fixed_charge_item_types fcit, tax_rates tara
          WHERE prli.sety_ref_num = p_sety_ref_num
            AND prli.package_category IS NULL
            AND prli.channel_type = p_channel_type
            AND prli.sepa_ref_num = p_sepa_ref_num
            AND NVL (prli.sepv_ref_num, 0) = NVL (p_sepv_ref_num, 0)
            AND NVL (prli.par_value_charge, 'N') = NVL (p_par_value_charge, 'N')
            AND prli.once_off = p_once_off
            AND prli.pro_rata = p_prorata
            AND prli.regular_charge = p_regular
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND prli.sety_ref_num = fcit.sety_ref_num
            AND (fcit.package_category = cp_package_category OR fcit.package_category IS NULL)
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date);

      --
      CURSOR c_prices_chan_sety (
         cp_package_category  IN  VARCHAR2
      ) IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               , (prli.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM price_lists prli, fixed_charge_item_types fcit, tax_rates tara
          WHERE prli.sety_ref_num = p_sety_ref_num
            AND prli.package_category IS NULL
            AND prli.channel_type = p_channel_type
            AND prli.sepv_ref_num IS NULL
            AND prli.par_value_charge IS NULL
            AND prli.once_off = p_once_off
            AND prli.pro_rata = p_prorata
            AND prli.regular_charge = p_regular
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND prli.sety_ref_num = fcit.sety_ref_num
            AND (fcit.package_category = cp_package_category OR fcit.package_category IS NULL)
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date);

      --
      CURSOR c_values_sety_value IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,ficv.charge_value charge_value
               , (ficv.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit, tax_rates tara
          WHERE ficv.sety_ref_num = p_sety_ref_num
            AND (   (ficv.sept_type_code = p_package_type AND ficv.chca_type_code IS NULL)
                 OR (ficv.chca_type_code = p_chca_type_code AND ficv.sept_type_code IS NULL)
                )
            AND ficv.channel_type IS NULL
            AND ficv.sepa_ref_num = p_sepa_ref_num
            AND NVL (ficv.sepv_ref_num, 0) = NVL (p_sepv_ref_num, 0)
            AND NVL (ficv.par_value_charge, 'N') = NVL (p_par_value_charge, 'N')
            AND ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN ficv.start_date AND NVL (ficv.end_date, p_service_date);

      --
      CURSOR c_values_sety IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,ficv.charge_value charge_value
               , (ficv.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit, tax_rates tara
          WHERE ficv.sety_ref_num = p_sety_ref_num
            AND (   (ficv.sept_type_code = p_package_type AND ficv.chca_type_code IS NULL)
                 OR (ficv.chca_type_code = p_chca_type_code AND ficv.sept_type_code IS NULL)
                )
            AND ficv.channel_type IS NULL
            AND ficv.sepv_ref_num IS NULL
            AND ficv.par_value_charge IS NULL
            AND ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN ficv.start_date AND NVL (ficv.end_date, p_service_date);

      --
      CURSOR c_prices_cat_sety_values (
         cp_package_category  IN  VARCHAR2
        ,cp_nety_type_code    IN  VARCHAR2
      ) IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               , (prli.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM price_lists prli, fixed_charge_item_types fcit, tax_rates tara
          WHERE prli.sety_ref_num = p_sety_ref_num
            AND prli.package_category = cp_package_category
            AND prli.nety_type_code = cp_nety_type_code
            AND prli.channel_type IS NULL
            AND prli.sepa_ref_num = p_sepa_ref_num
            AND NVL (prli.sepv_ref_num, 0) = NVL (p_sepv_ref_num, 0)
            AND NVL (prli.par_value_charge, 'N') = NVL (p_par_value_charge, 'N')
            AND prli.once_off = p_once_off
            AND prli.pro_rata = p_prorata
            AND prli.regular_charge = p_regular
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND prli.sety_ref_num = fcit.sety_ref_num
            AND (fcit.package_category = cp_package_category OR fcit.package_category IS NULL)
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date);

      --
      CURSOR c_prices_cat_sety (
         cp_package_category  IN  VARCHAR2
        ,cp_nety_type_code    IN  VARCHAR2
      ) IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               , (prli.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM price_lists prli, fixed_charge_item_types fcit, tax_rates tara
          WHERE prli.sety_ref_num = p_sety_ref_num
            AND prli.package_category = cp_package_category
            AND prli.nety_type_code = cp_nety_type_code
            AND prli.channel_type IS NULL
            AND prli.sepv_ref_num IS NULL
            AND prli.par_value_charge IS NULL
            AND prli.once_off = p_once_off
            AND prli.pro_rata = p_prorata
            AND prli.regular_charge = p_regular
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND prli.sety_ref_num = fcit.sety_ref_num
            AND (fcit.package_category = cp_package_category OR fcit.package_category IS NULL)
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date);

      --
      CURSOR c_prices_sety_values (
         cp_package_category  IN  VARCHAR2
      ) IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               , (prli.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM price_lists prli, fixed_charge_item_types fcit, tax_rates tara
          WHERE prli.sety_ref_num = p_sety_ref_num
            AND prli.package_category IS NULL
            AND prli.channel_type IS NULL
            AND prli.sepa_ref_num = p_sepa_ref_num
            AND NVL (prli.sepv_ref_num, 0) = NVL (p_sepv_ref_num, 0)
            AND NVL (prli.par_value_charge, 'N') = NVL (p_par_value_charge, 'N')
            AND prli.once_off = p_once_off
            AND prli.pro_rata = p_prorata
            AND prli.regular_charge = p_regular
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND prli.sety_ref_num = fcit.sety_ref_num
            AND (fcit.package_category = cp_package_category OR fcit.package_category IS NULL)
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date);

      --
      CURSOR c_prices_sety (
         cp_package_category  IN  VARCHAR2
      ) IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               , (prli.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM price_lists prli, fixed_charge_item_types fcit, tax_rates tara
          WHERE prli.sety_ref_num = p_sety_ref_num
            AND prli.package_category IS NULL
            AND prli.channel_type IS NULL
            AND prli.sepv_ref_num IS NULL
            AND prli.par_value_charge IS NULL
            AND prli.once_off = p_once_off
            AND prli.pro_rata = p_prorata
            AND prli.regular_charge = p_regular
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND prli.sety_ref_num = fcit.sety_ref_num
            AND (fcit.package_category = cp_package_category OR fcit.package_category IS NULL)
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date);

      --
      CURSOR c_values_chan_sept_chca IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,ficv.charge_value charge_value
               , (ficv.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit, tax_rates tara
          WHERE ficv.sety_ref_num IS NULL
            AND (   (ficv.sept_type_code = p_package_type AND ficv.chca_type_code IS NULL)
                 OR (ficv.chca_type_code = p_chca_type_code AND ficv.sept_type_code IS NULL)
                )
            AND ficv.channel_type = p_channel_type
            AND ficv.sepv_ref_num IS NULL
            AND ficv.par_value_charge IS NULL
            AND ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN ficv.start_date AND NVL (ficv.end_date, p_service_date);

      --
      CURSOR c_values_sept_chca IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,ficv.charge_value charge_value
               , (ficv.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit, tax_rates tara
          WHERE ficv.sety_ref_num IS NULL
            AND (   (ficv.sept_type_code = p_package_type AND ficv.chca_type_code IS NULL)
                 OR (ficv.chca_type_code = p_chca_type_code AND ficv.sept_type_code IS NULL)
                )
            AND ficv.channel_type IS NULL
            AND ficv.sepv_ref_num IS NULL
            AND ficv.par_value_charge IS NULL
            AND ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN ficv.start_date AND NVL (ficv.end_date, p_service_date);

      --
      CURSOR c_prices_chan_cat (
         cp_package_category  IN  VARCHAR2
        ,cp_nety_type_code    IN  VARCHAR2
      ) IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               , (prli.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM price_lists prli, fixed_charge_item_types fcit, tax_rates tara
          WHERE prli.sety_ref_num IS NULL
            AND prli.package_category = cp_package_category
            AND prli.nety_type_code = cp_nety_type_code
            AND prli.channel_type = p_channel_type
            AND prli.sepv_ref_num IS NULL
            AND prli.par_value_charge IS NULL
            AND prli.once_off = p_once_off
            AND prli.pro_rata = p_prorata
            AND prli.regular_charge = p_regular
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND prli.package_category = fcit.prli_package_category
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date);

      --
      CURSOR c_prices_cat (
         cp_package_category  IN  VARCHAR2
        ,cp_nety_type_code    IN  VARCHAR2
      ) IS
         SELECT fcit.type_code type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               , (prli.charge_value * tara.rate_value) / 100 tax
               ,fcit.fcdt_type_code   -- CHG-498
           FROM price_lists prli, fixed_charge_item_types fcit, tax_rates tara
          WHERE prli.sety_ref_num IS NULL
            AND prli.package_category = cp_package_category
            AND prli.nety_type_code = cp_nety_type_code
            AND prli.channel_type IS NULL
            AND prli.sepv_ref_num IS NULL
            AND prli.par_value_charge IS NULL
            AND prli.once_off = p_once_off
            AND prli.pro_rata = p_prorata
            AND prli.regular_charge = p_regular
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_prorata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND prli.package_category = fcit.prli_package_category
            AND p_service_date BETWEEN tara.start_date AND NVL (tara.end_date, p_service_date)
            AND p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date);

      -- CHG-13618
      CURSOR c_sety_charge IS
         SELECT 1
         FROM price_lists prli, fixed_charge_item_types fcit
         WHERE p_service_date BETWEEN prli.start_date AND NVL (prli.end_date, p_service_date)
           AND prli.sety_ref_num = p_sety_ref_num
           AND prli.sety_ref_num = fcit.sety_ref_num
           AND prli.once_off = p_once_off
           AND prli.pro_rata = p_prorata
           AND prli.regular_charge = p_regular
           AND fcit.once_off = p_once_off
           AND fcit.pro_rata = p_prorata
           AND fcit.regular_charge = p_regular
           AND prli.sepa_ref_num IS NULL;
      
      --
      CURSOR c_category_nety IS
         SELECT sept.CATEGORY
               ,sept.special_mark   -- CHG-3060
               ,susg.nety_type_code
               ,sept.fixed_term_type   -- CHG-3345
           FROM serv_package_types sept, subs_serv_groups susg
          WHERE sept.type_code = p_package_type AND susg.ref_num = p_susg_ref_num;

      --
      CURSOR c_inve (
         p_type_code         IN  VARCHAR2
        ,p_billing_selector  IN  VARCHAR2
        ,p_taty_type_code    IN  VARCHAR2
        ,ip_susg_ref_num     IN  NUMBER
        ,p_ad_entry_text     IN  VARCHAR2
      ) IS
         SELECT ref_num
               ,fcit_type_code
               ,eek_amt
               ,billing_selector
               ,taty_type_code
               ,fixed_charge_value
               ,ROWID   -- CHG-498
           FROM invoice_entries
          WHERE invo_ref_num = p_invo_ref_num
            AND NVL (susg_ref_num, 0) = NVL (ip_susg_ref_num, 0)
            AND NVL (maas_ref_num, 0) = NVL (p_maas_ref_num, 0)   -- CHG-498
            AND NVL (additional_entry_text, '*!*') = Nvl(p_ad_entry_text, '*!*') -- MOBE-540
            AND fcit_type_code = p_type_code
            AND billing_selector = p_billing_selector
            AND taty_type_code = p_taty_type_code;

      --
      CURSOR c_inen_seq IS
         SELECT inen_ref_num_s.NEXTVAL
           FROM DUAL;

      -- CHG-2180
      CURSOR c_last_ftco IS
         SELECT   *
             FROM fixed_term_contracts
            WHERE susg_ref_num = p_susg_ref_num AND date_closed IS NOT NULL
         ORDER BY date_closed DESC;

      --
      CURSOR c_senu_num IS
         SELECT senu_num
           FROM senu_susg
          WHERE susg_ref_num = p_susg_ref_num AND TRUNC (SYSDATE) BETWEEN start_date AND NVL (end_date, SYSDATE);

      -- CHG-5438
      CURSOR c_mipa IS
         SELECT compens_billing_selector
              , compens_fcit_type_code
         FROM mixed_packets
         WHERE packet_code = p_mixed_packet_code
      ;
      -- CHG-5438
      CURSOR c_ftmc IS
         SELECT *
         FROM fixed_term_maac_contracts
         WHERE maac_ref_num = p_maac_ref_num
           AND mixed_packet_code = p_mixed_packet_code
           AND waiting_serv_num = p_kw_serv_num
           AND fixed_term_category = Fixed_Term_Contract.c_fix_term_kw
      ;
      --
      CURSOR c_mipo_comp (p_ebs_order_number  mixed_packet_orders.ebs_order_number%TYPE) IS
         SELECT 1
         FROM mixed_packet_orders
         WHERE ebs_order_number = p_ebs_order_number
           AND compens_charged_date IS NOT NULL
      ;
      --DOBAS-1107
      CURSOR c_spoe(p_susg_ref_num IN NUMBER,p_susg_ref_num_prev IN NUMBER, p_spoc_type_code IN VARCHAR2) IS 
         SELECT *
           FROM SPECIAL_OFFER_ENTRIES	spoe
		  WHERE spoe.spoc_type_code = p_spoc_type_code 
            AND (spoe.susg_ref_num = p_susg_ref_num  OR
	             spoe.susg_ref_num = p_susg_ref_num_prev )
            AND spoe.market_price is not null 
            AND spoe.offer_price is not null 
      ;

      --DOBAS-1205
      CURSOR c_spoc(p_spoc_type_code IN VARCHAR2) IS 
         SELECT *
           FROM SPECIAL_OFFER_CODES	spoc
		  WHERE spoc.type_code = p_spoc_type_code 
            AND spoc.markdown_amount is not null 
      ;                  
      --
      c_conn_billing_selector       VARCHAR2 (3) := LTRIM (RTRIM (get_system_parameter (66)));
      --
      l_inve_ref_num                invoice_entries.ref_num%TYPE;
      l_eek_amt                     invoice_entries.eek_amt%TYPE;
      l_fcit_type_code              invoice_entries.fcit_type_code%TYPE;
      l_billing_selector            invoice_entries.billing_selector%TYPE;
      l_taty_type_code              invoice_entries.taty_type_code%TYPE;
      l_fixed_charge_value          invoice_entries.fixed_charge_value%TYPE;
      l_discount_type               VARCHAR2 (4);   -- UPR 1991
      l_discount_applies            VARCHAR2 (1);
      l_apply_discount_now          VARCHAR2 (1);
      l_credit_disc_row             VARCHAR2 (1);
      l_ordinary_disc_row           VARCHAR2 (1);
      l_maac_ref_num                NUMBER;
      l_dummy                       NUMBER;  -- CHG-5438
      l_success                     BOOLEAN;
      l_found                       BOOLEAN;
      l_credit_fcit_type_code       invoice_entries.fcit_type_code%TYPE;
      l_credit_taty_type_code       invoice_entries.taty_type_code%TYPE;
      l_credit_rate_value           tax_rates.rate_value%TYPE;
      l_credit_inve_row             c_inve%ROWTYPE;
      --
      e_delete_credit_row_error     EXCEPTION;
      e_find_oo_conn_discount       EXCEPTION;
      e_find_fcit                   EXCEPTION;
      e_find_from_to_price          EXCEPTION;
      e_find_compensation           EXCEPTION;  -- CHG-5438
      --
      l_package_category            serv_package_types.CATEGORY%TYPE := NULL;
      l_nety_type_code              serv_package_types.nety_type_code%TYPE := NULL;
      l_special_mark                serv_package_types.special_mark%TYPE;       -- CHG-3060
      rec                           c_prices_cat%ROWTYPE;
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;
      l_ftco_rec                    fixed_term_contracts%ROWTYPE;               -- CHG-3060
      l_ftmc_rec                    fixed_term_maac_contracts%ROWTYPE;          -- CHG-5438
      l_inen_rowid                  VARCHAR2 (30);                              -- CHG-498
      l_sety_rec                    service_types%ROWTYPE;                      -- CHG-323
      l_pobp_rec                    packet_order_bill_periods%ROWTYPE;          -- CHG-3345
      l_from_package                serv_package_types.type_code%TYPE;          -- CHG-323
      l_from_category               package_categories.package_category%TYPE;   -- CHG-323
      l_to_package                  serv_package_types.type_code%TYPE;          -- CHG-323
      l_to_category                 package_categories.package_category%TYPE;   -- CHG-323
      l_subscription_fee            sept_packets.subscription_fee%TYPE;         -- CHG-3060
      l_amt_tax                     sept_packets.amt_tax_subs_fee%TYPE;         -- CHG-3060
      l_compensation                sept_packets.compensation%TYPE;             -- CHG-3060
      l_tax_compensation            sept_packets.amt_tax_compensation%TYPE;     -- CHG-3060
      l_sepo_ref_num                sept_packet_orders.ref_num%TYPE;            -- CHG-3345
      l_fixed_term_type             serv_package_types.fixed_term_type%TYPE;    -- CHG-3345
      l_compens_bise                sept_packets.compens_billing_selector%TYPE; -- CHG-5186
      l_compens_fcit                sept_packets.compens_fcit_type_code%TYPE ;  -- CHG-5186
      l_par_value_charge            price_lists.par_value_charge%TYPE;          -- CHG-13618
      l_sepv_ref_num                price_lists.sepv_ref_num%TYPE;              -- CHG-13618
      
      l_subsidy                     NUMBER;                                     -- DOBAS-1107
      l_months_count                NUMBER;                                     -- DOBAS-1107
      l_spoe_rec                    SPECIAL_OFFER_ENTRIES%ROWTYPE;              -- DOBAS-1107
      l_spoc_rec                    SPECIAL_OFFER_CODES%ROWTYPE;                -- DOBAS-1205
      
   BEGIN
      -- dbms_output.put_line('CREATE INVOICE ENTRY: for chca = ' || p_chca_type_code ||
       --    ', package = ' || p_package_type ||',sety ref = ' || to_char(p_sety_ref_num));
      -- dbms_output.put_line('CREATE INVOICE ENTRY : Once off = ' || p_once_off || ', regular = ' || p_regular ||
       --    ', pro rata = ' || p_prorata ||',date = ' || to_char(p_service_date, 'dd.mm.yyyy hh24:mi:ss'));
      bcc_proc_name := 'Create Charge Entry ';
      -- hinna leidmine (jupp):
      l_maac_ref_num := NVL (p_maac_ref_num, gen_bill.maac_ref_num_by_susg (p_susg_ref_num));

      IF p_package_type IS NOT NULL THEN
         OPEN c_category_nety;

         FETCH c_category_nety
          INTO l_package_category
              ,l_special_mark   -- CHG-3060
              ,l_nety_type_code
              ,l_fixed_term_type;   -- CHG-3345

         CLOSE c_category_nety;
      END IF;

      /*
        ** CHG-3060: Paketeeritud müük. Hinnakirjavälise liitumistasu leidmine
      */
      IF l_special_mark = 'PAK' AND p_sety_ref_num IS NULL AND p_once_off = 'Y' AND p_prorata = 'N' AND p_regular = 'Y' THEN
         -- Leida FTCO kirje
         l_ftco_rec := fixed_term_contract.get_last_open_contract (p_susg_ref_num, p_package_type);
         -- Leida Fixed_Term_Contracts Ebs_Order_Number järgi liitumistasu
         fixed_term_contract.get_packet_connection_charge (l_ftco_rec.ebs_order_number
                                                          ,l_subscription_fee
                                                          ,l_amt_tax
                                                          ,l_sepo_ref_num
                                                          );

         --
         IF NVL (l_subscription_fee, 0) = 0 AND NOT p_check_pricelist THEN
            /*
              ** CHG-2180: Eircase: kui hinnakirjavälist liitumistasu ei leitud, siis
              ** liitumistasu ei rakendata.
            */
            RETURN;
         END IF;
      END IF;

      /* End CHG-3060 */

      --- siia tuleb kirjutada teade, kui l_package_cat.. is null
      IF p_char_amt IS NULL THEN
         /*
           ** CHG-13618: MKONT liitumistasu parandus
         */
         l_par_value_charge := p_par_value_charge;
         l_sepv_ref_num     := p_sepv_ref_num;
         --
         IF p_once_off = 'Y' AND p_prorata = 'N' AND p_regular = 'Y' And l_par_value_charge = 'Y' THEN
            --
            OPEN  c_sety_charge;
            FETCH c_sety_charge INTO l_dummy;
            l_found := c_sety_charge%FOUND;
            CLOSE c_sety_charge;
            --
            IF l_found THEN
               --
               l_par_value_charge := 'N';
               l_sepv_ref_num := NULL;
               --
            END IF;
            --
         END IF;  -- End CHG-13618
         --
         LOOP
            -- CHG-13618: Asendatud LOOP'i sees p_par_value_charge -> l_par_value_charge ja p_sepv_ref_num -> l_sepv_ref_num
         
            /*
              ** CHG-323: Enne tavahindade leidmise kursorite käivitamist kontrollida, kas selle olukorra jaoks on
              ** vaja rakendada from->to väärtuste alusel erihinna leidmise loogikat.
            */
            IF p_sety_ref_num IS NOT NULL AND p_once_off = 'Y' AND p_prorata = 'N' AND p_regular = 'N' THEN
               l_sety_rec := tbcis_common.get_sety_record (p_sety_ref_num);

               -- CHG-5186
               -- CHG-5438: Added mixed packet and MFXTR logic
               IF (l_sety_rec.service_name = Or_Common.fixtr_service_name AND
                   ( l_special_mark = 'PAK' OR p_mixed_packet_code IS NOT NULL)
                  )
                  OR
                  (l_sety_rec.service_name = Or_Common.mfxtr_service_name AND
                   p_mixed_packet_code IS NOT NULL)
               THEN
                  EXIT;
               END IF;

               --
               IF l_sety_rec.charge_old_package = 'Y' THEN   -- (maksustatakse vana paketti)
                  l_from_package := p_package_type;   -- (primaarne pakett)
                  l_from_category := l_package_category;   -- (primaarne paketikategooria)
                  l_to_package := p_secondary_package;   -- (sekundaarne pakett)
                  l_to_category := p_secondary_category;   -- (sekundaarne paketikategooria)
               ELSE   -- (maksustatakse uut paketti)
                  l_from_package := p_secondary_package;   -- (sekundaarne pakett)
                  l_from_category := p_secondary_category;   -- (sekundaarne paketikategooria)
                  l_to_package := p_package_type;   -- (primaarne pakett)
                  l_to_category := l_package_category;   -- (primaarne paketikategooria)
               END IF;

               --
               get_from_to_special_price
                              (p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                              ,p_once_off   -- IN     fixed_charge_item_types.once_off%TYPE
                              ,p_prorata   -- IN     fixed_charge_item_types.pro_rata%TYPE
                              ,p_regular   -- IN     fixed_charge_item_types.regular_charge%TYPE
                              ,p_service_date   -- IN     DATE
                              ,l_from_package   -- IN     serv_package_types.type_code%TYPE
                              ,l_to_package   -- IN     serv_package_types.type_code%TYPE
                              ,l_from_category   -- IN     package_categories.package_category%TYPE
                              ,l_to_category   -- IN     package_categories.package_category%TYPE
                              ,p_sepa_ref_num   -- IN     service_parameters.ref_num%TYPE
                              ,p_from_sepv_ref_num   -- IN     service_param_values.ref_num%TYPE
                              ,p_sepv_ref_num   -- p_to_sepv_ref_num   IN     service_param_values.ref_num%TYPE
                              ,p_channel_type   -- IN     fixed_special_prices.channel_type%TYPE
                              ,p_fixed_term_category   -- IN  fixed_special_prices.fixed_term_category%TYPE,   -- CHG1634
                              ,p_fixed_term_length   -- IN       fixed_special_prices.fixed_term_length%TYPE,   -- CHG1634
                              ,p_fixed_term_sety   -- IN       fixed_special_prices.fixed_term_sety%TYPE   -- CHG1634
                              ,rec.type_code   -- OUT fixed_charge_item_types.type_code%TYPE
                              ,rec.charge_value   -- OUT fixed_special_prices.charge_value%TYPE
                              ,rec.taty_type_code   -- OUT tax_types.tax_type_code%TYPE
                              ,rec.billing_selector   -- OUT fixed_charge_item_types.billing_selector%TYPE
                              ,rec.fcdt_type_code   -- OUT fixed_charge_item_types.fcdt_type_code%TYPE
                              ,rec.tax   -- OUT NUMBER
                              ,p_success   -- CHG1634
                              ,p_error_text   -- CHG1634
                              );

               IF (NOT p_success) THEN
                  RAISE e_find_from_to_price;
               END IF;

               IF rec.charge_value IS NOT NULL THEN
                  /*
                    ** S.t. leiti from->to erihind; kui see hind on ka = 0, siis on see ometi olemas ja ongi just selle case-i maksustamine 0-hinnaga
                    ** => SKIP hinna leidmise kursorid
                  */
                  EXIT;
               ELSE
                  /*
                    ** CHG-2795: Leida teisest regulaarsest teenusest sõltuv erihind.
                    **
                    **  Kui hinnakirjas on defineeritud mobiili või masterteenuse Once_off teenustasu
                    **  või erihinna arvestus sõltuvalt teise regulaarse masterteenuse olemasolust,
                    **  siis sõltuv teenustasu  või erihind võetakse juhul kui määrav teenus on aktiivne
                    **  tellitava teenuse tellimise kuupäeval.
                  */
                  get_dependent_price (p_sety_ref_num   --IN     service_types.ref_num%TYPE
                                      ,p_once_off   --IN     fixed_charge_item_types.once_off%TYPE
                                      ,p_prorata   --IN     fixed_charge_item_types.pro_rata%TYPE
                                      ,p_regular   --IN     fixed_charge_item_types.regular_charge%TYPE
                                      ,p_service_date   --IN     DATE
                                      ,p_package_type   --IN     serv_package_types.type_code%TYPE
                                      ,l_package_category   --IN     package_categories.package_category%TYPE
                                      ,p_chca_type_code   --IN     fixed_dependent_prices.charging:category%TYPE
                                      ,p_channel_type   --IN     fixed_special_prices.channel_type%TYPE
                                      ,p_susg_ref_num   --IN     subs_serv_groups.ref_num%TYPE
                                      ,p_maac_ref_num   --IN accounts.ref_num%TYPE
                                      ,rec.type_code   --OUT fixed_charge_item_types.type_code%TYPE
                                      ,rec.charge_value   --OUT fixed_special_prices.charge_value%TYPE
                                      ,rec.taty_type_code   --OUT tax_types.tax_type_code%TYPE
                                      ,rec.billing_selector   --OUT fixed_charge_item_types.billing_selector%TYPE
                                      ,rec.fcdt_type_code   --OUT fixed_charge_item_types.fcdt_type_code%TYPE
                                      ,rec.tax   --OUT NUMBER
                                      );

                  IF rec.charge_value IS NOT NULL THEN
                     -- leiti sõltuv hind
                     EXIT;
                  END IF;
               --
               END IF;
            END IF;

            /*
              ** End CHG-323: S.t. from->to erihinda pole ja jätkatakse praegu olemasoleva funktsionaalsusega hinna leidmiseks.
              ** Seejuures kasutatakse maksustamiseks primaarset paketti p_package_type (täpselt nagu see ka praegu on).
            */
            IF p_sety_ref_num IS NOT NULL THEN
               IF p_channel_type IS NOT NULL THEN
                  IF l_sepv_ref_num IS NOT NULL OR l_par_value_charge = 'Y' THEN  -- CHG-13618: Asendatud lokaalsete muutujatega
                     OPEN  c_values_chan_sety_value;
                     FETCH c_values_chan_sety_value INTO rec;
                     --
                     IF c_values_chan_sety_value%FOUND THEN
                        CLOSE c_values_chan_sety_value; -- CHG-13979
                        EXIT;
                     END IF;
                     --
                     CLOSE c_values_chan_sety_value;
                  ELSE
                     OPEN  c_values_chan_sety;
                     FETCH c_values_chan_sety INTO rec;
                     --
                     IF c_values_chan_sety%FOUND THEN
                        CLOSE c_values_chan_sety; -- CHG-13979
                        EXIT;
                     END IF;
                     --
                     CLOSE c_values_chan_sety;
                  END IF;

                  --
                  IF p_package_type IS NOT NULL THEN
                     IF l_sepv_ref_num IS NOT NULL OR l_par_value_charge = 'Y' THEN  -- CHG-13618: Asendatud lokaalsete muutujatega
                        OPEN  c_prices_chan_cat_sety_values (l_package_category, l_nety_type_code);
                        FETCH c_prices_chan_cat_sety_values INTO rec;
                        --
                        IF c_prices_chan_cat_sety_values%FOUND THEN
                           CLOSE c_prices_chan_cat_sety_values; -- CHG-13979
                           EXIT;
                        END IF;
                        --
                        CLOSE c_prices_chan_cat_sety_values;
                     ELSE
                        OPEN  c_prices_chan_cat_sety (l_package_category, l_nety_type_code);
                        FETCH c_prices_chan_cat_sety INTO rec;
                        --
                        IF c_prices_chan_cat_sety%FOUND THEN
                           CLOSE c_prices_chan_cat_sety; -- CHG-13979
                           EXIT;
                        END IF;
                        --
                        CLOSE c_prices_chan_cat_sety;
                     END IF;
                  END IF;

                  --
                  IF l_sepv_ref_num IS NOT NULL OR l_par_value_charge = 'Y' THEN  -- CHG-13618: Asendatud lokaalsete muutujatega
                     OPEN  c_prices_chan_sety_values (l_package_category);
                     FETCH c_prices_chan_sety_values INTO rec;
                     --
                     IF c_prices_chan_sety_values%FOUND THEN
                        CLOSE c_prices_chan_sety_values; -- CHG-13979
                        EXIT;
                     END IF;
                     --
                     CLOSE c_prices_chan_sety_values;
                  ELSE
                     OPEN  c_prices_chan_sety (l_package_category);
                     FETCH c_prices_chan_sety INTO rec;
                     --
                     IF c_prices_chan_sety%FOUND THEN
                        CLOSE c_prices_chan_sety; -- CHG-13979
                        EXIT;
                     END IF;
                     --
                     CLOSE c_prices_chan_sety;
                  END IF;
               END IF;   --IF p_channel_type is not null THEN

               --
               IF l_sepv_ref_num IS NOT NULL OR l_par_value_charge = 'Y' THEN  -- CHG-13618: Asendatud lokaalsete muutujatega
                  OPEN  c_values_sety_value;
                  FETCH c_values_sety_value INTO rec;
                  --
                  IF c_values_sety_value%FOUND THEN
                     CLOSE c_values_sety_value; -- CHG-13979
                     EXIT;
                  END IF;
                  --
                  CLOSE c_values_sety_value;
               ELSE
                  OPEN  c_values_sety;
                  FETCH c_values_sety INTO rec;
                  --
                  IF c_values_sety%FOUND THEN
                     CLOSE c_values_sety; -- CHG-13979
                     EXIT;
                  END IF;
                  --
                  CLOSE c_values_sety;
               END IF;

               --
               IF p_package_type IS NOT NULL THEN
                  IF l_sepv_ref_num IS NOT NULL OR l_par_value_charge = 'Y' THEN  -- CHG-13618: Asendatud lokaalsete muutujatega
                     OPEN  c_prices_cat_sety_values (l_package_category, l_nety_type_code);
                     FETCH c_prices_cat_sety_values INTO rec;
                     --
                     IF c_prices_cat_sety_values%FOUND THEN
                        CLOSE c_prices_cat_sety_values; -- CHG-13979
                        EXIT;
                     END IF;
                     --
                     CLOSE c_prices_cat_sety_values;
                  ELSE
                     OPEN  c_prices_cat_sety (l_package_category, l_nety_type_code);
                     FETCH c_prices_cat_sety INTO rec;
                     --
                     IF c_prices_cat_sety%FOUND THEN
                        CLOSE c_prices_cat_sety; -- CHG-13979
                        EXIT;
                     END IF;
                     --
                     CLOSE c_prices_cat_sety;
                  END IF;
               END IF;   --  IF p_package_type is not null THEN

               --
               IF l_sepv_ref_num IS NOT NULL OR l_par_value_charge = 'Y' THEN  -- CHG-13618: Asendatud lokaalsete muutujatega
                  OPEN  c_prices_sety_values (l_package_category);
                  FETCH c_prices_sety_values INTO rec;
                  --
                  IF c_prices_sety_values%FOUND THEN
                     CLOSE c_prices_sety_values; -- CHG-13979
                     EXIT;
                  END IF;
                  --
                  CLOSE c_prices_sety_values;
               ELSE
                  OPEN  c_prices_sety (l_package_category);
                  FETCH c_prices_sety INTO rec;
                  --
                  IF c_prices_sety%FOUND THEN
                     CLOSE c_prices_sety; -- CHG-13979
                     EXIT;
                  END IF;
                  --
                  CLOSE c_prices_sety;
               END IF;
            END IF;   -- IF p_sety_ref_num is not null THEN

            --
            IF p_sety_ref_num IS NULL THEN
               IF p_channel_type IS NOT NULL THEN
                  OPEN  c_values_chan_sept_chca;
                  FETCH c_values_chan_sept_chca INTO rec;
                  --
                  IF c_values_chan_sept_chca%FOUND THEN
                     CLOSE c_values_chan_sept_chca; -- CHG-13979
                     EXIT;
                  END IF;
                  --
                  CLOSE c_values_chan_sept_chca;

                  --
                  OPEN  c_prices_chan_cat (l_package_category, l_nety_type_code);
                  FETCH c_prices_chan_cat INTO rec;
                  --
                  IF c_prices_chan_cat%FOUND THEN
                     CLOSE c_prices_chan_cat; -- CHG-13979
                     EXIT;
                  END IF;
                  --
                  CLOSE c_prices_chan_cat;
               END IF;

               --
               OPEN  c_values_sept_chca;
               FETCH c_values_sept_chca INTO rec;
               --
               IF c_values_sept_chca%FOUND THEN
                  CLOSE c_values_sept_chca; -- CHG-13979
                  EXIT;
               END IF;
               --
               CLOSE c_values_sept_chca;

               --
               OPEN  c_prices_cat (l_package_category, l_nety_type_code);
               FETCH c_prices_cat INTO rec;
               --
               IF c_prices_cat%FOUND THEN
                  CLOSE c_prices_cat; -- CHG-13979
                  EXIT;
               END IF;
               --
               CLOSE c_prices_cat;
            END IF;   --  IF p_sety_ref_num is null THEN

            --dbms_output.put_line('CREATE INVOICE ENTRIES :ei leidnud = ' || p_chca_type_code || ', package = ' || p_package_type ||
            --                     ',sety ref = ' || to_char(p_sety_ref_num));
            EXIT;
         END LOOP;
      ELSE   /* UPR-2794 */
         IF p_bise IS NULL THEN      
         
            /* UPR-3007 */
            l_fcit_rec := get_fcit_by_sety_paca (p_sety_ref_num, l_package_category, p_once_off, p_regular, p_prorata);

            IF l_fcit_rec.type_code IS NULL THEN
               RAISE e_find_fcit;
            END IF;

            --
            rec.billing_selector := l_fcit_rec.billing_selector;
            rec.type_code := l_fcit_rec.type_code;
            rec.taty_type_code := l_fcit_rec.taty_type_code;
         /* End UPR-3007 */
         ELSE
            IF p_fcit_type_code IS NOT NULL AND p_taty_type_code IS NOT NULL THEN
               rec.type_code := p_fcit_type_code;
               rec.taty_type_code := p_taty_type_code;
            ELSE
               l_fcit_rec := get_fcit_by_bise_sety (p_sety_ref_num, p_bise, p_once_off, p_regular, p_prorata);

               IF l_fcit_rec.type_code IS NULL THEN
                  RAISE e_find_fcit;
               END IF;

               --
               rec.type_code := l_fcit_rec.type_code;
               rec.taty_type_code := l_fcit_rec.taty_type_code;
            END IF;

            rec.billing_selector := p_bise;
         END IF;

         --
         rec.charge_value := p_char_amt;
         -- CHG-4899: rec.tax := rec.charge_value * gen_bill.get_tax_rate (rec.taty_type_code, p_service_date);
      END IF;

      /*
        ** CHG-3060: Paketeeritud müük.
      */
      IF NVL (l_subscription_fee, 0) > 0 THEN
         -- Hinnakirjaväline liitumistasu
         rec.charge_value := l_subscription_fee;
         -- CHG-4899: rec.tax := l_amt_tax;
         /*
           ** CHG-3345: Hinnakirjavälise liitumismaksu registreerimine
           ** arveldusgraafiku maksustuskirjesse.
         */
         l_pobp_rec := NULL;
         --
         l_pobp_rec.billing_year := TO_CHAR (l_ftco_rec.start_date, 'YYYY');
         l_pobp_rec.billing_month := TO_CHAR (l_ftco_rec.start_date, 'MM');
         l_pobp_rec.sepo_ref_num := l_sepo_ref_num;
         l_pobp_rec.ftco_ref_num := l_ftco_rec.ref_num;
         l_pobp_rec.sept_special_mark := l_special_mark;
         l_pobp_rec.subscription_fee := l_subscription_fee;
         l_pobp_rec.amt_tax_subs_fee := l_amt_tax;
         l_pobp_rec.maac_ref_num := p_maac_ref_num;
         l_pobp_rec.susg_ref_num := p_susg_ref_num;
         l_pobp_rec.senu_num := or_common.get_current_number_id (p_susg_ref_num);
         l_pobp_rec.date_created := SYSDATE;
         l_pobp_rec.created_by := sec.get_username;
         --
         fixed_term_contract.ins_packet_order_bill_periods (l_pobp_rec);
      --
      END IF;

      IF l_sety_rec.service_name = or_common.fixtr_service_name AND
         p_once_off = 'Y' AND
         p_prorata  = 'N' AND
         p_regular  = 'N' 
      THEN
         --
         IF l_special_mark = 'PAK' THEN
            /*
              ** Packaged Sale
            */
            l_ftco_rec := fixed_term_contract.get_last_contract (p_susg_ref_num, p_package_type);
            -- Leida Fixed_Term_Contracts EBS_order_number järgi compensation
            fixed_term_contract.get_packet_compensation (l_ftco_rec.ebs_order_number
                                                        ,l_compensation
                                                        ,l_tax_compensation
                                                        ,l_sepo_ref_num
                                                        ,l_compens_bise   -- CHG-5186
                                                        ,l_compens_fcit   -- CHG-5186
                                                        );

            -- CHG-5186: Kuna päringut hinnakirja ei toimu, tuleb rec omistamistega väärtustada
            l_found := get_fcit_by_bise_fcit (l_compens_bise
                                             ,l_compens_fcit 
                                             ,l_fcit_rec );
            --
            IF NOT l_found THEN
               RAISE e_find_fcit;
            END IF;


            rec.charge_value     := Nvl(l_compensation, 0);    -- CHG-5186: Nvl
            rec.tax              := NULL;                      -- CHG-5186
            rec.billing_selector := l_compens_bise;            -- CHG-5186
            rec.type_code        := l_compens_fcit;            -- CHG-5186
            rec.taty_type_code   := l_fcit_rec.taty_type_code; -- CHG-5186
            rec.fcdt_type_code   := NULL;                      -- CHG-5186


            /*
              ** CHG-3345: PAK hinnakirjavälise leppetrahvi registreerimine arveldusgraafiku maksustuskirjesse.
              ** Tavatähtajalise paketi hinnakirja leppetrahvi registreerimine tähtajalisse lepingusse.
            */

            -- Leida arveldusgraafikust susg'ile viimane maksustamise kirje
            l_found := fixed_term_contract.get_last_pobp_rec (l_sepo_ref_num, p_susg_ref_num, l_pobp_rec);

            /*
              ** Kontrollime, kas see on  aruandekuu arvelduskirje, peal võib olla sissemaks,
              ** liitumistasu, paketitasu(INT).
            */
            IF l_found AND
               l_pobp_rec.billing_year = TO_CHAR (SYSDATE, 'YYYY') AND
               l_pobp_rec.billing_month = TO_CHAR (SYSDATE, 'MM') 
            THEN
               UPDATE packet_order_bill_periods
                  SET sept_special_mark    = l_special_mark
                     ,compensation_amount  = Nvl(l_compensation, 0)     -- CHG-5186: Nvl
                     ,amt_tax_compensation = Nvl(l_tax_compensation, 0) -- CHG-5186: Nvl
                     ,date_updated         = SYSDATE
                     ,last_updated_by      = bcc_module_ref
                WHERE ref_num = l_pobp_rec.ref_num;
            --
            ELSE
               --
               l_pobp_rec := NULL;

               -- Senu num
               OPEN c_senu_num;

               FETCH c_senu_num
                INTO l_pobp_rec.senu_num;

               CLOSE c_senu_num;

               --
               l_pobp_rec.billing_year := TO_CHAR (SYSDATE, 'YYYY');
               l_pobp_rec.billing_month := TO_CHAR (SYSDATE, 'MM');
               l_pobp_rec.sepo_ref_num := l_sepo_ref_num;
               l_pobp_rec.ftco_ref_num := l_ftco_rec.ref_num;
               l_pobp_rec.sept_special_mark := l_special_mark;
               l_pobp_rec.compensation_amount := Nvl(l_compensation, 0);      -- CHG-5186: Nvl
               l_pobp_rec.amt_tax_compensation := Nvl(l_tax_compensation, 0); -- CHG-5186: Nvl
               l_pobp_rec.maac_ref_num := p_maac_ref_num;
               l_pobp_rec.susg_ref_num := p_susg_ref_num;
               l_pobp_rec.date_created := SYSDATE;
               l_pobp_rec.created_by := bcc_module_ref;
               --
               fixed_term_contract.ins_packet_order_bill_periods (l_pobp_rec);
            --
            END IF;

            /*
              ** CHG-1634: Registreerime leppetrahvi kuupäeva paketi arvelduslepingusse.
            */
            UPDATE sept_packet_orders
               SET compens_charged_date = TRUNC (SYSDATE)
                  ,date_updated = SYSDATE
                  ,last_updated_by = bcc_module_ref
             WHERE ref_num = l_sepo_ref_num;
         --
         ELSIF p_mixed_packet_code IS NOT NULL THEN
            /*
              ** CHG-5438: Mixed Packet Sale
            */
            l_ftco_rec := Fixed_Term_Contract.get_last_contract (p_susg_ref_num
                                                                ,p_package_type
                                                                ,p_mixed_packet_code
                                                                ,p_ebs_order_number );
            -- Arvutada ennetähtaegsel lõpetamisel PAK lepingu seadmete leppetrahv
            -- Registreerida arveldusgraafikusse 
            Fixed_Term_Contract.Calc_Mixed_Packet_Compensation (
                                     l_ftco_rec      -- IN     fixed_term_contracts%ROWTYPE
                                    ,'Y'             -- IN     p_reg_mpbp
                                    ,l_compensation  --    OUT NUMBER
                                    ,p_error_text    --    OUT VARCHAR2
                                    ,p_service_date  -- IN     DATE
            );
            --
            IF p_error_text IS NOT NULL THEN
               RAISE e_find_compensation;
            END IF;
            --
             
            -- Leida MIPA-st arverea koodid ja koodide järgi taty
            OPEN  c_mipa;
            FETCH c_mipa INTO l_compens_bise
                            , l_compens_fcit;
            CLOSE c_mipa;
            
            l_found := get_fcit_by_bise_fcit (l_compens_bise
                                             ,l_compens_fcit 
                                             ,l_fcit_rec );
            --
            IF NOT l_found THEN
               RAISE e_find_fcit;
            END IF;
            
            rec.charge_value     := Nvl(l_compensation, 0);
            rec.tax              := NULL; 
            rec.billing_selector := l_compens_bise;
            rec.type_code        := l_compens_fcit;
            rec.taty_type_code   := l_fcit_rec.taty_type_code;
            rec.fcdt_type_code   := NULL;
            
            --
         ELSE   -- CHG-1634
            /*
              ** Other fixed term contracts
            */
            IF l_fixed_term_type IS NOT NULL OR p_fixed_term_category IS NOT NULL THEN
               --
               l_ftco_rec := fixed_term_contract.get_last_contract_by_params (p_susg_ref_num
                                                                             ,p_fixed_term_category
                                                                             ,p_package_type
                                                                             ,p_fixed_term_sety
                                                                             );

               --DOBAS-1107
               -- tähtajalise lepingu kirjes täidetud eripakkumise kood, ei ole komplekti tähtajaline leping ja leping aktiivne, 
               -- arvutada subsiidimi proportsionaalne leppetrahv 
               l_subsidy      := 0;
               l_months_count := 0;
               l_spoe_rec     := null;
               l_spoc_rec     := null;  --DOBAS-1205   
               IF 	 l_ftco_rec.spoc_type_code is not null  
                 AND l_ftco_rec.mixed_packet_code is null 
                 AND l_ftco_rec.date_closed is null	THEN

                 -- Leida SPECIAL_OFFER_ENTRIES kirje
                  OPEN  c_spoe(l_ftco_rec.susg_ref_num,l_ftco_rec.prev_susg_ref_num, l_ftco_rec.spoc_type_code); 
                  FETCH c_spoe INTO l_spoe_rec; 
                  
                  IF c_spoe%FOUND THEN
                     -- Leida tähtajalise lepingu lõpuni jäänud kuude arv
		             l_months_count := trunc( months_between(trunc(l_ftco_rec.end_date),trunc(P_service_date)));
		             -- Leida subsiidium
		             l_subsidy := nvl(l_spoe_rec.market_price,0)-nvl(l_spoe_rec.offer_price,0);
		
                     -- Arvutada leppetrahv
		             -- Leppetrahv =( subsiidium/TL kuude arv) * TL lõpuni jäänud kuude arv
		             rec.charge_value := (l_subsidy/ l_ftco_rec.fixed_term_length ) * l_months_count; 
		              
 
                  ELSE --DOBAS-1205 
                    --kui puudub kirje tabelis SPOE, siis käsitlustasu arvutamiseks kasutatakse SPECIAL_OFFER_CODES.MARKDOWN_AMOUNT väärtust
                    --kui viimane on täidetud
                    OPEN  c_spoc(l_ftco_rec.spoc_type_code); 
                    FETCH c_spoc INTO l_spoc_rec; 
                    IF c_spoc%FOUND THEN
  
		               l_months_count := trunc( months_between(trunc(l_ftco_rec.end_date),trunc(P_service_date)));
		              -- Leida subsiidium
		               l_subsidy := nvl(l_spoc_rec.MARKDOWN_AMOUNT,0);
		               -- Arvutada leppetrahv
		               -- Leppetrahv =( subsiidium/TL kuude arv) * TL lõpuni jäänud kuude arv
		               rec.charge_value := (l_subsidy/ l_ftco_rec.fixed_term_length ) * l_months_count; 
		            END IF; --IF c_spoc%FOUND THEN  
                    CLOSE c_spoc;
                    --DOBAS-1205
                    
                  END IF; --IF c_spoe%FOUND THEN
                  CLOSE c_spoe;
                  
               END IF; --IF 	 l_ftco_rec.spoc_type_code is not null  

               -- Kui ei leia eripakkumise subsiidiumi või teenuseega seotud tähtajalise lepingu lõpetamisel arvutada 
               -- hinnakirja proportsionaalne leppetrahv
               IF l_subsidy = 0	THEN
                  -- Leida tähtajalise lepingu lõpuni jäänud kuude arv
		          l_months_count := trunc( months_between(trunc(l_ftco_rec.end_date),trunc(P_service_date)));
	              -- Arvutada leppetrahv
		          -- Leppetrahv =(hinnakirja hind/TL kuude arv) * TL lõpuni jäänud kuude arv
		          rec.charge_value := (rec.charge_value / l_ftco_rec.fixed_term_length ) * l_months_count; 
                   
               END IF;
               --DOBAS-1107
               ------------------------------------------------------------------------------------------
               
               -- Tavatähtajalise paketi hinnakirja leppetrahvi registreerimine tähtajalisse lepingusse
               -- CHG-4899: rec.tax replaced with calc_vat_amount
               UPDATE fixed_term_contracts
                  SET given_compensation = rec.charge_value
                     ,compensation_amt_tax = Gen_Bill.calc_vat_amount (rec.charge_value
                                                                      ,rec.taty_type_code
                                                                      ,p_service_date )
                     ,compens_charged_date = TRUNC (SYSDATE)
                     ,date_updated = SYSDATE
                     ,last_updated_by = bcc_module_ref
                WHERE ref_num = l_ftco_rec.ref_num;
            --
            END IF;
         --
         END IF;   -- CHG-1634
      --
      END IF;

      /* End CHG-3060 */

      
      /*
        ** CHG-5438: NL eellepingu ennetähtaese lõpetamise leppetrahv
        **           Aruandeperioodis seadmete arveldusgraafikusse ja kliendi arvele käsitlustasu
      */
      IF l_sety_rec.service_name = or_common.mfxtr_service_name AND
         p_mixed_packet_code IS NOT NULL AND
         p_once_off = 'Y' AND
         p_prorata  = 'N' AND
         p_regular  = 'N'
      THEN
         -- Leida FTMC maac ja Mixed_packet_code järgi 
         OPEN  c_ftmc;
         FETCH c_ftmc INTO l_ftmc_rec;
         l_found := c_ftmc%FOUND;
         CLOSE c_ftmc;
         --
         IF l_found THEN
            -- Kontrollida, kas leppetrahv arveldatud
            OPEN c_mipo_comp (l_ftmc_rec.ebs_order_number);
            FETCH c_mipo_comp INTO l_dummy;
            l_found := c_mipo_comp%FOUND;
            CLOSE c_mipo_comp;
            --
            IF l_found THEN
               --
               rec.charge_value := 0;
               --
            END IF;
            --
         END IF;
         
         /*
           ** Arvutada ennetähtaegsel lõpetamisel PAK lepingu seadmete leppetrahv
           ** Registreerida arveldusgraafikusse 
         */
         Fixed_Term_Contract.Calc_Vouc_Mixed_Packet_Compens (
               l_ftmc_rec      --p_ftmc_rec            IN     fixed_term_maac_contracts%ROWTYPE
              ,'Y'             --p_reg_mpbp            IN     VARCHAR2 DEFAULT 'Y'
              ,l_compensation  --p_total_compensation     OUT NUMBER
              ,p_error_text    --p_error_text             OUT VARCHAR2
         );
         --
         IF p_error_text IS NOT NULL THEN
            RAISE e_find_compensation;
         END IF;
         
         -- Leida MIPA-st arverea koodid ja koodide järgi taty
         OPEN  c_mipa;
         FETCH c_mipa INTO l_compens_bise
                         , l_compens_fcit;
         CLOSE c_mipa;
            
         l_found := get_fcit_by_bise_fcit (l_compens_bise
                                          ,l_compens_fcit 
                                          ,l_fcit_rec );
         --
         IF NOT l_found THEN
            RAISE e_find_fcit;
         END IF;
            
         rec.charge_value     := Nvl(l_compensation, 0);
         rec.tax              := NULL; 
         rec.billing_selector := l_compens_bise;
         rec.type_code        := l_compens_fcit;
         rec.taty_type_code   := l_fcit_rec.taty_type_code;
         rec.fcdt_type_code   := NULL;         
         --
      END IF;

      --
      -- lisandub p_count
      IF (NVL (rec.charge_value, 0) > 0 OR p_char_amt IS NOT NULL) THEN   -- Tingimust täiendatud Upr-2822
         --    dbms_output.put_line('CREATE INVOICE ENTRIES: TULEMUS: CHCA=' || p_chca_type_code
         --     || 'Package=' || p_package_type || ' ,sety ref=' || to_char(p_sety_ref_num)||' hind='
         --   ||to_char(rec.charge_value)  ||
         --           ', tax=' || to_char(rec.tax)
         --         );
         OPEN c_inve (rec.type_code, rec.billing_selector, rec.taty_type_code, p_susg_ref_num, p_additional_entry_text); -- MOBE-540: p_additional_entry_text

         FETCH c_inve
          INTO l_inve_ref_num
              ,l_fcit_type_code
              ,l_eek_amt
              ,l_billing_selector
              ,l_taty_type_code
              ,l_fixed_charge_value
              ,l_inen_rowid;   -- CHG-498

         --dbms_output.put_line('CREATE INVOICE ENTRIES :FCIT = ' || rec.type_code || ', billing selector = ' || rec.billing_selector);
         IF c_inve%NOTFOUND THEN   -- record has to be inserted into INVE
            CLOSE c_inve;

            IF p_transact_mode = 'INS' THEN
               SELECT inen_ref_num_s.NEXTVAL
                 INTO p_inen_ref_num
                 FROM SYS.DUAL;

               --   dbms_output.put_line('CREATE INVOICE ENTRIES : INSERT NEW INEN: '||to_char(p_inen_ref_num));
               --  ** Discount is applied only for connection charges.
               --  ** And as connection charge can be applied only once per mobile then
               --  ** look for possible discounts only here when new invoice entry is created.
               --  ** No need to look for possible discounts when updating existing invoice
               --  ** entry row in INS mode.
               INSERT INTO invoice_entries
                           (ref_num
                           ,invo_ref_num
                           ,acc_amount   -- CHG4594
                           ,rounding_indicator
                           ,under_dispute
                           ,created_by
                           ,date_created
                           ,billing_selector
                           ,fcit_type_code
                           ,taty_type_code
                           ,susg_ref_num
                           ,fixed_charge_value
                           ,evre_count
                           ,print_required
                           ,module_ref
                           ,amt_tax
                           ,maas_ref_num   -- CHG-498
                           ,additional_entry_text -- MOBE-540
                           ,pri_curr_code
                           )
                    VALUES (p_inen_ref_num
                           ,p_invo_ref_num
                           ,ROUND (NVL (p_count, 1) * rec.charge_value, g_inen_acc_precision /* CHG4594 */)
                           ,'N'   -- rounding
                           ,'N'
                           ,sec.get_username
                           ,SYSDATE
                           ,rec.billing_selector
                           ,rec.type_code
                           ,rec.taty_type_code
                           ,p_susg_ref_num
                           ,ROUND (NVL (p_count, 1) * rec.charge_value, 2)
                           ,1
                           ,NULL
                           ,DECODE (p_run_mode, 'BATCH', bcc_inve_mod_ref, p_run_mode)   -- Fxxx/BCCU
                           ,NULL  -- CHG-4899: ROUND (NVL (p_count, 1) * rec.tax, 2)
                           ,p_maas_ref_num   -- CHG-498
                           ,p_additional_entry_text -- MOBE-540
                           ,get_pri_curr_code ()
                           )
                 RETURNING ROWID
                      INTO l_inen_rowid;   -- CHG-498
            END IF;
         ELSE   -- when a record is found in INVE
            CLOSE c_inve;

            --
            IF p_transact_mode = 'INS' THEN
               --   dbms_output.put_line('CREATE INVOICE ENTRIES UPDATE inen :'|| l_inve_ref_num);
               UPDATE invoice_entries
                  SET eek_amt = ROUND (NVL (eek_amt, 0) + NVL (p_count, 1) * rec.charge_value, 2)
                     -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) + NVL (p_count, 1) * rec.tax, 2)
                     ,fixed_charge_value = ROUND (NVL (fixed_charge_value, 0) + NVL (p_count, 1) * rec.charge_value, 2)
                     ,evre_count = NVL (evre_count, 0) + 1
                     ,last_updated_by = sec.get_username
                     ,date_updated = SYSDATE
                     ,print_required = 'Y'
                WHERE ref_num = l_inve_ref_num;

               --
               p_inen_ref_num := l_inve_ref_num;   -- UPR-2794
            ELSIF p_transact_mode = 'DEL' THEN
               IF NVL (l_fixed_charge_value, 0) = NVL (p_count, 1) * NVL (rec.charge_value, 0) THEN
                  -- the invoice entry can be deleted
                  --  dbms_output.put_line('CREATE INVOICE ENTRIES delete inen :'|| l_inve_ref_num);
                  DELETE FROM invoice_entries
                        WHERE ref_num = l_inve_ref_num;
               ELSE
                  --      dbms_output.put_line('CREATE INVOICE ENTRIES update inen :'|| l_inve_ref_num);
                  UPDATE invoice_entries
                     SET eek_amt = ROUND (NVL (eek_amt, 0) - NVL (p_count, 1) * rec.charge_value, 2)   -- upr 1991
                        -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) - NVL (p_count, 1) * rec.tax, 2)   -- upr 1991
                        ,fixed_charge_value = ROUND (NVL (fixed_charge_value, 0) - NVL (p_count, 1) * rec.charge_value
                                                    ,2)
                        ,evre_count = NVL (evre_count, 0) - 1
                        ,last_updated_by = sec.get_username
                        ,date_updated = SYSDATE
                   WHERE ref_num = l_inve_ref_num;
               END IF;
            END IF;   -- p_transact_mode = 'INS' THEN
         END IF;   -- IF c_inve%NOTFOUND THEN

         -- upr 1991 pärast arverea lisamist lisame ka soodustuse, kui makse >0
         IF rec.charge_value > 0 THEN
            l_discount_type := calculate_discounts.find_discount_type (p_prorata   --p_pro_rata       VARCHAR2
                                                                      ,p_regular   --p_regular_charge VARCHAR2
                                                                      ,p_once_off
                                                                      );   --p_once_off       VARCHAR2) RETURN VARCHAR2;

            --  dbms_output.put_line('CREATE INVOICE ENTIES call calculate_discounts Find OO Conn Discounts');
            --  dbms_output.put_line('   l_discount_type: '|| l_discount_type);
            --  dbms_output.put_line('   rec.type_code  : '|| rec.type_code);
            --    dbms_output.put_line('   rec.billing_selector :'||  rec.billing_selector);
            --  dbms_output.put_line('   rec.charge_value :'||  rec.charge_value);
                     --
            IF p_susg_ref_num IS NOT NULL THEN   -- CHG-498
               calculate_discounts.find_oo_conn_discounts (l_discount_type   --p_discount_type     VARCHAR2
                                                          ,p_invo_ref_num   --p_invo_ref_num      NUMBER
                                                          ,rec.type_code   --p_fcit_type_code    VARCHAR2
                                                          ,rec.billing_selector   --p_billing_selector  VARCHAR2
                                                          ,p_sepv_ref_num   --p_sepv_ref_num      NUMBER
                                                          ,p_package_type   --p_sept_type_code    VARCHAR2
                                                          ,   NVL (p_count, 1)
                                                            * rec.charge_value   --p_charge_value      NUMBER
                                                          ,p_susg_ref_num   --p_susg_ref_num      NUMBER
                                                          ,l_maac_ref_num   --p_maac_ref_num      NUMBER
                                                          ,p_service_date   --p_date DATE
                                                          ,p_transact_mode  --p_mode  VARCHAR2  --'INS';'DEL'
                                                          ,p_error_text     --p_error_text IN out VARCHAR2
                                                          ,p_success        --p_success    IN out BOOLEAn
                                                          ,NULL             --p_max_calculated_amt  IN      NUMBER DEFAULT NULL
                                                          ,FALSE            --p_interim             IN      BOOLEAN DEFAULT FALSE
                                                          ,p_mixed_service  --p_mixed_service       IN      VARCHAR2 DEFAULT NULL
                                                          ); 
            ELSE
               calculate_discounts.find_ma_service_discounts
                                     (l_discount_type   -- IN     fixed_charge_types.discount_type%TYPE
                                     ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                     ,p_sety_ref_num   -- IN     service_types.ref_num%TYPE
                                     ,p_sepv_ref_num   -- IN     service_param_values.ref_num%TYPE  -- esialgu ei kodeeri
                                     ,p_maas_ref_num   -- IN     master_account_services.ref_num%TYPE
                                     ,rec.charge_value   -- p_charged_value  IN     NUMBER
                                     ,l_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                     ,rec.fcdt_type_code   -- IN     fixed_charge_item_types.fcdt_type_code%TYPE
                                     ,l_inen_rowid   -- IN     VARCHAR2
                                     ,p_service_date   -- IN     DATE
                                     ,p_error_text   -- OUT VARCHAR2
                                     ,p_success   -- OUT Boolean
                                     ,p_transact_mode   -- p_mode           IN     VARCHAR2 DEFAULT 'INS'  -- INS/DEL
                                     ,p_additional_entry_text   --dobas-262
                                     );
            END IF;   -- p_susg_ref_num IS NOT NULL

            --
            IF NOT p_success THEN
               RAISE e_find_oo_conn_discount;
            END IF;
         END IF;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_find_oo_conn_discount THEN   -- upr 1991
         p_success := FALSE;
         p_error_type := 'E';
         p_error_text := bcc_proc_name || ':' || p_error_text;
      WHEN e_find_fcit THEN
         p_success := FALSE;
         p_error_type := 'E';
         p_error_text :=    'Cannot find Fixed Charge Item Type for Billing Selector '
                         || p_bise
                         || ' (sety='
                         || TO_CHAR (p_sety_ref_num)
                         || ', regular='
                         || p_regular
                         || ', once off='
                         || p_once_off
                         || ', pro rata='
                         || p_prorata
                         || ')';
      WHEN e_find_from_to_price THEN
         p_success := FALSE;
         p_error_type := 'E';
         p_error_text := bcc_proc_name || ':' || p_error_text;
      WHEN e_find_compensation THEN
         p_success := FALSE;
         p_error_type := 'E';
         p_error_text := bcc_proc_name || ':' || p_error_text;
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := bcc_proc_name || ':' || SQLERRM || TO_CHAR (SQLCODE);
   END create_invoice_entry;

   -----------------------------------------------------------------------------------
   FUNCTION get_credit_fixed_charge_data (
      p_package_type      IN      serv_package_types.type_code%TYPE
     ,p_billing_selector  IN      fixed_charge_item_types.billing_selector%TYPE
     ,p_once_off          IN      fixed_charge_item_types.once_off%TYPE
     ,p_regular           IN      fixed_charge_item_types.regular_charge%TYPE
     ,p_pro_rata          IN      fixed_charge_item_types.pro_rata%TYPE
     ,p_start_date        IN      DATE
     ,p_fcit_type_code    OUT     fixed_charge_item_types.type_code%TYPE
     ,p_taty_type_code    OUT     fixed_charge_item_types.taty_type_code%TYPE
     ,p_rate_value        OUT     tax_rates.rate_value%TYPE
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_fcit (
         p_package_category  IN  VARCHAR2
      ) IS
         SELECT fcit.type_code
               ,fcit.taty_type_code
               ,tara.rate_value
           FROM fixed_charge_item_types fcit, tax_rates tara
          WHERE fcit.billing_selector = p_billing_selector
            AND fcit.package_category = p_package_category
            AND fcit.once_off = p_once_off
            AND fcit.pro_rata = p_pro_rata
            AND fcit.regular_charge = p_regular
            AND fcit.taty_type_code = tara.taty_type_code
            AND p_start_date BETWEEN tara.start_date AND NVL (tara.end_date, p_start_date);

      --
      l_category                    serv_package_types.CATEGORY%TYPE;
   BEGIN
      --Get current package category.
      l_category := get_package_category (p_package_type);

      --** Get FIXED_CHARGE_ITEM_TYPES data.
      OPEN c_fcit (l_category);

      FETCH c_fcit
       INTO p_fcit_type_code
           ,p_taty_type_code
           ,p_rate_value;

      --
      IF c_fcit%FOUND THEN
         CLOSE c_fcit;

         RETURN TRUE;
      ELSE
         CLOSE c_fcit;

         RETURN FALSE;
      END IF;
   END get_credit_fixed_charge_data;

   --
   ---------------------------------------------------------------------------
   FUNCTION get_package_category (
      p_package_type  IN  serv_package_types.type_code%TYPE
   )
      RETURN VARCHAR2 IS
      --
      CURSOR c_category IS
         SELECT CATEGORY
           FROM serv_package_types
          WHERE type_code = p_package_type;

      --
      l_category                    serv_package_types.CATEGORY%TYPE;
   BEGIN
      OPEN c_category;

      FETCH c_category
       INTO l_category;

      CLOSE c_category;

      --
      RETURN l_category;
   END get_package_category;

   ----------------------------------------------------------------------------------------
   PROCEDURE create_entries (
      p_success           IN OUT  BOOLEAN
     ,p_err_text          IN OUT  VARCHAR2
     ,p_invo_ref_num      IN      invoices.ref_num%TYPE
     ,p_fcit_type_code    IN      fixed_charge_item_types.type_code%TYPE
     ,p_taty_type_code    IN      fixed_charge_item_types.taty_type_code%TYPE
     ,p_billing_selector  IN      fixed_charge_item_types.billing_selector%TYPE
     ,p_charge_value      IN      NUMBER
     ,p_susg_ref_num      IN      subs_serv_groups.ref_num%TYPE
     ,p_num_of_days       IN      NUMBER
     ,p_module_ref        IN      invoice_entries.module_ref%TYPE DEFAULT 'U659'
     ,p_maas_ref_num      IN      master_account_services.ref_num%TYPE DEFAULT NULL
     ,p_cadc_ref_num      IN      invoice_entries.cadc_ref_num%TYPE DEFAULT NULL   -- UPR-3124
     ,p_fcdt_type_code    IN      invoice_entries.fcdt_type_code%TYPE DEFAULT NULL   -- UPR-3124
     ,p_add_entry_text    IN      invoice_entries.additional_entry_text%TYPE DEFAULT NULL  -- MOBE-425
   ) IS
      --
      CURSOR c_inen IS
         SELECT ref_num
               ,ROWID
           FROM invoice_entries
          WHERE invo_ref_num = p_invo_ref_num
            AND NVL (UPPER (fcit_type_code), '@?$') = NVL (p_fcit_type_code, '@?$')
            AND NVL (susg_ref_num, 0) = NVL (p_susg_ref_num, 0)
            AND NVL (maas_ref_num, 0) = NVL (p_maas_ref_num, 0)
            AND NVL (cadc_ref_num, 0) = NVL (p_cadc_ref_num, 0)
            AND NVL (fcdt_type_code, '@?$') = NVL (p_fcdt_type_code, '@?$')
            AND manual_entry = 'N';

      --
      l_inen_ref_num                NUMBER;
      l_inen_rowid                  VARCHAR2 (30);
   BEGIN
      --dbms_output.put_line('CREATE_ENTRIES '||to_char(p_num_of_days)||' inv_ref '||to_char(p_invo_ref_num)
      --||' fcit '||p_fcit_type_code||' susg '||to_char(p_susg_ref_num)||' billing_s '||p_billing_selector
      --||' num_days '||to_char(p_num_of_days));
         --
      OPEN c_inen;

      FETCH c_inen
       INTO l_inen_ref_num
           ,l_inen_rowid;

      CLOSE c_inen;

      --
      IF l_inen_ref_num IS NULL THEN
         -- dbms_output.put_line(' CREATE ENTRIES insert new inen ');
         INSERT INTO invoice_entries
                     (ref_num
                     ,invo_ref_num
                     ,acc_amount   -- CHG4594
                     ,rounding_indicator
                     ,under_dispute
                     ,created_by
                     ,date_created
                     ,billing_selector
                     ,fcit_type_code
                     ,taty_type_code
                     ,susg_ref_num
                     ,manual_entry
                     ,num_of_days
                     ,module_ref
                     ,maas_ref_num
                     ,cadc_ref_num
                     ,fcdt_type_code
                     ,pri_curr_code
                     ,additional_entry_text  -- MOBE-425
                     )
              VALUES (inen_ref_num_s.NEXTVAL
                     ,p_invo_ref_num
                     ,ROUND (p_charge_value, g_inen_acc_precision /* CHG4594 */)
                     ,'N'
                     ,'N'
                     ,sec.get_username
                     ,SYSDATE
                     ,p_billing_selector
                     ,p_fcit_type_code
                     ,p_taty_type_code
                     ,p_susg_ref_num
                     ,'N'
                     ,p_num_of_days
                     ,p_module_ref
                     ,p_maas_ref_num
                     ,p_cadc_ref_num
                     ,p_fcdt_type_code
                     ,get_pri_curr_code ()
                     ,p_add_entry_text  -- MOBE-425
                     )
           RETURNING ROWID
                INTO l_inen_rowid;   -- CHG-71
      ELSE
         IF p_num_of_days IS NOT NULL THEN
            -- dbms_output.put_line('CREATE ENTRIES update inen 1 '||  l_inen_ref_num);
            UPDATE invoice_entries
               SET acc_amount = ROUND (acc_amount + p_charge_value, g_inen_acc_precision)   -- CHG4594
                  ,num_of_days = NVL (num_of_days, 0) + p_num_of_days
             WHERE ROWID = l_inen_rowid;
         ELSE
            -- dbms_output.put_line('CREATE ENTRIES update inen 2 '||  l_inen_ref_num);
            UPDATE invoice_entries
               SET acc_amount = ROUND (acc_amount + p_charge_value, g_inen_acc_precision)   -- CHG4594
             WHERE ROWID = l_inen_rowid;
         END IF;
      END IF;

      --
      g_inen_rowid := l_inen_rowid;   -- CHG-71
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_err_text := SUBSTR (   'Create_Entries: SUSG='
                               || TO_CHAR (p_susg_ref_num)
                               || ', FCIT='
                               || p_fcit_type_code
                               || ', INVO='
                               || TO_CHAR (p_invo_ref_num)
                               || ': '
                               || SQLERRM
                              ,1
                              ,250
                              );
   END create_entries;
   
   -------------------------------------------------------------------------------------------
   PROCEDURE create_update_entry (
      p_inen_rec          IN OUT  invoice_entries%ROWTYPE
   ) IS
      --
      CURSOR c_inen_ref IS
         SELECT inen_ref_num_s.NEXTVAL
         FROM dual
      ;
      --
      CURSOR c_inen IS
         SELECT ref_num
               ,ROWID
         FROM invoice_entries
         WHERE invo_ref_num = p_inen_rec.invo_ref_num
           AND Nvl(susg_ref_num, 0)        = Nvl(p_inen_rec.susg_ref_num, 0)
           AND Nvl(fcit_type_code, '-1')   = Nvl(p_inen_rec.fcit_type_code, '-1')
           AND Nvl(billing_selector, '-1') = Nvl(p_inen_rec.billing_selector, '-1')
           AND Nvl(taty_type_code, '-1')   = Nvl(p_inen_rec.taty_type_code, '-1')
      ;
      --
      l_inen_ref_num                NUMBER;
      l_inen_rowid                  VARCHAR2 (30);
   BEGIN
      --
      OPEN  c_inen;
      FETCH c_inen INTO l_inen_ref_num
                      , l_inen_rowid;
      CLOSE c_inen;
      --
      IF l_inen_ref_num IS NULL THEN
         --
         OPEN  c_inen_ref;
         FETCH c_inen_ref INTO p_inen_rec.ref_num;
         CLOSE c_inen_ref;
         --
         INSERT INTO invoice_entries
                     (ref_num
                     ,invo_ref_num
                     ,acc_amount
                     ,rounding_indicator
                     ,under_dispute
                     ,created_by
                     ,date_created
                     ,billing_selector
                     ,fcit_type_code
                     ,taty_type_code
                     ,susg_ref_num
                     ,fixed_charge_value
                     ,evre_count
                     ,print_required
                     ,manual_entry
                     ,num_of_days
                     ,module_ref
                     ,maas_ref_num
                     ,cadc_ref_num
                     ,fcdt_type_code
                     ,pri_curr_code
                     )
              VALUES (p_inen_rec.ref_num
                     ,p_inen_rec.invo_ref_num
                     ,ROUND (p_inen_rec.acc_amount, g_inen_acc_precision /* CHG4594 */)
                     ,'N'
                     ,'N'
                     ,Nvl(p_inen_rec.created_by, sec.get_username)
                     ,SYSDATE
                     ,p_inen_rec.billing_selector
                     ,p_inen_rec.fcit_type_code
                     ,p_inen_rec.taty_type_code
                     ,p_inen_rec.susg_ref_num
                     ,p_inen_rec.fixed_charge_value
                     ,p_inen_rec.evre_count
                     ,p_inen_rec.print_required
                     ,'N'
                     ,p_inen_rec.num_of_days
                     ,p_inen_rec.module_ref
                     ,p_inen_rec.maas_ref_num
                     ,p_inen_rec.cadc_ref_num
                     ,p_inen_rec.fcdt_type_code
                     ,get_pri_curr_code ()
                     );
      ELSE
         --
         p_inen_rec.ref_num := l_inen_ref_num;
         --
         UPDATE invoice_entries
            SET acc_amount = acc_amount + ROUND (p_inen_rec.acc_amount, get_inen_acc_precision) 
              , fixed_charge_value = fixed_charge_value + ROUND (Nvl(p_inen_rec.fixed_charge_value, 0), 2)
              , evre_count = NVL (evre_count, 0) + 1
              , print_required = 'Y'
              , last_updated_by = sec.get_username
              , date_updated = SYSDATE
          WHERE ROWID = l_inen_rowid;
         --
      END IF;
      
   END create_update_entry;

   -------------------------------------------------------------------------------------------
   --start,end no trunc
   FUNCTION find_pack_days (
      p_start         DATE
     ,p_end           DATE
     ,p_susg_ref_num  NUMBER
     ,p_months_after  NUMBER
   )
      RETURN NUMBER IS
      CURSOR c_pack_stat (
         p_susg_ref_num  NUMBER
        ,p_start         DATE
        ,p_end           DATE
        ,p_tc_months     NUMBER
      ) IS
         SELECT   LEAST (DECODE (ssst.status_code, 'TC', (ADD_MONTHS (ssst.start_date, p_tc_months) - 1), p_end)
                        ,NVL (ssst.end_date, p_end)
                        ,p_end
                        ) end_date
                 ,GREATEST (ssst.start_date, p_start) start_date
                 ,ssst.status_code status_code
             FROM ssg_statuses ssst
            WHERE TRUNC (ssst.start_date) <= p_end   ----hh
              AND NVL (ssst.end_date, p_start) >= p_start
              AND ssst.status_code IN ('AC', 'TC')
              AND ssst.susg_ref_num = p_susg_ref_num
         ORDER BY ssst.start_date;

      l_prev_end                    DATE := TRUNC (TO_DATE (get_system_parameter (84), 'DD.MM.RRRR HH24:MI:SS'));
      l_max_start                   DATE;
      l_max_end                     DATE;
      l_num_days                    NUMBER := 0;
      l_tcp                         VARCHAR2 (2) := 'NO';
      l_tcpp                        VARCHAR2 (2) := 'NO';
      l_corr                        NUMBER := 0;
      l_first                       BOOLEAN := TRUE;
   BEGIN
      FOR rec IN c_pack_stat (p_susg_ref_num, p_start, p_end, p_months_after) LOOP
         IF l_first AND rec.status_code = 'TC' THEN
            l_first := FALSE;
            l_tcp := 'TC';
         ELSE
            IF rec.status_code = 'TC' AND l_tcp = 'AC' AND l_tcpp = 'TC' AND l_corr = 1 THEN
               l_num_days := l_num_days - 1;
               l_corr := 0;
            END IF;

            IF rec.status_code = 'TC' THEN
               l_tcpp := l_tcp;
               l_tcp := 'TC';
               l_corr := 0;
            ELSE
               l_tcpp := l_tcp;
               l_tcp := 'AC';
               l_corr := 0;
            END IF;

            IF TRUNC (rec.end_date) >= TRUNC (rec.start_date) THEN
               IF rec.end_date - rec.start_date < 0.5 THEN
                  l_corr := 1;
               ELSE
                  l_corr := 0;
               END IF;

               l_max_start := GREATEST (l_prev_end, TRUNC (rec.start_date) - 1);
               l_max_end := GREATEST (l_prev_end, TRUNC (rec.end_date));
               l_num_days := l_num_days + (l_max_end - l_max_start);
               l_prev_end := l_max_end;
            END IF;
         END IF;
      END LOOP;

      l_num_days := TO_NUMBER (GREATEST (l_num_days, 0));

      IF l_num_days > 99 THEN
         l_num_days := 62;
      END IF;

      RETURN l_num_days;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         RETURN -1;
   END find_pack_days;

   -------------------------------------------------------------------------------------
   PROCEDURE monthly_sept_charge (
      p_success         IN OUT  BOOLEAN
     ,p_err_text        IN OUT  VARCHAR2
     ,p_invo                    invoices%ROWTYPE
     ,p_invo_end_date           DATE
     ,p_end_day_num             NUMBER
     ,p_sept_type_code          subs_packages.sept_type_code%TYPE
     ,p_start_date              DATE
     ,p_end_date                DATE
     ,p_susg_ref_num            subs_serv_groups.ref_num%TYPE
     ,p_nety_type_code          subs_serv_groups.nety_type_code%TYPE
     ,p_pro_rata                fixed_charge_item_types.pro_rata%TYPE
     ,p_create_entry            VARCHAR2
     ,p_module_ref              invoice_entries.module_ref%TYPE
     ,p_maac_ref_num            accounts.ref_num%TYPE
     ,p_inen_tab        IN OUT  t_inen
     ,p_inen_sum_tab    IN OUT  t_inen_sum
   ) IS
      -- Modified_by  T.Hipeli  25.03.2002  upr 1991
      --* Kutsuda välja pärast Create_Entries protseduuri (kui see pole veaga lõppenud) protseduur
      --* Calculate_discounts.Find_MON_Discounts. Lisatud p_maac_ref_num, Muudetud sisendparameetrites
      --* p_invo_ref_num invoices.ref_num%TYPE -> p_invo INVOICES%TYPE
      ---paketi kuumaks tabelist fixed_charge_values
      CURSOR c_values_sept (
         p_sept_type_code  VARCHAR2
        ,p_end_date        DATE
        ,p_pro_rata        VARCHAR2 DEFAULT 'Y'
        ,p_start_date      DATE
      ) IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,fcit.future_period fcit_future_period
                 ,ficv.charge_value charge_value
                 ,GREATEST (ficv.start_date, p_start_date) start_date
                 ,LEAST (NVL (ficv.end_date, p_end_date), p_end_date) end_date
             FROM fixed_charge_values ficv, fixed_charge_item_types fcit
            WHERE ficv.sety_ref_num IS NULL
              AND ficv.sept_type_code = p_sept_type_code
              AND ficv.chca_type_code IS NULL
              AND ficv.channel_type IS NULL
              AND ficv.sepv_ref_num IS NULL
              AND ficv.par_value_charge IS NULL
              AND ficv.fcit_charge_code = fcit.type_code
              AND fcit.once_off = 'N'
              AND fcit.pro_rata = p_pro_rata
              AND fcit.regular_charge = 'Y'
              AND ficv.start_date <= p_end_date
              AND NVL (ficv.end_date, p_end_date) >= p_start_date
         ORDER BY ficv.start_date;

      l_start_value_date            DATE := NULL;
      l_end_value_date              DATE;
      l_pack_day                    NUMBER;
      l_charge_value                NUMBER;
      l_discount_type               VARCHAR2 (4);   -- upr 1991
      u_err_find_days               EXCEPTION;
      u_err_create_entries          EXCEPTION;
      u_err_find_mon_discount       EXCEPTION;   -- upr 1991
   BEGIN
      FOR rec_v IN c_values_sept (p_sept_type_code, p_invo_end_date, 'Y', p_start_date) LOOP
         --dbms_output.put_line('MON_SEPT: start '||to_char(rec_v.start_date)||' end '
         --||to_char(rec_v.end_date) || ' bil_sel ' || rec_v.billing_selector || ' fcit_type_code ' ||
         --rec_v.fcit_type_code);
         IF l_start_value_date IS NULL THEN
            IF rec_v.start_date > p_start_date THEN
                       ----hinda prli p_start_date kuni rec_v.start_date-1
               --  dbms_output.put_line('MON_SEPT: 1 :call monthly_prli_sept_charge');
               icalculate_fixed_charges.monthly_prli_sept_charge
                                                          (p_success   -- IN OUT BOOLEAN
                                                          ,p_err_text   -- IN OUT VARCHAR2
                                                          ,p_invo   --        INVOICES%ROWTYPE
                                                          ,p_end_day_num   --        NUMBER
                                                          ,p_sept_type_code   --        SUBS_PACKAGES.sept_type_code%TYPE
                                                          ,p_start_date   --        DATE
                                                          , rec_v.start_date - 1   --              DATE
                                                          ,p_susg_ref_num   --      SUBS_SERV_GROUPS.ref_num%TYPE
                                                          ,p_pro_rata   --      FIXED_CHARGE_ITEM_TYPES.pro_rata%TYPE
                                                          ,p_create_entry   --      VARCHAR2
                                                          ,p_module_ref   -- IN     INVOICE_ENTRIES.module_ref%TYPE
                                                          ,p_maac_ref_num   --      ACCOUNTS.ref_num%TYPE
                                                          ,p_inen_tab   -- IN OUT t_inen
                                                          ,p_inen_sum_tab   -- IN OUT t_inen_sum
                                                          );
            END IF;

            l_start_value_date := rec_v.start_date;
         ELSE
            IF TRUNC (rec_v.start_date) > TRUNC (l_end_value_date + 1) THEN
                   ----hinda prli l_end_value_date kuni rec_v.start_date-1( auk values-is)
               --dbms_output.put_line('MON_SEPT: 2 :call monthly_prli_sept_charge');
               icalculate_fixed_charges.monthly_prli_sept_charge (p_success
                                                                ,p_err_text
                                                                ,p_invo   -- upr 1991 p_invo_ref_num,
                                                                ,p_end_day_num
                                                                ,p_sept_type_code
                                                                , l_end_value_date + 1
                                                                , rec_v.start_date - 1
                                                                ,p_susg_ref_num
                                                                ,p_pro_rata
                                                                ,p_create_entry
                                                                ,p_module_ref
                                                                ,p_maac_ref_num   -- upr 1991
                                                                ,p_inen_tab   -- IN OUT t_inen
                                                                ,p_inen_sum_tab   -- IN OUT t_inen_sum
                                                                );
            END IF;
         END IF;

         --hinda nüüd leitud ficv rec_v.start_date kuni rec_v.end_date
         IF NVL (rec_v.charge_value, 0) > 0 THEN
            IF p_pro_rata = 'Y' THEN
               l_pack_day := find_pack_days (rec_v.start_date
                                            ,rec_v.end_date
                                            ,p_susg_ref_num
                                            ,NVL (rec_v.fcit_future_period, 0)
                                            );

               -- dbms_output.put_line('MON_SEPT: l_pack_day ' || l_pack_day);
               IF l_pack_day < 0 THEN
                  RAISE u_err_find_days;
               END IF;
            END IF;

            IF NVL (l_pack_day, 0) > 0 THEN
               IF p_pro_rata = 'Y' THEN
                  l_charge_value := rec_v.charge_value * l_pack_day / p_end_day_num;
               END IF;

               --dbms_output.put_line('MON_SEPT: paketi '||p_sept_type_code||' lõplik hind '||to_char(l_charge_value)
                --         ||' päevad '||to_char(l_pack_day)||' algus '||to_char(rec_v.start_date)
                 --        ||' lõpp '||to_char(rec_v.end_date));
               IF p_create_entry = 'B' THEN
                  /*
                    ** UPR-3124: Arverida kantakse PL/SQL tabelisse, et teostada võrdlus ÜKT-ga enne arvele kandmist.
                  */
                  add_invoice_entry (p_inen_tab   -- IN OUT t_inen
                                    ,p_inen_sum_tab   --- IN OUT t_inen_sum
                                    ,p_invo.ref_num   -- IN     invoices.ref_num%TYPE
                                    ,rec_v.fcit_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TYPE_CODE%TYPE
                                    ,rec_v.taty_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TATY_TYPE_CODE%TYPE
                                    ,rec_v.billing_selector   -- IN     FIXED_CHARGE_ITEM_TYPES.BILLING_SELECTOR%TYPE
                                    ,l_charge_value   -- IN     NUMBER
                                    ,p_susg_ref_num   -- IN     SUBS_SERV_GROUPS.ref_num%TYPE
                                    ,l_pack_day   -- IN     NUMBER
                                    ,p_module_ref   -- IN     invoice_entries.module_ref%TYPE
                                    ,NULL   -- IN     master_account_services.ref_num%TYPE
                                    ,p_sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                    ,rec_v.start_date   -- IN     DATE
                                    );
                  --  upr 1991  p_regular ja p_once_off väärtus c_values_sept kursorist

                  --DBMS_OUTPUT.PUT_LINE('MON_SEPT: call Calculate_discounts.Find_MON_Discounts ');
                  calculate_discounts.find_mon_discounts
                                 (calculate_discounts.c_discount_type_mon   --p_discount_type     VARCHAR2    mis siis????
                                 ,p_invo   --,p_invo              invoices%rowtype
                                 ,rec_v.fcit_type_code   --,p_fcit_type_code    VARCHAR2
                                 ,rec_v.billing_selector   --,p_billing_selector  VARCHAR2
                                 ,NULL   --,p_sety_ref_num      NUMBER
                                 ,NULL   --,p_sepa_ref_num      NUMBER
                                 ,NULL   --,p_sepv_ref_num      NUMBER
                                 ,p_sept_type_code   --,p_sept_type_code    VARCHAR2
                                 ,l_charge_value   --,p_charge_value      NUMBER
                                 ,l_pack_day   --,p_num_of_days       NUMBER
                                 ,p_susg_ref_num   --,p_susg_ref_num      NUMBER
                                 ,p_maac_ref_num   --,p_maac_ref_num      NUMBER
                                 ,p_start_date   --,p_start_date        DATE
                                 ,p_end_date   --,p_end_date          DATE
                                 ,p_end_day_num   --,p_day_num           NUMBER
                                 ,p_err_text   --,p_error_text   IN OUT VARCHAR2
                                 ,p_success   --,p_success      IN OUT BOOLEAN
                                 );

                  IF NOT p_success THEN
                     RAISE u_err_find_mon_discount;
                  END IF;
               END IF;

               --
               IF p_create_entry = 'I' THEN
                  close_interim_billing_invoice.cre_upd_interim_inen (p_success
                                                                     ,p_err_text
                                                                     ,p_invo.ref_num   -- upr 1991  ,p_invo_ref_num
                                                                     ,rec_v.fcit_type_code
                                                                     ,rec_v.billing_selector
                                                                     ,rec_v.taty_type_code
                                                                     ,l_charge_value
                                                                     ,l_pack_day
                                                                     ,p_susg_ref_num
                                                                     );

                  IF NOT p_success THEN
                     RAISE u_err_create_entries;
                  END IF;
               END IF;
            END IF;   --IF nvl(l_pack_day,0)>0
         END IF;   --IF nvl(rec_v.charge_value,0)>0

         ---hinnatud ficv
         l_end_value_date := rec_v.end_date;
      END LOOP;

      IF l_start_value_date IS NOT NULL THEN
         IF l_end_value_date < p_end_date THEN
                   --hinda prli l_end_value_date+1 kuni p_end_date
            --  dbms_output.put_line('MON_SEPT: 3 :call monthly_prli_sept_charge');
            icalculate_fixed_charges.monthly_prli_sept_charge (p_success
                                                             ,p_err_text
                                                             ,p_invo   -- uypr 1991 p_invo_ref_num  ,
                                                             ,p_end_day_num
                                                             ,p_sept_type_code
                                                             , l_end_value_date + 1   --start
                                                             ,p_end_date   --end
                                                             ,p_susg_ref_num
                                                             ,p_pro_rata
                                                             ,p_create_entry
                                                             ,p_module_ref
                                                             ,p_maac_ref_num   -- upr 1991
                                                             ,p_inen_tab   -- IN OUT t_inen
                                                             ,p_inen_sum_tab   -- IN OUT t_inen_sum
                                                             );
         END IF;
      ELSE
               --hinda prli p_start_date kuni p_end_date
         --  dbms_output.put_line('MON_SEPT: 4 :call monthly_prli_sept_charge');
         icalculate_fixed_charges.monthly_prli_sept_charge (p_success
                                                          ,p_err_text
                                                          ,p_invo   -- upr 1991 p_invo_ref_num,
                                                          ,p_end_day_num
                                                          ,p_sept_type_code
                                                          ,p_start_date   --start
                                                          ,p_end_date   --end
                                                          ,p_susg_ref_num
                                                          ,p_pro_rata
                                                          ,p_create_entry
                                                          ,p_module_ref
                                                          ,p_maac_ref_num   -- upr 1991
                                                          ,p_inen_tab   -- IN OUT t_inen
                                                          ,p_inen_sum_tab   -- IN OUT t_inen_sum
                                                          );
      END IF;
   EXCEPTION
      WHEN u_err_find_days THEN
         p_success := FALSE;
         p_err_text := (   'Find_Pack_Days= '
                        || TO_CHAR (p_susg_ref_num)
                        || ' SEPT= '
                        || p_sept_type_code
                        || ' Invo_ref_num= '
                        || TO_CHAR (p_invo.ref_num)
                       );
      WHEN u_err_create_entries THEN
         p_err_text := ('Monthly_Sept_Charge ' || p_err_text);
      WHEN u_err_find_mon_discount THEN
         p_success := FALSE;
         p_err_text := ('Monthly_Sept_Charge / Find_Mon_Discount ' || p_err_text);
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_err_text := (   'Monthly_Sept_Charge SUSG= '
                        || TO_CHAR (p_susg_ref_num)
                        || ' SEPT= '
                        || p_sept_type_code
                        || ' Invo_ref_num= '
                        || TO_CHAR (p_invo.ref_num)
                       );
   END monthly_sept_charge;

   -----------------------------------------------------------------------------
   PROCEDURE monthly_prli_sept_charge (
      p_success         IN OUT  BOOLEAN
     ,p_err_text        IN OUT  VARCHAR2
     ,p_invo                    invoices%ROWTYPE
     ,p_end_day_num             NUMBER
     ,p_sept_type_code          subs_packages.sept_type_code%TYPE
     ,p_start_date              DATE
     ,p_end_date                DATE
     ,p_susg_ref_num            subs_serv_groups.ref_num%TYPE
     ,p_pro_rata                fixed_charge_item_types.pro_rata%TYPE
     ,p_create_entry            VARCHAR2
     ,p_module_ref      IN      invoice_entries.module_ref%TYPE
     ,p_maac_ref_num            accounts.ref_num%TYPE
     ,p_inen_tab        IN OUT  t_inen
     ,p_inen_sum_tab    IN OUT  t_inen_sum
   ) IS
      -- Modified_by  T.Hipeli  19.03.2002  upr 1991
      -- Kutsuda välja pärast Create_Entries protseduuri (kui see pole veaga lõppenud) protseduur
      -- Calculate_discounts.Find_MON_Discounts. Lisatud p_maac_ref_num. Muudetud sisendparameetreid
      -- p_invo_ref_num       INVOICES.ref_num%TYPE -> p_invo               INVOICES%ROWTYPE
      --teenuse hinnad tabelist price_lists
      CURSOR c_prices_cat (
         p_package_category  IN  VARCHAR2
        ,p_nety_type_code    IN  VARCHAR2
        ,p_end_date          IN  DATE
        ,p_start_date        IN  DATE
        ,p_pro_rata              VARCHAR2 DEFAULT 'Y'
      ) IS
         SELECT fcit.type_code fcit_type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,fcit.future_period fcit_future_period
               ,prli.charge_value charge_value
               ,GREATEST (prli.start_date, p_start_date) start_date
               ,LEAST (NVL (prli.end_date, p_end_date), p_end_date) end_date
           FROM price_lists prli, fixed_charge_item_types fcit
          WHERE prli.sety_ref_num IS NULL
            AND prli.package_category = p_package_category
            AND prli.nety_type_code = p_nety_type_code
            AND prli.channel_type IS NULL
            AND prli.sepv_ref_num IS NULL
            AND prli.par_value_charge IS NULL
            AND prli.once_off = 'N'
            AND prli.pro_rata = p_pro_rata
            AND prli.regular_charge = 'Y'
            AND fcit.once_off = 'N'
            AND fcit.pro_rata = p_pro_rata
            AND fcit.regular_charge = 'Y'
            AND prli.package_category = fcit.prli_package_category
            AND prli.start_date <= p_end_date
            AND NVL (prli.end_date, p_end_date) >= p_start_date;

      CURSOR c_package_category (
         p_sept_type_code  VARCHAR2
      ) IS
         SELECT CATEGORY
               ,nety_type_code
           FROM serv_package_types
          WHERE type_code = p_sept_type_code;

      l_pack_day                    NUMBER;
      l_charge_value                NUMBER;
      l_discount_type               VARCHAR2 (4);   --upr 1991
      l_package_category            price_lists.package_category%TYPE;
      l_nety_type_code              serv_package_types.nety_type_code%TYPE;
      u_err_find_days               EXCEPTION;
      u_err_create_entries          EXCEPTION;
      u_err_find_mon_discount       EXCEPTION;
   BEGIN
      OPEN c_package_category (p_sept_type_code);

      FETCH c_package_category
       INTO l_package_category
           ,l_nety_type_code;

      CLOSE c_package_category;

      FOR rec_p IN c_prices_cat (l_package_category, l_nety_type_code, p_end_date, p_start_date, p_pro_rata) LOOP
         -- dbms_output.put_line('MON_PRLI_SEPT: category '||l_package_category|| ' nety ' || l_nety_type_code||
           -- ' start '||to_char(rec_p.start_date)||' end '||to_char(rec_p.end_date)||
           -- ' hind '||to_char(rec_p.charge_value));
         IF NVL (rec_p.charge_value, 0) > 0 THEN
            IF p_pro_rata = 'Y' THEN
               l_pack_day := find_pack_days (rec_p.start_date
                                            ,rec_p.end_date
                                            ,p_susg_ref_num
                                            ,NVL (rec_p.fcit_future_period, 0)
                                            );

               --  dbms_output.put_line('MON_PRLI_SEPT: l_pack_day '|| l_pack_day);
               IF l_pack_day < 0 THEN
                  RAISE u_err_find_days;
               END IF;
            END IF;

            IF NVL (l_pack_day, 0) > 0 THEN
               IF p_pro_rata = 'Y' THEN
                  l_charge_value := rec_p.charge_value * l_pack_day / p_end_day_num;
               END IF;

               -- dbms_output.put_line('MON_PRLI_SEPT: paketi '||p_sept_type_code||' prli lõplik hind '||to_char(l_charge_value)
                --                ||' päevad '||to_char(l_pack_day)||' ');
                --
               IF p_create_entry = 'B' THEN
                  /*
                    ** UPR-3124: Arverida kantakse PL/SQL tabelisse, et teostada võrdlus ÜKT-ga enne arvele kandmist.
                  */
                  add_invoice_entry (p_inen_tab   -- IN OUT t_inen
                                    ,p_inen_sum_tab   -- IN OUT t_inen_sum
                                    ,p_invo.ref_num   -- IN     invoices.ref_num%TYPE
                                    ,rec_p.fcit_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TYPE_CODE%TYPE
                                    ,rec_p.taty_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TATY_TYPE_CODE%TYPE
                                    ,rec_p.billing_selector   -- IN     FIXED_CHARGE_ITEM_TYPES.BILLING_SELECTOR%TYPE
                                    ,l_charge_value   -- IN     NUMBER
                                    ,p_susg_ref_num   -- IN     SUBS_SERV_GROUPS.ref_num%TYPE
                                    ,l_pack_day   -- p_num_of_days IN     NUMBER
                                    ,p_module_ref   -- IN     invoice_entries.module_ref%TYPE
                                    ,NULL   -- IN     master_account_services.ref_num%TYPE
                                    ,p_sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                    ,rec_p.start_date   -- IN     DATE
                                    );
                  --   dbms_output.put_line(' MON_PRLI_SEPT: call Calculate_Discounts.Find_MON_Discounts');
                  calculate_discounts.find_mon_discounts
                                                 (calculate_discounts.c_discount_type_mon   --p_discount_type     VARCHAR2
                                                 ,p_invo   --,p_invo              invoices%rowtype
                                                 ,rec_p.fcit_type_code   --,p_fcit_type_code    VARCHAR2
                                                 ,rec_p.billing_selector   --,p_billing_selector  VARCHAR2
                                                 ,NULL   --,p_sety_ref_num      NUMBER
                                                 ,NULL   --,p_sepa_ref_num      NUMBER
                                                 ,NULL   --,p_sepv_ref_num      NUMBER
                                                 ,p_sept_type_code   --,p_sept_type_code    VARCHAR2
                                                 ,l_charge_value   --,p_charge_value      NUMBER
                                                 ,l_pack_day   --,p_num_of_days       NUMBER
                                                 ,p_susg_ref_num   --,p_susg_ref_num      NUMBER
                                                 ,p_maac_ref_num   --,p_maac_ref_num      NUMBER
                                                 ,rec_p.start_date   --,p_start_date        DATE
                                                 ,rec_p.end_date   --,p_end_date          DATE
                                                 ,p_end_day_num   --,p_day_num           NUMBER
                                                 ,p_err_text   --,p_error_text   IN OUT VARCHAR2
                                                 ,p_success   --,p_success      IN OUT BOOLEAN
                                                 );

                  IF NOT p_success THEN
                     RAISE u_err_find_mon_discount;
                  END IF;
               END IF;

               --
               IF p_create_entry = 'I' THEN
                  close_interim_billing_invoice.cre_upd_interim_inen (p_success
                                                                     ,p_err_text
                                                                     ,p_invo.ref_num   -- upr 199 ,p_invo_ref_num
                                                                     ,rec_p.fcit_type_code
                                                                     ,rec_p.billing_selector
                                                                     ,rec_p.taty_type_code
                                                                     ,l_charge_value
                                                                     ,l_pack_day
                                                                     ,p_susg_ref_num
                                                                     );

                  IF NOT p_success THEN
                     RAISE u_err_create_entries;
                  END IF;
               END IF;
            END IF;
         END IF;
      END LOOP;
   EXCEPTION
      WHEN u_err_find_days THEN
         p_success := FALSE;
         p_err_text := (   'Find_Pack_Days= '
                        || TO_CHAR (p_susg_ref_num)
                        || ' SEPT= '
                        || p_sept_type_code
                        || ' Invo_ref_num= '
                        || TO_CHAR (p_invo.ref_num)
                       );
      WHEN u_err_create_entries THEN
         p_err_text := ('Monthly_PRLI_Sept_Charge ' || p_err_text);
      WHEN u_err_find_mon_discount THEN
         p_success := FALSE;
         p_err_text := ('Monthly_PRLI_Sept_Charge /Find_mon_disount' || p_err_text);
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_err_text := (   'Monthly_PRLI_Sept_Charge SUSG= '
                        || TO_CHAR (p_susg_ref_num)
                        || ' SEPT= '
                        || p_sept_type_code
                        || ' Invo_ref_num= '
                        || TO_CHAR (p_invo.ref_num)
                        || SQLERRM
                       );
   END monthly_prli_sept_charge;

   ------------------------------------------------------------------------------------
   PROCEDURE get_num_of_days (
      p_invo_start_date  IN      DATE
     ,p_invo_end_date    IN      DATE
     ,p_susg_ref_num     IN      NUMBER
     ,p_sety_ref_num     IN      NUMBER
     ,p_sepa_ref_num     IN      NUMBER
     ,p_sepv_ref_num     IN      NUMBER
     ,p_months_after     IN      NUMBER
     ,p_days_param       OUT     NUMBER
     ,p_success          OUT     BOOLEAN
   ) IS
      --REEGEL: 07.12.2001 Päev hinnatakse selle parameetri järgi, mis oli päeva alguses või
      --mida võeti esimesena. Pärast parameetri hindamise vahemiku kindlakstegemist vaadata,
      --mitu päeva oli mobiil selles vahemikus aktiivne.
      CURSOR c_sepv_periods (
         p_susg_ref_num  NUMBER
        ,p_sety_ref_num  NUMBER
        ,p_invo_start    DATE
        ,p_invo_end      DATE
        ,p_tc_months     NUMBER
      ) IS   -- ei kasutata
         SELECT   TRUNC (LEAST (NVL (end_date, p_invo_end), p_invo_end)) end_date
                 ,TRUNC (GREATEST (start_date, p_invo_start)) start_date
                 ,sepv_ref_num
             FROM subs_service_parameters
            WHERE TRUNC (start_date) <= p_invo_end   --hh
              AND NVL (end_date, p_invo_start) >= p_invo_start
              AND susg_ref_num = p_susg_ref_num
              AND sety_ref_num = p_sety_ref_num
              AND sepa_ref_num = p_sepa_ref_num
         ORDER BY start_date;

      l_start                       DATE;
      l_end                         DATE;
      l_start1                      DATE;
      l_end1                        DATE;
      l_num_days                    NUMBER := 0;
      l_num                         NUMBER := 0;
      l_sepv                        NUMBER;
      l_sepv1                       NUMBER;
      l_ting                        DATE;
      i                             NUMBER := 1;
      l_abi                         DATE;
   BEGIN
      FOR rec IN c_sepv_periods (p_susg_ref_num, p_sety_ref_num, p_invo_start_date, p_invo_end_date, p_months_after) LOOP
         IF i = 1 THEN
            l_sepv1 := rec.sepv_ref_num;
            l_start1 := rec.start_date;
            l_end1 := rec.end_date;

            IF l_sepv1 <> p_sepv_ref_num THEN
               l_ting := l_end1 + 1;
               l_start1 := NULL;
            ELSE
               IF NVL (l_ting, l_end1) <= l_end1 THEN
                  l_start1 := GREATEST (NVL (l_ting, l_start1), l_start1);
                  i := 0;
               ELSE
                  l_start1 := NULL;
               END IF;
            END IF;
         ELSE
            l_sepv := rec.sepv_ref_num;
            l_start := GREATEST (NVL (l_ting, rec.start_date), rec.start_date);
            l_end := rec.end_date;

            IF l_end = l_end1 THEN
               l_start := NULL;
            ELSE
               IF l_sepv = p_sepv_ref_num THEN
                  IF l_start = l_start1 THEN
                     l_end1 := l_end;
                     l_start := NULL;
                     i := 0;
                  ELSE
                     l_num := icalculate_fixed_charges.find_pack_days (l_start1
                                                                     ,TO_DATE (   TO_CHAR (l_end1, 'dd.mm.yyyy')
                                                                               || ' 23:59:59'
                                                                              ,'dd.mm.yyyy hh24:mi:ss'
                                                                              )
                                                                     ,p_susg_ref_num
                                                                     ,p_months_after
                                                                     );
                     l_num_days := l_num_days + NVL (l_num, 0);
                     l_ting := l_end1 + 1;
                     l_end1 := l_end;
                     l_start1 := l_start;
                     l_start := NULL;
                  END IF;
               ELSE   -- sepv<>
                  l_num := icalculate_fixed_charges.find_pack_days (l_start1
                                                                  ,TO_DATE (TO_CHAR (l_end1, 'dd.mm.yyyy')
                                                                            || ' 23:59:59'
                                                                           ,'dd.mm.yyyy hh24:mi:ss'
                                                                           )
                                                                  ,p_susg_ref_num
                                                                  ,p_months_after
                                                                  );
                  l_num_days := l_num_days + NVL (l_num, 0);
                  i := 1;
                  l_start := NULL;
                  l_start1 := NULL;
                  l_ting := l_end1 + 1;
               END IF;
            END IF;
         END IF;
      END LOOP;

      IF l_start1 IS NOT NULL AND l_sepv1 = p_sepv_ref_num THEN
         l_abi := GREATEST (l_start1, NVL (l_ting, l_start1));
         l_num := icalculate_fixed_charges.find_pack_days (l_abi
                                                         ,TO_DATE (TO_CHAR (l_end1, 'dd.mm.yyyy') || ' 23:59:59'
                                                                  ,'dd.mm.yyyy hh24:mi:ss'
                                                                  )
                                                         ,p_susg_ref_num
                                                         ,p_months_after
                                                         );
         l_num_days := l_num_days + NVL (l_num, 0);
      END IF;

      IF l_start IS NOT NULL AND l_sepv = p_sepv_ref_num THEN
         l_num := icalculate_fixed_charges.find_pack_days (l_abi
                                                         ,TO_DATE (TO_CHAR (l_end, 'dd.mm.yyyy') || ' 23:59:59'
                                                                  ,'dd.mm.yyyy hh24:mi:ss'
                                                                  )
                                                         ,p_susg_ref_num
                                                         ,p_months_after
                                                         );
         l_num_days := l_num_days + NVL (l_num, 0);
      END IF;

      --dbms_output.put_line(to_char(l_num)||' sain lõpus '||to_char(l_num_days));
       --dbms_output.put_line('Väljun päevade arvuga FIND_Num_Of_Days: ' || To_Char(l_num_days));
      IF l_num_days > 99 THEN
         l_num_days := 62;
      END IF;

      p_days_param := GREATEST (l_num_days, 0);
      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_days_param := -1;
   END get_num_of_days;

   ----------------------------------------------------------------------------------
   FUNCTION find_num_of_days (
      p_invo_start    DATE
     ,p_invo_end      DATE
     ,p_susg_ref_num  NUMBER
     ,p_sety_ref_num  NUMBER
     ,p_months_after  NUMBER
   )
      RETURN NUMBER IS
      --
      CURSOR c_stat_periods (
         p_susg_ref_num  NUMBER
        ,p_sety_ref_num  NUMBER
        ,p_tc_months     NUMBER
      ) IS
         SELECT   TRUNC (LEAST (NVL (stpe.end_date, p_invo_end), p_invo_end)) end_date
                 ,TRUNC (GREATEST (stpe.start_date, p_invo_start)) start_date
             FROM status_periods stpe
            WHERE TRUNC (stpe.start_date) <= p_invo_end   --hh
              AND NVL (stpe.end_date, p_invo_start) >= p_invo_start
              AND stpe.susg_ref_num = p_susg_ref_num
              AND stpe.sety_ref_num = p_sety_ref_num
         ORDER BY stpe.start_date;

      -- CHG-2795
      CURSOR c_tc_dates (
         p_susg_ref_num  NUMBER
        ,p_sety_ref_num  NUMBER
        ,p_start_date    DATE
        ,p_end_date      DATE
      ) IS
         SELECT   tcsp.start_date - c_one_second AS start_date
                 , NVL (tcsp.end_date, p_end_date) + c_one_second AS end_date
                 ,1 AS tcsp_exists
             FROM tc_status_periods tcsp
            WHERE TRUNC (tcsp.start_date) <= TRUNC (p_end_date)
              AND NVL (TRUNC (tcsp.end_date), TRUNC (p_end_date)) >= TRUNC (p_start_date)
              AND susg_ref_num = p_susg_ref_num
              AND sety_ref_num = p_sety_ref_num
         UNION ALL
         SELECT   ssg.start_date - c_one_second AS start_date
                 , NVL (ssg.end_date, p_end_date) + c_one_second AS end_date
                 ,NULL AS tcsp_exists
             FROM ssg_statuses ssg
            WHERE ssg.status_code = 'TC'
              AND TRUNC (ssg.start_date) <= TRUNC (p_end_date)
              AND NVL (TRUNC (ssg.end_date), TRUNC (p_end_date)) > TRUNC (p_start_date)
              AND susg_ref_num = p_susg_ref_num
         ORDER BY tcsp_exists;

      --
      l_sety_start_tab              t_date;   -- CHG-2795
      l_sety_end_tab                t_date;   -- CHG-2795
      l_start_date_tab              t_date;   -- CHG-2795
      l_end_date_tab                t_date;   -- CHG-2795
      l_tcsp_chk_tab                t_number;   -- CHG-2795
      l_chk_date                    DATE;   -- CHG-2795
      l_prev_date                   DATE;   -- CHG-2795
      l_prev_end_date               DATE;   -- CHG-2795
      l_sety_idx                    NUMBER;   -- CHG-2795
      l_idx                         NUMBER;   -- CHG-2795
      l_tc_count                    NUMBER;   -- CHG-2795
      l_sety_opened                 BOOLEAN;   -- CHG-2795
      l_tc_stpe_exists              BOOLEAN;   -- CHG-2795
      l_start_date                  DATE;   -- CHG-2795
      l_end_date                    DATE;   -- CHG-2795
      --
      l_start                       DATE;
      l_end                         DATE;
      l_start_1                     DATE;
      l_end_1                       DATE;
      l_num_days                    NUMBER := 0;
      l_num                         NUMBER := 0;
   BEGIN
      l_start_date := p_invo_start;
      l_end_date := TO_DATE (TRUNC (p_invo_end) || ' 23:59:59', 'dd.mm.yy hh24:mi:ss');
      l_chk_date := TRUNC (p_invo_start);
      l_tc_count := 0;

      OPEN c_tc_dates (p_susg_ref_num, p_sety_ref_num, l_start_date, l_end_date);

      FETCH c_tc_dates
      BULK COLLECT INTO l_start_date_tab
            ,l_end_date_tab
            ,l_tcsp_chk_tab;

      CLOSE c_tc_dates;

      IF l_tcsp_chk_tab.EXISTS (1) THEN
         IF l_tcsp_chk_tab (1) = 1 THEN
            l_tc_stpe_exists := TRUE;
         ELSE
            l_tc_stpe_exists := FALSE;
         END IF;
      ELSE
         l_tc_stpe_exists := FALSE;
      END IF;

      IF l_tc_stpe_exists THEN
         -- Leiame, kas teenus on olnud avatud antud perioodis ning kogume perioodid PL/SQL tabelisse
         OPEN c_stat_periods (p_susg_ref_num, p_sety_ref_num, p_months_after);

         FETCH c_stat_periods
         BULK COLLECT INTO l_sety_end_tab
               ,l_sety_start_tab;

         CLOSE c_stat_periods;

         IF l_sety_start_tab.EXISTS (1) THEN
            NULL;
         ELSE
            -- Teenus pole antud arveldusperioodis aktiivne olnud, tagastame 0 päeva.
            RETURN 0;
         END IF;

         -- Teenus on olnud arveldusperioodi vahemikus TC staatuses
         WHILE l_chk_date <= TRUNC (p_invo_end) LOOP
            -- Käime läbi arveldusperioodi päevade kaupa, et leida, kas teenus
            -- või mobiil on olnud suletud terve ööpäeva. Kui teenus/mobiil on
            -- olnud avatud vähemalt 1 sekund, siis ei suuredata TC päevade loendit.

            -- Kontrollime, kas teenus on olnud avatud antud ajahetkel
            l_sety_idx := l_sety_start_tab.FIRST;
            l_sety_opened := FALSE;

            WHILE l_sety_idx IS NOT NULL LOOP
               IF l_sety_start_tab (l_sety_idx) <= l_chk_date AND l_sety_end_tab (l_sety_idx) >= l_chk_date THEN
                  l_sety_opened := TRUE;
               END IF;

               l_sety_idx := l_sety_start_tab.NEXT (l_sety_idx);
            END LOOP;

            IF l_sety_opened THEN
               -- Käime läbi teenuse TC staatused ja mobiili SSG staatused
               l_idx := l_start_date_tab.FIRST;

               WHILE l_idx IS NOT NULL LOOP
                  IF    TRUNC (l_start_date_tab (l_idx)) < l_chk_date AND TRUNC (l_end_date_tab (l_idx)) > l_chk_date
                     OR     l_prev_end_date IS NOT NULL
                        AND l_prev_end_date = l_start_date_tab (l_idx) + c_one_second
                        AND TRUNC (l_start_date_tab (l_idx)) = l_chk_date THEN
                     IF l_prev_date IS NULL OR l_prev_date <> l_chk_date THEN
                        -- Teenus või mobiil on olnud suletud täis päeva,
                        -- suurendame TC päevade loendit.
                        l_prev_date := l_chk_date;
                        l_tc_count := l_tc_count + 1;
                     --
                     END IF;
                  END IF;

                  l_prev_end_date := l_end_date_tab (l_idx);
                  l_idx := l_start_date_tab.NEXT (l_idx);
               END LOOP;
            ELSE
               l_tc_count := l_tc_count + 1;
            END IF;

            l_chk_date := l_chk_date + 1;
         END LOOP;

         --         -- Leida SSG staatuse päevade arv, kus TC staatusele järgneb uuesti TC staatus

         -- Leida teenuse päevade arv
         l_num_days := TRUNC (p_invo_end) - TRUNC (p_invo_start) + 1;
         -- Leida teenuse maksustatavate päevade arv
         l_num_days := GREATEST (l_num_days - l_tc_count, 0);
      ELSE
         -- Teenusel puudub arveldusperioodi vahemikus TC staatus
         FOR rec IN c_stat_periods (p_susg_ref_num, p_sety_ref_num, p_months_after) LOOP
            IF l_start_1 IS NULL THEN
               l_end_1 := rec.end_date;
               l_start_1 := rec.start_date;
            ELSE
               l_end := rec.end_date;
               l_start := rec.start_date;

               IF TRUNC (l_start) <> TRUNC (l_start_1) THEN
                  IF l_end_1 = l_start THEN
                     l_end_1 := l_end_1 - 1;
                  END IF;

                  l_num := icalculate_fixed_charges.find_pack_days (l_start_1
                                                                  ,TO_DATE (   TO_CHAR (l_end_1, 'dd.mm.yyyy')
                                                                            || ' 23:59:59'
                                                                           ,'dd.mm.yyyy hh24:mi:ss'
                                                                           )
                                                                  ,p_susg_ref_num
                                                                  ,p_months_after
                                                                  );
                  l_num_days := l_num_days + NVL (l_num, 0);
                  l_start_1 := l_start;
                  l_end_1 := l_end;
               ELSE
                  l_end_1 := l_end;
               END IF;
            END IF;
         END LOOP;

         IF l_end_1 = l_start THEN
            l_end_1 := l_end_1 - 1;
         END IF;

         IF l_start_1 IS NOT NULL THEN
            l_num := icalculate_fixed_charges.find_pack_days (l_start_1
                                                            ,TO_DATE (TO_CHAR (l_end_1, 'dd.mm.yyyy') || ' 23:59:59'
                                                                     ,'dd.mm.yyyy hh24:mi:ss'
                                                                     )
                                                            ,p_susg_ref_num
                                                            ,p_months_after
                                                            );
            l_num_days := l_num_days + NVL (l_num, 0);
         END IF;
      --
      END IF;   -- CHG-2795

      --dbms_output.put_line('Väljun päevade arvuga FIND_Num_Of_Days: ' || To_Char(l_num_days));
      IF l_num_days > 99 THEN
         l_num_days := 62;
      END IF;

      RETURN GREATEST (l_num_days, 0);
   EXCEPTION
      WHEN OTHERS THEN
         RETURN -1;
   END find_num_of_days;
   
   ----------------------------------------------------------------------------------
   -- AVL-49: Funktsioon tagastab teenuse kasutuse päevade arvu, millele on FCIT-is defineeritud future_period ja free_periods
   ----------------------------------------------------------------------------------
  FUNCTION find_avl_num_days (p_susg_ref_num    IN  NUMBER
                              ,p_sety_ref_num    IN  NUMBER
                              ,p_prli_start_date IN  DATE
                              ,p_prli_end_date   IN  DATE
                              ,p_future_period   IN  NUMBER
                              ,p_free_periods    IN  NUMBER
   ) RETURN NUMBER IS
   
    CURSOR c_stpe IS
              
      select start_date, 
           nvl(end_date,p_prli_end_date)  end_date
      from status_periods
     where sety_ref_num=p_sety_ref_num
       and susg_ref_num=p_susg_ref_num
       and nvl(end_date, sysdate) > p_prli_start_date-p_future_period*30 
     order by start_date 
      ;
      
      
 Cursor c_max_start_date (p_susg        number, 
                           p_sety_ref_num number
                           ) is
    select max(start_date) 
      from status_periods
     where sety_ref_num=p_sety_ref_num
       and susg_ref_num=p_susg
;
      --
     
      l_curr_stpe_rec    status_periods%ROWTYPE;
      l_prev_stpe_rec    status_periods%ROWTYPE;
      l_soodustus_saadud      varchar2(3):='';
      l_num_of_days           number:=0;
      l_max_start_date   date;
      l_free_end_date    DATE;
      --
     
   BEGIN
      --
      
   --   dbms_output.enable(100000);
 
      
   l_max_start_date:=null;
   Open c_max_start_date(p_susg_ref_num, p_sety_ref_num);
   Fetch c_max_start_date into l_max_start_date;
   close c_max_start_date;

   
   l_soodustus_saadud:='EI';
      
      -- Leiame STPE kirjed - uuemad eespool
      FOR rec IN c_stpe LOOP
               --
       if rec.end_date-rec.start_date > 0 then 

    if rec.start_date+p_future_period*30-1 <= l_max_start_date then -- TC üle 360 vana
    
        if rec.end_date>=p_prli_start_date THEN --üle aasta kinni, kõik maksu alla
           l_soodustus_saadud:='JAH'; --start+90 loppes soodustus, minevik
           l_num_of_days:=l_num_of_days+ 
                          rec.end_date -p_prli_start_date;      
        end if; 
           
    else -- start_date+360 > l_max_start_date 
   
        if rec.end_date < p_prli_start_date THEN   
           l_soodustus_saadud:='JAH'; -- periood läbi
        else --end_date>=l_salp_start_date 
          
             if  l_soodustus_saadud='JAH' THEN   
                 l_num_of_days:=l_num_of_days+ 
                                rec.end_date-
                                greatest(rec.start_date, p_prli_start_date);    
             else      
                 l_num_of_days:=l_num_of_days+  
                                greatest((rec.end_date-
                                greatest(rec.start_date+p_free_periods*30,
                                         p_prli_start_date)),0);
                  l_soodustus_saadud:='JAH'; -- soodustus võib edasi kesta
             end if;   
        end if;--end_date>=l_salp_start_date   
    end if; ---- TC  vana vanus
 end if;

   -- DBMS_OUTPUT.Put_Line(to_char(l_num_of_days) ); 
end loop;
     
      -- Ümardame täisarvuks - alla poole päeva aktiivse teenuse eest tasu ei võeta.
      l_num_of_days := Round(nvl(l_num_of_days, 0));
      --
     -- DBMS_OUTPUT.Put_Line(to_char(l_num_of_days) ); 
     RETURN l_num_of_days;
   END find_avl_num_days;
   --------------------------------------------------------------------------------------mmmmmmm

   ------------------------------------
   ----------------------------------------------------------------------------------
   PROCEDURE main_master_service_charges (
      p_maac_ref_num  IN             NUMBER
     ,p_invo_details  IN OUT NOCOPY  invoices%ROWTYPE
     ,p_success       IN OUT         BOOLEAN
     ,p_error_text    IN OUT         VARCHAR2
     ,p_period_start  IN             DATE
     ,p_period_end    IN             DATE
     ,p_inv_entry     IN             VARCHAR2 DEFAULT 'B'
     ,p_main_bill     IN             BOOLEAN DEFAULT FALSE
   ) IS
      --
      CURSOR c_chca (p_maac_ref_num  NUMBER
             ,p_start         DATE
             ,p_end           DATE
      ) IS
         SELECT DISTINCT TRUNC ((GREATEST (macc.start_date, p_start))) start_date
                        ,TRUNC (LEAST (NVL (macc.end_date, p_end), p_end)) end_date   -- ilma 23:59:59
                        ,macc.chca_type_code
         FROM maac_charging_categories macc
         WHERE macc.maac_ref_num = p_maac_ref_num
           AND macc.start_date <= p_end
           AND NVL (macc.end_date, p_end) >= p_start
         ORDER BY start_date, end_date
      ;
      --
      CURSOR c_maas (p_maac_ref_num  NUMBER
                    ,p_start         DATE
                    ,p_end           DATE
      ) IS
         SELECT DISTINCT maas.ref_num
                        ,maas.sety_ref_num
                        ,TRUNC ((GREATEST (maas.start_date, p_start))) start_date
                        ,TRUNC (LEAST (NVL (maas.end_date, p_end), p_end)) end_date   -- ilma 23:59:59
         FROM master_account_services maas
         WHERE maas.maac_ref_num = p_maac_ref_num
           AND maas.start_date <= p_end
           AND NVL (maas.end_date, p_end) >= p_start
           AND EXISTS (SELECT 1
                       FROM tbcis.emt_bill_price_list a
                       WHERE a.sety_ref_num = maas.sety_ref_num
                         AND a.what = 'Konto teenused'
                         AND a.start_date <= p_end
                         AND NVL (a.end_date, p_end) >= p_start
                         AND a.chargeable = 'Y'
                         AND a.fcty_type = 'MCH'
                         AND ROWNUM = 1)
         ORDER BY sety_ref_num, start_date, end_date
      ;
      -- CHG-13407
      CURSOR c_sety (p_sety_ref_num  NUMBER) IS
         SELECT *
         FROM service_types
         WHERE ref_num = p_sety_ref_num
      ;
      -- CHG-13407
      CURSOR c_masp (p_maas_ref_num  NUMBER
                    ,p_start         DATE
                    ,p_end           DATE
      ) IS
         SELECT masp.param_value
         FROM master_service_parameters masp
            , service_parameters        sepa
         WHERE masp.maas_ref_num = p_maas_ref_num
           AND sepa.nw_param_name = 'GROUP_ID'
           AND masp.sepa_ref_num = sepa.ref_num
           AND masp.start_date <= p_end
           AND NVL (masp.end_date, p_end) >= p_start
           AND sepa.start_date <= p_end
           AND NVL (sepa.end_date, p_end) >= p_start
      ;
      -- CHG-13407
      CURSOR c_ac_susgs (p_sety_ref_num  NUMBER
                        ,p_group_id      VARCHAR2
                        ,p_start         DATE
                        ,p_end           DATE
      ) IS
         SELECT 1
         FROM ssg_statuses             ssst
            , service_parameters       sepa
            , subs_service_parameters  susp
         WHERE ssst.susg_ref_num = susp.susg_ref_num
           AND susp.sety_ref_num IN (select sety_ref_num_valid
                                     from valid_serv_combs
                                     where sety_ref_num = p_sety_ref_num
                                       and condition_type = 'J')
           AND sepa.sety_ref_num = susp.sety_ref_num
           AND susp.sepa_ref_num = sepa.ref_num
           AND sepa.nw_param_name = 'GROUP_ID'
           AND susp.param_value = p_group_id
           AND ssst.status_code = 'AC'
           AND ssst.start_date <= p_end
           AND Nvl(ssst.end_date, p_end) >= p_start
           AND susp.start_date <= p_end
           AND Nvl(susp.end_date, p_end) >= p_start
           AND ssst.start_date <= Nvl(susp.end_date, p_end)
           AND Nvl(ssst.end_date, p_end) >= susp.start_date           
      ;
      -- CHG-13407
      CURSOR c_first_susp (p_sety_ref_num  NUMBER
                          ,p_group_id      VARCHAR2
      ) IS
         SELECT susp.start_date
         FROM service_parameters       sepa
            , subs_service_parameters  susp
         WHERE susp.sety_ref_num IN (select sety_ref_num_valid
                                     from valid_serv_combs
                                     where sety_ref_num = p_sety_ref_num
                                       and condition_type = 'J')
           AND sepa.sety_ref_num = susp.sety_ref_num
           AND susp.sepa_ref_num = sepa.ref_num
           AND sepa.nw_param_name = 'GROUP_ID'
           AND susp.param_value = p_group_id
         ORDER BY susp.start_date
      ;
      -- SFILES-251
      CURSOR c_maas_tc (p_maas_ref_num  NUMBER
                       ,p_start_date    DATE
                       ,p_end_date      DATE
      ) IS
         SELECT 1
         FROM master_service_tc_periods
         WHERE maas_ref_num = p_maas_ref_num
           AND start_date <= p_start_date
           AND Nvl(end_date, p_end_date) >= p_end_date
      ;
      --
      l_num_days                    NUMBER;   -- kuus palju päevi on,viimane päev PP
      l_last_end_date               DATE;
      l_skip_sety                   BOOLEAN;                -- CHG-13407
      l_found                       BOOLEAN;                -- CHG-13407
      l_dummy                       NUMBER;                 -- CHG-13407
      l_first_susp_start            DATE;                   -- CHG-13407
      l_sety_rec                    service_types%ROWTYPE;  -- CHG-13407
      l_group_id                    master_service_parameters.param_value%TYPE;  -- CHG-13407
      -----------------------
      u_err_sety_monthly            EXCEPTION;
   BEGIN
      --päevade arv kuus
      l_num_days := TO_NUMBER (TO_CHAR (LAST_DAY (p_period_end), 'dd'));

      --
      FOR l_chca_rec IN c_chca (p_maac_ref_num, p_period_start, p_period_end) LOOP
         FOR l_maas_rec IN c_maas (p_maac_ref_num
                                  ,GREATEST (l_chca_rec.start_date, NVL (l_last_end_date + 1, l_chca_rec.start_date))
                                  ,l_chca_rec.end_date) 
         LOOP
            --dbms_output.put_line( '-----teenus '||to_char(ii.sety_ref_num)||'  curr start '||to_char(ii.start_date)||'-'
            --||to_char(ii.end_date)||' maas '||to_char(ii.ref_num));
            
            l_skip_sety := FALSE;
            -- SFILES-251: Kui teenus on olnud terve perioodi TC, siis ei lähe kuutasu arvutama
            OPEN  c_maas_tc (l_maas_rec.ref_num
                            ,l_maas_rec.start_date
                            ,l_maas_rec.end_date
                            );
            FETCH c_maas_tc INTO l_dummy;
            l_skip_sety := c_maas_tc%FOUND;
            CLOSE c_maas_tc;
            
            /*
              ** CHG-13407: MultiSIM arveldus
            */
            l_sety_rec := NULL;
            --
            OPEN  c_sety (l_maas_rec.sety_ref_num);
            FETCH c_sety INTO l_sety_rec;
            l_found := c_sety%FOUND;
            CLOSE c_sety;
            --
            IF l_sety_rec.station_param = 'MULTISIM' AND
               NOT l_skip_sety  -- SFILES-251
            THEN
               -- Leiame teenuse parameetri väärtuse - Group ID
               l_group_id := NULL;
               --
               OPEN  c_masp (l_maas_rec.ref_num
                            ,l_maas_rec.start_date
                            ,l_maas_rec.end_date
                            );
               FETCH c_masp INTO l_group_id;
               CLOSE c_masp;
               
               -- Leiame, kas mobiilid, millel on liikmeteenus, on olnud aktiivsed arveldusperioodis
               OPEN  c_ac_susgs (l_maas_rec.sety_ref_num
                                ,l_group_id
                                ,l_maas_rec.start_date
                                ,l_maas_rec.end_date
                                );
               FETCH c_ac_susgs INTO l_dummy;
               l_found := c_ac_susgs%FOUND;
               CLOSE c_ac_susgs;
               --
               IF NOT l_found THEN
                  -- Puudusid aktiivsed mobiilid
                  l_skip_sety := TRUE;
                  --
               ELSE
                  -- Leida kõige esimese liikme algus
                  l_first_susp_start := NULL;
                  --
                  OPEN  c_first_susp (l_maas_rec.sety_ref_num
                                     ,l_group_id
                                     );
                  FETCH c_first_susp INTO l_first_susp_start;
                  CLOSE c_first_susp;
                  
                  -- Kui see on arveldusperioodis
                  IF l_first_susp_start > l_maas_rec.end_date THEN
                     -- Jätame arvutuse vahele
                     l_skip_sety := TRUE;
                     --
                  ELSIF l_first_susp_start > l_maas_rec.start_date THEN
                     --
                     l_maas_rec.start_date := Nvl(l_first_susp_start, l_maas_rec.start_date); 
                     --
                  END IF;                  
                  --
               END IF;              
               --
            END IF;            
            /* End CHG-13407 */
            
            
            IF NOT l_skip_sety THEN  -- CHG-13407
               --
               monthly_maas_sety_charge (p_success                 -- IN OUT boolean
                                        ,p_error_text              -- IN OUT varchar2
                                        ,p_invo_details            -- IN     INVOICES%ROWTYPE
                                        ,l_num_days                -- p_end_day_num    IN     number    -- päevade arv kuus pp
                                        ,l_maas_rec.sety_ref_num   -- IN     service_types.ref_num%type
                                        ,l_maas_rec.start_date     -- IN     date
                                        ,l_maas_rec.end_date       -- IN     date
                                        ,l_maas_rec.ref_num        -- p_maas_ref_num   IN     master_account_services.ref_num%type
                                        ,p_inv_entry               -- p_create_entry   IN     varchar2
                                        ,l_chca_rec.chca_type_code -- IN     varchar2
                                        ,l_first_susp_start        -- IN     DATE  CHG-13643
                                        ,p_main_bill               -- IN     BOOLEAN
                                        );

               IF NOT p_success THEN
                  RAISE u_err_sety_monthly;
               END IF;
               --
            END IF;
            --
         END LOOP;

         --
         -- Kui CHCA vahetus poole päeva pealt, siis uus periood järgmise päeva algusest, kuna eelmine päev on juba arveldatud
         l_last_end_date := TRUNC (l_chca_rec.end_date);
      END LOOP;
   EXCEPTION
      WHEN u_err_sety_monthly THEN
         ROLLBACK;
         p_success := FALSE;
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;
         p_error_text := 'MA=' || TO_CHAR (p_maac_ref_num) || ': ' || SQLERRM;
   END main_master_service_charges;

   ---------------------------------------------------------------------------------
   --------------------------------------------------------------------------------
   PROCEDURE calculate_masp_days (
      p_maas_ref_num  IN      master_account_services.ref_num%TYPE
     ,p_sety_ref_num  IN      service_types.ref_num%TYPE
     ,p_start_date    IN      DATE   -- teenuse start_date
     ,p_end_date      IN      DATE   -- teenuse/perioodi lõpp end_date
     ,p_sepa_ref_num  IN      service_parameters.ref_num%TYPE
     ,p_sepv_ref_num  IN      service_param_values.ref_num%TYPE
     ,p_days          OUT     NUMBER   --  arvutatud päevi
     ,p_success       OUT     BOOLEAN
   ) IS
      CURSOR c_masp_sepv (
         p_maas_ref_num  IN  NUMBER
        ,p_start_date    IN  DATE
        ,p_end_date      IN  DATE
        ,p_sepa_ref_num  IN  NUMBER
        ,p_sepv_ref_num  IN  NUMBER
      ) IS
         SELECT   sepa_ref_num
                 ,sepv_ref_num
                 ,param_value
                 ,TRUNC (GREATEST (p_start_date, start_date)) start_date
                 ,TRUNC (LEAST (p_end_date, NVL (end_date, p_end_date))) end_date
             FROM master_service_parameters
            WHERE start_date <= p_end_date
              AND NVL (end_date, p_end_date) >= p_start_date
              AND maas_ref_num = p_maas_ref_num
              AND sepa_ref_num = p_sepa_ref_num
         --and sepv_ref_num               = p_sepv_ref_num
         ORDER BY sepa_ref_num, start_date
      ;
      -- SFILES-251
      CURSOR c_maas_tc IS
         SELECT *
         FROM master_service_tc_periods
         WHERE maas_ref_num = p_maas_ref_num
           AND Trunc(start_date) <= p_end_date
           AND Nvl(end_date, p_end_date) >= p_start_date
         ORDER BY start_date
      ;
      -- SFILES-251
      TYPE t_tc_tab IS TABLE OF master_service_tc_periods%ROWTYPE;
      l_tc_tab                      t_tc_tab;
      --
      l_sum_days                    NUMBER := 0;
      l_days                        NUMBER := 0;
      l_start                       DATE;
      l_end                         DATE;
      l_start1                      DATE;
      l_end1                        DATE;
      l_num_days                    NUMBER := 0;
      l_num                         NUMBER := 0;
      l_sepv                        NUMBER;
      l_sepv1                       NUMBER;
      l_ting                        DATE;
      i                             NUMBER := 1;
      l_abi                         DATE;
      --
      l_chk_start                   DATE;   -- SFILES-251
      l_chk_end                     DATE;   -- SFILES-251
      l_tc_days                     NUMBER; -- SFILES-251
   BEGIN
      -- SFILES-251: Leiame TC perioodid mälutabelisse
      OPEN  c_maas_tc;
      FETCH c_maas_tc BULK COLLECT INTO l_tc_tab;
      CLOSE c_maas_tc;
      --
      FOR ii IN c_masp_sepv (p_maas_ref_num, p_start_date, p_end_date, p_sepa_ref_num, p_sepv_ref_num) LOOP
         IF i = 1 THEN
            l_sepv1 := ii.sepv_ref_num;
            l_start1 := ii.start_date;
            l_end1 := ii.end_date;

            --
            IF l_sepv1 <> p_sepv_ref_num THEN
               l_ting := l_end1 + 1;
               l_start1 := NULL;
            ELSE
               IF NVL (l_ting, l_end1) <= l_end1 THEN
                  l_start1 := GREATEST (NVL (l_ting, l_start1), l_start1);
                  i := 0;
               ELSE
                  l_start1 := NULL;
               END IF;
            END IF;
         ELSE
            l_sepv := ii.sepv_ref_num;
            l_start := GREATEST (NVL (l_ting, ii.start_date), ii.start_date);
            l_end := ii.end_date;

            IF l_end = l_end1 THEN
               l_start := NULL;
            ELSE
               IF l_sepv = p_sepv_ref_num THEN
                  IF l_start = l_start1 THEN
                     l_end1 := l_end;
                     l_start := NULL;
                     i := 0;
                  ELSE
                     l_num :=   ROUND (TO_DATE (TO_CHAR (l_end1, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss'))
                              - l_start1;
                     -- SFILES-251: Leiame TC päevade arvu
                     l_chk_start := l_start1;
                     l_chk_end   := TO_DATE (TO_CHAR (l_end1, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss');
                     l_tc_days   := 0;
                     --
                     FOR i IN 1 .. l_tc_tab.COUNT LOOP
                        --
                        l_tc_days := Nvl(l_tc_days, 0) + Round( Least(l_chk_end, Nvl(l_tc_tab(i).end_date, l_chk_end)) - Greatest(l_chk_start, Nvl(l_tc_tab(i).start_date, l_chk_start)), 0);
                        --
                     END LOOP;
                     -- End SFILES-251
                     l_num_days := l_num_days + NVL (l_num, 0) - Nvl(l_tc_days, 0);
                     l_ting := l_end1 + 1;
                     l_end1 := l_end;
                     l_start1 := l_start;
                     l_start := NULL;
                  END IF;
               ELSE   -- sepv<>
                  l_num :=   ROUND (TO_DATE (TO_CHAR (l_end1, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss'))
                           - l_start1;
                  -- SFILES-251: Leiame TC päevade arvu
                  l_chk_start := l_start1;
                  l_chk_end   := TO_DATE (TO_CHAR (l_end1, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss');
                  l_tc_days   := 0;
                  --
                  FOR i IN 1 .. l_tc_tab.COUNT LOOP
                     --
                     l_tc_days := Nvl(l_tc_days, 0) + Round( Least(l_chk_end, Nvl(l_tc_tab(i).end_date, l_chk_end)) - Greatest(l_chk_start, Nvl(l_tc_tab(i).start_date, l_chk_start)), 0);
                     --
                  END LOOP;
                  -- End SFILES-251
                  l_num_days := l_num_days + NVL (l_num, 0) - Nvl(l_tc_days, 0);
                  i := 1;
                  l_start := NULL;
                  l_start1 := NULL;
                  l_ting := l_end1 + 1;
               END IF;
            END IF;
         END IF;
      END LOOP;

      IF l_start1 IS NOT NULL AND l_sepv1 = p_sepv_ref_num THEN
         l_abi := GREATEST (l_start1, NVL (l_ting, l_start1));
         l_num := ROUND (TO_DATE (TO_CHAR (l_end1, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss')) - l_abi;
         -- SFILES-251: Leiame TC päevade arvu
         l_chk_start := l_abi;
         l_chk_end   := TO_DATE (TO_CHAR (l_end1, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss');
         l_tc_days   := 0;
         --
         FOR i IN 1 .. l_tc_tab.COUNT LOOP
            --
            l_tc_days := Nvl(l_tc_days, 0) + Round( Least(l_chk_end, Nvl(l_tc_tab(i).end_date, l_chk_end)) - Greatest(l_chk_start, Nvl(l_tc_tab(i).start_date, l_chk_start)), 0);
            --
         END LOOP;
         -- End SFILES-251
         l_num_days := l_num_days + NVL (l_num, 0) - Nvl(l_tc_days, 0);
      END IF;

      IF l_start IS NOT NULL AND l_sepv = p_sepv_ref_num THEN
         l_num := ROUND (TO_DATE (TO_CHAR (l_end, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss')) - l_abi;
         -- SFILES-251: Leiame TC päevade arvu
         l_chk_start := l_abi;
         l_chk_end   := TO_DATE (TO_CHAR (l_end, 'dd.mm.yyyy') || ' 23:59:59', 'dd.mm.yyyy hh24:mi:ss');
         l_tc_days   := 0;
         --
         FOR i IN 1 .. l_tc_tab.COUNT LOOP
            --
            l_tc_days := Nvl(l_tc_days, 0) + Round( Least(l_chk_end, Nvl(l_tc_tab(i).end_date, l_chk_end)) - Greatest(l_chk_start, Nvl(l_tc_tab(i).start_date, l_chk_start)), 0);
            --
         END LOOP;
         -- End SFILES-251
         l_num_days := l_num_days + NVL (l_num, 0) - Nvl(l_tc_days, 0);
      END IF;

      --dbms_output.put_line('Väljun päevade arvuga FIND_Num_Of_Days: ' || To_Char(l_num_days));
      IF l_num_days > 99 THEN
         l_num_days := 62;
      END IF;

      p_days := GREATEST (l_num_days, 0);
      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_days := -1;
         p_success := FALSE;
   END calculate_masp_days;

   -----------------------------------------------------------------------------
   PROCEDURE period_fixed_charges (
      p_maac_ref_num                    NUMBER
     ,p_susg_ref_num                    NUMBER
     ,p_invo_details     IN OUT NOCOPY  invoices%ROWTYPE
     ,p_success          IN OUT         BOOLEAN
     ,p_error_text       IN OUT         VARCHAR2
     ,p_period_start                    DATE
     ,p_period_end                      DATE
     ,p_inv_entry                       VARCHAR2 DEFAULT 'B'
     ,p_module_ref                      invoice_entries.module_ref%TYPE DEFAULT 'U659'
     ,p_int_invo_exists                 BOOLEAN DEFAULT NULL   -- UPR-3124
     ,p_main_bill                       BOOLEAN DEFAULT FALSE   -- CHG-464
   ) IS
      CURSOR c_all_pack (
         p_maac_ref_num  NUMBER
        ,p_susg_ref_num  NUMBER
        ,p_start_date    DATE
        ,p_end_date      DATE
      ) IS
         SELECT supa.sept_type_code sept_type_code
               ,supa.gsm_susg_ref_num susg_ref_num
               ,GREATEST (supa.start_date, p_start_date) start_date
               ,TO_DATE (TO_CHAR (LEAST (NVL (supa.end_date, p_end_date), p_end_date), 'dd.mm.yyyy') || ' 23.59.59'
                        ,'dd.mm.yyyy hh24.mi.ss'
                        ) end_date
               ,susg.nety_type_code nety_type_code
           FROM subs_packages supa, subs_serv_groups susg
          WHERE supa.suac_ref_num IN (SELECT ref_num
                                        FROM accounts
                                       WHERE maac_ref_num = p_maac_ref_num)
            AND susg.ref_num = NVL (supa.gsm_susg_ref_num, 0)
            AND ((susg.ref_num = NVL (p_susg_ref_num, 0) OR p_susg_ref_num IS NULL))
            AND supa.start_date <= p_end_date
            AND NVL (supa.end_date, p_end_date) >= p_start_date;

      --
      l_string                      VARCHAR2 (80);
      l_serv                        get_susg_serv.t_susg_serv;
      l_err_mesg                    VARCHAR2 (200);
      l_idx                         BINARY_INTEGER := 0;
      l_success                     BOOLEAN := TRUE;
      l_susg_serv_tab               get_susg_serv.t_susg_serv_tab;
      l_num_days                    NUMBER;
      l_creating_bill_period        NUMBER;   -- upr 1991
      l_inen_tab                    t_inen;
      l_inen_sum_tab                t_inen_sum;
      l_period_end_time             DATE;
      l_ykt_sety_nr                 NUMBER;   -- ühise kuutasu teenuse rea jrk nr PL/SQL tabelis
      l_chg_service_name            service_types.service_name%TYPE;   -- CHG-742
      --
      u_err_sept_monthly            EXCEPTION;
      u_err_sety_monthly            EXCEPTION;
      u_err_discount_to_entry       EXCEPTION;   -- UPR 1991
      e_proc_common_mon_chg         EXCEPTION;

      --
      FUNCTION fetch_serv (
         p_serv  IN OUT NOCOPY  get_susg_serv.t_susg_serv
      )
         RETURN BOOLEAN IS
      -- Returns TRUE IF no more records found.
      BEGIN
         IF (l_susg_serv_tab.LAST >= l_idx) THEN   --works correct also IF (l_susg_serv_tab.Last IS NULL)
            p_serv := l_susg_serv_tab (l_idx);
            l_idx := l_idx + 1;
            RETURN FALSE;
         END IF;

         RETURN TRUE;
      END fetch_serv;
   --
   BEGIN
      l_num_days := TO_NUMBER (TO_CHAR (LAST_DAY (p_period_end), 'dd'));

      --
      FOR rec_pack IN c_all_pack (p_maac_ref_num, p_susg_ref_num, p_period_start, p_period_end) LOOP
          -- Added by upr 1991  --
         -- dbms_output.put_line('PFC: sept_type_code '|| rec_pack.SEPT_TYPE_CODE);
         -- dbms_output.put_line('PFC: susg_ref_num   '|| rec_pack.SUSG_REF_NUM);
         -- dbms_output.put_line('PFC: start_date     '|| rec_pack.STart_date);
         -- dbms_output.put_line('PFC: end date       '|| rec_pack.end_date);
         -- dbms_output.put_line('PFC: nety_type_code '|| rec_pack.NETY_TYPE_CODE);
         IF p_inv_entry = 'B' AND p_invo_details.invoice_type = 'INT' THEN
            UPDATE disc_call_amounts
               SET int_dur_discount = 0
                  ,interim_disc = 0
             WHERE susg_ref_num = rec_pack.susg_ref_num
               AND maac_ref_num = p_maac_ref_num
               AND discount_type = 'MON'
               AND invo_ref_num = p_invo_details.ref_num;
         --   dbms_output.put_line('PFC: UPDATE dica: ');
         END IF;   -- END of upr 1991

         icalculate_fixed_charges.monthly_sept_charge (l_success
                                                     ,p_error_text
                                                     ,p_invo_details   -- upr 1991 l_invo_ref_num
                                                     ,TRUNC (rec_pack.end_date)
                                                     ,l_num_days
                                                     ,rec_pack.sept_type_code
                                                     ,rec_pack.start_date
                                                     ,rec_pack.end_date
                                                     ,rec_pack.susg_ref_num
                                                     ,rec_pack.nety_type_code
                                                     ,'Y'
                                                     ,p_inv_entry
                                                     ,bcc_inve_mod_ref   -- upr 1991
                                                     ,p_maac_ref_num   -- upr 1991
                                                     ,l_inen_tab   -- IN OUT t_inen -- UPR-3124
                                                     ,l_inen_sum_tab   -- IN OUT t_inen_sum -- UPR-3124
                                                     );

         IF NOT l_success THEN
            RAISE u_err_sept_monthly;
         END IF;
      END LOOP;

      --dbms_output.put_line( 'PFC:Lähen teenustesse susg: '||to_char(p_susg_ref_num));
      get_susg_serv.get_susg_serv (p_maac_ref_num, p_period_start, p_period_end, l_susg_serv_tab, p_susg_ref_num);
      l_idx := l_susg_serv_tab.FIRST;

      IF fetch_serv (l_serv) THEN
         --  dbms_output.put_line(To_Char(l_idx-1) || '. service NOT found');
         GOTO nothing_to_do_with_serv;
      END IF;

      LOOP
         IF l_serv.sept_type_code IS NULL THEN
            -- dbms_output.put_line('PFC: hindan teenust '||to_char(l_serv.sety_ref_num)||' start '||
            --      to_char(l_serv.start_date)||' end '||to_char(l_serv.end_date));
            IF p_main_bill THEN
               /*
                 ** Hinnakirja hinnad võetakse mälutabelist.
               */
               icalculate_fixed_charges.calc_service_monthly_charge
                                                  (l_success   -- IN OUT BOOLEAN
                                                  ,p_error_text   -- IN OUT VARCHAR2
                                                  ,p_invo_details   -- IN     INVOICES%ROWTYPE
                                                  ,l_num_days   -- p_end_day_num    IN     NUMBER
                                                  ,l_serv.in_sept_type_code   -- IN     SUBS_PACKAGES.sept_type_code%TYPE
                                                  ,l_serv.sety_ref_num   -- IN     SERVICE_TYPES.ref_num%TYPE
                                                  ,l_serv.start_date   -- IN     DATE
                                                  ,l_serv.end_date   -- IN     DATE
                                                  ,l_serv.susg_ref_num   -- IN     SUBS_SERV_GROUPS.ref_num%TYPE
                                                  ,p_maac_ref_num   -- IN     ACCOUNTS.ref_num%TYPE
                                                  ,p_inv_entry   -- p_create_entry   IN     VARCHAR2 DEFAULT 'B'
                                                  );
            ELSE
               /*
                 ** Hinnad loetakse andmebaasist.
               */
               icalculate_fixed_charges.monthly_sety_charge
                                                  (l_success   -- IN OUT BOOLEAN
                                                  ,p_error_text   -- IN OUT VARCHAR2
                                                  ,p_invo_details   -- IN     INVOICES%ROWTYPE
                                                  ,l_num_days   -- p_end_day_num    IN     NUMBER
                                                  ,l_serv.in_sept_type_code   -- IN     SUBS_PACKAGES.sept_type_code%TYPE
                                                  ,l_serv.sety_ref_num   -- IN     SERVICE_TYPES.ref_num%TYPE
                                                  ,l_serv.start_date   -- IN     DATE
                                                  ,l_serv.end_date   -- IN     DATE
                                                  ,l_serv.susg_ref_num   -- IN     SUBS_SERV_GROUPS.ref_num%TYPE
                                                  ,p_maac_ref_num   -- IN     ACCOUNTS.ref_num%TYPE
                                                  ,p_inv_entry   -- p_create_entry   IN     VARCHAR2
                                                  );
            END IF;

            --
            IF NOT l_success THEN
               RAISE u_err_sety_monthly;
            END IF;
         END IF;

         --
         IF fetch_serv (l_serv) THEN   --also fetches the record
            --  dbms_output.put_line(To_Char(l_idx) || '. service NOT found inside loop');
            EXIT;
         END IF;
      END LOOP;

      <<nothing_to_do_with_serv>>
      --
      IF p_inv_entry = 'B' THEN
         IF p_invo_details.invoice_type = 'INB' THEN
            /*
              ** UPR-3124: Leitakse kuumaksud M/A teenustele, millede kuumaksu arvutus on päevade arvust sõltumatu (prorata=N).
            */
            l_period_end_time := TRUNC (p_period_end) + 1 - c_one_second;   -- 23:59:59
            icalculate_fixed_charges.calc_non_prorata_ma_serv_chg
                                                (p_maac_ref_num   -- IN     master_accounts_v.ref_num %TYPE
                                                ,p_invo_details.ref_num   -- IN     invoices.ref_num%TYPE
                                                ,l_period_end_time   -- IN     DATE
                                                ,l_success   -- OUT BOOLEAN
                                                ,p_error_text   -- OUT VARCHAR2
                                                ,l_ykt_sety_nr   -- OUT NUMBER
                                                ,l_inen_tab   -- IN OUT t_inen
                                                ,l_chg_service_name   --    OUT service_types.service_name%TYPE -- CHG-742
                                                );

            IF NOT l_success THEN
               RAISE e_proc_common_mon_chg;
            END IF;

            --
            IF l_ykt_sety_nr IS NOT NULL THEN
               IF l_chg_service_name = c_common_mon_chg_service THEN
                  /*
                    ** Teostada ühise kuumaksu summa ja mobiilide kuumaksude koondsumma võrdlus
                    ** Kallim variant kantakse siin ka ära vahetabelisse, soodsam kantakse hiljem arvele.
                  */
                  compare_monthly_charges (l_inen_tab   -- IN OUT t_inen
                                          ,l_inen_sum_tab   -- IN     t_inen_sum
                                          ,l_ykt_sety_nr   -- IN     NUMBER
                                          ,p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                          ,p_period_start   -- IN     DATE
                                          ,p_period_end   -- IN     DATE
                                          ,l_success   --    OUT BOOLEAN
                                          ,p_error_text   --    OUT VARCHAR2
                                          ,p_int_invo_exists   -- IN BOOLEAN
                                          );
               ELSIF l_chg_service_name = bccp683sb.c_pere_kt_service THEN
                  /*
                    ** Soodsama variandi võrdlust ei toimu. Arvele läheb pere kuutasu.
                  */
                  exclude_mobile_package_charges (l_inen_tab   -- IN OUT t_inen
                                                 ,l_ykt_sety_nr   -- IN     NUMBER
                                                 ,p_maac_ref_num   -- IN     accounts.ref_num%TYPE
                                                 ,p_period_start   -- IN     DATE
                                                 ,p_period_end   -- IN     DATE
                                                 ,l_period_end_time   -- IN     DATE
                                                 ,l_success   --    OUT BOOLEAN
                                                 ,p_error_text   --    OUT VARCHAR2
                                                 ,p_int_invo_exists   -- IN     BOOLEAN
                                                 );
               END IF;

               --
               IF NOT l_success THEN
                  RAISE e_proc_common_mon_chg;
               END IF;
            END IF;
         END IF;

         /*
           ** Kantakse PL/SQL tabelisse kogutud paketi kuumaksud + non-prorata M/A teenuste kuumaksud ära arveridadeks.
         */
         write_down_invoice_entries (l_inen_tab   -- IN OUT t_inen
                                    ,p_invo_details.ref_num   -- IN     invoices.ref_num%TYPE
                                    ,bcc_inve_mod_ref   -- IN     invoice_entries.module_ref%TYPE
                                    );
         /*
           ** CHG-4418: MeieEMT lahendustasu.
         */
         iprocess_monthly_service_fees.chk_one_maac_ma_calculated_fee
                                                                 (p_maac_ref_num   --IN     master_accounts_v.ref_num%TYPE
                                                                 ,p_period_start   --IN     DATE DEFAULT NULL
                                                                 ,p_period_end   --IN     DATE DEFAULT NULL
                                                                 ,p_invo_details.ref_num   --IN     invoices.ref_num%TYPE
                                                                 );
         --
         -- dbms_output.put_line('PFC: call carry_discount_to_entry');
         -- upr 1991 kanda arvutatud soodustused arvele
         calculate_discounts.carry_discount_to_entry (p_invo_details
                                                     ,p_maac_ref_num
                                                     ,p_susg_ref_num
                                                     ,p_error_text
                                                     ,l_success
                                                     );

         IF NOT l_success THEN
            RAISE u_err_discount_to_entry;
         END IF;
      ELSE
         IF p_inv_entry = 'I' THEN
            /*
             ** CHG-4418/xxxx: MeieEMT lahendustasu jooksva saldo arvutuseks
             */
            iprocess_monthly_service_fees.chk_one_maac_ma_calculated_fee
                                                                 (p_maac_ref_num   --IN     master_accounts_v.ref_num%TYPE
                                                                 ,p_period_start   --IN     DATE DEFAULT NULL
                                                                 ,p_period_end   --IN     DATE DEFAULT NULL
                                                                 ,p_invo_details.ref_num   --IN     invoices.ref_num%TYPE
                                                                 ,TRUE  -- IN p_interim BOOLEAN 
                                                                 );
         END IF;
      END IF;
   EXCEPTION
      WHEN u_err_sept_monthly THEN
         -- dbms_output.put_line('Paketi viga '||p_error_text);
         p_success := FALSE;
      WHEN u_err_sety_monthly THEN
         -- dbms_output.put_line('Teenuse viga '||p_error_text);
         p_success := FALSE;
      WHEN u_err_discount_to_entry THEN   -- upr 1991
         p_success := FALSE;
      WHEN e_proc_common_mon_chg THEN
         p_success := FALSE;
      WHEN OTHERS THEN
         ROLLBACK;
         p_success := FALSE;

         IF p_invo_details.ref_num IS NULL THEN
            l_string := '*****';
         ELSE
            l_string := 'Account: ' || TO_CHAR (p_maac_ref_num) || ',' || 'Invoice: '
                        || TO_CHAR (p_invo_details.ref_num);
         END IF;

         IF l_err_mesg IS NOT NULL THEN
            p_error_text := l_err_mesg;
         ELSE
            p_error_text := SUBSTR ('Unexp. error CLOSE Invoice:' || SQLERRM || '/' || l_string, 1, 200);
         END IF;
   END period_fixed_charges;

   ----------------------------------------------------------------------------------
   -----
   PROCEDURE put_batch_message (
      p_mesg_num   NUMBER
     ,p_mesg_par1  VARCHAR2 DEFAULT ''
     ,p_mesg_par2  VARCHAR2 DEFAULT ''
   ) IS
   BEGIN
      g_message_count := g_message_count + 1;
      g_mesg_num (g_message_count) := p_mesg_num;
      g_mesg_param1 (g_message_count) := SUBSTR (p_mesg_par1, 1, 100);
      g_mesg_param2 (g_message_count) := SUBSTR (p_mesg_par2, 1, 100);
   EXCEPTION
      WHEN OTHERS THEN
         IF g_message_count > 0 THEN
            g_message_count := g_message_count - 1;
         END IF;
   END put_batch_message;

   ----------------------------------------------------------------------------------------
   PROCEDURE connection_charge (
      p_maac_ref_num      IN      accounts.ref_num%TYPE
     ,p_susg_ref_num      IN      subs_serv_groups.ref_num%TYPE
     ,p_chca_type_code    IN      subs_serv_groups.chca_type_code%TYPE
     ,p_package_type      IN      serv_package_types.type_code%TYPE
     ,p_service_date      IN      DATE
     ,p_sety_ref_num      IN      service_types.ref_num%TYPE
     ,p_sepv_ref_num      IN      service_param_values.ref_num%TYPE
     ,p_run_mode          IN      VARCHAR2   -- Fxxx,BATCH
     ,p_error_text        IN OUT  VARCHAR2   --200  Order System
     ,p_error_type        IN OUT  VARCHAR2   --W-warning/E-error
     ,p_success           IN OUT  BOOLEAN
     ,p_transact_mode     IN      VARCHAR2 DEFAULT 'INS'
     ,p_order_date        IN      DATE DEFAULT NULL
     ,p_channel_type      IN      price_lists.channel_type%TYPE DEFAULT NULL
     ,p_par_value_charge  IN      price_lists.par_value_charge%TYPE DEFAULT 'N'
     ,p_sepa_ref_num      IN      service_parameters.ref_num%TYPE DEFAULT NULL
     ,p_maas_ref_num      IN      master_account_services.ref_num%TYPE DEFAULT NULL   -- CHG-498
     ,p_check_pricelist   IN      BOOLEAN DEFAULT TRUE   -- CHG-3180
     ,p_mixed_service     IN      VARCHAR2 DEFAULT NULL -- CHG-5438
   ) IS
      --
      l_once_off                    VARCHAR2 (1);
      l_prorata                     VARCHAR2 (1);
      l_regular                     VARCHAR2 (1);
      l_inen_ref_num                invoice_entries.ref_num%TYPE;
      l_invo_ref_num                invoices.ref_num%TYPE;
      l_service_date                DATE;
   BEGIN
      bcc_proc_name := 'Connection_charging';
      l_once_off := 'Y';
      l_prorata := 'N';
      l_regular := 'Y';
      l_service_date := TRUNC (p_service_date);
      --
      fixed_charge_calc (p_maac_ref_num
                        ,p_susg_ref_num
                        ,p_chca_type_code
                        ,p_package_type
                        ,l_service_date
                        ,p_sety_ref_num
                        ,p_sepv_ref_num
                        ,p_run_mode   -- Fxxx,BATCH
                        ,l_once_off
                        ,l_prorata
                        ,l_regular
                        ,p_error_text   --200  Order System
                        ,p_error_type   --W-warning/E-error
                        ,p_success
                        ,l_inen_ref_num
                        ,l_invo_ref_num
                        ,p_transact_mode
                        ,p_order_date
                        ,p_channel_type
                        ,p_par_value_charge
                        ,NULL   -- p_count
                        ,p_sepa_ref_num
                        ,NULL   -- p_char_amt         IN NUMBER DEFAULT NULL         -- UPR-2794
                        ,NULL   -- p_bise             IN VARCHAR2 DEFAULT NULL         -- UPR-2794
                        ,NULL   -- p_fcit_type_code   IN VARCHAR2 DEFAULT NULL         -- UPR-2794
                        ,NULL   -- p_taty_type_code   IN VARCHAR2 DEFAULT NULL         -- UPR-2794
                        ,p_maas_ref_num   -- master_account_services.ref_num%TYPE DEFAULT NULL -- CHG-498
                        ,NULL
                        ,NULL
                        ,NULL
                        ,p_check_pricelist   -- CHG-3180
                        ,NULL --p_fixed_term_category  IN      fixed_special_prices.fixed_term_category%TYPE DEFAULT NULL
                        ,NULL --p_fixed_term_length    IN      fixed_special_prices.fixed_term_length%TYPE DEFAULT NULL
                        ,NULL --p_fixed_term_sety      IN      fixed_special_prices.fixed_term_sety%TYPE DEFAULT NULL
                        ,NULL --p_mixed_service        IN      VARCHAR2 DEFAULT NULL -- CHG-5438
                        ,p_mixed_service     -- IN      VARCHAR2 DEFAULT NULL -- CHG-5438
                        );
   END connection_charge;

   /*
     ** Funktsioon väljastab andmed teenustasu tüüpide tabeli reast (Fixed_Charge_Item_Types),
     ** milline leitakse ette antud teenuse tüübi, billing selectori ja nn. semafori
     ** (pro_rata+once_off+regular_charge) alusel.
   */
   FUNCTION get_fcit_by_bise_sety (
      p_sety_ref_num    IN  service_types.ref_num%TYPE
     ,p_bise            IN  billing_selectors_v.type_code%TYPE
     ,p_once_off        IN  fixed_charge_item_types.once_off%TYPE
     ,p_regular_charge  IN  fixed_charge_item_types.regular_charge%TYPE
     ,p_pro_rata        IN  fixed_charge_item_types.pro_rata%TYPE
   )
      RETURN fixed_charge_item_types%ROWTYPE IS
      --
      CURSOR c_fcit IS
         SELECT *
           FROM fixed_charge_item_types
          WHERE sety_ref_num = p_sety_ref_num
            AND billing_selector = p_bise
            AND once_off = p_once_off
            AND regular_charge = p_regular_charge
            AND pro_rata = p_pro_rata
            AND ARCHIVE <> 'Y';

      --
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;
   BEGIN
      OPEN c_fcit;

      FETCH c_fcit
       INTO l_fcit_rec;

      CLOSE c_fcit;

      --
      RETURN l_fcit_rec;
   END get_fcit_by_bise_sety;

   /*
     ** Funktsioon väljastab andmed teenustasu tüüpide tabeli reast (Fixed_Charge_Item_Types),
     ** milline leitakse ette antud teenuse tüübi ja nn. semafori (pro_rata+once_off+regular_charge) alusel
     ** + mobiili taseme teenuste korral ka paketi kategooria järgi (M/A teenuste korral paketi kategooria puudub).
   */
   FUNCTION get_fcit_by_sety_paca (
      p_sety_ref_num    IN  service_types.ref_num%TYPE
     ,p_category        IN  package_categories.package_category%TYPE
     ,p_once_off        IN  fixed_charge_item_types.once_off%TYPE
     ,p_regular_charge  IN  fixed_charge_item_types.regular_charge%TYPE
     ,p_pro_rata        IN  fixed_charge_item_types.pro_rata%TYPE
   )
      RETURN fixed_charge_item_types%ROWTYPE IS
      --
      CURSOR c_fcit IS
         SELECT *
           FROM fixed_charge_item_types
          WHERE sety_ref_num = p_sety_ref_num
            AND NVL (package_category, '*') = NVL (p_category, '*')
            AND once_off = p_once_off
            AND regular_charge = p_regular_charge
            AND pro_rata = p_pro_rata
            AND ARCHIVE <> 'Y';

      --
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;
   BEGIN
      OPEN c_fcit;

      FETCH c_fcit
       INTO l_fcit_rec;

      CLOSE c_fcit;

      --
      RETURN l_fcit_rec;
   END get_fcit_by_sety_paca;
   
   /*
     ** Funktsioon väljastab andmed teenustasu tüüpide tabeli reast (Fixed_Charge_Item_Types),
     ** milline leitakse ette antud teenuse tüübi, bise ja fcit järgi.
   */
   FUNCTION get_fcit_by_bise_fcit (
      p_bise            IN     fixed_charge_item_types.billing_selector%TYPE
     ,p_fcit            IN     fixed_charge_item_types.type_code%TYPE
     ,p_fcit_rec           OUT fixed_charge_item_types%ROWTYPE
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_fcit IS
         SELECT *
           FROM fixed_charge_item_types
          WHERE billing_selector = p_bise
            AND type_code = p_fcit
            AND ARCHIVE <> 'Y';
      --
      l_found      BOOLEAN;
      l_fcit_rec   fixed_charge_item_types%ROWTYPE;
   BEGIN
      --
      OPEN c_fcit;
      FETCH c_fcit INTO p_fcit_rec;
      l_found := c_fcit%FOUND;
      CLOSE c_fcit;
      --
      RETURN l_found;
   END get_fcit_by_bise_fcit;

   /*
     ** Protseduur leiab kuumaksud sellistele M/A teenustele, millede kuumaksude arvutus ei ole
     ** sõltuvuses kasutatud päevade arvust (prorata = N)
   */
   PROCEDURE calc_non_prorata_ma_serv_chg (
      p_maac_ref_num     IN      master_accounts_v.ref_num%TYPE
     ,p_invo_ref_num     IN      invoices.ref_num%TYPE
     ,p_period_end_date  IN      DATE
     ,p_success          OUT     BOOLEAN
     ,p_error_text       OUT     VARCHAR2
     ,p_ykt_sety_nr      OUT     NUMBER   -- ühise kuutasu teenuse rea jrk nr PL/SQL tabelis
     ,p_inen_tab         IN OUT  t_inen
     ,p_service_name     OUT     service_types.service_name%TYPE   -- CHG-742
   ) IS
      --
      CURSOR c_maas IS
         SELECT   *
             FROM master_account_services maas
            WHERE maas.maac_ref_num = p_maac_ref_num
              AND p_period_end_date BETWEEN maas.start_date AND NVL (maas.end_date, p_period_end_date)
              AND EXISTS (SELECT 1
                            FROM price_lists
                           WHERE sety_ref_num = maas.sety_ref_num
                             AND Trunc(p_period_end_date) BETWEEN start_date AND NVL (end_date, p_period_end_date)  -- CHG-13407
                             AND regular_charge = 'Y'
                             AND pro_rata = 'N'
                             AND once_off = 'N')
              AND NOT EXISTS (SELECT 1   -- CHG-498: Arve ja kõnede eristuse teenuseid vaadeldakse eraldi
                                FROM service_types
                               WHERE ref_num = maas.sety_ref_num 
                                 AND ( station_param IN ('KER', 'ARVE', 'TEAV', 'MEIE')   -- CHG-4467: added station parameter 'MEIE'
                                       OR
                                       sept_type_code IS NOT NULL)  -- CHG-4803
                              )
         ORDER BY maas.start_date DESC   -- CHG-742
                                      ;

      --
      l_chca_type_code              maac_charging_categories.chca_type_code%TYPE;
      l_price                       NUMBER;
      l_taty_type_code              tax_types.tax_type_code%TYPE;
      l_billing_selector            billing_selectors_v.type_code%TYPE;
      l_fcit_type_code              fixed_charge_item_types.type_code%TYPE;
      l_sety_rec                    service_types%ROWTYPE;
      l_inen_sum_tab                t_inen_sum;
      l_masa_rec                    master_service_adjustments%ROWTYPE;
      --
      e_missing_data                EXCEPTION;
      e_duplicate_serv              EXCEPTION;
   BEGIN
      p_ykt_sety_nr := NULL;

      /*
        ** Leiame antud M/A kõik aktiivsed teenused, mille kuumaksu arvutus on päevade arvust sõltumatu (prorata=N).
      */
      FOR l_maas_rec IN c_maas LOOP
         BEGIN
            /*
              ** Leiame teenuse andmed
            */
            l_sety_rec := tbcis_common.get_sety_record (l_maas_rec.sety_ref_num);

            /*
              ** UPR-3194: Arvestame, et ühtne kuutasu kuulub töötlemisele ainult 1-kordselt. Kui on vigase
              **           sisestuse tõttu läinud 1-le Masterile pelae > 1, siis kõiki järgnevaid ignoreerime.
            */
            IF     l_sety_rec.service_name IN (c_common_mon_chg_service, bccp683sb.c_pere_kt_service)
               AND p_ykt_sety_nr IS NOT NULL THEN
               RAISE e_duplicate_serv;
            END IF;

            --
            get_non_prorata_ma_serv_price
               (p_maac_ref_num   -- IN     master_accounts_v.ref_num%TYPE
               ,l_maas_rec.ref_num   -- IN     master_account_services.ref_num%TYPE
               ,l_maas_rec.sety_ref_num   -- IN     service_types.ref_num%TYPE
               ,p_period_end_date   -- IN     DATE
               ,l_chca_type_code   -- IN OUT maac_charging_categories.chca_type_code%TYPE
               ,l_price   --    OUT NUMBER
               ,l_taty_type_code   --    OUT tax_types.tax_type_code%TYPE
               ,l_billing_selector   --    OUT billing_selectors_v.type_code%TYPE
               ,l_fcit_type_code   --    OUT fixed_charge_item_types.type_code%TYPE
               ,l_masa_rec   --    OUT master_service_adjustments%ROWTYPE, ei kasutata: YKT korral kampaaniaga seotud soodustusi ei arvesta
               );

            --
            IF l_price IS NULL THEN
               p_error_text := 'Puudub kuumaksu tariif Master teenusele ' || l_sety_rec.type_code;
               RAISE e_missing_data;
            END IF;

            /*
              ** Kanname leitud kuumaksu PL/SQL tabelisse.
            */
            add_invoice_entry (p_inen_tab   -- IN OUT t_inen
                              ,l_inen_sum_tab   -- IN OUT t_inen_sum, M/A teenuste korral ei kasutata tegelikult
                              ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                              ,l_fcit_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TYPE_CODE%TYPE
                              ,l_taty_type_code   -- IN     FIXED_CHARGE_ITEM_TYPES.TATY_TYPE_CODE%TYPE
                              ,l_billing_selector   -- IN     FIXED_CHARGE_ITEM_TYPES.BILLING_SELECTOR%TYPE
                              ,l_price   -- IN     NUMBER
                              ,NULL   -- IN     SUBS_SERV_GROUPS.ref_num%TYPE
                              ,NULL   -- p_num_of_days IN     NUMBER
                              ,NULL   -- IN     invoice_entries.module_ref%TYPE
                              ,l_maas_rec.ref_num   -- IN     master_account_services.ref_num%TYPE
                              ,NULL   -- IN     serv_package_types.type_code%TYPE
                              ,NULL   -- IN     DATE, package start date
                              );

            --
            IF l_sety_rec.service_name IN (c_common_mon_chg_service, bccp683sb.c_pere_kt_service) THEN   -- teenus ühine kuutasu, pere kuutasu
               p_ykt_sety_nr := p_inen_tab.LAST;   -- need M/A teenused lähevad arvereale ainult 1 korra ja hetkel tabeli viimaseks
               p_service_name := l_sety_rec.service_name;   -- CHG-742
            END IF;
         EXCEPTION
            WHEN e_duplicate_serv THEN
               gen_bill.msg (bcc_module_ref
                            ,'Calculate Non-Prorata MA Services Monthly Charges'   -- module description
                            ,bcc_warning
                            ,    'Master Account '
                              || TO_CHAR (p_maac_ref_num)
                              || ' has duplicate service '
                              || l_sety_rec.service_name
                              || ' open at '
                              || TO_CHAR (p_period_end_date, 'dd.mm.yyyy hh24:mi:ss')
                            );
         END;
      END LOOP;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_missing_data THEN
         p_success := FALSE;
   END calc_non_prorata_ma_serv_chg;

   /*
     ** Protseduur lisab ette antud arverea PL/SQL tabelisse
   */
   PROCEDURE add_invoice_entry (
      p_inen_tab          IN OUT  t_inen
     ,p_inen_sum_tab      IN OUT  t_inen_sum
     ,p_invo_ref_num      IN      invoices.ref_num%TYPE
     ,p_fcit_type_code    IN      fixed_charge_item_types.type_code%TYPE
     ,p_taty_type_code    IN      fixed_charge_item_types.taty_type_code%TYPE
     ,p_billing_selector  IN      fixed_charge_item_types.billing_selector%TYPE
     ,p_charge_value      IN      NUMBER
     ,p_susg_ref_num      IN      subs_serv_groups.ref_num%TYPE
     ,p_num_of_days       IN      NUMBER
     ,p_module_ref        IN      invoice_entries.module_ref%TYPE
     ,p_maas_ref_num      IN      master_account_services.ref_num%TYPE
     ,p_sept_type_code    IN      serv_package_types.type_code%TYPE
     ,p_start_date        IN      DATE
     ,p_sol_fee_indicator IN      VARCHAR2 DEFAULT NULL  -- CHG-13617
   ) IS
      --
      l_idx                         NUMBER;
      l_inen_exists                 BOOLEAN;
   BEGIN
      /*
        ** Kontrollime, kas vajalik arverida on juba tabelis, või tuleb sinna lisada.
      */
      l_idx := p_inen_tab.FIRST;
      l_inen_exists := FALSE;

      --
      WHILE l_idx IS NOT NULL LOOP
         IF     p_inen_tab (l_idx).invo_ref_num = p_invo_ref_num
            AND p_inen_tab (l_idx).fcit_type_code = p_fcit_type_code
            AND NVL (p_inen_tab (l_idx).susg_ref_num, 0) = NVL (p_susg_ref_num, 0)
            AND NVL (p_inen_tab (l_idx).maas_ref_num, 0) = NVL (p_maas_ref_num, 0) THEN
            l_inen_exists := TRUE;
            EXIT;
         END IF;

         --
         l_idx := p_inen_tab.NEXT (l_idx);
      END LOOP;

      --
      IF l_inen_exists THEN
         p_inen_tab (l_idx).acc_amount := p_inen_tab (l_idx).acc_amount + ROUND (p_charge_value, g_inen_acc_precision);   -- CHG4594/06.10.2010
         p_inen_tab (l_idx).eek_amt := ROUND (p_inen_tab (l_idx).acc_amount, 2);   -- CHG4594/06.10.2010
         p_inen_tab (l_idx).amt_in_curr := ROUND (p_inen_tab (l_idx).amt_in_curr + p_charge_value, 2);
         p_inen_tab (l_idx).pri_curr_code := get_pri_curr_code ();
         p_inen_tab (l_idx).last_updated_by := p_sol_fee_indicator;  -- CHG-13617
         --
         IF p_num_of_days IS NOT NULL THEN
            p_inen_tab (l_idx).num_of_days := NVL (p_inen_tab (l_idx).num_of_days, 0) + p_num_of_days;
         END IF;
      ELSE
         l_idx := p_inen_tab.COUNT + 1;
         --
         p_inen_tab (l_idx).invo_ref_num := p_invo_ref_num;
         p_inen_tab (l_idx).acc_amount := ROUND (p_charge_value, g_inen_acc_precision);   -- CHG4594
         p_inen_tab (l_idx).eek_amt := ROUND (p_inen_tab (l_idx).acc_amount, 2);   -- CHG4594
         p_inen_tab (l_idx).rounding_indicator := 'N';
         p_inen_tab (l_idx).under_dispute := 'N';
         p_inen_tab (l_idx).billing_selector := p_billing_selector;
         p_inen_tab (l_idx).fcit_type_code := p_fcit_type_code;
         p_inen_tab (l_idx).taty_type_code := p_taty_type_code;
         p_inen_tab (l_idx).manual_entry := 'N';
         p_inen_tab (l_idx).module_ref := NVL (p_module_ref, bcc_inve_mod_ref);
         p_inen_tab (l_idx).maas_ref_num := p_maas_ref_num;
         p_inen_tab (l_idx).susg_ref_num := p_susg_ref_num;
         p_inen_tab (l_idx).num_of_days := p_num_of_days;
         p_inen_tab (l_idx).pri_curr_code := get_pri_curr_code ();
         p_inen_tab (l_idx).last_updated_by := p_sol_fee_indicator;  -- CHG-13617
      END IF;

      /*
        ** Kontrollime, kas arverea summade tabelis on selle mobiili kohta kirje juba olemas (suurendada kogusummat)
        ** või tuleb lisada uus kirje.
      */
      IF p_susg_ref_num IS NOT NULL THEN
         IF p_inen_sum_tab.EXISTS (p_susg_ref_num) THEN
            p_inen_sum_tab (p_susg_ref_num).amount := p_inen_sum_tab (p_susg_ref_num).amount + p_charge_value;

            --
            IF p_start_date > p_inen_sum_tab (p_susg_ref_num).start_date THEN
               /*
                 ** Summade tabelis hoitakse perioodi kõige hilisema algusajaga paketti
               */
               p_inen_sum_tab (p_susg_ref_num).sept_type_code := p_sept_type_code;
               p_inen_sum_tab (p_susg_ref_num).start_date := p_start_date;
            END IF;
         ELSE
            p_inen_sum_tab (p_susg_ref_num).susg_ref_num := p_susg_ref_num;
            p_inen_sum_tab (p_susg_ref_num).amount := p_charge_value;
            p_inen_sum_tab (p_susg_ref_num).sept_type_code := p_sept_type_code;
            p_inen_sum_tab (p_susg_ref_num).start_date := p_start_date;
         END IF;
      END IF;
   END add_invoice_entry;

   /*
     ** Funktsiooni kirjeldus:
     ** Käiakse läbi kõik PL/SQL tabelisse salvestatud mobiilide summaarsed kuumaksu read
     ** ja kopeeritakse need siis teise PL/SQL vahetabelisse juba kuumaksude kahanemise järjekorras paigutatuna.
     ** Kui ridade summad on võrdsed, siis paigutatakse indeksiga+1 väiksemad susgid eespool (kuna on juba lähtetabelis
     ** eespool ning selle algoritmi järgi jäävad ka siin ettepoole), muul juhul jagatakse vaba vahemik alati pooleks.
   */
   FUNCTION create_ordered_mon_chg_list (
      p_inen_sum_tab  IN      t_inen_sum
     ,p_success       OUT     BOOLEAN
     ,p_error_text    OUT     VARCHAR2
   )
      RETURN t_inen_sum IS
      --
      c_max_subscript      CONSTANT NUMBER := 2147483647;   -- PL/SQL tabeli max index (suurem pole füüsiliselt enam lubatud)
      --
      l_idx                         NUMBER;
      l_idx_ordered                 NUMBER;
      l_ordered_exist               BOOLEAN;
      l_position                    NUMBER;
      l_prev_idx                    NUMBER;
      l_ordered_sum_tab             t_inen_sum;
      --
      e_invalid_algorithm           EXCEPTION;
   BEGIN
      l_idx := p_inen_sum_tab.FIRST;

      WHILE l_idx IS NOT NULL LOOP
         l_position := NULL;
         l_ordered_exist := FALSE;
         l_prev_idx := NULL;
         --
         l_idx_ordered := l_ordered_sum_tab.FIRST;

         WHILE l_idx_ordered IS NOT NULL LOOP
            l_ordered_exist := TRUE;

            --
            IF p_inen_sum_tab (l_idx).amount > l_ordered_sum_tab (l_idx_ordered).amount THEN
               l_prev_idx := l_ordered_sum_tab.PRIOR (l_idx_ordered);

               --
               IF l_prev_idx IS NULL THEN
                  /*
                    ** Tegemist senise suurima kuumaksu summaga mobiiliga.
                  */
                  l_position := TRUNC (l_idx_ordered / 2);
               ELSIF p_inen_sum_tab (l_idx).amount = l_ordered_sum_tab (l_prev_idx).amount THEN
                  /*
                    ** Käesoleva mobiili kuumaksu summa on sama kui eelneva mobiili oma.
                    ** Sel juhul salvestatakse summad järjestikkustele indeksitele, kuna sinna vahele niikuinii
                    ** enam midagi tulla ei saa.
                  */
                  l_position := l_prev_idx + 1;
               ELSE
                  /*
                    ** Käesoleva mobiili kuumaksu summa on väiksem kui eelneva mobiili oma.
                  */
                  l_position := l_prev_idx + (l_idx_ordered - l_prev_idx) / 2;
               END IF;

               --
               EXIT;
            END IF;

            --
            l_idx_ordered := l_ordered_sum_tab.NEXT (l_idx_ordered);
         END LOOP;

         --
         IF NOT l_ordered_exist THEN
            /*
              ** Lisatakse esimene rida järjestatud tabelisse (keskele).
            */
            l_position := TRUNC (c_max_subscript / 2);
         ELSIF l_position IS NULL THEN
            /*
              ** Tegemist seni vähima kuumaksu summaga mobiiliga. Lisatakse tabelisse kõige lõppu.
            */
            l_position := l_ordered_sum_tab.LAST + (c_max_subscript - l_ordered_sum_tab.LAST) / 2;
         END IF;

         --
         IF l_ordered_sum_tab.EXISTS (l_position) THEN
            /*
              ** Paha jama - vahemik on kusagilt otsa saanud. Ei oska küll sellise vahemiku suuruse juures
              ** seda varianti ette näha. Sel juhul on algoritm vigaseks osutunud.
            */
            p_error_text :=    'Viga algoritmis. Positsioonile '
                            || TO_CHAR (l_position)
                            || ' pretendeerivad 2 mobiili '
                            || ' SUSG= '
                            || TO_CHAR (p_inen_sum_tab (l_idx).susg_ref_num)
                            || ' kuumaksu summaga '
                            || TO_CHAR (p_inen_sum_tab (l_idx).amount)
                            || ' ja SUSG= '
                            || TO_CHAR (l_ordered_sum_tab (l_position).susg_ref_num)
                            || ' kuumaksu summaga '
                            || TO_CHAR (l_ordered_sum_tab (l_position).amount);
            RAISE e_invalid_algorithm;
         END IF;

         --
         l_ordered_sum_tab (l_position).susg_ref_num := p_inen_sum_tab (l_idx).susg_ref_num;
         l_ordered_sum_tab (l_position).amount := p_inen_sum_tab (l_idx).amount;
         l_ordered_sum_tab (l_position).sept_type_code := p_inen_sum_tab (l_idx).sept_type_code;
         l_ordered_sum_tab (l_position).start_date := p_inen_sum_tab (l_idx).start_date;
         --
         l_idx := p_inen_sum_tab.NEXT (l_idx);
      END LOOP;

      --
      p_success := TRUE;
      RETURN l_ordered_sum_tab;
   EXCEPTION
      WHEN e_invalid_algorithm THEN
         p_success := FALSE;
   END create_ordered_mon_chg_list;

   --
   PROCEDURE calc_non_prorata_maac_pkg_chg (
      p_maac_ref_num     IN      accounts.ref_num%TYPE
     ,p_susg_ref_num     IN      subs_serv_groups.ref_num%TYPE
     ,p_invo_ref_num     IN      invoices.ref_num%TYPE
     ,p_period_start     IN      DATE
     ,p_period_end       IN      DATE   -- 23:59:59
     ,p_success          OUT     BOOLEAN
     ,p_error_text       OUT     VARCHAR2
     ,p_interim_balance  IN      BOOLEAN DEFAULT FALSE
     ,p_regular_type     IN      fixed_charge_item_types.regular_charge%TYPE DEFAULT 'ALL'   --CHG-3714
   ) IS
      --
      CURSOR c_supa_minb IS
         SELECT   supa.sept_type_code
                 ,susg.ref_num susg_ref_num
                 ,supa.start_date
                 ,supa.end_date
                 ,susg.nety_type_code
                 ,sept.CATEGORY
             FROM subs_packages supa, subs_serv_groups susg, subs_accounts_v suac, serv_package_types sept
            WHERE suac.maac_ref_num = p_maac_ref_num
              AND supa.suac_ref_num = suac.ref_num
              AND susg.ref_num = supa.gsm_susg_ref_num
              AND susg.suac_ref_num = suac.ref_num
              AND (susg.ref_num = p_susg_ref_num OR p_susg_ref_num IS NULL)
              AND supa.start_date <= p_period_end
              AND NVL (supa.end_date, p_period_start) >= p_period_start
              AND sept.type_code = supa.sept_type_code
              AND NVL (sept.special_mark, '*') NOT IN ('PAK', 'PAT')   -- CHG-3345/CHG-3360
              AND EXISTS (SELECT 1
                            FROM fixed_charge_item_types   -- CHG-3714
                           WHERE sety_ref_num IS NULL
                             AND package_category = sept.CATEGORY
                             --AND nety_type_code = susg.nety_type_code -- CHG-3714: commented out
                             AND regular_charge = 'Y'
                             AND pro_rata = 'N'
                             AND once_off = 'N'
                             AND regular_type = 'MINB')   -- CHG-3714
         ORDER BY susg.ref_num, supa.start_date;

      -- CHG-3714
      CURSOR c_supa_repl IS
         SELECT   supa.sept_type_code
                 ,susg.ref_num susg_ref_num
                 ,supa.start_date
                 ,supa.end_date
                 ,susg.nety_type_code
                 ,sept.CATEGORY
             FROM subs_packages supa, subs_serv_groups susg, subs_accounts_v suac, serv_package_types sept
            WHERE suac.maac_ref_num = p_maac_ref_num
              AND supa.suac_ref_num = suac.ref_num
              AND susg.ref_num = supa.gsm_susg_ref_num
              AND susg.suac_ref_num = suac.ref_num
              AND (susg.ref_num = p_susg_ref_num OR p_susg_ref_num IS NULL)
              AND supa.start_date <= p_period_end
              AND NVL (supa.end_date, p_period_start) >= p_period_start
              AND sept.type_code = supa.sept_type_code
              AND NVL (sept.special_mark, '*') NOT IN ('PAK', 'PAT')   -- CHG-3345/CHG-3360
              AND EXISTS (SELECT 1
                            FROM fixed_charge_item_types
                           WHERE sety_ref_num IS NULL
                             AND package_category = sept.CATEGORY
                             AND regular_charge = 'Y'
                             AND pro_rata = 'N'
                             AND once_off = 'N'
                             AND regular_type = 'REPL')
         ORDER BY susg.ref_num, supa.start_date;

      --
      l_package_charge_set          BOOLEAN;
      l_last_susg_ref_num           subs_serv_groups.ref_num%TYPE;
      --
      e_calc_charge                 EXCEPTION;
   BEGIN
      IF p_regular_type IN ('ALL', 'MINB') THEN   -- CHG-3714
         /*
           ** Leiab Masteri jooksvas perioodis avatud pakettide hulgast ainult need, millede jaoks on
           ** hinnakirjas üldse olemas MINB tüüpi päevade arvust sõltumatu kuutasu (ülejäänusid pole üldse mõtet vaadata).
         */
         FOR l_supa IN c_supa_minb LOOP
            /*
              ** Samale mobiilile võib kuutasu peale panna ainult 1 kord. Kui on olnud paketivahetus ja
              ** kuutasu on peale pandud, siis ülejäänud sama mobiili kirjeid ignoreerida.
            */
            IF l_supa.susg_ref_num = l_last_susg_ref_num AND l_package_charge_set THEN
               l_last_susg_ref_num := l_supa.susg_ref_num;
            ELSE
               calc_non_prorata_package_chg (p_maac_ref_num   -- IN     master_accounts_v.ref_num %TYPE
                                            ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                            ,l_supa.susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                            ,l_supa.nety_type_code   -- IN     subs_serv_groups.nety_type_code%TYPE
                                            ,l_supa.sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                            ,l_supa.CATEGORY   -- IN     package_categories.package_category%TYPE
                                            ,p_period_start   -- IN     DATE
                                            ,p_period_end   -- IN     DATE   23:59:59
                                            ,l_supa.start_date   -- IN     DATE
                                            ,l_supa.end_date   -- IN     DATE
                                            ,p_success   --   OUT BOOLEAN
                                            ,p_error_text   --   OUT VARCHAR2
                                            ,l_package_charge_set   --   OUT BOOLEAN
                                            ,p_interim_balance   -- IN    BOOLEAN DEFAULT FALSE
                                            );

               IF NOT p_success THEN
                  RAISE e_calc_charge;
               END IF;

               --
               l_last_susg_ref_num := l_supa.susg_ref_num;
            END IF;
         END LOOP;
      --
      END IF;   -- CHG-3714

      IF p_regular_type IN ('ALL', 'REPL') THEN
         /*
           ** CHG-3714: ** Leiab Masteri jooksvas perioodis avatud pakettide hulgast ainult need,
           ** milledel jaoks on hinnakirjas üldse olemas REPL tüüpi päevade arvust sõltumatu kuutasu.
         */
         FOR l_supa IN c_supa_repl LOOP
            calc_non_prorata_package_repl (p_maac_ref_num   -- IN     master_accounts_v.ref_num %TYPE
                                          ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                                          ,l_supa.susg_ref_num   -- IN     subs_serv_groups.ref_num%TYPE
                                          ,l_supa.nety_type_code   -- IN     subs_serv_groups.nety_type_code%TYPE
                                          ,l_supa.sept_type_code   -- IN     serv_package_types.type_code%TYPE
                                          ,l_supa.CATEGORY   -- IN     package_categories.package_category%TYPE
                                          ,p_period_start   -- IN     DATE
                                          ,p_period_end   -- IN     DATE   23:59:59
                                          ,l_supa.start_date   -- IN     DATE
                                          ,l_supa.end_date   -- IN     DATE
                                          ,p_success   --   OUT BOOLEAN
                                          ,p_error_text   --   OUT VARCHAR2
                                          ,p_interim_balance   -- IN    BOOLEAN DEFAULT FALSE
                                          );

            IF NOT p_success THEN
               RAISE e_calc_charge;
            END IF;
         --
         END LOOP;
      --
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_calc_charge THEN
         p_success := FALSE;
   END calc_non_prorata_maac_pkg_chg;

   /*
     ** Protseduur kirjutab arveread PL/SQL tabelist AB tabelisse
   */
   PROCEDURE write_down_invoice_entries (
      p_inen_tab      IN OUT  t_inen
     ,p_invo_ref_num  IN      invoices.ref_num%TYPE
     ,p_module_ref    IN      invoice_entries.module_ref%TYPE
     ,p_interim       IN      BOOLEAN DEFAULT FALSE
   ) IS
      --
      TYPE t_acc_amount IS TABLE OF invoice_entries.acc_amount%TYPE
         INDEX BY BINARY_INTEGER;   -- CHG4594

      TYPE t_bise IS TABLE OF billing_selectors_v.type_code%TYPE
         INDEX BY BINARY_INTEGER;

      TYPE t_fcit IS TABLE OF fixed_charge_item_types.type_code%TYPE
         INDEX BY BINARY_INTEGER;

      TYPE t_taty IS TABLE OF tax_types.tax_type_code%TYPE
         INDEX BY BINARY_INTEGER;

      TYPE t_susg IS TABLE OF subs_serv_groups.ref_num%TYPE
         INDEX BY BINARY_INTEGER;

      TYPE t_maas IS TABLE OF master_account_services.ref_num%TYPE
         INDEX BY BINARY_INTEGER;

      TYPE t_num_days IS TABLE OF invoice_entries.num_of_days%TYPE
         INDEX BY BINARY_INTEGER;
      -- CHG-13617
      TYPE t_solution_fee_indicator IS TABLE OF invoice_entries.last_updated_by%TYPE
         INDEX BY BINARY_INTEGER;

      -- CHG-13617
      CURSOR c_inen_ref IS
         SELECT inen_ref_num_s.NEXTVAL
         FROM dual
      ;
      --
      l_idx                         NUMBER;
      l_count                       NUMBER := 0;
      l_acc_amount_tab              t_acc_amount;   -- CHG4594
      l_bise_tab                    t_bise;
      l_fcit_tab                    t_fcit;
      l_taty_tab                    t_taty;
      l_susg_tab                    t_susg;
      l_maas_tab                    t_maas;
      l_num_days_tab                t_num_days;
      l_indicator_tab               t_solution_fee_indicator;  -- CHG-13617
      l_inen_ref_num                NUMBER;                    -- CHG-13617
   BEGIN
      /*
        ** Kanname kõik arveread teise sama struktuuriga tabelisse, et kaotada indeksist võimalikud
        ** augud (võivad tekkida kallima variandi eelneva mahasalvestamisega) ning kasutada mass-insertimise eelist.
      */
      l_idx := p_inen_tab.FIRST;

      --
      WHILE l_idx IS NOT NULL LOOP
         p_inen_tab (l_idx).acc_amount := ROUND (p_inen_tab (l_idx).acc_amount, g_inen_acc_precision);   -- CHG4594
         p_inen_tab (l_idx).eek_amt := ROUND (p_inen_tab (l_idx).acc_amount, 2);   -- CHG4594
         --
         l_count := l_count + 1;
         l_acc_amount_tab (l_count) := p_inen_tab (l_idx).acc_amount;
         l_bise_tab (l_count) := p_inen_tab (l_idx).billing_selector;
         l_fcit_tab (l_count) := p_inen_tab (l_idx).fcit_type_code;
         l_taty_tab (l_count) := p_inen_tab (l_idx).taty_type_code;
         l_susg_tab (l_count) := p_inen_tab (l_idx).susg_ref_num;
         l_maas_tab (l_count) := p_inen_tab (l_idx).maas_ref_num;
         l_num_days_tab (l_count) := p_inen_tab (l_idx).num_of_days;
         l_indicator_tab (l_count) := p_inen_tab (l_idx).last_updated_by;  -- CHG-13617
         --
         l_idx := p_inen_tab.NEXT (l_idx);
      END LOOP;

      --
      IF p_interim = TRUE THEN
         FORALL i IN 1 .. l_count
            INSERT INTO invoice_entries_interim inen
                        (ref_num   --NOT NULL NUMBER(10)
                        ,invo_ref_num   --NOT NULL NUMBER(10)
                        ,eek_amt   --NOT NULL NUMBER(14,2)
                        ,rounding_indicator   --NOT NULL VARCHAR2(1)
                        ,under_dispute   --NOT NULL VARCHAR2(1)
                        ,created_by   --NOT NULL VARCHAR2(15)
                        ,date_created   --NOT NULL DATE
                        ,billing_selector   --         VARCHAR2(3)
                        ,fcit_type_code   --         VARCHAR2(3)
                        ,taty_type_code   --         VARCHAR2(3)
                        ,susg_ref_num   --         NUMBER(10)
                        ,manual_entry   --         VARCHAR2(1)
                        ,module_ref   --         VARCHAR2(4)
                        ,num_of_days   --         NUMBER(2)
                        ,maas_ref_num
                        )
                 VALUES (inen_ref_num_s.NEXTVAL
                        ,p_invo_ref_num
                        ,ROUND (l_acc_amount_tab (i), 2)   -- CHG4594
                        ,'N'
                        ,'N'
                        ,sec.get_username
                        ,SYSDATE
                        ,l_bise_tab (i)
                        ,l_fcit_tab (i)
                        ,l_taty_tab (i)
                        ,l_susg_tab (i)
                        ,'N'
                        ,NVL (p_module_ref, bcc_inve_mod_ref)
                        ,l_num_days_tab (i)
                        ,l_maas_tab (i)
                        );
      ELSE
         --FORALL i IN 1 .. l_count
         FOR i IN 1 .. l_count LOOP  -- CHG-13617
            -- CHG-13617
            OPEN  c_inen_ref;
            FETCH c_inen_ref INTO l_inen_ref_num;
            CLOSE c_inen_ref;
            --
            INSERT INTO invoice_entries inen
                        (ref_num   --NOT NULL NUMBER(10)
                        ,invo_ref_num   --NOT NULL NUMBER(10)
                        ,acc_amount   -- CHG4594, NOT NULL NUMBER(14,2)
                        ,rounding_indicator   --NOT NULL VARCHAR2(1)
                        ,under_dispute   --NOT NULL VARCHAR2(1)
                        ,created_by   --NOT NULL VARCHAR2(15)
                        ,date_created   --NOT NULL DATE
                        ,billing_selector   --         VARCHAR2(3)
                        ,fcit_type_code   --         VARCHAR2(3)
                        ,taty_type_code   --         VARCHAR2(3)
                        ,susg_ref_num   --         NUMBER(10)
                        ,manual_entry   --         VARCHAR2(1)
                        ,module_ref   --         VARCHAR2(4)
                        ,num_of_days   --         NUMBER(2)
                        ,maas_ref_num
                        ,pri_curr_code
                        )
                 VALUES (l_inen_ref_num  -- CHG-13617 inen_ref_num_s.NEXTVAL
                        ,p_invo_ref_num
                        ,l_acc_amount_tab (i)   -- CHG4594
                        ,'N'
                        ,'N'
                        ,sec.get_username
                        ,SYSDATE
                        ,l_bise_tab (i)
                        ,l_fcit_tab (i)
                        ,l_taty_tab (i)
                        ,l_susg_tab (i)
                        ,'N'
                        ,NVL (p_module_ref, bcc_inve_mod_ref)
                        ,l_num_days_tab (i)
                        ,l_maas_tab (i)
                        ,get_pri_curr_code ()
                        );
                        
            -- CHG-13617: Seome ära COMC tabelis olevad lahendustasu teenuste kirjed lisatud kirjega.
            IF l_indicator_tab (i) IS NOT NULL THEN
               --
               UPDATE common_monthly_charges
                  SET invo_inen_ref_num = l_inen_ref_num
                    , date_updated      = SYSDATE
                    , last_updated_by   = sec.get_username
                WHERE invo_ref_num = p_invo_ref_num
                  AND susg_ref_num = l_susg_tab (i)
                  AND last_updated_by = l_indicator_tab (i);
               --
            END IF;
            --
         END LOOP;  -- CHG-13617
      END IF;

      --
      p_inen_tab.DELETE;
   END write_down_invoice_entries;

   /*
     ** Protseduur leiab hinnakirjajärgse hinna või erihinna sellistele M/A teenustele,
     ** millede kuumaksude arvutus ei ole sõltuvuses kasutatud päevade arvust (prorata = N).
   */
   PROCEDURE get_non_prorata_ma_serv_price (
      p_maac_ref_num      IN      master_accounts_v.ref_num%TYPE
     ,p_maas_ref_num      IN      master_account_services.ref_num%TYPE
     ,p_sety_ref_num      IN      service_types.ref_num%TYPE
     ,p_period_end_date   IN      DATE
     ,p_chca_type_code    IN OUT  maac_charging_categories.chca_type_code%TYPE
     ,p_price             OUT     NUMBER
     ,p_taty_type_code    OUT     tax_types.tax_type_code%TYPE
     ,p_billing_selector  OUT     billing_selectors_v.type_code%TYPE
     ,p_fcit_type_code    OUT     fixed_charge_item_types.type_code%TYPE
     ,p_masa_rec          OUT     master_service_adjustments%ROWTYPE
   ) IS
      --
      CURSOR c_ficv IS
         SELECT fcit.type_code fcit_type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,ficv.charge_value charge_value
               ,ficv.sepv_ref_num sepv_ref_num
               ,ficv.sepa_ref_num sepa_ref_num
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit
          WHERE ficv.sety_ref_num = p_sety_ref_num
            AND ficv.sept_type_code IS NULL
            AND ficv.chca_type_code = p_chca_type_code
            AND ficv.channel_type IS NULL
            AND NVL (ficv.par_value_charge, 'N') = 'N'
            AND ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = 'N'
            AND fcit.pro_rata = 'N'
            AND fcit.regular_charge = 'Y'
            AND TRUNC (p_period_end_date) BETWEEN ficv.start_date AND NVL (ficv.end_date, TRUNC (p_period_end_date));

      --
      CURSOR c_prli IS
         SELECT fcit.type_code fcit_type_code
               ,fcit.taty_type_code taty_type_code
               ,fcit.billing_selector billing_selector
               ,prli.charge_value charge_value
               ,prli.sepv_ref_num sepv_ref_num
               ,prli.sepa_ref_num sepa_ref_num
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
            AND TRUNC (p_period_end_date) BETWEEN prli.start_date AND NVL (prli.end_date, TRUNC (p_period_end_date));

      --
      l_sepv_ref_num                service_param_values.ref_num%TYPE;
      l_price                       NUMBER;
   BEGIN
      /*
        ** Leiame M/A kehtiva hinnakategooria
      */
      IF p_chca_type_code IS NULL THEN
         p_chca_type_code := get_master_chca (p_maac_ref_num   -- IN master_accounts_v.ref_num%TYPE
                                             ,p_period_end_date   -- IN DATE
                                             );
      END IF;

      /*
        ** Kontrollime, kas antud hinnakategooriale on registreeritud eritariif
      */
      FOR l_ficv IN c_ficv LOOP
         /*
           ** Kui tariif on antud parameetri väärtuse alusel, siis tuleb leida ka kehtiv parameetri väärtus
         */
         IF l_ficv.sepa_ref_num IS NOT NULL AND l_sepv_ref_num IS NULL THEN
            l_sepv_ref_num :=
               get_master_service_parameter (p_maas_ref_num   -- IN master_account_services.ref_num%TYPE
                                            ,l_ficv.sepa_ref_num   --  IN service_parameters.ref_num%TYPE
                                            ,p_period_end_date   -- IN DATE
                                            ).sepv_ref_num;
         END IF;

         --
         IF (l_ficv.sepa_ref_num IS NOT NULL AND l_ficv.sepv_ref_num = l_sepv_ref_num) OR l_ficv.sepa_ref_num IS NULL THEN
            l_price := GREATEST (l_ficv.charge_value, 0);
            p_taty_type_code := l_ficv.taty_type_code;
            p_billing_selector := l_ficv.billing_selector;
            p_fcit_type_code := l_ficv.fcit_type_code;
            EXIT;
         END IF;
      END LOOP;

      /*
        ** Kui eritariifi pole registreeritud, siis leiame hinnakirja järgse üldise tariifi.
      */
      IF l_price IS NULL THEN
         FOR l_prli IN c_prli LOOP
            /*
              ** Kui tariif on antud parameetri väärtuse alusel, siis tuleb leida ka kehtiv parameetri väärtus
            */
            IF l_prli.sepa_ref_num IS NOT NULL AND l_sepv_ref_num IS NULL THEN
               l_sepv_ref_num :=
                  get_master_service_parameter (p_maas_ref_num   -- IN master_account_services.ref_num%TYPE
                                               ,l_prli.sepa_ref_num   --  IN service_parameters.ref_num%TYPE
                                               ,p_period_end_date   -- IN DATE
                                               ).sepv_ref_num;
            END IF;

            --
            IF (l_prli.sepa_ref_num IS NOT NULL AND l_prli.sepv_ref_num = l_sepv_ref_num) OR l_prli.sepa_ref_num IS NULL THEN
               l_price := GREATEST (l_prli.charge_value, 0);
               p_taty_type_code := l_prli.taty_type_code;
               p_billing_selector := l_prli.billing_selector;
               p_fcit_type_code := l_prli.fcit_type_code;
               EXIT;
            END IF;
         END LOOP;
      END IF;

      --
      IF NVL (l_price, 0) > 0 THEN
         /*
           ** Leiame, kas M/A teenusele on perioodi lõpu seisuga registreeritud soodustus
         */
         p_masa_rec := get_master_service_adjustment (p_maas_ref_num   -- IN master_account_services.ref_num%TYPE
                                                     ,p_period_end_date   -- IN DATE
                                                     ,p_fcit_type_code   -- IN fixed_charge_item_types.type_code%TYPE
                                                     ,p_billing_selector   -- IN billing_selectors_v.type_code%TYPE
                                                     );

         IF p_masa_rec.ref_num IS NOT NULL THEN
            IF p_masa_rec.cadc_ref_num IS NOT NULL THEN
               /*
                 ** Need on kampaaniaga seotud soodustused, millised vajavad erikäsitlust.
               */
               NULL;
            ELSE
               /*
                 ** Kampaaniaga mitte seotud soodustused. Nende korral leitakse teenusele kehtiv erihind
                 ** (mitte soodustus!!!), milline kantaksegi arvele.
               */
               IF p_masa_rec.charge_value IS NOT NULL THEN
                  l_price := LEAST (GREATEST (p_masa_rec.charge_value, 0), l_price);
               ELSIF p_masa_rec.credit_rate_value >= 100 THEN
                  l_price := 0;
               ELSIF p_masa_rec.credit_rate_value IS NOT NULL THEN
                  l_price := GREATEST (l_price - ((p_masa_rec.credit_rate_value / 100) * l_price), 0);
               END IF;
            END IF;
         END IF;
      END IF;

      --
      p_price := l_price;
   END get_non_prorata_ma_serv_price;

   /*
     ** Protseduur leiab hinnakirjajärgse hinna või erihinna sellistele mobiili taseme teenustele,
     ** millede kuutasude arvutus ei ole sõltuvuses kasutatud päevade arvust (prorata = N).
   */
   PROCEDURE get_non_prorata_mob_serv_price (
      p_susg_ref_num      IN      subs_serv_groups.ref_num%TYPE
     ,p_sety_ref_num      IN      service_types.ref_num%TYPE
     ,p_end_date          IN      DATE
     ,p_channel           IN      price_lists.channel_type%TYPE
     ,p_sept_type_code    IN      serv_package_types.type_code%TYPE
     ,p_category          IN      serv_package_types.CATEGORY%TYPE
     ,p_price             OUT     NUMBER
     ,p_taty_type_code    OUT     tax_types.tax_type_code%TYPE
     ,p_billing_selector  OUT     billing_selectors_v.type_code%TYPE
     ,p_fcit_type_code    OUT     fixed_charge_item_types.type_code%TYPE
     ,p_sepv_ref_num      OUT     service_param_values.ref_num%TYPE
   ) IS
      --
      CURSOR c_ficv IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,ficv.charge_value charge_value
                 ,ficv.sepv_ref_num sepv_ref_num
                 ,ficv.sepa_ref_num sepa_ref_num
             FROM fixed_charge_values ficv, fixed_charge_item_types fcit
            WHERE ficv.sety_ref_num = p_sety_ref_num
              AND ficv.sept_type_code = p_sept_type_code
              AND ficv.chca_type_code IS NULL
              AND NVL (ficv.channel_type, p_channel) = p_channel
              AND NVL (ficv.par_value_charge, 'N') = 'N'
              AND ficv.fcit_charge_code = fcit.type_code
              AND fcit.once_off = 'N'
              AND fcit.pro_rata = 'N'
              AND fcit.regular_charge = 'Y'
              AND TRUNC (p_end_date) BETWEEN ficv.start_date AND NVL (ficv.end_date, TRUNC (p_end_date))
         ORDER BY ficv.channel_type, ficv.sepa_ref_num;

      --
      CURSOR c_prli IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,prli.charge_value charge_value
                 ,prli.sepv_ref_num sepv_ref_num
                 ,prli.sepa_ref_num sepa_ref_num
             FROM price_lists prli, fixed_charge_item_types fcit
            WHERE prli.sety_ref_num = p_sety_ref_num
              AND NVL (prli.channel_type, p_channel) = p_channel
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
              AND TRUNC (p_end_date) BETWEEN prli.start_date AND NVL (prli.end_date, TRUNC (p_end_date))
         ORDER BY prli.package_category, prli.channel_type, prli.sepa_ref_num;

      --
      l_sepv_ref_num                service_param_values.ref_num%TYPE;
      l_price                       NUMBER;
   BEGIN
      /*
        ** Kontrollime, kas antud teenuspaketile on registreeritud eritariif
      */
      FOR l_ficv IN c_ficv LOOP
         /*
           ** Kui tariif on antud parameetri väärtuse alusel, siis tuleb leida ka kehtiv parameetri väärtus
         */
         IF l_ficv.sepa_ref_num IS NOT NULL AND l_sepv_ref_num IS NULL THEN
            l_sepv_ref_num :=
               get_subs_service_parameter (p_susg_ref_num   -- IN subs_serv_groups.ref_num%TYPE
                                          ,p_sety_ref_num   -- IN service_types.ref_num%TYPE
                                          ,l_ficv.sepa_ref_num   -- IN service_parameters.ref_num%TYPE
                                          ,p_end_date   -- IN DATE
                                          ).sepv_ref_num;
         END IF;

         --
         IF (l_ficv.sepa_ref_num IS NOT NULL AND l_ficv.sepv_ref_num = l_sepv_ref_num) OR l_ficv.sepa_ref_num IS NULL THEN
            l_price := GREATEST (l_ficv.charge_value, 0);
            p_taty_type_code := l_ficv.taty_type_code;
            p_billing_selector := l_ficv.billing_selector;
            p_fcit_type_code := l_ficv.fcit_type_code;
            EXIT;
         END IF;
      END LOOP;

      /*
        ** Kui eritariifi pole registreeritud, siis leiame hinnakirja järgse üldise tariifi.
      */
      IF l_price IS NULL THEN
         FOR l_prli IN c_prli LOOP
            /*
              ** Kui tariif on antud parameetri väärtuse alusel, siis tuleb leida ka kehtiv parameetri väärtus
            */
            IF l_prli.sepa_ref_num IS NOT NULL AND l_sepv_ref_num IS NULL THEN
               l_sepv_ref_num :=
                  get_subs_service_parameter (p_susg_ref_num   -- IN subs_serv_groups.ref_num%TYPE
                                             ,p_sety_ref_num   -- IN service_types.ref_num%TYPE
                                             ,l_prli.sepa_ref_num   -- IN service_parameters.ref_num%TYPE
                                             ,p_end_date   -- IN DATE
                                             ).sepv_ref_num;
            END IF;

            --
            IF (l_prli.sepa_ref_num IS NOT NULL AND l_prli.sepv_ref_num = l_sepv_ref_num) OR l_prli.sepa_ref_num IS NULL THEN
               l_price := GREATEST (l_prli.charge_value, 0);
               p_taty_type_code := l_prli.taty_type_code;
               p_billing_selector := l_prli.billing_selector;
               p_fcit_type_code := l_prli.fcit_type_code;
               EXIT;
            END IF;
         END LOOP;
      END IF;

      --
      p_price := l_price;
      p_sepv_ref_num := l_sepv_ref_num;
   END get_non_prorata_mob_serv_price;

   --
   FUNCTION get_fcit_rec (
      p_fcit_type_code  IN  fixed_charge_item_types.type_code%TYPE
   )
      RETURN fixed_charge_item_types%ROWTYPE IS
      --
      CURSOR c_fcit IS
         SELECT *
           FROM fixed_charge_item_types
          WHERE type_code = p_fcit_type_code;

      --
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;
   BEGIN
      OPEN c_fcit;

      FETCH c_fcit
       INTO l_fcit_rec;

      CLOSE c_fcit;

      --
      RETURN l_fcit_rec;
   END get_fcit_rec;

   /*
     ** Prorata teenusepaketijärgse eritariifi leidmine.
     ** Selle puudumisel leitakse hinnakirjajärgne tariif.
   */
   PROCEDURE get_prorata_mob_serv_price (
      p_susg_ref_num      IN      subs_serv_groups.ref_num%TYPE
     ,p_sety_ref_num      IN      service_types.ref_num%TYPE
     ,p_chk_date          IN      DATE
     ,p_channel           IN      price_lists.channel_type%TYPE
     ,p_sept_type_code    IN      serv_package_types.type_code%TYPE
     ,p_category          IN      serv_package_types.CATEGORY%TYPE
     ,p_price             OUT     NUMBER
     ,p_pro_rata          OUT     fixed_charge_item_types.pro_rata%TYPE
     ,p_taty_type_code    OUT     tax_types.tax_type_code%TYPE
     ,p_billing_selector  OUT     billing_selectors_v.type_code%TYPE
     ,p_fcit_type_code    OUT     fixed_charge_item_types.type_code%TYPE
     ,p_sepv_ref_num      OUT     service_param_values.ref_num%TYPE
   ) IS
      --
      CURSOR c_ficv IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.pro_rata pro_rata
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,ficv.charge_value charge_value
                 ,ficv.sepv_ref_num sepv_ref_num
                 ,ficv.sepa_ref_num sepa_ref_num
             FROM fixed_charge_values ficv, fixed_charge_item_types fcit
            WHERE ficv.sety_ref_num = p_sety_ref_num
              AND ficv.sept_type_code = p_sept_type_code
              AND ficv.chca_type_code IS NULL
              AND NVL (ficv.channel_type, p_channel) = p_channel
              AND NVL (ficv.par_value_charge, 'N') = 'N'
              AND ficv.fcit_charge_code = fcit.type_code
              AND fcit.once_off = 'N'
              AND fcit.regular_charge = 'Y'
              AND TRUNC (p_chk_date) BETWEEN ficv.start_date AND NVL (ficv.end_date, TRUNC (p_chk_date))
         ORDER BY ficv.channel_type, ficv.sepa_ref_num;

      --
      CURSOR c_prli IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.pro_rata pro_rata
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,prli.charge_value charge_value
                 ,prli.sepv_ref_num sepv_ref_num
                 ,prli.sepa_ref_num sepa_ref_num
             FROM price_lists prli, fixed_charge_item_types fcit
            WHERE prli.sety_ref_num = p_sety_ref_num
              AND NVL (prli.channel_type, p_channel) = p_channel
              AND NVL (prli.par_value_charge, 'N') = 'N'
              AND prli.once_off = 'N'
              AND prli.regular_charge = 'Y'
              AND fcit.once_off = 'N'
              AND fcit.regular_charge = 'Y'
              AND prli.sety_ref_num = fcit.sety_ref_num
              AND fcit.package_category = p_category
              AND (fcit.package_category = prli.package_category OR prli.package_category IS NULL)
              AND TRUNC (p_chk_date) BETWEEN prli.start_date AND NVL (prli.end_date, TRUNC (p_chk_date))
         ORDER BY prli.package_category, prli.channel_type, prli.sepa_ref_num;

      --
      l_sepv_ref_num                service_param_values.ref_num%TYPE;
      l_price                       NUMBER;
   --
   BEGIN
      -- Kontrollime, kas antud teenuspaketile on registreeritud eritariif
      FOR l_ficv IN c_ficv LOOP
         -- Kui tariif on antud parameetri väärtuse alusel, siis tuleb leida ka kehtiv parameetri väärtus
         IF l_ficv.sepa_ref_num IS NOT NULL AND l_sepv_ref_num IS NULL THEN
            l_sepv_ref_num := get_subs_service_parameter (p_susg_ref_num
                                                         ,p_sety_ref_num
                                                         ,l_ficv.sepa_ref_num
                                                         ,p_chk_date
                                                         ).sepv_ref_num;
         END IF;

         --
         IF (l_ficv.sepa_ref_num IS NOT NULL AND l_ficv.sepv_ref_num = l_sepv_ref_num) OR l_ficv.sepa_ref_num IS NULL THEN
            l_price := GREATEST (l_ficv.charge_value, 0);
            p_pro_rata := l_ficv.pro_rata;
            p_taty_type_code := l_ficv.taty_type_code;
            p_billing_selector := l_ficv.billing_selector;
            p_fcit_type_code := l_ficv.fcit_type_code;
            --
            EXIT;
         END IF;
      --
      END LOOP;

      -- Kui eritariifi pole registreeritud, siis leiame hinnakirja järgse üldise tariifi.
      IF l_price IS NULL THEN
         FOR l_prli IN c_prli LOOP
            -- Kui tariif on antud parameetri väärtuse alusel,
            -- siis tuleb leida ka kehtiv parameetri väärtus
            IF l_prli.sepa_ref_num IS NOT NULL AND l_sepv_ref_num IS NULL THEN
               l_sepv_ref_num := get_subs_service_parameter (p_susg_ref_num
                                                            ,p_sety_ref_num
                                                            ,l_prli.sepa_ref_num
                                                            ,p_chk_date
                                                            ).sepv_ref_num;
            END IF;

            --
            IF (l_prli.sepa_ref_num IS NOT NULL AND l_prli.sepv_ref_num = l_sepv_ref_num) OR l_prli.sepa_ref_num IS NULL THEN
               l_price := GREATEST (l_prli.charge_value, 0);
               p_pro_rata := l_prli.pro_rata;
               p_taty_type_code := l_prli.taty_type_code;
               p_billing_selector := l_prli.billing_selector;
               p_fcit_type_code := l_prli.fcit_type_code;
               --
               EXIT;
            END IF;
         END LOOP;
      END IF;

      --
      p_price := l_price;
      p_sepv_ref_num := l_sepv_ref_num;
   --
   END get_prorata_mob_serv_price;

   /*
     ** Protseduur leiab OnceOff dokumendi teenuse Masteri või mobiilitasemel
     ** erihinna või selle puudumisel hinnakirjajärgse hinna.
     ** Esmalt otsitakse hinda kanali järgi, seejärel ilma kanalita.
   */
   PROCEDURE get_oo_service_price (
      p_maac_ref_num      IN      master_accounts_v.ref_num%TYPE
     ,p_susg_ref_num      IN      subscriber_details.exis_susg_ref_num%TYPE
     ,p_sety_ref_num      IN      service_types.ref_num%TYPE
     ,p_package_type      IN      subs_packages.sept_type_code%TYPE
     ,p_package_category  IN      serv_package_types.CATEGORY%TYPE
     ,p_param_table       IN      or_common.nw_param_table
     ,p_sety_secl_class   IN      service_types.secl_class_code%TYPE
     ,p_channel_type      IN      user_requests.channel_type%TYPE
     ,p_order_date        IN      DATE
     ,p_chca_type_code    IN      maac_charging_categories.chca_type_code%TYPE
     ,p_price             OUT     NUMBER
     ,p_taty_type_code    OUT     tax_types.tax_type_code%TYPE
     ,p_billing_selector  OUT     billing_selectors_v.type_code%TYPE
     ,p_fcit_type_code    OUT     fixed_charge_item_types.type_code%TYPE
   ) IS
      --
      c_no_channel         CONSTANT VARCHAR2 (10) := 'NOCHANNEL';

      --
      CURSOR c_ficv_ma (
         p_channel  VARCHAR2
      ) IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,ficv.charge_value charge_value
                 ,ficv.sepv_ref_num sepv_ref_num
                 ,ficv.sepa_ref_num sepa_ref_num
             FROM fixed_charge_values ficv, fixed_charge_item_types fcit
            WHERE ficv.sety_ref_num = p_sety_ref_num
              AND ficv.sept_type_code IS NULL
              AND ficv.chca_type_code = p_chca_type_code
              AND (ficv.channel_type = p_channel OR ficv.channel_type IS NULL AND p_channel = c_no_channel)
              AND NVL (ficv.par_value_charge, 'N') = 'N'
              AND ficv.fcit_charge_code = fcit.type_code
              AND fcit.once_off = 'Y'
              AND fcit.pro_rata = 'N'
              AND fcit.regular_charge = 'N'
              AND TRUNC (p_order_date) BETWEEN ficv.start_date AND NVL (ficv.end_date, TRUNC (p_order_date))
         ORDER BY ficv.channel_type, ficv.sepa_ref_num;

      --
      CURSOR c_prli_ma (
         p_channel  VARCHAR2
      ) IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,prli.charge_value charge_value
                 ,prli.sepv_ref_num sepv_ref_num
                 ,prli.sepa_ref_num sepa_ref_num
             FROM price_lists prli, fixed_charge_item_types fcit
            WHERE prli.sety_ref_num = p_sety_ref_num
              AND (prli.channel_type = p_channel OR prli.channel_type IS NULL AND p_channel = c_no_channel)
              AND NVL (prli.par_value_charge, 'N') = 'N'
              AND prli.once_off = 'Y'
              AND prli.pro_rata = 'N'
              AND prli.regular_charge = 'N'
              AND fcit.once_off = 'Y'
              AND fcit.pro_rata = 'N'
              AND fcit.regular_charge = 'N'
              AND prli.sety_ref_num = fcit.sety_ref_num
              AND fcit.package_category IS NULL
              AND TRUNC (p_order_date) BETWEEN prli.start_date AND NVL (prli.end_date, TRUNC (p_order_date))
         ORDER BY prli.channel_type, prli.sepa_ref_num;

      --
      CURSOR c_ficv_mo (
         p_channel  VARCHAR2
      ) IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,ficv.charge_value charge_value
                 ,ficv.sepv_ref_num sepv_ref_num
                 ,ficv.sepa_ref_num sepa_ref_num
             FROM fixed_charge_values ficv, fixed_charge_item_types fcit
            WHERE ficv.sety_ref_num = p_sety_ref_num
              AND ficv.sept_type_code = p_package_type
              AND ficv.chca_type_code IS NULL
              AND (ficv.channel_type = p_channel OR ficv.channel_type IS NULL AND p_channel = c_no_channel)
              AND NVL (ficv.par_value_charge, 'N') = 'N'
              AND ficv.fcit_charge_code = fcit.type_code
              AND fcit.once_off = 'Y'
              AND fcit.pro_rata = 'N'
              AND fcit.regular_charge = 'N'
              AND TRUNC (p_order_date) BETWEEN ficv.start_date AND NVL (ficv.end_date, TRUNC (p_order_date))
         ORDER BY ficv.channel_type, ficv.sepa_ref_num;

      --
      CURSOR c_prli_mo (
         p_channel  VARCHAR2
      ) IS
         SELECT   fcit.type_code fcit_type_code
                 ,fcit.taty_type_code taty_type_code
                 ,fcit.billing_selector billing_selector
                 ,prli.charge_value charge_value
                 ,prli.sepv_ref_num sepv_ref_num
                 ,prli.sepa_ref_num sepa_ref_num
             FROM price_lists prli, fixed_charge_item_types fcit
            WHERE prli.sety_ref_num = p_sety_ref_num
              AND (prli.channel_type = p_channel OR prli.channel_type IS NULL AND p_channel = c_no_channel)
              AND NVL (prli.par_value_charge, 'N') = 'N'
              AND prli.once_off = 'Y'
              AND prli.pro_rata = 'N'
              AND prli.regular_charge = 'N'
              AND fcit.once_off = 'Y'
              AND fcit.pro_rata = 'N'
              AND fcit.regular_charge = 'N'
              AND prli.sety_ref_num = fcit.sety_ref_num
              AND fcit.package_category = p_package_category
              AND (fcit.package_category = prli.package_category OR prli.package_category IS NULL)
              AND TRUNC (p_order_date) BETWEEN prli.start_date AND NVL (prli.end_date, TRUNC (p_order_date))
         ORDER BY prli.package_category, prli.channel_type, prli.sepa_ref_num;

      --
      l_channel_tab                 t_varchar10;
      l_sepv_ref_num                service_param_values.ref_num%TYPE;
      l_price                       NUMBER;
      l_ch_idx                      NUMBER;
      l_idx                         NUMBER;
      --
      e_price_found                 EXCEPTION;
   BEGIN
      -- Esmalt käime kursorid läbi kanaliga. Seejärel ilma kanalita, kui hinda pole leitud.
      -- Täidame kanali tabeli
      l_channel_tab (1) := p_channel_type;
      l_channel_tab (2) := c_no_channel;
      l_ch_idx := l_channel_tab.FIRST;

      WHILE l_ch_idx IS NOT NULL LOOP
         -- Masterkonto onceoff teenus
         IF p_sety_secl_class = 'Q' THEN
            -- Kontrollida, kas antud ma hinnakategooriale on registreeritud erihind
            FOR l_ficv IN c_ficv_ma (l_channel_tab (l_ch_idx)) LOOP
               -- Kui hind on antud parameetri väärtuse alusel,
               -- siis tuleb leida hinnastatud tellitud parameetri väärtus
               IF l_ficv.sepa_ref_num IS NOT NULL AND l_sepv_ref_num IS NULL THEN
                  l_idx := p_param_table.FIRST;

                  WHILE l_idx IS NOT NULL LOOP
                     IF p_param_table (l_idx).sepv_ref_num = l_ficv.sepv_ref_num THEN
                        l_sepv_ref_num := l_ficv.sepv_ref_num;
                     END IF;

                     --
                     l_idx := p_param_table.NEXT (l_idx);
                  END LOOP;
               END IF;

               --
               IF    (l_ficv.sepa_ref_num IS NOT NULL AND l_ficv.sepv_ref_num = l_sepv_ref_num)
                  OR l_ficv.sepa_ref_num IS NULL THEN
                  l_price := GREATEST (l_ficv.charge_value, 0);
                  p_taty_type_code := l_ficv.taty_type_code;
                  p_billing_selector := l_ficv.billing_selector;
                  p_fcit_type_code := l_ficv.fcit_type_code;
                  RAISE e_price_found;
               END IF;
            END LOOP;

            --Kui erihinda pole defineeritud, siis leiame hinnakirja järgse ületuru hinna.
            IF l_price IS NULL THEN
               FOR l_prli IN c_prli_ma (l_channel_tab (l_ch_idx)) LOOP
                  -- Kui tariif on antud parameetri väärtuse alusel,
                  -- siis tuleb leida hinnastatud tellitud parameetri väärtus
                  IF l_prli.sepa_ref_num IS NOT NULL AND l_sepv_ref_num IS NULL THEN
                     l_idx := p_param_table.FIRST;

                     WHILE l_idx IS NOT NULL LOOP
                        IF p_param_table (l_idx).sepv_ref_num = l_prli.sepv_ref_num THEN
                           l_sepv_ref_num := l_prli.sepv_ref_num;
                        END IF;

                        --
                        l_idx := p_param_table.NEXT (l_idx);
                     END LOOP;
                  END IF;

                  --
                  IF (   (l_prli.sepa_ref_num IS NOT NULL AND l_prli.sepv_ref_num = l_sepv_ref_num)
                      OR l_prli.sepa_ref_num IS NULL
                     ) THEN
                     l_price := GREATEST (l_prli.charge_value, 0);
                     p_taty_type_code := l_prli.taty_type_code;
                     p_billing_selector := l_prli.billing_selector;
                     p_fcit_type_code := l_prli.fcit_type_code;
                     RAISE e_price_found;
                  END IF;
               END LOOP;
            END IF;

            p_price := l_price;
         END IF;   -- End Q

         --
         --  Mobiili onceoff teenus
         IF p_sety_secl_class = 'O' THEN
            -- Kontrollida, kas antud mobiili teenuspaketiga on registreeritud erihind
            FOR l_ficv IN c_ficv_mo (l_channel_tab (l_ch_idx)) LOOP
               -- Kui hind on antud parameetri väärtuse alusel, siis tuleb leida hinnastatud tellitud parameetri väärtus
               IF l_ficv.sepa_ref_num IS NOT NULL AND l_sepv_ref_num IS NULL THEN
                  l_idx := p_param_table.FIRST;

                  WHILE l_idx IS NOT NULL LOOP
                     IF p_param_table (l_idx).sepv_ref_num = l_ficv.sepv_ref_num THEN
                        l_sepv_ref_num := l_ficv.sepv_ref_num;
                     END IF;

                     --
                     l_idx := p_param_table.NEXT (l_idx);
                  END LOOP;
               END IF;

               --
               IF    (l_ficv.sepa_ref_num IS NOT NULL AND l_ficv.sepv_ref_num = l_sepv_ref_num)
                  OR l_ficv.sepa_ref_num IS NULL THEN
                  l_price := GREATEST (l_ficv.charge_value, 0);
                  p_taty_type_code := l_ficv.taty_type_code;
                  p_billing_selector := l_ficv.billing_selector;
                  p_fcit_type_code := l_ficv.fcit_type_code;
                  RAISE e_price_found;
               END IF;
            END LOOP;

            --Kui erihinda pole defineeritud, siis leiame hinnakirja järgse ületuru hinna.
            IF l_price IS NULL THEN
               FOR l_prli IN c_prli_mo (l_channel_tab (l_ch_idx)) LOOP
                  -- Kui tariif on antud parameetri väärtuse alusel,
                  -- siis tuleb leida hinnastatud tellitud parameetri väärtus
                  IF l_prli.sepa_ref_num IS NOT NULL AND l_sepv_ref_num IS NULL THEN
                     l_idx := p_param_table.FIRST;

                     WHILE l_idx IS NOT NULL LOOP
                        IF p_param_table (l_idx).sepv_ref_num = l_prli.sepv_ref_num THEN
                           l_sepv_ref_num := l_prli.sepv_ref_num;
                        END IF;

                        --
                        l_idx := p_param_table.NEXT (l_idx);
                     END LOOP;
                  END IF;

                  --
                  IF    (l_prli.sepa_ref_num IS NOT NULL AND l_prli.sepv_ref_num = l_sepv_ref_num)
                     OR l_prli.sepa_ref_num IS NULL THEN
                     l_price := GREATEST (l_prli.charge_value, 0);
                     p_taty_type_code := l_prli.taty_type_code;
                     p_billing_selector := l_prli.billing_selector;
                     p_fcit_type_code := l_prli.fcit_type_code;
                     RAISE e_price_found;
                  END IF;
               END LOOP;
            END IF;

            p_price := l_price;
         END IF;   -- O

         l_ch_idx := l_channel_tab.NEXT (l_ch_idx);
      --
      END LOOP;
   EXCEPTION
      WHEN e_price_found THEN
         -- Hind leitud, väljume protseduurist
         p_price := l_price;
   END get_oo_service_price;

   /*
     ** Protseduur leiab teenustasu määrava teenuse olemasolul kui selline defineeritud.
   */
   PROCEDURE get_dependent_price (
      p_sety_ref_num      IN      service_types.ref_num%TYPE
     ,p_once_off          IN      fixed_charge_item_types.once_off%TYPE
     ,p_pro_rata          IN      fixed_charge_item_types.pro_rata%TYPE
     ,p_regular_charge    IN      fixed_charge_item_types.regular_charge%TYPE
     ,p_chk_date          IN      DATE
     ,p_package           IN      serv_package_types.type_code%TYPE
     ,p_category          IN      package_categories.package_category%TYPE
     ,p_chca_type_code    IN      fixed_dependent_prices.charging_category%TYPE
     ,p_channel_type      IN      fixed_special_prices.channel_type%TYPE
     ,p_susg_ref_num      IN      subs_serv_groups.ref_num%TYPE
     ,p_maac_ref_num      IN      accounts.ref_num%TYPE
     ,p_fcit_type_code    OUT     fixed_charge_item_types.type_code%TYPE
     ,p_charge_value      OUT     fixed_special_prices.charge_value%TYPE
     ,p_taty_type_code    OUT     tax_types.tax_type_code%TYPE
     ,p_billing_selector  OUT     fixed_charge_item_types.billing_selector%TYPE
     ,p_fcdt_type_code    OUT     fixed_charge_item_types.fcdt_type_code%TYPE
     ,p_tax               OUT     NUMBER
   ) IS
      --
      CURSOR c_fidp_sept IS
         SELECT   fidp.fcit_type_code
                 ,fidp.key_sety_ref_num
                 ,fidp.key_charge_value
                 ,fcit.taty_type_code
                 ,fcit.billing_selector
                 ,fcit.fcdt_type_code
                 , gen_bill.get_tax_rate (fcit.taty_type_code, p_chk_date) * fidp.key_charge_value tax
             FROM fixed_dependent_prices fidp, fixed_charge_item_types fcit
            WHERE fcit.type_code = fidp.fcit_type_code
              AND fidp.sety_ref_num = p_sety_ref_num
              AND fidp.once_off = p_once_off
              AND fidp.pro_rata = p_pro_rata
              AND fidp.regular_charge = p_regular_charge
              AND NVL (fidp.channel_type, NVL (p_channel_type, '***')) = NVL (p_channel_type, '***')
              AND fidp.package_category = p_category
              AND fidp.sept_type_code = p_package
              AND p_chk_date BETWEEN fidp.start_date AND NVL (fidp.end_date, p_chk_date)
         ORDER BY fidp.channel_type;

      --
      CURSOR c_fidp_cat IS
         SELECT   fidp.fcit_type_code
                 ,fidp.key_sety_ref_num
                 ,fidp.key_charge_value
                 ,fcit.taty_type_code
                 ,fcit.billing_selector
                 ,fcit.fcdt_type_code
                 , gen_bill.get_tax_rate (fcit.taty_type_code, p_chk_date) * fidp.key_charge_value tax
             FROM fixed_dependent_prices fidp, fixed_charge_item_types fcit
            WHERE fcit.type_code = fidp.fcit_type_code
              AND fidp.sety_ref_num = p_sety_ref_num
              AND fidp.once_off = p_once_off
              AND fidp.pro_rata = p_pro_rata
              AND fidp.regular_charge = p_regular_charge
              AND NVL (fidp.channel_type, NVL (p_channel_type, '***')) = NVL (p_channel_type, '***')
              AND fidp.package_category = p_category
              AND fidp.sept_type_code IS NULL
              AND p_chk_date BETWEEN fidp.start_date AND NVL (fidp.end_date, p_chk_date)
         ORDER BY fidp.channel_type;

      --
      CURSOR c_fidp_chca IS
         SELECT   fidp.fcit_type_code
                 ,fidp.key_sety_ref_num
                 ,fidp.key_charge_value
                 ,fcit.taty_type_code
                 ,fcit.billing_selector
                 ,fcit.fcdt_type_code
                 , gen_bill.get_tax_rate (fcit.taty_type_code, p_chk_date) * fidp.key_charge_value tax
             FROM fixed_dependent_prices fidp, fixed_charge_item_types fcit
            WHERE fcit.type_code = fidp.fcit_type_code
              AND fidp.sety_ref_num = p_sety_ref_num
              AND fidp.once_off = p_once_off
              AND fidp.pro_rata = p_pro_rata
              AND fidp.regular_charge = p_regular_charge
              AND NVL (fidp.channel_type, NVL (p_channel_type, '***')) = NVL (p_channel_type, '***')
              AND NVL (fidp.charging_category, NVL (p_chca_type_code, '***')) = NVL (p_chca_type_code, '***')
              AND p_chk_date BETWEEN fidp.start_date AND NVL (fidp.end_date, p_chk_date)
         ORDER BY fidp.channel_type, fidp.charging_category;

      --
      CURSOR c_chk_maas (
         p_key_sety_ref_num  service_types.ref_num%TYPE
      ) IS
         SELECT 1
           FROM master_account_services
          WHERE maac_ref_num = p_maac_ref_num
            AND sety_ref_num = p_key_sety_ref_num
            AND p_chk_date BETWEEN start_date AND NVL (end_date, p_chk_date);

      --
      CURSOR c_chk_stpe (
         p_key_sety_ref_num  service_types.ref_num%TYPE
      ) IS
         SELECT 1
           FROM status_periods
          WHERE susg_ref_num = p_susg_ref_num
            AND sety_ref_num = p_key_sety_ref_num
            AND p_chk_date BETWEEN start_date AND NVL (end_date, p_chk_date);

      --
      l_found                       BOOLEAN;
      l_dummy                       NUMBER;
      l_key_sety_ref_num            service_types.ref_num%TYPE;
      l_key_charge_value            fixed_special_prices.charge_value%TYPE;
   --
   BEGIN
      --
      IF p_sety_ref_num IS NOT NULL AND p_once_off = 'Y' AND p_pro_rata = 'N' AND p_regular_charge = 'N' THEN
         IF p_package IS NOT NULL THEN
            --väljakutse paketi tasemel (sisendis p_package IS NOT NULL),
            OPEN c_fidp_sept;

            FETCH c_fidp_sept
             INTO p_fcit_type_code
                 ,l_key_sety_ref_num
                 ,l_key_charge_value
                 ,p_taty_type_code
                 ,p_billing_selector
                 ,p_fcdt_type_code
                 ,p_tax;

            l_found := c_fidp_sept%FOUND;

            CLOSE c_fidp_sept;

            IF NOT l_found THEN
               -- väljakutse paketikategooria tasemel (sisendis p_category IS NOT NULL
               -- ja p_package IS NULL)
               OPEN c_fidp_cat;

               FETCH c_fidp_cat
                INTO p_fcit_type_code
                    ,l_key_sety_ref_num
                    ,l_key_charge_value
                    ,p_taty_type_code
                    ,p_billing_selector
                    ,p_fcdt_type_code
                    ,p_tax;

               CLOSE c_fidp_cat;
            END IF;
         ELSIF p_category IS NULL AND p_package IS NULL THEN
            --
            OPEN c_fidp_chca;

            FETCH c_fidp_chca
             INTO p_fcit_type_code
                 ,l_key_sety_ref_num
                 ,l_key_charge_value
                 ,p_taty_type_code
                 ,p_billing_selector
                 ,p_fcdt_type_code
                 ,p_tax;

            CLOSE c_fidp_chca;
         END IF;

         IF l_key_sety_ref_num IS NOT NULL THEN
            -- Kontrollime masterkonto tasemelt
            OPEN c_chk_maas (l_key_sety_ref_num);

            FETCH c_chk_maas
             INTO l_dummy;

            l_found := c_chk_maas%FOUND;

            CLOSE c_chk_maas;

            IF NOT l_found THEN
               -- Kontrollime mobiili tasemelt
               OPEN c_chk_stpe (l_key_sety_ref_num);

               FETCH c_chk_stpe
                INTO l_dummy;

               l_found := c_chk_stpe%FOUND;

               CLOSE c_chk_stpe;
            END IF;

            IF l_found THEN
               --
               p_charge_value := l_key_charge_value;
               p_tax := p_charge_value * gen_bill.get_tax_rate (p_taty_type_code, p_chk_date);
            --
            END IF;
         END IF;
      END IF;   -- End IF p_sety_ref_num IS NOT NULL AND
   --
   END get_dependent_price;

   /*
     ** Protseduur leiab paketi erihinna.
   */
   PROCEDURE get_non_prorata_package_charge (
      p_package_type      IN      serv_package_types.type_code%TYPE
     ,p_charge_end_date   IN      DATE
     ,p_charge_value      OUT     NUMBER
     ,p_taty_type_code    OUT     tax_types.tax_type_code%TYPE
     ,p_billing_selector  OUT     billing_selectors_v.type_code%TYPE
     ,p_fcit_type_code    OUT     fixed_charge_item_types.type_code%TYPE
   ) IS
      --
      CURSOR c_ficv IS
         SELECT fcit.type_code fcit_type_code
               ,fcit.billing_selector billing_selector
               ,fcit.taty_type_code taty_type_code
               ,ficv.charge_value charge_value
           FROM fixed_charge_values ficv, fixed_charge_item_types fcit
          WHERE ficv.sept_type_code = p_package_type
            AND ficv.chca_type_code IS NULL
            AND ficv.sety_ref_num IS NULL
            AND ficv.channel_type IS NULL
            AND NVL (ficv.par_value_charge, 'N') = 'N'
            AND p_charge_end_date BETWEEN ficv.start_date AND NVL (ficv.end_date, p_charge_end_date)
            AND ficv.fcit_charge_code = fcit.type_code
            AND fcit.once_off = 'N'
            AND fcit.pro_rata = 'N'
            AND fcit.regular_charge = 'Y'
            AND TRUNC (p_charge_end_date) BETWEEN ficv.start_date AND NVL (ficv.end_date, TRUNC (p_charge_end_date));
   --
   BEGIN
      --
      OPEN c_ficv;

      FETCH c_ficv
       INTO p_fcit_type_code
           ,p_billing_selector
           ,p_taty_type_code
           ,p_charge_value;

      CLOSE c_ficv;
   --
   END get_non_prorata_package_charge;
   
   /*
     ** Teenuse või teenuse min/fix parameetri kuumakse/kuutasu võetakse hinnakirjast.
     ** Komplekti juures on komponendi detailandmetes defineeritud teenusele
     **    - Parameetritele rakendatav kuutasu soodustuse %  MIPS.Monthly_Disc_Rate või  
     **      kuutasu soodustus absoluutväärtusena MIPS.Monthly_Markdown
     ** Soodustus = Round(Hinnakirja hind * Rakendatav soodustuse %) / 100    , 2) 
     ** või soodustuse absoluutväärtus
     ** Teenuse/parameetri väärtuse kuutasu km-ta =  Hinnakirja hind km-ta - Soodustus km-ta
   */
   PROCEDURE Get_EMTPL_Mixed_Sety_Mon (
      p_sept_type_code  IN     serv_package_types.type_code%TYPE
     ,p_sety_ref_num    IN     service_types.ref_num%TYPE
     ,p_sepv_ref_num    IN     service_param_values.ref_num%TYPE
     ,p_check_date      IN     DATE
     ,p_disc_rate       IN     NUMBER
     ,p_disc_amount     IN     NUMBER
     ,p_monthly_charge     OUT NUMBER
   ) IS
      --
      CURSOR c_ebpl IS
         SELECT charge_value
         FROM emt_bill_price_list
         WHERE sept_type_code = p_sept_type_code
           AND sety_ref_num = p_sety_ref_num
           AND (sepv_ref_num IS NULL OR sepv_ref_num = p_sepv_ref_num)
           AND chca_type_code IS NULL
           AND Trunc(p_check_date) BETWEEN start_date AND Nvl(end_date, p_check_date)
         ORDER BY Decode(sepv_ref_num, NULL, 1, 0)
      ;
      --
      l_discount   NUMBER;
   BEGIN
      --
      OPEN  c_ebpl;
      FETCH c_ebpl INTO p_monthly_charge;
      CLOSE c_ebpl;
      --
      IF p_monthly_charge > 0 THEN
         --
         IF p_disc_rate > 0 THEN
            --
            l_discount := Round( (p_monthly_charge * p_disc_rate)/100, 2);
            --
         ELSIF p_disc_amount > 0 THEN
            --
            IF p_disc_amount > p_monthly_charge THEN
               l_discount := p_monthly_charge;
            ELSE
               l_discount := p_disc_amount;
            END IF;
            --
         ELSIF p_disc_amount < 0 THEN
            -- ETEENUP-128: juurdehindluse täiendus
            p_monthly_charge := Nvl(p_monthly_charge, 0) - p_disc_amount;
            --
         END IF;
         --
         p_monthly_charge := p_monthly_charge - Nvl(l_discount, 0);
         --
      ELSIF Nvl(p_monthly_charge, 0) = 0 THEN
         -- ETEENUP-41: teenuse 0,- kuutasule on defineeritud juurdehindlus
         IF p_disc_amount < 0 THEN
            --
            p_monthly_charge := Nvl(p_monthly_charge, 0) - p_disc_amount;
            --
         END IF;
         --
      END IF;
      --
   END Get_EMTPL_Mixed_Sety_Mon;
--
-- DOBAS-813 
   PROCEDURE INSERT_SERVICE_INEN (
             P_MAAC_REF_NUM  IN NUMBER
            ,P_SERVICE_NAME  IN VARCHAR2 
            ,P_AMOUNT        IN NUMBER  
            ,P_PERIOD        IN VARCHAR2              
            ,P_CHECK_REF_NUM IN OUT NUMBER  
            ,P_ERROR_MESSAGE OUT VARCHAR2  ---(100)  
            ) IS
   /* Sisendid:
        MAAC_REF_NUM IN NUMBER ? koondarve number
        SERVICE_NAME IN VARCHAR2(5) ? teenuse nimi
        AMOUNT IN NUMBER ? arverea summa ilma KM-ta, formaat 2-kohta peale koma
        PERIOD IN VARCHAR2(4) ? periood, millisesse perioodi soovitakse arverida lisada (YYYYMM)
        CHECK_REF_NUM IN OUT NUMBER ? kontrollimiseks, et kui salvestus õnnestus, siis tagastatakse sama väärtus
        ERROR_MESSAGE OUT VARCHAR2(100) -- vea tekkimisel tagastatav vea kirjeldus
    */
   
    CURSOR c_get_salp (p_year    IN NUMBER
                      ,p_per  IN NUMBER
                        ) IS
    SELECT *
      FROM SALES_LEDGER_PERIODS salp
     WHERE salp.financial_year = p_year 
       AND salp.period_num = p_per;
       
     CURSOR c_maac_status (p_maac  IN NUMBER) IS
     SELECT acst.*
       FROM ACCOUNT_STATUSES acst
      WHERE acst.acco_ref_num = p_maac AND acst.acst_code in ('AC')
     ORDER BY acst.start_date DESC;  
     
     CURSOR c_maac (p_maac  IN NUMBER) IS
     SELECT acco.*
       FROM ACCOUNTS acco
      WHERE ref_num = p_maac; 
     
     CURSOR c_get_fcit_rec(p_sety_ref_num NUMBER) IS
     SELECT * 
       FROM FIXED_CHARGE_ITEM_TYPES
      WHERE sety_ref_num = p_sety_ref_num;
   
  -- E_MAAC_REF_ERROR EXCEPTION;
   SOME_ERRORS  EXCEPTION;
   
   l_sety_rec     SERVICE_TYPES%ROWTYPE := NULL;
   l_salp_rec     SALES_LEDGER_PERIODS%ROWTYPE := NULL;
   l_inen_rec     INVOICE_ENTRIES%ROWTYPE := NULL;
   l_fcit_rec     FIXED_CHARGE_ITEM_TYPES%ROWTYPE := NULL;
   l_acco_rec     ACCOUNTS%ROWTYPE := NULL;
   
   l_err_message  VARCHAR2(100) := NULL;
   l_maac         ACCOUNTS.REF_NUM%TYPE := NULL;
   l_amt          INVOICE_ENTRIES.EEK_AMT%TYPE := NULL;
   l_period       NUMBER(6):= NULL;
   l_year         SALES_LEDGER_PERIODS.FINANCIAL_YEAR%TYPE := NULL;
   l_month        SALES_LEDGER_PERIODS.PERIOD_NUM%TYPE := NULL;
   l_invo_ref_num INVOICES.REF_NUM%TYPE := NULL;
   l_exist_AC     BOOLEAN := FALSE;
   
   
   BEGIN 

     --Sisendandmete kontroll 
     IF P_MAAC_REF_NUM is null THEN 
        l_err_message := 'Koondarve on määramata';
        RAISE SOME_ERRORS;
     ELSE 
       -- kas p_maac_ref_num on numbriline väli
       begin
        l_maac := to_number(p_maac_ref_num);
       exception
       when others then 
            l_err_message := 'Koondarve peab olema number';
            RAISE SOME_ERRORS; 
       end;   
       --Kas koondarve number on olemas
       OPEN c_maac(p_maac_ref_num);
       FETCH c_maac INTO l_acco_rec;
       CLOSE c_maac;
       
       IF l_acco_rec.REF_NUM is null THEN 
          l_err_message := 'Koondarvet ei leitud';
          RAISE SOME_ERRORS;
       END IF;

     END IF;
     
     IF P_SERVICE_NAME is null THEN 
        l_err_message := 'Teenuse nimi on määramata';
        RAISE SOME_ERRORS;
     ELSE 
        IF NOT Or_Common.Get_Sety_Rec_By_Service_Name (P_SERVICE_NAME,l_sety_rec ) THEN 
          l_err_message := 'Teenust '||P_SERVICE_NAME||' ei leitud';
          RAISE SOME_ERRORS;           
        END IF;       
     END IF;   
     
     IF P_AMOUNT is null THEN 
        l_err_message := 'Summa on määramata';
        RAISE SOME_ERRORS;
     ELSE 
       -- kas p_amount on numbriline väli
       begin
        l_amt := to_number(p_amount);
       exception
       when others then 
            l_err_message := 'Summa peab olema number';
            RAISE SOME_ERRORS; 
       end;      
     
     END IF;        

     IF P_PERIOD is null THEN 
        l_err_message := 'Periood on määramata';
        RAISE SOME_ERRORS;
     ELSE 
       -- kas p_period on numbriline väli
       begin
        l_period := to_number(p_period);
       exception
       when others then 
            l_err_message := 'Periood peab olema number (formaat YYYYMM)';
            RAISE SOME_ERRORS; 
       end;
       
       -- p_period peab olema avatud periood
       -- kas jooksev kuu või eelmine kuu(kuu alguses võib olla lahti 2 avatud perioodi) 
       l_year   := substr(p_period,1,4);
       l_month  := substr(p_period,5,2);
       
       --P_PERIOD 5.ja 6.positsioonil peab olema kuu number
       IF l_month not in ('01','02','03','04','05','06','07','08','09','10','11','12') 
         OR length(ltrim(rtrim(p_period))) <6 THEN
          l_err_message := 'Arveldusperiood '||p_period||' ei vasta formaadile';
          RAISE SOME_ERRORS;
       END IF;

       OPEN c_get_salp (l_year, l_month);
       FETCH c_get_salp INTO l_salp_rec;
       CLOSE c_get_salp;
      
       IF l_salp_rec.DATE_CLOSED IS NOT NULL THEN
          --arvet ei saa tekitada suletud perioodi
          l_err_message := 'Arveldusperiood '||p_period||' on suletud';
          RAISE SOME_ERRORS;

       ELSIF l_salp_rec.start_date IS NULL THEN
          --arveldusperiood puudub tabelis sales_ledger_periods
          l_err_message := 'Arveldusperiood '||p_period||' puudub tabelis SALES_LEDGER_PERIODS';
          RAISE SOME_ERRORS;        
       
       ELSIF  to_date('01'||substr(p_period,5,2)||substr(p_period,1,4),'dd.mm.yyyy') > sysdate  THEN   
          --periood on tulevikus, ei saa tekitda arvet
          l_err_message := 'Tuleviku arveldusperiood '||p_period;
          RAISE SOME_ERRORS;     
       END IF;        
      
               
     END IF;  
     
     -- Kui masteri staatus on INI ,siis ei lähe üldse järgmisse tsüklisse
     l_exist_AC := FALSE;
     FOR stat IN c_maac_status (p_maac_ref_num) LOOP
       l_exist_AC := TRUE; 
       IF stat.end_date IS NOT NULL AND stat.end_date < l_salp_rec.start_date THEN
          -- Masterkonto staatus ei ole AC, billing arvet avada ei saa
          l_err_message := 'Masterkonto '|| p_maac_ref_num || ' suletud, arvet avada ei saa!';
          RAISE SOME_ERRORS;
       END IF;
       EXIT;
     END LOOP;
     --Ei leidnud AC staatust, arvatavasti on INI
     IF not l_exist_AC THEN 
        -- Masterkonto staatus ei ole AC, billing arvet avada ei saa
       l_err_message := 'Masterkontol'|| p_maac_ref_num || ' suletud või staatusega INI, arvet avada ei saa!';
       RAISE SOME_ERRORS;     
     END IF;

     -- Now get the Invoice Number (Or Create one)
     l_invo_ref_num := open_invoice.find_or_open_invoice (p_maac_ref_num, l_salp_rec.end_date, 'INB', TRUE);

     IF  l_invo_ref_num IS NULL  THEN
         l_err_message := 'Masterkontole ' || p_maac_ref_num || ', arve avamine ebaõnnestus';
         RAISE  SOME_ERRORS;
     END IF;              
 
    -- Arve olemas, nüüd arverida  
    OPEN c_get_fcit_rec(l_sety_rec.ref_num);
    FETCH c_get_fcit_rec INTO l_fcit_rec;
    CLOSE c_get_fcit_rec;

     IF  l_fcit_rec.type_code IS NULL  THEN
         rollback;  -- teen rollback-i. Kui tegi arve päise, siis siin võtab tagasi
         l_err_message := 'Ei leitud teenuse ' || P_SERVICE_NAME || ' arverea häälestust tabelis FIXED_CHARGE_ITEM_TYPES';
         RAISE  SOME_ERRORS;
     END IF;      

     -- Kogu info on koos, tee arverida
     l_inen_rec.invo_ref_num       := l_invo_ref_num;
     l_inen_rec.acc_amount         := P_AMOUNT;
     l_inen_rec.eek_amt            := P_AMOUNT;
     l_inen_rec.amt_tax            := NULL;
     l_inen_rec.rounding_indicator := 'N';
     l_inen_rec.under_dispute      := 'N';
     l_inen_rec.date_created       := SYSDATE;
     l_inen_rec.amt_in_curr        := NULL;
     l_inen_rec.billing_selector   := l_fcit_rec.billing_selector;
     l_inen_rec.fcit_type_code     := l_fcit_rec.type_code;
     l_inen_rec.taty_type_code     := l_fcit_rec.taty_type_code;
     l_inen_rec.susg_ref_num       := NULL;
     l_inen_rec.curr_code          := get_pri_curr_code;
     l_inen_rec.manual_entry       := 'N';
     l_inen_rec.evre_count         := NULL;
     l_inen_rec.evre_duration      := NULL;
     l_inen_rec.module_ref         := 'U659';  
     l_inen_rec.maas_ref_num       := NULL;
     l_inen_rec.pri_curr_code      := get_pri_curr_code; 

     gen_bill.insert_inen (l_inen_rec);

     IF  l_inen_rec.ref_num IS NULL  THEN
         rollback;  -- teen rollback-i. Kui tegi arve päise, siis siin võtab tagasi
         l_err_message := 'Arverea sisestamine ebaõnnestus';
         RAISE  SOME_ERRORS;
     ELSE 
     null;
        --COMMIT;    
     END IF;     
   
   EXCEPTION 
     WHEN SOME_ERRORS THEN 
          P_ERROR_MESSAGE := l_err_message;
          P_CHECK_REF_NUM := NULL;
                                    
     WHEN OTHERS THEN
          -- arvatavasti mingi ORA viga
          rollback;
          P_ERROR_MESSAGE := substr( SQLERRM,1,100);
          P_CHECK_REF_NUM := NULL;       
     
   END INSERT_SERVICE_INEN;
--
END icalculate_fixed_charges;
/