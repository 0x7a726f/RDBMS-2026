
DROP DATABASE IF EXISTS yg_eupolis_hospital;
CREATE DATABASE yg_eupolis_hospital
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE yg_eupolis_hospital;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS entity_image;
DROP TABLE IF EXISTS image_asset;
DROP TABLE IF EXISTS hospitalization_evaluation;
DROP TABLE IF EXISTS prescription;
DROP TABLE IF EXISTS patient_allergy;
DROP TABLE IF EXISTS drug_active_substance;
DROP TABLE IF EXISTS active_substance;
DROP TABLE IF EXISTS drug;
DROP TABLE IF EXISTS procedure_participant;
DROP TABLE IF EXISTS procedure_event;
DROP TABLE IF EXISTS procedure_catalog;
DROP TABLE IF EXISTS lab_test;
DROP TABLE IF EXISTS lab_test_catalog;
DROP TABLE IF EXISTS hospitalization_doctor;
DROP TABLE IF EXISTS hospitalization;
DROP TABLE IF EXISTS emergency_visit;
DROP TABLE IF EXISTS shift_assignment;
DROP TABLE IF EXISTS department_shift;
DROP TABLE IF EXISTS operating_place;
DROP TABLE IF EXISTS ken;
DROP TABLE IF EXISTS icd10_diagnosis;
DROP TABLE IF EXISTS emergency_contact;
DROP TABLE IF EXISTS bed;
DROP TABLE IF EXISTS doctor_department;
DROP TABLE IF EXISTS administrative_staff;
DROP TABLE IF EXISTS nurse;
DROP TABLE IF EXISTS doctor;
DROP TABLE IF EXISTS patient;
DROP TABLE IF EXISTS department;
DROP TABLE IF EXISTS personnel;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE personnel (
    amka                    CHAR(11) PRIMARY KEY,
    first_name              VARCHAR(80) NOT NULL,
    last_name               VARCHAR(80) NOT NULL,
    age                     INT NOT NULL,
    email                   VARCHAR(255) NOT NULL,
    phone_number            VARCHAR(30) NOT NULL,
    hiring_date             DATE NOT NULL,
    personnel_type          VARCHAR(20) NOT NULL,
    CONSTRAINT uq_personnel_email UNIQUE (email),
    CONSTRAINT ck_personnel_age CHECK (age BETWEEN 18 AND 100),
    CONSTRAINT ck_personnel_type CHECK (personnel_type IN ('DOCTOR', 'NURSE', 'ADMIN'))
);

CREATE TABLE doctor (
    amka                    CHAR(11) PRIMARY KEY,
    license_number          VARCHAR(50) NOT NULL,
    specialization          VARCHAR(120) NOT NULL,
    doctor_rank             VARCHAR(20) NOT NULL,
    supervisor_amka         CHAR(11) NULL,
    CONSTRAINT fk_doctor_personnel
        FOREIGN KEY (amka) REFERENCES personnel(amka)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_doctor_supervisor
        FOREIGN KEY (supervisor_amka) REFERENCES doctor(amka)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT uq_doctor_license UNIQUE (license_number),
    CONSTRAINT ck_doctor_rank CHECK (doctor_rank IN ('RESIDENT', 'CONSULTANT_B', 'CONSULTANT_A', 'DIRECTOR'))
);

