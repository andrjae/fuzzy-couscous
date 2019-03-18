CREATE OR REPLACE PACKAGE interim_invoice AS
   /********************************************************************************************************************
   **
   **  Module      :  BCCU750
   **  Module Name : INTERIM_INVOICE
   **  Date Created:  02.03.2001
   **  Author      :  U.Aarna
   **  Description :  This package contains procedures and functions used
   **                 in creating Interim Invoices.
   **
   ** ------------------------------------------------------------------------------------------------------------------
   ** Version Date        Modified by  Reason
   ** ------------------------------------------------------------------------------------------------------------------
   **   1.29  05.02.2019  A.Jaek       DOBAS-1721: Lisatud process.daily_charges.proc_daily_charges_ma väljakutse
   **   1.28  24.04.2018  Inge Reeder  TELBAL2-161: Välja kommenteeritud protseduuri after_closing_invoice kasutamine
   **   1.27  10.11.2015  A.Soo        ARCA-76:  Sissenõudmiskulu hüvitise arveldus ARCA platvormil.
   **                                            Täiendatud protseduuri: create_maac_int_invoice
   **   1.26  06.02.2015 I.Jentson     CHG-14030, IS-11682: Täiendatud protseduuri create_maac_int_invoice, lisatud arve lõpetamise järgsed tegevused.
   **   1.25  08.01.2015 I.Jentson     CHG-14030, IS-11682: Täiendatud protseduuri upd_invo, lisatud arve lõpetamise järgsed tegevused.
   **   1.24  09.05.2012  A.Soo        CHG-5762: PAK2 seadme kuutasu ning lahendustasu arvutamine VNV vahearvele.
   **                                            Täiendatud protseduuri: create_susg_int_fixed_charges
   **   1.23  09.12.2010  K.Peil       CHG4783, IS-6841: CREATE_ROUNDING_ENTRIES loogika asendatud
   **                                           BCC_CALC.ROUNDING_INVOICES väljakutsega.
   **   1.22  16.08.2010  K.Peil       CHG4594, IS-5573: alamprogrammis CREATE_ROUNDING_ENTRIES realiseeritud ümardusrea
   **                                            valuutapõhine koostamine.
   **   1.21  04.05.2009  A.Soo        CHG-3811: Lisatud REPL tüüpi paketi kuutasude arvutus.
   **                                            Täiendatud protseduuri: create_susg_int_fixed_charges.
   **   1.20  23.04.2009  A.Soo        CHG-3714: Täiendatud protseduuri: create_susg_int_fixed_charges
   **   1.19  16.12.2008  A.Soo        CHG-3345: PAK tagastused - iPhone paketitasu arvutatakse kuu lõpus billing arvetele ja võlanõuete vahearvetele, aga ei
   **                                            arvutata krediidilimiidi ületuse tõttu koostatud vahearvetele.
   **                                            Muudetud protseduuri: create_susg_int_fixed_charges.
   **   1.18  27.08.2008  A.Soo        CHG-3231: PAK müügi parandus - perioodi lõppkuupäev.
   **                                            Muudetud protseduuri: create_susg_int_fixed_charges.
   **   1.17  26.06.2008  A.Soo        CHG-3060: SUSG paketeeritud teenuspaketi paketitasu arveldus
   **                                            Muudetud protseduuri: create_susg_int_fixed_charges
   **   1.16  14.02.2008  A.Mestserski CHG-2716: Panin õige versioon ja tegin muudatused CHG-2580 uuesti
   **   1.15  24.01.2008  A.Mestserski CHG-2580: Vahetatud CHG-498 ja CHG-69 lisatud koodi blokkide järjestus:
   **                                            Esmalt käivitatakse CHG-498, seejärel CHG-69
   **   1.14  17.09.2007  H.Luhasalu CHG2282 : Vahearvetele ei või arvutada Roaming Markupi
   **   1.13  27.06.2007  S.Sokk     CHG2110 : Replaced USER with sec.get_username
   **   1.12  20.03.2006  A.Rosman   CHG-776 : create_interim_invoice_header - eemaldasin curr_code väärtustamise, pri_curr_code väärtustamine lisatud
   **                                          create_rounding_entries: eemaldasin amt_in_curr ja amt_tax_curr väärtustamise, pri_curr_code lisamine lisatud
   **                                          procedure ins_invo - lisatud pri_curr_code lisamine invoice tabelisse, procedure calc_interim_invoice -
   **                                          update käigus ümardatakse tabeli invoice väli outstanding_amt kahe komakohani
   **   1.11  29.03.2006  U.Aarna    CHG-776 : Vea parandus: invoice created_by/last_updted_by pikkusega 15 (pikema kasutajanime sisestus
   **                                          põhjustas ORA vea).
   **   1.10  02.12.2005  U.Aarna    CHG-498 : Lisatud mobiili taseme teenuste päevade arvust sõltumatute (non-prorata) kuutasude arvutus.
   **   1.9   28.09.2005  O.Vaikneme CHG-112 : Päisesse FUNCTION Get_Mobile_Number, võimaldamaks selle väljakutset ekraanivormist BCCF040.
   **                                          NB! Protseduurid Remove_SUSG_Tab_Duplicate_Rows ja Create_MultiSUSG_Int_Invoice ning
   **                                          tyyp SUSGTabType on 10g kompatiiblusprobleemide tõttu kopeeritud ekraanivormi BCCF040
   **                                          paketti Multisusg_Int_Invoice_P, kui need muutuvad, siis on vaja need protseduurid
   **                                          kopeerida ka sinna!
   **   1.8   20.04.2005  U.Aarna    CHG-69:   Lisatud päevade arvust sõltumatute (non-prorata) paketi kuutasude arvutus
   **                                          võlanõude vahearvetele (reason = VNV). Muudetud protseduuri Create_SUSG_Int_Fixed_Charges.
   **   1.7   02.02.2004  I.Stolfot  UPR-2922: Partitsiooni muutumisel tuleb ümbertõstetud INEN-ile
   **                                          viitavad referensid ka ümber suunata.
   **   1.6   10.10.2003  I.Reeder   UPR-2757: Invoices.payment_plan_status - atribuuti ei kasutata enam
   **   1.5   03.03.2003  H.Luhasalu UPR-2491: Calx_taxes lisatud kuupäeva parameeter
   **   1.4   13.05.2002  P.Metsalu  UPR-1991: Chk_One_SUSG_Minute_Disc,
   **                                          Create_Int_SUSG_Minute_Disc, Create_Int_MAAC_Minute_Disc ära
   **   1.3   28.08.2001  M.Sabul    UPR-1891: Partitsioneerimisel viga ,parandus protseduuris ENTRIES_PARTITITION
   **   1.2   05.04.2001  M.Sabul    UPR-1508: Added call Calculate_fixed_Charges.
   **                                          Main_Master_service_charges
   **   1.1   26.04.2001  U.Aarna    UPR-1766: Commit added to the end of maac and
   **                                          multisusg INT invoice creation
   **   1.0   16.04.2001  T.Hipeli   UPR-1667: added partitition trap
   **   1.0   02.03.2001  U.Aarna    UPR-1667: Initial version
   **
   ********************************************************************************************************************/

   /*
     ** Type declarations.
   */
   TYPE susgtabtype IS TABLE OF subs_serv_groups.ref_num%TYPE
                          INDEX BY BINARY_INTEGER;

   /*
     ** Global constant declarations.
   */

   /*
     ** Program unit declarations.
   */
   PROCEDURE check_maac_invoicability (p_maac_ref_num  IN     accounts.ref_num%TYPE
                                      ,p_salp_start    IN     sales_ledger_periods.start_date%TYPE
                                      ,p_invo_ref_num     OUT invoices.ref_num%TYPE
                                      ,p_invo_start       OUT invoices.invo_start%TYPE
                                      ,p_inip_ref_num     OUT interim_invoice_periods.ref_num%TYPE
                                      ,p_success          OUT BOOLEAN
                                      ,p_message          OUT VARCHAR2
                                      );

   --
   FUNCTION susg_events_exists (p_susg_ref_num  IN subs_serv_groups.ref_num%TYPE
                               ,p_invo_ref_num  IN invoices.ref_num%TYPE
                               )
      RETURN BOOLEAN;

   --
   PROCEDURE check_susg_invoicability (p_maac_ref_num  IN     accounts.ref_num%TYPE
                                      ,p_susg_ref_num  IN     subs_serv_groups.ref_num%TYPE
                                      ,p_invo_ref_num  IN     invoices.ref_num%TYPE
                                      ,p_period_start  IN     sales_ledger_periods.start_date%TYPE
                                      ,p_invo_start       OUT invoices.invo_start%TYPE
                                      ,p_inip_ref_num     OUT interim_invoice_periods.ref_num%TYPE
                                      ,p_success          OUT BOOLEAN
                                      ,p_message          OUT VARCHAR2
                                      );

   --
   PROCEDURE create_interim_invoice_header (p_maac_ref_num     IN     accounts.ref_num%TYPE
                                           ,p_susg_ref_num     IN     subs_serv_groups.ref_num%TYPE
                                           ,p_period_start     IN     sales_ledger_periods.start_date%TYPE
                                           ,p_creation_reason  IN     invoices.creation_reason%TYPE
                                           ,p_days_credit      IN     NUMBER
                                           ,p_created_by       IN     VARCHAR2
                                           ,p_invo_rec            OUT invoices%ROWTYPE
                                           ,p_inip_ref_num        OUT interim_invoice_periods.ref_num%TYPE
                                           ,p_success             OUT BOOLEAN
                                           ,p_invo_start       IN     invoices.invo_start%TYPE DEFAULT NULL
                                           );

   --
   PROCEDURE create_susg_int_fixed_charges (p_maac_ref_num  IN     accounts.ref_num%TYPE
                                           ,p_susg_ref_num  IN     subs_serv_groups.ref_num%TYPE
                                           ,p_invo_rec      IN OUT invoices%ROWTYPE
                                           ,p_success          OUT BOOLEAN
                                           ,p_error_text       OUT VARCHAR2
                                           ,p_maac_level    IN     BOOLEAN DEFAULT FALSE
                                           );

   --
   PROCEDURE create_maac_int_fixed_charges (p_maac_ref_num  IN     accounts.ref_num%TYPE
                                           ,p_invo_rec      IN OUT invoices%ROWTYPE
                                           ,p_inip_ref_num  IN     interim_invoice_periods.ref_num%TYPE
                                           ,p_success          OUT BOOLEAN
                                           ,p_error_text       OUT VARCHAR2
                                           );

   --
   PROCEDURE calc_interim_invoice (p_invo_rec  IN OUT invoices%ROWTYPE
                                  ,p_success      OUT BOOLEAN
                                  ,p_message      OUT VARCHAR2
                                  );

   --
   PROCEDURE create_susg_invoice_entries (
      p_maac_ref_num         IN     accounts.ref_num%TYPE
     ,p_susg_ref_num         IN     subs_serv_groups.ref_num%TYPE
     ,p_inb_invo_ref_num     IN     invoices.ref_num%TYPE
     ,p_int_invo_rec         IN OUT invoices%ROWTYPE
     ,p_success                 OUT BOOLEAN
     ,p_message                 OUT VARCHAR2
     ,p_check_invoicability  IN     BOOLEAN DEFAULT TRUE
     ,p_inip_ref_num         IN     interim_invoice_periods.ref_num%TYPE DEFAULT NULL);

   --
   PROCEDURE create_susg_int_invoice (p_maac_ref_num     IN     accounts.ref_num%TYPE
                                     ,p_susg_ref_num     IN     subs_serv_groups.ref_num%TYPE
                                     ,p_int_ref_num         OUT invoices.ref_num%TYPE
                                     ,p_int_rec             OUT invoices%ROWTYPE
                                     ,p_inb_ref_num         OUT invoices.ref_num%TYPE
                                     ,p_success             OUT BOOLEAN
                                     ,p_error_text          OUT VARCHAR2
                                     ,p_close_inv        IN     BOOLEAN DEFAULT FALSE
                                     ,p_creation_reason  IN     invoices.creation_reason%TYPE DEFAULT NULL
                                     ,p_days_credit      IN     NUMBER DEFAULT NULL
                                     ,p_created_by       IN     VARCHAR2 DEFAULT 'INT_INVO_SUSG'
                                     );

   --
   PROCEDURE create_multisusg_int_invoice (p_maac_ref_num     IN     accounts.ref_num%TYPE
                                          ,p_susg_tab         IN     susgtabtype
                                          ,p_invo_ref_num        OUT invoices.ref_num%TYPE
                                          ,p_success             OUT BOOLEAN
                                          ,p_error_text          OUT VARCHAR2
                                          ,p_error_susg_tab      OUT susgtabtype
                                          ,p_creation_reason  IN     invoices.creation_reason%TYPE DEFAULT NULL
                                          ,p_days_credit      IN     NUMBER DEFAULT NULL
                                          ,p_created_by       IN     VARCHAR2 DEFAULT 'INT_INVO_SUSG'
                                          );

   --
   PROCEDURE create_maac_int_invoice (p_maac_ref_num     IN     accounts.ref_num%TYPE
                                     ,p_invo_ref_num        OUT invoices.ref_num%TYPE
                                     ,p_success             OUT BOOLEAN
                                     ,p_error_text          OUT VARCHAR2
                                     ,p_creation_reason  IN     invoices.creation_reason%TYPE DEFAULT NULL
                                     ,p_days_credit      IN     NUMBER DEFAULT NULL
                                     ,p_created_by       IN     VARCHAR2 DEFAULT 'INT_INVO_MAAC'
                                     );

   --
   PROCEDURE create_rounding_entries (p_invo_ref_num IN invoices.ref_num%TYPE);

   --
   FUNCTION get_invoice_by_ref_num (p_invo_ref_num  IN     invoices.ref_num%TYPE
                                   ,p_invo_rec         OUT invoices%ROWTYPE
                                   )
      RETURN BOOLEAN;

   --
   PROCEDURE upd_invo (p_invo_rec IN OUT invoices%ROWTYPE);

   --
   FUNCTION get_cur_salp_start (p_chk_date IN DATE)
      RETURN DATE;

   --0tt CHG112: Päisesse toodud, et saaks välja kutsuda ekraanivormist bccf040.
   FUNCTION get_mobile_number (p_susg_ref_num IN subs_serv_groups.ref_num%TYPE)
      RETURN VARCHAR2;
