select * from continent
select * from customers

select * from dbo.Trans_action

UPDATE trans_action 
SET txn_date = CONVERT(CHAR(10), CONVERT(DATE, txn_date, 105), 126);

ALTER TABLE trans_action
ALTER COLUMN txn_date DATE;

--1--
SELECT 
    c.region_name, 
    COUNT(DISTINCT t.customer_id) AS unique_customer_count
FROM trans_action t
JOIN Customers cu ON t.customer_id = cu.customer_id
JOIN Continent c ON cu.region_id = c.region_id
WHERE YEAR(t.txn_date) = 2020
GROUP BY c.region_name
ORDER BY unique_customer_count DESC;

--2--
SELECT 
    txn_type, 
    MAX(txn_amount) AS max_amount, 
    MIN(txn_amount) AS min_amount
FROM trans_action
GROUP BY txn_type;

ALTER TABLE trans_action
ALTER COLUMN txn_amount INT;

--3--
SELECT 
    t.customer_id, 
    c.region_name, 
    t.txn_amount
FROM trans_action t
JOIN Customers cu 
    ON t.customer_id = cu.customer_id
JOIN Continent c 
    ON cu.region_id = c.region_id
WHERE t.txn_type = 'deposit' 
  AND t.txn_amount > 2000;
  ----------------------------------------------------------------------------------------
  --just to verify the highest deposits currently in this database to see what range i'm working with--
  SELECT TOP 10 
    customer_id, 
    txn_amount 
FROM trans_action 
WHERE txn_type = 'deposit' 
ORDER BY txn_amount DESC;

--4--
SELECT 
    customer_id, 
    region_id, 
    start_date, 
    end_date, 
    COUNT(*) AS occurrence_count
FROM Customers
GROUP BY 
    customer_id, 
    region_id, 
    start_date, 
    end_date
HAVING COUNT(*) > 1;

--just wanted to see which customers have more than one entry in the table--

SELECT 
    customer_id, 
    COUNT(*) AS total_entries
FROM Customers
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY total_entries DESC;
---------------------------------------

--5--
SELECT
    t.customer_id, 
    c.region_name, 
    t.txn_type, 
    t.txn_amount
FROM trans_action t
JOIN Customers cu ON t.customer_id = cu.customer_id
JOIN Continent c ON cu.region_id = c.region_id
WHERE t.txn_type = 'deposit' 
  AND t.txn_amount = (SELECT MIN(txn_amount) 
                      FROM trans_action 
                      WHERE txn_type = 'deposit');

--6--
CREATE PROCEDURE GetRecentTransactions
AS
BEGIN
    SELECT 
        t.customer_id,
        t.txn_date,
        t.txn_type,
        t.txn_amount,
        c.region_name
    FROM trans_action t
    JOIN Customers cu ON t.customer_id = cu.customer_id
    JOIN Continent c ON cu.region_id = c.region_id
    WHERE 
        
        CONVERT(DATE, t.txn_date, 105) > '2020-06-01'
    ORDER BY 
        CONVERT(DATE, t.txn_date, 105) ASC;
END;
GO

exec GetRecentTransactions

--7--
CREATE PROCEDURE NewContinent
    @RegionID INT,
    @RegionName VARCHAR(50)
AS
BEGIN
    
    IF NOT EXISTS (SELECT 1 FROM Continent WHERE region_id = @RegionID)
    BEGIN
        INSERT INTO Continent (region_id, region_name)
        VALUES (@RegionID, @RegionName);
        
        PRINT 'Continent added successfully.';
    END
    ELSE
    BEGIN
        PRINT 'Error: Region ID already exists.';
    END
END;
GO
 
exec NewContinent @regionid = 6, @regionname = 'Antartica';

--8--

CREATE PROCEDURE GetTransactionsByDate
    @InputDate VARCHAR(10) 
AS
BEGIN
    SELECT 
        t.customer_id, 
        t.txn_date, 
        t.txn_type, 
        t.txn_amount,
        c.region_name
    FROM trans_action t
    JOIN Customers cu ON t.customer_id = cu.customer_id
    JOIN Continent c ON cu.region_id = c.region_id
    WHERE t.txn_date = @InputDate;
END;
GO

exec GetTransactionsByDate @inputdate = '2020-01-21'

--9--
CREATE FUNCTION fn_AddTenPercent
(
    @Amount INT
)
RETURNS DECIMAL(10, 2)
AS
BEGIN
    RETURN @Amount * 1.10
END;
GO

SELECT 
    customer_id, 
    txn_type, 
    txn_amount AS original_amount,
    dbo.fn_AddTenPercent(txn_amount) AS increased_amount
FROM trans_action;

