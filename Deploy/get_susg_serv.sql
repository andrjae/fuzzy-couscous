CREATE OR REPLACE PACKAGE TBCIS.GET_SUSG_SERV IS
--Purpose:
--  To create of function (SUSG_SERV()) with output equivalent to C_SERVICES cursor in package BCC_CL_INV_NEW.
--  Created to avoid index misusage with Oracle RDBMS v8.1.6.0.0
--
--MODIFICATION HISTORY
--Person       Version  Date        Comments
-------------  -------  ----------  ---------------------------------------------------------------
--A.Jaek       1.7      09.01.2019  DOBAS-1622: Uue DCH tüüpi kirjete daily_charge='Y' välistamine päringutes.
--U.Aarna      1.6      18.05.2005  CHG-499: Detail Bill usage removed. Dynamic SQL usage replaced by bulk collect.
--U.Aarna      1.5      27.03.2006  CHG-701: c_one_second asendatud dünaamilises SQL-is 1/86400
--U.Aarna      1.4      03.05.2002  UPR-2150: Select only the services which have monthly charges in Price List
--T.Hipeli     1.3      08.03.2001  UPR-1667: lisatud l_clause loogika
--Pille	       1.3      22.02.2001  UPR-1667: Lisatud parameeter p_susg_ref_num. Order by maha võet. Uus nimi:
--				    BCCU666 -> GET_SUSG_SERV. Sety peab olema olemas price_listis.
--Pille        1.2	26.01.2001  UPR-1649: Massiivi olemasolev rida on muudetud mitmerealiseks
--				    vastavalt susg-le eraldatud paketile.
--
--Virgo        1.1  	26.07.2000      Strange behaviour workaround: When using buffer size larger than
--                                  number of rows returned by query, NUMBER tables are evaluated incorrectly.
--                                  Thus using a VARCHAR2 table (nety_type_code) for loop initialization
--                                  instead. Oracle is messing up smth. with number tables.
--                                  See Oracle bug#1340820 and bug#1115720.
--
--Virgo        1.1  	06.07.2000  UPR-1542: The function rebuilt to procedure with IN OUT NOCOPY
--                                  parameter. Should be faster. Procedure name changed to Get_SUSG_SERV().
--                                  Procedure Get_SUSG_SERV() takes care of initializing the IN OUT table variable.
--
--Virgo        1.0  	04.07.2000  UPR-1542: Initial release.
--

--Query return type.
TYPE t_susg_serv IS RECORD(
   susg_ref_num      services.susg_ref_num%TYPE
  ,sety_ref_num      services.sety_ref_num%TYPE
  ,sept_type_code    subs_packages.sept_type_code%TYPE
  ,start_date        subs_packages.start_date%TYPE
  ,end_date          subs_packages.end_date%TYPE
  ,nety_type_code    subs_serv_groups.nety_type_code%TYPE
  ,in_sept_type_code subs_packages.sept_type_code%TYPE  -- UPR-1649
  ,package_category  serv_package_types.category%TYPE  -- UPR-1649
);

--Procedure Get_SUSG_SERV() return type.
TYPE t_susg_serv_tab IS TABLE OF t_susg_serv INDEX BY BINARY_INTEGER;

--The procedure returns table of records according to Master Account and
--Start/End Date specified.
PROCEDURE Get_SUSG_SERV(
   p_maac_ref_num    IN NUMBER
  ,p_invo_start_date IN DATE
  ,p_invo_end_date   IN DATE
  ,p_susg_serv_tab   IN OUT NOCOPY t_susg_serv_tab
  ,p_susg_ref_num    IN NUMBER DEFAULT NULL  -- UPR-1667
);
--
END GET_SUSG_SERV;
/
CREATE OR REPLACE PACKAGE BODY TBCIS.GET_SUSG_SERV IS
--
TYPE t_date     IS TABLE OF DATE INDEX BY BINARY_INTEGER;
TYPE t_ref_num  IS TABLE OF NUMBER(10) INDEX BY BINARY_INTEGER;
TYPE t_nety     IS TABLE OF VARCHAR2(3) INDEX BY BINARY_INTEGER;
TYPE t_sept     IS TABLE OF VARCHAR2(4) INDEX BY BINARY_INTEGER;
TYPE t_category IS TABLE OF VARCHAR2(1) INDEX BY BINARY_INTEGER;


PROCEDURE Get_SUSG_SERV(
   p_maac_ref_num    IN NUMBER
  ,p_invo_start_date IN DATE
  ,p_invo_end_date   IN DATE
  ,p_susg_serv_tab   IN OUT NOCOPY t_susg_serv_tab
  ,p_susg_ref_num    IN NUMBER DEFAULT NULL  -- UPR-1667
) IS
   --
   c_one_second CONSTANT NUMBER := 1/86400;

