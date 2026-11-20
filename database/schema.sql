
-- ============================================================
-- School Equipment Borrowing System - MySQL (InnoDB) DDL (BCNF)
-- Target: MySQL 8.0.16+ (CHECK constraints enforced; UUID() defaults need 8.0.13+)
-- ============================================================

CREATE DATABASE IF NOT EXISTS equipment_borrowing
    CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE equipment_borrowing;

DROP TABLE IF EXISTS return_record;
DROP TABLE IF EXISTS borrowing_details;
DROP TABLE IF EXISTS borrowing;
DROP TABLE IF EXISTS equipment;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS staff;
DROP TABLE IF EXISTS borrower;

-- ------------------------------------------------------------
-- BORROWER
-- ------------------------------------------------------------
CREATE TABLE borrower (
    borrower_id     CHAR(36)     NOT NULL DEFAULT (UUID()),
    full_name       VARCHAR(100) NOT NULL,
    student_number  VARCHAR(20)  NOT NULL,
    course          VARCHAR(100) NULL,
    contact_number  VARCHAR(20)  NULL,
    CONSTRAINT pk_borrower PRIMARY KEY (borrower_id),
    CONSTRAINT uq_borrower_student_number UNIQUE (student_number),
    CONSTRAINT ck_borrower_full_name CHECK (CHAR_LENGTH(TRIM(full_name)) > 0),
    CONSTRAINT ck_borrower_contact   CHECK (contact_number IS NULL
                                            OR contact_number REGEXP '^[0-9+() -]{7,20}$')
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- STAFF
-- ------------------------------------------------------------
CREATE TABLE staff (
    staff_id        CHAR(36)     NOT NULL DEFAULT (UUID()),
    full_name       VARCHAR(100) NOT NULL,
    username        VARCHAR(50)  NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,   -- store a hash, never plain text
    CONSTRAINT pk_staff PRIMARY KEY (staff_id),
    CONSTRAINT uq_staff_username UNIQUE (username),
    CONSTRAINT ck_staff_full_name CHECK (CHAR_LENGTH(TRIM(full_name)) > 0),
    CONSTRAINT ck_staff_username  CHECK (CHAR_LENGTH(username) >= 4)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- CATEGORY
-- ------------------------------------------------------------
CREATE TABLE category (
    category_id     CHAR(36)     NOT NULL DEFAULT (UUID()),
    category_name   VARCHAR(50)  NOT NULL,
    description     TEXT         NULL,
    CONSTRAINT pk_category PRIMARY KEY (category_id),
    CONSTRAINT uq_category_name UNIQUE (category_name)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- EQUIPMENT
-- ------------------------------------------------------------
CREATE TABLE equipment (
    equipment_id        CHAR(36)     NOT NULL DEFAULT (UUID()),
    category_id         CHAR(36)     NOT NULL,
    equipment_name      VARCHAR(100) NOT NULL,
    quantity            INT UNSIGNED NOT NULL DEFAULT 0,
    available_quantity  INT UNSIGNED NOT NULL DEFAULT 0,
    CONSTRAINT pk_equipment PRIMARY KEY (equipment_id),
    CONSTRAINT uq_equipment_name_category UNIQUE (category_id, equipment_name),
    CONSTRAINT fk_equipment_category
        FOREIGN KEY (category_id) REFERENCES category (category_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_equipment_available CHECK (available_quantity <= quantity)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- BORROWING  (one transaction per borrower per visit)
-- TIMESTAMP is stored in UTC and converted to the session time zone
-- ------------------------------------------------------------
CREATE TABLE borrowing (
    borrowing_id    CHAR(36)     NOT NULL DEFAULT (UUID()),
    borrower_id     CHAR(36)     NOT NULL,
    staff_id        CHAR(36)     NOT NULL,
    borrow_date     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_date        TIMESTAMP    NOT NULL,
    status          VARCHAR(10)  NOT NULL DEFAULT 'Borrowed',
    CONSTRAINT pk_borrowing PRIMARY KEY (borrowing_id),
    CONSTRAINT fk_borrowing_borrower
        FOREIGN KEY (borrower_id) REFERENCES borrower (borrower_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_borrowing_staff
        FOREIGN KEY (staff_id) REFERENCES staff (staff_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_borrowing_dates  CHECK (due_date >= borrow_date),
    CONSTRAINT ck_borrowing_status CHECK (status IN ('Borrowed', 'Returned', 'Overdue')),
    INDEX idx_borrowing_status_due (status, due_date)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- BORROWING_DETAILS  (associative / weak entity: Borrowing M:N Equipment)
-- Composite PK = identifying relationships to both parents
-- ------------------------------------------------------------
CREATE TABLE borrowing_details (
    borrowing_id    CHAR(36)     NOT NULL,
    equipment_id    CHAR(36)     NOT NULL,
    quantity        INT UNSIGNED NOT NULL,
    CONSTRAINT pk_borrowing_details PRIMARY KEY (borrowing_id, equipment_id),
    CONSTRAINT fk_details_borrowing
        FOREIGN KEY (borrowing_id) REFERENCES borrowing (borrowing_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_details_equipment
        FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT ck_details_quantity CHECK (quantity > 0)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- RETURN_RECORD  (0..1 per borrowing, enforced by UNIQUE on borrowing_id)
-- ------------------------------------------------------------
CREATE TABLE return_record (
    return_id            CHAR(36)    NOT NULL DEFAULT (UUID()),
    borrowing_id         CHAR(36)    NOT NULL,
    return_date          TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    equipment_condition  VARCHAR(10) NOT NULL DEFAULT 'Good',
    CONSTRAINT pk_return_record PRIMARY KEY (return_id),
    CONSTRAINT uq_return_borrowing UNIQUE (borrowing_id),
    CONSTRAINT fk_return_borrowing
        FOREIGN KEY (borrowing_id) REFERENCES borrowing (borrowing_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT ck_return_condition CHECK (equipment_condition IN ('Good', 'Damaged', 'Lost'))
) ENGINE=InnoDB;

-- Note: InnoDB automatically indexes foreign key columns, so no extra
-- FK indexes are needed (unlike PostgreSQL).
