/* After importing data from CSV file downloaded from the following website: https://ourworldindata.org/covid-deaths
 to a DATABASE (dbCovid19), and befor doing some Exploratory Analysis I'm going to do some NORMALIZATION and DATA CLEANING
 to the dataset because it's been stored in a single table */

 -- Skills Used : Creat DataBase, Tables, Views, Indexes, Functions, Insert From Another table, Data Type determination 

DROP DATABASE IF EXISTS dbCovid19;
GO
CREATE DATABASE dbCovid19;
USE dbCovid19 
GO

 -- THEN import the data into the Data Base
 -- Rename the imported table to ( CovidData )
 
 -- Craeting a Calender Table 

DROP TABLE IF EXISTS Calender;
GO
CREATE TABLE Calender (
    Date date PRIMARY KEY,
	Year char(4),
	Quarter char(2),
	Month int,
	MonthName varchar(10),
	Day int,
	DayOfWeek varchar(10))

INSERT INTO Calender (Date,Year,Quarter,Month,MonthName,Day,DayOfWeek)
 SELECT DISTINCT CAST(date AS date),
                YEAR(date),
	            CASE WHEN DATEPART(qq,date) = 1 THEN 'Q1'
	                 WHEN DATEPART(qq,date) = 2 THEN 'Q2'
			         WHEN DATEPART(qq,date) = 3 THEN 'Q3'
		          	 WHEN DATEPART(qq,date) = 4 THEN 'Q4' END,
                MONTH(date),
	            DATENAME(MONTH,date),
	            DAY(date),
	            DATENAME(WEEKDAY,date)
FROM CovidData

-- Creating a Table for countries records

DROP TABLE IF EXISTS Countries;
GO
CREATE TABLE Countries (
     id int identity(1,1) PRIMARY KEY,
     CountryName nvarchar(50) ,
	 CountryCode nvarchar(10) ,
	 Continent varchar(30),
	 Population bigint,
	 PopulationDensity float,
	 MedianAge float,
	 LifeExpectancy float )

INSERT INTO Countries 
SELECT DISTINCT location,
                iso_code,
				continent,
				population, 
				population_density,
				median_age,
				life_expectancy
FROM CovidData
WHERE continent IS NOT NULL /* When Continent is null location column provides the continent name to 
                               give us records on a continent level wich is something I execluded here */


-- Creating a Data Table and select the columns we are going to use

DROP TABLE IF EXISTS CovidRecords;
GO
CREATE TABLE CovidRecords (
    Date date, 
	CountryID int FOREIGN KEY REFERENCES Countries(id),
	NewCases int,
	TotalCases bigint,
	NewDeaths int,
	TotalDeaths bigint,
	NewTest int,
	TotalTest bigint,
	NewVaccinations int,
	TotalVaccinations bigint,
	ICU_patients bigint,
	Hosp_patients bigint)

INSERT INTO CovidRecords 
SELECT d.date, c.id, new_cases, total_cases, new_deaths, total_deaths, 
       new_tests, total_tests, new_vaccinations, total_vaccinations, icu_patients, hosp_patients
FROM CovidData AS d
INNER JOIN Countries AS c -- File has provided records on a Continent Level so I used Inner Join to execlude them  
  ON d.location = c.CountryName

	

-- Finally Delete the original table 

DROP TABLE CovidData ;


-- Creating a Clustered index on CovidRecord table to help with the performance 

CREATE CLUSTERED INDEX IX_CovidRecord_DateAndCountryID
ON CovidRecords (CountryID ASC, Date ASC)


-- Creating a scalar function to return country name with country id as an input parameter

CREATE FUNCTION fnCountryName(@id int)
RETURNS varchar(20)
AS BEGIN RETURN (
  SELECT CountryName 
  FROM Countries 
  WHERE id = @id) END

-- Creating A view that shows the tables in the database and thier columns 

CREATE VIEW ColumnName AS
SELECT TABLE_NAME, 
       STRING_AGG(COLUMN_NAME, '  /  ') AS COLUMNS
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
GROUP BY TABLE_NAME

