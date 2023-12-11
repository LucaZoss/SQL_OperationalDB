'''Answers to Questions '''

'''Question 1 - Which are the top 3 phone sales?'''

SELECT
   PA.Model AS PhoneModel,
   SUM(TI.ItemQuantity) AS TotalSales
FROM TicketItems TI
JOIN PhoneAttributes PA ON TI.PhoneID = PA.PhoneID
GROUP BY PA.Model
ORDER BY TotalSales DESC
LIMIT 3;

'''Question 2 - Show the revenue per type of credit card.'''

SELECT
   CC.CreditCardProvider_ID,
   CCP.ProviderName AS CreditCardType,
   SUM(TI.ItemQuantity * PA.Price) AS Revenue
FROM
   TicketItems TI
JOIN
   PhoneAttributes PA ON TI.PhoneID = PA.PhoneID
JOIN
   SalesTicket ST ON TI.TicketID = ST.SalesTicketID
JOIN
   CreditCard CC ON ST.PaymentID = CC.PaymentID
JOIN
   CreditCardType CCP ON CC.CreditCardProvider_ID = CCP.CreditCardProvider_ID
GROUP BY
   CC.CreditCardProvider_ID, CCP.ProviderName
ORDER BY
   Revenue DESC;


'''Question 3 - Which brand are we selling the most this year?'''

SELECT
   I.Model,
   SUM(TI.ItemQuantity) AS TotalSales
FROM
   TicketItems TI
JOIN
   PhoneAttributes PA ON TI.PhoneID = PA.PhoneID
JOIN
   Inventory I ON PA.Model = I.Model
JOIN
   SalesTicket ST ON TI.TicketID = ST.SalesTicketID
WHERE
   YEAR(ST.SaleDate) = YEAR(CURDATE())  -- Filter for sales in the current year
GROUP BY
   I.Model
ORDER BY
   TotalSales DESC
LIMIT 1;  -- To get the top-selling model, you can use LIMIT 1

'''Question 4 - Who (salesman) makes us earn more money?'''

SELECT
   S.SalesmanID,
   S.Name,
   S.LastName,
   COALESCE(SUM(PA.Price * TI.ItemQuantity), 0) AS TotalRevenue
FROM
   Salesman S
LEFT JOIN
   SalesTicket ST ON S.SalesmanID = ST.SalesmanID
LEFT JOIN
   TicketItems TI ON ST.SalesTicketID = TI.TicketID
LEFT JOIN
   PhoneAttributes PA ON TI.PhoneID = PA.PhoneID
GROUP BY
   S.SalesmanID, S.Name, S.LastName
ORDER BY
   TotalRevenue DESC
LIMIT 1; -- To get the top-earning salesman, you can use LIMIT 1

'''Question 5 - How can we categorize our customers based on their purchase behavior to optimize our marketing strategies across different segments?'''

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
    R.Recency AS nb_days_since_last_purchase,
    R.Frequency AS nb_purchase,
    R.Monetary AS sales_values,
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
    