--
END interim_invoice;
/

CREATE OR REPLACE PACKAGE BODY interim_invoice AS
   /*
     **
     **   -- LOCAL PROGRAM UNITS used inside current package
     **
   */

   /***************************************************************************
   **
   **   Function Name :  CHK_MAAC_AC
   **
   **   Description : Local function.
   **                 Check if given Master Account is AC at specified time.
   **
   ****************************************************************************/
   FUNCTION chk_maac_ac (p_maac_ref_num  IN accounts.ref_num%TYPE
                        ,p_chk_date      IN DATE
                        )
      RETURN BOOLEAN IS
      --
      CURSOR c_acst IS
         SELECT 1
           FROM account_statuses
          WHERE     acco_ref_num = p_maac_ref_num
                AND acst_code = 'AC'
                AND start_date <= p_chk_date
                AND (end_date IS NULL OR end_date >= p_chk_date);

      --
      l_dummy                       NUMBER;
   BEGIN
      OPEN c_acst;

      FETCH c_acst INTO l_dummy;

      --
      IF c_acst%FOUND THEN
         CLOSE c_acst;

         RETURN TRUE;
      ELSE
         CLOSE c_acst;

         RETURN FALSE;
      END IF;
   END chk_maac_ac;

   /***************************************************************************
   **
   **   Function Name :  GET_MOBILE_NUMBER
   **
   **   Description : Local function.
   **                 Get mobile number by susg_ref_num
   **
   ****************************************************************************/
   FUNCTION get_mobile_number (p_susg_ref_num IN subs_serv_groups.ref_num%TYPE)
      RETURN VARCHAR2 IS
      --
      CURSOR c_sesu IS
         SELECT serv_num
           FROM senu_susg
          WHERE susg_ref_num = p_susg_ref_num AND end_date IS NULL;

      --
      l_serv_num                    senu_susg.serv_num%TYPE;
   BEGIN
      OPEN c_sesu;

      FETCH c_sesu INTO l_serv_num;

      CLOSE c_sesu;

      --
      RETURN l_serv_num;
   END get_mobile_number;

   /***************************************************************************
   **
   **   Function Name :  GET_INVO_REF_NUM
   **
   **   Description : Local function.
   **                 Get Invoice ref_num from sequence.
   **
   ****************************************************************************/
   FUNCTION get_invo_ref_num
      RETURN NUMBER IS
      --
      CURSOR c_ref_num IS
         SELECT invo_ref_num_s.NEXTVAL FROM DUAL;

      --
      l_ref_num                     NUMBER;
   BEGIN
      OPEN c_ref_num;

      FETCH c_ref_num INTO l_ref_num;

      CLOSE c_ref_num;

      --
      RETURN l_ref_num;
   END get_invo_ref_num;

   /***************************************************************************
   **
   **   Procedure Name :  INS_INVO
   **
   **   Description : Local procedure.
   **                 Insert a record into Invoices.
   **
   ****************************************************************************/
   PROCEDURE ins_invo (p_invo_rec IN OUT invoices%ROWTYPE) IS
   BEGIN
      p_invo_rec.ref_num := get_invo_ref_num;

      --
      INSERT
        INTO invoices (ref_num
                      ,invoice_number
                      ,maac_ref_num
                      ,total_amt
                      ,total_vat
                      ,outstanding_amt
                      ,created_by
                      ,date_created
                      ,credit
                      ,billed
                      ,billing_inv
                      ,print_req
                      ,stat_ref_num
                      ,due_date
                      ,salp_fina_year
                      ,salp_per_num
                      ,invoice_date
                      ,period_start
                      ,period_end
                      ,date_printed
                      ,last_updated_by
                      ,date_updated
                      ,sully_paid
                      ,fully_paid
                      ,bicy_cycle_code
                      ,invo_sequence
                      ,invoice_type
                      ,invo_start
                      ,invo_end
                      ,extra_due_date
                      ,creation_reason
                      ,pri_curr_code
                      )
      VALUES (p_invo_rec.ref_num
             ,p_invo_rec.invoice_number
             ,p_invo_rec.maac_ref_num
             ,p_invo_rec.total_amt
             ,p_invo_rec.total_vat
             ,p_invo_rec.outstanding_amt
             ,p_invo_rec.created_by
             ,p_invo_rec.date_created
             ,p_invo_rec.credit
             ,p_invo_rec.billed
             ,p_invo_rec.billing_inv
             ,p_invo_rec.print_req
             ,p_invo_rec.stat_ref_num
             ,p_invo_rec.due_date
             ,p_invo_rec.salp_fina_year
             ,p_invo_rec.salp_per_num
             ,p_invo_rec.invoice_date
             ,p_invo_rec.period_start
             ,p_invo_rec.period_end
             ,p_invo_rec.date_printed
             ,p_invo_rec.last_updated_by
             ,p_invo_rec.date_updated
             ,p_invo_rec.sully_paid
             ,p_invo_rec.fully_paid
             ,p_invo_rec.bicy_cycle_code
             ,p_invo_rec.invo_sequence
             ,p_invo_rec.invoice_type
             ,p_invo_rec.invo_start
             ,p_invo_rec.invo_end
             ,p_invo_rec.extra_due_date
             ,p_invo_rec.creation_reason
             ,p_invo_rec.pri_curr_code
             );
   END ins_invo;

   /***************************************************************************
   **
   **   Procedure Name :  CHANGE_INVO_TYPE_TO_INT
   **
   **   Description : Local procedure.
   **                 This procedure changes current billing invoice from
   **                 billing invoice to interim invoice.
   **
   ****************************************************************************/
   PROCEDURE change_invo_type_to_int (p_invo_rec         IN OUT invoices%ROWTYPE
                                     ,p_creation_reason  IN     invoices.creation_reason%TYPE
                                     ,p_days_credit      IN     NUMBER
                                     ,p_created_by       IN     VARCHAR2
                                     ) IS
   BEGIN
      p_invo_rec.invoice_type := 'INT';
      p_invo_rec.invoice_number := 'V' || SUBSTR (p_invo_rec.invoice_number, 2);
      p_invo_rec.invo_sequence := SUBSTR (p_invo_rec.invoice_number, 6);
      p_invo_rec.invoice_date := SYSDATE;
      p_invo_rec.period_end := p_invo_rec.invoice_date;
      p_invo_rec.invo_end := p_invo_rec.invoice_date;
      p_invo_rec.creation_reason := p_creation_reason;
      p_invo_rec.due_date := gen_bill.calc_due_date (p_invo_rec.invoice_date, 'INT', p_days_credit, NULL);
      p_invo_rec.last_updated_by := SUBSTR (p_created_by, 1, 15); -- CHG-776
      p_invo_rec.date_updated := SYSDATE;
      --
      upd_invo (p_invo_rec);
   END change_invo_type_to_int;

   /***************************************************************************
   **
   **   Procedure Name :  REMOVE_SUSG_TAB_DUPLICATE_ROWS
   **
   **   Description : Local procedure.
   **                 Removes rows with duplicate values from input table and
   **                 produces output table without duplicate row values.
   **
   ** NB!  1.9   28.09.2005  O.Vaikneme CHG-112:  Päisesse FUNCTION Get_Mobile_Number, võimaldamaks selle väljakutset ekraanivormist BCCF040.
   **                                          NB! Protseduurid Remove_SUSG_Tab_Duplicate_Rows ja Create_MultiSUSG_Int_Invoice ning
   **                                          tyyp SUSGTabType on 10g kompatiiblusprobleemide tõttu kopeeritud ekraanivormi BCCF040
   **                                          paketti Multisusg_Int_Invoice_P, kui need muutuvad, siis on vaja need protseduurid
   **                                          kopeerida ka sinna!
   ****************************************************************************/
   PROCEDURE remove_susg_tab_duplicate_rows (p_in_susg_tab   IN     susgtabtype
                                            ,p_out_susg_tab     OUT susgtabtype
                                            ) IS
      --
      l_exists                      BOOLEAN;
      l_idx                         NUMBER;
   BEGIN
      l_idx := p_in_susg_tab.FIRST;
      p_out_susg_tab (1) := p_in_susg_tab (l_idx);

      --
      IF p_in_susg_tab.COUNT > 1 THEN
         l_idx := p_in_susg_tab.NEXT (l_idx);

         FOR i IN 2 .. p_in_susg_tab.COUNT LOOP
            l_exists := FALSE;

            FOR j IN 1 .. p_out_susg_tab.COUNT LOOP
               IF p_out_susg_tab (j) = p_in_susg_tab (l_idx) THEN
                  l_exists := TRUE;
                  EXIT;
               END IF;
            END LOOP;

            --
            IF NOT l_exists THEN
               p_out_susg_tab (p_out_susg_tab.COUNT + 1) := p_in_susg_tab (l_idx);
            END IF;

            --
            l_idx := p_in_susg_tab.NEXT (l_idx);
         END LOOP;
      END IF;
   END remove_susg_tab_duplicate_rows;

   /***************************************************************************
   **   Local Procedure
   **   Procedure Name :  ENTRIES_PARTITITION
   **
   **   Description : This procedure deals with partitition error on updating
   **   invoice_entries. References only create_susg_invoice_entries
   **
   ****************************************************************************/
   PROCEDURE entries_partitition (p_int_invo_ref_num  IN invoices.ref_num%TYPE
                                 ,p_inb_invo_ref_num  IN invoices.ref_num%TYPE
                                 ,p_susg_ref_num         invoice_entries.susg_ref_num%TYPE
                                 ) IS
      CURSOR c_invo_entry IS
         SELECT *
           FROM invoice_entries
          WHERE invo_ref_num = p_inb_invo_ref_num AND susg_ref_num = p_susg_ref_num;

      l_entry                       invoice_entries%ROWTYPE;
      l_inb_inen_ref                invoice_entries.ref_num%TYPE;
   BEGIN
      FOR l_entry IN c_invo_entry LOOP
         l_inb_inen_ref := l_entry.ref_num; -- vana inb arve inen.ref_num
         l_entry.invo_ref_num := p_int_invo_ref_num;
         -- INSERT a new invoice_entry
         gen_bill.insert_inen (l_entry);

         -- update kõik evre_records_curr, kus tegu selle ref_num-ga
         UPDATE event_records_curr
            SET char_inen_ref_num = l_entry.ref_num
          WHERE char_inen_ref_num = l_inb_inen_ref AND susg_ref_num = p_susg_ref_num;

         UPDATE delivery_note_entries
            SET char_inen_ref_num = l_entry.ref_num, date_updated = SYSDATE, updated_by = sec.get_username
          WHERE char_inen_ref_num = l_inb_inen_ref;

         UPDATE evre_min_discounts
            SET inen_ref_num = l_entry.ref_num
          WHERE inen_ref_num = l_inb_inen_ref;

         UPDATE smsss_event_records
            SET char_inen_ref_num = l_entry.ref_num
          WHERE char_inen_ref_num = l_inb_inen_ref;

         UPDATE gprs_event_records
            SET char_inen_ref_num = l_entry.ref_num
          WHERE char_inen_ref_num = l_inb_inen_ref;
      END LOOP;

      -- delete an old invoice_entry
      DELETE FROM invoice_entries
            WHERE invo_ref_num = p_inb_invo_ref_num AND susg_ref_num = p_susg_ref_num;
   END entries_partitition;

   /*
     **
     **   -- GLOBAL PROGRAM UNITS seen also outside current package
     **
   */

   /***************************************************************************
   **
   **   Procedure Name :  CHECK_MAAC_INVOICABILITY
   **
   **   Description : This procedure checks according to rules if interim invoice
   **                 is allowed for current Master Account.
   **
   ****************************************************************************/
   PROCEDURE check_maac_invoicability (p_maac_ref_num  IN     accounts.ref_num%TYPE
                                      ,p_salp_start    IN     sales_ledger_periods.start_date%TYPE
                                      ,p_invo_ref_num     OUT invoices.ref_num%TYPE
                                      ,p_invo_start       OUT invoices.invo_start%TYPE
                                      ,p_inip_ref_num     OUT interim_invoice_periods.ref_num%TYPE
                                      ,p_success          OUT BOOLEAN
                                      ,p_message          OUT VARCHAR2
                                      ) IS
      --
      e_prev_interim_inv_today      EXCEPTION;
      e_maac_not_ac                 EXCEPTION;
   BEGIN
      /*
        ** Get interim invoice start date.
        ** If start date is today then previous interim invoice was also created today
        ** and it is not allowed to create this invoice.
      */
      invoice_periods.lock_invo_start_for_maac (p_maac_ref_num, p_salp_start, p_inip_ref_num, p_invo_start);

      --
      IF TRUNC (p_invo_start) = TRUNC (SYSDATE) THEN
         RAISE e_prev_interim_inv_today;
      END IF;

      /*
        ** Get open billing invoice for current period.
        ** If not found then check if Mater Account is AC at invoice end.
      */
      p_invo_ref_num := open_invoice.get_open_invo (p_maac_ref_num, SYSDATE -- get invoice for current period
                                                                           , FALSE);

      -- don't create new invoice if not found
      IF p_invo_ref_num IS NULL THEN
         IF NOT chk_maac_ac (p_maac_ref_num, SYSDATE) THEN
            RAISE e_maac_not_ac;
         END IF;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_prev_interim_inv_today THEN
         p_success := FALSE;
         p_message :=    'Not allowed to create interim invoice. Previous interim invoice'
                      || ' for M/A '
                      || TO_CHAR (p_maac_ref_num)
                      || ' was created at '
                      || TO_CHAR (p_invo_start, 'dd.mm.yyyy hh24:mi:ss');
      WHEN e_maac_not_ac THEN
         p_success := FALSE;
         p_message :=    'Not allowed to create interim invoice. Master Account '
                      || TO_CHAR (p_maac_ref_num)
                      || ' is not AC.';
   END check_maac_invoicability;

   /***************************************************************************
   **
   **   Function Name :  SUSG_EVENTS_EXISTS
   **
   **   Description : This function checks if there are any events on given
   **                 Invoice for given Mobile.
   **
   ****************************************************************************/
   FUNCTION susg_events_exists (p_susg_ref_num  IN subs_serv_groups.ref_num%TYPE
                               ,p_invo_ref_num  IN invoices.ref_num%TYPE
                               )
      RETURN BOOLEAN IS
      --
      CURSOR c_inen IS
         SELECT 1
           FROM invoice_entries
          WHERE invo_ref_num = p_invo_ref_num AND susg_ref_num = p_susg_ref_num;

      --
      l_dummy                       NUMBER;
   BEGIN
      OPEN c_inen;

      FETCH c_inen INTO l_dummy;

      --
      IF c_inen%FOUND THEN
         CLOSE c_inen;

         RETURN TRUE;
      ELSE
         CLOSE c_inen;

         RETURN FALSE;
      END IF;
   END susg_events_exists;

   /***************************************************************************
   **
   **   Procedure Name :  CHECK_SUSG_INVOICABILITY
   **
   **   Description : This procedure checks according to rules if interim invoice
   **                 is allowed for current Mobile.
   **
   ****************************************************************************/
   PROCEDURE check_susg_invoicability (p_maac_ref_num  IN     accounts.ref_num%TYPE
                                      ,p_susg_ref_num  IN     subs_serv_groups.ref_num%TYPE
                                      ,p_invo_ref_num  IN     invoices.ref_num%TYPE
                                      ,p_period_start  IN     sales_ledger_periods.start_date%TYPE
                                      ,p_invo_start       OUT invoices.invo_start%TYPE
                                      ,p_inip_ref_num     OUT interim_invoice_periods.ref_num%TYPE
                                      ,p_success          OUT BOOLEAN
                                      ,p_message          OUT VARCHAR2
                                      ) IS
      --
      l_serv_num                    senu_susg.serv_num%TYPE;
      l_ac_days                     NUMBER;
      l_inip_ref_for_maac           interim_invoice_periods.ref_num%TYPE;
      l_invo_start_for_maac         interim_invoice_periods.invo_period_start%TYPE;
      l_prev_invo_end               DATE;
      --
      e_prev_interim_inv_today      EXCEPTION;
      e_no_charges                  EXCEPTION;
   BEGIN
      /*
        ** Get interim invoice start date for current Mobile.
        ** If start date is today then previous interim invoice was also created today
        ** and it is not allowed to create this invoice.
      */
      DBMS_OUTPUT.put_line ('Calling Invoice Periods.LOCK_INVO_START_FOR_SUSG');
      invoice_periods.lock_invo_start_for_susg (p_maac_ref_num
                                               ,p_susg_ref_num
                                               ,p_period_start
                                               ,p_inip_ref_num
                                               ,p_invo_start
                                               );

      --
      IF TRUNC (p_invo_start) = TRUNC (SYSDATE) THEN
         l_prev_invo_end := p_invo_start;
         RAISE e_prev_interim_inv_today;
      END IF;

      /*
        ** Check also that previous interim invoice for Master Account
        ** was not created today.
      */
      invoice_periods.retrieve_invo_start_for_maac (p_maac_ref_num
                                                   ,p_period_start
                                                   ,l_inip_ref_for_maac
                                                   ,l_invo_start_for_maac
                                                   );

      --
      IF TRUNC (l_invo_start_for_maac) = TRUNC (SYSDATE) THEN
         l_prev_invo_end := l_invo_start_for_maac;
         RAISE e_prev_interim_inv_today;
      END IF;

      --
      IF l_inip_ref_for_maac IS NOT NULL THEN
         p_invo_start := l_invo_start_for_maac;
      END IF;

      /*
        ** Check if events exist on this invoice for the current Mobile.
        ** If not then check if Mobile has been AC within current invoice period
        ** (for monthly charges calculation).
      */
      IF NOT susg_events_exists (p_susg_ref_num, p_invo_ref_num) THEN
         DBMS_OUTPUT.put_line ('Calling Calculate_Fixed_Charges.Find_Pack_Days');
         l_ac_days := calculate_fixed_charges.find_pack_days (NVL (p_invo_start, p_period_start)
                                                             ,SYSDATE
                                                             ,p_susg_ref_num
                                                             ,0
                                                             ); -- months after TC

         IF l_ac_days = 0 THEN
            RAISE e_no_charges;
         END IF;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_prev_interim_inv_today THEN
         p_success := FALSE;
         l_serv_num := get_mobile_number (p_susg_ref_num);
         p_message :=    'Previous interim invoice for Mobile '
                      || l_serv_num
                      || ' was created at '
                      || TO_CHAR (l_prev_invo_end, 'dd.mm.yyyy hh24:mi:ss');
      WHEN e_no_charges THEN
         p_success := FALSE;
         l_serv_num := get_mobile_number (p_susg_ref_num);
         p_message := 'No charges to calculate for mobile ' || l_serv_num;
   END check_susg_invoicability;

   /***************************************************************************
   **
   **   Procedure Name :  CREATE_INTERIM_INVOICE_HEADER
   **
   **   Description : This procedure creates a record in Invoices table for
   **                 interim invoice.
   **
   ****************************************************************************/
   PROCEDURE create_interim_invoice_header (p_maac_ref_num     IN     accounts.ref_num%TYPE
                                           ,p_susg_ref_num     IN     subs_serv_groups.ref_num%TYPE
                                           ,p_period_start     IN     sales_ledger_periods.start_date%TYPE
                                           ,p_creation_reason  IN     invoices.creation_reason%TYPE
                                           ,p_days_credit      IN     NUMBER
                                           ,p_created_by       IN     VARCHAR2
                                           ,p_invo_rec            OUT invoices%ROWTYPE
                                           ,p_inip_ref_num        OUT interim_invoice_periods.ref_num%TYPE
                                           ,p_success             OUT BOOLEAN
                                           ,p_invo_start       IN     invoices.invo_start%TYPE DEFAULT NULL
                                           ) IS
   BEGIN
      p_success := FALSE;
      --
      p_invo_rec.invoice_type := 'INT';
      p_invo_rec.billing_inv := 'Y';
      p_invo_rec.credit := 'N';
      p_invo_rec.period_start := p_period_start;
      /*
        ** Get invoice number and sequence.
      */
      open_invoice.get_invoice_number (p_invo_rec.invoice_type
                                      ,p_invo_rec.period_start
                                      ,p_invo_rec.invoice_number
                                      ,p_invo_rec.invo_sequence
                                      );

      /*
        ** Get invoice start date.
      */
      IF p_invo_start IS NOT NULL THEN
         p_invo_rec.invo_start := p_invo_start;
      ELSE
         IF p_susg_ref_num IS NULL THEN
            /*
              ** Master Account level.
            */
            invoice_periods.retrieve_invo_start_for_maac (p_maac_ref_num
                                                         ,p_period_start
                                                         ,p_inip_ref_num
                                                         ,p_invo_rec.invo_start
                                                         );
         ELSE
            /*
              ** Mobile level.
            */
            invoice_periods.retrieve_invo_start_for_susg (p_maac_ref_num
                                                         ,p_susg_ref_num
                                                         ,p_period_start
                                                         ,p_inip_ref_num
                                                         ,p_invo_rec.invo_start
                                                         );
         END IF;

         /*
           ** If Interim Invoice Period not found then invoice start = period start.
         */
         IF p_inip_ref_num IS NULL THEN
            p_invo_rec.invo_start := p_period_start;
         END IF;
      END IF;

      --
      p_invo_rec.invoice_date := SYSDATE;
      p_invo_rec.period_end := p_invo_rec.invoice_date;
      p_invo_rec.invo_end := p_invo_rec.invoice_date;
      p_invo_rec.creation_reason := p_creation_reason;
      p_invo_rec.due_date := gen_bill.calc_due_date (p_invo_rec.invoice_date, 'INT', p_days_credit, NULL);
      p_invo_rec.created_by := SUBSTR (p_created_by, 1, 15); -- CHG-776
      p_invo_rec.date_created := SYSDATE;
      p_invo_rec.maac_ref_num := p_maac_ref_num;
      p_invo_rec.print_req := 'N';
      p_invo_rec.billed := 'N';
      p_invo_rec.total_amt := 0;
      p_invo_rec.total_vat := 0;
      p_invo_rec.outstanding_amt := 0;
      p_invo_rec.pri_curr_code := get_pri_curr_code ();
      --
      ins_invo (p_invo_rec);
      --
      p_success := TRUE;
   END create_interim_invoice_header;

   /***************************************************************************
   **
   **   Procedure Name :  CREATE_SUSG_INT_FIXED_CHARGES
   **
   **   Description : This procedure calls fixed charges calculation for given
   **                 Mobile.
   **
   ****************************************************************************/
   PROCEDURE create_susg_int_fixed_charges (p_maac_ref_num  IN     accounts.ref_num%TYPE
                                           ,p_susg_ref_num  IN     subs_serv_groups.ref_num%TYPE
                                           ,p_invo_rec      IN OUT invoices%ROWTYPE
                                           ,p_success          OUT BOOLEAN
                                           ,p_error_text       OUT VARCHAR2
                                           ,p_maac_level    IN     BOOLEAN DEFAULT FALSE
                                           ) IS
      --
      l_inip_ref_num                interim_invoice_periods.ref_num%TYPE;
      l_invo_period_start           DATE;
      l_invo_charge_start           DATE;
      l_invo_ref_num_retrieved      invoices.ref_num%TYPE;
   BEGIN
      IF p_maac_level THEN
         l_invo_ref_num_retrieved := NULL;
      ELSE
         l_invo_ref_num_retrieved := p_invo_rec.ref_num;
      END IF;

      /*
        ** Find start date for fixed charge calculations.
      */
      invoice_periods.find_susg_charge_curr_start (p_maac_ref_num
                                                  ,p_susg_ref_num
                                                  ,p_invo_rec.period_start
                                                  ,l_inip_ref_num
                                                  ,l_invo_period_start
                                                  ,l_invo_charge_start
                                                  ,l_invo_ref_num_retrieved
                                                  ,p_invo_rec.ref_num
                                                  );

      IF l_invo_period_start = p_invo_rec.period_start THEN
         l_invo_charge_start := p_invo_rec.invo_start;
      END IF;

      --
      calculate_fixed_charges.period_fixed_charges (p_maac_ref_num
                                                   ,p_susg_ref_num
                                                   ,p_invo_rec
                                                   ,p_success
                                                   ,p_error_text
                                                   ,l_invo_charge_start
                                                   ,p_invo_rec.invo_end
                                                   ,'B'
                                                   ,'U750'
                                                   );

      IF NOT p_success THEN
         RETURN;
      END IF;

      /*
        ** CHG-498: Lisatud mobiili taseme teenuste päevade arvust sõltumatute (non-prorata) kuutasude arvutus.
      */
      process_monthly_service_fees.chk_mob_nonker_serv_fees_by_ma (p_maac_ref_num -- IN     accounts.ref_num%TYPE
                                                                  ,p_invo_rec.ref_num -- IN     invoices.ref_num%TYPE
                                                                  ,p_invo_rec.period_start -- p_period_start IN     DATE
                                                                  ,p_invo_rec.invo_end -- p_period_end   IN     DATE
                                                                  ,p_success -- OUT BOOLEAN
                                                                  ,p_error_text -- OUT VARCHAR2
                                                                  ,p_susg_ref_num -- IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                                  );

      IF NOT p_success THEN
         RETURN;
      END IF;

      /* End of CHG-498 */

      /*
        ** DOBAS-1721: Lisatud mobiili taseme teenuste päevade arvust sõltuvate (daily_charge) kuutasude arvutus.
      */
      PROCESS_DAILY_CHARGES.PROC_DAILY_CHARGES_MA (p_maac_ref_num 
                                                  ,p_invo_rec.ref_num 
                                                  ,p_invo_rec.period_start
                                                  ,trunc(p_invo_rec.invo_end)
                                                  ,p_success
                                                  ,p_error_text
                                                  ,p_susg_ref_num -- IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
      );

      IF NOT p_success THEN
         RETURN;
      END IF;

      /* End of DOBAS-1721 */

      /*
        ** CHG-3811: Lisatud REPL tüüpi paketi kuutasude arvutus.
      */
      calculate_fixed_charges.calc_non_prorata_maac_pkg_chg (p_maac_ref_num -- IN     accounts.ref_num%TYPE
                                                            ,p_susg_ref_num -- IN     subs_serv_groups.ref_num%TYPE
                                                            ,p_invo_rec.ref_num -- IN     INVOICES.ref_num%TYPE
                                                            ,p_invo_rec.period_start -- p_period_start IN     DATE
                                                            ,p_invo_rec.invo_end -- p_period_end   IN     DATE
                                                            ,p_success -- OUT BOOLEAN
                                                            ,p_error_text -- OUT VARCHAR2
                                                            ,FALSE -- CHG-3714: p_interim_balance  IN
                                                            ,'REPL' -- CHG-3714: p_regular_type     IN
                                                            );

      /*
        ** CHG-69: Lisatud päevade arvust sõltumatute (non-prorata) paketi kuutasude arvutus
        **         võlanõude vahearvetele.
      */
      IF p_invo_rec.invoice_type = 'INT' AND p_invo_rec.creation_reason = 'VNV' THEN
         calculate_fixed_charges.calc_non_prorata_maac_pkg_chg (p_maac_ref_num -- IN     accounts.ref_num%TYPE
                                                               ,p_susg_ref_num -- IN     subs_serv_groups.ref_num%TYPE
                                                               ,p_invo_rec.ref_num -- IN     INVOICES.ref_num%TYPE
                                                               ,p_invo_rec.period_start -- p_period_start IN     DATE
                                                               ,p_invo_rec.invo_end -- p_period_end   IN     DATE
                                                               ,p_success -- OUT BOOLEAN
                                                               ,p_error_text -- OUT VARCHAR2
                                                               ,FALSE -- CHG-3714: p_interim_balance  IN
                                                               ,'MINB' -- CHG-3714: p_regular_type     IN
                                                               );

         IF NOT p_success THEN
            RETURN;
         END IF;

         /*
           ** CHG-3060: SUSG paketeeritud teenuspaketi paketitasu arveldus
         */
         process_packet_fees.bill_susg_packet_fees (p_maac_ref_num -- IN     accounts.ref_num%TYPE,
                                                   ,p_invo_rec.ref_num -- IN     INVOICES.ref_num%TYPE,
                                                   ,p_susg_ref_num -- IN     subs_serv_groups.ref_num%TYPE,
                                                   ,p_invo_rec.period_start -- p_period_start IN     DATE,
                                                   ,p_invo_rec.period_end -- CHG-3231
                                                   ,p_error_text ---- OUT VARCHAR2,
                                                   ,p_success -- OUT BOOLEAN
                                                   );

         IF NOT p_success THEN
            RETURN;
         END IF;

         /*
           ** CHG-5762: SUSG paketeeritud seadme kuutasud
         */
         process_mixed_packet_fees.bill_one_maac_packet_orders (p_maac_ref_num --IN     accounts.ref_num%TYPE
                                                               ,p_invo_rec.period_start --IN     DATE
                                                               ,p_invo_rec.period_end --IN     DATE
                                                               ,p_success --   OUT BOOLEAN
                                                               ,p_error_text --   OUT VARCHAR2
                                                               ,p_invo_rec.ref_num --IN     invoices.ref_num%TYPE DEFAULT NULL
                                                               ,p_susg_ref_num --IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                               ,'N' --p_commit IN     VARCHAR2 DEFAULT 'Y'
                                                               );

         IF NOT p_success THEN
            RETURN;
         END IF;

         /*
           ** CHG-5762: SUSG PAK2 lahendustasu
         */
         process_mixed_packet_fees.calc_invo_solution_fees (p_invo_rec.ref_num --IN     invoices.ref_num%TYPE
                                                           ,p_success --   OUT BOOLEAN
                                                           ,p_error_text --   OUT VARCHAR2
                                                           ,p_susg_ref_num --IN     subs_serv_groups.ref_num%TYPE DEFAULT NULL
                                                           ,'N' --p_commit         IN     VARCHAR2 DEFAULT 'Y'
                                                           );

         IF NOT p_success THEN
            RETURN;
         END IF;
      END IF;

      /*
       ** Set calculated status in Interim Invoice Period if Mobile level record was found.
      */
      IF l_inip_ref_num IS NOT NULL THEN
         p_success := invoice_periods.update_calculation_status (l_inip_ref_num, p_invo_rec.ref_num);
      END IF;

      --
      p_success := TRUE;
   END create_susg_int_fixed_charges;

   /***************************************************************************
   **
   **   Procedure Name :  CREATE_MAAC_INT_FIXED_CHARGES
   **
   **   Description : This procedure calls fixed charges calculation for
   **                 all Mobiles of the given Master Account.
   **
   ****************************************************************************/
   PROCEDURE create_maac_int_fixed_charges (p_maac_ref_num  IN     accounts.ref_num%TYPE
                                           ,p_invo_rec      IN OUT invoices%ROWTYPE
                                           ,p_inip_ref_num  IN     interim_invoice_periods.ref_num%TYPE
                                           ,p_success          OUT BOOLEAN
                                           ,p_error_text       OUT VARCHAR2
                                           ) IS
      --
      CURSOR c_susg IS
         SELECT ref_num
           FROM subs_serv_groups
          WHERE suac_ref_num IN (SELECT ref_num
                                   FROM subs_accounts_v
                                  WHERE maac_ref_num = p_maac_ref_num);

      --
      e_fixed_charges_error         EXCEPTION;
      l_one_sec                     NUMBER := 1 / 86400;
      l_start                       DATE;
      l_end                         DATE;
   BEGIN
      /*
        ** Calculate fixed charges for Master Account Services.
      */
      DBMS_OUTPUT.enable (1000000);

      IF p_invo_rec.period_start = p_invo_rec.invo_start THEN
         l_start := p_invo_rec.invo_start;
      ELSE
         IF p_invo_rec.invo_start < TRUNC (p_invo_rec.invo_start) + 0.5 THEN
            -- päev läheb arvesse kuumaksu arvutusel
            l_start := p_invo_rec.invo_start;
         ELSE -- päev ei lähe arvesse kuumaksu arvutusel , peale 12.00
            l_start := TRUNC (p_invo_rec.invo_start) + 1;
         END IF;
      END IF;

      -- end_date kontroll
      IF p_invo_rec.invo_end >= TRUNC (p_invo_rec.invo_end) + 0.5 THEN
         -- päev läheb arvesse kuumaksu arvutusel
         l_end := (TRUNC (p_invo_rec.invo_end) + 1) - l_one_sec;
      ELSE -- päev ei lähe arvesse kuumaksu arvutusel , enne 12.00
         l_end := TRUNC (p_invo_rec.invo_end) - l_one_sec;
      END IF;

      --dbms_output.put_line('l_start='||to_char(l_start,'dd.mm.yyyy hh24:mi:ss'));
      --dbms_output.put_line('l_end='||to_char(l_end,'dd.mm.yyyy hh24:mi:ss'));
      calculate_fixed_charges.main_master_service_charges (p_maac_ref_num
                                                          ,p_invo_rec
                                                          ,p_success
                                                          ,p_error_text
                                                          ,l_start --   kuumaksu arvutamise start kuupäev
                                                          ,l_end --   kuumaksu arvutamise end kuupäev timefaktoriga
                                                          ,'B'
                                                          );

      IF NOT p_success THEN
         RAISE e_fixed_charges_error;
      END IF;

      /*
        ** Loop through all Mobiles of current M/A.
        ** Fixed charges calculation will calculate anyway charges only for
        ** currently active Mobiles.
      */
      FOR l_susg_rec IN c_susg LOOP
         create_susg_int_fixed_charges (p_maac_ref_num, l_susg_rec.ref_num, p_invo_rec, p_success, p_error_text, TRUE); -- Called from Master Account level

         --
         IF NOT p_success THEN
            RAISE e_fixed_charges_error;
         END IF;
      END LOOP;

      /*
        ** Set calculated status in Interim Invoice Period if Master Account level
        ** record was found.
      */
      IF p_inip_ref_num IS NOT NULL THEN
         p_success := invoice_periods.update_calculation_status (p_inip_ref_num, p_invo_rec.ref_num);
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_fixed_charges_error THEN
         /*
           ** Return error message text from subprocedure.
         */
         NULL;
   END create_maac_int_fixed_charges;

   /***************************************************************************
   **
   **   Procedure Name :  CALC_INTERIM_INVOICE
   **
   **   Description : This procedure calls standard routines for calculations
   **                 upon given Invoice.
   **
   ****************************************************************************/
   PROCEDURE calc_interim_invoice (p_invo_rec  IN OUT invoices%ROWTYPE
                                  ,p_success      OUT BOOLEAN
                                  ,p_message      OUT VARCHAR2
                                  ) IS
      --
      l_invo_total                  NUMBER;
      l_chk_outstanding             NUMBER;
      l_fully_paid                  DATE;
      --
      e_create_roaming_markup       EXCEPTION;
      e_calculate_taxes             EXCEPTION;
      e_recalc_invoice              EXCEPTION;
   BEGIN
      bcc_calc.calc_taxes (p_success, p_invo_rec.ref_num, p_invo_rec.invo_end);

      IF NOT p_success THEN
         RAISE e_calculate_taxes;
      END IF;

      --
      create_rounding_entries (p_invo_rec.ref_num);
      --
      l_invo_total := 0;
      wholesale_common.recalc_invoice (p_invo_rec.maac_ref_num, p_invo_rec.ref_num, l_invo_total, p_message, p_success);
      DBMS_OUTPUT.put_line ('Invoice ' || TO_CHAR (p_invo_rec.ref_num) || ' total is ' || TO_CHAR (l_invo_total));

      IF NOT p_success THEN
         RAISE e_recalc_invoice;
      END IF;

      /*
        ** Allocate unallocated payments and credit invoices of this Master Account
        ** to newly created invoice.
      */
      l_invo_total := NVL (l_invo_total, 0);
      l_chk_outstanding := l_invo_total;
      process_account_payments.allocate_invoice (p_invo_rec.ref_num
                                                ,p_invo_rec.maac_ref_num
                                                ,'N' -- No credit invoice
                                                ,l_invo_total -- outstanding amt = invoice total right now (when passing in)
                                                ,0 -- amount, not needed here
                                                ,0 -- old amount, not needed here
                                                ,0 -- tax, not needed here
                                                ,0 -- old tax, not needed here
                                                );

      IF l_chk_outstanding <> l_invo_total THEN
         /*
           ** Some payments were allocated to this invoice.
         */
         IF l_invo_total = 0 THEN
            l_fully_paid := SYSDATE;
         END IF;

         --
         UPDATE invoices
            SET outstanding_amt = ROUND (l_invo_total, 2), fully_paid = NVL (l_fully_paid, fully_paid)
          WHERE ref_num = p_invo_rec.ref_num;
      END IF;
   EXCEPTION
      WHEN e_create_roaming_markup THEN
         p_message := 'Error when creating roaming markup entries for invoice.';
      WHEN e_calculate_taxes THEN
         p_message := 'Error when calculating taxes for invoice.';
      WHEN e_recalc_invoice THEN
         NULL;
   END calc_interim_invoice;

   /***************************************************************************
   **
   **   Procedure Name :  CREATE_SUSG_INVOICE_ENTRIES
   **
   **   Description : This procedure creates interim invoice entries for one
   **                 given Mobile.
   **
   ****************************************************************************/
   PROCEDURE create_susg_invoice_entries (
      p_maac_ref_num         IN     accounts.ref_num%TYPE
     ,p_susg_ref_num         IN     subs_serv_groups.ref_num%TYPE
     ,p_inb_invo_ref_num     IN     invoices.ref_num%TYPE
     ,p_int_invo_rec         IN OUT invoices%ROWTYPE
     ,p_success                 OUT BOOLEAN
     ,p_message                 OUT VARCHAR2
     ,p_check_invoicability  IN     BOOLEAN DEFAULT TRUE
     ,p_inip_ref_num         IN     interim_invoice_periods.ref_num%TYPE DEFAULT NULL) IS
      --
      CURSOR c_inen IS
         SELECT     *
               FROM invoice_entries
              WHERE invo_ref_num = p_inb_invo_ref_num AND susg_ref_num = p_susg_ref_num
         FOR UPDATE OF invo_ref_num, date_updated, last_updated_by;

      --
      l_invo_start                  invoices.invo_start%TYPE;
      l_inip_ref_num                interim_invoice_periods.ref_num%TYPE;
      l_new_inip_ref_num            interim_invoice_periods.ref_num%TYPE;
      l_serv_num                    senu_susg.serv_num%TYPE;
      --
      e_susg_not_invoicable         EXCEPTION;
      e_creating_minute_disc        EXCEPTION;
      e_fixed_charge_calc           EXCEPTION;
      e_upd_invo_retrieved          EXCEPTION;
      e_partitition                 EXCEPTION;
      PRAGMA EXCEPTION_INIT (e_partitition, -14402);
   BEGIN
      IF p_inip_ref_num IS NOT NULL THEN
         l_inip_ref_num := p_inip_ref_num;
      END IF;

      /*
        ** Check if there is anything to invoice for this Mobile.
        ** In case called by group of mobiles.
      */
      IF p_check_invoicability THEN
         check_susg_invoicability (p_maac_ref_num
                                  ,p_susg_ref_num
                                  ,p_inb_invo_ref_num
                                  ,p_int_invo_rec.period_start
                                  ,l_invo_start
                                  ,l_inip_ref_num
                                  ,p_success
                                  ,p_message
                                  );

         IF NOT p_success THEN
            RAISE e_susg_not_invoicable;
         END IF;
      END IF;

      /*
        ** If current billing invoice exists then transfer all rows for current Mobile
        ** from billing invoice to new interim invoice and
        ** calculate minute discounts for this Mobile.
      */
      IF p_inb_invo_ref_num IS NOT NULL THEN
         /* trap partitition error  -- th */
         BEGIN
            SAVEPOINT s;

            FOR rec_inen IN c_inen LOOP
               UPDATE invoice_entries
                  SET invo_ref_num = p_int_invo_rec.ref_num, date_updated = SYSDATE, last_updated_by = sec.get_username
                WHERE CURRENT OF c_inen;
            END LOOP;
         EXCEPTION
            WHEN e_partitition THEN
               ROLLBACK TO s;
               entries_partitition (p_int_invo_rec.ref_num, p_inb_invo_ref_num, p_susg_ref_num);
         END;
      /* END trap partitition -- th */

      END IF;

      /*
        ** Mark retrieved record in Interim Invoice Periods as used.
        ** In case called by group of mobiles.
      */
      IF p_check_invoicability THEN
         IF l_inip_ref_num IS NOT NULL THEN
            p_success := invoice_periods.update_invo_retrieved (l_inip_ref_num, p_int_invo_rec.ref_num);

            IF NVL (p_success, FALSE) = FALSE THEN
               RAISE e_upd_invo_retrieved;
            END IF;
         END IF;
      END IF;

      /*
        ** Now call fixed charge calculation for this Mobile.
      */
      create_susg_int_fixed_charges (p_maac_ref_num, p_susg_ref_num, p_int_invo_rec, p_success, p_message);

      IF NVL (p_success, FALSE) = FALSE THEN
         RAISE e_fixed_charge_calc;
      END IF;

      /*
        ** Create new record in Interim Invoice Periods for this Mobile.
        ** In case called by group of mobiles.
      */
      IF p_check_invoicability THEN
         l_new_inip_ref_num := invoice_periods.insert_int_start_susg (p_maac_ref_num
                                                                     ,p_susg_ref_num
                                                                     ,p_int_invo_rec.ref_num
                                                                     ,p_int_invo_rec.invo_end
                                                                     ,p_int_invo_rec.period_start
                                                                     );
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_susg_not_invoicable THEN
         -- Return error message from sub-procedure
         NULL;
      WHEN e_fixed_charge_calc THEN
         -- Return error message from sub-procedure
         NULL;
      WHEN e_creating_minute_disc THEN
         l_serv_num := get_mobile_number (p_susg_ref_num);
         p_message := 'Error when creating minute discounts for Mobile ' || l_serv_num;
      WHEN e_upd_invo_retrieved THEN
         l_serv_num := get_mobile_number (p_susg_ref_num);
         p_message := 'Error when updating retrieved invoice for Mobile ' || l_serv_num;
   END create_susg_invoice_entries;

   /***************************************************************************
   **
   **   Procedure Name :  CREATE_SUSG_INT_INVOICE
   **
   **   Description : This procedure performs interim invoice creating for one
   **                 given Mobile. Can also be called when processing group
   **                 of mobiles, but called in context of one mobile.
   **
   ****************************************************************************/
   PROCEDURE create_susg_int_invoice (p_maac_ref_num     IN     accounts.ref_num%TYPE
                                     ,p_susg_ref_num     IN     subs_serv_groups.ref_num%TYPE
                                     ,p_int_ref_num         OUT invoices.ref_num%TYPE
                                     ,p_int_rec             OUT invoices%ROWTYPE
                                     ,p_inb_ref_num         OUT invoices.ref_num%TYPE
                                     ,p_success             OUT BOOLEAN
                                     ,p_error_text          OUT VARCHAR2
                                     ,p_close_inv        IN     BOOLEAN DEFAULT FALSE
                                     ,p_creation_reason  IN     invoices.creation_reason%TYPE DEFAULT NULL
                                     ,p_days_credit      IN     NUMBER DEFAULT NULL
                                     ,p_created_by       IN     VARCHAR2 DEFAULT 'INT_INVO_SUSG'
                                     ) IS
      --
      l_period_start                sales_ledger_periods.start_date%TYPE;
      l_invo_start                  invoices.invo_start%TYPE;
      l_invo_start_to_creation      invoices.invo_start%TYPE;
      l_period_start_to_creation    invoices.invo_start%TYPE;
      l_inip_ref_num                interim_invoice_periods.ref_num%TYPE;
      l_new_inip_ref_num            interim_invoice_periods.ref_num%TYPE;
      l_maac_level_inip_ref         interim_invoice_periods.ref_num%TYPE;
      l_susg_ref_num                subs_serv_groups.ref_num%TYPE;
      l_found                       BOOLEAN;
      l_inb_rec                     invoices%ROWTYPE;
      l_int_rec                     invoices%ROWTYPE;
      --
      e_susg_not_invoicable         EXCEPTION;
      e_creating_invoice            EXCEPTION;
      e_creating_inen               EXCEPTION;
      e_calc_totals                 EXCEPTION;
      e_upd_invo_retrieved          EXCEPTION;
   BEGIN
      /*
        ** Get current sales ledger period start date.
      */
      l_period_start := get_cur_salp_start (SYSDATE);
      /*
        ** Get open billing invoice for current period.
      */
      DBMS_OUTPUT.put_line ('Calling Open Invoice.Get_Open_Invo');
      p_inb_ref_num := open_invoice.get_open_invo (p_maac_ref_num, SYSDATE -- get invoice for current period
                                                                          , FALSE); -- don't create new invoice if not found

      IF p_inb_ref_num IS NOT NULL THEN
         l_found := get_invoice_by_ref_num (p_inb_ref_num, l_inb_rec);
         l_period_start_to_creation := l_inb_rec.period_start;
      ELSE
         l_period_start_to_creation := l_period_start;
      END IF;

      /*
        ** Check if there is anything to invoice for this Mobile.
      */
      check_susg_invoicability (p_maac_ref_num
                               ,p_susg_ref_num
                               ,p_inb_ref_num
                               ,l_period_start
                               ,l_invo_start
                               ,l_inip_ref_num
                               ,p_success
                               ,p_error_text
                               );

      IF NVL (p_success, FALSE) = FALSE THEN
         RAISE e_susg_not_invoicable;
      END IF;

      --
      IF NOT p_close_inv THEN
         /*
           ** Called for a group of Mobiles. So use Master Account level data
           ** when creating interim invoice.
         */
         l_susg_ref_num := NULL;
         l_invo_start_to_creation := NULL;
      ELSE
         /*
           ** Use Mobile level data when creating interim invoice.
         */
         l_susg_ref_num := p_susg_ref_num;
         l_invo_start_to_creation := l_invo_start;
      END IF;

      /*
        ** Create new interim invoice.
      */
      create_interim_invoice_header (p_maac_ref_num
                                    ,l_susg_ref_num
                                    ,l_period_start_to_creation
                                    ,p_creation_reason
                                    ,p_days_credit
                                    ,p_created_by
                                    ,l_int_rec
                                    ,l_maac_level_inip_ref
                                    ,p_success
                                    ,l_invo_start_to_creation
                                    );

      IF NVL (p_success, FALSE) = FALSE THEN
         RAISE e_creating_invoice;
      END IF;

      /*
        ** Mark retrieved record in Interim Invoice Periods as used.
      */
      IF l_inip_ref_num IS NOT NULL THEN
         p_success := invoice_periods.update_invo_retrieved (l_inip_ref_num, l_int_rec.ref_num);

         IF NVL (p_success, FALSE) = FALSE THEN
            RAISE e_upd_invo_retrieved;
         END IF;
      END IF;

      /*
        ** Create new record in Interim Invoice Periods for this Mobile.
      */
      l_new_inip_ref_num := invoice_periods.insert_int_start_susg (p_maac_ref_num
                                                                  ,p_susg_ref_num
                                                                  ,l_int_rec.ref_num
                                                                  ,l_int_rec.invo_end
                                                                  ,l_int_rec.period_start
                                                                  );
      --
      COMMIT;
      p_int_ref_num := l_int_rec.ref_num;
      p_int_rec := l_int_rec;
      /*
        ** Now create entries to new interim invoice.
      */
      create_susg_invoice_entries (p_maac_ref_num
                                  ,p_susg_ref_num
                                  ,p_inb_ref_num
                                  ,l_int_rec
                                  ,p_success
                                  ,p_error_text
                                  ,FALSE -- do not check invoicability (it's already checked here)
                                  ,l_inip_ref_num
                                  );

      IF NVL (p_success, FALSE) = FALSE THEN
         RAISE e_creating_inen;
      END IF;

      /*
        ** Calculate invoice totals (if needed).
      */
      IF p_close_inv THEN
         calc_interim_invoice (l_int_rec, p_success, p_error_text);

         IF NVL (p_success, FALSE) = FALSE THEN
            RAISE e_calc_totals;
         END IF;
      END IF;

      --
      p_success := TRUE;
   EXCEPTION
      WHEN e_susg_not_invoicable THEN
         -- Return error message from sub-procedure
         NULL;
      WHEN e_creating_invoice THEN
         p_error_text := 'Error when creating interim invoice header.';
      WHEN e_creating_inen THEN
         -- Return error message from sub-procedure
         NULL;
      WHEN e_calc_totals THEN
         -- Return error message from sub-procedure
         NULL;
      WHEN e_upd_invo_retrieved THEN
         p_error_text := 'Error when updating retrieved invoice for Mobile.';
      WHEN OTHERS THEN
         ROLLBACK;
         p_error_text := SQLERRM;
         p_success := FALSE;
   END create_susg_int_invoice;

   /***************************************************************************
   **
   **   Procedure Name :  CREATE_MULTISUSG_INT_INVOICE
   **
   **   Description : This procedure performs interim invoice creating for
   **                 a group of mobiles.
   **
   ** NB!  1.9   28.09.2005  O.Vaikneme CHG-112:  Päisesse FUNCTION Get_Mobile_Number, võimaldamaks selle väljakutset ekraanivormist BCCF040.
   **                                          NB! Protseduurid Remove_SUSG_Tab_Duplicate_Rows ja Create_MultiSUSG_Int_Invoice ning
   **                                          tyyp SUSGTabType on 10g kompatiiblusprobleemide tõttu kopeeritud ekraanivormi BCCF040
   **                                          paketti Multisusg_Int_Invoice_P, kui need muutuvad, siis on vaja need protseduurid
   **                                          kopeerida ka sinna!
   ****************************************************************************/
   PROCEDURE create_multisusg_int_invoice (p_maac_ref_num     IN     accounts.ref_num%TYPE
                                          ,p_susg_tab         IN     susgtabtype
                                          ,p_invo_ref_num        OUT invoices.ref_num%TYPE
                                          ,p_success             OUT BOOLEAN
                                          ,p_error_text          OUT VARCHAR2
                                          ,p_error_susg_tab      OUT susgtabtype
                                          ,p_creation_reason  IN     invoices.creation_reason%TYPE DEFAULT NULL
                                          ,p_days_credit      IN     NUMBER DEFAULT NULL
                                          ,p_created_by       IN     VARCHAR2 DEFAULT 'INT_INVO_SUSG'
                                          ) IS
      --
      l_int_rec                     invoices%ROWTYPE;
      l_int_ref_num                 invoices.ref_num%TYPE;
      l_inb_ref_num                 invoices.ref_num%TYPE;
      l_susg_tab                    susgtabtype;
      l_error_text                  VARCHAR2 (200);
      l_error_mobs                  VARCHAR2 (100);
      l_serv_num                    senu_susg.serv_num%TYPE;
      l_success                     BOOLEAN;
      l_idx                         NUMBER;
      --
      e_creating_invoice            EXCEPTION;
      e_calc_totals                 EXCEPTION;
   BEGIN
      l_int_ref_num := NULL;
      l_inb_ref_num := NULL;
      /*
        ** First remove possible duplicate row values from input table
        ** in order to ensure we have pure data.
      */
      remove_susg_tab_duplicate_rows (p_susg_tab -- input table
                                                , l_susg_tab);
      -- result table with pure data
      /*
        ** Loop through all given Mobiles.
      */
      l_idx := l_susg_tab.FIRST;

      FOR i IN 1 .. l_susg_tab.COUNT LOOP
         BEGIN
            IF l_int_ref_num IS NULL THEN
               /*
                 ** This is the 1st mobile. So we must create new invoice header and
                 ** then all the rows for this mobile.
               */
               create_susg_int_invoice (p_maac_ref_num
                                       ,l_susg_tab (l_idx)
                                       ,l_int_ref_num
                                       ,l_int_rec
                                       ,l_inb_ref_num
                                       ,l_success
                                       ,l_error_text
                                       ,FALSE -- do not close this invoice
                                       ,p_creation_reason
                                       ,p_days_credit
                                       ,p_created_by
                                       );

               IF NVL (l_success, FALSE) = FALSE THEN
                  RAISE e_creating_invoice;
               END IF;
            ELSE
               /*
                ** This is not the 1st mobile. So we must only create the rows for this mobile.
               */
               create_susg_invoice_entries (p_maac_ref_num
                                           ,l_susg_tab (l_idx)
                                           ,l_inb_ref_num
                                           ,l_int_rec
                                           ,l_success
                                           ,l_error_text
                                           ,TRUE -- Check invoicability of this mobile
                                           ,NULL
                                           ); -- inip_ref_num

               IF NVL (l_success, FALSE) = FALSE THEN
                  RAISE e_creating_invoice;
               END IF;
            END IF;
         EXCEPTION
            WHEN e_creating_invoice THEN
               p_error_susg_tab (p_error_susg_tab.COUNT + 1) := l_susg_tab (l_idx);
               l_serv_num := get_mobile_number (l_susg_tab (l_idx));
               p_success := FALSE;

               --
               IF l_error_mobs IS NULL THEN
                  l_error_mobs := l_serv_num;
                  p_error_text := l_error_text;
               ELSE
                  l_error_mobs := l_error_mobs || ', ' || l_serv_num;
                  p_error_text := p_error_text || ' ' || l_error_text;
               END IF;

               DBMS_OUTPUT.put_line ('Error mobs: ' || l_error_mobs);
               DBMS_OUTPUT.put_line ('Error text: ' || SUBSTR (p_error_text, 1, 150));
         END;

         --
         l_idx := l_susg_tab.NEXT (l_idx);
      END LOOP;

      --
      IF NOT p_success THEN
         p_error_text := 'MultiSUSG Invoice. Errors in mobiles: ' || l_error_mobs || ' ' || p_error_text;
      END IF;

      /*
        ** Calculate invoice totals (if needed).
      */
      IF l_int_ref_num IS NOT NULL THEN
         calc_interim_invoice (l_int_rec, l_success, l_error_text);

         IF NVL (l_success, FALSE) = FALSE THEN
            RAISE e_calc_totals;
         END IF;
      END IF;

      --
      IF NVL (p_success, TRUE) = TRUE THEN
         p_success := TRUE;
      END IF;

      --
      COMMIT;
      p_invo_ref_num := l_int_ref_num;
   EXCEPTION
      WHEN e_calc_totals THEN
         IF NVL (p_success, TRUE) = TRUE THEN
            p_success := FALSE;
            p_error_text := l_error_text;
         END IF;
      WHEN OTHERS THEN
         ROLLBACK;
         p_error_text := SQLERRM;
         p_success := FALSE;
   END create_multisusg_int_invoice;

   /***************************************************************************
   **
   **   Procedure Name :  CREATE_MAAC_INT_INVOICE
   **
   **   Description : This procedure performs interim invoice creating for one
   **                 given Master Account.
   **
   ****************************************************************************/
   PROCEDURE create_maac_int_invoice (p_maac_ref_num     IN     accounts.ref_num%TYPE
                                     ,p_invo_ref_num        OUT invoices.ref_num%TYPE
                                     ,p_success             OUT BOOLEAN
                                     ,p_error_text          OUT VARCHAR2
                                     ,p_creation_reason  IN     invoices.creation_reason%TYPE DEFAULT NULL
                                     ,p_days_credit      IN     NUMBER DEFAULT NULL
                                     ,p_created_by       IN     VARCHAR2 DEFAULT 'INT_INVO_MAAC'
   ) IS
      -- ARCA-76
      CURSOR c_chca (p_chk_date  DATE) IS
         SELECT chca_type_code
         FROM maac_charging_categories
         WHERE maac_ref_num = p_maac_ref_num
           AND p_chk_date BETWEEN start_date AND Nvl(end_date, p_chk_date)
      ;
      -- ARCA-76
      CURSOR c_sety_ref (p_service_name  VARCHAR2) IS
         SELECT ref_num
         FROM service_types
         WHERE service_name = p_service_name
      ;
      --
      l_period_start                sales_ledger_periods.start_date%TYPE;
      l_invo_start                  invoices.invo_start%TYPE;
      l_inip_ref_num                interim_invoice_periods.ref_num%TYPE;
      l_temp_inip_ref_num           interim_invoice_periods.ref_num%TYPE;
      l_new_inip_ref_num            interim_invoice_periods.ref_num%TYPE;
      l_found                       BOOLEAN;
      l_invo_rec                    invoices%ROWTYPE;
      l_sety_ref_num                service_types.ref_num%TYPE;  -- ARCA-76
      l_invo_ref_num                invoices.ref_num%TYPE;
      l_inen_ref_num                invoice_entries.ref_num%TYPE;  -- ARCA-76
      l_chca_type_code              maac_charging_categories.chca_type_code%TYPE;   -- ARCA-76
      l_error_type                  VARCHAR2(3);  -- ARCA-76
      --
      e_maac_not_invoicable         EXCEPTION;
      e_creating_invoice            EXCEPTION;
      e_calc_totals                 EXCEPTION;
      e_creating_minute_disc        EXCEPTION;
      e_fixed_charge_calc           EXCEPTION;
      e_upd_invo_retrieved          EXCEPTION;
   BEGIN
      DBMS_OUTPUT.enable (1000000);
      /*
        ** Get current sales ledger period start date.
      */
      l_period_start := get_cur_salp_start (SYSDATE);
      /*
        ** Check if there is anything to invoice for this Master Account and
        ** get current billing invoice.
      */
      check_maac_invoicability (p_maac_ref_num
                               ,l_period_start
                               ,l_invo_ref_num
                               ,l_invo_start
                               ,l_inip_ref_num
                               ,p_success
                               ,p_error_text
                               );

      IF NVL (p_success, FALSE) = FALSE THEN
         RAISE e_maac_not_invoicable;
      END IF;

      --
      IF l_invo_ref_num IS NOT NULL THEN
         /*
           ** Get current invoice data and update to make it interim invoice.
         */
         l_found := get_invoice_by_ref_num (l_invo_ref_num, l_invo_rec);
         change_invo_type_to_int (l_invo_rec, p_creation_reason, p_days_credit, p_created_by);
      ELSE
         /*
           ** No current billing invoice. So create one.
         */
         create_interim_invoice_header (p_maac_ref_num
                                       ,NULL -- susg_ref_num
                                       ,l_period_start
                                       ,p_creation_reason
                                       ,p_days_credit
                                       ,p_created_by
                                       ,l_invo_rec
                                       ,l_temp_inip_ref_num
                                       ,p_success
                                       ,l_invo_start
                                       );

         IF NVL (p_success, FALSE) = FALSE THEN
            RAISE e_creating_invoice;
         END IF;
      END IF;

      /*
        ** Mark retrieved record in Interim Invoice Periods as used.
      */
      IF l_inip_ref_num IS NOT NULL THEN
         p_success := invoice_periods.update_invo_retrieved (l_inip_ref_num, l_invo_rec.ref_num);

         IF NVL (p_success, FALSE) = FALSE THEN
            RAISE e_upd_invo_retrieved;
         END IF;
      END IF;

      /*
        ** Create new record in Interim Invoice Periods for this Master Account.
      */
      l_new_inip_ref_num := invoice_periods.insert_int_start_maac (p_maac_ref_num
                                                                  ,l_invo_rec.ref_num
                                                                  ,l_invo_rec.invo_end
                                                                  ,l_invo_rec.period_start
                                                                  );
      --
      COMMIT;
      /*
        ** Now call fixed charge calculation for this Master Account.
      */
      create_maac_int_fixed_charges (p_maac_ref_num, l_invo_rec, l_inip_ref_num, p_success, p_error_text);

      IF NVL (p_success, FALSE) = FALSE THEN
         RAISE e_fixed_charge_calc;
      END IF;
      
      /*
        ** ARCA-76: Arveldada Võla sissenõudmiskulude hüvitise teenus VOLAH
      */
      IF l_invo_rec.creation_reason = 'VTV' THEN  -- Võlateatise koostamine
         -- Leida Masterkonto maksustamise kategooria
         OPEN  c_chca (l_invo_rec.invoice_date);
         FETCH c_chca INTO l_chca_type_code;
         CLOSE c_chca;
         -- Leida teenuse VOLAH reference
         OPEN  c_sety_ref ('VOLAH');
         FETCH c_sety_ref INTO l_sety_ref_num;
         CLOSE c_sety_ref;
         --
         Calculate_Fixed_Charges.create_invoice_entry (
             p_invo_ref_num    => l_invo_rec.ref_num
            ,p_susg_ref_num    => NULL 
            ,p_sety_ref_num    => l_sety_ref_num
            ,p_sepv_ref_num    => NULL
            ,p_package_type    => NULL
            ,p_chca_type_code  => l_chca_type_code
            ,p_service_date    => l_invo_rec.invoice_date
            ,p_once_off        => 'Y'
            ,p_prorata         => 'N'
            ,p_regular         => 'N'
            ,p_run_mode        => NULL
            ,p_error_text      => p_error_text
            ,p_error_type      => l_error_type
            ,p_success         => p_success
            ,p_inen_ref_num    => l_inen_ref_num
            ,p_maac_ref_num    => p_maac_ref_num
         );
         --
         IF NVL (p_success, FALSE) = FALSE THEN
            RAISE e_fixed_charge_calc;
         END IF;
         --
      END IF;

      /*
        ** Calculate invoice totals.
      */
      calc_interim_invoice (l_invo_rec, p_success, p_error_text);

      IF NVL (p_success, FALSE) = FALSE THEN
         RAISE e_calc_totals;
      END IF;

      --telbal2-161 after_closing_invoice(l_invo_rec.ref_num);
      --
      COMMIT;
      p_success := TRUE;
      p_invo_ref_num := l_invo_rec.ref_num;
   EXCEPTION
      WHEN e_maac_not_invoicable THEN
         -- Return error message from sub-procedure
         NULL;
      WHEN e_creating_invoice THEN
         p_error_text := 'Error when creating interim invoice header.';
      WHEN e_calc_totals THEN
         -- Return error message from sub-procedure
         NULL;
      WHEN e_creating_minute_disc THEN
         p_error_text := 'Error when creating minute discounts for Master Account ' || TO_CHAR (p_maac_ref_num);
      WHEN e_fixed_charge_calc THEN
         -- Return error message from sub-procedure
         NULL;
      WHEN e_upd_invo_retrieved THEN
         p_error_text := 'Error when updating retrieved invoice for Master Account ' || TO_CHAR (p_maac_ref_num);
      WHEN OTHERS THEN
         ROLLBACK;
         p_error_text := SQLERRM;
         p_success := FALSE;
   END create_maac_int_invoice;

   /***************************************************************************
   **
   **   Procedure Name :  CREATE_ROUNDING_ENTRIES
   **
   **   Description : This procedure creates rounding entries on the given
   **                 invoice.
   **
   ****************************************************************************/
   PROCEDURE create_rounding_entries (p_invo_ref_num IN invoices.ref_num%TYPE) IS
      l_success                     BOOLEAN;
   BEGIN
      bcc_calc.rounding_invoices (p_success => l_success, p_invo_ref_num => p_invo_ref_num, p_update_invo_totals => FALSE);
   END create_rounding_entries;

   /***************************************************************************
   **
   **   Function Name :  GET_INVOICE_BY_REF_NUM
   **
   **   Description : Gets a row from Invoices table by ref num.
   **
   ****************************************************************************/
   FUNCTION get_invoice_by_ref_num (p_invo_ref_num  IN     invoices.ref_num%TYPE
                                   ,p_invo_rec         OUT invoices%ROWTYPE
                                   )
      RETURN BOOLEAN IS
      --
      CURSOR c_invo IS
         SELECT     *
               FROM invoices
              WHERE ref_num = p_invo_ref_num
         FOR UPDATE OF invoice_date NOWAIT;
   BEGIN
      OPEN c_invo;

      FETCH c_invo INTO p_invo_rec;

      --
      IF c_invo%FOUND THEN
         CLOSE c_invo;

         RETURN TRUE;
      ELSE
         CLOSE c_invo;

         RETURN FALSE;
      END IF;
   END get_invoice_by_ref_num;

   /***************************************************************************
   **
   **   Procedure Name :  UPD_INVO
   **
   **   Description : Update given row in Invoices table.
   **
   ****************************************************************************/
   PROCEDURE upd_invo (p_invo_rec IN OUT invoices%ROWTYPE) IS
   BEGIN
      UPDATE invoices
         SET invoice_type = NVL (p_invo_rec.invoice_type, invoice_type)
            ,invoice_number = NVL (p_invo_rec.invoice_number, invoice_number)
            ,invo_sequence = NVL (p_invo_rec.invo_sequence, invo_sequence)
            ,invoice_date = NVL (p_invo_rec.invoice_date, invoice_date)
            ,period_end = NVL (p_invo_rec.period_end, period_end)
            ,invo_end = NVL (p_invo_rec.invo_end, invo_end)
            ,creation_reason = NVL (p_invo_rec.creation_reason, creation_reason)
            ,due_date = NVL (p_invo_rec.due_date, due_date)
            ,last_updated_by = NVL (p_invo_rec.last_updated_by, last_updated_by)
            ,date_updated = NVL (p_invo_rec.date_updated, date_updated)
       WHERE ref_num = p_invo_rec.ref_num;

      --telbal2-161 after_closing_invoice (p_invo_rec.ref_num);
   END upd_invo;

   /***************************************************************************
   **
   **   Function Name :  GET_CUR_SALP_START
   **
   **   Description : Gets current Sales_Ledger_Periods start date.
   **
   ****************************************************************************/
   FUNCTION get_cur_salp_start (p_chk_date IN DATE)
      RETURN DATE IS
      --
      CURSOR c_salp IS
         SELECT start_date
           FROM sales_ledger_periods
          WHERE TRUNC (p_chk_date) BETWEEN start_date AND end_date;

      --
      l_salp_start_date             sales_ledger_periods.start_date%TYPE;
   BEGIN
      OPEN c_salp;

      FETCH c_salp INTO l_salp_start_date;

      CLOSE c_salp;

      --
      RETURN l_salp_start_date;
   END get_cur_salp_start;
--
END interim_invoice;
/