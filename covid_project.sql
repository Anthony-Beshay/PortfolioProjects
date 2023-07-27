SELECT *
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT null
ORDER BY 3, 4

SELECT *
FROM PortfolioProject..CovidVaccinations
ORDER BY 3, 4

-- 1) death rate per case total (deaths/total cases)
-- error: can't divide nvarchar, need to convert it into intiger
-- use "alter table alter column" to change the data type of the column in the original table
ALTER TABLE PortfolioProject..CovidDeaths
ALTER COLUMN total_deaths int

ALTER TABLE PortfolioProject..CovidDeaths
ALTER COLUMN total_cases int

-- how death rate changes according to time in this location
-- the likelihood of dying if you contract covid in your country
-- *1.0 gives results in decimal point

SELECT location, date, total_cases, total_deaths, (total_deaths * 1.0/total_cases)*100 DeathRate
FROM PortfolioProject..CovidDeaths
WHERE location LIKE '%states%'
ORDER BY 1, 2

-- 2) proportion got it changes according to time in this location
-- total cases vs population

SELECT location, date, total_cases, population, (total_cases *1.0/population)*100 Proportion
FROM PortfolioProject..CovidDeaths
WHERE location LIKE '%states%'
ORDER BY 1, 2

-- 3) which location has the most infection rate (percentage of population) according to population
-- just a single row for each location use "max(total_cases)"; 
-- other than that you will have to group by total_cases and get more than 1 row for each location

SELECT location, MAX(total_cases) HighestInfectionCount, population, MAX((total_cases *1.0/population))*100 inf_rate
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'
GROUP BY location, population
ORDER BY 4 DESC

-- 4) which location has the most death count
-- if total_deaths were nvarchar, you need to cast it into int by "cast(total_deaths as int)"

SELECT location, MAX(total_deaths) HighestDeathsCount
FROM PortfolioProject..CovidDeaths
--WHERE location LIKE '%states%'
-- adding this where clause will remove all locations that are grouping of other locations like: asia, world, ...
-- as these grouping locations do have "null" value in continent column
WHERE continent IS NOT null
GROUP BY location
ORDER BY 2 DESC

-- breaking things by continent
-- 5) which continent has the most death rate (percentage of population) according to population
-- both queries below get close values, 
--the first one is summing the new cases in each continent (new cases in every day in every location in this continent)
--while the second one is making use of the fact that in this dataset when continent is null, the location then is showing a group of locations

SELECT continent, SUM(new_deaths) HighestDeathsCount
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT null
GROUP BY continent
ORDER BY 2 DESC

SELECT location, MAX(total_deaths) HighestDeathsCount
FROM PortfolioProject..CovidDeaths
WHERE continent IS null AND location NOT LIKE '%income%'
GROUP BY location
ORDER BY 2 DESC

-- 6) showing continents with the highest death count per population
-- this query below shows the total deaths of **only** the highest country in the continent, 
-- not the total of all contries in the continent

SELECT continent, MAX(total_deaths) HighestDeathsCount
FROM PortfolioProject..CovidDeaths
WHERE continent IS not null 
GROUP BY continent
ORDER BY 2 DESC

-- 7) global numbers
-- division by zero error, use "nullif" which takes 2 arguments; 
-- if the first one matches the second the output of the function will be null
SELECT SUM(new_cases) total_cases, SUM(new_deaths) total_deaths, 
		(SUM(new_deaths)*1.0/NULLIF(SUM(new_cases), 0))*100 DeathsPercentage
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT null --AND continent NOT LIKE '%income%'
-- this line below is just a confirming for the result of the line above
--WHERE location LIKE '%world%'
-- could've shown the numbers by date; add date to the select statement
--GROUP BY date
ORDER BY 1, 2

-- working on the other table and joining both tables (on location and date; for specificity)

SELECT *
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date

-- 8) looking at total population vs vaccinations

SELECT DISTINCT SUM(dea.population) WholeWorld, SUM(CAST(vac.people_vaccinated AS bigint)) TotalVaccination, 
		(SUM((CAST(vac.people_vaccinated AS bigint)))/SUM(dea.population))*100 ProportionVaccinated --, MAX((vac.total_vaccinations/dea.population))*100 ProportionVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent IS NOT null
ORDER BY 3 DESC

-- use sum over "window frame" to group specific rows, instead of vac.total_vaccinations column (can also be used)
-- order by date to get the "running total".. why order by location also?!
-- use convert is the same as using cast to change the datatype of a particular column
-- use bigint instead of int to avoid overflow error

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) 
AS RollingPeopleVaccinated
-- instead of this line below just use subqueries as in the next queries which show the same results
,(SUM(CONVERT(bigint, vac.new_vaccinations)) 
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date)/dea.population)*100 AS PercentageVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent IS NOT null
ORDER BY 2, 3
--ORDER BY 6 DESC

-- computing the maximum percentage percentage of population of each location, using subquery in from statement

SELECT T1.location, MAX(t1.RollingPeopleVaccinated/t1.population)*100 PercentageVaccinated
FROM (SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) 
AS RollingPeopleVaccinated
--,(SUM(CONVERT(bigint, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date)/dea.population)*100 AS PercentageVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent IS NOT null
--ORDER BY 2, 3
) T1
GROUP BY t1.location
ORDER BY t1.location

-- using CTE & temp table to be able to use a column that you created earlier

-- using CTE
-- perform calculations on a column in the pseudo-table created

WITH PopvsVac --(Continent, Location, Date, Population, New_vaccinations, RollingPeopleVaccinated)
AS
(
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CONVERT(bigint, vac.new_vaccinations)) OVER(PARTITION BY dea.location ORDER BY dea.location, dea.date)
AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent	IS NOT null
)

SELECT *, (RollingPeopleVaccinated/Population)*100
FROM PopvsVac


-- temp table:
-- create table and specify the column names and datatypes
-- insert the previously used inner query into this created table
-- then query this created table

DROP TABLE if exists #PercentPopulationVaccinated -- to add alteration to the query without needing to delete the table
CREATE TABLE #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
-- add a new column in the newly created table, to perform calculations on this column
RollingPeopleVaccinated numeric
)

INSERT INTO #PercentPopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CONVERT(bigint, vac.new_vaccinations)) OVER(PARTITION BY dea.location ORDER BY dea.location, dea.date)
AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent	IS NOT null

SELECT *, (RollingPeopleVaccinated/Population)*100
FROM #PercentPopulationVaccinated

-- CREATE VIEW

CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CONVERT(bigint, vac.new_vaccinations)) OVER(PARTITION BY dea.location ORDER BY dea.location, dea.date)
AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
ON dea.location = vac.location AND dea.date = vac.date
WHERE dea.continent	IS NOT null

SELECT *
FROM PercentPopulationVaccinated