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