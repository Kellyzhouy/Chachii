/*
********************************************************************************************************************************************************
ANZ Smart Choice Super Employer Membership Listing Report

This report will produce an extract of all members that are linked or were previously linked to an Employer, which have an active member account status.
Members with an inactive account are excluded.

Components, Investment and Beneficiary details for the member have been included.

The Employer ID must be provided. Please update this in the Report Parameters section below.
Execution time is approximately 1 minute and may vary due to size of query.

If TFN details are to be displayed - need to set the variable @tfn_details_required_flag to 'Y'

History
Date          Author                Description
----          ------                -----------
01/01/2014    John Bontzouklis      Initial Writing
14/08/2014    Carl James            Add Investment, Component and Beneficiary details.
18/08/2014    Carl James            Add decrypt TFN details
21/10/2014    Carl James	    Updates the SQL when getting MySuper details - Use member_account_id instead of entity_id
16/07/2019	  Riken Pandejee		Updated script to be compatbile with SQL Server

*********************************************************************************************************************************************************
*/

--set quoted_identifier off


declare	@effective_date			datetime,
	@personal_conts_start_date	datetime,
	@dt_start_financial_yr		datetime,
	@return_code            	int,
	@employer_id 			int,
	@max_macc_id			int,
	@min_macc_id			int,
	@next_macc_id			int,
	@tfn_details_required_flag	char(1)

declare @include_pending 		char(1),
        @emp_refundable 		char(1),
        @exclude_trans_id 		int,
        @can_apportion 			char(1),
        @include_sequence_0 		char(1),
        @include_non_liquid 		char(1),
        @component_id 			int,
        @party_balance 			decimal(18,2)

declare @preserved_amount 		decimal(18,2),
        @restricted_amount 		decimal(18,2),
        @unrestricted_amount 		decimal(18,2)

declare @sEncryptedTFN 			varchar(11),
        @iLengthTFN 			integer,
	@iCount 			integer,
	@iValue 			integer,
	@iNewValue 			integer,
	@sMemberTFN 			varchar(11),
	@tfn_flag			varchar(20),
	@c_new_value            	char(1),
	@c_value                        char(1)

/****************************************************************/
/* Initialise local variables					*/
/****************************************************************/

--Report Parameters

set @employer_id = 100135 -- Citi --Update Employer Group ID here!

--End Report Parameters


set @tfn_details_required_flag = 'N' -- if tfn details are required, that is decrypted..set to 'Y'



-- initialise the static local variables

set @effective_date = getdate()
set @personal_conts_start_date = '25 Nov 2013'  --dont change this


set @include_pending = 'N'
set @emp_refundable = 'A'
set @exclude_trans_id = 0
set @can_apportion = 'Y'
set @include_sequence_0 = 'Y'
set @include_non_liquid = 'Y'


/****************************************************************/
/* Create Temp Tables						*/
/****************************************************************/


