with policy_series as
(
select
p.policy_id,
p.status,
p.policy_name,
p.plan_name,
p.appkey,
p.coverage_territory,
pt.coverage_start_t,
pt.coverage_end_t,
generate_series(
	date_trunc('month', pt.coverage_start_t),
    pt.coverage_end_t, '1 month'
)::date as coverage_month,
row_number() over(partition by p.policy_id order by generate_series(
	date_trunc('month', pt.coverage_start_t),
    pt.coverage_end_t, '1 month'
)::date) as policy_seq
	

from
thimble.policies p
left join thimble.policies_timestamps pt
	on p.policy_id = pt.policy_id

where
policy_name = 'Monthly Policy'
and p.status NOT IN('declined')
	
order by
1,
9
),


total_new_end_policies as
(
select
*,
1 as total_policies,
case 
	when coverage_month = date_trunc('month', coverage_start_t)
	then 1
	else 0
end as new_policies,
case 
	when coverage_month = date_trunc('month', coverage_end_t)
	then 1
	else 0
end as end_policies
	
from
policy_series
	
where
coverage_month <= (select max(create_date_t) from thimble.policies_timestamps) --remove coverage months past last created record in data
)


select
coverage_month,
plan_name,
sum(total_policies) as total_policies,
lag(sum(total_policies),1) over(partition by plan_name order by coverage_month) as start_policies,
sum(new_policies) as new_policies,
sum(end_policies) as termed_policies,
ROUND(1.00 * (sum(total_policies) - sum(new_policies)) / lag(sum(total_policies),1) over(partition by plan_name order by coverage_month),3) as retention

from
total_new_end_policies

group by
1,
2

order by
2,1