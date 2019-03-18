CREATE OR REPLACE PACKAGE LIMIT_TRACKING IS
     /******************************************************************************
      UPR:        1768 ... 3137
      MODULE:     BCCU772
      NAME: LIMIT_TRACKING
      PURPOSE:    Teenuste limiitide jälgimise funktsionaalsus.
      REVISIONS:
      Ver        Date        Author           Description
      ---------  ----------  ---------------  ------------------------------------
      1.0        03.09.2001 Indrek Jentson    Saldomeenutuse jälgimine (upr'id: 1768, 1886, 1897)
      1.1        15.11.2001 Indrek Ott        UPR -1986
      1.2        26.04.2002 Indrek Ott        UPR -2048
      1.3        27.02.2003 U.Aarna           UPR-2478: Käibemaksu arvutamisel voetakse väärtus tabelist Tax Rates
                                                        (Gen_Bill funktsiooni abil) senise süsteemse parameetri asemel.
      1.4        11.09.2003 Merike Kivistik   Kui täidetakse tabel SMS_HISTORY, siis täidetakse ka tabel
                                              SMS_HISTORY_ENTRIES
      1.5        28.10.2003 Indrek Jentson    UPR-2797: Lisaks rahalisele limiidile jälgitakse nüüd ka
                                                        andmemahu limiite.
      1.6        19.02.2004 Lauri Tammiste    UPR-2934: Saldostopi lisamine
      1.7        30.03.2004 Indrek Jentson    UPR-2973: Parandus PCDR parameetrites.
      1.8        21.04.2004 Indrek Jentson    UPR-3000: Parandused funktsioonides calculate ja fix_calculate .
      1.9        31.05.2004 Indrek Jentson    UPR-3109: Parandused protseduuris Finish_Month
      1.10       23.09.2004 Indrek Jentson    UPR-3136: Funktsionaalsuse muudatus. Saldostopi sidepiiramise kehtestamist
                                                        välismaal viibijale jälgib nüüd protseduur Do_Action.
      1.11       03.11.2004 Indrek Jentson    UPR-3137: Täiendus. Teenuse NBLIM olemasolul saadetakse limiidi
                                                                             ületamisel SMS.
                                                                             Muudetud on tabeliga BATCH_PROCESSES ringikäimist ja USRE
                                                                             kirjetele lisatakse vastava BATCH_PROCESSES kirje REF_NUM.
      1.12       24.11.2004 Indrek Jentson    UPR-3216: Täiendus. Uus versioon protseduurist FINISH_MONTH.
      1.13       01.12.2004 Indrek Jentson    UPR-3219: Täiendus. Enne noude esitamist kontrollitakse SUSGi aktiivsust.
      1.14       07.01.2005 U.Aarna           UPR-3249: Muudetud funktsiooni Insert_Order - orderite koostamise loogika viidud koik
                                                        ühte paketti or_insert_orders. Teenuse sulgemisel staatus manual_ok on samaväärne success.
      1.15       01.02.2005 Indrek Jentson    UPR-3272: Täiendus. Muudetud protseduuri Stop_Usage.
      1.16       15.08.2005 Helve Luhasalu    CHG-258 : Parandus. Tabelis susg_limit kustutab kirjeid rohkem kui tohib.
      1.17       04.05.2006 Indrek Jentson    CHG-872 : Parandus protseduuris decode_macros - summa ümardamine.
      1.18       05.05.2006 Andrus Rosman     CHG-776 : FUNCTION get_service_usage_value, get_mobile_usage_fix_value, get_service_usage_fix_value -
                                                        muutujasse lnres selectimisele lisatud ümardamine kahe komakohani
      1.19       19.05.2006 Andrus Rosman     CHG-883 : PROCEDURE init_action (pnseus NUMBER) - lisatud tingimus sepa.end_date kontrolliks
      1.20       10.12.2006 Sander Sokk       CHG-656:  PROCEDURE ins_limit_susg(pnsusg NUMBER, pnsety NUMBER) - käivitatakse insertimisel
                          subs_service_parameters tabelisse, kui on tegemist saldostopi
                  limiidi tellimisega. Siit ka limit_susg tabelisse kirje, kui vastab
                  tingimusetele.
                 FUNCTION  susg_canceled_lim_check(pnsusg NUMBER) - kontrollimaks, kas susg on
                    tellinud saldostopi piirangust loobumise
                 PROCEDURE ins_limit_susg(pnsusg NUMBER) autonoomne transaktsioon, et saaks
                    subs_service_parameters tabeli updatemisel käivitada. Lisatud ka
                  kontroll selecti, et poleks juba sellist susgi limit_susg tabelis
                  olemas.
                 FUNCTION check_all_limits(pnbapr NUMBER) kontrollitakse kas seus status pole
                    IGN - kasutatakse, siis, kui susg on valinud saldostopi piirangust
                  loobumise jooksval kuul. Kui pole siis kutsutakse susg_canceled_lim_check
                  ning kui tagastati TRUE siis pannakse staatus IGN. IGN siis selleks
                  et enam edasi ei teostataks piirangu toiminguid, küll aga toimub
                  edasi kalkuleerimine. Peale kalkuleerimist peab staatus tagasi IGN minema.
                 FUNCTION  prepare(pnsusg NUMBER, pnsety NUMBER, pdtime DATE, pnbapr NUMBER) lisatud
                    seus staatuse kontrolli IGN staatus, paneb kalkuleerimise jaoks ajutiselt
                  staatuse CTRL.
      1.21        04.05.2007 A.Soo            CHG-2048: Täiendus: funktsiooni 'do_action' kursorisse 'cur_mobils' lisandus 'GSM' filter.
                                                        Põhjus: M-ID teenust omavale numbrile saadeti 2 sõnumit.
      1.22        27.06.2007 S.Sokk           CHG-2110: Replaced USER with sec.get_username
      1.23        26.10.2007 A.Soo            CHG-2385: Protseduuri 'check_all_limits' algul loetakse kõik tabeli limit_susg ref_num'id
                                                        PL/SQL tabelisse ning hiljem samast tabelist kustutamisel kustutatakse ainult vastavad
                                                        kirjed, vältimaks poole töötlemise pealt COMMIT'itud ja töötlemata kirjete kustutamist.
                  29.10.2007 H.Luhasalu       CHG-2385: ALGUL polnud ALGUL.
      1.24        14.08.2008 A.Soo            CHG-3180: Paketeeritud teenuspakettide paketitasud.
                                                        Muudetud protseduure:
                                                          -- get_mobile_usage_fix_value
                                                          -- get_service_usage_fix_value
      1.25        29.09.2008 A.Soo            CHG-2762: Parandatud paketivahetusest ja limiidi muutmisest tingitud Saldostopi lõpetamise viga
                                                        Muudetud protseduure:
                                                          -- when_limit_value_updated
      1.26        25.11.2009 A.Soo            CHG-3360: Limiidi sisse arvutada ka iPhone paketitasud, MinuEMT lahendustasu/asenduskuutasu ja miinimumarve tasu ning soodustused
                                                        Eemaldatud OnceOff teenuste tasud ning cadc_ref_num-iga arveread.
                                                        Muudetud protseduure:
                                                          -- get_mobile_usage_fix_value
                                                          -- get_service_usage_value
                                                          -- get_mobile_usage_value
                                                        Uus funktsioon:
                                                          -- get_minb_calculated_value
      1.27        01.12.2009 A.Soo            CHG-4135: Limiidi arvutusest välja võtta paketi haldustasu (MINB)
                                                        Muudetud protseduure:
                                                          -- get_mobile_usage_fix_value
      1.28        02.12.2009 A.Soo            CHG-4138: Miinimumarve pakettidel (category M) toimub fix_value kontroll igal Saldostopi protsessi käivitusel.
                                                        Eemaldatud CHG-4135 täiendus.
                                                        Muudetud protseduure:
                                                          -- get_mobile_usage_fix_value
                                                          -- check_all_limits
                                                        Uus funktsioon:
                                                          -- get_package_category
      1.29        09.12.2009 A.Soo            CHG-4148: Lisatud MIN tüüpi soodustused limiidi arvutusse.
                                                        Muudetud protseduuri:
                                                          -- get_mobile_usage_value
      1.30        02.02.2010 A.Soo            CHG-4236: Paralleelkäivituse kontroll. Ei tohi käivituda, kui eelmine pole lõpuni jõudnud.
                                                        Muudetud protseduuri:
                                                          -- process_limits
      1.31        16.02.2010 H.Luhasalu       CHG-4252: Limiiditeenuste päring muudetud
      1.32        16.03.2010 H.Luhasalu       CHG-3970: Limiiti peab vaatama ka jooksva perioodi vahearvetelt.
                                                        Muudetud unit MINUT, perioodi arvepõhiseks kasutuseks
      1.33        22.11.2010 I.Jentson        CHG-4594; Konstandi cc_tlmoney_unit kasutamine asendatud fn-i GET_PRI_CURR_CODE
                                                        kasutamisega (alamprogrammis GET_DATE_UPDATED paketikonstant G_PRI_CURR_CODE).
      1.34        05.04.2011 A.Soo            CHG-4899: Käibemaksu ümardus 3 komakoha peale.
                                                        Muudetud protseduure:
                                                          -- get_service_usage_value
                                                          -- get_mobile_usage_value
                                                          -- get_service_usage_fix_value
                                                          -- get_mobile_usage_fix_value
      1.35        27.09.2012 A.Soo            CHG-6068: Paketeeritud müügi seadmete kuutasud
                                                        Muudetud protseduure:
                                                          -- get_mobile_usage_fix_value
      1.36        01.04.2014 A.Soo            CHG-13669: IS-17972 - MultiSIM - Limiidi kontroll
                                                        Muudetud protseduure:
                                                          -- ins_limit_susg
                                                          -- ins_limit_susg (2)
      1.37        05.08.2014 A.Soo            CHG-13846: IS-14371 - Billingu koormuse vähendamine ja invoice entrid
                                                        Muudetud protseduuri:
                                                          -- ins_limit_susg
     1.38        05.02.2019  A.Jaek           DOBAS-1721: Lisatud process.daily_charges.proc_daily_charges_ma väljakutse
     ******************************************************************************/
     -- KONSTANDID
   cc_module_ref        CONSTANT VARCHAR2 (7) := 'BCCU772';
   cc_tl_tunnus         CONSTANT VARCHAR2 (5) := 'LIMIT';
   cc_tlunit_tunnus     CONSTANT VARCHAR2 (4) := 'UNIT';
   cc_tldata_unit       CONSTANT VARCHAR2 (2) := 'KB';
   cc_tltime_unit       CONSTANT VARCHAR2 (5) := 'MINUT';
   -- 1 sekund
   cn_sec               CONSTANT NUMBER := 1 / 86400;
   cn_sysparam_tax_type CONSTANT NUMBER := 26;
   cn_sysparam_sms_outbox CONSTANT NUMBER := 102;
   cn_sysparam_proc_start CONSTANT NUMBER := 900;
   cn_sysparam_proc_stage CONSTANT NUMBER := 901;
   cn_open_err          CONSTANT NUMBER := -1;
   cn_write_err         CONSTANT NUMBER := -2;
   cn_close_err         CONSTANT NUMBER := -3;
   -- BCC_MESSAGES.ref_num väärtused
   -- üldine veateade
   cn_others            CONSTANT NUMBER := 1723;
   -- ärireegli rikkumine
   cn_br_error          CONSTANT NUMBER := 850;
   -- üldine teade
   cn_info              CONSTANT NUMBER := 9999;
   --
   g_pri_curr_code      CONSTANT VARCHAR2 (3) := get_pri_curr_code;   -- CHG4594

   /*
   Koigi limiitide kontrollimise algatamine
   Käivitada limiitide kontrollimise protsess

   Tagastab TRUE, kui kontrollimine onnestus;
   Tagastab FALSE, kui kontrollimine ebaonnestus
   */
   FUNCTION check_all_limits (
      pnbapr  NUMBER
   )
      RETURN BOOLEAN;

   /*
   Kontrollib, kas susg on ITB-st v?i DLG-st algatanud ise
   sidepiirangust loobumise jooksval kuul

   Tagastab TRUE, kui on algatatud
   Tagastab FALSE, kui pole algatatud
   */
   FUNCTION susg_canceled_lim_check (
      pnsusg  NUMBER
   )
      RETURN BOOLEAN;

   -- Teenuse ettevalmistamine limiidi kontrollimiseks
   FUNCTION PREPARE (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
     ,pnbapr  NUMBER
   )
      RETURN NUMBER;

   -- Etteantud teenuse mahu arvutamine
   FUNCTION calculate (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER;

   -- Etteantud teenuse fikseeritud maksete mahu arvutamine
   FUNCTION fix_calculate (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER;

   /*
   Class: Limit Tracking Service / Limiidi jälgimise teenus
   Limiidi kontrollimine etteantud teenuse juures
   */
   FUNCTION check_limit (
      pnsusg  NUMBER
     ,pnsety  NUMBER
   )
      RETURN NUMBER;

   -- Etteantud teenuse limiidi suuruse pärimine
   FUNCTION get_limit_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER;

   -- Limiidi suuruse muutmisega kaasnevad tegevused
   PROCEDURE when_limit_value_updated (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pnlim   NUMBER   -- limiidi uus väärtus
     ,pnbapr  NUMBER
   );

   -- Kuu lopetamise tegevused
   PROCEDURE finish_month (
      pnyear  NUMBER
     ,   -- aasta number
      pnmon   NUMBER   -- kuu number
   );

   /*
   Class: Service Usage / Teenuse kasutusinfo
   Uue SEUS kirje tekitamine
   */
   PROCEDURE start_new_usage (
      pnsusg       NUMBER
     ,pnsety       NUMBER
     ,pnyear       NUMBER
     ,   -- aasta number
      pnmon        NUMBER
     ,   -- kuu number
      pnover       NUMBER
     ,   -- eelmises kuus üle limiidi
      pnseus  OUT  NUMBER
   );

   -- Kasutatud teenuste mahu küsimine
   FUNCTION get_usage_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER;

   -- Kasutatud teenuste mahu leidmine mobiili tasemel
   FUNCTION get_mobile_usage_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER;

   -- Kasutatud teenuste mahu leidmine teenuse tasemel
   FUNCTION get_service_usage_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER;

   -- Fikseeritud maksete suuruse leidmine mobiili tasemel
   FUNCTION get_mobile_usage_fix_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER;

   -- Fikseeritud maksete suuruse leidmine teenuse tasemel
   FUNCTION get_service_usage_fix_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER;

   -- SEUS kirje oleku muutmine
   PROCEDURE set_usage_status (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pcstat  VARCHAR2   -- uus olek
   );

   -- SEUS kirje oleku muutmine; 2.ver
   PROCEDURE set_usage_status (
      pnseus  NUMBER
     ,pcstat  VARCHAR2   -- uus olek
   );

   -- SEUS kirje oleku pärimine
   FUNCTION get_usage_status (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pnyear  NUMBER
     ,pnmon   NUMBER
   )
      RETURN VARCHAR;

   -- SEUS kirje oleku pärimine; 2.ver
   FUNCTION get_usage_status (
      pnsusg  NUMBER
     ,pnsety  NUMBER
   )
      RETURN VARCHAR;

   -- SEUS kirje oleku pärimine; 3.ver
   FUNCTION get_usage_status (
      pnseus  NUMBER
   )
      RETURN VARCHAR;

   -- SEUS kirje atribuudi OVER_LIMIT muutmine
   PROCEDURE set_over_limit (
      pnseus  NUMBER
     ,pnolim  NUMBER   -- uus OVER_LIMIT väärtus
   );

   -- SEUS kirje atribuudi OVER_LIMIT väärtus
   FUNCTION get_over_limit (
      pnseus  NUMBER
   )
      RETURN NUMBER;

   -- Limiidiületuse tegevuse algatamine
   PROCEDURE init_action (
      pnsusg  NUMBER
     ,pnsety  NUMBER
   );

   -- Limiidiületuse tegevuse algatamine; 2.ver
   PROCEDURE init_action (
      pnseus  NUMBER
   );

   -- SEUS kirje passiivseks märkimine
   PROCEDURE stop_usage (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pnyear  NUMBER
     ,   -- aasta number
      pnmon   NUMBER   -- kuu number
     ,pnbapr  NUMBER
   );

   /*
   Class: Limit_Action / Limiidiületamise tegevused
   Koigi initsialiseeritud tegevuste läbivaatamine
   */
   FUNCTION check_actions (
      pnbapr  NUMBER
   )
      RETURN NUMBER;

   -- Konkreetse tegevuse teostamine
   FUNCTION do_action (
      pnliac  NUMBER
     ,pnpcfi  NUMBER
     ,pnbapr  NUMBER
   )
      RETURN NUMBER;

   -- Protseduur SMS sonumi kirjutamiseks faili süsteemse parameetriga 102 määratletud kataloogi.
   PROCEDURE write_tl_sms_file (
      pcanr       VARCHAR2
     ,   -- number, kust saadetakse (voib olla tühi?)
      pcbnr       VARCHAR2
     ,   -- number, kuhu saadetakse
      pcmsg       VARCHAR2
     ,   -- teade
      pnres  OUT  NUMBER
   -- töö lopetamise kood: 0=korras, muud tähistavad vigu
   );

   -- Protseduur etteantud tekstis makrode asendamiseks väärtustega.
   PROCEDURE decode_macros (
      pnsusg          NUMBER
     ,   -- viit mobiilile
      pnsety          NUMBER
     ,   -- viit teenuste tüübile
      pcmsg   IN OUT  VARCHAR2
     ,   -- töödeldav tekst
      pnres   OUT     NUMBER
   -- asendamise onnestumisel tagastatakse 0, muidu esimene '#' positsioon
   );

   PROCEDURE create_interim_invo (
      pnmaac          NUMBER
     ,prinvo  IN OUT  invoices%ROWTYPE
   );

   -- Etteantud teenuse limiidi suuruse ühiku pärimine
   FUNCTION get_limit_unit (
      pnsety  NUMBER
   )
      RETURN VARCHAR2;

   PRAGMA RESTRICT_REFERENCES (get_limit_unit, WNDS);

   FUNCTION get_active_seus (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pnyear  NUMBER
     ,pnmon   NUMBER
   )
      RETURN NUMBER;

   -- Lisab kirje tabelisse LIMIT_SUSG (UPR-2934)
   PROCEDURE ins_limit_susg (
      pnsusg  NUMBER
   );

   -- Lisab kirje tabelisse LIMIT_SUSG, kui on lisatud uus kirje subs_service_parameters tabelisse
   PROCEDURE ins_limit_susg (
      pnsusg  NUMBER
     ,pnsety  NUMBER
   );

   -- Käivitab CHECK_ALL_LIMITS (UPR-2934)
   -- pnbapr = BATCH_PROCESSES.REF_NUM
   PROCEDURE process_limits (
      pnbapr  NUMBER
   );

   -- Abifunktsioon CHECK_ALL_LIMITS peapäringu sooritamisel (UPR-2934)
   FUNCTION get_date_updated (
      pnsusg  NUMBER
     ,pnsety  NUMBER
   )
      RETURN DATE;

   -- Leiab miinimumarve haldustasu. Juhul, kui fix tasud on suuremad haldustasust,
   -- tagastab fix tasude summa.
   FUNCTION get_minb_calculated_value (
      p_susg_ref_num     NUMBER
     ,p_invo_ref_num     NUMBER
     ,p_total_int_value  NUMBER
     ,p_chk_date         DATE
   )
      RETURN NUMBER;

   -- Leiab SUSG-ile paketi kategooria
   FUNCTION get_package_cagegory (
      p_susg_ref_num  NUMBER
     ,p_chk_date      DATE
   )
      RETURN VARCHAR2;

   PRAGMA RESTRICT_REFERENCES (get_date_updated, WNDS);
END limit_tracking;
/

CREATE OR REPLACE PACKAGE BODY LIMIT_TRACKING IS
   /*
   Määratleb aja, millal ei ole vaja enam limiidi ületamise korral
   väljuva side piiramist rakendada
   */
   cd_end_of_month      CONSTANT DATE := ADD_MONTHS (TRUNC (SYSDATE, 'MM'), 1) - get_system_parameter (86) / 24;
   cc_bapr_incomplete   CONSTANT VARCHAR2 (10) := 'INCOMPLETE';
   cc_bapr_complete     CONSTANT VARCHAR2 (8) := 'COMPLETE';
   cc_bapr_error        CONSTANT VARCHAR2 (5) := 'ERROR';
   cn_year              CONSTANT NUMBER (4) := TO_NUMBER (TO_CHAR (SYSDATE, 'YYYY'));
   cn_month             CONSTANT NUMBER (2) := TO_NUMBER (TO_CHAR (SYSDATE, 'MM'));
   cc_emt_lyhinumber    CONSTANT VARCHAR2 (4) := get_system_parameter (109);
   cc_sms_looja         CONSTANT VARCHAR2 (14) := 'LIMIT TRACKING';
   cc_tariff_class      CONSTANT VARCHAR2 (20) := get_system_parameter (160);
   cc_service_name      CONSTANT VARCHAR2 (5) := 'GMSST';
   cc_rety_type_code    CONSTANT VARCHAR2 (4) := 'CHAG';
   cc_complete          CONSTANT VARCHAR2 (8) := or_common.COMPLETE;
   cc_success           CONSTANT VARCHAR2 (8) := or_common.success;
   cc_open              CONSTANT VARCHAR2 (8) := or_common.open_service;
   cc_close             CONSTANT VARCHAR2 (7) := or_common.close_service;
   cc_canceled          CONSTANT VARCHAR2 (8) := or_common.canceled;
   cc_created_by        CONSTANT VARCHAR2 (4) := 'U772';

   -- Tekitab ORDER-süsteemi orderi side piiramiseks/avamiseks (UPR-2934)
   FUNCTION insert_order (
      pnsusg  NUMBER
     ,pctype  VARCHAR2
     ,pnbapr  NUMBER
   )
      RETURN BOOLEAN IS
      lnusre                        user_requests.ref_num%TYPE;
      lctype                        VARCHAR2 (10);
      lcstatus                      ssg_statuses.status_code%TYPE;
      l_success                     BOOLEAN;
      l_message                     VARCHAR2 (200);
      --
      notactive_susg                EXCEPTION;
      e_creating_order              EXCEPTION;
   BEGIN
      -- Kontrollime SUSGi olekut (UPR-3219)
      BEGIN
         SELECT status_code
           INTO lcstatus
           FROM ssg_statuses
          WHERE susg_ref_num = pnsusg AND start_date <= SYSDATE AND (end_date IS NULL OR end_date > SYSDATE);

         IF lcstatus IN ('CLN') THEN
            RAISE notactive_susg;
         END IF;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RAISE notactive_susg;
      END;

      --
      IF pctype = 'OPEN' THEN
         lctype := cc_open;
      ELSE
         lctype := cc_close;
      END IF;

      /*
        ** UPR-3249: Kogu orderite koostamise loogika viidud paketti or_insert_orders.
        **           Loob orderi milline koosneb USRE+SUDE+SEDE ilma parameetriteta teenusele.
      */
      lnusre := or_insert_orders.create_no_param_service_order (pnsusg
                                                               ,cc_service_name
                                                               ,lctype   -- IN  service_details.rety_type_code%TYPE
                                                               ,l_success   -- OUT BOOLEAN
                                                               ,l_message   -- OUT VARCHAR2
                                                               ,pnbapr   -- IN  batch_processes.ref_num%TYPE DEFAULT NULL
                                                               ,cc_created_by
                                                               );

      IF NOT l_success THEN
         RAISE e_creating_order;
      END IF;

      --
      RETURN TRUE;
   EXCEPTION
      WHEN e_creating_order THEN
         ROLLBACK;
         gen_bill.msg (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Insert_Order', l_message);
         RETURN FALSE;
      WHEN notactive_susg THEN
         RETURN TRUE;
      WHEN OTHERS THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Insert_Order', SQLERRM);
         COMMIT;
         RETURN FALSE;
   END;

   -- Tekitab kirje PCDR-faili (UPR-2934)
   FUNCTION insert_pcdr_record (
      pnpcfi        pcdr_records.pcfi_ref_num%TYPE
     ,pnevent_id    pcdr_records.event_id%TYPE
     ,pnsety        service_types.ref_num%TYPE
     ,pca_num       pcdr_records.a_num%TYPE
     ,pcb_num       pcdr_records.b_num%TYPE
     ,pcmaksustada  VARCHAR2
     ,pddate        DATE
   )
      RETURN BOOLEAN IS
      lctext_value                  pcdr_records.service_name%TYPE;
      lctext1                       pcdr_records.tariff_class%TYPE;
      lbcorrect                     BOOLEAN := TRUE;
      lcmsg                         VARCHAR2 (256);
      tariff_class_exception        EXCEPTION;
   BEGIN
      BEGIN
         SELECT bcdv.text_value
               ,DECODE (pcmaksustada, 'J', bcdv.text1, DECODE (pca_num, pcb_num, cc_tariff_class, bcdv.text1))
           INTO lctext_value
               ,lctext1
           FROM bcc_domain_values bcdv, service_types sety
          WHERE bcdv.doma_type_code = 'PCTC' AND bcdv.value_code = sety.service_name AND sety.ref_num = pnsety;
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            RAISE tariff_class_exception;
      END;

      IF lctext1 IS NULL THEN
         RAISE tariff_class_exception;
      END IF;

      pcdr.INSERT_RECORD (pnpcfi                  => pnpcfi
                         ,pcevent_type            => 'BI'
                         ,pnevent_id              => pnevent_id
                         ,pnrelated_event_id      => NULL
                         ,pnmaster_id             => 23343000
                         ,pcservice_id            => 'TT'
                         ,pcservice_name          => lctext_value
                         ,pnanum_type             => 0
                         ,pca_num                 => pca_num
                         ,pnbnum_type             => 0
                         ,pcb_num                 => pcb_num
                         ,pdreq_date              => pddate
                         ,pdans_date              => pddate
                         ,pnaction_id             => 5
                         ,pccharge_class          => 'E'
                         ,pnitem_count            => 1
                         ,pctariff_class          => lctext1
                         ,pnprice                 => NULL
                         ,pndiscounted_price      => NULL
                         ,pbcorrect               => lbcorrect
                         ,pcmsg                   => lcmsg
                         );

      IF NOT lbcorrect THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Insert_Pcdr_Record'
                               , 'PCDR.Insert_Pcdr_Record error: ' || lcmsg
                               );
         COMMIT;
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END IF;
   EXCEPTION
      WHEN tariff_class_exception THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Insert_Pcdr_Record'
                               , 'Teenuse liigil ' || pnsety || ' on tariifiklass määratlemata!'
                               );
         COMMIT;
         RETURN FALSE;
      WHEN OTHERS THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Insert_Pcdr_Record', SQLERRM);
         COMMIT;
         RETURN FALSE;
   END;

   --Kas mobiilikasutaja viibib välismaal? (UPR-2934)
   FUNCTION susg_in_roaming (
      pnsusg  NUMBER
   )
      RETURN BOOLEAN IS
   BEGIN
      RETURN or_communication_initiator.susg_in_roaming (pnsusg);
   END;

   -- *** --
   FUNCTION get_active_seus (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pnyear  NUMBER
     ,pnmon   NUMBER
   )
      RETURN NUMBER IS
      lnseus                        NUMBER := 0;

      CURSOR cur_seus IS
         SELECT ref_num
               ,status
           FROM service_usages
          WHERE susg_ref_num = pnsusg AND sety_ref_num = pnsety AND YEAR = pnyear AND MONTH = pnmon;

      rec_seus                      cur_seus%ROWTYPE;
   BEGIN
      -- kontrollime SEUS'i olemasolu
      OPEN cur_seus;

      FETCH cur_seus
       INTO rec_seus;

      IF cur_seus%FOUND THEN
         IF rec_seus.status IN ('AC', 'LMO') THEN
            -- kasutatav SEUS on olemas
            lnseus := rec_seus.ref_num;
         ELSE
            -- jooksva kuu SEUS olemas ja mitteaktiivne
            lnseus := -1;
         END IF;
      END IF;

      CLOSE cur_seus;

      RETURN lnseus;
   END get_active_seus;

   -- *** --
   FUNCTION check_all_limits (
      pnbapr  NUMBER
   )
      RETURN BOOLEAN IS
      lcstage                       VARCHAR2 (20);
      ldprocess_start               DATE;
      ldstage_start                 DATE;
      lncnt                         NUMBER;
      lnacnt                        NUMBER;

      TYPE tabtype_susg IS TABLE OF subs_service_parameters.susg_ref_num%TYPE
         INDEX BY BINARY_INTEGER;

      TYPE tabtype_sety IS TABLE OF subs_service_parameters.sety_ref_num%TYPE
         INDEX BY BINARY_INTEGER;

      TYPE tabtype_date_updated IS TABLE OF DATE
         INDEX BY BINARY_INTEGER;

      --TYPE tabtype_seus_status IS TABLE OF service_usages.status%TYPE
      --   INDEX BY BINARY_INTEGER;
      ltseus_status                 service_usages.status%TYPE;
      ltsusg                        tabtype_susg;
      ltsety                        tabtype_sety;
      ltdate_updated                tabtype_date_updated;
      l_ref_tab                     number_tab;   -- CHG-2385
      --ltseus_status     tabtype_seus_status;
      lntab_count                   PLS_INTEGER;
      lnmin                         limit_susg.ref_num%TYPE;
      lnmax                         limit_susg.ref_num%TYPE;
      lnidx                         PLS_INTEGER;
   BEGIN
       /* PROTSESSI ALUSTAMINE */
      -- kontrollime jooksva limiitide protsessi etapi
      lcstage := get_system_parameter (cn_sysparam_proc_stage);

      -- kui protsess oli eelnevalt läbitud
      IF lcstage = 'Finished' THEN
         ldprocess_start := SYSDATE;

         -- uuendame system_parameters tabelis viimase limiidi kontrollimise alustamise aja
         UPDATE system_parameters
            SET text_value = TO_CHAR (ldprocess_start, 'DD.MM.YYYY HH24:MI:SS')
          WHERE ref_num = cn_sysparam_proc_start;

         lcstage := 'Prepare';

         -- uuendame system_parameters tabelis jooksva limiitide protsessi etapi 'prepare' peale
         UPDATE system_parameters
            SET text_value = lcstage
               ,date_updated = SYSDATE
          WHERE ref_num = cn_sysparam_proc_stage;

         ldstage_start := ldprocess_start;
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Check_All_Limits'
                               , 'Processing started, stage : ' || lcstage
                               );
         COMMIT;
      -- kui protsess oli jäänud pooleli
      ELSE
         -- teeme kindlaks poolelijäänud etapi ja selle algamise aja
         ldprocess_start := TO_DATE (get_system_parameter (cn_sysparam_proc_start), 'DD.MM.YYYY HH24:MI:SS');

         SELECT date_updated
           INTO ldstage_start
           FROM system_parameters
          WHERE ref_num = cn_sysparam_proc_stage;

         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Check_All_Limits'
                               , 'Processing resumed, stage : ' || lcstage
                               );
         COMMIT;
      END IF;

      /*
        ** CHG-2385: Loeme kõik limit_susg ref_num'id PL/SQL tabelisse, et ei kustutaks
        **           poole töötlemise pealt limit_trackingu protsessi töö ajal COMMIT'itud kirjeid.
      */
      SELECT ref_num
      BULK COLLECT INTO l_ref_tab
        FROM limit_susg;

      -- küsime limit_susg tabeli esimese ja viimase kirje ref_numi
      SELECT MIN (ref_num)
            ,MAX (ref_num)
        INTO lnmin
            ,lnmax
        FROM limit_susg;

      SELECT   susp.susg_ref_num susg
              ,susp.sety_ref_num sety
              ,limit_tracking.get_date_updated (susp.susg_ref_num, susp.sety_ref_num) date_updated   --,
      --limit_tracking.get_usage_status (susp.susg_ref_num,
      --                                 susp.sety_ref_num
      --                                ) prev_status
      BULK COLLECT INTO ltsusg
               ,ltsety
               ,ltdate_updated   --,
          --ltseus_status
      FROM     subs_service_parameters susp
              , (SELECT sepa.sety_ref_num
                       ,sepa.ref_num
                   FROM service_parameters sepa, service_types sety
                  WHERE sepa.nw_param_name = cc_tl_tunnus
                    AND sepa.start_date < SYSDATE
                    AND sepa.end_date IS NULL
                    AND sety.ref_num = sepa.sety_ref_num
                    AND sety.nety_type_code = 'BIL'
                    AND NVL (sety.station_service, 'N') = 'N') sepa
         WHERE susp.start_date < SYSDATE
           AND susp.end_date IS NULL
           AND susp.sety_ref_num = sepa.sety_ref_num
           AND susp.sepa_ref_num = sepa.ref_num
           AND EXISTS (SELECT 1
                         FROM limit_susg lisu
                        WHERE ref_num <= lnmax AND lisu.susg_ref_num = susp.susg_ref_num)
      ORDER BY susp.sety_ref_num;

      lntab_count := ltsusg.COUNT;

      /* STAGE 1: PREPARE */
      IF lcstage = 'Prepare' THEN
         lncnt := 0;

         FOR i_idx IN 1 .. lntab_count LOOP
            lncnt := lncnt + PREPARE (ltsusg (i_idx), ltsety (i_idx), ldstage_start, pnbapr);
         END LOOP;

         -- etapi l?petamine
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Check_All_Limits'
                               ,    'Processing continued, stage '
                                 || lcstage
                                 || ' finished ('
                                 || TO_CHAR (lncnt)
                                 || ' services processed)'
                               );
         lcstage := 'Calculate';

         UPDATE system_parameters
            SET text_value = lcstage
               ,date_updated = SYSDATE
          WHERE ref_num = cn_sysparam_proc_stage;

         ldstage_start := SYSDATE;
         COMMIT;
      END IF;

      /* STAGE 2: CALCULATE */
      IF lcstage = 'Calculate' THEN
         lncnt := 0;

         FOR i_idx IN 1 .. lntab_count LOOP
            lnacnt := calculate (ltsusg (i_idx), ltsety (i_idx), ldstage_start);

            IF    (ltdate_updated (i_idx) IS NULL)
               OR (ltdate_updated (i_idx) < TRUNC (SYSDATE))
               OR (get_package_cagegory (ltsusg (i_idx), ldstage_start) = 'M')   -- CHG-4138
                                                                              THEN
               lnacnt := lnacnt + fix_calculate (ltsusg (i_idx), ltsety (i_idx), ldstage_start);

               IF lnacnt = 2 THEN
                  lnacnt := 1;
               END IF;
            END IF;

            -- kontrollime, kas limit_trackingu seus staatus oli alguses IGN
            -- kalkuleerimised on tehtud, kui susg on loobunud jooksvas kuus ise saldostopi piirangust
            -- siis antud susgi puhul enam check_limit ei pea uuesti arvutama
            ltseus_status := limit_tracking.get_usage_status (ltsusg (i_idx), ltsety (i_idx));

            IF ltseus_status IS NOT NULL AND ltseus_status = 'IGN' THEN
               UPDATE service_usages
                  SET status = 'IGN'
                     ,date_updated = SYSDATE
                     ,last_updated_by = cc_module_ref
                WHERE ref_num = (SELECT ref_num
                                   FROM service_usages
                                  WHERE susg_ref_num = ltsusg (i_idx)
                                    AND sety_ref_num = ltsety (i_idx)
                                    AND YEAR = cn_year
                                    AND MONTH = cn_month
                                    AND (date_updated <= SYSDATE OR date_updated IS NULL));

               COMMIT;
            ELSIF susg_canceled_lim_check (ltsusg (i_idx)) THEN
               UPDATE service_usages
                  SET status = 'IGN'
                     ,date_updated = SYSDATE
                     ,last_updated_by = cc_module_ref
                WHERE ref_num = (SELECT ref_num
                                   FROM service_usages
                                  WHERE susg_ref_num = ltsusg (i_idx)
                                    AND sety_ref_num = ltsety (i_idx)
                                    AND YEAR = cn_year
                                    AND MONTH = cn_month
                                    AND (date_updated <= SYSDATE OR date_updated IS NULL));

               COMMIT;
            END IF;

            lncnt := lncnt + lnacnt;
         END LOOP;

         -- etapi l?petamine
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Check_All_Limits'
                               ,    'Processing continued, stage '
                                 || lcstage
                                 || ' finished ('
                                 || TO_CHAR (lncnt)
                                 || ' services processed)'
                               );
         lcstage := 'Check Limits';

         UPDATE system_parameters
            SET text_value = lcstage
               ,date_updated = SYSDATE
          WHERE ref_num = cn_sysparam_proc_stage;

         ldstage_start := SYSDATE;
         COMMIT;
      END IF;

      /* STAGE 3: CHECK LIMITS */
      IF lcstage = 'Check Limits' THEN
         lncnt := 0;

         FOR i_idx IN 1 .. lntab_count LOOP
            lncnt := lncnt + check_limit (ltsusg (i_idx), ltsety (i_idx));
         END LOOP;

         -- etapi l?petamine
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Check_All_Limits'
                               ,    'Processing continued, stage '
                                 || lcstage
                                 || ' finished ('
                                 || TO_CHAR (lncnt)
                                 || ' actions generated)'
                               );
         lcstage := 'Do Actions';

         UPDATE system_parameters
            SET text_value = lcstage
               ,date_updated = SYSDATE
          WHERE ref_num = cn_sysparam_proc_stage;

         ldstage_start := SYSDATE;
         COMMIT;
      END IF;

      /* STAGE 4: DO ACTIONS */
      IF lcstage = 'Do Actions' THEN
         lncnt := check_actions (pnbapr);
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Check_All_Limits'
                               ,    'Processing continued, stage '
                                 || lcstage
                                 || ' finished ('
                                 || TO_CHAR (lncnt)
                                 || ' actions processed)'
                               );
         -- etapi l?petamine
         lcstage := 'Finished';

         UPDATE system_parameters
            SET text_value = lcstage
               ,date_updated = SYSDATE
          WHERE ref_num = cn_sysparam_proc_stage;

         COMMIT;
      END IF;

      insert_batch_messages (cc_module_ref, 'Limit_Tracking INFO', cn_info, 'Check_All_Limits', 'Processing finished');

      IF lnmax - lnmin >= 5000 THEN
         lnidx := lnmin;

         LOOP
            lnidx := LEAST (lnidx + 5000, lnmax);

            DELETE FROM limit_susg
                  WHERE ref_num <= lnidx AND ref_num IN (SELECT *
                                                           FROM TABLE ((CAST (l_ref_tab AS number_tab))));   -- CHG-2385

            COMMIT;
            EXIT WHEN lnidx >= lnmax;
         END LOOP;
      ELSE
         DELETE FROM limit_susg
               WHERE ref_num <= lnmax AND ref_num IN (SELECT *
                                                        FROM TABLE ((CAST (l_ref_tab AS number_tab))));   -- CHG-2385
      END IF;

      SELECT COUNT (1)
        INTO lnmax
        FROM user_requests usre, subscriber_details sude, service_details sede
       WHERE usre.rety_type_code = cc_rety_type_code
         AND usre.ref_num = sude.usre_ref_num
         AND sude.created_by = cc_created_by
         AND sude.ref_num = sede.sude_ref_num
         AND sede.service_name = cc_service_name
         AND usre.date_created >= ldprocess_start;

      IF lnmax > 0 THEN
         UPDATE batch_processes
            SET selected_count = lncnt
          WHERE ref_num = pnbapr;
      ELSE
         DELETE FROM batch_processes
               WHERE ref_num = pnbapr;
      END IF;

      COMMIT;
      RETURN TRUE;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Check_All_Limits', SQLERRM);
         COMMIT;
         RETURN FALSE;
   END check_all_limits;

   /*
   Kontrollib, kas susg on ITB-st v?i DLG-st algatanud ise
   sidepiirangust loobumise jooksval kuul

   Tagastab TRUE, kui on algatatud
   Tagastab FALSE, kui pole algatatud
   */
   FUNCTION susg_canceled_lim_check (
      pnsusg  NUMBER
   )
      RETURN BOOLEAN IS
      lncnt                         NUMBER;
   BEGIN
      SELECT COUNT (1)
        INTO lncnt
        FROM subscriber_details sude, service_details sede, user_requests usre
       WHERE sude.exis_susg_ref_num = pnsusg
         AND sude.ref_num = sede.sude_ref_num
         AND sede.service_name = cc_service_name
         AND sede.rety_type_code = cc_close
         AND sude.usre_ref_num = usre.ref_num
         AND usre.channel_type IN ('ITB', 'DLG')
         AND usre.date_created > TO_DATE (ADD_MONTHS (TRUNC (SYSDATE, 'MM'), 0));

      COMMIT;

      IF lncnt > 0 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN FALSE;
   END susg_canceled_lim_check;

   -- *** --
   -- Teenuse ettevalmistamine limiidi kontrollimiseks
   -- etapi jooksul muudetud kirjeid ei näpita
   FUNCTION PREPARE (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
     ,pnbapr  NUMBER
   )
      RETURN NUMBER IS
      lnseus                        NUMBER;
      lnoseus                       NUMBER;
      lnlimit                       NUMBER;   --upr1886
      lnlimitx                      NUMBER;
      lnover                        NUMBER;
      lcstatus                      VARCHAR2 (3);
   BEGIN
      insert_batch_messages (cc_module_ref, 'Limit_Tracking INFO', cn_others, 'Prepare', 'Prepare algus');
      -- DBMS_OUTPUT.PUT_LINE('Prepare started at '||to_char(sysdate,'dd.mm.yy hh24:mi:ss'));
      -- kontrollime eelmise kuu SEUS'i olekut
      lnoseus := get_active_seus (pnsusg
                                 ,pnsety
                                 ,TO_NUMBER (TO_CHAR (ADD_MONTHS (SYSDATE, -1), 'YYYY'))
                                 ,TO_NUMBER (TO_CHAR (ADD_MONTHS (SYSDATE, -1), 'MM'))
                                 );
      -- kontrollime jooksva kuu SEUS'i olemasolu
      lnseus := get_active_seus (pnsusg, pnsety, cn_year, cn_month);
      insert_batch_messages (cc_module_ref
                            ,'Limit_Tracking INFO'
                            ,cn_others
                            ,'Prepare after lnseus, lnoseus'
                            , 'lnoseus: ' || lnoseus || ' lnseus: ' || lnseus
                            );

      -- kui jooksvas kuus puudub seus kirje
      IF lnseus = 0 THEN
         -- kui eelmises kuus oli seus kirje
         IF lnoseus > 0 THEN
            -- paneme eelmise kuu seus kirje passiivseks status = 'PSV'
            stop_usage (pnsusg
                       ,pnsety
                       ,TO_NUMBER (TO_CHAR (ADD_MONTHS (SYSDATE, -1), 'YYYY'))
                       ,TO_NUMBER (TO_CHAR (ADD_MONTHS (SYSDATE, -1), 'MM'))
                       ,pnbapr
                       );
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking INFO'
                                  ,cn_others
                                  ,'Prepare'
                                  ,'Prepare after stop_usage'
                                  );

            -- kontrollime kas eelmisest kuust on vaja tuua
            SELECT GREATEST (NVL (NVL (seus.VALUE, 0) + NVL (seus.fix_value, 0) - seus.limit_value, 0), 0)
              INTO lnover
              FROM service_usages seus
             WHERE seus.ref_num = lnoseus;

            lnseus := get_active_seus (pnsusg, pnsety, cn_year, cn_month);

            IF lnseus > 0 THEN
               set_over_limit (lnseus, lnover);
            END IF;
         ELSE
            -- tekitame uue seus kirje
            start_new_usage (pnsusg, pnsety, cn_year, cn_month, 0, lnseus);
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking INFO'
                                  ,cn_others
                                  ,'Prepare'
                                  ,'Prepare after start_new_usage'
                                  );
         END IF;
      END IF;

       -- DBMS_OUTPUT.PUT_LINE('lnSEUS = '||to_char(lnSEUS));
      -- pärime kasutaja poolt tellitud limiidi suuruse
      lnlimit := get_limit_value (pnsusg, pnsety, SYSDATE);   --upr1886

      -- DBMS_OUTPUT.put_line ('--');                                                                               --upr1886
      -- DBMS_OUTPUT.put_line ('LIMIT: ' || lnlimit);                                                               --upr1886
      -- DBMS_OUTPUT.put_line ('SUSG : ' || pnsusg);                                                                --upr1886
      SELECT ref_num
            ,status
            ,limit_value
        INTO lnseus
            ,lcstatus
            ,lnlimitx
        FROM service_usages
       WHERE susg_ref_num = pnsusg
         AND sety_ref_num = pnsety
         AND YEAR = cn_year
         AND MONTH = cn_month
         AND (date_updated <= pdtime OR date_updated IS NULL);

      insert_batch_messages (cc_module_ref
                            ,'Limit_Tracking INFO'
                            ,cn_others
                            ,'Prepare'
                            , 'lnlimit: ' || lnlimit || ' lnlimitx: ' || lnlimitx
                            );

      IF lcstatus IN ('AC', 'IGN') THEN
         -- DBMS_OUTPUT.put_line ('seus : ' || lnseus );                                      --upr1886
         UPDATE service_usages
            SET status = 'CTRL'
               ,limit_value = lnlimit
               ,
                --upr1886 hetkel seatud piirsumma hilisema v?rdluse tarbeks
                date_updated = SYSDATE
               ,last_updated_by = cc_module_ref
          WHERE ref_num = lnseus;

         COMMIT;
         -- DBMS_OUTPUT.PUT_LINE('SEUS exists');
         RETURN 1;
      ELSIF lnlimit != lnlimitx THEN
         when_limit_value_updated (pnsusg, pnsety, lnlimit, pnbapr);
         COMMIT;
         RETURN 1;
      ELSE
         RETURN 0;
      END IF;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         -- DBMS_OUTPUT.PUT_LINE('SEUS not exists');
         RETURN 0;
      WHEN OTHERS THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Prepare', SQLERRM);
         COMMIT;
         RETURN 0;
   END;

   -- *** --
   -- Etteantud teenuse mahu arvutamine
   FUNCTION calculate (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER IS
      lnseus                        NUMBER;
      lclevel                       VARCHAR2 (7);
      lnvalue                       NUMBER;
   BEGIN
      -- DBMS_OUTPUT.PUT_LINE('Calculate started at '||to_char(sysdate,'dd.mm.yy hh24:mi:ss'));
      SELECT ref_num
            ,service_level
        INTO lnseus
            ,lclevel
        FROM service_usages
       WHERE susg_ref_num = pnsusg AND sety_ref_num = pnsety AND YEAR = cn_year AND MONTH = cn_month AND status = 'CTRL';

      -- AND date_updated <= pdtime; -- ver 1.8 by IJ
      IF lclevel = 'SERVICE' THEN
         lnvalue := get_service_usage_value (pnsusg, pnsety, SYSDATE);
      ELSE
         lnvalue := get_mobile_usage_value (pnsusg, pnsety, SYSDATE);
      END IF;

      UPDATE service_usages
         SET VALUE = lnvalue
            ,date_updated = SYSDATE
            ,last_updated_by = cc_module_ref
       WHERE ref_num = lnseus;

      COMMIT;
      -- DBMS_OUTPUT.PUT_LINE('SEUS updated');
      RETURN 1;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         -- DBMS_OUTPUT.PUT_LINE('SEUS not updated');
         RETURN 0;
      WHEN OTHERS THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Calculate', SQLERRM);
         COMMIT;
         RETURN 0;
   END;

   -- *** --
   -- Etteantud teenuse fikseeritud maksete mahu arvutamine
   FUNCTION fix_calculate (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER IS
      lnseus                        NUMBER;
      lclevel                       VARCHAR2 (7);
      lnvalue                       NUMBER;
   BEGIN
      -- DBMS_OUTPUT.PUT_LINE('Fix Calculate started at '||to_char(sysdate,'dd.mm.yy hh24:mi:ss'));
      SELECT ref_num
            ,service_level
        INTO lnseus
            ,lclevel
        FROM service_usages
       WHERE susg_ref_num = pnsusg AND sety_ref_num = pnsety AND YEAR = cn_year AND MONTH = cn_month AND status = 'CTRL';

      -- AND date_updated <= pdtime; -- ver 1.8 by IJ
      IF lclevel = 'SERVICE' THEN
         lnvalue := get_service_usage_fix_value (pnsusg, pnsety, SYSDATE);
      ELSE
         lnvalue := get_mobile_usage_fix_value (pnsusg, pnsety, SYSDATE);
      END IF;

      -- insert into test values ('f:'||pnsusg||':'||pnsety||':'||lnvalue); commit;
      UPDATE service_usages
         SET fix_value = lnvalue
            ,date_updated = SYSDATE
            ,last_updated_by = cc_module_ref
       WHERE ref_num = lnseus;

      COMMIT;
      -- DBMS_OUTPUT.PUT_LINE('SEUS updated');
      RETURN 1;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         -- DBMS_OUTPUT.PUT_LINE('SEUS not updated');
         RETURN 0;
      WHEN OTHERS THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Fix_Calculate', SQLERRM);
         COMMIT;
         RETURN 0;
   END;

   /* Class: Limit Tracking Service / Limiidi jälgimise teenus */
   -- Limiidi kontrollimine etteantud teenuse juures
   FUNCTION check_limit (
      pnsusg  NUMBER
     ,pnsety  NUMBER
   )
      RETURN NUMBER IS
      lnlimit                       NUMBER;
      lnres                         NUMBER;
      seus_rec                      service_usages%ROWTYPE;
   BEGIN
      SELECT *
        INTO seus_rec
        FROM service_usages
       WHERE susg_ref_num = pnsusg AND sety_ref_num = pnsety AND YEAR = cn_year AND MONTH = cn_month AND status = 'CTRL';

      -- Eeldame, et PREPARE() värskendas juba limit_value väärtust.
      lnlimit := seus_rec.limit_value;
                                 -- get_limit_value (pnsusg, pnsety, sysdate);
      /*
      K?igil tasemetel tuleb v?rreldavast limiidist lahutada eelmisel
      perioodil üle limiidi läinud summa (SERVICE_USAGE.OVER_LIMIT).
      */
      lnlimit := lnlimit - seus_rec.over_limit;

      IF NVL (seus_rec.VALUE, 0) + NVL (seus_rec.fix_value, 0) >= lnlimit THEN
         -- limiidi ületamise tegevused
         set_usage_status (seus_rec.ref_num, 'LMO');
         init_action (seus_rec.ref_num);
         lnres := 1;
      ELSE
         -- limiiti ei ole veel täis
         set_usage_status (seus_rec.ref_num, 'AC');
         lnres := 0;
      END IF;

      COMMIT;
      RETURN lnres;
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN 0;
      WHEN OTHERS THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Check_Limit', SQLERRM);
         COMMIT;
         RETURN 0;
   END check_limit;

   -- *** --
   -- Etteantud teenuse limiidi suuruse pärimine
   FUNCTION get_limit_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER IS
      res                           NUMBER;

      CURSOR cur_limit IS
         SELECT   TO_NUMBER (NVL (sspa.param_value, sepv.param_value)) LIMIT
             FROM subs_service_parameters sspa, service_parameters sepa, service_param_values sepv
            WHERE sspa.susg_ref_num = pnsusg
              AND sspa.sety_ref_num = pnsety
              AND sspa.sepa_ref_num = sepa.ref_num
              AND sepa.nw_param_name = cc_tl_tunnus
              AND sspa.start_date <= pdtime
              AND (sspa.end_date IS NULL OR sspa.end_date > pdtime)
              AND sepv.ref_num(+) = sspa.sepv_ref_num
         ORDER BY sspa.start_date DESC;
   BEGIN
      OPEN cur_limit;

      FETCH cur_limit
       INTO res;

      IF cur_limit%NOTFOUND THEN
         res := NULL;
      END IF;

      CLOSE cur_limit;

      RETURN res;
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Get_Limit_Value', SQLERRM);
         COMMIT;
         RETURN NULL;
   END get_limit_value;

   -- *** --
   -- Limiidi suuruse muutmisega kaasnevad tegevused
   PROCEDURE when_limit_value_updated (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pnlim   NUMBER
     ,pnbapr  NUMBER
   ) IS
      lcstat                        service_usages.status%TYPE;
      lnvalue                       service_usages.VALUE%TYPE;
      lnx                           NUMBER;
      lnpicnt                       NUMBER;
      lnlimitx                      service_usages.limit_value%TYPE;
      lctype_code                   service_types.type_code%TYPE;
      order_error                   EXCEPTION;
   BEGIN
      -- seus.status oleku pärimine susg.ref_num nig sety.ref_num alusel jooksva kuu kohta
      lcstat := get_usage_status (pnsusg, pnsety);

      IF lcstat IN ('ACT', 'LMO') THEN
         UPDATE service_usages
            SET limit_value = pnlim
               ,status = 'CTRL'
               ,date_updated = SYSDATE
          WHERE susg_ref_num = pnsusg AND sety_ref_num = pnsety AND YEAR = cn_year AND MONTH = cn_month;

         lnx := calculate (pnsusg, pnsety, SYSDATE);
         lnx := fix_calculate (pnsusg, pnsety, SYSDATE);
         lnvalue := get_usage_value (pnsusg, pnsety, SYSDATE);

         -- kui limiit on suurem kui kasutatud teenuste maht
         IF lnvalue < pnlim THEN
            UPDATE service_usages
               SET status = 'AC'
                  ,date_updated = SYSDATE
             WHERE susg_ref_num = pnsusg AND sety_ref_num = pnsety AND YEAR = cn_year AND MONTH = cn_month;

            -- 'LMO' puhul pole side piiramiseni j?utud
            IF lcstat = 'ACT' THEN
               SELECT COUNT (1)
                 INTO lnpicnt
                 FROM subs_service_parameters susp, service_parameters sepa, service_param_values sepv
                WHERE susp.sety_ref_num = pnsety
                  AND susp.susg_ref_num = pnsusg
                  AND susp.sepv_ref_num = sepv.ref_num
                  AND sepa.ref_num = sepv.sepa_ref_num
                  AND sepa.nw_param_name = 'ACTION'
                  AND sepv.nw_param_value = 'PI';

               -- Kui on tegemist side piiramisega, siis eemaldada side piirang
               IF lnpicnt > 0 THEN
                  /*
                  kas pnsusg'il leidub cc_complete staatuses side piiramise order,
                  mis on seatud LIMIT_TRACKING'u ehk kasutaja cc_created_by poolt?
                  kui leidub, siis tühistada need orderid (neid ei saa vist > 1 olla,
                  aga igaks juhuks ...)
                  */
                  UPDATE user_requests
                     SET request_status = cc_canceled
                   WHERE ref_num IN (SELECT usre.ref_num
                                       FROM user_requests usre, subscriber_details sude, service_details sede
                                      WHERE usre.rety_type_code = cc_rety_type_code
                                        AND usre.request_status = cc_complete
                                        AND usre.ref_num = sude.usre_ref_num
                                        AND sude.created_by = cc_created_by
                                        AND sude.exis_susg_ref_num = pnsusg
                                        AND sude.ref_num = sede.sude_ref_num
                                        AND sede.service_name = cc_service_name
                                        AND sede.rety_type_code = cc_open);

                  IF SQL%ROWCOUNT = 0 THEN
                     /*
                     Kui ülal toodud tingimustele vastavaid kirjeid pole, siis:
                     a) LIMIT_TRACKING'u tellitud order on täidetud
                     v?i
                     b) susg v?ib olla ise tellinud side piiramise.
                     Olukorras (b) ei tee me midagi. Seega otsime HILISEIMA
                     execution_date väärtusega sulgemise v?i avamise cc_success/manula_ok v?i cc_complete (st susg)
                     orderi ja kontrollime, kes selle tellis. Kui tellija pole
                     cc_created_by, siis ei tee me midagi. Vastasel juhul tellime
                     side piiramise l?petamise orderi siis, kui klient pole ise vahepeal sidet avanud.
                     */
                     FOR rec_user IN (SELECT   usre.ref_num
                                              ,sude.created_by
                                              ,sede.rety_type_code
                                          FROM user_requests usre, subscriber_details sude, service_details sede
                                         WHERE usre.rety_type_code = cc_rety_type_code
                                           AND usre.request_status IN
                                                    (cc_complete, cc_success, or_common.manual_ok)   -- UPR-3249 manual_ok
                                           AND usre.ref_num = sude.usre_ref_num
                                           AND sude.exis_susg_ref_num = pnsusg
                                           AND sude.ref_num = sede.sude_ref_num
                                           AND sede.service_name = cc_service_name
                                           AND sede.rety_type_code IN (cc_open, cc_close)
                                      ORDER BY usre.execution_date DESC) LOOP
                        IF rec_user.rety_type_code = cc_open
                                                            /*   AND rec_user.created_by = cc_created_by CHG-2762 */
                        THEN
                           IF NOT insert_order (pnsusg, 'CLOSE', pnbapr) THEN
                              RAISE order_error;
                           END IF;
                        END IF;

                        EXIT;
                     END LOOP;
                  END IF;
               END IF;
            END IF;
         ELSE
            UPDATE service_usages
               SET status = lcstat
                  ,date_updated = SYSDATE
             WHERE susg_ref_num = pnsusg AND sety_ref_num = pnsety AND YEAR = cn_year AND MONTH = cn_month;
         END IF;
      END IF;

      COMMIT;
   EXCEPTION
      WHEN order_error THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'When_Limit_Value_Updated'
                               ,'Viga side piiramise l?petamise orderi esitamisel.'
                               );
         COMMIT;
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'When_Limit_Value_Updated', SQLERRM);
         COMMIT;
   END when_limit_value_updated;

   -- *** --
   -- Kuu l?petamise tegevused etteantud teenuse juures
   PROCEDURE finish_month (
      pnyear  NUMBER
     ,pnmon   NUMBER
   ) IS
      lnseus                        NUMBER;
      lnover                        NUMBER;
      l_success                     BOOLEAN;
      l_errtext                     VARCHAR2 (500);
      lnyear                        NUMBER := TO_NUMBER (TO_CHAR (LAST_DAY (SYSDATE - 15), 'YYYY'));
      lnmon                         NUMBER := TO_NUMBER (TO_CHAR (LAST_DAY (SYSDATE - 15), 'MM'));
      lnbapr                        NUMBER := 0;
      l_session_id                  VARCHAR2 (10) := USERENV ('sessionid');
      cnt                           NUMBER;

      CURSOR c IS
         SELECT *
           FROM service_usages
          WHERE YEAR = lnyear AND MONTH = lnmon AND status != 'PSV';
   BEGIN
      insert_batch_messages (cc_module_ref, 'Limit_Tracking INFO', cn_info, 'Finish_Month', 'START');

      IF NVL (pnyear, 0) > 0 THEN
         lnyear := pnyear;
      END IF;

      IF NVL (pnmon, 0) > 0 THEN
         lnmon := pnmon;
      END IF;

      insert_batch_messages (cc_module_ref
                            ,'Limit_Tracking INFO'
                            ,cn_info
                            ,'Finish_Month'
                            , 'pnYear: ' || TO_CHAR (lnyear, 9999)
                            );
      insert_batch_messages (cc_module_ref
                            ,'Limit_Tracking INFO'
                            ,cn_info
                            ,'Finish_Month'
                            , 'pnMon: ' || TO_CHAR (lnmon, 99)
                            );
      register_batch_processes.start_process (sec.get_username
                                             ,l_session_id
                                             ,'FMON'
                                             ,'Finish month'
                                             ,NULL
                                             ,'PROC'
                                             ,SYSDATE
                                             ,get_system_parameter (151)
                                             ,get_system_parameter (152)
                                             ,get_system_parameter (153)
                                             ,NULL
                                             ,NULL
                                             ,NULL
                                             ,NULL
                                             ,l_success
                                             ,l_errtext
                                             );

      IF l_success THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Finish_Month'
                               ,'Batch process record created'
                               );

         SELECT MAX (ref_num)
           INTO lnbapr
           FROM batch_processes
          WHERE session_id = l_session_id;

         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Finish_Month'
                               , 'BATCH_PROCESS.REF_NUM: ' || lnbapr
                               );
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Finish_Month'
                               ,'  STOP_USAGE loop started'
                               );

         FOR r IN c LOOP
            limit_tracking.stop_usage (r.susg_ref_num, r.sety_ref_num, lnyear, lnmon, lnbapr);
         END LOOP;

         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Finish_Month'
                               ,'  STOP_USAGE loop finished'
                               );

         SELECT COUNT (1)
           INTO cnt
           FROM user_requests usre
          WHERE usre.bapr_ref_num = lnbapr;

         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking INFO'
                               ,cn_info
                               ,'Finish_Month'
                               , '  selected count = ' || cnt
                               );

         IF cnt > 0 THEN
            UPDATE batch_processes
               SET status = cc_bapr_complete
                  ,selected_count = cnt
             WHERE ref_num = lnbapr;

            insert_batch_messages (cc_module_ref, 'Limit_Tracking INFO', cn_info, 'Finish_Month', '  updating record');
         ELSE
            DELETE FROM batch_processes
                  WHERE ref_num = lnbapr;

            insert_batch_messages (cc_module_ref, 'Limit_Tracking INFO', cn_info, 'Finish_Month', '  removing record');
         END IF;

         COMMIT;
      ELSE
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Finish_Month'
                               , 'Error on registering batch process: ' || l_errtext
                               );
      END IF;

      insert_batch_messages (cc_module_ref, 'Limit_Tracking INFO', cn_info, 'Finish_Month', 'END');
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Finish_Month', SQLERRM);
         COMMIT;
   END finish_month;   /* Class: Service Usage / Teenuse kasutusinfo */

   -- Uue SEUS kirje tekitamine
   PROCEDURE start_new_usage (
      pnsusg       NUMBER
     ,pnsety       NUMBER
     ,pnyear       NUMBER
     ,pnmon        NUMBER
     ,pnover       NUMBER
     ,pnseus  OUT  NUMBER
   ) IS
      lnseus                        NUMBER;
      lncnt                         NUMBER;
      lclevel                       VARCHAR2 (7);
   BEGIN
      SELECT COUNT (1)
        INTO lnseus
        FROM status_periods stpe
       WHERE stpe.susg_ref_num = pnsusg
         AND stpe.sety_ref_num = pnsety
         AND stpe.start_date < SYSDATE
         AND (stpe.end_date IS NULL OR stpe.end_date > SYSDATE);

      IF lnseus > 0 THEN
         SELECT COUNT (1)
           INTO lncnt
           FROM bise_sety
          WHERE sety_ref_num = pnsety
            AND start_date <= SYSDATE
            AND (end_date IS NULL OR end_date > SYSDATE)
            AND group_name = cc_tl_tunnus;

         IF lncnt = 0 THEN
            lclevel := 'MOBILE';
         ELSE
            lclevel := 'SERVICE';
         END IF;

         SELECT seus_ref_num_s.NEXTVAL
           INTO lnseus
           FROM SYS.DUAL;

         INSERT INTO service_usages
                     (ref_num
                     ,susg_ref_num
                     ,sety_ref_num
                     ,YEAR
                     ,MONTH
                     ,service_level
                     ,VALUE
                     ,fix_value
                     ,over_limit
                     ,status
                     ,created_by
                     ,date_created
                     )
              VALUES (lnseus
                     ,pnsusg
                     ,pnsety
                     ,pnyear
                     ,pnmon
                     ,lclevel
                     ,0
                     ,0
                     ,pnover
                     ,'AC'
                     ,cc_module_ref
                     ,SYSDATE
                     );

         pnseus := lnseus;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Start_New_Usage', SQLERRM);
         COMMIT;
         pnseus := NULL;
   END start_new_usage;

   -- *** --
   -- Kasutatud teenuste mahu küsimine
   FUNCTION get_usage_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER IS
      lnvalue                       service_usages.VALUE%TYPE;
   BEGIN
      SELECT NVL (VALUE, 0) + NVL (fix_value, 0)
        INTO lnvalue
        FROM service_usages
       WHERE susg_ref_num = pnsusg
         AND sety_ref_num = pnsety
         AND YEAR = TO_NUMBER (TO_CHAR (pdtime, 'YYYY'))
         AND MONTH = TO_NUMBER (TO_CHAR (pdtime, 'MM'));

      RETURN lnvalue;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   -- *** --
   -- Kasutatud teenuste mahu leidmine mobiili tasemel
   FUNCTION get_mobile_usage_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER IS
      lnres                         NUMBER := 0;
      lnres2                        NUMBER := 0;
      lnmaac                        NUMBER;
      lcunit                        service_param_values.param_value%TYPE;
   BEGIN
      lnmaac := gen_bill.maac_ref_num_by_susg (pnsusg);

      IF lnmaac IS NOT NULL THEN
         lcunit := get_limit_unit (pnsety);

         -- if charging unit is money (EEK, EUR)
         IF lcunit = get_pri_curr_code   -- CHG-4594
                                      THEN
            SELECT SUM (  NVL (inen.eek_amt, 0)
                        + NVL (inen.amt_tax
                              ,ROUND (  NVL (inen.eek_amt, 0)
                                      * gen_bill.get_tax_rate (inen.taty_type_code
                                                              ,   LAST_DAY (TRUNC (NVL (invo.invo_start
                                                                                       ,invo.period_start
                                                                                       )
                                                                                  )
                                                                           )
                                                                + 1
                                                                - cn_sec
                                                              -- invoice period last day 23:59:59
                                                              )
                                     ,3  -- CHG-4899: Round(,3)
                                     )
                              )
                       )
              INTO lnres
              FROM invoices invo, invoice_entries inen
             WHERE invo.maac_ref_num = lnmaac
               AND invo.period_start >= TRUNC (pdtime, 'MONTH')
               AND invo.period_start < ADD_MONTHS (TRUNC (pdtime, 'MONTH'), 1)
               AND invo.billing_inv = 'Y'
               AND invo.credit = 'N'
               AND inen.invo_ref_num = invo.ref_num
               AND inen.susg_ref_num = pnsusg
               AND inen.fcit_type_code IS NULL   -- CHG-3360
               /* CHG-3360: Eemaldatud OnceOff teenused
               AND (   inen.fcit_type_code IS NULL
                    OR inen.fcit_type_code IN (
                              SELECT fcit.type_code
                                FROM fixed_charge_item_types fcit
                               WHERE fcit.once_off = 'Y'
                                     AND fcit.ARCHIVE = 'N')
                   ) */
               AND (inen.cadc_ref_num IS NULL
                    OR   -- CHG-3360
                      inen.cadc_ref_num IN (SELECT ref_num   -- CHG-4148
                                              FROM call_discount_codes
                                             WHERE call_type IN ('MIN', 'CONN', 'REGU', 'MON'))
                   )
               AND inen.vmct_type_code IS NULL;
         -- if charged by kilobytes
         ELSIF lcunit = cc_tldata_unit THEN   /* UPR-2797 */
            SELECT SUM (NVL (inen.evre_data_volume, 0))
              INTO lnres
              FROM invoices invo, invoice_entries inen
             WHERE invo.maac_ref_num = lnmaac
               AND invo.period_start >= TRUNC (pdtime, 'MONTH')
               AND invo.period_start < ADD_MONTHS (TRUNC (pdtime, 'MONTH'), 1)
               AND invo.billing_inv = 'Y'
               AND invo.credit = 'N'
               AND inen.invo_ref_num = invo.ref_num
               AND inen.susg_ref_num = pnsusg
               AND inen.evre_data_volume <> 0
               AND inen.billing_selector NOT IN (SELECT evty_billing_selector
                                                   FROM evty_tacl_v
                                                  WHERE roaming = 'Y')
               AND inen.fcit_type_code IS NULL   -- CHG-3360
               /* CHG-3360: Eemaldatud OnceOff teenused
               AND (   inen.fcit_type_code IS NULL
                    OR inen.fcit_type_code IN (
                              SELECT fcit.type_code
                                FROM fixed_charge_item_types fcit
                               WHERE fcit.once_off = 'Y'
                                     AND fcit.ARCHIVE = 'N')
                   ) */
               AND inen.vmct_type_code IS NULL;
         -- if charged by minut
         ELSIF lcunit = cc_tltime_unit THEN                                                          /* UPR-3137
                                              CHG-3970 muudetud teenuse loogika arvepõhiseks päringuks, palju on jooksvas kuus minuteid kasutatud
                                              */
            -- DBMS_OUTPUT.put_line ('MOBILE-MINUT for ' || pnsusg || ' found');
            SELECT ROUND (SUM (GREATEST (NVL (inen.evre_char_usage, 0), inen.evre_duration)) / 60, 0)
              INTO lnres
              FROM invoices invo, invoice_entries inen
             WHERE invo.maac_ref_num = lnmaac
               AND invo.period_start >= TRUNC (pdtime, 'MONTH')
               AND invo.period_start < ADD_MONTHS (TRUNC (pdtime, 'MONTH'), 1)
               AND invo.billing_inv = 'Y'
               AND invo.credit = 'N'
               AND inen.invo_ref_num = invo.ref_num
               AND inen.susg_ref_num = pnsusg
               AND inen.evre_duration <> 0
               AND inen.billing_selector NOT IN (SELECT evty_billing_selector
                                                   FROM evty_tacl_v
                                                  WHERE roaming = 'Y')
               AND inen.evre_data_volume IS NULL
               AND inen.fcit_type_code IS NULL
               AND cadc_ref_num IS NULL;
         -- DBMS_OUTPUT.put_line ('MOBILE-MINUT value = ' || lnres);
         END IF;
      END IF;

      RETURN NVL (lnres, 0);
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Get_Mobile_Usage_Value'
                               , TO_CHAR (lnres) || ':' || SQLERRM
                               );
         COMMIT;
         RETURN NULL;
   END get_mobile_usage_value;

   -- *** --
   -- Kasutatud teenuste mahu leidmine teenuse tasemel
   FUNCTION get_service_usage_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER IS
      lnres                         NUMBER := 0;
      lnres2                        NUMBER := 0;
      lnmaac                        NUMBER;
      lcunit                        service_param_values.param_value%TYPE;
   BEGIN
      lnmaac := gen_bill.maac_ref_num_by_susg (pnsusg);

      IF lnmaac IS NOT NULL THEN
         lcunit := get_limit_unit (pnsety);

         IF lcunit = get_pri_curr_code   -- CHG-4594
                                      THEN
            SELECT SUM (  NVL (inen.eek_amt, 0)
                        + NVL (inen.amt_tax
                              ,ROUND (  NVL (inen.eek_amt, 0)
                                      * gen_bill.get_tax_rate (inen.taty_type_code
                                                              ,   LAST_DAY (TRUNC (NVL (invo.invo_start
                                                                                       ,invo.period_start
                                                                                       )
                                                                                  )
                                                                           )
                                                                + 1
                                                                - cn_sec
                                                              -- invoice period last day 23:59:59
                                                              )
                                     ,3  -- CHG-4899: Round(,3)
                                     )
                              )
                       )
              INTO lnres
              FROM invoices invo, invoice_entries inen, bise_sety b
             WHERE invo.maac_ref_num = lnmaac
               AND invo.period_start >= TRUNC (pdtime, 'MONTH')
               AND invo.period_start < ADD_MONTHS (TRUNC (pdtime, 'MONTH'), 1)
               AND invo.billing_inv = 'Y'
               AND invo.credit = 'N'
               AND inen.invo_ref_num = invo.ref_num
               AND inen.susg_ref_num = pnsusg
               AND inen.fcit_type_code IS NULL   -- CHG-3360
               /* CHG-3360: Eemaldatud OnceOff teenused
               AND (   inen.fcit_type_code IS NULL
                    OR inen.fcit_type_code IN (
                              SELECT fcit.type_code
                                FROM fixed_charge_item_types fcit
                               WHERE fcit.once_off = 'Y'
                                     AND fcit.ARCHIVE = 'N')
                   ) */
               AND inen.vmct_type_code IS NULL
               AND inen.billing_selector = b.billing_selector
               AND b.sety_ref_num = pnsety
               AND b.start_date <= pdtime
               AND (b.end_date > pdtime OR b.end_date IS NULL)
               AND inen.cadc_ref_num IS NULL   -- CHG-3360
               AND b.group_name = cc_tl_tunnus;
         ELSIF lcunit = cc_tldata_unit THEN   /* UPR-2797 */
            SELECT SUM (NVL (inen.evre_data_volume, 0))
              INTO lnres
              FROM invoices invo, invoice_entries inen, bise_sety b
             WHERE invo.maac_ref_num = lnmaac
               AND invo.period_start >= TRUNC (pdtime, 'MONTH')
               AND invo.period_start < ADD_MONTHS (TRUNC (pdtime, 'MONTH'), 1)
               AND invo.billing_inv = 'Y'
               AND invo.credit = 'N'
               AND inen.invo_ref_num = invo.ref_num
               AND inen.susg_ref_num = pnsusg
               AND inen.fcit_type_code IS NULL   -- CHG-3360
               /* CHG-3360: Eemaldatud OnceOff teenused
               AND (   inen.fcit_type_code IS NULL
                    OR inen.fcit_type_code IN (
                              SELECT fcit.type_code
                                FROM fixed_charge_item_types fcit
                               WHERE fcit.once_off = 'Y'
                                     AND fcit.ARCHIVE = 'N')
                   ) */
               AND inen.evre_data_volume IS NOT NULL
               AND inen.vmct_type_code IS NULL
               AND inen.billing_selector NOT IN (SELECT evty_billing_selector
                                                   FROM evty_tacl_v
                                                  WHERE roaming = 'Y')
               AND inen.billing_selector = b.billing_selector
               AND b.sety_ref_num = pnsety
               AND b.start_date <= pdtime
               AND (b.end_date > pdtime OR b.end_date IS NULL)
               AND inen.cadc_ref_num IS NULL   -- CHG-3360
               AND b.group_name = cc_tl_tunnus;
         ELSIF lcunit = cc_tltime_unit THEN
            --CHG-3970 muudetud teenuse loogika arvepõhiseks päringuks, palju on jooksvas kuus minuteid kasutatud
            SELECT FLOOR (SUM (GREATEST (NVL (inen.evre_char_usage, 0), inen.evre_duration)) / 60)
              INTO lnres
              FROM invoices invo, invoice_entries inen, bise_sety b
             WHERE invo.maac_ref_num = lnmaac
               AND invo.period_start >= TRUNC (pdtime, 'MONTH')
               AND invo.period_start < ADD_MONTHS (TRUNC (pdtime, 'MONTH'), 1)
               AND invo.billing_inv = 'Y'
               AND invo.credit = 'N'
               AND inen.invo_ref_num = invo.ref_num
               AND inen.susg_ref_num = pnsusg
               AND inen.evre_duration <> 0
               AND inen.billing_selector NOT IN (SELECT evty_billing_selector
                                                   FROM evty_tacl_v
                                                  WHERE roaming = 'Y')
               AND inen.evre_data_volume IS NULL
               AND inen.fcit_type_code IS NULL
               AND cadc_ref_num IS NULL
               AND inen.billing_selector = b.billing_selector
               AND b.sety_ref_num = pnsety
               AND b.start_date <= pdtime
               AND (b.end_date > pdtime OR b.end_date IS NULL)
               AND inen.cadc_ref_num IS NULL   -- CHG-3360
               AND b.group_name = cc_tl_tunnus;
         END IF;
      END IF;

      RETURN NVL (lnres, 0);
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Get_Service_Usage_Value'
                               , TO_CHAR (lnres) || ':' || SQLERRM
                               );
         COMMIT;
         RETURN NULL;
   END get_service_usage_value;

   -- *** --
   -- Fikseeritud maksete suuruse leidmine mobiili tasemel
   FUNCTION get_mobile_usage_fix_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   ) RETURN NUMBER IS
      --
      CURSOR c_ftco_mixed IS
         SELECT 1
         FROM fixed_term_contracts ftco
         WHERE susg_ref_num = pnsusg
           AND mixed_packet_code IS NOT NULL
           AND start_date <= TRUNC (LAST_DAY (pdtime)) + 1 - cn_sec
           AND Nvl(date_closed, end_date) > TRUNC (pdtime, 'MONTH')
      ;    
      --
      lnres                         NUMBER := 0;
      lnmaac                        NUMBER;
      lrinvo                        invoices%ROWTYPE;
      lbsuccess                     BOOLEAN;
      lbsuccess2                    BOOLEAN;   --upr1897
      lbsuccess3                    BOOLEAN;   -- CHG-3360
      l_error                       VARCHAR2 (500);   -- CHG-3360
      lcerr_mesg                    VARCHAR2 (200);
      lcunit                        service_param_values.param_value%TYPE;   -- UPR-2797
      l_found                       BOOLEAN; -- CHG-6068
      l_dummy                       NUMBER;  -- CHG-6068
   BEGIN
      -- insert into test values ('MF:'||pnsusg||':'||pnsety||':'||sec.get_username); commit;
      /* UPR-2797 */
      lcunit := get_limit_unit (pnsety);

      IF lcunit != get_pri_curr_code   -- CHG-4594
                                    THEN
         -- insert into test values ('!eek:'||pnsusg||':'||pnsety); commit;
         RETURN 0;
      END IF;

      /***/
      lnmaac := gen_bill.maac_ref_num_by_susg (pnsusg);

      IF lnmaac IS NOT NULL THEN
         create_interim_invo (lnmaac, lrinvo);
         -- insert into test values ('ii:'||lrinvo.ref_num); commit;
         lbsuccess := TRUE;
         calculate_fixed_charges.period_fixed_charges (lnmaac
                                                      ,pnsusg
                                                      ,lrinvo
                                                      ,lbsuccess
                                                      ,lcerr_mesg
                                                      ,TRUNC (pdtime, 'MONTH')
                                                      ,TRUNC (LAST_DAY (pdtime))
                                                      ,'I'
                                                      );

         IF NOT lbsuccess THEN
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking ERR'
                                  ,cn_others
                                  ,'Get_Mobile_Usage_Fix_Value'
                                  , 'period_fixed_charges error: ' || lcerr_mesg
                                  );
            COMMIT;
         -- insert into test values ('!lb:'||lcerr_mesg); commit;
         END IF;

         /*
           ** CHG-3180: Paketeeritud teenuspakettide paketitasud
         */
         process_packet_fees.bill_susg_packet_fees (lnmaac
                                                   ,lrinvo.ref_num
                                                   ,pnsusg
                                                   ,TRUNC (pdtime, 'MONTH')
                                                   , TRUNC (LAST_DAY (pdtime)) + 1 - cn_sec
                                                   ,lcerr_mesg
                                                   ,lbsuccess
                                                   ,TRUE   --p_interim_balance IN
                                                   );

         --
         IF NOT lbsuccess THEN
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking ERR'
                                  ,cn_others
                                  ,'Get_Mobile_Usage_Fix_Value'
                                  , 'bill_susg_packet_fees error: ' || lcerr_mesg
                                  );
            COMMIT;
         -- insert into test values ('!lb:'||lcerr_mesg); commit;
         END IF;

         /* End CHG-3180 */

         /*
           ** CHG-3360: Teenuste kuutasud, MinuEMT lahendustasud koos soodustustega.
         */
         process_monthly_service_fees.chk_mob_nonker_serv_fees_by_ma (lnmaac   --p_maac_ref_num
                                                                     ,lrinvo.ref_num   --p_invo_ref_num
                                                                     ,TRUNC (pdtime, 'MONTH')   --p_period_start
                                                                     ,   TRUNC (LAST_DAY (pdtime))
                                                                       + 1
                                                                       - cn_sec   --p_period_end
                                                                     ,lbsuccess3   --p_success
                                                                     ,l_error   --p_error_text
                                                                     ,pnsusg   --p_susg_ref_num
                                                                     ,TRUE   --p_interim
                                                                     );

         --
         IF NOT lbsuccess3 THEN
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking ERR'
                                  ,cn_others
                                  ,'Get_Mobile_Usage_Fix_Value'
                                  , 'nonker_serv_fees error: ' || l_error
                                  );
            COMMIT;
         END IF;

         /*
           ** DOBAS-1721: DCH tasud.
         */
         process_daily_charges.proc_daily_charges_ma (lnmaac   --p_maac_ref_num
                                                                     ,lrinvo.ref_num   --p_invo_ref_num
                                                                     ,TRUNC (pdtime, 'MONTH')   --p_period_start
                                                                     ,TRUNC (LAST_DAY (pdtime))   --p_period_end
                                                                     ,lbsuccess3   --p_success
                                                                     ,l_error   --p_error_text
                                                                     ,pnsusg   --p_susg_ref_num
                                                                     ,TRUE   --p_interim
                                                                     );

         --
         IF NOT lbsuccess3 THEN
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking ERR'
                                  ,cn_others
                                  ,'Get_Mobile_Usage_Fix_Value'
                                  , 'daily_charges error: ' || l_error
                                  );
            COMMIT;
         END IF;
         /*
           ** CHG-3360: Miinimumarve ja MinuEMT asenduspaketitasu
         */
         calculate_fixed_charges.calc_non_prorata_maac_pkg_chg
                                                      (lnmaac   --p_maac_ref_num     IN      accounts.ref_num%TYPE
                                                      ,pnsusg   --p_susg_ref_num     IN      subs_serv_groups.ref_num%TYPE
                                                      ,lrinvo.ref_num   --p_invo_ref_num     IN      invoices.ref_num%TYPE
                                                      ,TRUNC (pdtime, 'MONTH')   --p_period_start     IN      DATE
                                                      ,   TRUNC (LAST_DAY (pdtime))
                                                        + 1
                                                        - cn_sec   --p_period_end       IN      DATE   -- 23:59:59
                                                      ,lbsuccess3   --p_success          OUT     BOOLEAN
                                                      ,l_error   --p_error_text       OUT     VARCHAR2
                                                      ,TRUE   --p_interim_balance  IN      BOOLEAN DEFAULT FALSE
                                                      );

         --
         IF NOT lbsuccess3 THEN
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking ERR'
                                  ,cn_others
                                  ,'Get_Mobile_Usage_Fix_Value'
                                  , 'non_prorata_pkg_chg error: ' || l_error
                                  );
            COMMIT;
         END IF;
         
         /*
           ** CHG-6068: Paketeeritud müügi seadmete kuutasud
         */
         OPEN  c_ftco_mixed;
         FETCH c_ftco_mixed INTO l_dummy;
         l_found := c_ftco_mixed%FOUND;
         CLOSE c_ftco_mixed;
         --
         IF l_found THEN
            -- Seadmete kuutasud
            Process_Mixed_Packet_Fees.Bill_One_MAAC_Packet_Orders (
                    lnmaac                                --p_maac_ref_num    IN     accounts.ref_num%TYPE
                   ,Trunc(pdtime, 'MONTH')                --p_period_start    IN     DATE
                   ,Trunc(LAST_DAY (pdtime)) + 1 - cn_sec --p_period_end      IN     DATE
                   ,lbsuccess3                            --p_success            OUT BOOLEAN
                   ,l_error                               --p_error_text         OUT VARCHAR2
                   ,lrinvo.ref_num                        --p_invo_ref_num    IN     invoices.ref_num%TYPE DEFAULT NULL
                   ,pnsusg                                --p_susg_ref_num    IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                   ,'N'                                   --p_commit          IN     VARCHAR2 DEFAULT 'Y'
                   ,TRUE                                  --p_interim         IN     BOOLEAN DEFAULT FALSE  -- CHG-6068
            );
            --
            IF NOT lbsuccess3 THEN
               insert_batch_messages (cc_module_ref
                                     ,'Limit_Tracking ERR'
                                     ,cn_others
                                     ,'Get_Mobile_Usage_Fix_Value'
                                     ,' Bill_One_MAAC_Packet_Orders error: ' || l_error
                                     );
               COMMIT;
            END IF;
            --
         END IF;
         
         

         lbsuccess2 := TRUE;   --upr1897
         close_interim_billing_invoice.calc_interim_taxes (lbsuccess2, lcerr_mesg, lrinvo.ref_num);

         --upr1897
         IF lbsuccess THEN
            -- käibemaksu arvutamise eba?nnestumine ei takista jätkumist
            SELECT SUM (  NVL (inen.eek_amt, 0)
                        + NVL (inen.amt_tax
                              ,ROUND (NVL (inen.eek_amt, 0) * gen_bill.get_tax_rate (inen.taty_type_code, pdtime
                                                                                                                -- SYSDATE in fact
                                                             ), 3)  -- CHG-4899: Round(,3)
                              )
                       )
              INTO lnres
              FROM invoice_entries_interim inen
             WHERE inen.invo_ref_num = lrinvo.ref_num AND inen.susg_ref_num = pnsusg
                                                                                    /* CHG-3360: Võetakse sisse kõik interimi kirjed, sealhulgas soodustused
                                                                                    AND inen.fcit_type_code IN (
                                                                                           SELECT fcit.type_code
                                                                                             FROM fixed_charge_item_types fcit
                                                                                            WHERE fcit.once_off = 'N'
                                                                                              AND fcit.pro_rata = 'Y'
                                                                                              AND fcit.regular_charge = 'Y'
                                                                                              AND fcit.ARCHIVE = 'N')
                                                                                    */
                   AND inen.vmct_type_code IS NULL;

            -- insert into test values ('sum:'||lnres||':'||lrinvo.ref_num); commit;

            -- CHG-3360: Kui haldustasu on suurem fix tasudest, tagastada haldustasu.
            -- Vastasel korral tagastada fix tasude summa ilma haldustasuta.
            lnres := get_minb_calculated_value (pnsusg   --p_susg_ref_num    NUMBER
                                               ,lrinvo.ref_num   --p_invo_ref_num    NUMBER
                                               ,lnres   --p_total_int_value NUMBER
                                               ,pdtime   --p_chk_date        DATE
                                               );
         ELSE
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking ERR'
                                  ,cn_others
                                  ,'Get_Mobile_Usage_Fix_Value'
                                  ,'Can NOT calculate Monthly Charges. Unknown Bill Period.'
                                  );
            COMMIT;
         END IF;
      -- else insert into test values ('!ma:'||pnsusg||':'||pnsety); commit;
      END IF;

      RETURN NVL (lnres, 0);
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Get_Mobile_Usage_Fix_Value'
                               , TO_CHAR (lnres) || ':' || SQLERRM
                               );
         COMMIT;
         RETURN NULL;
   END get_mobile_usage_fix_value;

   -- *** --
   -- Fikseeritud maksete suuruse leidmine teenuse tasemel
   FUNCTION get_service_usage_fix_value (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pdtime  DATE
   )
      RETURN NUMBER IS
      lnres                         NUMBER := 0;
      lnmaac                        NUMBER;
      lrinvo                        invoices%ROWTYPE;
      lbsuccess                     BOOLEAN;
      lbsuccess2                    BOOLEAN;
      lbsuccess3                    BOOLEAN;   -- CHG-3180
      lcerr_mesg                    VARCHAR2 (200);
      lcunit                        service_param_values.param_value%TYPE;   -- UPR-2797
   BEGIN
      -- insert into test values ('S:'||pnsusg||':'||pnsety); commit;
      /* UPR-2797 */
      lcunit := get_limit_unit (pnsety);

      IF lcunit != get_pri_curr_code   -- CHG-4594
                                    THEN
         RETURN 0;
      END IF;

      /***/
      lnmaac := gen_bill.maac_ref_num_by_susg (pnsusg);

      IF lnmaac IS NOT NULL THEN
         create_interim_invo (lnmaac, lrinvo);
         lbsuccess := TRUE;
         calculate_fixed_charges.period_fixed_charges (lnmaac
                                                      ,pnsusg
                                                      ,lrinvo
                                                      ,lbsuccess
                                                      ,lcerr_mesg
                                                      ,TRUNC (pdtime, 'MONTH')
                                                      ,TRUNC (LAST_DAY (pdtime))
                                                      ,'I'
                                                      );
         lbsuccess2 := TRUE;
         /*
           ** CHG-3180: Paketeeritud teenuspakettide paketitasud
         */
         lbsuccess3 := TRUE;
         --
         process_packet_fees.bill_susg_packet_fees (lnmaac
                                                   ,lrinvo.ref_num
                                                   ,pnsusg
                                                   ,TRUNC (pdtime, 'MONTH')
                                                   ,TRUNC (LAST_DAY (pdtime))
                                                   ,lcerr_mesg
                                                   ,lbsuccess3
                                                   ,TRUE   --p_interim_balance IN
                                                   );
         --                                  --upr1897
         close_interim_billing_invoice.calc_interim_taxes (lbsuccess2, lcerr_mesg, lrinvo.ref_num);

         --upr1897
         IF lbsuccess THEN
            SELECT SUM (  NVL (inen.eek_amt, 0)
                        + NVL (inen.amt_tax
                              ,ROUND (NVL (inen.eek_amt, 0) * gen_bill.get_tax_rate (inen.taty_type_code, pdtime
                                                                                                                -- SYSDATE in fact
                                                             ), 3)  -- CHG-4899: Round(,3)
                              )
                       )
              INTO lnres
              FROM invoice_entries_interim inen, bise_sety b
             WHERE inen.invo_ref_num = lrinvo.ref_num
               AND inen.susg_ref_num = pnsusg
               AND inen.fcit_type_code IN (SELECT fcit.type_code
                                             FROM fixed_charge_item_types fcit
                                            WHERE fcit.once_off = 'N'
                                              AND fcit.pro_rata = 'Y'
                                              AND fcit.regular_charge = 'Y'
                                              AND fcit.ARCHIVE = 'N'
                                              AND fcit.billing_selector = inen.billing_selector)
               AND inen.vmct_type_code IS NULL
               AND inen.billing_selector = b.billing_selector
               AND b.sety_ref_num = pnsety
               AND b.start_date <= pdtime
               AND (b.end_date > pdtime OR b.end_date IS NULL)
               AND b.group_name = cc_tl_tunnus;
         ELSE
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking ERR'
                                  ,cn_others
                                  ,'Get_Service_Usage_Fix_Value'
                                  , 'Can NOT calculate Monthly Charges. Unknown Bill Period. ' || lcerr_mesg
                                  );
            COMMIT;
         END IF;

         /* CHG-3180 */
         IF NOT lbsuccess3 THEN
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking ERR'
                                  ,cn_others
                                  ,'Get_Service_Usage_Fix_Value'
                                  , 'Error when processing packet fees: ' || lcerr_mesg
                                  );
            COMMIT;
         END IF;
      END IF;

      RETURN NVL (lnres, 0);
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Get_Service_Usage_Fix_Value'
                               , TO_CHAR (lnres) || ':' || SQLERRM
                               );
         COMMIT;
         RETURN NULL;
   END get_service_usage_fix_value;

   -- *** --
   -- SEUS kirje oleku muutmine
   PROCEDURE set_usage_status (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pcstat  VARCHAR2
   ) IS
      lnseus                        NUMBER;
   BEGIN
      lnseus := get_active_seus (pnsusg, pnsety, cn_year, cn_month);

      IF NVL (lnseus, 0) > 0 THEN
         set_usage_status (lnseus, pcstat);
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Set_Usage_Status', SQLERRM);
   END set_usage_status;

   -- *** --
   -- SEUS kirje oleku muutmine
   PROCEDURE set_usage_status (
      pnseus  NUMBER
     ,pcstat  VARCHAR2
   ) IS
      lcstat                        VARCHAR2 (4);
      invalid_status_transition     EXCEPTION;
   BEGIN
      lcstat := get_usage_status (pnseus);

      IF NOT (   (lcstat = 'AC' AND pcstat IN ('CTRL', 'PSV'))
              OR (lcstat = 'CTRL' AND pcstat IN ('AC', 'LMO'))
              OR (lcstat = 'LMO' AND pcstat IN ('ACT', 'AC', 'PSV'))
              OR (lcstat = 'ACT' AND pcstat IN ('AC', 'PSV'))
             ) THEN
         RAISE invalid_status_transition;
      END IF;

      UPDATE service_usages
         SET status = pcstat
            ,date_updated = SYSDATE
            ,last_updated_by = cc_module_ref
       WHERE ref_num = pnseus;
   EXCEPTION
      WHEN invalid_status_transition THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_br_error
                               ,'Set_Usage_Status 2'
                               , 'Lubamatu olekuvahetus: ' || lcstat || '->' || NVL (pcstat, '?')
                               );
         COMMIT;
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Set_Usage_Status 2', SQLERRM);
         COMMIT;
   END set_usage_status;

   -- *** --
   -- SEUS kirje oleku pärimine
   FUNCTION get_usage_status (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pnyear  NUMBER
     ,pnmon   NUMBER
   )
      RETURN VARCHAR IS
      res                           VARCHAR2 (4);
   BEGIN
      SELECT status
        INTO res
        FROM service_usages
       WHERE susg_ref_num = pnsusg AND sety_ref_num = pnsety AND YEAR = pnyear AND MONTH = pnmon;

      RETURN res;
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Get_Usage_Status', SQLERRM);
         COMMIT;
         RETURN NULL;
   END get_usage_status;

   -- *** --
   -- SEUS kirje oleku pärimine
   FUNCTION get_usage_status (
      pnsusg  NUMBER
     ,pnsety  NUMBER
   )
      RETURN VARCHAR IS
   BEGIN
      RETURN get_usage_status (pnsusg, pnsety, cn_year, cn_month);
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Get_Usage_Status 2', SQLERRM);
         COMMIT;
         RETURN NULL;
   END get_usage_status;

   -- *** --
   -- SEUS kirje oleku pärimine
   FUNCTION get_usage_status (
      pnseus  NUMBER
   )
      RETURN VARCHAR IS
      res                           VARCHAR2 (4);
   BEGIN
      SELECT status
        INTO res
        FROM service_usages
       WHERE ref_num = pnseus;

      RETURN res;
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Get_Usage_Status 3', SQLERRM);
         COMMIT;
         RETURN NULL;
   END get_usage_status;

   -- *** --
   -- SEUS kirje atribuudi OVER_LIMIT muutmine
   PROCEDURE set_over_limit (
      pnseus  NUMBER
     ,pnolim  NUMBER   -- uus OVER_LIMIT väärtus
   ) IS
   BEGIN
      UPDATE service_usages
         SET over_limit = pnolim
            ,date_updated = SYSDATE
            ,last_updated_by = cc_module_ref
       WHERE ref_num = pnseus AND over_limit != pnolim;
   -- uuendame kirjet ainult siis, kui vaja
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Set_Over_Limit', SQLERRM);
         COMMIT;
   END set_over_limit;

   -- *** --
   -- SEUS kirje atribuudi OVER_LIMIT väärtus
   FUNCTION get_over_limit (
      pnseus  NUMBER
   )
      RETURN NUMBER IS
      res                           NUMBER;
   BEGIN
      SELECT NVL (over_limit, 0)
        INTO res
        FROM service_usages
       WHERE ref_num = pnseus;

      RETURN res;
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Get_Over_Limit', SQLERRM);
         COMMIT;
         RETURN NULL;
   END get_over_limit;

   -- *** --
   -- Limiidiületuse tegevuse algatamine
   PROCEDURE init_action (
      pnsusg  NUMBER
     ,pnsety  NUMBER
   ) IS
      lnseus                        NUMBER;
   BEGIN
      lnseus := get_active_seus (pnsusg, pnsety, cn_year, cn_month);

      IF NVL (lnseus, 0) > 0 THEN
         init_action (lnseus);
      ELSE
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Init_Action'
                               ,'SEUS_REF_NUM NOT FOUND!'
                               );
         COMMIT;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Init_Action', SQLERRM);
         COMMIT;
   END init_action;

   -- *** --
   -- Limiidiületuse tegevuse algatamine
   PROCEDURE init_action (
      pnseus  NUMBER
   ) IS
      lcact                         VARCHAR2 (20);
   BEGIN
      SELECT sepv.nw_param_value
        INTO lcact
        FROM service_usages seus, subs_service_parameters sspa, service_parameters sepa, service_param_values sepv
       WHERE seus.ref_num = pnseus
         AND sspa.susg_ref_num = seus.susg_ref_num
         AND sspa.sety_ref_num = seus.sety_ref_num
         AND sspa.sepa_ref_num = sepa.ref_num
         AND sepa.nw_param_name = 'ACTION'
         AND sspa.sepv_ref_num = sepv.ref_num
         AND sspa.start_date <= SYSDATE
         AND (sspa.end_date IS NULL OR sspa.end_date > SYSDATE)
         AND (sepa.end_date IS NULL OR sepa.end_date > SYSDATE);

      IF INSTR (lcact, 'SMS') > 0 THEN
         -- SMS saatmise tellimine
         INSERT INTO limit_actions
                     (ref_num
                     ,seus_ref_num
                     ,action_type
                     ,status
                     ,created_by
                     ,date_created
                     )
              VALUES (liac_ref_num_s.NEXTVAL
                     ,pnseus
                     ,'SMS'
                     ,'OR'
                     ,cc_module_ref
                     ,SYSDATE
                     );
      ELSIF INSTR (lcact, 'PI') > 0 THEN
         -- Side piirangu tellimine
         INSERT INTO limit_actions
                     (ref_num
                     ,seus_ref_num
                     ,action_type
                     ,status
                     ,created_by
                     ,date_created
                     )
              VALUES (liac_ref_num_s.NEXTVAL
                     ,pnseus
                     ,'PI'
                     ,'OR'
                     ,cc_module_ref
                     ,SYSDATE
                     );
      END IF;

      set_usage_status (pnseus, 'ACT');
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Init_Action 2', SQLERRM);
         COMMIT;
   END init_action;

   -- *** --
   -- SEUS'i kirje passiivseks märkimine
   PROCEDURE stop_usage (
      pnsusg  NUMBER
     ,pnsety  NUMBER
     ,pnyear  NUMBER
     ,pnmon   NUMBER
     ,pnbapr  NUMBER
   ) IS
      lcstat                        service_usages.status%TYPE;
      lnseus                        service_usages.ref_num%TYPE;
      lctype_code                   service_types.type_code%TYPE;
      order_error                   EXCEPTION;
      lnpicnt                       NUMBER;
   BEGIN
      SELECT status
            ,ref_num
        INTO lcstat
            ,lnseus
        FROM service_usages
       WHERE susg_ref_num = pnsusg AND sety_ref_num = pnsety AND YEAR = pnyear AND MONTH = pnmon;

      IF lcstat = 'ACT' THEN
         SELECT COUNT (1)
           INTO lnpicnt
           FROM subs_service_parameters susp, service_parameters sepa, service_param_values sepv
          WHERE susp.sety_ref_num = pnsety
            AND susp.susg_ref_num = pnsusg
            AND susp.sepv_ref_num = sepv.ref_num
            AND sepa.ref_num = sepv.sepa_ref_num
            AND sepa.nw_param_name = 'ACTION'
            AND sepv.nw_param_value = 'PI';

         -- Kui on tegemist side piiramisega, siis eemaldada side piirang
         IF lnpicnt > 0 THEN
            /*
            kas pnsusg'il leidub cc_complete staatuses side piiramise order,
            mis on seatud LIMIT_TRACKING'u ehk kasutaja cc_created_by poolt?
            kui leidub, siis tühistada need orderid (neid ei saa vist > 1 olla,
            aga igaks juhuks ...)
            */
            UPDATE user_requests
               SET request_status = cc_canceled
             WHERE ref_num IN (SELECT usre.ref_num
                                 FROM user_requests usre, subscriber_details sude, service_details sede
                                WHERE usre.rety_type_code = cc_rety_type_code
                                  AND usre.request_status = cc_complete
                                  AND usre.ref_num = sude.usre_ref_num
                                  AND sude.created_by = cc_created_by
                                  AND sude.exis_susg_ref_num = pnsusg
                                  AND sude.ref_num = sede.sude_ref_num
                                  AND sede.service_name = cc_service_name
                                  AND sede.rety_type_code = cc_open);

            IF SQL%ROWCOUNT = 0 THEN
               /*
               Kui ülal toodud tingimustele vastavaid kirjeid pole, siis:
               a) LIMIT_TRACKING'u tellitud order on täidetud
               v?i
               b) susg v?ib olla ise tellinud side piiramise. ==> NB! 1.2.2005 selgus, et see situatsioon on välistatud.
               Olukorras b) ei tee me midagi. Seega otsime HILISEIMA
               execution_date väärtusega sulgemise v?i avamise cc_success/manual_ok v?i cc_complete (st susg)
               orderi ja kontrollime, kes selle tellis. Kui tellija pole
               cc_created_by, siis ei tee me midagi. Vastasel juhul tellime
               side piiramise l?petamise orderi siis, kui klient pole ise vahepeal sidet avanud.
               */
               FOR rec_user IN (SELECT   usre.ref_num
                                        ,sude.created_by
                                        ,sede.rety_type_code
                                    FROM user_requests usre, subscriber_details sude, service_details sede
                                   WHERE usre.rety_type_code = cc_rety_type_code
                                     AND usre.request_status IN (cc_complete, cc_success, or_common.manual_ok)
                                     -- UPR-3249 manual_ok
                                     AND usre.ref_num = sude.usre_ref_num
                                     AND sude.exis_susg_ref_num = pnsusg
                                     AND sude.ref_num = sede.sude_ref_num
                                     AND sede.service_name = cc_service_name
                                     AND sede.rety_type_code IN (cc_open, cc_close)
                                ORDER BY usre.execution_date DESC) LOOP
                  IF rec_user.rety_type_code = cc_open
                                                      /* AND rec_user.created_by = cc_created_by (UPR3272) */
                  THEN
                     IF NOT insert_order (pnsusg, 'CLOSE', pnbapr) THEN
                        RAISE order_error;
                     END IF;
                  END IF;

                  EXIT;
               END LOOP;
            END IF;

            UPDATE limit_actions
               SET status = 'EX'
                  ,date_updated = SYSDATE
                  ,last_updated_by = cc_module_ref
             WHERE seus_ref_num = lnseus AND action_type = 'PI' AND status = 'PN';

            COMMIT;
         END IF;
      END IF;

      UPDATE service_usages
         SET status = 'PSV'
            ,date_updated = SYSDATE
            ,last_updated_by = cc_module_ref
       WHERE susg_ref_num = pnsusg AND sety_ref_num = pnsety AND YEAR = pnyear AND MONTH = pnmon;
   EXCEPTION
      WHEN order_error THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'stop_usage'
                               ,'Viga side piiramise l?petamise orderi esitamisel.'
                               );
         COMMIT;
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Stop_Usage', SQLERRM);
   END stop_usage;

   /* Class: Limit_Action / Limiidiületamise tegevused */
   FUNCTION check_actions (
      pnbapr  NUMBER
   )
      RETURN NUMBER IS
      -- K?igi initsialiseeritud tegevuste läbivaatamine
      CURSOR cur_liac IS
         SELECT   ref_num
             FROM limit_actions
            WHERE status IN ('OR', 'PN')
         ORDER BY ref_num;

      lncnt                         NUMBER := 0;
      lnpcfi                        pcdr_files.ref_num%TYPE;
      lbcorrect                     BOOLEAN := TRUE;
      lcmsg                         VARCHAR2 (256);
   BEGIN
      lnpcfi := pcdr.make_new_pcdr (pcprefix        => 'SALDO'
                                   ,pcappname       => 'SALDOTEENUSED'
                                   ,pcnetwork       => 'BIL'
                                   ,pcfiletype      => 'B'
                                   ,pnversion       => 1
                                   );

      FOR rec_liac IN cur_liac LOOP
         lncnt := lncnt + do_action (rec_liac.ref_num, lnpcfi, pnbapr);
      END LOOP;

      pcdr.send_pcdr (pnpcfi => lnpcfi, pbcorrect => lbcorrect, pcmsg => lcmsg);

      IF NOT lbcorrect THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_info
                               ,'Check_Actions'
                               , 'PCDR.Send_Pcdr error: ' || lcmsg
                               );
      END IF;

      RETURN lncnt;
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Check_Actions', SQLERRM);
         COMMIT;
         RETURN lncnt;
   END;

   -- *** --
   -- Konkreetse tegevuse teostamine
   FUNCTION do_action (
      pnliac  NUMBER
     ,pnpcfi  NUMBER
     ,pnbapr  NUMBER
   )
      RETURN NUMBER IS
      lrliac                        limit_actions%ROWTYPE;
      sms_error                     EXCEPTION;
      pcdr_error                    EXCEPTION;
      order_error                   EXCEPTION;
      macro_error                   EXCEPTION;
      lnsusg                        NUMBER;
      lnsety                        NUMBER;
      lcsmte                        sms_templates.text_type_code%TYPE;
      lnmaac                        NUMBER;
      lnbnr                         NUMBER;
      lcmsg                         VARCHAR2 (200);
      lnres                         NUMBER;
      lncnt                         NUMBER := 0;
      lnsenu_num                    senu_susg.senu_num%TYPE;
      lctext_type_code              VARCHAR2 (5);
      lnsms                         NUMBER;
      lndelay                       NUMBER;
      cc_sec                        NUMBER := 1 / 86400;
      lbroaming                     BOOLEAN;
      lcnextstatus                  VARCHAR2 (2);

      CURSOR cur_mobils IS
         SELECT DISTINCT sspa.param_value nr
                        ,sesu.susg_ref_num saaja
                    FROM subs_service_parameters sspa, service_parameters sepa, senu_susg sesu
                   WHERE sspa.susg_ref_num = lnsusg
                     AND sspa.sety_ref_num = lnsety
                     AND sspa.sepa_ref_num = sepa.ref_num
                     AND sepa.nw_param_name LIKE 'MOBILE_'
                     AND sspa.param_value IS NOT NULL
                     AND (lnsenu_num IS NULL OR sspa.param_value <> lnsenu_num)
                     AND sspa.start_date <= SYSDATE
                     AND (sspa.end_date IS NULL OR sspa.end_date > SYSDATE)
                     AND sspa.param_value = sesu.senu_num
                     AND sesu.end_date IS NULL
                     AND sesu.nety_type_code = 'GSM';   -- CHG-2048
   BEGIN
      SELECT *
        INTO lrliac
        FROM limit_actions
       WHERE ref_num = pnliac;

      lndelay := 0;

      IF lrliac.action_type = 'SMS' THEN
         -- Tegemist on SMS teate saatmisega
         -- teeme kindlaks SMS'i malli
         BEGIN
            SELECT smte.template_text
                  ,seus.sety_ref_num
                  ,seus.susg_ref_num
                  ,smte.text_type_code
              INTO lcmsg
                  ,lnsety
                  ,lnsusg
                  ,lcsmte
              FROM sms_templates smte, sety_sms sesm, service_usages seus
             WHERE smte.text_type_code = sesm.text_type_code
               AND sesm.sety_ref_num = seus.sety_ref_num
               AND seus.ref_num = lrliac.seus_ref_num
               AND sesm.start_date < SYSDATE
               AND (sesm.end_date IS NULL OR sesm.end_date > SYSDATE);
         EXCEPTION
            WHEN NO_DATA_FOUND THEN
               insert_batch_messages (cc_module_ref
                                     ,'Limit_Tracking ERR'
                                     ,cn_others
                                     ,'Do_Action'
                                     ,    'Puudub kehtiv seos Service_Type ja SMS_Template vahel! SEUS_REF_NUM='
                                       || TO_CHAR (lrliac.seus_ref_num)
                                     );
               lrliac.status := 'ER';
         END;

         IF lcmsg IS NOT NULL THEN
            -- koostame teate teksti
            decode_macros (lnsusg, lnsety, lcmsg, lnres);

            IF lnres = 0 THEN
               lrliac.status := 'EX';
            ELSE
               RAISE macro_error;
            END IF;

            -- Kui s?num osutub liiga pikaks, siis l?ikame saba maha
            IF LENGTH (lcmsg) > 160 THEN
               lcmsg := SUBSTR (lcmsg, 1, 156) || '...';
            END IF;

            -- laseme kirjutada teate faili
            lnmaac := gen_bill.maac_ref_num_by_susg (lnsusg);

            -- susg-le saadetakse SMS alati, s?ltumata MOBILE_ väärtustest
            SELECT senu_num
              INTO lnsenu_num
              FROM senu_susg
             WHERE susg_ref_num = lnsusg AND start_date < SYSDATE AND end_date IS NULL;

            -- SMS limiidi ületajale
            BEGIN
               send_sms (lnsenu_num, lcmsg, cc_emt_lyhinumber, cc_sms_looja);

               SELECT tbmc_ref_num_s.CURRVAL
                 INTO lnsms
                 FROM SYS.DUAL;

               lrliac.status := 'EX';
            EXCEPTION
               WHEN OTHERS THEN
                  RAISE sms_error;
            END;

            -- see maksustatakse
            IF NOT insert_pcdr_record (pnpcfi            => pnpcfi
                                      ,pnevent_id        => lnsms
                                      ,pnsety            => lnsety
                                      ,pca_num           => lnsenu_num
                                      ,pcb_num           => lnsenu_num
                                      ,pcmaksustada      => 'J'
                                      ,pddate            => lrliac.date_created + cc_sec * lndelay
                                      ) THEN
               RAISE pcdr_error;
            END IF;

            lndelay := lndelay + 1;

            SELECT smhi_ref_num_s.NEXTVAL
              INTO lrliac.smhi_ref_num
              FROM SYS.DUAL;

            INSERT INTO sms_history
                        (ref_num
                        ,text_type_code
                        ,maac_ref_num
                        ,date_created
                        ,error_detected
                        ,created_by
                        ,sms_message
                        )
                 VALUES (lrliac.smhi_ref_num
                        ,lcsmte
                        ,lnmaac
                        ,SYSDATE
                        ,'N'
                        ,sec.get_username
                        ,lcmsg
                        );

            INSERT INTO sms_history_entries
                        (smhi_ref_num
                        ,susg_ref_num
                        ,serv_num
                        )
                 VALUES (lrliac.smhi_ref_num
                        ,lnsusg
                        ,lnsenu_num
                        );

            COMMIT;
            lncnt := lncnt + 1;

            FOR rec_mobil IN cur_mobils LOOP
               BEGIN
                  send_sms (rec_mobil.nr, lcmsg, cc_emt_lyhinumber, cc_sms_looja);

                  SELECT tbmc_ref_num_s.CURRVAL
                    INTO lnsms
                    FROM SYS.DUAL;

                  lrliac.status := 'EX';
               EXCEPTION
                  WHEN OTHERS THEN
                     RAISE sms_error;
               END;

               IF NOT insert_pcdr_record (pnpcfi            => pnpcfi
                                         ,pnevent_id        => lnsms
                                         ,pnsety            => lnsety
                                         ,pca_num           => lnsenu_num
                                         ,pcb_num           => rec_mobil.nr
                                         ,pcmaksustada      => 'J'
                                         ,pddate            => lrliac.date_created + cc_sec * lndelay
                                         ) THEN
                  RAISE pcdr_error;
               END IF;

               lndelay := lndelay + 1;

               --write_tl_sms_file (NULL, rec_mobil.nr, lcmsg, lnres);
               SELECT smhi_ref_num_s.NEXTVAL
                 INTO lrliac.smhi_ref_num
                 FROM SYS.DUAL;

               INSERT INTO sms_history
                           (ref_num
                           ,text_type_code
                           ,maac_ref_num
                           ,date_created
                           ,error_detected
                           ,created_by
                           ,sms_message
                           )
                    VALUES (lrliac.smhi_ref_num
                           ,lcsmte
                           ,lnmaac
                           ,SYSDATE
                           ,'N'
                           ,sec.get_username
                           ,lcmsg
                           );

               INSERT INTO sms_history_entries
                           (smhi_ref_num
                           ,susg_ref_num
                           ,serv_num
                           )
                    VALUES (lrliac.smhi_ref_num
                           ,rec_mobil.saaja
                           ,rec_mobil.nr
                           );

               COMMIT;
               lncnt := lncnt + 1;
            END LOOP;
         END IF;
      ELSIF lrliac.action_type = 'PI' THEN
         -- Tegemist on side piiranguga
         -- Kontrollime, kas klient on välismaal.
         -- Välismaa olles side piirangut kohe ei rakendata
         -- ja sellisel juhul lülitame oleku väärtusele 'PN'
         SELECT susg_ref_num
           INTO lnsusg
           FROM service_usages
          WHERE ref_num = lrliac.seus_ref_num;

         lbroaming := susg_in_roaming (lnsusg);

         IF lbroaming THEN
            lctext_type_code := 'TL5';
            lcnextstatus := 'PN';
         ELSE
            lctext_type_code := 'TL4';
            lcnextstatus := 'EX';
         END IF;

         IF lrliac.status = 'OR' THEN
            IF NOT lbroaming THEN   -- Esitame side piiramise n?ude
               IF NOT insert_order (lnsusg, 'OPEN', pnbapr) THEN
                  RAISE order_error;
               END IF;
            END IF;

            BEGIN
               -- Teeme kindlaks SMS'i malli
               SELECT smte.template_text
                     ,seus.sety_ref_num
                     ,smte.text_type_code
                 INTO lcmsg
                     ,lnsety
                     ,lcsmte
                 FROM sms_templates smte, sety_sms sesm, service_usages seus
                WHERE smte.text_type_code = lctext_type_code
                  AND sesm.text_type_code = lctext_type_code
                  AND sesm.sety_ref_num = seus.sety_ref_num
                  AND seus.ref_num = lrliac.seus_ref_num
                  AND sesm.start_date < SYSDATE
                  AND (sesm.end_date IS NULL OR sesm.end_date > SYSDATE);
            EXCEPTION
               WHEN NO_DATA_FOUND THEN
                  insert_batch_messages (cc_module_ref
                                        ,'Limit_Tracking ERR'
                                        ,cn_others
                                        ,'Do_Action'
                                        ,    'Puudub kehtiv seos Service_Type ja SMS_Template vahel! SEUS_REF_NUM='
                                          || TO_CHAR (lrliac.seus_ref_num)
                                        );
                  lrliac.status := 'ER';
            END;

            IF lcmsg IS NOT NULL THEN
               -- koostame teate teksti
               decode_macros (lnsusg, lnsety, lcmsg, lnres);

               IF lnres = 0 THEN
                  lrliac.status := lcnextstatus;
               ELSE
                  RAISE macro_error;
               END IF;

               -- Kui s?num osutub liiga pikaks, siis l?ikame saba maha
               IF LENGTH (lcmsg) > 160 THEN
                  lcmsg := SUBSTR (lcmsg, 1, 156) || '...';
               END IF;

               lnmaac := gen_bill.maac_ref_num_by_susg (lnsusg);

               -- susg-le saadetakse SMS alati, s?ltumata MOBILE_ väärtustest
               SELECT senu_num
                 INTO lnsenu_num
                 FROM senu_susg
                WHERE susg_ref_num = lnsusg AND start_date < SYSDATE AND end_date IS NULL;

               -- SMS limiidi ületajale
               BEGIN
                  send_sms (lnsenu_num, lcmsg, cc_emt_lyhinumber, cc_sms_looja);

                  SELECT tbmc_ref_num_s.CURRVAL
                    INTO lnsms
                    FROM SYS.DUAL;

                  lrliac.status := lcnextstatus;
               EXCEPTION
                  WHEN OTHERS THEN
                     RAISE sms_error;
               END;

               -- seda ei maksustata
               IF NOT insert_pcdr_record (pnpcfi            => pnpcfi
                                         ,pnevent_id        => lnsms
                                         ,pnsety            => lnsety
                                         ,pca_num           => lnsenu_num
                                         ,pcb_num           => lnsenu_num
                                         ,pcmaksustada      => 'E'
                                         ,pddate            => lrliac.date_created + cc_sec * lndelay
                                         ) THEN
                  RAISE pcdr_error;
               END IF;

               lndelay := lndelay + 1;

               SELECT smhi_ref_num_s.NEXTVAL
                 INTO lrliac.smhi_ref_num
                 FROM SYS.DUAL;

               INSERT INTO sms_history
                           (ref_num
                           ,text_type_code
                           ,maac_ref_num
                           ,date_created
                           ,error_detected
                           ,created_by
                           ,sms_message
                           )
                    VALUES (lrliac.smhi_ref_num
                           ,lcsmte
                           ,lnmaac
                           ,SYSDATE
                           ,'N'
                           ,sec.get_username
                           ,lcmsg
                           );

               INSERT INTO sms_history_entries
                           (smhi_ref_num
                           ,susg_ref_num
                           ,serv_num
                           )
                    VALUES (lrliac.smhi_ref_num
                           ,lnsusg
                           ,lnsenu_num
                           );

               COMMIT;
               lncnt := lncnt + 1;

               FOR rec_mobil IN cur_mobils LOOP
                  BEGIN
                     send_sms (rec_mobil.nr, lcmsg, cc_emt_lyhinumber, cc_sms_looja);

                     SELECT tbmc_ref_num_s.CURRVAL
                       INTO lnsms
                       FROM SYS.DUAL;

                     lrliac.status := lcnextstatus;
                  EXCEPTION
                     WHEN OTHERS THEN
                        RAISE sms_error;
                  END;

                  IF NOT insert_pcdr_record (pnpcfi            => pnpcfi
                                            ,pnevent_id        => lnsms
                                            ,pnsety            => lnsety
                                            ,pca_num           => lnsenu_num
                                            ,pcb_num           => rec_mobil.nr
                                            ,pcmaksustada      => 'J'
                                            ,pddate            => lrliac.date_created + cc_sec * lndelay
                                            ) THEN
                     RAISE pcdr_error;
                  END IF;

                  lndelay := lndelay + 1;

                  --write_tl_sms_file (NULL, rec_mobil.nr, lcmsg, lnres);
                  SELECT smhi_ref_num_s.NEXTVAL
                    INTO lrliac.smhi_ref_num
                    FROM SYS.DUAL;

                  INSERT INTO sms_history
                              (ref_num
                              ,text_type_code
                              ,maac_ref_num
                              ,date_created
                              ,error_detected
                              ,created_by
                              ,sms_message
                              )
                       VALUES (lrliac.smhi_ref_num
                              ,lcsmte
                              ,lnmaac
                              ,SYSDATE
                              ,'N'
                              ,sec.get_username
                              ,lcmsg
                              );

                  INSERT INTO sms_history_entries
                              (smhi_ref_num
                              ,susg_ref_num
                              ,serv_num
                              )
                       VALUES (lrliac.smhi_ref_num
                              ,rec_mobil.saaja
                              ,rec_mobil.nr
                              );

                  COMMIT;
                  lncnt := lncnt + 1;
               END LOOP;
            END IF;
         ELSE
            IF lrliac.status = 'PN' AND NOT lbroaming THEN   -- Esitame side piiramise n?ude
               IF NOT insert_order (lnsusg, 'OPEN', pnbapr) THEN
                  RAISE order_error;
               END IF;

               lrliac.status := 'EX';
            END IF;
         END IF;
      ELSE
         -- Tundmatu tegevuse tüüp!
         lrliac.status := 'ER';
      END IF;

      UPDATE limit_actions
         SET status = lrliac.status
            ,smhi_ref_num = lrliac.smhi_ref_num
            ,date_updated = SYSDATE
            ,last_updated_by = cc_module_ref
       WHERE ref_num = pnliac;

      COMMIT;
      RETURN lncnt;
   EXCEPTION
      WHEN order_error THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Do_Action'
                               ,'Viga side piiramise orderi esitamisel.'
                               );
         COMMIT;
         RETURN lncnt;
      WHEN sms_error THEN
         IF lnres < 0 THEN
            insert_batch_messages (cc_module_ref
                                  ,'Limit_Tracking ERR'
                                  ,cn_others
                                  ,'Do_Action'
                                  ,'Viga SMS saatmisel SEND_SMS kaudu.'
                                  );
         END IF;

         COMMIT;
         RETURN lncnt;
      WHEN pcdr_error THEN
         ROLLBACK;
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Do_Action'
                               ,'Viga rea lisamisel PCDR faili insert_pcdr_record kaudu.'
                               );
         COMMIT;
         RETURN lncnt;
      WHEN macro_error THEN
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'Do_Action'
                               ,    'SMS s?numi koostamisel ei asendatud k?iki makrosid! SEUS_REF_NUM='
                                 || TO_CHAR (lrliac.seus_ref_num)
                                 || ', MSG='
                                 || lcmsg
                               );
         COMMIT;
         RETURN lncnt;
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'Do_Action', SQLERRM);
         COMMIT;
         RETURN lncnt;
   END;

   -- *** --
   PROCEDURE write_tl_sms_file (
      pcanr       VARCHAR2
     ,pcbnr       VARCHAR2
     ,pcmsg       VARCHAR2
     ,pnres  OUT  NUMBER
   ) IS
      lnres                         NUMBER := -10;
      lcbnr                         VARCHAR2 (20);
      lcoutbox_path                 VARCHAR2 (80) := get_system_parameter (cn_sysparam_sms_outbox);
      lcsms_fname                   VARCHAR (120);
      vf                            UTL_FILE.file_type;
   BEGIN
      lcsms_fname := 'SMS_LIST.TXT';
      lnres := cn_open_err;
      vf := UTL_FILE.fopen (lcoutbox_path, lcsms_fname, 'a');
      lnres := cn_write_err;
      UTL_FILE.put_line (vf, '00' || pcbnr || CHR (9) || pcmsg);
      lnres := cn_close_err;
      UTL_FILE.fclose (vf);
      pnres := 0;
   EXCEPTION
      WHEN UTL_FILE.invalid_path THEN   -- ajutiselt
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_others
                               ,'WRITE_TL_SMS_FILE'
                               , '00' || pcbnr || CHR (9) || pcmsg
                               );
         pnres := lnres;
         COMMIT;
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'WRITE_TL_SMS_FILE', SQLERRM);

         IF UTL_FILE.is_open (vf) THEN
            UTL_FILE.fclose (vf);
         END IF;

         pnres := lnres;
         COMMIT;
   END write_tl_sms_file;

   -- *** --
   PROCEDURE decode_macros (
      pnsusg          NUMBER
     ,   -- viit mobiilile
      pnsety          NUMBER
     ,   -- viit teenuste tüübile
      pcmsg   IN OUT  VARCHAR2
     ,   -- töödeldav tekst
      pnres   OUT     NUMBER
   ) IS
      lcfld                         VARCHAR2 (40);

      PROCEDURE macro_replace (
         pcm    IN OUT  VARCHAR2
        ,pcmc   IN      VARCHAR2
        ,pcval  IN      VARCHAR2
      ) IS
         lnpos                         NUMBER;
      BEGIN
         lnpos := INSTR (UPPER (pcm), pcmc);
         pcm := SUBSTR (pcm, 1, lnpos - 1) || pcval || SUBSTR (pcm, lnpos + LENGTH (pcmc), 160);
      END;
   BEGIN
      IF INSTR (UPPER (pcmsg), '#SERV_NUM') > 0 THEN
         SELECT serv_num
           INTO lcfld
           FROM senu_susg
          WHERE susg_ref_num = pnsusg AND start_date < SYSDATE AND (end_date IS NULL OR end_date > SYSDATE);

         macro_replace (pcmsg, '#SERV_NUM', lcfld);
      END IF;

      IF INSTR (UPPER (pcmsg), '#MOBILE') > 0 THEN
         SELECT serv_num
           INTO lcfld
           FROM senu_susg
          WHERE susg_ref_num = pnsusg AND start_date < SYSDATE AND (end_date IS NULL OR end_date > SYSDATE);

         macro_replace (pcmsg, '#MOBILE', lcfld);
      END IF;

      IF INSTR (UPPER (pcmsg), '#LIMIT') > 0 THEN
         lcfld := TO_CHAR (limit_tracking.get_limit_value (pnsusg, pnsety, SYSDATE));
         macro_replace (pcmsg, '#LIMIT', lcfld);
      END IF;

      IF INSTR (UPPER (pcmsg), '#SEUS_VALUE') > 0 THEN
         lcfld := TO_CHAR (ROUND (limit_tracking.get_usage_value (pnsusg, pnsety, SYSDATE), 2));
         macro_replace (pcmsg, '#SEUS_VALUE', lcfld);
      END IF;

      IF INSTR (UPPER (pcmsg), '#TOTAL') > 0 THEN
         lcfld := TO_CHAR (ROUND (limit_tracking.get_usage_value (pnsusg, pnsety, SYSDATE), 2));
         macro_replace (pcmsg, '#TOTAL', lcfld);
      END IF;

      pnres := INSTR (pcmsg, '#');
   EXCEPTION
      WHEN OTHERS THEN
         insert_batch_messages (cc_module_ref, 'Limit_Tracking ERR', cn_others, 'DECODE_MACROS', SQLERRM);
         COMMIT;
   END;

   PROCEDURE create_interim_invo (
      pnmaac          NUMBER
     ,prinvo  IN OUT  invoices%ROWTYPE
   ) IS
      cd_sysdate           CONSTANT DATE := SYSDATE;
   BEGIN
      prinvo.maac_ref_num := pnmaac;
      prinvo.invoice_number := TO_CHAR (cd_sysdate, 'YYYYMMDD');
      prinvo.total_amt := 0;
      prinvo.total_vat := 0;
      prinvo.outstanding_amt := 0;
      prinvo.created_by := sec.get_username;
      prinvo.date_created := cd_sysdate;
      prinvo.credit := 'N';
      prinvo.billed := 'N';
      prinvo.billing_inv := 'Y';
      prinvo.print_req := 'N';
      prinvo.invoice_date := ADD_MONTHS (TRUNC (cd_sysdate, 'MONTH'), 1) - cn_sec;
      prinvo.sully_paid := NULL;
      prinvo.invo_sequence := TO_NUMBER (TO_CHAR (cd_sysdate, 'YYYYMM'));
      prinvo.period_end := ADD_MONTHS (TRUNC (cd_sysdate, 'MONTH'), 1) - 1;
      close_interim_billing_invoice.insert_interim_invo (prinvo);
   END;

   -- *** --
   -- Etteantud teenuse limiidi suuruse ühiku pärimine : UPR-2797
   FUNCTION get_limit_unit (
      pnsety  NUMBER
   )
      RETURN VARCHAR2 IS
      res                           service_param_values.param_value%TYPE;

      CURSOR cur_unit IS
         SELECT   sepv.param_value unit
             FROM service_parameters sepa, service_param_values sepv
            WHERE sepa.sety_ref_num = pnsety
              AND sepa.nw_param_name = cc_tlunit_tunnus
              AND sepa.start_date <= SYSDATE
              AND (sepa.end_date IS NULL OR sepa.end_date > SYSDATE)
              AND sepv.sepa_ref_num = sepa.ref_num
              AND sepv.start_date <= SYSDATE
              AND (sepv.end_date IS NULL OR sepv.end_date > SYSDATE)
         ORDER BY sepa.start_date DESC;
   BEGIN
      OPEN cur_unit;

      FETCH cur_unit
       INTO res;

      IF cur_unit%NOTFOUND THEN
         res := NULL;
      END IF;

      CLOSE cur_unit;

      RETURN res;
   EXCEPTION
      WHEN OTHERS THEN
         /*
         insert_batch_messages (cc_module_ref,
                                'Limit_Tracking ERR',
                                cn_others,
                                'Get_Limit_Unit',
                                sqlerrm
                               );
         COMMIT;
         */
         RETURN NULL;
   END get_limit_unit;

   -- Lisab kirje tabelisse limit_susg (UPR-2934)
   PROCEDURE ins_limit_susg (
      pnsusg  NUMBER
   ) IS
      PRAGMA AUTONOMOUS_TRANSACTION;
      lncnt                         PLS_INTEGER;
   BEGIN
      IF pnsusg IS NOT NULL AND SYSDATE <= cd_end_of_month THEN
         /* CHG-13846: replaced query with new
         SELECT COUNT (1)
           INTO lncnt
           FROM subs_service_parameters susp
               , (SELECT sepa.sety_ref_num
                        ,sepa.ref_num
                    FROM service_parameters sepa
                   WHERE sepa.nw_param_name = cc_tl_tunnus AND sepa.start_date < SYSDATE AND sepa.end_date IS NULL) sepa
               , service_types sety  -- CHG-13669
          WHERE susp.susg_ref_num = pnsusg
            AND susp.start_date < SYSDATE
            AND susp.end_date IS NULL
            AND susp.sety_ref_num = sepa.sety_ref_num
            AND sepa.sety_ref_num = sety.ref_num  -- CHG-13669
            AND susp.sepa_ref_num = sepa.ref_num
            AND sety.nety_type_code = 'BIL'       -- CHG-13669
            AND NOT EXISTS (SELECT 1
                              FROM limit_susg lisu
                             WHERE lisu.susg_ref_num = susp.susg_ref_num)
            AND ROWNUM = 1;
         */
         -- CHG-13846: Check for active limit services
         SELECT COUNT (1) INTO lncnt
         FROM susg_active_limit_services sals
         WHERE sals.susg_ref_num = pnsusg
           AND NOT EXISTS (SELECT 1
                           FROM limit_susg lisu
                           WHERE lisu.susg_ref_num = sals.susg_ref_num)
           AND ROWNUM = 1;

         IF lncnt > 0 THEN
            INSERT INTO limit_susg
                        (ref_num
                        ,susg_ref_num
                        )
                 VALUES (lisu_ref_num_s.NEXTVAL
                        ,pnsusg
                        );

            COMMIT;
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
   END;

   -- Lisab kirje tabelisse LIMIT_SUSG, kui on lisatud uus kirje subs_service_parameters tabelisse
   PROCEDURE ins_limit_susg (
      pnsusg  NUMBER
     ,pnsety  NUMBER
   ) IS
      /*PRAGMA AUTONOMOUS_TRANSACTION;*/
      lncnt                         PLS_INTEGER;
   BEGIN
      IF pnsusg IS NOT NULL AND pnsety IS NOT NULL AND SYSDATE <= cd_end_of_month THEN
         -- kontrollime, kas on tegemist limiidi teenuse tellimisega saldostopi raames
         SELECT COUNT (1)
           INTO lncnt
           FROM service_parameters sepa, service_types sety
          WHERE sepa.param_name = cc_tl_tunnus
            AND sepa.start_date < SYSDATE
            AND sepa.end_date IS NULL
            AND sety.ref_num = pnsety
            AND sety.nety_type_code = 'BIL'  -- CHG-13669
            AND sepa.sety_ref_num = sety.ref_num
            AND NOT EXISTS (SELECT 1
                              FROM limit_susg lisu
                             WHERE lisu.susg_ref_num = pnsusg);

         IF lncnt > 0 THEN
            INSERT INTO limit_susg
                        (ref_num
                        ,susg_ref_num
                        )
                 VALUES (lisu_ref_num_s.NEXTVAL
                        ,pnsusg
                        );
         /*COMMIT;*/
         END IF;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
   END;

   -- Käivitab CHECK_ALL_LIMITS (UPR-2934)
   -- pnbapr = BATCH_PROCESSES.REF_NUM
   PROCEDURE process_limits (
      pnbapr  NUMBER
   ) IS
      --
      l_success                     BOOLEAN;   -- CHG-4236
      --
      e_proc_start_error            EXCEPTION;
   BEGIN
      IF pnbapr IS NOT NULL THEN
         /*
           ** CHG-4236: Kontrollida, kas eelmine protsess on lõpuni käinud.
         */
         bcc_misc_processing.check_process_status (l_success, cc_module_ref);

         IF NOT l_success THEN
            RAISE e_proc_start_error;
         END IF;

         UPDATE batch_processes
            SET status = cc_bapr_incomplete
          WHERE ref_num = pnbapr;

         COMMIT;

         IF limit_tracking.check_all_limits (pnbapr) THEN
            UPDATE batch_processes
               SET status = cc_bapr_complete
             WHERE ref_num = pnbapr;
         ELSE
            UPDATE batch_processes
               SET status = cc_bapr_error
             WHERE ref_num = pnbapr;
         END IF;

         COMMIT;
         --
         DBMS_APPLICATION_INFO.set_client_info (' ');
      ELSE
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_info
                               ,'Process_Limits'
                               ,'Processing not started, pnBAPR IS NULL'
                               );
      END IF;
   EXCEPTION
      WHEN e_proc_start_error THEN   -- CHG-4236
         --
         UPDATE batch_processes
            SET status = cc_bapr_error
          WHERE ref_num = pnbapr;

         --
         insert_batch_messages (cc_module_ref
                               ,'Limit_Tracking ERR'
                               ,cn_info
                               ,'Process_Limits'
                               ,'Processing is already running! Parallel execution not allowed!'
                               );
         COMMIT;
      WHEN OTHERS THEN   -- CHG-4236
         --
         DBMS_APPLICATION_INFO.set_client_info (' ');
   END;

   -- Abifunktsioon CHECK_ALL_LIMITS peapäringu sooritamisel (UPR-2934)
   FUNCTION get_date_updated (
      pnsusg  NUMBER
     ,pnsety  NUMBER
   )
      RETURN DATE IS
      d_result                      DATE;
      n_fix                         NUMBER;
      c_unit                        VARCHAR2 (10);
   BEGIN
      SELECT seus.date_updated
            ,seus.fix_value
        INTO d_result
            ,n_fix
        FROM service_usages seus
       WHERE seus.susg_ref_num = pnsusg AND seus.sety_ref_num = pnsety AND seus.YEAR = cn_year AND seus.MONTH = cn_month;

      IF NVL (n_fix, 0) = 0 THEN
         c_unit := get_limit_unit (pnsety);

         IF c_unit = g_pri_curr_code /* CHG-4594 */ THEN
            d_result := NULL;
         END IF;
      END IF;

      RETURN d_result;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END;

   -- Kui on tegemist miinimumarve tüüpi lahendusega, siis fixtasud on miinimumarve sees.
   -- Seega saldostopi fixi ei tohi kõiki fixtasusi summeerida. Üldine reegel,
   -- kui INTERIM arve fikstasud ei ületa haldustasu, siis läheb saldostopi fixtasuks
   -- haldustasu summa. Kui aga ületab, siis pannakse INTERIM arve fikstasude summa.
   FUNCTION get_minb_calculated_value (
      p_susg_ref_num     NUMBER
     ,p_invo_ref_num     NUMBER
     ,p_total_int_value  NUMBER
     ,p_chk_date         DATE
   )
      RETURN NUMBER IS
      --
      CURSOR c_minb IS
         SELECT SUM (  NVL (inen.eek_amt, 0)
                     + NVL (inen.amt_tax
                           ,ROUND (NVL (inen.eek_amt, 0) * gen_bill.get_tax_rate (inen.taty_type_code, p_chk_date), 2)
                           )
                    )
           FROM invoice_entries_interim inen
          WHERE inen.invo_ref_num = p_invo_ref_num
            AND inen.susg_ref_num = p_susg_ref_num
            AND EXISTS (SELECT 1
                          FROM fixed_charge_item_types curr, fixed_charge_item_types prev
                         WHERE curr.type_code = inen.fcit_type_code
                           AND curr.prev_fcit_type_code = prev.type_code
                           AND prev.regular_type = 'MINB')
            AND inen.vmct_type_code IS NULL;

      --
      l_found                       BOOLEAN;
      l_minb_value                  NUMBER;
   BEGIN
      --
      OPEN c_minb;

      FETCH c_minb
       INTO l_minb_value;

      l_found := c_minb%FOUND;

      CLOSE c_minb;

      --
      IF NOT l_found THEN
         -- Pole tegu miinimumarve tüübiga
         RETURN p_total_int_value;
      ELSE
         -- Kui haldustasu on suurem fix tasudest, tagastada haldustasu.
         -- Vastasel korral tagastada fix tasude summa ilma haldustasuta.
         RETURN GREATEST (NVL (l_minb_value, 0), p_total_int_value - NVL (l_minb_value, 0));
      END IF;
   --
   EXCEPTION
      WHEN OTHERS THEN
         RETURN p_total_int_value;
   END get_minb_calculated_value;

   FUNCTION get_package_cagegory (
      p_susg_ref_num  NUMBER
     ,p_chk_date      DATE
   )
      RETURN VARCHAR2 IS
      --
      CURSOR c_cat IS
         SELECT sept.CATEGORY
           FROM subs_packages supa, serv_package_types sept
          WHERE supa.gsm_susg_ref_num = p_susg_ref_num
            AND p_chk_date BETWEEN supa.start_date AND NVL (supa.end_date, p_chk_date)
            AND supa.sept_type_code = sept.type_code
            AND p_chk_date BETWEEN sept.start_date AND NVL (sept.end_date, p_chk_date);

      --
      l_category                    serv_package_types.CATEGORY%TYPE;
   BEGIN
      --
      OPEN c_cat;

      FETCH c_cat
       INTO l_category;

      CLOSE c_cat;

      --
      RETURN l_category;
   END get_package_cagegory;
END limit_tracking;
/