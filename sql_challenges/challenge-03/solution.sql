Find the longest time that an employee has been at the studio 
SELECT MAX(Years_employed) FROM employees;

For each role, find the average number of years employed by employees in that role
SELECT role, AVG(years_employed) as Avg_years FROM employees GROUP BY role;

Find the total number of employee years worked in each building 
SELECT building, SUM(Years_employed) as sum_years FROM employees GROUP BY building

Find the number of Artists in the studio (without a HAVING clause) 
SELECT role, COUNT(*) as NumArtists FROM employees WHERE role = "Artist";

Find the number of Employees of each role in the studio
SELECT role, COUNT(*)FROM all_employees BY role;

Find the total number of years employed by all Engineers
SELECT SUM(Years_employed) from employees WHERE role ="Engineer"


Complete the following query to return the:

Number of different shapes
The standard deviation (stddev) of the unique weights
select count (distinct shape) number_of_shapes,
       stddev(distinct weight) distinct_weight_stddev
from   bricks;

Complete the following query to return the total weight for each shape stored in the bricks table:
select shape, sum(weight) as shape_weight
from   bricks
group by shape;

Complete the following query to find the shapes which have a total weight less than four:
select shape, sum(weight)
from bricks
where weight < 4
group by shape;