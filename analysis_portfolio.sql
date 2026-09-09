-- Polish Junior Data Job Market 2026
-- SQL analysis
-- Dataset: 100 junior / entry-level data-related job offers

-- =========================================================
-- DATA QUALITY CHECK
-- =========================================================

SELECT 'jobs' AS table_name, COUNT(*) AS row_count
FROM jobs

UNION ALL

SELECT 'skills', COUNT(*)
FROM skills

UNION ALL

SELECT 'job_skills', COUNT(*)
FROM job_skills;


-- =========================================================
-- ANALYSIS 01 - MOST FREQUENTLY MENTIONED SKILLS
-- =========================================================
-- Shows which technologies and tools appear most often across the sample.

SELECT
    s.skill_name,
    COUNT(DISTINCT js.job_id) AS offers_count
FROM job_skills js
JOIN skills s
    ON js.skill_id = s.skill_id
GROUP BY s.skill_id, s.skill_name
ORDER BY offers_count DESC
LIMIT 10;


-- =========================================================
-- ANALYSIS 02 - SKILL SHARE OF THE JOB MARKET
-- =========================================================
-- Shows what percentage of all 100 offers mentions each skill.

SELECT
    s.skill_name,
    ROUND(
        COUNT(DISTINCT js.job_id) * 100.0 / (SELECT COUNT(*) FROM jobs),
        2
    ) AS offer_percentage
FROM job_skills js
JOIN skills s
    ON js.skill_id = s.skill_id
GROUP BY s.skill_id, s.skill_name
ORDER BY offer_percentage DESC;


-- =========================================================
-- ANALYSIS 03 - MOST FREQUENTLY REQUIRED SKILLS
-- =========================================================
-- Excludes skills listed only as alternatives and focuses on mandatory requirements.

SELECT
    s.skill_name,
    COUNT(DISTINCT js.job_id) AS required_offers
FROM job_skills js
JOIN skills s
    ON js.skill_id = s.skill_id
WHERE js.is_alternative IS FALSE
GROUP BY s.skill_id, s.skill_name
ORDER BY required_offers DESC
LIMIT 10;


-- =========================================================
-- ANALYSIS 04 - ALTERNATIVE SKILL REQUIREMENTS
-- =========================================================
-- Identifies technologies accepted as alternatives, e.g. SQL or Python.

SELECT
    s.skill_name,
    COUNT(DISTINCT js.job_id) AS alternative_offers_count
FROM job_skills js
JOIN skills s
    ON js.skill_id = s.skill_id
WHERE js.is_alternative IS TRUE
GROUP BY s.skill_id, s.skill_name
ORDER BY alternative_offers_count DESC;


-- =========================================================
-- ANALYSIS 05 - MOST COMMON REQUIRED SKILL PAIRS
-- =========================================================
-- Finds skills that are most often required together in the same job offer.

SELECT
    s1.skill_name AS skill_1,
    s2.skill_name AS skill_2,
    COUNT(DISTINCT js1.job_id) AS offers_count
FROM job_skills js1
JOIN job_skills js2
    ON js1.job_id = js2.job_id
   AND js1.skill_id < js2.skill_id
JOIN skills s1
    ON js1.skill_id = s1.skill_id
JOIN skills s2
    ON js2.skill_id = s2.skill_id
WHERE js1.is_alternative IS FALSE
  AND js2.is_alternative IS FALSE
GROUP BY s1.skill_name, s2.skill_name
ORDER BY offers_count DESC
LIMIT 10;


-- =========================================================
-- ANALYSIS 06 - EXPERIENCE BARRIER
-- =========================================================
-- Measures how often junior offers require previous professional experience.

