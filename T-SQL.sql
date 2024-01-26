--TRIGGER BEFORE INSERT CUSTOMER
--If the customer is under 18 years of age, he will not be added to the database.
drop TRIGGER TRIGGER1;
CREATE TRIGGER TRIGGER1
ON CUSTOMER
FOR INSERT,UPDATE
AS
BEGIN
	IF ((SELECT year(DATE_BIRTH)FROM inserted)>2005)
	BEGIN
	ROLLBACK
	PRINT 'CUSTOMER IS UNDER 18 YEARS OF AGE'
	END
END

INSERT INTO CUSTOMER VALUES(26, 'Mike', 'KONRADOWSKI', 'M', '2004-10-02', '+480127456', 0);
INSERT INTO CUSTOMER VALUES(29, 'Miroslaw', 'Kwiatwoski', 'M', '2000-11-02', '+480127456', 0);

UPDATE CUSTOMER SET DATE_BIRTH='1998-04-27' where FIRST_NAME='Kot'
SELECT * FROM CUSTOMER;

--TRIGGER AFTER
--For UPDATE: changes cannot be made for hotels if the number of hotel stars is less than 3
-- For DELETE: cannot delete data from the Hotel table
-- For INSERT: you cannot insert a hotel with the same name that already exists
drop TRIGGER HOTEL_CHANGE;
CREATE TRIGGER HOTEL_CHANGE
ON HOTEL
AFTER UPDATE, INSERT, DELETE
AS
DECLARE @ID INT,@NAME VARCHAR(20), @STARS_NUMBER INT;
IF EXISTS(SELECT * from inserted) AND EXISTS(SELECT * from deleted) --UPDATE
BEGIN
	SELECT @STARS_NUMBER=STARS_NUMBER from inserted i;
	SELECT @ID = ID_HOTEL from inserted i;
	SELECT @NAME= NAME from inserted i;
	IF(@STARS_NUMBER<3) BEGIN
	ROLLBACK PRINT 'Hotels with less than 3 stars cannot be updated'
	END

	ELSE BEGIN
	UPDATE Hotel SET STARS_NUMBER=@STARS_NUMBER WHERE @ID=ID_HOTEL
	PRINT 'The new star number has been determined'
	END
END

IF EXISTS(Select * from inserted) AND NOT EXISTS(Select * from deleted) --INSERT
BEGIN

	SELECT @ID = ID_HOTEL from inserted i;
	SELECT @STARS_NUMBER=STARS_NUMBER from inserted i;
	SELECT @NAME = NAME from inserted i;

	IF NOT EXISTS(SELECT 'X' FROM inserted WHERE @ID=ID_HOTEL AND @NAME=NAME)
	BEGIN
	UPDATE Hotel SET NAME=@NAME WHERE @ID=ID_HOTEL
	PRINT 'A new hotel has been added'
	END

	ELSE
	    BEGIN
	        ROLLBACK
	        PRINT 'You cannot insert the same name' end

END

IF EXISTS(select * FROM deleted) AND NOT EXISTS(Select * from inserted) --DELETE
BEGIN
    ROLLBACK
	PRINT 'You cannot delete records from the Hotel table'
END

--FOR UPDATE
UPDATE HOTEL SET STARS_NUMBER=2 WHERE ID_HOTEL=1;--WON'T CHANGE
UPDATE HOTEL SET STARS_NUMBER=4 WHERE ID_HOTEL=1;--CHANGE

--FOR INSERT
INSERT INTO HOTEL VALUES(1, 'Warwick New York', 4) --SUCH A HOTEL ALREADY EXISTS
INSERT INTO HOTEL VALUES(9, 'New Hotel', 3) --NEW NAME

--FOR DELETE
INSERT INTO HOTEL VALUES(11,'Walk Warsaw',5);
INSERT INTO TRIP VALUES(11,'2022-06-06','2022-06-15',1, 2, 3, 2, 1)
INSERT INTO BOOKING VALUES(9, '2024-09-01', 2, 3, 6) --ADD SAMPLE DATA

DELETE FROM BOOKING WHERE ID_BOOKING=9;
DELETE FROM TRIP WHERE ID_TRIP=11;
DELETE FROM HOTEL WHERE ID_HOTEL=11; --WON'T DELETE

