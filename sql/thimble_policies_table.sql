create table thimble.policies
(
policy_id varchar(100),
user_id varchar(100),
carrier_id int,
status varchar(50),
policy_name varchar(100),
plan_name varchar(100),
activity jsonb,
group_info jsonb,
appkey varchar(100),
coverage_territory varchar(50),
coverage_start_timestamp bigint,
coverage_end_timestamp bigint,
create_date_time timestamp,
cancel_date_time timestamp,
is_in_suspend boolean,
is_test smallint,
collected_premium numeric(12,2),
remaining_balance numeric(12,2),
written_premium numeric(12,2)
);