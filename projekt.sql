-- zbaBw5yNnZg8R8L

-- roky -- payroll_year
-- mzdy -- avg_wages
-- odvětví -- branch 
-- cen potravin -- avg_value
-- potraviny -- name

CREATE TABLE t_jindrich_franek_project_SQL_primary_final
SELECT 
	w.*,
	cpc.*,
	v.avg_value
FROM (SELECT 
	cp.payroll_year,
	cp.industry_branch_code,
	cpib.name AS branch,
	round(sum(cp.value)/count(value), 0) AS avarage_wages_czk -- přepočteny  atd
	FROM czechia_payroll cp 
	JOIN	czechia_payroll_industry_branch cpib 
		ON industry_branch_code = cpib.code
		AND cp.value_type_code = 5958
	GROUP BY cp.payroll_year, cpib.name) AS w
JOIN (
	SELECT
		category_code,
		date_from,
		value,
		round(avg(cp2.value), 2) AS avg_value
	FROM czechia_price cp2 
	GROUP BY category_code, YEAR (date_from)) AS v
ON w.payroll_year = YEAR (v.date_from)
JOIN czechia_price_category cpc 
	ON v.category_code = cpc.code 
ORDER BY w.payroll_year, w.industry_branch_code


	
CREATE TABLE	t_jindrich_franek_project_SQL_secondary_final
SELECT 
	c.country,
	e.GDP,
	e.population,
	e.gini,
	e.`year`
FROM countries c 
JOIN economies e 
	ON c.country = e.country 
WHERE c.continent = 'Europe' AND e.year > 2005 AND e.year < 2019


-- Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
SELECT 
	 t.payroll_year,
	 t.branch,
	 t.avarage_wages_czk,
	 t2.avarage_wages_czk AS previous_year_avarage_wages,
	 round(t.avarage_wages_czk - t2.avarage_wages_czk)
FROM t_jindrich_franek_project_sql_primary_final t
JOIN t_jindrich_franek_project_sql_primary_final t2
	ON t.payroll_year = t2.payroll_year + 1 
	AND t.branch = t2.branch 
	AND t.name = t2.name -- zabránění "duplicitních" řádku
GROUP BY t.payroll_year, t.branch 
HAVING  round(t.avarage_wages_czk - t2.avarage_wages_czk) < 0


-- Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?
SELECT 
	payroll_year,
	round(avg(avarage_wages_czk)) AS avg_from_avarage_wages,
	name,
	price_value,
	price_unit,
	avg_value,
	round(round(avg(avarage_wages_czk))/avg_value)  
FROM t_jindrich_franek_project_sql_primary_final t
WHERE (name = 'Mléko polotučné pasterované' OR name = 'Chléb konzumní kmínový') AND payroll_year IN (2006, 2018)
GROUP BY payroll_year, name  



-- Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?
WITH raise_price AS (
	SELECT 
		t.payroll_year, 
		t.name,
		round((t.avg_value - t2.avg_value)/ t2.avg_value *100,2) AS diffrent_year_value
	FROM t_jindrich_franek_project_sql_primary_final t
	JOIN t_jindrich_franek_project_sql_primary_final t2
		ON t.payroll_year = t2.payroll_year + 1  
		AND t.name = t2.name 
	GROUP BY t.name, t.payroll_year)
SELECT 
	*,	
	round(avg(diffrent_year_value),2) AS avg_percent_diffrent
FROM raise_price
GROUP BY name 
ORDER BY avg_percent_diffrent


-- Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?
WITH table_avg AS (
	SELECT 
		t.code,
		t.payroll_year,
		t.avg_value,
		round((avg(t.avg_value)-avg(t2.avg_value))/ avg(t2.avg_value) * 100, 2) AS raise_value,
		round((avg(t.avarage_wages_czk)-avg(t2.avarage_wages_czk))/ avg(t2.avarage_wages_czk) * 100, 2) AS raise_wages
	FROM t_jindrich_franek_project_sql_primary_final t 
	JOIN t_jindrich_franek_project_sql_primary_final t2
		ON t.payroll_year = t2.payroll_year + 1  
		AND t.name = t2.name 
	GROUP BY payroll_year )
SELECT
	payroll_year,
	raise_value - raise_wages AS avg_raise_value
FROM table_avg




-- Má výška HDP vliv na změny ve mzdách a cenách potravin? 
-- Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?
WITH table_1 AS (
	SELECT 
		t.payroll_year,
		round((avg(t.avg_value)-avg(t2.avg_value))/ avg(t2.avg_value) * 100, 2) AS raise_value,
		round((avg(t.avarage_wages_czk)-avg(t2.avarage_wages_czk))/ avg(t2.avarage_wages_czk) * 100, 2) AS raise_wages
	FROM t_jindrich_franek_project_sql_primary_final t 
	JOIN t_jindrich_franek_project_sql_primary_final t2
		ON t.payroll_year = t2.payroll_year + 1  
		AND t.name = t2.name 
	GROUP BY t.payroll_year ), 
table_2 AS (
	SELECT
		ts.`year`,
		ts.GDP AS next_year, 
		ts2.GDP,
		round((avg(ts.GDP)-avg(ts2.GDP))/ avg(ts2.GDP)*100,2) AS  raise_gdp
	FROM t_jindrich_franek_project_sql_secondary_final ts
	JOIN t_jindrich_franek_project_sql_secondary_final ts2
		ON ts.`year` = ts2.`year` + 1
		AND ts.country = 'Czech Republic' AND ts2.country = 'Czech Republic' 
	GROUP BY ts.`year` )  
SELECT 
	payroll_year,
	raise_gdp,
	raise_value,
	raise_wages
FROM table_1
JOIN table_2
	ON table_1.payroll_year = table_2.year



