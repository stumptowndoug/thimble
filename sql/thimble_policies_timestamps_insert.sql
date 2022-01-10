insert into thimble.policies_timestamps
(
policy_id,
coverage_start_t,
coverage_end_t,
create_date_t,
cancel_date_t
)
(
select
a.policy_id,
to_timestamp(a.coverage_start_timestamp) at time zone 'UTC' as coverage_start_t,
to_timestamp(a.coverage_end_timestamp) at time zone 'UTC' as coverage_end_t,
date_trunc('second',a.create_date_time) as create_date_t,
date_trunc('second',A.cancel_date_time) as cancel_date_t

from
thimble.policies a
);