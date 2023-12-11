-- Drop the tables
DROP TABLE IF EXISTS `TicketItems`;
DROP TABLE IF EXISTS `SalesTicket`;
DROP TABLE IF EXISTS `DebitCard`;
DROP TABLE IF EXISTS `CreditCard`;
DROP TABLE IF EXISTS `Payment_Info`;
DROP TABLE IF EXISTS `Payment_plan`;
DROP TABLE IF EXISTS `CreditCardType`;
DROP TABLE IF EXISTS `Customer`;
DROP TABLE IF EXISTS `Salesman`;
DROP TABLE IF EXISTS `PhoneAttributes`;
DROP TABLE IF EXISTS `Phone`;
DROP TABLE IF EXISTS `Supplier`;
DROP TABLE IF EXISTS `Inventory`;
DROP TRIGGER IF EXISTS before_insert_Customer;
DROP TRIGGER IF EXISTS before_insert_CreditCard;
DROP TRIGGER IF EXISTS before_insert_TicketItems;

-- Create the Inventory table
CREATE TABLE `Inventory` (
  `Model` VARCHAR(255) PRIMARY KEY,
  `Stock` INT NOT NULL DEFAULT 0 CHECK (`Stock` >= 0) -- Non-negative stock
);

-- Create the Supplier table
CREATE TABLE `Supplier` (
  `SupplierID` VARCHAR(30) PRIMARY KEY,
  `SupplierName` VARCHAR(255) NOT NULL,
  `ContactInfo` VARCHAR(255),
  `ContactName` VARCHAR(255)
);

-- Create the Phone table
CREATE TABLE `Phone` (
  `PhoneID` VARCHAR(6) PRIMARY KEY,
  `PhoneBrand` VARCHAR(255) NOT NULL,
  `SupplierID` VARCHAR(30),
  FOREIGN KEY (`SupplierID`) REFERENCES `Supplier` (`SupplierID`) ON DELETE CASCADE
);

-- Create the PhoneAttributes table
CREATE TABLE `PhoneAttributes` (
  `PhoneID` VARCHAR(6) PRIMARY KEY,
  `Model` VARCHAR(255),
  `Price` DECIMAL(10,2) NOT NULL CHECK (`Price` >= 0), -- Non-negative price
  `Color` VARCHAR(255),
  `Storage` VARCHAR(255),
  `Memory` VARCHAR(255),
  `Camera` VARCHAR(255),
  `Size` VARCHAR(255),
  `AspectRatio` VARCHAR(10),
  `Connectivity` VARCHAR(255),
  `Processor` VARCHAR(255),
  `OS` VARCHAR(255),
  FOREIGN KEY (`PhoneID`) REFERENCES `Phone` (`PhoneID`) ON DELETE CASCADE,
  FOREIGN KEY (`Model`) REFERENCES `Inventory` (`Model`) ON DELETE CASCADE
);

-- Create the Salesman table
CREATE TABLE `Salesman` (
  `SalesmanID` VARCHAR(5) PRIMARY KEY,
  `Name` VARCHAR(255) NOT NULL,
  `LastName` VARCHAR(255) NOT NULL,
  `ContactNumber` VARCHAR(10) UNIQUE -- Unique contact number
);

-- Create the Customer table
CREATE TABLE `Customer` (
  `CustomerID` INT PRIMARY KEY,
  `Customer_Name` VARCHAR(255) NOT NULL,
  `Customer_LastName` VARCHAR(255) NOT NULL,
  `Customer_PhoneNumber` VARCHAR(10), -- Unique phone number
  `Customer_DateOfBirth` DATE -- Date of birth
);

-- Create a trigger to enforce the DateOfBirth constraint in Customer table
DELIMITER //
CREATE TRIGGER before_insert_Customer
BEFORE INSERT ON `Customer`
FOR EACH ROW
BEGIN
    IF NEW.Customer_DateOfBirth IS NOT NULL AND NEW.Customer_DateOfBirth > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Date of birth should not be in the future';
    END IF;
END;
//
DELIMITER ;

-- Create the CreditCardType table
CREATE TABLE `CreditCardType` (
  `CreditCardProvider_ID` VARCHAR(4) PRIMARY KEY,
  `ProviderName` VARCHAR(50) UNIQUE -- Unique provider name
);