CREATE TABLE nurse (
    amka                    CHAR(11) PRIMARY KEY,
    degree                  VARCHAR(20) NOT NULL,
    department_id           INT NOT NULL,
    CONSTRAINT fk_nurse_personnel
        FOREIGN KEY (amka) REFERENCES personnel(amka)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_nurse_department
        FOREIGN KEY (department_id) REFERENCES department(department_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT ck_nurse_rank CHECK (nurse_rank IN ('ASSISTANT_NURSE', 'NURSE', 'HEAD_NURSE'))
);

CREATE TABLE administrative_staff (
    amka                    CHAR(11) PRIMARY KEY,
    admin_role              VARCHAR(120) NOT NULL,
    office_work             VARCHAR(120) NOT NULL,
    department_id           INT NOT NULL,
    CONSTRAINT fk_admin_personnel
        FOREIGN KEY (amka) REFERENCES personnel(amka)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_admin_department
        FOREIGN KEY (department_id) REFERENCES department(department_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE department (
    department_id           INT AUTO_INCREMENT PRIMARY KEY,
    department_name         VARCHAR(120) NOT NULL,
    description             TEXT NULL,
    bed_capacity            INT NOT NULL,
    floor_building          VARCHAR(120) NOT NULL,
    manager_doctor_amka     CHAR(11) NULL,
    CONSTRAINT uq_department_name UNIQUE (department_name),
    CONSTRAINT ck_department_bed_capacity CHECK (bed_capacity >= 0)
    CONSTRAINT fk_department_manager
    FOREIGN KEY (manager_doctor_amka) REFERENCES doctor(amka)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
    CONSTRAINT uq_department_manager UNIQUE (manager_doctor_amka);
);

CREATE TABLE doctor_department (
    doctor_amka             CHAR(11) NOT NULL,
    department_id           INT NOT NULL,
    PRIMARY KEY (doctor_amka, department_id),
    CONSTRAINT fk_doctor_department_doctor
        FOREIGN KEY (doctor_amka) REFERENCES doctor(amka)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_doctor_department_department
        FOREIGN KEY (department_id) REFERENCES department(department_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE bed (
    bed_id                   INT AUTO_INCREMENT PRIMARY KEY,
    department_id            INT NOT NULL,
    bed_type                 VARCHAR(20) NOT NULL,
    bed_status               VARCHAR(20) NOT NULL,
    CONSTRAINT fk_bed_department
        FOREIGN KEY (department_id) REFERENCES department(department_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT ck_bed_type CHECK (bed_type IN ('ICU', 'SINGLE', 'MULTI_BED')),
    CONSTRAINT ck_bed_status CHECK (bed_status IN ('AVAILABLE', 'OCCUPIED', 'MAINTENANCE'))
) ENGINE=InnoDB;

CREATE TABLE patient (
    patient_amka            CHAR(11) PRIMARY KEY,
    first_name              VARCHAR(80) NOT NULL,
    last_name               VARCHAR(80) NOT NULL,
    father_name             VARCHAR(80) NOT NULL,
    age                     INT NOT NULL,
    gender                  VARCHAR(20) NOT NULL,
    weight_kg               DECIMAL(5,2) NULL,
    height_cm               DECIMAL(5,2) NULL,
    address_line            VARCHAR(255) NOT NULL,
    phone_number            VARCHAR(30) NOT NULL,
    email                   VARCHAR(255) NULL,
    profession              VARCHAR(120) NULL,
    nationality             VARCHAR(80) NULL,
    insurance_provider      VARCHAR(120) NOT NULL,
    CONSTRAINT uq_patient_email UNIQUE (email),
    CONSTRAINT ck_patient_age CHECK (age BETWEEN 0 AND 120),
    CONSTRAINT ck_patient_weight CHECK (weight_kg IS NULL OR weight_kg > 0),
    CONSTRAINT ck_patient_height CHECK (height_cm IS NULL OR height_cm > 0)
);

CREATE TABLE emergency_contact (
    patient_amka            CHAR(11) NOT NULL,
    first_name              VARCHAR(80) NOT NULL,
    last_name               VARCHAR(80) NOT NULL,
    phone_number            VARCHAR(30) NOT NULL,
    email                   VARCHAR(255) NULL,
    PRIMARY KEY (patient_amka, first_name, last_name, phone_number),
    CONSTRAINT fk_emergency_contact_patient
        FOREIGN KEY (patient_amka) REFERENCES patient(patient_amka)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE icd10_diagnosis (
    icd10_code              VARCHAR(20) PRIMARY KEY,
    icd10_description       VARCHAR(500) NOT NULL
);

CREATE TABLE ken (
    ken_code                VARCHAR(20) PRIMARY KEY,
    ken_description         VARCHAR(500) NOT NULL,
    basic_cost              DECIMAL(12,2) NOT NULL,
    mean_duration_days      INT NOT NULL,
    extra_daily_cost        DECIMAL(12,2) NOT NULL,/*numeric*/
    CONSTRAINT ck_ken_costs CHECK (basic_cost >= 0 AND extra_daily_cost >= 0),
    CONSTRAINT ck_ken_duration CHECK (mean_duration_days >= 0)
);

CREATE TABLE operating_place (
    place_id                INT AUTO_INCREMENT PRIMARY KEY,
    place_name              VARCHAR(120) NOT NULL,
    place_type              VARCHAR(30) NOT NULL,
    place_status            VARCHAR(20) NOT NULL,
    CONSTRAINT uq_place_name UNIQUE (place_name),
    CONSTRAINT ck_place_type CHECK (place_type IN ('OPERATING_ROOM', 'PROCEDURE_ROOM')),
    CONSTRAINT ck_place_status CHECK (place_status IN ('AVAILABLE', 'OCCUPIED', 'MAINTENANCE'))
);

CREATE TABLE department_shift (
    shift_id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    department_id           INT NOT NULL,
    shift_date              DATE NOT NULL,
    shift_type              VARCHAR(20) NOT NULL,
    start_time              TIME NOT NULL,
    end_time                TIME NOT NULL,
    CONSTRAINT fk_department_shift_department
        FOREIGN KEY (department_id) REFERENCES department(department_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT uq_department_shift UNIQUE (department_id, shift_date, shift_type),
    CONSTRAINT ck_shift_type CHECK (shift_type IN ('MORNING', 'AFTERNOON', 'NIGHT')),
    CONSTRAINT ck_shift_time CHECK (
        (shift_type = 'MORNING'   AND start_time = '07:00:00' AND end_time = '15:00:00') OR
        (shift_type = 'AFTERNOON' AND start_time = '15:00:00' AND end_time = '23:00:00') OR
        (shift_type = 'NIGHT'     AND start_time = '23:00:00' AND end_time = '07:00:00')
    )
);

CREATE TABLE shift_assignment (
    shift_id                BIGINT NOT NULL,
    personnel_amka          CHAR(11) NOT NULL,
    assigned_role           VARCHAR(40) NULL,
    PRIMARY KEY (shift_id, personnel_amka),
    CONSTRAINT fk_shift_assignment_shift
        FOREIGN KEY (shift_id) REFERENCES department_shift(shift_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_shift_assignment_personnel
        FOREIGN KEY (personnel_amka) REFERENCES personnel(amka)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE emergency_visit (
    visit_id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    patient_amka            CHAR(11) NOT NULL,
    triage_nurse_amka       CHAR(11) NOT NULL,
    arrival_ts              DATETIME NOT NULL,
    symptoms                TEXT NOT NULL,
    emergency_level         INT NOT NULL,
    service_start_ts        DATETIME NULL,
    disposition             VARCHAR(20) NOT NULL,
    discharge_instructions  TEXT NULL,
    CONSTRAINT fk_emergency_visit_patient
        FOREIGN KEY (patient_amka) REFERENCES patient(patient_amka)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_emergency_visit_triage_nurse
        FOREIGN KEY (triage_nurse_amka) REFERENCES nurse(amka)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT ck_emergency_level CHECK (emergency_level BETWEEN 1 AND 5),
    CONSTRAINT ck_emergency_disposition CHECK (disposition IN ('DISCHARGED', 'HOSPITALIZED')),
    CONSTRAINT ck_emergency_times CHECK (
        service_start_ts IS NULL OR service_start_ts >= arrival_ts
    )
);

CREATE TABLE hospitalization (
    hosp_id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    patient_amka             CHAR(11) NOT NULL,
    department_id            INT NOT NULL,
    bed_id                   INT NOT NULL,
    ken_code                 VARCHAR(20) NOT NULL,
    admission_ts             DATETIME NOT NULL,
    discharge_ts             DATETIME NULL,
    admission_icd10_code     VARCHAR(20) NOT NULL,
    discharge_icd10_code     VARCHAR(20) NULL,
    total_cost               DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_hosp_patient
        FOREIGN KEY (patient_amka) REFERENCES patient(patient_amka)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_hosp_department
        FOREIGN KEY (department_id) REFERENCES department(department_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_hosp_bed
        FOREIGN KEY (bed_id) REFERENCES bed(bed_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_hosp_ken
        FOREIGN KEY (ken_code) REFERENCES ken(ken_code)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_hosp_admission_icd10
        FOREIGN KEY (admission_icd10_code) REFERENCES icd10_diagnosis(icd10_code)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_hosp_discharge_icd10
        FOREIGN KEY (discharge_icd10_code) REFERENCES icd10_diagnosis(icd10_code)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT uq_hosp_patient_pair UNIQUE (hosp_id, patient_amka),
    CONSTRAINT ck_hosp_cost CHECK (total_cost >= 0),
    CONSTRAINT ck_hosp_dates CHECK (discharge_ts IS NULL OR discharge_ts >= admission_ts)
);

CREATE TABLE hospitalization_doctor (
    hosp_id                  BIGINT NOT NULL,
    doctor_amka              CHAR(11) NOT NULL,
    PRIMARY KEY (hosp_id, doctor_amka),
    CONSTRAINT fk_hosp_doctor_hosp
        FOREIGN KEY (hosp_id) REFERENCES hospitalization(hosp_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_hosp_doctor_doctor
        FOREIGN KEY (doctor_amka) REFERENCES doctor(amka)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
);

CREATE TABLE lab_test_catalog (
    test_code               VARCHAR(30) PRIMARY KEY,
    test_name               VARCHAR(255) NOT NULL,
    test_type               VARCHAR(80) NOT NULL
);

CREATE TABLE lab_test (
    test_id                 BIGINT AUTO_INCREMENT PRIMARY KEY,
    hosp_id                 BIGINT NOT NULL,
    test_code               VARCHAR(30) NOT NULL,
    ordered_by_doctor_amka  CHAR(11) NOT NULL,
    test_datetime           DATETIME NOT NULL,
    result_text             TEXT NULL,
    CONSTRAINT fk_lab_test_hosp
        FOREIGN KEY (hosp_id) REFERENCES hospitalization(hosp_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_lab_test_catalog
        FOREIGN KEY (test_code) REFERENCES lab_test_catalog(test_code)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_lab_test_doctor
        FOREIGN KEY (ordered_by_doctor_amka) REFERENCES doctor(amka)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
);

CREATE TABLE procedure_catalog (
    procedure_code          VARCHAR(30) PRIMARY KEY,
    procedure_name          VARCHAR(255) NOT NULL,
    procedure_category      VARCHAR(20) NOT NULL,
    required_place_type     VARCHAR(30) NOT NULL,
    CONSTRAINT ck_procedure_category CHECK (procedure_category IN ('SURGICAL', 'DIAGNOSTIC', 'THERAPEUTIC')),
    CONSTRAINT ck_required_place_type CHECK (required_place_type IN ('OPERATING_ROOM', 'PROCEDURE_ROOM'))
);

CREATE TABLE procedure_event (
    procedure_event_id      BIGINT AUTO_INCREMENT PRIMARY KEY,
    hosp_id                 BIGINT NOT NULL,
    procedure_code          VARCHAR(30) NOT NULL,
    place_id                INT NOT NULL,
    chief_surgeon_amka      CHAR(11) NOT NULL,
    start_ts                DATETIME NOT NULL,
    end_ts                  DATETIME NOT NULL,
    actual_duration_min     INT NOT NULL,
    CONSTRAINT fk_proc_event_hosp
        FOREIGN KEY (hosp_id) REFERENCES hospitalization(hosp_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_proc_event_catalog
        FOREIGN KEY (procedure_code) REFERENCES procedure_catalog(procedure_code)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_proc_event_place
        FOREIGN KEY (place_id) REFERENCES operating_place(place_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_proc_event_chief
        FOREIGN KEY (chief_surgeon_amka) REFERENCES doctor(amka)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT ck_proc_event_times CHECK (end_ts > start_ts),
    CONSTRAINT ck_proc_event_duration CHECK (actual_duration_min > 0),
);

CREATE TABLE procedure_participant (
    procedure_event_id      BIGINT NOT NULL,
    personnel_amka          CHAR(11) NOT NULL,
    PRIMARY KEY (procedure_event_id, personnel_amka),
    CONSTRAINT fk_proc_participant_event
        FOREIGN KEY (procedure_event_id) REFERENCES procedure_event(procedure_event_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_proc_participant_personnel
        FOREIGN KEY (personnel_amka) REFERENCES personnel(amka)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE drug (
    drug_id                 VARCHAR(80) PRIMARY KEY,
    drug_name               VARCHAR(255) NOT NULL,
);

CREATE TABLE active_substance (
    substance_id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    substance_name          VARCHAR(255) NOT NULL,
    CONSTRAINT uq_substance_name UNIQUE (substance_name)
);

CREATE TABLE drug_active_substance (
    drug_id                 VARCHAR(80) NOT NULL,
    substance_id            BIGINT NOT NULL,
    PRIMARY KEY (drug_id, substance_id),
    CONSTRAINT fk_das_drug
        FOREIGN KEY (drug_id) REFERENCES drug(drug_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_das_substance
        FOREIGN KEY (substance_id) REFERENCES active_substance(substance_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE patient_allergy (
    patient_amka            CHAR(11) NOT NULL,
    substance_id            BIGINT NOT NULL,
    PRIMARY KEY (patient_amka, substance_id),
    CONSTRAINT fk_patient_allergy_patient
        FOREIGN KEY (patient_amka) REFERENCES patient(patient_amka)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_patient_allergy_substance
        FOREIGN KEY (substance_id) REFERENCES active_substance(substance_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

CREATE TABLE prescription (
    prescription_id         BIGINT AUTO_INCREMENT PRIMARY KEY,
    hosp_id                 BIGINT NOT NULL,
    patient_amka            CHAR(11) NOT NULL,
    doctor_amka             CHAR(11) NOT NULL,
    drug_id                 VARCHAR(80) NOT NULL,
    dosage                  VARCHAR(120) NOT NULL,
    frequency               VARCHAR(120) NOT NULL,
    start_datetime          DATETIME NOT NULL,
    end_datetime            DATETIME NULL,
    CONSTRAINT fk_prescription_hosp_patient
        FOREIGN KEY (hosp_id, patient_amka) REFERENCES hospitalization(hosp_id, patient_amka)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_prescription_doctor
        FOREIGN KEY (doctor_amka) REFERENCES doctor(amka)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_prescription_drug
        FOREIGN KEY (drug_id) REFERENCES drug(drug_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT uq_prescription UNIQUE (doctor_amka, patient_amka, drug_id, start_datetime),
    CONSTRAINT ck_prescription_dates CHECK (end_datetime IS NULL OR end_datetime >= start_datetime)
);

CREATE TABLE hospitalization_evaluation (
    hosp_id                         BIGINT PRIMARY KEY,
    evaluation_date                DATE NOT NULL,
    medical_care_score             INT NOT NULL,
    nursing_care_score             INT NOT NULL,
    cleanliness_score              INT NOT NULL,
    food_score                     INT NOT NULL,
    overall_experience_score       INT NOT NULL,
    comments                       TEXT NULL,
    CONSTRAINT fk_eval_hosp
        FOREIGN KEY (hosp_id) REFERENCES hospitalization(hosp_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT ck_eval_medical CHECK (medical_care_score BETWEEN 1 AND 5),
    CONSTRAINT ck_eval_nursing CHECK (nursing_care_score BETWEEN 1 AND 5),
    CONSTRAINT ck_eval_cleanliness CHECK (cleanliness_score BETWEEN 1 AND 5),
    CONSTRAINT ck_eval_food CHECK (food_score BETWEEN 1 AND 5),
    CONSTRAINT ck_eval_overall CHECK (overall_experience_score BETWEEN 1 AND 5)
);

CREATE TABLE image_asset (
    image_id                 BIGINT AUTO_INCREMENT PRIMARY KEY,
    image_url                VARCHAR(500) NOT NULL,
    alt_text                 VARCHAR(500) NOT NULL
);

CREATE TABLE entity_image (
    entity_name              VARCHAR(64) NOT NULL,
    entity_pk                VARCHAR(64) NOT NULL,
    image_id                 BIGINT NOT NULL,
    entity_description       TEXT NULL,
    PRIMARY KEY (entity_name, entity_pk, image_id),
    CONSTRAINT fk_entity_image_asset
        FOREIGN KEY (image_id) REFERENCES image_asset(image_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

/* Indexes for the requested queries */

CREATE INDEX idx_doctor_specialization_rank /*Για ερώτημα 2, μπορούμε να βρούμε την ειδικότητα και να συνεχίσει πιο γρήγορα το query*/
    ON doctor (specialization, doctor_rank);

CREATE INDEX idx_doctor_supervisor /*Για ερώτημα 13 για να βρούμε την σειρά ιεραρχίας*/
    ON doctor (supervisor_amka);

CREATE INDEX idx_nurse_department_rank /*Για Q8 και για Q12 για να βρούμε τους νοσηλευτές ενός τμήματος με συγκεκριμένη βαθμίδα πιο γρήγορα*/
    ON nurse (department_id, nurse_rank);

CREATE INDEX idx_admin_department_role /*To ίδιο με το προηγούμενο για το διοικητικό προσωπικό για Q8 και Q12 για να βρούμε τους διοικητικούς ενός τμήματος με συγκεκριμένο ρόλο πιο γρήγορα*/
    ON administrative_staff (department_id, admin_role);

CREATE INDEX idx_doctor_department_department /*Q12 για να βρούμε τους γιατρούς ενός τμήματος πιο γρήγορα*/
    ON doctor_department (department_id, doctor_amka);

CREATE INDEX idx_shift_department_date_type 
    ON department_shift (department_id, shift_date, shift_type); /* Q8, Q12 για να βρούμε τις βάρδιες ενός τμήματος σε συγκεκριμένη ημερομηνία και τύπο πιο γρήγορα */

CREATE INDEX idx_shift_assignment_personnel
    ON shift_assignment (personnel_amka, shift_id); /* Q8, Q12 για να βρούμε τις βάρδιες ενός νοσηλευτή ή διοικητικού προσωπικού πιο γρήγορα */

CREATE INDEX idx_emergency_visit_level_arrival /* Q15 για να βρούμε τις επείγουσες επισκέψεις με συγκεκριμένο επίπεδο επείγοντος και χρονικό διάστημα άφιξης πιο γρήγορα */
    ON emergency_visit (emergency_level, arrival_ts);

CREATE INDEX idx_emergency_visit_referred_department /* Q15 για να βρούμε τις επείγουσες επισκέψεις που παραπέμφθηκαν σε συγκεκριμένο τμήμα πιο γρήγορα */
    ON emergency_visit (referred_department_id);

CREATE INDEX idx_hosp_patient_dept_dates /*Q3, Q6 , Q9 για να βρούμε τις νοσηλείες ενός ασθενή σε συγκεκριμένο τμήμα και χρονικό διάστημα πιο γρήγορα*/
    ON hospitalization (patient_amka, department_id, admission_ts, discharge_ts);

CREATE INDEX idx_hosp_department_admission /*Q1 για να βρούμε τις νοσηλείες ενός τμήματος με συγκεκριμένη ημερομηνία εισαγωγής πιο γρήγορα*/
    ON hospitalization (department_id, admission_ts);

CREATE INDEX idx_hosp_ken /*Q1 για να βρούμε τις νοσηλείες με συγκεκριμένο κεν πιο γρήγορα*/
    ON hospitalization (ken_code);

CREATE INDEX idx_hosp_admission_icd10 /*Q14 για να βρούμε τις νοσηλείες με συγκεκριμένο κωδικό διάγνωσης εισαγωγής πιο γρήγορα*/
    ON hospitalization (admission_icd10_code);

CREATE INDEX idx_lab_test_hosp_code /* Μαλλον για σβησιμο */
    ON lab_test (hosp_id, test_code, test_datetime);

CREATE INDEX idx_lab_test_ordering_doctor /* Μαλλον για σβησιμο */
    ON lab_test (ordered_by_doctor_amka, test_datetime);

CREATE INDEX idx_proc_event_hosp_start /*Μάλλον για τροποποιηση*/
    ON procedure_event (hosp_id, start_ts);

CREATE INDEX idx_proc_event_chief /*Q2,Q5,Q11 ίσως*/
    ON procedure_event (chief_surgeon_amka, start_ts);

CREATE INDEX idx_proc_event_place /*Ελεγχος overlap για το ίδιο μέρος πιο γρήγορα -> Triggers*/
    ON procedure_event (place_id, start_ts, end_ts);

CREATE INDEX idx_proc_participant_personnel /*Q11*/
    ON procedure_participant (personnel_amka, procedure_event_id);

CREATE INDEX idx_prescription_hosp_patient_start /*Q10 για να βρούμε τις συνταγές ενός ασθενή σε συγκεκριμένη νοσηλεία*/
    ON prescription (hosp_id, patient_amka, start_datetime);

CREATE INDEX idx_prescription_doctor /* Μαλλον για σβησιμο */
    ON prescription (doctor_amka, start_datetime);

CREATE INDEX idx_das_substance /*Q7 για να βρούμε τα φάρμακα που περιέχουν μια δραστική ουσία πιο γρήγορα*/
    ON drug_active_substance (substance_id, drug_id);

CREATE INDEX idx_patient_allergy_substance /*Q7 για να βρούμε τους ασθενείς που είναι αλλεργικοί σε μια δραστική ουσία πιο γρήγορα*/
    ON patient_allergy (substance_id, patient_amka);

CREATE INDEX idx_evaluation_date /*??*/
    ON hospitalization_evaluation (evaluation_date);


/* Triggers for key business rules */

DELIMITER $$

CREATE TRIGGER trg_doctor_supervision_bi
BEFORE INSERT ON doctor
FOR EACH ROW
BEGIN
    IF NEW.supervisor_amka = NEW.amka THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A doctor cannot supervise himself/herself.';
    END IF;

    IF NEW.doctor_rank = 'RESIDENT' AND NEW.supervisor_amka IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A resident doctor must have a supervisor.';
    END IF;

    IF NEW.doctor_rank = 'DIRECTOR' AND NEW.supervisor_amka IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A director doctor cannot have a supervisor.';
    END IF;

    IF NEW.supervisor_amka IS NOT NULL THEN
        DECLARE current_amka CHAR(11) DEFAULT NEW.supervisor_amka;
        WHILE current_amka IS NOT NULL DO
            IF current_amka = NEW.amka THEN /* έφτασα σε κύκλο */
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Circular supervision chain detected.';
            END IF;
            SELECT supervisor_amka INTO current_amka FROM doctor WHERE amka = current_amka; /*ελέγχω τον επόμενο */
        END WHILE;
    END IF;
END$$

CREATE TRIGGER trg_doctor_supervision_bu
BEFORE UPDATE ON doctor
FOR EACH ROW
BEGIN
    IF NEW.supervisor_amka = NEW.amka THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A doctor cannot supervise himself/herself.';
    END IF;

    IF NEW.doctor_rank = 'RESIDENT' AND NEW.supervisor_amka IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A resident doctor must have a supervisor.';
    END IF;

    IF NEW.doctor_rank = 'DIRECTOR' AND NEW.supervisor_amka IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A director doctor cannot have a supervisor.';
    END IF;

    IF NEW.supervisor_amka IS NOT NULL THEN
        DECLARE current_amka CHAR(11) DEFAULT NEW.supervisor_amka;
        WHILE current_amka IS NOT NULL DO
            IF current_amka = NEW.amka THEN /* Εφτασα σε κύκλο */
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Circular supervision chain detected.';
            END IF;
            SELECT supervisor_amka INTO current_amka FROM doctor WHERE amka = current_amka; /*ελέγχω τον επόμενο */
        END WHILE;
    END IF;
END$$

CREATE TRIGGER trg_prescription_no_allergy_bi
BEFORE INSERT ON prescription
FOR EACH ROW /* Για πολλά perscriptions*/
BEGIN
    IF EXISTS (  /*Αν query επιστρεψει αποτελέσματα τότε υπάρχει αλλεργία και απαγορεύεται η συνταγογράφηση*/
        SELECT 1 /*Δεν χρειάζεται να επιλέξουμε συγκεκριμένα πεδία, αρκεί να επιστρέψουμε κάτι για να ξέρουμε ότι υπάρχει αποτέλεσμα*/
        FROM patient_allergy pa
        JOIN drug_active_substance das /*Ενώνουμε τους πίνακες για να βρούμε αν υπάρχει κοινό στοιχείο μεταξύ των δραστικών ουσιών του φαρμάκου και των αλλεργιών του ασθενή*/
          ON das.substance_id = pa.substance_id /*Ελέγχουμε αν ο ασθενής είναι αλλεργικός σε κάποια από τις δραστικές ουσίες του φαρμάκου που προσπαθούμε να συνταγογραφήσουμε*/
        WHERE pa.patient_amka = NEW.patient_amka
          AND das.drug_id = NEW.drug_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Prescription forbidden: patient is allergic to an active substance of this drug.';
    END IF;
END$$

CREATE TRIGGER trg_prescription_no_allergy_bu
BEFORE UPDATE ON prescription /* ακολουθάμε την ίδια λογικη και για το update */
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM patient_allergy pa
        JOIN drug_active_substance das
          ON das.substance_id = pa.substance_id
        WHERE pa.patient_amka = NEW.patient_amka
          AND das.drug_id = NEW.drug_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Prescription forbidden: patient is allergic to an active substance of this drug.';
    END IF;
END$$

CREATE TRIGGER trg_procedure_room_overlap_bi
BEFORE INSERT ON procedure_event /* insert of an event */
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM procedure_event pe
        WHERE pe.place_id = NEW.place_id
          AND NEW.start_ts < pe.end_ts
          AND NEW.end_ts > pe.start_ts
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Two procedures cannot overlap in the same operating place.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM procedure_event pe
        WHERE pe.chief_surgeon_amka = NEW.chief_surgeon_amka
          AND NEW.start_ts < pe.end_ts
          AND NEW.end_ts > pe.start_ts
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The same chief surgeon cannot participate in overlapping procedures.';
    END IF;
END$$

CREATE TRIGGER trg_procedure_room_overlap_bu
BEFORE UPDATE ON procedure_event /* update of an event */
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM procedure_event pe
        WHERE pe.procedure_event_id != NEW.procedure_event_id  /* not equal */
          AND pe.place_id = NEW.place_id
          AND NEW.start_ts < pe.end_ts
          AND NEW.end_ts > pe.start_ts
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Two procedures cannot overlap in the same operating place.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM procedure_event pe
        WHERE pe.procedure_event_id != NEW.procedure_event_id /* not equal */
          AND pe.chief_surgeon_amka = NEW.chief_surgeon_amka
          AND NEW.start_ts < pe.end_ts
          AND NEW.end_ts > pe.start_ts
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The same chief surgeon cannot participate in overlapping procedures.';
    END IF;
END$$

CREATE TRIGGER trg_procedure_participant_overlap_bi /* Για να ελέγξουμε αν το προσωπικό που προσπαθούμε να προσθέσουμε ως συμμετέχοντα σε μια διαδικασία συμμετέχει ήδη σε άλλη διαδικασία που επικαλύπτεται χρονικά με την τρέχουσα ή είναι επικεφαλής χειρουργός σε άλλη διαδικασία που επικαλύπτεται χρονικά με την τρέχουσα */
BEFORE INSERT ON procedure_participant
FOR EACH ROW
BEGIN
    DECLARE v_start DATETIME; /* Χρειαζόμαστε την ημερομηνία έναρξης */
    DECLARE v_end DATETIME;   /* και λήξης της διαδικασίας για να ελέγξουμε τις επικαλύψεις */

    SELECT start_ts, end_ts /* Επιλέγουμε την ημερομηνία έναρξης και λήξης της διαδικασίας στην οποία προσπαθούμε να προσθέσουμε συμμετέχοντα */
      INTO v_start, v_end
      FROM procedure_event
     WHERE procedure_event_id = NEW.procedure_event_id;

    IF EXISTS (  /* Ελέγχουμε αν το προσωπικό που προσπαθούμε να προσθέσουμε συμμετέχει ήδη σε άλλη διαδικασία που επικαλύπτεται χρονικά με την τρέχουσα */
        SELECT 1 /* Δεν χρειάζεται να επιλέξουμε συγκεκριμένα πεδία, αρκεί να επιστρέψουμε κάτι για να ξέρουμε ότι υπάρχει αποτέλεσμα */
        FROM procedure_participant pp
        JOIN procedure_event pe
          ON pe.procedure_event_id = pp.procedure_event_id
        WHERE pp.personnel_amka = NEW.personnel_amka 
          AND v_start < pe.end_ts
          AND v_end > pe.start_ts
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The same staff member cannot participate in overlapping procedures.';
    END IF;

    IF EXISTS ( /* Ελέγχουμε αν το προσωπικό που προσπαθούμε να προσθέσουμε είναι επικεφαλής χειρουργός σε άλλη διαδικασία που επικαλύπτεται χρονικά με την τρέχουσα */
        SELECT 1
        FROM procedure_event pe
        WHERE pe.chief_surgeon_amka = NEW.personnel_amka
          AND v_start < pe.end_ts
          AND v_end > pe.start_ts
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'The same doctor cannot be chief surgeon in one procedure and participant in another at the same time.';
    END IF;
END$$

CREATE TRIGGER trg_procedure_place_type_bi /* Για να ελέγξουμε αν ο τύπος του χώρου που προσπαθούμε να ορίσουμε για μια διαδικασία ταιριάζει με τον απαιτούμενο τύπο χώρου της διαδικασίας */
BEFORE INSERT ON procedure_event
FOR EACH ROW
BEGIN
    DECLARE v_required_place_type VARCHAR(30);
    DECLARE v_actual_place_type VARCHAR(30);

    SELECT required_place_type
      INTO v_required_place_type
      FROM procedure_catalog
     WHERE procedure_code = NEW.procedure_code;

    SELECT place_type
      INTO v_actual_place_type
      FROM operating_place
     WHERE place_id = NEW.place_id;

    IF v_required_place_type != v_actual_place_type THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Procedure event place type does not match the required place type of the procedure.';
    END IF;
END$$

CREATE TRIGGER trg_procedure_place_type_bu /* Για να ελέγξουμε αν ο τύπος του χώρου που προσπαθούμε να ορίσουμε για μια διαδικασία ταιριάζει με τον απαιτούμενο τύπο χώρου της διαδικασίας σε περίπτωση update */
BEFORE UPDATE ON procedure_event
FOR EACH ROW
BEGIN
    DECLARE v_required_place_type VARCHAR(30);
    DECLARE v_actual_place_type VARCHAR(30);

    SELECT required_place_type
      INTO v_required_place_type
      FROM procedure_catalog
     WHERE procedure_code = NEW.procedure_code;

    SELECT place_type
      INTO v_actual_place_type
      FROM operating_place
     WHERE place_id = NEW.place_id;

    IF v_required_place_type != v_actual_place_type THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Procedure event place type does not match the required place type of the procedure.';
    END IF;
END$$

CREATE TRIGGER trg_procedure_participant_not_chief_bi /* Για να ελέγξουμε αν ο συμμετέχων που προσπαθούμε να προσθέσουμε είναι ο ίδιος με τον επικεφαλής χειρουργό της διαδικασίας, κάτι που απαγορεύεται */
BEFORE INSERT ON procedure_participant
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM procedure_event pe
        WHERE pe.procedure_event_id = NEW.procedure_event_id
          AND pe.chief_surgeon_amka = NEW.personnel_amka
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Chief surgeon must not be duplicated in procedure participants.';
    END IF;
END$$

CREATE TRIGGER trg_procedure_participant_not_admin_bi /* Για να ελέγξουμε αν ο συμμετέχων που προσπαθούμε να προσθέσουμε είναι διοικητικό προσωπικό, κάτι που απαγορεύεται */
BEFORE INSERT ON procedure_participant
FOR EACH ROW
BEGIN
    DECLARE v_type VARCHAR(20);
    SELECT personnel_type INTO v_type FROM personnel WHERE amka = NEW.personnel_amka;
    IF v_type = 'ADMIN' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Administrative staff cannot participate in procedures.';
    END IF;
END$$

CREATE TRIGGER trg_procedure_participant_not_admin_bu /* Για να ελέγξουμε αν ο συμμετέχων που προσπαθούμε να προσθέσουμε είναι διοικητικό προσωπικό σε περίπτωση update, κάτι που απαγορεύεται */
BEFORE UPDATE ON procedure_participant
FOR EACH ROW
BEGIN
    DECLARE v_type VARCHAR(20);
    SELECT personnel_type INTO v_type FROM personnel WHERE amka = NEW.personnel_amka;
    IF v_type = 'ADMIN' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Administrative staff cannot participate in procedures.';
    END IF;
END$$

DELIMITER ;
