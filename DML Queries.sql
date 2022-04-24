-- In this Query I'm going to do some Exploration, Manipulation, and Analysis to the data 

/* Skills Used: Joins, CTE's, Temp Tables, Subquery, Window Functions, Aggregate Functions, 
   Pivoting, Converting data type, Aliasing, Mathematical Calculations, Nested CTE's */
  

-- Exploring the Tables

SELECT  *
FROM Calender

SELECT *
FROM Countries

SELECT * 
FROM CovidRecords 


-- Countries with Highest Deaths Count 

SELECT CountryName,
       MAX(TotalDeaths) AS Deaths
FROM CovidRecords AS r
JOIN Countries AS c
 ON r.CountryID = c.id
GROUP BY CountryName
ORDER BY Deaths DESC




-- Cases number VS tests number Day By Day

SELECT Date, 
       dbo.fnCountryName(CountryID) AS Country_Name,--Function
       NewCases,
	   NewTest,
	   CAST(NewCases AS float) / NewTest *100 AS CasesPerTests
FROM CovidRecords
WHERE CountryID IN (SELECT CountryID
                    FROM CovidRecords
					GROUP BY CountryID
					HAVING SUM(NewTest) = MAX(TotalTest)) /* I excluded any countries don't have this logic to get 
				                                           better results because Some countries don't have records 
														   for new tests and athors dont have logical one  */



-- Worst Month Deaths Have been recorded For each country 

SELECT CountryName, 
       MonthName AS WorstMonth, 
       TotalDethsPerMonths
FROM (
      SELECT dbo.fnCountryName(d.CountryID) AS CountryName,
             c.MonthName, 
	         SUM(d.NewDeaths) AS TotalDethsPerMonths,
	         ROW_NUMBER() OVER(PARTITION BY dbo.fnCountryName(d.CountryID) ORDER BY SUM(d.NewDeaths) DESC) AS Row_num
      FROM CovidRecords AS d
      LEFT JOIN Calender AS c
         ON d.Date = c.Date
      GROUP BY dbo.fnCountryName(CountryID), MonthName
      HAVING SUM(d.NewDeaths) IS NOT NULL ) AS SubQ
WHERE Row_num = 1 
ORDER BY TotalDethsPerMonths DESC



-- Looking For Deaths Percentage VS Population Percentage Per Continent Using Temp Table

CREATE TABLE #PopulationAndDeaths_continent 
(
  Continent VARCHAR(20),
  ContinentPop FLOAT,
  GlobalPop FLOAT,
  ContinentDeaths FLOAT,
  GlobalDeaths FLOAT )

INSERT INTO #PopulationAndDeaths_continent
SELECT c.Continent,
       SUM(c.Population) AS Pop_Per_Continent,
       SUM(SUM(c.Population)) OVER() AS GlobalPop,
	   SUM(r.NewDeaths) AS Deaths_per_continent, 
	   SUM(SUM(r.NewDeaths)) OVER() AS GlobalDeaths
FROM CovidRecords AS r
LEFT JOIN Countries AS c
ON r.CountryID = c.id
GROUP BY Continent

SELECT Continent, 
       ROUND(ContinentPop / GlobalPop *100 , 2) AS Pop_Pct,
	   ROUND(ContinentDeaths / GlobalDeaths *100 , 2) AS Deaths_Pct
FROM #PopulationAndDeaths_continent
ORDER BY Deaths_Pct DESC



-- Over view of total cases with population density And total deaths with Life expectancy for each country

SELECT DISTINCT CountryName,  
       SUM(NewCases) OVER (PARTITION BY CountryName) AS Total_Cases, 
	   PopulationDensity,
	   SUM(NewDeaths) OVER (PARTITION BY CountryName) AS Total_Deaths,
	   LifeExpectancy
FROM CovidRecords AS r
JOIN Countries AS c
ON r.CountryID = c.id
ORDER BY Total_Cases DESC



-- Looking for Cases, Deaths, Tests, and Vaccination Percentage For Each Country

SELECT DISTINCT CountryName, 
       Population,
   ROUND(SUM(CAST (NewCases AS FLOAT)) OVER( PARTITION BY CountryName) / Population,3) AS Cases_Pct, 
   ROUND(SUM(CAST (NewDeaths AS FLOAT)) OVER( PARTITION BY CountryName) / Population,3) AS Deaths_Pct,
   ROUND(SUM(CAST (NewTest AS FLOAT)) OVER( PARTITION BY CountryName) / Population,3) AS Tests_Pct,
   ROUND(SUM(CAST (NewVaccinations AS FLOAT)) OVER( PARTITION BY CountryName) / Population,3) AS Vacc_Pct