create table #tmp_member_details (
	    	employer_id			integer not null,
		employer_name			varchar(80),
		employer_group			varchar(80) null,
		ANZ_BSB_Account      varchar(20) null,
		account_status			varchar(10) null,
		employment_status		varchar(10) null,
		legacy_system			varchar(20) null,
		legacy_id			   varchar(20) null,
		mail_exclusion_flag		char(1) null,
		mysuper_member_flag		char(1) null,
		eligible_service_date		varchar(10) null,
		member_account_id	        integer not null,
		salutation			varchar(80) null,
		surname				varchar(80) null,
		given_names			varchar(80) null,
		gender				char(10) null,
		age				integer null,
		home_phone_number		varchar(40) null,
		work_phone_number		varchar(40) null,
		mobile_number			varchar(40) null,
		fax_number			varchar(40) null,
		email_address			varchar(60) null,
		residential_property_name	varchar(120) null,
		reisdential_street_1		varchar(40) null,
		residential_street_2		varchar(40) null,
		residential_suburb		varchar(40) null,
		residential_statecode		varchar(10) null,
		residential_postcode		varchar(10) null,
		residential_country		varchar(10) null,
		mailing_property_name		varchar(120) null,
		mailing_street_1		varchar(120) null,
		mailing_street_2		varchar(120) null,
		mailing_suburb			varchar(40) null,
		mailing_statecode		varchar(10) null,
		mailing_postcode		varchar(10) null,
		mailing_country			varchar(10) null,
		birth_date			varchar(10) null,
		adviser_account_id		integer null,
		adviser				varchar(80) null,
		adviser_effective_date	        varchar(10) null,
		date_joined_fund		varchar(10) null,
		earliest_fund_start_date	varchar(10) null,
		lost_member_flag		varchar(20) null,
		date_lostmember_reported	varchar(10) null,
		employer_reference		varchar(20) null,
		employer_site			varchar(40) null,
		date_joined_employer		varchar(10) null,
		date_left_employer		varchar(10) null,
		salary				decimal(20,2)  null,
		tfn_flag			varchar(20) null,
		at_work_flag			char(01) null,
		account_balance			decimal(20,2)  null,
		insurance_cover_id		integer null,
		insurer				varchar(60) null,
		insurance_type			varchar(40) null,
		insurance_subtype		varchar(40) null,
		cover_start_date		varchar(10) null,
		calculated_sum_insured		decimal(20,2)  null,
		actual_sum_insured		decimal(20,2)  null,
		medical_loading			decimal(6,2)  null,
		gross_premium			decimal(20,2)  null,
		underwriting_status		varchar(40) null,
		forward_uw_amount		decimal(20,2)  null,
		forward_uw_date			varchar(10) null
	        )


create table #tempBalances (
        	member_account_id       	integer         not null,
        	portfolio_id            	integer         not null,
        	price_as_at_date        	datetime        not null,
        	include_pending         	char(1)         default 'N',
        	include_non_liquid      	char(1)         default 'Y',
        	confirmed_flag          	char(1)         default 'N',
        	exclude_trans_id        	integer         default 0,
        	row_status              	char(1)         default 'O',
        	exception_message       	varchar(255)    null,
        	avc_amount_colname      	decimal(20,6)   null,
        	avc_units_colname       	decimal(20,6)   null
        	)


create table #tmp_member_invest_details (
		member_account_id		integer,
	    	employer_id			integer        null,
		legacy_id			varchar(20)    null,
		account_status			varchar(10)    null,
		employment_status		varchar(10)    null,
		portfolio_id			integer	       null,
		portfolio_name			varchar(80)    null,
		investment_percent		decimal(20,2)  null,
		balance             		decimal(18, 2) null,
		unit_bal            		decimal(18, 6) null
		)


create table #tmp_beneficiary_details (
		member_account_id		integer,
	    	employer_id			integer        null,
		legacy_id			varchar(20)    null,
		account_status			varchar(10)    null,
		employment_status		varchar(10)    null,
		beneficiary_name		varchar(80)    null,
		beneficiary_percent		decimal(10,2)  null,
		binding_nomination_date		varchar(10)    null,
		binding_nomination_expiry_date	varchar(10)    null,
		binding_nomination_revoke_date	varchar(10)    null
		)


create table #component_balances (
		component_id			int not null,
		taxable_balance			decimal(12,2) not null,
		non_taxable_balance		decimal(12,2) not null,
		contribution_source_code	char(1) )


create table #tmp_member_comp_balances (
		member_account_id		integer,
	    	employer_id			integer       null,
		legacy_id			varchar(20)   null,
		account_status			varchar(10)   null,
		employment_status		varchar(10)   null,
		taxable_balance			decimal(12,2) null,
		non_taxable_balance		decimal(12,2) null,
		preserved_amount 		decimal(12,2) null,
        	restricted_amount 		decimal(12,2) null,
        	unrestricted_amount 		decimal(12,2) null)


create table #tmp_contributions (
		member_account_id		integer,
		personal_conts_prev_fin_yr	decimal(12,2) null,
		personal_conts_curr_fin_yr	decimal(12,2) null
		)


