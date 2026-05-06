/* Q1 */
SELECT 
    d.department_name,
    YEAR(h.discharge_ts) AS hosp_year,
    k.ken_code,
    k.ken_description,
    p.insurance_provider,
    COUNT(h.hosp_id) AS total_hospitalizations,
    -- Συνολικό βασικό κόστος
    SUM(k.basic_cost) AS total_basic_cost,
    -- Συνολικό πρόσθετο κόστος εάν οι ημέρες νοσηλείας > mean_duration_days
    SUM(
        GREATEST(0, DATEDIFF(DATE(h.discharge_ts), DATE(h.admission_ts)) - k.mean_duration_days) * k.extra_daily_cost
    ) AS total_extra_cost,
    -- Συνολικά έσοδα (άθροισμα του total_cost από τον πίνακα hospitalization)
    SUM(h.total_cost) AS final_total_revenue
FROM hospitalization h
JOIN department d ON h.department_id = d.department_id
JOIN ken k ON h.ken_code = k.ken_code
JOIN patient p ON h.patient_amka = p.patient_amka
WHERE h.discharge_ts IS NOT NULL
GROUP BY 
    d.department_name, 
    YEAR(h.discharge_ts), 
    k.ken_code, 
    k.ken_description,
    p.insurance_provider
ORDER BY 
    d.department_name, 
    hosp_year, 
    k.ken_code;

/* Q2 */
-- Αντικατέστησε το 'Χειρουργική' με την επιθυμητή ειδικότητα
SELECT 
    p.amka, 
    p.first_name, 
    p.last_name, 
    d.specialization,
    -- Ένδειξη αν είχε βάρδια στο τρέχον έτος
    CASE 
        WHEN COUNT(DISTINCT ds.shift_id) > 0 THEN 'YES' 
        ELSE 'NO' 
    END AS had_shift_current_year,
    -- Αριθμός επεμβάσεων ως κύριος χειρουργός
    COUNT(DISTINCT pe.procedure_event_id) AS primary_surgeries_count
FROM doctor d
JOIN personnel p ON d.amka = p.amka
-- Left join για βάρδιες του τρέχοντος έτους
LEFT JOIN shift_assignment sa ON p.amka = sa.personnel_amka
LEFT JOIN department_shift ds ON sa.shift_id = ds.shift_id 
    AND YEAR(ds.shift_date) = YEAR(CURRENT_DATE())
-- Left join για τις επεμβάσεις που ήταν chief surgeon
LEFT JOIN procedure_event pe ON d.amka = pe.chief_surgeon_amka
WHERE d.specialization = 'Χειρουργική' 
GROUP BY 
    p.amka, 
    p.first_name, 
    p.last_name, 
    d.specialization;

/* Q3 */
SELECT 
    p.patient_amka, 
    p.first_name, 
    p.last_name, 
    d.department_name,
    COUNT(h.hosp_id) AS total_hospitalizations,
    SUM(h.total_cost) AS total_hospitalization_cost
FROM patient p
JOIN hospitalization h ON p.patient_amka = h.patient_amka
JOIN department d ON h.department_id = d.department_id
GROUP BY 
    p.patient_amka, 
    p.first_name, 
    p.last_name, 
    d.department_id, 
    d.department_name
HAVING COUNT(h.hosp_id) > 3
ORDER BY total_hospitalizations DESC;

/* Q4 */
/* Αντικατέστησε το '12345678901' με τον AMKA του συγκεκριμένου ιατρού */
EXPLAIN ANALYZE
SELECT 
    p.first_name, 
    p.last_name, 
    AVG(e.medical_care_score) AS avg_medical_care,
    AVG(e.overall_experience_score) AS avg_overall_experience
FROM doctor d
JOIN personnel p ON d.amka = p.amka
JOIN hospitalization_doctor hd ON d.amka = hd.doctor_amka
JOIN hospitalization_evaluation e ON hd.hosp_id = e.hosp_id
WHERE d.amka = '12345678901'
GROUP BY 
    d.amka, 
    p.first_name, 
    p.last_name;

/* ignore index */
EXPLAIN ANALYZE
SELECT p.first_name, p.last_name, 
       AVG(e.medical_care_score) AS avg_medical_care,
       AVG(e.overall_experience_score) AS avg_overall_experience
FROM doctor d
JOIN personnel p ON d.amka = p.amka
JOIN hospitalization_doctor hd IGNORE INDEX (fk_hosp_doctor_doctor) ON d.amka = hd.doctor_amka
JOIN hospitalization_evaluation e ON hd.hosp_id = e.hosp_id
WHERE d.amka = '12345678901'
GROUP BY d.amka, p.first_name, p.last_name;

