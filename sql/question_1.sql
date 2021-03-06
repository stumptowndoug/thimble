with bop_coverage as
(
select
p.user_id
	
from
thimble.policies p

where
p.is_test IS NULL --remove tests
and p.status NOT IN('declined') --exclude declined policies. I'm assuming these policies did not go into effect but I could be wrong on that assumption
and p.policy_name = 'Business Owners Policy'
	
group by
1
),

non_bop_dates as 
(
select
p.user_id,
min(pt.create_date_t) as min_non_bop_create_dt,
min(pt.coverage_end_t) as min_non_bop_coverage_dt,
max(pt.coverage_end_t) as max_non_bop_coverage_dt,
max(pt.cancel_date_t) as max_non_bop_cancel_dt

from
thimble.policies p
left join thimble.policies_timestamps pt
	on p.policy_id = pt.policy_id

where
p.is_test IS NULL --remove tests
and p.status NOT IN('declined') --exclude declined policies. I'm assuming these policies did not go into effect but I could be wrong on that assumption
and p.policy_name != 'Business Owners Policy'

group by
1
),

bop_summary as
(
select
p.policy_id,
p.user_id,
p.status,
p.policy_name,
pt.create_date_t,
pt.coverage_start_t,
pt.coverage_end_t,
pt.cancel_date_t,
row_number() over(partition by p.user_id order by pt.create_date_t) as purchase_seq,
row_number() over(partition by p.user_id, p.policy_name order by pt.create_date_t) as policy_name_seq

from
thimble.policies p
left join thimble.policies_timestamps pt
	on p.policy_id = pt.policy_id
left join bop_coverage bop
	on p.user_id = bop.user_id

where
p.is_test IS NULL --remove tests
and p.status NOT IN('declined') --exclude declined policies. I'm assuming these policies did not go into effect but I could be wrong on that assumption
and bop.user_id is not null --only include users with bop product

order by
user_id
),

bop_data as
(
select
bs.*,
nbd.*,
case
	when purchase_seq = 1 and policy_name_seq = 1
	then 1
	else 0
end as new_customer,
case
	when purchase_seq > 1 and policy_name_seq = 1
	then 1
	else 0
end as repeat_customer,
case
	when purchase_seq > 1 and policy_name_seq = 1 and max_non_bop_coverage_dt > create_date_t
	then 1
	else 0
end as active_policy_at_purchase,
case
	when purchase_seq > 1 and policy_name_seq = 1 and max_non_bop_coverage_dt < create_date_t
	then 1
	else 0
end as dormant_policy_at_purchase,
case
	when purchase_seq > 1 and policy_name_seq = 1 and max_non_bop_coverage_dt > create_date_t and max_non_bop_cancel_dt IS NULL
	then 1
	when purchase_seq > 1 and policy_name_seq = 1 and max_non_bop_coverage_dt > create_date_t and date(max_non_bop_cancel_dt) != date(max_non_bop_coverage_dt)
	then 1
	else 0
end as retained_non_bop_policy

from
bop_summary bs
left join non_bop_dates nbd
	on bs.user_id = nbd.user_id

where
bs.policy_name = 'Business Owners Policy'

order by
bs.user_id
)

select
sum(new_customer) as new_bop_customers,
sum(repeat_customer) as repeat_bop_customers,
sum(active_policy_at_purchase) as active_non_bop_policy_at_purchase,
sum(dormant_policy_at_purchase) as dormant_non_bop_policy_at_purchase,
sum(retained_non_bop_policy) as retained_non_bop_policy

from
bop_data