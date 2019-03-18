CREATE OR REPLACE PACKAGE TBCIS.CALCULATE_DISCOUNTS IS
   /*
   **  Module Name : CALCULATE_DISCOUNTS   BCCU847
   **  Date Created:  16.11.2001
   **  Author      :  Helve Luhasalu
   **  Description :  This Package contain all the procedures to calculate
   **                 different types of Discounts
   **
   ** Change History.
   ** ----------------------------------------------------------------------
   ** Version Date         Modified by  Reason
   **
   **  1.0    20.05.2002   H.Luhasalu   UPR-1991    New
   **  1.1    16.08.2002   H.Luhasalu   UPR-2240    OO_CONN soodustustele lisatud käibemaks ja evre_count;
   **  1.2    27.08.2002   H.Luhasalu   UPR-2253    Find_Breaks.vmct_maac_type definitsioon tabelile(pikemaks)-viga!
   **  1.3    18.10.2002   H.Luhasalu   UPR-2328    Täiendatud soodustusi väljaga: parties.month_of_serv
   **  1.4    04.11.2002   U.Aarna      UPR-2335    Lisatud protseduur diileri poolt lisatud manual soodustuste
   **                                               valideerimiseks (Val_NewMob_Manual_Discount)
   **  1.5    19.12.2002   U.Aarna      UPR-2405    Diileri poolt lisatud manual soodustuste valideerimise protseduur
   **                                               kohendatud ka olemasolevate mobiilide (mitte ainult uute) soodustuste
   **                                               valideerimiseks ja ümber nimetatud Validate_Manual_Discount.
   **  1.6    10.01.2003   H.Luhasalu   UPR-2380    Lisatud soodustuse katkemine paketikategooria ja paketivahetuse korral
   **                                               (x päeva möödudes). Täiendatud automaatset soodustuse ülestõstmist järgmiselt:
   **                                               seotud soodustuse korral parent soodustuse korral sudi_ref_num'ga täitmine
   **  1.7    31.01.2003   H.Luhasalu   UPR-2454    Katkemine maksete hilinemise tõttu täiendatud järgmiselt:
   **                                               -arveid vaadatakse alates soodustuse registreerimise hetkest
   **                                               -arvestatakse accounts.check_debt+kuupäev
   **                                               -lisatud katkemistesse katkemine part_type järgi
   **  1.8    03.03.2003   H.Luhasalu   UPR-2491    -find_dica_fcit - lisatud nvl( väljale end_date...
   **  1.9    23.04.2004   H.Luhasalu   UPR-2990    -Lisatud automaatse soodustuse kontrolli Party vanus B-numbrile
   **  2.0    08.06.2004   H.Luhasalu   UPR-3028    -Carry_discount_to_Entry kursor kiiremaks
   **  2.1    09.08.2004   H.Luhasalu   UPR-3094    -Algväärtustatud BOOLEAN Setup_new_mobile
   **  2.2    24.09.2004   U.Aarna      UPR-3124    Seoses ühise kuutasuga muudetud Carry_Discount_To_Entry: kui originaalrida
   **                                               arvel pole, siis ei tohi ka soodustust sinna kanda.
   **  2.3    15.11.2004   H.Luhasalu   UPR-3122    Täiendatud New_and_several_mobile
   **  2.4    10.01.2005   H.Luhasalu   UPR-3250    Uus mobiil paketi kategooriasse
   **  2.5    05.05.2005   H.Luhasalu   CHG-103     Lisatud protseduur Chk_Apply_Package ja võetud kasutusele. Breaks välja.
   **  2.6    02.06.2005   H.Luhasalu   CHG-107     Lisatud uus võimalus soodustuse arvutamiseks. Kõne pärast teatud aega odavam(PRICING='Y')
   **  2.7    10.06.2005   U.Aarna      CHG-498     Lisatud CONN/OO/REGU soodustuste leidmise loogika Master taseme teenuste jaoks.
   **  2.8    14.02.2006   U.Aarna      CHG-685     Protseduur Setup_Disc_New_Conn ümber kirjutatud nii, et exclude dico korral korrektne
   **                                               soodustus välja arvataks.
   **  2.9    02.03.2006   H.Luhasalu   CHG-724     Definitsioonid; arve rea rahaühik sama, mis arve päises.
   **  3.0    28.03.2006   H.Luhasalu   CHG-789     MN8 lugeda alati kompaniiks
   **  3.1    27.03.2006   M.Teino      CHG-776     Eemaldatud valuutaväljade (..._CURR) ja valuutakoodi (CURR_CODE) täitmine
   **                                               tabelites INVOICE_ENTRIES ja INVOICE_ENTRIES_INTERIM, lisatud pri_curr_code väärtustamine ja lisamine tabelitesse
   **                                               protseduuris find_oo_conn_discounts - l_inen.amt_tax ümardamine kahe komakohani
   **  3.2    04.07.2006   U.Aarna      CHG-1044    Muudetud protseduuri setup_disc_package. Paketi tasemel määratud soodustus antakse ka siis, kui paketikategooria
   **                                               ei muutu. Paketikategooria tasemel määratud soodustuse korral jääb kehtima vana reegel - ei anta soodustust,
   **                                               kui paketivahetuse käigus paketkategooria ei muutu.
   **  3.3    21.08.2006   H.Luhasalu   CHG-1132    Parandatud kuumaksu soodustuse kursorit lisatingimustega.
   **  3.4    08.09.2006   U.Aarna      CHG-1167    Muudetud protseduuri setup_disc_sety. Lisatud soodustuse lubamise kontroll ka teenusparameetri tasemel.
   **  3.5    25.06.2007   S.Sokk       CHG2110     Replaced USER with sec.get_username
   **  3.6    13.03.2009   H.Luhasalu   CHG-1634   find_mon_discounts - muudatus
   **  3.7    04.11.2009   A.Soo        CHG-4079    Parandatud soodustuste summa loogikat seoses vahearvetega (MinuEMT lahendustasu komponendid)
   **                                               Muudetud protseduuri: find_oo_conn_discounts
   **                                               Uus protseduur: get_discountable_amont
   **  3.8    17.11.2009   A.Soo        CHG-3360    Soodustustele lisatud Interim toetus seoses SaldoStop-iga.
   **                                               Muudetud protseduuri: find_oo_conn_discounts
   **  3.9    28.05.2010   A.Soo        CHG-4461    Automaatsete soodustuste rakendumise parandus. Soodustus ei tohi rakenduda, kui uus ja vana parameeter võrduvad.
   **                                               Muudetud protseduuri: setup_disc_sety
   **  3.10   12.08.2010   K.Peil       CHG4594, IS-5537: INEN.EEK_AMT töötlemise asemel INEN.ACC_AMOUNT täpsusega
   **                                               GET_INEN_ACC_PRECISION alamprogrammides:
   **                                               - UNDO_EVRE_MIN_DISCOUNT
   **                                               - FIND_OO_CONN_DISCOUNTS
   **                                               - INSERT_INEN, lisatud EEK_AMT väärtustamine väljundis
   **                                               - INSERT_INEN_INT, täiendatud selliselt, et väärtus loetakse sisendi
   **                                                 ACC_AMOUNT väljalt
   **                                               - CARRY_DISCOUNT_TO_ENTRY
   **                                               - INVOICE_DISCOUNT
   **  3.11   31.03.2011   A.Soo        CHG-4899    Käibemaksu ei arvutata koheselt arverea/arvereale lisamisel, vaid arve sulgemisel.
   **                                               Muudetud protseduure:
   **                                                 -- find_oo_conn_discounts
   **                                                 -- invoice_discount
   **  3.12   21.12.2011   A.Soo        CHG-5438    Paketeeritud müük Vol 2
   **                                               Muudetud protseduuri:
   **                                                 -- find_oo_conn_discounts
   **  3.13   25.03.2015   A.Soo        SFILES-229  SuhtlusPilv
   **                                               Muudetud protseduuri:
   **                                                 -- setup_disc_master_sety
   **  3.14   07.12.2016   A.Soo        ARVO-759    Soodustuste lubamise kontrolli parandus
   **                                               Muudetud protseduuri:
   **                                                 -- new_and_several_mob
   **  3.15   14.12.2016   A.Soo        MOBET-22    Soodustuse arvutamisel tagastatakse soodustuse olemasolu ja summa
   **                                               Uus protseduur (väljundparameetritega)
   **                                                 -- find_oo_conn_discounts
   **                                               Muudetud protseduuri:
   **                                                 -- find_oo_conn_discounts
   **  3.16   21.12.2016   A.Soo        MOBET-7     Jagatava interneti grupi kuutasu soodustus
   **                                               Muudetud protseduuri:
   **                                                 -- setup_disc_master_sety
   **                                               Uus funktsioon:
   **                                                 -- calculate_sudi_end_date
   **         03.01.2017  Inge Reeder   MOBET-7     Muudetud protseduurid: 
   **                                                 -- setup_disc_master_sety(kursor c_cadc, muutja l_masa_rec.end_date)
   **         16.01.2017                              -- calculate_sudi_end_date 
   **  3.17   13.01.2017  Inge Reeder   MOBET-23    Muudetud protseduurid: 
   **                                                  --invoice_discount,carry_discount_to_entry, insert_inen
   **                                               Kui arvereal on täidetud additional_entry_text, siis sama sisu tuuakse soodustuse reale ka.
   **  3.18   16.01.2017  Inge Reeder   MOBET-49    Muudetud protseduur: 
   **                                                 -- find_oo_conn_discounts
   **  3.19   20.02.2017  Inge Reeder   MOBET-74    Muudetud protseduur: 
   **                                                 -- INSERT_SUDI
   **  3.20   22.02.2017  Inge Reeder   MOBET-75    Muudetud protseduurid: 
   **                                                 -- find_oo_conn_discounts
   **                                                 -- calculate_one_amount
   **                                                 -- find_mon_discounts 
   **  3.21   15.05.2017  Inge Reeder   EUREG-102   Uus soodustuse sulgemise konstant: g_rc_service_closed    
   **  3.22   09.06.2017  Inge Reeder   MOBET-163   Muudetud protseduurid: 
   **                                                 -- find_oo_conn_discounts (kursor c_fcit_disc)
   **  3.23   08.11.2017  Inge Reeder   DOBAS-262   Kliendipõhiste ühekordsete teenuste soodustused.
   **                                               Muudetud protseduurid: 
   **                                                 -- find_ma_service_discounts 
   **                                                 -- invoice_discount  
   **  3.24   08.12.2017  Inge Reeder   DOBAS-467   SUDI uued väljad usre_ref_num, caof_ref_num.
   **                                               Muudetud protseduur: 
   **                                                 -- insert_sudi
   **  3.25   16.01.2018  Inge Reeder   DOBAS-561   MON tüüpi kuutasudel ei osata arvestada soodustuse lõppkuupäevaga
   **                                               Muudetud protseduur: 
   **                                                 -- find_mon_discounts
   **  3.26   23.10.2018  Inge Reeder   DOBAS-1315  OS automaatsoodustused peavad väärtustama mobiili soodustuse lõppkuupäeva
   **                                               Muudetud protseduurid: 
   **                                                 --  setup_disc_package ,setup_disc_sety, setup_disc_new_conn, find_oo_conn_discounts
   **  3.27   12.11.2018  Inge Reeder   DOBAS-1217  OS - pakkumisega kaasneva soodustuse valideerimise muutmine
   **                                               Muudetud protseduurid: 
   **                                                 --  validate_manual_discount
   **
   **  3.28   09.01.2018  Andres Jaek   DOBAS-1622  Muudetud funktsioon: find_discount_type. 
   **                                                  Lisatud parameeter p_daily_charge ja muudetud funktsiooni nii, et DCH fixed charge type lisamine ei põhjusta viga.
   **----------------------------------------------------------------------------
   */
   g_module_ref         CONSTANT VARCHAR2 (4) := 'U847';
   c_discount_type_min  CONSTANT call_discount_codes.call_type%TYPE := 'MIN';
   c_cancel_reason_fix  CONSTANT subs_discounts.reason_code%TYPE := 'FIX';   -- Mistake fix.-vorm
   c_discount_type_call CONSTANT call_discount_codes.call_type%TYPE := 'CALL';
   c_discount_type_mon  CONSTANT call_discount_codes.call_type%TYPE := 'MON';
   c_discount_type_regular CONSTANT call_discount_codes.call_type%TYPE := 'REGU';   -- CHG-498
   --Soodustuse sulgemise põhjused:
   g_cancel_reason_cln  CONSTANT subs_discounts.reason_code%TYPE := 'CLN';   -- Close Mobile.--OK
   g_cancel_reason_stat CONSTANT subs_discounts.reason_code%TYPE := 'STAT';   -- Special Cancel Status.--OK
   g_cancel_reason_omcl CONSTANT subs_discounts.reason_code%TYPE := 'OMCL';   -- Other Mobile Closed.--OK
   c_cancel_reason_statem CONSTANT subs_discounts.reason_code%TYPE := 'SDSC';   -- Statement Discount --Ok
   c_cancel_reason_vmct CONSTANT subs_discounts.reason_code%TYPE := 'VMCT';   -- OK
   g_rc_service_closed  CONSTANT subs_discounts.reason_code%TYPE := 'SCL';   -- EUREG-102
   g_rc_chg_serv_num    CONSTANT subs_discounts.reason_code%TYPE := 'CMN';   --OK
   g_rc_debt            CONSTANT subs_discounts.reason_code%TYPE := 'DEBT';   --OK
   g_rc_paym            CONSTANT subs_discounts.reason_code%TYPE := 'PAYM';   --OK
   g_rc_mob_part        CONSTANT subs_discounts.reason_code%TYPE := 'REL';
   g_rc_chg_pack        CONSTANT subs_discounts.reason_code%TYPE := 'PACK';
   g_rc_chg_cat         CONSTANT subs_discounts.reason_code%TYPE := 'CAT';
   g_rc_amt             CONSTANT subs_discounts.reason_code%TYPE := 'AMT';
   g_rc_paty            CONSTANT subs_discounts.reason_code%TYPE := 'PATY';

   TYPE dicotabtype IS TABLE OF discount_codes%ROWTYPE
      INDEX BY BINARY_INTEGER;

   PROCEDURE get_discountable_amount (
      p_period_end             IN      DATE
     ,p_dico_start_date        IN      DATE
     ,p_disc_billing_selector  IN      VARCHAR2
     ,p_cadc_ref_num           IN      NUMBER
     ,p_maac_ref_num           IN      NUMBER
     ,p_susg_ref_num           IN      NUMBER
     ,p_billing_selector       IN      VARCHAR2
     ,p_fcit_type_code         IN      VARCHAR2
     ,p_inen_amount            IN      NUMBER
     ,p_max_amount             IN      NUMBER
     ,p_discountable_amount    OUT     NUMBER
   );

   --
   PROCEDURE insert_inen (
      p_inen        IN OUT NOCOPY  invoice_entries%ROWTYPE
     ,p_success     OUT            BOOLEAN
     ,p_error_text  OUT            VARCHAR2
   );

   --
   PROCEDURE insert_inen_int (
      p_inen        IN OUT NOCOPY  invoice_entries%ROWTYPE
     ,p_success     OUT            BOOLEAN
     ,p_error_text  OUT            VARCHAR2
   );

   --sisestus ainult soodustuse jaoks. Teised väljad elimineeritud.VT default väärtustamine.
   --
   PROCEDURE insert_sudi (
      p_sudi        IN OUT NOCOPY  subs_discounts%ROWTYPE
     ,p_success     OUT            BOOLEAN
     ,p_error_text  OUT            VARCHAR2
   );

   --
   PROCEDURE insert_dica (
      p_dica        IN OUT NOCOPY  disc_call_amounts%ROWTYPE
     ,p_success     OUT            BOOLEAN
     ,p_error_text  OUT            VARCHAR2
   );

   --
   FUNCTION insert_dial (
      p_dial        IN      discount_allowed_list%ROWTYPE
     ,p_success     OUT     BOOLEAN
     ,p_error_text  OUT     VARCHAR2
   )
      RETURN NUMBER;

   --
   PROCEDURE insert_evmd (
      p_evmd        IN OUT NOCOPY  evre_min_discounts%ROWTYPE
     ,p_success     OUT            BOOLEAN
     ,p_error_text  OUT            VARCHAR2
   );

   --
   PROCEDURE undo_min_discounts (
      p_susg_ref_num       NUMBER
     ,p_sudi_ref_num       NUMBER
     ,p_success       OUT  BOOLEAN
     ,p_error_text    OUT  VARCHAR2
   );

   --võtab minutisoodustuse tagasi kuni väljasaadetud arveni
   --
   --
   PROCEDURE undo_evre_discounts (
      p_evre             event_records_curr%ROWTYPE
     ,p_success     OUT  BOOLEAN
     ,p_error_text  OUT  VARCHAR2
   );   --võtab minutisoodustuse tagasi, mis arvutati sellele evendile

   --
   PROCEDURE find_amount_dica_fcit (
      p_susg_ref_num              NUMBER
     ,p_cadc_ref_num              NUMBER
     ,p_sudi_ref_num              NUMBER
     ,p_fcit_type_code            VARCHAR2
     ,p_billing_selector          VARCHAR2
     ,p_bill_period               NUMBER
     ,p_in_month          IN OUT  NUMBER
     ,p_prev_period       IN OUT  NUMBER
     ,p_in_duration       IN OUT  NUMBER
     ,p_prev_duration     IN OUT  NUMBER
     ,p_bill_sel_sum              VARCHAR2
   );

   --arvutab, palju on soodustust saadud jooksval kuul ja väljaspool jooksvat kuud
   --arvutab fcit'le või billing_selectorile kokku, kui soodustus on defineeritud nii.
   --
   PROCEDURE find_amount_dica (
      p_susg_ref_num              NUMBER
     ,p_sudi_ref_num              NUMBER
     ,p_bill_period               NUMBER
     ,p_in_month          IN OUT  NUMBER
     ,p_prev_period       IN OUT  NUMBER
     ,p_in_duration       IN OUT  NUMBER
     ,p_prev_duration     IN OUT  NUMBER
     ,p_in_count          IN OUT  NUMBER
     ,p_prev_count        IN OUT  NUMBER
     ,p_in_count_count    IN OUT  NUMBER   -- mitu 'in' kõnet selle count'ga soodust. saanud
     ,p_prev_count_count  IN OUT  NUMBER   -- mitu 'prev' kõnet selle count'ga soodust. saanud
   );

   --arvutab, palju on soodustust saadud jooksval kuul ja väljaspool jooksvat kuud
   --arvutab fcit'le või billing_selectorile .
   PROCEDURE find_amount_sudi (
      p_susg_ref_num          NUMBER
     ,p_sudi_ref_num          NUMBER
     ,p_amount        IN OUT  NUMBER
   );

   --
   PROCEDURE find_mon_discounts (
      p_discount_type             VARCHAR2
     ,p_invo                      invoices%ROWTYPE
     ,p_fcit_type_code            VARCHAR2
     ,p_billing_selector          VARCHAR2
     ,p_sety_ref_num              NUMBER
     ,p_sepa_ref_num              NUMBER
     ,p_sepv_ref_num              NUMBER
     ,p_sept_type_code            VARCHAR2
     ,p_charge_value              NUMBER
     ,p_num_of_days               NUMBER
     ,p_susg_ref_num              NUMBER
     ,p_maac_ref_num              NUMBER
     ,p_start_date                DATE
     ,p_end_date                  DATE
     ,p_day_num                   NUMBER   -- mitu päeva on kuus
     ,p_error_text        IN OUT  VARCHAR2
     ,p_success           IN OUT  BOOLEAN
   );

   --arvutab kuumaksu soodustuse kuumaksude arvutamise juures. Salvestab saadava summa dica'sse.
   --Arvele ei kirjuta.
   PROCEDURE find_oo_conn_discounts (
      p_discount_type               VARCHAR2
     ,p_invo_ref_num                NUMBER
     ,p_fcit_type_code              VARCHAR2
     ,p_billing_selector            VARCHAR2
     ,p_sepv_ref_num                NUMBER
     ,p_sept_type_code              VARCHAR2
     ,p_charge_value                NUMBER
     ,p_susg_ref_num                NUMBER
     ,p_maac_ref_num                NUMBER
     ,p_date                        DATE
     ,p_mode                        VARCHAR2   --'INS';'DEL'
     ,p_error_text          IN OUT  VARCHAR2
     ,p_success             IN OUT  BOOLEAN
     ,p_max_calculated_amt  IN      NUMBER DEFAULT NULL
     ,p_interim             IN      BOOLEAN DEFAULT FALSE   -- CHG-3360
     ,p_mixed_service       IN      VARCHAR2 DEFAULT NULL   -- CHG-5438
   );
   
   --arvutab kuumaksu soodustuse kuumaksude arvutamise juures. Salvestab saadava summa dica'sse.
   --Arvele ei kirjuta.
   -- MOBET-22: Tagastab, kas soodustust eksisteerib ning ka soodustuse summa
   PROCEDURE find_oo_conn_discounts (
      p_discount_type               VARCHAR2
     ,p_invo_ref_num                NUMBER
     ,p_fcit_type_code              VARCHAR2
     ,p_billing_selector            VARCHAR2
     ,p_sepv_ref_num                NUMBER
     ,p_sept_type_code              VARCHAR2
     ,p_charge_value                NUMBER
     ,p_susg_ref_num                NUMBER
     ,p_maac_ref_num                NUMBER
     ,p_date                        DATE
     ,p_mode                        VARCHAR2   --'INS';'DEL'
     ,p_error_text          IN OUT  VARCHAR2
     ,p_success             IN OUT  BOOLEAN
     ,p_discount_exists        OUT  BOOLEAN
     ,p_disc_amount            OUT  NUMBER
     ,p_max_calculated_amt  IN      NUMBER DEFAULT NULL
     ,p_interim             IN      BOOLEAN DEFAULT FALSE   -- CHG-3360
     ,p_mixed_service       IN      VARCHAR2 DEFAULT NULL   -- CHG-5438
   );

   --Leia, kas 00,CONN,REGU soodustust on ja arvuta, kanna arvele, registreeri sudisse.
   --
   FUNCTION find_discount_type (
      p_pro_rata        IN  VARCHAR2
     ,p_regular_charge  IN  VARCHAR2
     ,p_once_off        IN  VARCHAR2
     ,p_daily_charge    IN  VARCHAR2 DEFAULT NULL -- DOBAS-1622
   )
      RETURN VARCHAR2;

   --leiab fikseeritud makse järgi soodustuse tüübi.
   --
   FUNCTION get_part_maac_data (
      p_maac_ref_num        IN      accounts.ref_num%TYPE
     ,p_chca_type_code      OUT     accounts.chca_type_code%TYPE
     ,p_bicy_cycle_code     OUT     accounts.bicy_cycle_code%TYPE
     ,p_month_of_serv       OUT     accounts.month_of_serv%TYPE
     ,p_party_type          OUT     parties.party_type%TYPE
     ,p_stat_ref_num        OUT     accounts.stat_ref_num%TYPE
     ,p_part_month_of_serv  OUT     parties.month_of_serv%TYPE
   )
      RETURN BOOLEAN;

   --
   FUNCTION get_vmct_maac_type (
      p_stat_ref_num    IN      statements.ref_num%TYPE
     ,p_vmct_maac_type  OUT     statements.vmct_maac_type%TYPE
   )
      RETURN BOOLEAN;

   --
   FUNCTION chk_discount_allowed_lists (
      p_dico_ref_num     IN  discount_codes.ref_num%TYPE
     ,p_maac_ref_num     IN  accounts.ref_num%TYPE
     ,p_chca_type_code   IN  accounts.chca_type_code%TYPE
     ,p_bicy_cycle_code  IN  accounts.bicy_cycle_code%TYPE
     ,p_vmct_maac_type   IN  statements.vmct_maac_type%TYPE
     ,p_dealer_party     IN  discount_allowed_list.dealer_party%TYPE
     ,p_region           IN  discount_allowed_list.region%TYPE
     ,p_dealer_office    IN  discount_allowed_list.dealer_office%TYPE
     ,p_channel_type     IN  discount_allowed_list.channel_type%TYPE
     ,p_chk_date         IN  DATE
   )
      RETURN BOOLEAN;

   --
   FUNCTION chk_several_maac (
      p_dico_rec      IN      discount_codes%ROWTYPE
     ,p_maac_ref_num  IN      accounts.ref_num%TYPE
     ,p_count         OUT     NUMBER
   )
      RETURN BOOLEAN;

   --
   FUNCTION get_discount_code_rec (
      p_dico_ref_num        IN      discount_codes.ref_num%TYPE
     ,p_date_start          IN      DATE
     ,p_month_of_serv       IN      accounts.month_of_serv%TYPE
     ,p_party_type          IN      parties.party_type%TYPE
     ,p_part_month_of_serv  IN      parties.month_of_serv%TYPE
     ,p_dico_rec            OUT     discount_codes%ROWTYPE
   )
      RETURN BOOLEAN;

   --
   FUNCTION chk_apply_discount (
      p_dico_rec         IN  discount_codes%ROWTYPE
     ,p_susg_ref_num     IN  subs_serv_groups.ref_num%TYPE
     ,p_maac_ref_num     IN  accounts.ref_num%TYPE
     ,p_dealer_party     IN  discount_allowed_list.dealer_party%TYPE
     ,p_region           IN  discount_allowed_list.region%TYPE
     ,p_dealer_office    IN  discount_allowed_list.dealer_office%TYPE
     ,p_channel_type     IN  discount_allowed_list.channel_type%TYPE
     ,p_chca_type_code   IN  accounts.chca_type_code%TYPE
     ,p_bicy_cycle_code  IN  accounts.bicy_cycle_code%TYPE
     ,p_date_start       IN  DATE
     ,p_is_new_mobile    IN  BOOLEAN
     ,p_vmct_maac_type   IN  statements.vmct_maac_type%TYPE
     ,p_sept_type_code   IN  serv_package_types.type_code%TYPE DEFAULT NULL
   )
      RETURN BOOLEAN;

   --
   PROCEDURE setup_b_discount (
      p_date_start      IN      DATE
     ,   --execution_date
      p_susg_a_ref_num  IN      NUMBER
     ,p_susg_b_ref_num  IN      NUMBER
     ,p_error_text      IN OUT  VARCHAR2
     ,p_success         IN OUT  BOOLEAN
   );

   --
   PROCEDURE setup_disc_sety (
      p_date_start     IN      DATE   --execution_date
     ,p_maac_ref_num   IN      NUMBER
     ,p_susg_ref_num   IN      NUMBER
     ,p_sety_ref_num   IN      NUMBER
     ,p_dealer_party   IN      NUMBER
     ,p_region         IN      NUMBER
     ,p_dealer_office  IN      NUMBER
     ,p_channel_type   IN      VARCHAR2
     ,p_is_new_mobile  IN      BOOLEAN
     ,p_error_text     IN OUT  VARCHAR2
     ,p_success        IN OUT  BOOLEAN
     ,p_sede_ref_num   IN      service_details.ref_num%TYPE   -- CHG-1167
   );

   --
   PROCEDURE setup_disc_master_sety (
      p_date_start       IN  DATE   -- order date
     ,p_maac_ref_num     IN  NUMBER
     ,p_maas_ref_num     IN  master_account_services.ref_num%TYPE
     ,p_maas_start_date  IN  DATE
     ,p_sety_ref_num     IN  NUMBER
     ,p_dealer_party     IN  NUMBER
     ,p_region           IN  NUMBER
     ,p_dealer_office    IN  NUMBER
     ,p_channel_type     IN  VARCHAR2
     ,p_sude_rec         IN  subscriber_details%ROWTYPE  -- SFILES-229
   );

   --
   PROCEDURE setup_disc_package (
      p_date_start        IN      DATE   --execution_date
     ,p_maac_ref_num      IN      NUMBER
     ,p_susg_ref_num      IN      NUMBER
     ,p_pack_type_code    IN      VARCHAR2
     ,p_dealer_party      IN      NUMBER
     ,p_region            IN      NUMBER
     ,p_dealer_office     IN      NUMBER
     ,p_channel_type      IN      VARCHAR2
     ,p_is_new_mobile     IN      BOOLEAN
     ,p_error_text        IN OUT  VARCHAR2
     ,p_success           IN OUT  BOOLEAN
     ,p_package_category  IN      VARCHAR2 DEFAULT NULL
     ,p_nety_type_code    IN      VARCHAR2 DEFAULT NULL
   );

   --
   PROCEDURE setup_disc_new_conn (
      p_date_start        IN      DATE   --execution_date
     ,p_maac_ref_num      IN      NUMBER
     ,p_susg_ref_num      IN      NUMBER
     ,p_maac_par_ref_num  IN      NUMBER
     ,p_susg_par_ref_num  IN      NUMBER
     ,p_dealer_party      IN      NUMBER
     ,p_region            IN      NUMBER
     ,p_dealer_office     IN      NUMBER
     ,p_channel_type      IN      VARCHAR2
     ,p_error_text        IN OUT  VARCHAR2
     ,p_success           IN OUT  BOOLEAN
     ,p_sept_type_code    IN      serv_package_types.type_code%TYPE DEFAULT NULL
   );

   --
   FUNCTION control_dealer (
      p_dico_ref_num       discount_codes.ref_num%TYPE
     ,p_date               DATE   --order date
     ,p_channel_type   IN  VARCHAR2
     ,p_dealer_party   IN  NUMBER
     ,p_region         IN  NUMBER
     ,p_dealer_office  IN  NUMBER
   )
      RETURN VARCHAR2;

   --
   FUNCTION new_and_several_mob (
      p_dico_rec       IN      discount_codes%ROWTYPE
     ,p_susg_ref_num   IN      NUMBER
     ,p_is_new_mobile  IN      BOOLEAN
     ,p_count          OUT     NUMBER
   )
      RETURN BOOLEAN;

   --
   -- Fn annab tagasi arvu, mitmes soodustus anti. Üks kahest (p_dico / p_spoc) peab olema NULL
   -- p_update_count = Kas tabelis discount_codes suurendada väärtust "given_count".
   FUNCTION discount_count (
      p_dico_ref_num       discount_codes.ref_num%TYPE
     ,p_update_count       VARCHAR2   --Kas tabelis discount_codes suurendada väärtust "given_count".
     ,p_success       OUT  BOOLEAN
     ,p_error_text    OUT  VARCHAR2
   )
      RETURN NUMBER;

   --
   -- Fn annab tagasi Y/N, kas soodustus MA'le lubatud või mitte tabelis discount_allowed_list.
   -- Üks kahest (p_dico / p_spoc) peab olema NULL
   -- p_date DATE -- Millise kuupäevaga tuleb soodustus
   FUNCTION control_ma_for_special (
      p_maac_ref_num  IN  NUMBER
     ,p_dico_ref_num      discount_codes.ref_num%TYPE
     ,p_date              DATE
   )
      RETURN VARCHAR2;

   --
   -- Fn annab tagasi Y/N, kas soodustus MA'le lubatud või mitte (party,chca,bicy,month_of_serv,new_ma).
   -- Üks kahest (p_dico / p_spoc) peab olema null
   FUNCTION control_ma_for_discount (
      p_maac_ref_num  IN  NUMBER
     ,p_date_start        DATE
     ,p_dico_ref_num      discount_codes.ref_num%TYPE
   )
      RETURN VARCHAR2;

   --
   PROCEDURE calculate_one_amount (
      p_chg_duration    IN      NUMBER   -- kestus
     ,p_price           IN      NUMBER   -- hind
     ,p_cadc            IN      call_discount_codes%ROWTYPE
     ,p_cutoff_day_num  IN      NUMBER   -- Kuumaksu  soodustuse miinimumhinna defineerimiseks
     ,p_disc_duration   IN OUT  NUMBER
     ,p_disc_amount     IN OUT  NUMBER
     ,p_padi_ref_num    IN      NUMBER DEFAULT NULL  --mobet-75
   );

   --
   PROCEDURE sum_end_discount (
      p_susg_ref_num       NUMBER
     ,p_cadc_ref_num       NUMBER
     ,p_success       OUT  BOOLEAN
     ,p_text          OUT  VARCHAR2
   );

   --
   PROCEDURE sum_end_one_discount (
      p_sudi_ref_num       NUMBER
     ,p_success       OUT  BOOLEAN
     ,p_text          OUT  VARCHAR2
   );

   --
   PROCEDURE carry_discount_to_entry (
      p_invo               invoices%ROWTYPE
     ,p_maac_ref_num       accounts.ref_num%TYPE
     ,p_susg_ref_num       subs_serv_groups.ref_num%TYPE
     ,p_error         OUT  VARCHAR2
     ,p_success       OUT  BOOLEAN
   );

   --
   --Leiab kas susgil on vastav soodustus olemas
   FUNCTION has_susg_discount (
      p_susg_ref_num   NUMBER
     ,p_discount_code  VARCHAR2
   )
      RETURN BOOLEAN;

   --
   PROCEDURE setup_cadc_completed (
      p_cadc_ref_num  IN      NUMBER
     ,p_error_text    IN OUT  VARCHAR2
     ,p_success       IN OUT  BOOLEAN
   );

   --
   PROCEDURE validate_manual_discount (
      p_discount_code   IN      VARCHAR2
     ,p_maac_ref_num    IN      accounts.ref_num%TYPE
     ,p_deal_ref_num    IN      parties.ref_num%TYPE
     ,p_region          IN      dealer_offices.region_code%TYPE
     ,p_deof_ref_num    IN      dealer_offices.ref_num%TYPE
     ,p_channel_type    IN      VARCHAR2
     ,p_active_date     IN      DATE
     ,p_susg_ref_num    IN      subs_serv_groups.ref_num%TYPE
     ,p_success         IN OUT  BOOLEAN
     ,p_dico_rec        OUT     discount_codes%ROWTYPE
     ,p_sept_type_code  IN      serv_package_types.type_code%TYPE DEFAULT NULL
   );

   --
   FUNCTION chk_apply_package (
      p_dico_ref_num    IN  discount_codes.ref_num%TYPE
     ,p_susg_ref_num    IN  subs_serv_groups.ref_num%TYPE
     ,p_sept_type_code  IN  serv_package_types.type_code%TYPE
   )
      RETURN BOOLEAN;

   --
   PROCEDURE find_ma_service_discounts (
      p_discount_type   IN      fixed_charge_types.discount_type%TYPE
     ,p_invo_ref_num    IN      invoices.ref_num%TYPE
     ,p_sety_ref_num    IN      service_types.ref_num%TYPE
     ,p_sepv_ref_num    IN      service_param_values.ref_num%TYPE   -- esialgu ei kodeeri
     ,p_maas_ref_num    IN      master_account_services.ref_num%TYPE
     ,p_charged_value   IN      NUMBER
     ,p_maac_ref_num    IN      accounts.ref_num%TYPE
     ,p_fcdt_type_code  IN      fixed_charge_item_types.fcdt_type_code%TYPE
     ,p_inen_rowid      IN      VARCHAR2
     ,p_chk_date        IN      DATE
     ,p_error_text      OUT     VARCHAR2
     ,p_success         OUT     BOOLEAN
     ,p_mode            IN      VARCHAR2 DEFAULT 'INS'   -- INS/DEL
     ,p_additional_entry_text  IN invoice_entries.additional_entry_text%TYPE DEFAULT NULL -- DOBAS-262

   );

   --
   FUNCTION get_ma_serv_discount_amount (
      p_full_chg_value    IN  NUMBER
     ,p_remain_chg_value  IN  NUMBER
     ,p_cadc_min_price    IN  call_discount_codes.minimum_price%TYPE
     ,p_percentage        IN  call_discount_codes.precentage%TYPE
     ,p_discount_schema   IN  call_discount_codes.pricing%TYPE
   )
      RETURN NUMBER;

   --
   PROCEDURE invoice_discount (
      p_maas_ref_num      IN      master_account_services.ref_num%TYPE
     ,p_invo_ref_num      IN      invoices.ref_num%TYPE
     ,p_inen_rowid        IN      VARCHAR2
     ,p_discounted_value  IN      NUMBER
     ,p_cadc_rec          IN      call_discount_codes%ROWTYPE
     ,p_chk_date          IN      DATE
     ,p_fcdt_type_code    IN      fixed_charge_item_types.fcdt_type_code%TYPE
     ,p_success           OUT     BOOLEAN
     ,p_message           OUT     VARCHAR2
     ,p_mode              IN      VARCHAR2 DEFAULT 'INS'   -- INS/DEL
   );
   
   --
   FUNCTION calculate_sudi_end_date (p_dico_ref_num    IN discount_codes.ref_num%TYPE
                                    ,p_sudi_start_date IN subs_discounts.start_date%TYPE
   ) RETURN subs_discounts.end_date%TYPE;
--
END calculate_discounts;
/