create table #tmp_tfn_details (
		member_account_id		integer,
	    	employer_id			integer        null,
		legacy_id			varchar(20)    null,
		account_status			varchar(10)    null,
		employment_status		varchar(10)    null,
		tfn_flag			varchar(20)    null,
		tax_file_number 		varchar(11)    null,
		decrypt_tax_file_number 	varchar(11)    null
		)

/****************************************************************/
/* Populate Temp Tables						*/
/****************************************************************/

--Extraction Query
insert into #tmp_member_details
select  er.employer_id,
	employer_name = erent.name,
	employer_group = eg.name,
	ANZ_BSB_Account = left(per.external_reference,20),
	account_status = case ma.status when 'A' then 'Active' when 'I' then 'Inactive' else '' end,
	employment_status = case when ed.end_date is null then 'Linked' else 'Delinked' end,
	legacy_system = left(perleg.external_system,20),
	legacy_id = left(perleg.external_reference,20),
	mail_exclusion_flag = left(isnull(pmail.attribute_value,''),1),
	mysuper_member_flag = left((case when ((select count(1) from party_attribute
			            where party_id = ma.member_account_id
			            and party_type_id = 1
			            and attribute_id in (select attribute_id from attribute
                     			                 where description = 'Division')
					                 and attribute_value = 'My Super') > 0) then 'Y' else 'N' end),1),
	eligible_service_date = convert(varchar,ma.earliest_fund_start_date,103),
	ma.member_account_id,
	maent.salutation,
	surname = maent.name,
	maent.given_names,
	gender = (case maent.gender when 'F' then 'Female' else 'Male' end),
	age = datediff(yy, maent.birth_date, getdate()),
	home_phone_number = isnull(maent.home_phone_number,''),
	work_phone_number = isnull(maent.work_phone_number,''),
	mobile_number = isnull(maent.mobile_number,''),
	fax_number = isnull(maent.fax_number,''),
	email_address = isnull(maent.email_address,''),
	residential_property_name = isnull(addp.property_name,''),
	reisdential_street_1 = isnull(addp.street,''),
	residential_street_2 = isnull(addp.street2,''),
	residential_suburb = isnull(addp.suburb,''),
	residential_statecode = isnull(addp.statecode,''),
	residential_postcode = isnull(addp.postcode,''),
	residential_country = isnull(addp.countrycode,''),
	mailing_property_name = isnull(addm.property_name,''),
	mailing_street_1 = isnull(addm.street,''),
	mailing_street_2 = isnull(addm.street2,''),
	mailing_suburb = isnull(addm.suburb,''),
	mailing_statecode = isnull(addm.statecode,''),
	mailing_postcode = isnull(addm.postcode,''),
	mailing_country = isnull(addm.countrycode,''),
	birth_date = convert(varchar,maent.birth_date,103),
	ma.adviser_account_id,
	adviser = aaent.name,
	adviser_effective_date = convert(varchar,ma.adviser_effective_datetime,103),
	date_joined_fund = convert(varchar,ma.fund_start_date,103),
	earliest_fund_start_date = convert(varchar,ma.earliest_fund_start_date,103),
	lost_member_flag = (case ma.lost_member_flag when 'L' then 'Returned Mail' else '' end),
	date_lostmember_reported = isnull(convert(varchar,ma.date_lostmember_reported,103),''),
	left(isnull(ed.employer_reference,''),20),
	employer_site = left(isnull(scent.name,''),40),
	date_joined_employer = convert(varchar,ed.start_date,103),
	date_left_employer = isnull(convert(varchar,ed.end_date,103),''),
	ed.salary,
	tfn_flag = (case maent.tfn_flag when 'S' then 'Supplied' when 'D' then 'Declined to Supply' when 'I' then 'Invalid' when 'N' then 'Not Supplied' else '' end),
	ed.at_work_flag,
	account_balance = isnull(mbv.balance,0),
	ic.insurance_cover_id,
	insurer = isnull(irent.name,''),
	insurance_type = isnull(ity.name,''),
	insurance_subtype = isnull(ist.name,''),
	cover_start_date = convert(varchar,ic.start_date,103),
	ic.calculated_sum_insured,
	ic.actual_sum_insured,
	medical_loading = (case when ic.medical_loading > 0 then ic.medical_loading else 0 end),
	gross_premium = ic.super_premium,
	underwriting_status = case ic.underwriting_status when 'N' then 'Not Required' when 'R' then 'Required' when 'U' then 'Underwritten' else '' end,
	ic.forward_uw_amount,
	forward_uw_date = convert(varchar,ic.forward_uw_date,103)
