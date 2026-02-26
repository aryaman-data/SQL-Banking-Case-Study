# International Bank Database — SQL Case Study

A comprehensive SQL case study simulating the database operations of an international bank. This project covers customer management, transaction analysis, stored procedures, triggers, user-defined functions, and more implemented in **Microsoft SQL Server (SSMS-21)**.

---

##  Dataset Overview

| Table | Records | Description |
|---|---|---|
| `Continent` | 5 | Maps `region_id` to continent names (Asia, Europe, Africa, America, Australia) |
| `Customers` | 3,500 | Customer details with region and account activity dates |
| `trans_action` | 5,850 | Transaction records with date, type, and amount |

### Schema

```sql
Continent   (region_id  TINYINT PK,  region_name VARCHAR(50))
Customers   (customer_id INT PK,     region_id TINYINT,  start_date DATE,  end_date DATE)
trans_action(customer_id INT,        txn_date DATE,      txn_type VARCHAR(50),  txn_amount INT)
```

---

##  Repository Structure

```
📦 bank-sql-case-study
├── 📄 README.md
├── 📂 data/
│   ├── Continent.csv
│   ├── Customers.csv
│   └── Transaction.csv
└── 📄 Bank_Database_SQL_Solutions.sql
```

---

##  Pre-processing

Before running the queries, the `txn_date` column was cleaned and converted from a string format to a proper `DATE` type:

```sql
--  Converting string dates to ISO format
UPDATE trans_action 
SET txn_date = CONVERT(CHAR(10), CONVERT(DATE, txn_date, 105), 126);

--  Alter column type to DATE
ALTER TABLE trans_action
ALTER COLUMN txn_date DATE;

-- Alter txn_amount to INT
ALTER TABLE trans_action
ALTER COLUMN txn_amount INT;
```

---

##  SQL Queries & Solutions

---

### Q1 — Customer Count per Region (Year 2020)

Counts distinct customers in each region who made at least one transaction in 2020.

```sql
SELECT 
    c.region_name, 
    COUNT(DISTINCT t.customer_id) AS unique_customer_count
FROM trans_action t
JOIN Customers cu ON t.customer_id = cu.customer_id
JOIN Continent c  ON cu.region_id  = c.region_id
WHERE YEAR(t.txn_date) = 2020
GROUP BY c.region_name
ORDER BY unique_customer_count DESC;
```

---

### Q2 — Max and Min Transaction Amount per Type

```sql
SELECT 
    txn_type, 
    MAX(txn_amount) AS max_amount, 
    MIN(txn_amount) AS min_amount
FROM trans_action
GROUP BY txn_type;
```

---

### Q3 — Deposits Greater Than 2000

Retrieves customer id, region name and transaction amount for all deposits above 2000.

```sql
SELECT 
    t.customer_id, 
    c.region_name, 
    t.txn_amount
FROM trans_action t
JOIN Customers cu ON t.customer_id = cu.customer_id
JOIN Continent c  ON cu.region_id  = c.region_id
WHERE t.txn_type = 'deposit' 
  AND t.txn_amount > 2000;
```

---

### Q4 — Duplicate Records in Customers Table

```sql
-- Exact duplicates across all columns
SELECT 
    customer_id, region_id, start_date, end_date, 
    COUNT(*) AS occurrence_count
FROM Customers
GROUP BY customer_id, region_id, start_date, end_date
HAVING COUNT(*) > 1;

-- Customers with more than one entry
SELECT 
    customer_id, 
    COUNT(*) AS total_entries
FROM Customers
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY total_entries DESC;
```

---

### Q5 — Customer with Minimum Deposit Amount

```sql
SELECT
    t.customer_id, 
    c.region_name, 
    t.txn_type, 
    t.txn_amount
FROM trans_action t
JOIN Customers cu ON t.customer_id = cu.customer_id
JOIN Continent c  ON cu.region_id  = c.region_id
WHERE t.txn_type = 'deposit' 
  AND t.txn_amount = (
      SELECT MIN(txn_amount) 
      FROM trans_action 
      WHERE txn_type = 'deposit'
  );
```

---

### Q6 — Stored Procedure: Transactions After June 2020

