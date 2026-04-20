Find the domestic and international sales for each movie
SELECT title, domestic_sales, international_sales
FROM movies
  JOIN boxoffice
    ON movies.id = boxoffice.movie_id
WHERE international_sales > domestic_sales;

Show the sales numbers for each movie that did better internationally rather than domestically 
SELECT title, domestic_sales, international_sales
FROM movies
  JOIN boxoffice
    ON movies.id = boxoffice.movie_id
WHERE international_sales > domestic_sales;


List all the movies by their ratings in descending order 
SELECT title, rating
FROM movies
  JOIN boxoffice
    ON movies.id = boxoffice.movie_id
ORDER BY rating DESC;

Find the list of all buildings that have employees
SELECT DISTINCT building FROM employees;

Find the list of all buildings and their capacity
SELECT Building_name, capacity FROM Building

List all buildings and the distinct employee roles in each building (including empty buildings)
SELECT DISTINCT building_name, role 
FROM buildings 
  LEFT JOIN employees
    ON building_name = building;

Assume you're given two tables containing data about Facebook Pages and their respective likes (as in "Like a Facebook Page").

Write a query to return the IDs of the Facebook pages that have zero likes. The output should be sorted in ascending order based on the page IDs.

SELECT DISTINCT p.page_id FROM pages AS p 
LEFT JOIN page_likes ON p.page_id = page_likes.page_id
WHERE liked_date IS NULL
ORDER BY page_id ASC