/* Q5 */
SELECT 
    p.amka, 
    p.first_name, 
    p.last_name, 
    p.age,
    COUNT(pe.procedure_event_id) AS total_surgeries
FROM doctor d
JOIN personnel p ON d.amka = p.amka
JOIN procedure_event pe ON d.amka = pe.chief_surgeon_amka
JOIN procedure_catalog pc ON pe.procedure_code = pc.procedure_code
WHERE p.age < 35 
  AND pc.procedure_category = 'SURGICAL'
GROUP BY 
    p.amka, 
    p.first_name, 
    p.last_name, 
    p.age
ORDER BY total_surgeries DESC;

/* Q6 */
EXPLAIN ANALYZE
/* Αντικατέστησε το '01234567890' με τον AMKA του επιθυμητού ασθενή */
SELECT 
    h.hosp_id,
    h.admission_ts,
    h.discharge_ts,
    icd_in.icd10_code AS admission_diagnosis_code,
    icd_in.icd10_description AS admission_diagnosis_desc,
    icd_out.icd10_code AS discharge_diagnosis_code,
    icd_out.icd10_description AS discharge_diagnosis_desc,
    h.total_cost,
    -- Υπολογισμός του μέσου όρου των βαθμολογιών που άφησε ο ασθενής για τη συγκεκριμένη νοσηλεία
    (e.medical_care_score + e.nursing_care_score + e.cleanliness_score + e.food_score + e.overall_experience_score) / 5.0 AS average_evaluation_score
FROM hospitalization h
-- Διαγνώσεις εισαγωγής
JOIN icd10_diagnosis icd_in ON h.admission_icd10_code = icd_in.icd10_code
-- Διαγνώσεις εξόδου (LEFT JOIN γιατί μπορεί να μην έχει δοθεί ακόμα εξιτήριο)
LEFT JOIN icd10_diagnosis icd_out ON h.discharge_icd10_code = icd_out.icd10_code
-- Αξιολογήσεις (LEFT JOIN γιατί δεν κάνουν όλοι οι ασθενείς αξιολόγηση)
LEFT JOIN hospitalization_evaluation e ON h.hosp_id = e.hosp_id
WHERE h.patient_amka = '01234567890'
ORDER BY h.admission_ts DESC;

/*ignore index */
EXPLAIN ANALYZE
SELECT h.hosp_id, h.admission_ts, h.discharge_ts,
       icd_in.icd10_code, icd_in.icd10_description,
       h.total_cost,
       (e.medical_care_score + e.nursing_care_score + e.cleanliness_score + e.food_score + e.overall_experience_score) / 5.0 AS avg_score
FROM hospitalization h IGNORE INDEX (idx_hosp_patient_dept_dates, fk_hosp_patient)
JOIN icd10_diagnosis icd_in ON h.admission_icd10_code = icd_in.icd10_code
LEFT JOIN hospitalization_evaluation e ON h.hosp_id = e.hosp_id
WHERE h.patient_amka = '01234567890'
ORDER BY h.admission_ts DESC;

/* Q7 */
SELECT 
    s.substance_name,
    COUNT(DISTINCT pa.patient_amka) AS allergic_patients_count,
    COUNT(DISTINCT das.drug_id) AS drugs_containing_count
FROM active_substance s
-- LEFT JOIN για να συμπεριληφθούν και ουσίες που ίσως δεν έχουν καταγεγραμμένες αλλεργίες
LEFT JOIN patient_allergy pa ON s.substance_id = pa.substance_id
-- LEFT JOIN για τα φάρμακα
LEFT JOIN drug_active_substance das ON s.substance_id = das.substance_id
GROUP BY 
    s.substance_id, 
    s.substance_name
ORDER BY allergic_patients_count DESC;

/* Q8 */
/*Αντικαταστήστε την ημερομηνία και το τμήμα με τα επιθυμητά*/
SELECT p.amka, p.first_name, p.last_name, p.personnel_type
FROM personnel p
WHERE p.amka NOT IN (
    /* Υποερώτημα: Βρίσκει όσους ΕΧΟΥΝ βάρδια τη συγκεκριμένη μέρα στο συγκεκριμένο τμήμα*/
    SELECT sa.personnel_amka
    FROM shift_assignment sa
    JOIN department_shift ds ON sa.shift_id = ds.shift_id
    WHERE ds.shift_date = '2026-05-20' 
      AND ds.department_id = 1
);