SELECT
    COUNT(*) AS total_offers,

    SUM(
        CASE
            WHEN experience_status = 'Required' THEN 1
            ELSE 0
        END
    ) AS experience_required,

    SUM(
        CASE
            WHEN experience_status = 'Not required' THEN 1
            ELSE 0
        END
    ) AS no_experience_required,

    SUM(
        CASE
            WHEN experience_status = 'Unknown' THEN 1
            ELSE 0
        END
    ) AS unknown_experience,

    ROUND(
        SUM(
            CASE
                WHEN experience_status = 'Required' THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        0
    ) AS required_percentage,

    ROUND(
        SUM(
            CASE
                WHEN experience_status = 'Not required' THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        0
    ) AS no_experience_percentage,

    ROUND(
        SUM(
            CASE
                WHEN experience_status = 'Unknown' THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        0
    ) AS unknown_percentage
FROM jobs;


-- =========================================================
-- ANALYSIS 07 - MINIMUM EXPERIENCE REQUIRED
-- =========================================================
-- Shows the distribution of minimum years of experience stated in job offers.

SELECT
    CASE
        WHEN experience_years_min = 0 THEN '0 years'
        WHEN experience_years_min = 0.5 THEN '0.5 years'
        WHEN experience_years_min = 1 THEN '1 year'
        WHEN experience_years_min = 2 THEN '2 years'
        WHEN experience_years_min IS NULL THEN 'Not specified'
        ELSE experience_years_min::text || ' years'
    END AS experience_level,
    COUNT(*) AS offers_count
FROM jobs
GROUP BY experience_years_min
ORDER BY experience_years_min NULLS LAST;


-- =========================================================
-- ANALYSIS 08 - SKILLS VS EXPERIENCE REQUIREMENT
-- =========================================================
-- Compares how often each required skill appears in jobs with and without
-- a previous-experience requirement.

SELECT
    s.skill_name,

    SUM(
        CASE
            WHEN j.experience_status = 'Required' THEN 1
            ELSE 0
        END
    ) AS required_experience,

    SUM(
        CASE
            WHEN j.experience_status = 'Not required' THEN 1
            ELSE 0
        END
    ) AS no_experience_required,

    COUNT(DISTINCT j.job_id) AS total_offers
FROM jobs j
JOIN job_skills js
    ON j.job_id = js.job_id
JOIN skills s
    ON js.skill_id = s.skill_id
WHERE js.is_alternative IS FALSE
GROUP BY s.skill_id, s.skill_name
ORDER BY total_offers DESC
LIMIT 10;


-- =========================================================
-- ANALYSIS 09 - WORK MODEL DISTRIBUTION
-- =========================================================
-- Shows the availability of hybrid, office and remote entry-level jobs.

SELECT
    work_model,
    COUNT(*) AS offers_count,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM jobs),
        0
    ) AS offer_percentage
FROM jobs
GROUP BY work_model
ORDER BY offers_count DESC;


-- =========================================================
-- ANALYSIS 10 - SALARY OVERVIEW
-- =========================================================
-- Compares salary ranges only within the same salary type.
-- Gross employment salaries and net B2B rates are intentionally kept separate.

SELECT
    salary_type,
    COUNT(*) AS offers_with_salary,
    ROUND(AVG(salary_min), 0) AS avg_salary_min,
    ROUND(AVG(salary_max), 0) AS avg_salary_max,
    ROUND(AVG((salary_min + salary_max) / 2.0), 0) AS avg_salary_midpoint
FROM jobs
WHERE salary_min IS NOT NULL
  AND salary_max IS NOT NULL
GROUP BY salary_type
ORDER BY salary_type;


-- =========================================================
-- ANALYSIS 11 - SALARY RANKING WITHIN SALARY TYPE
-- =========================================================
-- Compares each offer's salary midpoint with the average for its salary type
-- and ranks offers separately for gross and net B2B compensation.

WITH salary_data AS (
    SELECT
        title,
        company,
        salary_type,
        ROUND((salary_min + salary_max) / 2.0, 2) AS salary_midpoint
    FROM jobs
    WHERE salary_min IS NOT NULL
      AND salary_max IS NOT NULL
)

SELECT
    title,
    company,
    salary_type,
    salary_midpoint,
    ROUND(
        AVG(salary_midpoint) OVER (PARTITION BY salary_type),
        2
    ) AS avg_salary_midpoint_by_type,
    ROUND(
        salary_midpoint
        - AVG(salary_midpoint) OVER (PARTITION BY salary_type),
        2
    ) AS difference_from_average,
    RANK() OVER (
        PARTITION BY salary_type
        ORDER BY salary_midpoint DESC
    ) AS salary_rank
FROM salary_data
ORDER BY salary_type, salary_rank, title;


-- =========================================================
-- ANALYSIS 12 - TOP SKILLS BY WORK MODEL
-- =========================================================
-- Ranks the top required skills separately within each work model.

WITH skill_counts AS (
    SELECT
        j.work_model,
        s.skill_name,
        COUNT(DISTINCT j.job_id) AS offers_count
    FROM jobs j
    JOIN job_skills js
        ON j.job_id = js.job_id
    JOIN skills s
        ON js.skill_id = s.skill_id
    WHERE js.is_alternative IS FALSE
    GROUP BY j.work_model, s.skill_name
),

ranked_skills AS (
    SELECT
        work_model,
        skill_name,
        offers_count,
        DENSE_RANK() OVER (
            PARTITION BY work_model
            ORDER BY offers_count DESC
        ) AS skill_rank
    FROM skill_counts
)

SELECT
    work_model,
    skill_name,
    offers_count,
    skill_rank
FROM ranked_skills
WHERE skill_rank <= 3
ORDER BY work_model, skill_rank, skill_name;


-- =========================================================
-- ANALYSIS 13 - ENTRY-LEVEL SKILL ACCESSIBILITY
-- =========================================================
-- Identifies required skills that appear most often in jobs not requiring
-- previous experience. Skills appearing in fewer than 3 offers are excluded
-- to reduce noise from very rare technologies.

WITH skill_access AS (
    SELECT
        s.skill_name,
        COUNT(DISTINCT j.job_id) AS total_offers,

        COUNT(DISTINCT CASE
            WHEN j.experience_status = 'Not required' THEN j.job_id
        END) AS no_experience_offers,

        COUNT(DISTINCT CASE
            WHEN j.experience_status = 'Required' THEN j.job_id
        END) AS required_experience_offers
    FROM jobs j
    JOIN job_skills js
        ON j.job_id = js.job_id
    JOIN skills s
        ON js.skill_id = s.skill_id
    WHERE js.is_alternative IS FALSE
    GROUP BY s.skill_name
    HAVING COUNT(DISTINCT j.job_id) >= 3
),

skill_percentage AS (
    SELECT
        skill_name,
        total_offers,
        no_experience_offers,
        required_experience_offers,
        ROUND(
            no_experience_offers * 100.0 / total_offers,
            2
        ) AS no_experience_percentage
    FROM skill_access
)

SELECT
    skill_name,
    total_offers,
    no_experience_offers,
    required_experience_offers,
    no_experience_percentage,
    RANK() OVER (
        ORDER BY
            no_experience_percentage DESC,
            total_offers DESC
    ) AS accessibility_rank
FROM skill_percentage
ORDER BY accessibility_rank, skill_name;