-- Create the Payment_plan table
CREATE TABLE `Payment_plan` (
  `PaymentPlanID` VARCHAR(5) PRIMARY KEY,
  `PlanType` VARCHAR(16) NOT NULL,
  `PaymentCycle` VARCHAR(16) NOT NULL
);

-- Create the Payment_Info table
CREATE TABLE `Payment_Info` (
  `PaymentID` VARCHAR(5) PRIMARY KEY,
  `PaymentPlanID` VARCHAR(5),
  `PaymentMethod` VARCHAR(255),
  FOREIGN KEY (`PaymentPlanID`) REFERENCES `Payment_plan` (`PaymentPlanID`) ON DELETE CASCADE
);

-- Create the CreditCard table
CREATE TABLE `CreditCard` (
  `PaymentID` VARCHAR(5) PRIMARY KEY,
  `CardNumber` VARCHAR(20) NOT NULL,
  `ExpiryDate` DATE NOT NULL, -- Expiry date should not be in the past
  `CreditCardProvider_ID` VARCHAR(4),
  FOREIGN KEY (`PaymentID`) REFERENCES `Payment_Info` (`PaymentID`) ON DELETE CASCADE,
  FOREIGN KEY (`CreditCardProvider_ID`) REFERENCES `CreditCardType` (`CreditCardProvider_ID`)
);

-- Trigger to enforce the ExpiryDate constraint in CreditCard table
DELIMITER //
CREATE TRIGGER before_insert_CreditCard
BEFORE INSERT ON `CreditCard`
FOR EACH ROW
BEGIN
    IF NEW.ExpiryDate IS NOT NULL AND NEW.ExpiryDate < CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Expiry date should not be in the past';
    END IF;
END;
//
DELIMITER ;

-- Create the DebitCard table
CREATE TABLE `DebitCard` (
  `PaymentID` VARCHAR(5) PRIMARY KEY,
  `DebitNumber` VARCHAR(25) NOT NULL,
  FOREIGN KEY (`PaymentID`) REFERENCES `Payment_Info` (`PaymentID`) ON DELETE CASCADE
);

CREATE TABLE `SalesTicket` (
  `SalesTicketID` VARCHAR(10) PRIMARY KEY,
  `SalesmanID` VARCHAR(5),
  `CustomerID` INT,
  `PaymentID` VARCHAR(5),
  `SaleDate` DATETIME,
  FOREIGN KEY (`SalesmanID`) REFERENCES `Salesman` (`SalesmanID`) ON DELETE SET NULL,
  FOREIGN KEY (`CustomerID`) REFERENCES `Customer` (`CustomerID`) ON DELETE SET NULL,
  FOREIGN KEY (`PaymentID`) REFERENCES `Payment_Info` (`PaymentID`) ON DELETE CASCADE
);

CREATE TABLE `TicketItems`(
	`TicketID` VARCHAR(10),
	`PhoneID` VARCHAR(6),
	`ItemQuantity` SMALLINT, 
	PRIMARY KEY (`TicketID`,`PhoneID`),
	FOREIGN KEY (`TicketID`) REFERENCES `SalesTicket` (`SalesTicketID`),
	FOREIGN KEY (`PhoneID`) REFERENCES `Phone` (`PhoneID`)
);

-- Trigger to automatically discount the stock when a ticket is inserted
DELIMITER //
CREATE TRIGGER before_insert_TicketItems
BEFORE INSERT ON `TicketItems`
FOR EACH ROW
BEGIN
  DECLARE StockChange INT;
  SET StockChange = NEW.ItemQuantity;
  
  -- Check if the phone model is in stock
  SELECT Stock INTO @CurrentStock FROM Inventory WHERE Model = (SELECT Model FROM PhoneAttributes WHERE PhoneID = NEW.PhoneID);
  
  IF @CurrentStock < StockChange THEN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'Not enough stock available for the requested phone model';
  ELSE
    -- Update the stock in the Inventory table
    UPDATE Inventory SET Stock = Stock - StockChange WHERE Model = (SELECT Model FROM PhoneAttributes WHERE PhoneID = NEW.PhoneID);
  END IF;
END;
//
DELIMITER ;