/* Q9 */
/* Χρήση CTE (Common Table Expression) για να υπολογίσουμε τις μέρες ανά ασθενή/έτος */
WITH PatientYearlyDays AS (
    SELECT 
        patient_amka,
        YEAR(admission_ts) AS hosp_year,
        /* Αν δεν έχει πάρει εξιτήριο, μετράμε μέχρι τη σημερινή μέρα */
        SUM(DATEDIFF(IFNULL(discharge_ts, CURRENT_TIMESTAMP), admission_ts)) AS total_days
    FROM hospitalization
    GROUP BY patient_amka, YEAR(admission_ts)
    HAVING total_days > 15
)
/* Self Join για να βρούμε τα ζευγάρια (ή ομάδες) ασθενών που έχουν ακριβώς τις ίδιες μέρες */
SELECT 
    p1.patient_amka AS patient_A, 
    p2.patient_amka AS patient_B, 
    p1.total_days, 
    p1.hosp_year
FROM PatientYearlyDays p1
JOIN PatientYearlyDays p2 
    ON p1.total_days = p2.total_days 
    AND p1.hosp_year = p2.hosp_year 
    AND p1.patient_amka < p2.patient_amka /* Χρήση '<' για να μην πάρουμε διπλότυπα ζεύγη (πχ Α-Β και Β-Α) */
ORDER BY p1.total_days DESC, p1.hosp_year;

/* Q10 */
WITH PatientSubstances AS (
    /* Βρίσκουμε όλες τις διακριτές ουσίες ανά νοσηλεία και ασθενή*/
    SELECT DISTINCT pr.hosp_id, pr.patient_amka, das.substance_id, asub.substance_name
    FROM prescription pr
    JOIN drug_active_substance das ON pr.drug_id = das.drug_id
    JOIN active_substance asub ON das.substance_id = asub.substance_id
)
SELECT 
    ps1.substance_name AS substance_1,
    ps2.substance_name AS substance_2,
    COUNT(*) AS co_occurrence_count
FROM PatientSubstances ps1
JOIN PatientSubstances ps2 
    ON ps1.hosp_id = ps2.hosp_id 
    AND ps1.patient_amka = ps2.patient_amka
    /* Χρήση '<' για να διασφαλίσουμε μοναδικά ζεύγη */
    AND ps1.substance_id < ps2.substance_id 
GROUP BY ps1.substance_name, ps2.substance_name
ORDER BY co_occurrence_count DESC
LIMIT 3;

/* Q11 */
WITH DoctorSurgeries AS (
    SELECT chief_surgeon_amka, COUNT(procedure_event_id) AS num_surgeries
    FROM procedure_event
    WHERE YEAR(start_ts) = YEAR(CURRENT_DATE())
    GROUP BY chief_surgeon_amka
),
MaxSurgeries AS (
    SELECT MAX(num_surgeries) AS max_surg FROM DoctorSurgeries
)
SELECT ds.chief_surgeon_amka, ds.num_surgeries, ms.max_surg
FROM DoctorSurgeries ds
CROSS JOIN MaxSurgeries ms
WHERE ds.num_surgeries <= (ms.max_surg - 5)
ORDER BY ds.num_surgeries DESC;

/* Q12 */
/* Αντικαταστήστε την ημερομηνία της εβδομάδας που θέλετε να ελέγξετε */
SELECT 
    ds.department_id, 
    d.department_name, 
    ds.shift_date, 
    ds.shift_type,
    p.personnel_type,
    doc.specialization,
    n.degree AS nurse_rank,
    a.admin_role,
    COUNT(sa.personnel_amka) AS assigned_count
FROM department_shift ds
JOIN department d ON ds.department_id = d.department_id
JOIN shift_assignment sa ON ds.shift_id = sa.shift_id
JOIN personnel p ON sa.personnel_amka = p.amka
/* Left joins για να πάρουμε τα ειδικά χαρακτηριστικά της κάθε υποκλάσης */
LEFT JOIN doctor doc ON p.amka = doc.amka
LEFT JOIN nurse n ON p.amka = n.amka
LEFT JOIN administrative_staff a ON p.amka = a.amka
WHERE YEARWEEK(ds.shift_date, 1) = YEARWEEK('2026-05-20', 1)
GROUP BY 
    ds.department_id, d.department_name, ds.shift_date, ds.shift_type,
    p.personnel_type, doc.specialization, n.degree, a.admin_role
ORDER BY ds.department_id, ds.shift_date, ds.shift_type;

