# Thimble Take-Home Assignment

## Question 1:
We just launched a new product, called a Business Owners Policy (BOP).  Our CEO wants to better understand customer behavior after launch.  These are his questions:

**What is the ratio of new to repeat customers we’re getting for our BOP sales?**
 * **Answer:** I show 344 total BOP sales (excluding declind status).  313 new, 31 repeat

**For our repeat customers:**
 * How many had an active policy at time of purchase for BOP?
 
   * **Answer:** I show 7 had an active policy at the time of BOP purchase

 * How many were dormant before their BOP purchase?
   * **Answer:** I show 24 dormant before NOP purchase
 * How many retained their non-BOP policy when they purchased BOP?
   * **Answer:** I show 4 retained thier non-BOP policy

For this exercise, provide the code you used to answer these questions.

```SQL
----------------------------------------------------------------
--QUESTION 1 QUERY
----------------------------------------------------------------


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
```

## Question 2:
We sell a monthly product where customers can choose to continue coverage on a monthly basis.  We want to know what % of our monthly customers we’re keeping over each month of their lifetime.

Help us understand this by showing our customer retention rate over each month of their lifetime.  As you work on this, compare the performance of some different customer segmentations or cohorts.  Did you find that any one particular group of customers performs differently than any others?

We’d like to see an accompanying visualization to show your findings, and also the code you used to calculate monthly retention. 

 * **Answer:** I show the retention rates hovers around 85-95%
 
 ![Retention Rate](https://thimble-homework.s3.us-west-2.amazonaws.com/question_2.png)
 
 ```SQL
----------------------------------------------------------------
--QUESTION 2 QUERY
----------------------------------------------------------------


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
sum(total_policies) as total_policies,
lag(sum(total_policies),1) over(order by coverage_month) as start_policies,
sum(new_policies) as new_policies,
sum(end_policies) as termed_policies,
ROUND(1.00 * (sum(total_policies) - sum(new_policies)) / lag(sum(total_policies),1) over(order by coverage_month),3) as retention

from
total_new_end_policies

group by
1
```

**Here is a view of retention rate by appkey.  Interesting to see policies purchased on andriod app have lower retention**
 
 ![Retention Rate - appkey](https://thimble-homework.s3.us-west-2.amazonaws.com/question_2b_appkey.png)
 
 
**Here is a view of retention rate by plan name.
 
 ![Retention Rate - appkey](https://thimble-homework.s3.us-west-2.amazonaws.com/question_2b_plan_name.png)



