CREATE OR REPLACE PROCEDURE TBCIS.iTemp_EMT_HINNAKIRI as


--declare


--- erihind
Cursor c_ficv  is
select f.type_code,f.billing_selector,f.taty_type_code,
v.charge_value,v.sety_ref_num,v.sepa_ref_num,v.sepv_ref_num,v.end_date,v.sept_type_code
 from fixed_charge_values v,fixed_charge_item_types f
where  v.fcit_charge_code=f.type_code
and pro_rata='N' and regular_charge='Y' and once_off='N'
and v.sety_ref_num is not null
and f.package_category is not null
and nvl(end_date, sysdate+1)>=sysdate
and not exists (select 1 from service_param_values where ref_num=v.sepv_ref_num
and end_date is not null)   


;

--- 
-- kategooria põhihind

Cursor c_fcit_pack is
select p.charge_value,p.sety_ref_num,p.sepa_ref_num,p.sepv_ref_num,p.end_date,
f.type_code,f.billing_selector,f.taty_type_code,f.package_category
from fixed_charge_item_types f, price_lists p
 where f.pro_rata='N'and   f.once_off='N' and f.regular_charge='Y'
   and f.package_category is not null
   and p.pro_rata='N'and   p.once_off='N' and p.regular_charge='Y'
   and p.sety_ref_num=f.sety_ref_num
   and p.package_category=f.package_category
   and nvl(p.end_date, sysdate+1)>=sysdate-1
   and not exists (select 1 from service_param_values where ref_num=p.sepv_ref_num
and end_date is not null)   
   
   ;
   
----
-- puhas põhihind
Cursor c_fcit is
select p.charge_value,p.sety_ref_num,p.sepa_ref_num,p.sepv_ref_num,p.end_date,
f.type_code,f.billing_selector,f.taty_type_code,f.package_category
from fixed_charge_item_types f, price_lists p
 where f.pro_rata='N'and   f.once_off='N' and f.regular_charge='Y'
   and f.package_category is not null
   and p.pro_rata='N'and   p.once_off='N' and p.regular_charge='Y'
   and p.sety_ref_num=f.sety_ref_num
   and p.package_category is NULL
   and nvl(p.package_category,f.package_category)=f.package_category
   and nvl(p.end_date, sysdate+1)>=sysdate
   and not exists (select 1 from service_param_values where ref_num=p.sepv_ref_num
and end_date is not null)   
   
   ;

cursor c_olemas (p_sept varchar2,p_sety number,p_sepa number, p_sepv number) is
select 1 from tbcis.iemt_bill_price_list 
  where end_date is null
  and SEPT_TYPE_CODE = p_sept 
  and nvl(sepv_ref_num,0)=nvl(p_sepv,0) 
  and nvl(sepa_ref_num,0)=nvl(p_sepa,0) 
  and fcty_type='RCH'
  and sety_ref_num=p_sety;


cursor c_sept(p_cat varchar2) is
select type_code from serv_package_types
where category=p_cat
and end_date is null; 
   
l_olemas  number;

begin
--DBMS_OUTPUT.enable( 1000000 );


for r in c_ficv loop

l_olemas:=0;

Open   c_olemas(r.sept_type_code,r.sety_ref_num,r.sepa_ref_num,r.sepv_ref_num);
Fetch  c_olemas into l_olemas;
Close  c_olemas;

  if l_olemas=1 then
  --DBMS_OUTPUT.Put_Line(' eri on ' ||r.sept_type_code ||' '||to_char(r.sety_ref_num)); 
  null;
  else
--DBMS_OUTPUT.Put_Line(' eri pole ' ||r.sept_type_code ||' '||to_char(r.sepv_ref_num)||' '||r.type_code); 

       INSERT
        INTO tbcis.iemt_bill_price_list (fcty_type
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
                                 ,curr_code
                                 )
      VALUES ('RCH'
             ,'Mobiili teenused'
             ,'Erihind'
             ,r.type_code
             ,r.taty_type_code
             ,r.billing_selector
             ,r.charge_value
             ,r.sept_type_code
             ,r.sety_ref_num
             ,r.sepa_ref_num
             ,r.sepv_ref_num
             , trunc(sysdate-1,'mm')
             ,r.end_date
             ,null
             ,decode(r.charge_value,0,'N','Y')
             ,null
             , null
             , 'TBCIS'--sec.get_username
             ,SYSDATE
             ,'EUR'
             );
    
      end if;
             
end loop;

------------------------
-- kategooria põhihind

for r in c_fcit_pack loop

for rr in c_sept(r.package_category) loop

l_olemas:=0;

Open   c_olemas(rr.type_code,r.sety_ref_num,r.sepa_ref_num,r.sepv_ref_num);
Fetch  c_olemas into l_olemas;
Close  c_olemas;

  if l_olemas=1 then
  --DBMS_OUTPUT.Put_Line(' kateg ' ||rr.type_code ||' '||to_char(r.sety_ref_num));  
  null;
  else

--DBMS_OUTPUT.Put_Line(' kateg pole ' ||rr.type_code ||' '||to_char(r.sepv_ref_num)||' '||r.type_code); 



INSERT
        INTO tbcis.iemt_bill_price_list (fcty_type
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
                                 ,curr_code
                                 )
      VALUES ('RCH'
             ,'Mobiili teenused'
             ,'Põhihind'
             ,r.type_code
             ,r.taty_type_code
             ,r.billing_selector
             ,r.charge_value
             ,rr.type_code
             ,r.sety_ref_num
             ,r.sepa_ref_num
             ,r.sepv_ref_num
             , trunc(sysdate-1,'mm')
             ,r.end_date
             ,null
             ,decode(r.charge_value,0,'N','Y')
             ,null
             , null
             , 'TBCIS'--sec.get_username
             ,SYSDATE
             ,'EUR'
             );
      
      end if;
      
end loop;
end loop;

--- puhas põhihind

for r in c_fcit loop

for rr in c_sept(r.package_category) loop


l_olemas:=0;

Open   c_olemas(rr.type_code,r.sety_ref_num,r.sepa_ref_num,r.sepv_ref_num);
Fetch  c_olemas into l_olemas;
Close  c_olemas;

  if l_olemas=1 then
 -- DBMS_OUTPUT.Put_Line(' pohi on ' ||rr.type_code ||' '||to_char(r.sety_ref_num)); 
  null;
  else

--DBMS_OUTPUT.Put_Line(' pohi pole ' ||rr.type_code ||' '||to_char(r.sepv_ref_num)||' '||r.type_code); 

INSERT
        INTO tbcis.iemt_bill_price_list (fcty_type
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
                                 ,curr_code
                                 )
      VALUES ('RCH'
             ,'Mobiili teenused'
             ,'Põhihind'
             ,r.type_code
             ,r.taty_type_code
             ,r.billing_selector
             ,r.charge_value
             ,rr.type_code
             ,r.sety_ref_num
             ,r.sepa_ref_num
             ,r.sepv_ref_num
             , trunc(sysdate-1,'mm')
             ,r.end_date
             ,null
             ,decode(r.charge_value,0,'N','Y')
             ,null
             , null
             , 'TBCIS'--sec.get_username
             ,SYSDATE
             ,'EUR'
             );
            
             
             end if;
end loop;
end loop;


--commit;
end;
/