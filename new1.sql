select * from invoice_entries inen, invoices invo
where inen.susg_ref_num = 13791448
and inen.invo_ref_num = invo.ref_num
and salp_fina_year = 2018 and salp_per_num = 10
order by inen.billing_selector, inen.date_created

select * from aj_temp_31
where susg = 7822

select * from aj_temp_2
where susg = 14957408

select * from common_monthly_charges
where susg_ref_num = 14957408

select * from subs_service_parameters
where susg_ref_num = 320125
and sety_ref_num = 5802234

select * from price_lists
where sety_ref_num = 5802234
and sepv_ref_num in (11828, 11830)


select * fr


select * from common_monthly_charges
where susg_ref_num = 15204909


select * from public_contract_data
where end_date >= date '2018-10-01'
and start_date <= date '2018-10-31'
and susg_ref_num = 13791448

where susg_ref_num = 15809868

select * from accounts
where ref_num = 2670779000