--
-- Massiivi olemasolev rida (susg, sety järgi) on muudetud mitmerealiseks vastavalt susg-le
-- eraldatud paketile:
-- Susg'i sety pakettide lõikes antud ajavahemiku jooksul, arvestades eraldi hinnatud ja
-- hindamata ajavahemikke.
-- Uued väljad: in_sept_type_code ja package_category. Start_date ja end_date TRUNC ära võetud.
-- 1. Paketis antud ajavahemikul HINNATUD teenustel: antud ajavahemikku kuuluvad start_date ja
-- end_date eraldi igas paketis in_sept_type_code, tunnusena sept_type_code is null.
-- 2. Paketis antud ajavahemikul HINDAMATA teenustel: antud ajavahemikku kuuluvad start_date
-- ja end_date eraldi igas paketis in_sept_type_code, tunnusena sept_type_code = in_sept_type_code.
--
--
-- 1. Maksa teenus pakettides täielikult (HINNATUD teenused)
-- 2. Maksa teenus pakettides osaliselt (kusagil antud ajavahemiku sees muutub HINNATUD
-- teenus HINDAMATA teenuseks)
-- 3. Tasuta teenusega pakett/paketiosa
-- NB!!! Asendatud: ||'  AND susg.suac_ref_num BETWEEN '||To_Char(p_maac_ref_num)||' AND '
--         ||To_Char(p_maac_ref_num + 999)||' '
-- Uus palju kiirem: ||'  AND susg.suac_ref_num IN (SELECT ref_num FROM accounts
--          WHERE maac_ref_num = '||To_Char(p_maac_ref_num)||') '
--

   CURSOR c_serv IS
      SELECT serv.susg_ref_num
            ,serv.sety_ref_num
            ,Greatest(supa.start_date, p_invo_start_date) start_date
            ,Trunc(Least(Nvl(supa.end_date, p_invo_end_date), p_invo_end_date))+1-c_one_second end_date -- 23:59:59
            ,susg.nety_type_code
            ,supa.sept_type_code
            ,sept.category
      FROM   serv_package_types   sept
            ,subs_packages        supa
            ,services             serv
            ,subs_serv_groups     susg
      WHERE  supa.sept_type_code = sept.type_code
      AND    supa.gsm_susg_ref_num = susg.ref_num
      AND    supa.start_date <= p_invo_end_date
      AND    Nvl(supa.end_date, p_invo_end_date) >= p_invo_start_date
      AND    susg.ref_num = serv.susg_ref_num
      AND   (p_susg_ref_num IS NULL OR susg.ref_num = p_susg_ref_num)
      AND EXISTS (SELECT 1
                  FROM   price_lists
                  WHERE  sety_ref_num = serv.sety_ref_num
                  AND    regular_charge = 'Y'
                  AND    pro_rata = 'Y'
                  AND    once_off = 'N'
                  AND nvl(daily_charge, 'N') = 'N') -- DOBAS-1622
      AND    susg.suac_ref_num IN (SELECT ref_num
                                   FROM   accounts
                                   WHERE  maac_ref_num = p_maac_ref_num)
   ;
   --
   l_susg_ref_num_tab   t_ref_num;
   l_sety_ref_num_tab   t_ref_num;
   l_start_date_tab     t_date;
   l_end_date_tab       t_date;
   l_nety_type_code_tab t_nety;
   l_sept_type_code_tab t_sept;
   l_category_tab       t_category;
   --
   l_idx                NUMBER;
BEGIN
   OPEN  c_serv;
   FETCH c_serv BULK COLLECT INTO l_susg_ref_num_tab
                                 ,l_sety_ref_num_tab
                                 ,l_start_date_tab
                                 ,l_end_date_tab
                                 ,l_nety_type_code_tab
                                 ,l_sept_type_code_tab
                                 ,l_category_tab;
   CLOSE c_serv;
   --
   l_idx := l_susg_ref_num_tab.First;
   WHILE l_idx IS NOT NULL LOOP
      p_susg_serv_tab(l_idx).susg_ref_num   := l_susg_ref_num_tab(l_idx);
      p_susg_serv_tab(l_idx).sety_ref_num   := l_sety_ref_num_tab(l_idx);
      p_susg_serv_tab(l_idx).start_date     := l_start_date_tab(l_idx);
      p_susg_serv_tab(l_idx).end_date       := l_end_date_tab(l_idx);
      p_susg_serv_tab(l_idx).in_sept_type_code  := l_sept_type_code_tab(l_idx);  -- UPR-1649
      p_susg_serv_tab(l_idx).package_category := l_category_tab(l_idx);  -- UPR-1649
      p_susg_serv_tab(l_idx).nety_type_code := l_nety_type_code_tab(l_idx);
      --
      l_idx := l_susg_ref_num_tab.Next(l_idx);
   END LOOP;
END Get_susg_SERV;
--
END GET_SUSG_SERV;
/

