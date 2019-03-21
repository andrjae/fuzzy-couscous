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