/* Q13 */
/*Απαιτείται Recursive CTE */
WITH RECURSIVE SupervisorHierarchy AS (
    /*Base Case: Ο ιατρός και ο άμεσος επόπτης του */
    SELECT 
        amka AS original_doctor_amka,
        amka AS current_doctor_amka,
        supervisor_amka,
        1 AS hierarchy_level
    FROM doctor
    WHERE supervisor_amka IS NOT NULL

    UNION ALL

    /* Recursive Step: Βρίσκουμε τον επόπτη του επόπτη */
    SELECT 
        sh.original_doctor_amka,
        d.amka AS current_doctor_amka,
        d.supervisor_amka,
        sh.hierarchy_level + 1
    FROM SupervisorHierarchy sh
    JOIN doctor d ON sh.supervisor_amka = d.amka
    WHERE d.supervisor_amka IS NOT NULL
)
SELECT 
    sh.original_doctor_amka,
    p1.first_name AS doc_first_name,
    p1.last_name AS doc_last_name,
    sh.supervisor_amka,
    p2.first_name AS sup_first_name,
    p2.last_name AS sup_last_name,
    d2.doctor_rank AS sup_rank,
    sh.hierarchy_level
FROM SupervisorHierarchy sh
JOIN personnel p1 ON sh.original_doctor_amka = p1.amka
JOIN doctor d2 ON sh.supervisor_amka = d2.amka
JOIN personnel p2 ON d2.amka = p2.amka
ORDER BY sh.original_doctor_amka, sh.hierarchy_level;

/* Q14 */
WITH YearlyICD AS (
    SELECT 
        admission_icd10_code AS icd10,
        YEAR(admission_ts) AS adm_year,
        COUNT(*) AS num_admissions
    FROM hospitalization
    GROUP BY admission_icd10_code, YEAR(admission_ts)
    HAVING COUNT(*) >= 5
)
SELECT 
    y1.icd10, 
    i.icd10_description,
    y1.adm_year AS year_1,
    y2.adm_year AS year_2,
    y1.num_admissions
FROM YearlyICD y1
JOIN YearlyICD y2 
    ON y1.icd10 = y2.icd10 
    AND y1.num_admissions = y2.num_admissions 
    AND y2.adm_year = y1.adm_year + 1 /* Συνεχόμενα έτη */
JOIN icd10_diagnosis i ON y1.icd10 = i.icd10_code
ORDER BY y1.num_admissions DESC, y1.icd10;

/* Q15 */
/* Εφόσον δεν υπάρχει ρητό πεδίο referred_department_id στον πίνακα emergency_visit που δώσατε, 
συνδέουμε έμμεσα την επίσκεψη στο triage με τον πίνακα νοσηλείας του ίδιου ασθενή εφόσον η 
εισαγωγή έγινε εντός 24 ωρών από την επίσκεψη */
WITH VisitData AS (
    SELECT 
        ev.visit_id, 
        ev.emergency_level,
        /* Υπολογισμός χρόνου αναμονής σε λεπτά */
        TIMESTAMPDIFF(MINUTE, ev.arrival_ts, ev.service_start_ts) AS wait_time_mins,
        ev.disposition,
        h.department_id,
        d.department_name
    FROM emergency_visit ev
    /*Σύνδεση με νοσηλεία εάν προέκυψε νοσηλεία (εντός 24 ωρών)*/
    LEFT JOIN hospitalization h 
        ON ev.patient_amka = h.patient_amka 
        AND h.admission_ts >= ev.arrival_ts 
        AND h.admission_ts <= DATE_ADD(ev.arrival_ts, INTERVAL 24 HOUR)
    LEFT JOIN department d ON h.department_id = d.department_id
)
SELECT 
    emergency_level,
    COUNT(DISTINCT visit_id) AS total_visits,
    ROUND(AVG(wait_time_mins), 2) AS avg_wait_time_mins,
    /* Ποσοστό περιστατικών που οδήγησαν σε νοσηλεία */
    ROUND(SUM(CASE WHEN disposition = 'HOSPITALIZED' THEN 1 ELSE 0 END) / COUNT(DISTINCT visit_id) * 100, 2) AS hosp_percentage,
    /* Κατανομή παραπομπών: Το τμήμα και πόσες φορές δέχτηκε ασθενείς αυτού του επιπέδου */
    IFNULL(department_name, 'NO_ADMISSION') AS referred_department,
    COUNT(department_id) AS referrals_count
FROM VisitData
GROUP BY emergency_level, department_name
ORDER BY emergency_level, referrals_count DESC;




