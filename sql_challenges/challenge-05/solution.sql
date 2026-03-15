5 . Try It!
Complete this query to return a list of all the colours in the two tables. Each colour must only appear once:
select colour from my_brick_collection
union 
select colour from your_brick_collection
order by colour; -

select shape from my_brick_collection
union all,
select shape from your_brick_collection
order  by shape;

10 . Try It!
Complete the following query to return a list of all the shapes in my collection not in yours:
select shape from my_brick_collection
minus
select shape from your_brick_collection;

select colour from my_brick_collection
intersect
select colour from your_brick_collection
order  by colour;

