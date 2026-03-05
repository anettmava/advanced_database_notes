
select b.*,
       count(*) over (
         partition /* TODO */
       ) bricks_per_shape,
       median ( weight ) over (
         partition /* TODO */
       ) median_weight_per_shape
from   bricks b
order  by shape, weight, brick_id;

SOLUTION:
select b.*,
       count(*) over (
         partition by shape
       ) bricks_per_shape,
       median ( weight ) over (
         partition by shape
       ) median_weight_per_shape
from   bricks b
order  by shape, weight, brick_id;


select b.brick_id, b.weight,
       round ( avg ( weight ) over (
         order /* TODO */
       ), 2 ) running_average_weight
from   bricks b
order  by brick_id;

SOLUTION:
select b.brick_id, b.weight,
       round ( avg ( weight ) over (
         order by brick_id
       ), 2 ) running_average_weight
from   bricks b
order  by brick_id;

select b.*,
       min ( colour ) over (
         order by brick_id
         rows /* TODO */
       ) first_colour_two_prev,
       count (*) over (
         order by weight
         range /* TODO */
       ) count_values_this_and_next
from   bricks b
order  by weight;

SOLUTION:


select b.*,
       min ( colour ) over (
         order by brick_id
         rows between 2 preceding and 1 preceding
       ) first_colour_two_prev,
       count (*) over (
         order by weight
         range between current row and 1 following
       ) count_values_this_and_next
from   bricks b
order  by weight;



Complete the following query to find the rows where

The total weight for the shape
The running weight by brick_id
are both greater than four:

with totals as (
  select b.*,
         sum ( weight ) over (
           /* TODO */
         ) weight_per_shape,
         sum ( weight ) over (
           /* TODO */
         ) running_weight_by_id
  from   bricks b
)
select * from totals
where  /* TODO */
order  by brick_id

with totals as (
  select b.*,
         sum(weight) over (
           partition by shape
         ) weight_per_shape,
         sum(weight) over (
           order by brick_id
         ) running_weight_by_id
  from   bricks b
)
select *
from   totals
where  weight_per_shape > 4
and    running_weight_by_id > 4
order  by brick_id;



As part of an ongoing analysis of salary distribution within the company, your manager has requested a report identifying high earners in each department. A 'high earner' within a department is defined as an employee with a salary ranking among the top three salaries within that department.
You're tasked with identifying these high earners across all departments. Write a query to display the employee's name along with their department name and salary. In case of duplicates, sort the results of department name in ascending order, then by salary in descending order. If multiple employees have the same salary, then order them alphabetically.
SELECT
    d.department_name,
    e.name,
    e.salary
FROM (
    SELECT
        e.*,
        DENSE_RANK() OVER (
            PARTITION BY department_id
            ORDER BY salary DESC
        ) AS salary_rank
    FROM employee e
) e
JOIN department d
    ON e.department_id = d.department_id
WHERE salary_rank <= 3
ORDER BY
    d.department_name ASC,
    e.salary DESC,
    e.name ASC;

