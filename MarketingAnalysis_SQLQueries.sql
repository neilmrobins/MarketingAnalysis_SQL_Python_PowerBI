USE PortfolioProject_MarketingAnalytics
SELECT 
    c.CustomerID,
    c.CustomerName,
    c.Email,
    c.Gender,
    c.Age,
    g.Country,
    g.City  
FROM 
    dbo.customers as c  
LEFT JOIN
    dbo.geography g  
ON 
    c.GeographyID = g.GeographyID;  -- Joins the two tables on the GeographyID field to match customers with their geographic information

SELECT 
    ProductID,  
    ProductName,  
    Price,  
	

    CASE -- Categorizes the products into price categories: Low, Medium, or High
        WHEN Price < 50 THEN 'Low'  
        WHEN Price BETWEEN 50 AND 200 THEN 'Medium'  
        ELSE 'High'  
    END AS PriceCategory  

FROM 
    dbo.products; 
    
-- Query to clean whitespace issues in the ReviewText column

SELECT 
    ReviewID,  
    CustomerID,  
    ProductID,  
    ReviewDate,  
    Rating,  
    -- Cleans up the ReviewText by replacing double spaces with single spaces to ensure the text is more readable and standardized
    REPLACE(ReviewText, '  ', ' ') AS ReviewText
FROM 
    dbo.customer_reviews;
    
SELECT 
    EngagementID, 
    ContentID,  
	CampaignID,  
    ProductID,  
    UPPER(REPLACE(ContentType, 'Socialmedia', 'Social Media')) AS ContentType,  -- Replaces "Socialmedia" with "Social Media" and then converts all ContentType values to uppercase
    LEFT(ViewsClicksCombined, CHARINDEX('-', ViewsClicksCombined) - 1) AS Views,  -- Extracts the Views part from the ViewsClicksCombined column by taking the substring before the '-' character
    RIGHT(ViewsClicksCombined, LEN(ViewsClicksCombined) - CHARINDEX('-', ViewsClicksCombined)) AS Clicks,  -- Extracts the Clicks part from the ViewsClicksCombined column by taking the substring after the '-' character
    Likes,  
    -- Converts the EngagementDate to the dd.mm.yyyy format
    FORMAT(CONVERT(DATE, EngagementDate), 'dd.MM.yyyy') AS EngagementDate  -- Converts and formats the date as dd.mm.yyyy
FROM 
    dbo.engagement_data  
WHERE 
    ContentType != 'Newsletter';  -- Filters out rows where ContentType is 'Newsletter' as these are not relevant for our analysis

-- Common Table Expression (CTE) to identify and tag duplicate records

WITH DuplicateRecords AS (
    SELECT 
        JourneyID,  -- Select the unique identifier for each journey (and any other columns you want to include in the final result set)
        CustomerID,  -- Select the unique identifier for each customer
        ProductID,  -- Select the unique identifier for each product
        VisitDate,  -- Select the date of the visit, which helps in determining the timeline of customer interactions
        Stage,  -- Select the stage of the customer journey (e.g., Awareness, Consideration, etc.)
        Action,  -- Select the action taken by the customer (e.g., View, Click, Purchase)
        Duration,  -- Select the duration of the action or interaction
        -- Use ROW_NUMBER() to assign a unique row number to each record within the partition defined below
        ROW_NUMBER() OVER (
            -- PARTITION BY groups the rows based on the specified columns that should be unique
            PARTITION BY CustomerID, ProductID, VisitDate, Stage, Action  
            -- ORDER BY defines how to order the rows within each partition (usually by a unique identifier like JourneyID)
            ORDER BY JourneyID  
        ) AS row_num  -- This creates a new column 'row_num' that numbers each row within its partition
    FROM 
        dbo.customer_journey  -- Specifies the source table from which to select the data
)

-- Select all records from the CTE where row_num > 1, which indicates duplicate entries
    
SELECT *
FROM DuplicateRecords
-- WHERE row_num > 1  -- Filters out the first occurrence (row_num = 1) and only shows the duplicates (row_num > 1)
ORDER BY JourneyID

-- Outer query selects the final cleaned and standardized data
    
SELECT 
    JourneyID,  
    CustomerID,  
    ProductID,  
    VisitDate,  
    Stage,  
    Action,  
    COALESCE(Duration, avg_duration) AS Duration  -- Replaces missing durations with the average duration for the corresponding date
FROM 
    (
        -- Subquery to process and clean the data
        SELECT 
            JourneyID,  
            CustomerID,  
            ProductID,  
            VisitDate,  
            UPPER(Stage) AS Stage,  
            Action,  
            Duration,  
            AVG(Duration) OVER (PARTITION BY VisitDate) AS avg_duration,  
            ROW_NUMBER() OVER (
                PARTITION BY CustomerID, ProductID, VisitDate, UPPER(Stage), Action  
                ORDER BY JourneyID 
            ) AS row_num  
        FROM 
            dbo.customer_journey  
    ) AS subquery 
WHERE 
    row_num = 1;  -- Keeps only the first occurrence of each duplicate group identified in the subquery