CREATE OR REPLACE PACKAGE BODY TBCIS.CALCULATE_DISCOUNTS AS
   /*
   ** Package level type declarations
   */
   TYPE t_ref_num IS TABLE OF NUMBER (10)
      INDEX BY BINARY_INTEGER;

   /*
     ** Private functions and procedures
   */
   PROCEDURE get_discountable_amount (
      p_period_end             IN      DATE
     ,p_dico_start_date        IN      DATE
     ,p_disc_billing_selector  IN      VARCHAR2
     ,p_cadc_ref_num           IN      NUMBER
     ,p_maac_ref_num           IN      NUMBER
     ,p_susg_ref_num           IN      NUMBER
     ,p_billing_selector       IN      VARCHAR2
     ,p_fcit_type_code         IN      VARCHAR2
     ,p_inen_amount            IN      NUMBER
     ,p_max_amount             IN      NUMBER
     ,p_discountable_amount    OUT     NUMBER
   ) IS
      --
      CURSOR c_fcit IS
         SELECT *
           FROM fixed_charge_item_types
          WHERE type_code = p_fcit_type_code;

      --
      CURSOR c_inen (
         p_period_start  DATE
        ,p_dico_start    DATE
      ) IS
         SELECT SUM (inen.eek_amt)
           FROM invoice_entries inen, invoices invo
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start AND p_period_end
            AND inen.invo_ref_num = invo.ref_num
            AND inen.susg_ref_num = p_susg_ref_num
            AND (inen.date_created >= p_dico_start OR p_dico_start IS NULL)
            AND inen.billing_selector = p_billing_selector
            AND inen.fcit_type_code IN (SELECT type_code
                                          FROM fixed_charge_item_types
                                         WHERE billing_selector = p_billing_selector
                                           AND type_code = p_fcit_type_code
                                           AND regular_charge = 'Y'
                                           AND once_off = 'N'
                                           AND pro_rata = 'N');

      --
      CURSOR c_comc (
         p_period_start  DATE
        ,p_dico_start    DATE
      ) IS
         SELECT MAX (comc.eek_amt)
           FROM invoices invo, common_monthly_charges comc
          WHERE invo.ref_num = comc.invo_ref_num
            AND invo.maac_ref_num = p_maac_ref_num
            AND comc.susg_ref_num = p_susg_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start AND p_period_end
            AND comc.billing_selector = p_billing_selector
            AND comc.fcit_type_code IN (SELECT type_code
                                          FROM fixed_charge_item_types
                                         WHERE billing_selector = p_billing_selector
                                           AND type_code = p_fcit_type_code
                                           AND regular_charge = 'Y'
                                           AND once_off = 'N'
                                           AND pro_rata = 'N');

      --
      CURSOR c_inen_dico (
         p_period_start  DATE
        ,p_dico_start    DATE
      ) IS
         SELECT 1
           FROM invoice_entries inen, invoices invo
          WHERE invo.maac_ref_num = p_maac_ref_num
            AND invo.billing_inv = 'Y'
            AND invo.period_start BETWEEN p_period_start AND p_period_end
            AND (NVL (inen.date_updated, inen.date_created) >= p_dico_start OR p_dico_start IS NULL)
            AND inen.invo_ref_num = invo.ref_num
            AND inen.susg_ref_num = p_susg_ref_num
            AND inen.billing_selector = p_disc_billing_selector
            AND inen.eek_amt <> 0
            AND inen.cadc_ref_num IN (SELECT ref_num
                                        FROM call_discount_codes
                                       WHERE for_billing_selector = p_billing_selector
                                         AND for_fcit_type_code = p_fcit_type_code
                                         AND disc_billing_selector = p_disc_billing_selector)
            AND inen.fcdt_type_code = (SELECT fcdt_type_code
                                         FROM fixed_charge_item_types
                                        WHERE type_code = p_fcit_type_code);

      --
      l_dummy                       NUMBER;
      l_dico_on_inen                BOOLEAN;
      l_inen_exists                 BOOLEAN;
      l_period_start                DATE;
      l_dico_start                  DATE;
      l_invoiced_amount             NUMBER;
      l_discountable_amount         NUMBER;
      l_fcit_rec                    fixed_charge_item_types%ROWTYPE;
   BEGIN
      IF p_max_amount IS NULL THEN
         --
         p_discountable_amount := p_inen_amount;
      --
      ELSE
         -- Leiame arveldusperioodi alguse
         l_period_start := TRUNC (p_period_end, 'MM');

         -- Väärtustame dico_start, kui see on suurem arveldusperioodi alguskuupäevast
         IF p_dico_start_date > l_period_start THEN
            l_dico_start := p_dico_start_date;
         END IF;

         -- Leiame FCIT kirje
         OPEN c_fcit;

         FETCH c_fcit
          INTO l_fcit_rec;

         CLOSE c_fcit;

         -- Kas arveldusperioodis on juba discount rakendunud
         OPEN c_inen_dico (l_period_start, l_dico_start);

         FETCH c_inen_dico
          INTO l_dummy;

         l_dico_on_inen := c_inen_dico%FOUND;

         CLOSE c_inen_dico;

         IF l_fcit_rec.bill_fcit_type_code IS NOT NULL THEN
            -- Kui INEN tabelis sissekanded puuduvad, kontrollime COMC tabelist
            -- (MinuEMT lahendustasu komponendid)
            OPEN c_comc (l_period_start, NULL);

            FETCH c_comc
             INTO l_invoiced_amount;

            CLOSE c_comc;
         --
         ELSE
            -- Leiame, kas teenuse kuutasu on arveldusperioodis arvele kantud (vahearve)
            OPEN c_inen (l_period_start, l_dico_start);

            FETCH c_inen
             INTO l_invoiced_amount;

            l_inen_exists := c_inen%FOUND;

            CLOSE c_inen;
         --
         END IF;

         --
         l_invoiced_amount := NVL (l_invoiced_amount, 0);

         IF l_invoiced_amount >= p_max_amount AND l_dico_on_inen THEN
            -- Soodustus peaks olema arvel, uuesti ei rakenda
            l_discountable_amount := 0;
         --
         ELSIF l_invoiced_amount >= p_max_amount AND NOT l_dico_on_inen THEN
            -- Kuutasu on arvele kantud, aga soodustus pole mingil põhjusel rakendunud
            -- Rakendame soodustuse suurimale arveldusperioodis arveldatavale summale
            l_discountable_amount := GREATEST (l_invoiced_amount, p_max_amount);
         --
         ELSIF l_invoiced_amount < p_max_amount THEN
            --
            IF l_dico_on_inen THEN
               -- Kuutasu on suurenenud, leiame täiendavale osale ka soodustuse
               l_discountable_amount := p_max_amount - l_invoiced_amount;
            ELSE
               -- Soodustust pole rakendatud
               l_discountable_amount := p_max_amount;
            END IF;
         --
         END IF;

         --
         p_discountable_amount := l_discountable_amount;
      --
      END IF;
   --
   END get_discountable_amount;

   /*
     ** Global functions and procedures
   */
   FUNCTION has_susg_discount (
      p_susg_ref_num   NUMBER
     ,p_discount_code  VARCHAR2
   )
      RETURN BOOLEAN IS
      ------------------------------------------------------------------------------------
      -- T.Hipeli  16.04.2002  UPR 1991   Leiab kas susgil on vastav soodustus olemas
      ------------------------------------------------------------------------------------
      CURSOR c_dico IS
         SELECT for_all
               ,ref_num
           FROM discount_codes
          WHERE discount_code = p_discount_code;

      --
      CURSOR c_sudi (
         p_dico_ref_num  NUMBER
      ) IS
         SELECT 1
           FROM subs_discounts
          WHERE dico_ref_num = p_dico_ref_num AND susg_ref_num = p_susg_ref_num;

      --
      l_for_all                     discount_codes.for_all%TYPE;
      l_dico_ref_num                discount_codes.ref_num%TYPE;
      l_success                     BOOLEAN;
      l_dummy                       NUMBER;
   BEGIN
      OPEN c_dico;

      FETCH c_dico
       INTO l_for_all
           ,l_dico_ref_num;

      IF c_dico%NOTFOUND THEN
         RETURN FALSE;
      END IF;

      CLOSE c_dico;

      --
      IF l_for_all = 'Y' THEN
         RETURN TRUE;
      ELSE
         OPEN c_sudi (l_dico_ref_num);

         FETCH c_sudi
          INTO l_dummy;

         IF c_sudi%NOTFOUND THEN
            RETURN FALSE;
         ELSE
            RETURN TRUE;
         END IF;

         CLOSE c_sudi;
      END IF;
   END has_susg_discount;

   --
   --
   PROCEDURE insert_evmd (
      p_evmd        IN OUT NOCOPY  evre_min_discounts%ROWTYPE
     ,p_success     OUT            BOOLEAN
     ,p_error_text  OUT            VARCHAR2
   ) IS
   BEGIN
      IF p_evmd.ref_num IS NULL THEN
         SELECT evmd_ref_num_s.NEXTVAL
           INTO p_evmd.ref_num
           FROM SYS.DUAL;
      END IF;

      IF (p_evmd.created_by IS NULL) THEN
         p_evmd.created_by := sec.get_username;
      END IF;

      IF (p_evmd.date_created IS NULL) THEN
         p_evmd.date_created := SYSDATE;
      END IF;

      INSERT INTO evre_min_discounts evmd
                  (evmd.ref_num   --NOT NULL NUMBER(16)
                  ,evmd.evre_ref_num   --NOT NULL NUMBER(16)
                  ,evmd.dica_ref_num   --NOT NULL NUMBER(16)
                  ,evmd.discount_code   --NOT NULL VARCHAR2(3)
                  ,evmd.discount_duration   --         NUMBER(10)
                  ,evmd.discount_amount   --         NUMBER(14,3)
                  ,evmd.char_anal_code   --         VARCHAR2(3)
                  ,evmd.date_created   --         DATE
                  ,evmd.created_by   --         VARCHAR2(30)
                  ,evmd.cadc_ref_num   --         NUMBER(10)      upr 1991
                  ,evmd.inen_ref_num   --         NUMBER(10)    upr 1991
                  ,evmd.cadc_sudi_ref_num   --         NUMBER(10)    upr 1991
                  ,evmd.invo_ref_num   --         NUMBER(10)
                  )
           VALUES (p_evmd.ref_num
                  ,p_evmd.evre_ref_num
                  ,p_evmd.dica_ref_num
                  ,p_evmd.discount_code
                  ,p_evmd.discount_duration
                  ,p_evmd.discount_amount
                  ,p_evmd.char_anal_code
                  ,p_evmd.date_created
                  ,p_evmd.created_by
                  ,p_evmd.cadc_ref_num
                  ,p_evmd.inen_ref_num
                  ,p_evmd.cadc_sudi_ref_num
                  ,p_evmd.invo_ref_num
                  );

      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
   END insert_evmd;

   --
   PROCEDURE undo_evre_min_discount (
      p_evre          IN      event_records_curr%ROWTYPE
     ,p_evmd_rec      IN      evre_min_discounts%ROWTYPE
     ,p_evre_rowid    IN      VARCHAR2
     ,p_evmd_rowid    IN      VARCHAR2
     ,p_invo_ref_num  IN OUT  invoices.ref_num%TYPE
     ,p_undo_allowed  IN OUT  VARCHAR2
     ,p_upd_sudi      IN      BOOLEAN
   ) IS
      --
      --kontrollida, kas soodustust saab tagasi võtta (kas arve on kinni)
      CURSOR c_invo (
         p_invo_ref_num  NUMBER
      ) IS
         SELECT TRUNC (i.period_start)
           FROM invoices i
          WHERE i.ref_num = p_invo_ref_num AND i.period_end IS NULL;

      --
      -- kontroll, ega arve ei läinud 0 ega vastasmärgiks
      CURSOR c_inen (
         p_inen_ref_num  NUMBER
      ) IS
         SELECT        *
                  FROM invoice_entries
                 WHERE ref_num = p_inen_ref_num
         FOR UPDATE OF acc_amount /* CHG4594 */, eek_amt;

      --
      -- kontrollida, kas kuu lõpu arveldus pole käima läinud?
      CURSOR c_main_start (
         p_period_start  DATE
      ) IS
         SELECT 1   --ei või tegutseda, kui main_bill on käima läinud
           FROM bill_cycles
          WHERE ADD_MONTHS (p_period_start, 1) <= TRUNC (start_main_bill);

      --
      CURSOR c_other_evmd_exists (
         p_inen_ref_num  NUMBER
        ,p_evmd_ref_num  NUMBER
      ) IS
         SELECT 'Y'
           FROM evre_min_discounts
          WHERE inen_ref_num = p_inen_ref_num AND ref_num <> p_evmd_ref_num;

      --
      l_period_start                DATE;
      l_bill_period                 NUMBER;
      l_acc_amt                     invoice_entries.acc_amount%TYPE;   -- CHG4594
      l_exist                       VARCHAR2 (1);
      l_inen_rec                    invoice_entries%ROWTYPE;
      l_found                       BOOLEAN;
      l_dummy                       NUMBER;
   BEGIN
      IF p_evmd_rec.invo_ref_num IS NOT NULL THEN
         IF p_evmd_rec.invo_ref_num <> p_invo_ref_num THEN
            OPEN c_invo (p_evmd_rec.invo_ref_num);

            FETCH c_invo
             INTO l_period_start;

            l_found := c_invo%FOUND;

            CLOSE c_invo;

            p_invo_ref_num := p_evmd_rec.invo_ref_num;

            --
            -- kui period_start on,on arve lahti ja võib soodustust tagasi arvutada;
            IF l_found THEN
               OPEN c_main_start (l_period_start);

               FETCH c_main_start
                INTO l_dummy;

               l_found := c_main_start%FOUND;

               CLOSE c_main_start;

               --
               IF l_found THEN
                  p_undo_allowed := 'N';
               ELSE
                  p_undo_allowed := 'Y';
               END IF;
            ELSE
               p_undo_allowed := 'N';
            END IF;
         END IF;
      ELSE
         p_undo_allowed := 'Y';
      END IF;

      --
      IF p_undo_allowed = 'Y' THEN
         -- keri soodustus tagasi
         DELETE FROM evre_min_discounts
               WHERE ROWID = p_evmd_rowid;

         --
         IF p_evmd_rec.inen_ref_num IS NOT NULL THEN
            OPEN c_inen (p_evmd_rec.inen_ref_num);

            FETCH c_inen
             INTO l_inen_rec;

            --
            IF c_inen%FOUND THEN
               -- CHG4594 asendatud väli ja täpsus
               l_acc_amt := ROUND (l_inen_rec.acc_amount + p_evmd_rec.discount_amount, get_inen_acc_precision);

               --
               IF l_acc_amt >= 0 THEN   --soodustus peab arvel olema negatiivne /kui on suurem kui null, on tegelikult ERROR!
                  l_exist := NULL;

                  OPEN c_other_evmd_exists (p_evmd_rec.inen_ref_num, p_evmd_rec.ref_num);

                  FETCH c_other_evmd_exists
                   INTO l_exist;

                  CLOSE c_other_evmd_exists;

                  --
                  IF l_exist = 'Y' THEN
                     ------ERROR!
                     UPDATE invoice_entries
                        SET acc_amount = l_acc_amt   -- CHG4594
                      --,evre_char_usage  = l_inen_rec.evre_char_usage-rec_3.discount_duration
                     WHERE CURRENT OF c_inen;
                  ELSE
                     DELETE FROM invoice_entries
                           WHERE CURRENT OF c_inen;
                  END IF;
               ELSE
                  UPDATE invoice_entries
                     SET acc_amount = l_acc_amt   -- CHG4594
                   --,evre_char_usage  = l_inen_rec.evre_char_usage-rec_3.discount_duration
                  WHERE CURRENT OF c_inen;
               END IF;
            END IF;

            CLOSE c_inen;
         END IF;

         --
         l_bill_period := TO_NUMBER (TO_CHAR (p_evre.chg_date, 'YYYYMM'));

         UPDATE disc_call_amounts
            SET min_discount = GREATEST (min_discount - p_evmd_rec.discount_duration, 0)
               ,call_discount = GREATEST (call_discount - p_evmd_rec.discount_amount, 0)
               ,calculate_count = GREATEST (calculate_count - 1, 0)
               ,int_dur_discount = GREATEST (int_dur_discount - 1, 0)
          WHERE susg_ref_num = p_evre.susg_ref_num
            AND sudi_ref_num = p_evmd_rec.cadc_sudi_ref_num
            AND created_bill_period = l_bill_period;

         --
         IF p_evre_rowid IS NOT NULL THEN
            UPDATE event_records_curr
               SET min_discount_exists = NULL
                  ,min_discount_amount = NULL
             WHERE ROWID = p_evre_rowid;
         ELSE
            UPDATE event_records_curr
               SET min_discount_exists = NULL
                  ,min_discount_amount = NULL
             WHERE ref_num = p_evre.ref_num;
         END IF;

         --
         IF p_upd_sudi THEN
            UPDATE subs_discounts
               SET closed = NULL
             WHERE ref_num = p_evmd_rec.cadc_sudi_ref_num;
         END IF;
      END IF;
   END undo_evre_min_discount;

   --
   PROCEDURE undo_evre_discounts (
      p_evre             event_records_curr%ROWTYPE
     ,p_success     OUT  BOOLEAN
     ,p_error_text  OUT  VARCHAR2
   ) IS
      -- võtab tagasi kõnesündmusele rakendatud kõik soodustused (va FF soodustus)

      --kõnekirjele rakendatud soodustused:
      CURSOR c_evmd (
         p_evre_ref_num  NUMBER
      ) IS
         SELECT   ROWID
                 ,ref_num
                 ,invo_ref_num
                 ,inen_ref_num
                 ,cadc_sudi_ref_num
                 ,discount_duration
                 ,discount_amount
             FROM evre_min_discounts
            WHERE evre_ref_num = p_evre_ref_num
         ORDER BY invo_ref_num;

      --
      l_undo_allowed                VARCHAR2 (1);
      l_invo_ref_num                invoices.ref_num%TYPE := 0;
      l_evmd_rowid                  VARCHAR2 (30);
      l_evmd_rec                    evre_min_discounts%ROWTYPE;
   BEGIN
      FOR evmd IN c_evmd (p_evre.ref_num) LOOP
         l_evmd_rowid := evmd.ROWID;
         l_evmd_rec.ref_num := evmd.ref_num;
         l_evmd_rec.invo_ref_num := evmd.invo_ref_num;
         l_evmd_rec.inen_ref_num := evmd.inen_ref_num;
         l_evmd_rec.cadc_sudi_ref_num := evmd.cadc_sudi_ref_num;
         l_evmd_rec.discount_duration := evmd.discount_duration;
         l_evmd_rec.discount_amount := evmd.discount_amount;
         --
         undo_evre_min_discount (p_evre
                                ,l_evmd_rec
                                ,NULL   -- p_evre_rowid (not known here)
                                ,l_evmd_rowid
                                ,l_invo_ref_num
                                ,l_undo_allowed
                                ,TRUE   -- update subs discounts
                                );
      END LOOP;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM || 'Undo_Evre_Discounts ERROR';
   END undo_evre_discounts;

   ----------------------------------------------------------------------
   PROCEDURE undo_min_discounts (
      p_susg_ref_num       NUMBER
     ,p_sudi_ref_num       NUMBER
     ,p_success       OUT  BOOLEAN
     ,p_error_text    OUT  VARCHAR2
   ) IS
      --
      CURSOR c_sudi_dico (
         p_sudi_ref_num  NUMBER
      ) IS
         SELECT dico_ref_num
           FROM subs_discounts
          WHERE ref_num = p_sudi_ref_num;

      --
      CURSOR c_sudi_cadc (
         p_sudi_ref_num  NUMBER
        ,p_susg_ref_num  NUMBER
        ,p_dico_ref_num  NUMBER
      ) IS
         SELECT s.ref_num
           FROM subs_discounts s, call_discount_codes c
          WHERE s.susg_ref_num = p_susg_ref_num
            AND s.dico_ref_num = p_dico_ref_num
            AND s.cadc_ref_num IS NOT NULL
            AND s.dico_sudi_ref_num = p_sudi_ref_num
            AND s.cadc_ref_num = c.ref_num
            AND c.call_type = c_discount_type_min;

      --
      CURSOR c_dica (
         p_susg_ref_num  NUMBER
        ,p_sudi_ref_num  NUMBER
      ) IS
         SELECT *
           FROM disc_call_amounts
          WHERE susg_ref_num = p_susg_ref_num AND sudi_ref_num = p_sudi_ref_num;

      --
      CURSOR c_evmd (
         p_dica_ref_num  NUMBER
      ) IS
         SELECT   ROWID
                 ,ref_num
                 ,invo_ref_num
                 ,inen_ref_num
                 ,cadc_sudi_ref_num
                 ,discount_duration
                 ,discount_amount
                 ,evre_ref_num
             FROM evre_min_discounts
            WHERE dica_ref_num = p_dica_ref_num
         ORDER BY evre_ref_num, invo_ref_num;

      --
      CURSOR c_evre (
         p_evre_ref_num  NUMBER
      ) IS
         SELECT ROWID
               ,ref_num
               ,susg_ref_num
               ,chg_date
           FROM event_records_curr
          WHERE ref_num = p_evre_ref_num;

      --
      l_dico_ref_num                NUMBER;
      l_undo_allowed                VARCHAR2 (1);
      l_invo_ref_num                invoices.ref_num%TYPE := 0;
      l_evmd_rec                    evre_min_discounts%ROWTYPE;
      l_evmd_rowid                  VARCHAR2 (30);
      l_evre_rec                    event_records_curr%ROWTYPE;
      l_evre_rowid                  VARCHAR2 (30);
   BEGIN
      OPEN c_sudi_dico (p_sudi_ref_num);

      FETCH c_sudi_dico
       INTO l_dico_ref_num;

      CLOSE c_sudi_dico;

      --
      FOR rec_1 IN c_sudi_cadc (p_sudi_ref_num, p_susg_ref_num, l_dico_ref_num) LOOP
         FOR rec_2 IN c_dica (p_susg_ref_num, rec_1.ref_num) LOOP
            FOR evmd IN c_evmd (rec_2.ref_num) LOOP
               l_evmd_rowid := evmd.ROWID;
               l_evmd_rec.ref_num := evmd.ref_num;
               l_evmd_rec.invo_ref_num := evmd.invo_ref_num;
               l_evmd_rec.inen_ref_num := evmd.inen_ref_num;
               l_evmd_rec.cadc_sudi_ref_num := evmd.cadc_sudi_ref_num;
               l_evmd_rec.discount_duration := evmd.discount_duration;
               l_evmd_rec.discount_amount := evmd.discount_amount;
               l_evmd_rec.evre_ref_num := evmd.evre_ref_num;

               --
               OPEN c_evre (l_evmd_rec.evre_ref_num);

               FETCH c_evre
                INTO l_evre_rowid
                    ,l_evre_rec.ref_num
                    ,l_evre_rec.susg_ref_num
                    ,l_evre_rec.chg_date;

               CLOSE c_evre;

               --
               undo_evre_min_discount (l_evre_rec
                                      ,l_evmd_rec
                                      ,l_evre_rowid
                                      ,l_evmd_rowid
                                      ,l_invo_ref_num
                                      ,l_undo_allowed
                                      ,FALSE   -- don't update subs discounts
                                      );
            END LOOP;
         END LOOP;
      END LOOP;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM || 'Undo_Min_Discounts ERROR';
   END undo_min_discounts;

   --------------------------------------------------------------------------------
   --------------------------------------------------------------------------------
   ----------------------------------------------------------------------------------
   PROCEDURE find_amount_dica_fcit (
      p_susg_ref_num              NUMBER
     ,p_cadc_ref_num              NUMBER
     ,p_sudi_ref_num              NUMBER
     ,p_fcit_type_code            VARCHAR2
     ,p_billing_selector          VARCHAR2
     ,p_bill_period               NUMBER
     ,p_in_month          IN OUT  NUMBER
     ,p_prev_period       IN OUT  NUMBER
     ,p_in_duration       IN OUT  NUMBER
     ,p_prev_duration     IN OUT  NUMBER
     ,p_bill_sel_sum              VARCHAR2
   ) IS
      --
      CURSOR c_amount_period IS
         SELECT NVL (SUM (NVL (dica.call_discount, dica.sum_interim_disc)), 0)
               ,NVL (SUM (NVL (dica.min_discount, sum_int_dur_discount)), 0)
           FROM disc_call_amounts dica
          WHERE dica.susg_ref_num = p_susg_ref_num
            AND dica.sudi_ref_num IN (SELECT s1.ref_num
                                        FROM subs_discounts s1
                                       WHERE s1.susg_ref_num = p_susg_ref_num
                                         AND s1.dico_sudi_ref_num IN (SELECT DISTINCT s2.dico_sudi_ref_num
                                                                                 FROM subs_discounts s2
                                                                                WHERE s2.ref_num = p_sudi_ref_num))
            AND dica.call_type = p_billing_selector
            AND dica.created_bill_period = p_bill_period
            AND (dica.for_fcit_type_code = p_fcit_type_code OR p_fcit_type_code IS NULL)
            AND (   (dica.cadc_ref_num = p_cadc_ref_num AND p_bill_sel_sum = 'N')
                 OR (    p_bill_sel_sum = 'Y'
                     AND dica.cadc_ref_num IN (SELECT DISTINCT ref_num
                                                          FROM call_discount_codes
                                                         WHERE dico_ref_num = (SELECT DISTINCT dico_ref_num
                                                                                          FROM call_discount_codes
                                                                                         WHERE ref_num = p_cadc_ref_num))
                    )
                );

      --
      CURSOR c_amount_prev IS
         SELECT NVL (SUM (NVL (dica.call_discount, dica.sum_interim_disc)), 0)
               ,NVL (SUM (NVL (dica.min_discount, sum_int_dur_discount)), 0)
           FROM disc_call_amounts dica
          WHERE dica.susg_ref_num = p_susg_ref_num
            AND dica.sudi_ref_num IN (SELECT s1.ref_num
                                        FROM subs_discounts s1
                                       WHERE s1.susg_ref_num = p_susg_ref_num
                                         AND s1.dico_sudi_ref_num IN (SELECT DISTINCT s2.dico_sudi_ref_num
                                                                                 FROM subs_discounts s2
                                                                                WHERE s2.ref_num = p_sudi_ref_num))
            AND dica.call_type = p_billing_selector
            AND dica.created_bill_period <> p_bill_period
            AND (dica.for_fcit_type_code = p_fcit_type_code OR p_fcit_type_code IS NULL)
            AND (   (    dica.cadc_ref_num = (SELECT ref_num
                                                FROM call_discount_codes
                                               WHERE ref_num = p_cadc_ref_num
                                                 AND dica.created_bill_period BETWEEN TO_NUMBER (TO_CHAR (start_date
                                                                                                         ,'yyyymm'
                                                                                                         )
                                                                                                )
                                                                                  AND TO_NUMBER
                                                                                               (TO_CHAR (NVL (end_date
                                                                                                             ,SYSDATE
                                                                                                             )
                                                                                                        ,'yyyymm'
                                                                                                        )
                                                                                               ))
                     AND p_bill_sel_sum = 'N'
                    )
                 OR (    p_bill_sel_sum = 'Y'
                     AND dica.cadc_ref_num IN (SELECT DISTINCT ref_num
                                                          FROM call_discount_codes
                                                         WHERE dico_ref_num IN (SELECT DISTINCT dico_ref_num
                                                                                           FROM call_discount_codes
                                                                                          WHERE ref_num = p_cadc_ref_num)
                                                           AND dica.created_bill_period
                                                                  BETWEEN TO_NUMBER (TO_CHAR (start_date, 'yyyymm'))
                                                                      AND TO_NUMBER (TO_CHAR (NVL (end_date, SYSDATE)
                                                                                             ,'yyyymm'
                                                                                             )
                                                                                    ))
                    )
                );
   --
   BEGIN
      OPEN c_amount_period;

      FETCH c_amount_period
       INTO p_in_month
           ,p_in_duration;

      CLOSE c_amount_period;

      OPEN c_amount_prev;

      FETCH c_amount_prev
       INTO p_prev_period
           ,p_prev_duration;

      CLOSE c_amount_prev;
   --läheb null väärtusega, kui pole soodustust arvutatud
   END find_amount_dica_fcit;

   --
   PROCEDURE find_amount_dica (
      p_susg_ref_num              NUMBER
     ,p_sudi_ref_num              NUMBER
     ,p_bill_period               NUMBER
     ,p_in_month          IN OUT  NUMBER
     ,p_prev_period       IN OUT  NUMBER
     ,p_in_duration       IN OUT  NUMBER
     ,p_prev_duration     IN OUT  NUMBER
     ,p_in_count          IN OUT  NUMBER
     ,p_prev_count        IN OUT  NUMBER
     ,p_in_count_count    IN OUT  NUMBER   -- mitu 'in' kõnet selle count'ga soodust. saanud
     ,p_prev_count_count  IN OUT  NUMBER   -- mitu 'prev' kõnet selle count'ga soodust. saanud
   ) IS
      --
      CURSOR c_amount_period IS
         SELECT NVL (SUM (NVL (dica.call_discount, dica.sum_interim_disc)), 0)
               ,NVL (SUM (NVL (dica.min_discount, dica.sum_int_dur_discount)), 0)
               ,NVL (SUM (dica.calculate_count), 0)
               ,NVL (SUM (dica.int_dur_discount), 0)
           FROM disc_call_amounts dica
          WHERE dica.susg_ref_num = p_susg_ref_num
            AND dica.sudi_ref_num = p_sudi_ref_num
            AND dica.created_bill_period = p_bill_period;

      --
      CURSOR c_amount_prev IS
         SELECT NVL (SUM (NVL (dica.call_discount, dica.sum_interim_disc)), 0)
               ,NVL (SUM (NVL (dica.min_discount, dica.sum_int_dur_discount)), 0)
               ,NVL (SUM (dica.calculate_count), 0)
               ,NVL (SUM (dica.int_dur_discount), 0)
           FROM disc_call_amounts dica
          WHERE dica.susg_ref_num = p_susg_ref_num
            AND dica.sudi_ref_num = p_sudi_ref_num
            AND dica.created_bill_period <> p_bill_period;
   --
   BEGIN
      OPEN c_amount_period;

      FETCH c_amount_period
       INTO p_in_month
           ,p_in_duration
           ,p_in_count
           ,p_in_count_count;

      CLOSE c_amount_period;

      OPEN c_amount_prev;

      FETCH c_amount_prev
       INTO p_prev_period
           ,p_prev_duration
           ,p_prev_count
           ,p_prev_count_count;

      CLOSE c_amount_prev;
   --läheb null väärtusega, kui pole soodustust arvutatud
   END find_amount_dica;

   ------------------------------------------------------------------
   --
   PROCEDURE find_amount_sudi (
      p_susg_ref_num          NUMBER
     ,p_sudi_ref_num          NUMBER
     ,p_amount        IN OUT  NUMBER
   ) IS
      --
      CURSOR c_amount IS
         SELECT NVL (SUM (NVL (dica.call_discount, dica.sum_interim_disc)), 0)
           FROM disc_call_amounts dica
          WHERE dica.susg_ref_num = p_susg_ref_num AND dica.sudi_ref_num = p_sudi_ref_num;
   --
   BEGIN
      OPEN c_amount;

      FETCH c_amount
       INTO p_amount;

      CLOSE c_amount;
   --läheb null väärtusega, kui pole soodustust arvutatud
   END find_amount_sudi;

   ------------------------------------------------------------------
   PROCEDURE find_mon_discounts (
      p_discount_type             VARCHAR2
     ,p_invo                      invoices%ROWTYPE
     ,p_fcit_type_code            VARCHAR2
     ,p_billing_selector          VARCHAR2
     ,p_sety_ref_num              NUMBER
     ,p_sepa_ref_num              NUMBER
     ,p_sepv_ref_num              NUMBER
     ,p_sept_type_code            VARCHAR2
     ,p_charge_value              NUMBER
     ,p_num_of_days               NUMBER
     ,p_susg_ref_num              NUMBER
     ,p_maac_ref_num              NUMBER
     ,p_start_date                DATE
     ,p_end_date                  DATE
     ,p_day_num                   NUMBER
     ,p_error_text        IN OUT  VARCHAR2
     ,p_success           IN OUT  BOOLEAN
   ) IS
      CURSOR c_start (
         pp_start_date  DATE
      ) IS
         SELECT   (GREATEST (pp_start_date, TRUNC (cadc.start_date))) cadc_start
                 , (GREATEST (pp_start_date
                             ,TRUNC (cadc.start_date)
                             ,NVL (TRUNC (sudi.start_date) + NVL (cadc.from_day, 0), pp_start_date)
                             )
                   ) sudi_start
                 ,   -- see annab palju sudisid
                  cadc.ref_num cadc_ref_num
                 ,sudi.ref_num sudi_ref_num
                 ,sudi.dico_ref_num dico_ref_num
                 ,cadc.start_date
                 ,sudi.padi_ref_num  --mobet-75
             FROM call_discount_codes cadc, subs_discounts sudi
            WHERE pp_start_date <= NVL (cadc.end_date, pp_start_date)
              AND p_end_date >= cadc.start_date
              AND cadc.call_type = p_discount_type
              AND NVL (cadc.discount_completed, 'N') <> 'Y'
              AND cadc.for_fcit_type_code = p_fcit_type_code
              AND (cadc.sept_type_code = p_sept_type_code OR cadc.sept_type_code IS NULL)
              AND (cadc.for_sepv_ref_num = p_sepv_ref_num OR cadc.for_sepv_ref_num IS NULL)
              AND cadc.dico_ref_num = sudi.dico_ref_num
              AND (TRUNC (sudi.start_date, 'MM') = TRUNC (pp_start_date, 'MM') OR cadc.next_bill_period = 'Y')
              AND sudi.cadc_ref_num IS NULL
              AND sudi.susg_ref_num = p_susg_ref_num
              AND NVL (sudi.closed, 'N') <> 'Y'
              AND (   ADD_MONTHS (TRUNC (sudi.start_date) + NVL (cadc.from_day, 0) + NVL (cadc.count_for_days, 0)
                                 ,NVL (cadc.count_for_months, 0)
                                 ) >= pp_start_date
                   OR (cadc.count_for_months IS NULL AND cadc.count_for_days IS NULL)
                   )
             AND ((SUDI.padi_ref_num is not null  AND exists (select 1 from part_dico_details padd
                                                              where padd.padi_ref_num = sudi.padi_ref_num
                                                              AND padd.cadc_ref_num = CADC.ref_num) )
                      OR SUDI.padi_ref_num is null
                  )  --mobet-75
             AND NVL (sudi.end_date, p_end_date) > pp_start_date   --DOBAS-561     
         ORDER BY 1, 2, 3;

      --
      CURSOR c_end (
         pp_start_date  DATE
        ,p_sudi_ref     NUMBER
      ) IS
         SELECT   LEAST (TRUNC (p_end_date)
                        ,NVL (cadc.end_date, TRUNC (p_end_date))
                        ,NVL (sudi.end_date, TRUNC (p_end_date))
                        ,NVL (TRUNC (sudi.start_date) + NVL (cadc.from_day, 0) + cadc.count_for_days, p_end_date)
                        ,NVL (ADD_MONTHS (TRUNC (sudi.start_date) + NVL (cadc.from_day, 0), cadc.count_for_months)
                             ,TRUNC (p_end_date)
                             )
                        ) sudi_dica
             FROM call_discount_codes cadc, subs_discounts sudi
            WHERE pp_start_date <= NVL (cadc.end_date, pp_start_date)
              AND p_end_date >= cadc.start_date
              AND cadc.call_type = p_discount_type
              AND cadc.discount_completed <> 'Y'
              AND cadc.for_fcit_type_code = p_fcit_type_code
              AND (cadc.sept_type_code = p_sept_type_code OR cadc.sept_type_code IS NULL)
              AND (cadc.for_sepv_ref_num = p_sepv_ref_num OR cadc.for_sepv_ref_num IS NULL)
              AND cadc.dico_ref_num = sudi.dico_ref_num   -- or dico=for_all
              AND sudi.cadc_ref_num IS NULL
              AND sudi.ref_num = p_sudi_ref
              AND (TRUNC (sudi.start_date, 'MM') = TRUNC (p_start_date, 'MM') OR cadc.next_bill_period = 'Y')
              AND sudi.cadc_ref_num IS NULL
              AND sudi.susg_ref_num = p_susg_ref_num
              AND NVL (sudi.closed, 'N') <> 'Y'
              AND (   ADD_MONTHS (TRUNC (sudi.start_date) + NVL (cadc.from_day, 0) + NVL (cadc.count_for_days, 0)
                                 ,NVL (cadc.count_for_months, 0)
                                 ) >= pp_start_date
                   OR (cadc.count_for_months IS NULL AND cadc.count_for_days IS NULL)
                  )
              AND NVL (sudi.end_date, p_end_date) > pp_start_date
         ORDER BY 1;

      CURSOR c_cadc (
         p_ref_num  NUMBER
      ) IS
         SELECT *
           FROM call_discount_codes
          WHERE ref_num = p_ref_num;

      --
      CURSOR c_dico_sudi (
         p_susg_ref_num  NUMBER
        ,p_dico_ref_num  NUMBER
      ) IS
         SELECT ref_num
           FROM subs_discounts
          WHERE susg_ref_num = p_susg_ref_num AND dico_ref_num = p_dico_ref_num AND cadc_ref_num IS NULL;

      --
      CURSOR c_cadc_sudi (
         p_dico_ref_num  NUMBER
        ,p_cadc_ref_num  NUMBER
        ,p_susg_ref_num  NUMBER
        ,p_sudi_ref_num  NUMBER
      ) IS
         SELECT ref_num
               ,NVL (closed, 'N')   -- th nvl
           FROM subs_discounts
          WHERE susg_ref_num = p_susg_ref_num
            AND dico_ref_num = p_dico_ref_num
            AND cadc_ref_num = p_cadc_ref_num
            AND dico_sudi_ref_num = p_sudi_ref_num;

      --
      CURSOR c_inen_disc (
         p_cadc_bill_sel  VARCHAR2
        ,p_cadc_ref_num   NUMBER
      ) IS
         SELECT ref_num
           FROM invoice_entries
          WHERE invo_ref_num = p_invo.ref_num
            AND susg_ref_num = p_susg_ref_num
            AND billing_selector = p_cadc_bill_sel
            AND cadc_ref_num = p_cadc_ref_num
            AND fcdt_type_code = (SELECT fcdt_type_code
                                    FROM fixed_charge_item_types
                                   WHERE type_code = p_fcit_type_code);

      --
      CURSOR c_disc_call_amounts (
         p_bill_period   NUMBER
        ,p_sudi_ref_num  NUMBER
      ) IS
         SELECT ref_num
           FROM disc_call_amounts
          WHERE susg_ref_num = p_susg_ref_num AND sudi_ref_num = p_sudi_ref_num AND created_bill_period = p_bill_period;

      --
      l_cadc                        call_discount_codes%ROWTYPE;
      l_inen                        invoice_entries%ROWTYPE;
      l_sudi                        subs_discounts%ROWTYPE;
      p_dica                        disc_call_amounts%ROWTYPE;
      l_yn                          VARCHAR2 (1) := 'N';
      l_closed                      VARCHAR2 (1) := 'N';
      l_charge_value                NUMBER := 0;
      ll_charge_value               NUMBER;
      l_disc_duration               NUMBER := 0;
      l_disc_dur_sum                NUMBER := 0;
      l_disc_amount                 NUMBER := 0;
      l_disc_amount_sum             NUMBER := 0;
      l_ref_num                     NUMBER;
      l_number                      NUMBER;
      l_ref_num_c                   NUMBER;
      l_sum                         NUMBER;
      l_days_disc                   NUMBER;
      l_in_month                    NUMBER;
      l_full_duration               NUMBER;
      l_prev_period                 NUMBER;
      l_in_duration                 NUMBER;
      l_prev_duration               NUMBER;
      l_in_count_count              NUMBER;
      l_prev_count_count            NUMBER;
      l_in_count                    NUMBER;
      l_prev_count                  NUMBER;
      l_bill_period                 NUMBER;
      l_duration                    NUMBER;
      l_disc_value                  NUMBER;
      l_disc_am_ref_num             NUMBER;
      l_fcit_type_code              VARCHAR2 (3);
      l_sudi_start                  DATE;
      l_start_date                  DATE;
      l_start_disc                  DATE;
      l_end_date                    DATE;
      l_sudi_start_cont             DATE;
      l_end_disc                    DATE;
      l_end                         DATE;
      l_end_cont                    DATE;
      l_start_cont                  DATE;
      l_full_days                   BOOLEAN := FALSE;
      e_update_count                EXCEPTION;
      e_delete_discount             EXCEPTION;
      e_sudi                        EXCEPTION;
      e_dica                        EXCEPTION;
   --
   BEGIN
      --------------------------------------------------------------------MONMON
      l_bill_period := TO_NUMBER (TO_CHAR (p_start_date, 'YYYYMM'));

      IF TRUNC (p_end_date) - TRUNC (p_start_date) + 1 = p_num_of_days THEN
         l_full_days := FALSE;
      --l_full_days:=true;
      END IF;

      l_disc_dur_sum := p_num_of_days;
      l_disc_amount_sum := p_charge_value;
      l_sudi_start := p_start_date;

      FOR rec_start IN c_start (l_sudi_start) LOOP
         l_start_date := rec_start.sudi_start;

         --DBMS_OUTPUT.Put_Line('leidsin midagi '||to_char(rec_start.sudi_start,'dd.mm.yyyy')||' ref '||to_char(rec_start.cadc_ref_num) );
         IF l_start_date > p_end_date THEN
            EXIT;
         END IF;

         OPEN c_end (l_sudi_start, rec_start.sudi_ref_num);

         FETCH c_end
          INTO l_end;

         CLOSE c_end;

         l_end := LEAST (l_end, p_end_date);
         l_ref_num := rec_start.sudi_ref_num;   --millega dico kirjutatud
         --
         -- kas soodustuse komponent on registreeritud
         l_ref_num_c := NULL;

         OPEN c_cadc_sudi (rec_start.dico_ref_num, rec_start.cadc_ref_num, p_susg_ref_num, l_ref_num);

         FETCH c_cadc_sudi
          INTO l_ref_num_c
              ,l_closed;

         CLOSE c_cadc_sudi;

         --
         IF l_ref_num_c IS NULL THEN   --soodustuse komponenti pole registreeritud, registreeri!
            SELECT sudi_ref_num_s.NEXTVAL
              INTO l_ref_num_c
              FROM SYS.DUAL;

            --registreeri soodustus:
            l_sudi := NULL;
            l_sudi.ref_num := l_ref_num_c;
            l_sudi.susg_ref_num := p_susg_ref_num;
            l_sudi.discount_code := 'KUU';
            l_sudi.connection_exist := 'N';
            l_sudi.date_created := SYSDATE;
            l_sudi.created_by := sec.get_username;
            --l_sudi.eek_amt            := l_disc_amount;----------------------katkemine???
            l_sudi.start_date := p_start_date;
            l_sudi.cadc_ref_num := rec_start.cadc_ref_num;
            l_sudi.dico_ref_num := rec_start.dico_ref_num;
            l_sudi.dico_sudi_ref_num := l_ref_num;
            --
            calculate_discounts.insert_sudi (l_sudi, p_success, p_error_text);

            IF NOT p_success THEN
               RAISE e_sudi;
            END IF;
         END IF;   -- IF l_ref_num_c IS NULL

         --
         OPEN c_cadc (rec_start.cadc_ref_num);
         FETCH c_cadc   INTO l_cadc;
         CLOSE c_cadc;

         --
         IF NVL (l_cadc.bill_sel_sum, 'Y') = 'Y' THEN
            l_fcit_type_code := NULL;
            calculate_discounts.find_amount_dica_fcit (p_susg_ref_num
                                                      ,rec_start.cadc_ref_num
                                                      ,l_ref_num_c
                                                      ,l_fcit_type_code
                                                      ,p_billing_selector
                                                      ,l_bill_period
                                                      ,l_in_month
                                                      ,l_prev_period
                                                      ,l_in_duration
                                                      ,l_prev_duration
                                                      ,NVL (l_cadc.bill_sel_sum, 'Y')
                                                      );
         ELSE   --hhcc
            l_fcit_type_code := p_fcit_type_code;
            calculate_discounts.find_amount_dica (p_susg_ref_num
                                                 ,l_ref_num_c
                                                 ,l_bill_period
                                                 ,l_in_month
                                                 ,l_prev_period
                                                 ,l_in_duration
                                                 ,l_prev_duration
                                                 ,l_in_count
                                                 ,l_prev_count
                                                 ,l_in_count_count
                                                 ,l_prev_count_count
                                                 );
         END IF;

         l_full_duration := 0;

         --
         IF NVL (l_cadc.summary_discount, 'Y') = 'Y' THEN
            l_full_duration := NVL (l_in_duration, 0) + NVL (l_prev_duration, 0);
         ELSE
            l_full_duration := NVL (l_in_duration, 0);
         END IF;

         IF NVL (l_cadc.DURATION, 0) > l_full_duration OR l_cadc.DURATION IS NULL THEN
            IF l_full_days THEN
               l_days_disc := p_num_of_days;
            ELSE
               l_days_disc := NULL;

               IF p_sepv_ref_num IS NULL THEN
                  IF p_sept_type_code IS NOT NULL THEN
                     l_days_disc := calculate_fixed_charges.find_pack_days (rec_start.sudi_start
                                                                           ,l_end
                                                                           ,p_susg_ref_num
                                                                           ,0
                                                                           );
                  ELSE
                     l_days_disc := calculate_fixed_charges.find_num_of_days (rec_start.sudi_start
                                                                             ,l_end
                                                                             ,p_susg_ref_num
                                                                             ,p_sety_ref_num
                                                                             ,0
                                                                             );
                  END IF;
               ELSE   -- p_sepv_ref_num IS NULL
                  calculate_fixed_charges.get_num_of_days (rec_start.sudi_start
                                                          ,l_end
                                                          ,p_susg_ref_num
                                                          ,p_sety_ref_num
                                                          ,p_sepa_ref_num
                                                          ,p_sepv_ref_num
                                                          ,0
                                                          ,l_days_disc
                                                          ,p_success
                                                          );
               END IF;   -- IF p_sepv_ref_num IS NULL THEN
            END IF;   -- IF l_full_days THEN

            --palju aktiivseid päevi soodustuse jaoks ja milline on hind:
            ll_charge_value := (p_charge_value / p_num_of_days) * l_days_disc;

            --
            IF l_cadc.DURATION IS NULL THEN
               l_duration := l_days_disc;
               l_disc_value := ll_charge_value;
            ELSE
               l_duration := LEAST ((l_cadc.DURATION - l_full_duration), l_days_disc);
               l_disc_value := (p_charge_value / p_num_of_days) * l_duration;
            END IF;

            --ei lähe suurema päevade arvuga soodustust arvutama, kui järelejäänud on!
            calculate_discounts.calculate_one_amount (l_duration   --kestus
                                                     ,l_disc_value   --arvutatud hind
                                                     ,l_cadc   --call_discount_codes rida
                                                     ,p_day_num   --MON ja MIN soodustuse miinimumhinna defineerimisek
                                                     ,l_disc_duration   --arvutatud soodustuse kestus
                                                     ,l_disc_amount
                                                     ,rec_start.padi_ref_num --mobet-75
                                                     );   --arvutatud soodustuse summa
            l_disc_amount_sum := l_disc_amount_sum - l_disc_amount;
            l_disc_dur_sum := l_disc_dur_sum - l_disc_duration;

            --
                -- soodustust ei saa rohkem, kui hind on (kuigi see kontroll on nagu tehtud, aga OK)
            IF l_disc_amount_sum <= 0 THEN
               l_disc_amount := GREATEST (LEAST (l_disc_amount + l_disc_amount_sum, l_disc_amount), 0);
            END IF;

            IF l_disc_dur_sum <= 0 THEN
               l_disc_duration := GREATEST (LEAST (l_disc_duration + l_disc_dur_sum, l_disc_duration), 0);
            END IF;

            l_disc_am_ref_num := NULL;

            OPEN c_disc_call_amounts (l_bill_period, l_ref_num_c);

            FETCH c_disc_call_amounts
             INTO l_disc_am_ref_num;

            CLOSE c_disc_call_amounts;

            --
            IF l_disc_am_ref_num IS NULL THEN   --soodustust pole enne seda arvutatud(uus dica)
               p_dica := NULL;
               p_dica.maac_ref_num := p_maac_ref_num;
               p_dica.susg_ref_num := p_susg_ref_num;
               p_dica.discount_type := p_discount_type;
               p_dica.for_fcit_type_code := p_fcit_type_code;
               p_dica.call_type := p_billing_selector;
               p_dica.invo_ref_num := p_invo.ref_num;
               p_dica.cadc_ref_num := rec_start.cadc_ref_num;
               p_dica.sudi_ref_num := l_ref_num_c;
               p_dica.created_bill_period := l_bill_period;   --  th

               IF p_invo.invoice_type = 'INB' THEN
                  p_dica.call_discount := NVL (p_dica.call_discount, 0) + NVL (l_disc_amount, 0);
                  p_dica.min_discount := NVL (p_dica.min_discount, 0) + NVL (l_disc_duration, 0);
               END IF;

               IF p_invo.invoice_type = 'INP' THEN
                  p_dica.sum_inp_disc := NVL (p_dica.call_discount, 0) + NVL (l_disc_amount, 0);
                  p_dica.inp_dur_discount := NVL (p_dica.min_discount, 0) + NVL (l_disc_duration, 0);
               END IF;

               IF p_invo.invoice_type = 'INT' THEN
                  p_dica.sum_interim_disc := NVL (p_dica.sum_interim_disc, 0) + NVL (l_disc_amount, 0);
                  p_dica.interim_disc := NVL (l_disc_amount, 0);
                  p_dica.int_dur_discount := NVL (l_disc_duration, 0);
                  p_dica.sum_int_dur_discount := NVL (p_dica.sum_int_dur_discount, 0) + NVL (l_disc_duration, 0);
               END IF;

               calculate_discounts.insert_dica (p_dica, p_success, p_error_text);

               IF NOT p_success THEN
                  RAISE e_dica;
               END IF;
            ELSE   --soodustust on juba arvutatud update dica
               --      dbms_output.put_line('FIND_MON: update dica '|| l_disc_am_ref_num);
               IF p_invo.invoice_type = 'INB' THEN
                  UPDATE disc_call_amounts
                     SET call_discount = NVL (call_discount, 0) + NVL (l_disc_amount, 0)
                        ,min_discount = NVL (min_discount, 0) + NVL (l_disc_duration, 0)
                        ,invo_ref_num = p_invo.ref_num
                   WHERE ref_num = l_disc_am_ref_num;
               END IF;

               IF p_invo.invoice_type = 'INP' THEN
                  UPDATE disc_call_amounts
                     SET sum_inp_disc = NVL (call_discount, 0) + NVL (l_disc_amount, 0)
                        ,inp_dur_discount = NVL (min_discount, 0) + NVL (l_disc_duration, 0)
                   WHERE ref_num = l_disc_am_ref_num;
               END IF;

               IF p_invo.invoice_type = 'INT' THEN
                  UPDATE disc_call_amounts
                     SET sum_interim_disc = NVL (sum_interim_disc, 0) + NVL (l_disc_amount, 0)
                        ,interim_disc = NVL (l_disc_amount, 0)
                        ,int_dur_discount = NVL (l_disc_duration, 0)
                        ,sum_int_dur_discount = NVL (sum_int_dur_discount, 0) + NVL (l_disc_duration, 0)
                        ,invo_ref_num = p_invo.ref_num
                   WHERE ref_num = l_disc_am_ref_num;
               END IF;
            END IF;   -- IF l_disc_am_ref_num IS NULL THEN
         --
         END IF;   --  IF nvl(l_cadc.duration,0)>l_full_duration OR l_cadc.duration IS NULL THEN
      END LOOP;
   EXCEPTION
      WHEN e_sudi THEN
         p_error_text := 'Insert Sudi: ' || p_error_text;
         p_success := FALSE;
      WHEN e_dica THEN
         p_error_text := 'Insert Dica: ' || p_error_text;
         p_success := FALSE;
      WHEN e_update_count THEN
         p_error_text := 'Update Count: ' || p_error_text;
         p_success := FALSE;
      WHEN OTHERS THEN
         p_error_text := SQLERRM;
         p_success := FALSE;
   END find_mon_discounts;   --monmon

   -----------------------------------------------------------------------------
   -- Leia, kas 00,Conn,Regu soodustust on ja siis: arvuta, kanna arvele, registreeri sudisse.
   -- MOBET-22: vanade parameetritega, et kood jääks kõikjal toimima. Kutsub välja uute parameetritega versiooni.
   PROCEDURE find_oo_conn_discounts (
      p_discount_type               VARCHAR2
     ,p_invo_ref_num                NUMBER
     ,p_fcit_type_code              VARCHAR2
     ,p_billing_selector            VARCHAR2
     ,p_sepv_ref_num                NUMBER
     ,p_sept_type_code              VARCHAR2
     ,p_charge_value                NUMBER
     ,p_susg_ref_num                NUMBER
     ,p_maac_ref_num                NUMBER
     ,p_date                        DATE
     ,p_mode                        VARCHAR2   --'INS';'DEL'
     ,p_error_text          IN OUT  VARCHAR2
     ,p_success             IN OUT  BOOLEAN
     ,p_max_calculated_amt  IN      NUMBER DEFAULT NULL
     ,p_interim             IN      BOOLEAN DEFAULT FALSE   -- CHG-3360
     ,p_mixed_service       IN      VARCHAR2 DEFAULT NULL   -- CHG-5438
   ) IS
      --
      l_discount_exists  BOOLEAN;
      l_disc_amount      NUMBER;
      --
   BEGIN
      --
      find_oo_conn_discounts (p_discount_type       --        VARCHAR2
                             ,p_invo_ref_num        --        NUMBER
                             ,p_fcit_type_code      --        VARCHAR2
                             ,p_billing_selector    --        VARCHAR2
                             ,p_sepv_ref_num        --        NUMBER
                             ,p_sept_type_code      --        VARCHAR2
                             ,p_charge_value        --        NUMBER
                             ,p_susg_ref_num        --        NUMBER
                             ,p_maac_ref_num        --        NUMBER
                             ,p_date                --        DATE
                             ,p_mode                --        VARCHAR2   --'INS';'DEL'
                             ,p_error_text          --IN OUT  VARCHAR2
                             ,p_success             --IN OUT  BOOLEAN
                             ,l_discount_exists     --   OUT  BOOLEAN
                             ,l_disc_amount         --   OUT  NUMBER
                             ,p_max_calculated_amt  --IN      NUMBER DEFAULT NULL
                             ,p_interim             --IN      BOOLEAN DEFAULT FALSE   -- CHG-3360
                             ,p_mixed_service       --IN      VARCHAR2 DEFAULT NULL
                             );
      --
   END find_oo_conn_discounts;
   -----------------------------------------------------------------------------
   -- Leia, kas 00,Conn,Regu soodustust on ja siis: arvuta, kanna arvele, registreeri sudisse.
   -- MOBET-22: Lisatud väljundparameetid: p_discount_exists ja p_disc_amount
   PROCEDURE find_oo_conn_discounts (
      p_discount_type               VARCHAR2
     ,p_invo_ref_num                NUMBER
     ,p_fcit_type_code              VARCHAR2
     ,p_billing_selector            VARCHAR2
     ,p_sepv_ref_num                NUMBER
     ,p_sept_type_code              VARCHAR2
     ,p_charge_value                NUMBER
     ,p_susg_ref_num                NUMBER
     ,p_maac_ref_num                NUMBER
     ,p_date                        DATE
     ,p_mode                        VARCHAR2   --'INS';'DEL'
     ,p_error_text          IN OUT  VARCHAR2
     ,p_success             IN OUT  BOOLEAN
     ,p_discount_exists        OUT  BOOLEAN
     ,p_disc_amount            OUT  NUMBER
     ,p_max_calculated_amt  IN      NUMBER DEFAULT NULL
     ,p_interim             IN      BOOLEAN DEFAULT FALSE   -- CHG-3360
     ,p_mixed_service       IN      VARCHAR2 DEFAULT NULL   -- CHG-5438
   ) IS
      CURSOR c_all_disc IS
         SELECT dico.ref_num
               ,dico.discount_code
           FROM discount_codes dico
          WHERE p_date BETWEEN dico.start_date AND NVL (dico.end_date, p_date)
            AND dico.MANUAL = 'N'
            AND dico.for_all = 'Y';

      --
      CURSOR c_all_cadc (
         p_dico_ref_num  NUMBER
      ) IS
         SELECT *
           FROM call_discount_codes cadc
          WHERE cadc.dico_ref_num = p_dico_ref_num
            AND p_date BETWEEN cadc.start_date AND NVL (cadc.end_date, p_date)
            AND NVL (cadc.discount_completed, 'N') <> 'Y'
            AND cadc.for_billing_selector = p_billing_selector
            AND cadc.for_fcit_type_code = p_fcit_type_code
            AND (cadc.sept_type_code = p_sept_type_code OR cadc.sept_type_code IS NULL)
            AND (cadc.for_sepv_ref_num = p_sepv_ref_num OR cadc.for_sepv_ref_num IS NULL)
            AND cadc.call_type = p_discount_type
            -- CHG-5438
            AND (cadc.mixed_service = 'Y' AND cadc.mixed_service = p_mixed_service OR
                 Nvl(cadc.mixed_service, 'N') = 'N'
                )
      ;

      --
      CURSOR c_fcit_disc IS
         SELECT   *
             FROM call_discount_codes cadc
            WHERE cadc.call_type = p_discount_type
              AND p_date BETWEEN cadc.start_date AND NVL (cadc.end_date, p_date)
              AND NVL (cadc.discount_completed, 'N') <> 'Y'
              AND cadc.for_billing_selector = p_billing_selector
              AND cadc.for_fcit_type_code = p_fcit_type_code
              AND (cadc.sept_type_code = p_sept_type_code OR cadc.sept_type_code IS NULL)
              AND (cadc.for_sepv_ref_num = p_sepv_ref_num OR cadc.for_sepv_ref_num IS NULL)
              AND 'N' = (SELECT dico.for_all
                           FROM discount_codes dico
                          WHERE cadc.dico_ref_num = dico.ref_num)
              AND 0 < (SELECT COUNT (*)
                         FROM subs_discounts sudi
                        WHERE sudi.susg_ref_num = p_susg_ref_num
                          AND sudi.dico_ref_num = cadc.dico_ref_num
                          AND sudi.cadc_ref_num IS NULL
                          AND NVL (sudi.closed, 'N') <> 'Y'
                          AND ( NVL(sudi.end_date,ADD_MONTHS (sudi.start_date, NVL (cadc.count_for_months, 0))
                                  + NVL (cadc.count_for_days, 0)) >= p_date
                               OR (cadc.count_for_days IS NULL AND cadc.count_for_months IS NULL)
                              )
                          AND sudi.start_date + NVL (cadc.from_day, 0) <= p_date
                          AND nvl(SUDI.end_date,p_date) >= p_date  -- mobet-49
                                                                                -- CHG-4079   AND TRUNC (sudi.start_date, 'MM') = TRUNC (p_date, 'MM')
                                                                                -- CHG-4079 OR cadc.next_bill_period = 'Y'
                          AND ((SUDI.padi_ref_num is not null and exists (select 1 from part_dico_details padd 
                                                                          where PADD.PADI_REF_NUM = sudi.padi_ref_num
                                                                          and padd.cadc_ref_num = cadc.ref_num))
                               OR SUDI.padi_ref_num is null) -- mobet-75 
                     )
              -- CHG-5438
              AND (cadc.mixed_service = 'Y' AND cadc.mixed_service = p_mixed_service OR
                   Nvl(cadc.mixed_service, 'N') = 'N'
                  )
                 
         ORDER BY cadc.start_date ASC;

      --
      CURSOR c_dico_sudi (
         p_susg_ref_num  NUMBER
        ,p_dico_ref_num  NUMBER
      ) IS
         SELECT ref_num
               ,start_date
               ,discount_code
               ,padi_ref_num  -- mobet-75
           FROM subs_discounts sudi
          WHERE susg_ref_num = p_susg_ref_num
            AND dico_ref_num = p_dico_ref_num
            AND NVL (closed, 'N') = 'N'
            AND nvl(SUDI.end_date,p_date) >= p_date  --mobet-49
            AND SUDI.start_date <= p_date            --mobet-75
            AND cadc_ref_num IS NULL;

      --
      CURSOR c_cadc_sudi (
         p_dico_ref_num  NUMBER
        ,p_cadc_ref_num  NUMBER
        ,p_susg_ref_num  NUMBER
        ,p_sudi_ref_num  NUMBER
      ) IS
         SELECT ref_num
           FROM subs_discounts
          WHERE susg_ref_num = p_susg_ref_num
            AND dico_ref_num = p_dico_ref_num
            AND cadc_ref_num = p_cadc_ref_num
            AND dico_sudi_ref_num = p_sudi_ref_num;

      --
      CURSOR c_inen_disc (
         p_cadc_bill_sel  VARCHAR2
        ,p_cadc_ref_num   NUMBER
      ) IS
         SELECT ref_num
           FROM invoice_entries
          WHERE invo_ref_num = p_invo_ref_num
            AND susg_ref_num = p_susg_ref_num
            AND billing_selector = p_cadc_bill_sel
            AND cadc_ref_num = p_cadc_ref_num
            AND fcdt_type_code = (SELECT fcdt_type_code
                                    FROM fixed_charge_item_types
                                   WHERE type_code = p_fcit_type_code);

      -- CHG-3360
      CURSOR c_inen_int_disc (
         p_cadc_bill_sel  VARCHAR2
        ,p_cadc_ref_num   NUMBER
      ) IS
         SELECT ref_num
           FROM invoice_entries_interim
          WHERE invo_ref_num = p_invo_ref_num
            AND susg_ref_num = p_susg_ref_num
            AND billing_selector = p_cadc_bill_sel
            AND cadc_ref_num = p_cadc_ref_num
            AND fcdt_type_code = (SELECT fcdt_type_code
                                    FROM fixed_charge_item_types
                                   WHERE type_code = p_fcit_type_code);

      --
      CURSOR c_fcdt (
         p_fcit_type_code  VARCHAR2
      ) IS
         SELECT fcdt_type_code
           FROM fixed_charge_item_types
          WHERE type_code = p_fcit_type_code;

      --
      CURSOR c_inen_sum (
         p_ref_num  NUMBER
      ) IS
         SELECT acc_amount   -- CHG4594
           FROM invoice_entries
          WHERE ref_num = p_ref_num;

      --
      CURSOR c_inen_int_sum (
         p_ref_num  NUMBER
      ) IS
         SELECT eek_amt
           FROM invoice_entries_interim
          WHERE ref_num = p_ref_num;

      --
      CURSOR c_tax (
         p_taty_type_code  VARCHAR2
      ) IS
         SELECT rate_value
           FROM tax_rates
          WHERE taty_type_code = p_taty_type_code AND p_date BETWEEN start_date AND NVL (end_date, p_date);

      --
      CURSOR c_all_disc_sudi (
         p_dico_ref_num  NUMBER
        ,p_susg_ref_num  NUMBER
      ) IS
         SELECT ref_num
           FROM subs_discounts
          WHERE susg_ref_num = p_susg_ref_num AND dico_ref_num = p_dico_ref_num AND cadc_ref_num IS NULL;

      --
      l_inen                        invoice_entries%ROWTYPE;
      l_sudi                        subs_discounts%ROWTYPE;
      l_charge_value                NUMBER := 0;
      l_disc_duration               NUMBER := 0;
      --l_disc_amount                 NUMBER := 0; -- MOBET-22: Asdatud p_disc_amount OUT parameetriga
      l_disc_amount_sum             NUMBER := 0;
      l_discountable_amount         NUMBER;
      l_yn                          VARCHAR2 (1) := 'N';
      l_discount_code               discount_codes.discount_code%TYPE;
      l_ref_num                     NUMBER;
      l_number                      NUMBER;
      l_ref_num_c                   NUMBER;
      l_dico_ref_num                NUMBER;
      l_sum                         NUMBER;
      l_sudi_start_date             DATE;
      l_fcdt_type_code              VARCHAR2 (4);
      l_rate_value                  NUMBER;
      e_update_count                EXCEPTION;
      e_delete_discount             EXCEPTION;
      e_sudi                        EXCEPTION;
      e_inen                        EXCEPTION;
   --
   BEGIN
      --
      p_discount_exists := FALSE;  -- MOBET-22
      p_disc_amount     := 0;      -- MOBET-22
      
      
      --dbms_output.put_line('OO:Find Discounts ');
      OPEN c_fcdt (p_fcit_type_code);

      FETCH c_fcdt
       INTO l_fcdt_type_code;

      CLOSE c_fcdt;

      l_disc_amount_sum := p_charge_value;

      OPEN c_all_disc;

      FETCH c_all_disc
       INTO l_dico_ref_num
           ,l_discount_code;

      CLOSE c_all_disc;

      FOR rec_y IN c_all_cadc (l_dico_ref_num) LOOP
         --
         p_discount_exists := TRUE;  -- MOBET-22
         l_rate_value := 0;

         OPEN c_tax (rec_y.taty_type_code);

         FETCH c_tax
          INTO l_rate_value;

         CLOSE c_tax;

         --  dbms_output.put_line('OO:Soodustuse all komponendi arvutus '||to_char(rec_y.ref_num));
         calculate_one_amount (NULL   --kestus
                              ,p_charge_value   --arvutatud hind
                              ,rec_y   --call_discount_codes rida
                              ,NULL   --MON ja MIN soodustuse miinimumhinna defineerimisek
                              ,l_disc_duration   --arvutatud soodustuse kestus
                              ,p_disc_amount
                              );   --arvutatud soodustuse summa
         --  dbms_output.put_line('OO:ALL Soodustuse  summa: '||to_char(l_disc_amount));
         p_disc_amount := LEAST (p_charge_value, NVL (p_disc_amount, 0));
         l_disc_amount_sum := l_disc_amount_sum - p_disc_amount;

         --  dbms_output.put_line('OO:ALL Soodustuse lõplik summa: '||to_char(l_disc_amount));
         --  dbms_output.put_line('OO:l_disc_amount_sum: '||to_char(l_disc_amount_sum));
         IF l_disc_amount_sum < 0 THEN
            l_disc_amount_sum := p_disc_amount + l_disc_amount_sum;
            --       dbms_output.put_line('OO:Soodustuse keskel1-sum '||to_char(l_disc_amount_sum));
            p_disc_amount := GREATEST (LEAST (l_disc_amount_sum, p_disc_amount), 0);
            l_disc_amount_sum := l_disc_amount_sum - p_disc_amount;
         --        dbms_output.put_line('OO:Soodustuse l_disc_amount_sum 2_1 '||to_char(l_disc_amount_sum));
         END IF;

         -- dbms_output.put_line('OO:ALL Soodustuse lõplik summa: '||to_char(l_disc_amount));
         -- dbms_output.put_line('OO:l_disc_amount_sum: '||to_char(l_disc_amount_sum));
         l_ref_num := NULL;

         OPEN c_all_disc_sudi (l_dico_ref_num, p_susg_ref_num);

         FETCH c_all_disc_sudi
          INTO l_ref_num;

         CLOSE c_all_disc_sudi;

         IF l_ref_num IS NULL THEN   --soodustust pole registreeritud (sisestan)
            --    dbms_output.put_line('OO:Sisestan soodustuse sudi: '||to_char(l_dico_ref_num));
            SELECT sudi_ref_num_s.NEXTVAL
              INTO l_ref_num
              FROM SYS.DUAL;

            l_sudi := NULL;
            l_sudi.ref_num := l_ref_num;
            l_sudi.susg_ref_num := p_susg_ref_num;
            l_sudi.discount_code := l_discount_code;
            l_sudi.connection_exist := 'N';
            l_sudi.date_created := SYSDATE;
            l_sudi.created_by := sec.get_username;
            l_sudi.start_date := p_date;
            l_sudi.dico_ref_num := l_dico_ref_num;
            l_sudi.end_date     := Calculate_Discounts.calculate_sudi_end_date (l_sudi.dico_ref_num, l_sudi.start_date);  -- DOBAS-1315
            --
            insert_sudi (l_sudi, p_success, p_error_text);

            IF NOT p_success THEN
               RAISE e_sudi;
            END IF;

            l_number := discount_count (l_dico_ref_num, 'Y', p_success, p_error_text);

            IF NOT p_success THEN
               RAISE e_update_count;
            END IF;
         END IF;

         l_ref_num_c := NULL;

         --
         OPEN c_cadc_sudi (rec_y.dico_ref_num   -- kas soodustuse komponent on registreeritud
                          ,rec_y.ref_num
                          ,p_susg_ref_num
                          ,l_ref_num
                          );

         FETCH c_cadc_sudi
          INTO l_ref_num_c;

         --CLOSE c_cadc_sudi;        -- th
          --IF l_ref_num_c IS NULL THEN  -- th
         IF c_cadc_sudi%NOTFOUND THEN   -- upr 1991 th
            CLOSE c_cadc_sudi;

            IF p_mode = 'INS' THEN
               --registreeri soodustus:
               l_sudi := NULL;
               l_sudi.susg_ref_num := p_susg_ref_num;
               l_sudi.discount_code := l_discount_code;
               l_sudi.connection_exist := 'N';
               l_sudi.date_created := SYSDATE;
               l_sudi.created_by := sec.get_username;
               l_sudi.eek_amt := p_disc_amount;
               l_sudi.start_date := p_date;
               l_sudi.cadc_ref_num := rec_y.ref_num;
               l_sudi.dico_ref_num := rec_y.dico_ref_num;
               l_sudi.dico_sudi_ref_num := l_ref_num;
               --
               insert_sudi (l_sudi, p_success, p_error_text);

               IF NOT p_success THEN
                  RAISE e_sudi;
               END IF;
            --   dbms_output.put_line('OO:Sisestasin sudi '||to_char(rec_y.ref_num));
            END IF;
         ELSE
            CLOSE c_cadc_sudi;

            --  dbms_output.put_line('OO: Updaten soodustuse sudi ');
            IF p_mode = 'INS' THEN
               UPDATE subs_discounts
                  SET eek_amt = eek_amt + p_disc_amount
                WHERE susg_ref_num = p_susg_ref_num
                  AND dico_ref_num = rec_y.dico_ref_num
                  AND cadc_ref_num = rec_y.ref_num
                  AND dico_sudi_ref_num = l_ref_num;
            ELSE
               UPDATE subs_discounts
                  SET eek_amt = eek_amt - p_disc_amount
                WHERE susg_ref_num = p_susg_ref_num
                  AND dico_ref_num = rec_y.dico_ref_num
                  AND cadc_ref_num = rec_y.ref_num
                  AND dico_sudi_ref_num = l_ref_num;
            END IF;
         END IF;   -- IF c_cadc_sudi%notfound

         --dbms_output.put_line('OO:Hakkan arvele ajama. Eraldi real? '||rec_y.crm);
         --
         IF rec_y.crm = 'Y' THEN   --trükkida arvele eraldi real
            --  dbms_output.put_line('OO:Trükin arvele eraldi real');
            l_ref_num := NULL;

            OPEN c_inen_disc (rec_y.disc_billing_selector, rec_y.ref_num);

            FETCH c_inen_disc
             INTO l_ref_num;

            CLOSE c_inen_disc;

            --  dbms_output.put_line('OO:Arve rea ref'||to_char(l_ref_num));
              --
            IF l_ref_num IS NOT NULL THEN   --arve rida olemas
               --    dbms_output.put_line('OO:tahan updateda entriest - soodustuse rida');
               IF p_mode = 'INS' THEN
                  UPDATE invoice_entries
                     SET acc_amount = ROUND (acc_amount - p_disc_amount, get_inen_acc_precision)   -- CHG4594
                        ,evre_count = evre_count + 1
                        -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) - (l_disc_amount * l_rate_value / 100), 2)
                   WHERE ref_num = l_ref_num;
               ELSE
                  UPDATE invoice_entries
                     SET acc_amount = ROUND (acc_amount + p_disc_amount, get_inen_acc_precision)   -- CHG4594
                        ,evre_count = evre_count - 1
                        -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) + (l_disc_amount * l_rate_value / 100), 2)
                   WHERE ref_num = l_ref_num;

                  --
                  OPEN c_inen_sum (l_ref_num);

                  FETCH c_inen_sum
                   INTO l_sum;

                  CLOSE c_inen_sum;

                  --
                  IF l_sum = 0 THEN
                     DELETE FROM invoice_entries
                           WHERE ref_num = l_ref_num AND eek_amt = 0;
                  END IF;
               END IF;
            ELSE   --arve rida pole olemas
               --   dbms_output.put_line('OO:Arve rida pole olemas');
               IF p_mode = 'INS' THEN
                  IF rec_y.print_required = 'N' AND p_disc_amount = 0 THEN
                     NULL;
                  ELSE
                     --dbms_output.put_line('OO:Sisestan inen');
                     l_inen := NULL;
                     l_inen.susg_ref_num := p_susg_ref_num;
                     l_inen.print_required := 'Y';
                     l_inen.billing_selector := rec_y.disc_billing_selector;
                     l_inen.invo_ref_num := p_invo_ref_num;
                     l_inen.acc_amount := ROUND (-1 * p_disc_amount, get_inen_acc_precision);   -- CHG4594
                     l_inen.taty_type_code := rec_y.taty_type_code;
                     -- CHG-4899: l_inen.amt_tax := ROUND (-1 * l_disc_amount * l_rate_value / 100, 2);
                     l_inen.evre_count := 1;
                     --l_inen.description        := 'OO+CONN soodustus'
                     l_inen.fcdt_type_code := l_fcdt_type_code;
                     l_inen.cadc_ref_num := rec_y.ref_num;
                     l_inen.pri_curr_code := get_pri_curr_code ();
                     insert_inen (l_inen, p_success, p_error_text);

                     IF NOT p_success THEN
                        RAISE e_inen;
                     END IF;
                  --     dbms_output.put_line('OO:inen sisestatud ' || to_char(l_inen.ref_num)
                   --        ||' cadc_ref '||to_char(rec_y.ref_num));
                  END IF;
               END IF;
            END IF;
         ELSE   --soodustus pole arvel eraldi real
            -- dbms_output.put_line('OO:tahan updateda entryt - maksu rida');
            IF p_mode = 'INS' THEN
               UPDATE invoice_entries
                  SET acc_amount = ROUND (acc_amount - p_disc_amount, get_inen_acc_precision)   -- CHG4594
                     -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) - (l_disc_amount * l_rate_value / 100), 2)
                WHERE invo_ref_num = p_invo_ref_num
                  AND susg_ref_num = p_susg_ref_num
                  AND billing_selector = p_billing_selector
                  AND fcit_type_code = p_fcit_type_code;
            ELSE
               UPDATE invoice_entries
                  SET acc_amount = ROUND (acc_amount + p_disc_amount, get_inen_acc_precision)   -- CHG4594
                     -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) + (l_disc_amount * l_rate_value / 100), 2)
                WHERE invo_ref_num = p_invo_ref_num
                  AND susg_ref_num = p_susg_ref_num
                  AND billing_selector = p_billing_selector
                  AND fcit_type_code = p_fcit_type_code;
            END IF;
         END IF;
      END LOOP;

      ----------------------------------------------------------------------------ALL läbi
      --dbms_output.put_line('teine pool');
      --Kõikide vastavat call tüüpi soodustuste kursor:
      FOR rec IN c_fcit_disc LOOP
         -- dbms_output.put_line('loop');
         OPEN c_tax (rec.taty_type_code);

         FETCH c_tax
          INTO l_rate_value;

         CLOSE c_tax;

         --dbms_output.put_line('OO:Soodustuse komponendi arvutus '||to_char(rec.ref_num));
         --
         FOR rec_sudi IN c_dico_sudi (p_susg_ref_num, rec.dico_ref_num) LOOP
            --
            p_discount_exists := TRUE;  -- MOBET-22
            /*
              ** CHG-4079: Leiame summa, mille pealt hakkame soodustust arvutama võttes arvesse
              **    vahearvetele kantud teenuse kuutasusid ning soodustusi.
              **    MinuEMT lahendustasu komponentidel vaadatakse rakendatud vahearvete kuutasusid tabelist
              **    common_monthly_charges, teistel teenustel vaadatakse olemasolevaid invoice_entries kandeid.
            */
            get_discountable_amount (p_date   -- p_period_end            IN   DATE
                                    ,rec_sudi.start_date   -- p_dico_start_date       IN   DATE
                                    ,rec.disc_billing_selector   -- p_disc_billing_selector IN   VARCHAR2
                                    ,rec.ref_num   -- p_cadc_ref_num          IN   NUMBER
                                    ,p_maac_ref_num   -- IN   NUMBER
                                    ,p_susg_ref_num   -- IN   NUMBER
                                    ,p_billing_selector   -- IN   VARCHAR2
                                    ,p_fcit_type_code   -- IN   VARCHAR2
                                    ,p_charge_value   -- p_inen_amount           IN   NUMBER
                                    ,p_max_calculated_amt   -- p_max_amount            IN   NUMBER
                                    ,l_discountable_amount   -- p_discountable_amount   OUT  NUMBER
                                    );
            --dbms_output.put_line('OO:Soodustuse  arvutus sudi'||to_char(rec_sudi.ref_num));--hbh
            calculate_one_amount (NULL   --kestus
                                 ,l_discountable_amount   --p_charge_value
                                 ,rec
                                 ,NULL   --Kuumaksu ja MIN soodustuse miinimumhinna defineerimisek
                                 ,l_disc_duration   --arvutatud soodustuse kestus
                                 ,p_disc_amount
                                 ,rec_sudi.padi_ref_num -- mobet-75
                                 );   --arvutatud soodustuse summa
                                 
            --dbms_output.put_line('OO:Soodustuse arvutatud summa 2 pool'||to_char(l_disc_amount));
            p_disc_amount := LEAST (l_discountable_amount, NVL (p_disc_amount, 0));
            l_disc_amount_sum := l_disc_amount_sum - p_disc_amount;

            --  dbms_output.put_line('OO:Soodustuse  summa 2_1 '||to_char(l_disc_amount));
            --dbms_output.put_line('OO:Soodustuse l_disc_amount_sum 2_1 '||to_char(l_disc_amount_sum));

            --
            IF l_disc_amount_sum < 0 THEN
               l_disc_amount_sum := p_disc_amount + l_disc_amount_sum;
               --      dbms_output.put_line('OO:Soodustuse keskel1-sum '||to_char(l_disc_amount_sum));
               p_disc_amount := GREATEST (LEAST (l_disc_amount_sum, p_disc_amount), 0);
               l_disc_amount_sum := l_disc_amount_sum - p_disc_amount;
            --       dbms_output.put_line('OO:Soodustuse l_disc_amount_sum 2_1 '||to_char(l_disc_amount_sum));
            END IF;

            --dbms_output.put_line('OO:Soodustuse  summa 2 '||to_char(l_disc_amount));
                --dbms_output.put_line('OO:Soodustuse l_disc_amount_sum 2_1 '||to_char(l_disc_amount_sum));
            l_ref_num_c := NULL;

            OPEN c_cadc_sudi (rec.dico_ref_num, rec.ref_num, p_susg_ref_num, rec_sudi.ref_num);

            FETCH c_cadc_sudi
             INTO l_ref_num_c;

            CLOSE c_cadc_sudi;

            l_yn := 'N';

            --
            /*
            and (add_months(sudi.start_date,nvl(cadc.count_for_months,0))+
                               nvl(cadc.count_for_days,0)>=p_date
                               or (cadc.count_for_days is null and cadc.count_for_months is null))
                          and sudi.start_date+nvl(cadc.from_day,0)<=p_date
            */
            --
            IF rec_sudi.start_date IS NOT NULL THEN
               IF (    ADD_MONTHS ((rec_sudi.start_date + NVL (rec.count_for_days, 0)), NVL (rec.count_for_months, 0)) <
                                                                               p_date   --arvutamise lõpp peab olema suurem
                   AND (rec.count_for_days IS NOT NULL OR rec.count_for_months IS NOT NULL)
                  ) THEN
                  l_disc_amount_sum := l_disc_amount_sum + NVL (p_disc_amount, 0);
                  p_disc_amount := 0;
               ELSE
                  l_yn := 'Y';
               END IF;
            ELSE   --kui soodustuse komponent ei vasta kuupäevale, seda üles ka ei tõsteta
               IF rec_sudi.start_date + NVL (rec.from_day, 0) > p_date THEN
                  l_disc_amount_sum := l_disc_amount_sum + NVL (p_disc_amount, 0);
                  p_disc_amount := 0;
               ELSE
                  l_yn := 'Y';
               END IF;
            END IF;

            -- CHG4594: vahearvele OO ja CONN soodustused alati täpsusega 2
            IF p_interim THEN
               p_disc_amount := ROUND (p_disc_amount, 2);
            END IF;

            --
            --dbms_output.put_line('OO:ARVELE summa 2_1 '||to_char(l_disc_amount));
            --dbms_output.put_line('OO:ARVELE l_disc_amount_sum 2_1 '||to_char(l_disc_amount_sum));
            IF l_yn = 'Y' THEN
               IF NOT p_interim THEN   -- CHG-3360: Interim arvete puhul ei tohi muuta SUDI tabelit!
                  --
                  IF l_ref_num_c IS NULL THEN
                     -- dbms_output.put_line('OO:Sisestan soodustuse ');
                     IF p_mode = 'INS' THEN   --registreeri soodustus:
                        l_sudi := NULL;
                        l_sudi.susg_ref_num := p_susg_ref_num;
                        l_sudi.discount_code := rec_sudi.discount_code;
                        l_sudi.connection_exist := 'N';
                        l_sudi.sudi_ref_num := NULL;
                        l_sudi.date_created := SYSDATE;
                        l_sudi.created_by := sec.get_username;
                        l_sudi.eek_amt := p_disc_amount;
                        l_sudi.start_date := p_date;
                        l_sudi.end_date := NULL;
                        l_sudi.cadc_ref_num := rec.ref_num;
                        l_sudi.dico_ref_num := rec.dico_ref_num;
                        l_sudi.dico_sudi_ref_num := rec_sudi.ref_num;
                         --  dbms_output.put_line('OO:Sisestan komp '||to_char(rec_sudi.ref_num));
                        --
                        insert_sudi (l_sudi, p_success, p_error_text);

                        IF NOT p_success THEN
                           RAISE e_sudi;
                        END IF;
                     END IF;
                  ELSE
                     --dbms_output.put_line('OO:Update soodustus ');
                     IF p_mode = 'INS' THEN
                        UPDATE subs_discounts
                           SET eek_amt = eek_amt + p_disc_amount
                         WHERE susg_ref_num = p_susg_ref_num
                           AND dico_ref_num = rec.dico_ref_num
                           AND cadc_ref_num = rec.ref_num
                           AND dico_sudi_ref_num = rec_sudi.ref_num;
                     ELSE
                        UPDATE subs_discounts
                           SET eek_amt = eek_amt - p_disc_amount
                         WHERE susg_ref_num = p_susg_ref_num
                           AND dico_ref_num = rec.dico_ref_num
                           AND cadc_ref_num = rec.ref_num
                           AND dico_sudi_ref_num = rec_sudi.ref_num;
                     END IF;
                  END IF;
               --
               END IF;   -- CHG-3360

               --dbms_output.put_line('OO: Hakkan arvele ajama');-------------------------------------------------ARVE!!!
               IF rec.crm = 'Y' THEN   --trükkida arvele eraldi real
                  --dbms_output.put_line('OO:Trükin arvele eraldi real');
                  l_ref_num := NULL;

                  IF NOT p_interim THEN   -- CHG-3360
                     --
                     OPEN c_inen_disc (rec.disc_billing_selector, rec.ref_num);

                     FETCH c_inen_disc
                      INTO l_ref_num;

                     CLOSE c_inen_disc;

                     -- dbms_output.put_line('OO:Arve rea ref'||to_char(l_ref_num)||' käibem '||to_char(l_rate_value));
                     --
                     IF l_ref_num IS NOT NULL THEN   --arve rida olemas
                        IF p_mode = 'INS' THEN   --lisa soodustus (arvel eraldi real miinusmärgiga!)
                           UPDATE invoice_entries
                              SET acc_amount = ROUND (acc_amount - p_disc_amount, get_inen_acc_precision)   -- CHG4594
                                 ,evre_count = evre_count + 1
                                 -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) - (l_disc_amount * l_rate_value / 100), 2)
                            WHERE ref_num = l_ref_num;
                        --   dbms_output.put_line('OO:uuendan arverida inen_ref: ' || l_ref_num);
                        ELSE   --kustuta saadud soodustus
                           UPDATE invoice_entries
                              SET acc_amount = ROUND (acc_amount + p_disc_amount, get_inen_acc_precision)   -- CHG4594
                                 ,evre_count = evre_count - 1
                                 -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) + (l_disc_amount * l_rate_value / 100), 2)
                            WHERE ref_num = l_ref_num;

                           -- dbms_output.put_line('OO:uuendan arverida inen_ref: ' || l_ref_num);
                             --soodustus arvel miinusmärgiga, suurendamine võib viia 0'i
                           OPEN c_inen_sum (l_ref_num);

                           FETCH c_inen_sum
                            INTO l_sum;

                           CLOSE c_inen_sum;

                           --
                           IF l_sum = 0 THEN
                              --  dbms_output.put_line('OO:kustutan 0-se arverida inen_ref: ' || l_ref_num);
                              DELETE FROM invoice_entries
                                    WHERE ref_num = l_ref_num AND eek_amt = 0;
                           END IF;
                        END IF;
                     ELSE   --arve rida pole olemas
                        --dbms_output.put_line('OO:Arve rida pole olemas');
                        IF p_mode = 'INS' THEN
                           IF NVL (rec.print_required, 'N') = 'N' AND p_disc_amount = 0 THEN
                              NULL;
                           ELSE
                              l_inen := NULL;
                              l_inen.susg_ref_num := p_susg_ref_num;
                              l_inen.print_required := 'Y';
                              l_inen.billing_selector := rec.disc_billing_selector;
                              l_inen.invo_ref_num := p_invo_ref_num;
                              l_inen.acc_amount := ROUND (-1 * p_disc_amount, get_inen_acc_precision);   -- CHG4594
                              l_inen.taty_type_code := rec.taty_type_code;
                              --l_inen.description        := 'OO+CONN soodustus'
                              l_inen.fcdt_type_code := l_fcdt_type_code;
                              l_inen.cadc_ref_num := rec.ref_num;
                              l_inen.evre_count := 1;
                              l_inen.amt_tax := NULL; -- CHG-4899: ROUND (-1 * (l_disc_amount * l_rate_value / 100), 2);
                              l_inen.pri_curr_code := get_pri_curr_code ();
                              insert_inen (l_inen, p_success, p_error_text);

                              IF NOT p_success THEN
                                 RAISE e_inen;
                              END IF;
                           --    dbms_output.put_line('OO:sisestatud uus inen ref '|| l_inen.ref_num);
                           END IF;
                        ELSE
                           RAISE e_delete_discount;   --arve rida pole olemas, kuid soodustus tuleb maha võtta!
                        END IF;
                     END IF;
                  ELSE
                     -- CHG-3360: Invoice_Entries_Interim
                     OPEN c_inen_int_disc (rec.disc_billing_selector, rec.ref_num);

                     FETCH c_inen_int_disc
                      INTO l_ref_num;

                     CLOSE c_inen_int_disc;

                     -- dbms_output.put_line('OO:Arve rea ref'||to_char(l_ref_num)||' käibem '||to_char(l_rate_value));
                     --
                     IF l_ref_num IS NOT NULL THEN   --arve rida olemas
                        IF p_mode = 'INS' THEN   --lisa soodustus (arvel eraldi real miinusmärgiga!)
                           UPDATE invoice_entries_interim
                              SET eek_amt = ROUND (eek_amt - p_disc_amount, 2)
                                 ,evre_count = evre_count + 1
                                 -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) - (l_disc_amount * l_rate_value / 100), 2)
                            WHERE ref_num = l_ref_num;
                        --   dbms_output.put_line('OO:uuendan arverida inen_ref: ' || l_ref_num);
                        ELSE   --kustuta saadud soodustus
                           UPDATE invoice_entries_interim
                              SET eek_amt = ROUND (eek_amt + p_disc_amount, 2)
                                 ,evre_count = evre_count - 1
                                 -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) + (l_disc_amount * l_rate_value / 100), 2)
                            WHERE ref_num = l_ref_num;

                           -- dbms_output.put_line('OO:uuendan arverida inen_ref: ' || l_ref_num);
                             --soodustus arvel miinusmärgiga, suurendamine võib viia 0'i
                           OPEN c_inen_int_sum (l_ref_num);

                           FETCH c_inen_int_sum
                            INTO l_sum;

                           CLOSE c_inen_int_sum;

                           --
                           IF l_sum = 0 THEN
                              --  dbms_output.put_line('OO:kustutan 0-se arverida inen_ref: ' || l_ref_num);
                              DELETE FROM invoice_entries_interim
                                    WHERE ref_num = l_ref_num AND eek_amt = 0;
                           END IF;
                        END IF;
                     ELSE   --arve rida pole olemas
                        --dbms_output.put_line('OO:Arve rida pole olemas');
                        IF p_mode = 'INS' THEN
                           IF NVL (rec.print_required, 'N') = 'N' AND p_disc_amount = 0 THEN
                              NULL;
                           ELSE
                              l_inen := NULL;
                              l_inen.susg_ref_num := p_susg_ref_num;
                              l_inen.print_required := 'Y';
                              l_inen.billing_selector := rec.disc_billing_selector;
                              l_inen.invo_ref_num := p_invo_ref_num;
                              l_inen.acc_amount := ROUND (-1 * p_disc_amount, get_inen_acc_precision);   -- CHG4594
                              l_inen.taty_type_code := rec.taty_type_code;
                              --l_inen.description        := 'OO+CONN soodustus'
                              l_inen.fcdt_type_code := l_fcdt_type_code;
                              l_inen.cadc_ref_num := rec.ref_num;
                              l_inen.evre_count := 1;
                              -- CHG-4899: l_inen.amt_tax := ROUND (-1 * (l_disc_amount * l_rate_value / 100), 2);
                              l_inen.pri_curr_code := get_pri_curr_code ();
                              insert_inen_int (l_inen, p_success, p_error_text);

                              IF NOT p_success THEN
                                 RAISE e_inen;
                              END IF;
                           --    dbms_output.put_line('OO:sisestatud uus inen ref '|| l_inen.ref_num);
                           END IF;
                        ELSE
                           RAISE e_delete_discount;   --arve rida pole olemas, kuid soodustus tuleb maha võtta!
                        END IF;
                     END IF;
                  END IF;
               --
               ELSE   --soodustus pole arvel eraldi real
                  IF p_mode = 'INS' THEN
                     -- dbms_output.put_line('OO:Uuendan inenit INS modes invo_ref:' || p_invo_ref_num || ' susg: '
                     -- || p_susg_ref_num || ' bil_sel: '|| p_billing_selector || ' fcit: '|| p_fcit_type_code);
                     IF NOT p_interim THEN   -- CHG-3360
                        UPDATE invoice_entries
                           SET acc_amount = ROUND (acc_amount - p_disc_amount, get_inen_acc_precision)   -- CHG4594
                              -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) - (l_disc_amount * l_rate_value / 100), 2)
                         WHERE invo_ref_num = p_invo_ref_num
                           AND susg_ref_num = p_susg_ref_num
                           AND billing_selector = p_billing_selector
                           AND fcit_type_code = p_fcit_type_code;
                     ELSE   -- CHG-3360: Interim
                        UPDATE invoice_entries_interim
                           SET eek_amt = ROUND (eek_amt - p_disc_amount, 2)
                              -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) - (l_disc_amount * l_rate_value / 100), 2)
                         WHERE invo_ref_num = p_invo_ref_num
                           AND susg_ref_num = p_susg_ref_num
                           AND billing_selector = p_billing_selector
                           AND fcit_type_code = p_fcit_type_code;
                     END IF;
                  ELSE
                     -- dbms_output.put_line('OO:Uuendan inenit DEL modes invo_ref:' || p_invo_ref_num || ' susg: '||
                     --  p_susg_ref_num || ' bil_sel: '|| p_billing_selector || ' fcit: '|| p_fcit_type_code);
                     IF NOT p_interim THEN   -- CHG-3360
                        UPDATE invoice_entries
                           SET acc_amount = ROUND (acc_amount + p_disc_amount, get_inen_acc_precision)   -- CHG4594
                              -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) + (l_disc_amount * l_rate_value / 100), 2)
                         WHERE invo_ref_num = p_invo_ref_num
                           AND susg_ref_num = p_susg_ref_num
                           AND billing_selector = p_billing_selector
                           AND fcit_type_code = p_fcit_type_code;
                     ELSE   -- CHG-3360: Interim
                        UPDATE invoice_entries_interim
                           SET eek_amt = ROUND (eek_amt + p_disc_amount, 2)
                              -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) + (l_disc_amount * l_rate_value / 100), 2)
                         WHERE invo_ref_num = p_invo_ref_num
                           AND susg_ref_num = p_susg_ref_num
                           AND billing_selector = p_billing_selector
                           AND fcit_type_code = p_fcit_type_code;
                     END IF;
                  END IF;
               END IF;
            END IF;
         END LOOP;
      END LOOP;
   EXCEPTION
      WHEN e_delete_discount THEN
         p_success := FALSE;
      WHEN e_sudi THEN
         p_error_text := 'Insert Sudi: ' || p_error_text;
         p_success := FALSE;
      WHEN e_inen THEN
         p_error_text := 'Insert Inen: ' || p_error_text;
         p_success := FALSE;
      WHEN e_update_count THEN
         p_error_text := 'Update Count: ' || p_error_text;
         p_success := FALSE;
      WHEN OTHERS THEN
         p_error_text := SQLERRM;
         p_success := FALSE;
   END find_oo_conn_discounts;

   --
   FUNCTION find_discount_type (
      p_pro_rata        IN  VARCHAR2
     ,p_regular_charge  IN  VARCHAR2
     ,p_once_off        IN  VARCHAR2
     ,p_daily_charge    IN  VARCHAR2 DEFAULT NULL  -- DOBAS-1622
   )
      RETURN VARCHAR2 IS
      CURSOR c_disc_type IS
         SELECT discount_type
           FROM fixed_charge_types
          WHERE pro_rata = p_pro_rata AND regular_charge = p_regular_charge AND once_off = p_once_off and nvl(daily_charge, 'N') = nvl(p_daily_charge, 'N'); -- DOBAS-1622

      p_discount_type               VARCHAR2 (4) := NULL;
   BEGIN
      OPEN c_disc_type;

      FETCH c_disc_type
       INTO p_discount_type;

      CLOSE c_disc_type;

      RETURN p_discount_type;
   END find_discount_type;

   --
   FUNCTION get_part_maac_data (
      p_maac_ref_num        IN      accounts.ref_num%TYPE
     ,p_chca_type_code      OUT     accounts.chca_type_code%TYPE
     ,p_bicy_cycle_code     OUT     accounts.bicy_cycle_code%TYPE
     ,p_month_of_serv       OUT     accounts.month_of_serv%TYPE
     ,p_party_type          OUT     parties.party_type%TYPE
     ,p_stat_ref_num        OUT     accounts.stat_ref_num%TYPE
     ,p_part_month_of_serv  OUT     parties.month_of_serv%TYPE
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_maac IS
         SELECT maac.chca_type_code
               ,maac.bicy_cycle_code
               ,maac.month_of_serv
               ,DECODE (maac.bicy_cycle_code, 'MN8', 'CMP', part.party_type)
               ,maac.stat_ref_num
               ,part.month_of_serv
           FROM accounts maac, parties part
          WHERE maac.ref_num = p_maac_ref_num AND part.ref_num = maac.part_ref_num;

      l_found                       BOOLEAN;
   BEGIN
      OPEN c_maac;

      FETCH c_maac
       INTO p_chca_type_code
           ,p_bicy_cycle_code
           ,p_month_of_serv
           ,p_party_type
           ,p_stat_ref_num
           ,p_part_month_of_serv;

      l_found := c_maac%FOUND;

      CLOSE c_maac;

      --
      RETURN l_found;
   END get_part_maac_data;

   --
   --
   FUNCTION get_vmct_maac_type (
      p_stat_ref_num    IN      statements.ref_num%TYPE
     ,p_vmct_maac_type  OUT     statements.vmct_maac_type%TYPE
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_vmct IS
         SELECT stat.vmct_maac_type
           FROM statements stat
          WHERE stat.ref_num = p_stat_ref_num;

      --
      l_found                       BOOLEAN;
   BEGIN
      OPEN c_vmct;

      FETCH c_vmct
       INTO p_vmct_maac_type;

      l_found := c_vmct%FOUND;

      CLOSE c_vmct;

      --
      RETURN l_found;
   END get_vmct_maac_type;

   --
   FUNCTION chk_discount_allowed_lists (
      p_dico_ref_num     IN  discount_codes.ref_num%TYPE
     ,p_maac_ref_num     IN  accounts.ref_num%TYPE
     ,p_chca_type_code   IN  accounts.chca_type_code%TYPE
     ,p_bicy_cycle_code  IN  accounts.bicy_cycle_code%TYPE
     ,p_vmct_maac_type   IN  statements.vmct_maac_type%TYPE
     ,p_dealer_party     IN  discount_allowed_list.dealer_party%TYPE
     ,p_region           IN  discount_allowed_list.region%TYPE
     ,p_dealer_office    IN  discount_allowed_list.dealer_office%TYPE
     ,p_channel_type     IN  discount_allowed_list.channel_type%TYPE
     ,p_chk_date         IN  DATE
   )
      RETURN BOOLEAN IS
      CURSOR c_dial IS
         SELECT *
           FROM discount_allowed_list
          WHERE dico_ref_num = p_dico_ref_num
            AND sety_ref_num IS NULL
            AND sepv_ref_num IS NULL
            AND package_category IS NULL
            AND nety_type_code IS NULL
            AND pack_type_code IS NULL;

      --
      l_this_chca_found             BOOLEAN := FALSE;
      l_other_chca_found            BOOLEAN := FALSE;
      l_this_bicy_found             BOOLEAN := FALSE;
      l_other_bicy_found            BOOLEAN := FALSE;
      l_this_vmct_found             BOOLEAN := FALSE;
      l_other_vmct_found            BOOLEAN := FALSE;
      l_this_maac_found             BOOLEAN := FALSE;
      l_other_maac_found            BOOLEAN := FALSE;
      l_this_dealer_found           BOOLEAN := FALSE;
      l_other_dealer_found          BOOLEAN := FALSE;
      l_this_channel_found          BOOLEAN := FALSE;
      l_other_channel_found         BOOLEAN := FALSE;
   BEGIN
      FOR l_dial_rec IN c_dial LOOP
         IF l_dial_rec.chca_type_code IS NOT NULL THEN
            IF     l_dial_rec.chca_type_code = p_chca_type_code
               AND p_chk_date >= l_dial_rec.start_date
               AND p_chk_date <= NVL (l_dial_rec.end_date, p_chk_date) THEN
               l_this_chca_found := TRUE;
            ELSE
               l_other_chca_found := TRUE;
            END IF;
         END IF;

         --
         IF l_dial_rec.bicy_cycle_code IS NOT NULL THEN
            IF     l_dial_rec.bicy_cycle_code = p_bicy_cycle_code
               AND p_chk_date >= l_dial_rec.start_date
               AND p_chk_date <= NVL (l_dial_rec.end_date, p_chk_date) THEN
               l_this_bicy_found := TRUE;
            ELSE
               l_other_bicy_found := TRUE;
            END IF;
         END IF;

         --
         IF l_dial_rec.vmct_maac_type IS NOT NULL THEN
            IF     l_dial_rec.vmct_maac_type = p_vmct_maac_type
               AND p_chk_date >= l_dial_rec.start_date
               AND p_chk_date <= NVL (l_dial_rec.end_date, p_chk_date) THEN
               l_this_vmct_found := TRUE;
            ELSE
               l_other_vmct_found := TRUE;
            END IF;
         END IF;

         --
         IF l_dial_rec.maac_ref_num IS NOT NULL THEN
            IF     l_dial_rec.maac_ref_num = p_maac_ref_num
               AND p_chk_date >= l_dial_rec.start_date
               AND p_chk_date <= NVL (l_dial_rec.end_date, p_chk_date) THEN
               l_this_maac_found := TRUE;
            ELSE
               l_other_maac_found := TRUE;
            END IF;
         END IF;

         --
         IF l_dial_rec.dealer_party IS NOT NULL OR l_dial_rec.region IS NOT NULL OR l_dial_rec.dealer_office IS NOT NULL THEN
            IF     (p_chk_date >= l_dial_rec.start_date AND p_chk_date <= NVL (l_dial_rec.end_date, p_chk_date))
               AND (   l_dial_rec.dealer_party = p_dealer_party
                    OR l_dial_rec.region = p_region
                    OR l_dial_rec.dealer_office = p_dealer_office
                   ) THEN
               l_this_dealer_found := TRUE;
            ELSE
               l_other_dealer_found := TRUE;
            END IF;
         END IF;

         --
         IF l_dial_rec.channel_type IS NOT NULL THEN
            IF     l_dial_rec.channel_type = p_channel_type
               AND p_chk_date >= l_dial_rec.start_date
               AND p_chk_date <= NVL (l_dial_rec.end_date, p_chk_date) THEN
               l_this_channel_found := TRUE;
            ELSE
               l_other_channel_found := TRUE;
            END IF;
         END IF;
      END LOOP;

      --
      IF    (l_other_chca_found = TRUE AND l_this_chca_found = FALSE)
         OR (l_other_bicy_found = TRUE AND l_this_bicy_found = FALSE)
         OR (l_other_vmct_found = TRUE AND l_this_vmct_found = FALSE)
         OR (l_other_maac_found = TRUE AND l_this_maac_found = FALSE)
         OR (l_other_dealer_found = TRUE AND l_this_dealer_found = FALSE)
         OR (l_other_channel_found = TRUE AND l_this_channel_found = FALSE) THEN
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END IF;
   END chk_discount_allowed_lists;

   --
   FUNCTION chk_several_maac (
      p_dico_rec      IN      discount_codes%ROWTYPE
     ,p_maac_ref_num  IN      accounts.ref_num%TYPE
     ,p_count         OUT     NUMBER
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_count_maac IS
         SELECT COUNT (*) + 1
           FROM subs_discounts
          WHERE susg_ref_num IN (SELECT ref_num
                                   FROM subs_serv_groups
                                  WHERE suac_ref_num BETWEEN p_maac_ref_num AND p_maac_ref_num + 999)
            AND dico_ref_num = p_dico_rec.ref_num;

      --
      l_ok                          BOOLEAN;
   BEGIN
      IF NVL (p_dico_rec.several_maac, 0) > 0 THEN
         OPEN c_count_maac;

         FETCH c_count_maac
          INTO p_count;

         CLOSE c_count_maac;

         --
         IF p_count > p_dico_rec.several_maac THEN
            l_ok := FALSE;
         ELSE
            l_ok := TRUE;
         END IF;
      ELSE
         p_count := 0;
         l_ok := TRUE;
      END IF;

      --
      RETURN l_ok;
   END chk_several_maac;

   --
   FUNCTION get_discount_code_rec (
      p_dico_ref_num        IN      discount_codes.ref_num%TYPE
     ,p_date_start          IN      DATE
     ,p_month_of_serv       IN      accounts.month_of_serv%TYPE
     ,p_party_type          IN      parties.party_type%TYPE
     ,p_part_month_of_serv  IN      parties.month_of_serv%TYPE
     ,p_dico_rec            OUT     discount_codes%ROWTYPE
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_dico IS
         SELECT *
           FROM discount_codes dico
          WHERE dico.ref_num = p_dico_ref_num
            AND p_date_start BETWEEN dico.start_date AND NVL (dico.end_date, p_date_start)
            AND dico.MANUAL = 'N'
            AND dico.for_all = 'N'
            AND NVL (dico.allowed_count, NVL (dico.given_count, 0)) >= NVL (dico.given_count, 0)
            AND NVL (dico.mobile_part, 'A') = 'A'
            AND NVL (dico.month_of_serv, NVL (p_month_of_serv, 0)) <= NVL (p_month_of_serv, 0)
            AND NVL (dico.part_month_of_serv, NVL (p_part_month_of_serv, 0)) <= NVL (p_part_month_of_serv, 0)
            AND NVL (dico.party_type, NVL (p_party_type, '*')) = NVL (p_party_type, '*');

      --
      l_found                       BOOLEAN;
   BEGIN
      OPEN c_dico;

      FETCH c_dico
       INTO p_dico_rec;

      l_found := c_dico%FOUND;

      CLOSE c_dico;

      --
      RETURN l_found;
   END get_discount_code_rec;

   --
   FUNCTION chk_apply_discount (
      p_dico_rec         IN  discount_codes%ROWTYPE
     ,p_susg_ref_num     IN  subs_serv_groups.ref_num%TYPE
     ,p_maac_ref_num     IN  accounts.ref_num%TYPE
     ,p_dealer_party     IN  discount_allowed_list.dealer_party%TYPE
     ,p_region           IN  discount_allowed_list.region%TYPE
     ,p_dealer_office    IN  discount_allowed_list.dealer_office%TYPE
     ,p_channel_type     IN  discount_allowed_list.channel_type%TYPE
     ,p_chca_type_code   IN  accounts.chca_type_code%TYPE
     ,p_bicy_cycle_code  IN  accounts.bicy_cycle_code%TYPE
     ,p_date_start       IN  DATE
     ,p_is_new_mobile    IN  BOOLEAN
     ,p_vmct_maac_type   IN  statements.vmct_maac_type%TYPE
     ,p_sept_type_code   IN  serv_package_types.type_code%TYPE DEFAULT NULL
   )
      RETURN BOOLEAN IS
      l_ok                          BOOLEAN;
      l_found                       BOOLEAN;
      l_mob_sudi_count              NUMBER;
      l_maac_sudi_count             NUMBER;
   BEGIN
      /*
        ** Check if discount can be applied for this M/A, dealer etc.
      */
      l_ok := chk_discount_allowed_lists (p_dico_rec.ref_num
                                         ,p_maac_ref_num
                                         ,p_chca_type_code
                                         ,p_bicy_cycle_code
                                         ,p_vmct_maac_type
                                         ,p_dealer_party
                                         ,p_region
                                         ,p_dealer_office
                                         ,p_channel_type
                                         ,TRUNC (p_date_start)
                                         );

      IF l_ok THEN
         /*
           ** Check that number of allowed discounts for (new) mobile is not exceeded.
         */
         l_ok := new_and_several_mob (p_dico_rec, p_susg_ref_num, p_is_new_mobile, l_mob_sudi_count);

         IF l_ok THEN
            /*
              ** Check that number of allowed discounts for Master Account mobiles is not exceeded.
            */
            l_ok := chk_several_maac (p_dico_rec, p_maac_ref_num, l_maac_sudi_count);

            IF l_ok THEN
               l_ok := chk_apply_package (p_dico_rec.ref_num, p_susg_ref_num, p_sept_type_code);
            END IF;
         END IF;
      END IF;

      --
      RETURN l_ok;
   END chk_apply_discount;

   --seda väljakutset pole!!!!!
   PROCEDURE setup_b_discount (
      p_date_start      IN      DATE   --execution_date
     ,p_susg_a_ref_num  IN      NUMBER   --uus klient
     ,p_susg_b_ref_num  IN      NUMBER   --vana klient
     ,p_error_text      IN OUT  VARCHAR2
     ,p_success         IN OUT  BOOLEAN
   ) IS
      CURSOR c_disc (
         p_susg_a_ref_num  NUMBER
      ) IS
         SELECT sudi.ref_num
               ,sudi.dico_ref_num
           FROM subs_discounts sudi
          WHERE sudi.susg_ref_num = p_susg_a_ref_num AND TRUNC (start_date) = TRUNC (p_date_start);

      CURSOR c_setup (
         p_ref_num  NUMBER
      ) IS
         SELECT dico.parent_dico_ref_num
           FROM discount_codes dico
          WHERE dico.ref_num = p_ref_num AND 'B' = (SELECT mobile_part
                                                      FROM discount_codes
                                                     WHERE ref_num = dico.parent_dico_ref_num);

      l_ref_num                     NUMBER;
      l_number                      NUMBER;
      l_sudi                        subs_discounts%ROWTYPE;
      e_update_count                EXCEPTION;
      e_sudi                        EXCEPTION;
   BEGIN
      IF p_susg_b_ref_num IS NOT NULL THEN
         FOR rec IN c_disc (p_susg_a_ref_num) LOOP
            --    dbms_output.put_line(' a soodustus '||to_char(rec.dico_ref_num));
            l_ref_num := NULL;

            OPEN c_setup (rec.dico_ref_num);

            FETCH c_setup
             INTO l_ref_num;

            CLOSE c_setup;

            --    dbms_output.put_line(' a parent soodustus '||to_char(l_ref_num));
                --
            IF l_ref_num IS NOT NULL THEN
               SELECT sudi_ref_num_s.NEXTVAL
                 INTO l_number
                 FROM SYS.DUAL;

               l_sudi.ref_num := l_number;
               l_sudi.susg_ref_num := p_susg_b_ref_num;
               l_sudi.sudi_ref_num := rec.ref_num;
               l_sudi.discount_code := 'B';
               l_sudi.connection_exist := 'N';
               l_sudi.date_created := SYSDATE;
               l_sudi.created_by := sec.get_username;
               l_sudi.start_date := p_date_start;
               l_sudi.dico_ref_num := l_ref_num;
               insert_sudi (l_sudi, p_success, p_error_text);

               IF NOT p_success THEN
                  RAISE e_sudi;
               END IF;

               l_number := NULL;
               l_number := discount_count (rec.ref_num, 'Y', p_success, p_error_text);

               IF NOT p_success THEN
                  RAISE e_update_count;
               END IF;

               ---update parent kah, et mõlemil oleks sudis, millega seotud
               UPDATE subs_discounts
                  SET sudi_ref_num = l_sudi.ref_num
                WHERE ref_num = rec.ref_num;
            END IF;
         END LOOP;
      END IF;
   EXCEPTION
      WHEN e_update_count THEN
         p_success := FALSE;
         p_error_text := 'Update Count: ' || p_error_text;
      WHEN e_sudi THEN
         p_success := FALSE;
         p_error_text := 'Insert Sudi: ' || p_error_text;
      WHEN OTHERS THEN
         p_error_text := SQLERRM;
         p_success := FALSE;
   END setup_b_discount;

   --
   PROCEDURE setup_disc_sety (
      p_date_start     IN      DATE   --execution_date
     ,p_maac_ref_num   IN      NUMBER
     ,p_susg_ref_num   IN      NUMBER
     ,p_sety_ref_num   IN      NUMBER
     ,p_dealer_party   IN      NUMBER
     ,p_region         IN      NUMBER
     ,p_dealer_office  IN      NUMBER
     ,p_channel_type   IN      VARCHAR2
     ,p_is_new_mobile  IN      BOOLEAN
     ,p_error_text     IN OUT  VARCHAR2
     ,p_success        IN OUT  BOOLEAN
     ,p_sede_ref_num   IN      service_details.ref_num%TYPE   -- CHG-1167
   ) IS
      --
      CURSOR c_dial IS
         SELECT DISTINCT dico_ref_num dico_ref_num
                    FROM discount_allowed_list dial
                   WHERE dial.sety_ref_num = p_sety_ref_num
                     AND TRUNC (p_date_start) BETWEEN dial.start_date AND NVL (dial.end_date, p_date_start);

      --
      CURSOR c_dial_sepv (
         p_dico_ref_num  IN  discount_codes.ref_num%TYPE
      ) IS
         SELECT   dial.sepv_ref_num
                 ,sepv.sepa_ref_num
             FROM discount_allowed_list dial, service_param_values sepv
            WHERE dial.sety_ref_num = p_sety_ref_num
              AND dial.dico_ref_num = p_dico_ref_num
              AND dial.sepv_ref_num IS NOT NULL
              AND TRUNC (p_date_start) BETWEEN dial.start_date AND NVL (dial.end_date, p_date_start)
              AND sepv.ref_num = dial.sepv_ref_num
         ORDER BY sepv.sepa_ref_num;

      --
      l_dico_rec                    discount_codes%ROWTYPE;
      l_ok                          BOOLEAN;
      l_found                       BOOLEAN;
      l_dico_found                  BOOLEAN;
      l_vmct_searched               BOOLEAN := FALSE;
      l_chca_type_code              accounts.chca_type_code%TYPE;
      l_bicy_cycle_code             accounts.bicy_cycle_code%TYPE;
      l_month_of_serv               accounts.month_of_serv%TYPE;
      l_party_type                  parties.party_type%TYPE;
      l_stat_ref_num                accounts.stat_ref_num%TYPE;
      l_part_month_of_serv          parties.month_of_serv%TYPE;
      l_vmct_maac_type              statements.vmct_maac_type%TYPE;
      l_number                      NUMBER;
      l_sudi                        subs_discounts%ROWTYPE;
      l_last_sepa_ref_num           service_parameters.ref_num%TYPE;   -- CHG-1167
      l_sepa_ok                     BOOLEAN;   -- CHG-1167
      l_sedp_rec                    service_detail_parameters%ROWTYPE;   -- CHG-1167
      --
      e_update_count                EXCEPTION;
      e_sudi                        EXCEPTION;
      e_dico_not_applicable         EXCEPTION;   -- CHG-1167
   BEGIN
      FOR l_dial_rec IN c_dial LOOP
         BEGIN
            --    dbms_output.put_line('DIAL found for DICO ref=' || to_char(l_dial_rec.dico_ref_num));
            IF c_dial%ROWCOUNT = 1 THEN
               l_found := get_part_maac_data (p_maac_ref_num
                                             ,l_chca_type_code
                                             ,l_bicy_cycle_code
                                             ,l_month_of_serv
                                             ,l_party_type
                                             ,l_stat_ref_num
                                             ,l_part_month_of_serv
                                             );
            --      dbms_output.put_line('CHCA ' || l_chca_type_code ||
            --                            ', BICY ' || l_bicy_cycle_code ||
            --                           ', month of service ' || to_char(l_month_of_serv) ||
            --                           ', party type ' || l_party_type);
            END IF;

            /*
              ** CHG-1167: Kontrollitakse, kas lisaks teenusele on antud kitsendus ka mingi(te) parameetri väärtus(t)e alusel.
            */
            l_sepa_ok := NULL;
            l_last_sepa_ref_num := NULL;
            l_sedp_rec := NULL;

            --
            FOR l_dial_sepv IN c_dial_sepv (l_dial_rec.dico_ref_num) LOOP
               IF l_dial_sepv.sepa_ref_num <> NVL (l_last_sepa_ref_num, -1) THEN
                  IF l_sepa_ok = FALSE THEN
                     /*
                       ** Eelmise parameetri sobiv väärtus puudus. Soodustust ei saa rakendada.
                     */
                     RAISE e_dico_not_applicable;
                  END IF;

                  --
                  l_sepa_ok := FALSE;
                  /*
                    ** Leitakse vastava parameetri väärtus jooksva orderi pealt.
                  */
                  l_found :=
                     or_common.get_sedp_rec_by_sepa_ref
                                            (p_sede_ref_num   -- IN  service_detail_parameters.sede_ref_num%TYPE
                                            ,l_dial_sepv.sepa_ref_num   -- IN  service_detail_parameters.sepa_ref_num%TYPE
                                            ,l_sedp_rec   -- OUT service_detail_parameters%ROWTYPE
                                            );
               END IF;

               --
               IF     l_dial_sepv.sepv_ref_num = l_sedp_rec.sepv_ref_num
                  AND NVL (l_sedp_rec.parameter_value, '!') <> NVL (l_sedp_rec.old_value, '?')   -- CHG-4461
                                                                                              THEN
                  l_sepa_ok := TRUE;
               END IF;

               --
               l_last_sepa_ref_num := l_dial_sepv.sepa_ref_num;
            END LOOP;

            --
            IF l_sepa_ok = FALSE THEN
               /*
                 ** Viimase parameetri sobiv väärtus puudus. Soodustust ei saa rakendada.
               */
               RAISE e_dico_not_applicable;
            END IF;

            /* End CHG-1167 */
            /*
              ** Perform the first check on discount here (if this is applicable at all).
            */
            l_dico_found := get_discount_code_rec (l_dial_rec.dico_ref_num
                                                  ,p_date_start
                                                  ,l_month_of_serv
                                                  ,l_party_type
                                                  ,l_part_month_of_serv
                                                  ,l_dico_rec
                                                  );

            IF l_dico_found THEN
               --     dbms_output.put_line('Discount code found OK');
               IF NOT l_vmct_searched THEN
                  l_found := get_vmct_maac_type (l_stat_ref_num, l_vmct_maac_type);
                  --         dbms_output.put_line('VMCT ' || l_vmct_maac_type);
                  l_vmct_searched := TRUE;
               END IF;

               --
               l_ok := chk_apply_discount (l_dico_rec
                                          ,p_susg_ref_num
                                          ,p_maac_ref_num
                                          ,p_dealer_party
                                          ,p_region
                                          ,p_dealer_office
                                          ,p_channel_type
                                          ,l_chca_type_code
                                          ,l_bicy_cycle_code
                                          ,TRUNC (p_date_start)
                                          ,p_is_new_mobile
                                          ,l_vmct_maac_type
                                          );

               IF l_ok THEN
                  --        dbms_output.put_line('OK to apply discount ref=' || to_char(l_dico_rec.ref_num));
                  --registreeri soodustus:
                  l_sudi.ref_num := NULL;
                  l_sudi.susg_ref_num := p_susg_ref_num;
                  l_sudi.discount_code := l_dico_rec.discount_code;
                  l_sudi.connection_exist := 'N';
                  l_sudi.date_created := SYSDATE;
                  l_sudi.created_by := sec.get_username;
                  l_sudi.start_date := p_date_start;
                  l_sudi.dico_ref_num := l_dico_rec.ref_num;
                  l_sudi.end_date     := Calculate_Discounts.calculate_sudi_end_date (l_sudi.dico_ref_num, l_sudi.start_date); --DOBAS-1315

                  --
                  insert_sudi (l_sudi, p_success, p_error_text);
                  --
                  l_number := discount_count (l_dico_rec.ref_num, 'Y', p_success, p_error_text);

                  --
                  IF NOT p_success THEN
                     RAISE e_update_count;
                  END IF;
               END IF;
            END IF;
         EXCEPTION
            WHEN e_dico_not_applicable THEN
               NULL;
         END;
      END LOOP;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_update_count THEN
         p_success := FALSE;
         p_error_text := 'Update Count discount code ref=' || TO_CHAR (l_dico_rec.ref_num) || ': ' || p_error_text;
      WHEN e_sudi THEN
         p_success := FALSE;
         p_error_text := 'Insert Sudi: ' || p_error_text;
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
   END setup_disc_sety;

   --
   PROCEDURE setup_disc_master_sety (
      p_date_start       IN  DATE   -- order date
     ,p_maac_ref_num     IN  NUMBER
     ,p_maas_ref_num     IN  master_account_services.ref_num%TYPE
     ,p_maas_start_date  IN  DATE
     ,p_sety_ref_num     IN  NUMBER
     ,p_dealer_party     IN  NUMBER
     ,p_region           IN  NUMBER
     ,p_dealer_office    IN  NUMBER
     ,p_channel_type     IN  VARCHAR2
     ,p_sude_rec         IN  subscriber_details%ROWTYPE  -- SFILES-229
   ) IS
      --
      CURSOR c_dial IS
         SELECT DISTINCT dico_ref_num dico_ref_num
         FROM discount_allowed_list dial
         WHERE dial.sety_ref_num = p_sety_ref_num
           AND TRUNC (p_date_start) BETWEEN dial.start_date AND NVL (dial.end_date, p_date_start)
      ;
      --
      CURSOR c_cadc (p_dico_ref_num  IN  discount_codes.ref_num%TYPE) IS
         SELECT *
         FROM call_discount_codes
         WHERE dico_ref_num = p_dico_ref_num 
           AND call_type in (c_discount_type_regular,c_discount_type_mon)
      ;
      -- SFILES-229
      CURSOR c_dico IS
         SELECT ref_num
         FROM discount_codes
         WHERE discount_code = p_sude_rec.discount_code
           AND Trunc(p_date_start) BETWEEN start_date AND Nvl(end_date, Trunc(p_date_start))
      ;
      --  SFILES-229
      CURSOR c_cadc_by_sety (p_dico_ref_num  IN  discount_codes.ref_num%TYPE) IS
         SELECT *
         FROM call_discount_codes
         WHERE dico_ref_num = p_dico_ref_num 
           AND for_sety_ref_num = p_sety_ref_num
           AND Trunc(p_date_start) BETWEEN start_date AND Nvl(end_date, Trunc(p_date_start))
      ;
      -- MOBET-7
      CURSOR c_is_multisim_sety IS
         SELECT 1
         FROM service_types
         WHERE ref_num = p_sety_ref_num
           AND station_param = Or_Common.c_sety_station_multisim
      ;
      --
      l_dico_rec                    discount_codes%ROWTYPE;
      l_cadc_rec                    call_discount_codes%ROWTYPE;
      l_masa_rec                    master_service_adjustments%ROWTYPE;
      l_chk_masa_rec                master_service_adjustments%ROWTYPE;
      l_ok                          BOOLEAN;
      l_found                       BOOLEAN;
      l_dico_found                  BOOLEAN;
      l_vmct_searched               BOOLEAN := FALSE;
      l_chca_type_code              accounts.chca_type_code%TYPE;
      l_bicy_cycle_code             accounts.bicy_cycle_code%TYPE;
      l_month_of_serv               accounts.month_of_serv%TYPE;
      l_party_type                  parties.party_type%TYPE;
      l_stat_ref_num                accounts.stat_ref_num%TYPE;
      l_part_month_of_serv          parties.month_of_serv%TYPE;
      l_vmct_maac_type              statements.vmct_maac_type%TYPE;
      l_dico_ref_num                discount_codes.ref_num%TYPE;  -- SFILES-229
      l_dummy                       NUMBER;   -- MOBET-7
      l_is_multisim_sety            BOOLEAN;  -- MOBET-7
      l_exists                      BOOLEAN;
   BEGIN
      -- MOBET-7: Kas teenuse station_param = MULTISIM
      OPEN  c_is_multisim_sety;
      FETCH c_is_multisim_sety INTO l_dummy;
      l_is_multisim_sety := c_is_multisim_sety%FOUND;
      CLOSE c_is_multisim_sety;
      
      --
      IF p_sude_rec.discount_code IS NOT NULL THEN
         /*
           ** SFILES-229: MON discount - SuhtlusPilv
         */
         
         -- Leida dico_ref_num
         OPEN  c_dico;
         FETCH c_dico INTO l_dico_ref_num;
         CLOSE c_dico;
         
         -- Leida cadc kirje
         OPEN  c_cadc_by_sety (l_dico_ref_num);
         FETCH c_cadc_by_sety INTO l_cadc_rec;
         CLOSE c_cadc_by_sety;
         
         --
         IF l_cadc_rec.ref_num IS NOT NULL THEN
            /*
              ** Defineerida soodustus tabelis MASTER_SERVICE_ADJUSTMENTS  MASA.
              ** Kontrollida, et poleks teenusele juba registreeritud kehtivat lisatavat  soodustust
              ** Kui on olemas, siis jääb soodustus lisamata.
            */
            l_masa_rec.ref_num           := NULL;
            l_masa_rec.maac_ref_num      := p_maac_ref_num;
            l_masa_rec.maas_ref_num      := p_maas_ref_num;
            l_masa_rec.sety_ref_num      := p_sety_ref_num;            
            l_masa_rec.dico_ref_num      := l_cadc_rec.dico_ref_num;            
            l_masa_rec.created_module    := g_module_ref;
            l_masa_rec.start_date        := GREATEST (p_maas_start_date, NVL (l_cadc_rec.start_date, p_date_start));
            -- MOBET-7
            IF l_is_multisim_sety THEN
               --
               l_masa_rec.fcit_charge_code  := NULL;
               l_masa_rec.billing_selector  := NULL;
               l_masa_rec.credit_rate_value := NULL;
               l_masa_rec.charge_value      := NULL;
               l_masa_rec.cadc_ref_num      := NULL;
               --
            ELSE
               --
               l_masa_rec.fcit_charge_code  := l_cadc_rec.for_fcit_type_code;
               l_masa_rec.billing_selector  := l_cadc_rec.for_billing_selector;
               l_masa_rec.credit_rate_value := l_cadc_rec.precentage;
               l_masa_rec.charge_value      := l_cadc_rec.minimum_price;
               l_masa_rec.cadc_ref_num      := l_cadc_rec.ref_num;
               --
            END IF;

            --
            IF l_cadc_rec.count_for_days IS NOT NULL THEN
               l_masa_rec.end_date := l_masa_rec.start_date + l_cadc_rec.count_for_days;
            ELSIF l_cadc_rec.end_date IS NOT NULL THEN
               l_masa_rec.end_date := l_cadc_rec.end_date;
            ELSIF l_cadc_rec.count_for_months IS NOT NULL THEN
               --MOBET-7 09.01.17
               IF l_is_multisim_sety THEN
                   l_masa_rec.end_date := Trunc(ADD_MONTHS(l_masa_rec.start_date, l_cadc_rec.count_for_months + 1),'MM') - Or_Common.g_one_second;
               ELSE 
                   l_masa_rec.end_date := ADD_MONTHS (l_masa_rec.start_date, l_cadc_rec.count_for_months);
               END IF;
               
            END IF;
            --
            l_chk_masa_rec := l_masa_rec;
            /*
              ** Kontrollime kehtiva soodustuse kombinatsiooni olemasolu.
            */
            l_exists := bccp683sb.masa_period_overlaps (l_chk_masa_rec);
            --
            IF NOT l_exists THEN
               bccp683sb.ins_masa (l_masa_rec);
            END IF;
            --
         END IF;
         --
      ELSE
         --
         FOR l_dial_rec IN c_dial LOOP
            --    dbms_output.put_line('DIAL found for DICO ref=' || to_char(l_dial_rec.dico_ref_num));
            /*
              ** For Master Account Service discounts check here if Call Discount with type REGU exists at all.
              ** If not then nothing to do with this discount type.
            */
            OPEN c_cadc (l_dial_rec.dico_ref_num);
            FETCH c_cadc INTO l_cadc_rec;
            l_found := c_cadc%FOUND;
            CLOSE c_cadc;

            --
            IF l_found THEN
               IF l_chca_type_code IS NULL THEN
                  l_found := get_part_maac_data (p_maac_ref_num
                                                ,l_chca_type_code
                                                ,l_bicy_cycle_code
                                                ,l_month_of_serv
                                                ,l_party_type
                                                ,l_stat_ref_num
                                                ,l_part_month_of_serv
                                                );
                  --      dbms_output.put_line('CHCA ' || l_chca_type_code ||
                  --                           ', BICY ' || l_bicy_cycle_code ||
                  --                           ', month of service ' || to_char(l_month_of_serv) ||
                  --                           ', party type ' || l_party_type);
               END IF;

               /*
                 ** Perform the first check on discount here (if this is applicable at all).
               */
               l_dico_found := get_discount_code_rec (l_dial_rec.dico_ref_num
                                                     ,p_date_start
                                                     ,l_month_of_serv
                                                     ,l_party_type
                                                     ,l_part_month_of_serv
                                                     ,l_dico_rec
                                                     );

               IF l_dico_found THEN
                  --     dbms_output.put_line('Discount code found OK');
                  IF l_stat_ref_num IS NOT NULL THEN
                     IF NOT l_vmct_searched THEN
                        l_found := get_vmct_maac_type (l_stat_ref_num, l_vmct_maac_type);
                        --         dbms_output.put_line('VMCT ' || l_vmct_maac_type);
                        l_vmct_searched := TRUE;
                     END IF;
                  END IF;

                  --
                  l_ok := chk_discount_allowed_lists (l_dico_rec.ref_num   -- IN discount_codes.ref_num%TYPE
                                                     ,p_maac_ref_num   -- IN accounts.ref_num%TYPE
                                                     ,l_chca_type_code   -- IN accounts.chca_type_code%TYPE
                                                     ,l_bicy_cycle_code   -- IN accounts.bicy_cycle_code%TYPE
                                                     ,l_vmct_maac_type   -- IN statements.vmct_maac_type%TYPE
                                                     ,p_dealer_party   -- IN discount_allowed_list.dealer_party%TYPE
                                                     ,p_region   -- IN discount_allowed_list.region%TYPE
                                                     ,p_dealer_office   -- IN discount_allowed_list.dealer_office%TYPE
                                                     ,p_channel_type   -- IN discount_allowed_list.channel_type%TYPE
                                                     ,TRUNC (p_date_start)   -- p_chk_date        IN DATE) RETURN BOOLEAN IS
                                                     );

                  IF l_ok THEN
                     --        dbms_output.put_line('OK to apply discount ref=' || to_char(l_dico_rec.ref_num));
                     --registreeri soodustus:
                     /*
                       ** Defineerida soodustus tabelis MASTER_SERVICE_ADJUSTMENTS  MASA.
                       ** Kontrollida, et poleks teenusele juba registreeritud kehtivat lisatava REGU soodustuse
                       ** kombinatsiooniga BISE + FCIT  soodustust, pole oluline, kas Dico_ref_num ja Cadc_ref_num
                       ** on väärtustatud või mitte. Kui on olemas, siis jääb REGU lisamata.
                     */
                     l_masa_rec.ref_num := NULL;
                     l_masa_rec.maac_ref_num := p_maac_ref_num;
                     l_masa_rec.maas_ref_num := p_maas_ref_num;
                     l_masa_rec.sety_ref_num := p_sety_ref_num;
                     l_masa_rec.dico_ref_num := l_cadc_rec.dico_ref_num;
                     l_masa_rec.created_module := g_module_ref;
                     l_masa_rec.start_date := GREATEST (p_maas_start_date, NVL (l_cadc_rec.start_date, p_date_start));
                     -- MOBET-7
                     IF l_is_multisim_sety THEN
                        --
                        l_masa_rec.fcit_charge_code  := NULL;
                        l_masa_rec.billing_selector  := NULL;
                        l_masa_rec.credit_rate_value := NULL;
                        l_masa_rec.charge_value      := NULL;
                        l_masa_rec.cadc_ref_num      := NULL;
                        --
                     ELSE
                        --
                        l_masa_rec.fcit_charge_code  := l_cadc_rec.for_fcit_type_code;
                        l_masa_rec.billing_selector  := l_cadc_rec.for_billing_selector;
                        l_masa_rec.credit_rate_value := l_cadc_rec.precentage;
                        l_masa_rec.charge_value      := l_cadc_rec.minimum_price;
                        l_masa_rec.cadc_ref_num      := l_cadc_rec.ref_num;
                        --
                     END IF;

                     --
                     IF l_cadc_rec.end_date IS NOT NULL THEN
                        l_masa_rec.end_date := l_cadc_rec.end_date;
                     ELSIF l_cadc_rec.count_for_months IS NOT NULL THEN
                        --MOBET-7 09.01.17
                        IF l_is_multisim_sety THEN
                           l_masa_rec.end_date := Trunc(ADD_MONTHS(l_masa_rec.start_date, l_cadc_rec.count_for_months + 1),'MM') - Or_Common.g_one_second;
                        ELSE 
                           l_masa_rec.end_date := ADD_MONTHS (l_masa_rec.start_date, l_cadc_rec.count_for_months);
                        END IF;

                     END IF;

                     --
                     l_chk_masa_rec := l_masa_rec;
                     /*
                       ** Kontrollime kehtiva soodustuse kombinatsiooni olemasolu.
                     */
                     l_exists := bccp683sb.masa_period_overlaps (l_chk_masa_rec);

                     --
                     IF NOT l_exists THEN
                        bccp683sb.ins_masa (l_masa_rec);
                     END IF;
                  END IF;   -- Discount Allowed List OK
               END IF;   -- Discount Code found
            END IF;   -- Call Discount Code found
         END LOOP;
         --
      END IF;  -- SFILES-229
   END setup_disc_master_sety;

   --
   PROCEDURE setup_disc_package (
      p_date_start        IN      DATE   --execution_date
     ,p_maac_ref_num      IN      NUMBER
     ,p_susg_ref_num      IN      NUMBER
     ,p_pack_type_code    IN      VARCHAR2
     ,p_dealer_party      IN      NUMBER
     ,p_region            IN      NUMBER
     ,p_dealer_office     IN      NUMBER
     ,p_channel_type      IN      VARCHAR2
     ,p_is_new_mobile     IN      BOOLEAN
     ,p_error_text        IN OUT  VARCHAR2
     ,p_success           IN OUT  BOOLEAN
     ,p_package_category  IN      VARCHAR2 DEFAULT NULL
     ,p_nety_type_code    IN      VARCHAR2 DEFAULT NULL
   ) IS
      --
      CURSOR c_category IS
         SELECT CATEGORY
               ,nety_type_code
           FROM serv_package_types
          WHERE type_code = p_pack_type_code;

      --
      CURSOR c_prev_category IS
         SELECT CATEGORY
               ,nety_type_code
           FROM serv_package_types
          WHERE type_code = (SELECT sp1.sept_type_code
                               FROM subs_packages sp1
                              WHERE sp1.gsm_susg_ref_num = p_susg_ref_num
                                AND sp1.end_date = (SELECT MAX (sp2.end_date)
                                                      FROM subs_packages sp2
                                                     WHERE sp2.gsm_susg_ref_num = p_susg_ref_num
                                                       AND sp2.end_date IS NOT NULL));

      --
      CURSOR c_dial_cat (
         p_package_category  IN  VARCHAR2
        ,p_nety_type_code    IN  VARCHAR2
      ) IS
         SELECT DISTINCT dico_ref_num dico_ref_num
                    FROM discount_allowed_list dial
                   WHERE (dial.package_category = p_package_category AND dial.nety_type_code = p_nety_type_code)
                     AND TRUNC (p_date_start) BETWEEN dial.start_date AND NVL (dial.end_date, p_date_start);

      --
      CURSOR c_dial_pack IS
         SELECT DISTINCT dico_ref_num dico_ref_num
                    FROM discount_allowed_list dial
                   WHERE (dial.pack_type_code = p_pack_type_code)
                     AND TRUNC (p_date_start) BETWEEN dial.start_date AND NVL (dial.end_date, p_date_start);

      --
      l_dico_rec                    discount_codes%ROWTYPE;
      l_ok                          BOOLEAN;
      l_found                       BOOLEAN;
      l_dico_found                  BOOLEAN;
      l_vmct_searched               BOOLEAN := FALSE;
      l_chca_type_code              accounts.chca_type_code%TYPE;
      l_bicy_cycle_code             accounts.bicy_cycle_code%TYPE;
      l_month_of_serv               accounts.month_of_serv%TYPE;
      l_party_type                  parties.party_type%TYPE;
      l_stat_ref_num                accounts.stat_ref_num%TYPE;
      l_part_month_of_serv          parties.month_of_serv%TYPE;
      l_vmct_maac_type              statements.vmct_maac_type%TYPE;
      l_number                      NUMBER;
      l_sudi                        subs_discounts%ROWTYPE;
      l_package_category            VARCHAR2 (1);
      l_nety_type_code              VARCHAR2 (3);
      l_prev_package_category       VARCHAR2 (1);
      l_prev_nety_type_code         VARCHAR2 (3);
      --
      e_update_count                EXCEPTION;
      e_sudi                        EXCEPTION;
   BEGIN
      -- tõsta üles soodustus, mis antakse paketiga liitumisel:
      FOR l_dial_rec IN c_dial_pack LOOP
         IF c_dial_pack%ROWCOUNT = 1 THEN
            l_found := get_part_maac_data (p_maac_ref_num
                                          ,l_chca_type_code
                                          ,l_bicy_cycle_code
                                          ,l_month_of_serv
                                          ,l_party_type
                                          ,l_stat_ref_num
                                          ,l_part_month_of_serv
                                          );
         /*   dbms_output.put_line('CHCA ' || l_chca_type_code ||
                                 ', BICY ' || l_bicy_cycle_code ||
                                 ', month of service ' || to_char(l_month_of_serv) ||
                                 ', party type ' || l_party_type); */
         END IF;

         /*
           ** Perform the first check on discount here (if this is applicable at all).
         */
         l_dico_found := get_discount_code_rec (l_dial_rec.dico_ref_num
                                               ,p_date_start
                                               ,l_month_of_serv
                                               ,l_party_type
                                               ,l_part_month_of_serv
                                               ,l_dico_rec
                                               );

         IF l_dico_found THEN
            --     dbms_output.put_line('Discount code found OK');
            IF NOT l_vmct_searched THEN
               l_found := get_vmct_maac_type (l_stat_ref_num, l_vmct_maac_type);
               --       dbms_output.put_line('VMCT ' || l_vmct_maac_type);
               l_vmct_searched := TRUE;
            END IF;

            --
            l_ok := chk_apply_discount (l_dico_rec
                                       ,p_susg_ref_num
                                       ,p_maac_ref_num
                                       ,p_dealer_party
                                       ,p_region
                                       ,p_dealer_office
                                       ,p_channel_type
                                       ,l_chca_type_code
                                       ,l_bicy_cycle_code
                                       ,TRUNC (p_date_start)
                                       ,p_is_new_mobile
                                       ,l_vmct_maac_type
                                       );

            IF l_ok THEN
               --    dbms_output.put_line('OK to apply discount ref=' || to_char(l_dico_rec.ref_num));
               --registreeri soodustus:
               l_sudi.ref_num := NULL;
               l_sudi.susg_ref_num := p_susg_ref_num;
               l_sudi.discount_code := l_dico_rec.discount_code;
               l_sudi.connection_exist := 'N';
               l_sudi.date_created := SYSDATE;
               l_sudi.created_by := sec.get_username;
               l_sudi.start_date := p_date_start;
               l_sudi.dico_ref_num := l_dico_rec.ref_num;
               l_sudi.end_date     := Calculate_Discounts.calculate_sudi_end_date (l_sudi.dico_ref_num, l_sudi.start_date); --DOBAS-1315
               --
               insert_sudi (l_sudi, p_success, p_error_text);

               --
               IF NOT p_success THEN
                  RAISE e_sudi;
               END IF;

               --
               l_number := discount_count (l_dico_rec.ref_num, 'Y', p_success, p_error_text);

               --
               IF NOT p_success THEN
                  RAISE e_update_count;
               END IF;
            END IF;
         END IF;
      END LOOP;

      -- lõppes soodustus, mis antakse paketiga liitumisel

      -- algab soodustus, mis antakse paketikategooriasse minekul:
      -- kui eelnev paketikategooria on sama, mis uus, siis soodustust ei saa
      IF p_package_category IS NOT NULL AND p_nety_type_code IS NOT NULL THEN
         l_package_category := p_package_category;
         l_nety_type_code := p_nety_type_code;
      ELSE
         OPEN c_category;

         FETCH c_category
          INTO l_package_category
              ,l_nety_type_code;

         CLOSE c_category;
      END IF;

      --
      FOR l_dial_rec IN c_dial_cat (l_package_category, l_nety_type_code) LOOP
         OPEN c_prev_category;

         FETCH c_prev_category
          INTO l_prev_package_category
              ,l_prev_nety_type_code;

         CLOSE c_prev_category;

         --
         IF    l_package_category <> NVL (l_prev_package_category, '*')
            OR l_nety_type_code <> NVL (l_prev_nety_type_code, '*') THEN
            --     dbms_output.put_line('DIAL found for DICO ref=' || to_char(l_dial_rec.dico_ref_num));
            IF c_dial_cat%ROWCOUNT = 1 THEN
               l_found := get_part_maac_data (p_maac_ref_num
                                             ,l_chca_type_code
                                             ,l_bicy_cycle_code
                                             ,l_month_of_serv
                                             ,l_party_type
                                             ,l_stat_ref_num
                                             ,l_part_month_of_serv
                                             );
            /*   dbms_output.put_line('CHCA ' || l_chca_type_code ||
                                    ', BICY ' || l_bicy_cycle_code ||
                                    ', month of service ' || to_char(l_month_of_serv) ||
                                    ', party type ' || l_party_type);*/
            END IF;

            /*
              ** Perform the first check on discount here (if this is applicable at all).
            */
            l_dico_found := get_discount_code_rec (l_dial_rec.dico_ref_num
                                                  ,p_date_start
                                                  ,l_month_of_serv
                                                  ,l_party_type
                                                  ,l_part_month_of_serv
                                                  ,l_dico_rec
                                                  );

            IF l_dico_found THEN
               --  dbms_output.put_line('Discount code found OK');
               IF NOT l_vmct_searched THEN
                  l_found := get_vmct_maac_type (l_stat_ref_num, l_vmct_maac_type);
                  --      dbms_output.put_line('VMCT ' || l_vmct_maac_type);
                  l_vmct_searched := TRUE;
               END IF;

               --
               l_ok := chk_apply_discount (l_dico_rec
                                          ,p_susg_ref_num
                                          ,p_maac_ref_num
                                          ,p_dealer_party
                                          ,p_region
                                          ,p_dealer_office
                                          ,p_channel_type
                                          ,l_chca_type_code
                                          ,l_bicy_cycle_code
                                          ,TRUNC (p_date_start)
                                          ,p_is_new_mobile
                                          ,l_vmct_maac_type
                                          );

               IF l_ok THEN
                  --      dbms_output.put_line('OK to apply discount ref=' || to_char(l_dico_rec.ref_num));
                        --registreeri soodustus:
                  l_sudi.ref_num := NULL;
                  l_sudi.susg_ref_num := p_susg_ref_num;
                  l_sudi.discount_code := l_dico_rec.discount_code;
                  l_sudi.connection_exist := 'N';
                  l_sudi.date_created := SYSDATE;
                  l_sudi.created_by := sec.get_username;
                  l_sudi.start_date := TRUNC (p_date_start);
                  l_sudi.dico_ref_num := l_dico_rec.ref_num;
                  l_sudi.end_date     := Calculate_Discounts.calculate_sudi_end_date (l_sudi.dico_ref_num, l_sudi.start_date); --DOBAS-1315

                  --
                  insert_sudi (l_sudi, p_success, p_error_text);

                  IF NOT p_success THEN
                     RAISE e_sudi;
                  END IF;

                  --
                  l_number := discount_count (l_dico_rec.ref_num, 'Y', p_success, p_error_text);

                  IF NOT p_success THEN
                     RAISE e_update_count;
                  END IF;
               END IF;
            END IF;
         END IF;
      END LOOP;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_update_count THEN
         p_success := FALSE;
         p_error_text := 'Update count for discount code ref=' || TO_CHAR (l_dico_rec.ref_num) || ': ' || p_error_text;
      WHEN e_sudi THEN
         p_success := FALSE;
         p_error_text := 'Insert Sudi: ' || p_error_text;
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
   END setup_disc_package;

   --
   PROCEDURE setup_disc_new_conn (
      p_date_start        IN      DATE   --execution_date
     ,p_maac_ref_num      IN      NUMBER
     ,p_susg_ref_num      IN      NUMBER
     ,p_maac_par_ref_num  IN      NUMBER
     ,p_susg_par_ref_num  IN      NUMBER
     ,p_dealer_party      IN      NUMBER
     ,p_region            IN      NUMBER
     ,p_dealer_office     IN      NUMBER
     ,p_channel_type      IN      VARCHAR2
     ,p_error_text        IN OUT  VARCHAR2
     ,p_success           IN OUT  BOOLEAN
     ,p_sept_type_code    IN      serv_package_types.type_code%TYPE DEFAULT NULL
   ) IS
      --
      CURSOR c_parent_dico (
         p_dico_ref_num  IN  NUMBER
      ) IS
         SELECT *
           FROM discount_codes
          WHERE ref_num = p_dico_ref_num AND p_date_start BETWEEN start_date AND NVL (end_date, p_date_start);

      --
      CURSOR c_dico IS
         SELECT   *
             FROM discount_codes dico
            WHERE p_date_start BETWEEN dico.start_date AND NVL (dico.end_date, p_date_start)
              AND dico.MANUAL = 'N'
              AND dico.for_all = 'N'
              AND NVL (dico.allowed_count, NVL (dico.given_count, 0)) >= NVL (dico.given_count, 0)
              AND NVL (dico.mobile_part, 'A') = 'A'
              AND NOT EXISTS (SELECT 1
                                FROM discount_allowed_list dial
                               WHERE dial.dico_ref_num = dico.ref_num
                                 AND (   dial.package_category IS NOT NULL
                                      OR dial.sety_ref_num IS NOT NULL
                                      OR dial.pack_type_code IS NOT NULL
                                     ))
         ORDER BY dico.exclude_dico_ref_num;

      --
      l_parent_dico_rec             discount_codes%ROWTYPE;
      l_parent_ok                   BOOLEAN;
      l_parent_sudi                 subs_discounts%ROWTYPE;
      l_b_maac_data_found           BOOLEAN := FALSE;
      l_b_vmct_searched             BOOLEAN := FALSE;
      l_ok                          BOOLEAN;
      l_found                       BOOLEAN;
      l_vmct_searched               BOOLEAN := FALSE;
      l_chca_type_code              accounts.chca_type_code%TYPE;
      l_bicy_cycle_code             accounts.bicy_cycle_code%TYPE;
      l_month_of_serv               accounts.month_of_serv%TYPE;
      l_party_type                  parties.party_type%TYPE;
      l_stat_ref_num                accounts.stat_ref_num%TYPE;
      l_part_month_of_serv          parties.month_of_serv%TYPE;
      l_vmct_maac_type              statements.vmct_maac_type%TYPE;
      l_b_chca_type_code            accounts.chca_type_code%TYPE;
      l_b_bicy_cycle_code           accounts.bicy_cycle_code%TYPE;
      l_b_month_of_serv             accounts.month_of_serv%TYPE;
      l_b_part_month_of_serv        parties.month_of_serv%TYPE;
      l_b_party_type                parties.party_type%TYPE;
      l_b_stat_ref_num              accounts.stat_ref_num%TYPE;
      l_b_vmct_maac_type            statements.vmct_maac_type%TYPE;
      l_number                      NUMBER;
      l_ref_num_c                   NUMBER;
      l_sudi                        subs_discounts%ROWTYPE;
      l_excl_dico_ref_tab           t_ref_num;   -- CHG-685
      l_count                       NUMBER;   -- CHG-685
      --
      e_insert_sudi                 EXCEPTION;
      e_update_count                EXCEPTION;
      e_missing_data                EXCEPTION;
   BEGIN
      l_count := 0;

      --
      FOR l_dico IN c_dico LOOP
         -- dbms_output.put_line('Starting processing DICO ref=' || to_char(l_dico.ref_num));
         IF NOT l_excl_dico_ref_tab.EXISTS (l_dico.ref_num) THEN
            l_parent_ok := FALSE;
            l_count := l_count + 1;   -- CHG-685

            --
            IF l_count = 1 THEN
               l_found := get_part_maac_data (p_maac_ref_num
                                             ,l_chca_type_code
                                             ,l_bicy_cycle_code
                                             ,l_month_of_serv
                                             ,l_party_type
                                             ,l_stat_ref_num
                                             ,l_part_month_of_serv
                                             );
            /*    dbms_output.put_line('For original mobile: CHCA ' || l_chca_type_code ||
                              ', BICY ' || l_bicy_cycle_code ||
                              ', month of service ' || to_char(l_month_of_serv) ||
                              ', party type ' || l_party_type);*/
            END IF;

            --
            IF     NVL (l_dico.month_of_serv, NVL (l_month_of_serv, 0)) <= NVL (l_month_of_serv, 0)
               AND NVL (l_dico.part_month_of_serv, NVL (l_part_month_of_serv, 0)) <= NVL (l_part_month_of_serv, 0)
               AND NVL (l_dico.party_type, NVL (l_party_type, '*')) = NVL (l_party_type, '*') THEN
               --  dbms_output.put_line('Party type and month of service OK');
               IF NOT l_vmct_searched THEN
                  l_found := get_vmct_maac_type (l_stat_ref_num, l_vmct_maac_type);
                  --        dbms_output.put_line('VMCT ' || l_vmct_maac_type);
                  l_vmct_searched := TRUE;
               END IF;

               --
               l_ok := chk_apply_discount (l_dico
                                          ,p_susg_ref_num
                                          ,p_maac_ref_num
                                          ,p_dealer_party
                                          ,p_region
                                          ,p_dealer_office
                                          ,p_channel_type
                                          ,l_chca_type_code
                                          ,l_bicy_cycle_code
                                          ,TRUNC (p_date_start)
                                          ,TRUE   -- here it is always a new mobile
                                          ,l_vmct_maac_type
                                          ,p_sept_type_code
                                          );

               IF l_ok THEN
                  --      dbms_output.put_line('OK to apply discount ref=' || to_char(l_dico.ref_num));
                  /*
                    ** This discount is OK to be inserted. Now if this discount excludes some other
                    ** discount then this other discount should be removed from applied discounts list.
                  */
                  IF l_dico.exclude_dico_ref_num IS NOT NULL THEN
                     l_excl_dico_ref_tab (l_dico.exclude_dico_ref_num) := l_dico.exclude_dico_ref_num;
                  --           dbms_output.put_line('Discount ref=' || to_char(l_dico.exclude_dico_ref_num) || ' excluded');
                  END IF;

                  /*
                    ** Now create subscriber discount record for this current discount.-hhgg
                  */
                  l_sudi := NULL;
                  l_ref_num_c := NULL;

                  --
                  SELECT sudi_ref_num_s.NEXTVAL
                    INTO l_ref_num_c
                    FROM SYS.DUAL;

                  --
                  l_sudi.ref_num := l_ref_num_c;
                  l_sudi.susg_ref_num := p_susg_ref_num;
                  l_sudi.discount_code := l_dico.discount_code;
                  l_sudi.connection_exist := 'N';
                  l_sudi.sudi_ref_num := NULL;
                  l_sudi.date_created := SYSDATE;
                  l_sudi.created_by := sec.get_username;
                  l_sudi.start_date := TRUNC (p_date_start);
                  l_sudi.dico_ref_num := l_dico.ref_num;
                  l_sudi.end_date     := Calculate_Discounts.calculate_sudi_end_date (l_sudi.dico_ref_num, l_sudi.start_date); --DOBAS-1315

                  /*
                    ** registreeri soodustuse parent( soodustusega antav teine soodustus)
                  */
                  IF l_dico.parent_dico_ref_num IS NOT NULL THEN
                     OPEN c_parent_dico (l_dico.parent_dico_ref_num);

                     FETCH c_parent_dico
                      INTO l_parent_dico_rec;

                     l_found := c_parent_dico%FOUND;

                     CLOSE c_parent_dico;

                     --
                     IF l_found THEN
                        /*
                          ** Parent discount applies for the same mobile as original discount.
                        */
                        IF NVL (l_parent_dico_rec.mobile_part, 'A') = 'A' THEN
                           --            dbms_output.put_line('Parent discount ref=' || to_char(l_parent_dico_rec.ref_num) || ' found for the same mobile');
                                         /*
                                           ** Check if parent discount can be applied to the same mobile.
                                         */
                           IF     NVL (l_parent_dico_rec.month_of_serv, NVL (l_month_of_serv, 0)) <=
                                                                                               NVL (l_month_of_serv, 0)
                              AND NVL (l_parent_dico_rec.part_month_of_serv, NVL (l_part_month_of_serv, 0)) <=
                                                                                           NVL (l_part_month_of_serv, 0)
                              AND NVL (l_parent_dico_rec.party_type, NVL (l_party_type, '*')) = NVL (l_party_type, '*') THEN
                              --               dbms_output.put_line('Party type and month of service OK for the parent discount');
                              l_parent_ok := chk_apply_discount (l_parent_dico_rec
                                                                ,p_susg_ref_num
                                                                ,p_maac_ref_num
                                                                ,p_dealer_party
                                                                ,p_region
                                                                ,p_dealer_office
                                                                ,p_channel_type
                                                                ,l_chca_type_code
                                                                ,l_bicy_cycle_code
                                                                ,TRUNC (p_date_start)
                                                                ,TRUE   -- here it is always a new mobile
                                                                ,l_vmct_maac_type
                                                                );

                              IF l_parent_ok THEN
                                 --              dbms_output.put_line('OK to apply parent discount ref=' || to_char(l_parent_dico_rec.ref_num));
                                 l_parent_sudi.ref_num := NULL;
                                 l_parent_sudi.susg_ref_num := p_susg_ref_num;
                                 l_parent_sudi.discount_code := l_parent_dico_rec.discount_code;
                                 l_parent_sudi.connection_exist := 'N';
                                 l_parent_sudi.date_created := SYSDATE;
                                 l_parent_sudi.created_by := sec.get_username;
                                 l_parent_sudi.start_date := TRUNC (p_date_start);
                                 l_parent_sudi.dico_ref_num := l_parent_dico_rec.ref_num;
                                 l_parent_sudi.sudi_ref_num := l_ref_num_c;
                                 l_parent_sudi.end_date     := Calculate_Discounts.calculate_sudi_end_date (l_parent_sudi.dico_ref_num, l_parent_sudi.start_date); --DOBAS-1315
                                 --
                                 insert_sudi (l_parent_sudi, p_success, p_error_text);
                                 l_sudi.sudi_ref_num := l_parent_sudi.ref_num;

                                 --
                                 IF NVL (p_success, TRUE) = TRUE THEN
                                    l_number := discount_count (l_parent_dico_rec.ref_num, 'Y', p_success
                                                               ,p_error_text);

                                    --
                                    IF NOT p_success THEN
                                       p_error_text :=    'Error when updating discounts count for discount code ref='
                                                       || TO_CHAR (l_parent_dico_rec.ref_num)
                                                       || ': '
                                                       || p_error_text;
                                       RAISE e_update_count;
                                    END IF;
                                 ELSE
                                    p_error_text :=    'DICO ref='
                                                    || TO_CHAR (l_parent_dico_rec.ref_num)
                                                    || ' (parent): '
                                                    || p_error_text;
                                    RAISE e_insert_sudi;
                                 END IF;
                              END IF;   -- IF l_parent_ok
                           END IF;
                        ELSE   -----parent=B
                           --       dbms_output.put_line('Parent discount ref=' || to_char(l_parent_dico_rec.ref_num) || ' found for other mobile');
                                  /*
                                    ** Parent discount applies for the different mobile from original discount.
                                  */
                           IF p_maac_par_ref_num IS NOT NULL AND p_susg_par_ref_num IS NOT NULL THEN
                              IF NOT l_b_maac_data_found THEN
                                 l_found := get_part_maac_data (p_maac_par_ref_num
                                                               ,l_b_chca_type_code
                                                               ,l_b_bicy_cycle_code
                                                               ,l_b_month_of_serv
                                                               ,l_b_party_type
                                                               ,l_b_stat_ref_num
                                                               ,l_b_part_month_of_serv
                                                               );
                                 --           dbms_output.put_line('For parent mobile: CHCA ' || l_b_chca_type_code ||
                                 --                                ', BICY ' || l_b_bicy_cycle_code ||
                                 --                                ', month of service ' || to_char(l_b_month_of_serv) ||
                                 --                                ', party type ' || l_b_party_type);
                                 l_b_maac_data_found := TRUE;
                              END IF;

                              --
                              IF     NVL (l_parent_dico_rec.month_of_serv, NVL (l_b_month_of_serv, 0)) <=
                                                                                              NVL (l_b_month_of_serv, 0)
                                 AND NVL (l_parent_dico_rec.part_month_of_serv, NVL (l_b_part_month_of_serv, 0)) <=
                                                                                         NVL (l_b_part_month_of_serv, 0)
                                 AND NVL (l_parent_dico_rec.party_type, NVL (l_b_party_type, '*')) =
                                                                                               NVL (l_b_party_type, '*') THEN
                                 --           dbms_output.put_line('Party type and month of service OK for the parent discount of parent mobile');
                                 IF NOT l_b_vmct_searched THEN
                                    l_found := get_vmct_maac_type (l_b_stat_ref_num, l_b_vmct_maac_type);
                                    --              dbms_output.put_line('Parent mobile VMCT ' || l_b_vmct_maac_type);
                                    l_b_vmct_searched := TRUE;
                                 END IF;

                                 --
                                 l_parent_ok := chk_apply_discount (l_parent_dico_rec
                                                                   ,p_susg_par_ref_num
                                                                   ,p_maac_par_ref_num
                                                                   ,p_dealer_party
                                                                   ,p_region
                                                                   ,p_dealer_office
                                                                   ,p_channel_type
                                                                   ,l_b_chca_type_code
                                                                   ,l_b_bicy_cycle_code
                                                                   ,TRUNC (p_date_start)
                                                                   ,FALSE   -- must be old mobile here
                                                                   ,l_b_vmct_maac_type
                                                                   );

                                 IF l_parent_ok THEN
                                    --             dbms_output.put_line('OK to apply parent discount ref=' || to_char(l_parent_dico_rec.ref_num));
                                    l_parent_sudi.ref_num := NULL;
                                    l_parent_sudi.susg_ref_num := p_susg_par_ref_num;
                                    l_parent_sudi.discount_code := 'B';
                                    l_parent_sudi.connection_exist := 'N';
                                    l_parent_sudi.date_created := SYSDATE;
                                    l_parent_sudi.created_by := sec.get_username;
                                    l_parent_sudi.start_date := TRUNC (p_date_start);
                                    l_parent_sudi.dico_ref_num := l_parent_dico_rec.ref_num;
                                    l_parent_sudi.sudi_ref_num := l_ref_num_c;
                                    l_parent_sudi.end_date     := Calculate_Discounts.calculate_sudi_end_date (l_parent_sudi.dico_ref_num, l_parent_sudi.start_date); --DOBAS-1315

                                    --
                                    insert_sudi (l_parent_sudi, p_success, p_error_text);
                                    l_sudi.sudi_ref_num := l_parent_sudi.ref_num;
                                    l_sudi.connection_exist := 'Y';

                                    --
                                    IF NVL (p_success, TRUE) = TRUE THEN
                                       l_number := discount_count (l_parent_dico_rec.ref_num
                                                                  ,'Y'
                                                                  ,p_success
                                                                  ,p_error_text
                                                                  );

                                       --
                                       IF NOT p_success THEN
                                          p_error_text :=
                                                'Error when updating discounts count for discount code ref='
                                             || TO_CHAR (l_parent_dico_rec.ref_num)
                                             || ': '
                                             || p_error_text;
                                          RAISE e_update_count;
                                       END IF;
                                    ELSE
                                       p_error_text :=    'DICO ref='
                                                       || TO_CHAR (l_parent_dico_rec.ref_num)
                                                       || ' (parent): '
                                                       || p_error_text;
                                       RAISE e_insert_sudi;
                                    END IF;
                                 END IF;   -- IF l_parent_ok
                              END IF;   -- IF NVL(l_parent_dico_rec.month_of_serv, NVL(l_b_month_of_serv, 0)) ...
                           END IF;   -- IF p_maac_par_ref_num IS NOT NULL AND p_susg_par_ref_num IS NOT NULL THEN
                        END IF;   -- IF parent = A/B
                     END IF;   -- IF found parent discount record
                  END IF;   -- IF parent discount registered for this DICO

                  /*
                    ** Now insert the original discount.
                  */
                  insert_sudi (l_sudi, p_success, p_error_text);

                  --
                  IF NVL (p_success, TRUE) = TRUE THEN
                     l_number := discount_count (l_dico.ref_num, 'Y', p_success, p_error_text);

                     --
                     IF NOT p_success THEN
                        p_error_text :=    'Error when updating discounts count for discount code ref='
                                        || TO_CHAR (l_dico.ref_num)
                                        || ': '
                                        || p_error_text;
                        RAISE e_update_count;
                     END IF;
                  ELSE
                     p_error_text := 'DICO ref=' || TO_CHAR (l_dico.ref_num) || ': ' || p_error_text;
                     RAISE e_insert_sudi;
                  END IF;
               END IF;   -- IF l_ok to apply this DICO
            END IF;   -- IF NVL(l_dico.month_of_serv, NVL(l_month_of_serv, 0)) <= NVL(l_month_of_serv, 0) AND ...
         END IF;   -- this discount has not been excluded
      END LOOP;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_insert_sudi THEN
         p_error_text := 'Insert Sudi: ' || p_error_text;
         p_success := FALSE;
      WHEN e_update_count THEN
         p_success := FALSE;
      WHEN e_missing_data THEN
         p_success := FALSE;
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
   END setup_disc_new_conn;

   ----------------------------------------------------------------------------------------
   FUNCTION control_dealer (
      p_dico_ref_num       discount_codes.ref_num%TYPE
     ,p_date               DATE   --order_date
     ,p_channel_type   IN  VARCHAR2
     ,p_dealer_party   IN  NUMBER
     ,p_region         IN  NUMBER
     ,p_dealer_office  IN  NUMBER
   )
      RETURN VARCHAR2 IS
      CURSOR c_dico_deal IS
         SELECT 'Y'
           FROM discount_allowed_list dial
          WHERE dial.dico_ref_num = p_dico_ref_num
            AND (dial.dealer_party = p_dealer_party OR dial.dealer_office = p_dealer_office OR dial.region = p_region)
            AND TRUNC (p_date) BETWEEN dial.start_date AND NVL (dial.end_date, p_date);

      CURSOR c_dico_deal_n IS
         SELECT 'Y'
           FROM DUAL
          WHERE 0 = (SELECT COUNT (*)
                       FROM discount_allowed_list dial
                      WHERE p_dico_ref_num = dial.dico_ref_num AND dial.dealer_party IS NOT NULL)
            AND 0 = (SELECT COUNT (*)
                       FROM discount_allowed_list dial
                      WHERE p_dico_ref_num = dial.dico_ref_num AND dial.dealer_office IS NOT NULL)
            AND 0 = (SELECT COUNT (*)
                       FROM discount_allowed_list dial
                      WHERE p_dico_ref_num = dial.dico_ref_num AND dial.region IS NOT NULL);

      CURSOR c_channel_dico IS
         SELECT 'Y'
           FROM discount_allowed_list dial
          WHERE (   (    dial.dico_ref_num = p_dico_ref_num
                     AND dial.channel_type = p_channel_type
                     AND TRUNC (p_date) BETWEEN dial.start_date AND NVL (dial.end_date, p_date)
                    )
                 OR 0 = (SELECT COUNT (*)
                           FROM discount_allowed_list dial
                          WHERE p_dico_ref_num = dial.dico_ref_num AND dial.channel_type IS NOT NULL)
                );

      p_yn                          VARCHAR2 (1) := 'N';
   BEGIN
      IF p_dico_ref_num IS NOT NULL THEN
         OPEN c_dico_deal;

         FETCH c_dico_deal
          INTO p_yn;

         CLOSE c_dico_deal;

         IF p_yn <> 'Y' THEN
            OPEN c_dico_deal_n;

            FETCH c_dico_deal_n
             INTO p_yn;

            CLOSE c_dico_deal_n;
         END IF;
      END IF;

      --
      IF p_yn = 'Y' THEN
         OPEN c_channel_dico;

         FETCH c_channel_dico
          INTO p_yn;

         CLOSE c_channel_dico;
      END IF;

      RETURN p_yn;
   END control_dealer;

   ---------------------------------------------------------------------
   PROCEDURE insert_sudi (
      p_sudi        IN OUT NOCOPY  subs_discounts%ROWTYPE
     ,p_success     OUT            BOOLEAN
     ,p_error_text  OUT            VARCHAR2
   ) IS
   BEGIN
      IF p_sudi.ref_num IS NULL THEN
         SELECT sudi_ref_num_s.NEXTVAL
           INTO p_sudi.ref_num
           FROM SYS.DUAL;
      END IF;

      IF (p_sudi.created_by IS NULL) THEN
         p_sudi.created_by := sec.get_username;
      END IF;

      IF (p_sudi.date_created IS NULL) THEN
         p_sudi.date_created := SYSDATE;
      END IF;

      INSERT INTO subs_discounts sudi
                  (sudi.ref_num   --NOT NULL NUMBER(10)
                  ,sudi.susg_ref_num   --NOT NULL NUMBER(10)
                  ,sudi.discount_code   --NOT NULL VARCHAR2(3)
                  ,sudi.connection_exist   --NOT NULL VARCHAR2(1)
                  ,sudi.sudi_ref_num   --         NUMBER(10)
                  ,sudi.closed   --         VARCHAR2(1)
                  ,sudi.reason_code   --         VARCHAR2(4)
                  ,sudi.date_created   --NOT NULL DATE
                  ,sudi.created_by   --NOT NULL VARCHAR2(15)
                  ,sudi.date_updated   --         DATE
                  ,sudi.last_updated_by   --         VARCHAR2(15)
                  ,sudi.doc_type   --         VARCHAR2(1)
                  ,sudi.doc_num   --         VARCHAR2(20)
                  ,sudi.eek_amt
                  ,sudi.start_date   --NOT NULL DATE
                  ,sudi.end_date   --         DATE
                  ,sudi.cadc_ref_num   --         NUMBER(10)
                  ,sudi.dico_ref_num   --NOT NULL Number(10)
                  ,sudi.dico_sudi_ref_num
                  ,sudi.padi_ref_num     --mobet-74
                  ,sudi.usre_ref_num     --DOBAS-467
                  ,sudi.caof_ref_num     --DOBAS-467
                  )
           VALUES (p_sudi.ref_num
                  ,p_sudi.susg_ref_num
                  ,p_sudi.discount_code
                  ,p_sudi.connection_exist
                  ,p_sudi.sudi_ref_num
                  ,p_sudi.closed
                  ,p_sudi.reason_code
                  ,p_sudi.date_created
                  ,p_sudi.created_by
                  ,p_sudi.date_updated
                  ,p_sudi.last_updated_by
                  ,p_sudi.doc_type
                  ,p_sudi.doc_num
                  ,p_sudi.eek_amt
                  ,TRUNC (p_sudi.start_date)
                  ,p_sudi.end_date
                  ,p_sudi.cadc_ref_num
                  ,p_sudi.dico_ref_num
                  ,p_sudi.dico_sudi_ref_num
                  ,p_sudi.padi_ref_num --mobet-74
                  ,p_sudi.usre_ref_num --DOBAS-467
                  ,p_sudi.caof_ref_num --DOBAS-467
                  );

       --dbms_output.put_line('Inserditud Sudi ref: '||to_char(p_sudi.ref_num)||',susg '||to_char(p_sudi.susg_ref_num)
      -- ||',parent ref '||to_char(p_sudi.sudi_ref_num)||',start '||
      -- to_char(p_sudi.start_date)||',cadc ref '||to_char(p_sudi.cadc_ref_num)||',dico ref '||
      -- to_char(p_sudi.dico_ref_num)||',dico sudi ref '||to_char(p_sudi.dico_sudi_ref_num) );
      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
   END insert_sudi;

   --------------------------------------------------------------------------------------
   FUNCTION insert_dial (
      p_dial        IN      discount_allowed_list%ROWTYPE
     ,p_success     OUT     BOOLEAN
     ,p_error_text  OUT     VARCHAR2
   )
      RETURN NUMBER IS
      l_ref_num                     NUMBER := NULL;
      l_date_created                DATE;
      l_created_by                  VARCHAR2 (15);
   BEGIN
      l_date_created := p_dial.date_created;
      l_created_by := p_dial.created_by;

      IF p_dial.date_created IS NULL THEN
         l_date_created := SYSDATE;
      END IF;

      IF p_dial.created_by IS NULL THEN
         l_created_by := sec.get_username;
      END IF;

      --
      IF p_dial.ref_num IS NULL THEN
         SELECT disc_ref_num_s.NEXTVAL
           INTO l_ref_num
           FROM SYS.DUAL;
      END IF;

      IF l_ref_num IS NOT NULL THEN
         INSERT INTO discount_allowed_list
                     (ref_num
                     ,spoc_ref_num
                     ,dico_ref_num
                     ,cadc_ref_num
                     ,start_date
                     ,end_date
                     ,dealer_party
                     ,region
                     ,dealer_office
                     ,maac_ref_num
                     ,vmct_maac_type
                     ,reason_code
                     ,channel_type
                     ,sety_ref_num
                     ,sepv_ref_num
                     ,package_category
                     ,nety_type_code
                     ,pack_type_code
                     ,bicy_cycle_code
                     ,chca_type_code
                     ,tariff_class
                     ,date_created
                     ,created_by
                     )
              VALUES (l_ref_num
                     ,p_dial.spoc_ref_num
                     ,p_dial.dico_ref_num
                     ,p_dial.cadc_ref_num
                     ,p_dial.start_date
                     ,p_dial.end_date
                     ,p_dial.dealer_party
                     ,p_dial.region
                     ,p_dial.dealer_office
                     ,p_dial.maac_ref_num
                     ,p_dial.vmct_maac_type
                     ,p_dial.reason_code
                     ,p_dial.channel_type
                     ,p_dial.sety_ref_num
                     ,p_dial.sepv_ref_num
                     ,p_dial.package_category
                     ,p_dial.nety_type_code
                     ,p_dial.pack_type_code
                     ,p_dial.bicy_cycle_code
                     ,p_dial.chca_type_code
                     ,p_dial.tariff_class
                     ,l_date_created
                     ,l_created_by
                     );
      END IF;

      p_success := TRUE;
      RETURN l_ref_num;
   EXCEPTION
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
         RETURN NULL;
   END insert_dial;

   ----------------------------------------------------------------------------------------
   FUNCTION new_and_several_mob (
      p_dico_rec       IN      discount_codes%ROWTYPE
     ,p_susg_ref_num   IN      NUMBER
     ,p_is_new_mobile  IN      BOOLEAN
     ,p_count          OUT     NUMBER
   )
      RETURN BOOLEAN IS
      CURSOR c_count IS
         SELECT COUNT (*) + 1
           FROM subs_discounts sudi
          WHERE sudi.susg_ref_num = p_susg_ref_num
            AND sudi.dico_ref_num = p_dico_rec.ref_num
            AND sudi.cadc_ref_num IS NULL;

      l_ok                          BOOLEAN;
   BEGIN
      OPEN c_count;

      FETCH c_count
       INTO p_count;

      CLOSE c_count;

      IF p_dico_rec.several_mobile IS NOT NULL THEN
         --
         IF p_count > p_dico_rec.several_mobile THEN
            l_ok := FALSE;
         ELSE
            -- ARVO-759
            IF (p_dico_rec.new_mobile = 'Y' AND p_is_new_mobile) OR NVL (p_dico_rec.new_mobile, 'N') <> 'Y' THEN
               l_ok := TRUE;
            ELSE
               l_ok := FALSE;
            END IF;
            --
         END IF;
      ELSE -- ARVO-759
         --
         IF (p_dico_rec.new_mobile = 'Y' AND p_is_new_mobile) OR NVL (p_dico_rec.new_mobile, 'N') <> 'Y' THEN
            l_ok := TRUE;
         ELSE
            l_ok := FALSE;
         END IF;
         --
      END IF;
      --
      RETURN l_ok;
   END new_and_several_mob;

   ----------------------------------------------------------------------------------------
   -- Fn annab tagasi arvu, mitmes soodustus anti.Üks kahest (p_dico / p_spoc) peab olema null
   FUNCTION discount_count (
      p_dico_ref_num       discount_codes.ref_num%TYPE
     ,p_update_count       VARCHAR2   --Kas tabelis discount_codes suurendada väärtust "given_count".
     ,p_success       OUT  BOOLEAN
     ,p_error_text    OUT  VARCHAR2
   )
      RETURN NUMBER IS
      CURSOR c_dico (
         p_dico_ref_num  NUMBER
      ) IS
         SELECT *
           FROM discount_codes
          WHERE ref_num = p_dico_ref_num;

      l_count                       NUMBER := 0;
      l_dico                        discount_codes%ROWTYPE;
   --
   BEGIN
      --dbms_output.put_line('DICO ref=' || to_char(p_dico_ref_num) || ', update?=' || p_update_count);
      IF p_dico_ref_num IS NOT NULL THEN
         OPEN c_dico (p_dico_ref_num);

         FETCH c_dico
          INTO l_dico;

         CLOSE c_dico;

         -- dbms_output.put_line('Allowed count=' || to_char(l_dico.allowed_count) ||
         --                      ', given count=' || to_char(l_dico.given_count));
         IF NVL (l_dico.allowed_count, (NVL (l_dico.given_count, 0) + 1)) > NVL (l_dico.given_count, 0) THEN
            l_count := NVL (l_dico.given_count, 0) + 1;

            --    dbms_output.put_line('Count=' || to_char(l_count));
            IF p_update_count = 'Y' THEN
               UPDATE discount_codes
                  SET given_count = l_count
                     ,date_updated = SYSDATE
                     ,last_updated_by = sec.get_username
                WHERE ref_num = l_dico.ref_num;
            --        dbms_output.put_line('Updating DICO ref=' || to_char(l_dico.ref_num));
            END IF;
         END IF;
      END IF;

      p_success := TRUE;
      RETURN l_count;
   EXCEPTION
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
         RETURN NULL;
   END discount_count;

   ----------------------------------------------------------------------------------------
   FUNCTION control_ma_for_special (
      p_maac_ref_num  IN  NUMBER
     ,p_dico_ref_num      discount_codes.ref_num%TYPE
     ,p_date              DATE
   )
      RETURN VARCHAR2 IS
      -- p_date date  -- Millise kuupäevaga soodustuse andmine tuleb (ilma kellata võib olla).date_start
      p_yn                          VARCHAR2 (1) := 'N';
      l_ref_num                     NUMBER := NULL;

      --
      CURSOR c_dico IS
         SELECT 'Y'
           FROM discount_allowed_list dial
          WHERE (   (    dial.dico_ref_num = p_dico_ref_num
                     AND dial.maac_ref_num = p_maac_ref_num
                     AND TRUNC (p_date) BETWEEN dial.start_date AND NVL (dial.end_date, p_date)
                    )
                 OR 0 = (SELECT COUNT (*)
                           FROM discount_allowed_list dial
                          WHERE p_dico_ref_num = dial.dico_ref_num AND dial.maac_ref_num IS NOT NULL)
                );
   BEGIN
      --dbms_output.put_line('Control_MA_for_Special ');
      IF p_dico_ref_num IS NOT NULL THEN
         OPEN c_dico;

         FETCH c_dico
          INTO p_yn;

         CLOSE c_dico;
      END IF;

      RETURN p_yn;
   END control_ma_for_special;

   ----------------------------------------------------------------------------------------
   --kontroll:vmct+party+month+bicy+chca
   FUNCTION control_ma_for_discount (
      p_maac_ref_num  IN  NUMBER
     ,p_date_start        DATE   --order date
     ,p_dico_ref_num      discount_codes.ref_num%TYPE
   )
      RETURN VARCHAR2 IS
      p_yn                          VARCHAR2 (1) := 'N';
      l_vmct                        VARCHAR2 (3);
      l_num                         NUMBER;
      l_dico                        discount_codes%ROWTYPE;

      CURSOR c_dico (
         p_dico_ref_num  NUMBER
      ) IS
         SELECT *
           FROM discount_codes
          WHERE ref_num = p_dico_ref_num;

      CURSOR c (
         l_vmct  VARCHAR2
        ,p_dico  discount_codes%ROWTYPE
      ) IS
         SELECT 'Y'
           FROM master_accounts_v acco
          WHERE acco.ref_num = p_maac_ref_num
            AND ((    (   (acco.chca_type_code IN (SELECT dial.chca_type_code
                                                     FROM discount_allowed_list dial
                                                    WHERE p_dico.ref_num = dial.dico_ref_num
                                                      AND TRUNC (p_date_start) BETWEEN dial.start_date
                                                                                   AND NVL (dial.end_date, p_date_start))
                          )
                       OR 0 = (SELECT COUNT (*)
                                 FROM discount_allowed_list dial
                                WHERE p_dico.ref_num = dial.dico_ref_num AND dial.chca_type_code IS NOT NULL)
                      )
                  AND (   (NVL (l_vmct, '*') IN (SELECT dial.vmct_maac_type
                                                   FROM discount_allowed_list dial
                                                  WHERE p_dico.ref_num = dial.dico_ref_num
                                                    AND TRUNC (p_date_start) BETWEEN dial.start_date
                                                                                 AND NVL (dial.end_date, p_date_start))
                          )
                       OR 0 = (SELECT COUNT (*)
                                 FROM discount_allowed_list dial
                                WHERE p_dico.ref_num = dial.dico_ref_num AND dial.vmct_maac_type IS NOT NULL)
                      )
                  AND (   (acco.bicy_cycle_code IN (SELECT dial.bicy_cycle_code
                                                      FROM discount_allowed_list dial
                                                     WHERE p_dico.ref_num = dial.dico_ref_num
                                                       AND TRUNC (p_date_start) BETWEEN dial.start_date
                                                                                    AND NVL (dial.end_date
                                                                                            ,p_date_start))
                          )
                       OR 0 = (SELECT COUNT (*)
                                 FROM discount_allowed_list dial
                                WHERE p_dico.ref_num = dial.dico_ref_num AND dial.bicy_cycle_code IS NOT NULL)
                      )
                  AND NVL (acco.month_of_serv, 0) >= NVL (p_dico.month_of_serv, NVL (acco.month_of_serv, 0))
                  AND ((NVL (p_dico.party_type, '*') = (SELECT part.party_type
                                                          FROM parties part
                                                         WHERE ref_num = acco.part_ref_num))
                       OR p_dico.party_type IS NULL
                      )
                 )
                );

      --
      CURSOR c_vmct IS
         SELECT stat.vmct_maac_type
           FROM statements stat, accounts acco
          WHERE stat.ref_num = acco.stat_ref_num AND acco.ref_num = p_maac_ref_num;

      --
      CURSOR c_count_maac (
         p_dico_ref_num  NUMBER
      ) IS
         SELECT COUNT (*)
           FROM subs_discounts
          WHERE susg_ref_num IN (SELECT ref_num
                                   FROM subs_serv_groups
                                  WHERE suac_ref_num BETWEEN p_maac_ref_num AND p_maac_ref_num + 999)
            AND dico_ref_num = p_dico_ref_num;
   --
   BEGIN
      -- dbms_output.put_line('Control_MA_for_Discount '||to_char(p_dico_ref_num));
      OPEN c_dico (p_dico_ref_num);

      FETCH c_dico
       INTO l_dico;

      CLOSE c_dico;

      --  dbms_output.put_line('dico '||to_char(l_dico.ref_num));
      OPEN c_vmct;

      FETCH c_vmct
       INTO l_vmct;

      CLOSE c_vmct;

      OPEN c (l_vmct, l_dico);

      FETCH c
       INTO p_yn;

      CLOSE c;

      IF p_yn = 'Y' THEN
         IF NVL (l_dico.several_maac, 0) > 0 THEN
            OPEN c_count_maac (p_dico_ref_num);

            FETCH c_count_maac
             INTO l_num;

            CLOSE c_count_maac;

            IF NVL (l_num, 0) + 1 > NVL (l_dico.several_maac, (NVL (l_num, 0) + 2)) THEN
               p_yn := 'N';
            END IF;
         END IF;
      END IF;

      RETURN p_yn;
   END control_ma_for_discount;

   ----------------------------------------------------------------------------------------
   ----------------------------------------------------------------------------------------
   PROCEDURE calculate_one_amount (
      p_chg_duration    IN      NUMBER   -- kestus(kõne, kuumaksu päevad) oneone
     ,p_price           IN      NUMBER   -- hind(minutis, kuus)
     ,p_cadc            IN      call_discount_codes%ROWTYPE
     ,p_cutoff_day_num  IN      NUMBER   -- Kuumaksu ja MIN soodustuse miinimumhinna defineerimisek
     ,p_disc_duration   IN OUT  NUMBER   --arvutatud soodustuse kestus
     ,p_disc_amount     IN OUT  NUMBER
     ,p_padi_ref_num    IN      NUMBER DEFAULT NULL  --mobet-75
   ) IS   --arvutatud soodustuse summa

    --mobet-75
    CURSOR c_padd(p_padi_ref number, p_cadc_ref number) IS    
    SELECT * 
     FROM PART_DICO_DETAILS 
    WHERE padi_ref_num = p_padi_ref
      AND cadc_ref_num = p_cadc_ref;

      l_padd_rec                    PART_DICO_DETAILS%rowtype := null;  --mobet-75
      i                             NUMBER := 1;
      j                             NUMBER;
      l_sum_protsent                NUMBER (12, 9) := 1;
      l_sum                         NUMBER (12, 9) := 0;
      l_price_sek                   NUMBER (14, 7);
      l_discount                    NUMBER (14, 6);
      l_int_count                   NUMBER (10);   -- täisarv perioode
      l_mod                         NUMBER (10);   --täisarvu perioodide jääk
      l_period_add                  NUMBER (10);   --suurema perioodi lisa
      l_duration_add                NUMBER (10);   -- väiksema perioodi lisa
      l_chg_duration                NUMBER (10);   --out mitu ühikut soodustuse alla
      l_minimum_price               NUMBER (14, 7);
      l_per_count                   NUMBER;   -- mitu vahemikku %-ga
      l_mod_max                     NUMBER (10);
      l_mod_min                     NUMBER (10);
   BEGIN
      IF NVL (p_chg_duration, 0) = 0 AND NVL (p_cadc.DURATION, 0) > 0 THEN
         --ära soodustust arvuta!
         p_disc_duration := NULL;
         p_disc_amount := NULL;
         RETURN;
      END IF;

      IF NVL (p_cadc.precentage, 0) = 0 AND NVL (p_cadc.minimum_price, 0) = 0 
      AND p_padi_ref_num is null  -- mobet-75
      THEN
         p_disc_duration := NULL;
         p_disc_amount := NULL;
         RETURN;
      ELSE
         IF p_chg_duration > 0 THEN
            l_price_sek := p_price / p_chg_duration;
         ELSE
            l_price_sek := p_price;
         END IF;

         --antakse soodustust protsent, aga mitte rohkem, kui minimum_price

          --mobet-75 Leia PADD kirje padi_ref_num ja cadc.ref_num järgi
          IF p_padi_ref_num is not null then

            OPEN c_padd(p_padi_ref_num,p_cadc.ref_num);
            FETCH c_padd INTO l_padd_rec;
            CLOSE c_padd;
            
            IF l_padd_rec.padi_ref_num is not null THEN --s.t., et kirje oli
               
               IF l_padd_rec.PRICE is not null THEN
                  l_minimum_price := l_padd_rec.price/NVL (p_cutoff_day_num, 1); 

               ELSIF l_padd_rec.DISC_ABSOLUTE is not null THEN
                  l_minimum_price := l_price_sek - (l_padd_rec.DISC_ABSOLUTE/NVL (p_cutoff_day_num, 1));

               ELSE
                  l_minimum_price := l_price_sek - l_price_sek * NVL (l_padd_rec.disc_percentage, 0) / 100;
               END IF;   
            ELSE -- kui padi_ref_num on täidetud ja PADD vastavat kirjet pole, siis ei saa soodustust
              p_disc_duration := NULL;
              p_disc_amount := NULL;
              RETURN;

            END IF;
         ELSE   

          IF p_cadc.pricing = 'Y' THEN   --hinda suuremaga
            IF NVL (p_cadc.minimum_price, 0) > 0 THEN
               l_minimum_price := GREATEST (p_cadc.minimum_price / NVL (p_cutoff_day_num, 1)
                                           , (l_price_sek * NVL (p_cadc.precentage, 0) / 100)
                                           );
            ELSE
               l_minimum_price := (l_price_sek * NVL (p_cadc.precentage, 0) / 100);
            END IF;
          --  dbms_output.put_line('min greatest'||to_char(l_minimum_price));
          --hinnatakse protsendiga, aga mitte vähem, kui minimum_price
          ELSE   --ana soodustust vähemaga
            IF NVL (p_cadc.minimum_price, 0) > 0 THEN
               l_minimum_price :=   l_price_sek
                                  - LEAST (p_cadc.minimum_price / NVL (p_cutoff_day_num, 1)
                                          , (l_price_sek * NVL (p_cadc.precentage, 100) / 100)
                                          );
            ELSE
               l_minimum_price := l_price_sek - (l_price_sek * NVL (p_cadc.precentage, 100) / 100);
            END IF;
         --   dbms_output.put_line('min greatest'||to_char(l_minimum_price));
          END IF;
         
         END IF; -- IF padi_ref_num
         --
         IF p_cadc.chg_duration IS NOT NULL THEN
            IF p_cadc.chg_duration <= p_chg_duration THEN
               IF p_cadc.pricing = 'N' THEN
                  IF NVL (p_cadc.DURATION, 0) = 0 THEN
                     l_discount := GREATEST ((  l_price_sek * p_chg_duration
                                              - (NVL (p_cadc.period_sek, 0) * l_price_sek)
                                              - (p_chg_duration - NVL (p_cadc.period_sek, 0)) * l_minimum_price
                                             )
                                            ,0
                                            );
                  ELSE   --duration is not null
                     IF p_cadc.decrease = 'N' OR p_cadc.decrease IS NULL THEN
                        l_int_count := FLOOR (p_chg_duration / (NVL (p_cadc.period_sek, 0) + p_cadc.DURATION));   --mitu perioodi
                        l_mod := MOD (p_chg_duration, NVL (p_cadc.period_sek, 0) + p_cadc.DURATION);   --täisperioodide jääk

                        IF l_mod - NVL (p_cadc.period_sek, 0) <= 0 THEN
                           l_period_add := l_mod;
                        ELSE
                           l_period_add := NVL (p_cadc.period_sek, 0);
                        END IF;

                        IF l_mod - NVL (p_cadc.period_sek, 0) > 0 THEN
                           l_duration_add := l_mod - NVL (p_cadc.period_sek, 0);
                        ELSE
                           l_duration_add := 0;
                        END IF;

                        l_mod_max := l_int_count * NVL (p_cadc.period_sek, 0) + l_period_add;
                        l_mod_min := l_int_count * p_cadc.DURATION + l_duration_add;
                        l_discount := GREATEST ((  (l_price_sek * p_chg_duration)
                                                 - (l_mod_max * l_price_sek)
                                                 - (l_mod_min * l_minimum_price)
                                                )
                                               ,0
                                               );
                        l_chg_duration := l_mod_min;
                     ELSE   -- decrease=Y
                        l_minimum_price := NVL (p_cadc.minimum_price, 0) / NVL (p_cutoff_day_num, 1);
                        l_int_count := FLOOR ((p_chg_duration - NVL (p_cadc.period_sek, 0)) / p_cadc.DURATION);   --mitu perioodi
                        l_mod := MOD (p_chg_duration - NVL (p_cadc.period_sek, 0), p_cadc.DURATION);   --täisperioodide jääk

                        --mitu korda saan % arvutada, kuni miinimum hind vastu tuleb (l_per_count):
                        IF NVL (p_cadc.precentage, 0) > 0 THEN
                           l_per_count := 0;
                           l_sum := l_price_sek;

                           LOOP
                              l_sum := l_sum - l_price_sek * p_cadc.precentage / 100;

                              IF l_sum < l_minimum_price THEN
                                 EXIT;
                              END IF;

                              l_per_count := l_per_count + 1;
                           END LOOP;
                        ELSE
                           l_per_count := l_int_count;
                        END IF;

                        --
                        IF l_per_count > l_int_count THEN
                           l_per_count := l_int_count;
                        END IF;

                        l_sum := 0;
                        l_sum_protsent := 1;
                        i := 1;

                        ------x+x2+x3+...+xn:(astmes)
                        IF l_per_count > 0 THEN
                           LOOP
                              j := 0;
                              l_sum_protsent := 1;

                              LOOP
                                 l_sum_protsent := l_sum_protsent - NVL (p_cadc.precentage, 0) / 100.000;
                                 j := j + 1;

                                 IF j >= i THEN
                                    EXIT;
                                 END IF;
                              END LOOP;

                              l_sum := l_sum + l_sum_protsent;
                              i := i + 1;

                              IF i > l_per_count THEN
                                 EXIT;
                              END IF;
                           END LOOP;
                        END IF;

                        ---
                        IF l_int_count = l_per_count THEN
                           l_sum_protsent := l_sum_protsent * l_price_sek * l_mod;
                        ELSE
                           l_sum_protsent := l_minimum_price * l_mod;
                        END IF;

                        l_discount := GREATEST ((  (l_price_sek * p_chg_duration)
                                                 - NVL (p_cadc.period_sek, 0) * l_price_sek
                                                 - (l_price_sek * p_cadc.DURATION * l_sum)
                                                 - l_minimum_price * p_cadc.DURATION * (l_int_count - l_per_count)
                                                 - l_sum_protsent
                                                )
                                               ,0
                                               );
                        l_chg_duration := p_chg_duration - p_cadc.period_sek;
                     END IF;   --if decrease='N' then OK
                  END IF;   --duration is null OK
               ------
               ELSE   -- pricing='Y' :hinda KÕNE selliselt:
                  IF NVL (p_cadc.DURATION, 0) > 0 THEN
                     -- pärast price_list perioodi teatud arv sekundeid kõne ümber
                     -- price_list perioodi võib olla ka 0
                     l_discount := GREATEST ((  l_price_sek * p_chg_duration
                                              - (NVL (p_cadc.period_sek, 0) * l_price_sek)
                                              -   LEAST ((p_chg_duration - NVL (p_cadc.period_sek, 0))
                                                        ,NVL (p_cadc.DURATION, 0)
                                                        )
                                                * l_minimum_price
                                             )
                                            ,0
                                            );
                  ELSE
                     -- pärast price_list perioodi hinnatakse kõne ümber
                     l_discount := GREATEST ((  l_price_sek * p_chg_duration
                                              - (NVL (p_cadc.period_sek, 0) * l_price_sek)
                                              - (p_chg_duration - NVL (p_cadc.period_sek, 0)) * l_minimum_price
                                             )
                                            ,0
                                            );
                  END IF;
               END IF;   -- pricing='Y'  OK
            ELSE
               l_discount := 0;   --kestus oli lühem, kui vajaminev periood
            END IF;   --chg_duration,0)<p_chg_duration then
         ELSE   --chg_duration is null
            -----
            IF NVL (p_cadc.DURATION, 0) > 0 THEN
               l_chg_duration := LEAST (p_chg_duration, p_cadc.DURATION);
            ELSE
               l_chg_duration := p_chg_duration;
            END IF;

            --
            IF NVL (l_chg_duration, 0) > 0 THEN
               l_discount :=   l_chg_duration * l_price_sek
                             - GREATEST ((LEAST ((l_chg_duration * l_minimum_price), l_chg_duration * l_price_sek)), 0);
            ELSE
               l_discount := p_price - GREATEST ((LEAST ((l_minimum_price), p_price)), 0);
            END IF;
         --
         END IF;   --chg_duration is (not) null OK

         --
         IF p_cadc.DURATION IS NULL THEN
            p_disc_duration := NULL;
         ELSE
            p_disc_duration := l_chg_duration;
         END IF;

         p_disc_amount := LEAST (l_discount, p_price);
      END IF;   -- if minimum_price or precentage is not null;
   END calculate_one_amount;

   --------------------------------------------------------------------------------------
   --------------------------------------------------------------------------------------
   PROCEDURE sum_end_discount (
      p_susg_ref_num       NUMBER
     ,p_cadc_ref_num       NUMBER
     ,p_success       OUT  BOOLEAN
     ,p_text          OUT  VARCHAR2
   ) IS
      /*************************************************************************
      *   T.Hipeli  18.03.2002
      *  Leiab arvutatud ja saadud soodustuse rahalise summa ja kirjutab selle
      *  subs_discounts.amt_eek
      **************************************************************************/
      CURSOR c_sudi IS
         SELECT sudi.ref_num   -- seda saab olla ainult 1 kui tullakse susgi ja cadciga
           FROM subs_discounts sudi
          WHERE sudi.susg_ref_num = p_susg_ref_num AND sudi.cadc_ref_num = p_cadc_ref_num;

      --
      CURSOR c_dica (
         p_sudi_ref  NUMBER
      ) IS
         SELECT SUM (NVL (dica.call_discount, 0) + NVL (dica.sum_inp_disc, 0)) discount
           FROM disc_call_amounts dica
          WHERE dica.susg_ref_num = p_susg_ref_num
            AND dica.cadc_ref_num = p_cadc_ref_num
            AND dica.sudi_ref_num = p_sudi_ref;

      l_discount                    disc_call_amounts.call_discount%TYPE;
   BEGIN
      FOR i IN c_sudi LOOP
         FOR j IN c_dica (i.ref_num) LOOP
            UPDATE subs_discounts
               SET eek_amt = j.discount
             WHERE ref_num = i.ref_num;
         END LOOP;
      END LOOP;

      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_text := 'Sum_end_discount ' || SQLERRM;
         p_success := FALSE;
   END sum_end_discount;

   ------------------------------------------------------------------------------
   PROCEDURE sum_end_one_discount (
      p_sudi_ref_num       NUMBER   -- 389026
     ,p_success       OUT  BOOLEAN
     ,p_text          OUT  VARCHAR2
   ) IS
      /*************************************************************************
      *   T.Hipeli  18.03.2002
      *  Leiab ühe soodustuse piires: arvutatud ja saadud soodustuse rahalise summa
      *     ja kirjutab selle subs_discounts.amt_eek
      **************************************************************************/
      CURSOR c_dica IS
         SELECT SUM (NVL (dica.call_discount, 0) + NVL (dica.sum_inp_disc, 0)) discount
           FROM disc_call_amounts dica
          WHERE dica.sudi_ref_num = p_sudi_ref_num;

      l_discount                    NUMBER := 0;
   --
   BEGIN
      FOR i IN c_dica LOOP
         UPDATE subs_discounts
            SET eek_amt = i.discount
          WHERE ref_num = p_sudi_ref_num;
      END LOOP;

      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_text := 'Sum_end_one_discount ' || SQLERRM;
         p_success := FALSE;
   END sum_end_one_discount;

   --
   PROCEDURE insert_inen (
      p_inen        IN OUT NOCOPY  invoice_entries%ROWTYPE
     ,p_success     OUT            BOOLEAN
     ,p_error_text  OUT            VARCHAR2
   ) IS
   BEGIN
      IF p_inen.ref_num IS NULL THEN
         SELECT inen_ref_num_s.NEXTVAL
           INTO p_inen.ref_num
           FROM SYS.DUAL;
      END IF;

      IF (p_inen.created_by IS NULL) THEN
         p_inen.created_by := sec.get_username;
      END IF;

      IF (p_inen.date_created IS NULL) THEN
         p_inen.date_created := SYSDATE;
      END IF;

      p_inen.acc_amount := ROUND (p_inen.acc_amount, get_inen_acc_precision);   -- CHG4594

      INSERT INTO invoice_entries inen
                  (ref_num   --NOT NULL NUMBER(10)
                  ,invo_ref_num   --NOT NULL NUMBER(10)
                  ,acc_amount   -- CHG4594
                  ,rounding_indicator   --NOT NULL VARCHAR2(1)
                  ,under_dispute   --NOT NULL VARCHAR2(1)
                  ,created_by   --NOT NULL VARCHAR2(15)
                  ,date_created   --NOT NULL DATE
                  ,billing_selector   --         VARCHAR2(3)
                  ,fcit_type_code   --         VARCHAR2(3)
                  ,taty_type_code   --         VARCHAR2(3)
                  ,susg_ref_num   --         NUMBER(10)
                  ,description   --         VARCHAR2(60)
                  ,manual_entry   --         VARCHAR2(1)
                  ,evre_count   --         NUMBER
                  ,evre_duration   --         NUMBER
                  ,module_ref   --         VARCHAR2(4)
                  ,print_required   --         VARCHAR2(1)
                  ,num_of_days
                  ,cadc_ref_num
                  ,fcdt_type_code
                  ,amt_tax
                  ,maas_ref_num   -- CHG-498
                  ,pri_curr_code
                  ,additional_entry_text  -- mobet-23
                  )
           VALUES (p_inen.ref_num
                  ,p_inen.invo_ref_num
                  ,p_inen.acc_amount   -- CHG4594
                  ,NVL (p_inen.rounding_indicator, 'N')
                  ,NVL (p_inen.under_dispute, 'N')
                  ,NVL (p_inen.created_by, sec.get_username)
                  ,NVL (p_inen.date_created, SYSDATE)
                  ,p_inen.billing_selector
                  ,p_inen.fcit_type_code
                  ,p_inen.taty_type_code
                  ,p_inen.susg_ref_num
                  ,p_inen.description
                  ,NVL (p_inen.manual_entry, 'N')
                  ,p_inen.evre_count
                  ,p_inen.evre_duration
                  ,NVL (p_inen.module_ref, g_module_ref)
                  ,p_inen.print_required
                  ,p_inen.num_of_days
                  ,p_inen.cadc_ref_num
                  ,p_inen.fcdt_type_code
                  ,p_inen.amt_tax
                  ,p_inen.maas_ref_num   -- CHG-498
                  ,p_inen.pri_curr_code
                  ,p_inen.additional_entry_text  --mobet-23
                  )
        RETURNING eek_amt   -- CHG4594
             INTO p_inen.eek_amt /* CHG4594 */;

      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
   END insert_inen;

   --
   PROCEDURE insert_inen_int (
      p_inen        IN OUT NOCOPY  invoice_entries%ROWTYPE
     ,p_success     OUT            BOOLEAN
     ,p_error_text  OUT            VARCHAR2
   ) IS
   BEGIN
      IF p_inen.ref_num IS NULL THEN
         SELECT inen_ref_num_s.NEXTVAL
           INTO p_inen.ref_num
           FROM SYS.DUAL;
      END IF;

      IF (p_inen.created_by IS NULL) THEN
         p_inen.created_by := sec.get_username;
      END IF;

      IF (p_inen.date_created IS NULL) THEN
         p_inen.date_created := SYSDATE;
      END IF;

      p_inen.acc_amount := ROUND (p_inen.acc_amount, get_inen_acc_precision);   -- CHG4594
      p_inen.eek_amt := ROUND (p_inen.acc_amount, 2);   -- CHG4594

      INSERT INTO invoice_entries_interim inen
                  (ref_num   --NOT NULL NUMBER(10)
                  ,invo_ref_num   --NOT NULL NUMBER(10)
                  ,eek_amt   -- NOT NULL NUMBER(14,2)
                  ,rounding_indicator   --NOT NULL VARCHAR2(1)
                  ,under_dispute   --NOT NULL VARCHAR2(1)
                  ,created_by   --NOT NULL VARCHAR2(15)
                  ,date_created   --NOT NULL DATE
                  ,billing_selector   --         VARCHAR2(3)
                  ,fcit_type_code   --         VARCHAR2(3)
                  ,taty_type_code   --         VARCHAR2(3)
                  ,susg_ref_num   --         NUMBER(10)
                  ,description   --         VARCHAR2(60)
                  ,manual_entry   --         VARCHAR2(1)
                  ,evre_count   --         NUMBER
                  ,evre_duration   --         NUMBER
                  ,module_ref   --         VARCHAR2(4)
                  ,print_required   --         VARCHAR2(1)
                  ,num_of_days
                  ,cadc_ref_num
                  ,fcdt_type_code
                  ,amt_tax
                  ,maas_ref_num   -- CHG-498
                  ,curr_code
                  )
           VALUES (p_inen.ref_num
                  ,p_inen.invo_ref_num
                  ,p_inen.eek_amt
                  ,NVL (p_inen.rounding_indicator, 'N')
                  ,NVL (p_inen.under_dispute, 'N')
                  ,NVL (p_inen.created_by, sec.get_username)
                  ,NVL (p_inen.date_created, SYSDATE)
                  ,p_inen.billing_selector
                  ,p_inen.fcit_type_code
                  ,p_inen.taty_type_code
                  ,p_inen.susg_ref_num
                  ,p_inen.description
                  ,NVL (p_inen.manual_entry, 'N')
                  ,p_inen.evre_count
                  ,p_inen.evre_duration
                  ,NVL (p_inen.module_ref, g_module_ref)
                  ,p_inen.print_required
                  ,p_inen.num_of_days
                  ,p_inen.cadc_ref_num
                  ,p_inen.fcdt_type_code
                  ,p_inen.amt_tax
                  ,p_inen.maas_ref_num   -- CHG-498
                  ,p_inen.pri_curr_code
                  );

      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
   END insert_inen_int;

   ----------------------------------------------------------------------------------
   PROCEDURE carry_discount_to_entry (
      p_invo               invoices%ROWTYPE
     ,p_maac_ref_num       accounts.ref_num%TYPE
     ,p_susg_ref_num       subs_serv_groups.ref_num%TYPE
     ,p_error         OUT  VARCHAR2
     ,p_success       OUT  BOOLEAN
   ) IS
      /*********************************************************
        T.Hipeli  27.03.2002  UPR 1991
        Kannab soodustuse arve-reale
      **********************************************************/
      CURSOR c_all_dica (
         p_created_bill_period  NUMBER
      ) IS
         SELECT dica.*
           FROM disc_call_amounts dica, subs_discounts sudi
          WHERE dica.susg_ref_num = sudi.susg_ref_num
            AND dica.sudi_ref_num = sudi.ref_num
            AND sudi.reason_code IS NULL   --
            AND dica.maac_ref_num = p_maac_ref_num
            AND dica.susg_ref_num = NVL (p_susg_ref_num, dica.susg_ref_num)
            AND dica.created_bill_period = p_created_bill_period
            AND dica.discount_type = 'MON';

      --
      CURSOR c_inen_fcit (
         p_for_fcit_type_code  VARCHAR2
        ,p_susg_ref_num        NUMBER
      ) IS
         SELECT ref_num
               ,acc_amount   -- CHG4594
               ,ROWID
               ,ADDITIONAL_ENTRY_TEXT  --mobet-23
           FROM invoice_entries
          WHERE invo_ref_num = p_invo.ref_num
            AND susg_ref_num = p_susg_ref_num
            AND fcit_type_code = p_for_fcit_type_code
            AND (manual_entry = 'N' OR manual_entry IS NULL);

      --
      CURSOR c_inen_cadc (
         p_cadc_ref_num    NUMBER
        ,p_fcdt_type_code  VARCHAR2
        ,p_susg_ref_num    NUMBER
      ) IS
         SELECT ref_num
               ,acc_amount   -- CHG4594
               ,ROWID
           FROM invoice_entries
          WHERE invo_ref_num = p_invo.ref_num
            AND susg_ref_num = p_susg_ref_num
            AND cadc_ref_num = p_cadc_ref_num
            AND fcdt_type_code = p_fcdt_type_code
            AND (manual_entry = 'N' OR manual_entry IS NULL);

      --
      CURSOR c_cadc (
         p_cadc_ref_num  NUMBER
      ) IS
         SELECT *
           FROM call_discount_codes
          WHERE ref_num = p_cadc_ref_num;

      --
      CURSOR c_fcdt (
         p_fcit_type_code  VARCHAR2
      ) IS
         SELECT fcdt_type_code
           FROM fixed_charge_item_types
          WHERE type_code = p_fcit_type_code;

      --
      l_cadc                        call_discount_codes%ROWTYPE;
      l_inen                        invoice_entries%ROWTYPE;
      l_inen_ref_num                invoice_entries.ref_num%TYPE;
      l_discount_amt                invoice_entries.acc_amount%TYPE;   -- CHG4594 (tüüp)
      l_acc_amt                     invoice_entries.acc_amount%TYPE;   -- CHG4594
      l_num_of_days                 NUMBER;
      l_print                       invoice_entries.print_required%TYPE;
      l_module_ref                  invoice_entries.module_ref%TYPE := 'U847';
      l_fcdt_type_code              fixed_charge_item_types.fcdt_type_code%TYPE;
      l_bill_period                 invoices.invo_sequence%TYPE;
      l_inen_exists                 BOOLEAN;
      l_inen_rowid                  VARCHAR2 (30);
      l_additional_entry_text       invoice_entries.additional_entry_text%TYPE := null;
      --
      e_cadc_not_exists             EXCEPTION;
      e_unknown_invo_type           EXCEPTION;
      e_too_long_period             EXCEPTION;
      e_inen                        EXCEPTION;
   --e_negative_amount EXCEPTION;
   --
   BEGIN
      --dbms_output.put_line('CARRY: START');
      -- leiame created_bill_period'i
      IF p_invo.invoice_type = 'INB' THEN
         l_bill_period := p_invo.invo_sequence;
      ELSIF p_invo.invoice_type = 'INT' THEN
         l_bill_period := TO_NUMBER (TO_CHAR (p_invo.invo_start, 'yyyymm'));
      ELSIF p_invo.invoice_type = 'INP' THEN   -- võtame eelmise kuu
         l_bill_period := TO_NUMBER (TO_CHAR (ADD_MONTHS (p_invo.invo_start, -1), 'yyyymm'));
      END IF;

      --
      FOR rec_dica IN c_all_dica (l_bill_period) LOOP
         -- dbms_output.put_line('CARRY: Loop start');
         l_inen_ref_num := NULL;
         l_print := NULL;

         -- leiame cacd-i andmed
         OPEN c_cadc (rec_dica.cadc_ref_num);

         FETCH c_cadc
          INTO l_cadc;

         IF c_cadc%NOTFOUND THEN
            RAISE e_cadc_not_exists;

            CLOSE c_cadc;
         END IF;

         CLOSE c_cadc;

         /*
               dbms_output.put_line('CARRY: cadc.bill_period      ' || l_bill_period);
                 dbms_output.put_line('CARRY: cadc.crm              ' || l_cadc.crm);
                 dbms_output.put_line('CARRY: cadc.print_required  ' || l_cadc.print_required);
                 dbms_output.put_line('CARRY: cadc.ref_num     ' || rec_dica.cadc_ref_num);
             dbms_output.put_line('CARRY: cadc.dica_ref_num     ' || rec_dica.ref_num);
                 dbms_output.put_line('CARRY: cadc.interim_disc     ' || rec_dica.interim_disc);
                 dbms_output.put_line('CARRY: cadc.int_dur_discount ' || rec_dica.int_dur_discount);
             dbms_output.put_line('CARRY: cadc.sum_int_dur_discount ' || rec_dica.sum_int_dur_discount);
                 dbms_output.put_line('CARRY: cadc.sum_inp_disc     ' || rec_dica.sum_inp_disc);
                 dbms_output.put_line('CARRY: cadc.call_discount    ' || rec_dica.call_discount);
                 dbms_output.put_line('CARRY: cadc.inp_dur_discount ' || rec_dica.inp_dur_discount);
                 dbms_output.put_line('CARRY: cadc.sum_interim_disc ' || rec_dica.sum_interim_disc);
                 dbms_output.put_line('CARRY: cadc.min_discount     ' || rec_dica.min_discount);
                 */
         -------------------------------------------------
         -- leiame summad vastavalt arvetüübile
         -------------------------------------------------
         IF p_invo.invoice_type = 'INT' THEN
            l_discount_amt := NVL (rec_dica.interim_disc, 0);
            l_num_of_days := NVL (rec_dica.int_dur_discount, 0);
         ELSIF p_invo.invoice_type = 'INP' THEN
            l_discount_amt := GREATEST ((NVL (rec_dica.sum_inp_disc, 0) - NVL (rec_dica.call_discount, 0)), 0);
            l_num_of_days := GREATEST ((NVL (rec_dica.inp_dur_discount, 0) - NVL (rec_dica.min_discount, 0)), 0);
         ELSIF p_invo.invoice_type = 'INB' THEN
            l_discount_amt := NVL (rec_dica.call_discount, 0) - NVL (rec_dica.sum_interim_disc, 0);
            l_num_of_days := NVL (rec_dica.min_discount, 0) - NVL (rec_dica.sum_int_dur_discount, 0);
         ELSE
            RAISE e_unknown_invo_type;
         END IF;

         --  dbms_output.put_line('CARRY: invo_type    ' || p_invo.invoice_type);
         --  dbms_output.put_line('CARRY: discount_amt ' || TO_CHAR(l_discount_amt));
           --    dbms_output.put_line('CARRY: num_of_days  ' || TO_CHAR(l_num_of_days));
         -- kui päevade arv on kolmekohaline, siis on soodustuse periood on üleliia pikk
         IF l_num_of_days > 99 THEN
            RAISE e_too_long_period;
         END IF;

         /*
           ** UPR-3124: Kontrollime, kas originaalrida, mille kohta soodustus käib, on arvel või
           **           mitte (seoses ühise kuutasuga võib arvele üldsegi mitte tulla). Kui originaalrida arvel
           **           pole, siis ei tohi ka soodustust sinna kanda.
         */
         OPEN c_inen_fcit (l_cadc.for_fcit_type_code, rec_dica.susg_ref_num);

         FETCH c_inen_fcit
          INTO l_inen_ref_num
              ,l_acc_amt
              ,l_inen_rowid
              ,l_additional_entry_text -- mobet-23  Kui lisainfo on täidetud, siis selle jätame meelde, et lisada sama soodustuse arvereale
              ;

         l_inen_exists := c_inen_fcit%FOUND;

         CLOSE c_inen_fcit;

         --
         IF l_inen_exists THEN
            -------------------------------------------------
            -- käime üle arveridade fcit järgi
            -------------------------------------------------
            IF l_cadc.crm = 'N' THEN
               /* -- kontrollime, kas arverida jääb positiivseks  -- vastavalt H.L väitele võib inen tulla negatiivne
                  IF (NVL(l_acc_amt,0) - l_discount_amt) < 0 THEN
                     RAISE e_negative_amount;
                  END IF;
               */
               --
               -- 0 lõppsummaga rida pole vaja hoida / kui rida läheb miinusesse on tegelikult ERROR
               IF l_cadc.print_required = 'N' AND (NVL (l_acc_amt, 0) - l_discount_amt) <= 0 THEN
                  DELETE FROM invoice_entries
                        WHERE ROWID = l_inen_rowid;
               ELSE
                  UPDATE invoice_entries
                     SET acc_amount = ROUND (NVL (l_acc_amt, 0) - l_discount_amt, get_inen_acc_precision)   -- CHG4594
                        ,print_required = 'Y'
                   WHERE ROWID = l_inen_rowid;
               END IF;
            END IF;   -- l_cadc.crm ='N '

            ------------------------------------------------------------
            --  käime üle arveridade cadc-i ja fcdt-ga
            ------------------------------------------------------------
            IF l_cadc.crm = 'Y' THEN   --trükime arvele eraldi real
               -- leiame fikseeritud makse soodustuse domain value
               OPEN c_fcdt (l_cadc.for_fcit_type_code);

               FETCH c_fcdt
                INTO l_fcdt_type_code;

               CLOSE c_fcdt;

               --
               OPEN c_inen_cadc (l_cadc.ref_num, l_fcdt_type_code, rec_dica.susg_ref_num);

               FETCH c_inen_cadc
                INTO l_inen_ref_num
                    ,l_acc_amt
                    ,l_inen_rowid;

               l_inen_exists := c_inen_cadc%FOUND;

               --     dbms_output.put_line('CARRY: Y: found inen '||to_char(l_inen_ref_num) || ' eek '|| TO_CHAR(l_eek_amt));
               CLOSE c_inen_cadc;

               /* -- kontrollime, kas arverida jääb positiivseks
                  IF (NVL(l_eek_amt,0) - l_discount_amt) < 0 THEN
                  RAISE e_negative_amount;
                END IF;*/-------------------------------------------------------
                     -- vaatame, kas teeme UPDATE või inserdime uue arverea
                     --------------------------------------------------------
               IF l_inen_exists THEN
                  IF l_cadc.print_required = 'N' AND (NVL (l_acc_amt, 0) - l_discount_amt) = 0 THEN
                     l_print := NULL;
                  ELSE
                     l_print := 'Y';
                  END IF;

                  --
                  UPDATE invoice_entries
                     SET acc_amount = ROUND (NVL (l_acc_amt, 0) - l_discount_amt, get_inen_acc_precision)   -- CHG4594
                        ,print_required = l_print
                   WHERE ROWID = l_inen_rowid;
               --dbms_output.put_line('CARRY: Y: update inen '|| TO_CHAR(l_inen_ref_num) || ' print ' || l_print);
               ELSE
                  IF l_cadc.print_required = 'N' AND l_discount_amt = 0 THEN
                     l_print := NULL;
                  ELSE
                     l_print := 'Y';
                  END IF;

                  --
                  l_inen := NULL;
                  l_inen.invo_ref_num := p_invo.ref_num;
                  l_inen.acc_amount := ROUND (-1 * l_discount_amt, get_inen_acc_precision);   -- CHG4594
                  l_inen.billing_selector := l_cadc.disc_billing_selector;
                  l_inen.susg_ref_num := rec_dica.susg_ref_num;
                  l_inen.taty_type_code := l_cadc.taty_type_code;
                  l_inen.module_ref := l_module_ref;
                  l_inen.print_required := l_print;
                  l_inen.cadc_ref_num := l_cadc.ref_num;
                  l_inen.fcdt_type_code := l_fcdt_type_code;
                  l_inen.pri_curr_code := get_pri_curr_code ();
                  l_inen.additional_entry_text := l_additional_entry_text; -- mobet-23
                  insert_inen (l_inen, p_success, p_error);

                  IF NOT p_success THEN
                     RAISE e_inen;
                  END IF;
               --      dbms_output.put_line('CARRY Y: inserted inen '|| TO_CHAR(l_inen.ref_num));
               END IF;
            END IF;   -- l_cadc.crm='Y'
         END IF;   --   IF l_inen_exists THEN

         --
         IF p_invo.invoice_type = 'INP' THEN   -- uuendame ka dica-t
            UPDATE disc_call_amounts
               SET inp_dur_discount = inp_dur_discount - min_discount
                  ,sum_inp_disc = sum_inp_disc - call_discount
             WHERE ref_num = rec_dica.ref_num;
         --     dbms_output.put_line('CARRY: update dica '|| rec_dica.ref_num);
         END IF;
      END LOOP;

      p_success := TRUE;
      p_error := NULL;
   EXCEPTION
      WHEN e_cadc_not_exists THEN
         p_success := FALSE;
         p_error := 'Carry_Discount_To_Entry - cadc does NOT exists';
      WHEN e_inen THEN
         p_success := FALSE;
         p_error := 'Insert Inen: ' || p_error;
      WHEN e_unknown_invo_type THEN
         p_success := FALSE;
         p_error := 'Carry_Discount_To_Entry - Unknown invo type';
      WHEN e_too_long_period THEN
         p_success := FALSE;
         p_error := 'Carry_Discount_To_Entry - Discount period longer than 99 days';
      /*  WHEN e_negative_amount THEN
           p_success:=false;
         p_error   := 'Carry_Discount_To_Entry - Inve eek_am negative after discount';
      */
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error := 'Carry_Discount_To_Entry ' || SQLERRM;
   END carry_discount_to_entry;

   ------------------------------------------
   PROCEDURE insert_dica (
      p_dica        IN OUT NOCOPY  disc_call_amounts%ROWTYPE
     ,p_success     OUT            BOOLEAN
     ,p_error_text  OUT            VARCHAR2
   ) IS
   BEGIN
      IF p_dica.ref_num IS NULL THEN
         SELECT dica_ref_num_s.NEXTVAL
           INTO p_dica.ref_num
           FROM SYS.DUAL;
      END IF;

      IF (p_dica.date_created IS NULL) THEN
         p_dica.date_created := SYSDATE;
      END IF;

      INSERT INTO disc_call_amounts dica
                  (dica.ref_num   --NOT NULL NUMBER(10)
                  ,dica.maac_ref_num   --NOT NULL NUMBER(10)
                  ,dica.susg_ref_num   --NOT NULL NUMBER(10)
                  ,dica.call_type   --         VARCHAR2(3)
                  ,dica.created_bill_period   --         NUMBER(6)
                  ,dica.call_discount   --         NUMBER(14,2)
                  ,dica.date_created   --         DATE
                  ,dica.date_updated   --         DATE
                  ,dica.invo_ref_num   --         NUMBER(10)
                  ,dica.cadc_ref_num   --NOT NULL NUMBER(10)
                  ,dica.sudi_ref_num   --         NUMBER(10)
                  ,dica.min_discount   --         NUMBER(10)
                  ,dica.discount_type   --         VARCHAR2(4)
                  ,dica.sum_interim_disc   --         NUMBER(10,2)
                  ,dica.interim_disc   --         NUMBER(10,2)
                  ,dica.eek_amt   --         NUMBER(10,2)
                  ,dica.calculate_count   --         NUMBER(6)
                  ,dica.sum_int_dur_discount   --         NUMBER(10)
                  ,dica.int_dur_discount   --         NUMBER(10)
                  ,dica.inp_dur_discount   --         NUMBER(10)
                  ,dica.sum_inp_disc   --         NUMBER(14,2)
                  ,dica.for_fcit_type_code   --         VARCHAR2(3)
                  ,dica.reason_code   -- CHG-1634
                  )
           VALUES (p_dica.ref_num
                  ,p_dica.maac_ref_num
                  ,p_dica.susg_ref_num
                  ,p_dica.call_type
                  ,p_dica.created_bill_period
                  ,p_dica.call_discount
                  ,p_dica.date_created
                  ,p_dica.date_updated
                  ,p_dica.invo_ref_num
                  ,p_dica.cadc_ref_num
                  ,p_dica.sudi_ref_num
                  ,p_dica.min_discount
                  ,p_dica.discount_type
                  ,p_dica.sum_interim_disc
                  ,p_dica.interim_disc
                  ,p_dica.eek_amt
                  ,p_dica.calculate_count
                  ,p_dica.sum_int_dur_discount
                  ,p_dica.int_dur_discount
                  ,p_dica.inp_dur_discount
                  ,p_dica.sum_inp_disc
                  ,p_dica.for_fcit_type_code
                  ,p_dica.reason_code   -- CHG-1634
                  );

      p_success := TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
   END insert_dica;

   --
   PROCEDURE setup_cadc_completed (
      p_cadc_ref_num  IN      NUMBER
     ,p_error_text    IN OUT  VARCHAR2
     ,p_success       IN OUT  BOOLEAN
   ) IS
      --  ---------------------------------------------------------------------
      --  CADC: kas soodustuse sulgemise protseduuri võib siin üldse rakendada?
      --  ---------------------------------------------------------------------
      CURSOR c_cadc IS
         SELECT cadc.ref_num
           FROM call_discount_codes cadc
          WHERE cadc.end_date < SYSDATE
            AND cadc.end_date IS NOT NULL
            AND cadc.call_type IN ('CALL', 'MON', 'MIN')
            AND cadc.ref_num = p_cadc_ref_num
            AND NVL (cadc.discount_completed, 'N') = 'N';

      --  --------------------------------------------------------------
      --  Loe summa SUDI'st: kas praegu on summa sudi.eek_amt NULL?
      --  --------------------------------------------------------------
      CURSOR c_sudi IS
         SELECT sudi.*
           FROM subs_discounts sudi
          WHERE sudi.cadc_ref_num = p_cadc_ref_num
                                                  --AND  sudi.eek_amt IS NULL
                AND NVL (sudi.closed, 'N') = 'N';

      --  ---------------------------------------------------------------------
      --  Loe summa DICA'st: kui palju on soodustust saanud just selle SUDI'ga?
      --  ---------------------------------------------------------------------
      CURSOR c_dica (
         p_susg_ref_num  IN  NUMBER
        ,p_sudi_ref_num  IN  NUMBER
      ) IS
         SELECT SUM (NVL (dica.call_discount, 0))   -- + sum_interim_disc ..
           FROM disc_call_amounts dica
          WHERE dica.susg_ref_num = p_susg_ref_num
            AND dica.sudi_ref_num = p_sudi_ref_num   -- see sudi
            AND dica.cadc_ref_num = p_cadc_ref_num;

      l_cadc                        call_discount_codes%ROWTYPE;
      l_sudi                        subs_discounts%ROWTYPE;
      --l_dica               disc_call_amounts%ROWTYPE;
      l_dica_call_discount          disc_call_amounts.call_discount%TYPE;
      l_found                       BOOLEAN;
      e_update_sudi                 EXCEPTION;
   BEGIN
      -- dbms_output.enable(100000);
      p_success := FALSE;

      OPEN c_cadc;

      FETCH c_cadc
       INTO l_cadc.ref_num;

      l_found := c_cadc%FOUND;

      CLOSE c_cadc;

      -- dbms_output.put_line('.. cadc: ' || to_char(l_cadc.ref_num));
      IF l_found THEN
         --  -----------------------------------------------------------------------
         --  Leia kõik aktiivsed SUDI'd, mille eek_amt IS NULL
         --  -----------------------------------------------------------------------
         FOR l_sudi IN c_sudi LOOP
            OPEN c_dica (l_sudi.susg_ref_num, l_sudi.ref_num);

            FETCH c_dica
             INTO l_dica_call_discount;

            l_found := c_dica%FOUND;

            CLOSE c_dica;

            --      dbms_output.put_line('.. susg: ' || to_char(l_sudi.susg_ref_num) || '  sudi: ' || to_char(l_sudi.ref_num));
            IF l_found THEN
               --        dbms_output.put_line('.. ok: ' || to_char(l_dica_call_discount));
               UPDATE subs_discounts sudi
                  SET eek_amt = l_dica_call_discount
                     --,closed  = 'Y'
                     --,end_date = SYSDATE
               ,      date_updated = SYSDATE
                     ,last_updated_by = sec.get_username
                WHERE ref_num = l_sudi.sudi_ref_num;

               IF NVL (p_success, TRUE) = FALSE THEN
                  RAISE e_update_sudi;
               END IF;
            END IF;
         END LOOP;

         COMMIT;
         p_success := TRUE;
      END IF;
   EXCEPTION
      WHEN e_update_sudi THEN
         p_success := FALSE;
         p_error_text := 'Error when updating subscriber discount for susg = ' || l_sudi.susg_ref_num || '. '
                         || SQLERRM;
      WHEN OTHERS THEN
         p_success := FALSE;
         p_error_text := SQLERRM;
   END setup_cadc_completed;

   --
   PROCEDURE validate_manual_discount (
      p_discount_code   IN      VARCHAR2
     ,p_maac_ref_num    IN      accounts.ref_num%TYPE
     ,p_deal_ref_num    IN      parties.ref_num%TYPE
     ,p_region          IN      dealer_offices.region_code%TYPE
     ,p_deof_ref_num    IN      dealer_offices.ref_num%TYPE
     ,p_channel_type    IN      VARCHAR2
     ,p_active_date     IN      DATE
     ,p_susg_ref_num    IN      subs_serv_groups.ref_num%TYPE
     ,p_success         IN OUT  BOOLEAN
     ,p_dico_rec        OUT     discount_codes%ROWTYPE
     ,p_sept_type_code  IN      serv_package_types.type_code%TYPE DEFAULT NULL
   ) IS
      --
      CURSOR c_dico (
         p_month_of_serv       IN  NUMBER
        ,p_part_month_of_serv  IN  NUMBER
        ,p_party_type          IN  VARCHAR2
      ) IS
         SELECT *
           FROM discount_codes dico
          WHERE dico.discount_code = p_discount_code
            AND TRUNC (p_active_date) BETWEEN dico.start_date AND NVL (dico.end_date, p_active_date)
            AND dico.MANUAL = 'Y'
            AND NVL (dico.allowed_count, NVL (dico.given_count, 0)) >= NVL (dico.given_count, 0)
            AND NVL (dico.mobile_part, 'A') = 'A'
            AND NVL (dico.month_of_serv, NVL (p_month_of_serv, 0)) <= NVL (p_month_of_serv, 0)
            AND NVL (dico.part_month_of_serv, NVL (p_part_month_of_serv, 0)) <= NVL (p_part_month_of_serv, 0)
            AND NVL (dico.party_type, NVL (p_party_type, '*')) = NVL (p_party_type, '*')
            /*dobas-1217 AND NOT EXISTS (SELECT 1
                              FROM discount_allowed_list dial
                             WHERE dial.dico_ref_num = dico.ref_num
                               AND (   dial.package_category IS NOT NULL
                                    OR dial.sety_ref_num IS NOT NULL
                                    OR dial.pack_type_code IS NOT NULL
                                   ))*/
                                   ;

      --
      l_found                       BOOLEAN;
      l_chca_type_code              accounts.chca_type_code%TYPE;
      l_bicy_cycle_code             accounts.bicy_cycle_code%TYPE;
      l_month_of_serv               accounts.month_of_serv%TYPE;
      l_party_type                  parties.party_type%TYPE;
      l_stat_ref_num                accounts.stat_ref_num%TYPE;
      l_part_month_of_serv          parties.month_of_serv%TYPE;
      l_new_mobile                  BOOLEAN;
      l_vmct_maac_type              statements.vmct_maac_type%TYPE;
   BEGIN
      l_found := calculate_discounts.get_part_maac_data (p_maac_ref_num
                                                        ,l_chca_type_code
                                                        ,l_bicy_cycle_code
                                                        ,l_month_of_serv
                                                        ,l_party_type
                                                        ,l_stat_ref_num
                                                        ,l_part_month_of_serv
                                                        );

      OPEN c_dico (l_month_of_serv, l_part_month_of_serv, l_party_type);

      FETCH c_dico
       INTO p_dico_rec;

      l_found := c_dico%FOUND;

      CLOSE c_dico;

      --
      IF l_found THEN
         IF p_susg_ref_num IS NOT NULL THEN
            l_new_mobile := FALSE;

            --
            IF l_stat_ref_num IS NOT NULL THEN
               l_found := get_vmct_maac_type (l_stat_ref_num, l_vmct_maac_type);
            END IF;
         ELSE
            l_new_mobile := TRUE;
         END IF;

         --
         p_success := calculate_discounts.chk_apply_discount (p_dico_rec
                                                             ,p_susg_ref_num
                                                             ,p_maac_ref_num
                                                             ,p_deal_ref_num
                                                             ,p_region
                                                             ,p_deof_ref_num
                                                             ,p_channel_type
                                                             ,l_chca_type_code
                                                             ,l_bicy_cycle_code
                                                             ,TRUNC (p_active_date)
                                                             ,l_new_mobile
                                                             ,l_vmct_maac_type
                                                             ,p_sept_type_code
                                                             );
      ELSE
         p_success := FALSE;
      END IF;
   END validate_manual_discount;

   --
   FUNCTION chk_apply_package (
      p_dico_ref_num    IN  discount_codes.ref_num%TYPE
     ,p_susg_ref_num    IN  subs_serv_groups.ref_num%TYPE
     ,p_sept_type_code  IN  serv_package_types.type_code%TYPE
   )
      RETURN BOOLEAN IS
      --
      CURSOR c_cat (
         p_sept_type_code  VARCHAR2
      ) IS
         SELECT CATEGORY
               ,nety_type_code
           FROM serv_package_types
          WHERE type_code = p_sept_type_code;

      --
      CURSOR c_sept (
         p_susg_ref_num  NUMBER
      ) IS
         SELECT sept_type_code
           FROM subs_packages
          WHERE gsm_susg_ref_num = p_susg_ref_num AND end_date IS NULL;

      --
      CURSOR c_apply_package (
         p_category        VARCHAR2
        ,p_nety_type_code  VARCHAR2
        ,p_sept_type_code  VARCHAR2
      ) IS
         SELECT 'N'
           FROM discount_codes d
          WHERE EXISTS (SELECT 1
                          FROM discount_allowed_list
                         WHERE dico_ref_num = p_dico_ref_num
                           AND (   not_allowed_packages = p_sept_type_code
                                OR (not_allowed_categories = p_category AND not_allowed_cat_nety = p_nety_type_code)
                               ))
             OR (    d.doma_type_code IS NOT NULL
                 AND d.ref_num = p_dico_ref_num
                 AND EXISTS (SELECT 1
                               FROM bcc_domain_values
                              WHERE doma_type_code = d.doma_type_code
                                AND NVL (numeric_value, 0) <= NVL (d.package_impact, 99)
                                AND value_code = p_sept_type_code)
                );

      --
      l_sept_type_code              serv_package_types.type_code%TYPE;
      l_category                    serv_package_types.CATEGORY%TYPE;
      l_nety_type_code              serv_package_types.nety_type_code%TYPE;
      l_allowed                     VARCHAR2 (1);
   BEGIN
      IF p_sept_type_code IS NULL THEN
         OPEN c_sept (p_susg_ref_num);

         FETCH c_sept
          INTO l_sept_type_code;

         CLOSE c_sept;
      ELSE
         l_sept_type_code := p_sept_type_code;
      END IF;

      IF l_sept_type_code IS NULL THEN
         l_allowed := 'Y';
      ELSE
         OPEN c_cat (l_sept_type_code);

         FETCH c_cat
          INTO l_category
              ,l_nety_type_code;

         CLOSE c_cat;

         l_allowed := 'Y';

         OPEN c_apply_package (l_category, l_nety_type_code, l_sept_type_code);

         FETCH c_apply_package
          INTO l_allowed;

         CLOSE c_apply_package;

         l_allowed := NVL (l_allowed, 'Y');
      END IF;

      --dbms_output.put_line('lubatud '||l_allowed||' pakett '||l_sept_type_code);
      IF l_allowed = 'Y' THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   END chk_apply_package;

   /*
     ** M/A teenustele CONN sooodudtuste leidmise protseduur.
   */
   PROCEDURE find_ma_service_discounts (
      p_discount_type   IN      fixed_charge_types.discount_type%TYPE
     ,p_invo_ref_num    IN      invoices.ref_num%TYPE
     ,p_sety_ref_num    IN      service_types.ref_num%TYPE
     ,p_sepv_ref_num    IN      service_param_values.ref_num%TYPE   -- esialgu ei kodeeri
     ,p_maas_ref_num    IN      master_account_services.ref_num%TYPE
     ,p_charged_value   IN      NUMBER
     ,p_maac_ref_num    IN      accounts.ref_num%TYPE
     ,p_fcdt_type_code  IN      fixed_charge_item_types.fcdt_type_code%TYPE
     ,p_inen_rowid      IN      VARCHAR2
     ,p_chk_date        IN      DATE
     ,p_error_text      OUT     VARCHAR2
     ,p_success         OUT     BOOLEAN
     ,p_mode            IN      VARCHAR2 DEFAULT 'INS'   -- INS/DEL
     ,p_additional_entry_text  IN invoice_entries.additional_entry_text%TYPE DEFAULT NULL -- DOBAS-262
   ) IS
      --
      CURSOR c_maac IS
         SELECT maac.bicy_cycle_code
               ,stat.vmct_maac_type
           FROM statements stat, master_accounts_v maac
          WHERE maac.ref_num = p_maac_ref_num AND stat.ref_num(+) = maac.stat_ref_num;

      --
      CURSOR c_cadc (
         p_vmct_maac_type   IN  statements.vmct_maac_type%TYPE
        ,p_bicy_cycle_code  IN  bill_cycles.cycle_code%TYPE
      ) IS
         SELECT   cadc.*
             FROM discount_codes dico, call_discount_codes cadc
            WHERE p_chk_date BETWEEN dico.start_date AND NVL (dico.end_date, p_chk_date)
              AND dico.MANUAL = 'N'
              AND EXISTS (SELECT 1
                            FROM discount_allowed_list
                           WHERE dico_ref_num = dico.ref_num
                             AND sety_ref_num = p_sety_ref_num
                             AND p_chk_date BETWEEN NVL (start_date, p_chk_date) AND NVL (end_date, p_chk_date))
              AND (   EXISTS (SELECT 1
                                FROM discount_allowed_list
                               WHERE dico_ref_num = dico.ref_num
                                 AND vmct_maac_type = NVL (p_vmct_maac_type, '*')
                                 AND p_chk_date BETWEEN NVL (start_date, p_chk_date) AND NVL (end_date, p_chk_date))
                   OR NOT EXISTS (SELECT 1
                                    FROM discount_allowed_list
                                   WHERE dico_ref_num = dico.ref_num
                                     AND vmct_maac_type IS NOT NULL
                                     AND p_chk_date BETWEEN NVL (start_date, p_chk_date) AND NVL (end_date, p_chk_date))
                  )
              AND (   EXISTS (SELECT 1
                                FROM discount_allowed_list
                               WHERE dico_ref_num = dico.ref_num
                                 AND bicy_cycle_code = p_bicy_cycle_code
                                 AND p_chk_date BETWEEN NVL (start_date, p_chk_date) AND NVL (end_date, p_chk_date))
                   OR NOT EXISTS (SELECT 1
                                    FROM discount_allowed_list
                                   WHERE dico_ref_num = dico.ref_num
                                     AND bicy_cycle_code IS NOT NULL
                                     AND p_chk_date BETWEEN NVL (start_date, p_chk_date) AND NVL (end_date, p_chk_date))
                  )
              AND cadc.dico_ref_num = dico.ref_num
              AND cadc.call_type = p_discount_type
         ORDER BY dico.start_date;

     --DOBAS-262
     -- Kontrollib, kas koondarvel on ühekordsele teenusele kliendipõhine soodustuse kirje olemas 
     CURSOR c_chk_mase IS  
        SELECT 1
        FROM MASTER_SERVICE_ADJUSTMENTS masa
        WHERE maac_ref_num = p_maac_ref_num
          AND sety_ref_num = p_sety_ref_num
          AND sety_ref_num in (select ref_num from SERVICE_TYPES where SECL_CLASS_CODE = 'Q' and masa.SETY_REF_NUM = ref_num)
          AND maas_ref_num is null
          AND padi_ref_num is not null
          AND p_chk_date BETWEEN start_date AND NVL (end_date, p_chk_date);

     -- DOBAS-262
     
     CURSOR c_find_param_gr_id IS
     SELECT distinct sepa.nw_param_name
     FROM service_types sety, 
          service_parameters sepa
     WHERE sety.ref_num  = p_sety_ref_num
       AND sepa.sety_ref_num = sety.ref_num
       AND sepa.nw_param_name = 'GROUP_ID'
       AND p_chk_date BETWEEN sepa.start_date AND NVL (sepa.end_date, p_chk_date);
     
     -- DOBAS-262
     CURSOR c_find_serv_param IS
     SELECT distinct masp.PARAM_VALUE
       FROM master_account_services maas, 
            master_service_parameters masp, 
            service_parameters sepa,
            master_service_parameters masp_n, 
            service_parameters sepa_n,
            master_service_parameters masp_m, 
            service_parameters sepa_m,
            GPRS_EXTRA_ADDITIONAL_VOLUMES geav
      WHERE maas.ref_num = masp.maas_ref_num
        AND maas.maac_ref_num = p_maac_ref_num
        AND maas.sety_ref_num = geav.SETY_REF_NUM
        AND masp.sepa_ref_num = sepa.ref_num
        AND p_chk_date BETWEEN MASP.start_date AND NVL (MASP.end_date, p_chk_date)
        AND sepa.nw_param_name = 'GROUP_ID'
        and geav.EXTRA_SETY_REF_NUM  = p_sety_ref_num
        and geav.sety_ref_num = sepa_n.sety_ref_num
        and p_chk_date BETWEEN geav.start_date AND NVL (geav.end_date, p_chk_date)
        and sepa_n.NW_PARAM_NAME='GROUPNAME'
        and  maas.ref_num = masp_n.maas_ref_num
        and masp_n.sepa_ref_num = sepa_n.ref_num
        AND p_chk_date BETWEEN MASP_n.start_date AND NVL (MASP_n.end_date, p_chk_date)
        and nvl(masp_n.param_value,'-1') = p_additional_entry_text
        and geav.sety_ref_num = sepa_m.sety_ref_num
        and sepa_m.NW_PARAM_NAME='CHARGETYPE'
        and  maas.ref_num = masp_m.maas_ref_num
        and masp_m.sepa_ref_num = sepa_m.ref_num
        AND p_chk_date BETWEEN MASP_m.start_date AND NVL (MASP_m.end_date, p_chk_date)
        and rownum = 1;
             
      -- DOBAS-262
       CURSOR c_masa_padi_padd(p_group_id MASTER_SERVICE_ADJUSTMENTS.group_id%type  ) IS
        SELECT padd.*
        FROM MASTER_SERVICE_ADJUSTMENTS masa
            ,PARTY_DISCOUNTS padi
            ,PART_DICO_DETAILS padd
            ,CALL_DISCOUNT_CODES cadc
        WHERE masa.maac_ref_num = p_maac_ref_num
          AND masa.sety_ref_num = p_sety_ref_num
          AND masa.maas_ref_num is null
          AND masa.padi_ref_num is not null
          AND nvl(group_id,'-1') = nvl(p_group_id,'-1')
          AND p_chk_date BETWEEN masa.start_date AND NVL (masa.end_date, p_chk_date)
          AND masa.padi_ref_num = padi.ref_num
          AND padi.ref_num = padd.padi_ref_num
          AND padd.cadc_ref_num = cadc.ref_num
          AND (cadc.FOR_SEPV_REF_NUM is null 
               or (nvl(cadc.FOR_SEPV_REF_NUM,-1) = nvl(p_sepv_ref_num,-1))
               );
                
      -- DOBAS-262
      CURSOR c_cadc_padd(p_cadc_ref number) IS    
      SELECT * 
       FROM CALL_DISCOUNT_CODES 
      WHERE ref_num = p_cadc_ref;

      
       
      --
      l_bicy_cycle_code             bill_cycles.cycle_code%TYPE;
      l_vmct_maac_type              statements.vmct_maac_type%TYPE;
      l_discounted_value            NUMBER;
      l_charged_value               NUMBER;
      l_found                       BOOLEAN; -- DOBAS-262
      l_dummy                       NUMBER;  -- DOBAS-262    
      l_gr_id_param_name            service_parameters.nw_param_name%TYPE;    -- DOBAS-262
      l_grupp_id                    master_service_adjustments.group_id%type; -- DOBAS-262
      l_cadc_rec                    CALL_DISCOUNT_CODES%rowtype := null;      -- DOBAS-262     
    
      --
      
      e_processing                  EXCEPTION;
   BEGIN
      /*
        ** Leida Masterkonto programmi tüüp (HH, T+) ja arveldustsükkel.
      */
      OPEN c_maac;

      FETCH c_maac
       INTO l_bicy_cycle_code
           ,l_vmct_maac_type;

      CLOSE c_maac;

      --
      l_charged_value := p_charged_value;

      /*
        ** Leida teenusele liitumis- või lisalepingu sõlmimise kuupäeval kehtivad soodustuste CADC kirjed.
      */
      FOR l_cadc IN c_cadc (l_vmct_maac_type, l_bicy_cycle_code) LOOP
         /*
           ** Leiame rakendatava soodustuse summa.
         */
         l_discounted_value :=
            get_ma_serv_discount_amount (p_charged_value   -- p_full_chg_value   IN NUMBER
                                        ,l_charged_value   -- p_remain_chg_value IN NUMBER
                                        ,l_cadc.minimum_price   -- IN call_discount_codes.minimum_price%TYPE
                                        ,l_cadc.precentage   -- IN call_discount_codes.precentage%TYPE
                                        ,l_cadc.pricing   -- IN call_discount_codes.pricing%TYPE
                                        );
         invoice_discount (p_maas_ref_num   -- IN     master_account_services.ref_num%TYPE
                          ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                          ,p_inen_rowid   -- IN     VARCHAR2
                          ,NVL (l_discounted_value, 0)   -- IN     NUMBER
                          ,l_cadc   -- IN     call_discount_codes%ROWTYPE
                          ,p_chk_date   -- IN     DATE
                          ,p_fcdt_type_code   -- IN     fixed_charge_item_types.fcdt_type_code%TYPE
                          ,p_success   --    OUT BOOLEAN
                          ,p_error_text   --    OUT VARCHAR2
                          ,p_mode   -- IN     VARCHAR2 DEFAULT 'INS'  -- INS/DEL
                          );

         IF NOT p_success THEN
            RAISE e_processing;
         END IF;

         --
         l_charged_value := l_charged_value - NVL (l_discounted_value, 0);

         --
         IF l_charged_value <= 0 THEN
            EXIT;
         END IF;
      END LOOP;
      --
      
       -- DOBAS-262 Ühekordsete teenuste kliendipõhised soodustused
       -- 1. Kas koondarve+teenus on olemas aktiivne kirje tabelis MASA
      l_found := FALSE; 
      OPEN c_chk_mase;
      FETCH c_chk_mase INTO l_dummy;
      l_found := c_chk_mase%FOUND;
      CLOSE c_chk_mase;
      
      
      IF l_found THEN  --teenusele on soodustuse kirje olemas 
     
         l_gr_id_param_name := null;
         l_grupp_id         := null;
         --kas teenusel on parameeter group_id            
         OPEN  c_find_param_gr_id;
         FETCH c_find_param_gr_id INTO l_gr_id_param_name;
         CLOSE c_find_param_gr_id;
         
         
         IF l_gr_id_param_name =  'GROUP_ID' and p_additional_entry_text is not null THEN
            -- kui on parameeter group_id, siis p_additional_entry_text järgi otsi group_id väärtus
            -- Soodustus võib olla defineeritud teenusele või teenus+grupp_id-le
             OPEN c_find_serv_param;
            FETCH c_find_serv_param INTO l_grupp_id;
            CLOSE c_find_serv_param;
                       
         END IF;

      
         FOR rec_padd in C_MASA_PADI_PADD(l_grupp_id) LOOP
            -- otsi kirje cadc tabelist
            OPEN c_cadc_padd(rec_padd.cadc_ref_num);
            FETCH c_cadc_padd INTO l_cadc_rec;
            CLOSE c_cadc_padd;

            --Kui on PRICE is not null => p_discount_schema := Y ja minimum_price := PADD.PRICE
            IF rec_padd.PRICE is not null THEN
               l_cadc_rec.pricing    := 'Y'; 
               l_cadc_rec.minimum_price  := rec_padd.PRICE;
               l_cadc_rec.precentage := null;
               
            ELSIF rec_padd.DISC_ABSOLUTE is not null THEN
               l_cadc_rec.pricing    := 'N'; 
               l_cadc_rec.minimum_price  := rec_padd.DISC_ABSOLUTE;
               l_cadc_rec.precentage := null;
            ELSE
               l_cadc_rec.precentage := rec_padd.DISC_PERCENTAGE;      
               l_cadc_rec.pricing   := null; 
               l_cadc_rec.minimum_price := null;
            END IF;    

            l_discounted_value :=
            get_ma_serv_discount_amount (p_charged_value   -- p_full_chg_value   IN NUMBER
                                        ,l_charged_value   -- p_remain_chg_value IN NUMBER
                                        ,l_cadc_rec.minimum_price   -- IN call_discount_codes.minimum_price%TYPE
                                        ,l_cadc_rec.precentage   -- IN call_discount_codes.precentage%TYPE
                                        ,l_cadc_rec.pricing   -- IN call_discount_codes.pricing%TYPE
                                        );
            invoice_discount (p_maas_ref_num   -- IN     master_account_services.ref_num%TYPE
                             ,p_invo_ref_num   -- IN     invoices.ref_num%TYPE
                             ,p_inen_rowid     -- IN     VARCHAR2
                             ,NVL (l_discounted_value, 0)   -- IN     NUMBER
                             ,l_cadc_rec         -- IN     call_discount_codes%ROWTYPE
                             ,p_chk_date         -- IN     DATE
                             ,p_fcdt_type_code   -- IN     fixed_charge_item_types.fcdt_type_code%TYPE
                             ,p_success          --    OUT BOOLEAN
                             ,p_error_text       --    OUT VARCHAR2
                             ,p_mode             -- IN     VARCHAR2 DEFAULT 'INS'  -- INS/DEL
                            );

             IF NOT p_success THEN
                RAISE e_processing;
             END IF;

             --
             l_charged_value := l_charged_value - NVL (l_discounted_value, 0);

             --
             IF l_charged_value <= 0 THEN
                EXIT;
             END IF;
            
           
         END LOOP;
      
      END IF;
      --DOBAS-262
     
      
      
      p_success := TRUE;
   EXCEPTION
      WHEN e_processing THEN
         p_success := FALSE;
   END find_ma_service_discounts;

   /*
     ** Leiab M/A teenusele vastava soodustuse summa.
   */
   FUNCTION get_ma_serv_discount_amount (
      p_full_chg_value    IN  NUMBER
     ,p_remain_chg_value  IN  NUMBER
     ,p_cadc_min_price    IN  call_discount_codes.minimum_price%TYPE
     ,p_percentage        IN  call_discount_codes.precentage%TYPE
     ,p_discount_schema   IN  call_discount_codes.pricing%TYPE
   )
      RETURN NUMBER IS
      --
      l_discounted_value            NUMBER;
      l_special_price               NUMBER;
   BEGIN
      /*
        ** Kui Discount Schema Pricing
        **    = Y - Percentage määramata, anna erihind = Minimum Price
        **    = Y - Percentage määratud, anna erihind = p_charge_value * Precentage/100
        ** Kui erihind suurem/võrdne kui hinnakirja liitumishind, siis erihinda ei rakendata.
        ** Soodustus = p_charge_value - erihind.
        **    = N - Percentage määramata, anna soodustust = Minimum Price
        **    = N - Percentage määratud, anna soodustust = p_charge_value * Precentage/100
      */
      IF p_discount_schema = 'Y' THEN
         -- CADC antud erihind
         IF p_cadc_min_price IS NOT NULL THEN
            l_special_price := p_cadc_min_price;
         ELSIF p_percentage IS NOT NULL THEN
            l_special_price := p_full_chg_value * (p_percentage / 100);
         ELSE
            l_special_price := p_remain_chg_value;
         END IF;

         --
         l_discounted_value := GREATEST ((p_remain_chg_value - l_special_price), 0);
      ELSE
         -- CADC antud soodustus
         IF p_cadc_min_price IS NOT NULL THEN
            l_discounted_value := LEAST (p_cadc_min_price, p_remain_chg_value);
         ELSIF p_percentage IS NOT NULL THEN
            l_discounted_value := LEAST (p_full_chg_value * (p_percentage / 100), p_remain_chg_value);
         ELSE
            l_discounted_value := 0;
         END IF;
      END IF;

      --
      RETURN l_discounted_value;
   END get_ma_serv_discount_amount;

   /*
     ** Kannab leitud soodustuse summa arvele vastavalt soodustuse definitsioonile:
     ** kas eraldi arvereana või vähendab põhirea summat soodustuse võrra.
   */
   PROCEDURE invoice_discount (
      p_maas_ref_num      IN      master_account_services.ref_num%TYPE
     ,p_invo_ref_num      IN      invoices.ref_num%TYPE
     ,p_inen_rowid        IN      VARCHAR2
     ,p_discounted_value  IN      NUMBER
     ,p_cadc_rec          IN      call_discount_codes%ROWTYPE
     ,p_chk_date          IN      DATE
     ,p_fcdt_type_code    IN      fixed_charge_item_types.fcdt_type_code%TYPE
     ,p_success           OUT     BOOLEAN
     ,p_message           OUT     VARCHAR2
     ,p_mode              IN      VARCHAR2 DEFAULT 'INS'   -- INS/DEL
   ) IS
      --
      CURSOR c_inen IS
         SELECT        *
                  FROM invoice_entries
                 WHERE invo_ref_num = p_invo_ref_num
                   AND susg_ref_num IS NULL
                   AND NVL (maas_ref_num, -1) = NVL (p_maas_ref_num, -1)
                   AND billing_selector = p_cadc_rec.disc_billing_selector
                   AND cadc_ref_num = p_cadc_rec.ref_num
                   AND fcdt_type_code = p_fcdt_type_code
                   AND manual_entry = 'N'
                   AND NVL(additional_entry_text,'#¤%&') = nvl((SELECT additional_entry_text FROM invoice_entries WHERE rowid = p_inen_rowid),'#¤%&')    /*dobas-262*/
         FOR UPDATE OF acc_amount /* CHG4594 */, eek_amt NOWAIT;

      CURSOR c_curr (
         p_invo_ref  NUMBER
      ) IS
         SELECT curr_code
           FROM invoices
          WHERE ref_num = p_invo_ref_num;
      -- mobet-23
      CURSOR c_inen_additional_text IS
       SELECT additional_entry_text
         FROM invoice_entries
        WHERE rowid = p_inen_rowid;         

      --
      l_discounted_tax              NUMBER;
      l_inen_rec                    invoice_entries%ROWTYPE;
      l_additional_entry_text       invoice_entries.additional_entry_text%type := null;
      --
      e_not_invoicable              EXCEPTION;
      e_missing_data                EXCEPTION;
      e_processing                  EXCEPTION;
   BEGIN
      IF p_discounted_value = 0 AND p_cadc_rec.print_required = 'N' THEN
         RAISE e_not_invoicable;
      END IF;

      /*
        ** Arvutada käibemaks
      */
      /* CHG-4899
      IF p_discounted_value = 0 THEN
         l_discounted_tax := 0;
      ELSE
         l_discounted_tax := gen_bill.calc_vat_amount (p_discounted_value, p_cadc_rec.taty_type_code, p_chk_date);
      END IF;
      */

      /*
        ** Kanda soodustus arvele vastavalt definitsioonile: kas eraldi arvereale või vähendada makset.
      */
      IF p_cadc_rec.crm = 'Y' THEN
         /*
           ** Kontrollime arvereale kandmiseks vajalike atribuutide olemasolu.
         */
         IF p_fcdt_type_code IS NULL THEN
            p_message := 'Discount Fixed Charge Item Type is missing.';
            RAISE e_missing_data;
         END IF;

         --
         IF p_cadc_rec.disc_billing_selector IS NULL THEN
            p_message := 'Discount Billing Selector is missing.';
            RAISE e_missing_data;
         END IF;

         /*
           ** Eraldi arvereale soodustuse BISE tüübiga c_Cadc.Disc_Billing_Selector.
         */
         OPEN c_inen;

         FETCH c_inen
          INTO l_inen_rec;

         --
         IF c_inen%FOUND THEN
            /*
              ** Kui soodustuse arverida olemas, suurendada soodustust (negatiivne).
            */
            IF p_mode = 'INS' THEN
               UPDATE invoice_entries
                  SET acc_amount = ROUND (acc_amount - p_discounted_value, get_inen_acc_precision)   -- CHG4594
                     -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) - l_discounted_tax, 2)
                     ,evre_count = NVL (evre_count, 0) + 1
                     ,date_updated = SYSDATE
                     ,last_updated_by = sec.get_username
                WHERE CURRENT OF c_inen;
            ELSE   -- DEL
               IF l_inen_rec.eek_amt + p_discounted_value <> 0 THEN
                  UPDATE invoice_entries
                     SET acc_amount = ROUND (acc_amount + p_discounted_value, get_inen_acc_precision)   -- CHG4594
                        -- CHG-4899: ,amt_tax = ROUND (NVL (amt_tax, 0) + l_discounted_tax, 2)
                        ,evre_count = NVL (evre_count, 0) - 1
                        ,date_updated = SYSDATE
                        ,last_updated_by = sec.get_username
                   WHERE CURRENT OF c_inen;
               ELSE
                  DELETE FROM invoice_entries
                        WHERE CURRENT OF c_inen;
               END IF;
            END IF;   -- mode

            --
            CLOSE c_inen;
         ELSE   -- Invoice entry not found
            CLOSE c_inen;

            -- mobet-23 Kui p_inen_rowid real on additional:entry_text täidetud, siis sama tuuakse ka lisatavasse kirjesse
            OPEN c_inen_additional_text;
            FETCH c_inen_additional_text INTO l_additional_entry_text;
            CLOSE c_inen_additional_text;

            --
            l_inen_rec.invo_ref_num := p_invo_ref_num;
            l_inen_rec.maas_ref_num := p_maas_ref_num;
            l_inen_rec.billing_selector := p_cadc_rec.disc_billing_selector;
            l_inen_rec.acc_amount := ROUND (-p_discounted_value, get_inen_acc_precision);   -- CHG4594
            l_inen_rec.amt_tax := NULL; -- CHG-4899: ROUND (-l_discounted_tax, 2);
            l_inen_rec.evre_count := 1;
            l_inen_rec.cadc_ref_num := p_cadc_rec.ref_num;
            l_inen_rec.fcdt_type_code := p_fcdt_type_code;
            l_inen_rec.print_required := 'Y';
            l_inen_rec.taty_type_code := p_cadc_rec.taty_type_code;
            l_inen_rec.pri_curr_code := get_pri_curr_code ();
            l_inen_rec.additional_entry_text := l_additional_entry_text;  -- mobet-23
            --
            insert_inen (l_inen_rec   -- IN OUT nocopy invoice_entries%ROWTYPE
                        ,p_success   -- OUT BOOLEAN
                        ,p_message   -- OUT VARCHAR2
                        );

            IF NOT p_success THEN
               RAISE e_processing;
            END IF;
         END IF;   -- Found/Not Found
      ELSE   -- Soodustus samale arvereale
         -- Soodustus vähendab makset
         IF p_mode = 'INS' THEN
            UPDATE invoice_entries
               SET acc_amount = ROUND (acc_amount - p_discounted_value, get_inen_acc_precision)   -- CHG4594
                  -- CHG-4899: ,amt_tax = ROUND (amt_tax - l_discounted_tax, 2)
                  ,date_updated = SYSDATE
                  ,last_updated_by = sec.get_username
             WHERE ROWID = p_inen_rowid;
         ELSE   -- DEL
            UPDATE invoice_entries
               SET acc_amount = ROUND (acc_amount + p_discounted_value, get_inen_acc_precision)   -- CHG4594
                  -- CHG-4899: ,amt_tax = ROUND (amt_tax + l_discounted_tax, 2)
                  ,date_updated = SYSDATE
                  ,last_updated_by = sec.get_username
             WHERE ROWID = p_inen_rowid;
         END IF;   -- mode
      END IF;   -- crm

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_not_invoicable THEN
         p_success := TRUE;
      WHEN e_missing_data THEN
         p_success := FALSE;
      WHEN e_processing THEN
         p_success := FALSE;
   END invoice_discount;
   
   /*
     ** MOBET-7: Funktsioon leiab etteantud dico_ref_num'i ja SUDI.start_date järgi CADC'ust soodustuse lõpukuupäeva
   */
   FUNCTION calculate_sudi_end_date (p_dico_ref_num    IN discount_codes.ref_num%TYPE
                                    ,p_sudi_start_date IN subs_discounts.start_date%TYPE
   ) RETURN subs_discounts.end_date%TYPE IS
      --
      CURSOR c_cadc IS
         SELECT end_date, count_for_months, count_for_days
         FROM call_discount_codes cadc
         WHERE cadc.dico_ref_num = p_dico_ref_num
           AND Nvl(cadc.end_date, SYSDATE) >= SYSDATE
           AND call_type IN ('REGU','MON')
      ;
      --
      l_end_date          call_discount_codes.end_date%TYPE;
      l_count_for_months  call_discount_codes.count_for_months%TYPE;
      l_count_for_days    call_discount_codes.count_for_days%TYPE;
      l_empty_end_date    BOOLEAN;
      --
      l_sudi_end_date     subs_discounts.end_date%TYPE;
   BEGIN
      --
      FOR rec IN c_cadc LOOP
         -- end_date
         IF rec.end_date IS NULL THEN
            l_empty_end_date := TRUE;
         ELSE
            --
            l_end_date := Greatest(rec.end_date, Nvl(l_end_date, rec.end_date));
            --
         END IF;
         -- count_for_months
         IF rec.count_for_months IS NOT NULL THEN
            --
            l_count_for_months := Greatest(rec.count_for_months, Nvl(l_count_for_months, rec.count_for_months));
            --
         END IF;
         -- count_for_days
         IF rec.count_for_days IS NOT NULL THEN
            --
            l_count_for_days := Greatest(rec.count_for_days, Nvl(l_count_for_days, rec.count_for_days));
            --
         END IF;
         --
      END LOOP;
      --
      IF NOT l_empty_end_date THEN
         --
         l_sudi_end_date := l_end_date;
         --
      ELSIF l_count_for_months IS NOT NULL THEN
        -- kuu esimene päev
        IF to_char(p_sudi_start_date,'dd') ='01' THEN --mobet-7 16.01.2017
           l_sudi_end_date := Trunc(Add_Months(p_sudi_start_date, l_count_for_months),'MM') - 1/86400;
        ELSE   
           l_sudi_end_date := Trunc(Add_Months(p_sudi_start_date, l_count_for_months + 1),'MM') - 1/86400;
        END IF;   
         --
      ELSIF l_count_for_days IS NOT NULL THEN
         --
         l_sudi_end_date := Trunc((p_sudi_start_date + l_count_for_days), 'MM') - 1/86400;
         --
      END IF;
      --
      RETURN l_sudi_end_date;
   END calculate_sudi_end_date;
--
END calculate_discounts;
/
