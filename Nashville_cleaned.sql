/* 
Cleaning data in SQL
*/

SELECT *
FROM PortfolioProject.dbo.NashvilleHousing
ORDER BY ParcelID


-- 1) STANDERDIZE DATE FORMAT

-- the original column (SaleDate) is of datetime data type, but the time dosen't show any significance
-- so in this step we will change its data type from datetime to date

SELECT SaleDate
FROM PortfolioProject..NashvilleHousing
ORDER BY ParcelID

-- change the datatype of the column from datetime to date
ALTER TABLE NashvilleHousing
ALTER COLUMN SaleDate DATE

SELECT SaleDate
FROM PortfolioProject..NashvilleHousing
ORDER BY ParcelID


-- 2) POPULATE PROPERTY ADDRESS DATA

-- here we can see there are null values in the propertyaddress column 
SELECT COUNT(PropertyAddress), COUNT(*)-COUNT(PropertyAddress) NullCountPropertyAddress
FROM PortfolioProject..NashvilleHousing
--ORDER BY ParcelID

-- NOTICE THAT: when parcelID doesn't change, property address also stays the same. look at rows 44& 45, 84&85 and 86&87

SELECT *
FROM PortfolioProject.dbo.NashvilleHousing
--WHERE PropertyAddress IS NULL
ORDER BY ParcelID

-- since rows with the same parcelID have the same propertyaddress, 
-- we need to pair these propertyaddress when they are null with propertyaddresses with the same parcelID
-- use SELF JOIN to pair rows from the same table 

SELECT a.ParcelID, a.PropertyAddress , b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM PortfolioProject..NashvilleHousing	a
JOIN PortfolioProject..NashvilleHousing b
ON a.ParcelID = b.ParcelID
-- this line below (AND) will prevent having duplicate rows
AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress	IS NULL 


UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
FROM PortfolioProject..NashvilleHousing	a
JOIN PortfolioProject..NashvilleHousing b
ON a.ParcelID = b.ParcelID
AND a.[UniqueID ] <> b.[UniqueID ]
WHERE a.PropertyAddress	IS NULL 


-- 3) BREAKING OUT ADDRESS INTO INDIVIDUAL COLUMNS (ADDRESS, CITY, STATE)

SELECT *
FROM PortfolioProject..NashvilleHousing
ORDER BY ParcelID

-- TO EXTRACT certain sting from a column use "substring, charindex, len"

SELECT 
SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1) AS Address, -- "-1" here to get rid of the comma
SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress)) AS City -- "+1" here to get rid of the comma
FROM PortfolioProject..NashvilleHousing

-- adding 2 new columns to the table, to assign to them the values created by the query above

ALTER TABLE PortfolioProject..NashvilleHousing
add PropertySplitAddress Nvarchar(255)

ALTER TABLE PortfolioProject..NashvilleHousing
add PropertySplitCity Nvarchar(255)

UPDATE PortfolioProject..NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, CHARINDEX(',', PropertyAddress)-1)

UPDATE PortfolioProject..NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress)+1, LEN(PropertyAddress))


-- doing the same thing with OwnerAddress, however this time with "PARCENAME" rather than creating a substring

SELECT OwnerAddress
FROM PortfolioProject..NashvilleHousing
ORDER BY ParcelID

SELECT -- parsename extracts strings only with delimiter '.', so we need to REPLACE other delimiters with it.
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3), -- extracts the address
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2), -- extracts the city
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1) -- extracts the state
FROM PortfolioProject..NashvilleHousing
ORDER BY ParcelID

-- adding 3 new columns to the table to store the results in them

ALTER TABLE PortfolioProject..NashvilleHousing
add OwnerSplitAddress Nvarchar(255)

ALTER TABLE PortfolioProject..NashvilleHousing
add OwnerSplitCity Nvarchar(255)

ALTER TABLE PortfolioProject..NashvilleHousing
add OwnerSplitState Nvarchar(255)

UPDATE PortfolioProject..NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3)

UPDATE PortfolioProject..NashvilleHousing
SET OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2)

UPDATE PortfolioProject..NashvilleHousing
SET OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1)


-- 4) CHANGE Y AND N TO YES AND NO IN "SOLD AS VACANT" FIELD

-- select distinct shows 4 different values in the column

SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM PortfolioProject..NashvilleHousing
GROUP BY SoldAsVacant
ORDER BY 2

UPDATE PortfolioProject..NashvilleHousing
SET SoldAsVacant = 
CASE
	WHEN SoldAsVacant = 'N' OR SoldAsVacant = 'No' THEN 'No'
	WHEN SoldAsVacant = 'Y' OR SoldAsVacant = 'Yes' THEN 'Yes'
END -- AS CorrectedSold
FROM PortfolioProject..NashvilleHousing
-- WHERE SoldAsVacant = 'N' OR SoldAsVacant = 'Y'
-- ORDER BY ParcelID


-- 5) REMOVE DUPLICATES
-- if these columns in partition by - in particular - are the same, then we will consider the data duplicated
-- for example look at rows 18043&18044 in the original dataset, each column has the same data
-- can't filter duplicated rows only (row_num >1) as it's not a column in the original table, so we use CTE


-- this will show duplicates
WITH RowNumCTE 
AS
(SELECT *,
	ROW_NUMBER() OVER(
	PARTITION BY ParcelID,
				PropertyAddress,
				SalePrice,
				SaleDate,
				LegalReference
				ORDER BY
					UniqueID
					) row_num

FROM PortfolioProject..NashvilleHousing
--ORDER BY ParcelID
)

SELECT * 
FROM RowNumCTE
WHERE row_num > 1	-- now we can use row_num as its now a column in the temp table
ORDER BY PropertyAddress 


-- this will remove duplicates
WITH RowNumCTE 
AS
(SELECT *,
	ROW_NUMBER() OVER(
	PARTITION BY ParcelID,
				PropertyAddress,
				SalePrice,
				SaleDate,
				LegalReference
				ORDER BY
					UniqueID
					) row_num

FROM PortfolioProject..NashvilleHousing
--ORDER BY ParcelID
)

DELETE
FROM RowNumCTE
WHERE row_num > 1

-- 6) DELETE UNUSED COLUMNS

SELECT *
FROM PortfolioProject..NashvilleHousing
ORDER BY ParcelID

ALTER TABLE PortfolioProject..NashvilleHousing
DROP COLUMN OwnerAddress, PropertyAddress, TaxDistrict, SaleDateConverted