SELECT * FROM HOTEL;

--TRIGGER BEFORE UPDATE CURSOR
-- change number of visa with id 3
drop TRIGGER UpdateVisaNumber;
CREATE TRIGGER UpdateVisaNumber
ON VISA
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ID_VISA INT;
    DECLARE @NEW_NUMBER INT;

    DECLARE CUR CURSOR FOR
    SELECT ID_VISA
    FROM INSERTED;

    OPEN CUR;
    FETCH NEXT FROM CUR INTO @ID_VISA;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Check if the current ID is 3
        IF @ID_VISA = 3
        BEGIN
            -- Your logic to determine the new number for ID 3
            SET @NEW_NUMBER = 234484;

            -- Insert the new record into VISA with the updated NUMBER_VISA
            INSERT INTO VISA (ID_VISA, NUMBER_VISA)
            VALUES (@ID_VISA, @NEW_NUMBER);
        END;

        FETCH NEXT FROM CUR INTO @ID_VISA;
    END;

    CLOSE CUR;
    DEALLOCATE CUR;
END;

--TRIGGER CURSOR BEFORE DELETE



--Procedure result set
--The procedure for inserting a customer with a PESEL number,
    --name and surname that already exists checks and blocks this operation.
-- If it did not exist, it is added as a new customer.
drop PROCEDURE Check_pesel;
CREATE PROCEDURE Check_pesel
@NAME varchar(20),
@SURENAME varchar(20),
@PESEL INT
AS BEGIN
	IF NOT EXISTS (
        SELECT 'X'
        FROM PASSPORT P
        JOIN CUSTOMER K ON P.ID_CUSTOMER = K.ID_CUSTOMER
        WHERE PESELE = @PESEL
    )
	BEGIN
		DECLARE @NEWID INT
		SELECT @NEWID=MAX(ID_CUSTOMER)+1 FROM CUSTOMER
		INSERT INTO CUSTOMER(ID_CUSTOMER, FIRST_NAME, LAST_NAME) VALUES (@NEWID, @NAME, @SURENAME)
		INSERT INTO PASSPORT(ID_PASSPORT, PESELE, ID_CUSTOMER, NUMER)
		VALUES (@NEWID, @PESEL, @NEWID, FLOOR(RAND()*(100000-80000+1))+10)
		PRINT 'The introduction of a new customer was a success'
	END

	ELSE PRINT 'Such a PESEL already exists'
END;

EXEC Check_pesel 'Maryna', 'Kamienieva', 12659874512 --EXIST
EXEC Check_pesel 'Angielina','Mirowska', 02223333356 --NOT EXIST

SELECT * FROM PASSPORT;
SELECT * FROM CUSTOMER;

-- Procedure1 retorn outpyt
--Define procedure which for given DATE_OF_ISSUE will correct date of given person by
--given % ( by default 20) and by output parameter will return date after being
--changed
drop PROCEDURE ChangeTripDate;
CREATE PROCEDURE ChangeTripDate
    @TripID INT,
    @NewStartDate DATE OUTPUT,
    @PercentageChange INT = 20
AS
BEGIN
    DECLARE @OldStartDate DATE;

    -- Get the current start date of the trip
    SELECT @OldStartDate = DATE_OF_ISSUE
    FROM TRIP
    WHERE ID_TRIP = @TripID;

    -- Calculate the new start date based on the percentage change
    SET @NewStartDate = DATEADD(DAY, DATEDIFF(DAY, 0, @OldStartDate) * @PercentageChange / 100, @OldStartDate);

    -- Update the TRIP table with the new start date
    UPDATE TRIP
    SET DATE_OF_ISSUE = @NewStartDate
    WHERE ID_TRIP = @TripID;
END;


-- Procedure 3 RETURN
--Define procedure which by RETURN will give number of customers in table customer.
drop PROCEDURE customer_number;
CREATE PROCEDURE customer_number
AS
BEGIN
DECLARE @num INT;
SELECT @num = COUNT(1) FROM CUSTOMER;
RETURN @num;
END;
DECLARE @x Int;
EXECUTE @x = customer_number;
PRINT @x;