FROM CovidRecords AS r
INNER JOIN Countries AS c
  ON r.CountryID = c.id
ORDER BY CountryName 




-- Pivot Table Present Total Cases FOR Each Quarter For 2020 And 2021 

SELECT Year, Q1, Q2, Q3, Q4
FROM (
   SELECT  c.Quarter, c.Year, d.NewCases
   FROM CovidRecords AS d
   INNER JOIN Calender AS c
   ON c.Date = CAST(d.date AS date)
   --WHERE dbo.fnCountryName(CountryID) = 'Jordan' -- You Can specify any country 
) AS SOURCEtbl
PIVOT
(
  SUM(NewCases) FOR Quarter IN (Q1, Q2, Q3, Q4)
  ) AS Pivottbl




-- Pivot Table Present Total Hospital patients by Day Name For Each Quarter 

SELECT DayOfWeek, Q1, Q2, Q3, Q4
FROM (
   SELECT  c.Quarter, c.DayOfWeek, d.Hosp_patients
   FROM CovidRecords AS d
   INNER JOIN Calender AS c
   ON c.Date = CAST(d.date AS date)
) AS SOURCEtbl1
PIVOT
(
  SUM(Hosp_patients) FOR Quarter IN (Q1, Q2, Q3, Q4)
  ) AS Pivottbl1
ORDER BY CASE WHEN DayOfWeek = 'Sunday' THEN 1
              WHEN DayOfWeek = 'Monday' THEN 2
			  WHEN DayOfWeek = 'Tuesday' THEN 3
			  WHEN DayOfWeek = 'Wednesday' THEN 4
			  WHEN DayOfWeek = 'Thursday' THEN 5
			  WHEN DayOfWeek = 'Friday' THEN 6
			  WHEN DayOfWeek = 'Saturday' THEN 7 END






/* This Query Shows Cases, Deaths, And Vaccinations Running Total Month Over Month For specific Country 
   And the Change Percentage Compared to the previous Month */

WITH MonthlyReport AS(
SELECT CountryID,
       CAST(DATEADD(MONTH, DATEDIFF(MONTH,0,Date),0) AS date) AS Monthly_Date,-- Downsampling the date to the nearest month
       SUM(NewCases) AS Total_Monthly_cases,
	   SUM(NewDeaths) AS Total_Monthly_deaths,
	   SUM(NewVaccinations) AS Total_Monthly_Vacc
FROM CovidRecords
GROUP BY CountryID, CAST(DATEADD(MONTH, DATEDIFF(MONTH,0,Date),0) AS date)
),
RunningTotal AS(
SELECT Monthly_Date,
       SUM(Total_Monthly_cases) OVER(ORDER BY Monthly_Date) AS Cases_RuningTotalPerMonth,
	   SUM(Total_Monthly_deaths) OVER(ORDER BY Monthly_Date) AS Deaths_RuningTotalPerMonth,
	   SUM(Total_Monthly_Vacc) OVER(ORDER BY Monthly_Date) AS Vaccination_RuningTotalPerMonth
FROM MonthlyReport
WHERE dbo.fnCountryName(CountryID) = 'United States' --feel free to choose your own country, I used UDF fnCountryName
),
PreviousMonth AS (
SELECT Monthly_Date, 
       Cases_RuningTotalPerMonth,
	   LAG(Cases_RuningTotalPerMonth)OVER(ORDER BY Monthly_Date) AS Prev_Cases,
       Deaths_RuningTotalPerMonth,
	   LAG(Deaths_RuningTotalPerMonth)OVER(ORDER BY Monthly_Date) AS Prev_Deaths,
	   Vaccination_RuningTotalPerMonth,
	   LAG(Vaccination_RuningTotalPerMonth)OVER(ORDER BY Monthly_Date) AS Prev_Vacc
FROM RunningTotal
)
SELECT Monthly_Date, 
       Cases_RuningTotalPerMonth,
	   ROUND((CAST(Cases_RuningTotalPerMonth AS float) - Prev_Cases)/Prev_Cases*100 , 3) AS Cases_monthly_Change,
	   Deaths_RuningTotalPerMonth,
	   ROUND((CAST(Deaths_RuningTotalPerMonth AS float) - Prev_Deaths)/Prev_Deaths*100 , 3) AS Deaths_monthly_Change,
	   Vaccination_RuningTotalPerMonth,
	   ROUND((CAST(Vaccination_RuningTotalPerMonth AS float) - Prev_Vacc)/Prev_Vacc*100 , 3) AS Vaccinations_monthly_Change
FROM PreviousMonth