```sql
CREATE PROCEDURE GetRecentTransactions
AS
BEGIN
    SELECT 
        t.customer_id, t.txn_date, t.txn_type, t.txn_amount, c.region_name
    FROM trans_action t
    JOIN Customers cu ON t.customer_id = cu.customer_id
    JOIN Continent c  ON cu.region_id  = c.region_id
    WHERE t.txn_date > '2020-06-01'
    ORDER BY t.txn_date ASC;
END;
GO

EXEC GetRecentTransactions;
```

---

### Q7 — Stored Procedure: Insert a New Continent

Includes a duplicate check before inserting.

```sql
CREATE PROCEDURE NewContinent
    @RegionID   INT,
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
        PRINT 'Error: Region ID already exists.';
END;
GO

EXEC NewContinent @RegionID = 6, @RegionName = 'Antarctica';
```

---

### Q8 — Stored Procedure: Transactions on a Specific Date

```sql
CREATE PROCEDURE GetTransactionsByDate
    @InputDate VARCHAR(10)
AS
BEGIN
    SELECT 
        t.customer_id, t.txn_date, t.txn_type, t.txn_amount, c.region_name
    FROM trans_action t
    JOIN Customers cu ON t.customer_id = cu.customer_id
    JOIN Continent c  ON cu.region_id  = c.region_id
    WHERE t.txn_date = @InputDate;
END;
GO

EXEC GetTransactionsByDate @InputDate = '2020-01-21';
```

---

### Q9 — UDF: Add 10% to Transaction Amount

```sql
CREATE FUNCTION fn_AddTenPercent (@Amount INT)
RETURNS DECIMAL(10, 2)
AS
BEGIN
    RETURN @Amount * 1.10;
END;
GO

SELECT 
    customer_id, txn_type,
    txn_amount                          AS original_amount,
    dbo.fn_AddTenPercent(txn_amount)    AS increased_amount
FROM trans_action;
```

---

### Q10 — UDF: Total Transaction Amount for a Given Type

```sql
CREATE FUNCTION fn_GetTotalByType (@Type VARCHAR(20))
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

-- Get total for all types at once
SELECT DISTINCT 
    txn_type, 
    dbo.fn_GetTotalByType(txn_type) AS Total_Amount
FROM trans_action;
```

---

### Q11 — Table-Valued Function: Customer Transaction Details

```sql
CREATE FUNCTION fn_GetCustomerTransactionDetails()
RETURNS TABLE
AS
RETURN (
    SELECT 
        t.customer_id, cu.region_id, 
        t.txn_date, t.txn_type, t.txn_amount
    FROM trans_action t
    INNER JOIN Customers cu ON t.customer_id = cu.customer_id
);
GO

-- Usage
SELECT * FROM dbo.fn_GetCustomerTransactionDetails();

-- Filter by region
SELECT * FROM dbo.fn_GetCustomerTransactionDetails()
WHERE region_id = 3;
```

---

### Q12 — TRY...CATCH: Region ID and Name in a Single Column

```sql
BEGIN TRY
    SELECT 
        CONCAT(region_id, ' - ', region_name) AS Region_Details
    FROM Continent;
END TRY
BEGIN CATCH
    SELECT 
        ERROR_NUMBER()  AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
    PRINT 'An error occurred while retrieving region details.';
END CATCH;
```

---

### Q13 — TRY...CATCH: Safe Insert into Continent

```sql
BEGIN TRY
    INSERT INTO Continent (region_id, region_name)
    VALUES (6, 'Antarctica');
    PRINT 'Success: Record inserted into Continent table.';
END TRY
BEGIN CATCH
    SELECT 
        ERROR_NUMBER()   AS ErrorNumber,
        ERROR_SEVERITY() AS ErrorSeverity,
        ERROR_STATE()    AS ErrorState,
        ERROR_MESSAGE()  AS ErrorMessage;
    PRINT 'Error: The record could not be inserted.';
END CATCH;
```

---

### Q14 — DDL Trigger: Prevent Dropping Tables

```sql
CREATE TRIGGER tr_PreventTableDrop
ON DATABASE 
FOR DROP_TABLE
AS
BEGIN
    PRINT 'CRITICAL: Table deletion is not allowed in this database!';
    ROLLBACK;
END;
GO
```

