--TRIGGER BEFORE INSERT CUSTOMER must be  18 years old to make a booking
--SYSDATE returns the current date
--months_between returns number of months between date1 and date2
drop TRIGGER TRIGGER1;
CREATE OR REPLACE TRIGGER TRIGGER1
    BEFORE INSERT
    ON  BOOKING
    FOR EACH ROW
DECLARE
    EXIST INTEGER := 18;
    CUSTOMER_CHECK_BIRTH DATE;
BEGIN
    SELECT DATE_BIRTH
    INTO CUSTOMER_CHECK_BIRTH
    FROM CUSTOMER
    WHERE ID_CUSTOMER = :NEW.ID_CUSTOMER;

    IF MONTHS_BETWEEN(SYSDATE, CUSTOMER_CHECK_BIRTH) < (EXIST * 12) THEN
        RAISE_APPLICATION_ERROR(-20100, 'User WHO IS UNDER 18 CANNOT BOOK A TICKET.');
    END IF;
END;

--TRIGGER BEFORE UPDATE
-- Update visa number of person with id 1
drop TRIGGER TRIGGER2;
CREATE OR REPLACE TRIGGER TRIGGER2
    BEFORE UPDATE
    ON VISA
    FOR EACH ROW
BEGIN
    IF :NEW.ID_VISA = 1 THEN
        :NEW.NUMBER_VISA := 265624;
    END IF;
END;

--TRIGGER BEFORE DELETE
-- delete one payment, because the customer reject the 1 booking
drop TRIGGER TRIGGER3;
CREATE OR REPLACE TRIGGER TRIGGER3
    BEFORE DELETE
    ON PAYMENT
    FOR EACH ROW
DECLARE
    EXIST NUMBER;
BEGIN
    SELECT ID_PAYMENT
    INTO EXIST
    FROM PAYMENT
    WHERE ID_PAYMENT = :OLD.ID_PAYMENT;
    DELETE FROM PAYMENT
    WHERE ID_PAYMENT = EXIST;
END;

--TRIGGER AFTER
--For UPDATE: changes cannot be made for hotels if the number of hotel stars is less than 3
-- For DELETE: cannot delete data from the Hotel table
-- For INSERT: you cannot insert a hotel with the same name that already exists
drop TRIGGER HOTEL_CHANGE;
CREATE OR REPLACE TRIGGER HOTEL_CHANGE
AFTER INSERT OR UPDATE OR DELETE
ON HOTEL
FOR EACH ROW
DECLARE
    v_ID NUMBER(10);
    v_NAME VARCHAR2(20);
    v_STARS_NUMBER NUMBER(10);
    v_COUNT NUMBER(10);
BEGIN
    -- FOR UPDATE
    IF UPDATING THEN
        v_STARS_NUMBER := :NEW.STARS_NUMBER;
        v_ID := :NEW.ID_HOTEL;
        v_NAME := :NEW.NAME;

        IF v_STARS_NUMBER < 3 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Hotels with less than 3 stars cannot be updated');
        ELSE
            UPDATE Hotel SET STARS_NUMBER = v_STARS_NUMBER WHERE ID_HOTEL = v_ID;
            DBMS_OUTPUT.PUT_LINE('The new star number has been determined');
        END IF;
    END IF;

    -- FOR INSERT
    IF INSERTING THEN
        v_ID := :NEW.ID_HOTEL;
        v_STARS_NUMBER := :NEW.STARS_NUMBER;
        v_NAME := :NEW.NAME;

        -- Check if a hotel with the same name already exists
        SELECT COUNT(*) INTO v_COUNT FROM Hotel WHERE ID_HOTEL = v_ID AND NAME = v_NAME;

        IF v_COUNT = 0 THEN
            UPDATE Hotel SET NAME = v_NAME WHERE ID_HOTEL = v_ID;
            DBMS_OUTPUT.PUT_LINE('A new hotel has been added');
        ELSE
            RAISE_APPLICATION_ERROR(-20002, 'You cannot insert the same name');
        END IF;
    END IF;

    -- FOR DELETE
    IF DELETING THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20003, 'You cannot delete records from the Hotel table');
    END IF;
END;


--TRIGGER AFTER DELETE
-- We check the sale date of the trip. If the customer payed for a booking we remove him from the database
drop TRIGGER check_payment;
CREATE OR REPLACE TRIGGER check_payment
AFTER DELETE
ON BOOKING
FOR EACH ROW
DECLARE
    v_payment_date DATE;
BEGIN
    SELECT DATE_SELLING
    INTO v_payment_date
    FROM BOOKING
    WHERE DATE_SELLING = :OLD.DATE_SELLING;

    IF v_payment_date IS NOT NULL THEN
        IF :OLD.DATE_SELLING > v_payment_date THEN
            DELETE FROM CUSTOMER WHERE ID_CUSTOMER = :OLD.ID_CUSTOMER;
            DBMS_OUTPUT.PUT_LINE('Customer removed from the database after a successful payment.');
        END IF;
    END IF;
END;

--Procedure
--Prints full statristics about given user
drop PROCEDURE PROCEDURE1;
CREATE OR REPLACE PROCEDURE PROCEDURE1(P_CUSTOMER_ID IN INTEGER)
AS
    FULL_NAME VARCHAR2(20);
    VISA_COUNT INTEGER;
    TOTAL_TRANSPORT INTEGER;
    TOTAL_PAYMENTS INTEGER;
    TOTAL_TRIP DATE;
    TOTAL_BOOKING INTEGER;