--10--
CREATE FUNCTION fn_GetTotalByType
(
    @Type VARCHAR(20)
)
RETURNS DECIMAL(18, 2)
AS
BEGIN
    DECLARE @TotalAmount DECIMAL(18, 2);

    SELECT @TotalAmount = SUM(txn_amount)
    FROM trans_action
    WHERE txn_type = @Type;

    
    RETURN ISNULL(@TotalAmount, 0);
END;
GO
SELECT dbo.fn_GetTotalByType('deposit') AS TotalDeposits;

SELECT DISTINCT 
    txn_type, 
    dbo.fn_GetTotalByType(txn_type) AS Total_Amount
FROM trans_action;

--11--
CREATE FUNCTION fn_GetCustomerTransactionDetails()
RETURNS TABLE
AS
RETURN
(
    SELECT 
        t.customer_id, 
        cu.region_id, 
        t.txn_date, 
        t.txn_type, 
        t.txn_amount
    FROM trans_action t
    INNER JOIN Customers cu ON t.customer_id = cu.customer_id
);
GO

SELECT * FROM dbo.fn_GetCustomerTransactionDetails();

SELECT * FROM dbo.fn_GetCustomerTransactionDetails()
WHERE region_id = 3;

--12--
BEGIN TRY
    SELECT 
        
        CONCAT(region_id, ' - ', region_name) AS Region_Details
    FROM Continent;
END TRY

BEGIN CATCH
    
    SELECT 
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
    
    PRINT 'An error occurred while retrieving region details.';
END CATCH;

--13--
BEGIN TRY
    
    INSERT INTO Continent (region_id, region_name)
    VALUES (6, 'Antarctica');

    
    PRINT 'Success: Record inserted into Continent table.';
END TRY

BEGIN CATCH
    
    SELECT 
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_SEVERITY() AS ErrorSeverity,
        ERROR_STATE() AS ErrorState,
        ERROR_MESSAGE() AS ErrorMessage;

    PRINT 'Error: The record could not be inserted. Check the details above.';
END CATCH;

--14--
CREATE TRIGGER tr_PreventTableDrop
ON DATABASE 
FOR DROP_TABLE
AS
BEGIN
    PRINT 'CRITICAL: Table deletion is not allowed in this database!';
    
    
    ROLLBACK;
END;
GO

--15--
CREATE TABLE trans_action_Audit (
    AuditID INT IDENTITY(1,1) PRIMARY KEY,
    customer_id INT,
    txn_amount_old INT,
    txn_amount_new INT,
    ActionType VARCHAR(20),
    ChangedBy VARCHAR(100),
    ChangedDate DATETIME DEFAULT GETDATE()
);

CREATE TRIGGER tr_Audit_TransactionChanges
ON trans_action
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO trans_action_Audit (customer_id, txn_amount_old, txn_amount_new, ActionType, ChangedBy)
        SELECT 
            i.customer_id, 
            d.txn_amount, 
            i.txn_amount, 
            'UPDATE', 
            SYSTEM_USER
        FROM inserted i
        JOIN deleted d ON i.customer_id = d.customer_id;
    END

    
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO trans_action_Audit (customer_id, txn_amount_old, ActionType, ChangedBy)
        SELECT 
            customer_id, 
            txn_amount, 
            'DELETE', 
            SYSTEM_USER
        FROM deleted;
    END
END;
GO


UPDATE trans_action 
SET txn_amount = 500 
WHERE customer_id = 1 AND txn_type = 'deposit';


SELECT * FROM trans_action_Audit;


--16--
CREATE TRIGGER tr_PreventMultipleLogins
ON ALL SERVER 
FOR LOGON
AS
BEGIN
    IF (SELECT COUNT(*) 
        FROM sys.dm_exec_sessions 
        WHERE is_user_process = 1 
        AND login_name = ORIGINAL_LOGIN()) > 1
    BEGIN
        
        ROLLBACK;
        PRINT 'Access Denied: You already have an active session.';
    END
END;
GO

--17--
WITH RankedTransactions AS (
    SELECT 
        customer_id, 
        txn_type, 
        txn_amount,
        DENSE_RANK() OVER (PARTITION BY txn_type ORDER BY txn_amount DESC) AS rnk
    FROM trans_action
)
SELECT 
    customer_id, 
    txn_type, 
    txn_amount
FROM RankedTransactions
WHERE rnk <= 3
ORDER BY txn_type, rnk;

--18--
SELECT 
    customer_id, 
    ISNULL(deposit, 0) AS Total_Deposit, 
    ISNULL(purchase, 0) AS Total_Purchase, 
    ISNULL(withdrawal, 0) AS Total_Withdrawal
FROM 
(
    
    SELECT 
        customer_id, 
        txn_type, 
        txn_amount 
    FROM trans_action
) AS SourceTable
PIVOT 
(
    
    SUM(txn_amount) 
    
    FOR txn_type IN (deposit, purchase, withdrawal)
) AS PivotTable
ORDER BY customer_id;

--****************************************************************************************************--