from employee_details ed
join member_account ma              on ma.member_account_id     = ed.member_account_id  and ma.status = 'A'
join entity maent                   on maent.entity_id          = ma.entity_id
left join address addp              on addp.entity_id           = maent.entity_id       and addp.address_type = 'A'
left join address addm              on addm.entity_id           = maent.entity_id       and addm.address_type = 'P'
join party_external_reference per   on per.party_id             = ma.member_account_id  and per.party_type_id = 1 and per.external_system = 'Client Acc'
join employer_group eg              on eg.employer_group_id     = ed.employer_group_id
join employer er                    on er.employer_id           = eg.employer_id
join entity erent                   on erent.entity_id          = er.entity_id
join adviser_account aa             on aa.adviser_account_id    = ma.adviser_account_id
join entity aaent                   on aaent.entity_id          = aa.entity_id
join macc_balance_view mbv          on mbv.member_account_id    = ed.member_account_id
left join site_code sc              on sc.site_code_id          = ed.site_code_id       and sc.employer_id = eg.employer_id
left join entity scent              on scent.entity_id          = sc.entity_id
left join insurance_cover ic        on ic.member_account_id     = ma.member_account_id  and ic.status = 'A'
left join insurance_subtype ist     on ist.insurance_subtype_id = ic.insurance_subtype_id
left join insurance_type ity        on ity.insurance_type_id    = ist.insurance_type_id
left join insurer ir                on ir.insurer_id            = ity.insurer_id
left join entity irent              on irent.entity_id          = ir.entity_id
left join party_attribute pmail     on pmail.party_id           = ma.member_account_id  and pmail.party_type_id = 1 and pmail.attribute_id = 67
left join party_external_reference perleg on perleg.party_id    = ma.member_account_id  and perleg.party_type_id = 1 and perleg.external_system IN('ASA Id','CorpSup Id','Integra Id','SSA Id')
where er.employer_id = @employer_id
--and ma.member_account_id in ( 10248654, 10249282, 10249340, 10248688,10330971 )
order by employer_group, member_account_id, insurance_type


/****************************************************************/
/* Populate and get Balances					*/
/****************************************************************/

insert into #tempBalances (member_account_id,portfolio_id,price_as_at_date)
select distinct tmpm.member_account_id,
		mai.portfolio_id,
        @effective_date
from   #tmp_member_details tmpm
join   member_account_investment mai on mai.member_account_id = tmpm.member_account_id


exec sp_dtbl_balance_portfolio_macc '#tempBalances', 'B','avc_amount_colname',  'avc_units_colname'


/****************************************************************/
/* Populate Portfolio Investments Details			*/
/****************************************************************/

insert into #tmp_member_invest_details
		(member_account_id,
		 employer_id,
		 legacy_id,
		 account_status,
	         employment_status,
		 portfolio_id,
		 portfolio_name,
		 investment_percent,
		 balance,
		 unit_bal)