---

### Q15 — DML Trigger: Audit Trail for Transactions

Creates an audit log table and tracks all `UPDATE` and `DELETE` operations on `trans_action`.

```sql
-- Audit log table
CREATE TABLE trans_action_Audit (
    AuditID         INT IDENTITY(1,1) PRIMARY KEY,
    customer_id     INT,
    txn_amount_old  INT,
    txn_amount_new  INT,
    ActionType      VARCHAR(20),
    ChangedBy       VARCHAR(100),
    ChangedDate     DATETIME DEFAULT GETDATE()
);

-- Trigger
CREATE TRIGGER tr_Audit_TransactionChanges
ON trans_action
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    -- Log UPDATEs
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
        INSERT INTO trans_action_Audit 
            (customer_id, txn_amount_old, txn_amount_new, ActionType, ChangedBy)
        SELECT i.customer_id, d.txn_amount, i.txn_amount, 'UPDATE', SYSTEM_USER
        FROM inserted i JOIN deleted d ON i.customer_id = d.customer_id;

    -- Log DELETEs
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
        INSERT INTO trans_action_Audit 
            (customer_id, txn_amount_old, ActionType, ChangedBy)
        SELECT customer_id, txn_amount, 'DELETE', SYSTEM_USER
        FROM deleted;
END;
GO
```

---

### Q16 — Logon Trigger: Prevent Multiple Active Sessions

```sql
CREATE TRIGGER tr_PreventMultipleLogins
ON ALL SERVER 
FOR LOGON
AS
BEGIN
    IF (
        SELECT COUNT(*) 
        FROM sys.dm_exec_sessions 
        WHERE is_user_process = 1 
          AND login_name = ORIGINAL_LOGIN()
    ) > 1
    BEGIN
        ROLLBACK;
        PRINT 'Access Denied: You already have an active session.';
    END
END;
GO
```

---

### Q17 — Top N Customers by Transaction Type

Uses `DENSE_RANK()` window function to rank customers within each transaction type.

```sql
WITH RankedTransactions AS (
    SELECT 
        customer_id, txn_type, txn_amount,
        DENSE_RANK() OVER (PARTITION BY txn_type ORDER BY txn_amount DESC) AS rnk
    FROM trans_action
)
SELECT customer_id, txn_type, txn_amount
FROM RankedTransactions
WHERE rnk <= 3
ORDER BY txn_type, rnk;
```

---

### Q18 — Pivot Table: Total Deposit, Purchase, Withdrawal per Customer

```sql
SELECT 
    customer_id, 
    ISNULL(deposit,    0) AS Total_Deposit, 
    ISNULL(purchase,   0) AS Total_Purchase, 
    ISNULL(withdrawal, 0) AS Total_Withdrawal
FROM (
    SELECT customer_id, txn_type, txn_amount 
    FROM trans_action
) AS SourceTable
PIVOT (
    SUM(txn_amount) 
    FOR txn_type IN (deposit, purchase, withdrawal)
) AS PivotTable
ORDER BY customer_id;
```

---

## 💡 Key Concepts Covered

- Multi-table `JOIN` operations across 3 tables
- Aggregate functions — `SUM`, `MAX`, `MIN`, `COUNT`
- Subqueries and correlated subqueries
- Window functions — `DENSE_RANK() OVER (PARTITION BY ... ORDER BY ...)`
- Stored Procedures with parameters and duplicate validation
- Scalar User Defined Functions
- Inline Table-Valued Functions
- Error handling with `TRY...CATCH` blocks
- DDL Trigger — prevents `DROP TABLE` at the database level
- DML Triggers — `AFTER UPDATE / DELETE` audit trail
- Server-level Logon Trigger — prevents concurrent sessions
- `PIVOT` operator for cross-tabulation reports
- Data type conversion and pre-processing with `CONVERT`

---

## 🛠️ Requirements

- Microsoft SQL Server 2016+
- SQL Server Management Studio (SSMS)

---

## 👤 Author

**Aryaman Vishnoi**  
[LinkedIn](https://www.linkedin.com/in/aryamanvishnoi-data/)

---

## 📜 License

This project is intended for educational purposes.
