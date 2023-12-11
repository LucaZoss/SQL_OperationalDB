WITH CustomerSales AS (
    SELECT
        ST.CustomerID,
        SUM(PA.Price * TI.ItemQuantity) AS TotalSalesValue
    FROM
        SalesTicket ST
    INNER JOIN TicketItems TI ON ST.SalesTicketID = TI.TicketID
    INNER JOIN PhoneAttributes PA ON TI.PhoneID = PA.PhoneID
    GROUP BY ST.CustomerID
),
CustomerRFM AS (
    SELECT
        ST.CustomerID,
        -- Recency: Days since last purchase
        DATEDIFF(CURRENT_DATE, MAX(ST.SaleDate)) AS Recency,
        -- Frequency: Number of purchases
        COUNT(DISTINCT ST.SalesTicketID) AS Frequency,
        CS.TotalSalesValue AS Monetary
    FROM
        SalesTicket ST
    INNER JOIN CustomerSales CS ON ST.CustomerID = CS.CustomerID
    GROUP BY ST.CustomerID, CS.TotalSalesValue
),
RFM_Scores AS (
    SELECT
        CR.CustomerID,
        CR.Recency,
        CR.Frequency,
        CR.Monetary,
        -- RFM scores
        NTILE(3) OVER (ORDER BY CR.Recency) AS R_Score,
        NTILE(3) OVER (ORDER BY CR.Frequency DESC) AS F_Score,
        NTILE(3) OVER (ORDER BY CR.Monetary DESC) AS M_Score
    FROM
        CustomerRFM CR
)
SELECT
    R.CustomerID,
    -- Real values
    R.Recency as nb_days_since_last_purchase,
    R.Frequency as nb_purchase,
    R.Monetary as sales_values,
    -- RFM scores
    R.R_Score,
    R.F_Score,
    R.M_Score,
    -- RFM Personas
    CASE
        WHEN R.R_Score = 3 AND R.F_Score = 3 AND R.M_Score = 3 THEN 'Champions'
        WHEN R.F_Score = 3 AND R.M_Score = 3 THEN 'Loyal Customers'
        WHEN R.R_Score = 3 AND R.F_Score = 2 THEN 'Potential Loyalist'
        WHEN R.R_Score = 3 AND R.F_Score IN (1, 2) AND R.M_Score IN (1, 2) THEN 'Recent Customers'
        WHEN R.R_Score = 3 AND R.F_Score = 1 AND R.M_Score = 1 THEN 'Promising'
        WHEN R.R_Score = 2 AND R.F_Score = 2 AND R.M_Score = 2 THEN 'Needs Attention'
        WHEN R.R_Score = 1 AND R.F_Score = 1 THEN 'About to Sleep'
        WHEN R.R_Score = 1 AND (R.F_Score = 2 OR R.F_Score = 3) AND (R.M_Score = 2 OR R.M_Score = 3) THEN 'At Risk'
        WHEN R.R_Score = 1 AND R.F_Score = 3 AND R.M_Score = 3 THEN 'Can’t Lose Them'
        ELSE 'Hibernating'
    END AS RFM_Personas
FROM
    RFM_Scores R