select  	tmpb.member_account_id,
		employer_id = (select max(tmpm.employer_id) from #tmp_member_details tmpm where tmpm.member_account_id = tmpb.member_account_id),
		legacy_id = (select max(tmpm.legacy_id) from #tmp_member_details tmpm where tmpm.member_account_id = tmpb.member_account_id),
		account_status = (select (case ma.status when 'A' then 'Active' when 'I' then 'Inactive' else '' end)
				  from member_account ma
				  where ma.member_account_id = tmpb.member_account_id ),
	        employment_status = (select min(tmpm.employment_status) from #tmp_member_details tmpm
				     where tmpm.member_account_id = tmpb.member_account_id),
		tmpb.portfolio_id,
		pt.name,
        	investment_percent = (select mai.investment_percent
				      from member_account_investment mai
                              	      where mai.member_account_id = tmpb.member_account_id
                              	      and mai.portfolio_id = tmpb.portfolio_id),
		tmpb.avc_amount_colname,
		tmpb.avc_units_colname
from   #tempBalances tmpb
join   portfolio pt on pt.portfolio_id = tmpb.portfolio_id



/****************************************************************/
/* Populate Beneficiary Details					*/
/****************************************************************/

insert into #tmp_beneficiary_details
		(member_account_id,
		 employer_id,
		 legacy_id,
		 account_status,
		 employment_status,
		 beneficiary_name,
		 beneficiary_percent,
		 binding_nomination_date,
		 binding_nomination_expiry_date,
		 binding_nomination_revoke_date)
select distinct tmpm.member_account_id,
		tmpm.employer_id,
		tmpm.legacy_id,
		tmpm.account_status,
		tmpm.employment_status,
		b.name,
		b.[percent],
		convert(varchar,b.binding_nomination_date,103),
		convert(varchar,b.binding_nomination_expiry_date,103),
		convert(varchar,b.binding_nomination_revoke_date,103)
from   #tmp_member_details tmpm
join   beneficiary b on b.member_account_id = tmpm.member_account_id



/****************************************************************/
/* Populate Component Details					*/
/****************************************************************/

insert into #tmp_member_comp_balances (member_account_id,employer_id,legacy_id,account_status,employment_status,taxable_balance,non_taxable_balance,preserved_amount,restricted_amount,unrestricted_amount)
select distinct tmpm.member_account_id,tmpm.employer_id,tmpm.legacy_id,'','',0,0,0,0,0
from   #tmp_member_details tmpm

select @min_macc_id = min(tmpmcb.member_account_id)
from   #tmp_member_comp_balances tmpmcb

select @max_macc_id = max(tmpmcb.member_account_id)
from   #tmp_member_comp_balances tmpmcb

select @next_macc_id = @min_macc_id

while @next_macc_id <= @max_macc_id
begin
	select @return_code 		= 0
	select @preserved_amount 	= 0
	select @restricted_amount 	= 0
	select @unrestricted_amount 	= 0

	-- get the component balances which will be stored into a temp table
	exec @return_code = sp_tbl_balance_component @next_macc_id,
                                              	     @effective_date,
                                              	     @include_pending,
                                              	     @emp_refundable,
                                              	     @exclude_trans_id,
                                              	     @can_apportion,
                                              	     @include_sequence_0,
                                              	     @include_non_liquid,
                                              	     @component_id,
                                              	     @party_balance


	-- get the preserved, restricted and unrestricted amounts
   	exec @return_code = sp_out_pres_balance_from_cryst
						    @next_macc_id,
                                                    @effective_date,
                                                    @include_pending,
                                                    @exclude_trans_id,
                                                    @include_non_liquid,
                                                    @party_balance,
                                                    @preserved_amount OUT,
                                                    @restricted_amount OUT,
                                                    @unrestricted_amount OUT



	update #tmp_member_comp_balances set taxable_balance 	 = (select sum(taxable_balance) from #component_balances),
					     non_taxable_balance = (select sum(non_taxable_balance) from #component_balances),
					     preserved_amount	 = @preserved_amount,
					     restricted_amount   = @restricted_amount,
					     unrestricted_amount = @unrestricted_amount,
					     account_status      = (select (case ma.status when 'A' then 'Active' when 'I' then 'Inactive' else '' end)
				  				    from member_account ma
				  				    where ma.member_account_id =  @next_macc_id ),
					     employment_status   =  (select min(tmpm.employment_status) from #tmp_member_details tmpm
				     				     where tmpm.member_account_id = @next_macc_id)
	where member_account_id = @next_macc_id

	truncate table #component_balances

    	if @next_macc_id < @max_macc_id
	begin
        	select @next_macc_id = min(member_account_id)
        	from #tmp_member_comp_balances
       		where member_account_id > @next_macc_id
	end
    	else
        	select @next_macc_id = @next_macc_id + 1


end



/****************************************************************/
/* Populate Personal Contribution Details			*/
/****************************************************************/

/* Determine start of this financial year */

if datepart(Month, (getdate())) > 6
Begin
	select @dt_start_financial_yr = CONVERT(datetime,CONVERT(char(4),DATEPART(yy,getdate()))+'0701')
end

/* Populate table #tmp_contributions to start with and then determine the personal contributions (last and current financial yr) */

insert into #tmp_contributions
select distinct tmpm.member_account_id,0,0
from   #tmp_member_details tmpm


update #tmp_contributions set personal_conts_prev_fin_yr = (select isnull(sum(amount),0)
							   from member_account_transaction macctran,
							        system_parameters sysp
							   where macctran.member_account_id = tmpconts.member_account_id
							   and macctran.transaction_type_id = sysp.mem_cont_ttype_id
							   and macctran.status = 'A'
							   and macctran.effective_datetime >= @personal_conts_start_date
							   and macctran.effective_datetime < @dt_start_financial_yr),
			      personal_conts_curr_fin_yr = (select isnull(sum(amount),0)
							   from member_account_transaction macctran,
							        system_parameters sysp
							   where macctran.member_account_id = tmpconts.member_account_id
							   and macctran.transaction_type_id = sysp.mem_cont_ttype_id
							   and macctran.status = 'A'
							   and macctran.effective_datetime >= @dt_start_financial_yr
							   and macctran.effective_datetime < getdate() )

from #tmp_contributions tmpconts


/****************************************************************/
/* Populate TFN Details						*/
/****************************************************************/


/* If TFN details have been request - then go and decrypt */

if @tfn_details_required_flag = 'Y'
begin
	/* first get the members encrypted TFN */
	insert into #tmp_tfn_details
	       		(member_account_id,
			employer_id,
			legacy_id,
			account_status,
			employment_status,
			tfn_flag,
			tax_file_number,
			decrypt_tax_file_number)
	select distinct tmpm.member_account_id,
			tmpm.employer_id,
			tmpm.legacy_id,
			tmpm.account_status,
			tmpm.employment_status,
	        	ent.tfn_flag,
			IsNull(ent.tax_file_number, ''),
			''
	from   #tmp_member_details tmpm
	join   member_account mem on mem.member_account_id = tmpm.member_account_id
	join   entity ent on ent.entity_id = mem.entity_id


	/* decrypt tfn */

	select @min_macc_id = min(tmpmcb.member_account_id)
	from   #tmp_member_comp_balances tmpmcb

	select @max_macc_id = max(tmpmcb.member_account_id)
	from   #tmp_member_comp_balances tmpmcb

	select @next_macc_id = @min_macc_id

	while @next_macc_id <= @max_macc_id
	begin

		select  @tfn_flag      = tfn_flag,
	       		@sEncryptedTFN = tax_file_number
		from   #tmp_tfn_details
		where  member_account_id = @next_macc_id

        	select @iLengthTFN = isnull(len(@sEncryptedTFN),0)
        	select @iCount = 1
        	select @sMemberTFN = null

        	while (@iCount <= @iLengthTFN)
        	begin

			if @tfn_flag = 'S' -- supplied
			begin
				select @c_value = substring(@sEncryptedTFN, @iCount, 1)
    				select @c_new_value = case when @c_value = 'Ú' then '0'
                               		   	   	   when @c_value = 'Û' then '1'
                               		  	   	   when @c_value = 'Ü' then '2'
                               		   	   	   when @c_value = 'Ý' then '3'
                               		   	   	   when @c_value = 'Þ' then '4'
                               		   	   	   when @c_value = 'ß' then '5'
                               		   	   	   when @c_value = 'à' then '6'
                               		   	   	   when @c_value = 'á' then '7'
                               		   	   	   when @c_value = 'â' then '8'
                               		   	   	   when @c_value = 'ã' then '9'
                          	      	      	       end

    				select @sMemberTFN = @sMemberTFN + @c_new_value

                		select @iCount = @iCount + 1
			end
			else
			begin
				/* TFN has not been tagged as Supplied, thus set to blank */
				select @sMemberTFN = ''
	                	select @iCount     = @iLengthTFN + 1
			end

        	end -- inner while


		update #tmp_tfn_details set decrypt_tax_file_number = @sMemberTFN
		where member_account_id = @next_macc_id


    		if @next_macc_id < @max_macc_id
		begin
        		select @next_macc_id = min(member_account_id)
        		from #tmp_member_comp_balances
       			where member_account_id > @next_macc_id
		end
    		else
        		select @next_macc_id = @next_macc_id + 1

	end

end /* if tfn details are required */


/****************************************************************/
/* Output Results						*/
/****************************************************************/

/***********************************/
/* 1) Basic Member Details 	   */
/***********************************/

select * from #tmp_member_details


/***********************************/
/* 2) Portfolio Investment Details */
/***********************************/

select  employer_id,
        legacy_id = isnull(legacy_id,''),
 	member_account_id,
	account_status,
        employment_status,
	portfolio_id,
	portfolio_name,
	investment_percent,
	balance	 as portfolio_balance,
	unit_bal as portfolio_units
from #tmp_member_invest_details
order by member_account_id


/***********************************/
/* 3) Component Details 	   */
/***********************************/

select employer_id,
       legacy_id = isnull(legacy_id,''),
       member_account_id,
       account_status,
       employment_status,
       taxable_balance = isnull(taxable_balance,0),
       tax_free_balance = isnull(non_taxable_balance,0),
       preserved_amount,
       restricted_amount,
       unrestricted_amount,
       total_account_balance = isnull(taxable_balance,0) + isnull(non_taxable_balance,0),
       personal_conts_prev_fin_yr = (select personal_conts_prev_fin_yr
				     from #tmp_contributions
				     where member_account_id = #tmp_member_comp_balances.member_account_id),
       personal_conts_curr_fin_yr = (select personal_conts_curr_fin_yr
				     from #tmp_contributions
				     where member_account_id = #tmp_member_comp_balances.member_account_id)
from #tmp_member_comp_balances
order by member_account_id

/***********************************/
/* 4) Beneficiary Details          */
/***********************************/

select   employer_id,
	 legacy_id = isnull(legacy_id,''),
	 member_account_id,
	 account_status,
         employment_status,
	 beneficiary_name,
	 beneficiary_percent,
	 binding_nomination_date = isnull(binding_nomination_date,''),
	 binding_nomination_expiry_date = isnull(binding_nomination_expiry_date,''),
	 binding_nomination_revoke_date = isnull(binding_nomination_revoke_date,'')
from #tmp_beneficiary_details
order by member_account_id

/***********************************/
/* 4) TFN Details                  */
/***********************************/

/* if TFN details are to be displayed */

if @tfn_details_required_flag = 'Y'
begin

	select  employer_id,
	 	legacy_id = isnull(legacy_id,''),
	 	member_account_id,
	 	account_status,
         	employment_status,
	 	decrypted_tfn = isnull(decrypt_tax_file_number,'')
	from #tmp_tfn_details

end

/****************************************************************/
/* Drop Tables							*/
/****************************************************************/

drop table #tmp_member_details
drop table #tmp_member_invest_details
drop table #tempBalances
drop table #tmp_beneficiary_details
drop table #component_balances
drop table #tmp_member_comp_balances
drop table #tmp_contributions
drop table #tmp_tfn_details

go