BEGIN
    SELECT FIRST_NAME || ' ' || LAST_NAME
    INTO FULL_NAME
    FROM CUSTOMER
    WHERE ID_CUSTOMER = P_CUSTOMER_ID;

    SELECT COUNT(*)
    INTO VISA_COUNT
    FROM VISA
    WHERE ID_VISA = P_CUSTOMER_ID;

    SELECT COUNT(*)
    INTO TOTAL_TRANSPORT
    FROM TRANSPORT
    WHERE ID_TRANSPORT = P_CUSTOMER_ID;

    SELECT COUNT(*)
    INTO TOTAL_PAYMENTS
    FROM PAYMENT
    WHERE ID_PAYMENT = P_CUSTOMER_ID;

    SELECT MAX(DATE_OF_ISSUE)
    INTO TOTAL_TRIP
    FROM TRIP T
    JOIN BOOKING B ON T.ID_TRIP = B.ID_TRIP
    WHERE B.ID_CUSTOMER = P_CUSTOMER_ID;

    SELECT COUNT(*)
    INTO TOTAL_BOOKING
    FROM BOOKING
    WHERE ID_CUSTOMER = P_CUSTOMER_ID;

    DBMS_OUTPUT.PUT_LINE('User statistics for: ' || FULL_NAME);
    DBMS_OUTPUT.PUT_LINE('Total VISAs: ' || VISA_COUNT);
    DBMS_OUTPUT.PUT_LINE('Total used transport: ' || TOTAL_TRANSPORT);
    DBMS_OUTPUT.PUT_LINE('Total payments: ' || TOTAL_PAYMENTS);
    DBMS_OUTPUT.PUT_LINE('Last trip date: ' || TO_CHAR(TOTAL_TRIP, 'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('Total bookings: ' || TOTAL_BOOKING);

END;

--CURSOR + procedure 1
-- Will be updated payments for every customer for 5% increase
drop PROCEDURE UPDATE_PAYMENTS;
CREATE OR REPLACE PROCEDURE UPDATE_PAYMENTS
AS
  customer_id INT;
  customer_paymenT INT;

  CURSOR cur IS
    SELECT ID_CUSTOMER, AMOUNT_BOOKINGS
    FROM CUSTOMER;

BEGIN
  OPEN cur;
  LOOP
    EXIT WHEN cur%NOTFOUND;
    FETCH cur INTO customer_id, customer_paymenT;

    -- updating payments for customers - 5% increase
    UPDATE PAYMENT
    SET AMOUNT = AMOUNT + ROUND(AMOUNT * 0.05)
    WHERE ID_PAYMENT = customer_id;

    DBMS_OUTPUT.PUT_LINE('Updated payment for Customer: ' || customer_id);
    DBMS_OUTPUT.PUT_LINE('Previous Amount: ' || customer_paymenT);
    DBMS_OUTPUT.PUT_LINE('New Amount: ' || (customer_paymenT + ROUND(customer_paymenT * 0.05)));

  END LOOP;
  CLOSE cur;
END;

--EXCEPTION
--if customer already have visa, just print it. if not do an exception that the agency should create it
-- SQLERRM function returns the error message associated with an error code.
drop PROCEDURE CHECK_VISA;
CREATE OR REPLACE PROCEDURE CHECK_VISA
(P_CUSTOMER_ID INT)
AS
    COUNTED NUMBER;
BEGIN
    -- Check if the customer already has a visa
    SELECT COUNT(*)
    INTO COUNTED
    FROM VISA V
    JOIN CUSTOMER K ON V.ID_VISA = K.ID_CUSTOMER
    WHERE ID_CUSTOMER = P_CUSTOMER_ID;

    IF COUNTED > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Customer already has a visa with number: ' ||(SELECT NUMBER_VISA
                                                                            FROM VISA V
                                                                            JOIN CUSTOMER K ON V.ID_VISA = K.ID_CUSTOMER
                                                                            WHERE ID_CUSTOMER = P_CUSTOMER_ID));
    ELSE
        -- Customer doesn't have a visa
        RAISE_APPLICATION_ERROR(-20001, 'Customer does not have a visa. Create a new visa.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
END;

--
-- CREATE OR REPLACE PROCEDURE CHECK_VISA
-- (P_CUSTOMER_ID INT)
-- AS
--     COUNTED NUMBER;
--     VISA_NUMBER VARCHAR2(20);
-- BEGIN
--     -- Check if the customer already has a visa
--     SELECT COUNT(*)
--     INTO COUNTED
--     FROM VISA V
--     JOIN CUSTOMER K ON V.ID_VISA = K.ID_CUSTOMER
--     WHERE ID_CUSTOMER = P_CUSTOMER_ID;
--
--     IF COUNTED > 0 THEN
--         -- Assign the result of the subquery to the variable VISA_NUMBER
--         SELECT NUMBER_VISA
--         INTO VISA_NUMBER
--         FROM VISA V
--         JOIN CUSTOMER K ON V.ID_VISA = K.ID_CUSTOMER
--         WHERE ID_CUSTOMER = P_CUSTOMER_ID;
--
--         DBMS_OUTPUT.PUT_LINE('Customer already has a visa with number: ' || VISA_NUMBER);
--     ELSE
--         -- Customer doesn't have a visa
--         RAISE_APPLICATION_ERROR(-20001, 'Customer does not have a visa. Create a new visa.');
--     END IF;
--
-- EXCEPTION
--     WHEN OTHERS THEN
--         DBMS_OUTPUT.PUT_LINE('Error: ' || SQLCODE || ' - ' || SQLERRM);
-- END;